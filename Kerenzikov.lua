--[[ 
>> Kerenzikov V1.0
   Configs below.
]]

--------------------------------------------------------------------------------
-- MODULE SOURCES
--------------------------------------------------------------------------------
local VL_URL  = "https://raw.githubusercontent.com/WearyHunter47/stuff/refs/heads/main/LoSD"
local ESP_URL = "https://raw.githubusercontent.com/WearyHunter47/stuff/refs/heads/main/ESP.lua"
local HB_URL  = "https://raw.githubusercontent.com/WearyHunter47/stuff/refs/heads/main/Healthbar.lua"

--------------------------------------------------------------------------------
-- SHARED NAME FORMATTING (both modules read these values)
-- Change NAME_MODE to "Username", "DisplayName", or "Both" to control the
-- name field rendered in the SEI edge arrows AND the self-HUD view list.
-- Truncation lengths are independent: usernames and display names each get
-- their own cap. 0 = no truncation for that field.
--------------------------------------------------------------------------------
local NAME_MODE                 = "DisplayName"
local NAME_TRUNCATE_USERNAME    = 8
local NAME_TRUNCATE_DISPLAYNAME = 8
--------------------------------------------------------------------------------
-- CONFIG — EDIT EVERYTHING HERE
--------------------------------------------------------------------------------
local CONFIG = {

    -- ─── ViewLines ────────────────────────────────────────────────────────
    ViewLines = {
        -- FOV + sampling
        FOV_DEGREES = 120,
        SAMPLE_PARTS = {
            "Head",
            "UpperTorso", "LowerTorso", "Torso",
            "LeftUpperArm", "RightUpperArm",
            "Left Arm",     "Right Arm",
        },

        -- Sight beam (viewer head → my root)
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
        LOOK_RANGE              = 150,
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
        KILL_KEYBIND    = nil,   -- master owns the kill switch

        -- Edge indicators (SEI)
        EDGE_INDICATORS     = true,
        EDGE_INDICATOR_MODE = "Always",   -- "Aimed" | "Visible" | "Always"
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
    },

    -- ─── ESP ──────────────────────────────────────────────────────────────
    ESP = {
        -- Core toggles
        ESPEnabled          = true,
        ESPShowText         = true,
        ESPTextSize         = 11,
        ESPMaxDistance      = 500,
        ESPUseDistanceLimit = true,
        ESPUseTeamColor     = true,
        ESPFriendColor      = true,

        ESPWhitelist = {},
        ESPBlacklist = {},

        -- Name format: "Horizontal" or "Vertical"
        ESP_NAME_FORMAT = "Vertical",
        ESP_NAME_WIDTH   = 100,
        ESP_ANCHOR_PART  = "HumanoidRootPart",
        ESP_STUDS_OFFSET = Vector3.new(0, 2, 0),

        -- ViewLines integration
        INTEGRATION_ENABLED = true,
        SIGHT_THRESHOLD     = 0.1,

        -- Highlight fill transparency by state
        HL_BASE_TRANSPARENCY  = 0.9,
        HL_SIGHT_TRANSPARENCY = 0.4,
        HL_LOOK_TRANSPARENCY  = 0.1,

        -- Nametag positioning
        NT_OFFSET_X     = 0,
        NT_OFFSET_Y     = -20,
        NT_LINE_SPACING = -5,

        -- Hide HP in the nametag sub-line when the bar shows its own number
        NT_HIDE_HP_IF_BAR_TEXT = true,

        -- Healthbar color sources
        HB_USE_TEAM_COLOR_FILL = true,
        HB_USE_TEAM_COLOR_TEXT = false,

        -- Low-HP override
        HB_LOWHP_OVERRIDE_ENABLED = true,
        HB_LOWHP_THRESHOLD        = 0.33,
        HB_LOWHP_FILL_TOP         = Color3.fromRGB(255, 0, 0),
        HB_LOWHP_FILL_BOTTOM      = Color3.fromRGB(0, 0, 0),
        HB_LOWHP_TEXT_TOP         = Color3.fromRGB(255, 120, 120),
        HB_LOWHP_TEXT_BOTTOM      = Color3.fromRGB(180, 0, 0),

        -- Nametag opacity by state
        NT_ALPHA_BASE  = 0.6,
        NT_ALPHA_SIGHT = 0.3,
        NT_ALPHA_LOOK  = 0.0,

        -- Nametag size by state (fixed pixels; never scaled)
        NT_SIZE_BASE  = 11,
        NT_SIZE_SIGHT = 14,
        NT_SIZE_LOOK  = 18,

        -- Bold nametag on look
        NT_BOLD_ON_LOOK = true,

        -- Camera-center override (applies to nametag AND healthbar)
        CENTER_OVERRIDE_ENABLED = true,
        CENTER_FALLOFF_DEGREES  = 45,
        CENTER_MAX_ALPHA        = 0.0,

        -- Screen-size scaling — HEALTHBAR ONLY
        SCALE_ENABLED          = true,
        SCALE_REFERENCE_HEIGHT = 140,
        SCALE_MIN              = 0.7,
        SCALE_MAX              = 1.5,

        -- ─── Healthbar geometry (pre-scale; multiplied by the scale) ──────
        HB_ENABLED           = true,
        HB_STYLE             = "Figma",   -- "Simple" or "Figma"
        HB_POSITION          = "Left",    -- "Top" | "Bottom" | "Left" | "Right"
        HB_LENGTH            = 60,
        HB_THICKNESS         = 6,
        HB_GAP               = -10,

        HB_BG_COLOR          = Color3.fromRGB(20, 20, 20),
        HB_FILL_COLOR        = Color3.fromRGB(150, 150, 150),       -- nil = auto green→red gradient

        HB_ROUNDED           = false,
        HB_CORNER_RADIUS     = 3,

        HB_BORDER            = true,
        HB_BORDER_COLOR      = Color3.fromRGB(0, 0, 0),
        HB_BORDER_THICKNESS  = 1,

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

            BG_ENABLED      = false,
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

        -- ─── Healthbar DYNAMIC opacity (mirrors nametag pipeline) ────────
        HB_ALPHA_BASE  = 0.3,
        HB_ALPHA_SIGHT = 0.15,
        HB_ALPHA_LOOK  = 0.0,

        HB_BG_EXTRA_TRANSPARENCY     = 0.15,
        HB_NUMBER_EXTRA_TRANSPARENCY = 0.0,

        -- Static fallbacks (only used when INTEGRATION_ENABLED = false)
        HB_BG_TRANSPARENCY   = 0.2,
        HB_FILL_TRANSPARENCY = 0.0,
        HB_NUMBER_ALPHA      = 0.0,

        -- Healthbar number
        HB_SHOW_NUMBER       = true,
        HB_NUMBER_POSITION   = "Inside",   -- "Inside"|"Left"|"Right"|"Above"|"Below"
        HB_NUMBER_SIZE       = 13,
        HB_NUMBER_COLOR      = Color3.fromRGB(255, 255, 255),
        HB_NUMBER_SHOW_MAX   = true,       -- true → "75/100", false → "75"

        -- Master owns the kill switch
        KILL_KEYBIND    = nil,
        UPDATE_INTERVAL = 0,
    },

    -- ─── Healthbar (self HUD) ─────────────────────────────────────────────
        -- ─── Healthbar ────────────────────────────────────────────────────────
    Healthbar = {
        CURSOR_OFFSET_X = 0,
        CURSOR_OFFSET_Y = 60,
        FOLLOW_CURSOR   = true,

        BAR_WIDTH_SCALE  = 0.10,
        BAR_WIDTH_PX     = nil,
        BAR_HEIGHT_SCALE = 0.01,
        BAR_HEIGHT_PX    = 8,

        PAD_X       = 100,
        PAD_TOP     = 80,
        PAD_BOTTOM  = 60,

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

        LOWHP_OVERRIDE_ENABLED = true,
        LOWHP_THRESHOLD        = 0.30,
        LOWHP_FILL_TOP         = Color3.fromRGB(255, 0, 0),
        LOWHP_FILL_BOTTOM      = Color3.fromRGB(0, 0, 0),
        LOWHP_BORDER_TOP       = Color3.fromRGB(128, 0, 0),
        LOWHP_BORDER_BOTTOM    = Color3.fromRGB(0, 0, 0),

        TEXT_ENABLED        = true,
        TEXT_FORMAT         = "PCT", -- "HP" | "HPMAX" | "PCT" | "HP_PCT" | "HPMAX_PCT"
        TEXT_SIZE           = 13,
        TEXT_COLOR_AUTO     = true,
        TEXT_COLOR          = Color3.fromRGB(255, 255, 255),
        TEXT_TRANSPARENCY   = 0.1,

        TEXT_FONT         = Enum.Font.Gotham,
        TEXT_BOLD         = true,
        TEXT_LABEL_WIDTH  = 220,
        TEXT_WRAPPED      = false,

        TEXT_POSITION     = "Below",
        TEXT_POSITION_GAP = 4,
        TEXT_OFFSET_X     = 0,
        TEXT_OFFSET_Y     = 0,

        TEXT_STROKE_COLOR_AUTO   = false,
        TEXT_STROKE_COLOR        = Color3.fromRGB(0, 0, 0),
        TEXT_STROKE_TRANSPARENCY = 0.3,
        TEXT_STROKE_WIDTH        = 1,

        PROGRESSION = "Both",

        SHAKE_ENABLED       = true,
        SHAKE_INTENSITY     = 6,
        SHAKE_INTENSITY_PER_DMG = 0.3,
        SHAKE_MAX           = 18,
        SHAKE_DURATION      = 0.10,
        SHAKE_STYLE         = Enum.EasingStyle.Quad,
        SHAKE_DIRECTION     = Enum.EasingDirection.Out,
        SHAKE_ON_DAMAGE     = true,
        SHAKE_ON_HEAL       = true,

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

        DPS_ENABLED      = true,
        DPS_MODE         = "Weighted",
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

        -- Always-visible when low HP
        OPACITY_ALWAYS_VISIBLE_BELOW_ENABLED = false,
        OPACITY_ALWAYS_VISIBLE_BELOW_PCT     = 0.33,

        DEBUG_HEALTH = false,

        PULSE_ENABLED          = true,
        PULSE_DAMAGE_PER_HP    = 0.010,
        PULSE_HEAL_PER_HP      = 0.006,
        PULSE_MAX              = 0.40,
        PULSE_IN_DURATION      = 0.12,
        PULSE_OUT_DURATION     = 0.40,
        PULSE_HEAL_IN_DURATION = 0.35,
        PULSE_HEAL_OUT_DURATION = 0.70,

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

        -- ─── Shared name formatting ────────────────────────────────────
        NAME_MODE                 = NAME_MODE,
        NAME_TRUNCATE_USERNAME    = NAME_TRUNCATE_USERNAME,
        NAME_TRUNCATE_DISPLAYNAME = NAME_TRUNCATE_DISPLAYNAME,

        -- ─── View list ─────────────────────────────────────────────────
        VIEWLIST_ENABLED         = true,
        VIEWLIST_WIDTH_MULT      = 1.25,
        VIEWLIST_STACK_GAP       = 6,
        VIEWLIST_OFFSET_X        = 0,
        VIEWLIST_OFFSET_Y        = 0,
        VIEWLIST_MAX_ROWS        = 8,
        VIEWLIST_ROW_HEIGHT      = 16,

        -- Multi-column layout
        VIEWLIST_COLUMNS    = 2,
        VIEWLIST_COLUMN_GAP = 4,

        VIEWLIST_INCLUDE_SIGHT   = true,
        VIEWLIST_INCLUDE_LOOK    = true,
        VIEWLIST_INCLUDE_IDLE    = false,
        VIEWLIST_IDLE_MAX_DISTANCE = 100,

        VIEWLIST_SORT            = "Priority",
        VIEWLIST_COLOR_MODE      = "Team",
        VIEWLIST_FIXED_COLOR     = Color3.fromRGB(255, 255, 255),
        VIEWLIST_SIGHT_THRESHOLD = 0.1,

        VIEWLIST_PRIORITIZE_OFFSCREEN = true,   -- rank offscreen viewers above onscreen ones

        VIEWLIST_SIZE_SIGHT      = 12,
        VIEWLIST_SIZE_LOOK       = 14,
        VIEWLIST_SIZE_IDLE       = 10,
        VIEWLIST_BOLD_ON_LOOK    = true,

        VIEWLIST_ALPHA_BASE      = 0.65,
        VIEWLIST_ALPHA_SIGHT     = 0.30,
        VIEWLIST_ALPHA_LOOK      = 0.00,

        -- View list opacity
        VIEWLIST_OPACITY_MODE          = "Threat",  -- "Follow" | "Independent" | "Floor" | "Threat"
        VIEWLIST_OPACITY_STATIC        = 0.3,       -- Independent: fixed transparency
        VIEWLIST_OPACITY_FLOOR         = 0.4,       -- Floor: max transparency the list can reach
        VIEWLIST_OPACITY_THREAT_LOOK   = 0.0,       -- Threat: when a looker is present
        VIEWLIST_OPACITY_THREAT_SIGHT  = 0.3,       -- Threat: when only sight-viewers
        VIEWLIST_OPACITY_THREAT_IDLE   = 0.6,       -- Threat: when only idle-nearby


        VIEWLIST_PROXIMITY_ENABLED    = true,
        VIEWLIST_PROXIMITY_DISTANCE   = 100,
        VIEWLIST_PROXIMITY_NEAR_COLOR = Color3.fromRGB(255, 30, 30),
        VIEWLIST_PROXIMITY_FAR_COLOR  = Color3.fromRGB(255, 165, 0),

        VIEWLIST_EMPTY_TEXT  = "",
        VIEWLIST_EMPTY_COLOR = Color3.fromRGB(150, 150, 150),

        KILL_KEYBIND    = nil,
        UPDATE_INTERVAL = 0,
    },

    -- ─── Master (kill keybind)───────────────────────────────────────────────────────────
    MASTER = {
        KILL_KEYBIND = Enum.KeyCode.F10,
    },
}

