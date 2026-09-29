--[[
    Master Loader — ViewLines + ESP + (future Healthbar)
    Run this. It creates the shared bus and boots all child modules.

    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/you/repo/main/loader.lua"))()
]]

local Players = game:GetService("Players")

--------------------------------------------------------------------------------
-- SHARED BUS
-- Child modules read/write here. Healthbar can be added later without
-- touching the other modules.
--------------------------------------------------------------------------------
getgenv().ModuleBus = {
    ViewLines = {
        Hit = {},         -- [Player] = boolean  (look beam hitting you)
        Visibility = {},  -- [Player] = number   (sight beam fraction 0-1)
        Active = false,   -- true once ViewLines is running
    },
    ESP = {
        Active = false,
    },
    -- Healthbar = { ... }  -- add later
}

--------------------------------------------------------------------------------
-- LOAD MODULES
--------------------------------------------------------------------------------
local VL_URL  = "https://raw.githubusercontent.com/WearyHunter47/stuff/refs/heads/main/LoSD"
local ESP_URL = "https://raw.githubusercontent.com/WearyHunter47/stuff/refs/heads/main/ESP.lua"

local ViewLines = loadstring(game:HttpGet(VL_URL))()
local ESP       = loadstring(game:HttpGet(ESP_URL))()

--------------------------------------------------------------------------------
-- CONFIGURE + START
--------------------------------------------------------------------------------
local viewlines = ViewLines.new({
    KILL_KEYBIND = nil,           -- master owns the kill switch
    FOV_DEGREES  = 120,
    TEAM_CHECK   = true,
})

local esp = ESP.new({
    -- Existing ESP config
    ESPEnabled         = true,
    ESPShowText        = true,
    ESPTextSize        = 13,
    ESPMaxDistance     = 500,
    ESPUseDistanceLimit = true,
    ESPUseTeamColor    = true,
    ESPFriendColor     = true,

    -- ViewLines integration (new)
    INTEGRATION_ENABLED = true,

    -- Highlight fill transparency by state
    HL_BASE_TRANSPARENCY    = 0.7,   -- nobody looking
    HL_SIGHT_TRANSPARENCY   = 0.4,   -- sight beam detects you
    HL_LOOK_TRANSPARENCY    = 0.1,   -- look beam on you

    -- Nametag opacity by state
    NT_ALPHA_BASE           = 0.6,
    NT_ALPHA_SIGHT          = 0.3,
    NT_ALPHA_LOOK           = 0.0,

    -- Nametag size by state
    NT_SIZE_BASE            = 13,
    NT_SIZE_SIGHT           = 16,
    NT_SIZE_LOOK            = 20,

    -- Bold only when look beam hits
    NT_BOLD_ON_LOOK         = true,

    -- Camera-center proximity opacity (overrides everything)
    CENTER_OVERRIDE_ENABLED = true,
    CENTER_FALLOFF_DEGREES  = 45,    -- beyond this angle, no center boost
    CENTER_MAX_ALPHA        = 0.0,   -- fully opaque at exact center
})

viewlines:start()
esp:start()

getgenv().ModuleBus.ViewLines.Active = true
getgenv().ModuleBus.ESP.Active = true

--------------------------------------------------------------------------------
-- GLOBAL KILL SWITCH (F10)
--------------------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local killConn = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F10 then
        esp:stop()
        viewlines:stop()
        getgenv().ModuleBus = nil
        killConn:Disconnect()
        print("[Master] All modules stopped.")
    end
end)

print("[Master] ViewLines + ESP loaded. F10 to kill everything.")
