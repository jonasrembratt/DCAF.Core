--[[ ///////////////////////////////////////////////////////////////////////////////////////////////////
                                                 DCAF.Recon
                                                 ----------
        Allows creating a recon unit that will automatically report detected hostiles with 
        semi-bespoke identification. 

        To use: 
        - Set up group on map, with a route.
        - Create DCAF.Recon object (eg. DCAF.Recon:New("BLU Recon-1"))
 
]]

local DCAF_Recon_Defaults = {
    ReportLifespan = {
        Stationary = Minutes(20),
        Mobile = Minutes(5),
    },
    CountPlayerReconTasks = 0
}

function DCAF_Recon_Defaults:GetPlayerReconID()
    self.CountPlayerReconTasks = self.CountPlayerReconTasks+1
    return self.CountPlayerReconTasks
end

DCAF.Recon = {
    ClassName = "DCAF.Recon",
    ----
    ReportLifespan = DCAF_Recon_Defaults.ReportLifespan
}

DCAF.ReconDrawOptions = {
    ClassName = "DCAF.ReconDrawOptions",
    ----
    IconRadius = NauticalMiles(0.3),
    TextSize = 11,
    TextColor = Color.White,
    TextFillColor = Color.Red,
    MaxAlpha = 1
    -- WORK IN PROGRESS (still experimental concept)
}

function DCAF.ReconDrawOptions:New()
    return DCAF.clone(DCAF.ReconDrawOptions)
end

function DCAF.ReconDrawOptions:InitIconSize(size)
    if not isNumber(size) or size < 0 then return Error("DCAF.ReconDrawOptions:InitIconSize :: `size` must be positive number, but was: " .. DumpPretty(size)) end
    self.IconRadius = size
    return self
end

function DCAF.ReconDrawOptions:InitMaxAlpha(alpha)
    if not isNumber(alpha) or alpha < 0 or alpha > 1 then return Error("DCAF.ReconDrawOptions:InitMaxAlpha :: `alpha` must be number between 0 and 1, but was: " .. DumpPretty(alpha)) end
    self.MaxAlpha = alpha
    return self
end

function DCAF.ReconDrawOptions:InitTextSize(size)
    if not isNumber(size) or size < 0 then return Error("DCAF.ReconDrawOptions:InitTextSize :: `size` must be positive number, but was: " .. DumpPretty(size)) end
    self.TextSize = size
    return self
end

function DCAF.ReconDrawOptions:InitTextColor(color)
    if not isList(color) then return Error("DCAF.ReconDrawOptions:InitTextColor :: `color` must be table, but was: " .. DumpPretty(color)) end
    self.TextColor = color
    return self
end

function DCAF.ReconDrawOptions:InitTextFillColor(color)
    if not isList(color) then return Error("DCAF.ReconDrawOptions:InitTextFillColor :: `color` must be table, but was: " .. DumpPretty(color)) end
    self.TextFillColor = color
    return self
end

DCAF.PlayerReconTask = {
    ClassName = "DCAF.ReconTask",
    ----
    ID = 0,    -- see DCAF_Recon_Defaults.CountReconTasks
}

function DCAF.PlayerReconTask:New(group, name)
    Debug("DCAF.PlayerReconTask:New :: group: " .. DumpPretty(group).." :: name: "..DumpPretty(name))
    local validGroup = getGroup(group)
    if not validGroup then return Error("DCAF.PlayerReconTask:New :: cannot resolve group: " .. DumpPretty(group)) end
    group = validGroup
    local task = DCAF.clone(DCAF.PlayerReconTask)
    task.ID = DCAF_Recon_Defaults:GetPlayerReconID()
    task.Group = group
    if isAssignedString(name) then
        task.Name = name
    else
        task.Name = DCAF.PlayerReconTask.ClassName.."#"..task.ID
    end
    return task
end

--- TODO :: move to DCAF.Core
function DCAF.IsSinglePlayer()
    local playerUnits = _DATABASE:GetPlayerUnits()
    local count = 0
    local singlePlayerName
    for playerName, playerUnit in pairs( playerUnits ) do
        singlePlayerName = playerName
        count = count + 1
        if count > 1 then return end
    end
    return count == 1, singlePlayerName
end

