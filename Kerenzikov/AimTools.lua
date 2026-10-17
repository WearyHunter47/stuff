--[[
    Kerenzikov — AimTools Module
    Handles Noclip Cam, penetrating Aim Raycasts, and X-Ray fading.
    Publishes valid targets to getgenv().ModuleBus.ViewLines.ValidTarget
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

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
    AIM_MAX_PENETRATIONS  = 15,     
    IGNORE_NO_COLLISION   = false,  
    MARK_THROUGH_WALLS    = false,  -- If true, marks targets even behind walls

    -- X-Ray
    XRAY_ENABLED          = true,
    XRAY_TARGET_TRANSPARENCY = 0.5, 
    XRAY_PREV_TRANSPARENCY   = 0.95,
    XRAY_FORCEFIELD          = false, 

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

    self._modifiedParts = {} 
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
    for part, data in pairs(self._modifiedParts) do
        if part and part.Parent then
            -- Restore original transparency modifier
            part.LocalTransparencyModifier = data.Transparency
            if self.config.XRAY_FORCEFIELD then
                pcall(function() part.Material = data.Material end)
            end
        end
    end
    self._modifiedParts = {}
end

function AimTools:_fadePart(part, transparency, applyForceField)
    if not part or not part.Parent then return end
    
    -- Save original state so we can restore it later
    if not self._modifiedParts[part] then
        self._modifiedParts[part] = {
            Material = part.Material,
            Transparency = part.LocalTransparencyModifier
        }
    end

    -- LocalTransparencyModifier is client-side only and won't replicate
    part.LocalTransparencyModifier = transparency
    if applyForceField then
        pcall(function() part.Material = Enum.Material.ForceField end)
    end
end

function AimTools:_updateNoclip(Camera)
    if not self.config.NOCLIP_ENABLED or not Camera then return end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local filter = {}
    if LocalPlayer.Character then
        table.insert(filter, LocalPlayer.Character)
    end
    overlapParams.FilterDescendantsInstances = filter

    local parts = workspace:GetPartBoundsInRadius(
        Camera.CFrame.Position, 
        self.config.NOCLIP_RADIUS, 
        overlapParams
    )

    for _, part in ipairs(parts) do
        self:_fadePart(part, self.config.NOCLIP_TRANSPARENCY, false)
    end
end

function AimTools:_updateAim(Camera)
    local cfg = self.config
    local bus = getgenv().ModuleBus
    
    if not bus or not bus.ViewLines then return end
    bus.ViewLines.ValidTarget = bus.ViewLines.ValidTarget or {}
    
    if not cfg.AIM_RAYCAST_ENABLED or not Camera then
        table.clear(bus.ViewLines.ValidTarget)
        return
    end

    local rayOrigin = Camera.CFrame.Position
    local rayDir = Camera.CFrame.LookVector
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local filter = {}
    if LocalPlayer.Character then
        table.insert(filter, LocalPlayer.Character)
    end
    params.FilterDescendantsInstances = filter
    
    -- 🛠️ FIX: RespectCanCollide MUST be false to hit player limbs (which are CanCollide=false)
    params.RespectCanCollide = false 

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
        
        -- Robust player detection
        local hitPlayer = nil
        local current = hitPart
        while current and current ~= workspace do
            if current:IsA("Model") then
                local p = Players:GetPlayerFromCharacter(current)
                if p then
                    hitPlayer = p
                    break
                end
            end
            current = current.Parent
        end

        if hitPlayer and hitPlayer ~= LocalPlayer then
            targetPlayer = hitPlayer
            break
        end

        -- Blocked by something else, add to obstructions
        table.insert(obstructions, hitPart)
        table.insert(params.FilterDescendantsInstances, hitPart)
        
        rayOrigin = hit.Position + rayDir * 0.1
    end

    -- Clear ValidTarget states without replacing the table reference
    table.clear(bus.ViewLines.ValidTarget)

    if targetPlayer then
        -- If MARK_THROUGH_WALLS is true, we ignore obstructions for the tag
        local isValid = self.config.MARK_THROUGH_WALLS or (#obstructions == 0)
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
    -- 🛠️ FIX: Update Camera reference dynamically
    local Camera = workspace.CurrentCamera
    if not Camera then return end

    self:_resetParts()
    
    -- 🛠️ FIX: Wrap in pcall so an error in Aim doesn't break the RenderStepped loop
    local ok1 = pcall(function() self:_updateNoclip(Camera) end)
    local ok2 = pcall(function() self:_updateAim(Camera) end)
    
    -- If you want to see errors, uncomment the lines below:
    -- if not ok1 then warn("Noclip Error") end
    -- if not ok2 then warn("Aim Error") end
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
