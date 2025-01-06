DCAF.ShowOfForce = {
    ClassName = "DCAF.ShowOfForce",
    ----
    Severity = 0,                   -- specifies level of escalation/severity, calculated by 
    BuzzCount = 0,                  -- no. of buzz events performed so far
    WeaponImpactCount = 0,          -- no. of bombs/missiles impacted within MaxWeaponDistance so far
    WeaponImpactTotalPower = 0,     -- total explosive power impacted within MaxWeaponDistance so far
}

local function resolveGroup(subject)
    if isUnit(subject) then return subject:GetGroup() end
    if isGroup(subject) then return subject end
    if isAssignedString(subject) then return getGroup(subject) end
end

DCAF.ShowOfForceOptions = {
    ClassName = "DCAF.ShowOfForceOptions",
    ----
    LongRange = NauticalMiles(8),   -- monitors at this range in long intervals
    LongInterval = 7,               -- monitors sky for hostile units using this interval
    ShortRange = NauticalMiles(3),  -- monitors at this range in short intervals
    ShortInterval = .5,             -- monitors sky very frequently using this interval
    ShortTimeout = Minutes(3),      -- monitors sky very frequently for this amount of time
    EndOnEvent = false,             -- when true, the SOF monitoring will automatically end on next SOF event
    BuzzMaxDistance = 400,          -- max distance (meters) a hostile can fly from subject for it to react
    TriggerMinSpeed = Knots(200),   -- minimum speed (m/s) a hostile needs to fly for a subject to react
    MaxWeaponDistance = 1000,       -- max distance (meters) from subject a weapon can impact for a 'weapons impact' event to trigger
}

--- Creates, initializes, and returns a #DCAF.ShowOfForceOptions object
function DCAF.ShowOfForceOptions:New()
    return DCAF.clone(DCAF.ShowOfForceOptions)
end

--- Initializes the Buzz event properties
---@param buzzMaxDistance number (optional) [default = 200] Specifies max distance (meters) an aircraft needs to fly from a unit to trigger a "buzz" event
---@param buzzMinSpeedKnots any (optional) [default = 200, minimum 100] Specifies minimum speed (knots) an aircraft needs to fly from past a unit to trigger a "buzz" event
---@return self object #DCAF.ShowOfForceOptions
function DCAF.ShowOfForceOptions:InitBuzz(buzzMaxDistance, buzzMinSpeedKnots)
    if buzzMaxDistance ~= nil then
        if not isNumber(buzzMaxDistance) or buzzMaxDistance < 1 then return Error("DCAF.ShowOfForceOptions:InitBuzz :: `buzzMaxDistance` must be positive number, but was: " .. DumpPretty(buzzMaxDistance), self) end
        self.BuzzMaxDistance = buzzMaxDistance
    end
    if buzzMinSpeedKnots ~= nil then
        if not isNumber(buzzMinSpeedKnots) or buzzMinSpeedKnots < 1 then return Error("DCAF.ShowOfForceOptions:InitBuzz :: `buzzMinSpeedKnots` must be positive number, but was: " .. DumpPretty(buzzMinSpeedKnots), self) end
        local buzzMinSpeedMps = UTILS.KnotsToMps(math.max(100, buzzMinSpeedKnots))
        self.TriggerMinSpeed = buzzMinSpeedMps
    end
    return self
end

--- Initializes the Weapon (nearby impact) event properties
---@param maxWeaponDistance number (optional) [default = 1000] Specifies max distance (meters) an aircraft needs to drop a weapon from a unit to trigger a "weapon" event
---@return self object #DCAF.ShowOfForceOptions
function DCAF.ShowOfForceOptions:InitWeapon(maxWeaponDistance)
    if maxWeaponDistance == nil or not isNumber(maxWeaponDistance) or maxWeaponDistance < 1 then return Error("DCAF.ShowOfForceOptions:InitWeapon :: `maxWeaponDistance` must be positive number, but was: " .. DumpPretty(maxWeaponDistance), self) end
    self.MaxWeaponDistance = maxWeaponDistance
    return self
end

