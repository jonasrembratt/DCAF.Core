--- /////////////////////////////////////////////////
--- This emulates a SAM site that makes a mistake and causes a fratricide (or a near-miss)

DCAF.GBAD.FratricideRisk = {
    Oups = "Oups",             -- missile is fired but is neutralized almost immediately
    Sweat = "Sweat",           -- missile is neutralized about half way to target
    CloseShave = "CloseShave", -- missile is neutralized a few moments before impact
    Disaster = "Disaster"      -- missile is not neutralized and may hit
}

DCAF.GBAD.Fratricide = {
    ClassName = "DCAF.GBAD.Fratricide",
    ----
    Risk = DCAF.GBAD.FratricideRisk.Sweat,      -- specifies behavior (unless set to Disaster, missiles will be destroyed before they are allowed to impact target)
    MaxEngagements = 2,                         -- specifies no. of engagement (missiles being launched at targets) before 'incident' is cancelled
}

function DCAF.GBAD.Fratricide:New(samGroup, activate)
    local self = DCAF.clone(DCAF.GBAD.Fratricide)
    self.Group = getGroup(samGroup)
    if not self.Group then
        return Error("SAM_Fratricide:New :: could not resolve `samGroup`: " .. DumpPretty(samGroup)) end

    self.HostileTemplate = self.Group:GetTemplate()
    self.FriendlyCoalition = self.Group:GetCoalition()
    local hostileCoalition = GetHostileCoalition(self.FriendlyCoalition)
    self.FratCoalition = Coalition.Resolve(hostileCoalition, true)
    self.HostileTemplate.SpawnCoalitionID = self.FratCoalition
    self.HostileTemplate.CoalitionID = self.FratCoalition
    self.HostileTemplate.CountryID = DCAF.DefaultCountries.CountryIDs[self.FratCoalition]
    self.HostileTemplate.SpawnCountryID = self.HostileTemplate.CountryID
    self.FriendlySpawn = getSpawn(self.Group.GroupName)
    if not isBoolean(activate) then
        activate = true
    end
-- Debug("nisse - DCAF.GBAD.Fratricide:New :: .IsActive: " .. Dump(self.Group:IsActive()) .. " :: .HostileTemplate: ".. DumpPrettyDeep(self.HostileTemplate, 1))
    if not self.Group:IsActive() and activate ~= false then
        self.Group:Activate()
    end
    return self
end

local function DCAF_GBAD_Resolve_FratricideRisk(value, default)
    if value == nil then return default end
    for _, v in pairs(DCAF.GBAD.FratricideRisk) do
        if v == value then return value end
    end
    return default
end

function DCAF.GBAD.Fratricide:InitRiskLevel(value)
    local validRisk = DCAF_GBAD_Resolve_FratricideRisk(value)
    if not validRisk then return Error("DCAF.GBAD.Fratricide:InitRisk :: `value` is not a valid #DCAF.GBAD.FratricideRisk value :: IGNORES") end
    self.RiskLevel = validRisk
    return self
end

function DCAF.GBAD.Fratricide:InitMaxEngagements(value)
    if not isNumber(value) then return Error("DCAF.GBAD.Fratricide:InitCountMaxEngagements :: `value` must be number, but was: " .. DumpPretty(value)) end
    self.MaxEngagements = value
    return self
end

function DCAF.GBAD.Fratricide:SwapHostile()
    local spawn = SPAWN:NewFromTemplate(self.HostileTemplate, self.Group.GroupName .. "(i)")
    self.Group:Destroy()
    self.FratGroup = spawn:Spawn()
    self.FratGroup:SetCommandInvisible(true)
    self.FratGroup:OptionROE(ENUMS.ROE.WeaponFree)
    self.FratGroup:OptionAlarmStateRed()
    return self
end

function DCAF.GBAD.Fratricide:SwapFriendly()
    local spawn = self.FriendlySpawn
    self.FratGroup:Destroy()
    self.FratGroup = nil
    self.Group = self.FriendlySpawn:Spawn()
    return self
end

local function gbadFratricide_ManageEngagements(me)
    -- track weapon ...
    me.WpnTracker = DCAF.WpnTracker:New(me.FratGroup.GroupName):Start()
    me.CountEngagements = 0
    me.Weapons = {
        -- list of weapon ids
    }

    function me.WpnTracker:OnUpdate(track)
        if not me.FratGroup then return end -- incident has ended
        if track.IniGroup.GroupName ~= me.FratGroup.GroupName then return end -- we don't care about this track
        local function killWeapon(value, distance)
            if value then
                track:ExplodeWeapon()
            end
            if not me.Weapons[track.ID] then
                me.Weapons[track.ID] = track
                me.CountEngagements = me.CountEngagements+1
            end
