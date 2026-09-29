--[[
    Self Healthbar — module
    Cursor-anchored HP HUD with damage popups, DPS/HPS tracking, dynamic
    opacity, size pulse, progression modes, and optional circular mode.

    Usage:
        local SelfHealthbar = loadstring(game:HttpGet(URL))()
        local hb = SelfHealthbar.new({ TEXT_FORMAT = "HPMAX_PCT" })
        hb:start()
        -- ...
        hb:stop()

    Or drive it manually:
        hb:update()   -- call from your own RenderStepped/Heartbeat

    Config is hot-swappable:  hb:setConfig({ TEXT_POSITION = "Above" })

    Fires no side effects on require. No auto-start, no print, no global.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------
local DEFAULTS = {
    -- ─── Positioning ───────────────────────────────────────────────────
    CURSOR_OFFSET_X = 0,
    CURSOR_OFFSET_Y = 60,
    FOLLOW_CURSOR   = true,

    -- ─── Bar dimensions ────────────────────────────────────────────────
    BAR_WIDTH_SCALE  = 0.10,
    BAR_WIDTH_PX     = nil,
    BAR_HEIGHT_SCALE = 0.01,
    BAR_HEIGHT_PX    = 8,

    -- ─── HUD padding ───────────────────────────────────────────────────
    PAD_X       = 100,
    PAD_TOP     = 80,
    PAD_BOTTOM  = 60,

    -- ─── Bar colors ────────────────────────────────────────────────────
    BAR_FILL_COLOR_AUTO = true,
    BAR_FILL_COLOR      = Color3.fromRGB(0, 255, 0),
    BAR_FILL_TRANSPARENCY = 0.5,

    BAR_BORDER_AUTO      = true,
    BAR_BORDER_COLOR     = Color3.fromRGB(0, 128, 0),
    BAR_BORDER_OFFSET    = 0.5,
    BAR_BORDER_THICKNESS = 2,
    BAR_BORDER_TRANSPARENCY = 0,

    BAR_ROUNDED = false,
    BAR_CORNER_RADIUS = 2,

    USE_TEAM_COLOR_FILL   = false,
    USE_TEAM_COLOR_BORDER = false,

    -- ─── Low-HP override ───────────────────────────────────────────────
    LOWHP_OVERRIDE_ENABLED = true,
    LOWHP_THRESHOLD        = 0.30,
    LOWHP_FILL_TOP         = Color3.fromRGB(255, 0, 0),
    LOWHP_FILL_BOTTOM      = Color3.fromRGB(0, 0, 0),
    LOWHP_BORDER_TOP       = Color3.fromRGB(128, 0, 0),
    LOWHP_BORDER_BOTTOM    = Color3.fromRGB(0, 0, 0),

    -- ─── HP Text ───────────────────────────────────────────────────────
    TEXT_ENABLED        = true,
    -- "HP" | "HPMAX" | "PCT" | "HP_PCT" | "HPMAX_PCT"
    TEXT_FORMAT         = "PCT",
    TEXT_SIZE           = 13,
    TEXT_COLOR_AUTO     = true,
    TEXT_COLOR          = Color3.fromRGB(255, 255, 255),
    TEXT_TRANSPARENCY   = 0.1,

    TEXT_FONT         = Enum.Font.Gotham,
    TEXT_BOLD         = true,
    TEXT_LABEL_WIDTH  = 220,
    TEXT_WRAPPED      = false,

    TEXT_POSITION     = "Below",   -- "Above"|"Below"|"Left"|"Right"|"Center"
    TEXT_POSITION_GAP = 4,
    TEXT_OFFSET_X     = 0,
    TEXT_OFFSET_Y     = 0,

    TEXT_STROKE_COLOR_AUTO   = false,
    TEXT_STROKE_COLOR        = Color3.fromRGB(0, 0, 0),
    TEXT_STROKE_TRANSPARENCY = 0.3,
    TEXT_STROKE_WIDTH        = 1,

    -- ─── Progression ───────────────────────────────────────────────────
    PROGRESSION = "Both",   -- "Both" | "Right" | "Left"

    -- ─── Shake ─────────────────────────────────────────────────────────
    SHAKE_ENABLED       = true,
    SHAKE_INTENSITY     = 6,
    SHAKE_INTENSITY_PER_DMG = 0.3,
    SHAKE_MAX           = 18,
    SHAKE_DURATION      = 0.10,
    SHAKE_STYLE         = Enum.EasingStyle.Quad,
    SHAKE_DIRECTION     = Enum.EasingDirection.Out,
    SHAKE_ON_DAMAGE     = true,
    SHAKE_ON_HEAL       = true,

    -- ─── Popups ────────────────────────────────────────────────────────
    INDICATOR_ENABLED        = true,
    INDICATOR_DURATION       = 1.2,
    INDICATOR_SIZE           = 14,
    INDICATOR_DAMAGE_COLOR   = Color3.fromRGB(255, 80, 80),
    INDICATOR_HEAL_COLOR     = Color3.fromRGB(80, 255, 80),
    INDICATOR_RISE_HEIGHT    = 40,
    INDICATOR_FALL_HEIGHT    = 30,
    INDICATOR_DRIFT_X        = 18,
    INDICATOR_START_X        = 40,
    INDICATOR_STROKE_TRANSPARENCY = 0.4,
    INDICATOR_DAMAGE_SIDE    = -1,
    INDICATOR_HEAL_SIDE      = 1,

    -- ─── DPS/HPS ───────────────────────────────────────────────────────
    DPS_ENABLED      = true,
    DPS_MODE         = "Weighted",   -- "Average" | "Weighted" | "Instant"
    DPS_WINDOW       = 5,
    DPS_DECAY_TIME   = 3,
    DPS_THRESHOLD    = 0.5,
    DPS_MAX_EVENTS   = 64,
    DPS_SIZE         = 11,
    DPS_DAMAGE_COLOR = Color3.fromRGB(255, 120, 120),
    DPS_HEAL_COLOR   = Color3.fromRGB(120, 255, 120),
    DPS_STROKE_TRANSPARENCY = 0.5,

    DPS_FONT         = Enum.Font.GothamBold,
    DPS_BOLD         = false,
    DPS_LABEL_WIDTH  = 220,
    DPS_WRAPPED      = false,

    DPS_FOLLOW_TEXT  = true,
    DPS_POSITION     = "Below",
    DPS_POSITION_GAP = 4,
    DPS_OFFSET_X     = 0,
    DPS_OFFSET_Y     = 0,

    -- ─── Dynamic opacity ───────────────────────────────────────────────
    OPACITY_ENABLED               = true,
    OPACITY_MIN                   = 0.15,
    OPACITY_FULL_HP_TRANSPARENCY  = 0.9,
    OPACITY_FULL_HP_DELAY         = 5,
    OPACITY_IDLE_FADE_START       = 5,
    OPACITY_IDLE_FADE_END         = 30,
    OPACITY_MAX_IDLE_FADE         = 0.70,
    OPACITY_FADE_IN_RATE          = 20,
    OPACITY_FADE_OUT_RATE         = 2,

    ALWAYS_VISIBLE       = false,
    ALWAYS_VISIBLE_ALPHA = 0.15,

    DEBUG_HEALTH = false,

    -- ─── Size pulse ────────────────────────────────────────────────────
    PULSE_ENABLED          = true,
    PULSE_DAMAGE_PER_HP    = 0.010,
    PULSE_HEAL_PER_HP      = 0.006,
    PULSE_MAX              = 0.40,
    PULSE_IN_DURATION      = 0.12,
    PULSE_OUT_DURATION     = 0.40,
    PULSE_HEAL_IN_DURATION = 0.35,
    PULSE_HEAL_OUT_DURATION = 0.70,

    -- ─── Circular mode ─────────────────────────────────────────────────
    CIRCULAR_ENABLED      = true,
    CIRCULAR_RADIUS       = 40,
    CIRCULAR_SEGMENTS     = 12,
    CIRCULAR_SEG_WIDTH    = 2,
    CIRCULAR_SEG_OVERLAP  = 1.8,
    CIRCULAR_ROUND_ENDS   = false,
    CIRCULAR_START_ANGLE  = -72,
    CIRCULAR_CLOCKWISE    = false,
    CIRCULAR_UNFILLED_COLOR = Color3.fromRGB(40, 40, 40),
    CIRCULAR_UNFILLED_TRANSPARENCY = 0.4,

    -- ─── Lifecycle ─────────────────────────────────────────────────────
    KILL_KEYBIND    = Enum.KeyCode.K,
    UPDATE_INTERVAL = 0,   -- 0 = every RenderStepped
}

--------------------------------------------------------------------------------
-- MODULE
--------------------------------------------------------------------------------
local SelfHealthbar = {}
SelfHealthbar.__index = SelfHealthbar

-- Font bold map (only pairs where both Enum.Font members exist)
local FONT_BOLD_MAP = {
    [Enum.Font.Gotham]              = Enum.Font.GothamBold,
    [Enum.Font.GothamMedium]        = Enum.Font.GothamBold,
    [Enum.Font.GothamSemibold]      = Enum.Font.GothamBold,
    [Enum.Font.SourceSans]          = Enum.Font.SourceSansBold,
    [Enum.Font.SourceSansSemibold]  = Enum.Font.SourceSansBold,
    [Enum.Font.SourceSansLight]     = Enum.Font.SourceSansBold,
    [Enum.Font.SourceSansItalic]    = Enum.Font.SourceSansBold,
    [Enum.Font.Arial]               = Enum.Font.ArialBold,
}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function resolveFont(baseFont, bold)
    if not bold then return baseFont end
    return FONT_BOLD_MAP[baseFont] or Enum.Font.GothamBold
end

function SelfHealthbar.new(overrides)
    local self = setmetatable({}, SelfHealthbar)
    self.config = {}
    for k, v in pairs(DEFAULTS) do self.config[k] = v end
    if overrides then
        for k, v in pairs(overrides) do self.config[k] = v end
    end

    -- Runtime state
    self._humanoid      = nil
    self._character     = nil
    self._charConn      = nil
    self._lastHealth    = nil
    self._lastChangeTime = 0
    self._lastFullHPTime = nil
    self._recentChanges = {}
    self._currentAlpha  = 0.15
    self._barWidthPx    = 180
    self._barHeightPx   = 11
    self._hudSize       = UDim2.fromOffset(380, 151)
    self._shakeActive   = false
    self._ringSegments  = {}
    self._lastUpdate    = 0

    self._connections   = {}
    self._running       = false

    self:_buildUI()
    self:_recomputeBaseSize()

    return self
end

--------------------------------------------------------------------------------
-- INTERNALS: connection tracking
--------------------------------------------------------------------------------
function SelfHealthbar:_track(conn)
    self._connections[#self._connections + 1] = conn
    return conn
end

--------------------------------------------------------------------------------
-- INTERNALS: color resolution
--------------------------------------------------------------------------------
function SelfHealthbar:_getTeamColor()
    local team = LocalPlayer.Team
    if team and team.TeamColor and team.TeamColor ~= BrickColor.new("Neutral") then
        return team.TeamColor.Color
    end
    return nil
end

function SelfHealthbar:_autoFillColor(pct)
    return Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
end

function SelfHealthbar:_resolveFillColor(pct)
    local cfg = self.config
    if cfg.LOWHP_OVERRIDE_ENABLED and pct < cfg.LOWHP_THRESHOLD then
        local t = pct / math.max(cfg.LOWHP_THRESHOLD, 1e-3)
        return cfg.LOWHP_FILL_BOTTOM:Lerp(cfg.LOWHP_FILL_TOP, t)
    end
    if cfg.USE_TEAM_COLOR_FILL then
        local tc = self:_getTeamColor()
        if tc then return tc end
    end
    if cfg.BAR_FILL_COLOR_AUTO then return self:_autoFillColor(pct) end
    return cfg.BAR_FILL_COLOR
end

function SelfHealthbar:_resolveBorderColor(pct, fillColor)
    local cfg = self.config
    if cfg.LOWHP_OVERRIDE_ENABLED and pct < cfg.LOWHP_THRESHOLD then
        local t = pct / math.max(cfg.LOWHP_THRESHOLD, 1e-3)
        return cfg.LOWHP_BORDER_BOTTOM:Lerp(cfg.LOWHP_BORDER_TOP, t)
    end
    if cfg.USE_TEAM_COLOR_BORDER then
        local tc = self:_getTeamColor()
        if tc then return tc end
    end
    if cfg.BAR_BORDER_AUTO then
        return Color3.new(
            fillColor.R * cfg.BAR_BORDER_OFFSET,
            fillColor.G * cfg.BAR_BORDER_OFFSET,
            fillColor.B * cfg.BAR_BORDER_OFFSET
        )
    end
    return cfg.BAR_BORDER_COLOR
end

function SelfHealthbar:_formatText(hp, maxHp, pct)
    local f = self.config.TEXT_FORMAT
    local hpI = math.floor(hp)
    local mI  = math.floor(maxHp)
    local pI  = math.floor(pct * 100 + 0.5)
    if f == "HPMAX_PCT" then return string.format("%d/%d | %d%%", hpI, mI, pI) end
    if f == "HP_PCT"    then return string.format("%d | %d%%", hpI, pI) end
    if f == "HPMAX"     then return string.format("%d/%d", hpI, mI) end
    if f == "HP"        then return tostring(hpI) end
    if f == "PCT"       then return string.format("%d%%", pI) end
    return string.format("%d/%d | %d%%", hpI, mI, pI)
end

function SelfHealthbar:_resolveAnchor(mode, halfW, halfH, gap)
    if mode == "Above" then
        return 0.5, 1,   0, -halfH - gap
    elseif mode == "Below" then
        return 0.5, 0,   0,  halfH + gap
    elseif mode == "Left" then
        return 1,   0.5, -halfW - gap, 0
    elseif mode == "Right" then
        return 0,   0.5,  halfW + gap, 0
    else
        return 0.5, 0.5, 0, 0
    end
end

--------------------------------------------------------------------------------
-- UI BUILDING
--------------------------------------------------------------------------------
function SelfHealthbar:_buildUI()
    local cfg = self.config

    local gui = Instance.new("ScreenGui")
    gui.Name           = "SelfHealthbar"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = LocalPlayer:WaitForChild("PlayerGui")
    self._gui = gui

    local root = Instance.new("Frame")
    root.Name                   = "Root"
    root.BackgroundTransparency = 1
    root.Size                   = UDim2.fromOffset(2, 2)
    root.AnchorPoint            = Vector2.new(0.5, 0.5)
    root.Position               = UDim2.new(0, 100, 0, 100)
    root.Parent                 = gui
    self._root = root

    local hud = Instance.new("CanvasGroup")
    hud.Name                   = "HUD"
    hud.BackgroundTransparency = 1
    hud.AnchorPoint            = Vector2.new(0.5, 0.5)
    hud.Position               = UDim2.new(0.5, 0, 0.5, 0)
    hud.Size                   = self._hudSize
    hud.GroupTransparency      = 0
    hud.Parent                 = root
    self._hud = hud

    local bar = Instance.new("Frame")
    bar.Name                   = "Bar"
    bar.AnchorPoint            = Vector2.new(0.5, 0.5)
    bar.Position               = UDim2.new(0.5, 0, 0.5, 0)
    bar.Size                   = UDim2.fromOffset(self._barWidthPx, self._barHeightPx)
    bar.BackgroundColor3       = cfg.BAR_FILL_COLOR
    bar.BackgroundTransparency = cfg.BAR_FILL_TRANSPARENCY
    bar.BorderSizePixel        = 0
    bar.Parent                 = hud
    self._bar = bar

    local stroke = Instance.new("UIStroke")
    stroke.Color        = cfg.BAR_BORDER_COLOR
    stroke.Thickness    = cfg.BAR_BORDER_THICKNESS
    stroke.Transparency = cfg.BAR_BORDER_TRANSPARENCY
    stroke.Parent       = bar
    self._stroke = stroke

    if cfg.BAR_ROUNDED then
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, cfg.BAR_CORNER_RADIUS)
        c.Parent = bar
    end

    -- HP text
    local textLabel = Instance.new("TextLabel")
    textLabel.Name                   = "Text"
    textLabel.BackgroundTransparency = 1
    textLabel.AnchorPoint            = Vector2.new(0.5, 1)
    textLabel.Position               = UDim2.new(0.5, 0, 0.5, -self._barHeightPx / 2 - cfg.TEXT_POSITION_GAP)
    textLabel.Size                   = UDim2.fromOffset(cfg.TEXT_LABEL_WIDTH, 18)
    textLabel.Font                   = resolveFont(cfg.TEXT_FONT, cfg.TEXT_BOLD)
    textLabel.TextScaled             = false
    textLabel.TextWrapped            = cfg.TEXT_WRAPPED
    textLabel.TextSize               = cfg.TEXT_SIZE
    textLabel.TextColor3             = cfg.TEXT_COLOR
    textLabel.TextTransparency       = cfg.TEXT_TRANSPARENCY
    textLabel.TextStrokeTransparency = cfg.TEXT_STROKE_TRANSPARENCY
    textLabel.TextStrokeColor3       = cfg.TEXT_STROKE_COLOR
    textLabel.Text                   = ""
    textLabel.Visible                = cfg.TEXT_ENABLED
    textLabel.Parent                 = hud
    self._textLabel = textLabel

    self._textUIStroke = nil
    if cfg.TEXT_STROKE_WIDTH and cfg.TEXT_STROKE_WIDTH > 1 then
        local s = Instance.new("UIStroke")
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        s.Thickness       = cfg.TEXT_STROKE_WIDTH
        s.Color           = cfg.TEXT_STROKE_COLOR
        s.Transparency    = cfg.TEXT_STROKE_TRANSPARENCY
        s.Parent          = textLabel
        textLabel.TextStrokeTransparency = 1
        self._textUIStroke = s
    end

    -- DPS label
    local dpsLabel = Instance.new("TextLabel")
    dpsLabel.Name                   = "DPS"
    dpsLabel.BackgroundTransparency = 1
    dpsLabel.AnchorPoint            = Vector2.new(0.5, 0)
    dpsLabel.Position               = UDim2.new(0.5, 0, 0.5, self._barHeightPx / 2 + cfg.DPS_POSITION_GAP)
    dpsLabel.Size                   = UDim2.fromOffset(cfg.DPS_LABEL_WIDTH, 14)
    dpsLabel.Font                   = resolveFont(cfg.DPS_FONT, cfg.DPS_BOLD)
    dpsLabel.TextScaled             = false
    dpsLabel.TextWrapped            = cfg.DPS_WRAPPED
    dpsLabel.TextSize               = cfg.DPS_SIZE
    dpsLabel.TextColor3             = Color3.new(1, 1, 1)
    dpsLabel.TextStrokeTransparency = cfg.DPS_STROKE_TRANSPARENCY
    dpsLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    dpsLabel.Text                   = ""
    dpsLabel.Visible                = false
    dpsLabel.Parent                 = hud
    self._dpsLabel = dpsLabel

    -- Circular ring container
    local circular = Instance.new("Frame")
    circular.Name                   = "Circular"
    circular.BackgroundTransparency = 1
    circular.AnchorPoint            = Vector2.new(0.5, 0.5)
    circular.Position               = UDim2.new(0.5, 0, 0.5, 0)
    circular.Size                   = UDim2.fromOffset(0, 0)
    circular.Visible                = cfg.CIRCULAR_ENABLED
    circular.Parent                 = hud
    self._circular = circular

    self:_rebuildCircular()
end

function SelfHealthbar:_rebuildCircular()
    -- Tear down existing segments
    for _, seg in ipairs(self._ringSegments) do
        if seg and seg.Parent then seg:Destroy() end
    end
    self._ringSegments = {}

    local cfg = self.config
    if cfg.CIRCULAR_ENABLED then
        self._bar.Visible = false
    else
        self._bar.Visible = true
        return
    end

    local N = cfg.CIRCULAR_SEGMENTS
    local R = cfg.CIRCULAR_RADIUS
    local startRad = math.rad(cfg.CIRCULAR_START_ANGLE)

    local arcLen = (2 * math.pi * R) / N
    local segLen = arcLen * cfg.CIRCULAR_SEG_OVERLAP
    local segWidth = cfg.CIRCULAR_SEG_WIDTH

    for i = 1, N do
        local frac = (i - 1) / N
        if not cfg.CIRCULAR_CLOCKWISE then frac = 1 - frac end
        local angle = startRad + frac * math.pi * 2
        local x = math.cos(angle) * R
        local y = math.sin(angle) * R

        local seg = Instance.new("Frame")
        seg.Name                   = "Seg_" .. i
        seg.AnchorPoint            = Vector2.new(0.5, 0.5)
        seg.Position               = UDim2.new(0.5, x, 0.5, y)
        seg.Size                   = UDim2.fromOffset(segLen, segWidth)
        seg.Rotation               = math.deg(angle) + 90
        seg.BackgroundColor3       = cfg.BAR_FILL_COLOR
        seg.BorderSizePixel        = 0
        seg.ZIndex                 = 2 + i

        if cfg.CIRCULAR_ROUND_ENDS then
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, math.max(1, segWidth / 2))
            corner.Parent = seg
        end

        seg.Parent = self._circular
        self._ringSegments[i] = seg
    end
end

--------------------------------------------------------------------------------
-- LAYOUT
--------------------------------------------------------------------------------
function SelfHealthbar:_positionText()
    local cfg = self.config
    local halfW, halfH
    if cfg.CIRCULAR_ENABLED then
        halfW, halfH = cfg.CIRCULAR_RADIUS, cfg.CIRCULAR_RADIUS
    else
        halfW, halfH = self._barWidthPx / 2, self._barHeightPx / 2
    end

    local ax, ay, sx, sy = self:_resolveAnchor(
        cfg.TEXT_POSITION, halfW, halfH, cfg.TEXT_POSITION_GAP
    )

    local tl = self._textLabel
    tl.AnchorPoint = Vector2.new(ax, ay)
    tl.Position = UDim2.new(
        0.5, sx + (cfg.TEXT_OFFSET_X or 0),
        0.5, sy + (cfg.TEXT_OFFSET_Y or 0)
    )
    tl.Font        = resolveFont(cfg.TEXT_FONT, cfg.TEXT_BOLD)
    tl.TextWrapped = cfg.TEXT_WRAPPED
    tl.Size        = UDim2.fromOffset(cfg.TEXT_LABEL_WIDTH, tl.Size.Y.Offset)
end

function SelfHealthbar:_positionDps()
    local cfg = self.config
    local halfW, halfH
    if cfg.CIRCULAR_ENABLED then
        halfW, halfH = cfg.CIRCULAR_RADIUS, cfg.CIRCULAR_RADIUS
    else
        halfW, halfH = self._barWidthPx / 2, self._barHeightPx / 2
    end

    local dl = self._dpsLabel

    if cfg.DPS_FOLLOW_TEXT and cfg.TEXT_ENABLED then
        local _, _, sx, sy = self:_resolveAnchor(
            cfg.TEXT_POSITION, halfW, halfH, cfg.TEXT_POSITION_GAP
        )
        local hpX = sx + (cfg.TEXT_OFFSET_X or 0)
        local hpY = sy + (cfg.TEXT_OFFSET_Y or 0)

        local stack = self._textLabel.Size.Y.Offset

        local dpsAnchorY, dpsY
        if cfg.TEXT_POSITION == "Above" then
            dpsAnchorY = 1
            dpsY = hpY - stack
        else
            dpsAnchorY = 0
            dpsY = hpY + stack
        end

        dl.AnchorPoint = Vector2.new(0.5, dpsAnchorY)
        dl.Position = UDim2.new(
            0.5, hpX + (cfg.DPS_OFFSET_X or 0),
            0.5, dpsY + (cfg.DPS_OFFSET_Y or 0)
        )
    else
        local ax, ay, sx, sy = self:_resolveAnchor(
            cfg.DPS_POSITION, halfW, halfH, cfg.DPS_POSITION_GAP
        )
        dl.AnchorPoint = Vector2.new(ax, ay)
        dl.Position = UDim2.new(
            0.5, sx + (cfg.DPS_OFFSET_X or 0),
            0.5, sy + (cfg.DPS_OFFSET_Y or 0)
        )
    end

    dl.Font        = resolveFont(cfg.DPS_FONT, cfg.DPS_BOLD)
    dl.TextWrapped = cfg.DPS_WRAPPED
    dl.Size        = UDim2.fromOffset(cfg.DPS_LABEL_WIDTH, dl.Size.Y.Offset)
end

function SelfHealthbar:_recomputeBaseSize()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local cfg = self.config

    if cfg.BAR_WIDTH_PX then
        self._barWidthPx = cfg.BAR_WIDTH_PX
    else
        self._barWidthPx = vp.X * cfg.BAR_WIDTH_SCALE
    end
    if cfg.BAR_HEIGHT_PX then
        self._barHeightPx = cfg.BAR_HEIGHT_PX
    else
        self._barHeightPx = vp.Y * cfg.BAR_HEIGHT_SCALE
    end

    self._hudSize = UDim2.fromOffset(
        self._barWidthPx + cfg.PAD_X * 2,
        self._barHeightPx + cfg.PAD_TOP + cfg.PAD_BOTTOM
    )

    self._hud.Size = self._hudSize
    self._bar.Size = UDim2.fromOffset(self._barWidthPx, self._barHeightPx)

    self:_positionText()
    self:_positionDps()
end

--------------------------------------------------------------------------------
-- FEEDBACK (popups, shake, pulse)
--------------------------------------------------------------------------------
function SelfHealthbar:_spawnIndicator(delta)
    local cfg = self.config
    if not cfg.INDICATOR_ENABLED then return end
    local isDamage = delta < 0
    local amount = math.abs(delta)
    if amount < 0.5 then return end

    local side  = isDamage and cfg.INDICATOR_DAMAGE_SIDE or cfg.INDICATOR_HEAL_SIDE
    local color = isDamage and cfg.INDICATOR_DAMAGE_COLOR or cfg.INDICATOR_HEAL_COLOR
    local text  = isDamage
        and string.format("-%d", math.floor(amount + 0.5))
        or  string.format("+%d", math.floor(amount + 0.5))

    local label = Instance.new("TextLabel")
    label.Name                   = isDamage and "DmgPopup" or "HealPopup"
    label.AnchorPoint            = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Size                   = UDim2.fromOffset(80, 20)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = cfg.INDICATOR_SIZE
    label.TextColor3             = color
    label.TextStrokeTransparency = cfg.INDICATOR_STROKE_TRANSPARENCY
    label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    label.Text                   = text
    label.ZIndex                 = 20
    label.Parent                 = self._hud

    local startX = cfg.INDICATOR_START_X * side
    label.Position = UDim2.new(0.5, startX, 0.5, 0)

    local drift = math.random(-cfg.INDICATOR_DRIFT_X, cfg.INDICATOR_DRIFT_X)
    local peakY = -cfg.INDICATOR_RISE_HEIGHT
    local endY  = cfg.INDICATOR_FALL_HEIGHT

    TweenService:Create(
        label,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, startX + drift, 0.5, peakY) }
    ):Play()

    task.delay(0.35, function()
        if not label.Parent then return end
        local t = TweenService:Create(
            label,
            TweenInfo.new(
                cfg.INDICATOR_DURATION - 0.35,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            ),
            {
                Position = UDim2.new(0.5, startX + drift, 0.5, endY),
                TextTransparency = 1,
                TextStrokeTransparency = 1,
            }
        )
        t:Play()
        t.Completed:Connect(function() label:Destroy() end)
    end)
