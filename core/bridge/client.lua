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

-- ============================================
-- REACTIVE JOB/GRADE UPDATES
-- ============================================

Bridge.Job = {
    _callbacks = {},
    _lastJob = nil,
    _lastGrade = nil,
}

---Register a callback for job changes
---@param callback function (newJob, oldJob)
---@return string id
function Bridge.Job.OnChange(callback)
    local id = 'job_cb_' .. GetGameTimer()
    Bridge.Job._callbacks[id] = callback
    return id
end

---Remove job change callback
---@param id string
function Bridge.Job.RemoveCallback(id)
    Bridge.Job._callbacks[id] = nil
end

---Notify all job change callbacks
local function NotifyJobChange(newJob, oldJob)
    for _, callback in pairs(Bridge.Job._callbacks) do
        local success, err = pcall(callback, newJob, oldJob)
        if not success then
            print(('[DPS-Parking] Bridge: Job callback error: %s'):format(err))
        end
    end

    -- Publish to EventBus
    if EventBus then
        EventBus.Publish('player:jobChanged', {
            new = newJob,
            old = oldJob
        })
    end
end

-- Job change detection thread
CreateThread(function()
    Bridge.WaitReady()
    Wait(2000)

    Bridge.Job._lastJob = Bridge.GetPlayerJob()

    while true do
        local currentJob = Bridge.GetPlayerJob()

        if currentJob then
            local jobChanged = Bridge.Job._lastJob == nil or
                              Bridge.Job._lastJob.name ~= currentJob.name
            local gradeChanged = Bridge.Job._lastJob and
                                Bridge.Job._lastJob.grade and
                                currentJob.grade and
                                Bridge.Job._lastJob.grade.level ~= currentJob.grade.level

            if jobChanged or gradeChanged then
                NotifyJobChange(currentJob, Bridge.Job._lastJob)
                Bridge.Job._lastJob = currentJob
            end
        end

        Wait(1000)
    end
end)

-- Framework-specific job update events
if Bridge.IsQB() then
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        NotifyJobChange(job, Bridge.Job._lastJob)
        Bridge.Job._lastJob = job
    end)
elseif Bridge.IsESX() then
    RegisterNetEvent('esx:setJob', function(job)
        NotifyJobChange(job, Bridge.Job._lastJob)
        Bridge.Job._lastJob = job
    end)
end

-- ============================================
-- SCRIPT INTEGRATIONS
-- ============================================

Bridge.Integrations = {}

---Check what vehicle-related scripts are available
function Bridge.Integrations.Detect()
    return {
        -- Fuel
        fuel = Bridge.Resources.GetFuel(),

        -- Keys
        vehicleKeys = Bridge.Resources.GetVehicleKeys(),

        -- Target
        target = Bridge.Resources.GetTarget(),

        -- Garages
        garage = Bridge.Resources.Exists('qb-garages') and 'qb-garages' or
                 Bridge.Resources.Exists('qs-advancedgarages') and 'qs-advancedgarages' or
                 Bridge.Resources.Exists('jg-advancedgarages') and 'jg-advancedgarages' or
                 nil,

        -- Damage/Visual sync
        vehicleSync = Bridge.Resources.Exists('qs-vehicletuning') and 'qs-vehicletuning' or
                      Bridge.Resources.Exists('qb-mechanicjob') and 'qb-mechanicjob' or
                      nil,

        -- Phone
        phone = Bridge.Resources.Exists('lb-phone') and 'lb-phone' or
                Bridge.Resources.Exists('qs-smartphone-pro') and 'qs-smartphone-pro' or
                Bridge.Resources.Exists('gksphone') and 'gksphone' or
                nil,

        -- Dispatch
        dispatch = Bridge.Resources.Exists('qs-dispatch') and 'qs-dispatch' or
                   Bridge.Resources.Exists('ps-dispatch') and 'ps-dispatch' or
                   Bridge.Resources.Exists('cd_dispatch') and 'cd_dispatch' or
                   nil,
    }
end

---Get vehicle properties using best available method
---@param vehicle number
---@return table
function Bridge.Integrations.GetVehicleData(vehicle)
    -- Check if we have a specialized vehicle sync script
    local integrations = Bridge.Integrations.Detect()

    if integrations.vehicleSync == 'qs-vehicletuning' then
        -- QS Vehicle Tuning has comprehensive data
        local props = Bridge.GetVehicleProperties(vehicle)
        return props
    end

    -- Use VehicleData utility for comprehensive capture
    if VehicleData then
        return VehicleData.Serialize(vehicle)
    end

    -- Fallback to basic properties
    return Bridge.GetVehicleProperties(vehicle)
end

---Set vehicle properties using best available method
---@param vehicle number
---@param data table
function Bridge.Integrations.SetVehicleData(vehicle, data)
    -- Use VehicleData utility for comprehensive restore
    if VehicleData and data.damage then
        VehicleData.Deserialize(vehicle, data)
    else
        Bridge.SetVehicleProperties(vehicle, data.mods or data)
    end

    -- Set fuel separately
    if data.fuel then
        Bridge.SetFuel(vehicle, data.fuel)
    end
end

print('^2[DPS-Parking] Client bridge loaded^0')
