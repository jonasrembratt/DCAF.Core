--[[ ///////////////////////////////////////////////////////////////////////////////////////////////////
                                                 DCAF.Recon
                                                 ----------
        Allows creating a recon unit that will automatically report detected hostiles with 
        semi-bespoke identification. 

        To use: 
        - Set up group on map, with a route.
        - Create DCAF.Recon object (eg. DCAF.Recon:New("BLU Recon-1"))
 
]]

DCAF.Recon = {
    ReportLifespan = Minutes(20)
}

function DCAF.Recon:New(group, tts)
    local validGroup = getGroup(group)
    if not validGroup then
        return Error("DCAF.Recon:New :: could not resolve `group`") end

    local self = DCAF.clone(DCAF.Recon)
    self.Group = validGroup
    self.Coalition = Coalition.Resolve(self.Group)
    self.CoalitionHostile = GetHostileCoalition(self.Coalition)
    self._tts = tts
    return self
end

function DCAF.Recon:NewUncontrolled(group, tts)
    local validGroup = getGroup(group)
    if not validGroup then
        return Error("DCAF.Recon:NewUncontrolled :: could not resolve `group`") end

    local self = DCAF.clone(DCAF.Recon)
    self.Group = validGroup
    self.Coalition = Coalition.Resolve(self.Group)
    self.CoalitionHostile = GetHostileCoalition(self.Coalition)
    self.Group:SetAIOff()
    if not self.Group:IsActive() then
        DCAF.delay(function()
            self.Group:Activate()
        end, 1)
    end
    self._isUncontrolled = true
    self._tts = tts
    return self
end

function DCAF.Recon:InitTTS(tts)
    self._tts = tts
    return self
end

function DCAF.Recon:Start(categories, hasOptical, hasRadar, hasRWR, hasIRST)
    if not categories then
        categories = { Unit.Category.GROUND_UNIT, Unit.Category.HELICOPTER }
    end
    local setGroup = SET_GROUP:New():AddGroup(self.Group)
    if not self.Group:IsActive() then
        self.Group:Activate()
    elseif self._isUncontrolled then
        self.Group:SetAIOn()
        self._isUncontrolled = nil
    end
    self.Detection = DETECTION_AREAS:New( setGroup ):FilterCategories(categories)
    self.Detection:InitDetectVisual( true )
    if hasOptical == true then
        self.Detection:InitDetectOptical( true )
    end
    if hasRadar == true then
        self.Detection:InitDetectRadar( true )
    end
    if hasRWR then
        self.Detection:InitDetectRWR( true )
    end
    if hasIRST then
        self.Detection:InitDetectIRST( true )
    end
    self.Detection:__Start( 5 )
    local recon = self
    function self.Detection:OnAfterDetected(from, event, to, units)
        recon:ProcessDetectedHostiles(units)
    end
end

local function extractReportingIdent(text)
    -- captures text between a pair of '='...
    return string.match(text, "=([^=]*)=")
end

function DCAF.Recon:GetGroupReportingName(group)
    -- todo consider allowing fetching this from something other that 1st waypoint, when needed
    return extractReportingIdent(group:CopyRoute()[1].name or group.GroupName)
end

local Recon_GroupStatusReport = {

}

function Recon_GroupStatusReport:New(text, group, isStatic, direction)
    local gsr = DCAF.clone(Recon_GroupStatusReport)
    gsr.Text = text
    gsr.Group = group
    gsr.Coordinate = group:GetCoordinate()
    gsr.IsStatic = isStatic
    gsr.Direction = direction
    return gsr
end

function Recon_GroupStatusReport:HasMoved(minimumDistance)
    return self.Coordinate:Get2DDistance(self.Group:GetCoordinate()) >= minimumDistance
end

function DCAF.Recon:Send(message)
    if isAssignedString(message) and self._tts then
        self._tts:Send(message)
    end
end

function DCAF.Recon:GetGroupStatusReport(group, spoken)
    local onRoad = ""
    local coordGroup = group:GetCoordinate()
    local speed = group:GetVelocityMPS()
    local direction = CardinalDirection.FromHeading(group:GetHeading())
