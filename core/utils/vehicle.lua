--[[
    DPS-Parking - Vehicle Data Utilities
    Comprehensive vehicle state serialization for robust persistence.

    Captures: Damage, fuel, mods, visual tuning, dirt, extras, and metadata.
]]

VehicleData = {}

-- ============================================
-- COMPREHENSIVE VEHICLE STATE CAPTURE
-- ============================================

---Get complete vehicle state for persistence
---@param vehicle number Entity handle
---@return table Complete vehicle data
function VehicleData.Serialize(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end

    local data = {
        -- Basic info
        model = GetEntityModel(vehicle),
        plate = Utils.FormatPlate(GetVehicleNumberPlateText(vehicle)),

        -- Health/Damage
        health = {
            body = GetVehicleBodyHealth(vehicle),
            engine = GetVehicleEngineHealth(vehicle),
            petrol = GetVehiclePetrolTankHealth(vehicle),
        },

        -- Detailed damage state
        damage = VehicleData.GetDamageState(vehicle),

        -- Fuel (via Bridge for compatibility)
        fuel = Bridge.GetFuel(vehicle),

        -- Dirt level
        dirtLevel = GetVehicleDirtLevel(vehicle),

        -- Visual properties
        visual = VehicleData.GetVisualState(vehicle),

        -- Full mods (via Bridge for framework compatibility)
        mods = Bridge.GetVehicleProperties(vehicle),

        -- Extras
        extras = VehicleData.GetExtras(vehicle),

        -- Doors/Windows state
        openElements = VehicleData.GetOpenElements(vehicle),

        -- Neon/Lights
        neon = VehicleData.GetNeonState(vehicle),

        -- Metadata timestamp
        serializedAt = os.time(),
    }

    return data
end

---Restore complete vehicle state from serialized data
---@param vehicle number Entity handle
---@param data table Serialized vehicle data
function VehicleData.Deserialize(vehicle, data)
    if not DoesEntityExist(vehicle) or not data then
        return false
    end

    -- Apply mods first (framework properties)
    if data.mods then
        Bridge.SetVehicleProperties(vehicle, data.mods)
    end

    -- Apply health
    if data.health then
        SetVehicleBodyHealth(vehicle, data.health.body or 1000.0)
        SetVehicleEngineHealth(vehicle, data.health.engine or 1000.0)
        SetVehiclePetrolTankHealth(vehicle, data.health.petrol or 1000.0)
    end

    -- Apply detailed damage
    if data.damage then
        VehicleData.SetDamageState(vehicle, data.damage)
    end

    -- Apply fuel
    if data.fuel then
        Bridge.SetFuel(vehicle, data.fuel)
    end

    -- Apply dirt
    if data.dirtLevel then
        SetVehicleDirtLevel(vehicle, data.dirtLevel)
    end

    -- Apply visual state
    if data.visual then
        VehicleData.SetVisualState(vehicle, data.visual)
    end

    -- Apply extras
    if data.extras then
        VehicleData.SetExtras(vehicle, data.extras)
    end

    -- Apply open elements (doors/windows)
    if data.openElements then
        VehicleData.SetOpenElements(vehicle, data.openElements)
    end

    -- Apply neon
    if data.neon then
        VehicleData.SetNeonState(vehicle, data.neon)
    end

    return true
end

-- ============================================
-- DAMAGE STATE (Detailed)
-- ============================================

---Get detailed damage state
---@param vehicle number
---@return table
function VehicleData.GetDamageState(vehicle)
    local damage = {
        windows = {},
        doors = {},
        tyres = {},
        deformed = false,
    }

    -- Windows (0-7)
    for i = 0, 7 do
        damage.windows[i] = IsVehicleWindowIntact(vehicle, i)
    end

    -- Doors (0-5)
    for i = 0, 5 do
        damage.doors[i] = {
            damaged = IsVehicleDoorDamaged(vehicle, i),
            open = GetVehicleDoorAngleRatio(vehicle, i) > 0.0,
        }
    end

    -- Tyres (0-7, includes spare tyres on some vehicles)
    for i = 0, 7 do
        damage.tyres[i] = {
            burst = IsVehicleTyreBurst(vehicle, i, false),
            completelyBurst = IsVehicleTyreBurst(vehicle, i, true),
        }
    end

    -- Check if vehicle has any deformation
    damage.deformed = GetVehicleDeformationAtPos(vehicle, 0.0, 0.0, 0.0) ~= vector3(0, 0, 0)

    return damage
end

---Set detailed damage state
---@param vehicle number
---@param damage table
function VehicleData.SetDamageState(vehicle, damage)
    if not damage then return end

    -- Windows
    if damage.windows then
        for i, intact in pairs(damage.windows) do
            if not intact then
                SmashVehicleWindow(vehicle, tonumber(i))
            end
        end
    end

    -- Doors
    if damage.doors then
        for i, state in pairs(damage.doors) do
            local doorIndex = tonumber(i)
            if state.damaged then
                SetVehicleDoorBroken(vehicle, doorIndex, true)
            end
        end
    end

    -- Tyres
    if damage.tyres then
        for i, state in pairs(damage.tyres) do
            local tyreIndex = tonumber(i)
            if state.completelyBurst then
                SetVehicleTyreBurst(vehicle, tyreIndex, true, 1000.0)
            elseif state.burst then
                SetVehicleTyreBurst(vehicle, tyreIndex, false, 1000.0)
            end
        end
    end
end

-- ============================================
-- VISUAL STATE
-- ============================================

---Get visual customization state
---@param vehicle number
---@return table
function VehicleData.GetVisualState(vehicle)
    local visual = {
        -- Plate
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),

        -- Colors
        colorPrimary = nil,
        colorSecondary = nil,
        pearlescentColor = nil,
        wheelColor = nil,

        -- Custom colors (RGB)
        customPrimary = nil,
        customSecondary = nil,

        -- Interior/Dashboard
        interiorColor = GetVehicleInteriorColor(vehicle),
        dashboardColor = GetVehicleDashboardColor(vehicle),

        -- Livery
        livery = GetVehicleLivery(vehicle),
        roofLivery = GetVehicleRoofLivery(vehicle),

        -- Xenon color
        xenonColor = GetVehicleXenonLightsColor(vehicle),

        -- Tyre smoke
        tyreSmokeColor = nil,
    end

    -- Get colors
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    visual.colorPrimary = colorPrimary
    visual.colorSecondary = colorSecondary

    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)
    visual.pearlescentColor = pearlescent
    visual.wheelColor = wheelColor

    -- Check for custom colors
    local hasCustomPrimary, customPrimaryR, customPrimaryG, customPrimaryB = GetVehicleCustomPrimaryColour(vehicle)
    if hasCustomPrimary then
        visual.customPrimary = { r = customPrimaryR, g = customPrimaryG, b = customPrimaryB }
    end

    local hasCustomSecondary, customSecondaryR, customSecondaryG, customSecondaryB = GetVehicleCustomSecondaryColour(vehicle)
    if hasCustomSecondary then
        visual.customSecondary = { r = customSecondaryR, g = customSecondaryG, b = customSecondaryB }
    end

    -- Tyre smoke
    local smokeR, smokeG, smokeB = GetVehicleTyreSmokeColor(vehicle)
    visual.tyreSmokeColor = { r = smokeR, g = smokeG, b = smokeB }

    return visual