--- Makes task automatically detect when player in group adds a map marker
---@return table self #DCAF.PlayerReconTask
function DCAF.PlayerReconTask:HandleMapMarker(funcOnMark)
    Debug("DCAF.PlayerReconTask:HandleMapMarker :: funcOnMark: " .. DumpPretty(funcOnMark))
    if not isFunction(funcOnMark) then return Error("DCAF.PlayerReconTask:HandleMapMarker :: `funcOnMark` must be function, but was: " .. DumpPretty(funcOnMark)) end

    local function isPlayerInGroup(playerName)
        if not playerName then
            local isSinglePlayer, singlePlayerName = DCAF.IsSinglePlayer()
            if DCAF.Debug and isSinglePlayer then return singlePlayerName end
            return
        end
        local playerNames = self.Group:GetPlayerNames()
        for _, pn in ipairs(playerNames) do
            if pn == playerName then return true end
        end
        return false
    end
    
    local function isProximity(coord)
        local location = self._requireProximity.Location
        local coordLocation = location:GetCoordinate()
        if not coordLocation then return Error("DCAF.PlayerReconTask:HandleMapMarker:HandleMapMarker :: cannot get coordinate for location") end
        local distance = coord:Get2DDistance(coordLocation)
        local maxDistance = self._requireProximity.MaxDistance
        Debug("DCAF.PlayerReconTask:HandleMapMarker:EnableFlightMarkerRecon :: distance: "..distance.." m".." :: maxDistance: "..maxDistance.." m")
        return distance < maxDistance
    end

    self._mapMarkerEventSink = BASE:New()
    self._mapMarkerEventSink:HandleEvent(EVENTS.MarkAdded, function(_, e)
Debug("nisse - DCAF.PlayerReconTask:HandleMapMarker_HandleEvent :: e: " .. DumpPrettyDeep(e, 2))
        local initiator = e.IniUnit or e.initiator
        local iniUnit
        local playerName
        if self._requireProximity and not isProximity(e.MarkCoordinate) then return end

        if not initiator then
            if self._requireInitiator then return Error("DCAF.PlayerReconTask:HandleMapMarker_HandleEvent :: no initiator object in event") end
            -- we're ok as long as the marker is within accepted distance
            local ok, err = pcall(function() funcOnMark(self, e) end)
            if not ok then Error("DCAF.PlayerReconTask:HandleMapMarker :: error in callback: " .. DumpPretty(err)) end
            return
        end
        if isClass(initiator, UNIT) then
Debug("nisse - DCAF.PlayerReconTask:HandleMapMarker_HandleEvent :: initiator is UNIT")
            iniUnit = initiator
            playerName = initiator:GetPlayerName()
        elseif initiator then
Debug("nisse - DCAF.PlayerReconTask:HandleMapMarker_HandleEvent :: initiator is DCS unit")
            iniUnit = UNIT:Find(initiator)
            if iniUnit then
                playerName = initiator:GetPlayerName()
            else
                playerName = initiator:getPlayerName()
            end
        end
        if not playerName then return Error("DCAF.PlayerReconTask:HandleMapMarker_HandleEvent :: cannot obtain initiator player name from event") end
        if not isPlayerInGroup(playerName) then return end
        e.PlayerName = playerName
        local ok, err = pcall(function() funcOnMark(self, e) end)
        if not ok then Error("DCAF.PlayerReconTask:HandleMapMarker :: error in callback: " .. DumpPretty(err)) end
    end)

    return self
end

function DCAF.PlayerReconTask:RequireInitiator(value)
    if not isBoolean(value) then value = true end
    self._requireInitiator = value
    return self
end

function DCAF.PlayerReconTask:RequireProximity(location, maxDistance)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error("DCAF.PlayerReconTask:RequireProximity :: cannot resolve `location`: "..DumpPretty(location)) end
    if not isNumber(maxDistance) or maxDistance < 1 then return Error("DCAF.PlayerReconTask:RequireProximity :: `maxDistance` must be numeric value >= 1, but was: "..DumpPretty(maxDistance)) end
    self._requireProximity = {
        Location = location,
        MaxDistance = maxDistance
    }
    return self
end

function DCAF.PlayerReconTask:End()
    if self._mapMarkerEventSink then
        self._mapMarkerEventSink:UnHandleEvent(EVENTS.MarkAdded)
    end
