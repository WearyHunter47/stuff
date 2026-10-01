--[[
    ViewLines + SEI — merged module (Kerenzikov V1.1)
    Player line-of-sight + look-direction visualizer with off-screen
    edge arrows and physical vision cones anchored to the head.

    Vision cones:
      • 2D: mirrored WedgeParts forming a triangle on the ground
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

    -- Sight beam
    VISIBLE_COLOR          = Color3.fromRGB(255, 45, 45),
    BLOCKED_COLOR          = Color3.fromRGB(80, 80, 80),
    VISIBLE_WIDTH          = 0.15,
    BLOCKED_WIDTH          = 0.05,
    HIDE_SIGHT_WHEN_AIMED  = true,
    SIGHT_ALPHA_UNVIEWED   = 0.75,
    SIGHT_ALPHA_VIEWED     = 0.05,

    -- Look beam
    LOOK_COLOR              = Color3.fromRGB(60, 140, 255),
    LOOK_HIT_COLOR          = Color3.fromRGB(255, 40, 40),
    LOOK_TRANSPARENCY_NEAR  = 0.10,
    LOOK_TRANSPARENCY_FAR   = 0.95,
    LOOK_WIDTH              = 0.18,
    LOOK_RANGE              = 35,
    LOOK_CLAMP_TO_WALL      = true,
    LOOK_HIT_RADIUS         = 1.5,

    -- Sniper dot
    LOOK_DOT_ENABLED  = true,
    LOOK_DOT_SIZE     = 0.35,
    LOOK_DOT_ALPHA    = 0.1,

    -- Filters
    TEAM_CHECK      = true,
    IGNORE_WATER    = true,
    UPDATE_INTERVAL = 0,
    MAX_DISTANCE    = 0,
    KILL_KEYBIND    = Enum.KeyCode.F10,

    -- Beam occlusion
    BEAM_OCCLUDE_ENABLED   = true,
    BEAM_OCCLUDE_THRESHOLD = 0.85,
    BEAM_OCCLUDE_MIN_ALPHA = 0.9,

    -- Name formatting
    NAME_MODE                 = "DisplayName",
    NAME_TRUNCATE_USERNAME    = 8,
    NAME_TRUNCATE_DISPLAYNAME = 8,

    -- SEI
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

    -- ─── Vision cones ──────────────────────────────────────────────────
    VISION_CONE_ENABLED        = true,
    VISION_CONE_MODE           = "2D",        -- "2D" | "3D" | "Both"
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
-- SEI
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

            if isOffscreen or atEdge then
                entry.frame.Visible = true

                local toTarget = anchor.Position - cam.CFrame.Position
                local obj = cam.CFrame:VectorToObjectSpace(toTarget)
                local dir2D = Vector2.new(obj.X, obj.Y)
                if dir2D.Magnitude < 1e-4 then dir2D = Vector2.new(0, 1) end
                dir2D = dir2D.Unit

                local tX = halfX / math.max(math.abs(dir2D.X), 1e-4)
                local tY = halfY / math.max(math.abs(dir2D.Y), 1e-4)
                local t = math.min(tX, tY)

                local edgeX = halfX + dir2D.X * t
                local edgeY = halfY - dir2D.Y * t
                edgeX = math.clamp(edgeX, pad, viewport.X - pad)
                edgeY = math.clamp(edgeY, pad, viewport.Y - pad)

                entry.frame.Position = UDim2.fromOffset(edgeX, edgeY)
                entry.arrow.Rotation = math.deg(math.atan2(dir2D.X, dir2D.Y))

                entry.arrow.ImageColor3 = entry.color
                entry.arrow.ImageTransparency = entry.alpha

                if entry.label then
                    entry.label.Text = formatPlayerName(player, self.config)
                    entry.label.TextColor3 = entry.nameColor
                    entry.label.TextTransparency = entry.viewing
                        and self.config.NAME_ALPHA_VIEWED
                        or self.config.NAME_ALPHA

                    local nameSize = entry.aiming
                        and self.config.NAME_SIZE_VIEWED
                        or self.config.NAME_SIZE
                    entry.label.TextSize = nameSize
                    entry.label.Size = UDim2.fromOffset(120, nameSize + 6)
                end
            else
                entry.frame.Visible = false
            end
        end
    end
end

function ScreenEdgeIndicators:stop()
    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}
    self:clearTargets()
    if self._gui then
        pcall(function() self._gui:Destroy() end)
        self._gui = nil
    end
    self._running = false
end

--------------------------------------------------------------------------------
-- ViewLines
--------------------------------------------------------------------------------
local ViewLines = {}
ViewLines.__index = ViewLines

function ViewLines.new(overrides)
    local self = setmetatable({}, ViewLines)
    self.config = {}
    for k, v in pairs(DEFAULTS) do self.config[k] = v end
    if overrides then
        for k, v in pairs(overrides) do self.config[k] = v end
    end

    self._entries     = {}
    self._visionCones = {}
    self._connections = {}
    self._running     = false
    self._lastUpdate  = 0

    self._edgeIndicators = ScreenEdgeIndicators.new({
        PADDING = self.config.EDGE_PADDING,
        ARROW_SIZE = self.config.EDGE_ARROW_SIZE,
        ARROW_COLOR = self.config.EDGE_ARROW_COLOR,
        ARROW_ALPHA = self.config.EDGE_ARROW_ALPHA,
        SHOW_NAME = self.config.EDGE_SHOW_NAME,
        NAME_SIZE = self.config.EDGE_NAME_SIZE,
        NAME_SIZE_VIEWED = self.config.EDGE_NAME_SIZE_VIEWED,
        NAME_COLOR = self.config.EDGE_NAME_COLOR,
        NAME_ALPHA = self.config.EDGE_NAME_ALPHA,
        NAME_ALPHA_VIEWED = self.config.EDGE_NAME_ALPHA_VIEWED,
        NAME_MODE = self.config.NAME_MODE,
        NAME_TRUNCATE_USERNAME = self.config.NAME_TRUNCATE_USERNAME,
        NAME_TRUNCATE_DISPLAYNAME = self.config.NAME_TRUNCATE_DISPLAYNAME,
        UPDATE_INTERVAL = 0,
        KILL_KEYBIND = nil,
    })

    return self
end

function ViewLines:_track(conn)
    self._connections[#self._connections + 1] = conn
    return conn
end

function ViewLines:_rayParams(ignoreChar)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = { ignoreChar, Camera }
    p.IgnoreWater = self.config.IGNORE_WATER
    return p
end

function ViewLines:_isHostile(player)
    if player == LocalPlayer then return false end
    if self.config.TEAM_CHECK
        and player.Team and LocalPlayer.Team
        and player.Team == LocalPlayer.Team
    then
        return false
    end
    return true
end

function ViewLines:_getSamplePoints(char)
    local pts = {}
    for _, name in ipairs(self.config.SAMPLE_PARTS) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            pts[#pts + 1] = {
                pos = part.Position,
                radius = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5,
            }
        end
    end
    if #pts == 0 then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then pts[1] = { pos = root.Position, radius = 1.5 } end
    end
    return pts
end

function ViewLines:_publishToBus(player, hit, vis)
    local bus = getgenv().ModuleBus
    if not bus or not bus.ViewLines then return end
    if not bus.ViewLines.Hit then bus.ViewLines.Hit = {} end
    if not bus.ViewLines.Visibility then bus.ViewLines.Visibility = {} end
    bus.ViewLines.Hit[player] = hit
    bus.ViewLines.Visibility[player] = vis
end

function ViewLines:_publishClear(player)
    local bus = getgenv().ModuleBus
    if not bus or not bus.ViewLines then return end
    if bus.ViewLines.Hit then bus.ViewLines.Hit[player] = nil end
    if bus.ViewLines.Visibility then bus.ViewLines.Visibility[player] = nil end
end

function ViewLines:_publishClearAll()
    local bus = getgenv().ModuleBus
    if not bus or not bus.ViewLines then return end
    bus.ViewLines.Hit = {}
    bus.ViewLines.Visibility = {}
end

--------------------------------------------------------------------------------
-- VISION CONES
--------------------------------------------------------------------------------
function ViewLines:_destroyVisionCone(player)
    local vc = self._visionCones[player]
    if not vc then return end
    for _, obj in ipairs({
        vc.model, vc.highlight,
        vc.wedge2DLeft, vc.wedge2DRight,
        vc.part3D, vc.mesh3D,
    }) do
        if obj then pcall(function() obj:Destroy() end) end
    end
    self._visionCones[player] = nil
end

function ViewLines:_createVisionCone(player)
    if self._visionCones[player] then return self._visionCones[player] end
    local cfg = self.config
    local vc = {}

    local model = Instance.new("Model")
    model.Name = "VisionCone_" .. player.Name
    model.Parent = workspace
    vc.model = model

    -- ─── 2D: mirrored WedgeParts forming a triangle on the ground ──────
    if cfg.VISION_CONE_MODE == "2D" or cfg.VISION_CONE_MODE == "Both" then
        local function makeWedge(name)
            local p = Instance.new("WedgePart")
            p.Name = name
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            p.CastShadow = false
            p.Material = Enum.Material.Neon
            p.Transparency = cfg.VISION_CONE_ALPHA_2D
            p.Color = Color3.fromRGB(255, 200, 80)
            p.Parent = model
            return p
        end

        vc.wedge2DLeft  = makeWedge("Cone2D_Left")
        vc.wedge2DRight = makeWedge("Cone2D_Right")
    end

    -- ─── 3D: Pyramid from head ─────────────────────────────────────────
    if cfg.VISION_CONE_MODE == "3D" or cfg.VISION_CONE_MODE == "Both" then
        local part = Instance.new("Part")
        part.Name = "Cone3D"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Transparency = cfg.VISION_CONE_ALPHA_3D
        part.Size = Vector3.new(1, 1, 1)
        part.Color = Color3.fromRGB(255, 200, 80)

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Pyramid
        mesh.Parent = part

        part.Parent = model
        vc.part3D = part
        vc.mesh3D = mesh
    end

    if cfg.VISION_CONE_HIGHLIGHT then
        local hl = Instance.new("Highlight")
        hl.Adornee = model
        hl.DepthMode = (cfg.VISION_CONE_HIGHLIGHT_DEPTH == "AlwaysOnTop")
            and Enum.HighlightDepthMode.AlwaysOnTop
            or  Enum.HighlightDepthMode.Occluded
        hl.FillColor = cfg.VISION_CONE_FIXED_COLOR
        hl.OutlineColor = cfg.VISION_CONE_FIXED_COLOR
        hl.FillTransparency = 0.8
        hl.OutlineTransparency = 0.5
        hl.Parent = CoreGui
        vc.highlight = hl
    end

    self._visionCones[player] = vc
    return vc
end

function ViewLines:_resolveConeColor(player, hit)
    local cfg = self.config
    local base

    if cfg.VISION_CONE_COLOR_MODE == "Fixed" then
        base = cfg.VISION_CONE_FIXED_COLOR
    else
        base = getTeamColorOf(player) or cfg.VISION_CONE_FIXED_COLOR
    end

    if hit then
        if cfg.VISION_CONE_USE_FIXED_HIT then
            return cfg.VISION_CONE_FIXED_HIT_COLOR
        else
            return inverseColor(base)
        end
    end
    return base
end

function ViewLines:_coneOcclusionAlpha(baseAlpha, worldPos)
    local cfg = self.config
    if not cfg.VISION_CONE_OCCLUDE_ENABLED then return baseAlpha end

    local cam = Camera
    if not cam then return baseAlpha end

    local toPos = worldPos - cam.CFrame.Position
    local d = toPos.Magnitude
    if d < 1e-3 then return baseAlpha end
    local facing = cam.CFrame.LookVector:Dot(toPos / d)

    local thresh = cfg.VISION_CONE_OCCLUDE_THRESHOLD or 0.85
    if facing <= thresh then return baseAlpha end

    local factor = (facing - thresh) / math.max(1 - thresh, 1e-3)
    local minA = cfg.VISION_CONE_OCCLUDE_MIN_ALPHA or 0.9
    return clamp(baseAlpha + (minA - baseAlpha) * factor, 0, 1)
end

function ViewLines:_updateVisionCone(player, entry, hit)
    local cfg = self.config
    if not cfg.VISION_CONE_ENABLED then return end
    if not entry or not entry.viewerHead or not entry.viewerHead.Parent then return end

    local vc = self:_createVisionCone(player)
    local head = entry.viewerHead
    local char = player.Character
    if not char then return end

    -- Direction (flattened)
    local look = head.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 1e-4 then flat = Vector3.new(0, 0, -1) end
    flat = flat.Unit

    -- Foot Y for the 2D cone
    local root = char:FindFirstChild("HumanoidRootPart")
    local footY = head.Position.Y - 3
    if root then footY = root.Position.Y - root.Size.Y * 0.5 end

    -- Apex position: head X/Z, foot Y
    local apexPos = Vector3.new(
        head.Position.X,
        footY + cfg.VISION_CONE_GROUND_OFFSET,
        head.Position.Z
    )

    -- Base geometry
    local halfFov = math.rad((cfg.FOV_DEGREES or 120) * 0.5)
    local baseWidth = 2 * cfg.VISION_CONE_RANGE * math.tan(halfFov)

    -- Tilt fade
    local tiltAlpha = 1
    if cfg.VISION_CONE_TILT_FADE then
        tiltAlpha = clamp(1 - math.abs(look.Y), 0, 1)
    end

    local baseColor = self:_resolveConeColor(player, hit)

    -- ─── 2D cone: two mirrored WedgeParts ──────────────────────────────
    if vc.wedge2DLeft and vc.wedge2DRight then
        -- WedgePart: right-angle triangle. We use two mirrored wedges so
        -- their hypotenuses meet to form the outer cone edges, and their
        -- shared right-angle corners form the apex at the head position.
        --
        -- Orient: local X points along `flat` (radial from apex outward),
        -- local Y points perpendicular to `flat` on the ground (fan out),
        -- local Z points up (thin axis).

        local wedgeLength = cfg.VISION_CONE_RANGE      -- X extent (radial)
        local wedgeWidth  = baseWidth * 0.5            -- Y extent (half of fan)
        local thickness   = 0.1

        -- Ground-plane perpendicular to flat
        local right = Vector3.new(-flat.Z, 0, flat.X)

        -- Base orientation: +X along flat, +Y along right, +Z up
        local baseCF = CFrame.fromMatrix(
            apexPos,
            flat,
            right,
            Vector3.new(0, 1, 0)
        )

        -- Right wedge: sits in the +Y half, extends +X and +Y from apex.
        -- Wedge's right-angle vertex is at the origin of the part. We want
        -- it at the apex, so offset the part center to (length/2, width/2).
        local rightCF = baseCF
            * CFrame.new(wedgeLength * 0.5, wedgeWidth * 0.5, 0)
        vc.wedge2DRight.Size = Vector3.new(wedgeLength, wedgeWidth, thickness)
        vc.wedge2DRight.CFrame = rightCF

        -- Left wedge: mirrored across the X axis (Y negated). Achieved by
        -- rotating 180° around the X axis and offsetting center to
        -- (length/2, -width/2). But since WedgePart's triangle is fixed
        -- in its local frame, we mirror via CFrame.
        local leftCF = baseCF
            * CFrame.new(wedgeLength * 0.5, -wedgeWidth * 0.5, 0)
            * CFrame.Angles(0, 0, math.rad(180))
        vc.wedge2DLeft.Size = Vector3.new(wedgeLength, wedgeWidth, thickness)
        vc.wedge2DLeft.CFrame = leftCF

        local alpha2D = (hit and cfg.VISION_CONE_HIT_ALPHA_2D or cfg.VISION_CONE_ALPHA_2D)
        alpha2D = clamp(alpha2D + (1 - tiltAlpha), 0, 1)
        vc.wedge2DLeft.Transparency  = alpha2D
        vc.wedge2DRight.Transparency = alpha2D
        vc.wedge2DLeft.Color  = baseColor
        vc.wedge2DRight.Color = baseColor
    end

    -- ─── 3D cone: Pyramid with apex at head ────────────────────────────
    if vc.part3D then
        -- Pyramid's apex is at +Y (mesh local). We want apex at head.
        -- So pyramid's local +Y must point from base-center toward the head,
        -- which is -flat. Local X and Z are the pyramid's width/depth axes.
        local yAxis = -flat
        local xAxis = yAxis:Cross(Vector3.new(0, 1, 0))
        if xAxis.Magnitude < 0.1 then
            xAxis = yAxis:Cross(Vector3.new(1, 0, 0))
        end
        xAxis = xAxis.Unit
        local zAxis = xAxis:Cross(yAxis).Unit

        local pyramidLength = cfg.VISION_CONE_RANGE
        local pyramidCenter = head.Position + flat * (pyramidLength * 0.5)

        vc.part3D.Size = Vector3.new(baseWidth, pyramidLength, baseWidth)
        vc.part3D.CFrame = CFrame.fromMatrix(pyramidCenter, xAxis, yAxis, zAxis)

        local alpha3D = (hit and cfg.VISION_CONE_HIT_ALPHA_3D or cfg.VISION_CONE_ALPHA_3D)
        if cfg.VISION_CONE_OCCLUDE_ENABLED then
            alpha3D = self:_coneOcclusionAlpha(alpha3D, vc.part3D.Position)
        end
        alpha3D = clamp(alpha3D + (1 - tiltAlpha), 0, 1)
        vc.part3D.Transparency = alpha3D
        vc.part3D.Color = baseColor
    end

    -- Highlight color
    if vc.highlight then
        vc.highlight.FillColor = baseColor
        vc.highlight.OutlineColor = baseColor
        vc.highlight.FillTransparency = hit and 0.6 or 0.85
        vc.highlight.OutlineTransparency = hit and 0.3 or 0.6
    end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------
function ViewLines:_cleanup(player)
    local e = self._entries[player]
    if e then
        for _, obj in ipairs({
            e.sightBeam, e.sightAttViewer, e.sightAttMine,
            e.lookBeam, e.lookAttFace, e.lookAttTip,
            e.dotPart,
        }) do
            if obj then pcall(function() obj:Destroy() end) end
        end
        self._entries[player] = nil
    end

    self:_destroyVisionCone(player)
    pcall(function() self:_publishClear(player) end)
    pcall(function() self._edgeIndicators:removeTarget(player) end)
end

function ViewLines:_cleanupAll()
    local list = {}
    for p in pairs(self._entries) do list[#list + 1] = p end
    for _, p in ipairs(list) do self:_cleanup(p) end

    local coneList = {}
    for p in pairs(self._visionCones) do coneList[#coneList + 1] = p end
    for _, p in ipairs(coneList) do self:_destroyVisionCone(p) end

    pcall(function() self._edgeIndicators:clearTargets() end)
    pcall(function() self:_publishClearAll() end)
end

--------------------------------------------------------------------------------
-- ENTRY BUILDING
--------------------------------------------------------------------------------
function ViewLines:_ensureEntry(player, myRoot)
    local char = player.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil end

    local e = self._entries[player]
    if e
        and e.viewerHead == head
        and e.myRoot == myRoot
        and e.viewerHead.Parent
        and e.myRoot.Parent
    then
        return e
    end
    if e then self:_cleanup(player) end

    local cfg = self.config

    local sa = Instance.new("Attachment"); sa.Parent = head
    local sb = Instance.new("Attachment"); sb.Parent = myRoot

    local sight = Instance.new("Beam")
    sight.Attachment0 = sa
    sight.Attachment1 = sb
    sight.FaceCamera = true
    sight.LightEmission = 1
    sight.LightInfluence = 0
    sight.Width0 = cfg.BLOCKED_WIDTH
    sight.Width1 = cfg.BLOCKED_WIDTH
    sight.Color = ColorSequence.new(cfg.BLOCKED_COLOR)
    sight.Transparency = NumberSequence.new(cfg.SIGHT_ALPHA_UNVIEWED)
    sight.Parent = workspace

    local lookFace = Instance.new("Attachment")
    lookFace.Position = Vector3.new(0, 0, -head.Size.Z * 0.5)
    lookFace.Parent = head

    local lookTip = Instance.new("Attachment")
    lookTip.Position = Vector3.new(0, 0, -head.Size.Z * 0.5 - cfg.LOOK_RANGE)
    lookTip.Parent = head

    local lookBeam = Instance.new("Beam")
    lookBeam.Attachment0 = lookFace
    lookBeam.Attachment1 = lookTip
    lookBeam.FaceCamera = true
    lookBeam.LightEmission = 1
    lookBeam.LightInfluence = 0
    lookBeam.Width0 = cfg.LOOK_WIDTH
    lookBeam.Width1 = cfg.LOOK_WIDTH
    lookBeam.Color = ColorSequence.new(cfg.LOOK_COLOR)
    lookBeam.Transparency = NumberSequence.new(cfg.LOOK_TRANSPARENCY_NEAR)
    lookBeam.Parent = workspace

    local dotPart
    if cfg.LOOK_DOT_ENABLED then
        dotPart = Instance.new("Part")
        dotPart.Shape = Enum.PartType.Ball
        dotPart.Size = Vector3.new(cfg.LOOK_DOT_SIZE, cfg.LOOK_DOT_SIZE, cfg.LOOK_DOT_SIZE)
        dotPart.Anchored = true
        dotPart.CanCollide = false
        dotPart.CanQuery = false
        dotPart.CanTouch = false
        dotPart.CastShadow = false
        dotPart.Material = Enum.Material.Neon
        dotPart.Color = cfg.LOOK_COLOR
        dotPart.Transparency = cfg.LOOK_DOT_ALPHA
        dotPart.Parent = workspace
    end

    local entry = {
        sightBeam = sight, sightAttViewer = sa, sightAttMine = sb,
        viewerHead = head, myRoot = myRoot,
        lookBeam = lookBeam, lookAttFace = lookFace, lookAttTip = lookTip,
        dotPart = dotPart,
    }
    self._entries[player] = entry
    return entry
end

--------------------------------------------------------------------------------
-- VISIBILITY
--------------------------------------------------------------------------------
function ViewLines:_evaluateVisibility(viewerChar, viewerHead, myChar, mySamples)
    if #mySamples == 0 then return 0 end
    local eye, look = eyeOf(viewerHead)
    local params = self:_rayParams(viewerChar)
    local cosHalf = math.cos(math.rad(self.config.FOV_DEGREES * 0.5))
    local hits = 0

    for _, s in ipairs(mySamples) do
        local toSample = s.pos - eye
        local dist = toSample.Magnitude
        if dist > 0.001 then
            local dir = toSample / dist
            if look:Dot(dir) >= cosHalf then
                local res = workspace:Raycast(eye, toSample, params)
                if res == nil or res.Instance:IsDescendantOf(myChar) then
                    hits += 1
                end
            end
        end
    end
    return hits / #mySamples
end

function ViewLines:_lookBeamHitsMe(viewerChar, viewerHead, myChar, mySamples)
    local eye, look = eyeOf(viewerHead)
    local range = self.config.LOOK_RANGE
    local radius = self.config.LOOK_HIT_RADIUS
    local params = self:_rayParams(viewerChar)

    for _, s in ipairs(mySamples) do
        local toSample = s.pos - eye
        local t = math.clamp(toSample:Dot(look), 0, range)
        local closest = eye + look * t
        local d = (s.pos - closest).Magnitude

        if d <= s.radius + radius then
            local res = workspace:Raycast(eye, s.pos - eye, params)
            if res == nil or res.Instance:IsDescendantOf(myChar) then
                return true
            end
        end
    end
    return false
end

function ViewLines:_updateLookGeometry(entry, viewerHead, viewerChar)
    local cfg = self.config
    local eye, look = eyeOf(viewerHead)
    local length = cfg.LOOK_RANGE
    if cfg.LOOK_CLAMP_TO_WALL then
        local params = self:_rayParams(viewerChar)
        local res = workspace:Raycast(eye, look * cfg.LOOK_RANGE, params)
        if res then length = (res.Position - eye).Magnitude end
    end
    local endWorld = eye + look * length
    entry.lookAttTip.Position = viewerHead.CFrame:PointToObjectSpace(endWorld)
    if entry.dotPart and entry.dotPart.Parent then
        entry.dotPart.CFrame = CFrame.new(endWorld)
    end
    return endWorld, length
end

--------------------------------------------------------------------------------
-- APPEARANCE
--------------------------------------------------------------------------------
function ViewLines:_applySightAppearance(beam, vis)
    local cfg = self.config
    local color, width, transparency
    if vis <= 0 then
        color = cfg.BLOCKED_COLOR
        width = cfg.BLOCKED_WIDTH
        transparency = cfg.SIGHT_ALPHA_UNVIEWED
    elseif vis >= 1 then
        color = cfg.VISIBLE_COLOR
        width = cfg.VISIBLE_WIDTH
        transparency = cfg.SIGHT_ALPHA_VIEWED
    else
        color = cfg.BLOCKED_COLOR:Lerp(cfg.VISIBLE_COLOR, vis)
        width = cfg.BLOCKED_WIDTH + (cfg.VISIBLE_WIDTH - cfg.BLOCKED_WIDTH) * vis
        transparency = cfg.SIGHT_ALPHA_UNVIEWED
            + (cfg.SIGHT_ALPHA_VIEWED - cfg.SIGHT_ALPHA_UNVIEWED) * vis
    end

    local a0 = beam.Attachment0 and beam.Attachment0.WorldPosition
    local a1 = beam.Attachment1 and beam.Attachment1.WorldPosition
    transparency = applyBeamOcclusion(cfg, a0, a1, transparency)

    beam.Color = ColorSequence.new(color)
    beam.Transparency = NumberSequence.new(transparency)
    beam.Width0 = width
    beam.Width1 = width
end

function ViewLines:_applyLookAppearance(entry, hit, length)
    local cfg = self.config
    local color = hit and cfg.LOOK_HIT_COLOR or cfg.LOOK_COLOR
    entry.lookBeam.Color = ColorSequence.new(color)

    local ratio = math.clamp(length / math.max(cfg.LOOK_RANGE, 1e-3), 0, 1)
    local tipT = cfg.LOOK_TRANSPARENCY_NEAR
        + (cfg.LOOK_TRANSPARENCY_FAR - cfg.LOOK_TRANSPARENCY_NEAR) * ratio

    local a0 = entry.lookAttFace and entry.lookAttFace.WorldPosition
    local a1 = entry.lookAttTip and entry.lookAttTip.WorldPosition

    local nearT = cfg.LOOK_TRANSPARENCY_NEAR
    local occludedNear = applyBeamOcclusion(cfg, a0, a1, nearT)

    entry.lookBeam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, occludedNear),
        NumberSequenceKeypoint.new(1, tipT),
    })

    if entry.dotPart and entry.dotPart.Parent then
        entry.dotPart.Color = color
        entry.dotPart.Transparency = applyBeamOcclusion(cfg, a0, a1, cfg.LOOK_DOT_ALPHA)
    end
end

--------------------------------------------------------------------------------
-- EDGE INDICATOR
--------------------------------------------------------------------------------
function ViewLines:_updateEdgeIndicator(player, theirChar, hit, vis)
    local cfg = self.config
    if not cfg.EDGE_INDICATORS then
        self._edgeIndicators:removeTarget(player)
        return
    end

    local mode = cfg.EDGE_INDICATOR_MODE
    local qualifies
    if mode == "Aimed" then qualifies = hit
    elseif mode == "Visible" then qualifies = vis > 0.001
    else qualifies = true end

    if not qualifies then
        self._edgeIndicators:removeTarget(player)
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local viewerRoot = theirChar:FindFirstChild("HumanoidRootPart")
                    or theirChar:FindFirstChild("Head")
    if not viewerRoot then
        self._edgeIndicators:removeTarget(player)
        return
    end

    local _, onScreen = cam:WorldToViewportPoint(viewerRoot.Position)
    local camSpace = cam.CFrame:PointToObjectSpace(viewerRoot.Position)
    local behind = camSpace.Z >= 0

    if (not onScreen) or behind then
        local sightSeen = vis >= cfg.EDGE_NAME_SIGHT_THRESHOLD
        local tc = getTeamColorOf(player) or Color3.fromRGB(235, 235, 235)
        self._edgeIndicators:addTarget(player, {
            Color = hit and cfg.EDGE_ARROW_ALERT_COLOR or cfg.EDGE_ARROW_COLOR,
            Alpha = cfg.EDGE_ARROW_ALPHA,
            NameColor = tc,
            Viewing = hit or sightSeen,
            Aiming = hit,
        })
    else
        self._edgeIndicators:removeTarget(player)
    end
end

--------------------------------------------------------------------------------
-- CONE PRIORITY
--------------------------------------------------------------------------------
function ViewLines:_selectConePlayers(candidates, myRoot)
    local cfg = self.config
    if not cfg.VISION_CONE_ENABLED then return {} end
    if not myRoot then return {} end

    local actRange = cfg.VISION_CONE_ACTIVATION_RANGE
    local eligible = {}

    for _, c in ipairs(candidates) do
        local theirChar = c.player.Character
        local theirRoot = theirChar and theirChar:FindFirstChild("HumanoidRootPart")
        if theirRoot then
            local dist = (myRoot.Position - theirRoot.Position).Magnitude
            if actRange <= 0 or dist <= actRange then
                eligible[#eligible + 1] = { player = c.player, distance = dist }
            end
        end
    end

    table.sort(eligible, function(a, b) return a.distance < b.distance end)

    local picked = {}
    for i = 1, math.min(#eligible, cfg.VISION_CONE_MAX_PLAYERS) do
        picked[eligible[i].player] = true
    end
    return picked
end

--------------------------------------------------------------------------------
-- MAIN UPDATE
--------------------------------------------------------------------------------
function ViewLines:update()
    local cfg = self.config
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myChar or not myRoot then
        self:_cleanupAll()
        pcall(function() self._edgeIndicators:update() end)
        return
    end

    local mySamples = self:_getSamplePoints(myChar)

    local stale = {}
    for player, e in pairs(self._entries) do
        if not player.Parent or not player.Character
            or e.myRoot ~= myRoot
            or not e.viewerHead.Parent
            or not e.myRoot.Parent
        then
            stale[#stale + 1] = player
        end
    end
    for _, player in ipairs(stale) do
        self:_cleanup(player)
    end

    local coneCandidates = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not self:_isHostile(player) then
                self:_cleanup(player)
            else
                local theirChar = player.Character
                if theirChar then
                    local distOk = true
                    if cfg.MAX_DISTANCE > 0 then
                        local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
                        if theirRoot then
                            distOk = (myRoot.Position - theirRoot.Position).Magnitude
                                <= cfg.MAX_DISTANCE
                        end
                    end

                    if distOk then
                        local e = self:_ensureEntry(player, myRoot)
                        if e then
                            local head = e.viewerHead

                            local _, length = self:_updateLookGeometry(e, head, theirChar)
                            local hit = self:_lookBeamHitsMe(theirChar, head, myChar, mySamples)
                            self:_applyLookAppearance(e, hit, length)

                            local vis = self:_evaluateVisibility(theirChar, head, myChar, mySamples)

                            self:_publishToBus(player, hit, vis)

                            if cfg.HIDE_SIGHT_WHEN_AIMED and hit then
                                e.sightBeam.Enabled = false
                            else
                                e.sightBeam.Enabled = true
                                self:_applySightAppearance(e.sightBeam, vis)
                            end

                            self:_updateEdgeIndicator(player, theirChar, hit, vis)

                            if cfg.VISION_CONE_ENABLED then
                                coneCandidates[#coneCandidates + 1] = {
                                    player = player,
                                    hit = hit,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if cfg.VISION_CONE_ENABLED then
        local picked = self:_selectConePlayers(coneCandidates, myRoot)

        for _, c in ipairs(coneCandidates) do
            if picked[c.player] then
                local e = self._entries[c.player]
                if e then
                    self:_updateVisionCone(c.player, e, c.hit)
                end
            else
                self:_destroyVisionCone(c.player)
            end
        end

        for player in pairs(self._visionCones) do
            if not self._entries[player] then
                self:_destroyVisionCone(player)
            end
        end
    else
        for player in pairs(self._visionCones) do
            self:_destroyVisionCone(player)
        end
    end

    pcall(function() self._edgeIndicators:update() end)
end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------
function ViewLines:start()
    if self._running then return end
    self._running = true

    self:_track(RunService.Heartbeat:Connect(function()
        local cfg = self.config
        if cfg.UPDATE_INTERVAL > 0 then
            local now = os.clock()
            if now - self._lastUpdate < cfg.UPDATE_INTERVAL then return end
            self._lastUpdate = now
        end
        self:update()
    end))

    self:_track(LocalPlayer.CharacterAdded:Connect(function()
        self:_cleanupAll()
    end))

    self:_track(Players.PlayerRemoving:Connect(function(player)
        self:_cleanup(player)
        self:_destroyVisionCone(player)
    end))

    self:_track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local key = self.config.KILL_KEYBIND
        if key and input.KeyCode == key then
            self:stop()
        end
    end))
end

function ViewLines:stop()
    for i = #self._connections, 1, -1 do
        local c = self._connections[i]
        self._connections[i] = nil
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    self._connections = {}
    self:_cleanupAll()
    pcall(function() self._edgeIndicators:stop() end)
    self._running = false
end

function ViewLines:destroy() self:stop() end

function ViewLines:setConfig(partial)
    if not partial then return end
    for k, v in pairs(partial) do self.config[k] = v end

    local cfg = self.config
    local sei = self._edgeIndicators
    if sei then
        sei.config.PADDING = cfg.EDGE_PADDING
        sei.config.ARROW_SIZE = cfg.EDGE_ARROW_SIZE
        sei.config.ARROW_COLOR = cfg.EDGE_ARROW_COLOR
        sei.config.ARROW_ALPHA = cfg.EDGE_ARROW_ALPHA
        sei.config.SHOW_NAME = cfg.EDGE_SHOW_NAME
        sei.config.NAME_SIZE = cfg.EDGE_NAME_SIZE
        sei.config.NAME_SIZE_VIEWED = cfg.EDGE_NAME_SIZE_VIEWED
        sei.config.NAME_COLOR = cfg.EDGE_NAME_COLOR
        sei.config.NAME_ALPHA = cfg.EDGE_NAME_ALPHA
        sei.config.NAME_ALPHA_VIEWED = cfg.EDGE_NAME_ALPHA_VIEWED
        sei.config.NAME_MODE = cfg.NAME_MODE
        sei.config.NAME_TRUNCATE_USERNAME = cfg.NAME_TRUNCATE_USERNAME
        sei.config.NAME_TRUNCATE_DISPLAYNAME = cfg.NAME_TRUNCATE_DISPLAYNAME
    end
end

function ViewLines:isRunning() return self._running end

return ViewLines