end

---Set visual customization state
---@param vehicle number
---@param visual table
function VehicleData.SetVisualState(vehicle, visual)
    if not visual then return end

    -- Plate style
    if visual.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, visual.plateIndex)
    end

    -- Colors
    if visual.colorPrimary and visual.colorSecondary then
        SetVehicleColours(vehicle, visual.colorPrimary, visual.colorSecondary)
    end

    -- Custom colors
    if visual.customPrimary then
        SetVehicleCustomPrimaryColour(vehicle, visual.customPrimary.r, visual.customPrimary.g, visual.customPrimary.b)
    end

    if visual.customSecondary then
        SetVehicleCustomSecondaryColour(vehicle, visual.customSecondary.r, visual.customSecondary.g, visual.customSecondary.b)
    end

    -- Extra colors
    if visual.pearlescentColor and visual.wheelColor then
        SetVehicleExtraColours(vehicle, visual.pearlescentColor, visual.wheelColor)
    end

    -- Interior
    if visual.interiorColor then
        SetVehicleInteriorColor(vehicle, visual.interiorColor)
    end

    if visual.dashboardColor then
        SetVehicleDashboardColor(vehicle, visual.dashboardColor)
    end

    -- Livery
    if visual.livery then
        SetVehicleLivery(vehicle, visual.livery)
    end

    if visual.roofLivery then
        SetVehicleRoofLivery(vehicle, visual.roofLivery)
    end

    -- Xenon
    if visual.xenonColor then
        SetVehicleXenonLightsColor(vehicle, visual.xenonColor)
    end

    -- Tyre smoke
    if visual.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, visual.tyreSmokeColor.r, visual.tyreSmokeColor.g, visual.tyreSmokeColor.b)
    end