end

--- Creates and returns a new #DCAF.Recon object
-- @param #Any group - a source for a #GROUP (can be a #GROUP, a #UNIT or the name of a #GROUP/#UNIT)
-- @param #DCAF.TTSChannel tts - (optional) initializes the TTS channel used to transmit verbal reports
function DCAF.Recon:New(group, tts)
    local validGroup = getGroup(group)
    if not validGroup then
        return Error("DCAF.Recon:New :: could not resolve `group`") end

    Debug(DCAF.Recon.ClassName .. ":New :: creates recon group: " .. group.GroupName)
    local recon = DCAF.clone(DCAF.Recon)
    recon.Group = validGroup
    recon.Coalition = Coalition.Resolve(recon.Group)
    recon.CoalitionHostile = GetHostileCoalition(recon.Coalition)
    recon._tts = tts
    return recon
end

--- Creates and returns a new #DCAF.Recon object with the AI switched off until :Start is invoked
-- @param #Any group - a source for a #GROUP (can be a #GROUP, a #UNIT or the name of a #GROUP/#UNIT)
-- @param #DCAF.TTSChannel tts - (optional) initializes the TTS channel used to trabsmit verbal reports
function DCAF.Recon:NewUncontrolled(group, tts)
    local validGroup = getGroup(group)
    if not validGroup then
        return Error("DCAF.Recon:NewUncontrolled :: could not resolve `group`") end

    local recon = DCAF.clone(DCAF.Recon)
    recon.Group = validGroup
    recon.Coalition = Coalition.Resolve(recon.Group)
    recon.CoalitionHostile = GetHostileCoalition(recon.Coalition)
    recon.Group:SetAIOff()
    if not recon.Group:IsActive() then
        DCAF.delay(function()
            recon.Group:Activate()
        end, 1)
    end
    recon._isUncontrolled = true
    recon._tts = tts
    return recon
end

function DCAF.Recon:InitDefaultReportLifespan(stationary, mobile)
    if not isNumber(stationary) or stationary < 0 then return Error("DCAF.Recon:InitDefaultReportLifespan :: `stationary` must be positive number, but was: " .. DumpPretty(stationary), self) end
    if not isNumber(mobile) or mobile < 0 then return Error("DCAF.Recon:InitDefaultReportLifespan :: `mobile` must be positive number, but was: " .. DumpPretty(mobile), self) end
    DCAF_Recon_Defaults.ReportLifespan = {
        Stationary = stationary,
        Mobile = mobile,
    }
    return self
end

function DCAF.Recon:InitReportLifespan(stationary, mobile)
    if not isNumber(stationary) or stationary < 0 then return Error("DCAF.Recon:InitReportLifespan :: `stationary` must be positive number, but was: " .. DumpPretty(stationary), self) end
    if not isNumber(mobile) or mobile < 0 then return Error("DCAF.Recon:InitReportLifespan :: `mobile` must be positive number, but was: " .. DumpPretty(mobile), self) end
    self.ReportLifespan = {
        Stationary = stationary,
        Mobile = mobile,
    }
    return self
end

function DCAF.Recon:InitTTS(tts)
    self._tts = tts
    return self
end

--- Configures a dead zone for the recon object, where contacts cannot be detected
-- @param #number angle - the relative dead zone angle
function DCAF.Recon:InitDeadZone(angle)
    if not isNumber(angle) then return Error("DCAF.Recon:InitDeadZone :: `angle` must be number, but was: " .. DumpPretty(angle), self) end
    self.DeadZoneAngle = angle
    return self
end

-- --- Sets behavior to 'managed', removing the autonomy of the recon group. This will mak it possible for a human controller to specify areas to be reconnoitered by placing map markers
-- -- @param #boolean value - (optional; default=true) specifies whether the recon group is to be managed (not autonomous)
-- function DCAF.Recon:InitManaged(value)
--     if not isBoolean(value) then value = true end
--     self.IsManaged = value
--     return self
-- end

