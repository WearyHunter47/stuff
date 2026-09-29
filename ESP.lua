--[[
    ESP Module — standalone, bus-aware, with healthbar + format modes

    Reads ViewLines state from getgenv().ModuleBus.ViewLines to drive:
      • Highlight fill transparency (base → sight → look)
      • Nametag opacity      (base → sight → look)
      • Nametag size         (base → sight → look)
      • Nametag bolding      (look beam only)
      • Camera-center override opacity
      • Healthbar fill, optional number tacked on

    Usage:
        local ESP = loadstring(game:HttpGet(URL))()
        local esp = ESP.new({ ... })
        esp:start()
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
    -- Existing ESP
    ESPEnabled          = true,
    ESPShowText         = true,
    ESPTextSize         = 13,
    ESPMaxDistance      = 500,
    ESPUseDistanceLimit = true,
    ESPUseTeamColor     = true,
    ESPFriendColor      = true,

    ESPWhitelist = {},
    ESPBlacklist = {},

    -- Nametag format
    ESP_NAME_FORMAT = "Horizontal",   -- "Horizontal" | "Vertical"

    -- ViewLines integration
    INTEGRATION_ENABLED = true,

    -- Highlight fill transparency by state
    HL_BASE_TRANSPARENCY  = 0.7,
    HL_SIGHT_TRANSPARENCY = 0.4,
    HL_LOOK_TRANSPARENCY  = 0.1,

    -- Nametag opacity
    NT_ALPHA_BASE  = 0.6,
    NT_ALPHA_SIGHT = 0.3,
    NT_ALPHA_LOOK  = 0.0,

    -- Nametag size
    NT_SIZE_BASE  = 13,
    NT_SIZE_SIGHT = 16,
    NT_SIZE_LOOK  = 20,

    -- Bold on look
    NT_BOLD_ON_LOOK = true,

    -- Camera-center proximity
    CENTER_OVERRIDE_ENABLED = true,
    CENTER_FALLOFF_DEGREES  = 45,
    CENTER_MAX_ALPHA        = 0.0,

    -- Sight beam threshold for "detected"
    SIGHT_THRESHOLD = 0.1,

    -- Healthbar
    HB_ENABLED          = true,
    HB_POSITION         = "Bottom",   -- "Top" | "Bottom" | "Left" | "Right"
    HB_LENGTH           = 120,        -- pixels along the long axis
    HB_THICKNESS        = 6,          -- pixels along the short axis
    HB_GAP              = 4,          -- pixels between nametag and bar
    HB_BG_COLOR         = Color3.fromRGB(20, 20, 20),
    HB_BG_TRANSPARENCY  = 0.2,
    HB_FILL_COLOR       = nil,        -- nil = auto health gradient (green→red)
    HB_FILL_TRANSPARENCY = 0.0,
    HB_ROUNDED          = true,
    HB_CORNER_RADIUS    = 3,
    HB_BORDER           = true,
    HB_BORDER_COLOR     = Color3.fromRGB(0, 0, 0),
    HB_BORDER_THICKNESS = 1,

    -- Healthbar number
    HB_SHOW_NUMBER       = false,
    HB_NUMBER_POSITION   = "Inside",  -- "Inside" | "Left" | "Right" | "Above" | "Below"
    HB_NUMBER_SIZE       = 12,
    HB_NUMBER_COLOR      = Color3.fromRGB(255, 255, 255),
    HB_NUMBER_ALPHA      = 0.0,
    HB_NUMBER_SHOW_MAX   = false,     -- "75" vs "75/100"

    -- Kill keybind (nil = disabled, master owns it)
    KILL_KEYBIND = nil,
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
        for k, v in pairs(overrides) do self.config[k] = v end
    end

    self._objects     = {}
    self._nameColors  = {}
    self._connections = {}
    self._running     = false
    self._lastUpdate  = 0
    self._espVisible  = true
    self._textVisible = true

    return self
end

--------------------------------------------------------------------------------
-- INTERNALS
--------------------------------------------------------------------------------
function ESP:_track(conn)
    self._connections[#self._connections + 1] = conn
    return conn
end

function ESP:_typing()
    return UserInputService:GetFocusedTextBox() ~= nil
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

-- Compute the BillboardGui and element layout sizes for this frame.
function ESP:_computeLayout()
    local cfg = self.config
    local ntSize = self._activeNtSize or cfg.NT_SIZE_BASE

    local nameH = ntSize + 6
    local subH  = (cfg.ESP_NAME_FORMAT == "Vertical") and (ntSize + 4) or 0
    local textH = nameH + subH
    local textW = 220

    local hb = {
        enabled = cfg.HB_ENABLED,
        pos     = cfg.HB_POSITION,
        len     = cfg.HB_LENGTH,
        thick   = cfg.HB_THICKNESS,
        gap     = cfg.HB_GAP,
    }

    local bbW, bbH
    if not hb.enabled then
        bbW, bbH = textW, textH
    elseif hb.pos == "Top" or hb.pos == "Bottom" then
        bbW = math.max(textW, hb.len)
        bbH = textH + hb.thick + hb.gap
    else -- Left or Right
        bbW = textW + hb.thick + hb.gap
        bbH = math.max(textH, hb.len)
    end

    return bbW, bbH, textW, textH, nameH, subH, hb
end

function ESP:_createESP(player)
    if self._objects[player] then return self._objects[player] end

    local cfg = self.config

    local highlight = Instance.new("Highlight")
    highlight.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency   = cfg.HL_BASE_TRANSPARENCY
    highlight.OutlineTransparency = 0
    highlight.Enabled            = true
    highlight.Parent             = CoreGui

    local billboard = Instance.new("BillboardGui")
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Size        = UDim2.fromOffset(220, 60)

    -- Name label
    local nameLabel = Instance.new("TextLabel")
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

    -- Sub label (Vertical mode only)
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

    -- Healthbar background
    local hbBack = Instance.new("Frame")
    hbBack.BackgroundColor3      = cfg.HB_BG_COLOR
    hbBack.BackgroundTransparency = cfg.HB_BG_TRANSPARENCY
    hbBack.BorderSizePixel       = 0
    hbBack.Visible               = cfg.HB_ENABLED
    hbBack.Parent                = billboard

    if cfg.HB_BORDER then
        local stroke = Instance.new("UIStroke")
        stroke.Color        = cfg.HB_BORDER_COLOR
        stroke.Thickness    = cfg.HB_BORDER_THICKNESS
        stroke.Transparency = 0
        stroke.Parent       = hbBack
    end

    if cfg.HB_ROUNDED then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cfg.HB_CORNER_RADIUS)
        corner.Parent = hbBack
    end

    -- Healthbar fill
    local hbFill = Instance.new("Frame")
    hbFill.BackgroundColor3      = Color3.fromRGB(0, 255, 0)
    hbFill.BackgroundTransparency = cfg.HB_FILL_TRANSPARENCY
    hbFill.BorderSizePixel       = 0
    hbFill.Size                  = UDim2.fromScale(1, 1)
    hbFill.Parent                = hbBack

    if cfg.HB_ROUNDED then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cfg.HB_CORNER_RADIUS)
        corner.Parent = hbFill
    end

    -- Healthbar number
    local hbNumber
    if cfg.HB_SHOW_NUMBER then
        hbNumber = Instance.new("TextLabel")
        hbNumber.BackgroundTransparency = 1
        hbNumber.Font                   = Enum.Font.GothamBold
        hbNumber.TextScaled             = false
        hbNumber.TextSize               = cfg.HB_NUMBER_SIZE
        hbNumber.TextColor3             = cfg.HB_NUMBER_COLOR
        hbNumber.TextTransparency       = cfg.HB_NUMBER_ALPHA
        hbNumber.TextStrokeTransparency = 0
        hbNumber.Text                   = ""
        hbNumber.Parent                 = billboard
    end

    self._objects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        SubLabel  = subLabel,
        HB_Back   = hbBack,
        HB_Fill   = hbFill,
        HB_Number = hbNumber,
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

function ESP:_getViewLinesState(player)
    local bus = getgenv().ModuleBus
    if not bus or not bus.ViewLines or not bus.ViewLines.Active then
        return false, 0
    end
    local hit = bus.ViewLines.Hit[player] == true
    local vis = bus.ViewLines.Visibility[player] or 0
    return hit, vis
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

-- Position the nametag, sub-label, and healthbar inside the BillboardGui
-- based on the current format + healthbar position. Called every frame
-- because the layout sizes can change with the size boost.
function ESP:_layout(obj, bbW, bbH, textW, textH, nameH, subH, hb)
    local cfg = self.config

    obj.Billboard.Size = UDim2.fromOffset(bbW, bbH)

    local textX, textY
    local hbX, hbY, hbW, hbH

    if not hb.enabled then
        textX = (bbW - textW) * 0.5
        textY = 0
    elseif hb.pos == "Top" then
        hbX = (bbW - hb.len) * 0.5
        hbY = 0
        hbW = hb.len
        hbH = hb.thick

        textX = (bbW - textW) * 0.5
        textY = hb.thick + hb.gap
    elseif hb.pos == "Bottom" then
        textX = (bbW - textW) * 0.5
        textY = 0

        hbX = (bbW - hb.len) * 0.5
        hbY = textH + hb.gap
        hbW = hb.len
        hbH = hb.thick
    elseif hb.pos == "Left" then
        hbX = 0
        hbY = (bbH - hb.len) * 0.5
        hbW = hb.thick
        hbH = hb.len

        textX = hb.thick + hb.gap
        textY = (bbH - textH) * 0.5
    else -- Right
        textX = 0
        textY = (bbH - textH) * 0.5

        hbX = textW + hb.gap
        hbY = (bbH - hb.len) * 0.5
        hbW = hb.thick
        hbH = hb.len
    end

    -- Nametag
    obj.NameLabel.Position = UDim2.fromOffset(textX, textY)
    obj.NameLabel.Size     = UDim2.new(0, textW, 0, nameH)

    -- Sub-label (only Vertical format)
    obj.SubLabel.Position = UDim2.fromOffset(textX, textY + nameH)
    obj.SubLabel.Size     = UDim2.new(0, textW, 0, subH)
    obj.SubLabel.Visible  = (cfg.ESP_NAME_FORMAT == "Vertical")

    -- Healthbar
    if hb.enabled then
        obj.HB_Back.Visible = true
        obj.HB_Back.Position = UDim2.fromOffset(hbX, hbY)
        obj.HB_Back.Size     = UDim2.fromOffset(hbW, hbH)
    else
        obj.HB_Back.Visible = false
    end
end

-- Update the fill, color, and optional number
function ESP:_updateHealthbar(obj, hp, maxHp)
    local cfg = self.config
    if not cfg.HB_ENABLED then return end

    local pct = math.clamp(hp / math.max(maxHp, 1), 0, 1)
    local isHorizontal = (cfg.HB_POSITION == "Top" or cfg.HB_POSITION == "Bottom")

    -- Fill size
    if isHorizontal then
        obj.HB_Fill.Size = UDim2.fromScale(pct, 1)
        obj.HB_Fill.AnchorPoint = Vector2.new(0, 0)
        obj.HB_Fill.Position = UDim2.fromScale(0, 0)
    else
        obj.HB_Fill.Size = UDim2.fromScale(1, pct)
        obj.HB_Fill.AnchorPoint = Vector2.new(0, 1)
        obj.HB_Fill.Position = UDim2.fromScale(0, 1)
    end

    -- Fill color
    if cfg.HB_FILL_COLOR then
        obj.HB_Fill.BackgroundColor3 = cfg.HB_FILL_COLOR
    else
        obj.HB_Fill.BackgroundColor3 = Color3.fromRGB(
            255 * (1 - pct),
            255 * pct,
            0
        )
    end

    -- Optional number
    if obj.HB_Number then
        if cfg.HB_NUMBER_SHOW_MAX then
            obj.HB_Number.Text = string.format("%d/%d", math.floor(hp), math.floor(maxHp))
        else
            obj.HB_Number.Text = tostring(math.floor(hp))
        end

        local numW = 80
        local numH = cfg.HB_NUMBER_SIZE + 4
        local hbBack = obj.HB_Back

        if cfg.HB_NUMBER_POSITION == "Inside" then
            obj.HB_Number.Size     = hbBack.Size
            obj.HB_Number.Position = hbBack.Position
        elseif cfg.HB_NUMBER_POSITION == "Above" then
            obj.HB_Number.Size     = UDim2.fromOffset(numW, numH)
            obj.HB_Number.Position = UDim2.fromOffset(
                hbBack.Position.X.Offset + (hbBack.Size.X.Offset - numW) * 0.5,
                hbBack.Position.Y.Offset - numH - 2
            )
        elseif cfg.HB_NUMBER_POSITION == "Below" then
            obj.HB_Number.Size     = UDim2.fromOffset(numW, numH)
            obj.HB_Number.Position = UDim2.fromOffset(
                hbBack.Position.X.Offset + (hbBack.Size.X.Offset - numW) * 0.5,
                hbBack.Position.Y.Offset + hbBack.Size.Y.Offset + 2
            )
        elseif cfg.HB_NUMBER_POSITION == "Left" then
            obj.HB_Number.Size     = UDim2.fromOffset(numW, numH)
            obj.HB_Number.Position = UDim2.fromOffset(
                hbBack.Position.X.Offset - numW - 4,
                hbBack.Position.Y.Offset + (hbBack.Size.Y.Offset - numH) * 0.5
            )
        elseif cfg.HB_NUMBER_POSITION == "Right" then
            obj.HB_Number.Size     = UDim2.fromOffset(numW, numH)
            obj.HB_Number.Position = UDim2.fromOffset(
                hbBack.Position.X.Offset + hbBack.Size.X.Offset + 4,
                hbBack.Position.Y.Offset + (hbBack.Size.Y.Offset - numH) * 0.5
            )
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

                -- ViewLines state
                local hit, vis = self:_getViewLinesState(player)
                local sightSeen = cfg.INTEGRATION_ENABLED
                    and vis >= cfg.SIGHT_THRESHOLD

                -- Highlight fill transparency
                local fillT
                if cfg.INTEGRATION_ENABLED then
                    if hit then
                        fillT = cfg.HL_LOOK_TRANSPARENCY
                    elseif sightSeen then
                        fillT = cfg.HL_SIGHT_TRANSPARENCY
                    else
                        fillT = cfg.HL_BASE_TRANSPARENCY
                    end
                else
                    fillT = cfg.HL_BASE_TRANSPARENCY
                end

                -- Nametag opacity
                local ntAlpha
                if cfg.INTEGRATION_ENABLED then
                    if hit then
                        ntAlpha = cfg.NT_ALPHA_LOOK
                    elseif sightSeen then
                        ntAlpha = cfg.NT_ALPHA_SIGHT
                    else
                        ntAlpha = cfg.NT_ALPHA_BASE
                    end
                else
                    ntAlpha = cfg.NT_ALPHA_BASE
                end

                -- Camera-center override
                if cfg.CENTER_OVERRIDE_ENABLED then
                    local cf = self:_centerFactor(root.Position)
                    if cf > 0 then
                        local centerAlpha = cfg.CENTER_MAX_ALPHA
                            + (1 - cfg.CENTER_MAX_ALPHA) * (1 - cf)
                        ntAlpha = math.min(ntAlpha, centerAlpha)
                    end
                end

                -- Nametag size
                local ntSize
                if cfg.INTEGRATION_ENABLED then
                    if hit then
                        ntSize = cfg.NT_SIZE_LOOK
                    elseif sightSeen then
                        ntSize = cfg.NT_SIZE_SIGHT
                    else
                        ntSize = cfg.NT_SIZE_BASE
                    end
                else
                    ntSize = cfg.NT_SIZE_BASE
                end
                self._activeNtSize = ntSize

                -- Nametag bold
                local ntFont = Enum.Font.GothamMedium
                if cfg.INTEGRATION_ENABLED and cfg.NT_BOLD_ON_LOOK and hit then
                    ntFont = Enum.Font.GothamBold
                end

                -- Health
                local hp    = math.floor(self:_getHealth(char))
                local maxHp = self:_getMaxHealth(char)

                local nameColor = self:_getNameColor(player)
                local hpColor   = healthColor(hp)
                local distColor = distanceColor(dist)

                -- Layout
                local bbW, bbH, textW, textH, nameH, subH, hb = self:_computeLayout()
                self:_layout(obj, bbW, bbH, textW, textH, nameH, subH, hb)

                -- Apply highlight
                if self._espVisible and withinRange then
                    obj.Highlight.Adornee          = char
                    obj.Highlight.Enabled          = true
                    obj.Highlight.FillColor        = nameColor
                    obj.Highlight.OutlineColor     = nameColor
                    obj.Highlight.FillTransparency = fillT
                else
                    obj.Highlight.Enabled = false
                    obj.Highlight.Adornee = nil
                end

                -- Apply text
                if self._textVisible and cfg.ESPShowText then
                    obj.Billboard.Parent = root
                    obj.Billboard.Enabled = true

                    obj.NameLabel.TextSize         = ntSize
                    obj.NameLabel.Font             = ntFont
                    obj.NameLabel.TextColor3       = nameColor
                    obj.NameLabel.TextTransparency = ntAlpha

                    obj.SubLabel.TextSize         = ntSize
                    obj.SubLabel.Font             = ntFont
                    obj.SubLabel.TextColor3       = nameColor
                    obj.SubLabel.TextTransparency = ntAlpha

                    if cfg.ESP_NAME_FORMAT == "Vertical" then
                        obj.NameLabel.Text = player.DisplayName
                        obj.SubLabel.Text  = string.format(
                            '<font color="%s">%d</font> | <font color="%s">%d</font>',
                            rgb(hpColor), hp, rgb(distColor), dist
                        )
                    else
                        obj.NameLabel.Text = string.format(
                            '<font color="%s">%s</font> | <font color="%s">%d</font> | <font color="%s">%d</font>',
                            rgb(nameColor), player.DisplayName,
                            rgb(hpColor), hp,
                            rgb(distColor), dist
                        )
                        obj.SubLabel.Text = ""
                    end

                    self:_updateHealthbar(obj, hp, maxHp)
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

    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}

    for player in pairs(self._objects) do
        self:_removeESP(player)
    end
end

function ESP:destroy()
    self:stop()
end

function ESP:setConfig(partial)
    if not partial then return end
    for k, v in pairs(partial) do
        self.config[k] = v
    end
    if partial.ESPWhitelist or partial.ESPBlacklist
        or partial.ESPFriendColor ~= nil or partial.ESPUseTeamColor ~= nil
    then
        self._nameColors = {}
    end
end

function ESP:isRunning()
    return self._running
end

return ESP
