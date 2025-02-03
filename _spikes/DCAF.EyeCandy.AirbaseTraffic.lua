DCAF.EyeCandy.AirbaseTraffic = {
    ClassName = "DCAF.EyeCandy.AirbaseTraffic",
    ----
    ConflictInterval = 20,      -- seconds between checking again, after holding for conflicting traffic
    CountRunways = 0,
    RunawyZones = {
        -- key   = #string - name to be used for runway zone
        -- value = #ZONE_BASE
    },
}

local DCAF_EyeCandy_AirbaseTrafficDB = {
    ABT = {
        -- key   = GROUP name
        -- value = #DCAF.EyeCandy.AirbaseTraffic
    }
}

function DCAF.EyeCandy.AirbaseTraffic:New(source, airbase, activateDelay, conflictInterval)
    Debug("DCAF.EyeCandy.AirbaseTraffic:New :: source: " .. DumpPretty(source) .. " :: activateDelay: " .. DumpPretty(activateDelay))
    local group = getGroup(source)
    if not group then return Error("DCAF.EyeCandy.AirbaseTraffic:New :: cannot resolve GROUP from source: " .. DumpPretty(source)) end
    local validAirbase = DCAF.Location.Resolve(airbase)
    if not validAirbase then return Error("DCAF.EyeCandy.AirbaseTraffic:New :: cannot resovle AIRBASE from: " .. DumpPretty(airbase)) end
    local abt = DCAF.clone(DCAF.EyeCandy.AirbaseTraffic)
    abt.Group = group
    abt.GroupName = group.GroupName
    abt.Airbase = validAirbase.Source
    abt._route = group:CopyRoute()
    abt._originalRoute = abt._route
    abt:_createZoneActiveRWY()

    if isNumber(conflictInterval) then
        abt.ConflictInterval = conflictInterval
    end
    if not isNumber(activateDelay) then
        activateDelay = 0
    end
    DCAF.delay(function()
        if group:IsActive() then return end
        group:Activate()
        Debug("DCAF.EyeCandy.AirbaseTraffic:New :: group was activated: " .. group.GroupName)
    end, activateDelay)
    DCAF_EyeCandy_AirbaseTrafficDB.ABT[abt.GroupName] = abt
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:New :: DCAF_EyeCandy_AirbaseTrafficDB.ABT: " .. DumpPretty(DCAF_EyeCandy_AirbaseTrafficDB.ABT))
    return abt
end

function DCAF_EyeCandy_AirbaseTrafficDB:GetAirbaseTraffic(source)
    local group = getGroup(source)
    if not group then return end
-- Debug("nisse - DCAF_EyeCandy_AirbaseTrafficDB:GetAirbaseTraffic :: group: " .. group.GroupName .. " :: DCAF_EyeCandy_AirbaseTrafficDB.ABT: " .. DumpPretty(DCAF_EyeCandy_AirbaseTrafficDB.ABT))
    return DCAF_EyeCandy_AirbaseTrafficDB.ABT[group.GroupName]
end

function DCAF.EyeCandy.AirbaseTraffic:_isConflictingTraffic(unit)
    local abtUnit = DCAF_EyeCandy_AirbaseTrafficDB:GetAirbaseTraffic(unit)
    if not abtUnit then return true end
    local unitGroupName = unit:GetGroup().GroupName
-- Debug("nisse - isConflictingTraffic :: " .. self.GroupName .. " :: unit group: " .. unitGroupName .. " :: abt._inhibitedConflicts: " .. DumpPrettyDeep(abtUnit._inhibitedConflicts, 2))
-- Debug("nisse - isConflictingTraffic :: self._inhibitedConflicts" .. DumpPretty(self._inhibitedConflicts))
    if self._inhibitedConflicts and self._inhibitedConflicts[unitGroupName] then
        return false
    end
    abtUnit:_inhibitConflictWith(self)
    return true
end

function DCAF.EyeCandy.AirbaseTraffic:_inhibitConflictWith(abt)
    self._inhibitedConflicts = self._inhibitedConflicts or {}
    self._inhibitedConflicts[abt.GroupName] = abt
-- Debug("nisse - _inhibitConflictWith :: abt._inhibitedConflicts: " .. DumpPrettyDeep(self._inhibitedConflicts, 1))
    DCAF.delay(function()
        self._inhibitedConflicts[abt.GroupName] = nil
    end, 60)
end

