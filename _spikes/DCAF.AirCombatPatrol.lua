-- //////////////////////////////////////////////////////////////////////////////////
--                                     DCAF.CombatAirPatrol
--                                     ********************
-------------------------------------------------------------------------------------
-- DEPENDENCIES
--   MOOSE
--   DCAF.Core

local CAP_THREAT = {
    None = 0,          -- no tracked target (can support other CAP)
    Low = 1,           -- tracked target is either inferior or doesn't seem to be heading straight for CAP (can support other CAP)
    Medium = 2,        -- tracked target is either inferior and heading for CAP, or equal but heading elsewhere (MIGHT support other CAP)
    High = 3,          -- CAP is engaged/supporting, or tracked target is either superior or heading for CAP (cannot support other CAP)
    Critical = 4       -- tracked target is superior force, headng for CAP. This is the flight-or-fight moment!
}

DCAF.AirThreat = {
    ClassName = "DCAF.AirThreat",
    ----
    ThreatSum = 0,
    ThreatSize = 0,
    ThreatGroups = {}
}

local CAP_INFO = {
    ClassName = "CAP_INFO",
    ----
    Name = nil,
    CAPGroup = nil,                     -- CAP #GROUP
    ThreatLevel = CAP_THREAT.None,      -- CAP's current threat level
    TrackedGroup = nil,                 -- #GROUP being tracked, and considered for engagement
    TrackedCluster = nil,               -- #INTEL.Cluster being tracked, and considered for engagement
    Manager = nil,                      -- #DCAF.CombatAirPatrol (or whatever we'll call it later)
    -- MinimumAttackRatio = 1.1,           -- #number The minimum numeric ratio required for a CAP to engage -- TODO consider ways to make this configurable

    Supporting = {
        -- key   = name of CAP supporting this CAP
        -- value = #CAP_INFO supporting this CAP
    },
    Supports = nil                      -- #CAP_INFO this CAP is supporting
}

DCAF.AirStrategy = {
    ClassName = "DCAF.AirStrategy",
    ----
    Name = nil,
    AirGroups = {
        -- list of GROUP
    },
    TargetCluster = nil,
    TargetGroups = {
        -- list of #GROUP
    },
    IntervalValidateOutcome = 5,                -- #number - interval (seconds) while validating outcome (see :ValidateOutcome())
    _onValidateOutcome = function(strategy)     -- #function - the delegate to be invoked during outcome validation
        -- to be supplied by client
    end
}

function DCAF.AirStrategy:New(name)
    local strategy = DCAF.clone(DCAF.AirStrategy)
    strategy.Name = name or "BASIC"
    return strategy
end

local function toString(list, func)
    local s
    if #list == 0 then return "(none)" end
    for _, group in ipairs(list) do
        if not s then
            s = func(group)
            if not isString(s) then error("toString :: expected string from delegate, but got: " .. DumpPretty(s)) end
        else
            s = s .. ', ' .. func(group)
        end
    end
    return s
end

function DCAF.AirStrategy:DebugMessage(message)
    return self.Manager:DebugMessage(message)
end

function DCAF.AirStrategy:GetName()
    return self._validationName or self.Name
end

function DCAF.AirStrategy:Execute(attacker, target)
    if target == nil then error("DCAF.AirStrategy:New :: target was not supplied") end
    if isGroup(attacker) then attacker = { attacker } end
    if not isList(attacker) then error("DCAF.AirStrategy:New :: attacker must be #GROUP or list of #GROUP") end
    if isGroup(target) then target = { target } end
    if not isList(target) then error("DCAF.AirStrategy:New :: target must be #GROUP or list of #GROUP") end

    self.AirGroups = attacker
    self.TargetGroups = target
    self:rebuildTargetGroupsIndex()

    DCAF.AirStrategy:CountAliveAirUnits()

    self:DebugMessage("Executes '" .. self:GetName() .. "' strategy. friendly: " .. self:CountAliveAirUnits() .. " :: hostile: " .. self:CountAliveTgtUnits())

    self:ValidateOutcome()
    return self:OnExecute()
end

function DCAF.AirStrategy:rebuildTargetGroupsIndex()
    self._targetGroupsIndex = self._targetGroupsIndex or {}
    for _, group in ipairs(self.TargetGroups) do
        self._targetGroupsIndex[group.GroupName] = true
    end
end

function DCAF.AirStrategy:IsTargetGroup(group)
    return self._targetGroupsIndex and self._targetGroupsIndex[group.GroupName]
end

function DCAF.AirStrategy:ValidateOutcome()
    self._schedulerID_execute = DCAF.startScheduler(function()
        local success, err = pcall(function()
            self._onValidateOutcome(self)
        end)
        if not success then
            if isString(err) then
                Error("DCAF.AirStrategy:ValidateOutcome :: delegate failure: " .. err)
            else
                Error("DCAF.AirStrategy:ValidateOutcome :: delegate failure: " .. DumpPretty(err))
            end
        end
    end, 5)
end

function DCAF.AirStrategy:OnAcceptNewTargetGroup(group)
    -- to be overridden by custom strategy (might not accept groups too far away etc.)
    return true
end

--- Calculates a heading from average air units locations and average target units location
function DCAF.AirStrategy:GetThreatAxis(update)
    if update or self._fightAxis == nil then
        local airUnitsLocation = self:GetMedianCoordinate(self:GetAliveAirUnits())
        local tgtUnitsLocation = self:GetMedianCoordinate(self:GetAliveTgtUnits())
        self._fightAxis = {
            Start = airUnitsLocation,
            End = tgtUnitsLocation
        }
    end
    if self:IsDebug() then
        self:Debug_VisualizeFightAxis()
    end
    return self._fightAxis
end

function DCAF.AirStrategy:IsDebug()
    return self.Manager:IsDebug()
end

function DCAF.AirStrategy:Debug_VisualizeFightAxis()
    local coordStart = self._fightAxis.Start:GetCoordinate()
    local coordEnd = self._fightAxis.End:GetCoordinate()
    if self._markID_fightAxis then
        COORDINATE:RemoveMark(self._markID_fightAxis)
    end
    self._markID_fightAxis = coordStart:LineToAll(coordEnd)
end

function DCAF.AirStrategy:Debug_End()
    if self._markID_fightAxis then
        COORDINATE:RemoveMark(self._markID_fightAxis)
    end
end

local function getMedianCoordinate(locations)
    if not isList(locations) or #locations == 0 then
