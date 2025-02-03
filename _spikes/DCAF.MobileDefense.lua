--- /////////////////////////////////////////////
--- Allow moile ground units to stop and deploy MANPADS for protection, when threatened

--- When "wrapping" a group, it will make it stop and deploy one or more MANPADS when it detects a threat within range

local function getSpawnsWithPrefix(prefix, count)
    local list = {}
-- Debug("nisse - getSpawnsWithPrefix :: prefix: " ..prefix)
    for _, group in pairs(_DATABASE.GROUPS) do
        if stringStartsWith(group.GroupName, prefix) then
-- Debug("nisse - getSpawnsWithPrefix :: group.GroupName: " .. group.GroupName .. " :: ")
            list[#list+1] = getSpawn(group.GroupName)
        end
    end
    if #list == 0 then
        return list end

    local randomSpawns = {}
    while #randomSpawns < count do
        for idx, group in ipairs(list) do
            if math.random(1000) < 20 then
                randomSpawns[#randomSpawns+1] = group
                break
            end
        end
    end
    return randomSpawns
end

local DCAF_MobileGroupDefense_Defaults = {
    DefendersTemplatePrefix = "RED Mobile Defense"
}

DCAF.MobileDefense = {
    ClassName = "DCAF.MobileDefense",
    ---------------
    GroupName = nil,     -- group name of mobile group
    DefendersTemplatePrefix = DCAF_MobileGroupDefense_Defaults.DefendersTemplatePrefix,
    SpawnDefenders = {}, -- #list of #SPAWN
    Defenders = {}   -- #list of #GROUP (empty when not defending)
}

local function isThreatInRange(md, threatUnits)
    local maxRange, maxAltitude = md:GetEffectiveRange(threatUnits)
    local coord = md.Group:GetCoordinate()

    local function isInAltitudeRange(threatUnit)
        local relativeAltitude = threatUnit:GetAltitude(true) - md.Group:GetAltitude(true)
-- Debug("nisse - isThreatInRange :: relativeAltitude: " .. UTILS.MetersToFeet(relativeAltitude))
        return relativeAltitude < maxAltitude
    end

    for _, unit in pairs(threatUnits) do
        if coord:Get2DDistance(unit:GetCoordinate()) > maxRange then
            return false end

        if (unit:IsAirPlane() or unit:IsHelicopter()) and isInAltitudeRange(unit) then
            return unit end
    end
end

function DCAF.MobileDefense:_removeDefenderSpawn(defender)
    local idx = tableIndexOf(self.SpawnDefenders, defender._spawn)
    if not idx then
        error("WTF?! nisse") end

    table.remove(self.SpawnDefenders, idx)
end

function DCAF.MobileDefense:Defend(threatUnit)
    self._isDefending = true
    self.Group:OptionAlarmStateRed()
    -- gwm.Group:RelocateGroundRandomInRadius(nil, 300)

-- Debug("nisse - DCAF.MobileDefense:Defend :: self.SpawnDefenders: " .. DumpPretty(self.SpawnDefenders))

    local function monitorDefendersHealth(defender)
        self._defenderHitEventID = defender:HandleEvent(EVENTS.Hit)
        function defender:OnEventHit(evt)
            local lifeRemaining = evt.TgtUnit:GetLife() / evt.TgtUnit:GetLife0()
-- Debug("nisse - DCAF.MobileGroupDefense:Defend_monitorDefendersHealth_hit :: lifeRemaining: " .. lifeRemaining)
            if lifeRemaining < .5 --[[and math.random(1000) < 500]] then -- nisse - restore chance of weapon surviving randomly
                self:_removeDefenderSpawn(defender)
                defender:UnHandleEvent(self._defenderHitEventID)
            end
        end
    end

    local delayDefense = math.random(10, 30) -- todo - link deployment speed to GROUP skill level
    -- Debug(self.ClassName .. " :: " .. self.GroupName .. " has detected " .. threatUnit.UnitName .. " :: deploys defence in " .. delayDefense .. " seconds")
    DCAF.delay(function()
        for _, spawn in ipairs(self.SpawnDefenders) do
            local coord = self.Group:GetCoordinate()
    -- coord:SmokeRed() -- nisse
            local coordDefender = coord:GetRandomCoordinateInRadius(math.random(6, 40))
            local defender = spawn:SpawnFromCoordinate(coordDefender)
            defender._spawn = spawn -- needed by the health monitor
            defender:OptionAlarmStateRed()
            table.insert(self.Defenders, defender)
            monitorDefendersHealth(defender)
        end
    end, delayDefense)
    self._resumeSpeed = self.Group:GetVelocityMPS()
    self.Group:SetSpeed(0)

    local scheduleID
    -- monitor detection to remove defender and 
    scheduleID = DCAF.startScheduler(function()
        self.Detection:CreateDetectionItems()
        local updatedDetectedItems = self.Detection.DetectedItems
        if #updatedDetectedItems == 0 then
            Debug(self.ClassName .. " :: " .. self.GroupName .. " undeploys defence and continues route")
            DCAF.stopScheduler(scheduleID)
            for _, defenders in ipairs(self.Defenders) do
                defenders:Destroy()
            end
            self.Defenders = {}
            self.Group:SetSpeed(self._resumeSpeed)
            DCAF.delay(function()
                self._isDefending = false
                self:StartDetection()
            end, 1)
        end
    end, Minutes(3), Minutes(3))
end

function DCAF.MobileDefense:StartDetection()
-- Debug("nisse - DCAF.MobileGroupDefense:StartDetection...")
    local setGroup = SET_GROUP:New():AddGroup(self.Group)
    self.Detection = DETECTION_AREAS:New( setGroup ):FilterCategories({Unit.Category.HELICOPTER, Unit.Category.AIRPLANE})
    self.Detection:InitDetectVisual( true )
    -- detection:InitDetectIRST( false )
    -- detection:InitDetectOptical( true )
    -- detection:InitDetectRadar( true )
    -- detection:InitDetectRWR( true )
    self.Detection:__Start( 5 )
    local gwm = self
    function self.Detection:OnAfterDetected(from, event, to, units)
        gwm:ProcessDetectedHostiles(units)
    end
end

function DCAF.MobileDefense:ProcessDetectedHostiles(detectedUnits)
    if self._isDefending then
        return end

    local threat = isThreatInRange(self, detectedUnits)
    if threat then
        self:Defend(threat)
    end
end

--- Creates and returns a #DCAF.MobileDefense - effectively making a group able to move and stop to defend itself
-- @param #GROUP group - the #GROUP that will be able to move and stop to defend when needed
-- @param #number maxDefenders - (optional; default = 1) Maximum no. of 'defender' #GROUPs to be deployed when defending
-- @param #string prefix - (optional; DCAF_MobileGroupDefense_Defaults.DefendersTemplatePrefix) Specifies groups to be spawned when defending
function DCAF.MobileDefense:New(group, maxDefenders, prefix)
    local md = DCAF.clone(DCAF.MobileDefense)
    if not isAssignedString(prefix) then
        prefix = DCAF_MobileGroupDefense_Defaults.DefendersTemplatePrefix
    end
    md.SpawnDefenders = getSpawnsWithPrefix(prefix, maxDefenders or 1)
    md.Group = getGroup(group)
    if not md.Group then
        return Warning("DCAF.MobileDefense:New :: group not found: " .. group) end

    md.GroupName = md.Group.GroupName
    -- todo :: isThreatInRange - improve to check for defender's actual effective range
    -- md:ResolveEffectiveRange()
    md:StartDetection()
    return md
end

--- Tears down the mobile defense behavior (stops detection and automatic stop-and-defend)
-- @param #number delay - (optional) A delay in seconds before the behavior is disposed of
function DCAF.MobileDefense:Dispose(delay)
    self.Detection:__Stop(delay)
    self.Detection = nil
end

function DCAF.MobileDefense:GetEffectiveRange(threatUnits)
    -- todo DCAF.MobileDefense:GetEffectiveRange - use actual threat vs. effective range of defenders
    return NauticalMiles(3), Feet(11000)
end

--- Sets the default prefix for grousp to be used for defence
-- @param #string prefix - The prefix to be used when not stated
function DCAF.MobileDefense:SetDefaultPrefix(prefix)
    if not isAssignedString(prefix) then
        error("DCAF.MobileGroupDefense:SetDefaultDefendersPrefix :: `prefix` must be assigned string, but was: " .. DumpPretty(prefix)) end

    DCAF_MobileGroupDefense_Defaults.DefendersTemplatePrefix = prefix
end