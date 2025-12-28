--[[
    DPS-Parking - Shared Utilities
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Common utility functions for both client and server.
]]

Utils = {}

-- ============================================
-- STRING UTILITIES
-- ============================================

---Trim whitespace from string
---@param s string
---@return string
function Utils.Trim(s)
    return s:match("^%s*(.-)%s*$")
end

---Check if string is empty or nil
---@param s string|nil
---@return boolean
function Utils.IsEmpty(s)
    return s == nil or Utils.Trim(s) == ''
end

---Format number with commas
---@param n number
---@return string
function Utils.FormatNumber(n)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

---Format currency
---@param amount number
---@return string
function Utils.FormatMoney(amount)
    return '$' .. Utils.FormatNumber(amount)
end

---Format time from seconds
---@param seconds number
---@return string
function Utils.FormatTime(seconds)
    if seconds < 60 then
        return seconds .. 's'
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return mins .. 'm ' .. secs .. 's'
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return hours .. 'h ' .. mins .. 'm'
    end
end

---Format date from timestamp
---@param timestamp number
---@return string
function Utils.FormatDate(timestamp)
    return os.date('%Y-%m-%d %H:%M', timestamp)
end

-- ============================================
-- TABLE UTILITIES
-- ============================================

---Deep copy a table
---@param orig table
---@return table
function Utils.DeepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in next, orig, nil do
            copy[Utils.DeepCopy(k)] = Utils.DeepCopy(v)
        end
        setmetatable(copy, Utils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

---Merge tables (shallow)
---@param t1 table Base table
---@param t2 table Table to merge in
---@return table
function Utils.Merge(t1, t2)
    local result = Utils.DeepCopy(t1)
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

---Count items in table
---@param t table
---@return number
function Utils.Count(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

---Check if table contains value
---@param t table
---@param value any
---@return boolean
function Utils.Contains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

---Get keys from table
---@param t table
---@return table
function Utils.Keys(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

---Get values from table
---@param t table
---@return table
function Utils.Values(t)
    local values = {}
    for _, v in pairs(t) do
        table.insert(values, v)
    end
    return values
end

-- ============================================
-- MATH UTILITIES
-- ============================================

---Clamp value between min and max
---@param value number
---@param min number
---@param max number
---@return number
function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

---Round number to decimal places
---@param num number
---@param decimals? number
---@return number
function Utils.Round(num, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

---Linear interpolation
---@param a number Start value
---@param b number End value
---@param t number Time (0-1)
---@return number
function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

-- ============================================
-- DISTANCE & VECTORS
-- ============================================

---Calculate distance between two points
---@param p1 vector3
---@param p2 vector3
---@return number
function Utils.Distance(p1, p2)
    return #(p1 - p2)
end

---Check if point is within radius
---@param point vector3
---@param center vector3
---@param radius number
---@return boolean
function Utils.IsInRadius(point, center, radius)
    return Utils.Distance(point, center) <= radius
end

-- ============================================
-- VEHICLE UTILITIES
-- ============================================

---Get vehicle display name
---@param model number|string
---@return string
function Utils.GetVehicleDisplayName(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    return GetDisplayNameFromVehicleModel(model)
end

---Get vehicle label (display name formatted)
---@param model number|string
---@return string
function Utils.GetVehicleLabel(model)
    local name = Utils.GetVehicleDisplayName(model)
    if name == 'CARNOTFOUND' then
        return 'Unknown Vehicle'
    end
    return GetLabelText(name)
end

---Format plate (trim and uppercase)
---@param plate string
---@return string
function Utils.FormatPlate(plate)
    return Utils.Trim(plate):upper()
end

-- ============================================
-- ZONE UTILITIES
-- ============================================

---Check if player job matches any in list
---@param playerJob string
---@param allowedJobs table|nil
---@return boolean
function Utils.JobMatches(playerJob, allowedJobs)
    if not allowedJobs or #allowedJobs == 0 then
        return true -- No restriction
    end

    for _, job in ipairs(allowedJobs) do
        if playerJob == job then
            return true
        end
    end
    return false
end

---Find nearest zone from list
---@param coords vector3
---@param zones table
---@return table|nil zone
---@return number|nil distance
function Utils.FindNearestZone(coords, zones)
    local nearest = nil
    local nearestDist = math.huge

    for _, zone in ipairs(zones) do
        local dist = Utils.Distance(coords, zone.coords)
        if dist < nearestDist then
            nearestDist = dist
            nearest = zone
        end
    end

    return nearest, nearestDist
end

---Check if coords are in any no-parking zone
---@param coords vector3
---@param playerJob string|nil
---@return boolean inZone
---@return table|nil zone
function Utils.IsInNoParkingZone(coords, playerJob)
    for _, zone in ipairs(Config.NoParkingZones or {}) do
        if Utils.IsInRadius(coords, zone.coords, zone.radius) then
            -- Check job restriction
            if zone.jobs and #zone.jobs > 0 then
                if not Utils.JobMatches(playerJob, zone.jobs) then
                    return true, zone
                end
            else
                return true, zone
            end
        end
    end
    return false, nil
end

---Check if coords are in a parking lot
---@param coords vector3
---@return boolean inLot
---@return table|nil lot
function Utils.IsInParkingLot(coords)
    for _, lot in ipairs(Config.ParkingLots or {}) do
        if Utils.IsInRadius(coords, lot.coords, lot.radius) then
            return true, lot
        end
    end
    return false, nil
end

-- ============================================
-- DEBUG
-- ============================================

---Debug print
---@param ... any
function Utils.Debug(...)
    if Config and Config.Debug then
        print('[DPS-Parking]', ...)
    end
end

---Debug table print
---@param t table
---@param name? string
function Utils.DebugTable(t, name)
    if Config and Config.Debug then
        print(('[DPS-Parking] %s:'):format(name or 'Table'))
        print(json.encode(t, { indent = true }))
    end
end

return Utils
