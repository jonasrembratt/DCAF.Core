-- https://stackoverflow.com/questions/10322341/simple-algorithm-for-drawing-filled-ellipse-in-c-c
-- https://gist.github.com/bobcgausa/8649a726c846b1791b83

--[[ 

    TODO
    //////////////////////////////////////////////////////////////////////////////////////////////////
    - Test behavior for all types of radars (from SA-2 up to high digit SAMs)
    - Assert behavior for when turning Jammer ON/OFF
    - Add ability to start jamming new location ad hoc (use F10 Map Marker?)
    - How to handle jammer getting out of range?
    - Handle Bingo fuel, and orderly RTB
    - Ability to go AAR on BINGO?

    QUESTIONS/POTENTIAL ISSUES
    //////////////////////////////////////////////////////////////////////////////////////////////////
    - Seems tracking radars doesn't return value from dcsUnit:getRadar(); will dcsUnit:enableEmission(true/false) still have effect?
    - Can a jammer jam all bands at once? If so, is it equally effective on all bands?
    - How does range affect efficacy?
    - Should airborne radars inside of "lobe" also be affected, incl. friendly (player units cannot be affected though)?
    - Can lobe size be adjusted? If so, is a smaller lobe more potent than a larger?
    - Is the suppression equally effective at all ranges within the lobe, or can the emitter "burn through" and acquire targets at closer ranges?
    - We've spoken briefly about being able to suppress specified 'types'. What does that enatil, in more detail? Can specific unit types be targeted or are we talking about types in specified frequency bands?
    - Should shape of lobe be changed with altitude or range? For example, should lobe get elongated with lower altitudes?
    - You mentioned the area outside of the lobe still affects radars in range, with efficay of about 20%. What is the shape of that area?

    KNOWN ISSUES
    //////////////////////////////////////////////////////////////////////////////////////////////////
    - Groups that ENTER into the residual (20% efficacy) range does not get included in "jammed" units. Reason is because of how detection happens (needs to be rewritten)
      FIXED :: now scans the entire max range, 360 degrees around jammer -- needs to be performance tested

]]

local DCAF_Jammer_Defaults = {
    JammerRangeMax = NauticalMiles(80),
    JammerRangeMin = 0,
    JammerGrayZoneAngle = 40,            -- gray zone start at this (relative) aspect angle
    JammerBlindZoneAngle = 20,           -- blind zone start at this (relative) aspect angle
    JammerRadius = NauticalMiles(5),
    JammerResidualStrength = .2,         -- jammer's suppression strength outside lobe, but inside residual area
    JammerInterval = 10,    -- #number; this is how often the jam efficacy gets calculated 
    TrackLength = NauticalMiles(40),
}

DCAF.Jammer = {
    ClassName = "DCAF.GBAD.Jammer",
    ----
    Name = nil,             -- #string (group name)
    TTSChannel = nil,       -- (optional) #DCAF.TTSChannel
    JammerRangeMax = DCAF_Jammer_Defaults.JammerRangeMax,     -- #number; effective max range of jammer (meters)
    JammerRangeMin = 0,     -- #number; effective min range of jammer (meters)
    JammerRadius = DCAF_Jammer_Defaults.JammerRadius,           -- #number; effective radius of jammer scope (meters)
    JammerStrength = .8,    -- #number [0-1]; 0 = no jamming, 1 = full jamming strength/comnplete suppression of emittors (can be used to reflect strength of different jammer types)
    JammerResidualStrength = DCAF_Jammer_Defaults.JammerResidualStrength,
    JammerEfficacy = 0,     -- #number [0-1]; 0 = no jamming, 1 = full jamming efficacy (reflects current efficacy of jammer)
    JammerGrayZoneAngle = DCAF_Jammer_Defaults.JammerGrayZoneAngle,
    JammerBlindZoneAngle = DCAF_Jammer_Defaults.JammerBlindZoneAngle,
    JammerInterval = DCAF_Jammer_Defaults.JammerInterval,
    TargetTypes = nil,      -- #table of emitter model type names to target while jamming
    _debug_log = false,       -- when set, writes log messages to dcs.log
    _debug_messages = false,  -- whet true, posts text messages to all. Can also be set to #GROUP or #DCAF.Coalition to control message scope
    _debug_visualize = false, -- when set, draws the projected jammed region
}