--- Makes a 'subject' group react to shows of force by hostile air units
---@param subject any -- #GROUP, #UNIT or name of group/unit to react to a SOF
---@param handler function -- a function to be called back when a SOF event happens
---@param options any -- (optional; default = #DCAF.ShowOfForceOptions) specifies options for SOF logic
function DCAF.ShowOfForce.React(subject, handler, options)
    if not isFunction(handler) then return Error("DCAF.ShowOfForce.React :: `handler` must be function, but was: " .. DumpPretty(handler)) end
    if options ~= nil and not isClass(options, DCAF.ShowOfForceOptions) then return Error("DCAF.ShowOfForce.React :: `options` must be " .. DCAF.ShowOfForceOptions.ClassName .. ", but was: " .. DumpPretty(handler)) end
    local group = resolveGroup(subject)
    if not group then return Error("DCAF.ShowOfForce.React :: cannot resolve GROUP from `subject`: " .. DumpPretty(subject)) end
    local sof = group._showOfForce
    if sof then return sof end
    sof = DCAF.clone(DCAF.ShowOfForce)
    sof.Name = group.GroupName
    sof.Group = group
    sof.Handler = handler
    sof.Options = options or DCAF.ShowOfForceOptions
    sof.HostileCoalition = GetHostileCoalition(group)
    sof:_startWeaponTracker()
    sof:_monitorLong()
    return sof
end

function DCAF.ShowOfForce:UpdateSeverity(event)
    if event:IsBuzz() then
        local function getBuzzSeverity()
            if self.BuzzCount >= 0 and self.BuzzCount < 3 then return self.BuzzCount+1 end
            if self.BuzzCount == 4 then return 2 end
            return 1
        end
        self.Severity = self.Severity + getBuzzSeverity() * 10
    elseif event:IsWeaponImpact() then
        local function getWpnImpactSeverity()
            local distance = event.ClosestDistance
            local triggerDistance = self.Options.MaxWeaponDistance
            local distanceFactor = (triggerDistance - distance) / triggerDistance
            return event.WeaponPower * distanceFactor
        end
        self.Severity = self.Severity + getWpnImpactSeverity()
    else
        return Error("DCAF.ShowOfForce:UpdateSeverity :: unsupported event type: " .. Dump(event.Type))
    end
    return self.Severity
end

function DCAF.ShowOfForce:_monitorLong()
    Debug("DCAF.ShowOfForce:_monitorLong :: " .. self.Name)
    self:_endScheduler()
    self._schedulerID = DCAF.startScheduler(function()
        local coordSelf = self.Group:GetCoordinate()
        if not coordSelf then return self:End() end
        local hostile = ScanAirborneUnits(self.Group, self.Options.LongRange, self.HostileCoalition)
        if not hostile:Any() then return end

        for _, info in ipairs(hostile.Units) do
            local unit = info.Unit
            local coordUnit = unit:GetCoordinate()
            if coordUnit then
                local relPos = GetRelativePosition(unit, self.Group)
                local relDir = math.abs(relPos.Direction)
                if relDir < 45 then
                    return self:_monitorClose()
                end
            end
        end
    end, self.Options.LongInterval)
    pcall(function() self:OnMonitorClose(self.Options.LongRange) end)
end

function DCAF.ShowOfForce:_monitorClose()
    Debug("DCAF.ShowOfForce:_monitorClose :: " .. self.Name)
    self:_endScheduler()
    local endTime = UTILS.SecondsOfToday() + Minutes(self.Options.ShortTimeout)
    self._schedulerID = DCAF.startScheduler(function()
        local now = UTILS.SecondsOfToday()
        if now > endTime then return self:_monitorLong() end
        if self._coolDownTime and now < self._coolDownTime then return end
        local coordSelf = self.Group:GetCoordinate()
        if not coordSelf then return self:End() end
        local hostile = ScanAirborneUnits(self.Group, self.Options.ShortRange, self.HostileCoalition)
        if not hostile:Any() then return end

        for _, info in ipairs(hostile.Units) do
            local unit = info.Unit
            local coordUnit = unit:GetCoordinate()
            if coordUnit then
                local distance = coordUnit:Get3DDistance(coordSelf)
                local unitSpeed = unit:GetVelocityMPS()
                if distance < self.Options.BuzzMaxDistance and unitSpeed >= self.Options.TriggerMinSpeed then
                    local closestUnit, closestDistance = getGroupClosestUnit(self.Group, coordUnit)
                    if closestDistance < self.Options.BuzzMaxDistance then
                        self:_eventBuzz(unit, closestUnit, closestDistance, unitSpeed)
                        self._coolDownTime = UTILS.SecondsOfToday() + 40
                    end
                end
            end
        end

    end, self.Options.ShortInterval)
    pcall(function() self:OnMonitorClose(self.Options.ShortRange) end)
end

function DCAF.ShowOfForce:OnMonitorLong(range)
end

function DCAF.ShowOfForce:OnMonitorClose(range)
end


DCAF.ShowOfForceEventType = {
    Buzz = "Buzz",
    WeaponImpact = "WeaponImpact"
}

local DCAF_ShowOfForce_Event = {
    ClassName = "DCAF_ShowOfForce_Event",
    ----
}

function DCAF_ShowOfForce_Event:Buzz(iniUnit, iniUnitSpeedMps, closestUnit, closestDistance)
    local e = DCAF.clone(DCAF_ShowOfForce_Event)
    e.Type = DCAF.ShowOfForceEventType.Buzz
    e.IniUnit = iniUnit
    e.IniUnitName = iniUnit.UnitName
    e.IniUnitSpeedMps = iniUnitSpeedMps
    e.ClosestUnit = closestUnit
    e.ClosestUnitName = closestUnit.UnitName
    e.ClosestDistance = closestDistance
    return e
end

function DCAF_ShowOfForce_Event:WeaponImpact(wpnTrack, closestUnit, closestDistance)
    local e = DCAF.clone(DCAF_ShowOfForce_Event)
    e.Type = DCAF.ShowOfForceEventType.WeaponImpact
    e.IniUnit = wpnTrack.IniUnit
    e.IniUnitName = wpnTrack.IniUnit.UnitName
    e.Weapon = wpnTrack.Weapon
    e.WeaponPower = wpnTrack.Power
    e.WeaponType = wpnTrack.Type
    e.ImpactCoordinate = wpnTrack.ImpactCoordinate
    e.ClosestUnit = closestUnit
    e.ClosestUnitName = closestUnit.UnitName
    e.ClosestDistance = closestDistance
    return e
end

function DCAF_ShowOfForce_Event:IsBuzz() return self.Type == DCAF.ShowOfForceEventType.Buzz end
function DCAF_ShowOfForce_Event:IsWeaponImpact() return self.Type == DCAF.ShowOfForceEventType.WeaponImpact end

function DCAF_ShowOfForce_Event:DebugText()
    local text

    local function defaultText()
        return     "Blu Unit: " .. self.IniUnitName.."\n"..
                   "Red Unit: " .. self.ClosestUnitName.."\n"..
                   "Distance: " .. self.ClosestDistance.." m\n"
    end

    if self.Type == DCAF.ShowOfForceEventType.Buzz then
        text =     "-------- SoF Buzz event ----------\n"..defaultText()
    elseif self.Type == DCAF.ShowOfForceEventType.WeaponImpact then
        text =     "-------- SoF Weapon event --------\n"..defaultText()..
                   "Wpn Type: " .. self.Type .. "\n"
    end
    text = text .. "----------------------------------\n"..
                   "Severity = " .. self.Severity
    return text
end

function DCAF.ShowOfForce:_startWeaponTracker()
    Debug("DCAF.ShowOfForce:_startWeaponTracker")

    -- experiment, calculating impact point of shells...
--     function getShellsImpactVec2(aircraftPosition, altitude, aircraftSpeed, pitch, groundAltitude, bulletSpeed)
--         local g = 9.81 -- Gravity (m/s^2)

--         -- Initial velocities
--         local v_bullet_x = bulletSpeed * math.cos(pitch) + aircraftSpeed.x
--         local v_bullet_z = bulletSpeed * math.sin(pitch) + aircraftSpeed.z
    
--         -- Initial position of the aircraft
--         local x0 = aircraftPosition.x
--         local y0 = aircraftPosition.y -- This is altitude (meters above ground)
    
--         -- Quadratic equation coefficients
--         local a = 0.5 * g
--         local b = -v_bullet_z
--         local c = y0 - groundAltitude
    
--         -- Solve for time of impact
--         local discriminant = b^2 - 4 * a * c
--         if discriminant < 0 then
--             return nil -- No impact (e.g., bullet doesn't reach ground)
--         end
    
--         local t = (-b + math.sqrt(discriminant)) / (2 * a) -- Positive root
    
--         -- Calculate impact position
--         local impactX = x0 + v_bullet_x * t
--         local impactY = groundAltitude -- Ground level in meters
--         return  {x = impactX, y = impactY, time = t}
--     end

--     local nisse = BASE:New() -- experiment, trying to see if we can also trace bullets
--     nisse:HandleEvent(EVENTS.ShootingStart, function(_, e)
--         local iniUnit = e.IniUnit
--         local vec2Unit = iniUnit:GetCoordinate():GetVec2()
--         local iniUnitPitch = iniUnit:GetPitch()
--         local iniUnitSpeed = iniUnit:GetVelocityVec3()
--         local iniUnitAgl = iniUnit:GetAltitude(true)
--         local vec2Impact = getShellsImpactVec2(vec2Unit, iniUnitAgl, iniUnitSpeed, iniUnitPitch, iniUnitAgl)
--         local coordImpact = COORDINATE:NewFromVec2(vec2Impact)
--         coordImpact:CircleToAll()
-- Debug("nisse - DCAF.ShowOfForce:_startWeaponTracker :: e: " .. DumpPrettyDeep(e, 1))
--     end)
--     nisse:HandleEvent(EVENTS.ShootingEnd, function(_, e)
-- Debug("nisse - DCAF.ShowOfForce:_startWeaponTracker :: e: " .. DumpPrettyDeep(e, 2))
--     end)
        

    DCAF.ShowOfForce._wpnTrackerHandlers = DCAF.ShowOfForce._wpnTrackerHandlers or {}
    DCAF.ShowOfForce._wpnTrackerHandlers[#DCAF.ShowOfForce._wpnTrackerHandlers+1] = self
    if DCAF.ShowOfForce._wpnTracker then return DCAF.ShowOfForce._wpnTracker end
    DCAF.ShowOfForce._wpnTracker = DCAF.WpnTracker:New(self.ClassName):IgnoreIniGroups({self.Group}):Start(false)
    function DCAF.ShowOfForce._wpnTracker:OnImpact(wpnTrack)
        Debug("DCAF.ShowOfForce:_startWeaponTracker_OnImpact :: wpnTrack: " .. DumpPretty(wpnTrack))
        for _, showOfForce in ipairs(DCAF.ShowOfForce._wpnTrackerHandlers) do
            local maxDistance = showOfForce.Options.MaxWeaponDistance
            local coordWeapon = wpnTrack:GetWeaponCoordinate()
            local closestUnit
            local closestDistance = maxDistance+1
            local units = showOfForce.Group:GetUnits()
            for _, unit in ipairs(units) do
                local coordUnit = unit:GetCoordinate()
                if coordUnit then
                    local distance = coordUnit:Get2DDistance(coordWeapon)
                    if distance < closestDistance then
                        closestDistance = distance
                        closestUnit = unit
                    end
                end
            end
            if closestUnit then showOfForce:_handleWeaponEvent(DCAF_ShowOfForce_Event:WeaponImpact(wpnTrack, closestUnit, closestDistance)) end
        end
    end
    return DCAF.ShowOfForce._wpnTracker
end

function DCAF.ShowOfForce._endWeaponTracker()
    DCAF.ShowOfForce._weaponTrackerCount = DCAF.ShowOfForce._weaponTrackerCount-1
    if DCAF.ShowOfForce._weaponTrackerCount == 0 then
        DCAF.ShowOfForce._wpnTracker:End()
        DCAF.ShowOfForce._wpnTracker = nil
    end
end

function DCAF.ShowOfForce:_handleWeaponEvent(event)
    self.WeaponImpactCount =  self.WeaponImpactCount + 1
    self.WeaponImpactTotalPower = self.WeaponImpactTotalPower + event.WeaponPower
    self:UpdateSeverity(event)
    event.Severity = self.Severity
    pcall(function() self.Handler(self, event) end)
    if self.Options.EndOnEvent then return self:End() end
end

function DCAF.ShowOfForce:_eventBuzz(iniUnit, closestUnit, closestDistance, iniUnitSpeed)
    Debug("DCAF.ShowOfForce:_eventBuzz :: iniUnit: " .. iniUnit.UnitName .. " :: closestUnit: " .. closestUnit.UnitName .. " :: closestDistance: " .. closestDistance .. " :: iniUnitSpeed: " .. iniUnitSpeed)
    self.BuzzCount = self.BuzzCount + 1
    local event = DCAF_ShowOfForce_Event:Buzz(iniUnit, iniUnitSpeed, closestUnit, closestDistance)
    self:UpdateSeverity(event)
    event.Severity = self.Severity
    if isFunction(self.Handler) then
        local ok, err = pcall(function() self.Handler(self, event) end)
        if not ok then Error("DCAF.ShowOfForce:_eventBuzz :: error when invoking event handler: " .. DumpPretty(err)) end
    end
    if self.Options.EndOnEvent then return self:End() end
end

function DCAF.ShowOfForce:End()
    Debug("DCAF.ShowOfForce:End :: " .. self.Name)
    self:_endScheduler()
    self:_endWeaponTracker()
end

function DCAF.ShowOfForce:_endScheduler()
    if self._schedulerID then pcall(function() DCAF.stopScheduler(self._schedulerID) end) end
end