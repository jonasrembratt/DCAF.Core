-- local DCAF_ShowOfForce_WpnTrackerCount = 0 -- OBSOLETE (each ShowOfForce maintains its own WepTracker now)

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
    BuzzMinSpeed = Knots(200),   -- minimum speed (m/s) a hostile needs to fly for a subject to react
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
        self.BuzzMinSpeed = buzzMinSpeedMps
    end
    return self
end

--- Initializes the Weapon (nearby impact) event properties
---@param maxWeaponDistance number Specifies max distance (meters) an aircraft needs to drop a weapon from a unit to trigger a "weapon" event
---@param maxEventWeaponDistance number (optional) Specifies a distance (must be larger than `maxWeaponDistance` or is ignored) where weapon impact will still trigger an event, but not affect SOF severity
---@return self object #DCAF.ShowOfForceOptions
function DCAF.ShowOfForceOptions:InitWeapon(maxWeaponDistance, maxEventWeaponDistance)
    if maxWeaponDistance == nil or not isNumber(maxWeaponDistance) or maxWeaponDistance < 1 then return Error("DCAF.ShowOfForceOptions:InitWeapon :: `maxWeaponDistance` must be positive number, but was: " .. DumpPretty(maxWeaponDistance), self) end
    self.MaxWeaponDistance = maxWeaponDistance
    if isNumber(maxEventWeaponDistance) then
        if maxEventWeaponDistance <= maxWeaponDistance then return Error("DCAF.ShowOfForceOptions:InitWeapon :: `maxEventWeaponDistance` must be greater than `maxWeaponDistance`, but was: "..maxEventWeaponDistance, self) end
        self.MaxEventWeaponDistance = maxEventWeaponDistance
    end
    return self
end

