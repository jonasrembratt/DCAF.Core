DCAF.ShowOfForce = {
    ClassName = "DCAF.ShowOfForce"
    ----
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
    EndOnEvent = true,              -- when true, the SOF monitoring will automatically end on next SOF event
    TriggerMaxDistance = 200,       -- max distance (meters) a hostile can fly from subject for it to react
    TriggerMinSpeed = Knots(200)    -- minimum speed (m/s) a hostile needs to fly for a subject to react
}

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
    sof:_monitorLong()
    return sof
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
end

function DCAF.ShowOfForce:_monitorClose()
    Debug("DCAF.ShowOfForce:_monitorClose :: " .. self.Name)
    self:_endScheduler()
    local endTime = UTILS.SecondsOfToday() + Minutes(self.Options.ShortTimeout)
    self._schedulerID = DCAF.startScheduler(function()
        if UTILS.SecondsOfToday() > endTime then return self:_monitorLong() end
        local coordSelf = self.Group:GetCoordinate()
        if not coordSelf then return self:End() end
        local hostile = ScanAirborneUnits(self.Group, self.Options.LongRange, self.HostileCoalition)
        if not hostile:Any() then return end

        for _, info in ipairs(hostile.Units) do
            local unit = info.Unit
            local coordUnit = unit:GetCoordinate()
            if coordUnit then
                local distance = coordUnit:Get3DDistance(coordSelf)
                if distance < self.Options.TriggerMaxDistance and unit:GetVelocityMPS() >= self.Options.TriggerMinSpeed then
                    pcall(function() self.Handler(self) end)
                    if self.Options.EndOnEvent then return self:End() end
                end
            end
        end

    end, self.Options.ShortInterval)
end

function DCAF.ShowOfForce:End()
    Debug("DCAF.ShowOfForce:End :: " .. self.Name)
    self:_endScheduler()
end

function DCAF.ShowOfForce:_endScheduler()
    if self._schedulerID then pcall(function() DCAF.stopScheduler(self._schedulerID) end) end
end