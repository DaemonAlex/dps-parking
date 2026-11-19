--[[
    DPS-Parking - EventBus System
    Original: mh-parking by MaDHouSe79
    Enhanced: DPS Development

    Provides:
    - Pub/sub pattern for decoupled module communication
    - Pre/post hooks for extension points
    - Priority-based event handling
]]

EventBus = {}
EventBus._subscribers = {}
EventBus._hooks = {
    pre = {},
    post = {}
}

-- Priority levels for event handlers
EventBus.Priority = {
    FIRST = 1,
    HIGH = 25,
    NORMAL = 50,
    LOW = 75,
    LAST = 100
}

-- Configuration
EventBus.Config = {
    HookTimeout = 750,       -- Max ms for a hook to respond (750ms - balanced for performance)
    EnableTimeouts = true,   -- Enable timeout protection
    LogTimeouts = true,      -- Log when hooks timeout
    MaxChainTimeout = 3000,  -- Max total time for entire hook chain (3 seconds)
}

-- ============================================
-- EVENT SUBSCRIPTION
-- ============================================

---Subscribe to an event
---@param event string Event name
---@param callback function Handler function
---@param priority? number Priority (lower = earlier, default 50)
---@return string id Subscription ID for unsubscribing
function EventBus.Subscribe(event, callback, priority)
    if not EventBus._subscribers[event] then
        EventBus._subscribers[event] = {}
    end

    priority = priority or EventBus.Priority.NORMAL
    local id = event .. '_' .. tostring(#EventBus._subscribers[event] + 1) .. '_' .. GetGameTimer()

    table.insert(EventBus._subscribers[event], {
        id = id,
        callback = callback,
        priority = priority
    })

    -- Sort by priority (lower number = higher priority)
    table.sort(EventBus._subscribers[event], function(a, b)
        return a.priority < b.priority
    end)

    if Config and Config.Debug then
        print(('[DPS-Parking] EventBus: Subscribed to "%s" with priority %d'):format(event, priority))
    end

    return id
end

---Unsubscribe from an event
---@param event string Event name
---@param id string Subscription ID
function EventBus.Unsubscribe(event, id)
    if not EventBus._subscribers[event] then return end

    for i, sub in ipairs(EventBus._subscribers[event]) do
        if sub.id == id then
            table.remove(EventBus._subscribers[event], i)
            return true
        end
    end
    return false
end

-- ============================================
-- EVENT PUBLISHING
-- ============================================

---Publish an event to all subscribers
---@param event string Event name
---@param ... any Event data
---@return table results Results from all handlers
function EventBus.Publish(event, ...)
    local results = {}

    if not EventBus._subscribers[event] then
        return results
    end

    for _, sub in ipairs(EventBus._subscribers[event]) do
        local success, result = pcall(sub.callback, ...)
        if success then
            table.insert(results, result)
        else
            print(('[DPS-Parking] EventBus: Error in handler for "%s": %s'):format(event, result))
        end
    end

    return results
end

---Publish an event and wait for async handlers
---@param event string Event name
---@param ... any Event data
---@return table results Results from all handlers
function EventBus.PublishAsync(event, ...)
    local results = {}
    local args = {...}

    if not EventBus._subscribers[event] then
        return results
    end

    local promises = {}

    for _, sub in ipairs(EventBus._subscribers[event]) do
        local p = promise.new()

        CreateThread(function()
            local success, result = pcall(sub.callback, table.unpack(args))
            if success then
                p:resolve(result)
            else
                print(('[DPS-Parking] EventBus: Async error in "%s": %s'):format(event, result))
                p:resolve(nil)
            end
        end)

        table.insert(promises, p)
    end

    for _, p in ipairs(promises) do
        table.insert(results, Citizen.Await(p))
    end

    return results
end

-- ============================================
-- HOOK SYSTEM
-- ============================================

---Register a pre-hook (runs before an action)
---@param action string Action name (e.g., "parking:park")
---@param callback function Hook function - return false to cancel
---@param priority? number Priority
---@return string id Hook ID
function EventBus.RegisterPreHook(action, callback, priority)
    if not EventBus._hooks.pre[action] then
        EventBus._hooks.pre[action] = {}
    end

    priority = priority or EventBus.Priority.NORMAL
    local id = 'pre_' .. action .. '_' .. GetGameTimer()

    table.insert(EventBus._hooks.pre[action], {
        id = id,
        callback = callback,
        priority = priority
    })

    table.sort(EventBus._hooks.pre[action], function(a, b)
        return a.priority < b.priority
    end)

    return id
end

---Register a post-hook (runs after an action)
---@param action string Action name
---@param callback function Hook function
---@param priority? number Priority
---@return string id Hook ID
function EventBus.RegisterPostHook(action, callback, priority)
    if not EventBus._hooks.post[action] then
        EventBus._hooks.post[action] = {}
    end

    priority = priority or EventBus.Priority.NORMAL
    local id = 'post_' .. action .. '_' .. GetGameTimer()

    table.insert(EventBus._hooks.post[action], {
        id = id,
        callback = callback,
        priority = priority
    })

    table.sort(EventBus._hooks.post[action], function(a, b)
        return a.priority < b.priority
    end)

    return id
end

---Remove a hook
---@param hookType string "pre" or "post"
---@param action string Action name
---@param id string Hook ID
function EventBus.RemoveHook(hookType, action, id)
    local hooks = EventBus._hooks[hookType]
    if not hooks or not hooks[action] then return false end

    for i, hook in ipairs(hooks[action]) do
        if hook.id == id then
            table.remove(hooks[action], i)
            return true
        end
    end
    return false
end

-- ============================================
-- TIMEOUT WRAPPER
-- ============================================

---Execute a function with timeout protection
---@param callback function The function to execute
---@param data any Data to pass to function
---@param timeoutMs number Timeout in milliseconds
---@param hookId string Hook ID for logging
---@return boolean timedOut
---@return boolean|nil result
---@return any modifiedData
local function ExecuteWithTimeout(callback, data, timeoutMs, hookId)
    if not EventBus.Config.EnableTimeouts then
        -- No timeout - direct execution
        local success, result, modifiedData = pcall(callback, data)
        return false, success and result, modifiedData
    end

    local completed = false
    local timedOut = false
    local callbackResult = nil
    local callbackModifiedData = nil
    local callbackError = nil

    -- Execute callback in a thread
    CreateThread(function()
        local success, result, modifiedData = pcall(callback, data)
        if not completed then
            completed = true
            if success then
                callbackResult = result
                callbackModifiedData = modifiedData
            else
                callbackError = result
            end
        end
    end)

    -- Wait for completion or timeout
    local startTime = GetGameTimer()
    while not completed do
        if GetGameTimer() - startTime > timeoutMs then
            timedOut = true
            completed = true -- Mark as completed to prevent late response
            break
        end
        Wait(10)
    end

    if timedOut then
        if EventBus.Config.LogTimeouts then
            print(('[DPS-Parking] EventBus: Hook "%s" TIMED OUT after %dms - continuing without it'):format(hookId, timeoutMs))
        end
        return true, nil, nil
    end

    if callbackError then
        return false, nil, nil
    end

    return false, callbackResult, callbackModifiedData
end

---Execute pre-hooks for an action with timeout protection
---@param action string Action name
---@param data table Action data
---@return boolean continue Whether to continue with action
---@return table data Modified data
function EventBus.ExecutePreHooks(action, data)
    local hooks = EventBus._hooks.pre[action]
    if not hooks then return true, data end

    for _, hook in ipairs(hooks) do
        local timedOut, result, modifiedData = ExecuteWithTimeout(
            hook.callback,
            data,
            EventBus.Config.HookTimeout,
            hook.id
        )

        if timedOut then
            -- Hook timed out - log and continue (don't block core functionality)
            print(('[DPS-Parking] EventBus: WARNING - Pre-hook "%s" for action "%s" timed out!'):format(hook.id, action))
            -- Continue to next hook, don't cancel the action due to a buggy hook
        elseif result == false then
            -- Hook explicitly cancelled the action
            if Config and Config.Debug then
                print(('[DPS-Parking] EventBus: Action "%s" cancelled by pre-hook "%s"'):format(action, hook.id))
            end
            return false, data
        elseif modifiedData then
            data = modifiedData
        end
    end

    return true, data
end

---Execute post-hooks for an action with timeout protection
---@param action string Action name
---@param data table Action result data
function EventBus.ExecutePostHooks(action, data)
    local hooks = EventBus._hooks.post[action]
    if not hooks then return end

    for _, hook in ipairs(hooks) do
        -- Post-hooks run in background - don't block on them
        CreateThread(function()
            local startTime = GetGameTimer()
            local success, err = pcall(hook.callback, data)

            local elapsed = GetGameTimer() - startTime

            if not success then
                print(('[DPS-Parking] EventBus: Post-hook error for "%s": %s'):format(action, err))
            elseif elapsed > EventBus.Config.HookTimeout and EventBus.Config.LogTimeouts then
                print(('[DPS-Parking] EventBus: Post-hook "%s" took %dms (slow)'):format(hook.id, elapsed))
            end
        end)
    end
end

---Safely execute pre-hooks with guaranteed return
---@param action string Action name
---@param data table Action data
---@param maxWaitMs? number Maximum total wait time (default from config)
---@return boolean continue
---@return table data
function EventBus.SafeExecutePreHooks(action, data, maxWaitMs)
    maxWaitMs = maxWaitMs or EventBus.Config.MaxChainTimeout

    local p = promise.new()
    local resolved = false

    CreateThread(function()
        local continue, modifiedData = EventBus.ExecutePreHooks(action, data)
        if not resolved then
            resolved = true
            p:resolve({ continue = continue, data = modifiedData })
        end
    end)

    -- Safety timeout for entire hook chain
    SetTimeout(maxWaitMs, function()
        if not resolved then
            resolved = true
            print(('[DPS-Parking] EventBus: CRITICAL - Entire pre-hook chain for "%s" timed out! Proceeding with action.'):format(action))
            p:resolve({ continue = true, data = data })
        end
    end)

    local result = Citizen.Await(p)
    return result.continue, result.data
end

-- ============================================
-- CONVENIENCE METHODS
-- ============================================

---Register a hook (shorthand)
---@param action string Action with prefix (e.g., "pre:parking:park" or "post:parking:park")
---@param callback function
---@param priority? number
---@return string id
function EventBus.Hook(action, callback, priority)
    local hookType, actionName = action:match("^(%w+):(.+)$")

    if hookType == 'pre' then
        return EventBus.RegisterPreHook(actionName, callback, priority)
    elseif hookType == 'post' then
        return EventBus.RegisterPostHook(actionName, callback, priority)
    else
        -- If no prefix, treat as event subscription
        return EventBus.Subscribe(action, callback, priority)
    end
end

---Execute an action with hooks
---@param action string Action name
---@param data table Action data
---@param executor function The actual action to execute
---@return boolean success
---@return any result
function EventBus.ExecuteWithHooks(action, data, executor)
    -- Run pre-hooks
    local shouldContinue, modifiedData = EventBus.ExecutePreHooks(action, data)

    if not shouldContinue then
        return false, 'Cancelled by hook'
    end

    -- Execute the action
    local success, result = pcall(executor, modifiedData)

    if not success then
        print(('[DPS-Parking] EventBus: Action "%s" failed: %s'):format(action, result))
        return false, result
    end

    -- Run post-hooks
    EventBus.ExecutePostHooks(action, {
        input = modifiedData,
        result = result
    })

    return true, result
end

-- ============================================
-- DEBUG
-- ============================================

function EventBus.GetStats()
    local stats = {
        events = {},
        hooks = { pre = {}, post = {} }
    }

    for event, subs in pairs(EventBus._subscribers) do
        stats.events[event] = #subs
    end

    for action, hooks in pairs(EventBus._hooks.pre) do
        stats.hooks.pre[action] = #hooks
    end

    for action, hooks in pairs(EventBus._hooks.post) do
        stats.hooks.post[action] = #hooks
    end

    return stats
end

return EventBus
