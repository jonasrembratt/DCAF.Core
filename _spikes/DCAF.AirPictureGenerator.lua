-- 10nm - 40nm between groups inside a 'package'
-- TODO
--   

DCAF.BvrForms = {
    Single = "Single", -- rename -> "Single Light"
    TwoGroups = "Two groups",           -- two groups azimuth / range
    -- note; adding more forms might require additional #DCAF_BvrFormDelegates
    Wall = "Wall",
    Vic = "Vic",
    Box = "Box",
    Champagne = "Champagne",
    Stack = "Stack",
    Ladder = "Ladder",
    -- Gorilla = "Gorilla"  -- a large bunch of generally disorganized groups
}

DCAF.BvrBehavior = {
    HoldFire = "Hold fire",
    AttackTarget = "Attack target",
    AttackInZone = "Attack in zone"
}

local kvIntensityMedium = KeyValue:New(3, AircraftAltitude.Medium)
local DCAF_IntensityValues = {
    VeryLow = KeyValue:New(1, AircraftAltitude.VeryLow),
    Low = KeyValue:New(2, AircraftAltitude.Low),
    Medium = kvIntensityMedium,
    High = KeyValue:New(4, AircraftAltitude.High),
    VeryHigh = KeyValue:New(5, AircraftAltitude.VeryHigh)
}

local DCAF_BVR_Distances = {
    KeyValue:New("20 nm", NauticalMiles(20)),
    KeyValue:New("30 nm", NauticalMiles(30)),
    KeyValue:New("40 nm", NauticalMiles(40)),
    KeyValue:New("50 nm", NauticalMiles(50)),
    KeyValue:New("60 nm", NauticalMiles(60)),
    KeyValue:New("80 nm", NauticalMiles(80)),
    KeyValue:New("100 nm", NauticalMiles(100)),
}

local kvAltitudePopup = KeyValue:New("Popup", 0)
local kvAltitudeVeryHigh = KeyValue:New(AircraftAltitude.VeryHigh, 35000)
local DCAF_BVR_Altitudes = {
    kvAltitudePopup,
    KeyValue:New(AircraftAltitude.Low, 8000),
    KeyValue:New(AircraftAltitude.Medium, 15000),
    KeyValue:New(AircraftAltitude.High, 25000),
    kvAltitudeVeryHigh
}

local kvLifetimeIndefinite = KeyValue:New("Indefinite", -1)
local DCAF_BVR_Lifetime = {
    kvLifetimeIndefinite,
    KeyValue:New("1 minute", Minutes(1)),
    KeyValue:New("3 minutes", Minutes(3)),
    KeyValue:New("5 minutes", Minutes(5)),
}

DCAF.AirPictureSettings = {
    ClassName = "DCAF.AirPictureSettings",
    RequiresTarget = true,      -- true = no hostile picture generated unless (friendly) targets can be resolved
    Intensity = kvIntensityMedium,
    Forms = {
        KeyValue:New(DCAF.BvrForms.Single, true),      -- light / heavy
        KeyValue:New(DCAF.BvrForms.TwoGroups, true),   -- range / azimuth
        KeyValue:New(DCAF.BvrForms.Wall, true),
        KeyValue:New(DCAF.BvrForms.Box, true),
        KeyValue:New(DCAF.BvrForms.Vic, true),
        KeyValue:New(DCAF.BvrForms.Champagne, true),
        KeyValue:New(DCAF.BvrForms.Ladder, true),
        KeyValue:New(DCAF.BvrForms.Stack, true),
    },
    Distance = {
        Min = NauticalMiles(60),
        Max = NauticalMiles(80)
    },
    Altitude = {
        Min = kvAltitudePopup,
        Max = kvAltitudeVeryHigh
    },
    GroupSize = {
        Min = 1,
        Max = 4
    },
    Behavior = DCAF.BvrBehavior.AttackTarget,
    Lifetime = kvLifetimeIndefinite
}

DCAF.FighterGroupFactory = {
    ClassName = "DCAF.FighterGroupFactory",
    Name = nil,                 -- #string - (display) name of group
    GroupName = nil,            -- #string - name of GROUP (template)
    Category = nil,             -- #string - fighter generation, western/eastern, whatever...
}

local function getIntensityFromKey(key)
    for _, kv in pairs(DCAF_IntensityValues) do
        if key == kv.Key then
            return kv end
    end
end

-- function DCAF_IntensityValues.GetForKey(key)
--     for _, kv in pairs(DCAF_IntensityValues) do
--         if key == kv.Key then
--             return kv end
--     end
-- end

function DCAF.FighterGroupFactory:New(name, groupName, category)
    if not isAssignedString(name) then
        error("DCAF.FighterGroupFactory:New :: `name` must be assigned string, but was: " .. DumpPretty(name)) end
    if not isAssignedString(groupName) then
        error("DCAF.FighterGroupFactory:New :: `groupName` must be assigned string, but was: " .. DumpPretty(groupName)) end
    if category ~= nil and not isAssignedString(category) then
        error("DCAF.FighterGroupFactory:New :: `category` must be assigned string, but was: " .. DumpPretty(category)) end
    
    local fg = DCAF.clone(DCAF.FighterGroupFactory)
    fg.Name = name
    fg.GroupName = groupName
    fg.Category = category
    return fg
end

function DCAF.FighterGroupFactory:WithSelectGroupFunc(func, arg)
    self.GroupSelectFunc = func
    self.GroupSelectArg = arg
    return self
end

function DCAF.FighterGroupFactory:Select()
    if self.GroupSelectFunc then
        return self.GroupSelectFunc(self.GroupSelectArg)
    end
    return self.GroupName
end

local DCAF_NewGroupInfo = {
    ClassName = "DCAF_NewGroupInfo",
    SpawnLocation = nil,        -- #DCAF.Location
    TargetLocation = nil,       -- #DCAF.Location
    Altitude = nil,             -- #number - feet
    Form = nil,                 -- #string - see #DCAF.BvrForms
    GroupName = nil,            -- #string - group template name
    -- these values controls intensity...
    MaxGroupSize = nil,         -- #number - max size of generated groups
    MaxGroupCount = nil,        -- #number - max number of generated groups
    GenerateInterval = nil      -- #number - (seconds) interval between generations
}

