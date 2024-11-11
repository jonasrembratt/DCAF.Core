-- relies on MANTIS
-- relies on DCAF.GBAD

-- function nisse_get_set_group(setGroup)
--     local set = {}
--     setGroup:ForEachGroup(function(g) 
--         table.insert(set, g)
--     end)
--     return set
-- end

DCAF.GBAD.RegimentMode = {
    Dynamic = "Dynamic",            -- regiment groups will spawn and despawn dynamically
    DynamicSpawn = "DynamicSpawn",  -- regiment groups will spawn dynamically, but will not despawn dynamically
    Static = "Static",              -- regiment groups will spawn when regiment is started and will never despawn
    OFF = "OFF"                     -- regiment groups will never spawn (useful mainly for testing)
}

--- Controls how a regiment despawns/spawns groups under its control
DCAF.GBAD.RegimentDespawnMethod = {
    Despawn = "Despawn",
    Lobotomize = "Lobotomize"
}

local GBAD_REGIMENT_DEFAULTS = {
    SAMPrefix = "SAM",
    EWRPrefix = "EWR",
    PrebriefedPrefix = "-PB-",
    RegimentMode = DCAF.GBAD.RegimentMode.Dynamic,
    SpawnInterval = 4, -- seconds
    DespawnInterval = 30, -- seconds :: minimum time between dynamically despawned GBAD groups (avoids flickering spawn/despawn as aircraft are close to triggering distance)
    MonitorActivationDistance = NauticalMiles(45),
    MonitorPostActivationDistance = NauticalMiles(35),
    MonitorDeactivationDistance = NauticalMiles(45),
    AutoDeactivation = false,
    UseEvasiveRelocation = true,
    DespawnMethod = DCAF.GBAD.RegimentDespawnMethod.Despawn,  -- controls how a regiment despawns/spawns groups under its control
    DestroyedUnitsPattern = "DESTROYED",
    MaxActiveSams = {
        Short = 1,
        Mid = 2,
        Long = 2,
    },
    ExcludeDestroyedSAMDelay = {
        [Skill.Excellent] = VariableValue:New(30, .1),
        [Skill.High] = VariableValue:New(Minutes(5), .3),
        [Skill.Good] = VariableValue:New(Minutes(10), .5),
        [Skill.Average] = VariableValue:New(Minutes(20), .5),
    }
}

DCAF.GBAD.Regiment = {
    ClassName = "DCAF.GBAD.Regiment",
    -----
    Name = nil,                 -- #string
    Coalition = nil,            -- #string (See #Coalition)
    HQ = nil,                   -- #GROUP
    Zones = nil,                -- #list of #ZONE
    SAMPrefix = nil,            -- #string
    EWRPrefix = nil,            -- #string
    AWACS = nil,                -- #string
    AutoDeactivate = false,     -- #boolean - when true; will automatically deactivate when no hostile AIR is within [MonitorDeactivationDistance]
    CountDynamic = 0,           -- #number - no. of dynamic groups than can be activated by the regiment (when all are activated a more performant monitoring strategy can be used)
    CountActiveDynamic = 0,            -- #number - no. of currently active GBAD groups managed by the regiment
    MonitorActivationDistance = nil,      -- when enemy air groups gets inside this distance the regiment activates (spawns all inactive groups)
    MonitorPostActivationDistance = nil,  -- when Regiment is activated, individual GBAD groups gets activated as hostile air gets within this range
    MonitorDeactivationDistance = nil,    -- when no hostile air is found inside this distance the regiment deactivates (despawns all late activated groups)
    AvailabilityFactors = {
        Long = 1,               -- number [0-1] (eg. 0.1 = 10% of long range systems will be unavailable)
        Medium = 1,             -- number [0-1] (eg. 0.1 = 10% of medium range systems will be unavailable)
        SHORADS = 1,            -- number [0-1] (eg. 0.1 = 10% of SHORADS will be unavailable)
    },
    DespawnMethod = GBAD_REGIMENT_DEFAULTS.DespawnMethod,-- controls how the regiment despawns/spawns groups under its control
    ExcludeDestroyedSAMDelay = GBAD_REGIMENT_DEFAULTS.ExcludeDestroyedSAMDelay -- time before an HQ excludes a SAM site that has been rendered useless
}

DCAF.GBAD.RegimentGroupDelegate = {
    ClassName = "DCAF.GBAD.RegimentGroupDelegate",
    -----
    RegimentName = nil,             -- #string - name of regiment
    GroupInfo = nil,                -- #GBAD_REGIMENT_GROUP_INFO - information about the regiment group
    IncludeInIADS = true,           -- #boolean - specifies whether to include the group in the IADS
    Coalition = nil,                -- #Coalition - GBAD group coalition
    Location = nil                  -- #DCAF.Location - GBAD group location
}

local GBAD_REGIMENT_GROUP_CATEGORY = {
    SAM = "SAM",
    EWR = "EWR",
    SHORAD = "SHORAD",
    HQ = "HQ",
    AWACS = "AWACS"
}

DCAF.GBAD.System = {
    SA2 = "SA-2",
    Guideline = "Guideline",
    SA3 = "SA-3",
    Goa = "Goa",
    SA5 = "SA-5",
    Gammon = "Gammon",
    SA6 = "SA-6",
    Gainful = "Gainful",
    SA8 = "SA-8",
    Gecko = "Gecko",
    SA9 = "SA-9",
    Gaskin = "Gaskin",
    SA10 = "SA-10",
    Grumble = "Grumble",
    SA11 = "SA-11",
    Gadfly = "Gadfly",
    SA13 = "SA-13",
    Gopher = "Gopher",
}

DCAF.GBAD.Attribute = {
    Tier = "Tier",             -- value: #number
    Mobile = "Mobile",         -- value: #boolean
    Role = "Role",             -- value: #GBAD_REGIMENT_GROUP_CATEGORY
    NATO = "NATO",             -- value: #string (NATO name, eg. "SA-8")
    NATOName = "NATOName"      -- value: #string (NATO name, eg. "Gecko")
}

local GBAD_REGIMENT_GBAD_PROPERTIES = {
    ClassName = "GBAD_REGIMENT_GBAD_PROPERTIES",
    ----
    TypeName = nil,                 -- type name
    Attributes = {
        -- key   = #string (see #DCAF.GBAD.Attribute)
        -- value = #Any (depends on property)
    },
    SuppressionTime = nil,          -- time (seconds) for this type to remain suppressed before wakng up again
    -- SkillFactors = {                -- used to add/cut to `SuppressionTime`
    --     VariableValue:New(1.8, .5), -- Average
    --     VariableValue:New(1.2, .5), -- Good
    --     VariableValue:New(1.0, .5), -- High
    --     VariableValue:New(0.7, .5), -- Excellent
    -- }
}

local GBAD_REGIMENT_DB = {
    IsMonitoringDamage = nil,          -- see GBAD_REGIMENT_DB:BeginMonitorDamage()
    GroupIndex = {
        -- key   = group name
        -- value = #GBAD_REGIMENT_GROUP_INFO
    },
    Regiments = {
        -- key   = regiment name
        -- value = #DCAF.GBAD.Regiment
    },
    RegimentIndex = {
        -- key   = regiment name
        -- value = { 
        --     key   = group name
        --     value = #GBAD_REGIMENT_GROUP_INFO 
        -- }
    },
    TypeProperties = {
        -- key   = GBAD type name
        -- value = #GBAD_REGIMENT_GBAD_PROPERTIES
    }
}

local GBAD_REGIMENT_EWR = {
    _sets = {
        -- key   = EWR name pattern (a.k.a. 'prefix')
        -- value = {  set = SET_GROUP,  adv_set = SET_GROUP } 
    }
}

--- This function will ensure all regiments utilizing the same "prefix" for identifying the EWRs they're to rely on, also end up
--- using the same internal SET_GROUP object. This also makes it possible for 'Regiments' to rely on common EWR assets (outside of the)
--- regiment geohraphical deployment zone
function GBAD_REGIMENT_EWR:Harmonize(regiment)
    local iads = regiment._iads
    local sets = self._sets[regiment.EWRPrefix]
    if not sets then
        Debug("GBAD_REGIMENT_EWR:Harmonize :: " .. regiment.Name .. " :: prefix: " .. regiment.EWRPrefix .. " :: stores EWR sets")
        self._sets[regiment.EWRPrefix] = {
            set = iads.EWR_Group,
            adv_set = iads.Adv_EWR_Group,
        }
    else
        Debug("GBAD_REGIMENT_EWR:Harmonize :: " .. regiment.Name .. " :: " .. regiment.EWRPrefix .. " :: assigns harmonized EWR sets")
        iads.EWR_Group = sets.set
        iads.Adv_EWR_Group = sets.adv_set
    end
    return regiment
end

function GBAD_REGIMENT_GBAD_PROPERTIES:New(typeName, role, tier, mobile)
    if not isAssignedString(typeName) then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `typeName` must be assigned string, but was: " .. DumpPretty(typeName)) end

    if GBAD_REGIMENT_DB.TypeProperties[typeName] then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `typeName` was already added to GBAD database") end

    local p = DCAF.clone(GBAD_REGIMENT_GBAD_PROPERTIES)
    p.TypeName = typeName
    p:Role(role)
    if isNumber(tier) then
        p:Tier(tier)
    end
    if isBoolean(mobile) then
        p:Mobile(mobile)
    end
    GBAD_REGIMENT_DB.TypeProperties[typeName] = p
    return p
end

function GBAD_REGIMENT_GBAD_PROPERTIES:Role(value)
    if not isAssignedString(value) then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `value` must be assigned string, but was: " .. DumpPretty(value)) end

    if not GBAD_REGIMENT_GROUP_CATEGORY[value] then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `value` must be valid role, but was: " .. DumpPretty(value)) end

    self.Attributes[DCAF.GBAD.Attribute.Role] = value
    return self
end

function GBAD_REGIMENT_GBAD_PROPERTIES:Tier(value)
    if not isNumber(value) then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:Tier :: `typeName` must be number, but was: " .. DumpPretty(value)) end

    self.Attributes[DCAF.GBAD.Attribute.Tier] = value
    return self
end

function GBAD_REGIMENT_GBAD_PROPERTIES:Mobile(value)
    if value ~= nil and not isBoolean(value) then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `value` must be boolean, but was: " .. DumpPretty(value)) end

    self.Attributes[DCAF.GBAD.Attribute.Mobile] = value
    return self
end

function GBAD_REGIMENT_GBAD_PROPERTIES:NATO(ident, name)
    if ident ~= nil and not isAssignedString(ident) then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `ident` must be assigned string, but was: " .. DumpPretty(ident)) end

    self.Attributes[DCAF.GBAD.Attribute.NATO] = ident
    GBAD_REGIMENT_DB.TypeProperties[ident] = self
    self:NATOName(name)
    return self
end

function GBAD_REGIMENT_GBAD_PROPERTIES:NATOName(value)
    if value ~= nil and not isAssignedString(value) then
        error("GBAD_REGIMENT_GBAD_PROPERTIES:New :: `value` must be assigned string, but was: " .. DumpPretty(value)) end

    self.Attributes[DCAF.GBAD.Attribute.NATOName] = value
    GBAD_REGIMENT_DB.TypeProperties[value] = self
    return self
end

GBAD_REGIMENT_GBAD_PROPERTIES:New("ERO HQ Bunker", GBAD_REGIMENT_GROUP_CATEGORY.HQ)
GBAD_REGIMENT_GBAD_PROPERTIES:New("EWR Generic radar tower", GBAD_REGIMENT_GROUP_CATEGORY.EWR)
GBAD_REGIMENT_GBAD_PROPERTIES:New("55G6 EWR", GBAD_REGIMENT_GROUP_CATEGORY.EWR, nil, true)
GBAD_REGIMENT_GBAD_PROPERTIES:New("1L13 EWR", GBAD_REGIMENT_GROUP_CATEGORY.EWR, nil, true)

-- Tier 1
GBAD_REGIMENT_GBAD_PROPERTIES:New("S-300PS 40B6M tr", GBAD_REGIMENT_GROUP_CATEGORY.SAM, 2):NATO(DCAF.GBAD.System.SA10, DCAF.GBAD.System.Grumble)
GBAD_REGIMENT_GBAD_PROPERTIES:New("SA-11 Buk SR 9S18M1", GBAD_REGIMENT_GROUP_CATEGORY.SAM, 2, true):NATO(DCAF.GBAD.System.SA11, DCAF.GBAD.System.Gadfly)

-- Tier 2
GBAD_REGIMENT_GBAD_PROPERTIES:New("SNR_75V", GBAD_REGIMENT_GROUP_CATEGORY.SAM, 2):NATO(DCAF.GBAD.System.SA2, DCAF.GBAD.System.Guideline)
GBAD_REGIMENT_GBAD_PROPERTIES:New("snr s-125 tr", GBAD_REGIMENT_GROUP_CATEGORY.SAM, 2):NATO(DCAF.GBAD.System.SA3, DCAF.GBAD.System.Goa)
GBAD_REGIMENT_GBAD_PROPERTIES:New("Kub 1S91 str", GBAD_REGIMENT_GROUP_CATEGORY.SAM, 2):NATO(DCAF.GBAD.System.SA6, DCAF.GBAD.System.Gainful)
GBAD_REGIMENT_GBAD_PROPERTIES:New("RPC_5N62V", GBAD_REGIMENT_GROUP_CATEGORY.SAM, 2):NATO(DCAF.GBAD.System.SA5, DCAF.GBAD.System.Gammon)

