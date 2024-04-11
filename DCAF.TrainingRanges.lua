-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                   DCAF.TrainingRange
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- https://static.e-publishing.af.mil/production/1/nellisafb/publication/afi13-212v1_accsup_nttrsup_add_a/afman13-212v1_nttr_add_a.pdf

DCAF_TrainingRange_Defaults = {
    SpawnInterval = 3,
    Audio = {
        Announcement = "Announcement.ogg",
        Message = "Message.ogg",
        Ready = "Ready.ogg"
    }
}

DCAF.TrainingRange = {
    ClassName = "DCAF.TrainingRange",
    Name = "TrainingRange",         -- #string - name of range
    IsActive = false,
    SpawnInterval = DCAF_TrainingRange_Defaults.SpawnInterval,  -- #number - interval used when spawning multiple range assets (prevents lag spikes)
    Spawns = {
        -- list of #SPAWN
    },
    ActivateHandlers = {
        -- list of #function( #DCAF.TrainingRange, ... )
    },
    DeactivateHandlers = {
        -- list of #function( #DCAF.TrainingRange, ... )
    },
    BeforeSpawnHandlers = {
        -- list of #function( #DCAF.TrainingRange, #SPAWN, ...)
    },
    SpawnedHandlers = {
        -- list of #function( #DCAF.TrainingRange, #GROUP, ...)
    },
    BurstEndHandlers = {
        -- list of #function(#DCAF_WpnTrack_ShellBurst)
    }
}

DCAF.TrainingTarget = {
    ClassName = "DCAF.TrainingTarget",
    Name = nil,                 -- #string - display name
    TemplateName = nil          -- #string - name of GROUP, to be activated/spawned
}

function DCAF.TrainingTarget:New(name, templateName)
    local tgt = DCAF.clone(DCAF.TrainingTarget)
    tgt.Name = name
    tgt.TemplateName = templateName
    return tgt
end

local TRAINING_RANGES_MENUS = {
    _keyMain = "_main_"
}
local _rebuildRadioMenus

local TRAINING_RANGES = { -- dictionary
    -- key   :: #string (name of #DCAF.TrainingRange)
    -- value :: #NTTR_RANGE
}

local TRAINING_RANGES_GROUPS = { -- dictionary (helps ensuring not two ranges control same spawn)
    -- key   :: #string (name of group, associated wit range)
    -- value :: #NTTR_RANGE
}

local DCAF_TrainingWeapons = {
    ["BDU_33"] = false, -- note: these already make a small 'puff' of smoke
    ["BDU_45"] = true,  -- high drag
    ["BDU_45LD"] = true,
    ["BDU_45LGB"] = true,
    ["BDU_50LD"] = true,
    ["BDU_50HD"] = true,
    ["BDU_50LGB"] = true
}

local _activatedSingletonGroups = {
    -- key   = group name
    -- value = range that activated it
}

--- Marks a group as activated by a range. This is to prevent spawning same group from a different range, also supporting it
local function addRangeSingletonGroup(group, range)
    _activatedSingletonGroups[group.GroupName] = range.Name
end

local function removeRangeSingletonGroups(rangeName)
    local groupNames = {}
    for groupName, _rangeName in pairs(_activatedSingletonGroups) do
        if _rangeName == rangeName then
            table.insert(groupNames, groupName)
        end
    end
    for groupName, _ in ipairs(groupNames) do
        _activatedSingletonGroups[groupName] = nil
    end
end

function DCAF.TrainingRange:New(name)
    local range = DCAF.clone(DCAF.TrainingRange)
    range.Name = name
    range.IsActive = false
    TRAINING_RANGES[name] = range
    return range
end

local function isPrefixPattern(s)
    local match = string.match(s, ".+[*]$")
    if match then
        return string.sub(s, 1, string.len(s)-1)
    end
end

DCAF.TRAINING_RANGE_ASSET_ACTIVATOR = {
    ClassName = "DCAF.TRAINING_RANGE_ASSET_ACTIVATOR",
    --
    Pattern = nil,              -- #string
    GroupNames = nil            -- #list of #string
}

function DCAF.TRAINING_RANGE_ASSET_ACTIVATOR:BuildGroupNames(structure)
    local pattern = isPrefixPattern(self.Pattern)
    local groupNames = {}
    local menuItems = {} -- those are needed to allow marking them as 'activated' later

    local function flattenGroupNames(item, filterFunc, result)
        result = result or {}
        if isClass(item, DCAF.TrainingRangeSubMenuGroupActivation) then
            if not isFunction(filterFunc) or filterFunc(item.Text) then
                table.insert(menuItems, item)
                for _, groupName in ipairs(item.GroupNames) do
                    table.insert(result, groupName)
                end
            end
            return result
        end
    end

    local function includePattern(text)
        local match = string.find(text, pattern)
        return match == 1
    end

    local function includeExact(text)
        return text == self.Pattern
    end
    local filterFunc
    if pattern then
        filterFunc = includePattern
    else
        filterFunc = includeExact
    end
    for _, item in ipairs(structure.Items) do
        flattenGroupNames(item, filterFunc, groupNames)
    end
    self.GroupNames = groupNames
    self.MenuItems = menuItems
end

function DCAF.TrainingRange.ActivateCategories(pattern)
    local activator = DCAF.clone(DCAF.TRAINING_RANGE_ASSET_ACTIVATOR)
    activator.Pattern = pattern
    return activator
end

local function DCAF_TrainingRange_addGroup(range, group)
    table.insert(range._groups, group)
end

DCAF.TRAINING_RANGE_MENU_SELECTION = {
    ClassName = "DCAF.TRAINING_RANGE_MENU_SELECTION",
    ----
    Function = nil,         -- #function
    Args = nil              -- #list of args
}

function DCAF.TrainingRange.MenuSelected(func, ...)
    local selected = DCAF.clone(DCAF.TRAINING_RANGE_MENU_SELECTION)
    selected.Function = func
    local args = {}
    for i = 1, #arg, 1 do
        table.insert(args, arg[i])
    end
    selected.Args = args
    return selected
end

DCAF.TRAINING_RANGE_RANDOM_SPAWN = {
    ClassName = "DCAF.TRAINING_RANGE_RANDOM_SPAWN",
    ----
    RemainingSpawns = 9999,
    Spawns = {
        -- list of #SPAWN (template)
    },
    Zones = {
        -- list of #ZONE
    }
}

function DCAF.TRAINING_RANGE_RANDOM_SPAWN:Spawn()
    local spawn = listRandomItem(self.Spawns)
    if not spawn then return Warning("DCAF.TRAINING_RANGE_RANDOM_SPAWN:Spawn :: could not resolve a random spawn/group :: IGNORES") end
    local zone = listRandomItem(self.Zones)
    if not zone then return Warning("DCAF.TRAINING_RANGE_RANDOM_SPAWN:Spawn :: could not resolve a random zone :: IGNORES") end
Debug("nisse - DCAF.TRAINING_RANGE_RANDOM_SPAWN:Spawn :: spawn: " .. DumpPretty(spawn) .. " :: zone: " .. DumpPretty(zone))
    DCAF_TrainingRange_addGroup(self.Range, spawn:SpawnInZone(zone, true))
    self.RemainingSpawns = self.RemainingSpawns - 1
end