function DCAF.EyeCandy.AirbaseTraffic:_isConflictInhibited(abt)
    if not self._inhibitedConflicts then return end
    return self._inhibitedConflicts[abt.GroupName]
end

-- function DCAF.EyeCandy.AirbaseTraffic:WithRunwayZone(zone, name)
--     local loc = DCAF.Location.ResolveZone(zone)
--     if not loc or not loc:IsZone() then return Error("DCAF.EyeCandy.AirbaseTraffic:WithRunwayZone :: could not resolve runway zone from: " .. DumpPretty(zone), self) end
--     if not isAssignedString(name) then name = loc.Name end
--     self.CountRunways = self.CountRunways + 1
--     self._defaultRunway = loc.Source
--     self.RunawyZones[name] = self._defaultRunway
--     return self
-- end

function DCAF.EyeCandy.AirbaseTraffic:WithDebug(name, messageDuration)
    self._debug = {
        Name = name or self.GroupName,
        MessageDuration = messageDuration or 20,
        InhibitMessageCrossing = false
    }
    if self._debug then
        local coordinates = self._zoneRWY:GetVerticiesCoordinates()
        coordinates[1]:LineToAll(coordinates[2])
        coordinates[2]:LineToAll(coordinates[3])
        coordinates[3]:LineToAll(coordinates[4])
        coordinates[1]:LineToAll(coordinates[4])
    end
    return self
end

function DCAF.EyeCandy.AirbaseTraffic:IsDebug() return self._debug and DCAF.Debug end

function DCAF.EyeCandy.AirbaseTraffic:DebugMessage(message, duration)
    if not self:IsDebug() then return end
    MessageTo(nil, self._debug.Name .. " : " .. message, duration or self._debug.MessageDuration)
end

function DCAF.EyeCandy.AirbaseTraffic:DebugMessageCrossing(message, duration)
    if not self:IsDebug() or self._debug.InhibitMessageCrossing then return end
    MessageTo(nil, self._debug.Name .. " : " .. message, duration or self._debug.MessageDuration)
end

function DCAF.EyeCandy.AirbaseTraffic:DebugInhibitMessageCrossing(value)
    if not self:IsDebug() then return end
    self._debug.InhibitMessageCrossing = value
end

function DCAF.EyeCandy.AirbaseTraffic:HoldWhen(funcCriteria, minDuration, maxDuration, funcContinue)
    if not isFunction(funcCriteria) then return Error("DCAF.EyeCandy.AirbaseTraffic:HoldWhen :: `funcCriteria` must be function, but was: " .. DumpPretty(funcCriteria), self) end
    local min, max = funcCriteria()
    if min == nil then return self end
    if isBoolean(min) then return self:Hold(minDuration, maxDuration) end
    if isNumber(min) then
        minDuration = min
    end
    if isNumber(max) then
        maxDuration = max
    end
    return self:Hold(minDuration, maxDuration, nil, funcContinue)
end

function DCAF.EyeCandy.AirbaseTraffic:Hold(minDuration, maxDuration, reason, funcResume)
    Debug("DCAF.EyeCandy.AirbaseTraffic:Hold :: " .. self.GroupName .. " :: minDuration: " .. DumpPretty(minDuration) .. " :: maxDuration: " .. DumpPretty(maxDuration))
    self.Group:RouteStop()
    if not isNumber(minDuration) then minDuration = Minutes(3) end
    local duration
    if isNumber(maxDuration) then
        if maxDuration < minDuration then minDuration, maxDuration = swap(minDuration, maxDuration) end
        duration = math.random(minDuration, maxDuration)
    else
        duration = minDuration
    end
    if DCAF.Debug then
        local debugMessage = "DCAF.EyeCandy.AirbaseTraffic:Hold :: " .. self.GroupName .. " :: holds for duration: " .. duration .. " seconds"
        if isAssignedString(reason) then
            debugMessage = debugMessage .. " :: reason: " .. reason
        end
        Debug(debugMessage)
    end
    self:DebugMessage("HOLDS for " .. duration .. "s")
    DCAF.delay(function()
        if isFunction(funcResume) then
            if funcResume(self) == false then
                Debug("DCAF.EyeCandy.AirbaseTraffic:Hold_delay :: " .. self.GroupName .. " :: function returned false (does not resume)")
                return
            end
        end
        if DCAF.Debug then
            local debugMessage = "DCAF.EyeCandy.AirbaseTraffic:Hold :: " .. self.GroupName .." :: resumes route"
            if isAssignedString(reason) then
                debugMessage = debugMessage .. " :: reason for hold=" .. reason
            end
            Debug(debugMessage)
        end
Debug("DCAF.EyeCandy.AirbaseTraffic:Hold_delay :: --RouteResume--")
        self.Group:RouteResume()
    end, duration)
    return self