--- Sets behavior to draw detected groups on map. This can be useful for scenarios with 'thicker' Fog of War, and the miz map View Option set to "Map Only"
-- @param #Any value - (optional; default=true) Can be #boolean or #DCAF.ReconDrawOptions. Specifies whether (and how) the recon group will draw detected groups on map
function DCAF.Recon:InitDrawDetected(value)
    if value == nil then value = true end
    if isBoolean(value) then
        if value then
            self._drawOptions = DCAF.ReconDrawOptions:New()
-- Debug("nisse - DCAF.Recon:InitDrawDetected :: self._drawOptions: " .. DumpPretty(self._drawOptions))
        else
            self._drawOptions = nil
        end
        return self
    end
    if isClass(value, DCAF.ReconDrawOptions) then
        self._drawOptions = value
    else
        Error(DCAF.Recon.ClassName .. ":InitDrawDetected :: `value` must be #" .. DCAF.ReconDrawOptions.ClassName .. " or #boolean, but vas: " .. DumpPretty(value))
    end
    return self
end

function DCAF.Recon:Start(categories, radar, optical, rwr, irst, datalink)
    if not self.Group:IsActive() then
        self.Group:Activate()
    elseif self._isUncontrolled then
        self.Group:SetAIOn()
        self._isUncontrolled = nil
    end
    self.GroupName = self.Group.GroupName
    Debug("DCAF.Recon:Start :: " .. self.GroupName .. " :: radar: " .. Dump(radar) .. " :: optical: " .. Dump(optical) .. " :: rwr: " .. Dump(rwr) .. " :: irst: " .. Dump(irst) .. " :: datalink: " .. Dump(datalink))

    -- use INTEL for detection...
    local setGroup = SET_GROUP:New():AddGroup(self.Group)
    self.Intel = INTEL:New(setGroup)
    self.Intel:SetDetectionTypes(true, optical, radar, irst, rwr, datalink)
    local recon = self
    self._intel_UpdateContact = self.Intel._UpdateContact
    function self.Intel:_UpdateContact(contact)
        recon:ProcessDetected(contact)
        recon._intel_UpdateContact(recon.Intel, contact)
    end

    function self.Intel:_CheckContactLost(contact) return recon:_intelCheckContactLost(contact) end
    if isNumber(radar) then
        self.Intel:SetAcceptRange(radar / 1000)
    end
    if not categories then
        categories = { Unit.Category.GROUND_UNIT, Unit.Category.HELICOPTER }
    end
    self.Intel:SetFilterCategory(categories)
    self.Intel:__Start( 2 )
    local recon = self
    function self.Intel:OnAfterNewContact(from, event, to, contact)
-- Debug("nisse - DCAF.Recon:Start_OnAfterNewContact :: contact: " .. DumpPretty(contact))
-- local text = string.format("nisse - NEW contact %s detected by %s", contact.groupname, contact.recce or "unknown")
-- MESSAGE:New(text, 15, "KGB"):ToAll()
        recon:ProcessDetected(contact)
    end
    return self
end

function DCAF.Recon:_isContactAccepted(contact)
-- Debug("nisse - DCAF.Recon:_isContactAccepted :: group: " .. contact.group.GroupName .. " :: .Intel.RadarAcceptRangeKilometers: " .. Dump(self.Intel.RadarAcceptRangeKilometers))

    local maxRange = self.Intel.RadarAcceptRangeKilometers
    if maxRange then
        local coord = self.Group:GetCoordinate()
        if not coord then return Error("DCAF.Recon:_isContactAccepted :: coordinate could not be resolved for recon group") end
        local distance = coord:Get2DDistance(contact.position) / 1000
-- Debug("nisse - DCAF.Recon:_isContactAccepted :: distance: " .. distance .. " :: maxRange: " .. maxRange)
        if distance > maxRange then return false, "Out of range" end
    end
    if self.DeadZoneAngle then
        local aspect = self:GetAspect(contact)
-- Debug("nisse - DCAF.Recon:_isContactAccepted :: .DeadZoneAngle: " .. self.DeadZoneAngle .. " :: aspect: " .. aspect)
        if math.abs(aspect) > self.DeadZoneAngle then return false, "Azimuth too high" end
    end
    return true
end

--- Calculates a' 'aspect' heading from recon unit. Value can be between [0,180] or [0,-179]. Negative value indicates right side; positive is left side
function DCAF.Recon:GetAspect(contact)
    local hdg = self.Group:GetHeading()
    local bearing = self.Group:GetCoordinate():HeadingTo(contact.position)
    local relBearing = hdg - bearing
