--[[
    Kerenzikov — AimTools Module
    Handles Noclip Cam, penetrating Aim Raycasts, and X-Ray fading.
    Publishes valid targets to getgenv().ModuleBus.ViewLines.ValidTarget

    Features:
      • Noclip Cam: Fades parts intersecting the camera.
      • Aim Raycast: Casts up to 1000 studs, penetrating through walls.
      • X-Ray: Fades walls blocking the target.
      • Valid Target: Marks players if they are in direct line of sight.

    No side effects on require. No auto-start, no print, no global.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------
local DEFAULTS = {
    -- Noclip Cam
    NOCLIP_ENABLED        = true,
    NOCLIP_RADIUS         = 1.5,
    NOCLIP_TRANSPARENCY   = 0.5,

    -- Aim Raycast / Valid Target
    AIM_RAYCAST_ENABLED   = true,
    AIM_RANGE             = 1000,
    AIM_MAX_PENETRATIONS  = 15,     -- Max parts to pass through
    IGNORE_NO_COLLISION   = false,  -- If true, CanCollide=false parts are ignored

    -- X-Ray
    XRAY_ENABLED          = true,
    XRAY_TARGET_TRANSPARENCY = 0.5, -- The wall closest to the target
    XRAY_PREV_TRANSPARENCY   = 0.95,-- Walls before the closest one
    XRAY_FORCEFIELD          = false, -- If true, applies ForceField material to ghosted walls

    UPDATE_INTERVAL       = 0,
}

--------------------------------------------------------------------------------
-- MODULE
--------------------------------------------------------------------------------
local AimTools = {}
AimTools.__index = AimTools

function AimTools.new(overrides)
    local self = setmetatable({}, AimTools)
    self.config = {}
    for k, v in pairs(DEFAULTS) do self.config[k] = v end
    if overrides then
        for k, v in pairs(overrides) do self.config[k] = v end
    end

    self._modifiedParts = {} -- [BasePart] = original material
    self._connections = {}
    self._running = false
    self._lastUpdate = 0

    return self
end

function AimTools:_track(conn)
    self._connections[#self._connections + 1] = conn
    return conn
end

function AimTools:_resetParts()
    for part, originalMat in pairs(self._modifiedParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = 0
            if self.config.XRAY_FORCEFIELD then
                pcall(function() part.Material = originalMat end)
            end
        end
    end
    self._modifiedParts = {}
end

function AimTools:_fadePart(part, transparency, applyForceField)
    if not part or not part.Parent then return end
    
    -- Save original material if we're applying ForceField
    if applyForceField and not self._modifiedParts[part] then
        self._modifiedParts[part] = part.Material
    end

    -- LocalTransparencyModifier is client-side only and won't replicate
    part.LocalTransparencyModifier = transparency
    if applyForceField then
        pcall(function() part.Material = Enum.Material.ForceField end)
    end
end

function AimTools:_updateNoclip()
    if not self.config.NOCLIP_ENABLED or not Camera then return end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }

    local parts = workspace:GetPartBoundsInRadius(
        Camera.CFrame.Position, 
        self.config.NOCLIP_RADIUS, 
        overlapParams
    )

    for _, part in ipairs(parts) do
        self:_fadePart(part, self.config.NOCLIP_TRANSPARENCY, false)
    end
end

function AimTools:_updateAim()
    local cfg = self.config
    local bus = getgenv().ModuleBus
    
    if not bus or not bus.ViewLines then return end
    bus.ViewLines.ValidTarget = bus.ViewLines.ValidTarget or {}
    
    if not cfg.AIM_RAYCAST_ENABLED or not Camera then
        bus.ViewLines.ValidTarget = {}
        return
    end

    local rayOrigin = Camera.CFrame.Position
    local rayDir = Camera.CFrame.LookVector
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    params.RespectCanCollide = not cfg.IGNORE_NO_COLLISION

    local obstructions = {}
    local targetPlayer = nil
    local totalDist = 0

    -- Penetrating Raycast Loop
    for i = 1, cfg.AIM_MAX_PENETRATIONS do
        local remaining = cfg.AIM_RANGE - totalDist
        if remaining <= 0 then break end

        local hit = workspace:Raycast(rayOrigin, rayDir * remaining, params)
        if not hit then break end

        totalDist = totalDist + hit.Distance
        local hitPart = hit.Instance
        local hitChar = hitPart:FindFirstAncestorOfClass("Model")
        local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)

        if hitPlayer and hitPlayer ~= LocalPlayer then
            targetPlayer = hitPlayer
            break
        end

        -- Blocked by something else, add to obstructions
        table.insert(obstructions, hitPart)
        table.insert(params.FilterDescendantsInstances, hitPart)
        
        rayOrigin = hit.Position + rayDir * 0.1
    end

    -- Reset ValidTarget states for everyone else
    bus.ViewLines.ValidTarget = {}

    if targetPlayer then
        local isValid = (#obstructions == 0)
        bus.ViewLines.ValidTarget[targetPlayer] = isValid

        -- Apply X-Ray
        if cfg.XRAY_ENABLED and #obstructions > 0 then
            for j, part in ipairs(obstructions) do
                local trans = (j == #obstructions) 
                    and cfg.XRAY_TARGET_TRANSPARENCY 
                    or cfg.XRAY_PREV_TRANSPARENCY
                
                self:_fadePart(part, trans, cfg.XRAY_FORCEFIELD)
            end
        end
    end
end

function AimTools:update()
    self:_resetParts()
    self:_updateNoclip()
    self:_updateAim()
end

--------------------------------------------------------------------------------
-- LIFECYCLE
--------------------------------------------------------------------------------
function AimTools:start()
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
end

function AimTools:stop()
    if not self._running then return end
    self._running = false

    for i = #self._connections, 1, -1 do
        local c = self._connections[i]
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    self._connections = {}
    
    self:_resetParts()
end

return AimTools