end

function DCAF.EyeCandy.AirbaseTraffic:CrossTWY(rangeOrZone, groundTraffic, maxAltitude, interval, funcResuming)
    self:DebugMessageCrossing("CROSSING TWY...")
    Debug("DCAF.EyeCandy.AirbaseTraffic:CrossTWY :: rangeOrZone: " .. DumpPretty(rangeOrZone) .. " :: groundTraffic: " .. DumpPretty(groundTraffic) .. " :: maxAltitude: " .. DumpPretty(maxAltitude) .. " :: interval: " .. DumpPretty(interval))
    local coordSelf = self:GetCoordinate()
    if not coordSelf then return false end

    local conflictingTraffic = self:_getConflictingTraffic(coordSelf, rangeOrZone, groundTraffic, maxAltitude)
    if conflictingTraffic then
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:CrossTWY :: CONFLICT: " .. conflictingTraffic.UnitName)
        if not self._debug.IsHoldingForTraffic then
            self._debug.IsHoldingForTraffic = true
            self:DebugMessage("STOPS FOR TRAFFIC!")
        end
        self:Hold(interval or self.ConflictInterval, nil, "conflicting traffic: " .. conflictingTraffic.GroupName, function()
            return self:CrossTWY(rangeOrZone, groundTraffic, maxAltitude, interval, funcResuming)
        end)
        return false
    end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:CrossTWY :: RESUMES")
    -- self.Group:RouteResume()
    self._debug.IsHoldingForTraffic = nil
    if isFunction(funcResuming) then
        pcall(function()
            funcResuming(self)
        end)
    end
    return true
end

function DCAF.EyeCandy.AirbaseTraffic:_getConflictingTraffic(coordSelf, rangeOrZone, groundTraffic, maxAltitude)
    local range
    local zone
    local maxConflictAspect = 94
    if isNumber(range) then
        range = rangeOrZone
    elseif isZone(rangeOrZone) then
        zone = rangeOrZone
        maxConflictAspect = 100 -- when using a zone we increase the angle when checking for 'oncoming' traffic
    else
        range = Feet(500)
    end
    if not isNumber(maxAltitude) or maxAltitude < 0 then
        maxAltitude = 10 -- should include taxiing rotaries
    end

    local setUnits
    if zone then
        setUnits = SET_UNIT:New():FilterZones({zone}):FilterOnce()
    else
        setUnits = coordSelf:ScanUnits(range)
    end
    local conflict
    setUnits:ForEachUnit(function(unit)
        if conflict or unit:GetGroup() == self.Group then return end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_getConflictingTraffic :: unit: " .. unit.UnitName .. "...")
        if not groundTraffic and not unit:IsAir() then return end
        if maxAltitude < 1 then
            if unit:InAir() then return end
        elseif unit:GetAltitude(true) > maxAltitude then
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_getConflictingTraffic :: unit: " .. unit.UnitName .. " :: unit altitude: " .. unit:GetAltitude(true) .. " :: maxAltitude: " .. maxAltitude)
            return
        end
        local speed = unit:GetVelocityMPS()
        if speed < 1 then return end
        local coordUnit = unit:GetCoordinate()
        if not coordUnit then return end
        local bearing = coordUnit:HeadingTo(coordSelf)
        local hdgUnit = unit:GetHeading()
        local hdgSelf = self:GetHeading()
        -- local aspect = GetRelativeDirection(hdgUnit, bearing)
        -- local aspect = hdgSelf - hdgUnit
        local aspect = hdgUnit - bearing
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_getConflictingTraffic (aaa) :: unit: " .. unit.UnitName .. " :: speed: " .. speed .. " :: hdgSelf: " .. hdgSelf .. " :: hdgUnit: " .. hdgUnit .. " :: aspect: " .. aspect)
        if aspect < -180 then aspect = aspect + 360 elseif aspect > 180 then aspect = aspect - 360 end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_getConflictingTraffic (bbb) :: unit: " .. unit.UnitName .. " :: speed: " .. speed .. " :: hdgSelf: " .. hdgSelf .. " :: hdgUnit: " .. hdgUnit .. " :: aspect: " .. aspect)
        if math.abs(aspect) < maxConflictAspect then
            conflict = unit
        end
    end)
    return conflict