-- Debug("DCAF.Recon:GetAspect :: " .. DumpPretty({
--     contact = contact.group.GroupName,
--     hdg = hdg,
--     bearing = bearing,
--     relBearing1 = relBearing,
-- }))
    if relBearing < -180 then
        return relBearing + 360
    elseif relBearing > 180 then
        return relBearing - 360
    else
        return relBearing
    end
end

function DCAF.Recon:_intelCheckContactLost(contact)
    if contact.group == nil or not contact.group:IsAlive() then return true end
    if contact.isStatic then return false end
    local dT = timer.getAbsTime()-contact.Tdetected
    return dT > 60 -- self.ReportLifespan -- todo Consider making 'forget time' configurable. 1 minute seems ok for now
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
    ClassName = "Recon_GroupStatusReport",
    ----
    Text = nil,
    Group = nil,
    UnitClass = DCAF_UnitClass.Unknown,
    Coordinate = nil,
    IsStatic = false,
    Direction = nil
}

local function updateGroupStatusReport(recon, report, spoken)
    local onRoad = ""
    local group = report.Group
    if not group then return Error("updateGroupStatusReport :: report have no Group set") end
    local coordGroup = group:GetCoordinate()
    local speed = group:GetVelocityMPS()
    local direction = CardinalDirection.FromHeading(group:GetHeading())
    local group = report.Group
-- Debug("nisse - updateGroupStatusReport :: group: " .. report.Group.GroupName .. " :: report: " .. DumpPretty(report))
    if group:IsGround() then
        local distRoad = coordGroup:Get2DDistance(coordGroup:GetClosestPointToRoad())
        if distRoad < 4 then
            onRoad = "On road. "
        end
        if speed < 2 then
            return report:Update(recon, onRoad .. "Stationary", true)
        end
        if speed <= 8.5 then  -- ~30 km/h
            speed = "Slow. "
        elseif speed > 15.5 then
            speed = "Fast. "
        else
            speed = ""
        end
        return report:Update(recon, onRoad .. "Heading " .. direction .. ". " .. speed .. ".", false, direction)
    end
    if group:IsShip() then
        if speed <= .5 then
            return report:Update(recon, "Moored. ", group, true)
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
        return report:Update(recon, "Tracking " .. direction .. ". " .. speed .. " " .. onRoad .. ".", false, direction)
    end
    if not group:IsAir() then
        return "" end

    local altitude = ""
    local isOnGround = IsOnGround(group)
    local isParked = false
-- Debug("nisse - updateGroupStatusReport :: group: " .. group.GroupName .. " :: speed: " .. speed)
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
    local altMSL = group:GetAltitude(false)
    if altMSL then
        altitude = math.floor(UTILS.MetersToFeet(altMSL)) .. " feet"
        if spoken then 
            onRoad = " feet"
        else
            onRoad = " ft"
        end
    end
    return report:Update(recon, "Tracking " .. direction .. ". " .. speed .. ". " .. altitude .. " " .. onRoad .. ".", isParked, direction)
end

function Recon_GroupStatusReport:New(recon, group, spoken)
    local report = DCAF.clone(Recon_GroupStatusReport)
    report.Group = group
    report.GroupName = group.GroupName
    report.Category = GetGroupType(group)
-- Debug("nisse - Recon_GroupStatusReport:New :: report: " .. DumpPretty(report))
    return updateGroupStatusReport(recon, report, spoken)
end

function Recon_GroupStatusReport:Update(recon, text, isStationary, direction)
    self.Text = text
    local group = self.Group
    self.Coordinate = group:GetCoordinate()
    self.UnitClass = ResolveGroundGroupClass(group)
    self.IsStationary = isStationary
    self.Direction = direction
    self.TimeSeconds = UTILS.SecondsOfToday()
    self.TimeClock = UTILS.SecondsToClock(self.TimeSeconds, true)
    if isStationary then
        self.Lifespan = recon.ReportLifespan.Stationary
    else
        self.Lifespan = recon.ReportLifespan.Mobile
    end
    return self
end