-- Debug("nisse - Recon:GetGroupStatus :: :IsGround(): " .. Dump(group:IsGround()) .. " :: spoken: " .. Dump(spoken))
    if group:IsGround() then
        local distRoad = coordGroup:Get2DDistance(coordGroup:GetClosestPointToRoad())
        if distRoad < 4 then
            onRoad = "On road. "
        end
        if speed < 2 then
            return Recon_GroupStatusReport:New(onRoad .. "Static. ", group, true)
        end
        if speed <= 8.5 then  -- ~30 km/h
            speed = "Slow. "
        elseif speed > 15.5 then
            speed = "Fast. "
        else
            speed = ""
        end
        return Recon_GroupStatusReport:New(onRoad .. "Heading " .. direction .. ". " .. speed .. ".", group, false, direction)
    end
    if group:IsShip() then
        if speed <= .5 then
            return Recon_GroupStatusReport:New("Heading " .. direction .. ". Dormant. ", group, true)
        elseif speed < 2 then
            speed = "Slow. "
        else
            speed = UTILS.MpsToKnots(speed)
            if spoken then
                onRoad = " knots"
            else
                onRoad = " kt"
            end
        end
        return Recon_GroupStatusReport:New("Tracking " .. direction .. ". " .. speed .. " " .. onRoad .. ".", group, false, direction)
    end
    if not group:IsAir() then
        return "" end

    local altitude = ""
    local isOnGround = IsOnGround(group)
    local isParked = false
    if speed < 1 then
        speed = "Parked. "
        isParked = true
    elseif speed < 15 then
        if isOnGround then
            speed = "Taxiing. "
        elseif group:IsHelicopter() then
            speed = "Hovering. "
        end
    elseif speed < 154 then
        speed = "Slow. "
    elseif speed > 308 then
        speed = "Fast. "
    end
    local altMSL = GROUP:GetAltitude(false)
    if altMSL then
        altitude = UTILS.MetersToFeet(altMSL) .. " feet"
        if spoken then 
            onRoad = " feet"
        else
            onRoad = " ft"
        end
    end
    return Recon_GroupStatusReport:New("Tracking " .. direction .. ". " .. speed .. ". " .. altitude .. " " .. onRoad .. ".", group, isParked, direction)
end

function DCAF.Recon:OnDetectedDefault(group)
-- Debug("nisse - Recon:OnDetected :: group: " .. group.GroupName .. " :: ._tts: " .. DumpPretty(self._tts))
    if self._tts then
        local ident = self:GetGroupReportingName(group)
        if not ident then
            return end

        local report = self:SubmitReport(self:GetGroupStatusReport(group, true))
        self._tts:Send("[CALLSIGN]. Contact. " .. self:GetReportBullseye(group, ident) .. report.Text)
    end
end

function DCAF.Recon:OnDetected(func)
    if not isFunction(func) then
        Error("Recon:OnDetected :: `func` must be function, but was: " .. DumpPretty(func))
        return self
    end
    self._onDetectedFunc = func
    return self
end
--     function Recon:OnDetected(func group)
-- end

function DCAF.Recon:ProcessDetectedHostiles(units)
    self._reports = self._reports or {}
    local function process(unit)
        local group = unit:GetGroup()
        local coalition = Coalition.Resolve(group)
-- Debug("nisse - Recon:ProcessDetectedHostiles :: group: " .. group.GroupName .. " :: coalition: " .. DumpPretty(coalition) .. " :: CoalitionHostile: " .. DumpPretty(self.CoalitionHostile))
        if coalition ~= self.CoalitionHostile then
            return self end

        local now = UTILS.SecondsOfToday()
        local oldReport = self._reports[group.GroupName]
        if oldReport then
            if now < oldReport.Time + self.ReportLifespan then
                return end

            if not oldReport.Group:IsGround() or not oldReport:HasMoved(NauticalMiles(2)) then
                return end
        end

-- Debug("nisse - Recon:ProcessDetectedHostiles :: group: " .. group.GroupName .. " :: ._onDetectedFunc: " .. Dump(self._onDetectedFunc))
        if isFunction(self._onDetectedFunc) then
            self._onDetectedFunc(self, group)
        else
            self:OnDetectedDefault(group)
        end
    end

    for _, unit in pairs(units) do
        process(unit)
    end
end

function DCAF.Recon:GetReportBullseye(group, ident)
    local validGroup = getGroup(group)
    if not validGroup then
        return Error("Recon:Report :: could not resolve `group`") end

    local bullseyeText = DCAF.GetBullseyeText(group, Coalition.Blue, true)
    if bullseyeText then
        return ident .. ". " ..  bullseyeText
    end
end

function DCAF.Recon:SubmitReport(report)
    report.Time = UTILS.SecondsOfToday()
    self._reports[report.Group.GroupName] = report
    return report
end

function DCAF.Recon:Tune(frequency, modulation)
    if self._tts then
        self._tts:Tune(frequency, modulation)
    end
    return self
end