-- https://skybrary.aero/articles/military-interception-signalling
--[[
    Possible nice images for document:
    https://www.flyingmag.com/nato-says-allied-forces-intercepted-more-than-300-russian-aircraft-in-2023/
    https://defence-industry.eu/danish-and-swedish-fighters-intercepted-russian-aircraft-over-baltic-sea/  
    https://en.wikipedia.org/wiki/Air_sovereignty#/media/File:McDonnell_Douglas_F-15C_Eagle_of_the_12th_FS_escorts_a_Russian_Tupolev_Tu-95MS_off_Alaska_(USA),_28_September_2006_(060928-F-0000X-104).jpg
    https://www.globaldefensecorp.com/2021/04/22/nato-scrambles-fighter-jet-to-intercept-russian-tu-160-blackjack/
    https://lithuaniatribune.com/baltic-air-policing-jets-intercept-russian-fighters/ 
]]

local DCAF_Interceptor_State = {
    None = "None",
    Approaching = "Approaching",
    Intercepting = "Intercepting",
    Leading = "Leading"
}

local DCAF_Interceptor_Animations = {
    Gear = {
        ["F-15ESE"] ={ Animation = 0, TriggerState = 1, Delay = 2 },
        ["F-16C_50"] = { Animation = 117, TriggerState = 1, Delay = 5 },
        ["FA-18C_hornet"] = { Animation = 0, TriggerState = 1, Delay = 2 },
    },
    Lights = {
        ["F-15ESE"] ={ Animation = { 200, 206, 191, 190 }, TriggerState = 1, Delay = 2 },
        ["F-16C_50"] = { Animation = { 190, 191 }, TriggerState = 1, Delay = 2 },
        ["FA-18C_hornet"] = { Animation = { 193, 190, 191 }, TriggerState = 1, Delay = 2 },
    }
}

DCAF.Interceptor = {
    ClassName = "DCAF.Interceptor",
    ----
    State = DCAF_Interceptor_State.None,
    Unit = nil,                 -- #UNIT (the interceptor)
    Group = nil,                -- #GROUP (the intercepting group)
    OwnLocation = nil,          -- #DCAF.Location:New(self.Unit)
    RestartInterception = true,
    LandAirbase = nil,          -- #AIRBASE to be used if interceptor signals "land now" (lowering gear) :: see :InitLandAirbase()
    LandRunway = nil,           -- #string (optional) runway to be used when LandAirbase is specified :: see :InitLandAirbase()
    LandRouting = false,        -- #boolean Specifies whether to build a route for follower as it is being sent to land
    TargetUnit = nil            -- #UNIT. When set, only this unit will be considered for interception (useful in many stories)
}

DCAF.InterceptorSignal = {
    WingRocking = "Wing rocking",
    Lights = "Lights",
    Departed = "Departed"
}

local DCAF_Interceptors = {
    -- key   = group name
    -- value = #DCAF.Interceptor
}

local DCAF_ClientInterceptor = {
    _restartInterception = DCAF.Interceptor.RestartInterception
}

function DCAF.Interceptor.DefaultInterceptorUnitCriteria(unit)
    local unitNumber = unit:GetDCSObject():getNumber()
Debug("nisse - DCAF.Interceptor:DefaultInterceptorUnitCriteria :: unitNumber: " .. Dump(unitNumber))
    return unitNumber == 1 or unitNumber == 3
end

--- Creates an interceptor group for all clients
-- @param #Any coalition - (optional) Can be #Coalition, or (DCS) number (DCS coalition.side enumerator). When set only units from specified coalition can be intercepted
-- @param #Any criteria - (optional) Can be funciton or coalition. When player slots in this criteria will have to be met for that unit to become interceptor
function DCAF.Interceptor:NewForClient(coalition, criteria)
    local ci = DCAF.clone(DCAF_ClientInterceptor)
    ci._coalition = coalition
    ci._criteria = criteria or self.DefaultInterceptorUnitCriteria
    return ci
end

--- Registers a function to be called back when client (player) interceptor is being automatically created
function DCAF_ClientInterceptor:OnCreated(func)
    if not isFunction(func) then return Error(DCAF.Interceptor.ClassName ..  ":OnCreated :: `func` must be function, but was: " .. DumpPretty(func)) end
    self._onCreatedFunc = func
-- Debug("nisse - DCAF_ClientInterceptor:OnCreated :: _onCreatedFunc: " .. Dump(self._onCreatedFunc))
    return self
end

-- --- Adds player menus that allows interceptor group some control/tools
-- -- @param #MENU parentMenu - (optional) Can be used to specify a parent menu for the player menus
-- function DCAF_ClientInterceptor:AddPlayerMenus(parentMenu)
--     self._addPlayerMenu = true
--     self._parentMenu = parentMenu
--     return self
-- end

--- Initializes the RestartInterception value. Pass false if interception should no longer be enabled after first interception completes
function DCAF_ClientInterceptor:InitRestartInterception(value)
    if not isBoolean(value) then
        value = true
    end
    self._restartInterception = value
    return self
end

function DCAF_ClientInterceptor:InitLandAirbase(airbase, runway)
    if isAssignedString(airbase) then
        local validAirbase = AIRBASE:FindByName(airbase)
        if not validAirbase then
            Error("DCAF.Interceptor:InitLandAirbase :: could not resolve `airbase`: '" .. airbase .. "' :: IGNORES")
            return
        end
        airbase = validAirbase
    elseif not isAirbase(airbase) then
        Error("DCAF.Interceptor:InitLandAirbase :: could not resolve `airbase`: '" .. airbase .. "' :: IGNORES")
        return
    end
    if runway ~= nil and not isAssignedString(runway) then
        Warning("DCAF.Interceptor:InitLandAirbase :: could not resolve `airbase`: '" .. airbase .. "' :: IGNORES")
    end
    self._landAirbase = airbase
    self._landRunway = runway
    return self