-- todo SA-5
GBAD_REGIMENT_GBAD_PROPERTIES:New("Osa 9A33 ln", GBAD_REGIMENT_GROUP_CATEGORY.SHORAD, 2, true):NATO(DCAF.GBAD.System.SA8, DCAF.GBAD.System.Gecko)
GBAD_REGIMENT_GBAD_PROPERTIES:New("Strela-1 9P31", GBAD_REGIMENT_GROUP_CATEGORY.SHORAD, 2, true):NATO(DCAF.GBAD.System.SA9, DCAF.GBAD.System.Gaskin)
GBAD_REGIMENT_GBAD_PROPERTIES:New("Strela-10M3", GBAD_REGIMENT_GROUP_CATEGORY.SHORAD, 2, true):NATO(DCAF.GBAD.System.SA13, DCAF.GBAD.System.Gopher)


-- local GBAD_REGIMENT_GBAD_PROPERTIES = {
--     ClassName = "GBAD_REGIMENT_GBAD_PROPERTIES",
--     ----
--     TypeName = nil,                 -- type name
--     SuppressionTime = nil,          -- time (seconds) for this type to remain suppressed before wakng up again
--     SkillFactors = {                -- used to add/cut to `SuppressionTime`
--         VariableValue:New(1.8, .5), -- Average
--         VariableValue:New(1.2, .5), -- Good
--         VariableValue:New(1.0, .5), -- High
--         VariableValue:New(0.7, .5), -- Excellent
--     }
-- }

-- function GBAD_REGIMENT_GBAD_PROPERTIES:New(typeName, suppressionTime)
--     local props = DCAF.clone(GBAD_REGIMENT_GBAD_PROPERTIES)
--     props.TypeName = typeName
--     props.SuppressionTime = suppressionTime
--     GBAD_REGIMENT_DB.TypeProperties[typeName] = props
--     return props
-- end

local GBAD_REGIMENT_GROUP_INFO = {
    ClassName = "GBAD_REGIMENT_GROUP_INFO",
    ------
    Spawn = nil,            -- #SPAWN
    Location = nil,         -- #DCAF.Location
    IsActive = false,       -- #boolean - indicates whether the group is currently spawned and active
    IsInoperable = nil,     -- #boolean - indicates whether the group is rendered inoprerable (malfuncitoning, out of stock, or otherwise not able to operate)
    UnitStates = {
        -- key   = #number - unit internal index
        -- value = #GBAD_REGIMENT_UNIT_STATE
    }
}

local GBAD_REGIMENT_UNIT_STATE = {
    Damage = 0,             -- #number [0,1] to reflect damage level (0 = undamaged; 1 = destroyed)
    DamageTime = nil,       -- #number Time when last damage was inflicted
}

function GBAD_REGIMENT_UNIT_STATE:New(unit, damage, time)
    local state = DCAF.clone(GBAD_REGIMENT_UNIT_STATE)
    state:Update(unit, damage, time)
    return state
end

function GBAD_REGIMENT_UNIT_STATE:Update(unit, damage, time)
    self.UnitName = unit.UnitName
    self.Damage = damage
    self.DamageTime = time or UTILS.SecondsOfToday()
end

local function getUnitKeyName(unit)
    local name = unit.UnitName
    local idxSuffixStart = string.find(name, "#%d%d%d%-%d%d")
    if not idxSuffixStart then
        return name
    end
    return string.sub(name, 1, idxSuffixStart-1) -- .. string.sub(name, idxSuffixStart + 5)
end

function GBAD_REGIMENT_GROUP_INFO:UpdateUnitDamage(unit, damage, time, isPreDestroyed)
    local key = getUnitKeyName(unit)
    local state = self.UnitStates[key]
    if not state then
        self.UnitStates[key] = GBAD_REGIMENT_UNIT_STATE:New(unit, damage, time)
    else
        state:Update(unit, damage, time)
    end
    self.IsDamaged = true
    self.IsPreDestroyed = isPreDestroyed
    self.IsDestroyed = not DCAF.GBAD:QueryIsSAMFunctional(unit:GetGroup())
end

function GBAD_REGIMENT_GROUP_INFO:Categorize(regiment)
    if self.Type then return self end
    local range, height, type, blind = regiment._iads:_GetSAMRange(self.Group.GroupName)
    self.Range = range
    self.Height = height
    self.Type = type
    self.Blind = blind
    return self
end

function GBAD_REGIMENT_GROUP_INFO:New(regiment, group, isInitialSpawn, isZoneLocked, category)
    local key = group.GroupName
    local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[regiment.Name]
    if not regimentIndex then
        regimentIndex = {}
        GBAD_REGIMENT_DB.RegimentIndex[regiment.Name] = regimentIndex
    end
    local info = GBAD_REGIMENT_DB.GroupIndex[key]
    if info then
        -- group was already indexed (by a different GBAD regiment)
Debug("nisse -- group was already indexed (by a different GBAD regiment): " .. group.GroupName)
        if DCAF.Debug and regimentIndex[key] then
            -- ensure same regiment doesn't index twice
            error("GBAD_REGIMENT_GROUP_INFO:New :: group '" .. key .. "' was already indexed by regiment '" .. regiment.Name .. "'")
        end
        regimentIndex[key] = info
        info.RefCount = info.RefCount + 1
        return info
    end
    if category == GBAD_REGIMENT_GROUP_CATEGORY.HQ then
        regiment.HQSkill = group:GetSkill()
    end

    -- create new index entry
    info = DCAF.clone(GBAD_REGIMENT_GROUP_INFO)
    info.Category = category
    info.Spawn = getSpawn(group.GroupName)
    info.Spawn:InitKeepUnitNames()
    info.TypeName = group:GetTypeName()
    info.Properties = GBAD_REGIMENT_DB.TypeProperties[info.TypeName]
    info.GroupName = group.GroupName
    info.IsPreBriefed = string.find(info.GroupName, GBAD_REGIMENT_DEFAULTS.PrebriefedPrefix)
    info.Location = DCAF.Location:NewNamed(group.GroupName, group:GetCoordinate())
    info.IsDynamicSpawn = not isInitialSpawn
    info.IsDynamicDespawn = regiment.Mode == DCAF.GBAD.RegimentMode.Dynamic
    info.RefSpawnCount = 0 -- increases/decreases as regiments spawn/destroy group (some groups can be referenced by multiple GBAD regiments)
    info.RefCount = 1      -- no. of GBAD regiments managing the group
    info.IsZoneLocked = isZoneLocked -- when true; the group will be used to monitor the GBAD regiment activation tripwire
    GBAD_REGIMENT_DB.GroupIndex[key] = info
    regimentIndex[key] = info
    if group:IsActive() then
        -- group wasn't Late Activated...
        Warning("GBAD_REGIMENT_GROUP_INFO:New :: group was not late activated: " .. info.GroupName .. " :: DESPAWNS GROUP")
        group:Destroy()
    end
    return info
end

function GBAD_REGIMENT_GROUP_INFO:ScanAirborneUnits(range, coalition, breakOnFirst, measureSlantRange, cacheTTL)
    return ScanAirborneUnits(self.Location, range, coalition, breakOnFirst, measureSlantRange, cacheTTL)
end

local function gbadRegiment_unitWasHit(unit, damage, time, isPreDestroyed) -- note: Was can pass a damage. Mainly for simulation/debugging purposes
    damage = damage or unit:GetDamageRelative()
    time = time or UTILS.SecondsOfToday()
    if damage == 0 then
        return end

    local group = unit:GetGroup()
    local key = GetGroupTemplateName(group) -- group:GetTemplate().GroupName OBSOLETE
    local info = GBAD_REGIMENT_DB.GroupIndex[key]
    if not info then
        return Warning(DCAF.GBAD.Regiment.ClassName .. " :: no info found for regiment group: " .. group.GroupName) end

    info:UpdateUnitDamage(unit, damage, time, isPreDestroyed)
    local group = unit:GetGroup()
    GBAD_REGIMENT_DB._notifyUnitHit(group, info, damage, time)
    return info.Group
end

function DCAF.GBAD.Regiment.SimulateHit(source, damage, time, isPreDestroyed)
    Debug("DCAF.GBAD.Regiment.SimulateHit :: source: " .. DumpPretty(source) .. " :: damage: " .. Dump(damage) .. " :: time: " .. Dump(time) .. " :: isPreDestroyed: " .. Dump(isPreDestroyed))
    local unit
    if isUnit(source) then
        unit = source
    else
        unit = getUnit(source)
    end
    if unit then
        gbadRegiment_unitWasHit(unit, damage, time, isPreDestroyed)
        return
    end

    local group
    if isGroup(source) then
        group = source
    else
        group = getGroup(source)
    end
    if not group then
        return Warning("DCAF.GBAD.Regiment:SimulateHit :: could not resolve group nor unit from: " .. DumpPretty(source)) end

    for _, u in ipairs(group:GetUnits()) do
        damage = damage or u:GetDamageRelative()
        if damage > 0 then
            gbadRegiment_unitWasHit(u, damage, time, isPreDestroyed)
        end
    end
end

function GBAD_REGIMENT_DB.GetSystemTypeName(system)
    local typeProperties = GBAD_REGIMENT_DB.TypeProperties[system]
    if typeProperties then
        return typeProperties.TypeName
    end
    for _, tp in pairs(GBAD_REGIMENT_DB.TypeProperties) do
        if tp.Attributes[DCAF.GBAD.Attribute.NATO] == system or tp.Attributes[DCAF.GBAD.Attribute.NATOName] == system then
            return tp.TypeName
        end
    end
end

function GBAD_REGIMENT_DB.GetRegiment(name)
    return GBAD_REGIMENT_DB.Regiments[name]
end

--- Notifies all regimentrs a GBAD group has been nit
function GBAD_REGIMENT_DB._notifyUnitHit(group, info, damage, time)
    local regimentIndexes = GBAD_REGIMENT_DB.RegimentIndex
    if not regimentIndexes then return end
    local key = info.GroupName
    for regimentName, regimentIndex in pairs(regimentIndexes) do
        if regimentIndex[key] then
            local regiment = GBAD_REGIMENT_DB.GetRegiment(regimentName)
            if regiment then regiment:_notifyUnitHit(group, info, damage, time) end
        end
    end
end

function GBAD_REGIMENT_DB.BeginMonitorDamage()
    if GBAD_REGIMENT_DB.IsMonitoringDamage then
        return end

    MissionEvents:OnUnitHit(function(event)
        if not event.TgtUnit then
            return end

        gbadRegiment_unitWasHit(event.TgtUnit)
    end)
end

local function restoreDamageState(group, info, now)
    if not info.IsDamaged and not info.IsInoperable then return end

    local function addStatics(statics)
        if not info.Statics then
            info.Statics = {}
        end
        for _, static in ipairs(statics) do
            table.insert(info.Statics, static)
        end
    end

    now = now or UTILS.SecondsOfToday()
    for _, unit in ipairs(group:GetUnits()) do
        local key = getUnitKeyName(unit)
        local state = info.UnitStates[key]
        if state and state.Damage > 0 then
            local damageAge = now - state.DamageTime
            local statics = SubstituteWithStatic(unit, state.Damage, damageAge)
            addStatics(statics)
        elseif info.IsInoperable then
            local statics = SubstituteWithStatic(unit, 0, 0)
            addStatics(statics)
        end
    end
end

