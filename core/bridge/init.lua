--[[
    DPS-Parking - Bridge Initialization
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Framework detection and initialization.
    All framework-specific code goes through Bridge.
]]

Bridge = {}
Bridge.Framework = nil
Bridge.Core = nil
Bridge.Ready = false

-- Supported frameworks
Bridge.Frameworks = {
    QB = 'qb',
    QBX = 'qbx',
    ESX = 'esx'
}

-- ============================================
-- FRAMEWORK DETECTION
-- ============================================

-- Build a QB/QBX-compatible core wrapper from DISCRETE exports.
-- IMPORTANT: qbx_core (and qb-core on this build) throw on GetCoreObject().
-- We never call GetCoreObject(); instead we wrap the individual exports so the
-- rest of the code can keep using Bridge.Core.Functions.* transparently.
---@param resourceName string
---@return table
local function BuildQBCore(resourceName)
    if IsDuplicityVersion() then
        -- Server context
        return {
            Functions = {
                GetPlayer = function(src) return exports[resourceName]:GetPlayer(src) end,
                GetPlayerByCitizenId = function(cid) return exports[resourceName]:GetPlayerByCitizenId(cid) end,
                GetPlayers = function() return exports[resourceName]:GetQBPlayers() end,
            }
        }
    else
        -- Client context
        return {
            Functions = {
                GetPlayerData = function() return exports[resourceName]:GetPlayerData() end,
            }
        }
    end
end

local function DetectFramework()
    if GetResourceState('qbx_core') == 'started' then
        Bridge.Framework = Bridge.Frameworks.QBX
        Bridge.Core = BuildQBCore('qbx_core')
        return true
    elseif GetResourceState('qb-core') == 'started' then
        Bridge.Framework = Bridge.Frameworks.QB
        Bridge.Core = BuildQBCore('qb-core')
        return true
    elseif GetResourceState('es_extended') == 'started' then
        Bridge.Framework = Bridge.Frameworks.ESX
        Bridge.Core = exports['es_extended']:getSharedObject()
        return true
    end
    return false
end

-- ============================================
-- INITIALIZATION
-- ============================================

CreateThread(function()
    local attempts = 0
    local maxAttempts = 50 -- 5 seconds
    local detected = false

    while not detected and attempts < maxAttempts do
        -- Wrap in pcall so a throwing export (e.g. GetCoreObject on this build)
        -- can never kill this thread and leave Bridge.Ready stuck false forever.
        local ok, result = pcall(DetectFramework)
        if not ok then
            print(('^1[DPS-Parking] Framework detection error: %s^0'):format(tostring(result)))
        elseif result then
            detected = true
            break
        end
        Wait(100)
        attempts = attempts + 1
    end

    if not Bridge.Framework then
        print('^1[DPS-Parking] ERROR: No supported framework detected!^0')
        print('^1[DPS-Parking] Supported: qb-core, qbx_core, es_extended^0')
        return
    end

    Bridge.Ready = true
    print(('^2[DPS-Parking] Framework detected: %s^0'):format(Bridge.Framework:upper()))

    -- Publish framework ready event
    if EventBus then
        EventBus.Publish('bridge:ready', { framework = Bridge.Framework })
    end
end)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

---Check if bridge is ready
---@return boolean
function Bridge.IsReady()
    return Bridge.Ready and Bridge.Framework ~= nil and Bridge.Core ~= nil
end

---Wait for bridge to be ready
function Bridge.WaitReady()
    while not Bridge.IsReady() do
        Wait(100)
    end
end

---Get framework name
---@return string|nil
function Bridge.GetFramework()
    return Bridge.Framework
end

---Check if using QB-based framework
---@return boolean
function Bridge.IsQB()
    return Bridge.Framework == Bridge.Frameworks.QB or Bridge.Framework == Bridge.Frameworks.QBX
end

---Check if using ESX
---@return boolean
function Bridge.IsESX()
    return Bridge.Framework == Bridge.Frameworks.ESX
end

---Check if using QBX
---@return boolean
function Bridge.IsQBX()
    return Bridge.Framework == Bridge.Frameworks.QBX
end

-- ============================================
-- RESOURCE DETECTION
-- ============================================

Bridge.Resources = {}

function Bridge.Resources.Exists(name)
    return GetResourceState(name) == 'started'
end

function Bridge.Resources.HasOxLib()
    return Bridge.Resources.Exists('ox_lib')
end

function Bridge.Resources.HasOxTarget()
    return Bridge.Resources.Exists('ox_target')
end

function Bridge.Resources.HasQBTarget()
    return Bridge.Resources.Exists('qb-target')
end

function Bridge.Resources.GetTarget()
    if Config and Config.Integration and Config.Integration.target then
        return Config.Integration.target
    end
    if Bridge.Resources.HasOxTarget() then
        return 'ox_target'
    elseif Bridge.Resources.HasQBTarget() then
        return 'qb-target'
    end
    return nil
end

function Bridge.Resources.GetFuel()
    local fuelScripts = {'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'qs-fuelstations'}
    for _, script in ipairs(fuelScripts) do
        if Bridge.Resources.Exists(script) then
            return script
        end
    end
    return nil
end

function Bridge.Resources.GetVehicleKeys()
    if Config and Config.Integration and Config.Integration.vehicleKeys then
        return Config.Integration.vehicleKeys
    end
    local keyScripts = {'qs-vehiclekeys', 'qb-vehiclekeys', 'qbx_vehiclekeys', 'wasabi_carlock'}
    for _, script in ipairs(keyScripts) do
        if Bridge.Resources.Exists(script) then
            return script
        end
    end
    return nil
end

return Bridge
