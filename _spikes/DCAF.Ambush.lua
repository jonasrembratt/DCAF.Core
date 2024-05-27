DCAF.Ambush = {
    ClassName = "DCAF.Ambush",
    ----
    Group = nil
}

function DCAF.Ambush:New(group, delayRevealed)
    local validGroup = getGroup(group)
    if not validGroup then return Error("DCAF.Ambush:New :: cannot resolve `group`: " .. DumpPretty(group)) end
    local ambush = DCAF.clone(DCAF.Ambush)
    ambush.Group = validGroup
    ambush.Group:CommandSetInvisible(true)
    ambush.Group:HandleEvent(EVENTS.ShootingStart, function(_, e)
        if e.IniGroup and e.IniGroup.GroupName ~= ambush.Group.GroupName then return end
        ambush.Group:UnHandleEvent(EVENTS.ShootingStart)
        ambush:OnRevealed(delayRevealed)
    end)
    return ambush
end

function DCAF.Ambush:OnRevealed(delay)
    if not isNumber(delay) then delay = 0 end
    DCAF.delay(function()
        self.Group:CommandSetInvisible(false)
    end,
    delay)
end

local function setupMortal(ambush, retreatLocation, retreatOnRoads, speed)
    local mortal

    local function hookupMortalEvents()
        function mortal:OnRetreating()
            ambush:OnRetreating()
        end
        ambush._mortal = mortal
        return ambush
    end

    if DCAF.Mortal then mortal = DCAF.Mortal:GetFrom(ambush.Group) end
    if not mortal then
        mortal = DCAF.Mortal:New(ambush.Group):InitRetreat(retreatLocation, retreatOnRoads, speed)
    else
        mortal:InitRetreat(retreatLocation, retreatOnRoads, speed)
    end
    return hookupMortalEvents()
end

function DCAF.Ambush:InitRetreat(retreatLocation, retreatOnRoads, isImmortal, speed)
    if not isBoolean(isImmortal) then isImmortal = false end
    if not isImmortal then
        local mortal = setupMortal(self, retreatLocation, retreatOnRoads, getMaxSpeed)
        if mortal then return self end
    end

    self._retreat = {}
    if retreatLocation ~= nil then
        local validRetreatLocation = DCAF.Location.Resolve(retreatLocation)
        if not validRetreatLocation then
            Error("DCAF.Ambush:InitRetreat :: cannot resolve `retreatLocation`: " .. DumpPretty(retreatLocation))
        end
        retreatLocation = validRetreatLocation
        self._retreat.RetreatLocation = retreatLocation
    end
    if isBoolean(retreatOnRoads) then
        self._retreat.RetreatOnRoads = retreatOnRoads
    end
    if isNumber(speed) and speed > 0 then
        self._retreat.RetreatSpeed = speed
    end
    return self
end

function DCAF.Ambush:Retreat()
    if self._mortal then
        self._mortal:Retreat()
        return self
    end
    if not self._retreat then
        Error("DCAF.Ambush:Retreat :: retreat values (location, speed etc) has not been initialized :: IGNORES") 
        return self
    end
end

function DCAF.Ambush:OnRetreating()
end