end

function DCAF.EyeCandy.AirbaseTraffic:CrossRWY()
    self:DebugMessageCrossing("CROSSING RWY...")
    self:DebugInhibitMessageCrossing(true)
    local result = self:CrossTWY(self._zoneRWY, false, Feet(4000), Minutes(1))
    self:DebugInhibitMessageCrossing(false)
    return result
end

function DCAF.EyeCandy.AirbaseTraffic:GiveWay(offsetWaypoint, groundTraffic, space, range, speedKmh, interval)
    if self._giveWaySchedulerID then return end

-- -- nisse
-- local route = getGroupRoute(self.Group)
-- for _, wp in ipairs(route) do
--     self:_debugAddTempMarker(COORDINATE_FromWaypoint(wp))
-- end

    if not isNumber(space) then space = 20 end
    if not isNumber(range) then range = 160 end
    if not isNumber(speedKmh) then speedKmh = 20 end
    if not isNumber(interval) then interval = 1 end

    local wpStart, wpStartIndex = GetClosestWaypoint(self.Group)
    if not wpStart._giveWayEnd then
        if not isNumber(offsetWaypoint) then
            offsetWaypoint = #self._route - wpStartIndex
        end
        wpStart._giveWayEnd = wpStartIndex + offsetWaypoint
        local wpEnd = self._route[wpStart._giveWayEnd]
-- Debug("DCAF.EyeCandy.AirbaseTraffic:GiveWay :: wpStartIndex: " .. wpStartIndex .. " :: wp._giveWayEnd: " .. wpStart._giveWayEnd .. " :: wpEnd: " .. DumpPretty(wpEnd))
        WaypointCallback(wpEnd, function()
-- Debug("DCAF.EyeCandy.AirbaseTraffic:GiveWay :: " .. self.GroupName)
            self:DebugMessage("Give Way END")
            self:GiveWayEnd()
        end)
    end

    -- self._route = route
    self._nextWaypointIndex = wpStartIndex
    self._nextWaypoint = self._route[wpStartIndex + 1]
-- nisse
if not self._nextWaypoint then
MessageTo(nil, "NO MORE WAYPOINTS - WTF?!", 60)
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay :: self._nextWaypointIndex: " .. self._nextWaypointIndex .. " :: #._route: " .. #self._route .. " :: ._route: " .. DumpPrettyDeep(self._route, 1))
end
    self._nextWaypointDistance = self:GetCoordinate():Get2DDistance(COORDINATE_FromWaypoint(self._nextWaypoint))

    local function refreshNextWaypoint()
local nisse
if self._debug then
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_refreshNextWaypoint :: ._nextWaypoint: " .. DumpPretty(self._nextWaypoint))
    if self._nextWaypoint.name then
        nisse = "nxt:" .. self._nextWaypoint.name
    else
        nisse = nil
    end
end
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_refreshNextWaypoint :: nextWaypoint: " .. Dump(nisse) .. " :: ._nextWaypointIndex: " .. Dump(self._nextWaypointIndex) .. " :: ._nextWaypointDistance: " .. Dump(self._nextWaypointDistance))
    if not self._nextWaypoint then return end
    local distance = self:GetCoordinate():Get2DDistance(COORDINATE_FromWaypoint(self._nextWaypoint) )
    if distance <= self._nextWaypointDistance then
        self._nextWaypointDistance = distance
        return self._nextWaypoint
    end
    -- we have passed the next waypoint, advance to next...
    self._nextWaypointIndex = self._nextWaypointIndex + 1
    self._nextWaypoint = self._route[self._nextWaypointIndex]
if self._debug then
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_refreshNextWaypoint :: ._nextWaypoint: " .. DumpPretty(self._nextWaypoint))
    if self._nextWaypoint.name then
        nisse = "nxt:" .. self._nextWaypoint.name
    else
        nisse = nil
    end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_refreshNextWaypoint :: nextWaypoint: " .. Dump(nisse) .. " :: ._nextWaypointIndex: " .. Dump(self._nextWaypointIndex) .. " :: ._nextWaypointDistance: " .. Dump(self._nextWaypointDistance))
end
self:_debugAddTempMarker(COORDINATE_FromWaypoint(self._nextWaypoint), nisse or "nxt", 20)
        if not self._nextWaypoint then
            -- no next waypoint...
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_refreshNextWaypoint :: NO NEXT WAYPOINT")
            return
        end
        self._nextWaypointDistance = self:GetCoordinate():Get2DDistance(COORDINATE_FromWaypoint(self._nextWaypoint) )
        return self._nextWaypoint
    end