local DCAF_AirPictureGenerator_count = 0
DCAF.AirPictureGenerator = {
    ClassName = "DCAF.AirPictureGenerator",
    IsPaused = false,
    Name = nil,
    Settings = nil,             -- #DCAF.AirPictureSettings:New(),
    SpawnLocations = nil,
    Groups = {
        -- list of spawned #GROUP
    },
}

local function spawnGroup(generator, info, count, locTarget, coordinate, altitude, skill)
    local template = info.GroupFactory:Select()
    local spawn = getSpawn(template)
    if not spawn then
        return Warning("Cannot generate pair from '" .. template .. "'. Group was not found in mission") end

    coordinate:SetAltitude(Feet(altitude))
    locTarget = locTarget or info.TargetLocation
    local heading = coordinate:HeadingTo(locTarget:GetCoordinate())
    if not count then
        count = math.random(generator.Settings.GroupSize.Min, generator.Settings.GroupSize.Max)
    end
    spawn:InitGroupHeading(heading)
         :InitGrouping(count)

    local group = spawn:SpawnFromCoordinate(coordinate)
    table.insert(generator.Groups, group)
    -- local units = group:GetUnits() obsolete
    -- local units = group:GetUnits()
    -- for i = #units, count+1, -1 do
    --     local unit = units[i]
    --     unit:Destroy()
    -- end
    return group
end

local function getRandomAngelsDiff(maxDiff)
    local altDiff = math.random(0, maxDiff) -- in thousands of feet
    if math.random(100) < 51 then
        altDiff = -altDiff 
    end
    return altDiff
end

local function formNone(generator, info, group, groupSize, skill)
    return { group }
end

local function spawnOffsetFromGroup(generator, info, group, distance, offsetAngle, altitudeDiff, groupSize, skill)
    local coord = group:GetCoordinate()
    offsetAngle = (info.Heading + offsetAngle) % 360
    distance = distance or NauticalMiles(math.random(10, 25))