end

function SelfHealthbar:_triggerShake(deltaMagnitude)
    local cfg = self.config
    if not cfg.SHAKE_ENABLED then return end
    if self._shakeActive then return end

    local intensity = math.min(
        cfg.SHAKE_INTENSITY + deltaMagnitude * cfg.SHAKE_INTENSITY_PER_DMG,
        cfg.SHAKE_MAX
    )
    local angle = math.random() * math.pi * 2
    local dx = math.cos(angle) * intensity
    local dy = math.sin(angle) * intensity

    self._shakeActive = true

    local t1 = TweenService:Create(
        self._hud,
        TweenInfo.new(cfg.SHAKE_DURATION, cfg.SHAKE_STYLE, cfg.SHAKE_DIRECTION),
        { Position = UDim2.new(0.5, dx, 0.5, dy) }
    )
    t1:Play()
    t1.Completed:Connect(function()
        local back = TweenService:Create(
            self._hud,
            TweenInfo.new(cfg.SHAKE_DURATION * 1.5, cfg.SHAKE_STYLE, cfg.SHAKE_DIRECTION),
            { Position = UDim2.new(0.5, 0, 0.5, 0) }
        )
        back:Play()
        back.Completed:Connect(function() self._shakeActive = false end)
    end)
end

function SelfHealthbar:_triggerPulse(delta, maxHP)
    local cfg = self.config
    if not cfg.PULSE_ENABLED then return end
    if maxHP <= 0 then return end

    local isDamage = delta < 0
    local amount = math.abs(delta)
    local factor = isDamage
        and amount * cfg.PULSE_DAMAGE_PER_HP
        or  amount * cfg.PULSE_HEAL_PER_HP
    factor = math.min(factor, cfg.PULSE_MAX)
    if factor <= 0.001 then return end

    local base = self._hudSize
    local boosted = UDim2.new(
        base.X.Scale * (1 + factor), base.X.Offset,
        base.Y.Scale * (1 + factor), base.Y.Offset
    )

    local inDuration  = isDamage and cfg.PULSE_IN_DURATION  or cfg.PULSE_HEAL_IN_DURATION
    local outDuration = isDamage and cfg.PULSE_OUT_DURATION or cfg.PULSE_HEAL_OUT_DURATION

    local inTween = TweenService:Create(
        self._hud,
        TweenInfo.new(inDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = boosted }
    )
    inTween:Play()
    inTween.Completed:Connect(function()
        TweenService:Create(
            self._hud,
            TweenInfo.new(outDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            { Size = base }
        ):Play()
    end)
end

--------------------------------------------------------------------------------
-- HEALTH TRACKING
--------------------------------------------------------------------------------
function SelfHealthbar:_onHealthChanged(newHP, maxHP)
    if self._lastHealth == nil then
        self._lastHealth = newHP
        if self.config.DEBUG_HEALTH then
            print(("[SelfHealthbar] Initial HP: %.1f / %.1f"):format(newHP, maxHP))
        end
        return
    end

    local delta = newHP - self._lastHealth
    local old   = self._lastHealth
    self._lastHealth     = newHP
    self._lastChangeTime = os.clock()
    self._lastFullHPTime = nil

    if self.config.DEBUG_HEALTH then
        print(("[SelfHealthbar] HP %.1f -> %.1f  (delta %+.1f, max %.1f)")
            :format(old, newHP, delta, maxHP))
    end

    if math.abs(delta) < 0.01 then return end

    table.insert(self._recentChanges, { t = os.clock(), delta = delta })
    while #self._recentChanges > self.config.DPS_MAX_EVENTS do
        table.remove(self._recentChanges, 1)
    end

    self._currentAlpha = math.min(self._currentAlpha, self.config.OPACITY_MIN + 0.05)

    local cfg = self.config
    if delta < 0 and cfg.SHAKE_ON_DAMAGE then
        self:_triggerShake(math.abs(delta))
    elseif delta > 0 and cfg.SHAKE_ON_HEAL then
        self:_triggerShake(math.abs(delta))
    end

    self:_triggerPulse(delta, maxHP)
    self:_spawnIndicator(delta)
end

function SelfHealthbar:_hookCharacter(char)
    -- Disconnect the previous character's HealthChanged, if any
    if self._charConn then
        pcall(function() self._charConn:Disconnect() end)
        self._charConn = nil
    end

    self._character = char
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then
        if self.config.DEBUG_HEALTH then
            warn("[SelfHealthbar] No Humanoid found in character")
        end
        return
    end

    self._humanoid      = hum
    self._lastHealth    = hum.Health
    self._recentChanges = {}
    self._lastChangeTime = os.clock()
    self._lastFullHPTime = nil

    if self.config.DEBUG_HEALTH then
        print(("[SelfHealthbar] Hooked %s — HP %.1f / %.1f")
            :format(char.Name, hum.Health, hum.MaxHealth))
    end

    self._charConn = hum.HealthChanged:Connect(function(hp)
        self:_onHealthChanged(hp, hum.MaxHealth)
    end)
end

--------------------------------------------------------------------------------
-- DPS/HPS COMPUTATION
--------------------------------------------------------------------------------
function SelfHealthbar:_computeRate(now)
    local cfg = self.config
    local mode = cfg.DPS_MODE

    local keepTime = math.max(cfg.DPS_WINDOW, cfg.DPS_DECAY_TIME)
    while #self._recentChanges > 0 and now - self._recentChanges[1].t > keepTime do
        table.remove(self._recentChanges, 1)
    end

    if mode == "Instant" then
        if #self._recentChanges == 0 then return 0 end
        local last = self._recentChanges[#self._recentChanges]
        local age = now - last.t
        if age >= cfg.DPS_DECAY_TIME then return 0 end
        return last.delta * (1 - age / cfg.DPS_DECAY_TIME)
    end

    if mode == "Weighted" then
        local sum = 0
        for _, e in ipairs(self._recentChanges) do
            local age = now - e.t
            if age < cfg.DPS_DECAY_TIME then
                sum = sum + e.delta * (1 - age / cfg.DPS_DECAY_TIME)
            end
        end
        return sum
    end

    -- "Average"
    local sum = 0
    for _, e in ipairs(self._recentChanges) do
        if now - e.t <= cfg.DPS_WINDOW then sum = sum + e.delta end
    end
    return sum / math.max(cfg.DPS_WINDOW, 1)
end

--------------------------------------------------------------------------------
-- PUBLIC: update
--------------------------------------------------------------------------------
function SelfHealthbar:update()
    local now = os.clock()
    local hum = self._humanoid
    if not hum or hum.Health <= 0 then
        self._hud.GroupTransparency = 1
        return
    end

    local cfg = self.config
    local hp    = hum.Health
    local maxHP = math.max(hum.MaxHealth, 1)
    local pct   = clamp(hp / maxHP, 0, 1)

    -- ─── Progression ─────────────────────────────────────────────────
    local mode = cfg.PROGRESSION
    if mode == "Both" then
        self._bar.AnchorPoint = Vector2.new(0.5, 0.5)
        self._bar.Position    = UDim2.new(0.5, 0, 0.5, 0)
    elseif mode == "Right" then
        self._bar.AnchorPoint = Vector2.new(0, 0.5)
        self._bar.Position    = UDim2.new(0.5, -self._barWidthPx / 2, 0.5, 0)
    elseif mode == "Left" then
        self._bar.AnchorPoint = Vector2.new(1, 0.5)
        self._bar.Position    = UDim2.new(0.5, self._barWidthPx / 2, 0.5, 0)
    end

    -- ─── Fill / ring ─────────────────────────────────────────────────
    if cfg.CIRCULAR_ENABLED then
        local N = cfg.CIRCULAR_SEGMENTS
        local litCount = math.floor(N * pct + 0.5)
        local fillColor = self:_resolveFillColor(pct)
        for i, seg in ipairs(self._ringSegments) do
            if i <= litCount then
                seg.BackgroundColor3       = fillColor
                seg.BackgroundTransparency = 0
            else
                seg.BackgroundColor3       = cfg.CIRCULAR_UNFILLED_COLOR
                seg.BackgroundTransparency = cfg.CIRCULAR_UNFILLED_TRANSPARENCY
            end
        end
    else
        self._bar.Size = UDim2.fromOffset(self._barWidthPx * pct, self._barHeightPx)
        local fillColor = self:_resolveFillColor(pct)
        self._bar.BackgroundColor3 = fillColor
        self._stroke.Color         = self:_resolveBorderColor(pct, fillColor)
    end

    -- ─── Text ────────────────────────────────────────────────────────
    if cfg.TEXT_ENABLED then
        local tl = self._textLabel
        tl.Visible = true
        tl.Text    = self:_formatText(hp, maxHP, pct)

        local fillC = cfg.TEXT_COLOR_AUTO and self:_autoFillColor(pct) or cfg.TEXT_COLOR
        tl.TextColor3 = fillC

        local strokeC = cfg.TEXT_STROKE_COLOR_AUTO and fillC or cfg.TEXT_STROKE_COLOR
        if self._textUIStroke then
            self._textUIStroke.Color = strokeC
        else
            tl.TextStrokeColor3 = strokeC
        end
    else
        self._textLabel.Visible = false
    end

    -- ─── DPS/HPS ─────────────────────────────────────────────────────
    if cfg.DPS_ENABLED then
        local rate = self:_computeRate(now)
        local rounded = math.floor(math.abs(rate) * 10 + 0.5) / 10
        if rounded < cfg.DPS_THRESHOLD then
            self._dpsLabel.Visible = false
        else
            self._dpsLabel.Visible = true
            if rate < 0 then
                self._dpsLabel.Text       = string.format("%.1f DPS", rounded)
                self._dpsLabel.TextColor3 = cfg.DPS_DAMAGE_COLOR
            else
                self._dpsLabel.Text       = string.format("%.1f HPS", rounded)
                self._dpsLabel.TextColor3 = cfg.DPS_HEAL_COLOR
            end
        end
    else
        self._dpsLabel.Visible = false
    end

    -- ─── Dynamic opacity ─────────────────────────────────────────────
    if cfg.ALWAYS_VISIBLE then
        self._hud.GroupTransparency = cfg.ALWAYS_VISIBLE_ALPHA
    elseif cfg.OPACITY_ENABLED then
        local targetAlpha
        if pct >= 0.999 then
            if not self._lastFullHPTime then self._lastFullHPTime = now end
            if now - self._lastFullHPTime > cfg.OPACITY_FULL_HP_DELAY then
                targetAlpha = cfg.OPACITY_FULL_HP_TRANSPARENCY
            else
                targetAlpha = cfg.OPACITY_MIN
            end
        else
            self._lastFullHPTime = nil
            local idle = now - self._lastChangeTime
            if idle < cfg.OPACITY_IDLE_FADE_START then
                targetAlpha = cfg.OPACITY_MIN
            else
                local span = math.max(
                    cfg.OPACITY_IDLE_FADE_END - cfg.OPACITY_IDLE_FADE_START,
                    1e-3
                )
                local prog = clamp((idle - cfg.OPACITY_IDLE_FADE_START) / span, 0, 1)
                targetAlpha = lerp(cfg.OPACITY_MIN, cfg.OPACITY_MAX_IDLE_FADE, prog)
            end
        end

        -- dt is approximated by the interval passed to update()
        local dt = self._lastDt or (1 / 60)
        local rate = (targetAlpha < self._currentAlpha)
            and cfg.OPACITY_FADE_IN_RATE
            or  cfg.OPACITY_FADE_OUT_RATE
        self._currentAlpha = self._currentAlpha
            + (targetAlpha - self._currentAlpha) * math.min(dt * rate, 1)
        self._hud.GroupTransparency = clamp(self._currentAlpha, 0, 1)
    else
        self._hud.GroupTransparency = 0
    end
end

-- Internal wrapper that computes dt before calling update()
function SelfHealthbar:_tick()
    local now = os.clock()
    self._lastDt = now - (self._lastTick or now)
    self._lastTick = now

    local cfg = self.config
    if cfg.UPDATE_INTERVAL > 0 then
        if now - self._lastUpdate < cfg.UPDATE_INTERVAL then return end
        self._lastUpdate = now
    end

    self:update()
end

--------------------------------------------------------------------------------
-- PUBLIC: lifecycle
--------------------------------------------------------------------------------
function SelfHealthbar:start()
    if self._running then return end
    self._running = true
    self._lastTick = os.clock()

    -- Cursor tracking
    self:_track(UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if not self.config.FOLLOW_CURSOR then return end
            self._root.Position = UDim2.new(
                0, input.Position.X + self.config.CURSOR_OFFSET_X,
                0, input.Position.Y + self.config.CURSOR_OFFSET_Y
            )
        end
    end))

    -- Initial cursor placement
    local m = UserInputService:GetMouseLocation()
    self._root.Position = UDim2.new(
        0, m.X + self.config.CURSOR_OFFSET_X,
        0, m.Y + self.config.CURSOR_OFFSET_Y
    )

    -- Character lifecycle
    if LocalPlayer.Character then
        self:_hookCharacter(LocalPlayer.Character)
    end
    self:_track(LocalPlayer.CharacterAdded:Connect(function(char)
        self:_hookCharacter(char)
    end))

    -- Viewport changes
    self:_track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        self:_recomputeBaseSize()
    end))

    -- Update loop
    self:_track(RunService.RenderStepped:Connect(function()
        if not self._running then return end
        self:_tick()
    end))

    -- Kill keybind (optional)
    if self.config.KILL_KEYBIND then
        self:_track(UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == self.config.KILL_KEYBIND then
                self:stop()
            end
        end))
    end
end

function SelfHealthbar:stop()
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

    if self._charConn then
        pcall(function() self._charConn:Disconnect() end)
        self._charConn = nil
    end

    if self._gui then
        pcall(function() self._gui:Destroy() end)
        self._gui = nil
    end
end

function SelfHealthbar:destroy()
    self:stop()
end

function SelfHealthbar:setConfig(partial)
    if not partial then return end
    local circularChanged = false

    for k, v in pairs(partial) do
        self.config[k] = v
        if k == "CIRCULAR_ENABLED" or k == "CIRCULAR_RADIUS"
            or k == "CIRCULAR_SEGMENTS" or k == "CIRCULAR_SEG_WIDTH"
            or k == "CIRCULAR_SEG_OVERLAP" or k == "CIRCULAR_ROUND_ENDS"
            or k == "CIRCULAR_START_ANGLE" or k == "CIRCULAR_CLOCKWISE"
        then
            circularChanged = true
        end
    end

    if circularChanged then
        self:_rebuildCircular()
    end

    -- Reflow layout with any new dimensions
    self:_recomputeBaseSize()
end

function SelfHealthbar:isRunning()
    return self._running
end

return SelfHealthbar