--- Spawns a group to be managed by a #DCAF.GBAD.Regiment
-- @param #DCAF.GBAD.Regiment regiment :: a regiment to manage the spawned group
-- @param #string groupName :: the name of the group (template) to be spawned
-- @param #number interval :: (optional; default = configured staggered spawn interval) specifies an interval to be used for staggered spawning
-- @param #boolean lobotomize :: (optional; default = false) when set the spawned group will have its AI controller removed
function GBAD_REGIMENT_DB.Spawn(regiment, info, onSpawnedFunc, interval, lobotomize)
    local now = UTILS.SecondsOfToday()
    info.IsActive = true
    if info.IsDynamicSpawn then
        regiment.CountActiveDynamic = regiment.CountActiveDynamic + 1
        regiment.IsCountActiveDynamicChanged = true
    end
    info.RefSpawnCount = info.RefSpawnCount + 1

    local function initGroupDestruction()
        local pattern = regiment._destroyNamePattern or GBAD_REGIMENT_DEFAULTS.DestroyedUnitsPattern
        if info._isDestroyInitialized then return end
        info._isDestroyInitialized = true
        local destroyAll = string.find(info.GroupName, pattern)
        local time = regiment._destroyTime

        local function destroyUnit(unit)
            if not destroyAll and not string.find(unit.UnitName, pattern) then return end
            DCAF.GBAD.Regiment.SimulateHit(unit, 1, time, true)
        end

        local units = info.Group:GetUnits()
        for _, unit in ipairs(units) do
            destroyUnit(unit)
        end
    end

    local function includeInIADS()
        initGroupDestruction()
        if info.Category ~= GBAD_REGIMENT_GROUP_CATEGORY.SAM then
            return info.Group end

        if regiment:GetIsInoperable(info) then -- some SAM groups might not be available (see DCAF.GBAD.Regiment:InitOperableSystems)
            Debug("GBAD_REGIMENT_DB.Spawn :: group is inoperable (not included in IADS): " .. info.GroupName)
            return info.Group
        end
        if info.IsDestroyed then
            Debug("GBAD_REGIMENT_DB.Spawn :: group is destroyed (not included in IADS): " .. info.GroupName)
            return info.Group
        end
        Debug("GBAD_REGIMENT_DB.Spawn :: " .. regiment.Name .. " :: group is included in IADS: " .. info.GroupName)
        regiment._iads.SAM_Group:AddGroup(info.Group)
        if regiment.IsActive then
            regiment._iads:_RefreshSAMTable()
        end
        return info.Group
    end

    if info.RefSpawnCount > 1 then
        -- group was already spawned by another GBAD regiment...
        return includeInIADS()
    end

    local function spawnNow()
        if regiment.DespawnMethod ~= DCAF.GBAD.RegimentDespawnMethod.Lobotomize then
            GBAD_REGIMENT_DB.DespawnThreatRing(info)
        end

        regiment.HQSkill = regiment.HQSkill or Skill.Validate(regiment.HQ:GetSkill())
        local skill = Skill.GetHarmonized(nil, regiment.HQSkill)
        if DCAF.GBAD.Debug and regiment.Debug then
            DebugMessageTo(nil, "Spawning Rgmt " .. regiment.Name .. "/" .. info.Spawn.SpawnTemplatePrefix .. " :: sets skill: " .. skill .. " :: HQ: " .. regiment.HQSkill)
        end
        if not info.Group then
            info.Spawn:InitSkill(skill)
            info.Spawn:InitKeepUnitNames(true)
            info.Group = info.Spawn:Spawn()
            includeInIADS()
            if lobotomize then
                info.Group:SetAIOff()
            end
        else
            info.Group:SetAIOn()
        end
        if info.IsPreDestroyed or info.IsInoperable or (not lobotomize and (info.IsDynamicSpawn and info.IsDamaged)) then
            restoreDamageState(info.Group, info, now)
        end
        if isFunction(onSpawnedFunc) then
            onSpawnedFunc(info)
        end
    end

    interval = interval or regiment.SpawnInterval or GBAD_REGIMENT_DEFAULTS.SpawnInterval
    if GBAD_REGIMENT_DB._nextSpawn == nil or interval == 0 or GBAD_REGIMENT_DB._nextSpawn + interval*2 < now then
        GBAD_REGIMENT_DB._nextSpawn = now
    end

    if now < GBAD_REGIMENT_DB._nextSpawn then
        local delay = GBAD_REGIMENT_DB._nextSpawn - now
        DCAF.delay(function()
            spawnNow()
        end, delay)
    else
        spawnNow()
    end
    GBAD_REGIMENT_DB.BeginMonitorDamage()
    GBAD_REGIMENT_DB._nextSpawn = GBAD_REGIMENT_DB._nextSpawn + GBAD_REGIMENT_DEFAULTS.SpawnInterval
    return info
end

function GBAD_REGIMENT_DB.Despawn(regiment, info, onBeforeDespawnFunc)
    if not info.IsDynamicDespawn or not info.IsActive then
        return info end

    local function destroyStatics()
        if not info.Statics then
            return end

        for _, static in ipairs(info.Statics) do
            static:Destroy(false)
        end
    end

    info.IsActive = false
    local now = UTILS.SecondsOfToday()

    local function despawnNow()
        if isFunction(onBeforeDespawnFunc) and not onBeforeDespawnFunc(info) then
            -- group should no longer be despawned
            info.IsActive = true
            return
        end

        regiment.CountActiveDynamic = regiment.CountActiveDynamic - 1
        regiment.IsCountActiveDynamicChanged = true
        if info.Category == GBAD_REGIMENT_GROUP_CATEGORY.SAM then
            regiment._iads.SAM_Group:RemoveGroupsByName(info.Group.GroupName)
        end
        info.RefSpawnCount = info.RefSpawnCount - 1
        if info.RefSpawnCount > 0 then
            -- other regiments are still managing this group
            return end

-- Debug("GBAD_REGIMENT_DB.Despawn :: " .. info.GroupName .. " :: regiment.CountActiveDynamic: " .. regiment.CountActiveDynamic)

        if regiment.DespawnMethod == DCAF.GBAD.RegimentDespawnMethod.Despawn then
            info.Group:Destroy()
            info.Group = nil
            destroyStatics()
            if info.IsPreBriefed then
                -- restore threat ring...
                GBAD_REGIMENT_DB.SpawnThreatRing(info)
            end
        else
            info.Group:SetAIOff()
        end
    end

    local interval = GBAD_REGIMENT_DEFAULTS.DespawnInterval
    if GBAD_REGIMENT_DB._nextDespawn == nil or GBAD_REGIMENT_DB._nextDespawn + interval*2 < now then
        GBAD_REGIMENT_DB._nextDespawn = now
    end

    if now < GBAD_REGIMENT_DB._nextDespawn then
        local delay = GBAD_REGIMENT_DB._nextDespawn - now
Debug("GBAD_REGIMENT_DB.Despawn :: scheduled for despawn: " .. info.GroupName .. " :: delay: " .. delay)
        info._isScheduledDespawn = true
        DCAF.delay(function()
            despawnNow()
        end, delay)
    else
        despawnNow()
    end
    GBAD_REGIMENT_DB._nextDespawn = GBAD_REGIMENT_DB._nextDespawn + interval
    return info
end

function GBAD_REGIMENT_DB.SpawnAllInitial(regiment, onSpawnedFunc)
-- Debug("nisse - GBAD_REGIMENT_DB.SpawnAllInitial :: regiment: " .. regiment.Name .. " :: mode: " .. regiment.Mode)
    local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[regiment.Name]
    if not regimentIndex then
        return Error("GBAD_REGIMENT_DB.SpawnAllInitial :: no regiment index found for regiment '" .. regiment.Name .. "'") end

    local listSpawnedInfo = {}
    local interval
    if regiment.Mode == DCAF.GBAD.RegimentMode.OFF then
        return listSpawnedInfo
    elseif regiment.Mode == DCAF.GBAD.RegimentMode.Static then
        interval = 0
    end
    for _, info in pairs(regimentIndex) do
-- Debug("nisse - GBAD_REGIMENT_DB.SpawnAllInitial :: regiment: " .. regiment.Name .. " :: info: " .. DumpPretty(info))
        if not info.IsDynamicSpawn or regiment.SpawnMethod == DCAF.GBAD.RegimentDespawnMethod.Lobotomize then
            local lobotomize = info.IsDynamicSpawn
            GBAD_REGIMENT_DB.Spawn(regiment, info, onSpawnedFunc, interval, lobotomize)
            table.insert(listSpawnedInfo, info)
        end
    end
    return listSpawnedInfo
end

function GBAD_REGIMENT_DB.GetAll(regiment, criteriaFunc)
    local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[regiment.Name]
    if not regimentIndex then
        return Error("GBAD_REGIMENT_DB.GetAll :: no regiment index found for regiment '" .. regiment.Name .. "'") end

    local result = {}
    for _, info in pairs(regimentIndex) do
        if not criteriaFunc or criteriaFunc(info) then
            table.insert(result, info)
        end
    end
    return result
end

-- function GBAD_REGIMENT_DB.GetSpawnForType(typeName, countryID)
--     if not GBAD_REGIMENT_DB.Templates then
--         GBAD_REGIMENT_DB.Templates = {
--             -- key   = type name
--             -- value = #SPAWN
--         }
--     end
--     local spawn = GBAD_REGIMENT_DB.Templates[typeName]
--     if spawn then
--         return spawn end

--     local name = "GBAD_REGIMENT_" .. typeName
--     local template = TEMPLATE.GetGround(typeName, name, countryID)
--     spawn = SPAWN:NewFromTemplate(template, name)
--     GBAD_REGIMENT_DB.Templates[typeName] = spawn
--     return spawn
-- end

-- function GBAD_REGIMENT_DB.SpawnThreatRing(info)
--     if info._uncontrolledSpawn then
--         info._tempLauncherGroup = info._uncontrolledSpawn:SpawnFromCoordinate(info._tempLauncherCoord)
--         return
--     end

--     local group = getGroup(info.GroupName)
--     if not group then
--         return Warning("GBAD_REGIMENT_DB.SpawnThreatRing :: cannot resolve group '" .. info.GroupName .. "' :: EXITS") end

--     local function isTrackRadar(unit)
--         local desc = unit:GetDCSObject():getDesc()
-- -- Debug("nisse - GBAD_REGIMENT_DB.SpawnThreatRing :: desc: " .. DumpPrettyDeep(desc))
--         return desc.attributes["SAM TR"] == true
--     end

--     for _, unit in ipairs(group:GetUnits()) do
--         if isTrackRadar(unit) then
--             local coord = unit:GetCoordinate()
--             if coord then
--                 info._uncontrolledSpawn = GBAD_REGIMENT_DB.GetSpawnForType(unit:GetTypeName(), unit:GetCountry())
--                 info._tempLauncherGroup = info._uncontrolledSpawn:SpawnFromCoordinate(coord)
--                 info._tempLauncherCoord = coord
--                 -- return
--             end
--         end
--     end
-- end

function GBAD_REGIMENT_DB.GetThreatRingSpawn(info)
--     if info._threatRingSpawn then
--         return info._threatRingSpawn end

--     local function isTrackRadar(unit)
--         local desc = unit:GetDCSObject():getDesc()
--         if desc.attributes["SAM TR"] then
--             return unit:GetTypeName()
--         end
--     end

--     local function isLauncher(unit)
--         local desc = unit:GetDCSObject():getDesc()
-- Debug("nisse - GBAD_REGIMENT_DB.SpawnThreatRing :: desc: " .. DumpPrettyDeep(desc))
--         if desc.attributes["SAM LA"] then
--             return unit:GetTypeName()
--         end
--     end

--     local function resolveTypes(template)
--         local typeTR, typeLA
--         local group = info.Spawn:Spawn()
--         -- TODO -- is there really no other way to get to 
--         for _, unit in ipairs(group:GetUnits()) do
            
--         end

--         group:Destroy()
--     end

--     local function removeAllButTrackingRadarAndOneLauncher(template)





