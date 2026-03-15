--[[
    Название плагина: AntiMell
    Автор: Feeloner
    Описание: AntiRotate system based on Lua. Created for Cuberite servers to prevent suspicious player rotations.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
-- ]]

local ROTATION_THRESHOLD = 90      -- Max rotation angel per tick (degrees)
local MIN_ROTATION_DELTA = 0.01    -- Minimal rotation delta to ignore micro-movements (degrees)
local MIN_TIME_BETWEEN_ROTATES = 0.05 -- Minimal time between rotations to prevent bot-like behavior (seconds)

local LastRotations = {}

local AdvancedAntiRotateConfig = {
    MaxYawPerTick = 90,             -- Max Yaw angle per tick
    MaxPitchPerTick = 90,           -- Max Pitch angle per tick
    MaxYawPerSecond = 360,          -- Max Yaw angle per second
    MaxPitchPerSecond = 360,        -- Max Pitch angle per second
    MinRotationDelta = 0.01,        -- Min rotation delta (ignore micro-movements)
    MinTimeBetweenRotates = 0.05,   -- Min time between rotations (seconds)
    MaxViolations = 3,              
    ViolationDecay = 2,             
    Allow180QuickTurn = true,      
    AllowMouseFlick = true,   
    IgnoreCreative = false,
    IgnoreOps = false,
    EnableYawCheck = true,
    EnablePitchCheck = true,
    CustomViolationHandler = nil,
    Debug = false,
}

local PlayerViolations = {}

local function IsSuspiciousRotation(dYaw, dPitch, dTime, config)
    if dYaw < config.MinRotationDelta and dPitch < config.MinRotationDelta then
        return false
    end

  
    if dTime < 0.005 and (dYaw > 5 or dPitch > 5) then
        return true
    end

   
    if (config.EnableYawCheck and dYaw > config.MaxYawPerTick) or
       (config.EnablePitchCheck and dPitch > config.MaxPitchPerTick) then
        if config.Allow180QuickTurn and (math.abs(dYaw - 180) < 2 or math.abs(dPitch - 180) < 2) then
            return false
        end
        return true
    end

    if dTime > 0 then
        if (config.EnableYawCheck and (dYaw / dTime) > config.MaxYawPerSecond) or
           (config.EnablePitchCheck and (dPitch / dTime) > config.MaxPitchPerSecond) then
            return true
        end
    end

    if dTime < config.MinTimeBetweenRotates and (dYaw > 10 or dPitch > 10) then
        return true
    end

    return false
end

local function DecayViolations(UUID)
    if PlayerViolations[UUID] then
        PlayerViolations[UUID].Count = 0
        PlayerViolations[UUID].LastTime = os.clock()
    end
end
AntiRotateConfig = {
    RotationThreshold = ROTATION_THRESHOLD,
    MinRotationDelta = MIN_ROTATION_DELTA,
    MinTimeBetweenRotates = MIN_TIME_BETWEEN_ROTATES,
    -- Дополнительные настройки:
    EnableYawCheck = true,           -- Yaw delta check
    EnablePitchCheck = true,         -- Pitch delta check
    MaxYawPerTick = 90,              -- Max Yaw angle per tick
    IgnoreCreative = false,          
    IgnoreOps = false,               
    CustomViolationHandler = nil,    
    Debug = false,                   
    -- U can add other settings here as needed
}
function SetAntiRotateConfig(newConfig)
    for k, v in pairs(newConfig) do
        AntiRotateConfig[k] = v
    end
end

function GetAntiRotateConfig()
    local copy = {}
    for k, v in pairs(AntiRotateConfig) do
        copy[k] = v
    end
    return copy
end

function OnPlayerMoving(Player)
    local UUID = Player:GetUUID()
    local CurTime = os.clock()
    local Yaw, Pitch = Player:GetYaw(), Player:GetPitch()

    if not LastRotations[UUID] then
        LastRotations[UUID] = {Yaw = Yaw, Pitch = Pitch, Time = CurTime}
        return
    end

    local Last = LastRotations[UUID]
    local dYaw = math.abs(Yaw - Last.Yaw)
    local dPitch = math.abs(Pitch - Last.Pitch)
    local dTime = CurTime - Last.Time

    if dYaw < MIN_ROTATION_DELTA and dPitch < MIN_ROTATION_DELTA then
        return
    end

    if (dYaw > ROTATION_THRESHOLD or dPitch > ROTATION_THRESHOLD) or (dTime < MIN_TIME_BETWEEN_ROTATES and (dYaw > 10 or dPitch > 10)) then
        Player:TeleportToCoords(Player:GetPosX(), Player:GetPosY(), Player:GetPosZ(), Last.Yaw, Last.Pitch)
        Player:SendMessageFailure("§c[AntiRotate] Подозрительный поворот заблокирован!")
        return true 
    end

    LastRotations[UUID] = {Yaw = Yaw, Pitch = Pitch, Time = CurTime}
end

function OnPlayerDestroyed(Player)
    LastRotations[Player:GetUUID()] = nil
end

-- Register hooks (make sure cPluginManager is available)
if cPluginManager then
    cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_MOVING, OnPlayerMoving)
    cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_DESTROYED, OnPlayerDestroyed)
else
    LOGWARNING("[AntiRotate] cPluginManager is not available. Hooks not registered.")
end