Debug("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------")
Debug("DCAF.EyeCandy.AirbaseTraffic:GiveWay :: self: " .. DumpPretty(self))

    local speedMps = math.max(UTILS.KmphToMps(speedKmh), 1) -- ensure at least 1m/s of speed when testing
    local safetyRadius = 30 -- meters

    local function isConflicting(unit, speedUnit, coordSelf, hdgSelf)
        if not groundTraffic and (not unit:IsAir() or unit:InAir()) then return end
        local coordUnit = unit:GetCoordinate()
        if not coordUnit then return end
        -- check whether units will come into conflict inside the specified range at current speeds/headings...
        local hdgUnit = unit:GetHeading()
        local distance = speedMps
        local minDistance = 9999999
        while distance < range do
            coordSelf = coordSelf:Translate(speedMps, hdgSelf)
            coordUnit = coordUnit:Translate(speedUnit, hdgUnit)
            local checkDistance = coordSelf:Get2DDistance(coordUnit)
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_isConflicting :: " .. unit.UnitName .. " :: checkDistance: " .. checkDistance .. " :: speedMps: " .. speedMps .. " :: range: " .. range)
            if checkDistance < safetyRadius and self:_isConflictingTraffic(unit) then
                -- local bearing = coordUnit:HeadingTo(coordSelf)
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_isConflicting :: " .. unit.UnitName .. " :: CONFLICT")
                return coordUnit
            end
            distance = distance + speedMps
            if checkDistance < minDistance then
                minDistance = checkDistance
            elseif checkDistance > minDistance then
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_isConflicting :: " .. unit.UnitName .. " :: checkDistance is increasing :: BREAKS")
                return -- distance between projected points are increasing and till keep increasing; no point continuing
            end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay_isConflicting :: " .. unit.UnitName .. " :: distance: " .. distance .. " :: range: " .. range .. " :: distance < range: " .. Dump(distance < range))
        end
    end

    local function monitorTraffic()
        local coordSelf = self:GetCoordinate()
        if not coordSelf or not refreshNextWaypoint() then
            self:GiveWayEnd()
            return
        end
        local conflict
        local setUnits = coordSelf:ScanUnits(range)
        setUnits:ForEachUnit(function(unit)
-- Debug("DCAF.EyeCandy.AirbaseTraffic:GiveWay (aaa) :: " .. unit.UnitName .. "...")
            if not unit:IsAlive() or unit:GetGroup() == self.Group then return end
            if conflict and conflict.Action == "Give Way" then return end
            local speedUnit = unit:GetVelocityMPS()
            local hdgSelf = self:GetHeading()
            local coordUnit = isConflicting(unit, speedUnit, coordSelf, hdgSelf)
            if coordUnit then
                local hdgUnit = unit:GetHeading()
                local bearing = coordUnit:HeadingTo(coordSelf)
                local aspect = hdgSelf - hdgUnit
-- Debug("DCAF.EyeCandy.AirbaseTraffic:GiveWay (bbb) :: " .. unit.UnitName .. " :: hdgSelf: " .. hdgSelf .. " :: hdgUnit: " .. hdgUnit .. " :: bearing: " .. bearing .. " :: aspect: " .. aspect)
                if aspect < -180 then aspect = aspect + 360 elseif aspect > 180 then aspect = aspect - 360 end
-- Debug("DCAF.EyeCandy.AirbaseTraffic:GiveWay (ccc) :: " .. unit.UnitName .. " :: hdgSelf: " .. hdgSelf .. " :: hdgUnit: " .. hdgUnit .. " :: bearing: " .. bearing .. " :: aspect: " .. aspect)
                if aspect < 70 and self.Group:GetVelocityMPS() > speedUnit then
                    conflict = { Unit = unit, Coordinate = coordUnit, Aspect = aspect, Speed = speedUnit, Action = "Slow Down" }
                elseif aspect < 135 then
                    conflict = { Unit = unit, Coordinate = coordUnit, Aspect = aspect, Speed = speedUnit, Action = "Hold" }
                else
                    conflict = { Unit = unit, Coordinate = coordUnit, Aspect = aspect, Speed = speedUnit, Action = "Give Way" }
                end
            end
        end)
        if not conflict then return end
        -- prioritize oncoming traffic...
        if conflict.Action == "Give Way" then
            -- match unit's speed so as to not catch up; otherwise give way...
            -- local wp, wpIndex, _, route = GetClosestWaypoint(self.Group)
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay :: (aaa) ._nextWaypointIndex: " .. self._nextWaypointIndex)
            self:_giveWay(self._nextWaypointIndex, conflict, speedKmh, groundTraffic, space, range, interval) -- add +1 to waypoint to match number in ME/F10 map
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:GiveWay :: (bbb) ._nextWaypointIndex: " .. self._nextWaypointIndex)
        elseif conflict.Action == "Hold" then
            self:GiveWayEnd()
            self:Hold(20, nil, "crossing traffic", function()
self:DebugMessage("Resumes Give Way...")
                self._giveWaySchedulerID = DCAF.startScheduler(monitorTraffic, interval)
            end)
        else
            self.Group:SetSpeed(conflict.Speed)
            if not self._debug.IsSlowingDown then
                self:DebugMessage("SLOWS DOWN...")
                self.Group:SetSpeed(conflict.Speed)
                self._debug.IsSlowingDown = true
            end
        end
    end

    self._giveWaySchedulerID = DCAF.startScheduler(monitorTraffic, interval)
    return self