Debug("nisse - getMedianCoordinate :: locations: " .. DumpPrettyDeep(locations, 2))
        return Error("getMedianCoordinate :: `locations` must be list of locations")
    end

    local function calculateMedian(numbers)
        table.sort(numbers)
        local count = #numbers
        if count % 2 == 0 then
            -- Even number of elements
            return (numbers[count / 2] + numbers[count / 2 + 1]) / 2
        else
            -- Odd number of elements
            return numbers[math.ceil(count / 2)]
        end
    end

    local xValues = {}
    local yValues = {}
    local zValues = {}

    for i, location in ipairs(locations) do
        local validLocation = DCAF.Location.Resolve(location)
        if not validLocation then return Error("getMedianCoordinate :: locations[" .. i .. "] cannot be resolved: " .. DumpPretty(location)) end
        local coord = validLocation:GetCoordinate()
        table.insert(xValues, coord.x)
        table.insert(yValues, coord.y)
        table.insert(zValues, coord.z)
    end

    local medianX = calculateMedian(xValues)
    local medianY = calculateMedian(yValues)
    local medianZ = calculateMedian(zValues)

    return DCAF.Location:New(COORDINATE:New(medianX, medianY, medianZ))
end

-- TODO - consider moving to more general (common) code
function DCAF.AirStrategy:GetMedianCoordinate(locations)
    return getMedianCoordinate(locations)
end

function DCAF.AirStrategy:OnExecute()
    -- implements very basic strategy: Each air group simply attacks the closest available target group
    local function groupsToString(groups)
        return toString(groups, function(capInfo)
            return capInfo.GroupName
        end)
    end

    Debug(DCAF.AirStrategy.ClassName .. " '" .. self:GetName() .. "' Starts :: " .. groupsToString(self.AirGroups) .. " :: engages " .. groupsToString(self.TargetGroups))
    for _, airGroup in ipairs(self.AirGroups) do
        local closestTgtGroup = self:GetClosestTargetGroup(airGroup)
        if closestTgtGroup then
            airGroup:OptionROEWeaponFree()
            ROEAggressive(airGroup)
            TaskAttackGroup(airGroup, closestTgtGroup)
        end
    end
end

--- Adds a delegate to handle validation of strategy outcome
-- @param #function func - Delegate function. Will be invoked repeatedly during execution. Takes one parameter: #DCAF.AirStrategy
function DCAF.AirStrategy:OnValidateOutcome(func, name)
    if not isFunction(func) then return Error("DCAF.AirStrategy:OnValidateOutcome :: `func` must be function, but was: " .. DumpPretty(func)) end
    self._onValidateOutcome = func
    if isAssignedString(name) then
        self._validationName = name
    end
    return self
end

function DCAF.AirStrategy:Stop()
    if self._schedulerID_execute then
        Debug("DCAF.AirStrategy :: " .. self.Name .. " :: ends execution validation scheduler")
        DCAF.stopScheduler(self._schedulerID_execute)
    end
    self:Debug_End()
    self:OnStopped()
end

function DCAF.AirStrategy:OnStopped()
end

function DCAF.AirStrategy:GetClosestTargetGroup(airGroup)
    local coordAirGroup = airGroup:GetCoordinate()
    if not coordAirGroup then return end
    local cDistance = NauticalMiles(9999)
    local cTgtGroup
    for _, tgtGroup in ipairs(self.TargetGroups) do
        local coordTgtGroup = tgtGroup:GetCoordinate()
        if coordTgtGroup then
            local distance = coordTgtGroup:Get2DDistance(coordAirGroup)
            if distance < cDistance then
                cDistance = distance
                cTgtGroup = tgtGroup
            end
        end
    end
    return cTgtGroup, cDistance
end

function CAP_INFO:New(group, capManager)
    local capWaypoint = FindWaypointByPattern(group, capManager.CAP_INFO_CAP_WAYPOINT_IDENT)
    if not capWaypoint then return Error("CAP_INFO:New :: cannot find waypoint with pattern '" .. capManager.CAP_INFO_CAP_WAYPOINT_IDENT .. "'") end

    local info = DCAF.clone(CAP_INFO)
    info.Name = group.GroupName
    info.CAPGroup = group
    info.Manager = capManager
    info.ReturnToCAPRoute = group:CopyRoute(capWaypoint.index-1)
    group._capInfo = info
    return info
end

local function GetCAPInfo(group)
    return group._capInfo
end

function CAP_INFO:ReturnToCAP(speedKmh)
    if not self.CAPGroup:IsAlive() then return end
    self:Disengage(true)
    self.CAPGroup:Route(self.ReturnToCAPRoute)
    if isNumber(speedKmh) then
        self.CAPGroup:SetSpeed(UTILS.KmphToMps(speedKmh))
    end
end

function CAP_INFO:GetSize(includeSupport)
    if not includeSupport then
        return #self.CAPGroup:GetUnits()
    end
    local groups = self:GetCAPGroups(true)
    local count = 0
    for _, group in ipairs(groups) do
        count = count + #group:GetUnits()
    end
    return count
end

