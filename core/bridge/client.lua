--[[
    DPS-Parking - Client Bridge
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Client-side framework abstraction.
]]

-- Wait for bridge initialization
Bridge.WaitReady()

-- ============================================
-- PLAYER FUNCTIONS
-- ============================================

---Get player data
---@return table|nil
function Bridge.GetPlayerData()
    if Bridge.IsESX() then
        return Bridge.Core.GetPlayerData()
    else
        return Bridge.Core.Functions.GetPlayerData()
    end
end

---Get citizen ID / identifier
---@return string|nil
function Bridge.GetCitizenId()
    local data = Bridge.GetPlayerData()
    if not data then return nil end

    if Bridge.IsESX() then
        return data.identifier
    else
        return data.citizenid
    end
end

---Get player job
---@return table|nil
function Bridge.GetPlayerJob()
    local data = Bridge.GetPlayerData()
    if not data then return nil end
    return data.job
end

---Get player job name
---@return string|nil
function Bridge.GetJobName()
    local job = Bridge.GetPlayerJob()
    return job and job.name or nil
end

---Check if player has a specific job
---@param jobName string
---@return boolean
function Bridge.HasJob(jobName)
    return Bridge.GetJobName() == jobName
end

---Check if player has any of the specified jobs
---@param jobs table Array of job names
---@return boolean
function Bridge.HasAnyJob(jobs)
    local currentJob = Bridge.GetJobName()
    for _, job in ipairs(jobs) do
        if currentJob == job then
            return true
        end
    end
    return false
end

-- ============================================
-- NOTIFICATIONS
-- ============================================

---Show notification
---@param message string
---@param type? string success/error/info/warning
---@param duration? number ms
function Bridge.Notify(message, type, duration)
    type = type or 'info'
    duration = duration or 5000

    if Bridge.Resources.HasOxLib() then
        lib.notify({
            title = 'Parking',
            description = message,
            type = type,
            duration = duration
        })
    elseif Bridge.IsESX() then
        TriggerEvent('esx:showNotification', message)
    else
        TriggerEvent('QBCore:Notify', message, type, duration)
    end
end

-- ============================================
-- CALLBACKS
-- ============================================

---Trigger server callback (async)
---@param name string
---@param cb function
---@param ... any
function Bridge.TriggerCallback(name, cb, ...)
    if Bridge.Resources.HasOxLib() then
        cb(lib.callback.await(name, false, ...))
    elseif Bridge.IsESX() then
        Bridge.Core.TriggerServerCallback(name, cb, ...)
    else
        Bridge.Core.Functions.TriggerCallback(name, cb, ...)
    end
end

---Await callback (sync)
---@param name string
---@param ... any
---@return any
function Bridge.Callback(name, ...)
    if Bridge.Resources.HasOxLib() then
        return lib.callback.await(name, false, ...)
    end

    local p = promise.new()
    Bridge.TriggerCallback(name, function(result)
        p:resolve(result)
    end, ...)
    return Citizen.Await(p)
end

-- ============================================
-- VEHICLE FUNCTIONS
-- ============================================

---Get vehicle properties
---@param vehicle number Entity handle
---@return table
function Bridge.GetVehicleProperties(vehicle)
    if Bridge.Resources.HasOxLib() then
        return lib.getVehicleProperties(vehicle)
    elseif Bridge.IsESX() then
        return ESX.Game.GetVehicleProperties(vehicle)
    else
        return Bridge.Core.Functions.GetVehicleProperties(vehicle)
    end
end

---Set vehicle properties
---@param vehicle number Entity handle
---@param props table
function Bridge.SetVehicleProperties(vehicle, props)
    if not props then return end

    if Bridge.Resources.HasOxLib() then
        lib.setVehicleProperties(vehicle, props)
    elseif Bridge.IsESX() then
        ESX.Game.SetVehicleProperties(vehicle, props)
    else
        Bridge.Core.Functions.SetVehicleProperties(vehicle, props)
    end
end

-- ============================================
-- FUEL INTEGRATION
-- ============================================

---Get vehicle fuel level
---@param vehicle number
---@return number
function Bridge.GetFuel(vehicle)
    local fuelScript = Bridge.Resources.GetFuel()

    if fuelScript == 'ox_fuel' then
        return GetVehicleFuelLevel(vehicle)
    elseif fuelScript == 'LegacyFuel' then
        return exports['LegacyFuel']:GetFuel(vehicle)
    elseif fuelScript == 'cdn-fuel' then
        return exports['cdn-fuel']:GetFuel(vehicle)
    elseif fuelScript == 'ps-fuel' then
        return exports['ps-fuel']:GetFuel(vehicle)
    elseif fuelScript == 'qs-fuelstations' then
        return exports['qs-fuelstations']:GetFuel(vehicle)
    else
        return GetVehicleFuelLevel(vehicle)
    end
end