end

function DCAF.EyeCandy.AirbaseTraffic:GiveWayEnd()
    self._debug.IsSlowingDown = nil
    if not self._giveWaySchedulerID then return end
    pcall(function()
        DCAF.stopScheduler(self._giveWaySchedulerID)
    end)
    self._giveWaySchedulerID = nil
    return self
end

function CopySubRoute(source, startWp, endWp)
    local group = getGroup(source)
    if not group then return Error("CopyTrimmedRoute :: cannot resolve `source`: " .. DumpPretty(source)) end
    local oldRoute = getGroupRoute(group)
    if not isNumber(startWp) or startWp < 1 then startWp = 1 end
    if not isNumber(endWp) or endWp < 1 then endWp = #oldRoute end
    if startWp == 1 and endWp == #oldRoute then return oldRoute end
    local subRoute = {}
    for index, wp in ipairs(oldRoute) do
        if index >= startWp and index <= endWp then
            subRoute[#subRoute+1] = wp
        end
    end
    return subRoute, oldRoute
end

function DCAF.EyeCandy.AirbaseTraffic:_createZoneActiveRWY()
    local runway = self:GetActiveRunway()
    if not runway then return Error("DCAF.EyeCandy.AirbaseTraffic:_createZoneActiveRWY :: no active runway at this time", self) end
    Debug("DCAF.EyeCandy.AirbaseTraffic:_createZoneActiveRWY :: active runway: " .. runway.name)
    local hdgPerp1 = (runway.heading + 90) % 360
    local hdgPerp2 = (runway.heading - 90) % 360
    local hdgReci = (runway.heading + 180) % 360
    
    -- create zone that covers first half of active RWY, with twice RWY width
    local points = {
        runway.position:Translate(NauticalMiles(7), hdgReci):Translate(runway.width*6, hdgPerp1):GetVec2(),
        runway.endpoint:Translate(runway.width, hdgPerp1):GetVec2(),
        runway.endpoint:Translate(runway.width, hdgPerp2):GetVec2(),
        runway.position:Translate(NauticalMiles(7), hdgReci):Translate(runway.width*6, hdgPerp2):GetVec2()
    }
    self._zoneRWY = ZONE_POLYGON:NewFromPointsArray(self.ClassName.."_RWY_"..runway.name, points)
end

function DCAF.EyeCandy.AirbaseTraffic:_getRoute(startWp, insertWaypoints)
    -- self._routeWpOffset = self._routeWpOffset or 0
    -- local wpStart = startWp - self._routeWpOffset
    -- local trimmedRoute, originalRoute = CopySubRoute(self.Group, wpStart)
    local trimmedRoute, originalRoute = CopySubRoute(self.Group, startWp)
    -- if not self._originalRoute then self._originalRoute = originalRoute end OBSOLETE
    if insertWaypoints then
        for _, wp in ipairs(trimmedRoute) do
            insertWaypoints[#insertWaypoints+1] = wp
        end
        trimmedRoute = insertWaypoints
    end
    local trimmedCount = #originalRoute - #trimmedRoute
    -- self._routeWpOffset = self._routeWpOffset + trimmedCount
    return trimmedRoute
end

function DCAF.EyeCandy.AirbaseTraffic:RestartRoute(startWaypoint, delay)
    if not self._originalRoute then return self end
    if not isNumber(startWaypoint) then startWaypoint = 1 end
    if not isNumber(delay) then delay = 0 end
    Debug("DCAF.EyeCandy.AirbaseTraffic:RestartRoute :: startWaypoint: " .. startWaypoint .. " :: delay: " .. delay)
    DCAF.delay(function()
        local route
        self:DebugMessage("RESTARTS ROUTE from #" .. startWaypoint)
        if isNumber(startWaypoint) and startWaypoint > 1 then
            route = listCopy(self._originalRoute, {}, startWaypoint)
        else
            route = self._originalRoute
        end
        startWaypoint = startWaypoint+1
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:RestartRoute :: #route: " .. #route)
        -- self._routeWpOffset = 0
        self:_setRoute(route)
self:_debugDrawRoute()
    end, delay)
    self._nextWaypointIndex = nil
    self._nextWaypoint = nil
    self._nextWaypointDistance = nil
    return self
end

function DCAF.EyeCandy.AirbaseTraffic:_giveWay(waypointEnd, conflict, speedKmh, groundTraffic, space, range, interval) -- positive relDir == conflict is oncoming left-to-right; negative is opposite
    speedKmh = speedKmh or self.Group:GetVelocityKMH()
    if self._isGivingWay then return end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_giveWay :: speedKmh: " .. DumpPretty(speedKmh) .. " :: waypointEnd: " .. DumpPretty(waypointEnd))
    self._isGivingWay = true
    self:DebugMessage("GIVES WAY...")
    self:GiveWayEnd()
    local hdg = 90 -- turn right, by default
    if conflict.Aspect < 0 then
        -- turn right instead
        hdg = -90
    end
    local hdgSelf = self:GetHeading()
    local coord1 = self.Group:GetCoordinate():Translate(10, hdgSelf)
    local coord2 = self:GetCoordinate():Translate(50, hdgSelf):Translate(space, (hdgSelf + hdg) % 360)
    local coord3 = self:GetCoordinate():Translate(70, hdgSelf)

    if self._debug then
        self:_debugAddTempMarker(coord1, "give way 1")
        self:_debugAddTempMarker(coord2, "give way 2")
        self:_debugAddTempMarker(coord3, "give way 3")
    end

    local wp2 = coord2:WaypointGround(speedKmh)
    if self._debug then
        -- local wpEnd = waypointEnd - (self._routeWpOffset or 0) OBSOLETE
        local route = getGroupRoute(self.Group)
        local coord = COORDINATE_FromWaypoint(route[waypointEnd])
        self:_debugAddTempMarker(coord, "give way wp#" .. waypointEnd .. "(=" .. waypointEnd .. ")")
    end
    WaypointCallback(wp2, function()
        self:DebugInhibitMessageCrossing(true)
        self:CrossTWY(range, groundTraffic, nil, interval, function()
            self:DebugInhibitMessageCrossing(false)
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_giveWay :: resumes...")
            self._isGivingWay = nil
            self:GiveWay(3, groundTraffic, space, range, speedKmh, interval)
        end)
        self:DebugInhibitMessageCrossing(false)
    end)

self:_debugAddTempMarker(COORDINATE_FromWaypoint(self._route[waypointEnd]))

    local route = self:_getRoute(waypointEnd, {
        coord1:WaypointGround(speedKmh),
        wp2,
        coord3:WaypointGround(speedKmh),
    })
    -- if 'resume' WP (3rd) is further away than the first WP in the rest of the route (4th), then remove it...
    local coord4 = COORDINATE_FromWaypoint(route[4])
    if coord1:Get2DDistance(coord3) > coord1:Get2DDistance(coord4) then
        table.remove(route, 3)
        -- if self._routeWpOffset then
        --     self._routeWpOffset = self._routeWpOffset - 1 OBSOLEETE
        -- end
    end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_giveWay :: #route: " .. #route)
    self:_setRoute(route)
    self._nextWaypointIndex = 2
    self._nextWaypoint = self._route[self._nextWaypointIndex]
    self._nextWaypointDistance = self:GetCoordinate():Get2DDistance(COORDINATE_FromWaypoint(self._nextWaypoint))

Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_giveWay :: ._nextWaypointIndex: " .. Dump(self._nextWaypointIndex) .. " :: ._nextWaypointDistance: " .. Dump(self._nextWaypointDistance) .. " :: ._nextWaypoint: " .. DumpPrettyDeep(self._nextWaypoint, 1))
self:_debugDrawRoute()
self:_debugAddTempCircle(COORDINATE_FromWaypoint(self._nextWaypoint), 100, Color.White)
    return self
end

local _debugTempMarkers = {}

function DCAF.EyeCandy.AirbaseTraffic:_setRoute(route)
    setGroupRoute(self.Group, route)
    self._route = route
end

function DCAF.EyeCandy.AirbaseTraffic:_debugDrawRoute()
    local route = getGroupRoute(self.Group)
    for i = 2, #route, 1 do
        self:_debugAddTempLine(COORDINATE_FromWaypoint(route[i-1]), COORDINATE_FromWaypoint(route[i]), nil, .5)
    end
end

function DCAF.EyeCandy.AirbaseTraffic:_debugAddTempMarker(coord, text, time)
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_debugAddTempMarker :: coord: " .. DumpPretty(coord))
    if not isNumber(time) then time = Minutes(1) end
    local markID = coord:MarkToAll(text or "debug", false, text)
    _debugTempMarkers[markID] = true
    DCAF.delay(function()
        self:_debugRemoveTempMarker(markID)
    end, time)
    return markID
end

function DCAF.EyeCandy.AirbaseTraffic:_debugRemoveTempMarker(markID)
    if not _debugTempMarkers[markID] then return end
    _debugTempMarkers[markID] = nil
    pcall(function()
        COORDINATE:RemoveMark(markID)
    end)
end

function DCAF.EyeCandy.AirbaseTraffic:_debugAddTempLine(coordStart, coordEnd, color, alpha, time)
-- Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_debugAddTempLine :: coord: " .. DumpPretty(coord))
    if not isNumber(time) then time = Minutes(1) end
    local markID = coordStart:LineToAll(coordEnd, nil, color, alpha)
    _debugTempMarkers[markID] = true
    DCAF.delay(function()
        self:_debugRemoveTempMarker(markID)
    end, time)
    return markID
end

function DCAF.EyeCandy.AirbaseTraffic:_debugAddTempCircle(coord, radius, color, time)
    if not isNumber(time) then time = Minutes(1) end
Debug("nisse - DCAF.EyeCandy.AirbaseTraffic:_debugAddTempCircle :: coord: " .. DumpPretty(coord))
    local markID = coord:CircleToAll(radius, nil, color)
    _debugTempMarkers[markID] = true
    DCAF.delay(function()
        self:_debugRemoveTempMarker(markID)
    end, time)
    return markID
end


function DCAF.EyeCandy.AirbaseTraffic:GetCoordinate() return self.Group:GetCoordinate() end
function DCAF.EyeCandy.AirbaseTraffic:GetHeading() return self.Group:GetHeading() end
function DCAF.EyeCandy.AirbaseTraffic:GetActiveRunway() return self.Airbase:GetActiveRunway() end

local nisse_groups = {}

function nisse_SpawnDelay(delay, interval, ...)
Debug("nisse - nisse_SpawnDelay...")
    local delay = delay or 0
    local interval = interval or 0
    for _, source in ipairs(arg) do
        DCAF.delay(function()
Debug("nisse - nisse_SpawnDelay :: activates group: " .. source)
            local group = getSpawn(source):Spawn()
            nisse_groups[source] = group
        end, delay)
        delay = delay + interval
    end
end

function nisse_Spawn(...)
    Debug("nisse - nisse_SpawnDelay...")
    local groups = {}
    for _, source in ipairs(arg) do
Debug("nisse - nisse_SpawnDelay :: activates group: " .. source)
        local group = getSpawn(source):Spawn()
        nisse_groups[source] = group
        groups[#groups+1] = group
    end
    return unpack(groups)
end

function nisse_SpawnAtParking(source, parkingSpots)
    local incirlik = AIRBASE:FindByName(AIRBASE.Syria.Incirlik)
Debug("nisse - nisse_SpawnAtParking :: incirlik: " .. DumpPretty(incirlik) .. " :: spots: " .. DumpPretty(parkingSpots))
    getSpawn(source):SpawnAtParkingSpot(incirlik, parkingSpots)
end

function nisse_Destroy(source, delay)
    delay = delay or 0
    DCAF.delay(function()
        local group = nisse_groups[source]
        if group then
             group:Destroy()
             nisse_groups[source] = nil
        end
    end, delay)
end