--------------------------------------------------------------------------------
-- SHARED BUS
--------------------------------------------------------------------------------
getgenv().ModuleBus = {
    ViewLines = {
        Hit        = {},
        Visibility = {},
        Active     = false,
    },
    ESP = {
        Active = false,
    },
    Healthbar = {
        Active = false,
    },
}

--------------------------------------------------------------------------------
-- LOAD MODULES
--------------------------------------------------------------------------------
local ViewLines     = loadstring(game:HttpGet(VL_URL))()
local ESP           = loadstring(game:HttpGet(ESP_URL))()
local SelfHealthbar = loadstring(game:HttpGet(HB_URL))()

--------------------------------------------------------------------------------
-- BOOT
--------------------------------------------------------------------------------
local viewlines = ViewLines.new(CONFIG.ViewLines)
local esp       = ESP.new(CONFIG.ESP)
local healthbar = SelfHealthbar.new(CONFIG.Healthbar)

viewlines:start()
esp:start()
healthbar:start()

getgenv().ModuleBus.ViewLines.Active = true
getgenv().ModuleBus.ESP.Active       = true
getgenv().ModuleBus.Healthbar.Active = true

--------------------------------------------------------------------------------
-- MASTER KILL SWITCH
--------------------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local stopped = false
local killConn

killConn = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode ~= CONFIG.MASTER.KILL_KEYBIND then return end
    if stopped then return end
    stopped = true

    -- Disconnect our own listener first so no second F10 can re-enter.
    if typeof(killConn) == "RBXScriptConnection" then
        killConn:Disconnect()
    end

    -- Each stop is isolated: a failure in one module can't block the others.
    pcall(function() esp:stop() end)
    pcall(function() viewlines:stop() end)
    pcall(function() healthbar:stop() end)
    getgenv().ModuleBus = nil

    print("[Master] All modules stopped.")
end)

print(("[Master] ViewLines + ESP + Healthbar loaded. Press %s to kill everything.")
    :format(CONFIG.MASTER.KILL_KEYBIND.Name))