---Set vehicle fuel level
---@param vehicle number
---@param level number
function Bridge.SetFuel(vehicle, level)
    local fuelScript = Bridge.Resources.GetFuel()

    if fuelScript == 'ox_fuel' then
        SetVehicleFuelLevel(vehicle, level + 0.0)
    elseif fuelScript == 'LegacyFuel' then
        exports['LegacyFuel']:SetFuel(vehicle, level)
    elseif fuelScript == 'cdn-fuel' then
        exports['cdn-fuel']:SetFuel(vehicle, level)
    elseif fuelScript == 'ps-fuel' then
        exports['ps-fuel']:SetFuel(vehicle, level)
    elseif fuelScript == 'qs-fuelstations' then
        exports['qs-fuelstations']:SetFuel(vehicle, level)
    else
        SetVehicleFuelLevel(vehicle, level + 0.0)
    end
end

-- ============================================
-- VEHICLE KEYS
-- ============================================

---Give vehicle keys to player
---@param plate string
---@param vehicle? number
function Bridge.GiveKeys(plate, vehicle)
    local keyScript = Bridge.Resources.GetVehicleKeys()

    if keyScript == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:GiveKeys(plate)
    elseif keyScript == 'qb-vehiclekeys' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    elseif keyScript == 'qbx_vehiclekeys' then
        TriggerEvent('qbx_vehiclekeys:client:GiveKeys', plate)
    elseif keyScript == 'wasabi_carlock' then
        exports.wasabi_carlock:GiveKey(plate)
    end
end

-- ============================================
-- TARGET INTEGRATION
-- ============================================

Bridge.Target = {}

---Add box zone target
---@param name string
---@param coords vector3
---@param size vector3
---@param options table
---@param targetOptions table
function Bridge.Target.AddBoxZone(name, coords, size, options, targetOptions)
    local target = Bridge.Resources.GetTarget()
    if not target then return end

    if target == 'ox_target' then
        exports.ox_target:addBoxZone({
            name = name,
            coords = coords,
            size = size,
            rotation = options.heading or 0,
            debug = options.debug or false,
            options = targetOptions
        })
    elseif target == 'qb-target' then
        exports['qb-target']:AddBoxZone(name, coords, size.x, size.y, {
            name = name,
            heading = options.heading or 0,
            debugPoly = options.debug or false,
            minZ = coords.z - (size.z / 2),
            maxZ = coords.z + (size.z / 2),
        }, {
            options = targetOptions,
            distance = options.distance or 2.5
        })
    end
end

---Add entity target
---@param entities number|table
---@param options table
function Bridge.Target.AddEntity(entities, options)
    local target = Bridge.Resources.GetTarget()
    if not target then return end

    if target == 'ox_target' then
        exports.ox_target:addLocalEntity(entities, options)
    elseif target == 'qb-target' then
        exports['qb-target']:AddTargetEntity(entities, {
            options = options,
            distance = 2.5
        })
    end
end

---Remove zone
---@param name string
function Bridge.Target.RemoveZone(name)
    local target = Bridge.Resources.GetTarget()
    if not target then return end

    if target == 'ox_target' then
        exports.ox_target:removeZone(name)
    elseif target == 'qb-target' then
        exports['qb-target']:RemoveZone(name)
    end
end

-- ============================================
-- PROGRESS BAR
-- ============================================

---Show progress bar
---@param options table { name, label, duration, canCancel, animation, prop, onFinish, onCancel }
function Bridge.Progress(options)
    if Bridge.Resources.HasOxLib() then
        local success = lib.progressBar({
            duration = options.duration or 5000,
            label = options.label or 'Please wait...',
            useWhileDead = options.useWhileDead or false,
            canCancel = options.canCancel or false,
            disable = options.disable or { move = true, car = true, combat = true },
            anim = options.animation,
            prop = options.prop
        })

        if success then
            if options.onFinish then options.onFinish() end
        else
            if options.onCancel then options.onCancel() end
        end
    elseif Bridge.Resources.Exists('progressbar') then
        exports['progressbar']:Progress({
            name = options.name or 'parking_progress',
            duration = options.duration or 5000,
            label = options.label or 'Please wait...',
            useWhileDead = options.useWhileDead or false,
            canCancel = options.canCancel or false,
            controlDisables = options.disable,
            animation = options.animation,
            prop = options.prop
        }, function(cancelled)
            if not cancelled then
                if options.onFinish then options.onFinish() end
            else
                if options.onCancel then options.onCancel() end
            end
        end)
    else
        Wait(options.duration or 5000)
        if options.onFinish then options.onFinish() end
    end
end

-- ============================================
-- INPUT DIALOG
-- ============================================

---Show input dialog
---@param title string
---@param inputs table
---@return table|nil
function Bridge.Input(title, inputs)
    if Bridge.Resources.HasOxLib() then
        return lib.inputDialog(title, inputs)
    end
    return nil
end

-- ============================================
-- CONTEXT MENU
-- ============================================

---Show context menu
---@param id string
---@param title string
---@param options table
function Bridge.ContextMenu(id, title, options)
    if Bridge.Resources.HasOxLib() then
        lib.registerContext({
            id = id,
            title = title,
            options = options
        })
        lib.showContext(id)
    elseif not Bridge.IsESX() then
        -- QB menu fallback
        local menuOptions = {}
        for _, opt in ipairs(options) do
            table.insert(menuOptions, {
                header = opt.title,
                txt = opt.description,
                params = {
                    event = opt.event,
                    args = opt.args
                }
            })
        end
        exports['qb-menu']:openMenu(menuOptions)
    end
end

print('^2[DPS-Parking] Client bridge loaded^0')