Debug("nisse - me.WpnTracker:OnUpdate_killWeapon :: distance: " .. Dump(distance) .. " :: CountEngagements: " .. Dump(me.CountEngagements))
            if me.CountEngagements == me.MaxEngagements then
                me:End()
            end
        end
        if me.RiskLevel == DCAF.GBAD.FratricideRisk.Oups then
            local distanceFlown = track:GetDistanceFlown()
            if distanceFlown > 200 then
                killWeapon(true, distanceFlown)
            end
        elseif me.RiskLevel == DCAF.GBAD.FratricideRisk.Sweat then
            -- let weapon get to about half way to target
            local distanceToTgt = track:GetDistanceToTarget()
            local distanceFlown = track:GetDistanceFlown()
-- Debug("nisse - me.WpnTracker:OnUpdate :: Sweat :: distanceToTgt: " .. Dump(distanceToTgt)  .. " :: distanceFlown: " .. Dump(distanceFlown))
            if distanceFlown >= distanceToTgt then
                killWeapon(true, distanceToTgt)
            end
        elseif me.RiskLevel == DCAF.GBAD.FratricideRisk.CloseShave then
            local distanceToTgt = track:GetDistanceToTarget()
-- Debug("nisse - me.WpnTracker:OnUpdate :: CloseShave :: distanceToTgt: " .. Dump(distanceToTgt))
            if distanceToTgt < 500 then
                killWeapon(true, distanceToTgt)
            end
        elseif me.RiskLevel == DCAF.GBAD.FratricideRisk.Disaster then
            local distanceToTgt = track:GetDistanceToTarget()
            if distanceToTgt < 500 then
                killWeapon(false, distanceToTgt)
            end
        end
    end
end

local function gbadFratricide_Start(me, target, targetTriggerRange)
    if target == nil then
        me:SwapHostile()
        me.FratGroup:OptionROEWeaponFree()
        gbadFratricide_ManageEngagements(me)
        return
    end

    -- target specific GROUP or UNIT...
    if not isAssignedString(target) and not isGroup(target) and not isUnit(target) and not isFunction(target) then
        return Error("DCAF.GBAD.Fratricide :: `target`must be string, UNIT, GROUP, or function, but was: " .. DumpPretty(target)) end

    -- defer from activating the 'incident' until target is in range
    if not isNumber(targetTriggerRange) then
        targetTriggerRange = DCAF.GBAD:QueryRange(me.Group) or NauticalMiles(20)
    end
    me.ScanScheduleID = DCAF.startScheduler(function()
        local function isMatch(info)
            if isFunction(target) then
                return target(info)
            end
            if isUnit(target) and info.Unit.UnitName == target.UnitName then
                return true, true
            end
            if isGroup(target) then 
                return info.Unit.GroupName == target.GroupName
            end
            local pattern = string.gsub(target, "(%-)", "%%-")
            if string.find(info.Unit.UnitName, pattern) then return true, true end
            return string.find(info.Unit:GetGroup().GroupName, pattern)
        end

        local closestUnits = ScanAirborneUnits(me.Group, targetTriggerRange, me.FriendlyCoalition, false)
        if not closestUnits:Any() then return end
        for _, info in pairs(closestUnits.Units) do
            local match, isUnitTarget = isMatch(info)
            if match then
                DCAF.stopScheduler(me.ScanScheduleID)
                me:SwapHostile()
                me.FratGroup:OptionROEOpenFirePossible()
                me.FratGroup:OptionAlarmStateRed()
                if isUnitTarget then
Debug("nisse - DCAF.GBAD.Fratricide :: attacks unit: " .. info.Unit.UnitName)
                    me.FratGroup:PushTask(me.FratGroup:TaskAttackUnit(info.Unit))
                else
Debug("nisse - DCAF.GBAD.Fratricide :: attacks group: " .. info.Unit:GetGroup().GroupName)
                    me.FratGroup:PushTask(me.FratGroup:TaskAttackGroup(info.Unit:GetGroup()))
                end
                if me.RiskLevel == DCAF.GBAD.FratricideRisk.Disaster then return end -- for 'Disaster' we don't need to track launched missiles
                gbadFratricide_ManageEngagements(me)
                return
            end
        end
    end, 5)
end

--- Starts 'incident' - swaps to hostile coalition and manages weapons fired at "own" coalition
-- @param #number delay - (optional) 
-- @param #Any target - (optional) A target unit/group to attack. This can be a string (name pattern) or an actual #UNIT/#GROUP object
-- @param #Any target - (optional, and only used if `target` is also passed) A max range to scan for the target. Only when inside of this range, will the incident trigger
function DCAF.GBAD.Fratricide:Start(delay, target, targetTriggerRange)
    if isNumber(delay) then
        DCAF.delay(function()
            gbadFratricide_Start(self, target, targetTriggerRange)
        end, delay)
    else
        gbadFratricide_Start(self, target, targetTriggerRange)
    end
end

function DCAF.GBAD.Fratricide:End()
    self:SwapFriendly()
end