end

-- ============================================
-- EXTRAS
-- ============================================

---Get vehicle extras state
---@param vehicle number
---@return table
function VehicleData.GetExtras(vehicle)
    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            extras[i] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end
    return extras
end

---Set vehicle extras state
---@param vehicle number
---@param extras table
function VehicleData.SetExtras(vehicle, extras)
    if not extras then return end
    for i, enabled in pairs(extras) do
        if DoesExtraExist(vehicle, tonumber(i)) then
            SetVehicleExtra(vehicle, tonumber(i), not enabled)
        end
    end
end

-- ============================================
-- OPEN ELEMENTS (Doors/Windows/Boot/Hood)
-- ============================================

---Get open elements state
---@param vehicle number
---@return table
function VehicleData.GetOpenElements(vehicle)
    return {
        hood = GetVehicleDoorAngleRatio(vehicle, 4) > 0.0,
        trunk = GetVehicleDoorAngleRatio(vehicle, 5) > 0.0,
        -- Windows rolled down
        windowsDown = {
            [0] = IsVehicleWindowIntact(vehicle, 0) and GetVehicleDoorAngleRatio(vehicle, 0) == 0,
            [1] = IsVehicleWindowIntact(vehicle, 1) and GetVehicleDoorAngleRatio(vehicle, 1) == 0,
        }
    }
end

---Set open elements state
---@param vehicle number
---@param elements table
function VehicleData.SetOpenElements(vehicle, elements)
    if not elements then return end

    -- Close everything for parked state
    SetVehicleDoorShut(vehicle, 4, false) -- Hood
    SetVehicleDoorShut(vehicle, 5, false) -- Trunk

    -- Roll up windows
    for i = 0, 3 do
        RollUpWindow(vehicle, i)
    end
end

-- ============================================
-- NEON
-- ============================================

---Get neon lights state
---@param vehicle number
---@return table
function VehicleData.GetNeonState(vehicle)
    local neon = {
        enabled = {
            [0] = IsVehicleNeonLightEnabled(vehicle, 0), -- Left
            [1] = IsVehicleNeonLightEnabled(vehicle, 1), -- Right
            [2] = IsVehicleNeonLightEnabled(vehicle, 2), -- Front
            [3] = IsVehicleNeonLightEnabled(vehicle, 3), -- Back
        },
        color = nil,
    }

    local r, g, b = GetVehicleNeonLightsColour(vehicle)
    neon.color = { r = r, g = g, b = b }

    return neon
end

---Set neon lights state
---@param vehicle number
---@param neon table
function VehicleData.SetNeonState(vehicle, neon)
    if not neon then return end

    if neon.enabled then
        for i, enabled in pairs(neon.enabled) do
            SetVehicleNeonLightEnabled(vehicle, tonumber(i), enabled)
        end
    end

    if neon.color then
        SetVehicleNeonLightsColour(vehicle, neon.color.r, neon.color.g, neon.color.b)
    end
end

-- ============================================
-- QUICK HELPERS
-- ============================================

---Check if vehicle is in good condition
---@param vehicle number
---@return boolean
function VehicleData.IsHealthy(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)

    return bodyHealth > 800 and engineHealth > 800
end

---Get simple damage percentage
---@param vehicle number
---@return number 0-100 (100 = fully damaged)
function VehicleData.GetDamagePercent(vehicle)
    if not DoesEntityExist(vehicle) then return 100 end

    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)

    local avgHealth = (bodyHealth + engineHealth) / 2
    return math.floor(100 - (avgHealth / 10))
end

print('^2[DPS-Parking] Vehicle data utilities loaded^0')

return VehicleData