end

function DCAF_ClientInterceptor:InitLandRoute(altitude, altitudeType, speed)
    self._landRouting = { Altitude = altitude, AltitudeType = altitudeType, Speed = speed }
    return self
end

function DCAF_ClientInterceptor:InitTargetUnit(unit)
    local validUnit = getUnit(unit)
    if not validUnit then return Error("DCAF.Interceptor:InitTargetUnit :: `unit` must be #UNIT, or name of unit, but was: " .. DumpPretty(unit)) end
    self._targetUnit = validUnit
    return self
end

function DCAF_ClientInterceptor:Start(delay)
    self._startDelay = delay
    local ci = self
    BASE:HandleEvent(EVENTS.PlayerEnterAircraft, function(_, e)
        local unit = e.IniUnit
        if isFunction(ci.criteria) then
            if not ci._criteria(unit) then return end
        elseif ci._criteria ~= nil then
            -- check coalition...
            local validCoalition = Coalition.Resolve(ci._criteria, true)
            if validCoalition then
                if unit:GetCoalition() ~= validCoalition then return end
            end
        end
        local existing = DCAF_Interceptors[unit.UnitName]
        if existing then return end
        local interceptor = DCAF.Interceptor:New(unit, ci._coalition):InitRestartInterception(ci._restartInterception)
-- Debug("nisse - creating..." .. unit.UnitName .. "  :: ci._onCreatedFunc: " .. Dump(ci._onCreatedFunc))
        if ci._landAirbase then interceptor:InitLandAirbase(ci._landAirbase, ci._landRunway) end
        if ci._landRouting then interceptor:InitLandRout(ci._landRouting.Altitude, ci._landRouting.Speed, ci._landRouting.AltitudeType) end
        if ci._targetUnit then interceptor:InitTargetUnit(ci._targetUnit) end
        if ci._onCreatedFunc then ci._onCreatedFunc(interceptor) end
        interceptor:Start(ci._startDelay)
    end)
    return self
end

--- Creates an interceptor from group or unit
-- @param #Any source - Can be #UNIT, GROUP, or name of unit/group. Specifies the interceptor source
-- @param #Any filterCoalition - (optional) Can be #Coalition, or (DCS) number (DCS coalition.side enumerator). When set only units from specified coalition can be intercepted
function DCAF.Interceptor:New(source, filterCoalition)
    local validUnit = getUnit(source)
    local me = DCAF.clone(DCAF.Interceptor)
    if not validUnit then
        local validGroup = getGroup(source)
        if not validGroup then
            Warning("DCAF.Interceptor:New :: could not resolve `source` as #UNIT or #GROUP: " .. DumpPretty(source))
            return me
        end
        validUnit = validGroup:GetUnit(1)
    end
    if not validUnit then
        Warning("DCAF.Interceptor:New :: could not resolve `source` as #UNIT or #GROUP: " .. DumpPretty(source))
        return me
    end
    if filterCoalition then
        local validCoalition = Coalition.Resolve(filterCoalition)
        if not validCoalition then
            Warning("DCAF.Interceptor:New :: could not resolve `coalition`: " .. DumpPretty(filterCoalition))
            return me
        end
        filterCoalition = validCoalition
    end
    local existing = DCAF_Interceptors[validUnit.UnitName]
    if existing then
        if existing:IsLeading() then
            return Error("DCAF.Interceptor:New :: `source` unit '" .. validUnit.UnitName .. "' is already interceptor")
        end
        Warning("DCAF.Interceptor:New :: `source` unit '" .. validUnit.UnitName .. "' is already interceptor")
        return existing
    end

    me.Unit = validUnit
    me.UnitName = validUnit.UnitName
    me.Group = me.Unit:GetGroup()
    me.GroupName = me.Group.GroupName
    me.OwnLocation = DCAF.Location:New(me.Unit)
    me.OwnCoalition = me.Group:GetCoalition()
    me.OwnCountry = me.Group:GetCountry()
    me.FilterCoalition = filterCoalition
    DCAF_Interceptors[me.UnitName] = me
    return me
end

