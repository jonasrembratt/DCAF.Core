local DCAF_ConvoyDefaults = {
    IntervalMeters = 30
}

DCAF.Convoy = {
    ClassName = "DCAF.Convoy",
    ----    
    Name = nil,
    Groups = { --[[ #GROUP ]] },
    IntervalMeters = DCAF_ConvoyDefaults.IntervalMeters,
    CustomIntervalMeters = {
        -- key   = name of GROUP
        -- value = number (meters)
    },
    Speed = 1,          -- specified current relative speed (0-1) from set speed
}



--- Creates a convoy from multiple groups, such that each group follows the previous one and tries avoid causing traffic jams
---@param groups any - A list of groups, or a name pattern (string) to automatically include all groups matching that pattern
---@param intervalMeters number - (optional; default = 30) A distance to be used as an interval between each group. Minimum value is 15m (will be enforced)
function DCAF.Convoy:New(groups, name, intervalMeters)
    if (isAssignedString) then
        groups = SET_GROUP:New():FilterPrefixes(groups):FilterOnce()
    end
    if isClass(groups, SET_GROUP) then
        local groupList = {}
        groups:ForEachGroup(function(g)
            local route = getGroupRoute(g)
            if #route > 1 then
                g._routeSize = #route
            end
            groupList[#groupList+1] = g
        end)
        groups = groupList
        table.sort(groups, function(a,b)
            if a and a._routeSize then
                if not b then return true end
                if a._routeSize > (b._routeSize or 1) then return true end
            end
            if b and b._routeSize then
                if not a then return false end
                if b._routeSize > (a._routeSize or 1) then return false end
            end
            return a.GroupName < b.GroupName
        end)
    end
    if not isListOfClass(groups, GROUP) then
        return Error("DCAF.Convoy:New :: could not resolve groups from: " .. DumpPretty(groups))
    end

-- NISSE
-- Debug("nisse - DCAF.Convoy:New :: groups:")
-- for i, group in ipairs(groups) do
-- Debug("nisse - DCAF.Convoy:New :: groups[" .. i .. "]: " .. groups[i].GroupName)
-- end

    if not isNumber(intervalMeters) then
        intervalMeters = DCAF_ConvoyDefaults.IntervalMeters
    else
        intervalMeters = math.max(15, intervalMeters)
    end
    if not isAssignedString(name) then name = groups[1].GroupName end
    local convoy = DCAF.clone(DCAF.Convoy)
    convoy.Name = name
    convoy.GroupName = name
    convoy.Groups = groups

    -- TODO test whether we'd need shorter monitoring intervals with shorter 
    convoy:__monitor()
    convoy.SchedulerID = DCAF.startScheduler(function()
        convoy:__monitor()
    end, 5)

    return convoy
end

--- Sets interval between a specified group of the convoy, to the group in front of it
---@param group number -- Specifies the affected group. Can be internal index, name of a group, of a #GROUP object
---@param intervalMeters number -- Specifies the requested interval, in meters. Must be at least 10 meters
function DCAF.Convoy:InitInterval(group, intervalMeters)
    local index, validGroup = self:GetGroupIndex(group)
    if not index or not validGroup then return Error("DCAF.Convoy:InitInterval :: group is not part of convoy: " .. DumpPretty(group), self) end
    self.CustomIntervalMeters[validGroup.GroupName] = intervalMeters
end

--- returns the internal index of a specified group (e.g. 1 is the avantgarde group)
---@param group any -- A #GROUP object or name of a group
---@return number A positive number if group is part of the convoy; otherwise nil
---@return any The resolved GROUP object
function DCAF.Convoy:GetGroupIndex(group)
    local validGroup = getGroup(group)
    if not validGroup then return Error("DCAF.Convoy:GetGroupIndex :: cannot resolve group: " .. DumpPretty(group)) end
    group = validGroup
    for i = 1, #self.Groups do
        local testGroup = self.Groups[i]
        if testGroup.GroupName == group.GroupName then return i, validGroup end
    end
end

function DCAF.Convoy:__monitor()
    local leadCoord, leadUnit = self:__getLastLivingUnitCoordinates(self.Groups[1])
    -- handle lead group is dead...
    while not leadCoord and #self.Groups > 1 do
        Debug("DCAF.Convoy :: lead group is dead; resolves new lead group")
        table.remove(self.Groups, 1)
        leadCoord, leadUnit = self:__getLastLivingUnitCoordinates(self.Groups[1])
    end
-- Debug("nisse - DCAF.Convoy:New :: leadUnit: " .. leadUnit.UnitName)
    if #self.Groups < 2 then
        Debug("DCAF.Convoy :: less than two groups remain; stops monitoring convoy")
        DCAF.stopScheduler(self.SchedulerID)
        self.LeadGroup = nil
        return
    end
    local leadGroup = leadUnit:GetGroup()
    self.LeadGroup = leadGroup
    leadGroup._dcaf_convoy = leadGroup._dcaf_convoy or { _speed = 1 }
    for i = 2, #self.Groups, 1 do
        local nextCoord, nextUnit = self:__getFirstLivingUnitCoordinates(self.Groups[i])
        while not nextCoord and i < #self.Groups do
            i = i + 1
            nextCoord, nextUnit = self:__getFirstLivingUnitCoordinates(self.Groups[i])
        end
        local nextGroup = nextUnit:GetGroup()
        nextGroup._dcaf_convoy = nextGroup._dcaf_convoy or { _speed = 1 }
        self:__adjustForInterval(leadCoord, leadUnit, nextCoord, nextUnit)
        leadCoord, leadUnit = self:__getLastLivingUnitCoordinates(nextUnit:GetGroup())
    end
end

function DCAF.Convoy:__cloneRoute(leadGroup, nextGroup)
    local routeLead = getGroupRoute(leadGroup)
    local route = getGroupRoute(nextGroup)
    local copyRoute = { route[1] }
    for i = 2, #routeLead do
        copyRoute[i] = routeLead[i]
    end
-- Debug("nisse - DCAF.Convoy:_cloneRoute :: nextGroup: " .. nextGroup.GroupName .. " :: route: " .. DumpPrettyDeep(copyRoute, 2))
    setGroupRoute(nextGroup, copyRoute)
    if leadGroup == self.LeadGroup then
        self:__stopAtFinalWaypoint(routeLead)
    end
end

function DCAF.Convoy:__getLastLivingUnitCoordinates(group)
    local units = group:GetUnits()
    for i = #units, 1, -1 do
        local unit = units[i]
        local coord = unit:GetCoordinate()
        if coord then
            return coord, unit
        end
    end
end

function DCAF.Convoy:__getFirstLivingUnitCoordinates(group)
    local units = group:GetUnits()
    for i = 1, #units do
        local unit = units[i]
        local coord = unit:GetCoordinate()
        if coord then
            return coord, unit
        end
    end
end

function DCAF.Convoy:__getInterval(nextGroup)
    local interval = self.CustomIntervalMeters[nextGroup.GroupName]
    return interval or self.IntervalMeters
end

function DCAF.Convoy:__adjustForInterval(leadCoord, leadUnit, nextCoord, nextUnit)

    local function adjustSpeed(relDistance)
        if relDistance < .1 then
            nextUnit:SetSpeed(0, false)
            return
        end
        local leadSpeed = leadUnit:GetVelocityMPS() * relDistance
        local nextSpeed = leadSpeed * relDistance
-- Debug("nisse - DCAF.Convoy:_adjustForInterval_adjustSpeed :: leadSpeed: " .. leadSpeed .. " :: nextSpeed: " .. nextSpeed)
        nextUnit:SetSpeed(leadSpeed, false)
    end

    local nextGroup = nextUnit:GetGroup()
    if not nextGroup._dcaf_convoy._is_cloned_route then
        local leadGroup = leadUnit:GetGroup()
        self:__cloneRoute(leadGroup, nextGroup)
        nextGroup._dcaf_convoy._is_cloned_route = true
        HandleSetRouteEvent(leadGroup, function() nextGroup._dcaf_convoy._is_cloned_route = nil end)
    end
    local distance = leadCoord:Get2DDistance(nextCoord)
    local intervalMeters = self:__getInterval(nextGroup)
    local relDistance = distance / intervalMeters
-- Debug("nisse - DCAF.Convoy:_adjustForInterval_adjustSpeed :: leadUnit: " .. leadUnit.UnitName .. " :: nextUnit: " .. nextUnit.UnitName .. " :: relDistance: " .. relDistance .. " :: nextGroup._dcaf_convoy: " .. DumpPretty(nextGroup._dcaf_convoy))
    if relDistance < 1 or distance > 1.05 then
        adjustSpeed(relDistance)
    end
end

--- Halts the convoy until `Continue` is invoked
function DCAF.Convoy:RouteStop()
    if self.LeadGroup then
        Debug("DCAF.Convoy:RouteStop :: stops lead group: " .. self.LeadGroup.GroupName)
        self.LeadGroup:RouteStop()
        return self
    end
    for _, group in ipairs(self.Groups) do
        if not group._dcaf_convoy._is_halted then
            group._dcaf_convoy._is_halted = true
            group:RouteStop()
        end
    end
    return self
end

--- Resumes convoy after having been halted (by `Halt`)
function DCAF.Convoy:RouteResume()
    if self.LeadGroup then
        Debug("DCAF.Convoy:RouteResume :: resumes lead group: " .. self.LeadGroup.GroupName)
        self.LeadGroup:RouteResume()
        return self
    end
    for _, group in ipairs(self.Groups) do
        if group._dcaf_convoy._is_halted then
            group._dcaf_convoy._is_halted = nil
            group:RouteResume()
        end
    end
    return self
end

--- Re-routes the convoy using a specified list of waypoints
function DCAF.Convoy:Route(waypoints)
    if self.LeadGroup then
        SetRoute(self.LeadGroup, waypoints)
        return self
    end
    for _, group in ipairs(self.Groups) do
        SetRoute(group, waypoints)
    end
    return self
end

--- Make the convoy drive towards a specific point.
---@param toCoordinate any A Coordinate to drive to.
---@param speed number (optional) Speed in km/h. The default speed is current speed, or 20 km/h if current speed is <1 km/h.
---@param formation string (optional) The route point Formation, which is a text string that specifies exactly the Text in the Type of the route point, like "Vee", "Echelon Right".
---@param delaySeconds number (optional) Wait for the specified seconds before executing the Route.
---@param waypointFunction function (Optional) Function called when passing a waypoint. First parameters of the function are the @{#CONTROLLABLE} object, the number of the waypoint and the total number of waypoints.
---@param waypointFunctionArguments table (Optional) List of parameters passed to the *WaypointFunction*
---@return unknown
function DCAF.Convoy:RouteGroundTo( toCoordinate, speed, formation, delaySeconds, waypointFunction, waypointFunctionArguments )
    if not self.LeadGroup then
        for _, group in ipairs(self.Groups) do
            group:RouteGroundTo( toCoordinate, speed, formation, delaySeconds, waypointFunction, waypointFunctionArguments )
        end
        return Error("DCAF.Convoy:RouteGroundTo :: no lead group available.Remaining groups are routed separately", self) 
    end

    local fromCoordinate = self:GetCoordinate()
    local fromWP = fromCoordinate:WaypointGround( speed, formation )
    local toWP = toCoordinate:WaypointGround( speed, formation )
    local route = { fromWP, toWP }

    -- Add passing waypoint function.
    if isFunction(waypointFunction) then
      local N = #route
      for n, waypoint in pairs( route ) do
        waypoint.task = {}
        waypoint.task.id = "ComboTask"
        waypoint.task.params = {}
        waypoint.task.params.tasks = { self:TaskFunction( "CONTROLLABLE.___PassingWaypoint", n, N, waypointFunction, unpack( waypointFunctionArguments or {} ) ) }
      end
    end

    if isNumber(delaySeconds) then
        DCAF.delay(function() SetRoute(self.LeadGroup, route) end, delaySeconds)
    else
        SetRoute(self.LeadGroup, route)
    end
    return self
end

function DCAF.Convoy:RouteGroundOnRoad( toCoordinate, speed, delaySeconds, offRoadFormation, waypointFunction, waypointFunctionArguments )
    if not self.LeadGroup then
        for _, group in ipairs(self.Groups) do
            group:RouteGroundOnRoad( toCoordinate, speed, delaySeconds, offRoadFormation, waypointFunction, waypointFunctionArguments )
        end
        return Error("DCAF.Convoy:RouteGroundOnRoad :: no lead group available.Remaining groups are routed separately", self) 
    end
    delaySeconds = delaySeconds or 1
    local route = self:TaskGroundOnRoad( toCoordinate, speed, offRoadFormation, nil, nil, waypointFunction, waypointFunctionArguments )
    self:__stopAtFinalWaypoint(route)
    SetRoute(self.LeadGroup, route)
    return self
end

function DCAF.Convoy:__stopAtFinalWaypoint(route)
    local finalWP = route[#route]
    WaypointCallback(finalWP, function()
MessageTo(nil, "NISSE - CONVOY STOPS (bbb): " .. self.Name, 60)
       for i = 2, #self.Groups do
            local group = self.Groups[i]
            group:SetSpeed(1)
        end
    end)
end

function DCAF.Convoy:OptionFormationInterval(meters)
    for _, group in ipairs(self.Groups) do
        group:OptionFormationInterval(meters)
    end
    return self
end

function DCAF.Convoy:OptionROEHoldFire()
    for _, group in ipairs(self.Groups) do
        group:OptionROEHoldFire()
    end
    return self
end

function DCAF.Convoy:OptionROEReturnFire()
    for _, group in ipairs(self.Groups) do
        group:OptionROEReturnFire()
    end
    return self
end

function DCAF.Convoy:OptionROEOpenFire()
    for _, group in ipairs(self.Groups) do
        group:OptionROEOpenFire()
    end
    return self
end

function DCAF.Convoy:OptionAlarmStateAuto()
    for _, group in ipairs(self.Groups) do
        group:OptionAlarmStateAuto()
    end
    return self
end

function DCAF.Convoy:OptionAlarmStateGreen()
    for _, group in ipairs(self.Groups) do
        group:OptionAlarmStateGreen()
    end
    return self
end

function DCAF.Convoy:OptionAlarmStateRed()
    for _, group in ipairs(self.Groups) do
        group:OptionAlarmStateRed()
    end
    return self
end

function DCAF.Convoy:OptionEngageRange(engageRange)
    for _, group in ipairs(self.Groups) do
        group:OptionEngageRange(engageRange)
    end
    return self
end

function DCAF.Convoy:OptionDisperseOnAttack(seconds)
    for _, group in ipairs(self.Groups) do
        group:OptionDisperseOnAttack(seconds)
    end
    return self
end

function DCAF.Convoy:SetSpeed(speed, keep)
    if self.LeadGroup then
        self.LeadGroup:SetSpeed(speed, keep)
        return self
    end
    for _, group in ipairs(self.Groups) do
        group:SetSpeed(speed, keep)
    end
    return self
end

function DCAF.Convoy:GetCoordinate()
    for i = 1, #self.Groups do
        local group = self.Groups[i]
        local coord = group:GetCoordinate()
        if coord then return coord end
    end
end

function DCAF.Convoy:SetAIOff()
    for _, group in ipairs(self.Groups) do
        group:SetAIOff()
    end
end

function DCAF.Convoy:SetAIOn()
    for _, group in ipairs(self.Groups) do
        group:SetAIOn()
    end
end

function DCAF.Convoy:CommandSetInvisible(value)
    for _, group in ipairs(self.Groups) do
        group:CommandSetInvisible(value)
    end
end

function DCAF.Convoy:GetUnits()
    local unitsList = {}
    for _, group in ipairs(self.Groups) do
        local units = group:GetUnits()
        for _, unit in ipairs(units) do
            unitsList[#unitsList+1] = unit
        end
    end
    return unitsList
end

--- Returns a specified unit from the convoy (internal index or unit name)
---@param indexOrName any -- when number the unit with that internal index is returned. When string the unit with that name is returned
---@return unknown
function DCAF.Convoy:GetUnit(indexOrName)
    local index
    local name
    if isNumber(indexOrName) then index = indexOrName elseif isAssignedString(indexOrName) then name = indexOrName end
    if not index and not name then return nil end
    for _, group in ipairs(self.Groups) do
        local units = group:GetUnits()
        if name then
            for _, unit in ipairs(units) do
                if unit.UnitName == indexOrName then return unit end
            end
        elseif index then
            if index <= #units then return units[index] end
            index = index - #units
        end
    end
    return nil
end

function DCAF.Convoy:TaskGroundOnRoad( toCoordinate, speed, offRoadFormation, shortcut, fromCoordinate, waypointFunction, waypointFunctionArguments )
    if not self.LeadGroup then return end

    -- Defaults.
    if not isNumber(speed) then
        speed = self.LeadGroup:GetVelocityKMH()
        if speed < 1 then speed = 20 end
    end
    offRoadFormation = offRoadFormation or "Off Road"

    -- Initial (current) coordinate.
    fromCoordinate = fromCoordinate or self.LeadGroup:GetCoordinate()

    -- Get path and path length on road including the end points (From and To).
    local pathOnRoad, lengthOnRoad, gotPath = fromCoordinate:GetPathOnRoad( toCoordinate, true )

    -- Get the length only(!) on the road.
    local _, lengthRoad = fromCoordinate:GetPathOnRoad( toCoordinate, false )

    -- Off road part of the rout: Total=OffRoad+OnRoad.
    local lengthOffRoad
    local longRoad

    -- Calculate the direct distance between the initial and final points.
    local lengthDirect = fromCoordinate:Get2DDistance( toCoordinate )

    if gotPath and lengthRoad then

      -- Off road part of the rout: Total=OffRoad+OnRoad.
      lengthOffRoad = lengthOnRoad - lengthRoad

      -- Length on road is 10 times longer than direct route or path on road is very short (<5% of total path).
      longRoad = lengthOnRoad and ((lengthOnRoad > lengthDirect * 10) or (lengthRoad / lengthOnRoad * 100 < 5))

      -- Debug info.
      Debug(string.format( "Length on road   = %.3f km", lengthOnRoad / 1000 ))
      Debug( string.format( "Length on road   = %.3f km", lengthOnRoad / 1000 ) )
      Debug( string.format( "Length directly  = %.3f km", lengthDirect / 1000 ) )
      Debug( string.format( "Length fraction  = %.3f km", lengthOnRoad / lengthDirect ) )
      Debug( string.format( "Length only road = %.3f km", lengthRoad / 1000 ) )
      Debug( string.format( "Length off road  = %.3f km", lengthOffRoad / 1000 ) )
      Debug( string.format( "Percent on road  = %.1f", lengthRoad / lengthOnRoad * 100 ) )

    end

    -- Route, ground waypoints along road.
    local route = {}
    local canRoad = false

    -- Check if a valid path on road could be found.
    if gotPath and lengthRoad and lengthDirect > 2000 then -- if the length of the movement is less than 1 km, drive directly.
      -- Check whether the road is very long compared to direct path.
      if longRoad and shortcut then

        -- Road is long ==> we take the short cut.

        table.insert( route, fromCoordinate:WaypointGround( speed, offRoadFormation ) )
        table.insert( route, toCoordinate:WaypointGround( speed, offRoadFormation ) )

      else

        -- Create waypoints.
        table.insert( route, fromCoordinate:WaypointGround( speed, offRoadFormation ) )
        table.insert( route, pathOnRoad[2]:WaypointGround( speed, "On Road" ) )
        table.insert( route, pathOnRoad[#pathOnRoad - 1]:WaypointGround( speed, "On Road" ) )

        -- Add the final coordinate because the final might not be on the road.
        local dist = toCoordinate:Get2DDistance( pathOnRoad[#pathOnRoad - 1] )
        if dist > 10 then
          table.insert( route, toCoordinate:WaypointGround( speed, offRoadFormation ) )
          table.insert( route, toCoordinate:GetRandomCoordinateInRadius( 10, 5 ):WaypointGround( 5, offRoadFormation ) )
          table.insert( route, toCoordinate:GetRandomCoordinateInRadius( 10, 5 ):WaypointGround( 5, offRoadFormation ) )
        end

      end

      canRoad = true
    else

      -- No path on road could be found (can happen!) ==> Route group directly from A to B.
      table.insert( route, fromCoordinate:WaypointGround( speed, offRoadFormation ) )
      table.insert( route, toCoordinate:WaypointGround( speed, offRoadFormation ) )

    end

    -- Add passing waypoint function.
    if waypointFunction then
      local N = #route
      for n, waypoint in pairs( route ) do
        waypoint.task = {}
        waypoint.task.id = "ComboTask"
        waypoint.task.params = {}
        waypoint.task.params.tasks = { self:TaskFunction( "CONTROLLABLE.___PassingWaypoint", n, N, waypointFunction, unpack( waypointFunctionArguments or {} ) ) }
      end
    end

    return route, canRoad
  end