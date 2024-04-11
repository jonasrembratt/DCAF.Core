DCAF.MissionState = {
    ClassName = "DCAF.PersistentMissionState",
    ----
    ID = 0
}

local UNIT_STATE = {
    ClassName = "UNIT_STATE",
    ----
    UnitName = nil,                -- #string - #UNIT name
    TemplateUnitIndex = nil,       -- #number - #UNIT internal index wthin template
    Timestamp = nil,               -- #number - time of state update
    Coordinate = nil,              -- #Vec3 - known location
    Heading = nil,                 -- #number - unit heading
    SpeedMps = nil                 -- #number - unit speed (m/s)
}

local GROUP_STATE = {
    ClassName = "GROUP_STATE",
    ----
    GroupName = nil,                -- #string - #GROUP name
    TemplateName = nil,             -- #string - name of #GROUP template
}

local STATE = {
    Groups = {
        -- list of #GROUP_STATE
    },
    Templates = {
        -- key   = template name
        -- value = #TEMPLATE
    },
    Statics = {
        -- list of #STATIC_STATE
    }
}

local DCAF_MISSION_STATE_ID = 0
DCAF_MISSION_STATE_SCHEDULE_ID = nil
DCAF_MISSION_STATE_SCHEDULE_INTERVAL = 30

local DCAF_MISSION_STATES = {
    -- list of #DCAF.MissionState
}

local GROUP_STATE_INDEX = {
    -- key   = GROUP name
    -- value = #GROUP_STATE
}

local UNIT_STATE_INDEX = {
    -- key   = UNIT name
    -- value = #UNIT_STATE
}

local STATIC_STATE_INDEX = {
    -- key   = STATIC.StaticName
    -- value = #STATIC_STATE
}

--- sedems MOOSE removed STATICs from its internal DB when they get destroyed so we need to keep an internal DB to allow updates
local STATIC_INDEX = {
    -- key   = STATIC.StaticName
    -- value = #STATIC
}

local TEMPLATE_INDEX = {
    -- key   = TEMPLATE name
    -- value = #TEMPLATE
}

local GROUP_STATE = {
    Gnm = nil,                      -- GROUP name
    Spn = false,                    -- #boolean - true if group was SPAWNed (not activated)
    Tnm = nil,                      -- template name
    Tim = nil,                      -- timestamp of last update (from UTILS.SecondsOfToday)
    Uns = {}                        -- list of #UNIT_STATE
}

local STATIC_STATE = {
    Snm = nil,                      -- #STATIC name
    Tim = nil,                      -- timestamp of last update (from UTILS.SecondsOfToday)
    Lfe = 1,                        -- relative life [0-1]
    Hdg = 0,                        -- heading (1-360)
    Pos = nil,                      -- location
}

local UNIT_STATE = {
    Unm = nil,                      -- UNIT name
    Idx = 0,                        -- internal index
    Lfe = 1,                        -- relative life [0-1]
    Hdg = 0,                        -- heading (1-360)
    Pos = nil,                      -- location
    Vel = 0                         -- velocity (m/s)
}

function STATIC_STATE:New(static)
    local staticState = STATE:FindStaticState(static)
    if staticState then return staticState end

    local staticState = DCAF.clone(STATIC_STATE, nil, true)
    staticState.Snm = static.StaticName
    staticState.Hdg = static:GetHeading()
    local coord = static:GetCoordinate()
    if coord then
        staticState.Pos = coord:GetVec3()
    end
    STATIC_STATE_INDEX[static.StaticName] = staticState
    STATIC_INDEX[static.StaticName] = static

    return staticState
end