function CAP_INFO:GetCAPGroups(includeSupport)
    if not includeSupport then return self.CAPGroup end
    local groups = { self.CAPGroup }
    for _, group in pairs(self.Supporting) do
        groups[#groups+1] = group
    end
    return groups
end

function CAP_INFO:IsDebug()
    return self.Manager:IsDebug()
end

function CAP_INFO:Track(group, cluster, threatSum, distance)
Debug("nisse - CAP_INFO:Track :: " .. DumpPretty(self.Name)  .. " / " .. group.GroupName)
    self.TrackedGroup = group
    self.TrackedGroupDistance = distance
    self.TrackedCluster = cluster
    self.TrackedClusterThreatSum = threatSum
    self:CalculateThreat()

    if self:IsDebug() then
        if self._trackMarkId then COORDINATE:RemoveMark(self._trackMarkId) end
        local coordOwn = self.CAPGroup:GetCoordinate()
        local coordTgt = group:GetCoordinate()
        self._trackMarkId = coordOwn:LineToAll(coordTgt, nil, { 1, 0.5, 0.5 }, 0.5, 3)
    end

    return self
end

function CAP_INFO:GetTrackedGroup()
    return self.TrackedGroup, self.TrackedCluster, self.TrackedClusterThreatSum or 0, self.TrackedGroupDistance
end

function CAP_INFO:Support(capInfo) -- NOTE the supported (capInfo) CAP must now be Engaged
    -- TODO - re-calculate threat level
    self.TrackedGroup = nil
    self.TrackedCluster = nil
    self.Supports = capInfo
    capInfo.Supporting[capInfo.Name] = capInfo
    self:CalculateThreat()
    return self
end

function CAP_INFO:GetTgtCluster()
    if self._engaged then return self._engaged.TgtCluster end
    if self.Supports then return self.Supports:GetTgtCluster() end
end

function CAP_INFO:GetTgtGroup()
    if self._engaged then return self._engaged.TgtGroup end
    if self.Supports then return self.Supports:GetTgtGroup() end
end

function CAP_INFO:GetAllTgtGroups()
    -- TODO - this can later be extended to be smarter
    local tgtCluster = self:GetTgtCluster()
    if tgtCluster then return tgtCluster.groups end
end

function CAP_INFO:GetAirStrategy()
    if self._engaged then return self._engaged.AirStrategy end
    if self.Supports then return self.Supports:GetAirStrategy() end
end

function CAP_INFO:EndSupport(capInfo)
    -- TODO - re-calculate threat level
    self.Supporting[capInfo.Name] = nil
    self:CalculateThreat()
    return self
end

function CAP_INFO:Engage(tgtCluster, tgtGroup, airStrategy)
    self.TrackedGroup = nil
    self.TrackedCluster = nil
    self._engaged = {
        TgtCluster = tgtCluster,
        TgtGroup = tgtGroup,
        AirStrategy = airStrategy
    }
    self:CalculateThreat()
    return self
end

function CAP_INFO:Disengage(allowDefend)
    -- TODO go back to patrolling, or RTB?
    self.TrackedGroup = nil
    self.TrackedCluster = nil
    if self.Supports then
        self.Supports:EndSupport(self)
        self.Supports = nil
    end
    self._engaged = nil
    if allowDefend == nil then allowDefend = true end
    if not allowDefend then
        self.CAPGroup:OptionROEReturnFire()
    else
        self.CAPGroup:OptionROEHoldFire()
    end
    self:CalculateThreat()
    return self
end

function CAP_INFO:IsEngaged()
    return self._engaged ~= nil or self.Supports ~= nil
end

function CAP_INFO:IsAvailable() -- called to see if CAP can engage hostile cluster/group
    return self.ThreatLevel < CAP_THREAT.High
end

function CAP_INFO:CanSupport(cap) -- cap: #CAP_INFO - called to see if CAP can support other CAP
    if self:IsEngaged() then
-- Debug("nisse - CAP_INFO:CanSupport :: " .. self.Name .. " :: Is Engaged :: _engaged: " .. DumpPretty(self._engaged) .. " :: Supporting: " .. DumpPretty(self.Supporting)  .. " :: cannot support")
        return false
    elseif self.ThreatLevel == CAP_THREAT.High then
-- Debug("nisse - CAP_INFO:CanSupport :: " .. self.Name .. " :: Threat Level = High :: cannot support")
        return false
    elseif self.ThreatLevel == CAP_THREAT.Medium then
-- Debug("nisse - CAP_INFO:CanSupport :: " .. self.Name .. " :: Threat Level = Medium :: might support")
        -- TODO consider refining how CAP offers support when threat is medium
        return math.random(100) < 61
    elseif self.ThreatLevel == CAP_THREAT.Low then
        return true
    elseif self.ThreatLevel == CAP_THREAT.None then
        return true
    end
end

local function delouseCAP(capInfo, airThreat)
Debug("nisse - delouseCAP :: " .. capInfo.Name)
    -- find best delouse option...
    local manager = capInfo.Manager

    for _, capInfo in ipairs(manager.CAPGroups) do
        
    end
end

local function scramCAP(capInfo, threat, location)
    if not capInfo.CAPGroup:IsAlive() then
Debug("nisse - scramCAP :: " .. capInfo.Name .. " :: CAPGroup is dead :: IGNORES")
        return
    end 
    local coord = capInfo.CAPGroup:GetCoordinate()
    if not coord then return end
    local airbase
    if location ~= nil then
        local validLocation = DCAF.Location.Resolve(location)
        if not validLocation then
            Error("DCAF.AirStrategy :: cannot resolve location: " .. DumpPretty(location))
            location = nil
        end
        if validLocation:IsAirbase() then
            airbase = validLocation.Source
        end
    else
        airbase = capInfo.Manager:SelectScramAirbase(capInfo, threat)
        if not airbase then
            local heading = threat:HeadingTo(coord)
            local coordScram = coord:Translate(NauticalMiles(150), heading)
            location = DCAF.Location:NewRaw(capInfo.Name.."-Scram", coordScram, coordScram)
        else
Debug("nisse - scramCAP :: airbase: " .. airbase.AirbaseName)
        end
    end

    local airGroup = capInfo.CAPGroup
    local speedKmh = airGroup:GetSpeedMax() or UTILS.KnotsToKmph(1200)
local nisse_speedKmh
if not speedKmh then nisse_speedKmh = "(null)" else nisse_speedKmh = UTILS.KmphToKnots(speedKmh) end
Debug("nisse - scramCAP :: " .. capInfo.Name .. " :: speed: " .. speedKmh .. " km/h (" .. nisse_speedKmh .. " kt)")
capInfo:Disengage(false)
    if airbase then
Debug("nisse - scramCAP :: " .. capInfo.Name .. " :: airbase: " .. airbase.AirbaseName)
        if airbase then
            RTBNow(airGroup, airbase, nil, speedKmh)
            -- airGroup:RouteRTB(airbase, speedKmh * 1.5)
        end
    elseif location == nil then
        capInfo:Disengage()
        airGroup:RouteRTB(nil, speedKmh * 1.5)
    else
Debug("nisse - scramCAP :: " .. capInfo.Name .. " :: no airbase - just scrams for 150nm and then lands")
        local coordLocation = location:GetCoordinate()
        coordLocation:MarkToAll("SCRAM - " .. capInfo.Name)
        local route = {
            coordLocation:WaypointAirFlyOverPoint("RADIO", speedKmh)
        }
        setGroupRoute(capInfo.CAPGroup, route)
    end
end

local function delouseOrScramCAP(capInfo, threat, scramLocation)
    local cap = capInfo.Manager
    if not cap._delouseOptions then
        scramCAP(capInfo, threat, scramLocation)
    end
    delouseCAP(capInfo, threat)
end

function CAP_INFO:CalculateTrackedClusterThreatAndSize() -- EDITED --
    local threatLevelMax = self.Manager._intel:CalcClusterThreatlevelMax(self.TrackedCluster)
    return threatLevelMax, DCAF.CombatAirPatrol:GetClusterSize(self.TrackedCluster)
end

function CAP_INFO:CalculateThreat()
    if self:IsEngaged() or self.SuperiorThreat then
        self.ThreatLevel = CAP_THREAT.High
        return self
    end

    if not self.TrackedGroup then
        self.ThreatLevel = CAP_THREAT.None
        return self
    end

    local hot, distancePredicted, relDirection = self:isHot(self.TrackedCluster, self.TrackedGroup)
    if hot then
        self.ThreatLevel = CAP_THREAT.Medium
        return self
    end
    if distancePredicted < self.Manager.CapTriggerDistanceNm then
        -- tracked group is predicted to be within engagement range "soon"...
        local threatLevelMax, threatSize = self:CalculateTrackedClusterThreatAndSize()
        if threatLevelMax < 5 then
            self.ThreatLevel = CAP_THREAT.Low
            return self
        end
        local ownSize = self:GetSize()
        local ratio = ownSize / threatSize
        if ratio < .7 or threatLevelMax > 7 then
            self.ThreatLevel = CAP_THREAT.High
        else
            self.ThreatLevel = CAP_THREAT.Medium
        end
        return self
    end
end

function CAP_INFO:isHot(cluster, tgtGroup)
    local coordCAP = self.CAPGroup:GetCoordinate()
    local coordFuture = self.Manager._intel:CalcClusterFuturePosition(cluster, self.CapMonitorPredictTime)
    local distanceFuture = coordCAP:Get2DDistance(coordFuture)
    local capBearing = self.Manager._intel:GetClusterCoordinate(cluster):HeadingTo(coordCAP)
    local tgtHeading = self.Manager._intel:CalcClusterDirection(cluster)
    local relDirection = math.abs(GetRelativeDirection(tgtHeading, capBearing))

Debug("nisse -CAP_INFO:isHot :: CAP: " .. self.Name .. " :: TGT: " .. tgtGroup.GroupName .. " :: tgtHeading: " .. tgtHeading .. " :: relDirection: " .. relDirection)

-- -- NISSE
-- if self.Manager._debug then
--     if self._markID_own then COORDINATE:RemoveMark(self._markID_own) end
--     if self._markID_tgt then COORDINATE:RemoveMark(self._markID_tgt) end
--     local coordTgt = tgtGroup:GetCoordinate()
--     if coordTgt then
--         self._markID_own = coordCAP:MarkToAll(tgtGroup.GroupName)
--         self._markID_tgt = coordTgt:MarkToAll(self.Name)
--     end
-- end

    local hot = distanceFuture <= NauticalMiles(self.Manager.CapTriggerDistanceNm) -- and relDirection < 41
Debug("nisse - CAP_INFO:isHot :: CAP: " .. self.Name .. " :: TGT: " .. tgtGroup.GroupName .. " :: distanceFuture: " .. UTILS.MetersToNM(distanceFuture).." nm :: hot: " .. Dump(hot))
    return hot, distanceFuture, relDirection
end

local dcafCombatAirPatrolCount = 0

DCAF.CombatAirPatrol = {
    ClassName = "DCAF.CombatAirPatrol",
    ----
    CapMonitorDistanceNm = 50,          -- when closer than this (from CAP) a hostile cluster will be tracked and considered for engagement
    CapMonitorPredictTime = Minutes(1), -- the time used to calculate a cluster's future position, while being tracked
    CapTriggerDistanceNm = 20,          -- when calculated to be closer than this (from CAP), within `CapMonitorPredictTime` seconds a hostile cluster 
    CAP_INFO_CAP_WAYPOINT_IDENT = "CAP",
    MinimumAttackRatio = 1.1,           -- #number The minimum numeric ratio required for a CAP to engage -- TODO consider ways to make this configurable
    MinimumRetreatRatio = 0.8,          -- #number When ration falls below this value the CombatAirPatrol invoke its ExecuteDefensiveStrategy function
    CAPGroups = {
        -- list of #CAP_INFO
    },
    AirStrategies = {
        -- list of #DCAF.AirStrategy
    }
}

function DCAF.CombatAirPatrol:New(name, capMonitorDistanceNm, capMonitorPredictSeconds, capTriggerDistanceNm)
    dcafCombatAirPatrolCount = dcafCombatAirPatrolCount+1
    if not isAssignedString(name) then name = DCAF.CombatAirPatrol.ClassName .. "-" .. dcafCombatAirPatrolCount end
    local cap = DCAF.clone(DCAF.CombatAirPatrol)
    cap.Name = name
    if isNumber(capMonitorDistanceNm) then cap.CapMonitorDistanceNm = capMonitorDistanceNm end
    if isNumber(capMonitorPredictSeconds) then cap.CapMonitorPredictTime = capMonitorPredictSeconds end
    if isNumber(capTriggerDistanceNm) then cap.CapTriggerDistanceNm = capTriggerDistanceNm end
    return cap
end

function DCAF.CombatAirPatrol:InitMinimumAttackRatio(value)
    if not isNumber(value) then return Error("DCAF.CombatAirPatrol:InitMinimumAttackRatio :: value must be number, but was: " .. DumpPretty(value), self) end
    self.MinimumAttackRatio = value
    return self
end

function DCAF.CombatAirPatrol:InitMinimumRetreatRatio(value)
    if not isNumber(value) then return Error("DCAF.CombatAirPatrol:InitMinimumRetreatRatio :: value must be number, but was: " .. DumpPretty(value), self) end
    self.MinimumRetreatRatio = value
    return self
end

function DCAF.CombatAirPatrol:InitScramAirbase(location)
    local listOfLocations
    if isListOfAssignedStrings(location) then
        listOfLocations = {}
        for _, l in ipairs(location) do
            local loc = DCAF.Location.Resolve(l)
            if not isAirbase(loc.Source) then return Error("DCAF.CombatAirPatrol:InitScramAirbase :: location is not a valid AIRBASE: " .. DumpPretty(loc.Source), self) end
            listOfLocations[#listOfLocations+1] = loc
        end
    elseif isListOfClass(location, DCAF.Location) then
        for _, loc in ipairs(location) do
            if not isAirbase(loc.Source) then return Error("DCAF.CombatAirPatrol:InitScramAirbase :: location is not a valid AIRBASE: " .. DumpPretty(loc.Source), self) end
        end
        listOfLocations = location
    else
        local validLocation = DCAF.Location.Resolve(location)
        if not validLocation or not isAirbase(validLocation.Source) then return Error("DCAF.CombatAirPatrol:InitScramAirbase :: cannot resolve AIRBASE from: " .. DumpPretty(location), self) end
        listOfLocations = { validLocation }
    end
    self._scramAirbases = listOfLocations
    return self
end

function DCAF.CombatAirPatrol:SelectScramAirbase(capInfo, threat)
    local coord = capInfo.CAPGroup:GetCoordinate()
    if not coord then return end
    local setAirbase
    if not self._scramAirbases then
        if not coord then return end
        local coalition = capInfo.CAPGroup:GetCoalition()
        setAirbase = SET_AIRBASE:New():FilterCoalitions(coalition):FilterOnce()
    else
        setAirbase = SET_AIRBASE:New()
        for _, locAirbase in ipairs(self._scramAirbases) do
            setAirbase:AddAirbase(locAirbase.Source)
        end
    end

    local coordThreat = threat:GetCoordinate()
    local headingFromThreat = coordThreat:HeadingTo(coord)
    local eval = {
        ClosestAirbase = nil,
        ClosestDistance = NauticalMiles(9999),
        -- the 'safe' alternative is inside safe bearings (away from threat)
        ClosestSafeAirbase = nil,
        ClosestSafeDistance = NauticalMiles(9999),
        -- safe bearings
        MinSafeBearing = (headingFromThreat - 130) % 360,
        MaxSafeBearing = (headingFromThreat + 130) % 360,
    }
    function eval:isSafeHeading(heading)
        local rel = GetRelativeDirection(heading, self.MinSafeBearing)
        if rel < 0 then return false end
        rel = GetRelativeDirection(heading, self.MaxSafeBearing)
        return rel <= 0
    end
    function eval:process(airbase)
        local coordAirbase = airbase:GetCoordinate()
        local distance = coord:Get2DDistance(coordAirbase)
        local headingToAirbase = coord:HeadingTo(coordAirbase)
        local isSafeHeading = self:isSafeHeading(headingToAirbase)
        if isSafeHeading then
            if self.ClosestSafeDistance >= distance then return end
            self.ClosestSafeAirbase = airbase
            self.ClosestSafeDistance = distance
        else
            if self.ClosestDistance >= distance then return end
            self.ClosestAirbase = airbase
            self.ClosestDistance = distance
        end
    end
    function eval:selectAirbase()
        if self.ClosestSafeAirbase then
            return self.ClosestSafeAirbase
        else
            return self.ClosestAirbase

        end
    end

    setAirbase:ForEachAirbase(function(airbase)
        eval:process(airbase)
    end)
    return eval:selectAirbase()
end

function DCAF.CombatAirPatrol:InitDelouseOptions(cap)
    local caps
    if isClass(cap, DCAF.CombatAirPatrol) then
        caps = { cap }
    elseif isListOfClass(cap, DCAF.CombatAirPatrol) then
        caps = cap
    else
        return Error("DCAF.CombatAirPatrol:InitDelouseOptions :: `cap` must be #" .. DCAF.CombatAirPatrol.ClassName  .. " or a list thereof, but was: " .. DumpPretty(cap))
    end
    self._delouseOptions = self._delouseOptions or {}
    for _, cap in ipairs(caps) do
        self._delouseOptions[#self._delouseOptions+1] = cap
    end
    return self
end

function DCAF.CombatAirPatrol:DebugMessage(message)
    local debug = self:IsDebug()
    if not debug then return self end
    local duration
    if isNumber(debug) then
        duration = debug
    end
    MessageTo(nil, message, duration)
end

function DCAF.CombatAirPatrol:GetClusterSize(cluster)
    local size = 0
    local groups = {}
    for _, contact in ipairs(cluster.Contacts) do
-- Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster_clusterSize :: contact: " .. DumpPrettyDeep(contact, 2))
        local group = contact.group
        size = size + #group:GetUnits()
        groups[#groups+1] = group
    end
    return size, groups
-- Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster_clusterSize :: cluster: " .. DumpPrettyDeep(cluster, 2))        
end

--- Adds cluster size and groups to existing size/collection
function DCAF.CombatAirPatrol:AddClusterSize(cluster, size, groups, index)
    -- note - I'm not 100% sure whether same group can occur in multiple clusters so we'll use a dictionary to avoid duplicates
    if index == nil then
        index = {}
        for _, group in ipairs(groups) do
            index[group.GroupName] = true
        end
    end
    for _, contact in ipairs(cluster.Contacts) do
-- Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster_clusterSize :: contact: " .. DumpPrettyDeep(contact, 2))
        local group = contact.group
        size = size + #group:GetUnits()
        local key = group.GroupName
        if not index[key] then
            groups[#groups+1] = group
            index[key] = true
        end
    end
    return size, groups, index
-- Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster_clusterSize :: cluster: " .. DumpPrettyDeep(cluster, 2))        
end

function DCAF.CombatAirPatrol:Start(coalition, capPattern, ewrPattern, awacsPattern)
    local validCoalition = Coalition.Resolve(coalition, true)
    if not validCoalition then return Error("DCAF.CombatAirPatrol:Start :: could not resolve coalition: " .. DumpPretty(coalition)) end

    local function ensureList(value, argName)
        if value == nil then return nil end
        if isAssignedString(value) then
            return { value }
        elseif not isListOfAssignedStrings(value) then
            return Error("DCAF.CombatAirPatrol:Start :: `" .. argName .. "` must be assigned string, or list thereof, but was: " .. DumpPretty(capPattern))
        end
        return value
    end

    local function join(tgtList, sourceList)
        if not isListOfAssignedStrings(sourceList) then return tgtList end
        for _, item in ipairs(sourceList) do
            tgtList[#tgtList+1] = item
        end
        return tgtList
    end


    local validCapPattern = ensureList(capPattern, 'capPattern')
    if not validCapPattern then return self end
    local validEwrPattern = ensureList(ewrPattern, 'ewrPattern')
    local validAwacsPattern = ensureList(awacsPattern, 'awacsPattern')

    if isAssignedString(capPattern) then
        capPattern = { capPattern }
    elseif not isListOfAssignedStrings(capPattern) then
        return Error("DCAF.CombatAirPatrol:Start :: `capPattern` must be assigned string, or list thereof, but was: " .. DumpPretty(capPattern))
    end
    local prefixes = join(join(capPattern,  validEwrPattern), validAwacsPattern)
    local setDetection = SET_GROUP:New():FilterPrefixes(prefixes):FilterOnce()
    self._intel = INTEL:New(setDetection, validCoalition, self.Name)
                       :SetFilterCategory(Group.Category.AIRPLANE, Group.Category.HELICOPTER) -- EDIT --
    self:_applyDebug()
    self._intel:__Start(2)

    local function startCAP(group)
        if not group:IsActive() or not group:IsAlive() then return end
        Debug(self.Name ..  ":Start :: added CAP group: " .. group.GroupName)
        self.CAPGroups[group.GroupName] = CAP_INFO:New(group, self)
        self._intel:AddAgent(group)
        group:OptionROEHoldFire()
    end

    local setGroups = SET_GROUP:New():FilterPrefixes(validCapPattern):FilterOnce()
    setGroups:ForEachGroup(function(group)
        startCAP(group)
    end)
    Debug("DCAF.CombatAirPatrol:Start :: " .. self.Name .. " :: CAP Groups: " .. DumpPretty(self.CAPGroups))

    self._schedulerID = DCAF.startScheduler(function()
        local clusters = self._intel:GetClusterTable()
        for i, cluster in pairs(clusters) do
            local threatSum = self._intel:CalcClusterThreatlevelSum(cluster)
            local coord = self._intel:GetClusterCoordinate(cluster, true)
            local capInfo, distance = self:GetClosestAvailableCAP(coord)
            if capInfo then
                self:EvaluateCluster(capInfo, cluster, threatSum, distance, i, #clusters)
            end
        end
    end, 5)

    return self
end

function DCAF.CombatAirPatrol:Stop()
    if self._schedulerID then
        DCAF.stopScheduler(self._schedulerID)
        self._schedulerID = nil
    end
end

-- function DCAF.AirStrategy:OnAfterNewCluster(cluster)
--     -- to be overridden
-- end

-- function DCAF.AirStrategy:OnAfterNewContact(contact)
--     -- to be overridden
-- end

function DCAF.AirStrategy:CountAliveUnits(listOfgroups)
    local count = 0
    for _, group in ipairs(listOfgroups) do
        count = count + group:CountAliveUnits()
    end
    return count
end

function DCAF.AirStrategy:CountAliveAirUnits()
    return self:CountAliveUnits(self.AirGroups)
end

function DCAF.AirStrategy:CountAliveTgtUnits()
    return self:CountAliveUnits(self.TargetGroups)
end

function DCAF.AirStrategy:GetAliveUnits(listOfgroups)
    local aliveUnits = {}
    for _, group in ipairs(listOfgroups) do
        local units = group:GetUnits()
        if units then
            for _, unit in ipairs(units) do
                if unit:IsAlive() then aliveUnits[#aliveUnits+1] = unit end
            end
        end
    end
    return aliveUnits
end

function DCAF.AirStrategy:GetAliveAirGroups()
    local aliveGroups = {}
    for _, airGroup in ipairs(self.AirGroups) do
        if airGroup:IsAlive() then aliveGroups[#aliveGroups+1] = airGroup end
    end
    return aliveGroups
end

function DCAF.AirStrategy:GetAliveAirUnits()
    return self:GetAliveUnits(self.AirGroups)
end

function DCAF.AirStrategy:GetAliveTgtUnits()
    return self:GetAliveUnits(self.TargetGroups)
end

function DCAF.AirStrategy:CalculateRatio()
    local airUnits = self:CountAliveAirUnits()
    local tgtUnits = self:CountAliveTgtUnits()
    local ratio = airUnits / tgtUnits
Debug("nisse - DCAF.AirStrategy:CalculateRatio :: airUnits: " .. airUnits .. " :: tgtUnits: " .. tgtUnits .. " :: ratio:" .. ratio)
    return airUnits / tgtUnits, tgtUnits
end

function DCAF.AirStrategy:GetIntelContactGroups(ignoreTargetGroups)
    local contacts = self.Manager._intel:GetContactTable()
    local groups = {}
    for _, contact in ipairs(contacts) do
        local group = contact.group
        if not ignoreTargetGroups or not self:IsTargetGroup(group) then
            groups[#groups+1] = group
        end
    end
-- Debug("nisse - DCAF.AirStrategy:GetIntelContactGroups :: groups: " .. DumpPrettyDeep(groups, 1))
    return groups
end

function DCAF.AirStrategy:AddTargetGroups(targetGroups)
    if isGroup(targetGroups) then targetGroups = { targetGroups } end
    if not isList(targetGroups) or #targetGroups == 0 then return end
    for _, tgtGroup in ipairs(targetGroups) do
        if not self:IsTargetGroup(tgtGroup) and self:OnAcceptNewTargetGroup(tgtGroup) then
            Debug("DCAF.AirStrategy:AddTargetGroups :: target group: " .. tgtGroup.GroupName)
            self.TargetGroups[#self.TargetGroups+1] = tgtGroup
        end
    end
    self:rebuildTargetGroupsIndex()
end

function DCAF.CombatAirPatrol:GetContactGroups(contact)
-- Debug("nisse - DCAF.CombatAirPatrol:GetContactGroups: " .. DumpPrettyDeep(contact, 1))
    return contact.Groups
end

function DCAF.CombatAirPatrol:ExecuteDefensiveStrategy(caps, tgtGroup, tgtCluster)
end

function DCAF.CombatAirPatrol:CalculateFuturePosition(contactOrGroup, seconds)
    local contact
    if isGroup(contactOrGroup) then
        contact = self._intel:GetContactByName(contactOrGroup.GroupName)
    else
        contact = contactOrGroup
    end
    local cluster = self._intel:GetClusterOfContact(contact)
    return self._intel:CalcClusterFuturePosition(cluster, seconds)
end

function DCAF.CombatAirPatrol:ExecuteOffensiveStrategy(caps, tgtGroup, tgtCluster)
    -- TODO - this can later be extended to pick one of several strategies, based on the air picture
    local function dca(airStrategy)

        local function isThreat(airGroup, tgtGroup)
            local coordAirGroup = airGroup:GetCoordinate()
            if not coordAirGroup then return false end
            local contact = self._intel:GetContactByName(tgtGroup.GroupName)
            local threatLevel = self._intel:GetContactThreatlevel(contact)
            if threatLevel < 6 then return false end
            local distance = coordAirGroup:Get2DDistance(self:CalculateFuturePosition(contact, Minutes(2)))
            local hot = distance < NauticalMiles(20)
            return hot
        end

        local function dispose()
            airStrategy._dca = nil
            for _, airGroup in ipairs(airStrategy.AirGroups) do
                airGroup._dca = nil
                local units = airGroup:GetUnits()
                if units then
                    for _, airUnit in ipairs(units) do
                        airUnit._dca = nil
                    end
                end
            end
            for _, tgtGroup in ipairs(airStrategy.TargetGroups) do
                tgtGroup._dca = nil
                local units = tgtGroup:GetUnits()
                if units then
                    for _, airUnit in ipairs(units) do
                        airUnit._dca = nil
                    end
                end
            end
        end

        local function scram(threat)
            Debug(self.Name..":ExecuteOffensiveStrategy_dca :: all air units scrams (ratio too unfavourable)")
            self:DebugMessage("AirStrategy '".. self.Name .."'. Friendly units are out-gunned. Scrams!")
local nisse = {}
for _, i in ipairs(caps) do
    nisse[#nisse+1] = i.Name
end            
Debug("nisse - scram :: caps: " .. DumpPretty(nisse))
            for _, capInfo in ipairs(caps) do
                delouseOrScramCAP(capInfo, threat)
            end
            airStrategy:Stop()
            dispose()
        end

        local function returnToCAP()
            for _, capInfo in ipairs(caps) do
                capInfo:ReturnToCAP()
            end
        end

        local function getThreatGroups()
            -- looks for groups that may be a threat, but currently not part of the strategy..
            local tgtGroups = airStrategy:GetIntelContactGroups(true)
            local airGroups = airStrategy:GetAliveAirGroups()
            local threatGroupsIndex = {}
            local threatGroups = {}
            for _, airGroup in ipairs(airGroups) do
                for _, tgtGroup in ipairs(tgtGroups) do
if self.Name == "CAP DEFENCE 1" then
Debug("nisse - getThreatGroups :: threatGroupsIndex: " .. DumpPretty(threatGroupsIndex))
end
                    if not threatGroupsIndex[tgtGroup.Name] and isThreat(airGroup, tgtGroup) then
                        self:DebugMessage("Strategy '".. airStrategy:GetName() .. "' detects threat: " .. tgtGroup.GroupName)
                        threatGroupsIndex[tgtGroup.GroupName] = tgtGroup
                        threatGroups[#threatGroups+1] = tgtGroup
                    end
                end
            end
-- Debug("nisse - getThreatGroups :: threatGroups: " .. DumpPretty(threatGroups))
            return threatGroups
        end

        -- monitor possible additional threat groups...
        local threatGroups = getThreatGroups()
        if #threatGroups > 0 then airStrategy:AddTargetGroups(threatGroups) end

        -- scram when too badly outnumbered...
        local ratio, threatSize = airStrategy:CalculateRatio()
        if ratio <= self.MinimumRetreatRatio then
            local threat = DCAF.AirThreat:New(threatSize, airStrategy.TargetGroups)
            return scram(threat)
        end

        -- check for TGT units leaving...
        local now = UTILS:SecondsOfToday()
        local tgtUnits = airStrategy:GetAliveTgtUnits()
        -- local airUnits = airStrategy:GetAliveAirUnits()
        local countCold = 0
        local fightAxis = airStrategy:GetThreatAxis(true)
        local fightAxisHeading = fightAxis.Start:HeadingTo(fightAxis.End)

        local function initialize()
            if airStrategy._dca then return end
            airStrategy._dca = {}
            for _, airGroup in ipairs(airStrategy.AirGroups) do
                airGroup._dca = {}
                for _, airUnit in ipairs(airGroup:GetUnits()) do
                    airUnit._dca = {}
                end
            end
            for _, tgtGroup in ipairs(airStrategy.TargetGroups) do
                tgtGroup._dca = {}
                for _, airUnit in ipairs(tgtGroup:GetUnits()) do
                    airUnit._dca = {}
                end
            end
        end

        initialize()

        local function isCold(tgtUnit)
            -- check if TGT unit is cold aspect to fight axis...
            local relDir = GetRelativeDirection(tgtUnit:GetHeading(), fightAxisHeading)
            local cold = math.abs(relDir) < 95
-- Debug("nisse - isCold :: relDir: " .. relDir .. " :: cold: " .. Dump(cold))
            return cold
        end

        for _, tgtUnit in ipairs(tgtUnits) do
            if tgtUnit._dca and tgtUnit._dca._coldTime and now - tgtUnit._dca._coldTime > 20 then
                -- TGT unit's been cold for 20+ seconds...
                countCold = countCold + 1
            else
                if isCold(tgtUnit) then
                    tgtUnit._dca._coldTime = tgtUnit._dca._coldTime or now
                else
                    tgtUnit._dca._coldTime = nil
                end
            end
        end
        if countCold == #tgtUnits then
            -- go back to CAP...
            Debug(self.Name .. ":ExecuteOffensiveStrategy - " .. airStrategy:GetName() .. " :: ends (air groups returns to CAP)")
            self:DebugMessage("AirStrategy '".. self.Name .."'. No threat detected. Friendly units return to CAP")
            returnToCAP()
            dispose()
            airStrategy:Stop()
        end
    end

    local function getAirGroups()
        local airGroups = {}
        for _, capInfo in ipairs(caps) do
            airGroups[#airGroups+1] = capInfo.CAPGroup
        end
        return airGroups
    end

    local function getTgtGroups()
        local target = { tgtGroup }
        -- add other groups in cluster, as "secondary" to provide better picture for strategy
        local contacts = tgtCluster.Contacts
        for _, contact in ipairs(contacts) do
-- Debug("nisse - DCAF.CombatAirPatrol:ExecuteOffensiveStrategy :: contact: " .. DumpPrettyDeep(contact, 1))
            local group = contact.group
            if group ~= tgtGroup then
                target[#target+1] = group
            end
        end
        return target
    end

    local airStrategy = DCAF.AirStrategy:New():OnValidateOutcome( dca, "DCA" )
    local primaryCAP = caps[1]
    primaryCAP:Engage(tgtCluster, tgtGroup, airStrategy)
    for i = 2, #caps, 1 do
        caps[i]:Support(primaryCAP)
    end

    self:AddAirStrategy(airStrategy)
    airStrategy:Execute(getAirGroups(), getTgtGroups())
    return self
end

function DCAF.CombatAirPatrol:AddAirStrategy(airStrategy)
    airStrategy.Manager = self
    self.AirStrategies[#self.AirStrategies+1] = airStrategy
end

function DCAF.CombatAirPatrol:_applyDebug()
    if not self._debug or not self._intel then return self end
Debug("nisse - DCAF.CombatAirPatrol:Debug :: sets cluster analysis ON")
    self._intel:SetClusterAnalysis(true, true, true)
    self._intel:SetVerbosity(2)
end

function DCAF.CombatAirPatrol:Debug(value)
-- Debug("nisse - DCAF.CombatAirPatrol:Debug :: self: " .. DumpPretty(self))
    self._debug = value
    return self:_applyDebug()
end

function DCAF.CombatAirPatrol:IsDebug()
    return self._debug
end

function DCAF.CombatAirPatrol:SortClosestAvailableCAP(coord, inSupportOfCAP)
    local availableCaps = {}

    local function calcCAP(capInfo)
        if inSupportOfCAP then
            if not capInfo:CanSupport(inSupportOfCAP) then return end
        else
            if not capInfo:IsAvailable() then return end
        end
        local capCoord = capInfo.CAPGroup:GetCoordinate()
        if not capCoord then
            return
        end
        availableCaps[#availableCaps+1] = { CAP = capInfo, Distance = capCoord:Get2DDistance(coord) }
    end

    for _, info in pairs(self.CAPGroups) do
        calcCAP(info)
    end
    table.sort(availableCaps, function (a, b)
        return a.Distance < b.Distance
    end)

-- Debug("nisse - DCAF.CombatAirPatrol:SortClosestAvailableCAP :: availableCaps: " .. toString(availableCaps, function(i) return i.CAP.Name end))
    return availableCaps
end

function DCAF.CombatAirPatrol:GetClosestAvailableCAP(coord, inSupportOfCAP)
    local closestDistanceTGT = NauticalMiles(9999999)
    local closestCapInfo
    local closestDistanceCAP

    local function calcCAP(capInfo)
        if inSupportOfCAP then
            if not capInfo:CanSupport(inSupportOfCAP) then return end
        else
            if not capInfo:IsAvailable() then return end
        end
        local capCoord = capInfo.CAPGroup:GetCoordinate()
        if not capCoord then
            return
        end
        local distance = capCoord:Get2DDistance(coord)
        if distance < closestDistanceTGT then
            closestDistanceTGT = distance
            closestCapInfo = capInfo
            if inSupportOfCAP then
                closestDistanceCAP = capInfo.CAPGroup:GetCoordinate():Get2DDistance(inSupportOfCAP.CAPGroup:GetCoordinate())
            end
        end
    end

    for _, info in pairs(self.CAPGroups) do
        calcCAP(info)
    end
    return closestCapInfo, closestDistanceTGT, closestDistanceCAP
end

function DCAF.AirThreat:New(threatSize, threatGroups, threatSum)
    local threat = DCAF.clone(DCAF.AirThreat)
    threat.ThreatSize = threatSize
    threat.ThreatGroups = threatGroups
    threat.ThreatSum = threatSum -- TODO - currently the threat SUM is not used. Consider removing if not needed
    return threat
end

function DCAF.AirThreat:GetCoordinate()
    return getMedianCoordinate(self.ThreatGroups)
end

function DCAF.AirThreat:HeadingTo(coordinate)
    local coordSelf = self:GetCoordinate()
    return coordSelf:HeadingTo(coordinate)
end

function DCAF.CombatAirPatrol:EvaluateCluster(capInfo, cluster, threatSum, distance, clusterIndex, countClusters)
    local tgtGroup = self._intel:GetHighestThreatContact(cluster).group
    local coordCapInfo = capInfo.CAPGroup:GetCoordinate()
    local coordFuture = self._intel:CalcClusterFuturePosition(cluster, capInfo.CapMonitorPredictTime)
    local distanceFuture = coordFuture:Get2DDistance(coordCapInfo)

-- local function isFulcrum() -- nisse
--     return true -- capInfo.Name == "DCAF.CombatAirPatrol RED CAP-2 Fulcrum-1" or capInfo.Name == "DCAF.CombatAirPatrol RED CAP-2 Fulcrum-2"
-- end
-- DebugIf( isFulcrum, "nisse - DCAF.CombatAirPatrol:EvaluateCluster :: capInfo: " .. DumpPretty({
--     capInfo = capInfo.Name,
--     tgtGroup = tgtGroup.GroupName,
--     threatSum = threatSum,
--     distance = UTILS.MetersToNM(distance) .. " nm",
--     distanceFuture = UTILS.MetersToNM(distanceFuture) .. " nm",
--     triggerDistance = self.CapTriggerDistanceNm .. " nm",
--     clusterIndex = clusterIndex
-- }))

    if distanceFuture >= distance then return end -- group is cold
    if distanceFuture > NauticalMiles(self.CapTriggerDistanceNm) then return end -- group is not projected to intrude on protected airspace

    -- group will penetrate the protected airspace...
    local trackedGroup, trackedCluster, trackedThreatSum, trackedDistance = capInfo:GetTrackedGroup()
    if not capInfo._eval then
        local clusterSize, clusterGroups, index = self:GetClusterSize(cluster)
        capInfo._eval = {
            Clusters = { cluster },
            ThreatSum = threatSum,
            ThreatUnitCount = clusterSize,
            ThreatGroups = clusterGroups,
            Index = index
        }
    else
        local countThreats = capInfo._eval.ThreatUnitCount
        local clusterGroups = capInfo._eval.ThreatGroups
        local index = capInfo._eval.Index
        local clusterSize, clusterGroups, index = self:AddClusterSize(cluster, countThreats, clusterGroups, index)
        capInfo._eval.ThreatSum = capInfo._eval.ThreatSum + threatSum
        capInfo._eval.ThreatUnitCount = clusterSize
        capInfo._eval.ThreatGroups = clusterGroups
        capInfo._eval.Index = index
        capInfo._eval.Clusters[#capInfo._eval.Clusters+1] = cluster
    end

-- DebugIf( isFulcrum, "nisse - trackedThreatSum: " .. Dump(trackedThreatSum))

    if distance < (trackedDistance or NauticalMiles(999999)) then -- threatSum > trackedThreatSum then
        capInfo:Track(tgtGroup, cluster, threatSum, distance)
-- DebugIf( isFulcrum, "nisse - DCAF.CombatAirPatrol:EvaluateCluster :: capInfo: " .. capInfo.Name .. " :: tracks: " .. tgtGroup.GroupName)
    end

    local isLastCluster = clusterIndex == countClusters
    if isLastCluster or not capInfo:GetTrackedGroup() then return end

    local coordTGT = tgtGroup:GetCoordinate()
-- DebugIf( isFulcrum, "nisse - DCAF.CombatAirPatrol:EvaluateCluster :: highest threat: " .. tgtGroup.GroupName)

    local caps = { capInfo }
    local unitCount = capInfo:GetSize()

    local threatSize = capInfo._eval.ThreatUnitCount -- self:GetClusterSize(cluster)
    local ratio = unitCount / threatSize
Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster :: processing TGT: " .. tgtGroup.GroupName.." :: threatSize: " .. threatSize .. " :: ratio: " .. ratio)

    local function considerSupportCAP(cap)
        if capInfo == cap.CAP then
            return
        end
        local supportCAP = cap.CAP
        caps[#caps+1] = supportCAP
        unitCount = unitCount + #supportCAP.CAPGroup:GetUnits()
        ratio = unitCount / threatSize
-- Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster_findSupport :: CAP: " .. capInfo.Name .." :: adds supporting CAP: " .. supportCAP.Name .. " :: unitCount: " .. unitCount .. " :: ratio: " .. ratio)
    end

    local function findSupport()
        local availableCaps = self:SortClosestAvailableCAP(coordTGT, capInfo)
-- Debug("nisse - DCAF.CombatAirPatrol:EvaluateCluster_findSupport :: availableCaps: " .. toString(availableCaps, function(i) return i.Name end))
        for _, cap in ipairs(availableCaps) do
            considerSupportCAP(cap)
            if ratio >= capInfo.Manager.MinimumAttackRatio then return true end
        end
    end

    if ratio >= self.MinimumAttackRatio or findSupport() then
        self:ExecuteOffensiveStrategy(caps, tgtGroup, cluster)
    else
        local threat = DCAF.AirThreat:New(
            capInfo._eval.ThreatUnitCount,
            capInfo._eval.ThreatGroups,
            capInfo._eval.ThreatSum
        )
        Debug(self.Name .. " :: cannot engage cluster. CAP is numerically inferior")
        self:_onSuperiorThreat(caps, threat)
    end
    return true
end

function DCAF.CombatAirPatrol:_onSuperiorThreat(caps, threat)
    local airGroups = {}
    for _, capInfo in ipairs(caps) do
        capInfo.SuperiorThreat = threat
        capInfo:CalculateThreat()
        airGroups[#airGroups+1] = capInfo.CAPGroup
    end
    self:OnSuperiorThreat(airGroups, threat)
end

function DCAF.CombatAirPatrol:OnSuperiorThreat(airGroups, threat)
    -- NOTE -- this function is 
    for _, airGroup in ipairs(airGroups) do
-- Debug("nisse - DCAF.CombatAirPatrol:OnSuperiorThreat // scram :: airGroup: " .. DumpPretty(airGroup))
        local capinfo = GetCAPInfo(airGroup)
        delouseOrScramCAP(capinfo, threat)
    end
end

Trace("\\\\\\\\\\ DCAF.CombatAirPatrol.lua was loaded //////////")