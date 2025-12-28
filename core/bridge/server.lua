--[[
    DPS-Parking - Server Bridge
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Server-side framework abstraction.
]]

-- Wait for bridge initialization
Bridge.WaitReady()

-- ============================================
-- PLAYER FUNCTIONS
-- ============================================

---Get player object
---@param source number
---@return table|nil
function Bridge.GetPlayer(source)
    if Bridge.IsESX() then
        return Bridge.Core.GetPlayerFromId(source)
    else
        return Bridge.Core.Functions.GetPlayer(source)
    end
end

---Get player by citizen ID
---@param citizenid string
---@return table|nil
function Bridge.GetPlayerByCitizenId(citizenid)
    if Bridge.IsESX() then
        return Bridge.Core.GetPlayerFromIdentifier(citizenid)
    else
        return Bridge.Core.Functions.GetPlayerByCitizenId(citizenid)
    end
end

---Get citizen ID from source
---@param source number
---@return string|nil
function Bridge.GetCitizenId(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.IsESX() then
        return player.identifier
    else
        return player.PlayerData.citizenid
    end
end

---Get player name
---@param source number
---@return string
function Bridge.GetPlayerName(source)
    local player = Bridge.GetPlayer(source)
    if not player then return 'Unknown' end

    if Bridge.IsESX() then
        return player.getName()
    else
        local charinfo = player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end
end

---Get player job name
---@param source number
---@return string|nil
function Bridge.GetPlayerJob(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    if Bridge.IsESX() then
        return player.job.name
    else
        return player.PlayerData.job.name
    end
end

---Get all online players
---@return table
function Bridge.GetOnlinePlayers()
    if Bridge.IsESX() then
        return Bridge.Core.GetPlayers()
    else
        return Bridge.Core.Functions.GetPlayers()
    end
end

-- ============================================
-- MONEY FUNCTIONS
-- ============================================

---Get player money
---@param source number
---@param moneyType? string cash/bank
---@return number
function Bridge.GetMoney(source, moneyType)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end

    moneyType = moneyType or 'cash'

    if Bridge.IsESX() then
        if moneyType == 'cash' then
            return player.getMoney()
        else
            return player.getAccount(moneyType).money
        end
    else
        return player.PlayerData.money[moneyType] or 0
    end
end

---Remove money from player
---@param source number
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function Bridge.RemoveMoney(source, moneyType, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    moneyType = moneyType or 'cash'
    reason = reason or 'Parking fee'

    if Bridge.IsESX() then
        if moneyType == 'cash' then
            player.removeMoney(amount)
        else
            player.removeAccountMoney(moneyType, amount)
        end
        return true
    else
        return player.Functions.RemoveMoney(moneyType, amount, reason)
    end
end

---Add money to player
---@param source number
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function Bridge.AddMoney(source, moneyType, amount, reason)
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    moneyType = moneyType or 'cash'
    reason = reason or 'Parking refund'

    if Bridge.IsESX() then
        if moneyType == 'cash' then
            player.addMoney(amount)
        else
            player.addAccountMoney(moneyType, amount)
        end
        return true
    else
        return player.Functions.AddMoney(moneyType, amount, reason)
    end
end

-- ============================================
-- NOTIFICATIONS
-- ============================================

---Send notification to player
---@param source number
---@param message string
---@param type? string
---@param duration? number
function Bridge.Notify(source, message, type, duration)
    type = type or 'info'
    duration = duration or 5000

    if Bridge.Resources.HasOxLib() then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Parking',
            description = message,
            type = type,
            duration = duration
        })
    elseif Bridge.IsESX() then
        TriggerClientEvent('esx:showNotification', source, message)
    else
        TriggerClientEvent('QBCore:Notify', source, message, type, duration)
    end
end

-- ============================================
-- CALLBACKS
-- ============================================

---Create server callback
---@param name string
---@param cb function
function Bridge.CreateCallback(name, cb)
    if Bridge.Resources.HasOxLib() then
        lib.callback.register(name, cb)
    elseif Bridge.IsESX() then
        Bridge.Core.RegisterServerCallback(name, cb)
    else
        Bridge.Core.Functions.CreateCallback(name, cb)
    end
end

-- ============================================
-- DATABASE ABSTRACTION
-- ============================================

Bridge.DB = {}

---Get vehicle table name
---@return string
function Bridge.DB.GetVehicleTable()
    if Bridge.IsESX() then
        return 'owned_vehicles'
    else
        return 'player_vehicles'
    end
end

---Get owner column name
---@return string
function Bridge.DB.GetOwnerColumn()
    if Bridge.IsESX() then
        return 'owner'
    else
        return 'citizenid'
    end
end

---Get state column name
---@return string
function Bridge.DB.GetStateColumn()
    if Bridge.IsESX() then
        return 'stored'
    else
        return 'state'
    end
end

-- Vehicle states
Bridge.DB.States = {
    OUT = 0,
    GARAGE = 1,
    IMPOUND = 2,
    PARKED = 3
}

---Get parked vehicles for player
---@param citizenid string
---@return table
function Bridge.DB.GetParkedVehicles(citizenid)
    local tbl = Bridge.DB.GetVehicleTable()
    local owner = Bridge.DB.GetOwnerColumn()
    local state = Bridge.DB.GetStateColumn()

    return MySQL.query.await(
        ('SELECT * FROM %s WHERE %s = ? AND %s = ?'):format(tbl, owner, state),
        {citizenid, Bridge.DB.States.PARKED}
    )
end

---Get all parked vehicles
---@return table
function Bridge.DB.GetAllParkedVehicles()
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    return MySQL.query.await(
        ('SELECT * FROM %s WHERE %s = ?'):format(tbl, state),
        {Bridge.DB.States.PARKED}
    )
end

---Set vehicle as parked
---@param plate string
---@param location table
---@param street string
---@param steerangle number
---@param fuel number
---@param trailerdata? table
function Bridge.DB.SetVehicleParked(plate, location, street, steerangle, fuel, trailerdata)
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    MySQL.update.await(
        ('UPDATE %s SET %s = ?, location = ?, street = ?, steerangle = ?, fuel = ?, trailerdata = ? WHERE plate = ?'):format(tbl, state),
        {Bridge.DB.States.PARKED, json.encode(location), street, steerangle, fuel, json.encode(trailerdata or {}), plate}
    )
end

---Set vehicle as out (unparked)
---@param plate string
function Bridge.DB.SetVehicleOut(plate)
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    MySQL.update.await(
        ('UPDATE %s SET %s = ?, location = NULL, street = NULL, trailerdata = NULL WHERE plate = ?'):format(tbl, state),
        {Bridge.DB.States.OUT, plate}
    )
end

---Set vehicle as impounded
---@param plate string
---@param body number
---@param engine number
---@param fuel number
function Bridge.DB.SetVehicleImpounded(plate, body, engine, fuel)
    local tbl = Bridge.DB.GetVehicleTable()
    local state = Bridge.DB.GetStateColumn()

    MySQL.update.await(
        ('UPDATE %s SET %s = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?'):format(tbl, state),
        {Bridge.DB.States.IMPOUND, body, engine, fuel, plate}
    )
end

---Check if player owns vehicle
---@param citizenid string
---@param plate string
---@return boolean
function Bridge.DB.PlayerOwnsVehicle(citizenid, plate)
    local tbl = Bridge.DB.GetVehicleTable()
    local owner = Bridge.DB.GetOwnerColumn()

    local result = MySQL.query.await(
        ('SELECT 1 FROM %s WHERE %s = ? AND plate = ?'):format(tbl, owner),
        {citizenid, plate}
    )

    return result and #result > 0
end

-- ============================================
-- ADMIN CHECK
-- ============================================

---Check if player is admin
---@param source number
---@return boolean
function Bridge.IsAdmin(source)
    return IsPlayerAceAllowed(source, 'admin') or IsPlayerAceAllowed(source, 'command')
end

-- ============================================
-- POLICE IMPOUND
-- ============================================

---Trigger police impound
---@param plate string
---@param fullImpound boolean
---@param price number
---@param body number
---@param engine number
---@param fuel number
function Bridge.PoliceImpound(plate, fullImpound, price, body, engine, fuel)
    if Bridge.IsESX() then
        -- ESX impound logic
        TriggerEvent('esx_policejob:impound', plate)
    else
        -- QB impound
        TriggerEvent('police:server:Impound', plate, fullImpound, price, body, engine, fuel)
    end

    -- Update DB
    Bridge.DB.SetVehicleImpounded(plate, body, engine, fuel)
end

-- ============================================
-- PERSISTENCE INTEGRATION
-- ============================================

Bridge.Persistence = {}

function Bridge.Persistence.IsAvailable()
    return Bridge.Resources.Exists('dps-vehiclepersistence')
end

function Bridge.Persistence.GetWorldVehicles()
    if not Bridge.Persistence.IsAvailable() then return {} end
    return exports['dps-vehiclepersistence']:GetWorldVehicles()
end

function Bridge.Persistence.IsVehiclePersisted(plate)
    if not Bridge.Persistence.IsAvailable() then return false end
    return exports['dps-vehiclepersistence']:IsVehiclePersisted(plate)
end

function Bridge.Persistence.RemoveVehicle(plate)
    if not Bridge.Persistence.IsAvailable() then return false end
    return exports['dps-vehiclepersistence']:RemovePersistedVehicle(plate)
end

-- ============================================
-- STATE SYNC
-- ============================================

---Sync state to client
---@param source number
function Bridge.SyncStateToClient(source)
    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then return end

    local syncData = State.GetClientSyncData(citizenid)
    TriggerClientEvent('dps-parking:client:stateSync', source, syncData)
end

-- Event for client to request sync
RegisterNetEvent('dps-parking:server:requestStateSync', function()
    local source = source
    Bridge.SyncStateToClient(source)
end)

-- ============================================
-- REACTIVE JOB/GRADE UPDATES (Server)
-- ============================================

Bridge.Job = {
    _callbacks = {},
}

---Register a callback for when any player's job changes
---@param callback function (source, newJob, oldJob)
---@return string id
function Bridge.Job.OnChange(callback)
    local id = 'job_cb_' .. os.time()
    Bridge.Job._callbacks[id] = callback
    return id
end

---Remove job change callback
---@param id string
function Bridge.Job.RemoveCallback(id)
    Bridge.Job._callbacks[id] = nil
end

---Notify all job change callbacks
local function NotifyJobChange(source, newJob, oldJob)
    for _, callback in pairs(Bridge.Job._callbacks) do
        local success, err = pcall(callback, source, newJob, oldJob)
        if not success then
            print(('[DPS-Parking] Bridge: Job callback error: %s'):format(err))
        end
    end

    -- Publish to EventBus
    if EventBus then
        EventBus.Publish('player:jobChanged', {
            source = source,
            citizenid = Bridge.GetCitizenId(source),
            new = newJob,
            old = oldJob
        })
    end
end

-- Framework-specific job update events
CreateThread(function()
    Bridge.WaitReady()

    if Bridge.IsQB() then
        -- QBCore job update
        RegisterNetEvent('QBCore:Server:OnJobUpdate', function(source, job)
            NotifyJobChange(source, job, nil)
        end)

        -- Also hook into player data updates
        if Bridge.Core and Bridge.Core.Functions then
            local originalSetJob = Bridge.Core.Functions.SetJob
            if originalSetJob then
                Bridge.Core.Functions.SetJob = function(source, job, grade)
                    local player = Bridge.GetPlayer(source)
                    local oldJob = player and player.PlayerData.job or nil
                    local result = originalSetJob(source, job, grade)
                    local newJob = Bridge.GetPlayer(source)
                    newJob = newJob and newJob.PlayerData.job or nil
                    NotifyJobChange(source, newJob, oldJob)
                    return result
                end
            end
        end
    elseif Bridge.IsESX() then
        RegisterNetEvent('esx:setJob', function(source, job, lastJob)
            NotifyJobChange(source, job, lastJob)
        end)
    end
end)

-- ============================================
-- BUSINESS ACCESS REVOCATION ON JOB LOSS
-- ============================================

-- Auto-hook to revoke business access when job changes
Bridge.Job.OnChange(function(source, newJob, oldJob)
    -- Check if this affects any business ownership
    local citizenid = Bridge.GetCitizenId(source)
    if not citizenid then return end

    -- Let the business module handle the logic via EventBus
    -- This keeps Bridge generic and lets modules subscribe to what they need
end)

-- ============================================
-- SERVER INTEGRATIONS
-- ============================================

Bridge.Integrations = {}

---Detect available server scripts
function Bridge.Integrations.Detect()
    return {
        -- Database
        database = Bridge.Resources.Exists('oxmysql') and 'oxmysql' or
                   Bridge.Resources.Exists('mysql-async') and 'mysql-async' or
                   nil,

        -- Banking
        banking = Bridge.Resources.Exists('qs-banking') and 'qs-banking' or
                  Bridge.Resources.Exists('qb-banking') and 'qb-banking' or
                  nil,

        -- Inventory
        inventory = Bridge.Resources.Exists('qs-inventory') and 'qs-inventory' or
                    Bridge.Resources.Exists('qb-inventory') and 'qb-inventory' or
                    Bridge.Resources.Exists('ox_inventory') and 'ox_inventory' or
                    nil,

        -- Management
        management = Bridge.Resources.Exists('qb-management') and 'qb-management' or
                     Bridge.Resources.Exists('okokBossMenu') and 'okokBossMenu' or
                     nil,

        -- Garages
        garage = Bridge.Resources.Exists('qs-advancedgarages') and 'qs-advancedgarages' or
                 Bridge.Resources.Exists('jg-advancedgarages') and 'jg-advancedgarages' or
                 Bridge.Resources.Exists('qb-garages') and 'qb-garages' or
                 nil,
    }
end

---Log detected integrations on startup
CreateThread(function()
    Bridge.WaitReady()
    Wait(3000)

    local integrations = Bridge.Integrations.Detect()
    local detected = {}

    for name, value in pairs(integrations) do
        if value then
            table.insert(detected, name .. ': ' .. value)
        end
    end

    if #detected > 0 then
        print('^2[DPS-Parking] Detected integrations: ' .. table.concat(detected, ', ') .. '^0')
    end
end)

print('^2[DPS-Parking] Server bridge loaded^0')
