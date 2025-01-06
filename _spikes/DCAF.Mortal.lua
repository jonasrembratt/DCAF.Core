--[[///////////////////////////////////////////////////////////////////////////////////////////////////////////
# DCAF.Mortal

## KONCEPT
Unlike human actors DCS groups behave like they are immortal, or berserks, fighting till the last unit is dead.
This class implements a very simple 'morale check' for such groups, making them break and retreat, or surrender,
when the loss rate for the unit exceeds some threshold value.

## USE
To create a 'mortal' group, just invoke the DCAF.Mortal:New() function, passing the group and, optionally, the
loss threshold expressed as a decimal value between 0 and 1. As an excample, this artillery unit will break and
surrender when the loss ration exceeds 35%: DCAF.Mortal:New("BLU Arty-1", .35). As losses exceeds the specified 
35% all units will simply become immobile, and become invisible to other AI. This is to simulate they are no
longer participating in the battle. By removing the AI controller from the broken group, server resources are
also preserved. Adding "mortal behavior" to groups like this might therefore be beneficial to server performance.

## BREAKING
As the group breaks the DCAF.Mortal:OnBreaks() function will always be called. The default implementation is
to either retreat (when one or more retreat locations have been set; see below) or surrender (also see below).
You can override this function if you want to implement your own custom behavior:

```lua
local mortalRecon = DCAF.Mortal:New("BLU Scout / Jackal 9")
function mortalRecon:OnBreaks()
    runAroundInCirclesCryingForMom(self.Group)
end
```

## RETREATING
You can have the group retreating to specified locations as it breaks by invoking the :InitRetreat function.
Just pass one or more locations to be used as "retreat points". The locations can be passed as:

- Names of locations (zones, airbases, other groups/units, etc.)
- #DCAF.Location(s)
- AIRBASE(s)
- GROUP(s)
- UNIT(s)
- A named waypoint (mu)

In this example the mortal group will flee to the closest destination of three specified locations:
```lua
DCAF.Mortal:New("BLU Scout / Jackal 9")
            :InitRetreat("ZN FARP Oslo", "BLU BTN Area-1", "WP:RETREAT_HERE")
```            

The above example the "ZN FARP Oslo" is an invisible FARP (#AIRBASE), "BLU BTN Area-1" is a #ZONE, and the
"WP:RETREAT_HERE" is a waypoint in the group's route given the name "RETREAT_HERE".

When retreating the group will navigate an offroad route by default. You can override this behavior by calling
```lua
DCAF.Mortal:InitRetreatOnRoads():
DCAF.Mortal:New("BLU Scout / Jackal 9")
           :InitRetreat({ "ZN FARP Oslo", "BLU BTN Area-1", "WP:RETREAT_HERE" })
           :InitRetreatOnRoads()
```

Also, by default, the group will retreat at maximum possible speed (default is set to 100 Km/h). You can set
a custom retreat speed using the InitRetreatSpeed, like in this exampe (sets to 40 Km/h):
```lua
DCAF.Mortal:New("BLU Scout / Jackal 9")
           :InitRetreat({ "ZN FARP Oslo", "BLU BTN Area-1", "WP:RETREAT_HERE" })
           :InitRetreatSpeed(40)
```

Finally, when a group initiates a retreat, it will always invoke the `DCAF.Mortal:OnRetreating()` function. 
This function can be overridden if needed. The default function does not implement anything at this time.           

SURRENDERING
As explained; by default, when a group takes too much losses it breaks. if non retreat locations have been 
specified, it will simply surrender. The default implementation to this is to simply turn off the AI 
controller and make the group "invisible" to other AI units. This has the effect of leaving the broken
group where it is, and it will no longer be engaging or get engaged by OPFOR. If you prefer a different
behavior just override the `DCAF.Mortal:OnSurrender()` function.
]]

DCAF.Mortal = {
    ClassName = "DCAF.Mortal",
    ----
    BreakThreshold = .6,
    RetreatOnRoads = false,
    RetreatSpeed = 100,     -- Km/h
    Group = nil,            -- #GROUP
    GroupName = nil,        -- #GROUP.GroupName
}

--- Creates and returns a #DCAF.Mortal
function DCAF.Mortal:New(source, breakThreshold)
    local validGroup = getGroup(source)
    if not validGroup then
        if isClass(source, DCAF.Convoy) then
            validGroup = source
        else
            return Error("DCAF.Mortal:New :: cannot resolve `group`: " .. DumpPretty(source))
        end
    end
    if isClass(validGroup._mortal, DCAF.Mortal) then Error("DCAF.Mortal:New :: group was already made mortal: : " .. validGroup.GroupName) end

    if breakThreshold ~= nil then
        if not isNumber(breakThreshold) then
            Error("DCAF.Mortal:New :: `breakAtLossRatio` must be number, but was: " .. DumpPretty(breakThreshold))
            breakThreshold = nil
        elseif breakThreshold < 0 or breakThreshold > 1 then
            Error("DCAF.Mortal:New :: `breakAtLossRatio` must be number, but was: " .. DumpPretty(breakThreshold))
            breakThreshold = nil
        end
    end

    local mortal = DCAF.clone(DCAF.Mortal)
    validGroup._mortal = mortal
    mortal.Group = validGroup
    mortal.GroupName = validGroup.GroupName
    mortal.BreakThreshold = breakThreshold or mortal.BreakThreshold
    mortal._countDetectedLoss = 0
    mortal._lifeLastCheck = 0
    mortal._lifeStart = mortal:_getLife()
    mortal._lifeLastCheck = mortal._lifeStart
    mortal._schedulerID = DCAF.startScheduler(function()
-- Debug("nisse - DCAF.Mortal_scheduler :: " .. group.GroupName .. " :: _schedulerID: " .. Dump(mortal._schedulerID))
        if not mortal._schedulerID then return end
        mortal:_monitorMorale()
    end, 4)
    return mortal
end

function DCAF.Mortal:End()
    if self._schedulerID then
        DCAF.stopScheduler(self._schedulerID)
        self._schedulerID = nil
    end
end

function DCAF.Mortal:GetFrom(obj)
    if obj and isClass(obj._mortal, DCAF.Mortal) then return obj._mortal end
end

function DCAF.Mortal:InitRetreat(...)
    if #arg == 0 then
        Error("DCAF.Mortal:InitRetreat :: no retreat location(s) was specified")
        return self
    end

    local resolvedLocations = {}
    for i, loc in ipairs(arg) do
        if stringStartsWith(loc, "WP:") then
            local wpName = string.sub(loc, 4)
            local wp = FindWaypointByName( getGroupRoute(self.Group), wpName)
            if not wp then
                Error("DCAF.Mortal:InitRetreat :: location #" .. i .. " implies a named waypoint but no such waypoint was found in route: '" .. wpName .. "'")
            else
                local coord = COORDINATE:NewFromVec2(wp)
                resolvedLocations[#resolvedLocations+1] = DCAF.Location:NewNamed(loc, coord)
            end
        else
            local validLocation = DCAF.Location.Resolve(loc)
            if validLocation then
                resolvedLocations[#resolvedLocations+1] = validLocation
            else
                Error("DCAF.Mortal:InitRetreat :: location #" .. i .. " cannot be resolved: '" .. DumpPretty(loc) .. "'")
            end
        end
    end
    self.RetreatLocations = resolvedLocations
    return self
end

function DCAF.Mortal:InitRetreatSpeed(kmh)
    if isNumber(kmh) and kmh > 0 then
        self.RetreatSpeed = kmh
    else
        Error("DCAF.Mortal:InitRetreatSpeed :: `kmh` must be a positive number, but was: " .. DumpPretty(kmh))
    end
    return self
end

function DCAF.Mortal:InitRetreatOnRoads(value)
    if isBoolean(value) then
        self.RetreatOnRoads = value
    else
        self.RetreatOnRoads = true
    end
    return self
end

local function getClosestRetreatLocation(mortal)
    local coordOwn = mortal.Group:GetCoordinate()
-- Debug("nisse - DCAF.Mortal / getClosestRetreatLocation :: coordOwn: " .. Dump(coordOwn) .. " :: .RetreatLocations: " .. DumpPrettyDeep(mortal.RetreatLocations, 2))
    if not coordOwn or not mortal.RetreatLocations then return end
    local closestDistance = 99999999
    local closestLocation
-- Debug("nisse - DCAF.Mortal/getClosestRetreatLocation :: mortal.RetreatLocations: " .. DumpPretty(mortal.RetreatLocations))
    for _, loc in ipairs(mortal.RetreatLocations) do
-- Debug("nisse - DCAF.Mortal/getClosestRetreatLocation :: loc: " .. DumpPrettyDeep(loc.Coordinate, 1))
        local coord = loc:GetCoordinate()
        local distance = coordOwn:Get2DDistance(coord)
        if distance < closestDistance then
            closestDistance = distance
            closestLocation = loc
        end
    end
    return closestLocation
end

function DCAF.Mortal:Break()
    if self.IsBroken then return self end
    self.IsBroken = true
    if self:IsAlive() then
        self.Group:OptionROEHoldFire()
    end
    self.IsBroken = true
    pcall(function() self:OnBreaks() end)
    return self
end

function DCAF.Mortal:OnBreaks()
    local retreatLocation = getClosestRetreatLocation(self)
    if not retreatLocation then
        -- no retreat location specified/resolved, just surrender...
        self:OnSurrender()
        return self
    end
    return self:Retreat(retreatLocation)
end

function DCAF.Mortal:Surrender()
    Debug(self.ClassName..":Surrender :: " .. self.GroupName .. " surrenders")
    return self:OnSurrender()
end

function DCAF.Mortal:Retreat(location, speed)
    Debug(self.ClassName..":Retreat :: " .. self.GroupName .. " :: location: " .. DumpPretty(location) .. " :: speed: " .. DumpPretty(speed))
    local coord = self.Group:GetCoordinate()
    if not coord then return self end
    location = location or getClosestRetreatLocation(self)
    if not location then 
        return Error("DCAF.Mortal:Retreat :: cannot resolve closest retreat location :: group: " .. self.Group.GroupName .. " :: IGNORES", self)
    end
    speed = speed or self.RetreatSpeed
    if self.RetreatOnRoads then
        self.Group:RouteGroundOnRoad(location:GetCoordinate(), speed)
    else
        self.Group:RouteGroundTo(location:GetCoordinate(), speed)
    end
    pcall(function() self:OnRetreats(location) end)
    return self
end

function DCAF.Mortal:OnRetreats(location)
    -- todo
end

function DCAF.Mortal:OnSurrender()
    self.Group:SetAIOff()
    self.Group:CommandSetInvisible(true)
    return self
end

function DCAF.Mortal:OnLoss(countLoss)
    -- to be overridden
end

function DCAF.Mortal:_getLife()
    local life = 0
    local units = self.Group:GetUnits()
    if not units then
        if self._lifeLastCheck > 0 then
            self._countDetectedLoss = self._countDetectedLoss + 1
        end
        self._lifeLastCheck = 0
        return 0
    end
    for _, unit in ipairs(units) do
        life = life + unit:GetLife()
    end
    if life < self._lifeLastCheck then
        self._countDetectedLoss = self._countDetectedLoss + 1
        self:OnLoss(self._countDetectedLoss)
    end
    self._lifeLastCheck = life
    return life
end

function DCAF.Mortal:GetRelativeLife()
    return self:_getLife() / self._lifeStart
end

function DCAF.Mortal:IsAlive()
    return Group.getByName( self.GroupName ) and self.Group:IsAlive()
end

function DCAF.Mortal:_monitorMorale()
    local function breakNow()
        self:End()
        self:OnBreaks()
        return self
    end
    if not self:IsAlive() or self:GetRelativeLife() <= self.BreakThreshold then return breakNow() end
end