--- Makes a 'subject' group react to shows of force by hostile air units
---@param subject any -- #GROUP, #UNIT or name of group/unit to react to a SOF
---@param handler function -- a function to be called back when a SOF event happens. Passes two parameters: The SOF object, and an event (#DCAF_ShowOfForce_Event)
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
            if distance > triggerDistance then return 0 end
            local distanceFactor = (triggerDistance - distance) / triggerDistance
            return event.WeaponPower * distanceFactor
        end

        local severity = getWpnImpactSeverity()
        if severity > 0 then
            self.Severity = self.Severity + severity
            event.IsInsideRange = true
        end
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
                if distance < self.Options.BuzzMaxDistance and unitSpeed >= self.Options.BuzzMinSpeed then
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

--- Triggers a Buzz event, mainly for debugging/testing purposes
---@param iniSource table The unit/group that initiates the buzz event
---@param closestUnit any (optional) [default = first unit of unit/group] The subject unit that is closest to the buzzing unit
---@param closestDistance any (optional) [default = random: 20-max buzz distance] The distance from buzzing unit to closest unit
---@param iniUnitSpeed any (optional) [default = highest of buzzing unit speed and minimum buzz speed] Speed of buzzing unit
function DCAF.ShowOfForce:DebugTriggerBuzz(iniSource, closestUnit, closestDistance, iniUnitSpeed)
    Debug("DCAF.ShowOfForce:DebugTriggerBuzz :: unitOrGroup: "..DumpPretty(iniSource).." :: closestUnit: "..DumpPretty(closestUnit).." :: closestDistance: "..Dump(closestDistance).." :: iniUnitSpeed: "..Dump(iniUnitSpeed))
    local iniUnit = getUnit(iniSource)
    if not iniUnit then
        local group = getGroup(iniSource)
        if not group then return Error("DCAF.ShowOfForce:DebugTriggerBuzz :: cannot resolve `unitOrGroup`: "..DumpPretty(iniSource)) end
        iniUnit = group:GetUnit(1)
    end
    if closestUnit == nil then
        closestUnit = self.Group:GetUnit(1)
    else
        local group = resolveGroup(closestUnit)
        if not group then return Error("DCAF.ShowOfForce:DebugTriggerBuzz :: `could not resolve `closestUnit`: "..DumpPretty(closestUnit)) end
        closestUnit = group:GetUnit(1)
    end
    if not isNumber(closestDistance) then
        closestDistance = math.random(20, self.Options.BuzzMaxDistance)
    end
    if not isNumber(iniUnitSpeed) then
        iniUnitSpeed = math.max(iniUnit:GetVelocityMPS(), self.Options.BuzzMinSpeed)
    end
    Debug("DCAF.ShowOfForce:DebugTriggerBuzz :: iniUnit: "..DumpPretty(iniUnit).." :: closestUnit: "..DumpPretty(closestUnit).." :: closestDistance: "..Dump(closestDistance).." :: iniUnitSpeed: "..Dump(iniUnitSpeed))
    self:_eventBuzz(iniUnit, closestUnit, closestDistance, iniUnitSpeed)
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
    e.TargetGroup = closestUnit:GetGroup()
    e.TargetGroupName = e.TargetGroup.GroupName
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
    e.TargetGroup = closestUnit:GetGroup()
    e.TargetGroupName = e.TargetGroup.GroupName
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


    -- DCAF.ShowOfForce._wpnTrackerHandlers = DCAF.ShowOfForce._wpnTrackerHandlers or {}
    -- DCAF.ShowOfForce._wpnTrackerHandlers[#DCAF.ShowOfForce._wpnTrackerHandlers+1] = self
    -- if DCAF.ShowOfForce._wpnTracker then return DCAF.ShowOfForce._wpnTracker end
    -- DCAF.ShowOfForce._wpnTracker = DCAF.WpnTracker:New(self.ClassName):IgnoreIniGroups({self.Group}):Start(false)
    self._wpnTracker = DCAF.WpnTracker:New(self.ClassName.."/"..self.Name):IgnoreIniGroups({self.Group}):Start(false)
    local sof = self
    -- DCAF_ShowOfForce_WpnTrackerCount = DCAF_ShowOfForce_WpnTrackerCount+1
    function self._wpnTracker:OnImpact(wpnTrack)
        -- for _, sof in ipairs(DCAF.ShowOfForce._wpnTrackerHandlers) do
        local maxDistance = sof.Options.MaxEventWeaponDistance or sof.Options.MaxWeaponDistance
        local coordWeapon = wpnTrack:GetWeaponCoordinate()
        local closestUnit
        local closestDistance = maxDistance+1
Debug("nisse - DCAF.ShowOfForce:_startWeaponTracker_OnImpact :: sof.Group: " .. DumpPretty(sof.Group))
        local units = sof.Group:GetUnits()
Debug("nisse - DCAF.ShowOfForce:_startWeaponTracker_OnImpact :: units: " .. DumpPretty(units))
        if not units then
            -- seems group's been destroyed, or despawned; end SOF...
            sof:End()
            return
        end
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

        if closestUnit then sof:_handleWeaponEvent(DCAF_ShowOfForce_Event:WeaponImpact(wpnTrack, closestUnit, closestDistance)) end
        -- end
    end
    return self._wpnTracker
end

function DCAF.ShowOfForce:_endWeaponTracker()
    -- if DCAF_ShowOfForce_WpnTrackerCount == 0 then return end
    -- DCAF_ShowOfForce_WpnTrackerCount = DCAF_ShowOfForce_WpnTrackerCount-1
    -- if DCAF_ShowOfForce_WpnTrackerCount == 0 then
    if self._wpnTracker then
Debug("nisse - DCAF.ShowOfForce:_endWeaponTracker :: self.Group: "..self.Group.GroupName)
        self._wpnTracker:End()
        self._wpnTracker = nil
    end
end

function DCAF.ShowOfForce:_handleWeaponEvent(event)
    self.WeaponImpactCount =  self.WeaponImpactCount + 1
    self.WeaponImpactTotalPower = self.WeaponImpactTotalPower + event.WeaponPower
    self:UpdateSeverity(event)
    event.Severity = self.Severity
    Debug("DCAF.ShowOfForce:_handleWeaponEvent ::\n"..event:DebugText())
    if isFunction(self.Handler) then
        local ok, err = pcall(function() self.Handler(self, event) end)
        if not ok then Error("DCAF.ShowOfForce:_handleWeaponEvent :: error when invoking event handler: " .. DumpPretty(err)) end
    end
    if self.Options.EndOnEvent then return self:End() end
end

function DCAF.ShowOfForce:_eventBuzz(iniUnit, closestUnit, closestDistance, iniUnitSpeed)
    Debug("DCAF.ShowOfForce:_eventBuzz :: iniUnit: " .. iniUnit.UnitName .. " :: closestUnit: " .. closestUnit.UnitName .. " :: closestDistance: " .. closestDistance .. " :: iniUnitSpeed: " .. iniUnitSpeed)
    self.BuzzCount = self.BuzzCount + 1
    local event = DCAF_ShowOfForce_Event:Buzz(iniUnit, iniUnitSpeed, closestUnit, closestDistance)
    self:UpdateSeverity(event)
    event.Severity = self.Severity
    Debug("DCAF.ShowOfForce:_eventBuzz ::\n"..event:DebugText())
    if isFunction(self.Handler) then
        local ok, err = pcall(function() self.Handler(self, event) end)
        if not ok then Error("DCAF.ShowOfForce:_eventBuzz :: error when invoking event handler: " .. DumpPretty(err)) end
    end
    if self.Options.EndOnEvent then return self:End() end
end

function DCAF.ShowOfForce:End()
    if self._isEnded then return end
    self._isEnded = true
    Debug("DCAF.ShowOfForce:End :: " .. self.Name)
    self:_endScheduler()
    self:_endWeaponTracker()
end

function DCAF.ShowOfForce:_endScheduler()
    if self._schedulerID then pcall(function() DCAF.stopScheduler(self._schedulerID) end) end
end