function Recon_GroupStatusReport:HasMoved(minimumDistance)
    return self.Coordinate:Get2DDistance(self.Group:GetCoordinate()) >= minimumDistance
end

function DCAF.Recon:Send(message)
    if isAssignedString(message) and self._tts then
        self._tts:Send(message)
    end
end

function DCAF.Recon:OnDetectedDefault(group)
-- Debug("nisse - DCAF.Recon:OnDetectedDefault :: group: " .. group.GroupName .. " :: ._reports: " .. DumpPretty(self._reports))
    local report = self:SubmitReport(Recon_GroupStatusReport:New(self, group, spoken))
    local ident = self:GetGroupReportingName(group)
    if self._tts then
        if not ident then
            return end

        self._tts:Send("[CALLSIGN]. Contact. " .. self:GetReportBullseye(group, ident) .. report.Text)
    end
    if self._drawOptions then
        self:OnDrawDetected(report, ident)
    end
end

function DCAF.Recon:OnRefineReport(report)
    -- TODO allow actual refinement, such as adding group strength etc. to the report as the same groups keeps getting 'detected'
    -- for now, just redraw the icons and text with full alpha...
    updateGroupStatusReport(self, report)
    if self._drawOptions then
        report:Draw(self, report._ident, true, true, true)
    end
    return self
end

function DCAF.Recon:OnDrawDetected(report, ident)
    report:Draw(self, ident, true, true, true)
    report._ident = ident
-- Debug("nisse - DCAF.Recon:OnDrawDetected :: ident: " .. Dump(ident) .. " :: report: " .. DumpPretty(report) .. " :: ._drawOptions: " .. DumpPretty(self._drawOptions))
    return self
end

function Recon_GroupStatusReport:_drawNatoHostileFrame()
end

function Recon_GroupStatusReport:Draw(recon, ident, icon, vector, text, alpha)
    self:Erase(icon, vector, text)
    if self._isShredded then return end

    if not alpha then alpha = 1 end
    local options = recon._drawOptions
    if alpha > options.MaxAlpha then alpha = options.MaxAlpha end
    local radius = options.IconRadius
    local coord0 = self.Coordinate
    if not coord0 then return Error("Recon_GroupStatusReport:Draw :: report contains no coordinate") end
    local coord1 = coord0:Translate(radius, 360)
    local coord2 = coord0:Translate(radius, 90)
    local coord3 = coord0:Translate(radius, 180)
    local coord4 = coord0:Translate(radius, 270)
    -- todo Make colors etc. based on coalition?

    local colorStroke = Color.Black
    local colorFill = Color.NatoHostile
    local BLU = coalition.side.BLUE
    if vector and not self.IsStationary then
        local heading = CardinalDirection.ToHeading(self.Direction)
        local coordEnd = coord0:Translate(radius * 1.5, heading)
        self._drawVectorID = coord0:LineToAll(coordEnd, BLU, colorStroke, alpha, nil, false)
    end
    if icon then
        self._drawIconBackgroundID = coord1:QuadToAll(coord2, coord3, coord4, BLU, colorStroke, alpha, colorFill, alpha, nil, false)
    end
    local text = (self.UnitClass or "(?)") .. " - " .. self.Text
    if isAssignedString(ident) then text = ident .. ". " .. text end
    text = text .. " | " .. self.TimeClock
    self._drawTextID = coord2:Translate(radius * .5, 90):TextToAll(' ' .. text .. ' ', BLU, options.TextColor, alpha, options.TextFillColor, alpha, options.FontSize or 10, false)
    self:AgeProcessBegin(recon)
    return self
end

function Recon_GroupStatusReport:Erase(icon, vector, text)
    if not isBoolean(icon) then icon = true end
    if not isBoolean(vector) then vector = true end
    if not isBoolean(text) then text = true end
    if icon and self._drawIconBackgroundID then
        COORDINATE:RemoveMark(self._drawIconBackgroundID)
        self._drawIconBackgroundID = nil
    end
    if vector and self._drawVectorID then
        COORDINATE:RemoveMark(self._drawVectorID)
    end
    if text and self._drawTextID then
        COORDINATE:RemoveMark(self._drawTextID)
        self._drawTextID = nil
    end
end

