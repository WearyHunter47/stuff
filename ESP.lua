--[[
    ESP Module — standalone, bus-aware, with healthbar + format modes

    Reads ViewLines state from getgenv().ModuleBus.ViewLines to drive:
      • Highlight fill transparency (base → sight → look)
      • Nametag opacity      (base → sight → look)
      • Nametag size         (base → sight → look)
      • Nametag bolding      (look beam only)
      • Camera-center override opacity
      • Healthbar fill, background, and number opacity (mirrors nametag)
      • Tool ESP (top line, above the display name)

    Screen-size scaling applies ONLY to the healthbar.

    No side effects on require. No auto-start, no print, no global.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------
local DEFAULTS = {
    ESPEnabled          = true,
    ESPShowText         = true,
    ESPTextSize         = 13,
    ESPMaxDistance      = 500,
    ESPUseDistanceLimit = true,
    ESPUseTeamColor     = true,
    ESPFriendColor      = true,

    ESPWhitelist = {},
    ESPBlacklist = {},

    ESP_NAME_FORMAT = "Vertical",
    ESP_NAME_WIDTH  = 150,

    ESP_ANCHOR_PART  = "HumanoidRootPart",
    ESP_STUDS_OFFSET = Vector3.new(0, 2, 0),

    NT_OFFSET_X     = 0,
    NT_OFFSET_Y     = 0,
    NT_LINE_SPACING = 0,

    NT_HIDE_HP_IF_BAR_TEXT = true,

    -- Tool ESP
    ESP_SHOW_TOOL        = true,
    ESP_TOOL_FORMAT      = "Brackets",     -- "Brackets" | "Plain"
    ESP_TOOL_USE_TOOLTIP = false,          -- false = tool.Name, true = tool.ToolTip
    ESP_TOOL_COLOR_MODE  = "White",        -- "White" | "Team" | "Fixed"
    ESP_TOOL_FIXED_COLOR = Color3.fromRGB(255, 200, 80),
    ESP_TOOL_SIZE_DELTA  = -2,             -- added to NT size, then scaled by HUD scale
    ESP_TOOL_BOLD        = false,

    INTEGRATION_ENABLED = true,
    SIGHT_THRESHOLD     = 0.1,

    HL_BASE_TRANSPARENCY  = 0.7,
    HL_SIGHT_TRANSPARENCY = 0.4,
    HL_LOOK_TRANSPARENCY  = 0.1,

    HL_OUTLINE_TRANSPARENCY       = 0.4,
    HL_OUTLINE_SIGHT_TRANSPARENCY = 0.2,
    HL_OUTLINE_LOOK_TRANSPARENCY  = 0.0,
    HL_OUTLINE_DYNAMIC            = true,

    NT_ALPHA_BASE  = 0.6,
    NT_ALPHA_SIGHT = 0.3,
    NT_ALPHA_LOOK  = 0.0,

    NT_SIZE_BASE  = 13,
    NT_SIZE_SIGHT = 16,
    NT_SIZE_LOOK  = 20,

    NT_BOLD_ON_LOOK = true,

    CENTER_OVERRIDE_ENABLED = true,
    CENTER_FALLOFF_DEGREES  = 45,
    CENTER_MAX_ALPHA        = 0.0,

    SCALE_ENABLED          = true,
    SCALE_REFERENCE_HEIGHT = 140,
    SCALE_MIN              = 0.5,
    SCALE_MAX              = 2.0,

    HB_STYLE             = "Figma",
    HB_ENABLED           = true,
    HB_POSITION          = "Bottom",
    HB_LENGTH            = 90,
    HB_THICKNESS         = 10,
    HB_GAP               = 4,

    HB_BG_COLOR          = Color3.fromRGB(20, 20, 20),
    HB_FILL_COLOR        = nil,

    HB_ROUNDED           = true,
    HB_CORNER_RADIUS     = 3,

    HB_BORDER            = true,
    HB_BORDER_COLOR      = Color3.fromRGB(0, 0, 0),
    HB_BORDER_THICKNESS  = 1,

    HB_USE_TEAM_COLOR_FILL = false,
    HB_USE_TEAM_COLOR_TEXT = false,

    HB_LOWHP_OVERRIDE_ENABLED = true,
    HB_LOWHP_THRESHOLD        = 0.33,
    HB_LOWHP_FILL_TOP         = Color3.fromRGB(255, 0, 0),
    HB_LOWHP_FILL_BOTTOM      = Color3.fromRGB(0, 0, 0),
    HB_LOWHP_TEXT_TOP         = Color3.fromRGB(255, 120, 120),
    HB_LOWHP_TEXT_BOTTOM      = Color3.fromRGB(180, 0, 0),

    HB_ALPHA_BASE  = 0.3,
    HB_ALPHA_SIGHT = 0.15,
    HB_ALPHA_LOOK  = 0.0,

    HB_BG_EXTRA_TRANSPARENCY     = 0.15,
    HB_NUMBER_EXTRA_TRANSPARENCY = 0.0,

    HB_BG_TRANSPARENCY   = 0.2,
    HB_FILL_TRANSPARENCY = 0.0,
    HB_NUMBER_ALPHA      = 0.0,

    HB_SHOW_NUMBER       = true,
    HB_NUMBER_POSITION   = "Inside",
    HB_NUMBER_SIZE       = 12,
    HB_NUMBER_COLOR      = Color3.fromRGB(255, 255, 255),
    HB_NUMBER_SHOW_MAX   = false,

    HB_FIGMA = {
        DESIGN_WIDTH = 204,

        OUTLINE_ENABLED   = true,
        OUTLINE_THICKNESS = 1,
        OUTLINE_COLOR     = Color3.fromRGB(200, 200, 200),

        CORNER_ENABLED   = true,
        CORNER_SIZE      = 6,
        CORNER_THICKNESS = 2,
        CORNER_COLOR     = Color3.fromRGB(255, 255, 255),

        TRACK_INSET_X = 3,
        TRACK_INSET_Y = 3,

        BG_ENABLED      = true,
        BG_COLOR        = Color3.fromRGB(45, 45, 45),
        BG_TRANSPARENCY = 0,

        MIDLINE_ENABLED = true,
        MIDLINE_HEIGHT  = 1,
        MIDLINE_COLOR   = Color3.fromRGB(150, 150, 150),

        DIVIDER_COUNT        = 4,
        DIVIDER_WIDTH        = 1,
        DIVIDER_COLOR        = Color3.fromRGB(200, 200, 200),
        DIVIDER_EXTEND_TOP    = 4,
        DIVIDER_EXTEND_BOTTOM = 4,
    },

    KILL_KEYBIND    = nil,
    UPDATE_INTERVAL = 0,
}

local DEFAULT_ESP_COLOR = Color3.fromRGB(255, 255, 255)

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function rgb(c)
    return string.format("rgb(%d,%d,%d)", c.R * 255, c.G * 255, c.B * 255)
end

local function healthColor(hp)
    local pct = math.clamp(hp / 150, 0, 1)
    return Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
end

local function distanceColor(dist)
    local pct = math.clamp(dist / 1000, 0, 1)
    return Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
end

local function getTeamColor(player)
    local ok, team = pcall(function() return player.Team end)
    if not ok or not team then return nil end
    local ok2, brick = pcall(function() return team.TeamColor end)
    if not ok2 or not brick then return nil end
    if brick == BrickColor.new("Neutral") then return nil end
    return brick.Color
end

local function resolveHealthColor(pct, teamColor, cfg, mode)
    if cfg.HB_LOWHP_OVERRIDE_ENABLED and pct < cfg.HB_LOWHP_THRESHOLD then
        local t = pct / math.max(cfg.HB_LOWHP_THRESHOLD, 1e-3)
        if mode == "fill" then
            return cfg.HB_LOWHP_FILL_BOTTOM:Lerp(cfg.HB_LOWHP_FILL_TOP, t)
        else
            return cfg.HB_LOWHP_TEXT_BOTTOM:Lerp(cfg.HB_LOWHP_TEXT_TOP, t)
        end
    end
    if mode == "fill" then
        if cfg.HB_USE_TEAM_COLOR_FILL and teamColor then return teamColor end
        if cfg.HB_FILL_COLOR then return cfg.HB_FILL_COLOR end
        return Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
    else
        if cfg.HB_USE_TEAM_COLOR_TEXT and teamColor then return teamColor end
        return cfg.HB_NUMBER_COLOR
    end
end

--------------------------------------------------------------------------------
-- MODULE
--------------------------------------------------------------------------------
local ESP = {}
ESP.__index = ESP

function ESP.new(overrides)
    local self = setmetatable({}, ESP)
    self.config = {}
    for k, v in pairs(DEFAULTS) do self.config[k] = v end
    if overrides then
        for k, v in pairs(overrides) do
            if k == "HB_FIGMA" and type(v) == "table" then
                for kk, vv in pairs(v) do self.config.HB_FIGMA[kk] = vv end
            else
                self.config[k] = v
            end
        end
    end

    self._objects     = {}
    self._nameColors  = {}
    self._connections = {}
    self._running     = false
    self._lastUpdate  = 0
    self._espVisible  = true
    self._textVisible = true
    self._activeNtSize = nil

    return self
end

function ESP:_track(conn)
    self._connections[#self._connections + 1] = conn
    return conn
end

function ESP:_getHealth(character)
    local hpValue = character:FindFirstChild("Health", true)
    if hpValue then
        local ok, val = pcall(function() return hpValue.Value end)
        if ok and typeof(val) == "number" then return val end
    end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health end
    return 0
end

function ESP:_getMaxHealth(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth > 0 then return hum.MaxHealth end
    return 100
end

function ESP:_getEquippedToolName(character)
    local cfg = self.config
    if not cfg.ESP_SHOW_TOOL then return nil end
    if not character then return nil end

    -- Prefer the currently equipped tool (parented to character),
    -- fall back to the humanoid's GetEquippedTool if that's clearer
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum and typeof(hum.GetEquippedTool) == "function" then
            local ok, equipped = pcall(function() return hum:GetEquippedTool() end)
            if ok and equipped then tool = equipped end
        end
    end
    if not tool then return nil end

    local name = tool.Name
    if cfg.ESP_TOOL_USE_TOOLTIP and tool.ToolTip and tool.ToolTip ~= "" then
        name = tool.ToolTip
    end
    return name
end

function ESP:_getNameColor(player)
    local cached = self._nameColors[player]
    if cached then return cached end

    local username = player.Name:lower()
    local display  = player.DisplayName:lower()

    local function matches(tbl)
        for _, str in ipairs(tbl) do
            str = str:lower()
            if username:find(str, 1, true) or display:find(str, 1, true) then
                return true
            end
        end
        return false
    end

    local color
    if matches(self.config.ESPBlacklist) then
        color = Color3.fromRGB(255, 0, 0)
    elseif matches(self.config.ESPWhitelist) then
        color = Color3.fromRGB(255, 255, 0)
    elseif self.config.ESPFriendColor then
        local ok, isFriend = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if ok and isFriend then
            color = Color3.fromRGB(255, 255, 255)
        end
    end

    if not color then
        if self.config.ESPUseTeamColor then
            color = getTeamColor(player)
        end
        if not color then
            color = DEFAULT_ESP_COLOR
        end
    end

    self._nameColors[player] = color
    return color
end

function ESP:_computeScreenScale(char, root)
    if not self.config.SCALE_ENABLED then return 1 end
    local cam = workspace.CurrentCamera
    if not cam then return 1 end
    local head = char:FindFirstChild("Head")
    if not head then return 1 end
    local headScreen = cam:WorldToViewportPoint(head.Position)
    local feetScreen = cam:WorldToViewportPoint(
        root.Position - Vector3.new(0, 2.5, 0)
    )
    local screenHeight = math.abs(headScreen.Y - feetScreen.Y)
    local reference    = math.max(self.config.SCALE_REFERENCE_HEIGHT, 1)
    local raw          = screenHeight / reference
    return math.clamp(raw, self.config.SCALE_MIN, self.config.SCALE_MAX)
end

function ESP:_resolveAlphas(hit, sightSeen, rootPos)
    local cfg = self.config
    local ntAlpha, hbAlpha

    if cfg.INTEGRATION_ENABLED then
        if hit then
            ntAlpha, hbAlpha = cfg.NT_ALPHA_LOOK, cfg.HB_ALPHA_LOOK
        elseif sightSeen then
            ntAlpha, hbAlpha = cfg.NT_ALPHA_SIGHT, cfg.HB_ALPHA_SIGHT
        else
            ntAlpha, hbAlpha = cfg.NT_ALPHA_BASE, cfg.HB_ALPHA_BASE
        end
    else
        ntAlpha = cfg.NT_ALPHA_BASE
        hbAlpha = cfg.HB_FILL_TRANSPARENCY
    end

    if cfg.CENTER_OVERRIDE_ENABLED then
        local cf = self:_centerFactor(rootPos)
        if cf > 0 then
            local centerAlpha = cfg.CENTER_MAX_ALPHA
                + (1 - cfg.CENTER_MAX_ALPHA) * (1 - cf)
            ntAlpha = math.min(ntAlpha, centerAlpha)
            hbAlpha = math.min(hbAlpha, centerAlpha)
        end
    end
    return ntAlpha, hbAlpha
end

function ESP:_centerFactor(worldPos)
    local cam = workspace.CurrentCamera
    if not cam then return 0 end
    local toTarget = (worldPos - cam.CFrame.Position)
    if toTarget.Magnitude < 1e-4 then return 0 end
    toTarget = toTarget.Unit
    local look = cam.CFrame.LookVector
    local dot  = look:Dot(toTarget)
    local cosFalloff = math.cos(math.rad(self.config.CENTER_FALLOFF_DEGREES))
    if dot <= cosFalloff then return 0 end
    return (dot - cosFalloff) / (1 - cosFalloff)
end

function ESP:_getViewLinesState(player)
    local bus = getgenv().ModuleBus
    if not bus or not bus.ViewLines or not bus.ViewLines.Active then
        return false, 0
    end
    local hit = bus.ViewLines.Hit[player] == true
    local vis = bus.ViewLines.Visibility[player] or 0
    return hit, vis
end

--------------------------------------------------------------------------------
-- LAYOUT
--------------------------------------------------------------------------------
function ESP:_computeLayout(scale)
    local cfg = self.config
    local ntSize = self._activeNtSize or cfg.NT_SIZE_BASE
    local isVertical = (cfg.ESP_NAME_FORMAT == "Vertical")

    -- Tool label height (0 if hidden)
    local toolH = 0
    if cfg.ESP_SHOW_TOOL then
        local toolSize = math.max(6, ntSize + (cfg.ESP_TOOL_SIZE_DELTA or 0))
        toolH = toolSize + 6
    end

    local nameH = ntSize + 6
    local subH  = isVertical and (ntSize + 4) or 0
    local lineSpacing = isVertical and (cfg.NT_LINE_SPACING or 0) or 0
    local textH = toolH + nameH + subH + lineSpacing
    local textW = cfg.ESP_NAME_WIDTH

    local hb = {
        enabled = cfg.HB_ENABLED,
        pos     = cfg.HB_POSITION,
        len     = cfg.HB_LENGTH    * scale,
        thick   = cfg.HB_THICKNESS * scale,
        gap     = cfg.HB_GAP,
    }

    local bbW, bbH
    if not hb.enabled then
        bbW, bbH = textW, textH
    elseif hb.pos == "Top" or hb.pos == "Bottom" then
        bbW = math.max(textW, hb.len)
        bbH = textH + hb.thick + hb.gap
    else
        bbW = textW + hb.thick + hb.gap
        bbH = math.max(textH, hb.len)
    end

    return bbW, bbH, textW, textH, nameH, subH, hb, lineSpacing, toolH
end

--------------------------------------------------------------------------------
-- HEALTHBAR BUILDERS
--------------------------------------------------------------------------------
function ESP:_buildSimpleBar(parent, cfg, scale)
    local refs = {}

    local back = Instance.new("Frame")
    back.Name                   = "HB_Back"
    back.BackgroundColor3       = cfg.HB_BG_COLOR
    back.BackgroundTransparency = cfg.HB_BG_TRANSPARENCY
    back.BorderSizePixel        = 0
    back.Visible                = cfg.HB_ENABLED
    back.Parent                 = parent

    if cfg.HB_BORDER then
        local stroke = Instance.new("UIStroke")
        stroke.Color     = cfg.HB_BORDER_COLOR
        stroke.Thickness = cfg.HB_BORDER_THICKNESS
        stroke.Parent    = back
    end
    if cfg.HB_ROUNDED then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cfg.HB_CORNER_RADIUS)
        corner.Parent = back
    end

    local fill = Instance.new("Frame")
    fill.Name                   = "HB_Fill"
    fill.BackgroundColor3       = Color3.fromRGB(0, 255, 0)
    fill.BackgroundTransparency = cfg.HB_FILL_TRANSPARENCY
    fill.BorderSizePixel        = 0
    fill.Size                   = UDim2.fromScale(1, 1)
    fill.Parent                 = back
    if cfg.HB_ROUNDED then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cfg.HB_CORNER_RADIUS)
        corner.Parent = fill
    end

    local number
    if cfg.HB_SHOW_NUMBER then
        number = Instance.new("TextLabel")
        number.Name                   = "HB_Number"
        number.BackgroundTransparency = 1
        number.Font                   = Enum.Font.GothamBold
        number.TextScaled             = false
        number.TextSize               = cfg.HB_NUMBER_SIZE
        number.TextColor3             = cfg.HB_NUMBER_COLOR
        number.TextTransparency       = cfg.HB_NUMBER_ALPHA
        number.TextStrokeTransparency = 0
        number.Text                   = ""
        number.Parent                 = parent
    end

    refs.style  = "Simple"
    refs.Back   = back
    refs.Fill   = fill
    refs.Number = number
    return refs
end

function ESP:_buildFigmaBar(parent, cfg, scale)
    local F = cfg.HB_FIGMA
    local refs = {}

    local s = math.max(scale * (cfg.HB_LENGTH / F.DESIGN_WIDTH), 0.05)
    local function dpx(v) return math.max(1, math.floor(v * s + 0.5)) end

    local barW = cfg.HB_LENGTH * scale
    local barH = cfg.HB_THICKNESS * scale

    local hbRoot = Instance.new("Frame")
    hbRoot.Name                   = "HB_FigmaRoot"
    hbRoot.BackgroundTransparency = 1
    hbRoot.BorderSizePixel        = 0
    hbRoot.Size                   = UDim2.fromOffset(barW, barH)
    hbRoot.AnchorPoint            = Vector2.new(0.5, 0.5)
    hbRoot.Parent                 = parent

    local isVertical = (cfg.HB_POSITION == "Left" or cfg.HB_POSITION == "Right")
    hbRoot.Rotation = isVertical and 90 or 0

    local insetX = dpx(F.TRACK_INSET_X)
    local insetY = dpx(F.TRACK_INSET_Y)

    local container = Instance.new("Frame")
    container.Name                   = "FigmaContainer"
    container.BackgroundTransparency = 1
    container.Size                   = UDim2.fromOffset(barW, barH)
    container.Position               = UDim2.fromOffset(0, 0)
    container.Parent                 = hbRoot

    local trackW = barW - insetX * 2
    local trackH = barH - insetY * 2
    if trackW < 1 then trackW = 1 end
    if trackH < 1 then trackH = 1 end

    local bg
    if F.BG_ENABLED then
        bg = Instance.new("Frame")
        bg.Name                   = "BG"
        bg.BackgroundColor3       = F.BG_COLOR
        bg.BackgroundTransparency = F.BG_TRANSPARENCY
        bg.BorderSizePixel        = 0
        bg.Position               = UDim2.fromOffset(insetX, insetY)
        bg.Size                   = UDim2.fromOffset(trackW, trackH)
        bg.Parent                 = container
    end

    local fill = Instance.new("Frame")
    fill.Name                   = "Fill"
    fill.BackgroundColor3       = Color3.fromRGB(0, 255, 0)
    fill.BorderSizePixel        = 0
    fill.Position               = UDim2.fromOffset(insetX, insetY)
    fill.Size                   = UDim2.fromOffset(trackW, trackH)
    fill.Parent                 = container

    if F.MIDLINE_ENABLED then
        local mh = dpx(F.MIDLINE_HEIGHT)
        local mid = Instance.new("Frame")
        mid.Name                   = "Midline"
        mid.BackgroundColor3       = F.MIDLINE_COLOR
        mid.BorderSizePixel        = 0
        mid.Position               = UDim2.fromOffset(
            insetX,
            insetY + math.floor((trackH - mh) / 2 + 0.5)
        )
        mid.Size                   = UDim2.fromOffset(trackW, mh)
        mid.Parent                 = container
    end

    local dividers = {}
    if F.DIVIDER_COUNT and F.DIVIDER_COUNT > 1 then
        local dw = dpx(F.DIVIDER_WIDTH)
        local extTop = dpx(F.DIVIDER_EXTEND_TOP)
        local extBot = dpx(F.DIVIDER_EXTEND_BOTTOM)
        local divH = trackH + extTop + extBot

        for i = 1, F.DIVIDER_COUNT - 1 do
            local frac = i / F.DIVIDER_COUNT
            local x = insetX + math.floor(trackW * frac + 0.5)

            local div = Instance.new("Frame")
            div.Name            = "Divider" .. i
            div.BackgroundColor3 = F.DIVIDER_COLOR
            div.BorderSizePixel = 0
            div.Position        = UDim2.fromOffset(x, insetY - extTop)
            div.Size            = UDim2.fromOffset(dw, divH)
            div.Parent          = container
            dividers[#dividers + 1] = div
        end
    end

    local outlineFrames = {}
    if F.OUTLINE_ENABLED then
        local T = dpx(F.OUTLINE_THICKNESS)
        local OC = F.OUTLINE_COLOR

        local function makeOutline(name, pos, size)
            local f = Instance.new("Frame")
            f.Name            = name
            f.BackgroundColor3 = OC
            f.BorderSizePixel = 0
            f.Position        = pos
            f.Size            = size
            f.Parent          = container
            outlineFrames[#outlineFrames + 1] = f
        end

        makeOutline("OutlineTop",    UDim2.fromOffset(0, 0), UDim2.fromOffset(barW, T))
        makeOutline("OutlineBottom", UDim2.fromOffset(0, barH - T), UDim2.fromOffset(barW, T))
        makeOutline("OutlineLeft",   UDim2.fromOffset(0, 0), UDim2.fromOffset(T, barH))
        makeOutline("OutlineRight",  UDim2.fromOffset(barW - T, 0), UDim2.fromOffset(T, barH))
    end

    local cornerFrames = {}
    if F.CORNER_ENABLED then
        local CS = dpx(F.CORNER_SIZE)
        local CT = dpx(F.CORNER_THICKNESS)
        local CC = F.CORNER_COLOR

        local function makeCorner(name, pos, size)
            local f = Instance.new("Frame")
            f.Name            = name
            f.BackgroundColor3 = CC
            f.BorderSizePixel = 0
            f.Position        = pos
            f.Size            = size
            f.Parent          = container
            cornerFrames[#cornerFrames + 1] = f
        end

        makeCorner("CornerTL_H", UDim2.fromOffset(0, 0), UDim2.fromOffset(CS, CT))
        makeCorner("CornerTL_V", UDim2.fromOffset(0, 0), UDim2.fromOffset(CT, CS))
        makeCorner("CornerTR_H", UDim2.fromOffset(barW - CS, 0), UDim2.fromOffset(CS, CT))
        makeCorner("CornerTR_V", UDim2.fromOffset(barW - CT, 0), UDim2.fromOffset(CT, CS))
        makeCorner("CornerBL_H", UDim2.fromOffset(0, barH - CT), UDim2.fromOffset(CS, CT))
        makeCorner("CornerBL_V", UDim2.fromOffset(0, barH - CS), UDim2.fromOffset(CT, CS))
        makeCorner("CornerBR_H", UDim2.fromOffset(barW - CS, barH - CT), UDim2.fromOffset(CS, CT))
        makeCorner("CornerBR_V", UDim2.fromOffset(barW - CT, barH - CS), UDim2.fromOffset(CT, CS))
    end

    local number
    if cfg.HB_SHOW_NUMBER then
        number = Instance.new("TextLabel")
        number.Name                   = "Number"
        number.BackgroundTransparency = 1
        number.Font                   = Enum.Font.GothamBold
        number.TextScaled             = false
        number.TextSize               = cfg.HB_NUMBER_SIZE * scale
        number.TextColor3             = cfg.HB_NUMBER_COLOR
        number.TextTransparency       = cfg.HB_NUMBER_ALPHA
        number.TextStrokeTransparency = 0
        number.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        number.AnchorPoint            = Vector2.new(0.5, 0.5)
        number.Position               = UDim2.fromScale(0.5, 0.5)
        number.Size                   = UDim2.fromOffset(barW, barH)
        number.Rotation               = isVertical and -90 or 0
        number.Text                   = ""
        number.ZIndex                 = 10
        number.Parent                 = container
    end

    refs.style     = "Figma"
    refs.Root      = hbRoot
    refs.Container = container
    refs.BG        = bg
    refs.Fill      = fill
    refs.Dividers  = dividers
    refs.Outlines  = outlineFrames
    refs.Corners   = cornerFrames
    refs.Number    = number
    refs.TrackW    = trackW
    refs.TrackH    = trackH
    refs.InsetX    = insetX
    refs.InsetY    = insetY
    return refs
end

function ESP:_buildHealthbar(parent, cfg, scale)
    if cfg.HB_STYLE == "Figma" then
        return self:_buildFigmaBar(parent, cfg, scale)
    end
    return self:_buildSimpleBar(parent, cfg, scale)
end

--------------------------------------------------------------------------------
-- CREATE / REMOVE
--------------------------------------------------------------------------------
function ESP:_createESP(player)
    if self._objects[player] then return self._objects[player] end

    local cfg = self.config

    local highlight = Instance.new("Highlight")
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency    = cfg.HL_BASE_TRANSPARENCY
    highlight.OutlineTransparency = cfg.HL_OUTLINE_TRANSPARENCY or 0.4
    highlight.Enabled             = true
    highlight.Parent              = CoreGui

    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = cfg.ESP_STUDS_OFFSET
    billboard.Size        = UDim2.fromOffset(cfg.ESP_NAME_WIDTH, 60)

    -- Tool label (top of stack, above name)
    local toolLabel = Instance.new("TextLabel")
    toolLabel.Name                   = "Tool"
    toolLabel.BackgroundTransparency = 1
    toolLabel.Size                   = UDim2.new(1, 0, 0, cfg.NT_SIZE_BASE)
    toolLabel.Position               = UDim2.new(0, 0, 0, 0)
    toolLabel.Font                   = Enum.Font.GothamMedium
    toolLabel.TextScaled             = false
    toolLabel.RichText               = true
    toolLabel.TextStrokeTransparency = 0
    toolLabel.TextColor3             = Color3.new(1, 1, 1)
    toolLabel.Text                   = ""
    toolLabel.Visible                = cfg.ESP_SHOW_TOOL
    toolLabel.Parent                 = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name                   = "Text"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size                   = UDim2.new(1, 0, 0, cfg.NT_SIZE_BASE + 6)
    nameLabel.Position               = UDim2.new(0, 0, 0, 0)
    nameLabel.Font                   = Enum.Font.GothamMedium
    nameLabel.TextScaled             = false
    nameLabel.RichText               = true
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextColor3             = Color3.new(1, 1, 1)
    nameLabel.Text                   = ""
    nameLabel.Parent                 = billboard

    local subLabel = Instance.new("TextLabel")
    subLabel.BackgroundTransparency = 1
    subLabel.Size                   = UDim2.new(1, 0, 0, cfg.NT_SIZE_BASE + 4)
    subLabel.Position               = UDim2.new(0, 0, 0, cfg.NT_SIZE_BASE + 6)
    subLabel.Font                   = Enum.Font.GothamMedium
    subLabel.TextScaled             = false
    subLabel.RichText               = true
    subLabel.TextStrokeTransparency = 0
    subLabel.TextColor3             = Color3.new(1, 1, 1)
    subLabel.Text                   = ""
    subLabel.Visible                = (cfg.ESP_NAME_FORMAT == "Vertical")
    subLabel.Parent                 = billboard

    local hbRefs = self:_buildHealthbar(billboard, cfg, 1)

    self._objects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        ToolLabel = toolLabel,
        NameLabel = nameLabel,
        SubLabel  = subLabel,
        HB        = hbRefs,
    }
    return self._objects[player]
end

function ESP:_removeESP(player)
    local obj = self._objects[player]
    if not obj then return end
    if obj.Highlight then obj.Highlight:Destroy() end
    if obj.Billboard then obj.Billboard:Destroy() end
    self._objects[player] = nil
    self._nameColors[player] = nil
end

--------------------------------------------------------------------------------
-- HEALTHBAR UPDATE
--------------------------------------------------------------------------------
function ESP:_updateSimpleBar(refs, hp, maxHp, scale, hbAlpha, teamColor)
    local cfg = self.config
    if not cfg.HB_ENABLED or not refs.Back then return end

    local pct = math.clamp(hp / math.max(maxHp, 1), 0, 1)
    local isHorizontal = (cfg.HB_POSITION == "Top" or cfg.HB_POSITION == "Bottom")

    if isHorizontal then
        refs.Fill.Size        = UDim2.fromScale(pct, 1)
        refs.Fill.AnchorPoint = Vector2.new(0, 0)
        refs.Fill.Position    = UDim2.fromScale(0, 0)
    else
        refs.Fill.Size        = UDim2.fromScale(1, pct)
        refs.Fill.AnchorPoint = Vector2.new(0, 1)
        refs.Fill.Position    = UDim2.fromScale(0, 1)
    end

    refs.Fill.BackgroundColor3 = resolveHealthColor(pct, teamColor, cfg, "fill")

    if hbAlpha ~= nil then
        refs.Fill.BackgroundTransparency = hbAlpha
        refs.Back.BackgroundTransparency = math.clamp(
            hbAlpha + cfg.HB_BG_EXTRA_TRANSPARENCY, 0, 1)
    else
        refs.Fill.BackgroundTransparency = cfg.HB_FILL_TRANSPARENCY
        refs.Back.BackgroundTransparency = cfg.HB_BG_TRANSPARENCY
    end

    if refs.Number then
        refs.Number.TextTransparency = hbAlpha ~= nil
            and math.clamp(hbAlpha + cfg.HB_NUMBER_EXTRA_TRANSPARENCY, 0, 1)
            or cfg.HB_NUMBER_ALPHA
        refs.Number.TextColor3 = resolveHealthColor(pct, teamColor, cfg, "text")
        refs.Number.Text = cfg.HB_NUMBER_SHOW_MAX
            and string.format("%d/%d", math.floor(hp), math.floor(maxHp))
            or tostring(math.floor(hp))
        refs.Number.TextSize = cfg.HB_NUMBER_SIZE * scale
    end
end

function ESP:_updateFigmaBar(refs, hp, maxHp, scale, hbAlpha, teamColor)
    local cfg = self.config
    if not cfg.HB_ENABLED or not refs.Root then return end

    local pct = math.clamp(hp / math.max(maxHp, 1), 0, 1)

    local fillW = math.floor(refs.TrackW * pct + 0.5)
    refs.Fill.Size     = UDim2.fromOffset(fillW, refs.TrackH)
    refs.Fill.Position = UDim2.fromOffset(refs.InsetX, refs.InsetY)

    refs.Fill.BackgroundColor3 = resolveHealthColor(pct, teamColor, cfg, "fill")

    if hbAlpha ~= nil then
        refs.Fill.BackgroundTransparency = hbAlpha
        if refs.BG then
            refs.BG.BackgroundTransparency = math.clamp(
                hbAlpha + cfg.HB_BG_EXTRA_TRANSPARENCY, 0, 1)
        end
    else
        refs.Fill.BackgroundTransparency = cfg.HB_FILL_TRANSPARENCY
        if refs.BG then
            refs.BG.BackgroundTransparency = cfg.HB_FIGMA.BG_TRANSPARENCY
        end
    end

    local unitAlpha = refs.Fill.BackgroundTransparency
    if refs.Dividers then
        for _, d in ipairs(refs.Dividers) do d.BackgroundTransparency = unitAlpha end
    end
    if refs.Outlines then
        for _, o in ipairs(refs.Outlines) do o.BackgroundTransparency = unitAlpha end
    end
    if refs.Corners then
        for _, c in ipairs(refs.Corners) do c.BackgroundTransparency = unitAlpha end
    end
    if refs.Midline then
        refs.Midline.BackgroundTransparency = unitAlpha
    end

    if refs.Number then
        refs.Number.TextTransparency = hbAlpha ~= nil
            and math.clamp(hbAlpha + cfg.HB_NUMBER_EXTRA_TRANSPARENCY, 0, 1)
            or cfg.HB_NUMBER_ALPHA
        refs.Number.TextColor3 = resolveHealthColor(pct, teamColor, cfg, "text")
        refs.Number.Text = cfg.HB_NUMBER_SHOW_MAX
            and string.format("%d/%d", math.floor(hp), math.floor(maxHp))
            or tostring(math.floor(hp))
        refs.Number.TextSize = math.max(4, math.floor(cfg.HB_NUMBER_SIZE * scale + 0.5))
    end
end

function ESP:_updateHealthbar(refs, hp, maxHp, scale, hbAlpha, teamColor)
    if refs.style == "Figma" then
        self:_updateFigmaBar(refs, hp, maxHp, scale, hbAlpha, teamColor)
    else
        self:_updateSimpleBar(refs, hp, maxHp, scale, hbAlpha, teamColor)
    end
end

--------------------------------------------------------------------------------
-- LAYOUT (positioning within BillboardGui)
--------------------------------------------------------------------------------
function ESP:_layout(obj, bbW, bbH, textW, textH, nameH, subH, hb, lineSpacing, toolH, scale)
    local cfg = self.config
    obj.Billboard.Size = UDim2.fromOffset(bbW, bbH)

    local textX, textY
    local hbCenterX, hbCenterY

    if not hb.enabled then
        textX = (bbW - textW) * 0.5
        textY = 0
    elseif hb.pos == "Top" then
        hbCenterX = bbW * 0.5
        hbCenterY = hb.thick * 0.5
        textX = (bbW - textW) * 0.5
        textY = hb.thick + hb.gap
    elseif hb.pos == "Bottom" then
        textX = (bbW - textW) * 0.5
        textY = 0
        hbCenterX = bbW * 0.5
        hbCenterY = textH + hb.gap + hb.thick * 0.5
    elseif hb.pos == "Left" then
        hbCenterX = hb.thick * 0.5
        hbCenterY = bbH * 0.5
        textX = hb.thick + hb.gap
        textY = (bbH - textH) * 0.5
    else -- Right
        textX = 0
        textY = (bbH - textH) * 0.5
        hbCenterX = textW + hb.gap + hb.thick * 0.5
        hbCenterY = bbH * 0.5
    end

    textX = textX + (cfg.NT_OFFSET_X or 0)
    textY = textY + (cfg.NT_OFFSET_Y or 0)

    local finalNtSize = self._activeNtSize or cfg.NT_SIZE_BASE
    local toolSize = math.max(6, finalNtSize + (cfg.ESP_TOOL_SIZE_DELTA or 0))

    -- Tool label (top)
    if cfg.ESP_SHOW_TOOL then
        obj.ToolLabel.Position = UDim2.fromOffset(textX, textY)
        obj.ToolLabel.Size     = UDim2.new(0, textW, 0, toolH)
        obj.ToolLabel.TextSize = toolSize
        obj.ToolLabel.Visible  = true
        textY = textY + toolH
    else
        obj.ToolLabel.Visible = false
    end

    -- Name label
    obj.NameLabel.Position = UDim2.fromOffset(textX, textY)
    obj.NameLabel.Size     = UDim2.new(0, textW, 0, nameH)
    obj.NameLabel.TextSize = finalNtSize

    -- Sub label
    obj.SubLabel.Position = UDim2.fromOffset(textX, textY + nameH + (lineSpacing or 0))
    obj.SubLabel.Size     = UDim2.new(0, textW, 0, subH)
    obj.SubLabel.TextSize = finalNtSize
    obj.SubLabel.Visible  = (cfg.ESP_NAME_FORMAT == "Vertical")

    -- Healthbar positioning
    local refs = obj.HB
    if refs.style == "Figma" then
        if refs.Root then
            refs.Root.Visible  = hb.enabled
            refs.Root.Position = UDim2.fromOffset(hbCenterX, hbCenterY)
        end
    else
        if refs.Back then
            refs.Back.Visible = hb.enabled
            if hb.enabled then
                local bx, by, bw, bh
                if hb.pos == "Top" or hb.pos == "Bottom" then
                    bw = hb.len
                    bh = hb.thick
                    bx = (bbW - bw) * 0.5
                    by = (hb.pos == "Top") and 0 or (textH + hb.gap)
                else
                    bw = hb.thick
                    bh = hb.len
                    bx = (hb.pos == "Left") and 0 or (textW + hb.gap)
                    by = (bbH - bh) * 0.5
                end
                refs.Back.Position = UDim2.fromOffset(bx, by)
                refs.Back.Size     = UDim2.fromOffset(bw, bh)

                if refs.Number then
                    local numW = 80 * scale
                    local numH = (cfg.HB_NUMBER_SIZE * scale) + 4
                    if cfg.HB_NUMBER_POSITION == "Inside" then
                        refs.Number.Size     = refs.Back.Size
                        refs.Number.Position = refs.Back.Position
                    else
                        refs.Number.Size     = UDim2.fromOffset(numW, numH)
                        refs.Number.Position = UDim2.fromOffset(bx, by)
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- PUBLIC: update
--------------------------------------------------------------------------------
function ESP:update()
    local cfg = self.config

    if not cfg.ESPEnabled then
        for _, obj in pairs(self._objects) do
            obj.Highlight.Enabled = false
            obj.Billboard.Enabled = false
        end
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local barShowsNumber = cfg.HB_ENABLED and cfg.HB_SHOW_NUMBER
    local showHpInNametag = not (cfg.NT_HIDE_HP_IF_BAR_TEXT and barShowsNumber)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if char and root then
                local obj = self:_createESP(player)
                local dist = math.floor((myRoot.Position - root.Position).Magnitude)

                local withinRange = true
                if cfg.ESPUseDistanceLimit then
                    withinRange = dist <= cfg.ESPMaxDistance
                end

                local hit, vis = self:_getViewLinesState(player)
                local sightSeen = cfg.INTEGRATION_ENABLED
                    and vis >= cfg.SIGHT_THRESHOLD

                local fillT
                if cfg.INTEGRATION_ENABLED then
                    if hit then fillT = cfg.HL_LOOK_TRANSPARENCY
                    elseif sightSeen then fillT = cfg.HL_SIGHT_TRANSPARENCY
                    else fillT = cfg.HL_BASE_TRANSPARENCY end
                else
                    fillT = cfg.HL_BASE_TRANSPARENCY
                end

                local outlineT
                if cfg.HL_OUTLINE_DYNAMIC and cfg.INTEGRATION_ENABLED then
                    if hit then outlineT = cfg.HL_OUTLINE_LOOK_TRANSPARENCY
                    elseif sightSeen then outlineT = cfg.HL_OUTLINE_SIGHT_TRANSPARENCY
                    else outlineT = cfg.HL_OUTLINE_TRANSPARENCY end
                else
                    outlineT = cfg.HL_OUTLINE_TRANSPARENCY
                end

                local ntAlpha, hbAlpha = self:_resolveAlphas(hit, sightSeen, root.Position)

                local ntSize
                if cfg.INTEGRATION_ENABLED then
                    if hit then ntSize = cfg.NT_SIZE_LOOK
                    elseif sightSeen then ntSize = cfg.NT_SIZE_SIGHT
                    else ntSize = cfg.NT_SIZE_BASE end
                else
                    ntSize = cfg.NT_SIZE_BASE
                end
                self._activeNtSize = ntSize

                local ntFont = Enum.Font.GothamMedium
                if cfg.INTEGRATION_ENABLED and cfg.NT_BOLD_ON_LOOK and hit then
                    ntFont = Enum.Font.GothamBold
                end

                local hp    = math.floor(self:_getHealth(char))
                local maxHp = self:_getMaxHealth(char)
                local nameColor = self:_getNameColor(player)
                local teamColor = getTeamColor(player)
                local hpColor   = healthColor(hp)
                local distColor = distanceColor(dist)

                local scale = self:_computeScreenScale(char, root)

                local bbW, bbH, textW, textH, nameH, subH, hb, lineSpacing, toolH =
                    self:_computeLayout(scale)
                self:_layout(obj, bbW, bbH, textW, textH, nameH, subH, hb, lineSpacing, toolH, scale)

                if self._espVisible and withinRange then
                    obj.Highlight.Adornee             = char
                    obj.Highlight.Enabled             = true
                    obj.Highlight.FillColor           = nameColor
                    obj.Highlight.OutlineColor        = nameColor
                    obj.Highlight.FillTransparency    = fillT
                    obj.Highlight.OutlineTransparency = outlineT
                else
                    obj.Highlight.Enabled = false
                    obj.Highlight.Adornee = nil
                end

                if self._textVisible and cfg.ESPShowText then
                    local anchorPart = char:FindFirstChild(cfg.ESP_ANCHOR_PART) or root
                    obj.Billboard.Parent  = anchorPart
                    obj.Billboard.Enabled = true

                    -- Tool label
                    if cfg.ESP_SHOW_TOOL then
                        local toolName = self:_getEquippedToolName(char)
                        if toolName and toolName ~= "" then
                            local display
                            if cfg.ESP_TOOL_FORMAT == "Brackets" then
                                display = "[" .. toolName .. "]"
                            else
                                display = toolName
                            end
                            obj.ToolLabel.Text = display

                            local toolColor
                            if cfg.ESP_TOOL_COLOR_MODE == "Fixed" then
                                toolColor = cfg.ESP_TOOL_FIXED_COLOR
                            elseif cfg.ESP_TOOL_COLOR_MODE == "Team" then
                                toolColor = teamColor or nameColor
                            else -- "White"
                                toolColor = Color3.fromRGB(255, 255, 255)
                            end
                            obj.ToolLabel.TextColor3 = toolColor

                            local toolFont = cfg.ESP_TOOL_BOLD
                                and Enum.Font.GothamBold
                                or Enum.Font.GothamMedium
                            obj.ToolLabel.Font = toolFont

                            obj.ToolLabel.TextTransparency = ntAlpha
                            obj.ToolLabel.Visible = true
                        else
                            obj.ToolLabel.Visible = false
                        end
                    else
                        obj.ToolLabel.Visible = false
                    end

                    -- Name
                    obj.NameLabel.Font             = ntFont
                    obj.NameLabel.TextColor3       = nameColor
                    obj.NameLabel.TextTransparency = ntAlpha

                    -- Sub
                    obj.SubLabel.Font             = ntFont
                    obj.SubLabel.TextColor3       = nameColor
                    obj.SubLabel.TextTransparency = ntAlpha

                    if cfg.ESP_NAME_FORMAT == "Vertical" then
                        obj.NameLabel.Text = player.DisplayName
                        if showHpInNametag then
                            obj.SubLabel.Text = string.format(
                                '<font color="%s">%d</font> | <font color="%s">%d</font>',
                                rgb(hpColor), hp, rgb(distColor), dist)
                        else
                            obj.SubLabel.Text = string.format(
                                '<font color="%s">%d</font>', rgb(distColor), dist)
                        end
                    else
                        obj.NameLabel.Text = string.format(
                            '<font color="%s">%s</font> | <font color="%s">%d</font> | <font color="%s">%d</font>',
                            rgb(nameColor), player.DisplayName,
                            rgb(hpColor), hp, rgb(distColor), dist)
                        obj.SubLabel.Text = ""
                    end

                    self:_updateHealthbar(obj.HB, hp, maxHp, scale, hbAlpha, teamColor)
                else
                    obj.Billboard.Parent = nil
                end
            else
                self:_removeESP(player)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- PUBLIC: lifecycle
--------------------------------------------------------------------------------
function ESP:start()
    if self._running then return end
    self._running = true

    self:_track(RunService.RenderStepped:Connect(function()
        local cfg = self.config
        if cfg.UPDATE_INTERVAL > 0 then
            local now = os.clock()
            if now - self._lastUpdate < cfg.UPDATE_INTERVAL then return end
            self._lastUpdate = now
        end
        self:update()
    end))

    self:_track(Players.PlayerRemoving:Connect(function(player)
        self:_removeESP(player)
    end))

    self:_track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.L then
            self._espVisible = not self._espVisible
        elseif input.KeyCode == Enum.KeyCode.P then
            self._textVisible = not self._textVisible
        end
    end))
end

function ESP:stop()
    if not self._running then return end
    self._running = false

    for i = #self._connections, 1, -1 do
        local c = self._connections[i]
        self._connections[i] = nil
        if typeof(c) == "RBXScriptConnection" then
            c:Disconnect()
        end
    end
    self._connections = {}

    for player in pairs(self._objects) do
        pcall(function() self:_removeESP(player) end)
    end
end

function ESP:destroy() self:stop() end

function ESP:setConfig(partial)
    if not partial then return end
    for k, v in pairs(partial) do
        if k == "HB_FIGMA" and type(v) == "table" then
            for kk, vv in pairs(v) do self.config.HB_FIGMA[kk] = vv end
        else
            self.config[k] = v
        end
    end
    if partial.ESPWhitelist or partial.ESPBlacklist
        or partial.ESPFriendColor ~= nil or partial.ESPUseTeamColor ~= nil
    then
        self._nameColors = {}
    end
end

function ESP:isRunning() return self._running end

return ESP