Debug("spawnOffsetFromGroup :: hdg: " .. Dump(info.Heading) .. " :: offsetAngle: " .. Dump(offsetAngle) .. " :: distance: " .. Dump(distance))
    local coordSpawn = coord:Translate(distance, offsetAngle)
    if not groupSize then
        groupSize = math.random(2, info.MaxGroupSize or #group:GetUnits())
    end
    altitudeDiff = altitudeDiff or getRandomAngelsDiff()*1000
    local altitude = UTILS.MetersToFeet(coord.y) + altitudeDiff or getRandomAngelsDiff() * 1000
    return spawnGroup(generator, info, groupSize, info.TargetLocation, coordSpawn, altitude, skill)
end

local function formSingle(generator, info, group, distance, skill)
    return formNone(generator, info, group)
end

local function formTwoGroups(generator, info, group, distance, altitudeDiff, groupSize, skill)
    local groups = { group }
    if math.random(100) < 51 then
        table.insert(groups, spawnOffsetFromGroup(generator, info, group, distance, 90, altitudeDiff, groupSize, skill))
    else
        table.insert(groups, spawnOffsetFromGroup(generator, info, group, distance, 180, altitudeDiff, groupSize, skill))
    end
    return groups
end

local function formOnAxis(generator, info, group, axisHeading, groupSize, skill, groupCount, bothDirections, distance, debug_prefix)
    if info.MaxGroupCount < 2 then
        return formNone(generator, info, group, groupSize, skill) end

    if not groupSize then
        groupSize = math.random(2, info.MaxGroupSize or #group:GetUnits())
    end
    local groupCount  = groupCount or math.random(2, info.MaxGroupCount or math.max(2, 5))
    local coordMiddle = group:GetCoordinate()
    distance = distance or NauticalMiles(math.random(10, 25))

-- group._nisse_id = "middle"

    local groups = { group } -- always make 'group' the middle group
    for i = 1, groupCount, 1 do
        local coord = coordMiddle:Translate(distance, axisHeading)
        local altDiff = getRandomAngelsDiff() -- in thousands of feet
        local altitude = info.Altitude + altDiff * 1000
        local group = spawnGroup(generator, info, groupSize, info.TargetLocation, coord, altitude, skill)

-- group._nisse_id = "#"..Dump(i) .. "_" .. Dump(debug_prefix)
-- Debug("nisse - formOnAxis :: _nisse_id: " .. group._nisse_id)

        table.insert(groups, group)
        if i % 2 == 0 then
            -- double distance to next group, form middle group
            distance = distance * 2
        end
        if bothDirections then
            axisHeading = ReciprocalAngle(axisHeading)
        end
    end
    return groups        
end

local function formWall(generator, info, group, groupSize, skill, groupCount)
    local coordMiddle = group:GetCoordinate()
    local hdg = coordMiddle:HeadingTo(info.TargetLocation:GetCoordinate())
    local hdgPerpendicular = (hdg + 90) % 360
    groupCount = groupCount or math.random(3, 5)
    return formOnAxis(generator, info, group, hdgPerpendicular, groupSize, skill, groupCount, true)
end

local function formLadder(generator, info, group, groupSize, skill, groupCount)
    local coordMiddle = group:GetCoordinate()
    local hdg = coordMiddle:HeadingTo(info.TargetLocation:GetCoordinate())
    groupCount = groupCount or math.random(3, 5)
    return formOnAxis(generator, info, group, ReciprocalAngle(hdg), groupSize, skill, groupCount, false)
end

local function formChampagne(generator, info, group, altitudeDiff, groupSize, skill)
    if info.MaxGroupCount < 3 then
        -- not enough groups for a Champagne - use simpler form...
        return formTwoGroups(generator, info, group, nil, nil, groupSize, skill)
    end
    local distance = NauticalMiles(math.random(10, 20))
    local groupFlank = spawnOffsetFromGroup(generator, info, group, distance, 90, nil, groupSize, skill)
    local groupRear = spawnOffsetFromGroup(generator, info, group, distance, 130, nil, groupSize, skill)
    return { group, groupFlank, groupRear }
end

local function formVic(generator, info, group, groupSize, skill)
    if info.MaxGroupCount < 3 then
        -- not enough groups for a Vic - use simpler form...
        return formTwoGroups(generator, info, group, nil, nil, groupSize, skill)
    end
    local distance = NauticalMiles(math.random(10, 20))
    local groupRight = spawnOffsetFromGroup(generator, info, group, distance, 130, nil, groupSize, skill)
    local groupLeft = spawnOffsetFromGroup(generator, info, group, distance, 230, nil, groupSize, skill)
    return { group, groupRight, groupLeft }
end

local function formBox(generator, info, group, altitudeDiff, groupSize, skill)
    if info.MaxGroupCount < 2 then
        return formSingle(generator, info, group, nil, nil, skill)
    elseif info.MaxGroupCount < 3 then
        -- not enough groups for a Vic - use simpler form...
        return formTwoGroups(generator, info, group, nil, altitudeDiff, groupSize, skill)       
    elseif info.MaxGroupCount < 4 then
        if math.random(100) < 51 then
            return formChampagne(generator, info, group, altitudeDiff, groupSize, skill)
        else
            return formVic(generator, info, group, groupSize, skill)
        end
    end
    local distance = NauticalMiles(math.random(10, 20))
    altitudeDiff = altitudeDiff or getRandomAngelsDiff() * 1000
    local groupRight = spawnOffsetFromGroup(generator, info, group, distance, 90, altitudeDiff, groupSize, skill)
    local groupLeftRear = spawnOffsetFromGroup(generator, info, group, distance, 180, altitudeDiff, groupSize, skill)
    local groupRightRear = spawnOffsetFromGroup(generator, info, groupRight, distance, 180, altitudeDiff, groupSize, skill)
    return { group, groupRight, groupLeftRear, groupRightRear }
end

local function formStack(generator, info, group, groupSize, skill, groupCount)
    -- build stack from bottom-up (group = lowest group)...
    if info.MaxGroupCount < 2 then
        -- not enough groups for a Stack - use simpler form...
        return formSingle(generator, info, group, groupSize, skill)
    end

    if not groupSize then
        groupSize = math.random(1, info.MaxGroupSize or #group:GetUnits())
    end
    groupCount = groupCount or math.random(2, info.MaxGroupCount or math.max(2, 5))
    local coord = group:GetCoordinate()
    local hardDeck = coord:GetLandHeight() + Feet(200)
    local minAltitude = generator.Settings.AircraftAltitude.Min.Value
    local maxAltitude = generator.Settings.AircraftAltitude.Max.Value
    local stackHeight = maxAltitude - minAltitude
    local orgSeparation = stackHeight / groupCount
    local orgAltitude = UTILS.MetersToFeet(group:GetAltitude())
-- Debug("nisse - formStack :: stackHeight: " .. Dump(stackHeight) .. " :: orgSeparation: " ..Dump(orgSeparation) .. " :: orgAltitude: " .. Dump(orgAltitude))
    local separation = orgSeparation
    local bothDirections = true
    local groups = { group } -- build from `group`...
    for i = 1, groupCount, 1 do
        local altitude
        if bothDirections then
            if i % 2 == 0 then
                altitude = orgAltitude + separation
                if altitude > maxAltitude then
                    altitude = orgAltitude - separation
                    bothDirections = false
                end
            else
                altitude = orgAltitude - separation
                if altitude < hardDeck then
                    altitude = orgAltitude + separation
                    bothDirections = false
                else
                    separation = separation * 2
                end
            end
        else
            altitude = orgAltitude + separation
            separation = separation + orgSeparation
        end
        if altitude >= minAltitude and altitude <= maxAltitude then
-- Debug("nisse - formStack :: separation: " .. Dump(separation) .. " :: altitude: " ..Dump(altitude) .. " :: bothDirections: " .. Dump(bothDirections))
            local group = spawnGroup(generator, info, groupSize, info.TargetLocation, coord, altitude, skill)
            table.insert(groups, group)
        else
            break
        end
    end
    return groups        
end

local DCAF_DefaultBvrFormDelegate = "(default)"
local DCAF_BvrFormDelegates = {
    [DCAF_DefaultBvrFormDelegate] = formNone,
    [DCAF.BvrForms.Single] = formSingle,
    [DCAF.BvrForms.TwoGroups] = formTwoGroups,
    [DCAF.BvrForms.Wall] = formWall,
    [DCAF.BvrForms.Stack] = formStack,   
    [DCAF.BvrForms.Box] = formBox,   
    [DCAF.BvrForms.Ladder] = formLadder,
    [DCAF.BvrForms.Champagne] = formChampagne,
    [DCAF.BvrForms.Vic] = formVic,
}

function DCAF.AirPictureSettings:New()
    local settings = DCAF.clone(DCAF.AirPictureSettings)
    return settings
end

function DCAF.AirPictureSettings:SetRequiresTarget(value)
    if not isBoolean(value) then
        error("DCAF.AirPictureSettings:SetRequiresTarget :: `value` must be boolean, but was: " .. DumpPretty(value)) end

    self.RequiresTarget = value
    return self
end

function DCAF.AirPictureSettings:SetMinDistance(value)
    self.Distance.Min = math.max(0, value)
    if self.Distance.Min > self.Distance.Max then
        self.Distance.Max = self.Distance.Min
    end
    return self
end

function DCAF.AirPictureSettings:SetMaxDistance(value)
    self.Distance.Max = math.max(1, value)
    if self.Distance.Max < self.Distance.Min then
        self.Distance.Min = self.Distance.Max
    end
    return self
end

function DCAF.AirPictureSettings:GetEnabledForms()
    if self._enabledForms then
        return self._enabledForms end

    local enabledForms = {}
    for _, kv in ipairs(self.Forms) do
        if kv.Value then
            table.insert(enabledForms.kv.Key)
        end
    end
    self._enabledForms = enabledForms
    return enabledForms
end

function DCAF.AirPictureSettings:ToggleForm(keyValue)
    keyValue.Value = not keyValue.Value
    self._enabledForms = nil
end

function DCAF.AirPictureGenerator:New(name, forCoalition, settings)
    if settings == nil then
        settings = DCAF.AirPictureSettings:New()
    elseif not isClass(settings, DCAF.AirPictureSettings.ClassName) then
        error("DCAF.AirPictureGenerator:New :: `setting`must be #" .. DCAF.AirPictureGenerator.ClassName .. ", but was: " .. DumpPretty(settings)) 
    end
    local generator = DCAF.clone(DCAF.AirPictureGenerator)
    if not forCoalition then
        forCoalition = Coalition.Blue
    end
    generator._coalition = Coalition.Resolve(forCoalition, true)
    generator._hostileCoalition = GetHostileCoalition(generator._coalition)
    DCAF_AirPictureGenerator_count = DCAF_AirPictureGenerator_count + 1
    if isAssignedString(name) then
        generator.Name = name
    else
        generator.Name = DCAF.AirPictureGenerator.ClassName .. "#" .. Dump(DCAF_AirPictureGenerator_count)
    end
    generator.Settings = settings
    return generator
end

local function validateLocations(locations, msgPrefix)
    if not isList(locations) then
        error(msgPrefix .. " :: `locations` must be a list, but was: " .. type(locations)) end

    local validLocations = {}
    for i, l in ipairs(locations) do
        local validLocation = DCAF.Location.Resolve(l)
        if not validLocation then
            error(msgPrefix .. " :: unexpected location for #" .. Dump(i) .. ": " .. DumpPretty(l)) end

        table.insert(validLocations, validLocation)
    end
    return validLocations
end

function DCAF.AirPictureGenerator:WithTargetLocations(locations)
    self.TargetLocations = validateLocations(locations)
    return self 
end

function DCAF.AirPictureGenerator:WithSpawnLocations(locations)
    self.SpawnLocations = validateLocations(locations)
    return self 
end

function DCAF.AirPictureGenerator:WithGroups(groups)
    local list = {}
    for i, fg in ipairs(groups) do
        if not isClass(fg, DCAF.FighterGroupFactory.ClassName) then
            error("DCAF.AirPictureGenerator:WithGroups :: group #" .. Dump(i) .. " was not #" .. DCAF.FighterGroupFactory.ClassName .. " :: was instead: " .. DumpPretty(fg))
        end
        table.insert(list, fg)
    end
    self.GroupTemplates = list
    return self
end

local function resetIntensity(generator)
    generator._lastGeneration = nil
    generator._tempoIntensity = nil
    generator._nextRaiseIntensity = nil    
    generator._raiseIntensityInterval = nil
end

function DCAF.AirPictureGenerator:GetIntensity()
    local kv = self._tempoIntensity or self.Settings.Intensity
    if not self._tempoIntensity then
Debug("nisse - DCAF.AirPictureGenerator:GetIntensity :: (no tempo intensity) :: kv: " .. DumpPretty(kv))
        return kv.Value, kv.Key end

    local now = UTILS.SecondsOfToday()
    if now < self._nextRaiseIntensity then
Debug("nisse - DCAF.AirPictureGenerator:GetIntensity :: (tempo intensity not yet raised) :: kv: " .. DumpPretty(kv))
        return kv.Value, kv.Key end
    
    local key = math.min(self._tempoIntensity.Key + 1, self.Settings.Intensity.Key)
    if key == self.Settings.Intensity.Key then
        -- intensity was restored...
        resetIntensity(self)
        kv = self.Settings.Intensity
Debug("nisse - DCAF.AirPictureGenerator:GetIntensity :: (restores intensity to setting :: kv: " .. DumpPretty(kv))
        return kv.Value, kv.Key
    end
    self._nextRaiseIntensity = now + self._raiseIntensityInterval
Debug("nisse - DCAF.AirPictureGenerator:GetIntensity :: (raises tempo intensity to :: key: " .. DumpPretty(key))
    return kv.Value, kv.Key
end

function DCAF.AirPictureGenerator:LowerTempoIntensity(amount, restoreInterval)
    local key = math.max(1, self.Settings.Intensity.Key - amount)
    self._tempoIntensity = getIntensityFromKey(key)
Debug("nisse - DCAF.AirPictureGenerator:GetIntensity :: lowers intensity to: " .. DumpPretty(self._tempoIntensity))
    self._raiseIntensityInterval = restoreInterval or Minutes(1)
    self._nextRaiseIntensity = UTILS.SecondsOfToday() + self._raiseIntensityInterval
end

local function setForm(generator, info, group)
    local formDelegate = DCAF_BvrFormDelegates[info.Form]
    if not formDelegate then
        return Warning(DCAF.AirPictureGenerator.ClassName .. " :: could not resolve a delegate for form: '" .. Dump(info.Form) .. "'" ) 
    end
    Debug("DCAF.AirPictureGenerator :: applies '" .. info.Form .. "' form")
    return formDelegate(generator, info, group)
end

local function setBehavior(generator, groups, info, behavior)
    behavior = behavior or generator.Settings.Behavior
    local task
    local coordTgt = info.TargetLocation:GetCoordinate()
    local coordGroup = groups[1]:GetCoordinate()
    local hdg = coordGroup:HeadingTo(coordTgt)
    local distance = coordGroup:Get2DDistance(coordTgt)
    local task

    local function getWaypoints(group)
        local coord = group:GetCoordinate()
        local coordStart = coord:Translate(NauticalMiles(1), hdg)
        local coordEnd = coord:Translate(distance - NauticalMiles(5), hdg)
        local wpStart = coordStart:WaypointAirTurningPoint(COORDINATE.WaypointAltType.BARO)
        local wpEnd = coordEnd:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO)
wpEnd.name = group._nisse_id
        return { wpStart, wpEnd }
    end

    if behavior == DCAF.BvrBehavior.AttackInZone then
    
        if not generator.TargetLocations:IsZone() and not info.TargetLocation then
            -- there's no target location zone and not even a target ...
            return setBehavior(generator, groups, DCAF.BvrBehavior.HoldFire) end

        -- attack targets in zone...
        for _, group in ipairs(groups) do
            local waypoints = getWaypoints(group)
            task = group:EnRouteTaskEngageTargetsInZone(coordTgt:GetVec2(), NauticalMiles(10))
            InsertWaypointTask(waypoints[1], task)
            group:SetRoute(waypoints)
        end

    elseif behavior == DCAF.BvrBehavior.AttackTarget then
        
        if not info.TargetLocation:IsGroup() then
            return setBehavior(generator, groups, DCAF.BvrBehavior.AttackInZone) end

        for _, group in ipairs(groups) do
            local waypoints = getWaypoints(group)
            task = group:TaskAttackGroup(info.TargetLocation.Source)
            InsertWaypointTask(waypoints[1], task)
            group:SetRoute(waypoints)
        end

    elseif behavior == DCAF.BvrBehavior.HoldFire then

        info.Task = nil
        for _, group in ipairs(groups) do
            group:OptionROEHoldFire()
            group:SetRoute(getWaypoints(group))
        end

    end

    return groups
end

local function setIntensity(generator, groups, info)
    local lowerIntensityAmount = 0
    local restoreIntensityInterval = Minutes(1)
    local currentIntensity = generator.Settings.Intensity
    local totalSize = 0
    for _, group in ipairs(groups) do
        totalSize = totalSize + #(group:GetUnits())
    end
    info.CountGroups = #groups
    info.TotalSize = totalSize
    if totalSize < 6 then
        lowerIntensityAmount = 1
    elseif totalSize < 8 then    
        lowerIntensityAmount = 2
    elseif totalSize < 10 then
        lowerIntensityAmount = 3
    else
        lowerIntensityAmount = 4
    end

    if currentIntensity.Value == AircraftAltitude.VeryLow then
        restoreIntensityInterval = restoreIntensityInterval*4
    elseif currentIntensity.Value == AircraftAltitude.Low then
        restoreIntensityInterval = restoreIntensityInterval*3
    elseif currentIntensity.Value == AircraftAltitude.Medium then
        restoreIntensityInterval = restoreIntensityInterval*2
    end
    generator:LowerTempoIntensity(lowerIntensityAmount, restoreIntensityInterval)
    return totalSize
end

local function generateGroups(generator, info)
    local group
    if info.Form == DCAF.BvrForms.SingleLight then
        group = spawnGroup(generator, info, 1, info.TargetLocation, info.SpawnLocation:GetCoordinate(), info.Altitude, info.Skill)
    elseif info.Form == DCAF.BvrForms.TwoGroupsAzimuth then
        group = spawnGroup(generator, info, 2, info.TargetLocation, info.SpawnLocation:GetCoordinate(), info.Altitude, info.Skill)
    elseif info.Form == DCAF.BvrForms.SingleHeavy then
        group = spawnGroup(generator, info, 4, info.TargetLocation, info.SpawnLocation:GetCoordinate(), info.Altitude, info.Skill)
    else
        group = spawnGroup(generator, info, nil, info.TargetLocation, info.SpawnLocation:GetCoordinate(), info.Altitude, info.Skill)
    end
    local groups = setForm(generator, info, group)
    setBehavior(generator, groups, info)
    setIntensity(generator, groups, info)
    return groups
end

local function generate(generator)
    local debug = "====== AIR PICTURE GENERATOR ======"
    local info = generator:Generate()
    if not info then
        return end

    local groups = generateGroups(generator, info)
    if generator.Settings.SuppressSpawn then
        for _, group in ipairs(groups) do
            group:Destroy()
        end
    end
   
    if generator.Settings.IsDebugging then
        generator._debug_markIDs = generator._debug_markIDs or {}
        table.insert(generator._debug_markIDs, info.TargetLocation:GetCoordinate():CircleToAll(nil, coalition.side.BLUE, {0,0,1}))
        table.insert(generator._debug_markIDs, info.SpawnLocation:GetCoordinate():CircleToAll(nil, coalition.side.BLUE, {1,0,0}))
        local infoText
        if isAssignedString(info.GroupName) then
            infoText = info.GroupName  .. "\n  "
        else
            infoText = ""
        end
        infoText = infoText .. info.Form .. " (" .. Dump(info.CountGroups) .. " / " .. Dump(info.TotalSize) .. ")\n  " .. Dump(info.Altitude)
        local coordInfoText = info.SpawnLocation:GetCoordinate():Translate(NauticalMiles(1), 130)
        local clrRed = {1,0,0}
        table.insert(generator._debug_markIDs, coordInfoText:TextToAll(infoText, coalition.side.BLUE, clrRed, nil, nil, nil, 10))
        if isNumber(generator.Settings.DebugMaxTrackMarks) and generator.Settings.DebugMaxTrackMarks < #generator._debug_markIDs then
            local diff = #generator._debug_markIDs - generator.Settings.DebugMaxTrackMarks
            local coord = info.TargetLocation:GetCoordinate()
            for i, id in ipairs(generator._debug_markIDs) do
                coord:RemoveMark(id)
                table.remove(generator._debug_markIDs, i)
                if #generator._debug_markIDs <= generator.Settings.DebugMaxTrackMarks then
                    break end
            end
        end
    end
end

function DCAF.AirPictureGenerator:Start(delay)
    self._lastGeneration = UTILS.SecondsOfToday()
    if isNumber(delay) then
        self._initialInterval = delay
    else
        self._initialInterval = 1
    end
    if self._schedulerID == nil then 
        self._schedulerID = DCAF.startScheduler(function() generate(self) end, 60, 1)
    end
    self.IsPaused = false
    return self
end

function DCAF.AirPictureGenerator:Pause(time)
    self.IsPaused = true
    if isNumber(time) then
        Delay(time, function()
            self.IsPaused = false
        end)
    end
    return self
end

function DCAF.AirPictureGenerator:Reset()
    resetIntensity(self)
    self:Despawn()
    self:Start()
    return self
end

function DCAF.AirPictureGenerator:Despawn()
    local coord
    for _, group in ipairs(self.Groups) do
        if not coord then
            coord = group:GetCoordinate()
        end
        group:Destroy()
    end
    if self._debug_markIDs and coord then
        for _, id in ipairs(self._debug_markIDs) do
            coord:RemoveMark(id)
        end
        self._debug_markIDs = nil
    end
    return self
end

function DCAF.AirPictureGenerator:Stop()
    if not self:IsRunning() then 
        return self end

    DCAF.stopScheduler(self._schedulerID)
    return self
end

function DCAF.AirPictureGenerator:IsRunning() return self._schedulerID ~= nil end

local function getAirplanesInZone(zone, coalition)
    local groups = {}
    if isClass(zone, ZONE_POLYGON.ClassName) then
        local units = zone:Scan({Object.Category.UNIT}, {Unit.Category.AIRPLANE, Unit.Category.HELICOPTER})
        local set_group = zone:GetScannedSetGroup()
        set_group:ForEachGroup(function(g) 
            if not coalition or coalition == g:GetCoalition() then
                table.insert(groups, g)
            end
        end)
        return groups
    end
    local set_targets = SET_GROUP:New():FilterZones({ zone }):FilterCategoryAirplane() --:FilterOnce()
    if coalition then 
        set_targets:FilterCoalitions({ coalition })
    end
    set_targets:FilterOnce()
    set_targets:ForEachGroup(function(g)
        if g:IsAlive() then
            table.insert(groups, g)
        end
    end)
    return groups
end

local function getRandomTargetCoordinate(generator)
    local locTarget = listRandomItem(generator.TargetLocations)
    local grpTarget
    if locTarget:IsZone() then
        local zonTarget = locTarget.Source
        local targets = getAirplanesInZone(zonTarget, generator._coalition)
        grpTarget = listRandomItem(targets)
        if not grpTarget then
            if generator.Settings.RequiresTarget then
                return end

            return DCAF.Location:New(COORDINATE:NewFromVec2(zonTarget:GetRandomVec2()))
        end
    elseif locTarget:IsAirbase() then
        return locTarget
    else
        local dictGroups = {}
        local coord = locTarget:GetCoordinate()
        local coordRandom = coord:GetRandomPointVec2()
        local units = coordRandom:ScanObjects(generator.Settings.Distance.Min.Value, true, false, false)
        for _, u in ipairs(units) do
            local group = u:GetGroup()
            if not dictGroups[group.GroupName] then
                dictGroups[group.GroupName] = group
            end
        end
        local key = dictRandomKey(dictGroups)
        grpTarget = dictGroups[key]
        if not grpTarget then
            return DCAF.Location:New(coord)
        end
    end
    return DCAF.Location:New(grpTarget)
end

local _nisse_rnd_hdgs
local function getRandomHeadingInZone(zone, hdgStart, coordStart, coordTarget, distance, debug)

    if _nisse_rnd_hdgs then
        for _, id in ipairs(_nisse_rnd_hdgs) do
            coordStart:RemoveMark(id)
        end
    end
    if debug then
        _nisse_rnd_hdgs = {}
    end

    local hdgMin
    local hdgMax
    local coordTest
    local hdgTest
    local hdgPrev
    for i = 1, 358, 2 do
        hdgTest = (hdgStart + i) % 360
        coordTest = coordTarget:Translate(distance, hdgTest)
        if zone:IsCoordinateInZone(coordTest) then
            if debug then
                table.insert(_nisse_rnd_hdgs, coordTest:CircleToAll(300, coalition.side.BLUE, {0,1,0}))
            end
            if not hdgMin then 
                hdgMin = hdgTest
            end
        else
            if debug then
                table.insert(_nisse_rnd_hdgs, coordTest:CircleToAll(300, coalition.side.BLUE))
            end
            if hdgMin and not hdgMax then
                hdgMax = hdgPrev
            end
        end
        hdgPrev = hdgTest
    end
    if zone:IsCoordinateInZone(coordTest) and not hdgMax then
        hdgMax = hdgTest
    end
    if hdgMin and hdgMax then
Debug("nisse - getRandomHeadingInZone (aaa) :: hdgMin: " .. Dump(hdgMin) .. " :: hdgMax: " .. Dump(hdgMax))        
        if hdgMax < hdgMin then
            hdgMax = hdgMax + 360 + hdgMin
        end
        local diff = hdgMax - hdgMin
        local hdgRandom = (hdgMin + math.random(diff)) % 360
Debug("nisse - getRandomHeadingInZone (bbb) :: hdgMin: " .. Dump(hdgMin) .. " :: hdgMax: " .. Dump(hdgMax) .. " :: diff: " .. Dump(diff) .. " :: hdgRandom: " .. Dump(hdgRandom))
        return coordTarget:Translate(distance, hdgRandom)
    end
end

local function getRandomSpawnLocation(generator, coordTarget)
    local locSpawn = listRandomItem(generator.SpawnLocations)
    local retries = 9

    local function cannotBeAirbase(locSpawn)
        return not generator.Settings:IsPopupEnabled() and locSpawn:IsAirbase()
    end

    local function isOutOfRange(coordSpawn)
        local distance = coordSpawn:Get2DDistance(coordTarget)
        return distance < generator.Settings.Distance.Min  or distance > generator.Settings.Distance.Max
    end

    while retries > 0 and cannotBeAirbase(locSpawn) and cannotBeAirbase(locSpawn) do
        retries = retries - 1
        locSpawn = listRandomItem(generator.SpawnLocations)
    end
    if not locSpawn then
        return end

    local coordSpawn
    if locSpawn:IsZone() then
        coordSpawn = COORDINATE:NewFromVec2(locSpawn.Source:GetRandomVec2())
-- Debug("nisse - getRandomSpawnLocation : random vec2: " .. DumpPrettyDeep(coordSpawn))
    else
        coordSpawn = locSpawn:GetCoordinate()
-- Debug("nisse - getRandomSpawnLocation : static loc: " .. DumpPrettyDeep(coordSpawn))
    end
    
    -- ensure we're in configured range...
    if not isOutOfRange(coordSpawn) and (not locSpawn:IsZone() or locSpawn.Source:IsCoordinateInZone(coordSpawn)) then
Debug("nisse - coordSpawn is OK on first try")
        return DCAF.Location:New(coordSpawn) end

-- Debug("nisse - generator.Settings : " .. DumpPrettyDeep(generator.Settings))       
    local distance = generator.Settings.Distance.Min
    local randomRange = generator.Settings.Distance.Max - generator.Settings.Distance.Min
    if randomRange > 0 then
        distance = distance + math.random(randomRange)
    end
    local hdg = coordTarget:HeadingTo(coordSpawn)
    coordSpawn = coordTarget:Translate(distance, hdg)
    if locSpawn:IsZone() then
        if not locSpawn.Source:IsCoordinateInZone(coordSpawn) then
            coordSpawn = getRandomHeadingInZone(locSpawn.Source, hdg, coordSpawn, coordTarget, distance, generator.Settings.IsDebugging)
        end
        if coordSpawn then
            return DCAF.Location:New(coordSpawn)
        else
            return
        end
    end
    -- todo - support spawning from airbase
    return DCAF.Location:New(coordSpawn)
end

local function getRandomForm(generator)
    local enabledForms = generator.Settings:GetEnabledForms()
    return listRandomItem(enabledForms)
end

local function getRandomAltitude(generator, form)
    return math.random(generator.Settings.AircraftAltitude.Min.Value, generator.Settings.AircraftAltitude.Max.Value)
end

local function isTimeForNextGeneration(generator, interval)
    if generator.IsPaused then
        return end

    local now = UTILS.SecondsOfToday()
Debug("nisse - isTimeForNextGeneration :: now: " .. Dump(now) .. " :: generator._lastGeneration: " .. Dump(generator._lastGeneration) .. " :: interval: " .. Dump(interval))            
    if not generator._lastGeneration then
        generator._lastGeneration = now
        return
    else
        if now < generator._lastGeneration + interval then
            return end

        generator._lastGeneration = now
        return true
    end
end

local function getIntensityValues(generator)
    local intensity = generator:GetIntensity()
    local maxGroupSize
    local maxGroupCount
    local generateInterval = Minutes(1)
    maxGroupSize = 4
    if intensity == AircraftAltitude.VeryLow then
        maxGroupSize = 2
        maxGroupCount = 2
        generateInterval = Minutes(3)
    elseif intensity == AircraftAltitude.Low then
        maxGroupSize = 3
        maxGroupCount = 3
        generateInterval = Minutes(2.5)
    elseif intensity == AircraftAltitude.Medium then
        maxGroupCount = 4
        generateInterval = 90
    elseif intensity == AircraftAltitude.High then
        maxGroupCount = 5
    else
        maxGroupCount = 7
    end
    if generator._initialInterval then
        generateInterval = generator._initialInterval
        generator._initialInterval = nil
    end
    return maxGroupSize, maxGroupCount, generateInterval
end

function DCAF.AirPictureGenerator:Generate()
    local maxGroupSize, maxGroupCount, interval = getIntensityValues(self)
    if not isTimeForNextGeneration(self, interval) then
        return end

    local locTarget = getRandomTargetCoordinate(self)
    if not locTarget and self.Settings.RequiresTarget then
        return end

    local retries = 9
    local locSpawn = getRandomSpawnLocation(self, locTarget:GetCoordinate())
    while retries > 0 and not locSpawn do
        retries = retries - 1
        locSpawn = getRandomSpawnLocation(self, locTarget:GetCoordinate())
    end
    if not locSpawn then
        return end

    local form = getRandomForm(self)
    local altitude = getRandomAltitude(self, form)
    return DCAF_NewGroupInfo:New(locSpawn, locTarget, altitude, form.Key, self.SelectedGroups, maxGroupSize, maxGroupCount, interval)
end

function DCAF.AirPictureSettings:GetEnabledForms()
    local forms = {}
    for _, kv in ipairs(self.Forms) do
        if kv.Value then
            table.insert(forms, kv)
        end
    end
    return forms
end

function DCAF.AirPictureSettings:Debug(value, maxTrackMarks, suppressSpawn)
    if not isBoolean(value) then
        value = true
    end
    self.IsDebugging = value
    if isNumber(maxTrackMarks) and maxTrackMarks >= 0 then
        self.DebugMaxTrackMarks = maxTrackMarks
    end
    if isBoolean(suppressSpawn) then
        self.SuppressSpawn = suppressSpawn
    end
    return self
end

function DCAF.AirPictureSettings:IsPopupEnabled()
    return self.Altitude.Min.Value == kvAltitudePopup.Value
end

function DCAF_NewGroupInfo:New(locSpawn, locTarget, altitude, form, groupFactory, maxGroupSize, maxGroupCount, generateInterval)
    local info = DCAF.clone(DCAF_NewGroupInfo)
    info.SpawnLocation = locSpawn
    info.TargetLocation = locTarget
    info.Altitude = altitude
    info.Form = form
    info.Distance = locSpawn:GetCoordinate():Get2DDistance(locTarget:GetCoordinate())
    info.DistanceNm = UTILS.MetersToNM(info.Distance)
    info.GroupFactory = groupFactory
    info.MaxGroupSize = maxGroupSize
    info.MaxGroupCount = maxGroupCount
    info.GenerateInterval = generateInterval
    info.Heading = locSpawn:GetCoordinate():HeadingTo(locTarget:GetCoordinate())
    return info
end

-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                      F10 MENU
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local function menu(generator, caption, parentMenu)
    if not parentMenu then
        parentMenu = generator._parentMenu
    end
    if generator._controllerGroup then
        return MENU_GROUP:New(generator._controllerGroup, caption, parentMenu)
    else
        return MENU_COALITION:New(generator._dcsCoalition, caption, parentMenu)
    end
end

local function command(generator, caption, parentMenu, func, ...)
    if generator._controllerGroup then
        return MENU_GROUP_COMMAND:New(generator._controllerGroup, caption, parentMenu, func, ...)
    else
        return MENU_COALITION_COMMAND:New(generator._dcsCoalition, caption, parentMenu, func, ...)
    end
end

local rebuildSettingsMenu
local _sortedIntensity
local function intensityMenu(generator, parentMenu)
    parentMenu:RemoveSubMenus()
   
    local function sort()
        if _sortedIntensity then
            return _sortedIntensity end

        _sortedIntensity = {}
        for k, v in pairs(DCAF_IntensityValues) do
            table.insert(_sortedIntensity, v)
        end
        table.sort(_sortedIntensity, function(a, b)
            return a.Key < b.Key
        end)
        return _sortedIntensity
    end

    local sortedIntensity = sort()
    for k, i in pairs(sortedIntensity) do
        command(generator, i.Value, parentMenu, function()
            generator.Settings.Intensity = i
            rebuildSettingsMenu(generator)
        end)
    end
end

local function behaviorMenu(generator, parentMenu)
    parentMenu:RemoveSubMenus()
    for _, value in pairs(DCAF.BvrBehavior) do
        command(generator, value, parentMenu, function()
            generator.Settings.Behavior = value.Value
            rebuildSettingsMenu(generator)
        end)
    end
end

local function formsMenu(generator, parentMenu)
    parentMenu:RemoveSubMenus()
    for i, form in ipairs(generator.Settings.Forms) do
        local text 
        if form.Value then text = form.Key.. ": ON" else text = form.Key .. ": --" end
        command(generator, text, parentMenu, function()
            generator.Settings:ToggleForm(form)
            rebuildSettingsMenu(generator)
        end)
    end
end

local function distanceMenu(generator)
    if generator._minDistanceMenu then
        generator._minDistanceMenu:Remove()
        generator._maxDistanceMenu:Remove()
    end
    
    generator._minDistanceMenu = menu(generator, "Min Distance: " .. Dump(UTILS.MetersToNM(generator.Settings.Distance.Min)) .. " nm", generator._settingsMenu)
    generator._maxDistanceMenu = menu(generator, "Max Distance: " .. Dump(UTILS.MetersToNM(generator.Settings.Distance.Max)) .. " nm", generator._settingsMenu)

    local function options(parentMenu, func)
        for _, kv in ipairs(DCAF_BVR_Distances) do
            command(generator, kv.Key, parentMenu, function() func(kv.Value) end)
        end
    end

    options(generator._minDistanceMenu, function(value)
        generator.Settings:SetMinDistance(value)
        rebuildSettingsMenu(generator)
    end)
    options(generator._maxDistanceMenu, function(value)
        generator.Settings:SetMaxDistance(value)
        rebuildSettingsMenu(generator)
    end)
end

local function altitudeMenu(generator)
    if generator._minAltitudeMenu then
        generator._minAltitudeMenu:Remove()
        generator._maxAltitudeMenu:Remove()
    end
    generator._minAltitudeMenu = menu(generator, "Min Altitude: " .. Dump(generator.Settings.Altitude.Min.Key), generator._settingsMenu)
    generator._maxAltitudeMenu = menu(generator, "Max Altitude: " .. Dump(generator.Settings.Altitude.Max.Key), generator._settingsMenu)

    local function options(parentMenu, func)
        for _, kv in ipairs(DCAF_BVR_Altitudes) do
            command(generator, kv.Key, parentMenu, function() func(kv) end)
        end
    end

    options(generator._minAltitudeMenu, function(kv)
        generator.Settings.Altitude.Min = kv
        if kv.Value > generator.Settings.Altitude.Max.Value then
            generator.Settings.Altitude.Max = kv
        end
        rebuildSettingsMenu(generator)
    end)
    options(generator._maxAltitudeMenu, function(kv)
        generator.Settings.Altitude.Max = kv
        if kv.Value < generator.Settings.Altitude.Min.Value then
            generator.Settings.Altitude.Min = kv
        end
        rebuildSettingsMenu(generator)
    end)
end

local function lifetimeMenu(generator)
    -- todo
end

local function groupsMenu(generator)
    local catInfos = {}
    if not generator.SelectedGroups then
        generator.SelectedGroups = DCAF.FighterGroupFactory:New("(Any)", "--"):WithSelectGroupFunc(function()
             local fg = listRandomItem(generator.GroupTemplates)
             return fg:Select()
        end)
    end
    local text = generator.SelectedGroups.Name
    local mnuGroups = menu(generator, "Groups: " .. text, generator._settingsMenu)
    command(generator, "Any", mnuGroups, function()
       generator.SelectedGroups = nil
       rebuildSettingsMenu(generator) 
    end)
    for _, fg in ipairs(generator.GroupTemplates) do
        if fg.Category then
            local mnuCatInfo = catInfos[fg.Category]
            if not mnuCatInfo then
                mnuCatInfo = { 
                    Menu = menu(generator, fg.Category, mnuGroups),
                    FG = DCAF.FighterGroupFactory:New(fg.Category .. " (any)", "--", fg.Category):WithSelectGroupFunc(function(ci) 
                        local fg = listRandomItem(ci.GroupTemplates)
                        return fg.SelectGroup()
                    end, mnuCatInfo),
                    GroupTemplates = {}
                }
                catInfos[fg.Category] = mnuCatInfo
                text = "Any " .. fg.Category
                command(generator, text, mnuCatInfo.Menu, function()
                    generator.SelectedGroups = mnuCatInfo.FG
                    rebuildSettingsMenu(generator)
                end)
            end
            table.insert(mnuCatInfo.GroupTemplates, fg)
            command(generator, fg.Name, mnuCatInfo.Menu, function()
                generator.SelectedGroups = fg
                rebuildSettingsMenu(generator)
            end)
        else
            command(generator, fg.Name, mnuGroups, function()
                generator.SelectedGroups = fg
                rebuildSettingsMenu(generator)
            end)
        end
    end
end

local function settingsMenu(generator)
-- Debug("nisse - settingsMenu :: settings: " .. DumpPrettyDeep(generator.Settings))

    generator._settingsMenu:RemoveSubMenus()
    local mnuIntensity = menu(generator, "Intensity: " .. generator.Settings.Intensity.Value, generator._settingsMenu)
    intensityMenu(generator, mnuIntensity)
    local mnuBehavior = menu(generator, "Behavior: " .. generator.Settings.Behavior, generator._settingsMenu)    
    behaviorMenu(generator, mnuBehavior)
    local formsCountMax = dictCount(DCAF.BvrForms)
    local formsCount = 0
    for k, v in pairs(generator.Settings.Forms) do
        if v.Value then 
            formsCount = formsCount + 1
        end
    end
    distanceMenu(generator)
    altitudeMenu(generator)
    local mnuForms = menu(generator, "Forms: " .. Dump(formsCount) .."/" .. Dump(formsCountMax), generator._settingsMenu)
    formsMenu(generator, mnuForms)
    groupsMenu(generator)
end
rebuildSettingsMenu = settingsMenu

local rebuildStartRestartMenu
local function startRestartMenu(generator)
    if generator._startRestartMenu then
        generator._startRestartMenu:Remove()
    end
    local text 
    if generator:IsRunning() then
        text = "Restart"
    else
        text = "Start"
    end
    generator._startRestartMenu = command(generator, text, generator._parentMenu, function()
        if generator:IsRunning() and not generator.IsPaused then
            generator:Reset()
        else
            generator:Start()
        end
        rebuildStartRestartMenu(generator)
    end)  
    if not generator.IsPaused and generator:IsRunning() then
        local pauseMenu
        pauseMenu = command(generator, "Pause", generator._parentMenu, function()
            generator:Pause()
            pauseMenu:Remove()
        end)
    end
end
rebuildStartRestartMenu = startRestartMenu

local function generatorMenu(generator)
    settingsMenu(generator)
    startRestartMenu(generator)
end

function DCAF.AirPictureGenerator:BuildF10Menu(caption, scope, parentMenu)
    if not isAssignedString(caption) then
        caption = self.Name
    end
    if scope == nil then
        scope = Coalition.Blue
    end
    self._dcsCoalition = Coalition.Resolve(scope, true)
    self._parentMenu = parentMenu
    if not self._dcsCoalition then
        self._controllerGroup = getGroup(scope)
        if not self._controllerGroup then
            error("DCAF.AirPictureGenerator:BuildF10Menu :: unrecognized `scope` (expected #Coalition or #GROUP/group name): " .. DumpPretty(scope)) end

        self._dcsCoalition = self._controllerGroup:GetCoalition()
    end
    self._settingsMenu = menu(self, "Settings", self._parentMenu)
    generatorMenu(self)
    return self
end