local DCAF_JammingScheduler = {
    SchedulerID = nil,
    JammingPeriod = 10
}

local DCAF_RadarUnits = {
    -- dictionary (key = GROUP.Name, value = { list of #UNIT with radar })
}

local DCAF_JammedGroups = {
    --  dictionary (key = #GROUP.GroupName, value = #DCAF_JammedGroup)
}

local DCAF_JammedGroup = {
    ClassName = "DCAF_JammedGroup",
    ----
    TimeStarted = 0,        -- #number; time (seconds of day) when jamming started
    Group = nil,            -- #GROUP (the suppressed group)
    Jammers = {}            -- dictionary (key = #GROUP.GroupName, value = #DCAF.Jammer)
}

local Count_JammedGroups = 0

function DCAF_JammedGroup:NewOrUpdate(group, jammer, jammerStrength)
    local jg = DCAF_JammedGroups[group.GroupName]
    if not jg then
        jg = DCAF.clone(DCAF_JammedGroup)
        jg.Group = group
        jg.JammerStrength = jammerStrength
        Count_JammedGroups = Count_JammedGroups + 1
    end
    jg.TimeStarted = UTILS.SecondsOfToday()
    local idx = tableIndexOf(jg.Jammers, function(j) return j.Name == jammer.Name end)
    if not idx then
        jg.Jammers[#jg.Jammers+1] = jammer
        DCAF_JammingScheduler:Start()
    end
    DCAF_JammedGroups[group.GroupName] = jg
    return jg
end

local function enable(jg, value, effectiveRange, alarmStateAuto)
    if value then
        if not jg._isSuppressed then return end
    elseif jg._isSuppressed then return end
    jg._isSuppressed = not value
    jg.Group:OptionEngageRange(effectiveRange)
    if value then
        if alarmStateAuto then
            jg.Group:OptionAlarmStateAuto()
        else
            jg.Group:OptionAlarmStateRed()
        end
    else
        jg.Group:OptionAlarmStateGreen()
    end
    local dcsGroup = jg.Group:GetDCSObject()
    dcsGroup:enableEmission(value)
end

function DCAF_JammedGroup.Remove(group, jammer)
    local jg = DCAF_JammedGroups[group.GroupName]
    if not jg then
        return end

Debug("nisse - DCAF_JammedGroup.Remove :: group.GroupName: " .. group.GroupName)
    tableRemoveWhere(jg.Jammers, function(i) return i.Name == jammer.Name end)
    if #jg.Jammers == 0 then
        enable(jg, true, 100, true)
        DCAF_JammedGroups[group.GroupName] = nil
        Count_JammedGroups = Count_JammedGroups - 1
        DCAF_JammingScheduler:Stop()
        -- remove any visualization...
        local radarUnits = DCAF_RadarUnits[jg.Group.GroupName]
        for _, radarUnit in ipairs(radarUnits) do
            if radarUnit._jammedVizID then
                COORDINATE:RemoveMark(radarUnit._jammedVizID)
            end
        end
        return true
    end
end

function DCAF_JammedGroup.RemoveJammer(jammer)
    for name, jg in pairs(DCAF_JammedGroups) do
        local idx = tableIndexOf(jg.Jammers, function(j) return j.Name == jammer.Name end)
        if idx then
            DCAF_JammedGroup.Remove(jg.Group, jammer)
        end
    end
end

function DCAF_JammedGroup.IsJammed(group)
    return DCAF_JammedGroups[group.GroupName]
end

function DCAF_JammingScheduler:Start()
    if self.SchedulerID then
        return end

    local function getMaxJammerStrength(jg)
        local maxStrength = 0
        local debug_vizualize = false
        for _, jammer in pairs(jg.Jammers) do
            local strength = jammer:GetJammerStrength(jg.Group:GetCoordinate())
            if strength > maxStrength then
                maxStrength = strength
            end
            debug_vizualize = debug_vizualize or jammer._debug_visualize
        end
        return maxStrength, debug_vizualize
    end

    local function jam()
        local now = UTILS.SecondsOfToday()

        for _, jg in pairs(DCAF_JammedGroups) do
            local jammerStrength, _debug_visualize = getMaxJammerStrength(jg)
            local suppressPhase = self.JammingPeriod * jammerStrength  -- eg. strength .8 should suppress for 8/10 seconds
            local releasePhase = self.JammingPeriod - suppressPhase     -- eg. stength .8 should enable for 2/10 seconds  
            local effectiveRange = 100 - jammerStrength*100
            if not jg.JamStart then
                jg.JamStart = now
                jg.SuppressUntil = now + suppressPhase
                jg.ReleaseUntil = jg.SuppressUntil + releasePhase
                enable(jg, false, effectiveRange)
            elseif effectiveRange < jg.JammerStrength then
                -- jammer strength was decreased before jam period was up; reduce jam period
                jg.SuppressUntil = now + suppressPhase
                jg.ReleaseUntil = jg.SuppressUntil + releasePhase
            end
            -- suppress/release group in periods of 10 seconds ...
            jg.JammerStrength = effectiveRange
            if now > jg.ReleaseUntil then
                jg.SuppressUntil = now + suppressPhase
                jg.ReleaseUntil = jg.SuppressUntil + releasePhase
                enable(jg, false, effectiveRange)
            elseif now > jg.SuppressUntil then
                enable(jg, true, effectiveRange)
            end
Debug("nisse - DCAF_JammingScheduler:Start_jam :: _debug_visualize: " .. Dump(_debug_visualize))
            if _debug_visualize then
                local alpha = math.max(effectiveRange, .8)
                if not jg._isSuppressed then alpha = 0 end
                local radarUnits = DCAF_RadarUnits[jg.Group.GroupName]
                for _, radarUnit in ipairs(radarUnits) do
Debug("nisse - DCAF_JammingScheduler:Start_jam :: radarUnit: " .. radarUnit.UnitName)
                    if radarUnit._jammedVizID then
                        COORDINATE:RemoveMark(radarUnit._jammedVizID)
                    end
                    radarUnit._jammedVizID = radarUnit:GetCoordinate():CircleToAll(20, nil, {0,1,1}, alpha, {0,1,1}, alpha)
                end
            end
        end
    end

    self.SchedulerID = DCAF.startScheduler(jam, 2)
end

function DCAF_JammingScheduler:Stop()
Debug("DCAF_JammingScheduler:Stop :: Count_JammedGroups: " .. Count_JammedGroups)
    if Count_JammedGroups > 0 then return end
    DCAF.stopScheduler(self.SchedulerID)
    self.SchedulerID = nil
    Count_JammedGroups = 0
end


DCAF.JammerLobe = {
    ClassName = "JammedArea",
    ----
    _rangesAtMax = {
        { 10, 1.01517857 },
        { 20, 1.05178571 },
        { 30, 1.11071428 },
        { 40, 1.20357142 },
        { 50, 1.33928571 },
        { 60, 1.53482142 },
        { 70, 1.80892857 },
        { 75, 1.97946428 },
        { 80, 2.15714285 },
        { 85, 2.32321428 },
        { 90, 2.39017857 },
    }
}

function DCAF.JammerLobe:New()
    return DCAF.clone(DCAF.JammerLobe)
end

function DCAF.JammerLobe:GetLobeMaxCoverage(jammer, coordCenter, radius)
    local cf = self._rangesAtMax[#self._rangesAtMax][2]
    return cf * radius
end

function DCAF.JammerLobe:GetLobeCoverage(jammer, coordCenter, radial, radius)
    --jammer:_messageDebug("DCAF.JammerProjectedArea:GetCoverageFromRadial :: /////////////////////////////////////////////////////////")
    local hdg = jammer:GetCoordinate():HeadingTo(coordCenter)
    local cf -- coverage factor (this is always the radius for aligned headings 270 through 90; beyond that it is resolved from table)
    -- radial = math.round(radial)
    local radialAligned = (math.round(radial) - hdg) % 360
    if radialAligned <= 90 or radialAligned >= 270 then
        cf = 1
    else
        local radialNormalized = radialAligned % 90
        if radialAligned > 180 then
            radialNormalized = math.abs((90 - radialAligned) % 90)
        end
        --jammer:_messageDebug("DCAF.JammerProjectedArea:GetCoverageFromRadial :: radial: " .. radial .. " :: radialAligned: " .. radialAligned .. " :: radialNormalized: " .. radialNormalized)
        for _, o in ipairs(self._rangesAtMax) do
            local r = o[1]
            local value = o[2]
            --jammer:_messageDebug("DCAF.JammerProjectedArea:GetCoverageFromRadial :: [" .. r .. "] = " .. value)
            if radialNormalized <= r then
                cf = value

                -- jammer:_messageDebug("DCAF.JammerProjectedArea:GetCoverageFromRadial :: coverage: " .. cf .. " :: [" .. r .. "] = " .. value)
                break
            end
        end
    end
    local w = jammer:GetLobeRadius(radius)
    -- jammer:_messageDebug("DCAF.JammerProjectedArea:GetCoverageFromRadial :: w: " .. w .. " :: cf: " .. cf) -- r100 ==> df: 0.54965893710981 :: w: 9260 :: cf: 1.05178571
    return w * cf  -- * df
end

function DCAF.JammerLobe:GetMaxCoverage(jammer, coordCenter, radius)
    local hdg = jammer:GetCoordinate():HeadingTo(coordCenter)
    local coverage = self:GetLobeCoverage(jammer, coordCenter, hdg, radius)
    return jammer:GetCoordinate():Get2DDistance(coordCenter) + coverage
end

--- Creates and returns a new #DCAF.GBAD.Jammer
-- @param #Any group - can be a ##GROUP, or a string for group name
-- @param #DCAF.TTSChannel ttsChannel - (optional) A text-to-speech channel to be used for jammer to report status
-- @param #number strength - (optional; default = .8) The jammer strength (0-1, 0 = completely ineffective; 1 = 100% suppression)
-- @param #number radius - (optional; default = 5nm) The jammer focal projected area (the "lobe") radius
-- @param #number maxRange - (optional; default = 30nm) The maximum jamming range for this jammer
-- @param #number minRange - (optional; default = 0nm) The minimum jamming range for this jammer
function DCAF.Jammer:New(group, ttsChannel, strength, radius, maxRange, minRange)
    local validGroup = getGroup(group)
    if not validGroup then
        return Error("DCAF.Jammer:New :: `group` could not be resolved") end

    if validGroup:GetCategory() ~= Group.Category.AIRPLANE then
        return Error("DCAF.Jammer:New :: `group` must be of type airplane") end

    local this = DCAF.clone(DCAF.Jammer)
    this.Group = validGroup
    this.Name = validGroup.GroupName
    if isNumber(strength) then
        if strength < 0 or strength > 1 then
            return Error("DCAF.Jammer:New :: `strength` must be number between 0 -> 1, but was: " .. strength) end

        this.JammerStrength = strength
    end
    if isNumber(radius) then
        if radius < 0 then
            return Error("DCAF.Jammer:New :: `radius` must be positive number, but was: " .. radius) end

        this.JammerRadius = radius
    end
    this.TTSChannel = ttsChannel
    this.MaxRange = maxRange or NauticalMiles(80)
    this.MinRange = minRange or 0
    this:WithLobe(DCAF.JammerLobe:New())
    return this
end

function DCAF.Jammer:Send(message)
    if self.TTSChannel then
        self.TTSChannel:Send(message)
    end
end

function DCAF.Jammer:Debug(log, visualize, messages)
    self:DebugLog(log)
    self._debug_visualize = visualize
    if not messages then
        return self end

    if isBoolean(messages) then
        self._debug_messages = messages
    else
        self._debug_messages = Coalition.Resolve(messages) or getGroup(messages)
    end
    return self
end

function DCAF.Jammer:WithLobe(lobe)
    lobe._jammerID = self.Name
    self._lobe = lobe
    return self
end

function DCAF.Jammer:GetCoordinate() return self.Group:GetCoordinate() end

function DCAF.Jammer:GetHeading() return self.Group:GetHeading() end

function DCAF.Jammer:GetTargetAspect(locLobe)
    locLobe = locLobe or self._locLobe
    local hdg = self:GetHeading()
    local bearingToTarget = self:GetCoordinate():HeadingTo(locLobe:GetCoordinate())
    local relBearing = hdg - bearingToTarget
    return math.abs(relBearing) % 180
end

function DCAF.Jammer:_calculateTrack(locLobe, locPattern, trackLength, speedKmph)
    -- create an arc to be flown to keep aircraft's banking so pod is exposed towards target area
    local arcRadius = self.JammerRangeMax * .5
    local coordTrackCenter = locPattern:GetCoordinate(true)
    local hdg = coordTrackCenter:HeadingTo(locLobe:GetCoordinate())
    local hdgReciprocal = hdg - 180 % 360
    local coordArcCenter = coordTrackCenter:Translate(arcRadius, hdgReciprocal)
    local arcSidesAngle = UTILS.ToDegree( trackLength*.5 / arcRadius )
    local coordArcStart = coordArcCenter:Translate(arcRadius, (hdg - arcSidesAngle) % 360)
    local coordArcEnd = coordArcCenter:Translate(arcRadius, (hdg + arcSidesAngle) % 360)
    local coordsArc = getArcCoordinates(coordArcCenter, arcRadius, coordArcCenter:HeadingTo(coordArcStart), coordArcCenter:HeadingTo(coordArcEnd), 10)
    -- draw track (arc)
    if self._debug_visualize then
        for _, c in ipairs(coordsArc) do
            c:CircleToAll(500, nil, {0,0,1})
        end
    end
    local waypoints = {}
    local altitude = locPattern:GetAltitude()
    for i, coord in ipairs(coordsArc) do
        waypoints[i] = coord:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speedKmph)
        waypoints[i].alt = altitude
    end
    return waypoints
end

function DCAF.Jammer:_visualize(radius, coordLobe, strength)
    if not self._debug_visualize then
        return end

    self:_visualize_remove()
    local maxRange = self._lobe:GetMaxCoverage(self, coordLobe, radius)
    local coordOwn = self:GetCoordinate()
    local hdgLobe = coordOwn:HeadingTo(coordLobe)
    local hdgBlindZoneLeft = (hdgLobe - 90 + self.JammerBlindZoneAngle) % 360
    local hdgBlindZoneRight = (hdgLobe + 90 - self.JammerBlindZoneAngle) % 360
Debug("nisse - DCAF.Jammer:_visualize :: hdgLobe: " .. hdgLobe .. " :: hdgBlindZoneLeft: " .. hdgBlindZoneLeft .. " :: hdgBlindZoneRight: " .. hdgBlindZoneRight)
    local coordsArc = getArcCoordinates(coordOwn, maxRange, hdgBlindZoneLeft, hdgBlindZoneRight)
    self._maxRangeID = coordOwn:MarkupToAllFreeForm(coordsArc, nil, {0,1,1}, 1, {0,1,1}, .15, 0)
    local inc = 5

    local coordsLobe = {}
    local coverage = self._lobe:GetLobeCoverage(self, coordLobe, inc, radius)
    local coord1 = coordLobe:Translate(coverage, inc)
    coordsLobe[#coordsLobe+1] = coord1
    for radial = inc+inc, 360, inc do
        coverage = self._lobe:GetLobeCoverage(self, coordLobe, radial, radius)
        local coord = coordLobe:Translate(coverage, radial)
        coordsLobe[#coordsLobe+1] = coord
    end
    self._lobeID = coord1:MarkupToAllFreeForm(coordsLobe, nil, {0,1,1}, strength, {0,0,0}, 0, 3)
end

function DCAF.Jammer:_visualize_remove()
    if self._maxRangeID then
        COORDINATE:RemoveMark(self._maxRangeID)
    end
    if self._lobeID then
        COORDINATE:RemoveMark(self._lobeID)
        self._lobeID = nil
    end
    -- if self._lobeTextIDs then
    --     for _, id in ipairs(self._lobeTextIDs) do
    --         COORDINATE:RemoveMark(id)
    --     end
    -- end
end

local function hasRadar(group)
    local radarUnits = DCAF_RadarUnits[group.GroupName]
    if radarUnits then
        if #radarUnits then
            return radarUnits end
        return
    end

    radarUnits = {}
    local units = group:GetUnits()
    for _, unit in ipairs(units) do
        local typeName = unit:GetTypeName()
        local info = DCAF_GBADDatabase[typeName]
Debug("nisse - hasRadar :: info: " .. DumpPretty(info))
        if info and info:IsRadar() then
            radarUnits[#radarUnits+1] = unit
        end
    end
Debug("nisse - hasRadar :: group: " .. group.GroupName .. " :: radarUnits: " .. DumpPretty(radarUnits))
    DCAF_RadarUnits[group.GroupName] = radarUnits
    if #radarUnits > 0 then
        return radarUnits end
end

function DCAF.Jammer:_jam(locLobe, radius, bands)
    self:_messageDebug("nisse - _jam ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::")
    local coordOwn = self.Group:GetCoordinate()
    local coordLobe = locLobe:GetCoordinate()
    local now = UTILS.SecondsOfToday()

    self:_visualize(radius, coordLobe, self:GetJammerStrength(locLobe:GetCoordinate()))

    local function suppress(group, effectiveStrength)
        DCAF_JammedGroup:NewOrUpdate(group, self, effectiveStrength)
        local effectiveRange = 100 - effectiveStrength*100
        self:OnGroupSuppressed(group, effectiveRange)
        self:_messageDebug("Group is suppressed: " .. group.GroupName .. " :: e-strength: " .. effectiveStrength .. " :: e-range: " .. effectiveRange .. "%")
    end

    local function unsuppress(group)
        if not DCAF_JammedGroup.Remove(group, self) then
            return end

        -- no jammers suppressing...
        group:OptionEngageRange(100)
        self:_messageDebug("Group is no longer suppressed: " .. group.GroupName)
        if self._debug_visualize then
            local radarUnits = DCAF_RadarUnits[group.GroupName]
            if radarUnits then
                for _, radarUnit in ipairs(radarUnits) do
                    if radarUnit._jammedVizID then
                        COORDINATE:RemoveMark(radarUnit._jammedVizID)
                    end
                end
            end
        end
        self:OnGroupReleased(group)
    end

    -- returns nil if no radar at all (should not be consolidated), 1 if inside of jammed area, or 0 otherwise
    local function consolidate(group)
        local radarUnits = hasRadar(group)
        if not radarUnits then return end
        local strength = self:GetJammerStrength(group:GetCoordinate())
        if strength > 0 then
            suppress(group, strength)
        else
            unsuppress(group)
        end
    end

    local maxRadialCoverage = self.JammerRangeMax
    local coordOwn = self:GetCoordinate()
    coordOwn:ScanUnits(maxRadialCoverage):ForEachUnit(function(unit)
        -- local maxRadialCoverage = self._lobe:GetLobeMaxCoverage(self, coordLobe, radius)
    -- coordLobe:ScanUnits(maxRadialCoverage):ForEachUnit(function(unit)
        if not unit:IsAlive() or not unit:IsActive() then return end
        local group = unit:GetGroup()
        if group._jammer_last_scan == now then
            return end

        group._jammer_last_scan = now
        consolidate(group)
    end)
end

--- Starts jamming a location
-- @param #Any locLobe - #DCAF.Location or #COORDINATE; The location of targets to be jammed
-- @param #number bearing - A bearing from target where jammer should be located (center of jamming track). If `nil` is passed the bearing will be the one from target to jammer's current location
-- @param #number distance - A distance from target where jammer should be located (center of jamming track). If `nil` is passed the bearing will be set to allow maximum jammer range
-- @param #number radius - (optional; default = 5nm) The jammer focal projected area ("lobe") radius
-- @param #number trackAltitude - (optional; default=25000) The altitude of the jamming track (meters, MSL)
-- @param #number trackLength - (optional; default=40nm) The length of the jamming track (meters)
-- @param #number speedKt - (optional) Specifies speed (knots) to be used for flying the jamming pattern
-- @param #number startsFromLeft - (optional; default=false) Specifies whether jammer should start flying the pattern from left-to-right
-- @param #table types - (optional) A list of one or more emitter types to be jammed
function DCAF.Jammer:JamLocation(locLobe, bearing, distance, radius, trackAltitude, trackLength, speedKt, startsFromLeft, types)
    if not self.Group:IsAlive() or not self.Group:IsActive() then
        return Error("DCAF.Jammer:JamLocation :: jammer ("..self.Name..") is not alive/active") end

    local validLocECM = DCAF.Location.Resolve(locLobe)
    if not validLocECM then
        return Error("DCAF.Jammer:JamLocation :: `locLobe` could not be resolved") end
    locLobe = validLocECM

    local coordLobe = locLobe:GetCoordinate()
    if not isNumber(bearing) then
        bearing = coordLobe:HeadingTo(self.Group:GetCoordinate())
    end
    if isNumber(distance) then
        if distance > self.JammerRangeMax then
            return Warning("DCAF.Jammer:JamLocation :: the distance between pattern location and target location (" .. UTILS.MetersToNM(distance) .. ") exceeds the jammer max range (" .. UTILS.MetersToNM(self.JammerRangeMax) .. ")") end
    else
        distance = self.JammerRangeMax - NauticalMiles(2) -- todo adjust for possible change to 'effective jam zone'
    end
    local locPattern = coordLobe:Translate(distance, bearing)
    return self:JamFromTrack(locLobe, locPattern, radius, trackAltitude, trackLength, speedKt, startsFromLeft, types)
end

--- Flies a track at a specified location while jamming a location
-- @param #Any locLobe - #DCAF.Location or #COORDINATE; The location of targets to be jammed
-- @param #Any locTrack - #DCAF.Location or #COORDINATE; The location of the track
-- @param #number trackAltitude - (optional; default=<current altitude>) The altitude of the jamming track (meters, MSL)
-- @param #number trackLength - (optional; default=40nm) The length of the jamming track (meters)
-- @param #number speedKt - (optional; default=<current speed>) Specifies speed (knots) to be used for flying the jamming pattern
-- @param #number radius - (optional; default = 5nm) The jammer focal projected area ("lobe") radius
-- @param #number startsFromLeft - (optional; default=false) Specifies whether jammer should start flying the pattern from left-to-right
-- @param #table types - (optional) A list of one or more emitter types to be jammed
function DCAF.Jammer:JamFromTrack(locLobe, locTrack, trackAltitude, trackLength, speedKt, radius, startsFromLeft, types)
    local validLocECM = DCAF.Location.Resolve(locLobe)
    if not validLocECM then
        return Error("DCAF.Jammer:JamFromTrack :: `locLobe` could not be resolved") end
    locLobe = validLocECM

    local validLocTrack = DCAF.Location.Resolve(locTrack)
    if not validLocTrack then
        return Error("DCAF.Jammer:JamFromTrack :: `locTrack` could not be resolved") end
    locTrack = validLocTrack
    local dtt = locLobe:GetCoordinate():Get2DDistance(locTrack:GetCoordinate())
    if dtt > self.JammerRangeMax then
        return Warning("DCAF.Jammer:JamFromTrack :: the distance between pattern location and ECM location (" .. UTILS.MetersToNM(dtt) .. ") exceeds the jammer max range (" .. UTILS.MetersToNM(self.JammerRangeMax) .. ")") end

    radius = self:GetLobeRadius(radius)
    self._locLobe = locLobe
    self._radiusECM = radius

    if not isNumber(speedKt) then
        speedKt = self.Group:GetVelocityKNOTS()
    end
    if not isBoolean(startsFromLeft) then
        startsFromLeft = false
    end

    if isNumber(trackAltitude) then
        locTrack:SetAltitude(trackAltitude, true)
    else
        locTrack:SetAltitude(self.Group:GetAltitude(false), true)
    end
    if not isNumber(trackLength) then
        trackLength = DCAF_Jammer_Defaults.TrackLength
    end

    local speedKmph = UTILS.MpsToKmph(UTILS.KnotsToMps(speedKt))
    local waypoints = self:_calculateTrack(validLocECM, locTrack, trackLength, speedKmph)
    if startsFromLeft then
        waypoints = listReverse(waypoints)
    end
    local group = self.Group
    local jammer = self
    for i = 1, #waypoints, 1 do
        WaypointCallback(waypoints[i], function()
            if not jammer._isJammerStopped then
                jammer:StartJammer(locLobe, radius, types)
            end
        end, false)
    end
    WaypointCallback(waypoints[#waypoints], function()
        waypoints = listReverse(waypoints)
        local callbackTask = waypoints[1].task.params.tasks[2]
        waypoints[1].task.params.tasks[2] = nil
        waypoints[#waypoints].task.params.tasks[2] = callbackTask
        group:Route(waypoints)
    end, false)
    self.Group:Route(waypoints)
    return self
end

function DCAF.Jammer:OnStartJammer(locLobe, radius, types)
    return self
end

function DCAF.Jammer:OnStopJammer(locLobe, radius, types)
    return self
end

function DCAF.Jammer:OnGroupSuppressed(unit, effectiveRange)
    return self
end

function DCAF.Jammer:OnGroupReleased(unit)
    return self
end

function DCAF.Jammer:IsJamming()
    return self._jammerScheduleID ~= nil
end

function DCAF.Jammer:StartJammer(locLobe, radius, delay, types)
Debug("nisse - DCAF.Jammer:StartJammer...")
    if self._jammerScheduleID then
        return self end

    if locLobe then
        local validLocECM = DCAF.Location.Resolve(locLobe)
        if not validLocECM then
            return Error("DCAF.Jammer:JamLocation :: `locLobe` could not be resolved") end
        locLobe = validLocECM
        self._locLobe = locLobe
    elseif not self._locLobe then
        return Error("DCAF.Jammer:StartJammer :: no location specified")
    end

    radius = self:GetLobeRadius(radius)
    self.JammerEfficacy = 1
    local jammer = self
    delay = delay or 0
    DCAF.delay(function()
        jammer._jammerScheduleID = DCAF.startScheduler(function()
            jammer._isJammerStopped = nil
            jammer:_jam(jammer._locLobe, radius, types)
        end, jammer.JammerInterval, 0)
        jammer:OnStartJammer(jammer._locLobe, radius, types)
        jammer:_messageDebug("starts jamming")
    end, delay)
    return self
end

function DCAF.Jammer:GetLobeRadius(radius)
    if isNumber(radius) then
        return radius end

    return self.JammerRadius or DCAF_Jammer_Defaults.JammerRadius
end

function DCAF.Jammer:StopJammer(delay)
    if not self._jammerScheduleID or self._isJammerStopped then
        return self end

    delay = delay or 0
    self.JammerEfficacy = 0
    local jammer = self
    DCAF.delay(function()
        jammer:_messageDebug("stops jamming")
        DCAF.stopScheduler(jammer._jammerScheduleID)
        jammer._jammerScheduleID = nil
        DCAF_JammedGroup.RemoveJammer(jammer)
        jammer._isJammerStopped = true
        jammer:OnStopJammer()
        jammer:_visualize_remove()
    end, delay)
end

function DCAF.Jammer:GetJammerStrength(group, locLobe)
    -- note - this is a great place to apply more realistic jammer efficiency calculations
    local coordJammer = self:GetCoordinate()
    if not coordJammer then
        return 0 end

    local distance = coordJammer:Get2DDistance(group:GetCoordinate())
    locLobe = locLobe or self._locLobe
    local coordLobe = locLobe:GetCoordinate()
    local maxRange = self._lobe:GetMaxCoverage(self, coordLobe, radius)
    if distance > maxRange then
        return 0
    end

    -- check whether group is inside lobe...
    if locLobe and group then
        local coordGroup = group:GetCoordinate()
        local lobeCoverage = self._lobe:GetLobeCoverage(self, coordLobe, coordLobe:HeadingTo(coordGroup))
        distance = coordLobe:Get2DDistance(coordGroup)
        if distance < lobeCoverage then
            -- group is inside lobe...
            return self.JammerStrength * self.JammerEfficacy
        end
    end

    local aspect = self:GetTargetAspect(locLobe or self._locLobe)
    local grayZoneStart = self.JammerGrayZoneAngle
    local blindZoneStart = self.JammerBlindZoneAngle

    -- residual area; manage gray/blind zone...
    if aspect < 90 then
        if aspect < blindZoneStart then
            return 0
        end
        if aspect > grayZoneStart then
            return self.JammerStrength * self.JammerEfficacy * self.JammerResidualStrength
        end
    else
        if aspect > 180-blindZoneStart then
            return 0
        end
        if aspect < 180-grayZoneStart then
            return self.JammerStrength * self.JammerEfficacy * self.JammerResidualStrength
        end
    end
    local grayZone = blindZoneStart - grayZoneStart
    local normAspect = aspect - grayZoneStart
    local grayZoneFactor = normAspect / grayZone
    return grayZoneFactor * self.JammerResidualStrength
end

function DCAF.Jammer:DebugLog(value)
    self._debug_log = value
    return self
end

function DCAF.Jammer:_messageDebug(message)
    if self._debug_log then
        Debug("DCAF.Jammer :: " .. self.Name .. " :: " .. message)
    end
    if not self._debug_messages then return end
    local scope = nil
    if not isBoolean(self._debug_messages) then
        scope = self._debug_messages
    end
    MessageTo(scope, "DCAF.Jammer :: " .. self.Name .. " :: " .. message)
end