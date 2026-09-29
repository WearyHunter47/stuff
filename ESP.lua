--[[
    ESP Module — standalone, bus-aware

    Reads ViewLines state from getgenv().ModuleBus.ViewLines to drive:
      • Highlight fill transparency (base → sight → look)
      • Nametag opacity      (base → sight → look)
      • Nametag size         (base → sight → look)
      • Nametag bolding      (look beam only)
      • Camera-center override opacity

    Usage:
        local ESP = loadstring(game:HttpGet(URL))()
        local esp = ESP.new({ ... })
        esp:start()

    Or drive manually:
        esp:update()
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

    self._objects     = {}   -- [Player] = { Highlight, Billboard, Label }
    self._nameColors  = {}   -- [Player] = Color3 (cached)
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

function ESP:_getNameColor(player)
    -- Cached: recompute only when whitelist/blacklist/friendship changes
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

function ESP:_createESP(player)
    if self._objects[player] then return self._objects[player] end

    local highlight = Instance.new("Highlight")
    highlight.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency   = self.config.HL_BASE_TRANSPARENCY
    highlight.OutlineTransparency = 0
    highlight.Enabled            = true
    highlight.Parent             = CoreGui

    local billboard = Instance.new("BillboardGui")
    billboard.Size        = UDim2.new(0, 220, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.Font                   = Enum.Font.Code
    label.TextScaled             = false
    label.RichText               = true
    label.TextStrokeTransparency = 0
    label.TextColor3             = Color3.new(1, 1, 1)
    label.Parent                 = billboard

    self._objects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        Label     = label,
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

-- Read ViewLines state from the shared bus
function ESP:_getViewLinesState(player)
    local bus = getgenv().ModuleBus
    if not bus or not bus.ViewLines or not bus.ViewLines.Active then
        return false, 0
    end
    local hit = bus.ViewLines.Hit[player] == true
    local vis = bus.ViewLines.Visibility[player] or 0
    return hit, vis
end

-- Camera-center factor: 1 at center, 0 beyond CENTER_FALLOFF_DEGREES
function ESP:_centerFactor(worldPos)
    local cam = workspace.CurrentCamera
    if not cam then return 0 end
    local toTarget = (worldPos - cam.CFrame.Position)
    if toTarget.Magnitude < 1e-4 then return 0 end
    toTarget = toTarget.Unit
    local look = cam.CFrame.LookVector
    local dot  = look:Dot(toTarget)                -- 1 = center, -1 = behind
    local cosFalloff = math.cos(math.rad(self.config.CENTER_FALLOFF_DEGREES))
    if dot <= cosFalloff then return 0 end
    -- Normalize dot from [cosFalloff, 1] to [0, 1]
    return (dot - cosFalloff) / (1 - cosFalloff)
end

--------------------------------------------------------------------------------
-- PUBLIC: update
--------------------------------------------------------------------------------
function ESP:update()
    local cfg = self.config

    -- Master off switch
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

                -- ─── ViewLines state ───────────────────────────────────────
                local hit, vis = self:_getViewLinesState(player)
                local sightSeen = cfg.INTEGRATION_ENABLED
                    and vis >= cfg.SIGHT_THRESHOLD

                -- ─── Highlight fill transparency ──────────────────────────
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

                -- ─── Nametag opacity (start with ViewLines state) ─────────
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

                -- ─── Camera-center override ───────────────────────────────
                -- If the player is near the screen center, they become
                -- more opaque proportionally, overriding the ViewLines
                -- opacity. Final = MIN (more opaque wins).
                if cfg.CENTER_OVERRIDE_ENABLED then
                    local cf = self:_centerFactor(root.Position)
                    if cf > 0 then
                        local centerAlpha = cfg.CENTER_MAX_ALPHA
                            + (1 - cfg.CENTER_MAX_ALPHA) * (1 - cf)
                        -- Lower transparency value = more opaque
                        ntAlpha = math.min(ntAlpha, centerAlpha)
                    end
                end

                -- ─── Nametag size ─────────────────────────────────────────
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

                -- ─── Nametag bold ─────────────────────────────────────────
                local ntFont = Enum.Font.Code
                if cfg.INTEGRATION_ENABLED and cfg.NT_BOLD_ON_LOOK and hit then
                    ntFont = Enum.Font.Code -- Code has no bold; use GothamBold
                    ntFont = Enum.Font.GothamBold
                end

                -- ─── Apply highlight ──────────────────────────────────────
                local nameColor = self:_getNameColor(player)

                if self._espVisible and withinRange then
                    obj.Highlight.Adornee           = char
                    obj.Highlight.Enabled           = true
                    obj.Highlight.FillColor         = nameColor
                    obj.Highlight.OutlineColor      = nameColor
                    obj.Highlight.FillTransparency  = fillT
                else
                    obj.Highlight.Enabled = false
                    obj.Highlight.Adornee = nil
                end

                -- ─── Apply nametag ────────────────────────────────────────
                if self._textVisible and cfg.ESPShowText then
                    obj.Billboard.Parent = root

                    local hp       = math.floor(self:_getHealth(char))
                    local hpColor  = healthColor(hp)
                    local distCol  = distanceColor(dist)

                    obj.Label.TextSize       = ntSize
                    obj.Label.Font           = ntFont
                    obj.Label.TextTransparency = ntAlpha

                    obj.Label.Text = string.format(
                        '<font color="%s">%s</font> | <font color="%s">%d</font> | <font color="%s">%d</font>',
                        rgb(nameColor),
                        player.DisplayName,
                        rgb(hpColor),
                        hp,
                        rgb(distCol),
                        dist
                    )
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
    -- Invalidate cached name colors when whitelist/blacklist change
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