--         local typeTR, typeLA = resolveTypes(template)
--         local reducedUnits = {}
--         local idx = tableIndexOf(template.units, function(u)   return u.type == typeTR   end)
--         if idx then
--             reducedUnits[#reducedUnits+1] = template.units[idx]
--         end
--         idx = tableIndexOf(template.units, function(u)   return u.type == typeLA   end)
--         if idx then
--             reducedUnits[#reducedUnits+1] = template.units[idx]
--         end
--         if #reducedUnits < 2 then
--             return end

-- Debug("nisse -  GBAD_REGIMENT_DB.GetReducedSAMSpawn_createReducedSAMSiteSpawn :: reducedUnits: " .. DumpPrettyDeep(reducedUnits, 1))

--         template.units = reducedUnits
--         return template

--     end

    local template = info.Spawn:_GetTemplate(info.GroupName)
    if not template then
-- Debug("nisse - GBAD_REGIMENT_DB.GetReducedSAMSpawn :: could not get template :: EXITS")
        return end

    template = DCAF.clone(template)
    template.hidden = false
    template.hiddenOnMFD = false

    -- template = removeAllButTrackingRadarAndOneLauncher(template)

    local spawn = SPAWN:NewFromTemplate(template, "-TR-" .. info.GroupName)
    if not spawn then 
-- Debug("nisse - GBAD_REGIMENT_DB.GetReducedSAMSpawn :: could not get spawn from template :: EXITS")
        return end

    -- spawn:InitUnControlled(true)
    -- info._threatRingSpawn = spawn
    return spawn

--     local function isSearchRadar(unit)
--         local desc = unit:GetDCSObject():getDesc()
--         if desc.attributes["SAM SR"] then
--             return unit:GetTypeName()
--         end
--     end

--     local function isTrackRadar(unit)
--         local desc = unit:GetDCSObject():getDesc()
--         if desc.attributes["SAM TR"] then
--             return unit:GetTypeName()
--         end
--     end

--     local function isLauncher(unit)
--         local desc = unit:GetDCSObject():getDesc()
-- Debug("nisse - GBAD_REGIMENT_DB.SpawnThreatRing :: desc: " .. DumpPrettyDeep(desc))
--         if desc.attributes["SAM LA"] then
--             return unit:GetTypeName()
--         end
--     end

--     local typeSR, typeTR, typeLA

--     local function createReducedSAMSiteSpawn()
--         local reducedUnits = {}
--         local idx = tableIndexOf(template.units, function(u)   return u.type == typeSR   end)
--         if idx then
--             reducedUnits[#reducedUnits+1] = template.units[idx]
--         end
--         idx = tableIndexOf(template.units, function(u)   return u.type == typeTR   end)
--         if idx then
--             reducedUnits[#reducedUnits+1] = template.units[idx]
--         end
--         idx = tableIndexOf(template.units, function(u)   return u.type == typeLA   end)
--         if idx then
--             reducedUnits[#reducedUnits+1] = template.units[idx]
--         end
--         if #reducedUnits < 3 then
--             return end

-- Debug("nisse -  GBAD_REGIMENT_DB.GetReducedSAMSpawn_createReducedSAMSiteSpawn :: reducedUnits: " .. DumpPrettyDeep(reducedUnits, 1))

--         local newTemplate = DCAF.clone(template)
--         newTemplate.units = reducedUnits
--         return SPAWN:NewFromTemplate(newTemplate, name)
--     end

-- Debug("nisse -  GBAD_REGIMENT_DB.GetReducedSAMSpawn :: template.units: " .. DumpPrettyDeep(template.units, 2))

--     -- remove all but one Search Radar (SR), Tracking Radar (TR), and one Launcher (LA)...
--     for _, unit in ipairs(info.Group:GetUnits()) do
--         if not typeSR then
--             typeSR = isSearchRadar(unit)
--         elseif not typeTR then
--             typeTR = isTrackRadar(unit)
--         elseif not typeLA then
--             typeLA = isLauncher(unit)
--         else
--             uncontrolledSpawn = createReducedSAMSiteSpawn()
--             GBAD_REGIMENT_DB.UncontrolledSpawns[info.GroupName] = uncontrolledSpawn
--             if uncontrolledSpawn then
--                 SPAWN:InitUnControlled(true)
--             end
--         end
--     end
--     return uncontrolledSpawn
end

-- local function refineThreatRingSpawn(spawn, group)
--     --remove all units except tracking radar and one launcher...
--     local function isTrackRadar(unit)
--         local desc = unit:GetDCSObject():getDesc()
--         if desc.attributes["SAM TR"] then
--             return unit:GetTypeName()
--         end
--     end

--     local function isLauncher(unit)
--         local desc = unit:GetDCSObject():getDesc()
-- Debug("nisse - GBAD_REGIMENT_DB.SpawnThreatRing :: desc: " .. DumpPrettyDeep(desc))
--         if desc.attributes["SAM LA"] then
--             return unit:GetTypeName()
--         end
--     end

--     local function resolveTypes(template)
--         local typeTR, typeLA
--         local group = info.Spawn:Spawn()
--         -- TODO -- is there really no other way to get to the UNITs without having to spawn a GROUP?
--         for _, unit in ipairs(group:GetUnits()) do
            
--         end

--         group:Destroy()
--     end

--     return spawn
-- end

function GBAD_REGIMENT_DB.SpawnThreatRing(info)
    if not info.IsPreBriefed then
        return end

    local spawn = GBAD_REGIMENT_DB.GetThreatRingSpawn(info)
    if spawn then
        info._threatRingGroup = spawn:Spawn()
        info._threatRingGroup:SetAIOff()
        if not info._threatRingSpawn then
            info._threatRingSpawn = spawn -- refineThreatRingSpawn(spawn, info._threatRingGroup)
        end
        restoreDamageState(info._threatRingGroup, info)
    end
end

function GBAD_REGIMENT_DB.DespawnThreatRing(info)
    if info._threatRingGroup then
        info._threatRingGroup:Destroy()
        info._threatRingGroup = nil
    end
end

function GBAD_REGIMENT_DB.SpawnAllThreatRings(regiment)
    if not isAssignedString(GBAD_REGIMENT_DEFAULTS.PrebriefedPrefix) then
        return end

    for _, info in ipairs(GBAD_REGIMENT_DB.GetAllInactive(regiment)) do
-- Debug("nisse - GBAD_REGIMENT_DB.SpawnAllThreatRings :: info.GroupName: " .. Dump(info.GroupName) .. " :: IsPreBriefed: " .. Dump(info.IsPreBriefed))
        if info.IsPreBriefed then
            GBAD_REGIMENT_DB.SpawnThreatRing(info) -- ÅTERSTÄLL --
        end
    end
end

function GBAD_REGIMENT_DB.GetAllActive(regiment, filterFunc)
    return GBAD_REGIMENT_DB.GetAll(regiment, function(info)
        if not info.IsActive then
            return end

        if not filterFunc or filterFunc(info) then
            return info end
    end)
end

function GBAD_REGIMENT_DB.GetAllInactive(regiment, filterFunc)
    return GBAD_REGIMENT_DB.GetAll(regiment, function(info)
        if info.IsActive then
            return end

        if not filterFunc or filterFunc(info) then
            return info end
    end)
end

function GBAD_REGIMENT_DB.GetGBADProperties(group)
    return GBAD_REGIMENT_DB.TypeProperties[group:GetTypeName()]
end

function GBAD_REGIMENT_DB.GetGroupLocation(group)
    local info = GBAD_REGIMENT_DB.GroupIndex[group.GroupName]
    if info then
        return info.Location
    end
end

function GBAD_REGIMENT_DB.DespawnAllForRegiment(regiment, filterFunc)
    local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[regiment.Name]
    if not regimentIndex then
        error("GBAD_REGIMENT_DB.SpawnAllInitial :: no regiment index found for regiment '" .. regiment.Name .. "'") end

    for _, info in pairs(regimentIndex) do
        if info.IsActive and (not isFunction(filterFunc) or filterFunc(info)) then
            GBAD_REGIMENT_DB.Despawn(regiment, info)
        end
    end
end

function GBAD_REGIMENT_DB.DestroyAllDynamic(regiment)
    -- despawn all GROUPs that are not IsInitialSpawn
    GBAD_REGIMENT_DB.DespawnAllForRegiment(regiment, function(info)
        return info.IsDynamicSpawn
    end)
end

function DCAF.GBAD.Regiment:SetDefaultPrefixes(samPrefix, ewrPrefix, shoradPrefix)
    GBAD_REGIMENT_DEFAULTS.SAMPrefix = samPrefix or GBAD_REGIMENT_DEFAULTS.SAMPrefix
    GBAD_REGIMENT_DEFAULTS.EWRPrefix = ewrPrefix or GBAD_REGIMENT_DEFAULTS.EWRPrefix
    GBAD_REGIMENT_DEFAULTS.SHORADPrefix = shoradPrefix
end

function DCAF.GBAD.Regiment:SetDefaultPreBriefed(prefix)
    if prefix == nil then
        GBAD_REGIMENT_DEFAULTS.PrebriefedPrefix = nil
    elseif isAssignedString(prefix) then
        GBAD_REGIMENT_DEFAULTS.PrebriefedPrefix = prefix
    elseif isBoolean(prefix) then
        if not prefix then
            DCAF.GBAD.Regiment:SetDefaultPreBriefed(nil)
        else
            DCAF.GBAD.Regiment:SetDefaultPreBriefed("-PB-")
        end
    end
end

function DCAF.GBAD.Regiment:SetDefaultDistances(activation, postActivation, deactivation)
    self:SetDefaultActivationDistance(activation)
    self:SetDefaultPostActivationDistance(postActivation)
    self:SetDefaultDectivationDistance(deactivation)
end

--- Sets the default namng pattern for designating destroyed units or groups
--- @param pattern string - the pattern to be used
function DCAF.GBAD.Regiment:SetDefaultDestroyedUnitsPattern(pattern)
    if not isAssignedString(pattern) then return Error("DCAF.GBAD.Regiment:SetDefaultDestroyedUnitsPattern :: `pattern` must be assigned string, but was: " .. DumpPretty(pattern)) end
    GBAD_REGIMENT_DEFAULTS.DestroyedUnitsPattern = pattern
end

function DCAF.GBAD.Regiment:SetDefaultActivationDistance(value)
    if not isNumber(value) then
        return Error("DCAF.GBAD.Regiment:SetDefaultActivationDistance :: `value` must be number, but was: " .. DumpPretty(value)) end

    GBAD_REGIMENT_DEFAULTS.MonitorActivationDistance = value
end

function DCAF.GBAD.Regiment:SetDefaultPostActivationDistance(value)
    if not isNumber(value) then
        return Error("DCAF.GBAD.Regiment:SetDefaultPostActivationDistance :: `value` must be number, but was: " .. DumpPretty(value)) end

    GBAD_REGIMENT_DEFAULTS.MonitorPostActivationDistance = value
end

function DCAF.GBAD.Regiment:SetDefaultDectivationDistance(value)
    if not isNumber(value) then
        return Error("DCAF.GBAD.Regiment:SetDefaultDectivationDistance :: `value` must be number, but was: " .. DumpPretty(value)) end

    GBAD_REGIMENT_DEFAULTS.MonitorDeactivationDistance = value
end

function DCAF.GBAD.Regiment:SetDefaultSpawnInterval(value)
    if not isNumber(value) then
        return Error("DCAF.GBAD.Regiment:SetDefaultSpawnInterval :: `value` must be number, but was: " .. DumpPretty(value)) end

    GBAD_REGIMENT_DEFAULTS.SpawnInterval = value
end

function DCAF.GBAD.Regiment:SetDefaultDespawnInterval(value)
    if not isNumber(value) then
        return Error("DCAF.GBAD.Regiment:SetDefaultDespawnInterval :: `value` must be number, but was: " .. DumpPretty(value)) end

    GBAD_REGIMENT_DEFAULTS.DespawnInterval = value
end

function DCAF.GBAD.Regiment:SetDefaultMaxActiveSAMs(short, mid, long)
    if isNumber(short) then
        GBAD_REGIMENT_DEFAULTS.MaxActiveSams.Short = math.max(0, short)
    end
    if isNumber(mid) then
        GBAD_REGIMENT_DEFAULTS.MaxActiveSams.Mid = math.max(0, mid)
    end
    if isNumber(long) then
        GBAD_REGIMENT_DEFAULTS.MaxActiveSams.Long = math.max(0, long)
    end
end

function DCAF.GBAD.Regiment:SetDefaultPreventEvasiveRelocation(value)
    if not isBoolean(value) then value = true end
    GBAD_REGIMENT_DEFAULTS.UseEvasiveRelocation = value
end

function DCAF.GBAD.Regiment:InitMaxActiveSAMs(short, mid, long)
    if short ~= nil and not isBoolean(short) then
        error("DCAF.GBAD.Regiment.InitMaxActiveSAMs :: `short` must be number, but was: " .. DumpPretty(short)) end
    if short ~= nil and not isBoolean(mid) then
        error("DCAF.GBAD.Regiment.InitMaxActiveSAMs :: `mid` must be number, but was: " .. DumpPretty(mid)) end
    if short ~= nil and not isBoolean(long) then
        error("DCAF.GBAD.Regiment.InitMaxActiveSAMs :: `long` must be number, but was: " .. DumpPretty(long)) end

    self.MaxActiveSAMsShort = short
    self.MaxActiveSAMsMid = mid
    self.MaxActiveSAMsLong = long
    return self
end

function DCAF.GBAD.Regiment:GetIsInoperable(info)
    if info.IsInoperable ~= nil then return info.IsInoperable end
    info:Categorize(self)
    local diceRoll = math.random(1000)

    if info.Type == MANTIS.SamType.LONG then
        info.IsInoperable = diceRoll > self.AvailabilityFactors.Long*1000
    elseif info.Type == MANTIS.SamType.MEDIUM
        then info.IsInoperable = diceRoll > self.AvailabilityFactors.Medium*1000
    elseif info.Type == MANTIS.SamType.SHORT then
        info.IsInoperable = diceRoll > self.AvailabilityFactors.SHORADS*1000
    else
        error("DCAF.GBAD.Regiment:_isAvailable :: unknown SAM type: " .. DumpPretty(info.Type)) -- just a safe guard
    end
    if self.Debug and info.IsInoperable then
        -- visualize inoperable group
        local coord = info.Group:GetCoordinate()
        if coord then
            coord:MarkToAll("Inoperable system", false, "Type: " .. info.Type)
        end
    end
    return info.IsInoperable
end

--- Sets a value ([0-1]) for how many SAM groups will be operable, or randomly picked out as unavailable for the IADS (down for maintenance, broken, lack of munitions, etc)
--- @param long number - value [0-1] (eg. 0.1 = 10% of long range systems will be operable). Set to 1 for 100% operability
--- @param medium number - value [0-1] (eg. 0.1 = 10% of medium range systems will be operable). Set to 1 for 100% operability
--- @param shorads number - value [0-1] (eg. 0.1 = 10% of SHORADS will be operable). Set to 1 for 100% operability
function DCAF.GBAD.Regiment:InitRandomOperableSystems(long, medium, shorads)
    Debug("DCAF.GBAD.Regiment:InitOperableSystems :: long: " .. Dump(long) .. " :: medium: " .. Dump(medium) .. " :: shorads: " .. Dump(shorads))
    local function ensureRange(value, argName, default)
        if value == nil then return default end
        if not isNumber(value) then return default end
        if value < 0 or value > 1 then
            return Error("DCAF.GBAD.Regiment:InitOperableSystems :: `" .. argName .. "` must be numeric value betwen 0 thru 1, but was: " .. DumpPretty(long), default)
        end
        return value
    end

    self.AvailabilityFactors.Long = ensureRange(long, 'long', self.AvailabilityFactors.Long)
    self.AvailabilityFactors.Medium = ensureRange(medium, 'medium', self.AvailabilityFactors.Medium)
    self.AvailabilityFactors.SHORADS = ensureRange(shorads, 'short', self.AvailabilityFactors.SHORADS)
    return self
end

function DCAF.GBAD.Regiment:_notifyUnitHit(group, info, damage, time)
    Debug("DCAF.GBAD.Regiment:_notifyUnitHit :: info: " .. DumpPretty(info) .. " :: damage: " .. Dump(damage) .. " :: time: " .. UTILS.SecondsToClock(time))
    if info.IsDestroyed and not info._scheduledForExclusion then
        info._scheduledForExclusion = self.ExcludeDestroyedSAMDelay[self.HQSkill]:GetValue()
        local delay = info._scheduledForExclusion
        DCAF.delay(function()
            self._iads.SAM_Group:Remove(group.GroupName)
            self._iads:_RefreshSAMTable()
            Debug("DCAF.GBAD.Regiment:_notifyUnitHit :: destroyed group was excluded from IADS): " .. info.GroupName)
        end, delay)
        local minutes = UTILS.Round(delay / 60, 1)
        Debug("DCAF.GBAD.Regiment:_notifyUnitHit :: group is destroyed: " .. info.GroupName .. " :: will be excluded in ~" .. minutes .. " min")
    end
end

local function gbadRegimentSetZones(regiment, accept, reject, conflict)
    local function ensureList(source)
        if isList(source) then
            return source end

        return { source }
    end

    if not accept and not reject and not conflict then
        if regiment._zones then
            local z = regiment._zones
            accept = z._accept
            reject = z._reject
            conflict = z._conflict
        end
    end

    if regiment._iads then
        regiment._iads:AddZones(ensureList(accept), ensureList(reject), ensureList(conflict))
        return regiment
    end

    regiment._zones = { _accept = accept, _reject = reject, _conflict = conflict }
    return regiment
end

local function gbadRegimentSetSNSZones(regiment)
Debug(regiment.ClassName .. "/gbadRegimentSetSNSZones :: regiment._iads.Shorad: " .. Dump(regiment._iads.Shorad))

    if not regiment._iads or not regiment._shootAndScootPrefix then return end
    local setZones = SET_ZONE:New():FilterPrefixes(regiment._shootAndScootPrefix):FilterOnce()
    if setZones:Count() > 0 then
        regiment._iads:AddScootZones(setZones)
    end
    return regiment
end

  --- Function to set accept and reject zones.
  --- @param accept any accept single zone, or table of @{Core.Zone#ZONE} objects
  --- @param reject any reject single zone, or table of @{Core.Zone#ZONE} objects
  --- @param conflict any  single zone, or table of @{Core.Zone#ZONE} objects
  --- @return self DCAF.GBAD.Regiment 
  --- @usage
  -- Parameters are either zones, or **tables of Core.Zone#ZONE** objects!   
  -- This is effectively a 3-stage filter allowing for zone overlap. A coordinate is accepted first when   
  -- it is inside any AcceptZone. Then RejectZones are checked, which enforces both borders, but also overlaps of   
  -- Accept- and RejectZones. Last, if it is inside a conflict zone, it is accepted.
function DCAF.GBAD.Regiment:InitZones(accept, reject, conflict)
    return gbadRegimentSetZones(self, accept, reject, conflict)
end

local function gbadRegimentInitAfterStart(regiment)
    local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[regiment.Name]
    if not regimentIndex then
        return end

    for _, info in pairs(regimentIndex) do
        if info.IsDynamicSpawn then
            regiment.CountDynamic = regiment.CountDynamic+1
        end
    end
end

function DCAF.GBAD.Regiment:InitSNSZones(prefix, minDistance, maxDistance)
    if not isAssignedString(prefix) then return Error("DCAF.GBAD.Regiment:InitSNSZones :: `prefix` must be assigned string, but was: " .. DumpPretty(prefix), self) end
    self._shootAndScootPrefix = prefix
    if minDistance ~= nil and (not isNumber(minDistance) or minDistance < 1) then return Error("DCAF.GBAD.Regiment:InitSNSZones :: `minDistance` must be positive (>0) number, but was: " .. DumpPretty(minDistance), self) end
    self._shootAndScootMinDistance = minDistance
    if maxDistance ~= nil and (not isNumber(maxDistance) or maxDistance < 1) then return Error("DCAF.GBAD.Regiment:InitSNSZones :: `maxDistance` must be positive (>0) number, but was: " .. DumpPretty(maxDistance), self) end
    self._shootAndScootMaxDistance = maxDistance
    return self
end

--- Initializes custom shoot'n'scoot zones for one or more SHORAD groups
-- @param #Any source - Name of group, or list of group names
-- @param #Any zones - Zone name prefix or list of Zone names
function DCAF.GBAD.Regiment:InitCustomSNSZones(source, zones)
    if isAssignedString(source) then
        return self:InitCustomSNSZones({ source }, zones) end

    local setZones = SET_ZONE:New()
    if isAssignedString(zones) then
        setZones:FilterPrefixes(zones):FilterOnce()
    else
        for _, z in ipairs(zones) do
            local zone
            if isAssignedString(z) then
                zone = ZONE:FindByName(z)
            elseif isZone(z) then
                zone = z
            end
            if zone then
                setZones:AddZone(zone)
            end
        end
    end
    self._shootAndScootCustomZones = self._shootAndScootCustomZones or {}
    for _, groupName in ipairs(source) do
        self._shootAndScootCustomZones[groupName] = setZones
    end
    return self
end

local function gbadRegiment_filterAndIndexGroups(regiment, source, setZone, isInitialSpawn, category)
   if source == nil then
        return end

    local function indexIfIsInZones(group)
-- Debug("nisse - indexIfIsInZones :: group: " .. group.GroupName)
        local coord = group:GetCoordinate()
        if not coord then
            -- group was despawned by a different regiment
            local location = GBAD_REGIMENT_DB.GetGroupLocation(group)
            if not location then
                Warning("gbadRegiment_filterAndIndexGroups :: cursed group: " .. group.GroupName .. " :: regiment: " .. regiment.Name)
                return
            end
            coord = location:GetCoordinate()
        end
        local isZoneLocked = setZone and setZone:IsCoordinateInZone(coord)
        if not setZone or isZoneLocked then
            return GBAD_REGIMENT_GROUP_INFO:New(regiment, group, isInitialSpawn, isZoneLocked, category)
        end
    end

    if isClass(source, SET_GROUP) then
        source:ForEachGroup(function(group)
            indexIfIsInZones(group)
        end)
    elseif isList(source) then
        for _, group in ipairs(source) do
            indexIfIsInZones(group)
        end
    elseif isGroup(source) then
        return gbadRegiment_filterAndIndexGroups(regiment, { source }, setZone, isInitialSpawn, category)
    end
end

function DCAF.GBAD.Regiment:New(name, coalition, zones, hq, mode, sams, ewrs, awacs)
    if DCAF.Debug then
        if not isAssignedString(name) then
            return Error("DCAF.GBAD.Regiment:New :: `name` must be assigned string, but was: " .. DumpPretty(name)) end

        local validCoalition = Coalition.Resolve(coalition)
        if not validCoalition then
            return Error("DCAF.GBAD.Regiment:New :: `coalition` must be a valid coalition, but was: " .. DumpPretty(coalition)) end

        coalition = validCoalition
        if awacs ~= nil and not isAssignedString(awacs) then
            return Error("DCAF.GBAD.Regiment:New :: `awacs` must be either a string or #SET_GROUP, but was: " .. DumpPretty(awacs)) end
    end

    if GBAD_REGIMENT_DB.Regiments[name] then return Error("DCAF.GBAD.Regiment:New :: a GBAD regiment was alreacy created with same name: '" .. name .. "'") end

    local listZones
    if not isZone(zones) then
        if isList(zones) then
            for i, z in ipairs(zones) do
                if not isZone(zones) then
                    return Error("DCAF.GBAD.Regiment:New :: zones[" .. i .. "] must be a valid ZONE, but was: " .. DumpPretty(zones[i]))
                end
            end
            listZones = zones
        else
            return Error("DCAF.GBAD.Regiment:New :: `zones` must be a valid ZONE or a list of ZONEs, but was: " .. DumpPretty(zones))
        end
    else
        listZones = { zones }
    end
    local validHQ = getGroup(hq)
    if not validHQ then
        return Error("DCAF.GBAD.Regiment:New :: cannot resolve `hq`: " .. DumpPretty(hq)) end

    if not isAssignedString(sams) then
        sams = GBAD_REGIMENT_DEFAULTS.SAMPrefix
    end
    if not isAssignedString(ewrs) then
        ewrs = GBAD_REGIMENT_DEFAULTS.EWRPrefix
    end

    local regiment = DCAF.clone(DCAF.GBAD.Regiment)
    regiment.Name = name
    regiment.Coalition = { coalition }
    regiment.HQ = validHQ
    regiment.Zones = listZones
    regiment.SAMPrefix = sams
    regiment.EWRPrefix = ewrs
    regiment.AWACS = awacs
    regiment.Mode = mode or GBAD_REGIMENT_DEFAULTS.RegimentMode
    regiment.CountDynamic = 0
    regiment.AutoDeactivate = GBAD_REGIMENT_DEFAULTS.AutoDeactivation
    regiment.SpawnInterval = GBAD_REGIMENT_DEFAULTS.SpawnInterval
    -- TODO consider making the monitor options configurable
    regiment.MonitorActivationDistance = GBAD_REGIMENT_DEFAULTS.MonitorActivationDistance -- when enemy air groups gets inside this distance the regiment activates (spawns all inactive groups)
    regiment.MonitorPostActivationDistance = GBAD_REGIMENT_DEFAULTS.MonitorPostActivationDistance
    regiment.MonitorDeactivationDistance = GBAD_REGIMENT_DEFAULTS.MonitorDeactivationDistance
    regiment.UseEvasiveRelocation = GBAD_REGIMENT_DEFAULTS.UseEvasiveRelocation

    local set_sams = SET_GROUP:New():FilterPrefixes(regiment.SAMPrefix):FilterCoalitions(regiment.Coalition):FilterOnce()
    local set_ewrs = SET_GROUP:New():FilterPrefixes(regiment.EWRPrefix):FilterCoalitions(regiment.Coalition):FilterOnce()
    local set_zone = SET_ZONE:New()
    for _, zone in ipairs(regiment.Zones) do
        set_zone:AddZone(zone)
    end
    local isStaticMode = regiment.Mode == DCAF.GBAD.RegimentMode.Static
    gbadRegiment_filterAndIndexGroups(regiment, regiment.HQ, nil, true, GBAD_REGIMENT_GROUP_CATEGORY.HQ)
    -- gbadRegiment_filterAndIndexGroups(regiment, set_ewrs, nil --[[set_zone]], true, GBAD_REGIMENT_GROUP_CATEGORY.EWR)
    gbadRegiment_filterAndIndexGroups(regiment, set_sams, set_zone, isStaticMode, GBAD_REGIMENT_GROUP_CATEGORY.SAM)
    gbadRegiment_filterAndIndexGroups(regiment, nil, regiment.AWACS, isStaticMode, GBAD_REGIMENT_GROUP_CATEGORY.AWACS)
    regiment._set_ewrs = set_ewrs
    regiment._set_sams = set_sams
    GBAD_REGIMENT_DB.Regiments[name] = regiment
    return regiment
end

local function gbadRegimentHasCustomSpawnDelegates(regiment)

    return regiment._customGroupSpawn
end

--- Destroys all controlled groups and/or units that matches a specified naming pattern (default: "DESTROYED")
-- @paramm #string namePattern - Pattern to look for when destroying units/groups
-- @paramm #numberg time - Specifies time (seonds since midnight) for when units was destroyed. If vale is negative then time will be calculated as 'now' - time
function DCAF.GBAD.Regiment:DestroyUnits(namePattern, time)
    if not isNumber(time) then
        time = UTILS.SecondsOfToday()
    elseif time < 0 then
        time = UTILS.SecondsOfToday() + time
    end
    local clockTime = UTILS.SecondsToClock(time)
    Debug("DCAF.GBAD.Regiment:DestroyUnits :: " .. self.Name .. " :: namePattern: " .. Dump(namePattern) .. " :: time: " .. Dump(clockTime))
    if not isAssignedString(namePattern) then namePattern = GBAD_REGIMENT_DEFAULTS.DestroyedUnitsPattern end
    self._destroyNamePattern = namePattern
    self._destroyTime = time
    return self
end

--- Registers customized group delegate to control group spawn and despawn behavior. 
-- @param #string groupName - Name of group to be controlled by delegate
-- @param #DCAF.GBAD.RegimentGroupDelegate delegate - Delegate to be used for custom spawn logic
function DCAF.GBAD.Regiment:InitGroupDelegate(groupName, delegate)
    if not isAssignedString(groupName) then
        error("DCAF.GBAD.Regiment:InitGroupDelegate :: `groupName` must be assigned string, but was: '" .. DumpPretty(groupName)) end

    if not isClass(delegate, DCAF.GBAD.RegimentGroupDelegate) then
        error("DCAF.GBAD.Regiment:InitGroupDelegate :: `delegate` must be #" .. DCAF.GBAD.RegimentGroupDelegate.ClassName .. ", but was: '" .. DumpPretty(delegate)) end

    local info = GBAD_REGIMENT_DB.GroupIndex[groupName]
    if not info then
        Warning("DCAF.GBAD.Regiment:InitGroupDelegate :: group '" .. groupName .. "' is not managed by regiment '" .. self.Name .. "'")
        return self
    end

    if not self._groupDelegates then
        self._groupDelegates = {
            -- key   - #string - name of group to be controlled
            -- value - #DCAF.GBAD.RegimentGroupDelegate - the custom group spawn delegate
        }
    elseif self._groupDelegates[groupName] then
        error("DCAF.GBAD.Regiment:InitGroupDelegate :: group '" .. groupName .. "' is already managed by a custom group spawn delegate")
    end

    info.IsDynamicSpawn = true
    delegate.GroupName = groupName
    delegate.RegimentName = self.Name
    delegate.GroupInfo = info
    delegate.Coalition = self.Coalition
    delegate.Location = info.Location
    info.IsDynamicSpawn = info.IsDynamicSpawn or isFunction(delegate.ShouldSpawnFunc)
    info.IsDynamicDespawn = info.IsDynamicDespawn or isFunction(delegate.ShouldDespawnFunc)
    info.Delegate = delegate
    self._groupDelegates[groupName] = delegate
    return self
end

--- Specifies prebriefed GBAD systems (to produce threat rings)
-- @param #string key :: Can be attribute identifier or a #DCAF.GBAD.System (if the latter, no `value` should be passed)
-- @param #Any value :: An attribute value to be tested for the attribute (key) (eg. "Mobile", with key false, to make all fixed GBAD groups pre-briefed)
function DCAF.GBAD.Regiment:PreBriefed(key, value)
    if not isAssignedString(key) then
        error("DCAF.GBAD.Regiment:PreBriefed :: `key` must be assigned string, but was: " .. DumpPretty(key)) end

    local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[self.Name]

    local typeName = GBAD_REGIMENT_DB.GetSystemTypeName(key)
    if typeName then
        -- key is weapons system
        for _, info in pairs(regimentIndex) do
            if info.TypeName == typeName then
                info.IsPreBriefed = true
                Debug("DCAF.GBAD.Regiment:PreBriefed :: sets to PreBriefed :: info: " .. DumpPretty(info))
            end
        end
        return self
    end

    -- match attribute value...
    local function isAttributeMatch(info)
        if not info.Properties then
            return value == false or value == nil
        end
        if not info.Properties.Attributes[key] then
            return value == false or value == nil
        end
        return info.Properties.Attributes[key] == value
    end

    for _, info in pairs(regimentIndex) do
        if isAttributeMatch(info) then
            info.IsPreBriefed = true
            Debug("DCAF.GBAD.Regiment:PreBriefed :: sets to PreBriefed :: info: " .. DumpPretty(info))
        end
    end
    return self
end

function DCAF.GBAD.Regiment:OnActivated(func)
    if not isFunction(func) then
        error("DCAF.GBAD.Regiment:OnActivated :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onActivated = func
    return self
end

function DCAF.GBAD.Regiment:OnDeactivated(func)
    if not isFunction(func) then
        error("DCAF.GBAD.Regiment:OnDeactivated :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onDeactivated = func
    return self
end

function DCAF.GBAD.Regiment:Debug(value, uiDuration)
    if not isBoolean(value) then value = true end
    self.Debug = value
    if isNumber(uiDuration) then
        self.DebugUIDuration = uiDuration
    elseif value then
        self.DebugUIDuration = 20 -- seconds
    end
    if self._iads then
        self._iads:Debug(value)
    end
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:New()
    return DCAF.clone(DCAF.GBAD.RegimentGroupDelegate)
end

function DCAF.GBAD.RegimentGroupDelegate:OnShouldSpawn(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentGroupDelegate:OnShouldSpawn :: `func` must be function, but was: " .. DumpPretty(func)) end

    self.ShouldSpawnFunc = func
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:OnShouldDespawn(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentGroupDelegate:OnShouldDespawn :: `func` must be function, but was: " .. DumpPretty(func)) end

    self.ShouldDespawnFunc = func
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:OnShouldActivate(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentGroupDelegate:OnShouldActivate :: `func` must be function, but was: " .. DumpPretty(func)) end

    self.ShouldActivate = func
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:OnShouldDeactivate(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentGroupDelegate:OnShouldDeactivate :: `func` must be function, but was: " .. DumpPretty(func)) end

    self.ShouldDeactivate = func
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:OnActivated(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentGroupDelegate:OnActivated :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onActivated = func
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:OnDeactivated(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentGroupDelegate:OnDeactivated :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onDeactivated = func
    return self
end

local function gbadRegimentGetDelegate(regiment, info)
    if not regiment._groupDelegates then
        return end

    if isAssignedString(info) then
        return regiment._groupDelegates[info] end

    return regiment._groupDelegates[info.GroupName]
end

local function isGroupDelegateSpawning(regiment, info)
    local delegate = gbadRegimentGetDelegate(regiment, info)
    if delegate and delegate:ShouldSpawnFunc(delegate) then
        return delegate
    end
end

local function gbadRegiment_monitorActivationBegin(regiment)
    local hostileCoalition = GetHostileCoalition(regiment.Coalition)

    local function isHostileInRange(_info)
        local closestUnits = ScanAirborneUnits(_info.Location, regiment.MonitorActivationDistance, hostileCoalition, true, true)
        return closestUnits:Any()
    end

    regiment._monitorScheduleID = DCAF.startScheduler(function()
        for _, info in pairs(GBAD_REGIMENT_DB.GetAllInactive(regiment)) do
            local spawnDelegate = isGroupDelegateSpawning(regiment, info)
            if (spawnDelegate and spawnDelegate.IncludeInIADS) or isHostileInRange(info) then
                DCAF.stopScheduler(regiment._monitorScheduleID)
                regiment._monitorScheduleID = nil
                DCAF.delay(function()
                    regiment:Activate(info, spawnDelegate)
                end, 2)
                break
            end
        end

    end, 15)
end

function DCAF.GBAD.RegimentGroupDelegate:OnBeforeSpawn(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentActivateGroup:OnBeforeSpawn :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onBeforeSpawnFunc = func
    return self
end

function DCAF.GBAD.RegimentGroupDelegate:OnSpawned(func)
    if not isFunction(func) then
        error("DCAF.GBAD.RegimentActivateGroup:OnSpawned :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onSpawnedFunc = func
    return self
end

--- Monitors hostile air to activate more and more GBAD groups as they get in range, and deactivate as they get out of range
local function gbadRegiment_monitorPostActivationBegin(regiment, interval, infoList)
    local hostileCoalition = GetHostileCoalition(regiment.Coalition)
    local monitorRange = math.max(regiment.MonitorDeactivationDistance, regiment.MonitorPostActivationDistance)

    local function monitor(info)
        if not info.IsActive and not info.IsDynamicSpawn then
            return end
        if info.IsActive and not info.IsDynamicDespawn then
            return end

        local function isHostileInRange(_info)
            local closestUnits = ScanAirborneUnits(_info.Location, monitorRange, hostileCoalition, true, true)
            return closestUnits:Any()
        end

        local function spawn(delegate)
            if not info.IsActive then
                local onSpawnedFunc
                if delegate then
                    onSpawnedFunc = delegate._onSpawnedFunc
                end
                GBAD_REGIMENT_DB.Spawn(regiment, info, onSpawnedFunc)
            end
        end

        local delegate = info.Delegate

        if not info.IsActive then
            local onCheckSpawn
            if delegate then
                onCheckSpawn = delegate.ShouldSpawnFunc or isHostileInRange
            else --if info.IsDynamicSpawn then
                onCheckSpawn = isHostileInRange
            end
-- if delegate then
-- Debug("nisse - gbadRegiment_monitorPostActivationBegin :: onCheckSpawn: " .. Dump(onCheckSpawn(info)))
-- end                
            if onCheckSpawn(info) then
                spawn(delegate)
            end
        else
            local onCheckDespawn
            if delegate then
                onCheckDespawn = delegate.ShouldDespawnFunc
            else --if info.IsDynamicDespawn then
                onCheckDespawn = function(_info) return not isHostileInRange(_info) end
            end
            if onCheckDespawn and onCheckDespawn(info) then 
                GBAD_REGIMENT_DB.Despawn(regiment, info, onCheckDespawn)
            end
        end

--         if delegate then
--             if delegate.ShouldSpawnFunc and delegate.ShouldSpawnFunc(delegate) then
--                 spawn(delegate)
--             end
--         elseif isHostileInRange(info) then
--             -- todo Consider also including hostile air heading/aspect to not include non-approaching units
--             spawn()
--         else
-- if delegate then
-- Debug("nisse - gbadRegiment_monitorPostActivationBegin_monitor :: delegate despawn :: info: " .. DumpPretty(info))
-- end
--             if isDelegateDespawning() or (info.IsActive and info.IsDynamicDespawn) then -- only despawn fully dynamic groups
--                 local onCheckDespawnFunc
--                 if delegate then
--                     onCheckDespawnFunc = delegate.ShouldSpawnFunc
--                 else
--                     onCheckDespawnFunc = function(_info)
--                         return not isHostileInRange(_info)
--                     end
--                 end
--                 GBAD_REGIMENT_DB.Despawn(regiment, info, onCheckDespawnFunc)
--             end
--         end
    end

    local function monitorPostActivationEnd()
        DCAF.stopScheduler(regiment._monitorScheduleID)
        regiment._monitorScheduleID = nil
    end

    regiment._monitorScheduleID = DCAF.startScheduler(function()
        infoList = infoList or GBAD_REGIMENT_DB.GetAll(regiment)
        for _, info in ipairs(infoList) do
            monitor(info)
        end
        if not regiment.IsCountActiveDynamicChanged then
            return end

        regiment.IsCountActiveDynamicChanged = false
        if regiment.CountActiveDynamic == 0 then
            monitorPostActivationEnd()
            DCAF.delay(function()
                regiment:Deactivate()
            end, 2)
        elseif regiment.CountActiveDynamic == regiment.CountDynamic then
            monitorPostActivationEnd()
            regiment:OnFullyActive()
        end

    end, interval or 5)
end

    

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                   MANTIS IMPROVEMENTS
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- GBAD_REGIMENT_GBAD_PROPERTIES:New("S-300PS 40B6M tr", 30)    -- SA-10 :: 30 seconds suppression time
-- GBAD_REGIMENT_GBAD_PROPERTIES:New("Hawk pcp", Minutes(1.5))  -- HAWK  :: 90 seconds suppression time
-- GBAD_REGIMENT_GBAD_PROPERTIES:New("SNR_75V", Minutes(3))     -- SA-2  :: 180 seconds suppression time
-- GBAD_REGIMENT_GBAD_PROPERTIES:New("RPC_5N62V", Minutes(3))   -- SA-5  :: 180 seconds suppression time

local function regimentHasSpawnDelegates(regiment)
    if not regiment._groupDelegates then
        return end

    for groupName, delegate in pairs(regiment._groupDelegates) do
        if delegate.ShouldSpawnFunc then
            return true end
    end
end

local function hackMantisIADS(regiment, iads)

    function iads:_CheckLoop(samset,detset,dlink,limit)
        local regimentIndex = GBAD_REGIMENT_DB.RegimentIndex[regiment.Name] -- //hacked//

        self:T(self.lid .. "CheckLoop " .. #detset .. " Coordinates")
        local switchedon = 0
        for _,_data in pairs (samset) do
          local samcoordinate = _data[2]
          local name = _data[1]
          local radius = _data[3]
          local height = _data[4]
          local blind = _data[5] * 1.25 + 1
          local samgroup = GROUP:FindByName(name)
-- Debug("nisse - iads:_CheckLoop :: name: " .. name .. " :: radius: " .. radius .. " :: height: " .. height)
          local IsInZone, Distance, coord = self:_CheckObjectInZone(detset, samcoordinate, radius, height, dlink) -- //hacked// -- also receives target coordinate
-- Debug("nisse - iads:_CheckLoop :: IsInZone: " .. Dump(IsInZone))
          local tgtRelativeAltitude                     -- //hacked//
          if coord then                                 -- //hacked//
            tgtRelativeAltitude = coord.y - samcoordinate.y
          end
          local suppressed = self.SuppressedGroups[name] or false
          local activeshorad = self.Shorad.ActiveGroups[name] or false
          local groupName = GetGroupOrUnitName(name)    -- //hacked//
          local info = regimentIndex[groupName]         -- //hacked//
-- nisse
-- if not info then
--     Debug("nisse - hackMantisIADS__CheckLoop :: info not found: " .. groupName)
-- end
          info.IsActiveShorad = activeshorad            -- //hacked//
          local delegate = info.Delegate                -- //hacked//

          local function shouldActivate()               -- //hacked//
            if delegate and delegate.ShouldActivate then
                if delegate.ShouldActivate(info, Distance, tgtRelativeAltitude) then
-- Debug("nisse - delegate for group (" .. info.GroupName ..") says activate")
                    return true
                else
-- Debug("nisse - delegate for group (" .. info.GroupName ..") says do not activate")
                    return false
                end
            end

            return true
          end

          local function shouldDeactivate()             -- //hacked//
            if delegate and delegate.ShouldDeactivate then
                return delegate.ShouldDeactivate(info) end

            return true
          end

          local function triggerOnActivatedDeactivated(value) -- //hacked//
            if value then
                if delegate and delegate._onActivated then
                    return delegate._onActivated(info) end

                if regiment._onActivated then
                    return regiment._onActivated(info) end
            else
                if delegate and delegate._onDeactivated then
                    return delegate._onDeactivated(info) end

                if regiment._onActivated then
                    return regiment._onDeactivated(info) end
            end
          end

          if IsInZone and not suppressed and not activeshorad then --check any target in zone and not currently managed by SEAD
-- Debug("nisse - iads:_CheckLoop :: samgroup:IsAlive(): " .. Dump(samgroup:IsAlive()))
            if samgroup:IsAlive() and shouldActivate() then -- //hacked//
              -- switch on SAM
              local switch = false
              if self.UseEmOnOff and switchedon < limit then
                -- DONE: add emissions on/off
                samgroup:EnableEmission(true)
                switchedon = switchedon + 1
                switch = true
              elseif (not self.UseEmOnOff) and switchedon < limit then
                samgroup:OptionAlarmStateRed()
                switchedon = switchedon + 1
                switch = true
              end
              if switch then
                triggerOnActivatedDeactivated(true)         -- //hacked//
              end
              if self.SamStateTracker[name] ~= "RED" and switch then
                self:__RedState(1,samgroup)
                self.SamStateTracker[name] = "RED"
              end
              -- link in to SHORAD if available
              -- DONE: Test integration fully
              if self.ShoradLink and (Distance < self.ShoradActDistance or Distance < blind ) then -- don't give SHORAD position away too early
                local Shorad = self.Shorad
                local radius = self.checkradius
                local ontime = self.ShoradTime
                Shorad:WakeUpShorad(name, radius, ontime)
                self:__ShoradActivated(1,name, radius, ontime)
              end
              -- debug output
              if (self.debug or self.verbose) --[[ and switch  ]] then  -- //hacked// -- always report RED, noto nly when switched
                local text = string.format("SAM %s in alarm state RED!", name)
                local m=MESSAGE:New(text,10,"MANTIS"):ToAllIf(self.debug)
                if self.verbose then self:I(self.lid..text) end
              end
            end --end alive
          else
            if samgroup:IsAlive() and not suppressed and not activeshorad and shouldDeactivate() then -- //hacked//
              -- switch off SAM
              if self.UseEmOnOff  then
                samgroup:EnableEmission(false)
              else
                samgroup:OptionAlarmStateGreen()
              end
              triggerOnActivatedDeactivated(false)          -- //hacked//
              if self.SamStateTracker[name] ~= "GREEN" then
                self:__GreenState(1,samgroup)
                self.SamStateTracker[name] = "GREEN"
              end
              if self.debug or self.verbose then
                local text = string.format("SAM %s in alarm state GREEN!", name)
                local m=MESSAGE:New(text,10,"MANTIS"):ToAllIf(self.debug)
                if self.verbose then self:I(self.lid..text) end
              end
            end --end alive
          end --end check
        end --for for loop
        return self
    end

    function iads:_CheckObjectInZone(dectset, samcoordinate, radius, height, dlink) -- hacked to also produce relative altitude
-- Debug("nisse - iads:_CheckObjectInZone...")
        self:T(self.lid.."_CheckObjectInZone")
        -- check if non of the coordinate is in the given defense zone
        local rad = radius or self.checkradius
        local set = dectset
        if dlink then
            -- DEBUG
            set = self:_PreFilterHeight(height)
        end
-- Debug("nisse - iads:_CheckObjectInZone :: set: " .. DumpPretty(set))
        for _,_coord in pairs (set) do
            local coord = _coord  -- get current coord to check
            -- output for cross-check
            local targetdistance = samcoordinate:DistanceFromPointVec2(coord)
            if not targetdistance then
                targetdistance = samcoordinate:Get2DDistance(coord)
            end
            -- check accept/reject zones
            local zonecheck = true
            if self.usezones then
                -- DONE
                zonecheck = self:_CheckCoordinateInZones(coord)
            end
            if self.verbose and self.debug then
                -- local dectstring = coord:ToStringLLDMS()  --//hacked//-- dead code
                local samstring = samcoordinate:ToStringLLDMS()
                local inrange = "false"
                if targetdistance <= rad then
                    inrange = "true"
                end
                local text = string.format("Checking SAM at %s | Targetdist %d | Rad %d | Inrange %s", samstring, targetdistance, rad, inrange)
                -- local m = MESSAGE:New(text,10,"Check"):ToAllIf(self.debug)  --//hacked//-- dead code
                self:T(self.lid..text)
            end
            -- end output to cross-check
            if targetdistance <= rad and zonecheck then
                return true, targetdistance, coord --//hacked//-- passes back coordinate
            end
        end
        return false, 0
    end

    function iads:StartIntelDetection()
        self:T(self.lid.."Starting Intel Detection")
        -- DEBUG
        -- start detection
        local groupset = self.EWR_Group -- //hacked// -- seems MANTIS should use the correct set of EWR when running in advanced (corrects problem with not detecting contacts from EWR)
        if self.advanced then           -- //hacked//
          groupset = self.Adv_EWR_Group -- //hacked//
        else                            -- //hacked//
          groupset = self.EWR_Group     -- //hacked//
        end                             -- //hacked//
        local samset = self.SAM_Group
        
        self.intelset = {}
        
        local IntelOne = INTEL:New(groupset,self.Coalition,self.name.." IntelOne")
        --IntelOne:SetClusterAnalysis(true,true)
        --IntelOne:SetClusterRadius(5000)
        IntelOne:Start()
        
        local IntelTwo = INTEL:New(samset,self.Coalition,self.name.." IntelTwo")
        --IntelTwo:SetClusterAnalysis(true,true)
        --IntelTwo:SetClusterRadius(5000)
        IntelTwo:Start()
        
        local IntelDlink = INTEL_DLINK:New({IntelOne,IntelTwo},self.name.." DLINK",22,300)
        IntelDlink:__Start(1)
        
        self:SetUsingDLink(IntelDlink)
        
        table.insert(self.intelset, IntelOne)
        table.insert(self.intelset, IntelTwo)
        
        return IntelDlink
      end

    -- --- this hack makes it possible to not pass an Accept zone, just a reject zone...
    -- function iads:_CheckCoordinateInZones(coord)
    --     -- DEBUG
    --     self:T(self.lid.."_CheckCoordinateInZones")
    --     local inzone = #self.AcceptZones == 0               -- //hacked//
    --     -- acceptzones
    --     if #self.AcceptZones > 0 then
    --       inzone = false
    --       for _,_zone in pairs(self.AcceptZones) do
    --         local zone = _zone -- Core.Zone#ZONE
    --         if zone:IsCoordinateInZone(coord) then
    --           inzone = true
    --           self:T(self.lid.."Target coord in Accept Zone!")
    --           break
    --         end
    --       end
    --     end
    --     -- rejectzones
    --     if #self.RejectZones > 0 and inzone then -- maybe in accept zone, but check the overlaps
    --       for _,_zone in pairs(self.RejectZones) do
    --         local zone = _zone -- Core.Zone#ZONE
    --         if zone:IsCoordinateInZone(coord) then
    --           inzone = false
    --           self:T(self.lid.."Target coord in Reject Zone!")
    --           break
    --         end
    --       end
    --     end
    --     -- conflictzones
    --     if #self.ConflictZones > 0 and not inzone then -- if not already accepted, might be in conflict zones
    --       for _,_zone in pairs(self.ConflictZones) do
    --         local zone = _zone -- Core.Zone#ZONE
    --         if zone:IsCoordinateInZone(coord) then
    --           inzone = true
    --           self:T(self.lid.."Target coord in Conflict Zone!")
    --           break
    --         end
    --       end
    --     end   
    --     return inzone
    --   end

      -- hacks the SHORAD shoot'n'scoot behavior, allowing for differently sized AOs and also custom zones for individual SHORAD groups
      function iads:onafterStart(From, Event, To)
        self:T({From, Event, To})
        self:T(self.lid.."Starting MANTIS")
        self:SetSAMStartState()

        function self.mysead:onafterManageEvasion(From,Event,To,_targetskill,_targetgroup,SEADPlanePos,SEADWeaponName,SEADGroup,timeoffset,Weapon)
            local timeoffset = timeoffset  or 0
            if _targetskill == "Random" then -- when skill is random, choose a skill
                local Skills = { "Average", "Good", "High", "Excellent" }
                _targetskill = Skills[ math.random(1,4) ]
            end
            --self:T( _targetskill )
            if self.TargetSkill[_targetskill] then
                local _evade = math.random (1,100) -- random number for chance of evading action
                if (_evade > self.TargetSkill[_targetskill].Evade) then
                    self:T("*** SEAD - Evading")
                    -- calculate distance of attacker
                    local _targetpos = _targetgroup:GetCoordinate()
                    local _distance = self:_GetDistance(SEADPlanePos, _targetpos)
                    -- weapon speed
                    local hit, data = self:_CheckHarms(SEADWeaponName)
                    local wpnspeed = 666 -- ;)
                    local reach = 10
                    if hit then
                        local wpndata = SEAD.HarmData[data]
                        reach = wpndata[1] * 1.1
                        local mach = wpndata[2]
                        wpnspeed = math.floor(mach * 340.29)
                        if Weapon then
                            wpnspeed = Weapon:GetSpeed()
                            self:T(string.format("*** SEAD - Weapon Speed from WEAPON: %f m/s",wpnspeed))
                        end
                    end
                    -- time to impact
                    local _tti = math.floor(_distance / wpnspeed) - timeoffset -- estimated impact time
                    if _distance > 0 then
                        _distance = math.floor(_distance / 1000) -- km
                    else
                        _distance = 0
                    end

                    self:T( string.format("*** SEAD - target skill %s, distance %dkm, reach %dkm, tti %dsec", _targetskill, _distance,reach,_tti ))

                    if reach >= _distance then
                        self:T("*** SEAD - Shot in Reach")

                        local function SuppressionStart(args)
                            self:T(string.format("*** SEAD - %s Radar Off & Relocating",args[2]))
                            local grp = args[1] -- Wrapper.Group#GROUP
                            local name = args[2] -- #string Group Name
                            local attacker = args[3] -- Wrapper.Group#GROUP
                            if self.UseEmissionsOnOff then
                                grp:EnableEmission(false)
                            end
                            grp:OptionAlarmStateGreen() -- needed else we cannot move around
-- Debug("nisse - GBAD.Regiment/onafterManageEvasion/SuppressionStart :: .UseEvasiveRelocation: " .. DumpPretty(self.UseEvasiveRelocation))
                            if regiment.UseEvasiveRelocation then  -- //hacked//
                                grp:RelocateGroundRandomInRadius(20,300,false,false,"Diamond",true)
                            end
                            if self.UseCallBack then
                                local object = self.CallBack
                                object:SeadSuppressionStart(grp,name,attacker)
                            end
                        end
                
                        local function SuppressionStop(args)
                            self:T(string.format("*** SEAD - %s Radar On",args[2]))
                            local grp = args[1]  -- Wrapper.Group#GROUP
                            local name = args[2] -- #string Group Name
                            if self.UseEmissionsOnOff then
                                grp:EnableEmission(true)
                            end
                            grp:OptionAlarmStateRed()
                            grp:OptionEngageRange(self.EngagementRange)
                            self.SuppressedGroups[name] = false
                            if self.UseCallBack then
                                local object = self.CallBack
                                object:SeadSuppressionEnd(grp,name)
                            end
                        end
                
                        -- randomize switch-on time
                        local delay = math.random(self.TargetSkill[_targetskill].DelayOn[1], self.TargetSkill[_targetskill].DelayOn[2])
                        if delay > _tti then delay = delay / 2 end -- speed up
                        if _tti > 600 then delay =  _tti - 90 end -- shot from afar, 600 is default shorad ontime
                
                        local SuppressionStartTime = timer.getTime() + delay
                        local SuppressionEndTime = timer.getTime() + delay + _tti + self.Padding + delay
                        local _targetgroupname = _targetgroup:GetName()
-- Debug("nisse - GBAD.Regiment/onafterManageEvasion :: .SuppressedGroups: " .. DumpPretty(self.SuppressedGroups))                 
                        if not self.SuppressedGroups[_targetgroupname] then
                            self:T(string.format("*** SEAD - %s | Parameters TTI %ds | Switch-Off in %ds",_targetgroupname,_tti,delay))
                            timer.scheduleFunction(SuppressionStart,{_targetgroup,_targetgroupname, SEADGroup},SuppressionStartTime)
                            timer.scheduleFunction(SuppressionStop,{_targetgroup,_targetgroupname},SuppressionEndTime)
                            self.SuppressedGroups[_targetgroupname] = true
                            if self.UseCallBack then
                                local object = self.CallBack
                                object:SeadSuppressionPlanned(_targetgroup,_targetgroupname,SuppressionStartTime,SuppressionEndTime, SEADGroup)
                            end
                        end
                
                    end
                end
            end
            return self
        end

        if not INTEL then
          self.Detection = self:StartDetection()
        else
          self.Detection = self:StartIntelDetection()
        end
        --[[
        if self.advAwacs and not self.automode then
          self.AWACS_Detection = self:StartAwacsDetection()
        end
        --]]
        if self.autoshorad then
          self.Shorad = SHORAD:New(self.name.."-SHORAD",self.name.."-SHORAD",self.SAM_Group,self.ShoradActDistance,self.ShoradTime,self.coalition,self.UseEmOnOff)
          self.Shorad:SetDefenseLimits(80,95)
          self.ShoradLink = true
          self.Shorad.Groupset=self.ShoradGroupSet
          self.Shorad.debug = self.debug
        end
        if self.shootandscoot and self.SkateZones then
          self.Shorad:AddScootZones(self.SkateZones,self.SkateNumber or 3)
        end
        self:__Status(-math.random(1,10))

        local function getPossibleShootAndScootZones(setZones, shoradGroup, minDistance, maxDistance)
-- Debug("nisse - getPossibleShootAndScootZones :: shoradGroup: " .. shoradGroup.GroupName .. " :: regiment._shootAndScootCustomZones: " .. DumpPretty(regiment._shootAndScootCustomZones))
            local possibleZones = {}
            if regiment._shootAndScootCustomZones then
                local key = GetGroupOrUnitName(shoradGroup.GroupName)
-- Debug("nisse - getPossibleShootAndScootZones :: key: " .. key)
                local customSetZones = regiment._shootAndScootCustomZones[key]
                if customSetZones then
-- Debug("nisse - getPossibleShootAndScootZones :: customSetZones.Set: " .. DumpPretty(customSetZones.Set))
                    setZones = customSetZones.Set
                end
            end
            local coordGroup = shoradGroup:GetCoordinate()
            for _,_zone in pairs(setZones) do
                local zone = _zone -- Core.Zone#ZONE_RADIUS
                local dist = coordGroup:Get2DDistance(zone:GetCoordinate())
-- Debug("nisse - getPossibleShootAndScootZones :: zone: " .. zone.ZoneName .. " :: dist: " .. dist)
                if dist >= minDistance and dist <= maxDistance then
                    possibleZones[#possibleZones+1] = zone
                    if #possibleZones == shoradGroup.SkateNumber then break end
                end
              end
              return possibleZones
        end

        function self.Shorad:onafterShootAndScoot(From,Event,To,Shorad)
            self:T( { From,Event,To } )
            -- local possibleZones = {}                                     -- //hacked//
            -- local mindist = 100                                          -- //hacked//
            -- local maxdist = 5000                                         -- //hacked// -- changes from 3kn to 5km AO
            if Shorad and Shorad:IsAlive() then
              local possibleZones = getPossibleShootAndScootZones(self.SkateZones.Set, Shorad, regiment._shootAndScootMinDistance or 100, regiment._shootAndScootMaxDistance or 5000)
            --   local NowCoord = Shorad:GetCoordinate()                    -- //hacked//
            --   for _,_zone in pairs(self.SkateZones.Set) do               -- //hacked//
            --     local zone = _zone -- Core.Zone#ZONE_RADIUS              -- //hacked//
            --     local dist = NowCoord:Get2DDistance(zone:GetCoordinate())-- //hacked//
            --     if dist >= mindist and dist <= maxdist then              -- //hacked//
            --       possibleZones[#possibleZones+1] = zone                 -- //hacked//
            --       if #possibleZones == self.SkateNumber then break end   -- //hacked//
            --     end                                                      -- //hacked//
            --   end                                                        -- //hacked//
              if #possibleZones > 0 and Shorad:GetVelocityKMH() < 2 then
                local rand = math.floor(math.random(1,#possibleZones*1000)/1000+0.5)
                if rand == 0 then rand = 1 end
                self:T(self.lid .. " ShootAndScoot to zone "..rand)
                local zone = possibleZones[rand]                            -- //hacked//
                -- targetShoradForShootAndScootZone(zone, Shorad)              -- //hacked//
                local ToCoordinate = zone:GetCoordinate() -- COORDINATE:NewFromVec2(possibleZones[rand]:GetRandomPointVec2())     -- //hacked//
                -- local ToCoordinate = COORDINATE:GetRandomCoordinate()       -- //hacked//
                local distance = Shorad:GetCoordinate():Get2DDistance()     -- //hacked//
                if distance > 1500 then                                     -- //hacked//
                  Shorad:RouteGroundOnRoad(ToCoordinate, 20, 1, "Cone")     -- //hacked//
                else                                                        -- //hacked//
                  Shorad:RouteGroundTo(ToCoordinate, 20, "Cone", 1)         -- //hacked//
                end                                                         -- //hacked//
                -- local ToCoordinate = possibleZones[rand]:GetCoordinate()
                -- Shorad:RouteGroundTo(ToCoordinate,20,"Cone",1)
              end
            end
            return self
          end

        return self
    end
end

function DCAF.GBAD.Regiment:Start()
    if self:IsStarted() or self.Mode == DCAF.GBAD.RegimentMode.OFF then
        return self
    end
    Debug(DCAF.GBAD.Regiment.ClassName .. ":Start :: " .. self.Name .. "...")
    local iads = MANTIS:New(self.Name, "n/a", self.EWRPrefix, self.HQ.GroupName, self.Coalition, true, self.AWACS)
    hackMantisIADS(self, iads)
    local set_zone = SET_ZONE:New()
    for _, zone in ipairs(self.Zones) do
        set_zone:AddZone(zone)
    end
    iads.SAM_Group = self._set_sams

    local function includeSpawnedInitialInIADS(info)
        -- if info.Category == GBAD_REGIMENT_GROUP_CATEGORY.EWR then
        --     iads.EWR_Group:AddGroup(info.Group)
        -- else
        if info.Category == GBAD_REGIMENT_GROUP_CATEGORY.HQ then
            iads:SetCommandCenter(info.Group)
        end
    end

    -- HQ and EWR must all be spawned from start...
    iads.EWR_Group = SET_GROUP:New()

    -- start MANTIS IADS...
    self._iads = iads

    -- set zones...
    gbadRegimentSetZones(self)

    -- spawn all groups that should be present from start...
    local isStaticMode = self.Mode == DCAF.GBAD.RegimentMode.Static
    gbadRegimentInitAfterStart(self)
    if isStaticMode then
        self:Activate()
    end
    GBAD_REGIMENT_EWR:Harmonize(self)
    GBAD_REGIMENT_DB.SpawnAllInitial(self, includeSpawnedInitialInIADS)
    if not isStaticMode then
        -- spawn TELAR vehicles to create threat rings...
        if isAssignedString(GBAD_REGIMENT_DEFAULTS.PrebriefedPrefix) then
            GBAD_REGIMENT_DB.SpawnAllThreatRings(self)
        end
        gbadRegiment_monitorActivationBegin(self)
    end
    return self
end

function DCAF.GBAD.Regiment:Activate(info, spawnDelegate)
    if self.IsActive then
        return end

    if DCAF.GBAD.Debug and self.Debug then
        DebugMessageTo(nil, "Message.ogg")
        DebugMessageTo(nil, "GBAD Regiment activates: " .. self.Name)
    end

    self.IsActive = true
    Debug("DCAF.GBAD.Regiment:Activate :: " .. self.Name)
    self._iads.SAM_Group = SET_GROUP:New()
    self._iads:SetAdvancedMode(true)
    self._iads:SetMaxActiveSAMs(
        self.MaxActiveSAMsShort or GBAD_REGIMENT_DEFAULTS.MaxActiveSams.Short,
        self.MaxActiveSAMsMid or GBAD_REGIMENT_DEFAULTS.MaxActiveSams.Mid,
        self.MaxActiveSAMsLong or GBAD_REGIMENT_DEFAULTS.MaxActiveSams.Long)
    gbadRegimentSetSNSZones(self)
    self._iads:Start()

    if isBoolean(self.Debug) then
        self._iads:Debug(self.Debug)
        if self.Debug == true then
            function self._iads:OnAfterSeadSuppressionStart(From, Event, To, Group, Name)
                if DCAF.GBAD.Debug and self.Debug then
                    DebugMessageTo(nil, "Announcement.ogg")
                    DebugMessageTo(nil, "nisse - DCAF.GBAD.Regiment:Activate_suppressed_start :: Group: " .. DumpPretty(Group.GroupName) .. " : Event: " .. DumpPrettyDeep(Event, 1))
                end
            end
            if DCAF.GBAD.Debug and self.Debug then
                function self._iads:OnAfterSeadSuppressionEnd(From, Event, To, Group, Name)
                    DebugMessageTo(nil, "Announcement.ogg")
                    DebugMessageTo(nil, "nisse - DCAF.GBAD.Regiment:Activate_suppressed_end :: Group: " .. DumpPretty(Group))
                end
            end
        end
    end
    if self.Mode ~= DCAF.GBAD.RegimentMode.Static or spawnDelegate or regimentHasSpawnDelegates(self) then
        local onSpawnedFunc
        if spawnDelegate then
            onSpawnedFunc = spawnDelegate._onSpawnedFunc
        end
        if info then
            GBAD_REGIMENT_DB.Spawn(self, info, onSpawnedFunc)
        end
        gbadRegiment_monitorPostActivationBegin(self)
    end
    self._iads.UseEvasiveRelocation = self.UseEvasiveRelocation
    mantis_hackSuppression(self._iads)
end

function DCAF.GBAD.Regiment:Deactivate(monitorForReactivation)
    if not self.IsActive then
        return end

    if DCAF.GBAD.Debug and self.Debug then
        DebugMessageTo(nil, "GBAD Regiment deactivates: " .. self.Name, 30)
    end

    if not isBoolean(monitorForReactivation) then
        monitorForReactivation = true
    end
    self.IsActive = false
    Debug("DCAF.GBAD.Regiment:Deactivate :: regiment: " .. self.Name)
    self._iads:Debug(false)
    self._iads:Stop(1)
    self._iads.EWR_Group:FilterStop()
    GBAD_REGIMENT_DB.DestroyAllDynamic(self)
    if not monitorForReactivation then
        return end

    DCAF.delay(function()
        -- wait 10 seconds before monitoring for re-activation...
        gbadRegiment_monitorActivationBegin(self)
    end, 10)
end

function DCAF.GBAD.Regiment:OnFullyActive()
    DCAF.delay(function()
        -- wait half a minute, then enter more performant post-activation monitoring
    -- Debug("GBAD.Regiment:OnFullyActive :: delegateControlled: " .. DumpPrettyDeep(delegateControlled, 2))
    -- DebugMessageTo(nil, "GBAD.Regiment is fully active: " .. self.Name, 30)
        if DCAF.GBAD.Debug and self.Debug then
            DebugMessageTo(nil, "GBAD Regiment is fully activated: " .. self.Name, 30)
        end
        if self.Mode == DCAF.GBAD.RegimentMode.Dynamic then
            gbadRegiment_monitorPostActivationBegin(self, Minutes(1))
        else
            local message = "GBAD Regiment will remain active: " .. self.Name
            Debug(message)
            if DCAF.GBAD.Debug and self.Debug then
                DebugMessageTo(nil, message, 30)
            end
            -- special case: Even static regiments can have delegate-controlled GBAD groups...
            local delegateControlled = GBAD_REGIMENT_DB.GetAllActive(self, function (info)   return info.Delegate   end)
-- Debug("GBAD.Regiment:OnFullyActive :: delegateControlled: " .. DumpPrettyDeep(delegateControlled, 2))
            if #delegateControlled > 0 then
                gbadRegiment_monitorPostActivationBegin(self, 30, delegateControlled)
            end
        end
    end, 30)
end

function DCAF.GBAD.Regiment:GetSAMs()
    if self._iads then return self._iads.SAM_Group.Set end
end

--- Stops the regiment, potentially despawning all its GBAD groups, or puting them to "sleep" (alarm state green, ROE=Hold Fire)
-- @param #number delay - (optional) Delays stopping the regiment with as as many seconds
-- @param #boolean sleep - (optional; default = false) When true, and groups are not getting despawned (only happens when spawning/despawning occurs dynamically) all groups are put to "sleep" (alarm state green, ROE=Hold Fire)
function DCAF.GBAD.Regiment:Stop(delay, sleep)
    self:Deactivate(false)
    if not self:IsStarted() then
        return
    end
    GBAD_REGIMENT_DB.DespawnAllForRegiment(self)
    self._iads:Stop(delay or 1)
    self._iads = nil
    if sleep == true then
        local infoList = GBAD_REGIMENT_DB.GetAll(self)

        local function putToSleep(group)
            if not group or not group:IsActive() or not group:IsAlive() then
                return end

            group:OptionAlarmStateGreen()
            group:OptionROEHoldFire()
        end

        for _, info in ipairs(infoList) do
            putToSleep(info.Group)
        end
    end
    return self
end

function DCAF.GBAD.Regiment:IsStarted()
    return self._iads ~= nil
end

Trace("\\\\\\\\\\ DCAF.GBAD.Regiment.lua was loaded //////////")