--- Looks for interceptor from a specified source (#UNIT, #GROUP, or name of unit/group)
-- returns #table - if one or more interceptors was found, each will be in the returned table. If no interceptors where found nil is returned
function DCAF.Interceptor:Find(source)
    local unit = getUnit(source)
    if unit then
        local interceptor = DCAF_Interceptors[unit.UnitName]
        if interceptor then return { interceptor } else return end
    end
    local group = getGroup(source)
    if not group then return end
    local found = {}
    local units = group:GetUnits()
    for _, unit in ipairs(units) do
        local interceptor = DCAF_Interceptors[unit.UnitName]
        if interceptor then found[#found+1] = interceptor end
    end
    if #found > 0 then return found end
end

--- Initializes the RestartInterception value. Pass false if interception should no longer be enabled after first interception completes
function DCAF.Interceptor:InitRestartInterception(value)
    if not isBoolean(value) then
        value = true
    end
    self.RestartInterception = value
    return self
end

function DCAF.Interceptor:InitLandAirbase(airbase, runway)
    self.LandAirbase = airbase
    self.LandRunway = runway
    return self
end

function DCAF.Interceptor:InitLandRoute(altitude, altitudeType, speed)
    self.LandRouting = { Altitude = altitude, Speed = speed, AltitudeType = altitudeType }
    return self
end

function DCAF.Interceptor:InitTargetUnit(unit)
    local validUnit = getUnit(unit)
    if not validUnit then return Error("DCAF.Interceptor:InitTargetUnit :: `unit` must be #UNIT, or name of unit, but was: " .. DumpPretty(unit)) end
    self.TargetUnit = validUnit
    return self

end

function DCAF.Interceptor:_cleanUp(minDistance, countTrigger)
    for unitName, info in pairs(self._units) do
        if info.Count < countTrigger then
            -- clean out units that wasn't close enough in the first place
            self._units[unitName] = nil
        else
            -- clean out units too far away, or dead
            local coordUnit = info.Unit:GetCoordinate()
            local coordOwn = self.OwnLocation:GetCoordinate()
            if coordUnit and coordOwn then
                local distance = coordOwn:Get3DDistance(coordUnit)
                if distance > minDistance then
                    self._units[unitName] = nil
                end
            else
                self._units[unitName] = nil
            end
        end
    end
    return self
end

function DCAF.Interceptor:_stopOnDead()
    local function stop()
        self:RemovePlayerMenu()
        self:Stop(true)
        return self
    end

    if not self.Group:IsAlive() then
        return stop()
    end
    if self.TargetUnit and not self.TargetUnit:IsAlive() then
        return stop()
    end
end

local function checkInInterceptArea(rp, triggerMaxDistance)
    if rp.SlantRange > triggerMaxDistance then return end
-- MessageTo(nil, "V: " .. rp.VerticalDiff .. " :: D: " .. rp.Direction)
    return rp.SlantRange <= triggerMaxDistance
           and
           (rp.VerticalDiff >= -20 and rp.VerticalDiff < 100)
           and
           (rp.Direction <= -90 or rp.Direction >= 90)
end

function DCAF.Interceptor:_stopScheduler()
    if not self._schedulerID then return self end
    DCAF.stopScheduler(self._schedulerID)
    self._schedulerID = nil
    return self
end

function DCAF.Interceptor:_monitorApproach() -- i == #DCAF.Interceptor
-- MessageTo(self.Group, self.GroupName .. " - nisse - APPROACHING...")
    -- look for nearby units. When same unit is in range for three executive scans, trigger _monitorIntercept...
    local TriggerCount = 3
    local TriggerMinDistance = 800 -- meters
    local MonitorInterval = 5

    self.State = DCAF_Interceptor_State.Approaching
    self:_stopScheduler()
    local me = self
    self._schedulerID = DCAF.startScheduler(function()
        me:_stopOnDead()
        local units
        if me.TargetUnit then
            -- just look for the target unit (more efficient)...
            local coordTargetUnit = me.TargetUnit:GetCoordinate()
            if not coordTargetUnit then return end
            local coordOwn = me.OwnLocation:GetCoordinate()
            if not coordOwn then
                return self:Stop()
            end
            local distance = me.OwnLocation:GetCoordinate():Get2DDistance(coordTargetUnit)
            if distance > TriggerMinDistance then return end
            units =  { [0] = { Unit = self.TargetUnit, Distance = distance } }
-- Debug("nisse - DCAF.Interceptor:_monitorApproach :: found single target: " .. me.TargetUnit.UnitName)
        else
            local scan = ScanAirborneUnits(me.OwnLocation, TriggerMinDistance, me.FilterCoalition, false, true, nil, true)
            if not scan:Any() then return end
            units = scan.Units
-- Debug("DCAF.Interceptor:_monitorApproach :: scan.Units: " .. DumpPrettyDeep(scan.Units, 2) )
        end

        local function isEstablishing(info)
            local unit = info.Unit
            if not unit:IsAlive()
               or unit:GetGroup().GroupName == me.Group then return end -- we don't intercept members of same group

            me._units =  me._units or {}
            local monitorInfo = me._units[unit.UnitName]
            if not monitorInfo then
                me._units[unit.UnitName] = { Unit = unit, Count = 1 }
                return
            end
-- MessageTo(me.Group, "nisse - approach " .. unit.UnitName .. " = " .. monitorInfo.Count .. "...")
            monitorInfo.Count = monitorInfo.Count + 1
            return monitorInfo.Count == TriggerCount or checkInInterceptArea(GetRelativePosition(me.OwnLocation, unit), TriggerMinDistance)
        end

        if #units > 1 then
            table.sort(units, function(a, b)
                return a.Distance < b.Distance
            end)
        end
        for _, info in ipairs(units) do
            if isEstablishing(info) then
                me:_monitorIntercept()
                return me:_cleanUp(TriggerMinDistance, TriggerCount)
            end
            me:OnApproaching(me._units)
        end
    end, MonitorInterval)
end

local function resetSignals(unit)
    unit._wingRockInfo = nil
    unit._wingRockInfo = nil
end

local function detectSignalLights(interceptor, triggerCountBlinks)
    local unit = interceptor.Unit
    if interceptor._isSignalInhibited or not unit:IsPlayer() then return end

    local info = DCAF_Interceptor_Animations.Lights[unit:GetTypeName()]
    if not info then return end

    if not isNumber(triggerCountBlinks) then
        triggerCountBlinks = 4
    end

    if not unit._icpt_lights then
        local lights = {}
        for _, animation in ipairs(info.Animation) do
            lights[animation] = math.round(unit:GetDrawArgumentValue(animation))
        end
        unit._icpt_lights = lights
        unit._icpt_lights_count_change = 0
        return
    end
    local isStateChanged = false
    for animation, state in pairs(unit._icpt_lights) do
        local currentState = math.round(unit:GetDrawArgumentValue(animation))
        if state ~= currentState then
            if not isStateChanged then
                unit._icpt_lights_count_change = unit._icpt_lights_count_change + 1
                isStateChanged = true
-- MessageTo(nil, "LIGHT SWITCH #" .. unit._icpt_lights_count_change .. " :: state: " .. state .. " :: currentState: " .. currentState .. " :: animation: " .. animation)
            end
        end
        unit._icpt_lights[animation] = currentState
    end
    if unit._icpt_lights_count_change >= triggerCountBlinks then
-- MessageTo(nil, "LIGHT SWITCH TRIGGER")
        unit._icpt_lights = nil
        unit._icpt_lights_count_change = nil
        return true
    end
end

local function detectSignalWingRock(interceptor, minBankAngle, minRockCount, maxTimeAllowed)
    local unit = interceptor.Unit
    if interceptor._isSignalInhibited or not unit:IsPlayer() then return end
    unit._wingRockInfo = unit._wingRockInfo or {
        ExpectMinBankAngle = nil,
        StartTime = nil
    }
    local info = unit._wingRockInfo
    local now = UTILS.SecondsOfToday()
    local totalTime = 0
    if info.StartTime then
        totalTime = now - info.StartTime
    end
    local bankAngle = unit:GetRoll()
    if not bankAngle then -- if unit gets killed GetRoll returns nil
        return end

    local absBankAngle = math.abs(bankAngle)
    minBankAngle = minBankAngle or 10
    minRockCount = minRockCount or 3 -- no. of times minimum bank angle must've been exceeded
    maxTimeAllowed = minRockCount * 2.25

    local function getIsWingRockComplete()
        if info.Count < minRockCount then return end
        if totalTime < maxTimeAllowed then
            return true
        end

        -- action took too long...
-- MessageTo(unit:GetGroup(), "WR too slow - restarting :: maxTimeAllowed: " .. maxTimeAllowed)
        info.Count = 0
        info.StartTime = nil
    end

-- Debug("nisse - _detectWingRock_getIsWingRockComplete :: totalTime: " .. totalTime .. " :: IsPlayer: " .. Dump(self.Unit:IsPlayer()))
    if not unit:IsPlayer() and totalTime > 5 then -- allow AI units to just spend 5 seconds in intercept location
        return true end

    if absBankAngle < minBankAngle then
        return end

    info.StartTime = info.StartTime or now
    if not info.ExpectMinBankAngle then
        if bankAngle < 0 then
            info.ExpectMinBankAngle = minBankAngle
        else
            info.ExpectMinBankAngle = -minBankAngle
        end
        info.Count = 1
        return
    end

    if info.ExpectMinBankAngle < 0 and bankAngle < info.ExpectMinBankAngle then
        info.Count = info.Count + 1
        info.ExpectMinBankAngle = minBankAngle
-- MessageTo(unit:GetGroup(), "nisse - WR #" .. info.Count .. " :: bankAngle: " .. bankAngle .." :: info: " .. DumpPretty(info))
    elseif info.ExpectMinBankAngle > 0 and bankAngle > info.ExpectMinBankAngle then
        info.Count = info.Count + 1
        info.ExpectMinBankAngle = -minBankAngle
-- MessageTo(unit:GetGroup(), "nisse - WR #" .. info.Count .. " :: bankAngle: " .. bankAngle .." :: info: " .. DumpPretty(info))
    end
    return getIsWingRockComplete()
end

local function detectRapidDeparture(interceptor)
    local unit = interceptor.Unit
    local followerUnit = interceptor.FollowerUnit
    if interceptor._isSignalInhibited then return end
    -- look for >20 degree pitch for 5 seconds...
    local rp = GetRelativePosition(unit, followerUnit)
    if rp.SlantRange > NauticalMiles(2) or rp.VerticalDiff > Feet(1500) then return true end
end

local function detectLoweredGear(interceptor)
    local unit = interceptor.Unit
    if interceptor._isSignalInhibited then return end
    local info = DCAF_Interceptor_Animations.Gear[unit:GetTypeName()]
    if not info then return end
    local now = UTILS.SecondsOfToday()
    local animationState = unit:GetDrawArgumentValue(info.Animation)
    if animationState < info.TriggerState then return end
    unit._loweredGearCheck = unit._loweredGearCheck or {
        LastCheck = now
    }
    if now > unit._loweredGearCheck.LastCheck + info.Delay then
        unit._loweredGearCheck = nil
        return true
    end
end

function DCAF.Interceptor:_monitorIntercept()
MessageTo(self.Group, self.Unit.UnitName .. " - nisse - INTERCEPTING...")
    local TriggerMaxDistance = 250 -- meters

    self.State = DCAF_Interceptor_State.Intercepting
    local nearbyUnits = {}
    for unitName, info in pairs(self._units) do
        nearbyUnits[unitName] = info.Unit
    end
    self:OnEstablishing(nearbyUnits)
    resetSignals(self.Unit)
    local me = self
    self:_stopScheduler()
    self._schedulerID = DCAF.startScheduler(function()
        me:_stopOnDead()
        local signal
        if detectSignalWingRock(me) then
            signal = DCAF.InterceptorSignal.WingRocking
        elseif detectSignalLights(me) then
            signal = DCAF.InterceptorSignal.Lights
        end
        for unitName, info in pairs(me._units) do
            -- interceptor is expected at a -30 --> -80 angle (left side) and fairly same level as intercepted aircraft...
            local rp = GetRelativePosition(me.OwnLocation, info.Unit)
            local debug_wasInInterceptArea
            local inInterceptArea = checkInInterceptArea(rp, TriggerMaxDistance)
            if self:IsDebug() then
                if not debug_wasInInterceptArea and inInterceptArea then
                    MessageTo(nil, "IN INTERCEPT AREA")
                end
            end
-- if isSignalComplete then
--     Debug("nisse - DCAF.Interceptor:_monitorIntercept :: rp: " .. DumpPretty(rp) .. " :: isInPosition: " .. Dump(inInterceptArea))
-- end
            if signal and inInterceptArea then
                resetSignals(me.Unit)
                self:_stopScheduler()
                me:OnSignalIntercept(info.Unit, signal)
            end
            if rp.SlantRange > TriggerMaxDistance then
                -- interceptor now too far away
                me._units[unitName] = nil
            end
        end
        if dictCount(me._units) == 0 then
            -- no aircraft in range for intercept; start over with approach phase...
Debug("nisse - DCAF.Interceptor:_monitorIntercept :: no aircraft in range :: goto APPROACH phase")
            me:_monitorApproach()
        end
    end, .25)
end

function DCAF.Interceptor:_monitorLeading()
    -- look for wing rock (= divert now), lowered gear (=land now), or continous high degree bank (= cancel leading/release following aircraft)
    local me = self
    self:_stopScheduler()
    self._schedulerID = DCAF.startScheduler(function()
-- Debug("nisse - DCAF.Interceptor:_monitorLeading :: Unit:IsAlive: " .. Dump(me.Unit:IsAlive()))
        if not me.Unit:IsAlive() then
            me:OnLeadUnitDead()
            me:Stop(true, "Lead unit dead")
            return
        elseif detectSignalWingRock(me) then
            me:OnSignalRelease(me.RestartInterception, true, DCAF.InterceptorSignal.WingRocking)
        elseif detectSignalLights(me) then
            me:OnSignalRelease(me.RestartInterception, true, DCAF.InterceptorSignal.Lights)
        elseif detectRapidDeparture(me) then
            me:OnSignalRelease(me.RestartInterception, false, DCAF.InterceptorSignal.Departed)
        elseif detectLoweredGear(me) then
            me:OnSignalLand(me.LandAirbase, me.LandRunway, me.RestartInterception)
            me:FollowerLand(airbase, runway, me.RestartInterception)
        end
    end, 1)
end

--- Called when the interceptor has signalled for the follower it is releasing it, either by way of rocking wings, flashing external lights, or it simply departed
-- @param #boolean restart - The interceptor should restart the interception process, allowing it to intercept more AI aircraft
-- @param #Any divert - (optional) If true, the released aircraft is ordered to go DIRECT its "_divert_" waypoint (if available). If set to a string it will instead go DIRECT to a steerpoint with a name matching that string
-- @param #DCAF.InterceptorSignal signal - Specifies typoe of signal used to release teh follower aircraft
-- The function can be overridden. Its default implementation is to just invoke the DCAF.Interceptor:FollowerRelease function, passing the same parameters, which will handle releasing the follower aircraft
function DCAF.Interceptor:OnSignalRelease(restart, divert, signal)
    self:FollowerRelease(restart, divert, signal)
end

--- Called when the interceptor has signalled for the follower to land (by lowering the gear)
function DCAF.Interceptor:OnSignalLand(airbase, runway, restart)
    Debug("nisse - DCAF.Interceptor:OnSignalLand :: airbase: " .. Dump(airbase) .. " :: runway: " .. Dump(runway) .. " :: restart: " .. Dump(restart))
    self:InhibitSignals(30)
    self:FollowerLand(airbase, runway, restart)
end

function DCAF.Interceptor:OnLeadUnitDead()
Debug("nisse - DCAF.Interceptor:OnLeadUnitDead")
    -- to be overridden
end

function DCAF.Interceptor:_resetInterception()
    self.FollowerUnit = nil
    self.FollowerGroup = nil
    self.FollowerCoalition = nil
    self.FollowerGroupName = nil
end

--- Enables the interceptor, making interception available to its UNIT/GROUP
-- @param #number delay - (optional) Will delay the start by this many seconds
function DCAF.Interceptor:Start(delay)
    self:_resetInterception()
    if not self.Group then return self end
    if isNumber(delay) then
        DCAF.delay(function()
            self:_monitorApproach()
        end, delay)
    elseif self.State == DCAF_Interceptor_State.None then
        self:_monitorApproach()
    end
    -- if self._menu then
    --     self:AddPlayerMenus()
    -- end
    return self
end

--- Disables the interceptor, making interception unavailable to its UNIT/GROUP
-- @param #boolean release - Specifies whether the follower should be released
-- @param #string reason - (optional) Specifies a reason for stopping the interception
function DCAF.Interceptor:Stop(release, reason)
    if not self.Group then return self end
    self:_stopScheduler()
    self.State = DCAF_Interceptor_State.None
    if release then
        self:FollowerRelease(false, false, reason or ":Stop")
    end
    -- if self._menu then
    --     self:AddPlayerMenus()
    -- end
    return self
end

function DCAF.Interceptor:IsLeading()
Debug("nisse - DCAF.Interceptor:IsLeading :: .State: " .. Dump(self.State))
    return self.State == DCAF_Interceptor_State.Leading
end

--- Invoked as interceptor approaches one or more units that can be intercepted
-- @param #table nearbyUnits - A dictionary of nearby units (key=unit name, value={ Unit = #UNIT, Distance = #number (meters) })
function DCAF.Interceptor:OnApproaching(nearbyUnits)
    -- to be overridden
end

--- Invoked when interceptor is close to one or more units that can be intercepted
-- @param #table nearbyUnits - A dictionary of nearby units (key=unit name, value=#UNIT)
function DCAF.Interceptor:OnEstablishing(nearbyUnits)
    -- to be overridden
end

function DCAF.Interceptor:GetActor()
    if not self.Unit then return "(unknown)" end
    local actor = self.Unit:GetPlayerName()
    if actor then return actor else return self.Unit.UnitName end
end

--- Is called automatically when interceptor is signalling an intercept to a unit
-- @param #Any unit - The unit or group being signalled. Can be specified as #UNIT, #GROUP, or name of unit/group. When resolved as GROUP, the #1 unit will be selected for interception
-- @param #DCAF.InterceptorSignal signal - Type of signal used
-- @remarks This method simply invokes the DCAF.Interceptor:Intercept function to implement standard behavior from intercepted unit. Override to implement custom behavior as unit gets signalled by interceptor
function DCAF.Interceptor:OnSignalIntercept(unit, signal)
    local msg = self:GetActor() .. " signals interception to " .. unit.UnitName .. " (" .. signal .. ")"
    Debug("DCAF.Interceptor:OnSignalIntercept :: " .. msg)
    self:InhibitSignals(30)
    if self:IsDebug() then
        MessageTo(nil, msg)
    end
    self:Intercept(unit, signal)
end

--- Initiates an intercept, targeting a specified unit/group. This function is automatically invoked when interceptor aircraft signals "you are intercepted" (by means of wing rocking  and/or flashing external lights)
-- @param #Any intercepted - The intercepted unit or group. Can be specified as #UNIT, #GROUP, or name of unit/group. When resolved as GROUP, the #1 unit will be selected for interception
-- @param #DCAF.InterceptorSignal signal - Type of signal used
-- @remarks This method simply invokes the DCAF.Interceptor:OnIntercepted function to implement standard behavior from intercepted unit
function DCAF.Interceptor:Intercept(intercepted, signal)
    local unit = getUnit(intercepted)
    if not unit then
        local group = getGroup(intercepted)
        if not group then return Error("DCAF.Interceptor:Intercept :: cannot resolve intercepted unit: " .. DumpPretty(intercepted)) end
        unit = group:GetUnit(1)
    end
    if signal == nil then 
        signal = DCAF.InterceptorSignal.Lights
    elseif signal ~= DCAF.InterceptorSignal.Lights and signal ~= DCAF.InterceptorSignal.WingRocking then
        return Error("DCAF.Interceptor:Intercept :: unsupported signal type: " .. DumpPretty(signal))
    end
    self:OnIntercepted(unit, signal)
Debug("DCAF.Interceptor:OnIntercepted :: interceptor: " .. self.UnitName .. " :: intercepted: " .. unit.UnitName .. " :: signal: " .. signal)
end

--- Invoked when interceptor aircraft has signalled "you are intercepted" (by means of wing rocking  and/or flashing external lights)
-- @param #UNIT unit - The intercepted unit
-- @param #DCAF.InterceptorSignal signal - Type of interception signal used
-- @remarks This method can be overridden but the default implementation always invokes the `FollowMe` function
function DCAF.Interceptor:OnIntercepted(unit, signal)
    if not self.Unit then return self end
    if self:IsDebug() then
        local actor = self.Unit:GetPlayerName()
        if not actor then actor = self.Unit.UnitName end
        MessageTo(nil, unit:GetGroup().GroupName .. " is INTERCEPTED by " .. actor .. "(" .. signal .. ")")
    end
Debug("DCAF.Interceptor:OnIntercepted :: unit: " .. unit.UnitName .. " :: signal: " .. Dump(signal))
    self:FollowMe(unit)
end

--- Invoked when interceptor is has intercepted an aircraft and it is now following the interceptor
-- @param #UNIT unit - The aircraft that is now following the interceptor
function DCAF.Interceptor:OnLeading(unit)
-- MessageTo(self.Group, "nisse - AIRCRAFT is FOLLOWING...")
    -- to be overridden
end

--- Invoked when follower aircraft is released, and allowed to continue its route
-- @param #GROUP followerGroup - The follower group
function DCAF.Interceptor:OnFollowerReleased(followerGroup)
-- MessageTo(nil, "nisse - AIRCRAFT is RELEASED")
    -- to be overridden
end

--- Invoked when follower aircraft is ordered to divert
-- @param #GROUP followerGroup - The follower group
-- @remarks Fow follower group to be able to divert its route must contain a waypoint named '_divert_'
function DCAF.Interceptor:OnFollowerDiverted(followerGroup)
-- MessageTo(nil, "nisse - AIRCRAFT was DIVERTED")
Debug("nisse - DCAF.Interceptor:OnFollowerDiverted  :: " .. DCAF.StackTrace())
    -- to be overridden
end

--- Invoked when follower aircraft is ordered to land
-- @param #GROUP followerGroup - The follower group
function DCAF.Interceptor:OnFollowerLands(airbase, followerGroup)
-- MessageTo(nil, "nisse - AIRCRAFT is LANDING")
    -- to be overridden
end

local function ensureCoalition(group, dcsCoalition, dcsCountry, templateSuffix)
    local c = group:GetCoalition()
    if c == dcsCoalition then return group end
    local template = group:GetTemplate()
    template.SpawnCoalitionID = dcsCoalition
    template.CoalitionID = dcsCoalition
    dcsCountry = dcsCountry or DCAF.DefaultCountries.CountryIDs[dcsCoalition]
    template.CountryID = dcsCountry
    template.SpawnCountryID = dcsCountry
    templateSuffix = templateSuffix or "_c"
    local spawn = SPAWN:NewFromTemplate(template, group.GroupName .. templateSuffix):InitHeading(group:GetHeading())
    Debug("ensureCoalition :: respawning group '" .. group.GroupName .. "' for coalition: " .. dcsCoalition)
    group:Destroy()
    local respawnedGroup = spawn:SpawnFromCoordinate(group:GetCoordinate())
    respawnedGroup._orig_coalition = c
    return respawnedGroup
end

DCAF.Offset = {
    ClassName = "DCAF.Offset",
    ----
    Elevation = 10,               -- x
    Longitudinal = Feet(-700),    -- y
    Horizontal = Feet(1000),      -- z
}

function DCAF.Offset:New(distance, elevation, interval)
    local offset = DCAF.clone(DCAF.Offset)
    offset.Longitudinal = distance or DCAF.Offset.Longitudinal
    offset.Elevation = elevation or DCAF.Offset.Elevation
    offset.Horizontal = interval or DCAF.Offset.Horizontal
    return offset
end

function DCAF.Offset:ToVec3()
    return {
        ["x"] = self.Longitudinal,
        ["y"] = self.Elevation,
        ["z"] = self.Horizontal
    }
end

local function getFollowTask(group, offset)
    offset = offset or DCAF.Offset
    return {
        ["id"] = "Follow",
        ["params"] = {
            ["lastWptIndexFlagChangedManually"] = false,
            ["groupId"] = group:GetID(),
            ["lastWptIndexFlag"] = false,
            ["pos"] = offset:ToVec3(),
        },
    }
end

--- Prevents pilot/AI from (accidentally) signalling to an AI aircraft
-- @param #number timeout - (optional) When set; the signal inhibiton is removed after this timeout
function DCAF.Interceptor:InhibitSignals(time)
    if time ~= nil then
        if not isNumber(time) then return Error("DCAF.Interceptor:InhibitSignals :: `time` must be number, but was: " .. DumpPretty(time)) end
        DCAF.delay(function()
            self._isSignalInhibited = false
        end, time)
    end
    self._isSignalInhibited = true
end

--- Forces a UNIT to follow the interceptor unit
-- @param #Any follower - The #UNIT/#GROUP or name of unit/group that will be forced to follow the interceptor
-- @remarks This will also trigger a call to the OnLeading function
function DCAF.Interceptor:FollowMe(follower, offset)
    local validUnit = getUnit(follower)
    if not validUnit then
        local validGroup = getGroup(follower)
        if validGroup then
            validUnit = validGroup:GetUnit(1)
        end
    end
    if not validUnit then
        return exitWarning("DCAF.Interceptor:FollowMe :: could not resolve `follower`: " .. DumpPretty(follower)) end

    if not self.Group then return self end
    if not isClass(offset, DCAF.Offset) then offset = DCAF.Offset:New() end
    self.State = DCAF_Interceptor_State.Leading
    follower = validUnit
    local followerGroup = follower:GetGroup()
    self.FollowerCoalition = followerGroup:GetCoalition()
    self.FollowerGroup = followerGroup
    self.FollowerGroupName = followerGroup.GroupName
    self.FollowerUnit = follower
    local taskFollow = getFollowTask(self.Group, offset)
-- local mooseTaskFollow = self.FollowerGroup:TaskFollow(self.Unit, offset:ToVec3())
    local controller = self.FollowerGroup:_GetController()
Debug("nisse - DCAF.Interceptor:FollowMe :: " .. self.FollowerGroup.GroupName .. " :: hasTask: " .. Dump(controller:hasTask()))
    if controller:hasTask() then
        controller:popTask()
    end
    -- let follower slip back for a bit before it starts following...
    ChangeSpeed(follower, Knots(-50))
    DCAF.delay(function()
        controller:pushTask( taskFollow )
    end, 20)
-- MessageTo(nil, "nisse - " .. self.FollowerGroup.GroupName .. " is FOLLOWING " .. self.Unit.UnitName)
    -- self.FollowerGroup:PushTask(taskFollow)
    -- if self._menu then
    --     self:AddPlayerMenus()
    -- end
    local me = self
    DCAF.delay(function() me:_monitorLeading() end, 2)
    self:OnLeading(self.FollowerUnit)
end

--- Releases follower aircraft, allowing it to continue its route
-- @param #boolean restart - (optional; default: self.RestartInterception) When set, the interceptor state is reset to allow further interceptions
-- @param #Any divert - (optional) If true, the released aircraft is ordered to go DIRECT its "_divert_" waypoint (if available). If set to a string it will instead go DIRECT to a steerpoint with a name matching that string
-- @remarks This will also trigger a call to the OnFollowerReleased or OnFollowerDiverted (depending on `divert` parameter)
function DCAF.Interceptor:FollowerRelease(restart, divert, debug_reason)
    if not self.Group then return self end
    if not self.FollowerGroup then return end

    Debug("DCAF.Interceptor:FollowerRelease :: follower group: " .. self.FollowerGroup.GroupName .. " :: lead: " .. self.Unit.UnitName .. " :: reason: " .. Dump(debug_reason) .. " :: divert: " .. Dump(divert))
    if self:IsDebug() then
        MessageTo(nil, "Intercepted group - " .. self.FollowerGroupName .. " was released (" .. debug_reason .. ")")
    end

    if not isBoolean(divert) then divert = true end
    self.FollowerGroup:PopCurrentTask()
    if divert then
        if isAssignedString(divert) then
            Divert(self.FollowerGroup, divert)
        else
            Divert(self.FollowerGroup)
        end
        self:OnFollowerDiverted(self.FollowerGroup)
    else
        self:OnFollowerReleased(self.FollowerGroup)
    end
    self.FollowerGroup = nil
    self.FollowerGroupName = nil
    if not isBoolean(restart) then restart = true end
    if restart then
        self:Start()
    else
        self:Stop(false)
    end
end

--- Releases follower aircraft and orders it to land at specified, order nearest, airdrome.
-- @param #Any airbase - (optional) Can be #AIRBASE or name of airbase. When specified the follower will land at this airdrome, if possible
-- @param #boolean restart - (optional; default: self.RestartInterception) When set, the interceptor state is reset to allow further interceptions
function DCAF.Interceptor:FollowerLand(airbase, runway, restart)
    if not self.Group then return self end
    if airbase then
        if isAssignedString(airbase) then
            local validAirbase = AIRBASE:FindByName(airbase)
            if not validAirbase then
                Error("DCAF.Interceptor:FollowerLand :: could not resolve airbase name: '" .. airbase .. "' :: IGNORES")
                self:FollowerRelease(restart, false, "land (unresolved airbase)")
                return
            end
            airbase = validAirbase
        elseif not isAirbase(airbase) then
            Error("DCAF.Interceptor:FollowerLand :: could not resolve airbase: '" .. airbase .. "' :: IGNORES")
            self:FollowerRelease(restart, false, "land (unresolved airbase)")
            return
        end
    end
    -- land at closest airbase...
-- MessageTo(self.Group, "AIRCRAFT departs to LAND...")

    airbase = airbase or self.OwnLocation:GetCoordinate():GetClosestAirbase(Airbase.Category.AIRDROME)
    local useAirbase, useRunway = self:OnFollowerLands(airbase, self.FollowerGroup)
    airbase = useAirbase or airbase
-- Debug("nisse - DCAF.Interceptor:FollowerLand :: airbase: " .. airbase.AirbaseName .. " :: coalition: " .. airbase:GetCoalition() .. " :: follower coalition: " .. self.FollowerGroup:GetCoalition())
    -- TODO - consider delaying ensuring coalition until later. It doesn't look very good as the follower aircraft gets respawned nearby
    self.FollowerGroup = ensureCoalition(self.FollowerGroup, airbase:GetCoalition(), airbase:GetCountry())
    if self.LandRouting then
        RTBNow(self.FollowerGroup, { Airbase = airbase, Runway = useRunway or runway }, nil, self.LandRouting.Altitude, self.LandRouting.AltitudeType, self.LandRouting.Speed)
    else
        self.FollowerGroup:RouteRTB(airbase)
    end
    if restart or self.RestartInterception then
        self:Start()
    else
        self:Stop(false)
    end
end

function DCAF.Interceptor:Debug(value)
    if not isBoolean(value) then value = true end
    self._debug = value
    return self
end

function DCAF.Interceptor:IsDebug() return self._debug end

-- --- Adds player menus that allows interceptor group some control/tools
-- -- @param #MENU parentMenu - (optional) Can be used to specify a parent menu for the player menus
-- function DCAF.Interceptor:AddPlayerMenus(parentMenu)
--     if not self.Group or not self.Unit:IsPlayer() then return self end
--     if self._menu then
--         self._menu:Remove()
--     end
--     local me = self
--     parentMenu = parentMenu or me._parentMenu
--     me._parentMenu = parentMenu
--     if self.State == DCAF_Interceptor_State.None then
--         self._menu = MENU_GROUP_COMMAND:New(self.Group, "INTERCEPT: Begin", parentMenu, function()
--             me:Start()
--             me:AddPlayerMenus(parentMenu)
--         end)
--     elseif self.State == DCAF_Interceptor_State.Approaching or self.State == DCAF_Interceptor_State.Intercepting then
--         self._menu = MENU_GROUP_COMMAND:New(self.Group, "INTERCEPT: Cancel", parentMenu, function()
--             me:Stop()
--             me:AddPlayerMenus(parentMenu)
--         end)
--     elseif self.State == DCAF_Interceptor_State.Leading then
--         self._menu = MENU_GROUP:New(self.Group, "Intercept", parentMenu)
--         MENU_GROUP_COMMAND:New(self.Group, "CANCEL", self._menu, function()
--             me:Stop()
--             me:AddPlayerMenus(parentMenu)
--         end)
--         MENU_GROUP_COMMAND:New(self.Group, "DIVERT", self._menu, function()
--             me:FollowerRelease(true, true, "divert (from menu)")
--             me:AddPlayerMenus(parentMenu)
--         end)
--         MENU_GROUP_COMMAND:New(self.Group, "LAND (closest airdrome)", self._menu, function()
--             me:FollowerLand(nil, true)
--             me:AddPlayerMenus(parentMenu)
--         end)
--     end
--     return self
-- end

-- --- Removes all interceptor player menus (created with AddPlayerMenus)
-- function DCAF.Interceptor:RemovePlayerMenus()
--     if not self.Group then return self end
--     if self._menu then
--         self._menu:Remove()
--     end
--     return self
-- end