--[[
    ViewLines + SEI — merged module (Kerenzikov V1.1)
    Player line-of-sight + look-direction visualizer with off-screen
    edge arrows and physical vision cones anchored to the head.

    Vision cones:
      • 2D: two Prism meshes forming a triangular footprint on the ground
      • 3D: Pyramid with apex at the head
      • Optional per-cone Highlight
      • Team colors, inverse hit color, in-house fallback
      • Priority selection by distance (max 8 by default)
      • Optional terrain conform (pitch only)

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
    FOV_DEGREES = 120,
    SAMPLE_PARTS = {
        "Head",
        "UpperTorso", "LowerTorso", "Torso",
        "LeftUpperArm", "RightUpperArm",
        "Left Arm",     "Right Arm",
    },

    VISIBLE_COLOR          = Color3.fromRGB(255, 45, 45),
    BLOCKED_COLOR          = Color3.fromRGB(80, 80, 80),
    VISIBLE_WIDTH          = 0.15,
    BLOCKED_WIDTH          = 0.05,
    HIDE_SIGHT_WHEN_AIMED  = true,
    SIGHT_ALPHA_UNVIEWED   = 0.75,
    SIGHT_ALPHA_VIEWED     = 0.05,

    LOOK_COLOR              = Color3.fromRGB(60, 140, 255),
    LOOK_HIT_COLOR          = Color3.fromRGB(255, 40, 40),
    LOOK_TRANSPARENCY_NEAR  = 0.10,
    LOOK_TRANSPARENCY_FAR   = 0.95,
    LOOK_WIDTH              = 0.18,
    LOOK_RANGE              = 35,
    LOOK_CLAMP_TO_WALL      = true,
    LOOK_HIT_RADIUS         = 1.5,

    LOOK_DOT_ENABLED  = true,
    LOOK_DOT_SIZE     = 0.35,
    LOOK_DOT_ALPHA    = 0.1,

    TEAM_CHECK      = true,
    IGNORE_WATER    = true,
    UPDATE_INTERVAL = 0,
    MAX_DISTANCE    = 0,
    KILL_KEYBIND    = Enum.KeyCode.F10,

    BEAM_OCCLUDE_ENABLED   = true,
    BEAM_OCCLUDE_THRESHOLD = 0.85,
    BEAM_OCCLUDE_MIN_ALPHA = 0.9,

    NAME_MODE                 = "DisplayName",
    NAME_TRUNCATE_USERNAME    = 8,
    NAME_TRUNCATE_DISPLAYNAME = 8,

    EDGE_INDICATORS     = true,
    EDGE_INDICATOR_MODE = "Visible",
    EDGE_PADDING        = 64,
    EDGE_ARROW_SIZE     = 36,

    EDGE_ARROW_COLOR       = Color3.fromRGB(60, 140, 255),
    EDGE_ARROW_ALERT_COLOR = Color3.fromRGB(255, 40, 40),
    EDGE_ARROW_ALPHA       = 0.15,

    EDGE_SHOW_NAME            = true,
    EDGE_NAME_SIZE            = 14,
    EDGE_NAME_SIZE_VIEWED     = 22,
    EDGE_NAME_COLOR           = Color3.fromRGB(255, 255, 255),
    EDGE_NAME_ALPHA           = 0.9,
    EDGE_NAME_ALPHA_VIEWED    = 0.0,
    EDGE_NAME_SIGHT_THRESHOLD = 0.1,

    -- Vision cones
    VISION_CONE_ENABLED        = true,
    VISION_CONE_MODE           = "2D",
    VISION_CONE_MAX_PLAYERS    = 8,
    VISION_CONE_RANGE          = 20,
    VISION_CONE_ACTIVATION_RANGE = 150,

    VISION_CONE_COLOR_MODE     = "Team",
    VISION_CONE_FIXED_COLOR    = Color3.fromRGB(255, 200, 80),
    VISION_CONE_USE_FIXED_HIT  = false,
    VISION_CONE_FIXED_HIT_COLOR = Color3.fromRGB(255, 60, 60),

    VISION_CONE_ALPHA_2D       = 0.7,
    VISION_CONE_ALPHA_3D       = 0.85,
    VISION_CONE_HIT_ALPHA_2D   = 0.4,
    VISION_CONE_HIT_ALPHA_3D   = 0.65,

    VISION_CONE_HIGHLIGHT      = true,
    VISION_CONE_HIGHLIGHT_DEPTH = "Occluded",
    VISION_CONE_GROUND_OFFSET  = 0.15,

    VISION_CONE_CONFORM_TERRAIN = false,
    VISION_CONE_CONFORM_RAYS    = 2,

    VISION_CONE_TILT_FADE      = true,
    VISION_CONE_OCCLUDE_ENABLED = true,
    VISION_CONE_OCCLUDE_THRESHOLD = 0.85,
    VISION_CONE_OCCLUDE_MIN_ALPHA = 0.9,
}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function truncateName(s, maxLen)
    if not maxLen or maxLen <= 0 then return s end
    if #s <= maxLen then return s end
    return s:sub(1, maxLen) .. ".."
end

local function formatPlayerName(player, cfg)
    local mode = cfg.NAME_MODE or "DisplayName"
    local un = truncateName(player.Name,        cfg.NAME_TRUNCATE_USERNAME or 0)
    local dn = truncateName(player.DisplayName, cfg.NAME_TRUNCATE_DISPLAYNAME or 0)
    if mode == "Username" then
        return un
    elseif mode == "Both" then
        return un .. " (" .. dn .. ")"
    else
        return dn
    end
end

local function getTeamColorOf(player)
    if player and player.Team and player.Team.TeamColor
        and player.Team.TeamColor ~= BrickColor.new("Neutral")
    then
        return player.Team.TeamColor.Color
    end
    return nil
end

local function inverseColor(c)
    return Color3.new(1 - c.R, 1 - c.G, 1 - c.B)
end

local function eyeOf(head)
    local look = head.CFrame.LookVector
    return head.Position + look * (head.Size.Z * 0.5), look
end

local function applyBeamOcclusion(cfg, worldA, worldB, baseAlpha)
    if not cfg.BEAM_OCCLUDE_ENABLED then return baseAlpha end
    local cam = workspace.CurrentCamera
    if not cam then return baseAlpha end

    local camPos  = cam.CFrame.Position
    local camLook = cam.CFrame.LookVector
    local facing = 0

    if worldA then
        local toA = worldA - camPos
        local dA = toA.Magnitude
        if dA > 1e-3 then facing = math.max(facing, camLook:Dot(toA / dA)) end
    end
    if worldA and worldB then
        local mid = (worldA + worldB) * 0.5
        local toMid = mid - camPos
        local dM = toMid.Magnitude
        if dM > 1e-3 then facing = math.max(facing, camLook:Dot(toMid / dM)) end
    end

    local thresh = cfg.BEAM_OCCLUDE_THRESHOLD or 0.85
    if facing <= thresh then return baseAlpha end

    local factor = (facing - thresh) / math.max(1 - thresh, 1e-3)
    local minA = cfg.BEAM_OCCLUDE_MIN_ALPHA or 0.9
    return clamp(baseAlpha + (minA - baseAlpha) * factor, 0, 1)
end

--------------------------------------------------------------------------------
-- SEI (unchanged from V1.1)
--------------------------------------------------------------------------------
local ScreenEdgeIndicators = {}
ScreenEdgeIndicators.__index = ScreenEdgeIndicators

function ScreenEdgeIndicators.new(overrides)
    local self = setmetatable({}, ScreenEdgeIndicators)
    self.config = {
        PADDING = 64, ARROW_SIZE = 36,
        ARROW_COLOR = Color3.fromRGB(60, 140, 255), ARROW_ALPHA = 0.15,
        SHOW_NAME = true, NAME_SIZE = 14, NAME_SIZE_VIEWED = 22,
        NAME_COLOR = Color3.fromRGB(255, 255, 255),
        NAME_ALPHA = 0.9, NAME_ALPHA_VIEWED = 0.0,
        NAME_MODE = "DisplayName",
        NAME_TRUNCATE_USERNAME = 8, NAME_TRUNCATE_DISPLAYNAME = 8,
        UPDATE_INTERVAL = 0, KILL_KEYBIND = nil,
    }
    if overrides then for k, v in pairs(overrides) do self.config[k] = v end end

    self._targets = {}
    self._connections = {}
    self._running = false
    self._lastUpdate = 0

    local gui = Instance.new("ScreenGui")
    gui.Name = "ScreenEdgeIndicators"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    self._gui = gui

    return self
end

function ScreenEdgeIndicators:_track(conn)
    self._connections[#self._connections + 1] = conn
    return conn
end

function ScreenEdgeIndicators:_buildArrow(cfg)
    local frame = Instance.new("Frame")
    frame.Name = "ArrowRoot"
    frame.Size = UDim2.fromOffset(self.config.ARROW_SIZE, self.config.ARROW_SIZE)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Parent = self._gui

    local arrow = Instance.new("ImageLabel")
    arrow.Name = "Arrow"
    arrow.Size = UDim2.fromScale(1, 1)
    arrow.BackgroundTransparency = 1
    arrow.Image = "rbxassetid://5052874450"
    arrow.ImageColor3 = cfg.Color or self.config.ARROW_COLOR
    arrow.ImageTransparency = cfg.Alpha or self.config.ARROW_ALPHA
    arrow.Rotation = 0
    arrow.Parent = frame

    local label
    if self.config.SHOW_NAME then
        label = Instance.new("TextLabel")
        label.Name = "Name"
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 1, 4)
        label.Size = UDim2.fromOffset(120, self.config.NAME_SIZE + 6)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextSize = self.config.NAME_SIZE
        label.TextColor3 = self.config.NAME_COLOR
        label.TextTransparency = self.config.NAME_ALPHA
        label.Text = ""
        label.Parent = frame
    end
    return frame, arrow, label
end

function ScreenEdgeIndicators:_destroyTarget(player)
    local entry = self._targets[player]
    if not entry then return end
    if entry.frame then pcall(function() entry.frame:Destroy() end) end
    self._targets[player] = nil
end

function ScreenEdgeIndicators:addTarget(player, opts)
    if player == LocalPlayer then return end
    opts = opts or {}

    local existing = self._targets[player]
    if existing then
        existing.viewing = opts.Viewing and true or false
        existing.aiming = opts.Aiming and true or false
        existing.nameColor = opts.NameColor or existing.nameColor
        if opts.Color then existing.color = opts.Color end
        if opts.Alpha then existing.alpha = opts.Alpha end
        return
    end

    local frame, arrow, label = self:_buildArrow(opts)
    self._targets[player] = {
        frame = frame, arrow = arrow, label = label,
        color = opts.Color or self.config.ARROW_COLOR,
        alpha = opts.Alpha or self.config.ARROW_ALPHA,
        nameColor = opts.NameColor or self.config.NAME_COLOR,
        viewing = opts.Viewing and true or false,
        aiming = opts.Aiming and true or false,
    }
end

function ScreenEdgeIndicators:removeTarget(player) self:_destroyTarget(player) end
function ScreenEdgeIndicators:clearTargets()
    local list = {}
    for p in pairs(self._targets) do list[#list + 1] = p end
    for _, p in ipairs(list) do self:_destroyTarget(p) end
end

function ScreenEdgeIndicators:update()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local viewport = cam.ViewportSize
    if viewport.X <= 0 or viewport.Y <= 0 then return end

    local pad = self.config.PADDING
    local halfX = viewport.X * 0.5
    local halfY = viewport.Y * 0.5

    for player, entry in pairs(self._targets) do
        local char = player.Character
        local anchor
        if char then
            anchor = char:FindFirstChild("HumanoidRootPart")
                  or char:FindFirstChild("Head")
        end

        if not anchor then
            entry.frame.Visible = false
        else
            local screenPos, onScreen = cam:WorldToViewportPoint(anchor.Position)
            local camSpace = cam.CFrame:PointToObjectSpace(anchor.Position)
            local behind = camSpace.Z >= 0
            local isOffscreen = (not onScreen) or behind

            local clampedX = math.clamp(screenPos.X, pad, viewport.X - pad)
            local clampedY = math.clamp(screenPos.Y, pad, viewport.Y - pad)
            local atEdge = (clampedX ~= screenPos.X) or (clampedY ~= screenPos.Y)

            if isOffscreen or