--- Spawns a random group at a random location in a random zone
-- @param #Any groups - single #GROUP, name of GROUP, or list of #GROUPs/names of GROUPs
-- @param #Any destination - single #ZONE_BASE, name of ZONE_BASE, or list of #ZONE_BASEs/names of ZONE_BASEs
function DCAF.TrainingRange.SpawnRandom(source, zones)
    local validSpawns = {}
    if isListOfClass(source, SPAWN) then
        validSpawns = source
    elseif isAssignedString(source) then
        return DCAF.SpawnRandom({ source })
    elseif isListOfAssignedStrings(source) or isListOfClass(source, GROUP) then
        for i, o in ipairs(source) do
            local spawn = getSpawn(o)
            if not spawn then
                return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolved #GROUP from #" .. i .. ": '" .. o .. "'") end

            validSpawns[#validSpawns+1] = spawn
        end
    end
    if #validSpawns == 0 then
        return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolve #GROUPs from `source`:" .. DumpPretty(source)) end

    local validZones = {}
    if isListOfClass(zones, ZONE_BASE) then
        validZones = zones
    elseif isAssignedString(zones) then
        return DCAF.SpawnRandom(validSpawns)
    elseif isListOfAssignedStrings(zones) then
        for i, name in ipairs(zones) do
            local zone = ZONE:FindByName(name)
            if not zone then
                return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolved #ZONE from #" .. i .. ": '" .. name .. "'") end

            table.insert(validZones, zone)
        end
    end
    if #validZones == 0 then
        return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolve #ZONEs from `zones`:" .. DumpPretty(zones)) end

    local randomSpawn = DCAF.clone(DCAF.TRAINING_RANGE_RANDOM_SPAWN)
    randomSpawn.Spawns = validSpawns
    randomSpawn.Zones = validZones
    return randomSpawn
end

-- --- Spawns a random group at a random location in a random zone OBSOLETE
-- -- @param #table 
-- function DCAF.TrainingRange.SpawnRandom(groups, zones)
--     local validSpawns = {}
--     if isListOfAssignedStrings(groups) then
--         for i, name in ipairs(groups) do
--             local spawn = getSpawn(name)
--             if not spawn then
--                 return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolved #GROUP from #" .. i .. ": '" .. name .. "'") end

--             table.insert(validSpawns, spawn)
--         end
--     end
--     if #validSpawns == 0 then
--         return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolve #GROUPs from `groups`:" .. DumpPretty(groups)) end

--     local validZones = {}
--     if isListOfAssignedStrings(zones) then
--         for i, name in ipairs(zones) do
--             local zone = ZONE:FindByName(name)
--             if not zone then
--                 return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolved #ZONE from #" .. i .. ": '" .. name .. "'") end

--             table.insert(validZones, zone)
--         end
--     end
--     if #validZones == 0 then
--         return Error("DCAF.TrainingRange.SpawnRandom :: cannot resolve #ZONEs from `zones`:" .. DumpPretty(groups)) end

--     local randomSpawn = DCAF.clone(DCAF.TRAINING_RANGE_RANDOM_SPAWN)
--     randomSpawn.Spawns = validSpawns
--     randomSpawn.Zones = validZones
--     return randomSpawn
-- end

--- Finds and returns a named #DCAF.TrainingRange
-- @arg :: list of #string (name of group to be associated with range)
function DCAF.TrainingRange:WithGroups(...)  --  arg = list of template names

    local function getGroupsThatStartsWith(prefix)
        local groupNames = {}
        for _, group in pairs(_DATABASE.GROUPS) do
            local match = string.find(group.GroupName, prefix)
            if match == 1 then
                table.insert(groupNames, group.GroupName)
            end
        end
        return groupNames
    end

    local function init(name, i)
        if not isAssignedString(name) then
            error("NTTR_RANGE:WithGroups :: arg[" .. Dump(i) .. "] was not assigned string. Was instead: " .. DumpPretty(name)) end

        local range = TRAINING_RANGES_GROUPS[name]
        if range then
            error("NTTR_RANGE:WithGroups :: arg[" .. Dump(i) .. "] ('" .. name .. "') is already associated with range '" .. range.Name .."'") end

        table.insert(self.Spawns, getSpawn(name))
        TRAINING_RANGES_GROUPS[name] = self
    end

    for i = 1, #arg, 1 do
        local name = arg[i]
        local pattern = isPrefixPattern(name)
        if pattern then 
            local groupNames = getGroupsThatStartsWith(pattern)
            for _, groupName in ipairs(groupNames) do
                init(groupName, i)
            end
        else
            init(name, i)
        end
    end
    return self
end

--- Finds and returns a named #DCAF.TrainingRange
-- @name :: #string; name of range
function DCAF.TrainingRange:Find(name)
    return TRAINING_RANGES[name]
end

--- Returns value to indicate whether a range is activated
-- @name :: #string; name of range
function DCAF.TrainingRange:IsActive(name)
    return DCAF.TrainingRange:Find(name).IsActive
end

local function dcafTrainingRange_cancelSpawns(range)
    if not range._spawnScheduleIDs or #range._spawnScheduleIDs  == 0 then
        return end

    for _, scheduleID in ipairs(range._spawnScheduleIDs) do
        pcall(DCAF.stopScheduler, scheduleID)
    end
end

function DCAF.TrainingRange:SpawnAndCallback(callbackFunc, ...)
    local now = UTILS.SecondsOfToday()
    self._groups = self._groups or {}
    local groups
    if isFunction(callbackFunc) then
        groups = {}
    end

Debug("nisse - DCAF.TrainingRange:Spawn :: now: " .. UTILS.SecondsToClock(now) .. " :: _nextSpawn: " .. UTILS.SecondsToClock(self._nextSpawn or now))

    local function spawnNow(source)
        local spawn
        if isAssignedString(source) then
            spawn = self.Spawns[source]
            if not spawn then
                spawn = getSpawn(source)
                self.Spawns[source] = spawn
            end
        elseif isClass(source, SPAWN) then
            spawn = source
        end
        spawn:InitKeepUnitNames()

        -- EVENT: before spawn...
        for _, info in ipairs(self.BeforeSpawnHandlers) do
            local args = { self, spawn }
            for i = 1, #info.Arg, 1 do
                table.insert(args, info.Arg[i])
            end
            info.Func(unpack(args))
        end

        local group = spawn:Spawn()
        if groups then
            table.insert(groups, group)
        end

        DCAF_TrainingRange_addGroup(self, group)

        -- EVENT: after spawn...
        for _, info in ipairs(self.SpawnedHandlers) do
            local args = { self, group }
            for i = 1, #info.Arg, 1 do
                table.insert(args, info.Arg[i])
            end
            info.Func(unpack(args))
        end
    end

local test = 0

    local function scheduleSpawn(source, isLastSpawn)
        if not self._nextSpawn or now > self._nextSpawn then
            spawnNow(source)
            if isLastSpawn == true and isFunction(callbackFunc) then
                callbackFunc(groups, self)
            end
        else
            local delay = self._nextSpawn - now
-- Debug("DCAF.TrainingRange:Spawn :: delays spawn :: now: " .. UTILS.SecondsToClock(now) .. " :: _nextSpawn: " .. UTILS.SecondsToClock(self._nextSpawn) .. " :: delay: " .. delay .. " :: isLastSpawn: " .. Dump(isLastSpawn or false))
            DCAF.delay(function(finalSpawn)
-- Debug("nisse - scheduleSpawn_delay :: finalSpawn: " .. DumpPretty(finalSpawn) .. " :: test: " .. Dump(test))
                spawnNow(source)
                if finalSpawn == true and isFunction(callbackFunc) then
                    callbackFunc(groups, self)
                end
            end, delay, isLastSpawn)
        end
        self._nextSpawn = (self._nextSpawn or now) + self.SpawnInterval
    end

    for i = 1, #arg, 1 do
test = i        
        scheduleSpawn(arg[i], i == #arg)
    end
    -- return time needed before all is spawned
    return (self._nextSpawn-self.SpawnInterval) - now
end

function DCAF.TrainingRange:Spawn(...)
    return self:SpawnAndCallback(nil, ...)
end

local DCAF_TrainingRange_Reserved = {
    -- key   = 
}

local function activateRange(range, interval)
    local self = range
    Debug("DCAF.TrainingRange:Activate :: name: " .. Dump(self.Name) .. " :: interval: " .. Dump(interval or self.SpawnInterval) .. " :: self: " .. DumpPrettyDeep(self, 1))

    if self.IsActive then
        return end

    self._nextSpawn = nil
    self.IsActive = true
    if #self.Spawns > 0 then
        local isRangeComplete
        local function onRangeReady(groups)
            if isRangeComplete then
                return end

            isRangeComplete = true
            self._onRangeReadyFunc = nil
            MessageTo(nil, DCAF_TrainingRange_Defaults.Audio.Message)
            MessageTo(nil, "Range '" .. self.Name .. "' is now open and ready")
        end

        local secondsBeforeAllIsSpawned = self:SpawnAndCallback(onRangeReady, unpack(self.Spawns))
        if secondsBeforeAllIsSpawned <= self.SpawnInterval then
            if not isRangeComplete then
                isRangeComplete = true
                MessageTo(nil, "Range '" .. self.Name .. "' is now open")
            end
        else
            MessageTo(nil, DCAF_TrainingRange_Defaults.Audio.Message)
            MessageTo(nil, "Range '" .. self.Name .. "' should be ready in aprox. " .. secondsBeforeAllIsSpawned .. " seconds")
        end
    end
    _rebuildRadioMenus()
Debug("DCAF.TrainingRange:Activate :: ActivateHandlers: " .. DumpPretty(self.ActivateHandlers))
    for _, info in ipairs(self.ActivateHandlers) do
        local args = { self }
        for i = 1, #info.Arg, 1 do
            table.insert(args, info.Arg[i])
        end
        info.Func(unpack(args))
    end
end

--- Activates all groups associated with range
-- @name :: #string; specifies name of range to activate
-- @interval :: #number; specifies interval (seconds) between spawning groups associated with range (set to negative value to avoid spawning assets)
function DCAF.TrainingRange:Activate(name, interval, delay)
    if isAssignedString(name) then
        local range = DCAF.TrainingRange:Find(name)
        if not range then
            Error("DCAF.TrainingRange:Activate :: could not resolve range '" .. name .. "' :: IGNORES")
            return self
        end
        return range:Activate(nil, interval, delay)
    end

    Debug("DCAF.TrainingRange:Activate :: name: " .. Dump(self.Name) .. " :: interval: " .. Dump(interval or self.SpawnInterval) .. " :: self: " .. DumpPrettyDeep(self, 1))
    if self.IsActive then
        return end

    if DCAF_TrainingRange_Reserved[self.Name] then
        MessageTo(nil, DCAF_TrainingRange_Defaults.Audio.Message)
        MessageTo(nil, "Range '" .. self.Name .. "' is already scheduled for activation. Please coordinate with other flights")
    end

    if not isNumber(delay) then
        activateRange(self, interval)
        return
    end
    DCAF_TrainingRange_Reserved[self.Name] = true
    DCAF.delay(function()
        activateRange(self, interval)
        DCAF_TrainingRange_Reserved[self.Name] = nil
    end, delay)
end

function DCAF.TrainingRange:Deactivate(name)
    if isAssignedString(name) then
        local range = DCAF.TrainingRange:Find(name)
        if range then
            range:Deactivate()
        end
        return range
    end

    if not self.IsActive then
        return end

    self.IsActive = false
    dcafTrainingRange_cancelSpawns(self)
    self._onRangeReadyFunc = nil
    for _, group in ipairs(self._groups) do
        group:Destroy()
    end
    self._groups = nil
    MessageTo(nil, DCAF_TrainingRange_Defaults.Audio.Announcement)
    MessageTo(nil, "Training range '" .. self.Name .. "' is now closed")
    _rebuildRadioMenus()
    for _, info in ipairs(self.DeactivateHandlers) do
        local args = { self }
        for i = 1, #info.Arg, 1 do
            table.insert(args, info.Arg[i])
        end
        info.Func(unpack(args))
    end
end

function DCAF.TrainingRange:OnActivated(func, ...)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnActivated :: `func` must be function but was: " .. type(func)) end

    local existingIdx = tableIndexOf(self.ActivateHandlers, function(i) return i.Func == func end)
    if existingIdx then
        return end

    table.insert(self.ActivateHandlers, { Func = func, Arg = arg })
    return self
end

function DCAF.TrainingRange:EndOnActivated(func, ...)
    if not isFunction(func) then
        error("DCAF.TrainingRange:EndOnActivated :: `func` must be function but was: " .. type(func)) end

    local existingIdx = tableIndexOf(self.ActivateHandlers, function(i) return i.Func == func end)
    if not existingIdx then
        return end

    table.remove(self.ActivateHandlers, existingIdx)
    return self
end

function DCAF.TrainingRange:OnDeactivated(func, ...)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnDeactivated :: `func` must be function but was: " .. type(func)) end

    local existingIdx = tableIndexOf(self.DeactivateHandlers, function(i) return i.Func == func end)
    if existingIdx then
        return end

    table.insert(self.DeactivateHandlers, { Func = func, Arg = arg })
    return self
end

function DCAF.TrainingRange:OnBeforeSpawn(func, ...)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnBeforeSpawn :: `func` must be function but was: " .. type(func)) end

    local existingIdx = tableIndexOf(self.BeforeSpawnHandlers, function(i) return i.Func == func end)
    if existingIdx then
        return end

    table.insert(self.BeforeSpawnHandlers, { Func = func, Arg = arg })
    return self
end

function DCAF.TrainingRange:EndOnBeforeSpawn(func)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnBeforeSpawn :: `func` must be function but was: " .. type(func)) end

    local idx = tableIndexOf(self.BeforeSpawnHandlers, function(i) return i.Func == func end)
    if idx then
        table.remove(self.BeforeSpawnHandlers, idx)
    end
end

function DCAF.TrainingRange:OnSpawned(func, ...)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnSpawned :: `func` must be function but was: " .. type(func)) end

    local existingIdx = tableIndexOf(self.SpawnedHandlers, function(i) return i.Func == func end)
    if existingIdx then
        return end

    table.insert(self.SpawnedHandlers, { Func = func, Arg = arg })
    return self
end

function DCAF.TrainingRange:EndOnSpawned(func)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnSpawned :: `func` must be function but was: " .. type(func)) end

    local idx = tableIndexOf(self.SpawnedHandlers, function(i) return i.Func == func end)
    if idx then
        table.remove(self.SpawnedHandlers, idx)
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                      RANGE TARGET SCORING
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local DCAF_TargetScoreTracking = {
    Targets = {
        -- list of #DCAF_TrackedTarget
    },
    WpnTracker = nil,       -- #DCAF.WpnTracker
}

local DCAF_TrackedTarget = {
    ClassName = "DCAF_TrackedTarget",
    Name = nil,                     -- #string - name of target
    Description = nil,              -- #string - target description
    RangeName = nil,                -- #string - name of #DCAF.TrainingRange
    Location = nil,                 -- #DCAF.Location (the target)
    ScoreDefault = 1,               -- ##number - used for default, simple, scoring (1 hit = this score, regardless of where it hit etc)
    ScoreDelegate = nil             -- #function - used to resolve score
}

-- -- used to suppress 'impact' events from weapons that also hit a unit (we're only looking for one of those events)
-- -- each weapon, as it hits a unit, will have the corresponding 'impact' event suppressed for one second
-- local DCAF_SuppressedImpacts = {
--     -- key   = #number - weapond id
--     -- value = #number - supression expire time
-- }

local DCAF_TargetImpactMark = {
    Timestamp = nil,
    TargetCoordinate = nil,
    ImpactCoordinate = nil,
    MarkIDs = nil
}


DCAF.TrainingRangeScoreDelegate = {
    ClassName = "DCAF.TrainingRangeScoreDelegate"
    --- 
}

DCAF.TrainingRangeVisualImpactPoint = {
    ClassName = "DCAF.TrainingRangeVisualImpactPoint",
    --- 
    Size = 5,               -- meters
    Thickness = 1,          -- thickness of circle
}

function DCAF.TrainingRangeScoreDelegate:New()
    return DCAF.clone(DCAF.TrainingRangeScoreDelegate)
end

function DCAF.TrainingRangeScoreDelegate:Inherit(base)
    setmetatable(base, self)
    self.__index = function(table, key)
        return self[key]
    end
    self._base = base
    return self
end

function DCAF.TrainingRangeScoreDelegate:GetSuccessLevel()
    if self._success then 
        return self._success end 
 
    local MaxAllowedDistance = 150 
 
    local hdg = self.WpnTrack.DeployCoordinate:HeadingTo(self.WpnTrack.ImpactCoordinate) 
    self._targetCoordinate = self.TrackedTarget.Location:GetCoordinate() 
    self._brgFromTarget = self._targetCoordinate:HeadingTo(self.WpnTrack.ImpactCoordinate) 
    self._relBrgFromTarget = (self._brgFromTarget - hdg) % 360 
    self.WpnTrack.RelBrgFromTarget = self._relBrgFromTarget 
    local clockPos, clockPosText = GetClockPosition(nil, self._relBrgFromTarget) 
    self._clockPosText = clockPosText 
    self.WpnTrack.ClockPosText = clockPosText 
    local maxAllowedDistance = MaxAllowedDistance 
    if clockPos > 4 and clockPos < 8 then 
        maxAllowedDistance = 30 
    end 
    self._success = math.max(0, (maxAllowedDistance - self.ImpactDistance)) / 100 
 
    -- extra info ... 
    self._coordTarget = self.TrackedTarget.Location:GetCoordinate() 
    self._coordImpact = self.WpnTrack.ImpactCoordinate 
    self._ripDistance = self._coordTarget:Get2DDistance(self.WpnTrack.DeployCoordinate)  -- meters 
    self._ripAgl = self.WpnTrack.DeployAltitudeMSL - self._coordTarget:GetLandHeight()   -- meters 
    self._slantRange = self.WpnTrack.DeployCoordinate:Get3DDistance(self._coordTarget)   -- meters 
    return self._success 
end

function DCAF.TrainingRangeScoreDelegate:ClearCache()
    self._mapText = nil
    self._success = nil
end

function DCAF.TrainingRangeScoreDelegate:GetResultMapText()
    if self._mapText then 
        return self._mapText end 
    -- local trackedTarget = self.TrackedTarget 
    local wpnTrack = self.WpnTrack 
    local distance = self.ImpactDistance 
    local success = self:GetSuccessLevel() 
 
    local initiator = wpnTrack.IniUnit:GetPlayerName() or wpnTrack.IniUnit.UnitName 
    local slantRange = wpnTrack.DeployCoordinate:Get3DDistance(self._targetCoordinate) 
    local diveAngle = wpnTrack.DeployPitch 
 
-- RIP:    12.5Kft AGL / SR 2.5 NMI 
-- Dive:  Steep Wire  / Slightly Right 
-- Impact: 4 O'Clock 
 
    self._mapText = initiator .. " -- " .. wpnTrack.Type .. " [" .. UTILS.SecondsToClock(wpnTrack.DeployTime) .. "]\n"  
                              .. "RP:        " .. string.format('%.1f', UTILS.MetersToFeet(self._ripAgl)/1000) .. "Kft AGL / SR " .. string.format('%.1f', UTILS.MetersToNM(self._slantRange)) .." NMI\n" 
                              .. "Dive:     --- / ---\n" 
                              .. "Impact: " .. self._clockPosText .. ", " .. string.format('%.1f', distance) .. " m" 
    return self._mapText 
end

function DCAF.TrainingRangeScoreDelegate:GetResultMessageText()
    return self:GetResultMapText()
end
 
function DCAF.TrainingRangeScoreDelegate:GetMarkColor() 
    local success = self:GetSuccessLevel() 
    local color = { 1 - success, success, 0 } 
-- Debug("nisse - DCAF.TrainingRangeScoreDelegate:GetMarkColor :: success: " .. success .. " :: color: " .. DumpPretty(color)) 
    return { 1 - success, success, 0 } 
end 

function DCAF.TrainingRangeScoreDelegate:GetMarkAlpha()
    if not self._markAlpha then
        self._markAlpha = .5
    end
    return self._markAlpha
end

function DCAF.TrainingRangeScoreDelegate:Fade()
local nisse_alpha = (self._this or self):GetMarkAlpha()
    self._markAlpha = math.max(0, nisse_alpha - .1)
end

function DCAF.TrainingRangeScoreDelegate:DrawBombTarget(target, interval, radius)
-- Debug("nisse - DCAF.TrainingRangeScoreDelegate:DrawBombTarget :: target: " .. target.Name)
    local coord = target:GetCoordinate()
    if not coord then
        return end

    if not isNumber(interval) then
        interval = 20 -- meters
    end
    if not isNumber(radius) then
        radius = 100 -- meters
    end
    local colorBlack = { 0, 0, 0 }
    local colorRed = { 1, 0, 0 }
    local colorWhite = { 1, 1, 1 }
    local markIds = {
        coord:CircleToAll(radius, coalition.side.BLUE, colorWhite, .1, colorBlack, .025)
    }
    local count = math.floor(radius / interval) - 1
    for i = 1, count, 1 do
        table.insert(markIds, coord:CircleToAll(interval * i, coalition.side.BLUE, colorWhite, .5, nil, 0))
-- Debug("nisse - DCAF.TrainingRangeScoreDelegate:DrawBombTarget :: count: " .. count .. " :: radius / interval: " .. radius / interval)
    end
    return markIds
end

function DCAF.TrainingRangeScoreDelegate:DrawImpactPoint() 
-- Debug("nisse - DCAF.TrainingRangeScoreDelegate:DrawImpactPoint :: self: " .. DumpPrettyDeep(self, 1))     
    local coordImpact = self.WpnTrack.ImpactCoordinate 
    local coordTarget = self.TrackedTarget.Location:GetCoordinate() 
    local wpnTrack = self.WpnTrack 
    local distance = self.ImpactDistance 
    local success = self:GetSuccessLevel() 
    local color = self:GetMarkColor(self.TrackedTarget, wpnTrack, distance, success) 
    local alpha = self:GetMarkAlpha() 
    local text = self:GetResultMapText() 
    return { 
        coordTarget:LineToAll(coordImpact, nil, color, alpha, 3), 
        coordImpact:CircleToAll(5, nil, color, alpha),     
        coordImpact:Translate(6, 130):TextToAll(text, coalition.side.BLUE, color, alpha, nil, 0, 12), 
    } 
end 

function DCAF_TargetImpactMark:New(trackedTarget, wpnTrack, distance, success, alpha) -- coordTarget, coordImpact, distance, initiatior, success, alpha) 
    local im = DCAF.clone(DCAF_TargetImpactMark) 
    if not isNumber(success) then 
        success = 0 
    end 
    im.ImpactCoordinate = wpnTrack.ImpactCoordinate 
    im.Delegate = trackedTarget.ScoreDelegate 
    im.Delegate:ClearCache() 
    im.Delegate.TrackedTarget = trackedTarget 
    im.Delegate.WpnTrack = wpnTrack 
    im.Delegate.ImpactDistance = distance 
    im.Timestamp = UTILS.SecondsOfToday() 
    im:draw() 
    MessageTo(wpnTrack.IniUnit:GetGroup(), im.Delegate:GetResultMessageText(), 12) 
    return im 
end 

function DCAF_TargetImpactMark:draw()
    self.MarkIDs = self.Delegate:DrawImpactPoint()
end

function DCAF_TargetImpactMark:fade()
    self.Delegate:Fade()
    self:erase()
    self:draw()
end

function DCAF_TargetImpactMark:erase()
    for _, id in ipairs(self.MarkIDs) do
        self.ImpactCoordinate:RemoveMark(id)
    end
end

function DCAF_TrackedTarget:New(location, range, description, scoreDelegate)
    local tt = DCAF.clone(DCAF_TrackedTarget)
    tt.Name = location.Name
    tt.Description = description
    tt.RangeName = range.Name
    tt.Location = location
    tt.ScoreDelegate = scoreDelegate
    tt.ImpactMarks = {}
    return tt
end

function DCAF_TrackedTarget:markImpact(wpnTrack, distance, initiatior, success) -- success = 0.0 -> 1.0
    local function fade()
        local oldestTimestamp = 65535
        local oldestImpactMarkIndex = nil
        for i, impactMark in ipairs(self.ImpactMarks) do
            if impactMark.Timestamp < oldestTimestamp then
                oldestTimestamp = impactMark.Timestamp
                oldestImpactMarkIndex = i
            end
            impactMark:fade()
        end
        return oldestImpactMarkIndex
    end 

    local oldestImpactMarkIndex = fade()
    if #self.ImpactMarks == 4 then
        self.ImpactMarks[oldestImpactMarkIndex]:erase()
        self.ImpactMarks[oldestImpactMarkIndex] = nil
    end
    table.insert(self.ImpactMarks, DCAF_TargetImpactMark:New(self, wpnTrack, distance, success))
end

function DCAF_TrackedTarget:removeImpactMarks()
    for _, mark in pairs(self.ImpactMarks) do
        mark:erase()
    end
end

-- local function suppressWeaponImpact(wpnID)
--     local now = UTILS.SecondsOfToday()
--     local expired = {}
--     for k, expire in pairs(DCAF_SuppressedImpacts) do
--         if expire < now then
--             table.insert(expired, k)
--         end
--     end
--     for _, id in ipairs(expired) do
--         DCAF_SuppressedImpacts[id] = nil
--     end
--     DCAF_SuppressedImpacts[wpnID] = now + 1
-- end

-- local function isWeaponImpactSuppressed(wpnID)
--     return DCAF_SuppressedImpacts[wpnID]
-- end

local DCAF_WpnTrack_ShellBursts = {
    -- key   = player name
    -- value = #table - list of #DCAF_WpnTrack_ShellBurst
}

local DCAF_WpnTrack_CountOpenShellBursts = 0

local DCAF_StrafeWeapons = {
    ["M242_Bushmaster"] = true,  -- note - for testing only (allows slotting into Bradley to test burst/strafe logic)
    ["M_61"] = true,        -- Viper, Hornet
    ["M-61"] = true,        -- Strike Eagle
    ["GAU_12"] = true,      -- Harrier
    ["M-61A1"] = true,      -- Tomcat    
}

local DCAF_WpnTrack_PlayerWeapons = { -- index Player >> Which weapon is currently shooting
    -- key   = player name
    -- value = #string - weapon name
}

local DCAF_WpnTrack_OpenShellBursts = {
    -- key   = player name
    -- value = #DCAF_WpnTrack_ShellBurst - an ongoing burst
}

local DCAF_WpnTrack_ShellBurst_MaxIdleTime = 0.6

local DCAF_WpnTrack_ShellBurst = {
    Time = nil,             -- #number - timestamp for first hit
    Expires = nil,          -- #number - relative time for when burst expires (see #DCAF_WpnTrack_ShellBurstTimer)
    -- TimeLastHit = nil,   -- #number - timestamp for last hit (if > .5 sec, another burst gets recorded)
    ShellType = nil,        -- #string - type of shell
    RipAGL = nil,           -- #number - altitude over target when burst initiated
    RipPitch = nil,         -- #number - pitch when burst initiated
    RipSpeedKMH = nil,      -- #number - speed when burst initiated
    RipSlantRange = nil,    -- #number - slant range (3D distance from Unit -> Target), in meters
    RipDistance = nil,      -- #number - 2D distance from Unit -> Target, in meters
    RipCoordinate = nil,    -- #COORDINATE - shooter's coordinate
    TgtCoordinate = nil,    -- #COORDINATE - target's coordinate
    IsFinished = true,      -- #boolean - true = burst is finished (no more hits are recorded for it)
    Hits = {
        -- key   = #string - name of target
        -- value = #number - number of hits
    }
}

local DCAF_WpnTrack_ShellBurstTimer = {
    ScheduleID = nil,
    Tick = 0,               -- #number - time, measured in no. of times 
}

local DCAF_WpnTrack_ShellBurstEndHandlers = {
    -- key   = name of handler
    -- value = #function(#DCAF_WpnTrack_ShellBurst)
}

local DCAF_WpnTrack_WpnImpactHandlers = {
    -- key   = name of handler
    -- value = #function(#DCAF.WpnTrack)
}


function DCAF_WpnTrack_ShellBurstTimer.Get()
    local INTERVAL = .1

    if DCAF_WpnTrack_ShellBurstTimer.ScheduleID then
        return DCAF_WpnTrack_ShellBurstTimer.Tick end

    local function tick()
        DCAF_WpnTrack_ShellBurstTimer.Tick = DCAF_WpnTrack_ShellBurstTimer.Tick + INTERVAL
        local countOpen = 0
        for playerName, burst in pairs(DCAF_WpnTrack_OpenShellBursts) do
            if burst.Expires < DCAF_WpnTrack_ShellBurstTimer.Tick then
                burst:End()
            else
                countOpen = countOpen + 1
            end
        end
        if countOpen == 0  then
            Debug("DCAF_WpnTrack_ShellBurstTimer :: ENDS")            
            DCAF.stopScheduler(DCAF_WpnTrack_ShellBurstTimer.ScheduleID)
            DCAF_WpnTrack_ShellBurstTimer.ScheduleID = nil
        end
    end

    Debug("DCAF_WpnTrack_ShellBurstTimer :: STARTS")
    DCAF_WpnTrack_ShellBurstTimer.ScheduleID = DCAF.startScheduler(tick, INTERVAL)
    return DCAF_WpnTrack_ShellBurstTimer.Tick
end

function DCAF_WpnTrack_ShellBurstTimer.AddBurstEndHandler(name, func)
    DCAF_WpnTrack_ShellBurstTimer.BurstEndHandlers[name] = func
end

function DCAF_WpnTrack_ShellBurstTimer.RemoveEndBurstHandler(name)
    DCAF_WpnTrack_ShellBurstTimer.BurstEndHandlers[name] = nil
end

function DCAF_WpnTrack_ShellBurst:New(event, weaponType)
    local now = DCAF_WpnTrack_ShellBurstTimer.Get()
    local unit = event.IniUnit
    local tgt = event.TgtUnit
    local burst = DCAF.clone(DCAF_WpnTrack_ShellBurst)
    burst.Target = tgt
    burst.Unit = unit
    burst.PlayerName = unit:GetPlayerName()
    burst.Time = UTILS.SecondsToClock(UTILS.SecondsOfToday())
    burst.Expires = now + DCAF_WpnTrack_ShellBurst_MaxIdleTime
    burst.TgtCoordinate = tgt:GetCoordinate()
    burst.RipCoordinate = unit:GetCoordinate()
    burst.RipAGL = unit:GetAltitude() - tgt:GetAltitude()
    burst.RipPitch = unit:GetPitch()
    burst.RipSpeedKMH = unit:GetVelocityKMH()
    burst.RipSlantRange = burst.RipCoordinate:Get3DDistance(burst.TgtCoordinate)
    burst.RipDistance = burst.RipCoordinate:Get2DDistance(burst.TgtCoordinate)
    burst.ShellType = weaponType
    burst:AddHit(burst.Target, now)

    DCAF_WpnTrack_ShellBursts[burst.PlayerName] = burst
    DCAF_WpnTrack_OpenShellBursts[burst.PlayerName] = burst
    DCAF_WpnTrack_CountOpenShellBursts = DCAF_WpnTrack_CountOpenShellBursts + 1
    return burst
end

function DCAF_WpnTrack_ShellBurst:End()
-- MessageTo(nil, "nisse - Burst ends : " .. self._debugId)

    DCAF_WpnTrack_CountOpenShellBursts = DCAF_WpnTrack_CountOpenShellBursts - 1
    DCAF_WpnTrack_OpenShellBursts[self.PlayerName] = nil
    self.IsFinished = true
    self.RopCoordinate = self.Unit:GetCoordinate()
    local tgtCoordinate = self.Target:GetCoordinate()
    self.RopSlantRange = self.RopCoordinate:Get3DDistance(tgtCoordinate)
    self.RopDistance = self.RopCoordinate:Get2DDistance(tgtCoordinate)
    self.RopSpeedKMH = self.Unit:GetVelocityKMH()
    self.RopPitch = self.Unit:GetPitch()
    self.RopAGL = self.Unit:GetAltitude() - self.Target:GetAltitude()
    for _, handler in pairs(DCAF_WpnTrack_ShellBurstEndHandlers) do
        handler(self)
    end
end

function DCAF_WpnTrack_ShellBurst:AddHit(tgt, time)
    self.Expires = DCAF_WpnTrack_ShellBurstTimer.Get() + DCAF_WpnTrack_ShellBurst_MaxIdleTime
    local hit = self.Hits[tgt.UnitName]
    if not hit then
        self.Hits[tgt.UnitName] = 1
    else
        self.Hits[tgt.UnitName] = self.Hits[tgt.UnitName] + 1
    end
end

local function shootingStart(event)
    DCAF_WpnTrack_PlayerWeapons[event.IniUnitName] = event.weapon_name
end

local function playerLeftUnit(event)
-- Debug("nisse - playerLeftAirplane :: event: " .. DumpPretty(event))
    if not event.IniUnitName then
        return end
    
    DCAF_WpnTrack_PlayerWeapons[event.IniUnitName] = nil
end

local function trackHits(event)
-- Debug("nisse - trackHits :: event: " .. DumpPretty(event))
    local BurstMaxInterval = 1 -- second

    if not event.IniUnitName or not event.TgtUnit then
        return end
    
    local weaponType = DCAF_WpnTrack_PlayerWeapons[event.IniUnitName]
    if not weaponType or not DCAF_StrafeWeapons[weaponType] then
        return end

    local playerName = event.IniUnit:GetPlayerName()
    if not playerName then
        return end
       
    local burst = DCAF_WpnTrack_OpenShellBursts[playerName]
    if burst then
        burst:AddHit(event.TgtUnit)
    else
        -- start new burst
        burst = DCAF_WpnTrack_ShellBurst:New(event, weaponType)
    end
end

local function isTrainingWeapon(wpnTrack)
    return DCAF_TrainingWeapons[wpnTrack.Type]
end

local function wpnImpact(wpnTrack)
    -- if isWeaponImpactSuppressed(wpnTrack.ID) then return end
    local tt, distance = DCAF_TargetScoreTracking.findClosestTarget(wpnTrack.ImpactCoordinate, 200)
    if not tt then return end
    local ttCoordinate = tt.Location:GetCoordinate()
    wpnTrack.TargetName = trimSpawnIndex(tt.Name)
    wpnTrack.TargetCoordinate = tt.Location:GetCoordinate()
    local unit = wpnTrack.IniUnit
    local unitCoordinate = unit:GetCoordinate()
    wpnTrack.DeploySlantRange = unitCoordinate:Get3DDistance(wpnTrack.TargetCoordinate)
    wpnTrack.DeployDistance = unitCoordinate:Get2DDistance(wpnTrack.TargetCoordinate)
    wpnTrack.IsTrainingWeapon = isTrainingWeapon(wpnTrack)
    tt:markImpact(wpnTrack, distance, wpnTrack.IniUnit:GetPlayerName())
-- Debug("nisse - wpnImpact :: wpnTrack: " .. DumpPretty(wpnTrack))
    for name, handler in pairs(DCAF_WpnTrack_WpnImpactHandlers) do
        handler(wpnTrack)
    end
end

local function startTargetScoringWpnTracker()
    if DCAF_TargetScoreTracking.WpnTracker then
        return end

    DCAF_TargetScoreTracking.WpnTracker = DCAF.WpnTracker:New("Target Scoring"):Start(true)
    function DCAF_TargetScoreTracking.WpnTracker:OnImpact(wpnTrack)
        wpnImpact(wpnTrack)
    end

-- -- nisse
-- function DCAF_TargetScoreTracking.WpnTracker:OnUpdate(wpnTrack)
--     local weapon_desc = wpnTrack.Weapon:getDesc()
--     Debug("nisse - startTargetScoringWpnTracker :: weapon_desc: " .. DumpPrettyDeep(weapon_desc))
-- end
-- -- Debug("nisse - startTargetScoringWpnTracker :: DCAF_TargetScoreTracking.WpnTracker: " .. Dump(DCAF_TargetScoreTracking.WpnTracker ~= nil))

end

local function stopTargetScoringWpnTracker()
    if not DCAF_TargetScoreTracking.WpnTracker then
        return end

-- Debug("nisse - stopTargetScoringWpnTracker :: DCAF_TargetScoreTracking.WpnTracker: " .. Dump(DCAF_TargetScoreTracking.WpnTracker ~= nil))
    DCAF_TargetScoreTracking.WpnTracker:End()
    DCAF_TargetScoreTracking.WpnTracker = nil
end

function DCAF_TargetScoreTracking.addTarget(location, range, description, scoreDelegate)
    local tt = DCAF_TrackedTarget:New(location, range, description, scoreDelegate)
    table.insert(DCAF_TargetScoreTracking.Targets, tt)
    if #DCAF_TargetScoreTracking.Targets == 1 then
        MissionEvents:OnShootingStart(shootingStart)
        MissionEvents:OnUnitHit(trackHits)
        MissionEvents:OnPlayerLeftUnit(playerLeftUnit)
        startTargetScoringWpnTracker()
    end
-- Debug("nisse - DCAF_TargetScoreTracking.addTarget :: DCAF_TargetScoreTracking.Targets: " .. DumpPrettyDeep(DCAF_TargetScoreTracking.Targets, 2))
    return tt
end

function DCAF_TargetScoreTracking.removeTargetsForRange(range)
    tableRemoveWhere(DCAF_TargetScoreTracking.Targets, function(tt)
        if range.Name == tt.RangeName then
            tt:removeImpactMarks()
            return true
        end
    end)
    if #DCAF_TargetScoreTracking.Targets == 0 then
        MissionEvents:EndOnShootingStart(shootingStart)
        MissionEvents:EndOnUnitHit(trackHits)
        MissionEvents:EndOnPlayerLeftUnit(playerLeftUnit)
        stopTargetScoringWpnTracker()
        -- range.WpnTracker:End()
    end
end

--- Looks for and returns closest #DCAF_TrackedTarget from a coordinate
function DCAF_TargetScoreTracking.findClosestTarget(coord, radius)
    local distClosest = 65535
    local ttClosest = nil
    if not isNumber(radius) then
        radius = 200 -- meters
    end
    for _, tt in ipairs(DCAF_TargetScoreTracking.Targets) do
        local distance = tt.Location:GetCoordinate():Get2DDistance(coord)
        if distance < radius and distance < distClosest then
            distClosest = distance
            ttClosest = tt
        end
    end
    return ttClosest, distClosest
end

function DCAF_TargetScoreTracking.findByName(name)
    for i, tt in ipairs(DCAF_TargetScoreTracking.Targets) do
        if tt.Name == name then
            return tt, i
        end
    end
end

local function onTrainingRangeDeactivated(range)
    Debug("DCAF.TrainingRange:TrackTargetScore :: range deactivated: " .. range.Name)        
    DCAF_TargetScoreTracking.removeTargetsForRange(range)
    -- remove tracked bomb target renditions...
    for _, markId in ipairs(range._bombTargetMarkIDs) do
        range._refCoordinate:RemoveMark(markId)
    end
    range._bombTargetMarkIDs = nil
end

function DCAF.TrainingRange:SetScoreDelegate(scoreDelegate)
    if scoreDelegate ~= nil and not isClass(scoreDelegate, DCAF.TrainingRangeScoreDelegate.ClassName) then
        error("DCAF.TrainingRange:SetScoreDelegate :: `scoreDelegate` must be #" .. DCAF.TrainingRangeScoreDelegate.ClassName .. ", but was: " .. DumpPretty(scoreDelegate)) end
            
    self.DefaultScoreDelegate = scoreDelegate
    return self
end

function DCAF.TrainingRange:TrackBombTargetScore(source, description, scoreDelegate)
-- Debug("nisse - DCAF.TrainingRange:TrackBombTargetScore...")

    local target = DCAF.Location.Resolve(source)
   
    if not target then
        error("DCAF.TrainingRange:TrackTargetScore :: cannot resolve target from `source`: " .. DumpPretty(source)) end

    if not target:IsUnit() then
        error("DCAF.TrainingRange:TrackTargetScore :: target must be a unit, but was: " .. DumpPretty(target.Source.ClassName or target.Source)) end

    if description == nil then
        description = source
    elseif not isAssignedString(description) then
        error("DCAF.TrainingRange:TrackTargetScore :: `description` must be string, but was: " .. type(description)) end
    
    if scoreDelegate ~= nil and not isClass(scoreDelegate, DCAF.TrainingRangeScoreDelegate.ClassName) then
        error("DCAF.TrainingRange:TrackTargetScore :: `scoreDelegate` must be #" .. DCAF.TrainingRangeScoreDelegate.ClassName .. ", but was: " .. type(scoreDelegate)) end
    
    scoreDelegate = scoreDelegate or self.DefaultScoreDelegate or DCAF.TrainingRangeScoreDelegate:New()
-- Debug("nisse - DCAF.TrainingRange:TrackBombTargetScore :: scoreDelegate: " .. DumpPretty(scoreDelegate))

    if DCAF_TargetScoreTracking.findByName(target.Name) then
        error("DCAF.TrainingRange:TrackTargetScore :: `source` was already added: " .. DumpPretty(target.Name))  end

    DCAF_TargetScoreTracking.addTarget(target, self, description, scoreDelegate)

    -- render tracked bomb target...
    self._bombTargetMarkIDs = self._bombTargetMarkIDs or {}
    local markIds = scoreDelegate:DrawBombTarget(target)
    for _, markId in ipairs(markIds) do
        table.insert(self._bombTargetMarkIDs, markId)
    end

    self._refCoordinate = target:GetCoordinate()
    self:OnDeactivated(onTrainingRangeDeactivated)
    return self
end

function DCAF.TrainingRange:OnWpnImpact(func)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnWpnImpact :: `func` must be function, but was " .. type(func)) end

    DCAF_WpnTrack_WpnImpactHandlers[self.Name] = func
    self:OnDeactivated(function()
        DCAF_WpnTrack_WpnImpactHandlers[self.Name] = nil
    end)
-- Debug("nisse - DCAF_WpnTrack_WpnImpactHandlers: " .. DumpPretty(DCAF_WpnTrack_WpnImpactHandlers, DumpPrettyOptions:New():IncludeFunctions()))
    return self
end

function DCAF.TrainingRange:OnShellBurstEnd(func)
    if not isFunction(func) then
        error("DCAF.TrainingRange:OnShellBurstEnd :: `func` must be function, but was " .. type(func)) end

-- Debug("nisse - DCAF.TrainingRange:OnShellBurstEnd...")    
    DCAF_WpnTrack_ShellBurstEndHandlers[self.Name] = func
    self:OnDeactivated(function()
        DCAF_WpnTrack_ShellBurstEndHandlers[self.Name] = nil
    end)
-- Debug("nisse - DCAF.TrainingRange:OnShellBurstEnd: " .. DumpPrettyDeep(DCAF_WpnTrack_ShellBurstEndHandlers, 2))    
    return self
end


-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                         F10 RADIO MENUS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local function sort(ranges)
    local list = {}
    for k, v in pairs(ranges) do
        table.insert(list, v)
    end
    table.sort(list, function(a, b) 
        if a and b then
            if a.IsActive and not b.IsActive then
                return true
            elseif b.IsActive and not a.IsActive then
                return false
            else
                local result = a.Name < b.Name
                return result
            end
        elseif a then 
            return true
        else 
            return false 
        end
    end)
    return list
end

local function buildRangeDeactivateMenu(range)
    MENU_COALITION_COMMAND:New(coalition.side.BLUE, "CLOSE RANGE", range:GetMenu(), function() 
        range:Deactivate()
    end)
end

local _radioMenusCaption
local function buildRangesMenus(caption)
    caption = caption or _radioMenusCaption
    if not isAssignedString(caption) then
        caption = "Training Ranges"
    end
    _radioMenusCaption = caption
    local menuMain = TRAINING_RANGES_MENUS[TRAINING_RANGES_MENUS._keyMain]
    if menuMain then
        menuMain:RemoveSubMenus()
    else
        menuMain = MENU_COALITION:New(coalition.side.BLUE, caption)
        TRAINING_RANGES_MENUS[TRAINING_RANGES_MENUS._keyMain] = menuMain
    end
    local menu = DCAF.MENU:New(menuMain)
    -- sort menu so that active ranges comes first, then in alphanumerical order
    local sorted = sort(TRAINING_RANGES)
    for _, range in ipairs(sorted) do
        local menuText = range.Name
        if not range.IsActive then
            menuText = menuText .. " (closed)"
        end
        local mnuRange = menu:Blue(menuText)
        TRAINING_RANGES_MENUS[range.Name] = mnuRange
        if range.IsActive then
            buildRangeDeactivateMenu(range)
            if range._subMenuStructure then
                range:BuildSubMenus(range._subMenuStructure, range._onActivateFunc)
            end
        else
            MENU_COALITION_COMMAND:New(coalition.side.BLUE, "OPEN RANGE", mnuRange, function()
                range:Activate(range.Name)
            end)
        end
    end
end
_rebuildRadioMenus = buildRangesMenus

-------------------------------------------------------------------------------------------------------------------
--                                             SUPPORT FUNCTIONS
--                      allows for creating range sub menus from a declared structure
-------------------------------------------------------------------------------------------------------------------

-- SUB MENU STRUCTURES

DCAF.TrainingRangeSubMenuStructure = { -- dictionary
    ClassName = "DCAF.TrainingRangeSubMenuStructure", 
    Range = nil,       -- #DCAF.TrainingRange
    Items = {}         -- list of #DCAF.TrainingRangeSubMenuGroupActivation or #DCAF.TrainingRangeSubMenuCategory
}

DCAF.TrainingRangeSubMenuCategory = {
    ClassName = "DCAF.TrainingRangeSubMenuCategory",
    Parent = nil,      -- #DCAF.TrainingRangeSubMenuCategory | #DCAF.TrainingRangeSubMenuStructure
    Text = nil,        -- menu text
    Items = {}         -- list of #DCAF.TrainingRangeSubMenuGroupActivation or #DCAF.TrainingRangeSubMenuCategory
}

DCAF.TrainingRangeSubMenuGroupActivation = {
    ClassName = "DCAF.TrainingRangeSubMenuGroupActivation", 
    Parent = nil,      -- #DCAF.TrainingRangeSubMenuCategory | #DCAF.TrainingRangeSubMenuStructure
    Text = nil,        -- menu text
    GroupNames = {}    -- list of group names 
}

local function addItemsRaw(struct, dictionary)
    for key, v in pairs(dictionary) do
        local item
        if isClass(v, DCAF.TRAINING_RANGE_ASSET_ACTIVATOR) then
            item = v
            item.Text = key
        elseif isClass(v, DCAF.TRAINING_RANGE_MENU_SELECTION) then
            item = v
            item.Text = key
        elseif isClass(v, DCAF.TRAINING_RANGE_RANDOM_SPAWN) then
            item = v
            item.Text = key
        elseif isListOfAssignedStrings(v) then
            item = DCAF.TrainingRangeSubMenuGroupActivation:NewRaw(key, v)
            -- table.insert(struct.Items, item) obsolete
        elseif isDictionary(v) then
            item = DCAF.TrainingRangeSubMenuCategory:NewRaw(key, v, struct.Path, struct.Range)
            -- table.insert(struct.Items, item) obsolete
        else
            error("DCAF.TrainingRangeSubMenuStructure:New :: item '" .. Dump(key) .. "' was not a valid sub menu object: " .. DumpPretty(item))
        end
        table.insert(struct.Items, item)
        item.Range = struct.Range
        item.Parent = struct
        item.Path = struct.Path .. [[\]] .. key
    end
    return struct
end

local function addItems(struct, ...)
    for i = 1, #arg, 1 do
        local item = arg[i]
        if not isClass(item, DCAF.TrainingRangeSubMenuCategory.ClassName) and not isClass(item, DCAF.TrainingRangeSubMenuGroupActivation.ClassName) then
            error("DCAF.TrainingRangeSubMenuStructure:New :: item #" .. Dump(i) .. " was not a valid sub menu object: " .. DumpPretty(item)) end
        
        table.insert(struct.Items, item)
        item.Parent = struct
    end
    return struct
end

-- function DCAF.TrainingRangeSubMenuStructure:New(range, ...)
--     if not isClass(range, DCAF.TrainingRange) then
--         error("DCAF.TrainingRangeSubMenuStructure:New :: `range` must be #" .. DumpPretty(DCAF.TrainingRange.ClassName) .. ", but was: " .. DumpPretty(range)) end

--     local structure = DCAF.clone(DCAF.TrainingRangeSubMenuStructure)
--     structure.Range = range
--     return addItems(structure, ...)
-- end

function DCAF.TrainingRangeSubMenuStructure:NewRaw(range, table)
    local structure = DCAF.clone(DCAF.TrainingRangeSubMenuStructure)
    if not isTable(table) then
        error("DCAF.TrainingRangeSubMenuStructure:NewRaw :: `table` must be a table, but was: " .. DumpPretty(table)) end

    structure.Range = range
    structure.Path = ""
    return addItemsRaw(structure, DCAF.clone(table, nil, true))
end

-- function DCAF.TrainingRangeSubMenuCategory:New(text, ...)
--     if #arg == 1 and isDictionary(arg[1]) then
--         return DCAF.TrainingRangeSubMenuCategory:NewRaw(text, arg[1]) end

--     if not isAssignedString(text) then
--         error("DCAF.TrainingRangeSubMenuCategory:New :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

--     local category = DCAF.clone(DCAF.TrainingRangeSubMenuCategory)
--     category.Text = text
--     return addItems(category, { DCAF.TrainingRangeSubMenuCategory, DCAF.TrainingRangeSubMenuGroupActivation }, ...)
-- end

function DCAF.TrainingRangeSubMenuCategory:NewRaw(text, dictionary, path, range)
    if not isAssignedString(text) then
        error("DCAF.TrainingRangeSubMenuCategory:NewRaw :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

    local category = DCAF.clone(DCAF.TrainingRangeSubMenuCategory)
    category.Range = range
    category.Text = text
    category.Path = path .. [[\]] .. text
    return addItemsRaw(category, dictionary)
end

function DCAF.TrainingRangeSubMenuGroupActivation:New(text, ...)
    if not isAssignedString(text) then
        error("DCAF.TrainingRangeSubMenuGroupActivation:New :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

    if #arg == 1 and isAssignedString(arg[1]) then
        return DCAF.TrainingRangeSubMenuGroupActivation:NewRaw(text, arg[1]) end

    local activation = DCAF.clone(DCAF.TrainingRangeSubMenuGroupActivation)
    activation.Text = text
    for i = 1, #arg, 1 do
        if not isAssignedString(arg[i]) then
            error("DCAF.TrainingRangeSubMenuGroupActivation:New :: item #" .. Dump(i) .. " was expected to be string, but was: " .. DumpPretty(arg[i])) end

        table.insert(activation.GroupNames, arg[i])
    end
    return activation
end

function DCAF.TrainingRangeSubMenuGroupActivation:NewRaw(text, groupNames)
    local activation = DCAF.clone(DCAF.TrainingRangeSubMenuGroupActivation)
    activation.Path = text
    activation.Text = text
    activation.GroupNames = groupNames
    return activation
end

-------------------------- ACTIVATION

local KeyActivated = "_isActivated"
-- local _text_activateAll = "Activate all"
local rebuildRangeMenus

local function sortedItems(items)
    local list = {}
    for _, item in ipairs(items) do
        if not item[KeyActivated] then
            table.insert(list, item)
        end
    end
    table.sort(list, function(a, b)
        return a.Text <= b.Text
    end)
    return list
end

-- local function activateAll(range, structure)
--     for _, groupStruct in pairs(structure) do
--         groupStruct[KeyActivated] = true
--         for _, groupName in ipairs(groupStruct.GroupNames) do
--             range:Spawn(groupName)
--         end
--         rebuildRangeMenus(range, structure)
--     end
-- end

local function markMenuItemActivated(menuItem)
    menuItem[KeyActivated] = true
    if isClass(menuItem, DCAF.TRAINING_RANGE_ASSET_ACTIVATOR) then
        for _, subMenuItem in ipairs(menuItem.MenuItems) do
            subMenuItem[KeyActivated] = true
        end
    else
        if not menuItem.Parent then
            return end
    
        for _, siblingItem in ipairs(menuItem.Parent.Items) do
            if not siblingItem[KeyActivated] then
                return end
        end
    end
    markMenuItemActivated(menuItem.Parent)
end

DCAF.TrainingRangeCustomSpawnBehavior = {
    Spawned = "asset was spawned by custom function",
    Blocked = "asset should not be spawned as this time",
    Default = "unhandled by custom function - spawn asset using default method"
}

local function menuActivateGroups(structure, item, parentMenu, onActivateFunc)
    local range = structure.Range

-- Debug("nisse - menuActivateGroups :: item: " .. DumpPrettyDeep(item, 1))

    local function activateGroups()
        if isClass(item, DCAF.TRAINING_RANGE_RANDOM_SPAWN) then
            item:Spawn()
            if item.RemainingSpawns == 0 then
                item[KeyActivated] = true
            end
        else
            for _, groupName in ipairs(item.GroupNames) do
                range:Spawn(groupName)
            end
        end
        markMenuItemActivated(item)
-- Debug("nisse - menuActivateGroups :: structure: " .. DumpPrettyDeep(structure))
-- Debug("nisse - menuActivateGroups :: item.Parent: " .. DumpPretty(item.Parent))
        rebuildRangeMenus(range, structure, onActivateFunc)
    end

    local mnuManager = parentMenu
    mnuManager:BlueCommand(item.Text, function()
Debug("Range menu selected: " .. structure.Range.Name .. item.Path)
        if isFunction(onActivateFunc) then
            local behavior = onActivateFunc(item.GroupNames, item.Path)
            if behavior == DCAF.TrainingRangeCustomSpawnBehavior.Spawned then
                -- custom function has spawned assets; mark as activated...
                item[KeyActivated] = true
                rebuildRangeMenus(range, structure, onActivateFunc)
            elseif behavior == DCAF.TrainingRangeCustomSpawnBehavior.Default then
                -- custom function needs default activation mechanism...
                activateGroups()
            end
        elseif isClass(item, DCAF.TRAINING_RANGE_MENU_SELECTION) then
            if item.Args then
                item.Function(item.Range, unpack(item.Args))
            else
                item.Function(item.Range)
            end
            item[KeyActivated] = true
            rebuildRangeMenus(range, structure, onActivateFunc)
        elseif isClass(item, DCAF.TRAINING_RANGE_RANDOM_SPAWN) then
            item:Spawn()
            if item.RemainingSpawns == 0 then
                item[KeyActivated] = true
            end
            rebuildRangeMenus(range, structure, onActivateFunc)
        else
            if isClass(item, DCAF.TRAINING_RANGE_ASSET_ACTIVATOR) then
                item:BuildGroupNames(structure)
            end
            activateGroups()
        end
    end)
end

local function menuCategory(structure, category, parentMenu, onActivateFunc)
    local range = structure.Range
    local mnuCat = parentMenu:Blue(category.Text)
    local mnuManager = DCAF.MENU:New(mnuCat)
    local items = sortedItems(category.Items)
    for _, groups in ipairs(items) do
        menuActivateGroups(structure, groups, mnuManager, onActivateFunc)
    end
end

function DCAF.TrainingRange:BuildF10Menus(caption)
    buildRangesMenus(caption)
end

local function buildRangeMenus(range, structure, onActivateFunc)
    range._subMenuStructure = structure
    range._onActivateFunc = onActivateFunc
    local mnuRange = range:GetMenu()
    mnuRange:RemoveSubMenus()
    buildRangeDeactivateMenu(range)
    local mnuManager = DCAF.MENU:New(range:GetMenu(), 7)
    local items = sortedItems(structure.Items)
    for _, item in ipairs(items) do
        if isClass(item, DCAF.TrainingRangeSubMenuCategory) then
            menuCategory(structure, item, mnuManager, onActivateFunc)
        else
            menuActivateGroups(structure, item, mnuManager, onActivateFunc)
        end
    end
end
rebuildRangeMenus = buildRangeMenus

function DCAF.TrainingRange:BuildSubMenus(structure, onActivateFunc)
    if not isClass(structure, DCAF.TrainingRangeSubMenuStructure) then
        error("DCAF.TrainingRange:BuildSubMenus :: structure was expected to be #" .. DCAF.TrainingRangeSubMenuStructure.ClassName .. ", but was: " .. DumpPretty(structure)) end

    buildRangeMenus(self, structure, onActivateFunc)
end

function DCAF.TrainingRange:GetMenu()
    return TRAINING_RANGES_MENUS[self.Name]
end


-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Debug("\\\\\\\\\\\\\\\\\\\\ DCAF.TrainingRanges.lua was loaded ///////////////////")