function GROUP_STATE:New(group)
    local groupState = STATE:FindGroupState(group)
    if groupState then return groupState end

    local groupState = DCAF.clone(GROUP_STATE, nil, true)
    groupState.Gnm = group.GroupName
    local template = group:GetTemplate()
    local existingTemplate = STATE:FindTemplate(template.name)
    if not existingTemplate then
        TEMPLATE_INDEX[template.name] = template
    end
    groupState.Tnm = template.name
    -- STATE.Groups[#STATE.Groups+1] = groupState
    GROUP_STATE_INDEX[group.GroupName] = groupState
    for index, unit in ipairs(group:GetUnits()) do
        groupState.Uns[#groupState.Uns+1] = UNIT_STATE:New(unit, index)
        STATE:Update(unit)
    end

    return groupState
end

function GROUP_STATE:Update()
    for _, unitState in ipairs(self.Uns) do
        local unit = getUnit(unitState.Unm)
        unitState:Update(unit)
    end
end

function UNIT_STATE:New(unit, index)
    local state = DCAF.clone(UNIT_STATE, nil, true)
    state.Unm = unit.UnitName
    state.Idx = index
    UNIT_STATE_INDEX[unit.UnitName] = state
    return state
end

function UNIT_STATE:Update(unit)
    if not unit then return end
    self.Tim = UTILS.SecondsOfToday()
    self:UpdateLife(unit)
    self.Hdg = unit:GetHeading()
    self.Vel= unit:GetVelocityMPS()
    local coord = unit:GetCoordinate()
    if coord then
        self.Pos = coord:GetVec3()
    end
    --[[
    Tim = <time stamp>
    Unm = <UNIT name>
    Idx = <unit's internal group index>
    Lfe = <relative life [0-1]>
    Hdg = <heading (1-360)>
    Pos = <location (Vec3)>
    Vel = <velocity (m/s)>
    ]]
end

function UNIT_STATE:UpdateLife(unit)
    unit = unit or UNIT:FindByName(self.Unm)
    if unit then
        self.Lfe = unit:GetLife() / unit:GetLife0()
    end
end

function STATIC_STATE:Update(static)
Debug("nisse - STATIC_STATE:Update :: static: " .. DumpPrettyDeep(static, 2) .. " :: life: " .. Dump(static:GetLife() .. " :: life0: " .. Dump(static:GetLife0())))
    self.Tim = UTILS.SecondsOfToday()
    self:UpdateLife(static)
    --[[
    Tim = <time stamp>
    Unm = <UNIT name>
    Idx = <unit's internal group index>
    Lfe = <relative life [0-1]>
    Hdg = <heading (1-360)>
    Pos = <location (Vec3)>
    Vel = <velocity (m/s)>
    ]]
end

function STATIC_STATE:UpdateLife(static)
    static = static or STATIC:FindByName(self.Snm) or self:GetStatic()
    if not static then
        return Warning(DCAF.MissionState.ClassName .. " / STATIC_STATE:UpdateLife :: could not find static '".. self.Snm .. "' :: IGNORES")
    end
    if static then
        self.Lfe = static:GetLife() / static:GetLife0()
    end
end

function STATIC_STATE:GetStatic()
    return STATIC:FindByName(self.Snm) or STATIC_INDEX[self.Snm]
end

local function matchesCriteria(groupOrStatic, missionState) -- self == #DCAF.MissionState
    local criteria = missionState.Criteria
    if not criteria then return true end
    if isAssignedString(criteria) and string.find(groupOrStatic.GroupName, criteria) then return true end
    if isFunction(criteria) and criteria(groupOrStatic) then return true end
end

function STATE:RegisterGroup(group)
    GROUP_STATE:New(group)
end

function STATE:RegisterStatic(static)
    STATIC_STATE:New(static)
end

function STATE:Update(source)
    local state
    if isStatic(source) then
        state = self:FindStaticState(source)
Debug("nisse - STATE:Update :: STATIC_STATE_INDEX: " .. DumpPrettyDeep(STATIC_STATE_INDEX, 2))        
        if not state then
            return Warning("STATE:Update :: could not find state for static '" .. source.StaticName .. "' :: IGNORES")
        end
        state:UpdateLife()
    else
        state = self:FindUnitState(source)
        if not state then
            return Warning("STATE:Update :: could not find state for unit '" .. source.UnitName .. "' :: IGNORES")
        end
        state:Update(source)
    end
end

local loadFile

function DCAF.MissionState:New(year, month, day, file, criteria)
    if not isNumber(year) then return Error("DCAF.PersistentState:Start :: `year` was was not specified (must be number)") end
    if not isNumber(month) then return Error("DCAF.PersistentState:Start :: `month` was was not specified (must be number)") end
    if not isNumber(day) then return Error("DCAF.PersistentState:Start :: `day` was was not specified (must be number)") end
    if not isAssignedString(file) then return Error("DCAF.PersistentState:Start :: `file` was not specified (must be string)") end
    local missionState = DCAF.clone(DCAF.MissionState)
    missionState.DateTime = {
        Year = year,
        Month = month,
        Day = day
    }
    missionState.File = file
    missionState.Criteria = criteria
    DCAF_MISSION_STATE_ID = DCAF_MISSION_STATE_ID + 1
    missionState.ID = DCAF_MISSION_STATE_ID
    DCAF_MISSION_STATES[#DCAF_MISSION_STATES+1] = missionState
    loadFile(missionState)
    return self
end

function DCAF.MissionState:Monitor(interval)
    -- we only run one scheduled monitor, even if several mission state objects needs it; using the lowest specified interval...
    if isNumber(interval) then 
        if interval < DCAF_MISSION_STATE_SCHEDULE_INTERVAL then
            DCAF_MISSION_STATE_SCHEDULE_INTERVAL = interval
            if DCAF_MISSION_STATE_SCHEDULE_ID then
                DCAF.stopScheduler(DCAF_MISSION_STATE_SCHEDULE_ID)
                DCAF_MISSION_STATE_SCHEDULE_ID = nil
            end
        end
    end
    if DCAF_MISSION_STATE_SCHEDULE_ID then return self end
    DCAF_MISSION_STATE_SCHEDULE_ID = DCAF.startScheduler(function ()
        for unitName, unitState in pairs(UNIT_STATE_INDEX) do
            local unit = getUnit(unitName)
            if unit then
                unitState:Update(unit)
            end
        end
-- Debug("nisse - DCAF.PersistentState:Monitor :: UNIT_STATE_INDEX: " .. DumpPrettyDeep(UNIT_STATE_INDEX))
    end, DCAF_MISSION_STATE_SCHEDULE_INTERVAL)
    return self
end

function DCAF.MissionState:Write()
    -- TODO
    return self
end

function STATE:FindStaticState(source)
    if isAssignedString(source) then
        local state = STATIC_STATE_INDEX[source]
        if state then return state end
    elseif isStatic(source) then
        return STATIC_STATE_INDEX[source.StaticName]
    end
end

function STATE:FindGroupState(source)
    if isAssignedString(source) then
        local state = GROUP_STATE_INDEX[source]
        if state then return state end
    elseif isGroup(source) then
        return GROUP_STATE_INDEX[source.GroupName]
    end
end

function STATE:FindUnitState(source)
    if isAssignedString(source) then
        local state = UNIT_STATE_INDEX[source]
        if state then return state end
    elseif isUnit(source) then
        return UNIT_STATE_INDEX[source.UnitName]
    end
end

function STATE:FindTemplate(source)
    if isAssignedString(source) then
        local template = TEMPLATE_INDEX[source]
        if template then return template end
        local groupState = self:FindGroupState(source)
        if groupState then return self:FindTemplate(groupState.Tnm) end
    end

    local unit = getUnit(source)
    if unit then
        return self:FindTemplate(unit:GetGroup())
    end
    local group = getGroup(source)
    if not group then return end
    local groupState = self:FindGroupState(group.GroupName)
    if groupState then return self:FindTemplate(groupState.Tnm) end
end


local function _loadInitial() -- self = DCAF.MissionState
    -- load initial state for all initially active groups...
    for _, group in pairs(_DATABASE.GROUPS) do
        if group:IsActive() then
            STATE:RegisterGroup(group)
        end
    end
-- Debug("nisse - _DATABASE.STATICS: " .. DumpPrettyDeep(_DATABASE.STATICS, 2))
    for _, static in pairs(_DATABASE.STATICS) do
        STATE:RegisterStatic(static)
    end
end

local function _loadFile(self) -- self = DCAF.MissionState
    -- TODO
end

local function _writeFile(self) -- self = DCAF.MissionState
    local state = DCAF.clone(STATE, nil, true)
    state.DateTime = self.DateTime
    local dayInSeconds = 24 * 3600
    state.DateTime.DayOffset = math.floor(timer.getAbsTime() / dayInSeconds)
    state.DateTime.Time = UTILS.SecondsOfToday()

    local function addGroupState(groupState)
        groupState:Update()
        local group = getGroup(groupState.Gnm)
        if not matchesCriteria(group, self) then return end
        state.Groups[#state.Groups+1] = groupState
        local template = state.Templates[groupState.Tnm]
        if template then return end
        template = TEMPLATE_INDEX[groupState.Tnm]
        if not template then return Warning(DCAF.MissionState.ClassName .. " :: Failed to obtain template for group '" .. groupState.Gnm .. "' when writing state :: IGNORES groups") end
        state.Templates[groupState.Tnm] = template
    end

    local function addStaticState(staticState)
        local static = staticState:GetStatic()
        if not matchesCriteria(static, self) then return end
        staticState:UpdateLife()
        state.Statics[#state.Statics+1] = staticState
    end

    for _, groupState in pairs(GROUP_STATE_INDEX) do
        addGroupState(groupState)
    end

-- Debug("nisse - STATIC_STATE_INDEX: " .. DumpPrettyDeep(STATIC_STATE_INDEX, 2))

    for _, staticState in pairs(STATIC_STATE_INDEX) do
        addStaticState(staticState)
    end

    local data = "state = " .. DumpPrettyDeep(state)
    local file = io.open(self.File, "w")
    if not file then return end
    file:write(data)
    file:close()
end

local function _writeFiles()
    for _, missionState in ipairs(DCAF_MISSION_STATES) do
        _writeFile(missionState)
    end
end

local function _hookEvents()
    DCAF_MISSION_STATE_EVENT_ROOT = BASE:New()

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.MissionEnd, function(_, e)
        Debug("=============> EVENTS.MissionEnd")
        _writeFiles()
    end)

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.MissionRestart, function(_, e)
        Debug("=============> EVENTS.MissionRestart")
        _writeFiles()
    end)

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.Birth, function(_, e)
        Debug("=============> EVENTS.Birth :: e: " .. DumpPrettyDeep(e, 2))
        STATE:RegisterGroup(e.IniGroup)
    end)

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.Hit, function(_, e)
        local tgtUnit = e.TgtUnit
        if not tgtUnit then return end
Debug("=============> EVENTS.Hit :: e: " .. DumpPrettyDeep(e, 2))
        STATE:Update(tgtUnit)
    end)

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.Kill, function(_, e)
        Debug("=============> EVENTS.Kill :: e: " .. DumpPrettyDeep(e, 2))
    end)

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.RemoveUnit, function(_, e)
        Debug("=============> EVENTS.RemoveUnit :: e: " .. DumpPrettyDeep(e, 2))
    end)

    DCAF_MISSION_STATE_EVENT_ROOT:HandleEvent(EVENTS.UnitLost, function(_, e)
        Debug("=============> EVENTS.UnitLost :: e: " .. DumpPrettyDeep(e, 2))
    end)
end

loadFile = _loadFile

if not io then return Error(DCAF.MissionState.ClassName .. " :: mission state will not work because 'io' has not been de-sanitized. Please de-sanitize (comment out) in <DCS install filder>/Scripts/MissionScripting.lua") end

_loadInitial()
_hookEvents()