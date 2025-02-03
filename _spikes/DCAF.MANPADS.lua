DCAF.MANPADS = {
    ClassName = "DCAF.MANPADS",
    ---
}

local DCAF_MANPADS_DB = {
    Count = 0,
    Manpads = {}
}

local DCAF_MAPNADS_MANAGER = {
    ClassName = "DCAF_MAPNADS_MANAGER",
    ---
}

local DCAF_MANPADS_REACTION = {
    None = "(none)",
    Orient = "Orient",
    Commit = "Commit",
    Commit_Fratricide = "Commit Fratricide",
}

function DCAF_MANPADS_DB.insert(manpads)
    if not isClass(manpads, DCAF.MANPADS) then return end
    DCAF_MANPADS_DB.Manpads[manpads.Name] = manpads
    DCAF_MANPADS_DB.Count = DCAF_MANPADS_DB.Count+1
    return manpads
end

function DCAF_MANPADS_DB.remove(manpads)
    if not isClass(manpads, DCAF.MANPADS) or not DCAF_MANPADS_DB.Manpads[manpads.Name] then return end
    DCAF_MANPADS_DB.Manpads[manpads.Name] = nil
    DCAF_MANPADS_DB.Count = DCAF_MANPADS_DB.Count-1
    return manpads
end

function DCAF.MANPADS:New(unit)
    local validUnit = getUnit(unit)
    if not validUnit then return Error("DCAF.MANPADS:New :: cannot resolve UNIT from: " .. DumpPretty(unit)) end
    unit = validUnit
    local manpads = DCAF.clone(DCAF.MANPADS)
    manpads.Name = unit.UnitName
    manpads.Unit = unit
    manpads.Group = unit:GetGroup()
    manpads.Location = DCAF.Location.Resolve(unit)
    manpads.HostileCoalition = Coalition.Resolve(GetHostileCoalition(unit), true)
    manpads.Heading = unit:GetHeading() -- this is the general direction the MANPAD is monitoring the skies
    Debug("DCAF.MANPADS:New :: Name: " .. manpads.Name .. " ::  type: " .. Dump(unit:GetTypeName()))
    return DCAF_MANPADS_DB.insert(manpads:Alert1())
end

function DCAF.MANPADS:Destroy()
    DCAF_MANPADS_DB.remove(self)
end

function DCAF.MANPADS:Alert1() -- listens for aircraft rumble, and orients toward it, until LOS is established
    self.Group:OptionAlarmStateGreen()
    self._scheduleID = DCAF.startScheduler(function()
        local coord = self.Location:GetCoordinate()
        if not coord then
            self:Destroy()
            return
        end
        local hostiles = ScanAirborneUnits(self.Location, NauticalMiles(15))
        if not hostiles:Any() then return end
        local isOriented = false
        hostiles:ForEachUnit(function(unit, distance)
            local raction = self:_react(coord, unit)

        end, nil, true)
    end, 5)
    return self
end

--- Calculates a sound decibel level from a source sound decibel level at a specified distance
-- @param #number sourceDb - source decibel (sound level)
-- @param #number distanceMeters - distance from sound source (meters)
-- @return #number - the sound level (decibel) at the specified distance
function CalculateDecibel(sourceDb, distanceMeters)
    if not isNumber(sourceDb) or sourceDb < 0 then return Error("CalculateDecibel :: `sourceDb` must be positive nmber, but was: " .. DumpPretty(sourceDb)) end
    if not isNumber(distanceMeters) or distanceMeters < 0 then return Error("CalculateDecibel :: `distanceMeters` must be positive nmber, but was: " .. DumpPretty(distanceMeters)) end
    return sourceDb - 20 * math.log10(distanceMeters) - 11;
end

