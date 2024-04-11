-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                      DCAF.Air - Build any A-A threat, from the cockpit
--                                                Digital Coalition Air Force
--                                                          2022
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local Weapons = {
    Guns = "Guns only",
    Heaters = "IR missiles only",
    DogFight = "Guns + IR Missiles",
    Radar = "Radar missiles",
    Realistic = "RDR + IR + Guns"
}

DCAF.AirBehavior = {
    Passive = "Passive",
    Defensive = "Defensive",
    Attack = "Attack", -- curently bugged - using the GROUP:EnRouteTaskEngageGroup task, which crashes the sim (https://discord.com/channels/378590350614462464/378596030910038028/1150090900177952923x)
    CAP = "CAP"
}

DCAF.AirSkill = {
    Rookie = Skill.Average,
    Trained = Skill.High,
    Veteran = Skill.Good,
    Ace = Skill.Excellent,
    Random = Skill.Random
}

DCAF.AirDistance = {
    ["60nm"] = 60,
    ["40nm"] = 40,
    ["20nm"] = 20,
    ["10nm"] = 10,
    ["2nm"] = 2,
    ["1nm"] = 1,
    ["3000ft"] = 0.5,
    ["1000ft"] = 0.17,
}

DCAF.AirAltitude = {
    High = { Name = "High", MSL = 35000 },
    Medium = { Name = "Medium", MSL = 18000 },
    Level = { Name = "Level", MSL = 0 },
    Popup = { Name = "Popup", MSL = 500 },
}

DCAF.AirStackHeight = {
    None = { Name = "None", Feet = 0 },
    Tight = { Name = "Tight", Feet = 50 },
    Open = { Name = "Open", Feet = 1000 },
    Tall = { Name = "Tall", Feet = 20000 },
    Full = { Name = "Full", Feet = 100000 },
}

DCAF.AirGroupDistribution = {
    None = "None",
    Half = "Half",
    All = "All",
}

DCAF.AirPosition = {
    Ahead = "12 o'clock",
    Behind = "6 o'clock",
    Left = "9 o'clock",
    Right = "3 o'clock",
}

DCAF.AirBearing = {
    North = "North",
    NorthEast = "North East",
    East = "East",
    SouthEast = "South East",
    South = "South",
    SouthWest = "South West",
    West = "West",
    NorthWest = "North West",
    FromHeading = "(heading)"
}

DCAF.AirAspect = {
    Hot = "Hot",
    Cold = "Cold",
    FlankingRight = "Flanking Right",
    FlankingLeft = "Flanking Left",
}

DCAF.AirDeck = {
    High = 12000,
    MediumHigh = 10000,
    Medium = 8000,
    MediumLow = 6000,
    Low = 4000,
    VeryLow = 2000,
    None = 0
}

local _airThreatRandomization

local Spawners = { -- dictionary
    -- key    = templat name
    -- value  = #SPAWN
}

local GroupState = {
    Group = nil,
    Options = nil,
    Randomization = nil,        -- #DCAF.Air.Randomization
    Categories = { -- categorized adversaries
        -- list of #DCAF.AirCategory
    },
    Adversaries = { -- non-categorized adversaries
        -- list of #AdversaryInfo
    },
    SpawnedAdversaries = {
        -- list of #GROUP
    },
    Menus = {
        Main = nil,
        Options = nil,
        Spawn = nil
    }
}

local GroupStateDict = { -- dictionary
    -- key = group name
    -- value = #GroupState
}

local AirGroupInfo = {
    -- Spawner = nil,              -- #SPAWN
    Name = nil,                 -- #string (adversary display name)
    TemplateName = nil,         -- #string (adversary template name)
    Size = 0,                   -- #number (size of template)
}

function AirGroupInfo:Spawner()
    return Spawners:Get(self.TemplateName)
end

local _isBuildingGroupMenus
local _groupMenusGroup                  -- when set; this group is the only one that gets menus
local _airCombatGroupMenuText

local function isSpecifiedGroupForMenus(groupName)
    return _groupMenusGroup == nil or _groupMenusGroup == groupName
end

DCAF.Air = {
    ClassName = "DCAF.Air",
    IsStarted = false,
    IsBuildingGroupMenus = false,
    GroupMenuText = nil,
    Categories = { 
        -- list of #DCAF.AirCategory
    },
    Adversaries = {
        -- list of #GroupInfo
    }
}

DCAF.AirCategory = {
    ClassName = "DCAF.AirCategory",
    Name = nil,
    Group = nil,
    Options = nil,
    Adversaries = {
        -- list of #GroupInfo
    },
    SpawnedAdversaries = {
        -- list of #GROUP
    },
    Menus = {
        Main = nil,
        Options = nil,
        Spawn = nil
    }
}

DCAF.Airbase = {
    ClassName = "DCAF.Airbase",
    Name = nil,
    Group = nil,
    Options = nil,
    Adversaries = {
        -- list of #GroupInfo
    },
    SpawnedAdversaries = {
        -- list of #GROUP
    },
    Menus = {
        Main = nil,
        Options = nil,
        Spawn = nil
    }
}

DCAF.AirOptions = {
    ClassName = "DCAF.AirOptions",
    _fallback = nil,                -- #DCAF.AirOptions
    _distance = nil,                -- #number (nautical miles)
    _position = nil,                -- #DCAF.AirPosition
    _aspect = nil,                  -- #DCAF.AirAspect
    _maxOffsetAngle = nil,          -- #number (degrees)
    _altitude = nil,                -- #DCAF.AirAltitude
    _behavior = nil,                -- #DCAF.AirBehavior
    _groupDistribution = nil,       -- #DCAF.AirGroupDistribution - used when splitting a group for stacking or separation
    _stackHeight = nil,             -- #DCAF.AirStackHeight; when ~= DCAF.AirStackHeight.None, the group gets split into two groups vertically separated by specified value
}

function Spawners:Get(sTemplateName)
    local spawner = self[sTemplateName]
    if not spawner then 
        spawner = SPAWN:New(sTemplateName)
        self[sTemplateName] = spawner
    end
    return spawner
end

function DCAF.AirOptions:New(fallback)
    local options = DCAF.clone(DCAF.AirOptions)
    options._fallback = fallback or {}
    return options
end

function DCAF.AirOptions:Default()
    local options = DCAF.AirOptions:New()
    options._distance = DCAF.AirDistance["40nm"]
    options._position = DCAF.AirBearing.FromHeading
    options._aspect = DCAF.AirAspect.Hot
    options._maxOffsetAngle = 60
    options._altitude = DCAF.AirAltitude.Level
    options._behavior = DCAF.AirBehavior.Attack
    options._groupDistribution = DCAF.AirGroupDistribution.None
    options._stackHeight = DCAF.AirStackHeight.None

    -- for debugging - nisse
    -- options._groupDistribution = DCAF.AirGroupDistribution.Half
    -- options._stackHeight = DCAF.AirStackHeight.Full

    return options
end

function DCAF.AirOptions:InitAltitude(key)
    local altitude = DCAF.AirAltitude[key]
    if not altitude then return exitWarning("DCAF.AirOptions:InitAltitude :: cannot resolve altitude: " .. DumpPretty(key) .. " :: IGNORES") end
    self._altitude = altitude
    return self
end

function DCAF.AirOptions:InitDistance(key)
    local distance = DCAF.AirDistance[key]
    if not distance then return exitWarning("DCAF.AirOptions:InitDistance :: cannot resolve distance: " .. DumpPretty(key) .. " :: IGNORES") end
    self._distance = distance
    return self
end

function DCAF.AirOptions:Reset()
    self._distance = nil
    self._position = nil
    self._aspect = nil
    self._altitude = nil
    self._maxOffsetAngle = nil
    self._behavior = nil
    self._stackHeight = nil
    self._groupDistribution = nil
    return self
end

function DCAF.AirOptions:GetDistance()
    return self._distance or self._fallback._distance or 60, self._distance == nil and self._fallback._distance ~= nil
end
function DCAF.AirOptions:SetDistance(value)
    self._distance = value
    return self
end

function DCAF.AirOptions:GetPosition()
    return self._position or self._fallback._position or DCAF.AirBearing.FromHeading, self._position == nil and self._fallback._position ~= nil
end
function DCAF.AirOptions:SetPosition(value)
    self._position = value
    return self
end

function DCAF.AirOptions:GetAspect()
    return self._aspect or self._fallback._aspect or DCAF.AirAspect.Hot, self._aspect == nil and self._fallback._aspect ~= nil
end
function DCAF.AirOptions:SetAspect(value)
    self._aspect = value
    return self
end

function DCAF.AirOptions:GetMaxOffsetAngle()
    return self._maxOffsetAngle or self._fallback._maxOffsetAngle or 60, self._maxOffsetAngle == nil and self._fallback._maxOffsetAngle ~= nil
end
function DCAF.AirOptions:SetMaxOffsetAngle(value)
    self._maxOffsetAngle = value
    return self
end

function DCAF.AirOptions:GetAltitude()
    return self._altitude or self._fallback._altitude or DCAF.AirAltitude.Level, self._altitude == nil and self._fallback._altitude ~= nil
end
function DCAF.AirOptions:SetAltitude(value)
    self._altitude = value
    return self
end

function DCAF.AirOptions:GetBehavior()
    return self._behavior or self._fallback._behavior or DCAF.AirBehavior.Attack, self._behavior == nil and self._fallback._behavior ~= nil
end
function DCAF.AirOptions:SetBehavior(value)
    self._behavior = value
    return self
end

function DCAF.AirOptions:GetSkill()
    return self._skill or self._fallback._skill or DCAF.AirSkill.Trained, self._skill == nil and self._fallback._skill ~= nil
end
function DCAF.AirOptions:SetSkill(value)
    self._skill = value
    return self
end

function DCAF.AirOptions:GetGroupDistribution()
    return self._groupDistribution or self._fallback._groupDistribution or DCAF.AirGroupDistribution.None, self._groupDistribution == nil and self._fallback._groupDistribution ~= nil
end
function DCAF.AirOptions:SetGroupDistribution(value)
    self._groupDistribution = value
    return self
end

function DCAF.AirOptions:GetStack()
    return self._stackHeight or self._fallback._stackHeight or DCAF.AirStackHeight.None, self._stackHeight == nil and self._fallback._stackHeight ~= nil
end
function DCAF.AirOptions:SetStack(value)
    self._stackHeight = value
    return self
end

function DCAF.AirOptions:GetDeck()
    return self._deck or self._fallback._deck or DCAF.AirDeck.None, self._deck == nil and self._fallback._deck ~= nil
end
function DCAF.AirOptions:SetDeck(value)
    self._deck = value
    return self
end



function DCAF.AirCategory:New(sCategoryName)
    if not isAssignedString(sCategoryName) then
        error("DCAF.AirCategory:New :: `sCategoryName` must be an assigned string but was: " .. DumpPretty(sCategoryName)) end
    local cat = DCAF.clone(DCAF.AirCategory)
    cat.Name = sCategoryName
    return cat
end

function DCAF.AirCategory:WithOptions(options)
    if not isClass(options, DCAF.AirOptions.ClassName) then
        error("DCAF.AirCategory:InitOptions :: expected type '"..DCAF.AirOptions.ClassName.."' but got: " .. DumpPretty(options)) end

    self.Options = options
    return self
end

function GroupState:New(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("GroupState:New :: cannot resolve group from: " .. DumpPretty) end

    local state = DCAF.clone(GroupState)
    state.Group = forGroup
    state.Options = DCAF.AirOptions:Default()
    state.SpawnedAdversaries = {}
    state.Randomization = _airThreatRandomization
    state.Adversaries = DCAF.clone(DCAF.Air.Adversaries, false, true)
    state.Categories = DCAF.clone(DCAF.Air.Categories, true, true)
    for _, category in ipairs(state.Categories) do
        category.Group = state.Group
        if category.Options == nil then
            category.Options = DCAF.AirOptions:New(state.Options)
        else
            category.Options._fallback = state.Options
        end
    end
    GroupStateDict[forGroup.GroupName] = state
    return state
end

local SpawnGroupRole = {
    Support = "Support",
    BFM = "BFM"
}

function CONTROLLABLE:EnRouteTaskCAP()
    return {
        enabled = true,
        auto = true,
        id = "EngageTargets",
        key = "CAP",
        params = 
        {
            targetTypes =
            {
                [1] = "Air",
            },
            priority = 0
        }
    }
end

local function applyOptions(adversaryGroup, waypoint, source, adversaryDisplayName, role)
    adversaryGroup:ClearTasks()
    local task
    local isEnRouteTask = false
    local behavior = source.Options:GetBehavior()
    if behavior == DCAF.AirBehavior.Attack then
        if source.Group:IsAir() then
            if role ~= SpawnGroupRole.Support then
                task = adversaryGroup:EnRouteTaskEngageGroup(source.Group)
-- Debug("nisse - adversaryGroup:EnRouteTaskEngageGroup :: source.Group: " .. DumpPretty(source.Group) .. " :: task: " .. DumpPrettyDeep(task))
                isEnRouteTask = true
            else
                ROEDefensive(adversaryGroup)
            end
            if isAssignedString(adversaryDisplayName) then
                -- MessageTo(source.Group, adversaryDisplayName .. " attacks " .. source.Group.GroupName)
            end
        else
            task = adversaryGroup:EnRouteTaskEngageTargets()
            if isAssignedString(adversaryDisplayName) then
                -- MessageTo(source.Group, adversaryDisplayName .. " searches/engages in area")
            end
        end
    elseif behavior == DCAF.AirBehavior.CAP then
        if source.Group:IsAir() then
            if role ~= SpawnGroupRole.Support then
                task = adversaryGroup:EnRouteTaskCAP()
            else
                ROEDefensive(adversaryGroup)
            end
            -- if isAssignedString(adversaryDisplayName) then
            --     -- MessageTo(source.Group, adversaryDisplayName .. " attacks " .. source.Group.GroupName)
            -- end
        end
    elseif behavior == DCAF.AirBehavior.Defensive then
        -- if isAssignedString(adversaryDisplayName) then
        --     -- MessageTo(source.Group, adversaryDisplayName .. " is defensive")
        -- end
        ROEDefensive(adversaryGroup)
    elseif behavior == DCAF.AirBehavior.Passive then
        -- if isAssignedString(adversaryDisplayName) then
        --     -- MessageTo(source.Group, adversaryDisplayName .. " is passive")
        -- end
        ROEHoldFire(adversaryGroup)
        adversaryGroup:OptionROTNoReaction()
    else
        error("applyOptions :: unsupported behavior: " .. DumpPretty(behavior))
    end

    local function applyToWaypoint(wp)
        if #task > 0 then
            wp.task = adversaryGroup:TaskCombo(task)
        else
            wp.task = adversaryGroup:TaskCombo({ task })
        end
    end

    if task then
        if isEnRouteTask then
-- Debug("nisse - adversaryGroup:EnRouteTaskEngageGroup :: waypoint: " .. DumpPrettyDeep(waypoint, 2))
            local wp
            if isList(waypoint) then
                wp = waypoint[1]
            else
                wp = waypoint
            end
-- Debug("nisse - adversaryGroup:EnRouteTaskEngageGroup :: wp: " .. DumpPrettyDeep(wp))
-- Debug("nisse - adversaryGroup:EnRouteTaskEngageGroup :: task: " .. DumpPrettyDeep(task))
-- Debug("nisse - adversaryGroup:EnRouteTaskEngageGroup :: adversaryGroup: " .. DumpPrettyDeep(adversaryGroup, 2))
            adversaryGroup: SetTaskWaypoint(wp, task)
-- Debug("nisse - adversaryGroup:EnRouteTaskEngageGroup :: (after SetTaskWaypoint)")
        elseif isList(waypoint) then
            for _, wp in ipairs(waypoint) do
                applyToWaypoint(wp)
            end
        else
            applyToWaypoint(waypoint)
        end
    end
end

local function getRandomOffsetAngle(maxOffsetAngle)
    if maxOffsetAngle == 0 then
        return 0
    end
    local offsetAngle = math.random(0, maxOffsetAngle)
    if offsetAngle > 0 and math.random(100) < 51 then
        offsetAngle = -offsetAngle
    end
    return offsetAngle
end

local function getHighestRankedUnit(group)
    local ranks = {1, 3, 2, 4}
    local units = group:GetUnits()
    for _, rank in ipairs(ranks) do
        if rank <= #units then
            local unit = units[rank]
            if unit:IsAlive() then
-- Debug("nisse - getCoordsAndHeading_getHighestRankedUnit :: rank: " .. rank)
                return unit
            end
        end
    end
end

local function getBearingAndCoordinateFrom(group, airBearing)
    if airBearing == DCAF.AirBearing.FromHeading then
        local leadUnit = getHighestRankedUnit(group)
        if leadUnit then
            return leadUnit:GetHeading(), leadUnit:GetCoordinate()
        end
    elseif airBearing == DCAF.AirBearing.North then
        return 360, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.NorthEast then
        return 45, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.East then
        return 90, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.SouthEast then
        return 135, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.South then
        return 180, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.SouthWest then
        return 225, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.West then
        return 270, group:GetCoordinate()
    elseif airBearing == DCAF.AirBearing.NorthWest then
        return 315, group:GetCoordinate()
    end
end

local function getPositionFrom(group, airBearing)
    local unit = getHighestRankedUnit(group)
    if not unit then
        return end

    local bearing, _ = getBearingAndCoordinateFrom(group, airBearing)
    local heading = unit:GetHeading()
    local diff = getAngleDiff(bearing, heading)
    local diffAbs = math.abs(diff)
    if diffAbs < 45 then
        return DCAF.AirPosition.Ahead
    elseif diffAbs > 135 then
        return DCAF.AirPosition.Behind
    elseif diff < 0 then
        return DCAF.AirPosition.Left
    else
        return DCAF.AirPosition.Left
    end
end

local function getCoordsAndHeading(source, distance, position, offsetAngle, aspect)
    -- local behavior = source.Options:GetBehavior()
    -- local groupHeading = source.Group:GetHeading()

    -- local leaderUnit = getHighestRankedUnit(source.Group)
    local bearing, coord = getBearingAndCoordinateFrom(source.Group, position)
    -- local angle = (leaderUnit:GetHeading() + offsetAngle) % 360
    -- local groupCoord = source.Group:GetCoordinate()
    
    -- local spawnCoord
    -- if position == DCAF.AirPosition.Ahead then
    --     -- just included to catch possible future additional AirPosition values
    --     -- spawnCoord = groupCoord:Translate(distance, angle, true)
    -- elseif position == DCAF.AirPosition.Right then
    --     angle = (angle + 90) % 360
    -- elseif position == DCAF.AirPosition.Behind then
    --     angle = (angle + 180) % 360
    -- elseif position == DCAF.AirPosition.Left then
    --     angle = (angle + 270) % 360
    -- else
    --     error("buildRoute_getStartCoord :: unsupported DCAF.AirPosition: " .. Dump(position))
    -- end
    local spawnCoord = coord:Translate(distance, bearing, true)
    local taskCoord
    local endCoord
    local heading
    local routeLength = 200

    if aspect == DCAF.AirAspect.Hot then
        routeLength = distance + 20
        heading = (bearing + 180) % 360
    elseif aspect == DCAF.AirAspect.Cold then
        heading = bearing
    elseif aspect == DCAF.AirAspect.FlankingLeft then
        -- todo Do we need to re-route an aggressive AI here (more WPs) or will it turn towards Group?
        heading = (bearing + 270) % 360
    elseif aspect == DCAF.AirAspect.FlankingRight then
        -- todo Do we need to re-route an aggressive AI here (more WPs) or will it turn towards Group?
        heading = (bearing + 90) % 360
    end

    taskCoord = spawnCoord:Translate(NauticalMiles(0.2), heading, true)
    endCoord = coord:Translate(NauticalMiles(routeLength), heading, true)
    return { Spawn = spawnCoord, Task = taskCoord, End = endCoord }, heading
end

local function getAltitude(source, distance, altitude)
    if not isNumber(altitude) then
        altitude = source.Options:GetAltitude()
        local variation = 0
        if altitude.Name == DCAF.AirAltitude.High.Name then
            variation = math.random(0, 5) * 1000
            altitude = Feet(altitude.MSL - variation)
        elseif altitude.Name == DCAF.AirAltitude.Level.Name then
            local nmDistance = UTILS.MetersToNM(distance)
            if nmDistance >= 10 then
                variation = math.random(0, 4) * 1000
                if math.random(100) < 50 then
                    variation = -variation
                end
            elseif nmDistance >= 2 then
                variation = math.random(0, 4) * 1000
                if math.random(100) < 50 then
                    variation = -variation
                end
            elseif nmDistance >= 1 then
                variation = math.random(0, 500)
                if math.random(100) < 50 then
                    variation = -variation
                end
            end
            altitude = source.Group:GetAltitude() + Feet(variation)
        else
            variation = math.random(0, 5) * 1000
            if math.random(100) < 50 then
                variation = -variation
            end
            altitude = math.max(Feet(300), Feet(altitude.MSL + variation))
        end
    end
    return altitude
end

local function spawnGroup(info, size, source, distance, altitude, bearing, offsetAngle, aspect, coords, heading, adversaryName, role)
    if not isNumber(offsetAngle) then
        offsetAngle = getRandomOffsetAngle(source.Options:GetMaxOffsetAngle())
    end
    if not isNumber(distance) then
        distance = NauticalMiles(source.Options:GetDistance())
    end
    if not bearing then
        bearing = source.Options:GetPosition()
    end
    if not aspect then
        aspect = source.Options:GetAspect()
    end

    local function isBFMSetup()
        local ownAltitude = source.Group:GetAltitude()
        if UTILS.MetersToNM(distance) > 2 or math.abs(altitude - ownAltitude) > Feet(5000) then
            return false end

        local _, direction = getPositionFrom(source.Group, bearing)

        return UTILS.MetersToNM(distance) < 2
                and math.abs(altitude - ownAltitude) < Feet(1000)
                and ((direction == DCAF.AirPosition.Ahead and aspect == DCAF.AirAspect.Cold)
                  or (direction == DCAF.AirPosition.Behind and aspect == DCAF.AirAspect.Hot))
    end

    -- route coordinates ...
    if coords == nil then
        coords, heading = getCoordsAndHeading(source, distance, bearing, offsetAngle, aspect)
    end
    local spawnCoord = coords.Spawn
    local taskCoord = coords.Task
    local endCoord = coords.End

    -- altitude ...
    altitude = getAltitude(source, distance, altitude)
    spawnCoord:SetAltitude(altitude, true)

    -- spawn and set route ...
    local spawn = info:Spawner()
    spawn:InitSkill(source.Options:GetSkill())
    spawn:InitGroupHeading(heading)
    spawn:InitGrouping(size)
    local group = spawn:SpawnFromCoordinate(spawnCoord)
    table.insert(source.SpawnedAdversaries, group)
    local route = group:CopyRoute()
    local wp0 = route[1]
    local speedMps = wp0.Speed
    if isBFMSetup() then
        speedMps = source.Group:GetVelocityMPS()
        group:SetSpeed(speedMps)
    end

    if role == SpawnGroupRole.Support then
        taskCoord:SetAltitude(altitude)
        endCoord:SetAltitude(altitude)
    end

    local wpTask = taskCoord:WaypointAir(
        COORDINATE.WaypointAltType.BARO,
        COORDINATE.WaypointType.TurningPoint,
        COORDINATE.WaypointAction.TurningPoint,
        speedMps)
    wpTask.task = wp0.task
    local wpEnd = endCoord:WaypointAir(
        COORDINATE.WaypointAltType.BARO,
        COORDINATE.WaypointType.TurningPoint,
        COORDINATE.WaypointAction.TurningPoint,
        speedMps)
    route = { wpTask, wpEnd }
    applyOptions(group, route, source, adversaryName, role)
    DCAF.delay(function()
        setGroupRoute(group, route)
    end, 1)
    -- SetRoute(group, route)
    return group
end

local CoordinatedAttack = {
    _interval = 1,
    _isEnded = false,
    _timer = nil,
    _groups = {
        -- list if #GROUP
    }
}

function CoordinatedAttack:New(func, interval)
    local attack = DCAF.clone(CoordinatedAttack)
    if isNumber(interval) then
        attack._interval = interval
    else
        attack._interval = 1
    end

    attack._timer = TIMER:New(function() 
        if attack._isEnded then
            return end

        local isAlive = false
        for _, group in ipairs(attack._groups) do
            if group:CountAliveUnits() > 0 then
                isAlive = true
                break
            end
        end
        if not isAlive then
            attack:Stop()
        end

        func(attack)
    end)
    return attack
end

function CoordinatedAttack:AddGroup(group)
    table.insert(self._groups, group)
    return self
end

function CoordinatedAttack:OnBegin(func)
    self._onStartFunc = func
    return self
end

function CoordinatedAttack:OnEnd(func)
    self._onEndFunc = func
    return self
end

function CoordinatedAttack:GetAliveGroups()
    local aliveGroups = {}
    for _, group in ipairs(self._groups) do
        if group:IsAlive() then
            table.insert(aliveGroups, group)
        end
    end
    return aliveGroups
end

function CoordinatedAttack:Includes(group)
    local g = getGroup(group)
    if not g then
        return false end

    for _, attackGroup in ipairs(self._groups) do
        if attackGroup == g then
            return true end
    end
    return false
end

function CoordinatedAttack:Start()
    self._timer:Start(1, self._interval)
    if isFunction(self._onStartFunc) then
        self._onStartFunc(self)
    end
end

function CoordinatedAttack:Stop()
    self._isEnded = true
    if isFunction(self._onEndFunc) then
        self._onEndFunc(self)
    end
    Delay(3, function()
        self._timer:Stop()
    end)
end

local function supportedAttack(targetGroup)

    local function finishAttack(attack)
        -- all support groups attack (coordination ends) ...
        for _, group in ipairs(attack:GetAliveGroups()) do
            local isSupporting = attack._supportGroups[group.GroupName]
            if isSupporting then
                TaskAttackGroup(group, targetGroup)
            end
        end
        attack:Stop()
    end

    local coordinatedAttack = CoordinatedAttack:New(function(attack) 
        -- ensure all supporting groups keep same speed as lead group(s)
        local leadUnit
        local supportingGroups = {}
        local aliveGroups = attack:GetAliveGroups()
        if #aliveGroups == 0 then
            attack:Stop()
            return
        end

        for _, group in ipairs(aliveGroups) do
            local isSupporting = attack._supportGroups[group.GroupName]
            if not isSupporting then
                leadUnit = leadUnit or group:GetFirstUnitAlive()
            else
                table.insert(supportingGroups, group)
            end
        end
        
        if not leadUnit then
            -- all lead groups destroyed; attack with supporting groups and end coordination ...
            finishAttack(attack)
            return
        end

        -- ensure supporting groups keep same speed as attacking (lead) group(s) ...
        -- also, have supporting group switch to attacking if inside of 18nm from TGT ...
        local speedMps = leadUnit:GetVelocityMPS()
        for _, supportingGroup in ipairs(supportingGroups) do
            local distanceToTGT = supportingGroup:GetCoordinate():Get2DDistance(targetGroup:GetCoordinate())
            if distanceToTGT < NauticalMiles(18) then
                finishAttack(attack)
                return
            end
            supportingGroup:SetSpeed(speedMps, true)
        end

    end):OnBegin(function(attack) 
        -- when missiles gets shot; all supporting groups attack and coordination ends ...
        local function onMissilesShot(event)
            -- check to see if the missiles fired was related to coorindated attack ...
            if (event.IniGroup ~= targetGroup and not attack:Includes(event.IniGroup)) 
            and (event.TgtGroup and not attack:Includes(event.TgtGroup)) then
                return end

            finishAttack(attack)
            MissionEvents:EndOnWeaponFired(attack._onMissileShot)
        end
        attack._onMissileShot = onMissilesShot
        MissionEvents:OnWeaponFired(attack._onMissileShot)
    end):OnEnd(function(attack) 
        if attack._onMissileShot then
            MissionEvents:EndOnWeaponFired(attack._onMissileShot)
        end
    end)
    coordinatedAttack._supportGroups = {}
    return coordinatedAttack

end

local function spawnStackedGroup(info, size, source, stack, distance, altitude, position, offsetAngle, aspect)
    if size == 1 then
        spawnGroup(info, 1, source, distance, altitude, position, offsetAngle, aspect, nil, nil, "Single " .. info.Name)
        return
    end
    if not isNumber(offsetAngle) then
        offsetAngle = getRandomOffsetAngle(source.Options:GetMaxOffsetAngle())
    end
    if not isNumber(distance) then
        distance = NauticalMiles(source.Options:GetDistance())
    end
    if not position then
        position = source.Options:GetPosition()
    end
    if not aspect then
        aspect = source.Options:GetAspect()
    end
    local altitude = getAltitude(source, distance, altitude)
    local distribution = source.Options:GetGroupDistribution()
    local factor = size
    if distribution == DCAF.AirGroupDistribution.Half then
        factor = 2
    end
    local separation = Feet(stack.Feet)
    local coords, heading = getCoordsAndHeading(source, distance, position, offsetAngle, aspect)
    local landHeight = COORDINATE:GetLandHeight()
    local hardDeck = Feet(100)
    if COORDINATE:GetSurfaceType() ~= land.SurfaceType.WATER then
        hardDeck = Feet(300)
    end
    local lowAlt, highAlt
    if stack.Name == DCAF.AirStackHeight.Full.Name then
        -- 'Full' stack, lowest at treetop/sea level and top at specified altitude
        lowAlt = landHeight + hardDeck
        separation = (altitude-lowAlt) / (factor-1)
        highAlt = altitude
    else
        lowAlt = altitude - (factor-1) * separation
        highAlt = separation * (factor-1)
    end
    highAlt = math.min(Feet(40000), highAlt)
    if lowAlt < landHeight + hardDeck then
        lowAlt = landHeight + hardDeck
    end

    local count = size
    local isEvenSize = size % factor == 0
    local groupSize = math.floor(size / factor)
    if not isEvenSize --[[or stack.Name == DCAF.AirStackHeight.Full.Name]] then
        groupSize = 1
    end
    local twoshipCreated = false
    local adversaryName = Dump(size) .. " x " .. info.Name
    local leadGroup
    local behavior = source.Options:GetBehavior()
    local isAttack = behavior == DCAF.AirBehavior.Attack
    local coordinatedAttack
    if isAttack then
        coordinatedAttack = supportedAttack(source.Group)
    end
    local countSupportGroups = 0

    for i = 0, factor-1, 1 do
        local useGroupSize = groupSize
        local stackedSize = 1
        local groupAltitude = lowAlt + i*separation
        local isSupportGroup = math.abs(altitude - groupAltitude) > 3000 -- meters (9000 ft)
        local role
        if isSupportGroup then
            role = SpawnGroupRole.Support
        end
        if not isEvenSize and factor == 2 and not twoshipCreated then
            if i == 1 or math.random(100) < 51 then
                twoshipCreated = true
                useGroupSize = 2
            end
        end
        local group = spawnGroup(info, useGroupSize, source, distance, groupAltitude, position, offsetAngle, aspect, coords, heading, adversaryName, role)
        if coordinatedAttack then
            coordinatedAttack:AddGroup(group)
            if isSupportGroup then
                countSupportGroups = countSupportGroups + 1
                coordinatedAttack._supportGroups[group.GroupName] = isSupportGroup
            end
        end
        adversaryName = nil
    end
    if coordinatedAttack and countSupportGroups > 0 then
        coordinatedAttack:Start()
    else
        coordinatedAttack = nil
    end

end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                           EXPERIMENT :: HARD DECK MONITORING
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local HARD_DECK_MONITOR = {
    Scheduler = SCHEDULER:New(),
    MonitoredUnits = {
        -- list of #UNIT
    }
}

function HARD_DECK_MONITOR:Monitor(unit)

end


-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                        MENUS
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local function buildMenus(state, unitName)
    if not state.Menus.Main and isAssignedString(_airCombatGroupMenuText) then
        state.Menus.Main = MENU_GROUP:New(state.Group, _airCombatGroupMenuText)
    end

    -- Options
    local function buildOptionsMenus(source, parentMenu)
        if not source.Menus.Options then
            source.Menus.Options = MENU_GROUP:New(source.Group, "OPTIONS", parentMenu)
        else
            source.Menus.Options:RemoveSubMenus()
        end

        local function displayValue(value, suffix, isFallback)
            if isFallback then
                return '[' .. Dump(value) .. (suffix or '') .. ']'
            else
                return Dump(value) .. suffix or ''
            end
        end

        local menu = DCAF.MENU:New(source.Menus.Options)

        -- Reset All Options
        MENU_GROUP_COMMAND:New(source.Group, "-- RESET --", source.Menus.Options, function()
            source.Options:Reset()
            buildOptionsMenus(source, parentMenu)
        end)
        
        -- Distance
        local distance, isFallback = source.Options:GetDistance()
        local distanceOptionsMenu = menu:Group(source.Group, "Distance: " .. displayValue(distance, 'nm', isFallback))
        for key, value in pairs(DCAF.AirDistance) do
            MENU_GROUP_COMMAND:New(source.Group, key, distanceOptionsMenu, function()
                source.Options:SetDistance(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Position ...
        local position, isFallback = source.Options:GetPosition()
        local positionOptionsMenu = menu:Group(source.Group, "Bearing: " .. displayValue(position, '', isFallback))
        for _, value in pairs(DCAF.AirBearing) do
            MENU_GROUP_COMMAND:New(source.Group, Dump(value), positionOptionsMenu, function()
                source.Options:SetPosition(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Aspect ...
        local aspect, isFallback = source.Options:GetAspect()
        local aspectOptionsMenu = menu:Group(source.Group, "Aspect: " .. displayValue(aspect, '', isFallback))
        for k, value in pairs(DCAF.AirAspect) do
            MENU_GROUP_COMMAND:New(source.Group, Dump(value), aspectOptionsMenu, function()
                source.Options:SetAspect(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Max Offset Angle ...
        local maxOffsetAngle, isFallback = source.Options:GetMaxOffsetAngle()
        local maxOffsetAngleMenu = menu:Group(source.Group, "Max Offset: " .. displayValue(maxOffsetAngle, '°', isFallback))
        for angle = 0, 80, 20 do
            MENU_GROUP_COMMAND:New(source.Group, "Max Offset: " .. Dump(angle) .. "°", maxOffsetAngleMenu, function()
                source.Options:SetMaxOffsetAngle(angle)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Altitude
        local altitude, isFallback = source.Options:GetAltitude()
        local altitudeOptionsMenu = menu:Group(source.Group, "Altitude: " .. displayValue(source.Options:GetAltitude().Name, '', isFallback))
        for key, value in pairs(DCAF.AirAltitude) do
            MENU_GROUP_COMMAND:New(source.Group, key, altitudeOptionsMenu, function()
                source.Options:SetAltitude(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Skill
        local skill, isFallback = source.Options:GetSkill()
        local skillMenuText = "Skill: " .. displayValue(skill, '', isFallback)
        local skillOptionsMenu = menu:Group(source.Group, skillMenuText)
        for key, value in pairs(DCAF.AirSkill) do
            MENU_GROUP_COMMAND:New(source.Group, key, skillOptionsMenu, function()
                source.Options:SetSkill(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Distribute
        local distribution, isFallback = source.Options:GetGroupDistribution()
        local stack, isStackFallback = source.Options:GetStack()
        local distributeMenuText = "Distribute: " .. displayValue(distribution, '', isFallback)
        if distribution ~= DCAF.AirGroupDistribution.None and stack.Name ~= DCAF.AirStackHeight.None.Name then
            distributeMenuText = distributeMenuText .. ", " .. string.lower(stack.Name) .. " stack"
        end
        local distributionOptionsMenu = menu:Group(source.Group, distributeMenuText)
        for key, value in pairs(DCAF.AirGroupDistribution) do
            MENU_GROUP_COMMAND:New(source.Group, key, distributionOptionsMenu, function()
                source.Options:SetGroupDistribution(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Stack
        if distribution ~= DCAF.AirGroupDistribution.None then
            local stackOptionsMenu = menu:Group(source.Group, "Stack: " .. displayValue(source.Options:GetStack().Name, '', isStackFallback))
            for key, value in pairs(DCAF.AirStackHeight) do
                MENU_GROUP_COMMAND:New(source.Group, key, stackOptionsMenu, function()
                    source.Options:SetStack(value)
                    buildOptionsMenus(source, parentMenu)
                end)
            end
        end

        -- Behavior
        local behavior, isFallback = source.Options:GetBehavior()
        local behaviorOptionsMenu = menu:Group(source.Group, "Behavior: " .. displayValue(behavior, '', isFallback))
        for key, value in pairs(DCAF.AirBehavior) do
            MENU_GROUP_COMMAND:New(source.Group, value, behaviorOptionsMenu, function()
                source.Options:SetBehavior(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Hard deck (experiment)
        -- local hardDeck, isFallback = source.Options:GetDeck()
        -- local valueText = displayValue(hardDeck, '', isFallback)
        -- if hardDeck == DCAF.AirDeck.None then
        --     valueText = "None"
        -- end
        -- local hardDeckOptionsMenu = MENU_GROUP:New(source.Group, "Hard deck: " .. valueText, source.Menus.Options)
        -- for key, value in pairs(DCAF.AirDeck) do
        --     valueText = tostring(value)
        --     if value == DCAF.AirDeck.None then
        --         valueText = "None"
        --     end
        --     if hardDeck == value then
        --         valueText = "[" .. valueText .."]"
        --     else
        --         valueText = valueText
        --     end
        --     MENU_GROUP_COMMAND:New(source.Group, valueText, hardDeckOptionsMenu, function()
        --         source.Options:SetDeck(value)
        --         buildOptionsMenus(source, parentMenu)
        --     end)
        -- end
        
    end
    -- uncategorized options ...
    buildOptionsMenus(state, state.Menus.Main)

    -- Spawn: 
    if state.Menus.Spawn then
        return end

    local function buildSpawnMenus(adversaries, parentMenu, source)
        local MaxAdversariesAtMenuLevel = 7
        local menuIndex = 0
        for _, info in ipairs(adversaries) do
            menuIndex = menuIndex+1
            if menuIndex > MaxAdversariesAtMenuLevel then
                -- create a 'More ...' sub menu to allow for all adversaries ...
                local clonedAdversaries = listClone(adversaries, false, menuIndex)
                local moreMenu = MENU_GROUP:New(source.Group, "More", parentMenu)
                buildSpawnMenus(clonedAdversaries, moreMenu, source)
                return
            end
            local displayName = info.Name
            local spawnMenu = MENU_GROUP:New(source.Group, displayName, parentMenu)
            for i = 1, info.Size, 1 do
                local sizeName
                if i == 1 then
                    sizeName = "Singleton"
                elseif i == 2 then
                    sizeName = "Pair"
                elseif i == 3 then
                    sizeName = "Threeship"
                elseif i == 4 then
                    sizeName = "Fourship"
                else
                    sizeName = tostring(i)
                end
                MENU_GROUP_COMMAND:New(source.Group, sizeName, spawnMenu, function()
                    local stack = source.Options:GetStack()
                    if stack.Name == DCAF.AirStackHeight.None.Name then
                        local adversaryName = Dump(i) .. " x " .. info.Name
                        spawnGroup(info, i, source, nil, nil, nil, nil, nil, nil, nil, adversaryName, nil)
                    else
                        spawnStackedGroup(info, i, source, stack)
                    end
                end)
            end
        end
    end

    -- non-categories adversaries ...
    if #state.Adversaries > 0 then
        state.Menus.Spawn = MENU_GROUP:New(state.Group, "Spawn", state.Menus.Main)
        buildSpawnMenus(state.Adversaries, state.Menus.Spawn, state)
    end

    local function despawnAll(source)
        for _, group in ipairs(source.SpawnedAdversaries) do
            group:Destroy()
        end
        source.SpawnedAdversaries = {}
    end

    -- categorised adversaries ...
    for _, category in ipairs(state.Categories) do
        local categoryMenu = MENU_GROUP:New(state.Group, category.Name, state.Menus.Main)
        buildOptionsMenus(category, categoryMenu)
        buildSpawnMenus(category.Adversaries, categoryMenu, category)
        MENU_GROUP_COMMAND:New(category.Group, "-- Despawn All --", categoryMenu, function()
            despawnAll(category)
        end)
    end

    -- Despawn:
    MENU_GROUP_COMMAND:New(state.Group, "-- Despawn All --", state.Menus.Main, function()
        despawnAll(state)
        for _, category in ipairs(state.Categories) do
            despawnAll(category)
        end
        state.SpawnedAdversaries = {}
    end)

end

local function onPlayerEnteredAircraft(event)
    local state = GroupStateDict[event.IniGroupName]
    if state or not isSpecifiedGroupForMenus(event.IniGroupName) then
        return end

    state = GroupState:New(event.IniGroupName)
    local unitName = event.IniUnitName
    if _isBuildingGroupMenus then
        buildMenus(state, unitName)
    end
    if state.Randomization then
        state.Randomization:StartForGroupState(state)
    end

end

function DCAF.Air:WithGroupMenus(sMenuText, sGroup)
    _isBuildingGroupMenus = true
    _groupMenusGroup = sGroup
    _airCombatGroupMenuText = sMenuText
    return self
end

function DCAF.Air:FindCategory(name)
    local index = tableIndexOf(self.Categories, function(c) return c.Name == name end)
    if index then 
        return self.Categories[index]
    end
end

local function initGroup(object, sName, sGroup, nSize)
    -- as both #DCAF.Air object and #DCAF.AirCategory can init groups, this method allows both to do so
    local self = object
    if not isAssignedString(sName) then
        error("DCAF.Air:InitGroup :: unexpected `sName`: " .. DumpPretty(sName)) end

    if tableIndexOf(self.Adversaries, function(adversary) return adversary.Name == sName end) then
        error("DCAF.Air:InitGroup :: group was already added: " .. DumpPretty(sName)) end
    
    local adversadyGroup = getGroup(sGroup)
    if not adversadyGroup then
        error("DCAF.Air:InitGroup :: cannot resolve group from: " .. DumpPretty(sGroup)) end

    local info = DCAF.clone(AirGroupInfo)
    info.Name = sName
    info.TemplateName = adversadyGroup.GroupName
    if isNumber(nSize) then
        info.Size = math.min(4, math.max(1, math.abs(nSize))) -- max size is 4 (DCS limitation)
    else
        info.Size = #adversadyGroup:GetUnits()
    end
    table.insert(self.Adversaries, info)
    return self
end

function DCAF.Air:InitGroup(sName, sGroup, nSize) 
    return initGroup(self, sName, sGroup, nSize)
end

function DCAF.Air:InitCategory(category)
    if not isClass(category, DCAF.AirCategory.ClassName) then
        error("DCAF.Air:InitCategory :: expected class '" .. DCAF.AirCategory.ClassName .. "' but got: " .. DumpPretty(category)) end

    table.insert(self.Categories, category)
    return self
end

function DCAF.AirCategory:WithGroup(sName, sGroup, nSize)
    self._adversayIndex = (self._adversayIndex or 0) + 1
    return initGroup(self, sName, sGroup, nSize)
end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                      EXPERIMENT :: RANDOMIZED AIR THREATS
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.Air.Randomization = {
    ClassName = "DCAF.Air.Randomization",
    -- MinInterval = 1,
    -- MaxInterval = Minutes(2),
    MinInterval = Minutes(1),
    MaxInterval = Minutes(20),
    MinSize = 1,                        -- minimum size of spawned group
    MaxSize = 4,                        -- maximum size of spawned group
    MinCount = 1,                       -- minimum number of spawned groups per event
    MaxCount = 2,                       -- maximum number of spawned groups per event
    Altitudes = {
        DCAF.AirAltitude.High,
        DCAF.AirAltitude.Medium,
        DCAF.AirAltitude.Level,
        DCAF.AirAltitude.Popup
    },
    -- MinAltitude = Feet(Altitude.Popup.MSL), obsolete
    -- MaxAltitude = Feet(Altitude.High.MSL),
    MinDistance = NauticalMiles(40),
    MaxDistance = NauticalMiles(160),
    MaxOffsetAngle = 60,
    MaxEvents = 5,
    RemainingEvents = 5,
}

function DCAF.Air.Randomization:New()
    return DCAF.clone(DCAF.Air.Randomization)
end

function DCAF.Air.Randomization:WithDistance(min, max)
    if not isNumber(min) then
        error("DCAF.Air.Randomization:WithDistance :: `min` must be a number but was: " .. DumpPretty(min)) end

    self.MinDistance = min
    if isNumber(max) then
        self.MaxDistance = max
    else
        self.MaxDistance = self.MaxDistance or min
    end
    if self.MinDistance > self.MaxDistance then
        self.MinDistance, self.MaxDistance = swap(self.MinDistance, self.MaxDistance)
    end
    return self
end

function DCAF.Air.Randomization:WithMaxOffsetAngle(max)
    if not isNumber(max) then
        error("DCAF.Air.Randomization:WithOffsetAngle :: `max` must be a number but was: " .. DumpPretty(max)) end

    self.MaxOffsetAngle = max
    return self
end

function DCAF.Air.Randomization:WithAltitudes(...)
    if #arg == 0 then
        error("DCAF.Air.Randomization:WithAltitude :: expected at least one altitude value") end

    -- validate args
    local altitudes = {}
    for i = 1, #arg, 1 do
        local alt = arg[i]
        if not isTable(alt) or not isAssignedString(alt.Name) or not isNumber(alt.MSL) then
            error("DCAF.Air.Randomization:WithAltitude :: unexpcted altitude value #" .. Dump(i) .. ": " .. DumpPretty(alt)) end 
    end

    self.Altitudes = altitudes
    return self
end

function DCAF.Air.Randomization:GetAltitude()
    local index = math.random(1, #self.Altitudes)
    return self.Altitudes[index]
end

function DCAF.Air.Randomization:WithInterval(min, max)
    if not isNumber(min) then
        error("DCAF.Air.Randomization:WithInterval :: `min` must be a number but was: " .. DumpPretty(min)) end

    self.MinInterval = min
    if isNumber(max) then
        self.MaxInterval = min
    else
        self.MaxInterval = self.MaxInterval or min
    end
    if self.MinInterval > self.MaxInterval then
        self.MinInterval, self.MaxInterval = swap(self.MinInterval, self.MaxInterval)
    end
    return self
end

function DCAF.Air.Randomization:WithMaxEvents(maxEvents)
    if not isNumber(maxEvents) then
        error("DCAF.Air.Randomization:WithMaxEvents :: `countEvents` must be a number but was: " .. DumpPretty(maxEvents)) end

    self.MaxEvents = maxEvents
    self.RemainingEvents = maxEvents
    return self
end

function DCAF.Air.Randomization:WithGroups(...)
    if #arg == 0 then
        error("DCAF.Air.Randomization:WithGroups :: expected at least one group") end

    -- validate
    local groups = {}
    for i = 1, #arg, 1 do
        local group = getGroup(arg[i])
        if not group then
            if isAssignedString(arg[i]) then
                group = DCAF.Air.Adversaries[arg[i]]
            end
            if not group then
                error("DCAF.Air.Randomization:WithGroups :: cannot resolve group from: " .. DumpPretty(arg[i]))  end
            table.insert(group)
        end
    end
    self.Adversaries = groups
    return self
end

function DCAF.Air.Randomization:StartForGroupState(state)
    local function stopTimer()
        Delay(2, function() 
            if self.Timer and self.Timer:IsRunning() then
                self.Timer:Stop()
                self.Timer = nil
            end
        end)
    end

    local function getNextEventTime()
        local timeToNext = math.random(self.MinInterval, self.MaxInterval)
        return timeToNext
    end

    local randomizeFunc
    local function randomize()
        local units = state.Group:GetUnits()
        if not state.Group:IsAlive() or units == nil or #units == 0 then
            return end

        if not state.Group:InAir() then
            -- we only spawn random threats if group is airborne
            if now >= self.NextEventTime then
                self.Timer = TIMER:New(randomizeFunc):Start(getNextEventTime())
            end
            return
        end

        if self.RemainingEvents == 0 then
            return end

        local now = UTILS.SecondsOfToday()
        local index = math.random(1, #state.Adversaries)
        local count = math.random(self.MinCount, self.MaxCount)
        for i = 1, count, 1 do
            local distance = math.random(self.MinDistance, self.MaxDistance)
            local alt = self:GetAltitude()
            local altitude = Feet(alt.MSL)
            local size = math.random(self.MinSize, self.MaxSize)
            local info = state.Adversaries[index]
            local offsetAngle = getRandomOffsetAngle(self.MaxOffsetAngle)
            spawnGroup(info, size, state, distance, altitude, DCAF.AirBearing.FromHeading, offsetAngle)
            index = math.random(1, #state.Adversaries)
        end
        self.RemainingEvents = self.RemainingEvents-1             
        if self.RemainingEvents == 0 then
            return 
        else
            self.Timer = TIMER:New(randomizeFunc):Start(getNextEventTime())
        end
    end
    randomizeFunc = randomize

    if self.Timer then
        stopTimer()
    end
    self.Timer = TIMER:New(randomizeFunc):Start(getNextEventTime())
    return self

end

--- Automatically spawns adversaries for (player) groups at random intervals as long as it is airborne
function DCAF.Air:WithGroupRandomization(randomization)
    if randomization == nil then
        randomization = DCAF.Air.Randomization:New()
    end
    if not isClass(randomization, "DCAF.Air.Randomization") then
        error("DCAF.Air:WithRandomization :: `randomization` is of unexpected value: " .. DumpPretty(randomization)) end

    _airThreatRandomization = randomization
    return self
end

local DCAF_Air_Events = {
    ClassName = "DCAF_Air_Events"
}

-- function DCAF_Air_Events.Subscribe()
--     local self = BASE:Inherit(DCAF_Air_Events, BASE:New())
--     self:HandleEvent(EVENTS.PlayerEnterAircraft)
--     function self:PlayerEnterAircraft(...)
--         Debug("nisse - DCAF_Air_Events:Subscribe...")
--         for i = 1, #arg, 1 do
--             Debug("nisse - arg[" .. i .. "]: " .. DumpPretty(arg[i]))
--         end
--     end
--     return self
-- end

--- Alows anyone to use the F10 map and map markers to create A-A pictures
local function startControllerUX(air)
    -- TODO
end

function DCAF.Air:Start(enableControllerUX)
    if DCAF.Air.IsStarted then
        return end

    DCAF.Air.IsStarted = true
    MissionEvents:OnPlayerEnteredAirplane(onPlayerEnteredAircraft)
    if enableControllerUX then
       startControllerUX(self)
    end
    return self
end

function DCAF.Air:SpawnFromCategory(group, categoryName, options, size)
    local validGroup = getGroup(group)
    if not validGroup then return Error("DCAF.Air:SpawnFromCategory :: cannot resolve group: " .. DumpPretty(group)) end
    local category = DCAF.Air:FindCategory(categoryName)
    if not category then return Error("DCAF.Air:SpawnFromCategory :: cannot resolve category: " .. DumpPretty(categoryName)) end
    local groupState = GroupState:New(validGroup)
    groupState.Options = options or groupState.Options
    local adversary = listRandomItem(category.Adversaries)
Debug("nisse - DCAF.Air:SpawnFromCategory ::adversary: " .. DumpPrettyDeep(adversary, 2))
    if not isNumber(size) then size = 1 end
    return spawnGroup(adversary, size, groupState)
end