function Recon_GroupStatusReport:AgeProcessBegin(recon)
    if self._ageProcessCheduleID then return end
    local report = self
-- Debug("nisse - Recon_GroupStatusReport:AgeProcessBegin :: report: " .. DumpPretty(report))
    self._ageProcessCheduleID = DCAF.startScheduler(function()
        -- fade the drawings over time...
        local lifespan = self.Lifespan
        local now = UTILS.SecondsOfToday()
        local timeout = report.TimeSeconds + lifespan
        local timeRemaining = timeout - now
-- Debug("nisse - Recon_GroupStatusReport:AgeProcessBegin_scheduler :: timeRemaining: " .. timeRemaining)
        if timeRemaining <= 0 then
-- Debug("nisse - Recon_GroupStatusReport:AgeProcessBegin_scheduler :: ends ageing / removes drawings")
            recon:RemoveReport(report)
            report:AgeProcessEnd(true)
            return
        end
        local alpha = timeRemaining / lifespan
-- Debug("nisse - Recon_GroupStatusReport:AgeProcessBegin_scheduler :: alpha: " .. alpha)
        report:Draw(recon, report._ident, true, true, true, alpha)
    end, 60)
end

function Recon_GroupStatusReport:AgeProcessEnd(shred)
    if not self._ageProcessCheduleID then
-- Debug("nisse - Recon_GroupStatusReport:AgeProcessEnd :: no scheduler ID")
        return
    end
-- Debug("nisse - Recon_GroupStatusReport:AgeProcessEnd :: ends ageing process")
    pcall(function() DCAF.stopScheduler(self._ageProcessCheduleID) end)
    self._ageProcessCheduleID = nil
    self._isShredded = shred
end

function DCAF.Recon:OnDetected(func)
    if not isFunction(func) then
        Error("Recon:OnDetected :: `func` must be function, but was: " .. DumpPretty(func))
        return self
    end
    self._onDetectedFunc = func
    return self
end

function DCAF.Recon:ProcessDetected(contact)
-- Debug("nisse - Recon:ProcessDetected :: contact: " .. DumpPretty(contact))
    self._reports = self._reports or {}
    local group = contact.group
    local isAccepted, reason = self:_isContactAccepted(contact)
-- if self.Group.GroupName == "Ground-Caiman-Convoy" then
-- Debug("nisse - Recon:ProcessDetected :: group: " .. group.GroupName .. " :: self._reports: " .. DumpPretty(self._reports))
-- end
    if not isAccepted then
-- Debug("nisse - Recon:ProcessDetected :: contact: " .. DumpPretty(contact) .. " :: was rejected :: reason: " .. Dump(reason))
        return
    end
    local coalition = Coalition.Resolve(group)
    if coalition ~= self.CoalitionHostile then
        return self end

    local now = UTILS.SecondsOfToday()
    local oldReport = self._reports[group.GroupName]
    if oldReport then
-- Debug("nisse - Recon:ProcessDetected :: now: " .. now .. " :: group: " .. group.GroupName .. " :: oldReport: " .. DumpPretty(oldReport))
        if now < oldReport.TimeSeconds + oldReport.Lifespan then
            if isFunction(self._onRefineReport) then
                self._onRefineReport(self, group, oldReport)
            else
                self:OnRefineReport(oldReport)
            end
            return
        end

        if not oldReport.Group:IsGround() or not oldReport:HasMoved(NauticalMiles(2)) then
            return end
    end

    if isFunction(self._onDetectedFunc) then
        self._onDetectedFunc(self, group)
    else
        self:OnDetectedDefault(group)
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
-- Debug("nisse - DCAF.Recon:SubmitReport :: report: " .. DumpPretty(report))
    self._reports[report.GroupName] = report
    return report
end

function DCAF.Recon:RemoveReport(report)
-- Debug("nisse - DCAF.Recon:RemoveReport :: report: " .. DumpPretty(report) .. " :: SS: " .. DCAF.StackTrace())
    self._reports[report.GroupName] = nil
    report:Erase(true, true, true)
    return self
end

function DCAF.Recon:Tune(frequency, modulation)
    if self._tts then
        self._tts:Tune(frequency, modulation)
    end
    return self
end

Trace("\\\\\\\\\\ DCAF.Recon.lua was loaded //////////")