--- Returns true if a source is audible to a listener, taking speed and distance into account
-- @param #Any source - a #UNIT, or name of unit, acting as the sound source
-- @param #Any listener - a resolvable #DCAF.Location acting as the sound listener
-- @param #number sourceDb - the sound decibel level at aprox. source's location
-- @param #number minDb - (optional, default = 44Db) the sound decibel level at aprox. target's location
function IsAudible(source, listener, sourceDb, minDb)
    local unitSource = getUnit(source)
    if not unitSource then return Error("IsAudible :: cannot resolve source from: " .. DumpPretty(source)) end
    if not isNumber(sourceDb) or sourceDb < 0 then return Error("IsAudible :: `sourceDb` must be positive nmber, but was: " .. DumpPretty(sourceDb)) end
    if minDb == nil then
        minDb = 44
    elseif not isNumber(minDb) or minDb < 0 then 
        return Error("IsAudible :: `minDb` must be positive nmber, but was: " .. DumpPretty(minDb))
    end
    local coordSource = unitSource:GetCoordinate()
    if not coordSource then return end
    local locListener = DCAF.Location.Resolve(listener)
    if not locListener then return Error("isAudible :: cannot resolve listener from: " .. DumpPretty(listener)) end
    local coordListener = locListener:GetCoordinate()
    if not coordListener then return end

    local relPos = GetRelativePosition(coordSource, coordListener)
    local decibel = CalculateDecibel(sourceDb, relPos.SlantRange)
    if decibel < minDb then
        return false, decibel
    end

    -- calculate with speed...
    local velMps = unitSource:GetVelocityMPS()
    local machSource = velMps / 343 -- 343 = speed of sound (m/s)
    local angleCone = 180 - math.asin(1 / machSource) -- the "sound cone angle"
    return angleCone >= relPos.Direction, decibel
end

function DCAF.MANPADS:_react(coord, unit)
    local coordUnit = unit:GetCoordinate()
    local dcsUnit = unit:GetDCSObject()
    if not coordUnit then return end
    local relPos = GetRelativePosition(coord, coordUnit)
    local absDirection = math.abs(relPos.Direction)
MessageTo(nil, unit.UnitName .. " / dir: " .. absDirection .. " / s-range: " .. relPos.SlantRange .. " / los: " .. Dump(coord:IsLOS(coordUnit)) .. " / det: " .. Dump(self.Unit:IsTargetDetected(dcsUnit, true)))
    if absDirection < 90 and coord:IsLOS(coordUnit) then
        local isHostile, isFalsePositive = self:_resolveIsHostile(unit, relPos)
        if not isHostile then
            return DCAF_MANPADS_REACTION.None
        elseif isFalsePositive then
MessageTo(nil, unit.UnitName .. " / dir: " .. absDirection .. " / s-range: " .. relPos.SlantRange .. " / los: true / hostile: false")
            return DCAF_MANPADS_REACTION.Commit_Fratricide
        end
MessageTo(nil, unit.UnitName .. " / dir: " .. absDirection .. " / s-range: " .. relPos.SlantRange .. " / los: true / hostile: true")
        return DCAF_MANPADS_REACTION.Commit
    else
        local isAudible, db = IsAudible(unit, self.Unit, 144)
MessageTo(nil, unit.UnitName .. " / dir: " .. absDirection .. " / s-range: " .. relPos.SlantRange .. " / los: false / sound: " .. db .. "Db")
        return DCAF_MANPADS_REACTION.Orient
    end
end

function DCAF.MANPADS:_resolveIsHostile(unit, relPos)
    -- todo: ensure there's a chance (skill-based?) the unit is actually friendly. High speed, close might make it more likely the MANPADS incorrectly engages friendly
    return unit:GetCoalition() == self.HostileCoalition, false -- the last value indicates whether it's a false positive (false = unit is indeed hostile)
end

function DCAF.MANPADS:Start(coalition)
    local dcsCoalition
    if coalition ~= nil then
        dcsCoalition = Coalition.Resolve(coalition, true)
        if not dcsCoalition then return Error("DCAF.MANPADS.Start :: Cannot resolve coalition from: " .. DumpPretty(coalition)) end
    end
    local manager = DCAF.clone(DCAF_MAPNADS_MANAGER)
    manager.Events = BASE:New()
    manager.Events:HandleEvent(EVENTS.Birth, function(_, e)
        local unit = e.IniUnit
        if dcsCoalition and unit:GetCoalition() ~= dcsCoalition then return end
        if unit:HasAttribute("MANPADS") then
            local manpads = DCAF.MANPADS:New(unit)
            manpads._manager = manager
        end
    end)
    return manager
end
