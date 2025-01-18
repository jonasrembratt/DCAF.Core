-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                     DCAF.Core - The DCAF Lua foundation (relies on MOOSE)
--                                             Digital Coalition Air Force
--                                                        2022
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

BASE:E("////////// Loading DCAF.Core.lua... \\\\\\\\\\")

-- if os then math.randomseed(os.clock()*100000000000) end

DCAF = {
    Trace = true,
    TraceToUI = false,
    Debug = false,
    DebugToUI = false,
    DataKey = "_dcaf_data", -- used to attach arbitrary data to an object (eg. see getGroup)
    WaypointNames = {
        RTB = '_rtb_',
        Divert = '_divert_',
    },
    Scheduler = SCHEDULER:New(),
    DefaultCountries = {
        CountryIDs = {
            [1] = 0,         -- always use Russia for RED coalition
            [2] = 2          -- always use USA for BLUE coalition
        }
    }
}

BASE:Inherit(DCAF, BASE:New())

Coalition = {
    Blue = "blue",
    Red = "red",
    Neutral = "neutral"
}

DCAF.Flight = {
    ClassName = "DCAF.Flight",
    ----
    CallSign = "",
    CallSignPhonetic = "",
    Group = nil
}

DCAF.DateTime = {
    ClassName = "DCAF.DateTime",
    Year = nil,         -- #number
    Month = nil,        -- #number
    Day = nil,          -- #number
    Hour = 0,           -- #number
    Minute = 0,         -- #number
    Second = 0,         -- #number
    IsDST = false       -- #bool - true = is Daylight Saving time
}

DCAF.Smoke = {
    ClassName = "DCAF.Smoke",
    Color = SMOKECOLOR.Red,
    Remaining = 1
}

DCAF.Flares = {
    ClassName = "DCAF.Flares",
    Color = SMOKECOLOR.Red,
    Remaining = 1
}

DCAF.AltitudeType = {
    AGL = "AGL",            -- Above Ground Level
    MSL = "MSL"             -- Mean Sea Level
}

DCAF.Units = {
    Imperial = "Imperial", -- feet / nautical miles
    Metric = "Metric"      -- meters / klicks
}

local _debugId = 0
local function get_next_debugId()
    _debugId = _debugId + 1
    return _debugId
end

local function with_debug_info(table)
    table._debugId = "debug_" .. tostring(get_next_debugId())
    return table
end

local function deepCopy(object)
      local lookup_table = {}
  local function _copy( object )
    if type( object ) ~= "table" then
      return object
    elseif lookup_table[object] then
      return lookup_table[object]
    end
    local new_table = {}
    lookup_table[object] = new_table
    for index, value in pairs( object ) do
      new_table[_copy( index )] = _copy( value )
    end
    return setmetatable( new_table, getmetatable( object ) )
  end
  local objectreturn = _copy( object )
  return objectreturn
end

function random(min, max)
    local lowNum, highNum
    if not max then
        highNum = min
        lowNum = 1
    else
        lowNum = min
        highNum = max
    end
    local total = 1
    if math.abs(highNum - lowNum + 1) < 50 then -- if total values is less than 50
        total = math.modf(50/math.abs(highNum - lowNum + 1)) -- make x copies required to be above 50
    end
    local choices = {}
    for i = 1, total do -- iterate required number of times
        for x = lowNum, highNum do -- iterate between the range
            choices[#choices +1] = x -- add each entry to a table
        end
    end
    local rtnVal = math.random(#choices) -- will now do a math.random of at least 50 choices
    for i = 1, 10 do
        rtnVal = math.random(#choices) -- iterate a few times for giggles
    end
    return choices[rtnVal]
end

function DCAF.clone(template, deep, suppressDebugData)
    if not isBoolean(deep) then
        deep = true
    end
    local cloned = nil
    if deep then
        cloned = deepCopy(template)
    else
        cloned = {}
        for k, v in pairs(template) do
            cloned[k] = v
        end
    end

    -- add debug information if applicable ...
    if DCAF.Debug then
        if not isBoolean(suppressDebugData) or suppressDebugData == false then
            return with_debug_info(cloned)
        end
    end
    return cloned
end

local function resolveSource(source)
    if isTable(source) then
        return source end

    local obj = getUnit(source)
    if obj then
        return obj end

    obj = getGroup(source)
    if obj then
        return obj end

end

function DCAF.tagGet(source, key)
    local obj = resolveSource(source)
    if not obj then
        return end

    if not isTable(obj.DCAF) then
        return end

    return obj.DCAF[key]
end

function DCAF.tagSet(source, key, value)
    local obj = resolveSource(source)
    if not obj then
        error("DCAF.tagSet :: could not resolve `source`: " .. DumpPretty(source)) end

    if not isTable(obj.DCAF) then
        obj.DCAF = {}
    end
    obj.DCAF[key] = value
    return value, obj
end

function DCAF.tagEnsure(source, key, value)
    local obj = resolveSource(source)
    if not obj then
        error("DCAF.tagEnsure :: could not resolve `source`: " .. DumpPretty(source)) end

    if not isTable(obj.DCAF) then
        obj.DCAF = {}
    end
    if obj.DCAF[key] ~= nil then
        return obj.DCAF[key], obj end

    obj.DCAF[key] = value
    return value, obj
end

function getAngleDiff(a1, a2)
    if a1 == a2 then
        return 0, 0
    end
    if a1 > 180 then
        a1 = a1 - 360
    end
    if a2 > 180 then
        a2 = a2 - 360
    end
    return -(a1 - a2)
end

function isString( value ) return type(value) == "string" end
function isAssignedString( value )
    if not isString(value) then
        return false end

    return string.len(value) > 0
end
function isBoolean( value ) return type(value) == "boolean" end
function isNumber( value ) return type(value) == "number" end
function isStringNumber( value )
    if not isAssignedString(value) then return end
    if string.len(value) == 1 then
        local c = value
        return c == '0' or c == '1' or c == '2' or c == '3' or c == '4' or c == '5' or c == '6' or c == '7' or c == '8' or c == '9'
    end
    return value:match("^%-?%d+$")
end
function isTable( value ) return type(value) == "table" end
function isFunction( value ) return type(value) == "function" end
function isClass( value, class )
    if not isTable(value) then return false end
    if isTable(class) then
        class = class.ClassName
    end
    if value.ClassName == class then return true end
    local metatable = getmetatable(value)
    if metatable then return isClass(metatable, class) end
end
function isUnit( value ) return isClass(value, UNIT) end
function isGroup( value ) return isClass(value, GROUP) end
function isZone( value ) return isClass(value, ZONE) or isClass(value, ZONE_POLYGON_BASE.ClassName) or isClass(value, ZONE_POLYGON.ClassName) end
function isCoordinate( value ) return isClass(value, COORDINATE) end
function isVec2( value ) return isClass(value, POINT_VEC2) end
function isVec3( value ) return isClass(value, POINT_VEC3) end
function isAirbase( value ) return isClass(value, AIRBASE) end
function isStatic( value ) return isClass(value, STATIC) end
function isLocation( value ) return isClass(value, DCAF.Location) end
function isVariableValue( value ) return isClass(value, VariableValue) end
function isCoalition( value ) return value == coalition.side.BLUE or value == coalition.side.RED or value == coalition.side.NEUTRAL end

function isUnits(value)
    if not isAssignedString(value) then return end
    return value == DCAF.Units.Imperial
        or value == DCAF.Units.Metric
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function trimSpawnIndex(s)
    local start, stop = string.find(s, "#%d+[-]%d+$")
    if not start then
        return s end

    local trimmed = string.sub(s, 1, start-1)
    return trimmed
end

function escapePattern(text)
    -- Escape all special characters by prefixing them with %
    return text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

function inString( s, pattern )
    return string.find(s, pattern ) ~= nil
end

function findLastOccurrence(str, char)
    local reversed_pos = str:reverse():find(char, 1, true) -- true ensures a plain match
    if reversed_pos then
        return #str - reversed_pos + 1 -- Convert position in reversed string to original string
    else
        return nil -- Character not found
    end
end

function newString(pattern, count)
    if not isAssignedString(pattern) then
        error("newString :: `pattern` must be an assigned string, but was: " .. DumpPretty(pattern)) end

    if not isNumber(count) then
        error("newString :: `count` must be a number, but was: " .. type(count)) end

    local s = pattern
    for i = 1, count-1, 1 do
        s = s .. pattern
    end
    return s
end

function findFirstNonWhitespace( s, start )
    local sLen = string.len(s)
    for i=start, sLen, 1 do
        local c = string.sub(s, i, i)
        if (c ~= ' ' and c ~= '\n' and c ~= '\t') then
            return i
        end
    end
    return nil
end

function getTableType(table)
    if not isTable(table) then
        return end

    for k, _ in pairs(table) do
        if isString(k) then
            return "dictionary"
        elseif isNumber(k) then
            return "list"
        end
    end
    return "list"
end

function isList( value )
    local tableType = getTableType(value)
    return tableType == "list"
end

function isListOfAssignedStrings(list, ignoreFunctions)
    if not isList(list) then return end

    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end
    for _, v in ipairs(list) do
        if not ignoreFunctions and isFunction(v) then
            return false end

        if not isAssignedString(v) then
            return false end
    end
    return true
end

function isTableOfAssignedStrings(list, ignoreFunctions)
    if not isTable(list) then return end
    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end
    for _, v in pairs(list) do
        if not ignoreFunctions and isFunction(v) then return false end
        if not isAssignedString(v) then return false end
    end
    return true
end

function isListOfClass(list, class, ignoreFunctions)
    if not isList(list) then return end
    if not isBoolean(ignoreFunctions) then ignoreFunctions = true end
    for _, v in ipairs(list) do
        if not ignoreFunctions and isFunction(v) then return false end
        if not isClass(v, class) then return false end
    end
    return true
end

function isDictionary( value )
    local tableType = getTableType(value)
    return tableType == "dictionary"
end

function isDictionaryOfClass( value, class, ignoreFunctions )
    if not isDictionary(value) then return end
    if not isBoolean(ignoreFunctions) then ignoreFunctions = true end
    for k, v in pairs(value) do
        if not ignoreFunctions and isFunction(v) then return false end
        if not isClass(v, class) then return false end
    end
    return true
end

function isTableOfClass( value, class, ignoreFunctions )
    if not isTable(value) then return end
    return isDictionaryOfClass( value, class, ignoreFunctions )
end

local next = next
function tableIsUnassigned(table)
    return table == nil or not next(table)
end

function dictCount(table)
    if not isTable(table) then
        error("dictCount :: `table` is of type " .. type(table)) end

    local count = 0
    for k, v in pairs(table) do
        count = count+1
    end
    return count
end

--- Creates and returns a list from a dicitonary
---@param dict table A dictionary (table with keys/values)
---@param sort any If 'true' then list will be sorted (assumed a list of strings). If a function then list will be sorted using the function as callback criteria
---@return any list The list (if dict was dictionary; otherwise nil)
function dictToList(dict, sort)
    if dict == nil then return nil end
    if not isTable(table) then return Error("dictToTable :: `table` is of type " .. type(table)) end
    local list = {}
    for _, item in pairs(dict) do
        list[#list+1] = item
    end
    if isFunction(sort) then
        table.sort(list, sort)
    elseif sort == true then
        table.sort(list)
    end
    return list
end

function tableAny(table, criteriaFunc)
    if not isTable(table) then
        error("tableAny :: `table` is of type " .. type(table)) end

    if isList(table) then return #table end
    for k, v in pairs(table) do
        if not criteriaFunc then return true end
        if criteriaFunc(v) then return true end
    end
end


do -- |||||||||||||||||||||||||||||||   Serializing Complex Values as String   |||||||||||||||||||||||||||||||
local function mkIndent( count )
    local s = ""
    for i=count,0,-1 do
        s = s.." "
    end
    return s
end
      
function Dump(value)
    if type(value) ~= 'table' then
        return tostring(value)
    end

    local s = "{ "
    for k,v in pairs(value) do
       if type(k) ~= 'number' then k = '"'..k..'"' end
       s = s .. '['..k..'] = ' .. Dump(v) .. ','
    end
    return s .. '} '
  end

  --[[
Parameters
    value :: (arbitrary) Value to be serialised and formatted
    options :: (object)
    {
        asJson :: (bool; default = false) Set to serialize as JSON instead of lua (makes it easier to use with many online JSON analysis tools)
        indentSize :: (int; default = 2) Specifies indentation size (no. of spaces)
        deep :: (bool; default=false) Specifies whether to dump the object with recursive information or "shallow" (just first level of graph)
    }
  ]]--
DumpPrettyOptions = {
    asJson = false,
    indentSize = 2,
    deep = false,             -- boolean or number (number can control how many levels to present for 'deep')
    includeFunctions = false,
    skipKeys = nil            -- #list of assigned strings; names of values/functions to be ignored (this can help alleviate recursion)
}

function DumpPrettyOptions:New()
    return DCAF.clone(DumpPrettyOptions)
end

function DumpPrettyOptions:JSON( value )
    self.asJson = value or true
    return self
end

function DumpPrettyOptions:IndentWize( value )
    self.indentSize = value or 2
    return self
end

function DumpPrettyOptions:Deep( value )
    if isNumber(value) then
        value = value+1 -- ensures 1 = only show root level details, 2 = show root + second level details etc. (0 == not deep)
    end
    self.deep = value or true
    return self
end

function DumpPrettyOptions:Skip(...)
    self.skipKeys = self.skipKeys or {}
    for i = 1, #arg, 1 do
        self.skipKeys[arg[i]] = true
    end
end

function DumpPrettyOptions:IsSkipped(key)
    return self.skipKeys and self.skipKeys[key]
end

function DumpPrettyOptions:IncludeFunctions( value )
    self.includeFunctions = value or true
    return self
end

function DumpPretty(value, options)

    options = options or DumpPrettyOptions
    local idtSize = options.indentSize or DumpPrettyOptions.indentSize
    local asJson = options.asJson or DumpPrettyOptions.asJson
    local dumpedValues = { }

    local function isAlreadyDumped(value)
        for _, v in ipairs(dumpedValues) do
            if v == value then
                return true
            end
        end
    end

    local function dumpRecursive(value, ilvl)
        if not isTable(value) then
            if (isString(value)) then
                return '"' .. tostring(value) .. '"'
            end
            return tostring(value)
        end

        local deep = options.deep
        if isNumber(deep) then
            deep = deep > ilvl
        end
        if (not deep or not DCAF.Debug) and ilvl > 0 then
            if options.asJson then
                return "{ }"
            end
            if tableIsUnassigned(value) then
                return "{ }"
            elseif isList(value) then
                return "{ --[[ list (" .. #value .. " values) ]] }"
            else
                return "{ --[[ object/dictionary ]] }"
            end
        end

        if isTable(value) then
            table.insert(dumpedValues, value)
        end
        local s = '{\n'
        local indent = mkIndent(ilvl * idtSize)

        local function dumpKeyValue(k, v)
            if isTable(v) and isTable(v.__index) and not isAlreadyDumped(v) then
                table.insert(dumpedValues, v)
                for ik, iv in pairs(v.__index) do
                    dumpKeyValue(ik, iv)
                end
            end

            if (options.includeFunctions or type(v) ~= "function") then
                if isAlreadyDumped(v) then
                    if asJson then
                        s = s .. indent..'"'..k..'"'..' : ' .. " {},\n"
                    else
                        if isNumber(k) then
                            s = s .. indent..'['..k..']'..' = { --[[ recursive table ]] },\n'
                        else
                            s = s .. indent..'["'..k..'"]'..' = { --[[ recursive table ]] },\n'
                        end
                    end
                else -- if not options:IsSkipped(k) then
                    if (asJson) then
                        s = s .. indent..'"'..k..'"'..' : '
                    else
                        if type(k) ~= 'number' then k = '"'..k..'"' end
                        s = s .. indent.. '['..k..'] = '
                    end
                        s = s .. dumpRecursive(v, ilvl+1, idtSize) .. ',\n'
                end
            end
        end
        for k, v in pairs(value) do
            dumpKeyValue(k, v)
        end
        return s .. mkIndent((ilvl-1) * idtSize) .. '}'
    end

    return dumpRecursive(value, 0)
end

function DumpPrettyJson(value, options)
    options = (options or DumpPrettyOptions:New()):AsJson()
    return DumpPretty(value, options)
end

function DumpPrettyDeep(value, options)
    if isNumber(options) then
        options = DumpPrettyOptions:New():Deep(options)
    elseif isTable(options) then
        options = options:Deep()
    else
        options = DumpPrettyOptions:New():Deep()
    end
    return DumpPretty(value, options)
end
end


function Trace( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    if (DCAF.Trace) then
        BASE:E("DCAF-TRC @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAF.TraceToUI) then
        MESSAGE:New("DCAF-TRC: "..message):ToAll()
    end
end

function Debug( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    if (DCAF.Debug) then
        BASE:E("DCAF-DBG @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAF.DebugToUI) then
        MESSAGE:New("DCAF-DBG: "..message):ToAll()
    end
end

function DebugIf( criteriaFunc, message )
    if not criteriaFunc() then return end
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    if (DCAF.Debug) then
        BASE:E("DCAF-DBG @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAF.DebugToUI) then
        MESSAGE:New("DCAF-DBG: "..message):ToAll()
    end
end

function Warning( message, value )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    BASE:E("DCAF-WRN @"..timestamp.."===> "..tostring(message))
    if (DCAF.TraceToUI or DCAF.DebugToUI) then
        MESSAGE:New("DCAF-WRN: "..message):ToAll()
    end
    return value
end

function Error( message, value )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    BASE:E("DCAF-ERR @"..timestamp.."===> "..tostring(message) .. " " .. BASE.Debug.traceback())
    if (DCAF.TraceToUI or DCAF.DebugToUI) then
        MESSAGE:New("DCAF-ERR: "..message):ToAll()
    end
    return value
end

VariableValue = {
    ClassName = "VariableValue",
    ----
    Value = 100,           -- #number - fixed value)
    Variance = nil         -- #number - variance (0.0 --> 1.0)
}

--[[
Resolves a UNIT from an arbitrary source
]]--
function getUnit( source )
    if (isUnit(source)) then return source end
    if (isString(source)) then
        return UNIT:FindByName( source )
    end
end

--[[
getGroup
    Resolves a GROUP from an arbitrary source
]]--

--- Gets a group from a source
-- @param #Any source - A #GROUP or name of a group
-- @param #Any data - (optional) Arbitrary value to be attached to the requested group
-- @param #Any dataKey - (optional) Key to be used for attaching `data` (only used when `data` is assigned)
function getGroup( source, data, dataKey )

    local function attachData(group)
        group[dataKey or DCAF.DataKey] = data
        return group
    end

    if (isGroup(source)) then
        return attachData(source)
    end
    if (isUnit(source)) then
        return attachData(source:GetGroup())
    end
    if (not isAssignedString(source)) then return end

    local group = GROUP:FindByName( source )
    if (group ~= nil) then
        return attachData(group)
    end
    local unit = UNIT:FindByName( source )
    if (unit ~= nil) then
        return attachData(unit:GetGroup())
    end
end

function getControllable( source )
    local unit = getUnit(source)
    if (unit ~= nil) then
      return unit end

    local group = getGroup(source)
    if (group ~= nil) then
      return group end

    return nil
end

function getStatic( source )
    if isStatic(source) then
        return source end
    if not isAssignedString(source) then
        return end

    local static
    pcall(function()
        static = STATIC:FindByName(source)
    end)
    return static
end

function getAirbase( source )
    if isClass(source, AIRBASE) then return source end
    if isAssignedString(source) then
        return AIRBASE:FindByName(source)
    end
    if isNumber(source) then return AIRBASE:FindByID(source) end
end

local RefPointsIndex = {}

local function getRefPointsIndex(coalition)
    local index = RefPointsIndex[coalition]
    if index then return index end
    index = {}
    local navPoints = env.mission.coalition[coalition].nav_points
    for _, navPoint in ipairs(navPoints) do
        local loc = DCAF.Location:NewNamed(navPoint.callsignStr, COORDINATE:NewFromVec2(navPoint))
        loc.Type = navPoint.type
        loc.ID = navPoint.id
        loc.Properties = navPoint.properties
        if isAssignedString(navPoint.comment) then loc.Comment = navPoint.comment end
        index[loc.Name] = loc
    end
    RefPointsIndex[coalition] = index
    return index
end

function getRefPoint(source, coalition)
    local validCoalition = Coalition.Resolve(coalition)
    if not validCoalition then return Error("getRefPoint :: cannot resolve `coalition`: " .. DumpPretty(coalition)) end
    local index = getRefPointsIndex(validCoalition)
    return index[source]
--     local navPoints = env.mission.coalition[validCoalition].nav_points
-- Debug("nisse - getRefPoint :: navPoints: " .. DumpPrettyDeep(navPoints))
-- error("NOT IMPLEMENTED")
end

--- Returns the unit of a group that is closest to a specified location
---@param group any Can be #GROUP, #UNIT, or name of group/unit. Must be resolvable to a #GROUP
---@param location any Can be anything that can be resolved into a #DCAF.Location
function getGroupClosestUnit(group, location)
    local validGroup = getGroup(group)
    if not validGroup then return Error("getGroupClosestUnit :: could not resolve `group`: " .. DumpPretty(group)) end
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error("getGroupClosestUnit :: could not resolve `location`: " .. DumpPretty(location)) end
    group = validGroup
    local coordLocation = validLocation:GetCoordinate()
    local units = group:GetUnits()
    local closestUnit
    local closestDistance = NauticalMiles(9999)
    local function measure(unit)
        local coordUnit = unit:GetCoordinate()
        if not coordUnit then return end
        local distance = coordUnit:Get2DDistance(coordLocation)
        if distance > closestDistance then return end
        closestDistance = distance
        closestUnit = unit
    end
    for _, unit in ipairs(units) do measure(unit) end
    return closestUnit, closestDistance
end

function getZone( source )
    if isZone(source) then
        return source end

    if not isAssignedString(source) then
        return end

    local zone = ZONE:FindByName(source)
    if zone then
        return zone end

    local group = getGroup(source)
    return zone
end

-- ///////////////////////////////////////////////////////////////////
-- Colors

Color = {
    Black = {0,0,0},
    Blue = {0,0,1},
    Green = {0,1,0},
    Pink = {1,.5,.5},
    Natofriendly = {.5,.5,1},
    NatoHostile = {1,.5,.5},
    Red = {1,0,0},
    White = {1,1,1},
}

do -- |||||||||||||||||||||||||||||||    DCAF Menu System    |||||||||||||||||||||||||||||||
local DCAF_Menu_DB = {
    _nextID = 0,
    _index = {
        -- key   = [scope?]/[menu path]
        -- value = #DCAF.Menu
    },
    -- _menus = {
    --     -- key   = menu id
    --     -- value = #DCAF.Menu
    -- },
    _childMenus = {
        -- key   = menu id
        -- value = #DCAF.Menu
    },
}

DCAF.Menu = {
    ClassName = "DCAF.Menu",
    ----
    ID = 0,
    ParentID = 0,
    CountChildren = 0,
    Menu = nil,             -- MOOSE MENU
    Path = ""
}

function DCAF_Menu_DB:GetKeyAndPath(parent, text, group, coalition)
    local path = parent.Path.."/"..text
    local key
    if group then
        key = group.GroupName..path
    elseif coalition then
        local validCoalition = Coalition.Resolve(coalition)
        key = validCoalition..path
    else
        key = path
    end
    return key, path
end

function DCAF_Menu_DB:Add(parent, menu, text, group, coalition)
    local key, path = self:GetKeyAndPath(parent, text, group, coalition)
    if self._index[key] then return false, "Menu with same path and scope already created: "..key end
    local id = self:GetNextID()
    menu.ID = id
    self._index[key] = menu
    menu.ParentID = parent.ID
    menu.Key = key
    menu.Path = path
    if parent.ID == 0 then return true end
    local childMenus = self._childMenus[parent.ID] or {}
    childMenus[id] = menu
    parent.CountChildren = parent.CountChildren + 1
    return true
end

function DCAF_Menu_DB:Remove(menu, removeEmptyParent)
    Debug(DCAF.Menu.ClassName..":Remove :: "..menu.Path.." :: removeEmptyParent: "..Dump(removeEmptyParent).." :: menu.Menu: "..DumpPretty(menu.Menu))
    if menu.Group then
        local groupId = menu.Group:GetID()
        missionCommands.removeItemForGroup(groupId, menu.Menu)
    elseif menu.Coalition then
        missionCommands.removeItemForCoalition(menu.Coalition, menu.Menu)
    else
        missionCommands.removeItem(menu.Menu)
    end
    self._index[menu.Key] = nil
    local parent = self:GetParent(menu)
    if not parent then return end
    parent.CountChildren = parent.CountChildren - 1
    if not removeEmptyParent or parent.CountChildren > 0 then return end
    parent:Remove(false)
end

function DCAF_Menu_DB:RemoveChildren(menu)
    local children = DCAF_Menu_DB:GetChildren(menu)
    if not children then return self end

Debug("nisse - DCAF_Menu_DB:RemoveChildren :: children: "..DumpPrettyDeep(children, 1).." :: #children: "..Dump(#children))
    for _, child in ipairs(children) do
Debug("nisse - DCAF_Menu_DB:RemoveChildren :: removes child: "..child.Path.."..")
        local ok, err = pcall(function() child:Remove(false) end)
        if not ok then return Error("WTF?! "..DumpPrettyDeep(err, 2)) end
    end

end

function DCAF_Menu_DB:Get(id) return self._menus[id] end

--- Returns next ID of a new menu
function DCAF_Menu_DB:GetNextID()
    self._nextID = self._nextID + 1
    return self._nextID
end

--- Returns the parent menu of a (child) menu
--- @param menu table Child menu
function DCAF_Menu_DB:GetParent(menu)
    local key = menu.Key
    local i = findLastOccurrence(key, '/')
    if not i then return end
    local prefix = string.sub(key, 1, i-1)
    return self._index[prefix]
end

--- Returns all child menus for a specified menu
---@param menu table The parent menu
function DCAF_Menu_DB:GetChildren(menu)
    local prefix = '^'..escapePattern(menu.Key)
    local children = {}
    local text = menu:GetText()
    for key, child in pairs(self._index) do
        if child:GetText() ~= text and string.find(key, prefix) then children[#children+1] = child end
    end
    return children
end

--- Returns a value indicating whether the menu is a root menu (has no parent)
---@return boolean
function DCAF.Menu:IsRoot() return self.ParentID == DCAF.Menu.ID end

function DCAF.Menu:_resolveGroupOrCoalition(groupOrCoalition, errorPrefix)
    local group
    local coalition
    if groupOrCoalition ~= nil then
        if isGroup(groupOrCoalition) then
            group = groupOrCoalition
        else
            local validCoalition = Coalition.Resolve(groupOrCoalition, true)
            if validCoalition then coalition = groupOrCoalition end
        end
        if group == nil and coalition == nil then
            if errorPrefix then  return Error(errorPrefix.." :: `groupOrCoalition` must be group or coalition, but was: "..DumpPretty(groupOrCoalition)) end
            return
        end
    end
    return group, coalition
end

--- Creates a new F10 menu for all, a coalition, or a group
---@param text string The text to be used
---@param groupOrCoalition any (optional) [default = visible for all] A coalition, or a group
function DCAF.Menu:New(text, groupOrCoalition)
    if not isAssignedString(text) then return Error("DCAF.Menu:New :: `text` must be assigned string, but was: "..DumpPretty(text)) end
    local menu = DCAF.clone(DCAF.Menu)
    local group, coalition
    if self.Group then
        group = self.Group
    elseif self.Coaltiion then
        coalition = self.Coaltion
    elseif groupOrCoalition then
        group, coalition = self:_resolveGroupOrCoalition(groupOrCoalition, "DCAF.Menu:New :: "..self.Path.."/"..text)
    end
    local ok, msg = DCAF_Menu_DB:Add(self, menu, text, group, coalition)
    if not ok then return Error("DCAF.Menu:NewCommand :: cannot add :: "..msg) end
    if group then
        menu.Group = group
        local groupId = group:GetID()
        menu.Menu = missionCommands.addSubMenuForGroup(groupId, text, self.Menu)
Debug("nisse - DCAF.Menu:New :: menu.Menu: "..DumpPretty(menu.Menu))
        -- menu.Menu = MENU_GROUP:New(group, text, self.Menu)
    elseif coalition then
        menu.Coalition = coalition
        menu.Menu = missionCommands.addSubMenuForCoalition(coalition, text, self.Menu)
        -- menu.Menu = MENU_COALITION:New(coalition, text, self.Menu)
    else
        menu.Menu = missionCommands.addSubMenu(text, self.Menu)
        -- menu.Menu = MENU_MISSION:New(text, self.Menu)
    end
    if DCAF.Debug then
        local scope
        if menu.Group then
            scope = menu.Group.GroupName
        elseif menu.Coalition then
            scope = Coalition.Resolve(menu.Coalition)
        else
            scope = "(mission)"
        end
        Debug(DCAF.Menu.ClassName..":New :: "..menu.Path.." :: scope: "..scope)
    end
    return menu
end

local nisse_count = 0

--- Creates a new F10 menu command, 
---@param text string The text to be used
---@param func any A function to be called to handle the command
---@param groupOrCoalition any (optional) [default = visible for all] A coalition, or a group
function DCAF.Menu:NewCommand(text, func, groupOrCoalition)
    if not isAssignedString(text) then return Error("DCAF.Menu:NewCommand :: `text` must be assigned string, but was: "..DumpPretty(text)) end
    if not isFunction(func) then return Error("DCAF.Menu:NewCommand :: `func` must be a function, but was: "..DumpPretty(func)) end
    local menu = DCAF.clone(DCAF.Menu)
    local group, coalition
    if self.Group then
        group = self.Group
    elseif self.Coaltiion then
        coalition = self.Coaltion
    elseif groupOrCoalition then
        group, coalition = self:_resolveGroupOrCoalition(groupOrCoalition, "DCAF.Menu:NewCommand :: "..self.Path.."/"..text)
    end
    local ok, msg = DCAF_Menu_DB:Add(self, menu, text, group, coalition)
    if not ok then return Error("DCAF.Menu:NewCommand :: cannot add :: "..msg) end
    if group then
        menu.Group = group
        local groupId = group:GetID()
        menu.Menu = missionCommands.addCommandForGroup(groupId, text, self.Menu, function() func(menu) end)
Debug("nisse - DCAF.Menu:NewCommand :: menu.Menu: "..DumpPretty(menu.Menu))
        -- menu.Menu = MENU_GROUP_COMMAND:New(group, text, self.Menu, function() func(menu) end)
    elseif coalition then
        menu.Coalition = coalition
        menu.Menu = missionCommands.addCommandForCoalition(coalition, text, self.Menu, function() func(menu) end)
        -- menu.Menu = MENU_COALITION_COMMAND:New(coalition, text, self.Menu, function() func(menu) end)
    else
        menu.Menu = missionCommands.addCommand(text, self.Menu, function() func(menu) end)
        -- menu.Menu = MENU_MISSION_COMMAND:New(text, self.Menu, function() func(menu) end)
    end
    if DCAF.Debug then
        local scope
        if menu.Group then
            scope = menu.Group.GroupName
        elseif menu.Coalition then
            scope = Coalition.Resolve(menu.Coalition)
        else
            scope = "(mission)"
        end
        Debug(DCAF.Menu.ClassName..":NewCommand :: "..menu.Path.." :: scope: "..scope)
    end
    return menu
end

function DCAF.Menu:GetText()
    return self.Menu[#self.Menu]
    -- local path = self.Path
    -- local i = findLastOccurrence(path, '/')
    -- return string.sub(path, i+1, string.len(path))
end

function DCAF.Menu:GetAll(scope)
    local prefix
    if isGroup(scope) then
        prefix = scope.GroupName
    elseif isAssignedString() then
        prefix = scope
    elseif isNumber(scope) then
        local coalition = Coalition.Resolve(scope)
        if not coalition then return Error("DCAF.Menu:DebugDump :: unknown numeric scope: "..scope..". Assumed coalition but could not resolve as such") end
        prefix = coalition
    end
    if not prefix then return DCAF_Menu_DB._menus end
    local menus = {}
    prefix = '^'..escapePattern(prefix)
    for key, menu in pairs(DCAF_Menu_DB._index) do
        local i = string.find(key, prefix)
        if i then menus[#menus+1] = menu end
    end
    return menus
end

--- Removes the menu, possible also removing the parent menu when is has no more sub menus
---@param removeEmptyParent boolean (optional) [default = false] Will also remove its parent menu, if menu is last child menu
function DCAF.Menu:Remove(removeEmptyParent)
    DCAF_Menu_DB:Remove(self, removeEmptyParent)
end

--- Gets parent menu (if any)
function DCAF.Menu:GetParent()
    return DCAF_Menu_DB:GetParent(self)
end

--- Removes all menu's child menus
function DCAF.Menu:RemoveChildren()
    DCAF_Menu_DB:RemoveChildren(self)
end
end -- (DCAF Menu System)



do -- |||||||||||||||||||||||||   Frequencies   |||||||||||||||||||||||||

AM = radio.modulation.AM
FM = radio.modulation.FM

DCAF.FrequencySystems = {
    Aviation = "aviation",
    Maritime = "maritime"
}

DCAF.Frequency = {
    ClassName = "DCAF.Frequency",
    ----
    Freq = 0,
    Mod = AM,
    Name = "",
    System = DCAF.FrequencySystems.Aviation,
    Notes = ""
}


local DCAF_FrequenciesDB = {
    [DCAF.FrequencySystems.Aviation] = { --[[ keys = Frequency names, values = #DCAF.Frequency]]  },
}

DCAF.Frequencies = {
    ClassName = "DCAF.Frequencies",
    ----
    System = DCAF.FrequencySystems.Aviation
}

---Adds a #DCAF.Frequency to the frequency database
---@param frequency table #DCAF.Frequency
function DCAF.Frequencies:Add(frequency)
    if not isClass(frequency, DCAF.Frequency) then return Error("Frequencies:Add :: `frequency` must be #DCAF.Frequency, but was: " .. DumpPretty(frequency)) end
    if not isAssignedString(frequency.Name) then return Error("Frequencies:Add :: `frequency` (" .. frequency.Freq .. ") must be named to be added") end
    local system = DCAF_FrequenciesDB[self.System]
    local key = string.lower(frequency.Name)
    local exists = system[key]
    if exists then return Error("DCAF.Frequencies:Add :: frequency with same name ('"..frequency.Name.."') already exists", exists) end
    system[key] = frequency
    return frequency
end

---Adds a new frequency to the frequency system
---@param name string Frequency identity, within its system
---@param freq number Frequency (including decimal, if applicable)
---@param mod string (optional) [default = "AM"] "AM" or "FM" (tip: You can use identifiers AM or FM)
---@param notes string (optional) Specifies notes/comments/explanation for frequency
---@return any self #DCAF.Frequency
function DCAF.Frequencies:AddNew(name, freq, mod, notes)
    if not isAssignedString(name) then return Error("Frequencies:AddNew :: `frequency` ("..DumpPretty(freq)..") must be named to be added") end
    return self:Add(DCAF.Frequency:New(freq, mod, name, notes))
end

--- Adds and returns a new frequency system
---@param systemName string Name of new frequency system
---@return any newFrequencySystem
function DCAF.Frequencies:AddSystem(systemName)
    if not isAssignedString(systemName) then return Error("DCAF.Frequencies:AddSystem :: `systemName` must be assigned string, but was: " .. DumpPretty(systemName)) end
    local key = string.lower(systemName)
    local exists = DCAF_FrequenciesDB[key]
    if exists then return Warning("DCAF.Frequencies:AddSystem :: System with name '"..systemName.."' already exists", exists) end
    DCAF_FrequenciesDB[key] = {}
    return self:GetSystem(systemName)
end

--- Returns a frequency system
---@param systemName string Name of requested frequency system (eg. 'aviation' or 'maritime')
---@return any frequencySystem #DCAF.Frequencies
function DCAF.Frequencies:GetSystem(systemName)
    if not isAssignedString(systemName) then return Error("DCAF.Frequencies:GetSystem :: `systemName` must be assigned string, but was: " .. DumpPretty(systemName)) end
    local key = string.lower(systemName)
    if not DCAF_FrequenciesDB[key] then return Error("DCAF.Frequencies:GetSystem :: Frequency system with name '"..systemName.."' is not supported") end
    local frequencies = DCAF.clone(DCAF.Frequencies)
    frequencies.System = key
    return frequencies
end

--- Returns a frequency (#DCAF.Frequency)
---@param name string Name of requested frequency
---@param systemName string (optional) [defaul = current frequency system name] Specifies an alternative frequency system
---@return any frequency A #DCAF.Frequency if it is supported by frequency system; otherwise nil
function DCAF.Frequencies:Get(name, systemName)
    if not isAssignedString(name) then return Error("DCAF.Frequencies:Get :: `name` must be assigned string, but was: " .. DumpPretty(name)) end
    local systemKey
    if isAssignedString(systemName) then
        systemKey = string.lower(systemName)
    else
        systemKey = self.System
    end
    local system = DCAF_FrequenciesDB[systemKey]
    if not system then return Error("DCAF.Frequencies:Get :: frequency "..systemKey.."/"..name.." was not found") end
    local key = string.lower(name)
    local freq = system[key]
    if not freq then return Error("DCAF.Frequencies:Get :: frequency "..systemKey.."/"..name.." was not found") end
    return freq
end

--- Gets a named frequency from current frequency system
---@param name string Identifies requested frequency
---@param systemName string (optional) [default = current system] Specifies a frequency system to query for the requested frequency
---@return any frequency A #DCAF.Frequency if one exists in the frequency system; otherwise nil
function DCAF.Frequency:Get(name, systemName)
    local system = DCAF.Frequencies
    if isAssignedString(systemName) then
        system = DCAF.Frequencies:GetSystem(systemName)
        if not system then return end
    end
    return system:Get(name, "")
end

---Creates and returns a new frequency
---@param freq number The frequency value, including decimal (if applicable)
---@param mod string "AM" or "FM" (tip: use radio.modulation enum)
---@return table self
function DCAF.Frequency:New(freq, mod, name, notes)
    local f = DCAF.clone(DCAF.Frequency)
    if not isNumber(freq) then return Error("DCAF.Frequency:New :: ") end
Debug("nisse - DCAF.Frequency:New :: AM: " .. Dump(AM) .. " :: mod: " .. Dump(mod))
    if isAssignedString(mod) and mod ~= AM and mod ~= FM then return Error("DCAF.Frequency:New :: invalid modulation: " .. mod) end
    if name ~= nil and not isAssignedString(name) then return Error("DCAF.Frequency:NewNamed :: `name` must be assigned string, but was: " .. DumpPretty(name)) end
    if notes ~= nil and not isAssignedString(notes) then return Error("DCAF.Frequency:New :: notes must be string, but was: " .. DumpPretty(notes)) end
    f.Freq = freq
    f.Mod = mod or DCAF.Frequency.Mod
    f.Name = name
    f.Notes = notes
    return f
end

---Compares frequency to other frequency and returns a value to indicate they are considered equal
---@param otherFrequency table #DCAF.Frequency
---@return boolean areEqual
function DCAF.Frequency:Equals(otherFrequency)
    if not isClass(otherFrequency, DCAF.Frequency) then return Error("DCAF.Frequency:Equals :: `otherFrequency` must be #"..DCAF.Frequency.ClassName..", but was: "..DumpPretty(otherFrequency)) end
    return self.Freq == otherFrequency.Freq and self.Mod == otherFrequency.Mod and self.Name == otherFrequency.Name
end

-- Aviation
local aviation = DCAF.Frequencies
aviation:AddNew("Guard", 243, AM, "Aviation guard frequency")

-- Maritime
local maritime = DCAF.Frequencies:AddSystem("Maritime")
maritime:AddNew(  "6", 150.300, AM, "Intership safety communication")
maritime:AddNew(  "8", 150.400, AM, "General intership communication")
maritime:AddNew(  "9", 150.450, AM, "Alternate calling channel (regional use)")
maritime:AddNew( "10", 150.500, AM, "Commercial port operations")
maritime:AddNew( "11", 150.550, AM, "Port operations")
maritime:AddNew( "12", 150.600, AM, "Port operations / VTS")
maritime:AddNew( "13", 150.650, AM, "Bridge-to-bridge communication (safety)")
maritime:AddNew( "14", 150.700, AM, "Port operations / VTS")
maritime:AddNew( "15", 150.750, AM, "Onboard communications (low power)")
maritime:AddNew( "16", 151.800, AM, "Distress, safety, and hailing")
maritime:AddNew( "17", 150.850, AM, "Onboard communications (low power)")
maritime:AddNew("22A", 151.100, AM, "U.S. Coast Guard liaison")
maritime:AddNew( "18", 300.250, AM, "Alternate calling channel (regional use)") -- DCAF specific
maritime:AddNew( "19", 300.500, AM, "Alternate calling channel (regional use)") -- DCAF specific
maritime:AddNew( "67", 150.370, AM, "Safety and navigation (often SAR coordination)")
maritime:AddNew( "68", 150.425, AM, "Non-commercial communications")
maritime:AddNew( "69", 150.475, AM, "Non-commercial communications")
maritime:AddNew( "70", 150.525, AM, "Digital Selective Calling (DSC) only")
maritime:AddNew( "71", 150.575, AM, "Non-commercial communications")
maritime:AddNew( "72", 150.625, AM, "Intership communication (non-commercial)")
maritime:AddNew( "73", 150.675, AM, "Intership communication")
maritime:AddNew( "77", 150.875, AM, "Intership communication (non-commercial)")
maritime:AddNew( "82", 150.225, AM, "Government and military use (ITU-designated)")
maritime:AddNew( "83", 151.275, AM, "Government and military use (ITU-designated)")
maritime:AddNew("87B", 151.975, AM, "AIS data transmission")
maritime:AddNew("88B", 152.025, AM, "AIS data transmission")

end

-- ///////////////////////////////////////////////////////////////////
-- Unit information (see https://en.wikipedia.org/wiki/NATO_Joint_Military_Symbology)

DCAF_UnitClass = {
    -- Unknown
    Unknown = "(unknown)",
    -- Airborn
    FixedWing = "Fixed Wing Aircraft",
    RotaryWing = "Rotary Wing Aircraft",
    UAV = "UAV",
    --- Ground
    AirDefence = "Air Defence",
    AntiTank = "Anti Tank",
    Armor = "Armor",
    Artillery = "Artillery",
    Mortar = "Mortar",
    CombinedManoeuvre = "Combined Manoeuvre", -- IFV / APC etc.
    UnarmoredArmed = "Gun equipped vehicle",  -- Gun mounted on otherwise unarmored bvehicle.
    Engineer = "Engineer",
    HQ = "HQ",
    Infantry = "Infantry",
    Missile = "Missile",
    Radar = "Radar",
    Recon = "Recon",
    SpecFor = "Special Forces",
    Transport = "Transport",
    -- Navy
    Navy = "Navy",
}

DCAF_UnitClassModifier = {
    Airborne = "Airborne",
    Parachute = "Parachute",
    Airmobile = "Airmobile",
    Amphibious = "Amphibious",
    Motorized = "Motorized",
    Mountain = "Mountain",
    CannonOrGun = "CannonOrGun",
    WheeledCrossCountry = "Wheeled cross country",
}

local function buildUnitClassWeight(list)
    local weight = {}
    for index, value in ipairs(list) do
        weight[value] = index
    end
    return weight
end

local DCAF_DefaultGroundUnitClassWeight = buildUnitClassWeight({
    DCAF_UnitClass.HQ,
    DCAF_UnitClass.Armor,
    DCAF_UnitClass.AirDefence,
    DCAF_UnitClass.Artillery,
    DCAF_UnitClass.CombinedManoeuvre,
    DCAF_UnitClass.Mortar,
    DCAF_UnitClass.Missile,
    DCAF_UnitClass.AntiTank,
    DCAF_UnitClass.Engineer,
    DCAF_UnitClass.Radar,
    DCAF_UnitClass.Recon,
    DCAF_UnitClass.SpecFor,
    DCAF_UnitClass.Transport,
    DCAF_UnitClass.Infantry,
})

local DCAF_UnitTypeInfo = {
    ClassName = "DCAF_UnitTypeInfo",
    ----
    TypeName = nil,         -- #string (eg. "AV8BNA")
    Nicknames = nil,        -- dictionary of #string(s) (eg. "Harrier")
    Category = nil,         -- Unit.Category.SHIP/.GROUND_UNIT/.AIRPLANE/.HELICOPTER/.STRUCTURE
    UnitClass = nil         -- #DCAF_UnitClass (enum)
}

local DCAF_UnitTypeDB = {
    -- key   = type name (eg. "F-16C_50")
    -- value = #DCAF_UnitTypeInfo
} 
local DCAF_UnitTypeNicknameDB = {
    -- key   = nickname (eg. "Tomcat")
    -- value = list of #DCAF_UnitTypeInfo
}

function DCAF_UnitTypeInfo:New(typeName, category, nickname, unitClass)
    local info = DCAF.clone(DCAF_UnitTypeInfo)
    info.TypeName = typeName
    info.Category = category
    info.UnitClass = unitClass
    DCAF_UnitTypeDB[typeName] = info
    if isAssignedString(nickname) then
        nickname = { nickname }
    end
    if isListOfAssignedStrings(nickname) then
        info.Nicknames = {}
        for _, a in ipairs(nickname) do
            info.Nicknames[a] = true
            local existingNickname = DCAF_UnitTypeNicknameDB[a]
            if not existingNickname then
                existingNickname = {}
                DCAF_UnitTypeNicknameDB[a] = existingNickname
            end
            existingNickname[#existingNickname+1] = info
        end
    end
    return info
end

-- Fixed Wing (WIP)
ENUMS.UnitType = {}
ENUMS.UnitType.AVN8B = DCAF_UnitTypeInfo:New("AV8BNA", Unit.Category.AIRPLANE, "Harrier", DCAF_UnitClass.FixedWing)
ENUMS.UnitType.F15ESE = DCAF_UnitTypeInfo:New("F-15ESE", Unit.Category.AIRPLANE, {"Eagle", "Mud Hen"}, DCAF_UnitClass.FixedWing)
ENUMS.UnitType.F16CM = DCAF_UnitTypeInfo:New("F-16C_50", Unit.Category.AIRPLANE, "Viper", DCAF_UnitClass.FixedWing)
ENUMS.UnitType.F14A135GR = DCAF_UnitTypeInfo:New("F-14A-135-GR", Unit.Category.AIRPLANE, "Tomcat", DCAF_UnitClass.FixedWing)
ENUMS.UnitType.F14B = DCAF_UnitTypeInfo:New("F-14B", Unit.Category.AIRPLANE, "Tomcat", DCAF_UnitClass.FixedWing)
ENUMS.UnitType.FA18C_hornet = DCAF_UnitTypeInfo:New("FA-18C_hornet", Unit.Category.AIRPLANE, {"Hornet", "Bug"}, DCAF_UnitClass.FixedWing)
ENUMS.UnitType.C_130 = DCAF_UnitTypeInfo:New("C-130", Unit.Category.AIRPLANE, {"C-130", "Hercules"}, DCAF_UnitClass.FixedWing)

-- Ground Units // Armor
ENUMS.UnitType.T55 = DCAF_UnitTypeInfo:New("T-55", Unit.Category.GROUND, {"T-55", "MBT T-55"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.T72B = DCAF_UnitTypeInfo:New("T-72B", Unit.Category.GROUND, {"T-72B", "MBT T-72"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.T72B3 = DCAF_UnitTypeInfo:New("T-72B3", Unit.Category.GROUND, {"T-72B3", "MBT T-72"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.T80UD = DCAF_UnitTypeInfo:New("T-80UD", Unit.Category.GROUND, {"T-80UD", "MBT T-80"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.T90 = DCAF_UnitTypeInfo:New("T-90", Unit.Category.GROUND, {"T-90", "MBT T-90"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.TYPE59 = DCAF_UnitTypeInfo:New("TYPE-59", Unit.Category.GROUND, {"Type 59", "MBT Type 59"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Merkava_Mk4 = DCAF_UnitTypeInfo:New("Merkava_Mk4", Unit.Category.GROUND, {"Merkava Mk4", "MBT Merkava"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.M_1_Abrams = DCAF_UnitTypeInfo:New("M-1 Abrams", Unit.Category.GROUND, {"M1A2 Abrams", "MBT M1A2 Abrams"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.M60_Patton = DCAF_UnitTypeInfo:New("M-60", Unit.Category.GROUND, {"M-60 Patton", "MBT Patton"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Challenger2 = DCAF_UnitTypeInfo:New("Challenger2", Unit.Category.GROUND, {"Challenger II", "MBT Challenger"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Chieftain_mk3 = DCAF_UnitTypeInfo:New("Chieftain_mk3", Unit.Category.GROUND, {"Chieftain Mk.3", "MBT Chieftain"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Leclerc = DCAF_UnitTypeInfo:New("Leclerc", Unit.Category.GROUND, {"Leclerc", "MBT Leclerc"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Leopard_1A3 = DCAF_UnitTypeInfo:New("Leopard1A3", Unit.Category.GROUND, {"Leopard 1A3", "MBT Leopard"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Leopard_2A4 = DCAF_UnitTypeInfo:New("leopard-2A4", Unit.Category.GROUND, {"Leopard 2A4", "MBT Leopard"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Leopard_2A4_trs = DCAF_UnitTypeInfo:New("leopard-2A4_trs", Unit.Category.GROUND, {"Leopard 2A4 Trs", "MBT Leopard"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Leopard_2A5 = DCAF_UnitTypeInfo:New("Leopard-2A5", Unit.Category.GROUND, {"Leopard 2A5", "MBT Leopard"}, DCAF_UnitClass.Armor)
ENUMS.UnitType.Leopard_2 = DCAF_UnitTypeInfo:New("Leopard-2", Unit.Category.GROUND, {"Leopard-2", "MBT Leopard"}, DCAF_UnitClass.Armor)

-- Ground Units // APC, Combined Manoeuvre
ENUMS.UnitType.AAV7 = DCAF_UnitTypeInfo:New("AAV7", Unit.Category.GROUND, {"AAV7 Amphibious"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.BTR_80 = DCAF_UnitTypeInfo:New("BTR-80", Unit.Category.GROUND, {"BTR-80"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.M_113 = DCAF_UnitTypeInfo:New("M-113", Unit.Category.GROUND, {"M-113"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.MTLB = DCAF_UnitTypeInfo:New("MTLB", Unit.Category.GROUND, {"MTLB"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.TPZ = DCAF_UnitTypeInfo:New("TPZ", Unit.Category.GROUND, {"TPz Fuchs"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.LARC_V = DCAF_UnitTypeInfo:New("LARC-V", Unit.Category.GROUND, {"LARC-V"}, DCAF_UnitClass.ArCombinedManoeuvremor)
ENUMS.UnitType.ZBD04A = DCAF_UnitTypeInfo:New("ZBD04A", Unit.Category.GROUND, {"ZBD-04A"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.Caiman_mk2 = DCAF_UnitTypeInfo:New("mrap_m2", Unit.Category.GROUND, {"MRAP Caiman MK2"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.Caiman_mk19 = DCAF_UnitTypeInfo:New("mrap_mk19", Unit.Category.GROUND, {"MRAP Caiman MK19"}, DCAF_UnitClass.CombinedManoeuvre)

-- Ground Units // IFV, Combined Manoeuvre
ENUMS.UnitType.BMD_1 = DCAF_UnitTypeInfo:New("BMD-1", Unit.Category.GROUND, {"BMD-1"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.BMP_1 = DCAF_UnitTypeInfo:New("BMP-1", Unit.Category.GROUND, {"BMP-1"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.BMP_2 = DCAF_UnitTypeInfo:New("BMP-2", Unit.Category.GROUND, {"BMP-2"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.BMP_3 = DCAF_UnitTypeInfo:New("BMP-3", Unit.Category.GROUND, {"BMP-3"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.BTR_82A = DCAF_UnitTypeInfo:New("BTR-82A", Unit.Category.GROUND, {"BTR-82A"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.BTR_82A = DCAF_UnitTypeInfo:New("BTR-82A", Unit.Category.GROUND, {"BTR-82A"}, DCAF_UnitClass.CombinedManoeuvre) -- TODO duplicate
ENUMS.UnitType.M1126_Stryker_ICV = DCAF_UnitTypeInfo:New("M1126 Stryker ICV", Unit.Category.GROUND, {"M1126 Stryker ICV"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.M_2_Bradley = DCAF_UnitTypeInfo:New("M-2 Bradley", Unit.Category.GROUND, {"M2A2 Bradley"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.Marder = DCAF_UnitTypeInfo:New("Marder", Unit.Category.GROUND, {"Marder"}, DCAF_UnitClass.CombinedManoeuvre)
ENUMS.UnitType.MCV_80 = DCAF_UnitTypeInfo:New("MCV-80", Unit.Category.GROUND, {"Warrior"}, DCAF_UnitClass.CombinedManoeuvre)

-- Unarmored, modified vehicles (eg. pickup trucks with mounted machines guns etc)
ENUMS.UnitType.HL_DSHK = DCAF_UnitTypeInfo:New("HL_DSHK", Unit.Category.GROUND, {"Armored car"}, DCAF_UnitClass.UnarmoredArmed)
ENUMS.UnitType.HL_KORD = DCAF_UnitTypeInfo:New("HL_KORD", Unit.Category.GROUND, {"Armored car"}, DCAF_UnitClass.UnarmoredArmed)

-- Ground Units // Artillery, Howizer
ENUMS.UnitType.LeFH_18_40_105 = DCAF_UnitTypeInfo:New("LeFH_18-40-105", Unit.Category.GROUND, {"LeFH-18 105mm", "Howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.M2A1_105 = DCAF_UnitTypeInfo:New("M2A1-105", Unit.Category.GROUND, {"M2A1 105mm", "Howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.Pak40 = DCAF_UnitTypeInfo:New("Pak40", Unit.Category.GROUND, {"Pak 40 75mm", "Howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType._2A18M = DCAF_UnitTypeInfo:New("2A18M", Unit.Category.GROUND, {"2A18M D-30", "Howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.L118_Unit = DCAF_UnitTypeInfo:New("L118_Unit", Unit.Category.GROUND, {"L118 Light Gun", "Howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.L118_Unit = DCAF_UnitTypeInfo:New("L118_Unit", Unit.Category.GROUND, {"L118 Light Gun", "Howizer"}, DCAF_UnitClass.Artillery) -- TODO duplicate

-- Ground Units // Artillery, MLRS
ENUMS.UnitType.Smerch = DCAF_UnitTypeInfo:New("Smerch", Unit.Category.GROUND, {"9A52 Smerch CM 300mm", "Smerch"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.Smerch_HE = DCAF_UnitTypeInfo:New("Smerch_HE", Unit.Category.GROUND, {"9A52 Smerch HE 300mm", "Smerch"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.Uragan_BM_27 = DCAF_UnitTypeInfo:New("Uragan_BM-27", Unit.Category.GROUND, {"9K57 Uragan BM-27 220mm", "Uragan"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.Grad_URAL = DCAF_UnitTypeInfo:New("Grad-URAL", Unit.Category.GROUND, {"BM-21 Grad 122mm", "Grad"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.MLRS = DCAF_UnitTypeInfo:New("MLRS", Unit.Category.GROUND, {"MLRS M270 227mm", "MLRS"}, DCAF_UnitClass.Artillery)

-- Ground Units // Artillery, Rocket pods on pickup vehicle
ENUMS.UnitType.HL_B8M1 = DCAF_UnitTypeInfo:New("HL_B8M1", Unit.Category.GROUND, {"HL with B8M1 80mm", "Rocket pod on Pickup"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.tt_B8M1 = DCAF_UnitTypeInfo:New("tt_B8M1", Unit.Category.GROUND, {"LC with B8M1 80mm", "Rocket pod on Pickup"}, DCAF_UnitClass.Artillery)

-- Ground Units // Artillery, Mortar
ENUMS.UnitType._2B11_mortar = DCAF_UnitTypeInfo:New("2B11 mortar", Unit.Category.GROUND, {"2B11 120mm", "Mortar"}, DCAF_UnitClass.Mortar)

-- Ground Units // Self propelled howizer
ENUMS.UnitType.PLZ05 = DCAF_UnitTypeInfo:New("PLZ05", Unit.Category.GROUND, {"PLZ-05", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.SAU_Gvozdika = DCAF_UnitTypeInfo:New("SAU Gvozdika", Unit.Category.GROUND, {"2S1 Gvozdika 122mm", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.SAU_Msta = DCAF_UnitTypeInfo:New("SAU Msta", Unit.Category.GROUND, {"2S19 Msta 152mm", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.SAU_Akatsia = DCAF_UnitTypeInfo:New("SAU Akatsia", Unit.Category.GROUND, {"2S3 Akatsia 152mm", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.SpGH_Dana = DCAF_UnitTypeInfo:New("SpGH_Dana", Unit.Category.GROUND, {"Dana vz77 152mm", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.M_109 = DCAF_UnitTypeInfo:New("M-109", Unit.Category.GROUND, {"M-109 Paladin 155mm", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.T155_Firtina = DCAF_UnitTypeInfo:New("T155_Firtina", Unit.Category.GROUND, {"T155 Firtina 155mm", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)
ENUMS.UnitType.SAU_2_C9 = DCAF_UnitTypeInfo:New("SAU 2-C9", Unit.Category.GROUND, {"2S9 Nona 120mm M", "Self-propelled howizer"}, DCAF_UnitClass.Artillery)

-- Ground Units // Missiles
ENUMS.UnitType.Silkworm_SR = DCAF_UnitTypeInfo:New("Silkworm_SR", Unit.Category.GROUND, {"AShM Silkworm SR", "Silkworm radar"}, DCAF_UnitClass.Missile)
ENUMS.UnitType.hy_launcher = DCAF_UnitTypeInfo:New("hy_launcher", Unit.Category.GROUND, {"AShM SS-N-2 Silkworm", "Silkworm anti-ship missile"}, DCAF_UnitClass.Missile)
ENUMS.UnitType.Scud_B = DCAF_UnitTypeInfo:New("Scud_B", Unit.Category.GROUND, {"SS-1C Scud-B", "SCUD Missile"}, DCAF_UnitClass.Missile)

-- Ground Units // Transport
ENUMS.UnitType.GAZ_3308 = DCAF_UnitTypeInfo:New("GAZ-3308", Unit.Category.GROUND, {"GAZ-3308", "GAZ Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.GAZ_66 = DCAF_UnitTypeInfo:New("GAZ-66", Unit.Category.GROUND, {"GAZ-66", "GAZ Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.KAMAZ = DCAF_UnitTypeInfo:New("KAMAZ Truck", Unit.Category.GROUND, {"KAMAZ Truck", "KAMAZ Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.KrAZ6322 = DCAF_UnitTypeInfo:New("KrAZ6322", Unit.Category.GROUND, {"KrAZ6322", "KrAZ Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.M_818 = DCAF_UnitTypeInfo:New("M 818", Unit.Category.GROUND, {"M-939 Heavy", "M-939 Heavy Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.Ural_375 = DCAF_UnitTypeInfo:New("Ural-375", Unit.Category.GROUND, {"Ural-375", "Ural-375 Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.Ural_4320_31 = DCAF_UnitTypeInfo:New("Ural-4320-31", Unit.Category.GROUND, {"Ural-4320-31 Arm'd", "Ural Armored Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.Ural_4320T = DCAF_UnitTypeInfo:New("Ural-4320T", Unit.Category.GROUND, {"Ural-4320T", "Ural Truck"}, DCAF_UnitClass.Transport)
ENUMS.UnitType.ZIL_135 = DCAF_UnitTypeInfo:New("ZIL-135", Unit.Category.GROUND, {"ZIL-135", "ZIL Truck"}, DCAF_UnitClass.Transport)

function IsUnitType(source, unitType)
    if isGroup(source) then
        for _, unit in ipairs(source:GetUnits()) do
            if IsUnitType(unit, unitType) then return end
        end
    elseif isUnit(source) then
        local info = ENUMS.UnitType[unitType]
        local unitTypeName = source:GetTypeName()
        if info then return unitTypeName == info.TypeName end
        -- look for actual type name...
        info = DCAF_UnitTypeDB[unitType]
        if info then return unitTypeName == info.TypeName end
        -- look for nickname...
        local infos = DCAF_UnitTypeNicknameDB[unitType]
        if infos then
            for _, info in ipairs(infos) do
                if unitTypeName == info.TypeName then
                    return true
                end
            end
        end
    else
        return Error("IsUnitType :: `source` must be UNIT or GROUP, but was: " .. DumpPretty(source))
    end
end

function GetUnitTypeInfo(unitType)
    if isAssignedString(unitType) then
        return GetUnitTypeInfo({ unitType })
    end
    if not isListOfAssignedStrings(unitType) then
        return Error("GetUnitTypeInfo :: `unitType` must be assigned #string or list of #string, but was: " .. DumpPretty(unitType))
    end
    local infos = {}
    for _, i in ipairs(unitType) do
        local info = DCAF_UnitTypeDB[i]
        if info then
            infos[#infos+1] = info
        else
            info = DCAF_UnitTypeNicknameDB[i]
            if info then
                for _, i in ipairs(info) do
                    infos[#infos+1] = i
                end
            end
        end
    end
    return infos
end

function IsAirborneUnitType(unitType)
    local infos = GetUnitTypeInfo(unitType)
    for _, info in ipairs(infos) do
        local category = info.Category
        if category ~= Unit.Category.AIRPLANE and category ~= Unit.Category.HELICOPTER then return false end
    end
    return true
end

--- Examines a UNIT and resolves its "unit class" (#DCAF_UnitClass)
-- @param #Any source - can be #UNIT or name of unit
function GetUnitClass(source)
    local validUnit = getUnit(source)
    if not validUnit then return Error("ResolveUnitClass :: could not resolve UNIT from `source`: " .. DumpPretty(source)) end
    local typeName = validUnit:GetTypeName()
    -- Debug("GetUnitClass :: unit: " .. validUnit.UnitName .. " :: unit type name: " .. typeName)
    local info = GetUnitTypeInfo(validUnit:GetTypeName())
    if info then
        -- Debug("GetUnitClass :: unit: " .. validUnit.UnitName .. " :: unit type name: " .. typeName .. " :: info: " .. DumpPretty(info))
        info = info[1]
        if info then return info.UnitClass end
    end
    if DCAF_GBADDatabase then
        local gbadInfo = DCAF_GBADDatabase:GetInfo(source)
        if gbadInfo then
            return DCAF_UnitClass.AirDefence
        end
    end
    Debug("GetUnitClass :: unit: " .. validUnit.UnitName .. " :: unit type name: " .. typeName .. " :: no unit information found for type: " .. typeName)
    return DCAF_UnitClass.Unknown
end

--- Examines a ground GROUP and resolves its "unit class" (#DCAF_UnitClass)
function ResolveGroundGroupClass(source, classWeight)
    local validGroup = getGroup(source)
    if not validGroup then return Error("ResolveGroupClass :: could not resolve GROUP from `source`: " .. DumpPretty(source)) end
    if not validGroup:IsGround() then return Debug("ResolveGroupClass :: group is not a ground type: " .. DumpPretty(validGroup.GroupName) .. " :: group type: " .. validGroup:GetTypeName()) end
    local units = validGroup:GetUnits()

    if isTable(classWeight) then
        classWeight = buildUnitClassWeight(classWeight)
    else
        classWeight = DCAF_DefaultGroundUnitClassWeight
    end

    local lowestWeight = 999
    local lowestUnitClass
    for _, unit in ipairs(units) do
        local unitClass = GetUnitClass(unit)
        local weight = classWeight[unitClass]
        if not weight then weight = 999 end
            if weight < lowestWeight then
            if weight == 1 then return unitClass end
            lowestWeight = weight
            lowestUnitClass = unitClass
        end
    end
    return lowestUnitClass
end

function tableToList(table)
    if not isTable(table) then
        error("tableToList :: `table` must be table, but was: " .. DumpPretty(table)) end

    local list = {}
    for _, value in pairs(table) do
        list[#list + 1] = value
    end
    return list
end

function listRandomizeOrder(list)
    if not isList(list) then error("listRandomizeOrder :: `list` was not actually a list, but was: " .. DumpPretty(list)) end
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
      end
      return list
end

function listClone(table, deep, startIndex, endIndex)
    if not isList(table) then
        error("tableClone :: `table` must be a list") end
    if not isBoolean(deep) then
        deep = false end
    if not isNumber(startIndex) then
        startIndex = 1  end
    if not isNumber(endIndex) then
        endIndex = #table end

    local clone = {}
    local index = 1
    for i = startIndex, endIndex, 1 do
        if deep then
            clone[index] = DCAF.clone(table[i])
        else
            clone[index] = table[i]
        end
        index = index+1
    end
    return clone
end

function listReverse(list)
    if not isList(list) then
        error("tableClone :: `list` must be a list, but was " .. type(list)) end

    local reversed = {}
    local r = 1
    for i = #list, 1, -1 do
        table.insert(reversed, list[i])
    end
    return reversed
end

function stringStartsWith(s, prefix)
    if not isAssignedString(s) or not isAssignedString(prefix) then
        return end

    local pattern = '^'..escapePattern(prefix)
    return string.find(s, pattern)
end

function stringSplit(s, sep)
    local words = {}
    local sepPattern = ""
    if sep then
        sepPattern = sep
    else
        sepPattern = '%s'
    end
    sepPattern = '[^' .. sepPattern .. ']+'
    for word in s:gmatch(sepPattern) do
        words[#words+1] = word
    end
    return words
end

function stringTrim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- function stringTrim(s)
--     local function countWhitespace(inc)
--         local count = 0
--         local start, last
--         if inc == 1 then
--             start = 1
--             last = #s
--         else
--             start = string.len(s)
--             last = 1
--         end
--         for i = start, last, inc do
--             local c = s:sub(i,i)
--             if c == ' ' or c == '\t' or c == '\n' then
--                 count = count + 1
--             else
--                 return count
--             end
--         end
--     end
--     local count = countWhitespace(1)
--     if count > 0 then
--         s = s:sub(count+1, #s)
--     end
--     count = countWhitespace(-1)
--     if count > 0 then
--         s = s:sub(1, #s - count)
--     end
--     return s
-- end

function fileExists(name)
    if not isAssignedString(name) then
        return false end

    local f=io.open(name,"r")
    if f~=nil then
        io.close(f)
        return true
    else
        return false
    end
end


function math.round(value)
    if not isNumber(value) then
        return end

    local dec = math.abs(value) % 1
    if dec == 0.0 then
        return value end

    if dec >= .5 then
        return math.ceil(value)
    else
        return math.floor(value)
    end
end

KeyValue = {
    ClassName = "DCAF_KEY_VALUE",
    Name = nil,
    Value = nil
}

function KeyValue:New(key, value)
    if key == nil then
        error("KeyValue:New :: `key` must be assigned") end

    local kv = DCAF.clone(KeyValue)
    kv.Key = key
    kv.Value = value
    return kv
end

Skill = {
    Average = "Average",
    High = "High",
    Good = "Good",
    Excellent = "Excellent",
    Random = "Random"
}

AircraftAltitude = {
    VeryLow = "Very low",
    Low = "Low",
    Medium = "Medium",
    High = "High",
    VeryHigh = "Very high"
}

CardinalDirection = {
    North = "North",
    NorthEast = "North East",
    East = "East",
    SouthEast = "South East",
    South = "South",
    SouthWest = "South West",
    West = "West",
    NorthWest = "North West"
}

--- Converts a heading (1-360) into a cardinal direction, or semi-cardinal direction 
function CardinalDirection.FromHeading(heading)
    local x = 90 / 3

    if heading > 360-x and heading <= x then
        return CardinalDirection.North
    elseif heading > x and heading <= 90-x then
        return CardinalDirection.NorthEast
    elseif heading > 90-x and heading <= 90+x then
        return CardinalDirection.East
    elseif heading > 90+x and heading <= 180-x then
        return CardinalDirection.SouthEast 
    elseif heading > 180-x and heading < 180+x then
        return CardinalDirection.South
    elseif heading > 180+x and heading <= 270-x then
        return CardinalDirection.SouthWest 
    elseif heading > 270-x and heading <= 270+x then
        return CardinalDirection.West
    else
        return CardinalDirection.NorthWest
    end
end

--- Converts a cardinal, or semi-cardinal, direction into a heading
function CardinalDirection.ToHeading(direction)
    local x = 90 / 3

    if direction == CardinalDirection.North then
        return 360
    elseif direction == CardinalDirection.NorthEast then
        return 45
    elseif direction == CardinalDirection.East then
        return 90
    elseif direction == CardinalDirection.SouthEast then
        return 135
    elseif direction == CardinalDirection.South then
        return 180
    elseif direction == CardinalDirection.SouthWest then
        return 225
    elseif direction == CardinalDirection.West then
        return 270
    elseif direction == CardinalDirection.NorthWest then
        return 315
    end        
end

function Skill.Validate(value)
    if not isAssignedString(value) then
        return false end

    local testValue = string.lower(value)
    for _, v in pairs(Skill) do
        if isAssignedString(v) and string.lower(v) == testValue then
            if v == Skill.Random then
                local i = math.random(4)
                if i == 1 then
                    return Skill.Average
                elseif i == 2 then
                    return Skill.High
                elseif i == 3 then
                    return Skill.Good
                elseif i == 4 then
                    return Skill.Excellent
                end
            end
            return v
        end
    end
end

function Skill.GetNumeric(value)
    if isNumber(value) then
        return value end

    local skill = Skill.Validate(value)
    if not skill then
        return end

    if skill == Skill.Average then
        return 1
    elseif skill == Skill.Good then
        return 2
    elseif skill == Skill.High then
        return 3
    elseif skill == Skill.Excellent then
        return 4
    end
end

function Skill.FromNumeric(value)
    if not isNumber(value) then
        error("Skill.FromNumeric :: `value` must be numeric, but was: " .. DumpPretty(value)) end

    if value == 1 then
        return Skill.Average
    elseif value == 2 then
        return Skill.Good
    elseif value == 3 then
        return Skill.High
    elseif value == 4 then
        return Skill.Excellent
    end
end

function Skill.GetHarmonized(skill, targetSkill, maxVariation)
    local tgtSkill
    if not isAssignedString(skill) and not isNumber(skill) then
        -- randomize harmonization when no skill gets passed...
        if maxVariation == 0 then
            return targetSkill end

        tgtSkill = Skill.GetNumeric(targetSkill)
        local rndOffset = math.random(0, maxVariation)
        if math.random(100) < 51 then
            return Skill.FromNumeric(math.min(4, tgtSkill + rndOffset))
        else
            return Skill.FromNumeric(math.max(1, tgtSkill - rndOffset))
        end
    end

    tgtSkill = Skill.GetNumeric(targetSkill)
    local numSkill = Skill.GetNumeric(skill)
    local diff = tgtSkill - numSkill
    if math.abs(diff) <= maxVariation then
        return Skill.FromNumeric(numSkill)
    end

    if diff < 0 then
        numSkill = math.min(4, tgtSkill + maxVariation)
    else
        numSkill = math.max(1, tgtSkill - maxVariation)
    end
    return Skill.FromNumeric(numSkill)
end

do -- |||||||||||||||||||||||||||||    Phonetic Alphabet    |||||||||||||||||||||||||||||
PhoneticAlphabet = {
    Upper = {
        A = "Alpha",
        B = "Bravo",
        C = "Charlie",
        D = "Delta",
        E = "Echo",
        F = "Foxtrot",
        G = "Golf",
        H = "Hotel",
        I = "India",
        J = "Juliet",
        K = "Kilo",
        L = "Lima",
        M = "Mike",
        N = "November",
        O = "Oscar",
        P = "Papa",
        Q = "Quebec",
        R = "Romeo",
        S = "Sierra",
        T = "Tango",
        U = "Uniform",
        V = "Victor",
        W = "Whiskey",
        X = "X-Ray",
        Y = "Yankee",
        Z = "Zulu"
    },
    Lower = {
        a = "Alpha",
        b = "Bravo",
        c = "Charlie",
        d = "Delta",
        e = "Echo",
        f = "Foxtrot",
        g = "Golf",
        h = "Hotel",
        i = "India",
        j = "Juliet",
        k = "Kilo",
        l = "Lima",
        m = "Mike",
        n = "November",
        o = "Oscar",
        p = "Papa",
        q = "Quebec",
        r = "Romeo",
        s = "Sierra",
        t = "Tango",
        u = "Uniform",
        v = "Victor",
        w = "Whiskey",
        x = "X-Ray",
        y = "Yankee",
        z = "Zulu"
    },
    Digit = {
        ["0"] = "Zero",
        ["1"] = "One",
        ["2"] = "Two",
        ["3"] = "Tree",
        ["4"] = "Four",
        ["5"] = "Fife",
        ["6"] = "Six",
        ["7"] = "Seven",
        ["8"] = "Eight",
        ["9"] = "Niner",
    },
    Teens = {
        ["11"] = "Eleven",
        ["12"] = "Twelve",
        ["13"] = "Thirteen",
        ["14"] = "Fourteen",
        ["15"] = "Fifteen",
        ["16"] = "Sixteen",
        ["17"] = "Seventeen",
        ["18"] = "Eighteen",
        ["19"] = "Nineteen",
    },
    Tens = {
        ["10"] = "Ten",
        ["20"] = "Twenty",
        ["30"] = "Thirty",
        ["40"] = "Fourty",
        ["50"] = "Fifty",
        ["60"] = "Sixty",
        ["70"] = "Seventy",
        ["80"] = "Eighty",
        ["90"] = "Ninety",
    }
}

PhoneticAlphabet.NumericPrecision = {
    SingleDigit = 1,
    Ten = 10,
    Hundreds = 100,
    Thousands = 1000
}

function PhoneticAlphabet:Convert(text, slow)
    local out = ""
    if not isBoolean(slow) then slow = false end
    for c in string.gmatch(text, '.') do
        local p = self.Upper[c] or self.Lower[c] or self.Digit[c]
        if p then
            if slow then
                p = p .. '. '
            else
                p = p .. ' '
            end
        end
        out = out .. (p or c)
    end
    return stringTrim(out)
end

function PhoneticAlphabet:ConvertNumber(number, precision)
    local s
Debug("nisse - PhoneticAlphabet:ConvertNumber :: number: " .. Dump(number) .. " :: precision: " .. Dump(precision))
    if number > 1000 then
        local thousands = math.floor(number / 1000)
Debug("nisse - PhoneticAlphabet:ConvertNumber :: thousands: " .. Dump(thousands))
        if thousands < 10 then
            s = self.Digit[tostring(thousands)] .. " tousand"
            if precision == self.NumericPrecision.Thousands then return s end
        elseif number < 20 then
            s = self.Teens[tostring(thousands)] .. " tousand"
            if precision == self.NumericPrecision.Thousands then return s end
        elseif number < 100 then
            s = self.Tens[tostring(thousands)] .. " tousand"
            if precision == self.NumericPrecision.Thousands then return s end
        elseif number < 1000 then
            local h = number / 100
            s = self.Digit[h] .. " hundred tousand"
            if precision == self.NumericPrecision.Thousands then return s end
        else -- todo - Do we need to consider millions and other silly high numbers for phonetic expression?
            s = tostring(number)
            if precision == self.NumericPrecision.Thousands then return s end
        end
        number = number - thousands*1000
Debug("nisse - PhoneticAlphabet:ConvertNumber :: (thousands) ::number: " .. Dump(number))
    end
    if number > 100 then
        local hundreds = math.floor(number / 100)
Debug("nisse - PhoneticAlphabet:ConvertNumber :: hundreds: " .. Dump(hundreds))
        if s then
            s = s .. " " .. self.Digit[tostring(hundreds)] .. " hundred"
        else
            s = self.Digit[tostring(hundreds)] .. " hundred"
        end
Debug("nisse - PhoneticAlphabet:ConvertNumber :: hundreds :: s:" .. Dump(s))
        if precision == self.NumericPrecision.Hundreds then return s end
        number = number - hundreds*100
    end
    if number >= 20 then
Debug("nisse - PhoneticAlphabet:ConvertNumber :: tens :: number: " .. Dump(number))
        local tens = math.floor(number / 10) * 10
Debug("nisse - PhoneticAlphabet:ConvertNumber :: tens:" .. Dump(tens))
        number = number - tens
        if s then
            s = s .. " " .. self.Tens[tostring(tens)]
        else
            s = self.Tens[tostring(tens)]
        end
        if precision == self.NumericPrecision.Ten then return s end
        number = number - tens
    end
    if number > 10 then
Debug("nisse - PhoneticAlphabet:ConvertNumber :: teens :: number: " .. Dump(number))
        if s then
            s = s .. " " .. self.Teens[tostring(number)]
        else
            s = self.Teens[tostring(number)]
        end
    elseif number > 0 then
        if s then
            s = s .. " " .. self.Digit[tostring(number)]
        else
            s = self.Digit[tostring(number)]
        end
    end
    return s
end

--- Converts a decimal value into phonetic 'speech', standardized for frequencies
---@param number any The frequency value
---@param decimals any (optional) Can be used to limit or 'pad' the decimal element to a specified length (eg. .2 becomes "two zero zero")
---@return string phoneticFrequency
function PhoneticAlphabet:ConvertFrequencyNumber(number, decimals)
Debug("nisse - PhoneticAlphabet:ConvertFrequencyNumber:: "..Dump(number).." :: decimals: "..Dump(decimals))
    if not isNumber(number) then return Error("PhoneticAlphabet:ConvertFrequencyNumber :: `number` must be numeric value, but was: " .. DumpPretty(number), tostring(number)) end
    if not isNumber(decimals) then decimals = 1 end
    local integer = math.floor(number)
    local text = tostring(number)
    local integerText = tostring(integer)
    local i = string.len(integerText)+1
    local decimalText = string.sub(text, i+1, string.len(text))
    i = string.len(decimalText)
    while i < decimals do
        decimalText = decimalText.."0"
        i = string.len(decimalText)
    end
    return self:Convert(integerText) .. " decimal " .. self:Convert(decimalText)
end

function DCAF.trimInstanceFromName( name, qualifierAt )
    if not isNumber(qualifierAt) then
        qualifierAt = string.find(name, "#%d")
    end
    if not qualifierAt then
        return name end

    return string.sub(name, 1, qualifierAt-1), string.sub(name, qualifierAt)
end

--- Returns phonetic representation of frequency
---@param decimals any  (optional) Can be used to 'pad' the decimal element to a specified length (eg. .2 becomes "two zero zero")
function DCAF.Frequency:PhoneticText(decimals)
    return PhoneticAlphabet:ConvertFrequencyNumber(self.Freq, decimals)
end

end

function DCAF.parseSpawnedUnitName(name)
    local groupName, indexer = DCAF.trimInstanceFromName(name)
    if groupName == name then
        return name end

    -- indexer now have format: <group indexer>-<unit indexer> (eg. "001-2", for second unit of first spawned group)
    local dashAt = string.find(indexer, '-')
    if not dashAt then
        -- should never happen, but ...
        return name end

    local unitIndex = string.sub(indexer, dashAt+1)
    return groupName
end

--- Overrides MOOSE's default function to allow trimming seconds from result
function UTILS.SecondsToClock(seconds, short, trimSeconds)

    if seconds==nil then return nil end

    -- Seconds
    local seconds = tonumber(seconds)

    -- Seconds of this day.
    local _seconds=seconds%(60*60*24)

    if seconds<0 then
        return nil
    else
        local hours = string.format("%02.f", math.floor(_seconds/3600))
        local mins  = string.format("%02.f", math.floor(_seconds/60 - (hours*60)))
        local secs  = string.format("%02.f", math.floor(_seconds - hours*3600 - mins *60))
        local days  = string.format("%d", seconds/(60*60*24))
        local clock=hours..":"..mins..":"..secs.."+"..days
        if not short then
            return clock
        end
        if trimSeconds == nil then
            clock = hours..":"..mins..":"..secs
        else
            clock = hours..":"..mins
        end
        return clock
        -- if hours=="00" then
        --     else
        --         clock = hours..":"..mins..":"..secs
        --     end
        -- end

    end
end

function DCAF.StackTrace(message)
    if message then
        return message .. " :: " .. debug.traceback()
    else
        return debug.traceback()
    end
    -- return BASE.Debug.traceback()
end

--- Schedule repeated invocation of a function
-- @param #function The function to be invoked
-- @param #number The interval (seconds) between invocations
-- @param #number (optional) The time (seconds) to delay the invocaton. Default = `interval`
-- @param #any (optional) Arguments to be passed to function
-- @param #number (optional) Specifies a randomization factor between 0 and 1 to randomize the Repeat
-- @param #number (optional) Specifies a time (seconds) after which the scheduler will be stopped
-- @param #number (optional) Specified an object for MOOSE, for which the timer is setup
function DCAF.startScheduler(func, interval, delay, args, randomizeFactor, stop, masterObject)
    if not isNumber(interval) then
        error("DCAF.startScheduler :: `interval` muste be a number, but was: " .. DumpPretty(interval)) end

    if not isNumber(delay) then
        delay = interval
    end
    if args == nil then
        args = {}
    elseif not isTable(args) then
        args = { args }
    end
    local id = DCAF.Scheduler:Schedule(masterObject or DCAF,
        function()
            func(args)
        end
    , args, delay, interval, randomizeFactor, stop)
    DCAF.Scheduler:Start(id)
    return id
end

--- Delays invocation of a function 
-- @param #function The function to be invoked
-- @param #number The time (seconds) to delay the invocaton
-- @param #any (optional) Arguments to be passed to function
function DCAF.delay(func, delay, args)
    if not isFunction(func) then return Error("DCAF.delay :: `func` must be a function, but was: " .. DumpPretty(func)) end
    if not isNumber(delay) then
        return Error("DCAF.delay :: `delay` must be number, but was: " .. DumpPretty(delay)) end

    if args and not isList(args) then
        args = { args }
    end
    if delay < 0 then
        return Error("DCAF.delay :: `delay` cannot be negative number, but was: " .. delay)
    elseif delay == 0 then
        func(args)
        return
    end

    local id = DCAF.Scheduler:Schedule(nil, func, args, delay, nil, nil, delay)
    DCAF.Scheduler:Start(id)
    return id
end

function DCAF.stopScheduler(id, bRemove)
    if not id then
        return Error("DCAF.stopScheduler :: `id` should be number, but was: " .. Dump(id)) end

    pcall(function()
        DCAF.Scheduler:Stop(id)
        if not isBoolean(bRemove) or bRemove then
            DCAF.Scheduler:Remove(id)
        end
    end)
end

function isGroupNameInstanceOf( name, templateName )
    if name == templateName then
        return true end

    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test = trimInstanceFromName(name, i)
        if test == templateName then
            return true, templateName end
    end

    if i and trimInstanceFromName(name, i) == templateName then
        return true, templateName
    end
    return false
end

function isGroupInstanceOf(group, groupTemplate)
    group = getGroup(group)
    if not group then
        return error("isGroupInstanceOf :: cannot resolve group from: " .. Dump(group)) end

        groupTemplate = getGroup(groupTemplate)
    if not groupTemplate then
        return error("isGroupInstanceOf :: cannot resolve group template from: " .. Dump(groupTemplate)) end

    return isGroupNameInstanceOf(group.GroupName, groupTemplate.GroupName)
end

function isUnitNameInstanceOf(name, templateName)
    if name == templateName then
        return true end

    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test, instanceElement = trimInstanceFromName(name, i)
        if test == templateName then
            -- local counterAt = string.find(instanceElement, "-")
            if not counterAt then
                return false end

            local counterElement = string.sub(instanceElement, counterAt)
            return true, templateName .. counterElement
        end
    end

    if i and trimInstanceFromName(name, i) == templateName then
        return true, templateName
    end
    return false
end

function isUnitInstanceOf( unit, unitTemplate )
    unit = getUnit(unit)
    if not unit then
        return error("isUnitInstanceOf :: cannot resolve unit from: " .. Dump(unit)) end

    unitTemplate = getUnit(unitTemplate)
    if not unitTemplate then
        return error("isUnitInstanceOf :: cannot resolve unit template from: " .. Dump(unitTemplate)) end

    if unit.UnitName == unitTemplate.UnitName then
        return true end

    return isGroupNameInstanceOf( unit:GetGroup().GroupName, unitTemplate:GetGroup().GroupName )
end

function isGroupInstanceOf( group, groupTemplate )
    return isGroupNameInstanceOf( group.GroupName, groupTemplate.GroupName )
end

function swap(a, b, key)
    if key then
        if not isTable(a) or not isTable(b) then error("swap :: when `key` is specified both `a` and `b` must be tables") end
        local _ = a[key]
        a[key] = b[key]
        b[key] = _
    else
        local _ = a
        a = b
        b = _
    end
    return a, b
end

FeetPerNauticalMile = 6076.1155
MetersPerNauticalMile = UTILS.NMToMeters(1)

function Feet(feet)
    return UTILS.FeetToMeters(feet)
end

function Knots(knots)
    return UTILS.KnotsToMps(knots)
end

--- Converts speed expressed as Mach to meters per second
function Mach(mach)
    return mach * 343
end

function MachToKnots(mach)
    if not isNumber(mach) then
        error("MachToKnots :: `mach` must be a number but was : " .. type(mach)) end

    return 666.738661 * mach
end

local function Menu(scope, text, parentMenu)
    if isGroup(scope) then
        return MENU_GROUP:New(scope, text, parentMenu) end

    if isCoalition(scope) then
        return MENU_COALITION:New(scope, text, parentMenu) end

    return Error("Menu :: unknown `scope`: " .. DumpPretty(scope))
end

local function MenuCommand(scope, text, parentMenu, func, ...)
    if isGroup(scope) then
        return MENU_GROUP_COMMAND:New(scope, text, parentMenu, func, ...) end

    if isCoalition(scope) then
        return MENU_COALITION_COMMAND:New(scope, text, parentMenu, func, ...) end

    return Error("Menu :: unknown `scope`: " .. DumpPretty(scope))
end


function getMaxSpeed(source)

    local function getUnitMaxSpeed(unit)
        local unitDesc = Unit.getDesc(unit:GetDCSObject())
        return unitDesc.speedMax
    end

    local unit = getUnit(source)
    if unit then
        return getUnitMaxSpeed(unit)
    end

    local group = getGroup(source)
    if not group then
        error("getMaxSpeed :: cannot resolve neither #UNIT nor #GROUP from `source: `" .. DumpPretty(source)) end

    local slowestMaxSpeed = 999999
    local slowestUnit
    for _, u in ipairs(group:GetUnits()) do
        local speedMax = getUnitMaxSpeed(u)
        if speedMax < slowestMaxSpeed then
            slowestMaxSpeed = speedMax
            slowestUnit = u
        end
    end
    return slowestMaxSpeed, slowestUnit
end

function Hours(seconds)
    if isNumber(seconds) then
        return seconds * 3600
    end
end

function Angels(angels)
    if isNumber(angels) then
        return Feet(angels * 1000)
    end
end

function Minutes(seconds)
    if not isNumber(seconds) then
        error("Minutes :: `value` must be a number but was " .. type(seconds)) end

    return seconds * 60
end

function Hours(seconds)
    if not isNumber(seconds) then
        error("Hours :: `value` must be a number but was " .. type(seconds)) end

    return seconds * 3600
end

function NauticalMiles( nm )
    if (not isNumber(nm)) then error("Expected 'nm' to be number") end
    return MetersPerNauticalMile * nm
end

function ReciprocalAngle(angle)
    return (angle + 180) % 360
end

function concatList(list, separator, itemSerializeFunc)
    if not isString(separator) then
        separator = ", "
    end
    local s = ""
    local count = 0
    for _, v in ipairs(list) do
        if count > 0 then
            s = s .. separator
        end
        count = count+1
        if itemSerializeFunc then
            s = s .. itemSerializeFunc(v)
        else
            if v == nil then
                s = s .. 'nil'
            elseif v.ToString then
                s = s .. v:ToString()
            else
                s = s .. tostring(v)
            end
        end
    end
    return s
end

function listCopy(source, target, sourceStartIndex, targetStartIndex)
    if not isNumber(sourceStartIndex) then
        sourceStartIndex = 1
    end
    if not isTable(target) then
        target = {}
    end
    if isNumber(targetStartIndex) then
        for i = sourceStartIndex, #source, 1 do
            table.insert( target, targetStartIndex, source[i] )
            targetStartIndex = targetStartIndex+1
        end
    else
        for i = sourceStartIndex, #source, 1 do
            table.insert( target, source[i] )
        end
    end
    return target, #target
end

function listCopyWhere(source, target, sourceCriteriaFunc)
    if not isTable(target) then
        target = {}
    end
    for i = 1, #source, 1 do
        if isFunction(sourceCriteriaFunc) then
            if sourceCriteriaFunc(source[i]) then
                table.insert(target, source[i] )
            end
        else
            table.insert(target, source[i] )
        end
    end
    return target, #target
end

--- Creates a new list by concatenating all items of two lists
---@param list table Items from this list will be at start of new list
---@param otherList table Items from this list will be added at the end of new list
---@return table list The resulting new list
function listJoin(list, otherList)
    if not isList(list) then
        error("listJoin :: `list` must be a list, but was: " .. type(list)) end

    if not isList(otherList) then
        error("listJoin :: `otherList` must be a list, but was: " .. type(otherList)) end

    local newList = {}
    for _, v in ipairs(list) do
        table.insert(newList, v)
    end
    for _, v in ipairs(otherList) do
        table.insert(newList, v)
    end
    return newList
end

function tableCopy(source, target, deep)
    local count = 0
    if not isTable(target) then
        target = {}
    end
    for k,v in pairs(source) do
        if target[k] == nil then
            -- if isTable(v) then
            --     target[k] = routines.utils.deepCopy(v)
            -- else
                target[k] = v
            -- end
        end
        count = count + 1
    end
    return target, count
end

---- Returns the internal index of an item in a table, if it exists (otherwise nil)
function tableIndexOf( table, itemOrFunc )
    if not isTable(table) then
        error("tableIndexOf :: unexpected type for table: " .. type(table)) end

    if itemOrFunc == nil then
        error("tableIndexOf :: item was unassigned") end

    for index, value in ipairs(table) do
        if isFunction(itemOrFunc) and itemOrFunc(value) then
            return index
        elseif itemOrFunc == value then
            return index
        end
    end
end

function tableRemoveWhere( tbl, func )
    if not isTable(tbl) then
        error("tableRemoveWhere :: unexpected type for table: " .. type(tbl)) end

    if func == nil then
        error("tableRemoveWhere :: item was unassigned") end

    local indices = {}
    for idx, item in ipairs(tbl) do
        if func(item) then
            table.insert(indices, idx)
        end
    end
    table.sort(indices, function(a, b) return  b < a end)
    for i = 1, #indices, 1 do
        table.remove(tbl, indices[i])
    end
    return tbl
end

function tableKeyOf( table, item )
    if not isTable(table) then
        error("tableKeyOf :: unexpected type for table: " .. type(table)) end

    if item == nil then
        error("tableKeyOf :: item was unassigned") end

    for key, value in pairs(table) do
        if isFunction(item) and item(value) then
            return key
        elseif item == value then
            return key
        end
    end
end

function tableFilter( table, func )
    if table == nil then
        return nil, 0 end

    if not isTable(table) then
        error("tableFilter :: table of unexpected type: " .. type(table)) end

    if func ~= nil and not isFunction(func) then
        error("tableFilter :: func must be function but is: " .. type(func)) end

    local result = {}
    local count = 0
    for k, v in pairs(table) do
        if func(k, v) then
            result[k] = v
            count = count + 1
        end
    end
    return result, count
end

function listRandomItemWhere(list, criteriaFunc)
    if not isTable(list) then
        error("listRandomItem :: `list` must be table but was " .. type(list)) end

    if isFunction(criteriaFunc) then
        list = tableRemoveWhere(listCopy(list, {}), function(i)  return not criteriaFunc(i)  end)
    end
    if #list == 0 then
        return end

    local index = math.random(#list)
    local item = list[index]
    return item, index
end

function listRandomItem(list, ignoreFunctions, nisse)
-- if nisse then
--     Debug("nisse - listRandomItem :: list: " .. DumpPretty(list))
-- end
    if not isList(list) then
        error("listRandomItem :: `list` must be list but was " .. type(list)) end

    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end
    if ignoreFunctions then
        return listRandomItemWhere(list, function(i)  return not isFunction(i)  end)
    end
    if #list == 0 then
        return end

    if #list == 1 then
        return list[1], 1
    end    
    local index = math.random(#list)
    local item = list[index]
if nisse then
    local nisseText = "nisse - listRandomItem :: #list: " .. #list .. " :: index: " .. index
    if isAssignedString(nisse) then
        nisseText = nisseText .. " :: " .. nisse
    end
    Debug(nisseText)
end
    return item, index
end

function listShuffleItems(list)
    if not isList(list) then return Error("listShuffleItems :: `list` must be a list, but was: " .. DumpPretty(list), list) end
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
end

--- Iterates items in a table or SET while applying a time interval between each iteration
--- @param source table The table to be iterated
--- @param func function A function to be called back for each key/value pair in the table
--- @param interval number The interval (seconds) between each iteration
--- @param delay number (optional) [default=0] Delays the first iteration
function tableIterateDelayed(source, func, interval, delay)
    if not isTable(source) then return Error("tableIterateDelayed :: `table` must be a table, but was: " .. DumpPretty(source)) end
    if not isFunction(func) then return Error("tableIterateDelayed :: `func` must be a function, but was: " .. DumpPretty(func)) end
    if not isNumber(interval) then return Error("tableIterateDelayed :: `interval` must be a number, but was: " .. DumpPretty(interval)) end
    if not isNumber(delay) then delay = 0 end
    local scheduleIDs = {}
    local isCancelled = false

    local function cancelIteration()
        isCancelled = true
        for _, scheduleID in pairs(scheduleIDs) do
            DCAF.stopScheduler(scheduleID)
        end
    end

    for key, value in pairs(source) do
        scheduleIDs[key] = DCAF.delay(function()
            if cancelled then return end
            local result = func(key, value)
            if result == false then cancelIteration() end
        end, delay)
        delay = delay + interval
    end
end

function tableIterate(table, func)
    return tableIterateDelayed(table, func, 0, 0)
end

function dictRandomKey(table, maxIndex, ignoreFunctions)
    if not isTable(table) then
        error("dictRandomKey :: `table` is of type " .. type(table)) end

    if not isNumber(maxIndex) then
        maxIndex = dictCount(table)
    end
    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end

    local function getRandomKey()
        local randomIndex = math.random(1, maxIndex)
        local count = 1
        for key, _ in pairs(table) do
            if count == randomIndex then
                return key
            end
            count = count + 1
        end
    end

    local key = getRandomKey()
    while ignoreFunctions and isFunction(table[key]) do
        key = getRandomKey()
    end
    return key
end

function dictGetKeyFor(table, criteria)
    if not isTable(table) then
        error("dictGetKeyFor :: `table` is of type " .. type(table)) end

    for key, v in pairs(table) do
        if isAssignedString(criteria) and criteria == v then
            return key end

        if isFunction(criteria) and criteria(v) then
            return key end
    end
end

function COORDINATE:ToMGRS(precision)
    local lat, lon = coord.LOtoLL( self:GetVec3() )
    local MGRS = coord.LLtoMGRS( lat, lon )
-- 37S DV 24 69
    if not isNumber(precision) then precision = 5 end
    local mgrs = UTILS.tostringMGRS( MGRS, precision )
    if not mgrs then return end
    local split = stringSplit(mgrs)
    local elevationMeter = self:GetLandHeight()
    return {
        Map = split[1],
        Grid = split[2],
        X = split[3],
        Y = split[4],
        Elevation = UTILS.MetersToFeet(elevationMeter)
    }
end

--- Calculates and returns coordinate's corresponding GMRS grid and keypad
-- @returns Object: { Map, Grid, Keypad } (eg. { Map = "36S", Grid = "DV26", Keypad = 5 }
function COORDINATE:ToKeypad()
    local items = self:ToMGRS(3)
    if not items then return end
--Debug("nisse - COORDINATE:ToKeypad() :: items: " .. DumpPretty(items))
    local grid = items.Grid .. " " .. string.sub(items.X, 1, 1) .. string.sub(items.Y, 1, 1)
    local x = tonumber(string.sub(items.X, 2, 3))
    local xo, yo
    if x < 33 then xo = 1 elseif x < 66 then xo = 2 else xo = 3 end
    local y = 100 - tonumber(string.sub(items.Y, 2, 3))
    if y < 33 then yo = 0 elseif y < 66 then yo = 3 else yo = 6 end
-- Debug("nisse - COORDINATE:ToKeypad() :: x: " .. x .. " :: xo: " .. xo .. " y: " .. y .. " :: yo: " .. yo )
    local keypad = xo + yo
-- Debug("nisse - COORDINATE:ToKeypad() :: grid: " .. grid .. " :: keypad: " .. Dump(keypad) )
    return {
        Map = items.Map,
        Grid = grid,
        Keypad = keypad
    }
end

--- Activates groups in a staggered fashion (applying a delay between each activation)
--- @param source any A table, SET_GROUP, or SET_STATIC containing all groups/statics to be activated
--- @param interval number (optional) [default=5] An interval (seconds) between each activation
--- @param onActivatedFunc function (optional) Function to be called back for each activated group. Passes the key and group as arguments
--- @param delay number (optional) [default=0] Delays the first activation
--- @param order any (optional) When specified, the `groups` table will be sorted on a value found in each group. Value can be `true` or a string to specify the name of the index to be used for the activation order
function activateStaggered(source, interval, onActivatedFunc, delay, order)
    Debug("activateStaggered :: source: " .. DumpPretty(source) .. " :: interval: " .. DumpPretty(interval) .. " :: onActivatedFunc: " .. DumpPretty(onActivatedFunc) .. " :: delay: " .. DumpPretty(delay) .. " :: order: " .. DumpPretty(order))
    if isClass(source, SET_BASE) then
        local table = {}
        if isClass(source, SET_GROUP) then
            source:ForEachGroup(function(group) table[#table+1] = group end)
        elseif isClass(source, SET_STATIC) then
            source:ForEachStatic(function(static) table[#table+1] = static end)
        end
        source = table
    end

    if not isTable(source) then return Error("activateStaggered :: `table` must be a #table or #SET_BASE, but was: " .. DumpPretty(table)) end
    if not isNumber(interval) then interval = 5 end
    local activatedGroups = {}

    if order ~= true and not isAssignedString(order) then
        tableIterateDelayed(source, function(key, group)
            local validGroup = getGroup(group)
            if not validGroup then return Error("activateStaggered :: item with key [" .. key .. "] was not a #GROUP :: group: " .. DumpPretty(group) .. " :: IGNORES") end
            group = validGroup
            if not group:IsActive() then
                group:Activate()
                activatedGroups[#activatedGroups+1] = group
                if isFunction(onActivatedFunc) then pcall(function() onActivatedFunc(group, key) end) end
                Debug("activateStaggered :: group " .. group.GroupName .. " was activated")
            end
        end, interval, delay)
        return activatedGroups
    end

    if order == true then order = DCAF.DataKey end
    local sorted = {}
    for k, group in pairs(source) do
        local validGroup = getGroup(group)
        if not validGroup then return Error("activateStaggered :: item with key [" .. k .. "] could not be resolved as a #GROUP :: IGNORES", activatedGroups) end
        group = validGroup
        group.__key = k
        sorted[#sorted+1] = group
    end
    table.sort(sorted, function(groupA, groupB)
        local idxA = groupA[order]
        local idxB = groupB[order]
        if not isNumber(idxA) or not isNumber(idxB) then return true end
        return idxA < idxB
    end)
    tableIterateDelayed(sorted, function(_, group)
        if not group:IsActive() then
            group:Activate()
            if isFunction(onActivatedFunc) then onActivatedFunc(group.__key, group) end
            Debug("activateStaggered :: group " .. group.GroupName .. " was activated")
        end
    end, interval, delay)
    return sourceactivatedGroups
end

function VariableValue:New(value, variance)
    if not isNumber(value) then return Error("VariableValue:New :: `value` must be a number but was " .. type(value)) end

    if isNumber(variance) then
        if variance < 0 then return Error("VariableValue:New :: `variance` must be a positive number, but was " .. Dump(variance)) end
    else
        variance = 0
    end

    local vv = DCAF.clone(VariableValue)
    vv.Value = value
    vv.Variance = variance
    return vv
end

function VariableValue:NewRange(min, max, minVariance, maxVariance)
    if not isNumber(min) then
        error("VariableValue:New :: `min` must be a number but was " .. type(min)) end
    if not isNumber(max) then
        error("VariableValue:New :: `max` must be a number but was " .. type(max)) end
    if minVariance ~= nil and not isNumber(minVariance) then
        error("VariableValue:New :: `minVariance` must be a number but was " .. type(minVariance)) end
    if maxVariance ~= nil and not isNumber(maxVariance) then
        error("VariableValue:New :: `maxVariance` must be a number but was " .. type(maxVariance)) end

    if min > max then
        min, max = swap(min, max)
    elseif min == max then
        return VariableValue:New(min, minVariance)
    end

    local vv = DCAF.clone(VariableValue)
    vv.MinValue = min
    vv.MaxValue = max
    vv.MinVariance = minVariance
    vv.MaxVariance = maxVariance
    return vv
end

function VariableValue:GetValue(variance)
    local function getValue(value, variance)
        if variance == nil or variance == 0 then
            return value end

        local rndVar = math.random(value * variance)
        if math.random(100) <= 50 then
            return value - rndVar
        else
            return value + rndVar
        end
    end

    local function getBoundedValue()
        local minValue = getValue(self.MinValue, self.MinVariance)
        local maxValue = getValue(self.MaxValue, self.MaxVariance or self.MinVariance)
        return math.random(minValue, maxValue )
    end

    if not isNumber(variance) then variance = self.Variance end
    if self.MinValue then
        return getBoundedValue()
    end
    return getValue(self.Value, variance)
end

function roundToNearest(number, n)
    return math.floor((number + n / 2) / n) * n
end

RoundMethod = {
    Round = 1,
    Floor = 2,
    Ceiling = 3
}

function VariableValue:GetIntegerValue(roundMethod)
    local value = self:GetValue()
    if not isNumber(roundMethod) then
        roundMethod = RoundMethod.Round
    end

    if roundMethod == RoundMethod.Floor then
        return math.floor(value)
    elseif roundMethod == RoundMethod.Ceiling then
        return math.ceil(value)
    else
        -- round...
        local floor = math.floor(value)
        local dec = value - floor
        if dec <= .5 then
            return floor
        else
            return floor+1
        end
    end
end

function Vec3_FromBullseye(aCoalition)
    local testCoalition = Coalition.Resolve(aCoalition, true)
    if isNumber(testCoalition) then
        return coalition.getMainRefPoint(testCoalition)
    end
    error("Vec3_FromBullseye :: cannot resolve numeric coalition from: " .. DumpPretty(aCoalition))
end

function ParseTACANChannelAndMode(text, defaultMode)
    local sChannel = text:match("[0-9]*")
    if not isAssignedString(sChannel) then
        return end

    local mode = text:match("[X,Y]")
    if not isAssignedString(mode) then
        if not isAssignedString(defaultMode) then
            defaultMode = "X"
        else
            local test = string.upper(defaultMode)
            if test ~= 'X' and test ~= 'Y' then
                error("ParseTACANChannelAndMode :: `defaultMode` must be 'X' or 'Y', but was: '" .. mode .. "'")
            end
        end
    end
    return tonumber(sChannel), mode
end

function DCAF.DateTime:New(year, month, day, hour, minute, second)
    local date = DCAF.clone(DCAF.DateTime)
    date.Year = year
    date.Month = month
    date.Day = day
    date.Hour = hour or DCAF.DateTime.Hour
    date.Minute = minute or DCAF.DateTime.Minute
    date.Second = second or DCAF.DateTime.Second
    local t = { year = date.Year, month = date.Month, day = date.Day, hour = date.Hour, min = date.Minute, sec = date.Second }
    date._timeStamp = os.time(t)
    local d = os.date("*t", date._timeStamp)
    date.IsDST = d.isdst
    date.IsUTC = false
    return date
end

function DCAF.DateTime:ParseDate(sYMD)
    local sYear, sMonth, sDay = string.match(sYMD, "(%d+)/(%d+)/(%d+)")
    return DCAF.DateTime:New(tonumber(sYear), tonumber(sMonth), tonumber(sDay))
end

function DCAF.DateTime:ParseDateTime(sYMD_HMS)
    local sYear, sMonth, sDay, sHour, sMinute, sSecond = string.match(sYMD_HMS, "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
    return DCAF.DateTime:New(tonumber(sYear), tonumber(sMonth), tonumber(sDay), tonumber(sHour), tonumber(sMinute), tonumber(sSecond))
end

function DCAF.DateTime:Now()
    return DCAF.DateTime:ParseDateTime(UTILS.GetDCSMissionDate() .. " " .. UTILS.SecondsToClock(UTILS.SecondsOfToday()))
end

function DCAF.DateTime:TotalHours()
    return self.Hour + self.Minute / 60 + self.Second / 3600
end

function DCAF.DateTime:AddSeconds(seconds)
    local timestamp = self._timeStamp + seconds
    local d = os.date("*t", timestamp)
    return DCAF.DateTime:New(d.year, d.month, d.day, d.hour, d.min, d.sec)
end

function DCAF.DateTime:AddMinutes(minutes)
    return self:AddSeconds(minutes * 60)
end

function DCAF.DateTime:AddHours(hours)
    return self:AddSeconds(hours * 3600)
end

function DCAF.DateTime:ToUTC()
    local diff = UTILS.GMTToLocalTimeDifference()
    if self.IsDST then
        diff = diff + 1
    end
    return self:AddHours(diff)
end

function DCAF.DateTime:ToString()
    return Dump(self.Year) .. "/" .. Dump(self.Month) .. "/" ..Dump(self.Day) .. " " .. Dump(self.Hour) .. ":" .. Dump(self.Minute) .. ":" .. Dump(self.Second)
end

-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                           WEATHER
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.Weather = {
    Factor = 1,
}

DCAF.Precipitation = {
    None = "None",
    Light = "Light",
    Medium = "Heavy"
}

function DCAF.Weather:Static()
    if DCAF.Weather._static then
        return DCAF.Weather._static
    end
    local w = DCAF.clone(DCAF.Weather)
    DCAF.Weather._static = w
    return w
end

-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                   COORDINATE - extensions
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local Deg2Rad = math.pi / 180.0;
local Rad2Deg = 180.0 / math.pi

function COORDINATE:SunPosition(dateTime)
    if not isClass(dateTime, DCAF.DateTime.ClassName) then
        dateTime = DCAF.DateTime:Now()--:ToUTC()
    end
    if dateTime.IsDST then
        dateTime = dateTime:AddHours(-1)
    end
    -- Get latitude and longitude as radians
    local latitude, longitude = self:GetLLDDM()
    latitude = math.rad(latitude)
    longitude = math.rad(longitude)

    local function correctAngle(angleInRadians)
        if angleInRadians < 0 then
            return 2 * math.pi - (math.abs(angleInRadians) % (2 * math.pi)) end
        if angleInRadians > 2 * math.pi then
            return angleInRadians % (2 * math.pi) end

        return angleInRadians
    end

    local julianDate = 367 * dateTime.Year -
            ((7.0 / 4.0) * (dateTime.Year +
                    ((dateTime.Month + 9.0) / 12.0))) +
            ((275.0 * dateTime.Month) / 9.0) +
            dateTime.Day - 730531.5
    local julianCenturies = julianDate / 36525.0
    local siderealTimeHours = 6.6974 + 2400.0513 * julianCenturies
    local siderealTimeUT = siderealTimeHours + (366.2422 / 365.2422) * dateTime:TotalHours()
    local siderealTime = siderealTimeUT * 15 + longitude
    -- Refine to number of days (fractional) to specific time.
    julianDate = julianDate + dateTime:TotalHours()
    julianCenturies = julianDate / 36525.0

    -- Solar Coordinates
    local meanLongitude = correctAngle(Deg2Rad * (280.466 + 36000.77 * julianCenturies))
    local meanAnomaly = correctAngle(Deg2Rad * (357.529 + 35999.05 * julianCenturies))
    local equationOfCenter = Deg2Rad * ((1.915 - 0.005 * julianCenturies) * math.sin(meanAnomaly) + 0.02 * math.sin(2 * meanAnomaly))
    local elipticalLongitude = correctAngle(meanLongitude + equationOfCenter)
    local obliquity = (23.439 - 0.013 * julianCenturies) * Deg2Rad

    -- Right Ascension
    local rightAscension = math.atan(
            math.cos(obliquity) * math.sin(elipticalLongitude),
            math.cos(elipticalLongitude))
    local declination = math.asin(math.sin(rightAscension) * math.sin(obliquity))

    -- Horizontal Coordinates
    local hourAngle = correctAngle(siderealTime * Deg2Rad) - rightAscension
    if hourAngle > math.pi then
        hourAngle = hourAngle - 2 * math.pi
    end

    local altitude = math.asin(math.sin(latitude * Deg2Rad) *
            math.sin(declination) + math.cos(latitude * Deg2Rad) *
            math.cos(declination) * math.cos(hourAngle))

    -- Nominator and denominator for calculating Azimuth
    -- angle. Needed to test which quadrant the angle is in.
    local aziNominator = -math.sin(hourAngle);
    local aziDenominator = math.tan(declination) * math.cos(latitude * Deg2Rad) - math.sin(latitude * Deg2Rad) * math.cos(hourAngle)
    local azimuth = math.atan(aziNominator / aziDenominator)
    if aziDenominator < 0 then -- In 2nd or 3rd quadrant
        azimuth = azimuth + math.pi
    elseif (aziNominator < 0) then -- In 4th quadrant
        azimuth = azimuth + 2 * math.pi
    end
    return altitude * Rad2Deg, azimuth * Rad2Deg
end

local _occupiedAreas = {
    -- list of #DCAF_ReservedArea
}
local _OCCUPIED_AREAS_PURGE_INTERVAL = Minutes(2)
local _reservedAreasPurgeTime = UTILS.SecondsOfToday() + _OCCUPIED_AREAS_PURGE_INTERVAL

local DCAF_OccupiedArea = {
    ClassName = "DCAF_OccupiedArea",
    Coordinate = nil,               -- #COORDINATE
    Radius = nil,                   -- #number - meters
    Time = nil                      -- #number - seconds
}

function DCAF_OccupiedArea:New(coordinate, radius, expires)
    local rc = DCAF.clone(DCAF_OccupiedArea)
    rc.Coordinate = coordinate
    rc.Radius = radius
    rc.Expires = expires
    table.insert(_occupiedAreas, rc)
    return rc
end

function DCAF_OccupiedArea:Purge(now)
    local now = now or UTILS.SecondsOfToday()
    if now < _reservedAreasPurgeTime then
        return end

    _reservedAreasPurgeTime = now + _OCCUPIED_AREAS_PURGE_INTERVAL
    local newOccipedAreas = {}
    for i, occupied in ipairs(_occupiedAreas) do
        if now < occupied.Expires then
            table.insert(newOccipedAreas, occupied)
        end
    end
    _occupiedAreas = newOccipedAreas
end

function COORDINATE:Occupy(radius, time)
    if not self then
        return self end

    if not isNumber(radius) then
        radius = 0
    end
    if not isNumber(time) then
        time = 35535
    end
    if self:IsOccupied() then
        error("COORDINATE:Reserve :: coordinate is already reserved") end

    DCAF_OccupiedArea:New(self, radius, time + UTILS.SecondsOfToday())
    return self
end

function COORDINATE:IsOccupied()
    local now = UTILS.SecondsOfToday()
    DCAF_OccupiedArea:Purge(now)
    for _, occupied in ipairs(_occupiedAreas) do
        if now < occupied.Expires and self:Get2DDistance(occupied.Coordinate) < occupied.Radius then
            return true
        end
    end
end

function COORDINATE:GetFlatArea(flatAreaSize, searchAreaSize, excludeSelf, maxInclination)
    if not isNumber(flatAreaSize) then
        error("COORDINATE:GetFlatArea :: `radius` must be number, but was: " .. DumpPretty(flatAreaSize)) end

    if not isNumber(searchAreaSize) then
        searchAreaSize = 200
    end
    if not isBoolean(excludeSelf) then
        excludeSelf = false
    end
    searchAreaSize = math.max(searchAreaSize, flatAreaSize)
    if not isNumber(maxInclination) then
        maxInclination = 0.05
    end
    maxInclination = math.max(0.005, maxInclination)
    if not excludeSelf then
        local inclination = self:GetLandInclination(flatAreaSize)
        if inclination <= maxInclination then
            return self end
    end

    local now = UTILS.SecondsOfToday()

    local function purgeExpiredBlockedCoordinates()
        if now < _reservedAreasPurgeTime then
            return end

        local newBlocked = {}
        for i, reserved in ipairs(_occupiedAreas) do
            if now < reserved.Expires then
                table.insert(newBlocked, reserved)
            end
        end
        _occupiedAreas = newBlocked
    end

    local function searchSquareEdge(searchSize) -- 1, 2, 3... (eg. 2 = `flatAreaSize` x 2)
        local coord = self:Translate(flatAreaSize * searchSize, 360):Translate(flatAreaSize * searchSize, 270)
        local function searchHeading(hdg)
            for i = 1, searchSize*2, 1 do
                coord = coord:Translate(flatAreaSize, hdg)
                local inclination = coord:GetLandInclination(flatAreaSize)
                if inclination <= maxInclination then
                    return coord end
            end
        end

        for _, hdg in ipairs({90, 180, 270, 360}) do
            local coordFlat = searchHeading(hdg)
            if coordFlat and not coordFlat:IsOccupied() then
                return coordFlat
            end
        end
    end

    local maxSearchSize = searchAreaSize / flatAreaSize
    for size = 1, maxSearchSize, 1 do
        local coord = searchSquareEdge(size)
        if coord then
            return coord end
    end
end

function COORDINATE:GetLandInclination(gridSizeX, gridSizeY, measureInterval)
    if not isNumber(gridSizeX) then
        gridSizeX = 200 -- meters
    end
    if not isNumber(gridSizeY) then
        gridSizeY = gridSizeX
    end
    if not isNumber(measureInterval) then
        measureInterval = math.max(gridSizeX, gridSizeY) / 10 -- 10 measurepoints
    end

    local heightMin = 9999999999
    local coordMin
    local heightMax = 0
    local coordMax
    local function measureHeight(coord)
        local height = coord:GetLandHeight()
        if height < heightMin then
            heightMin = height;
            coordMin = coord
        end
        if height > heightMax then
            heightMax = height
            coordMax = coord
        end
    end

    local coordX = self:Translate(gridSizeX / 2, 360):Translate(gridSizeY / 2, 270)
    measureHeight(coordX)
    for x = measureInterval, gridSizeX - measureInterval, measureInterval do
        for y = measureInterval, gridSizeY - measureInterval, measureInterval do
            local coordY = coordX:Translate(y, 180)
            measureHeight(coordY)
        end
        coordX = coordX:Translate(x, 90)
        measureHeight(coordX)
    end

    local distMinMax = coordMin:Get2DDistance(coordMax)
    local heightDifference = heightMax - heightMin
    return heightDifference / distMinMax
end

function COORDINATE_FromWaypoint(wp)
    return COORDINATE:New(wp.x, wp.alt, wp.y)
end

function COORDINATE_FromBullseye(aCoalition)
    local vec3 = Vec3_FromBullseye(aCoalition)
    if vec3 then
        return COORDINATE:NewFromVec3(vec3)
    end
end

function DCAF.GetBullseye(location, aCoalition)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then
        return Error("DCAF.GetBullseye :: cannot resolve `location` from: " .. DumpPretty(location)) end

    local be = COORDINATE:NewFromVec3(Vec3_FromBullseye(aCoalition))
    local coord = location:GetCoordinate()
    local bearing = be:HeadingTo(coord)
    local distance = be:Get2DDistance(coord)
    return bearing, UTILS.MetersToNM(distance), DCAF.GetBullseyeName(aCoalition)
end

--- Inserts a white space after each digit of a number and returns the resulting string (eg. "1234" => "1 2 3 4 "). Useful for when numbers are to be pronounced by a TTS voice
local function toSeparateDigits(number)
    local sNumber
    if isAssignedString(number) then
        sNumber = number
    elseif isNumber(number) then
        sNumber = tostring(math.round(number))
    else
        return Error("toPronouncedNumber :: `number` was neither a number nor a string")
    end
    return string.gsub(sNumber, "(%d)", "%1 ")
end

function DCAF.GetBullseyeText(location, aCoalition, bearingSeparateDigits)
    local beBearing, beDistance, beName = DCAF.GetBullseye(location, aCoalition)
    if not beBearing then return end
    beDistance = math.round(beDistance)
    if beDistance == 9 then
        beDistance = "niner"
    else
        beDistance = tostring(beDistance)
    end
    if bearingSeparateDigits then
        local sBearing = string.gsub(toSeparateDigits(beBearing), "9", "niner")
        return string.format("%s %s. %s", beName, sBearing, beDistance)
    end
    return string.format("%s %d. %s", beName, beBearing, beDistance)
end

function DCAF.InitBullseyeName(sName, aCoalition)
    if aCoalition == nil then
        aCoalition = Coalition.Blue
    else
        aCoalition = Coalition.Resolve(aCoalition)
        if not aCoalition then
            error("DCAF.InitBullseyeName :: cannot resolve `aCoalition` from: " .. DumpPretty(aCoalition)) end
    end

    if not DCAF.BullseyeNames then
        DCAF.BullseyeNames = {}
    end
    DCAF.BullseyeNames[aCoalition] = sName
end

function DCAF.GetBullseyeName(aCoalition)
    if aCoalition == nil then
        aCoalition = Coalition.Blue
    else
        local testCoalition = Coalition.Resolve(aCoalition)
        if not testCoalition then
            error("DCAF.InitBullseyeName :: cannot resolve `aCoalition` from: " .. DumpPretty(aCoalition)) end

        aCoalition = testCoalition
    end
    if DCAF.BullseyeNames and DCAF.BullseyeNames[aCoalition] then
        return DCAF.BullseyeNames[aCoalition]
    else
        return "BULLSEYE"
    end
end

function Debug_DrawWaypoints(waypoints)
    if not isTable(waypoints) then
        return end

    for _, wp in ipairs(waypoints) do
        local coord = COORDINATE_FromWaypoint(wp)
        coord:CircleToAll(nil, nil, nil, nil, nil, nil, nil, nil, wp.name)
    end
end

function TraceIgnore(message, ...)
    Trace(message .. " :: IGNORES")
    return arg
end

function exitTrace(message, ...)
    Warning(message .. " :: EXITS")
    return arg
end

function exitWarning(message, ...)
    Warning(message .. " :: EXITS")
    return arg
end

function errorOnDebug(message)
    if DCAF.Debug then
        error(message)
    else
        Error(message)
    end
end

function Delay( seconds, userFunction, data )
    if isVariableValue(seconds) then
        seconds = seconds:GetValue()
    end
    if not isNumber(seconds) then error("Delay :: `seconds` must be #number or #VariableValue, but was: " .. DumpPretty(seconds)) end
    if not isFunction(userFunction) then error("Delay :: `userFunction` must be function, but was: " .. type(userFunction)) end

    if seconds == 0 then
        userFunction(data)
        return
    end

    local timer = TIMER:New(
        function()
            userFunction(data)
         end):Start(seconds)
end

local _missionStartTime = UTILS.SecondsOfToday()

function MissionClock( short )
    if not isBoolean(short) then
        short = true
    end
    return UTILS.SecondsToClock(UTILS.SecondsOfToday(), short)
end

function MissionStartTime()
    return _missionStartTime
end

function MissionTime()
    return UTILS.SecondsOfToday() - _missionStartTime
end

function SecondsOfToday(missionTime)
    return _missionStartTime + (missionTime or 0)
end

function MissionClockTime( short, offset )
    if (short == nil) then
        short = true
    end
    if not isNumber(offset) then
        offset = 0
    end
    return UTILS.SecondsToClock( MissionTime() + offset, short )
end

local function log( rank, message )
end

---------------------------- FILE SYSTEM -----------------------------

-- https://www.geeks3d.com/hacklab/20210901/how-to-check-if-a-directory-exists-in-lua-and-in-python/

files = {}

function files.gettype( path )
    local attributes = lfs.attributes( path )
    if attributes then
        return attributes.mode end
    return nil
end

function files.isdir( path )
    return files.gettype( path ) == "directory"
end

function files.isfile( path )
    return files.gettype( path ) == "file"
end

function files.exists( path )
    return file.gettype( path ) ~= nil
end

------------------------------------------------------------------

GroupType = {
    Air = "Air",
    Airplane = "Airplane",
    Helicopter = "Helicopter",
    Ship = "Ship",
    Ground = "Ground",
    Structure = "Structure",
}

AiSkill = {
    Average = "Average",
    Good = "Good",
    High = "High",
    Excellent = "Excellent"
}

function Coalition.Resolve(value, returnDCS)
    local resolvedCoalition
    if isAssignedString(value) then
        local test = string.lower(value)
        if test == Coalition.Blue then resolvedCoalition = Coalition.Blue
        elseif test == Coalition.Red then resolvedCoalition = Coalition.Red
        elseif test == Coalition.Neutral then resolvedCoalition = Coalition.Neutral end
    elseif isList(value) then
        for _, v in ipairs(value) do
            resolvedCoalition = Coalition.Resolve(v)
            if resolvedCoalition then
                break end
        end
        return resolvedCoalition
    elseif isNumber(value) then
        if value == coalition.side.BLUE then
            resolvedCoalition = Coalition.Blue
        elseif value == coalition.side.RED then
            resolvedCoalition = Coalition.Red
        elseif value == coalition.side.NEUTRAL then
            resolvedCoalition = Coalition.Neutral
        end
    elseif isGroup(value) or isUnit(value) then
        return Coalition.Resolve(value:GetCoalition())
    end
    if resolvedCoalition and returnDCS then
        if resolvedCoalition == Coalition.Blue then return coalition.side.BLUE end
        if resolvedCoalition == Coalition.Red then return coalition.side.RED end
        if resolvedCoalition == Coalition.Neutral then return coalition.side.NEUTRAL end
    else
        return resolvedCoalition
    end
end

function Coalition.ToNumber(coalitionValue)
    if not isAssignedString(coalitionValue) then
        error("Coalition.ToNumber :: `coalition` must be string (but was " .. type(coalitionValue) .. ")")
    end
    local c = string.lower(coalitionValue)
    if c == Coalition.Blue then return coalition.side.BLUE end
    if c == Coalition.Red then return coalition.side.RED end
    if c == Coalition.Neutral then return coalition.side.NEUTRAL end
    error("Coalition.ToNumber :: unrecognized `coalition` name: '" .. coalitionValue .. "'")
    return -1
end

function Coalition.FromNumber(coalitionValue)
    if coalitionValue == coalition.side.RED then
        return Coalition.Red end

    if coalitionValue == coalition.side.BLUE then
        return Coalition.Blue end

    if coalitionValue == coalition.side.NEUTRAL then
        return Coalition.Neutral end
end

function Coalition.Equals(a, b)
    if isAssignedString(a) then
        a = Coalition.ToNumber(a)
    elseif not isNumber(a) then
        error("Coalition.Equals :: `a` must be string or number (but was " .. type(a) .. ")")
    end
    if isAssignedString(b) then
        b = Coalition.ToNumber(b)
    elseif not isNumber(b) then
        error("Coalition.Equals :: `b` must be string or number (but was " .. type(b) .. ")")
    end
    return a == b
end

function Coalition.IsAny(coalition, table)
    if not isTable(table) then
        error("Coalition.IsAny :: `table` must be string or number (but was " .. type(table) .. ")")
    end
    for _, c in ipairs(table) do
        if Coalition.Equals(coalition, c) then
            return true
        end
    end
end

function GroupType.IsValid(value, caseSensitive)
    if not isBoolean(caseSensitive) then
        caseSensitive = false
    end
    if isString(value) then
        local test
        if caseSensitive then
            test = value
        else
            test = string.lower(value)
        end
        return test == GroupType.Air
            or test == GroupType.Airplane
            or test == GroupType.Ground
            or test == GroupType.Ship
            or test == GroupType.Structure
    elseif isList(value) then
        for _, v in ipairs(value) do
            if not GroupType.IsValid(v) then
                return false end
        end
        return true
    end
end

function GroupType.IsAny(groupType, table)
    if not isTable(table) then
        error("GroupType.IsAny :: `table` must be string or number (but was " .. type(table) .. ")")
    end
    for _, gt in ipairs(table) do
        if groupType == gt then
            return true
        end
    end
end

function DCAF.Smoke:New(remaining, color)
    if not isNumber(remaining) then
        remaining = 1
    end
    if not isNumber(color) then
        color = SMOKECOLOR.Red
    end
    local smoke = DCAF.clone(DCAF.Smoke)
    smoke.Color = color
    smoke.Remaining = remaining
    return smoke
end

function DCAF.Flares:Shoot(coordinate)
    if not isCoordinate(coordinate) then
        error("DCAF.Flares:Shoot :: `coordinate` must be " .. COORDINATE.ClassName .. ", but was: " .. DumpPretty(coordinate)) end

    if self.Remaining == 0 then
        return end

    coordinate:Flare(self.Color)
    self.Remaining = self.Remaining-1
    return self
end

function DCAF.Flares:New(remaining, color)
    if not isNumber(remaining) then
        remaining = 1
    end
    if not isNumber(color) then
        color = SMOKECOLOR.Red
    end
    local smoke = DCAF.clone(DCAF.Flares)
    smoke.Color = color
    smoke.Remaining = remaining
    return smoke
end

-- @smoke       :: #DCAF.Smoke
function DCAF.Smoke:Pop(coordinate, color)
    if not isCoordinate(coordinate) then
        error("DCAF.Smoke:Pop :: `coordinate` must be " .. COORDINATE.ClassName .. ", but was: " .. DumpPretty(coordinate)) end

    if self.Remaining == 0 then
        return end

    coordinate:Smoke(color or self.Color)
    self.Remaining = self.Remaining-1
    return self
end


local SPAWNS = { -- dictionary
    -- key   = template name
    -- value = #SPAWN
}

function getSpawn(source)
    local function f()
        local spawn = SPAWNS[source]
        if spawn then return
            spawn
        end
        if isClass(source, GROUP) then
            source = source.GroupName
        end
        spawn = SPAWN:New(source)
        SPAWNS[source] = spawn
        return spawn
    end

    local success, spawn = pcall(f)
    if success then
        if string.find(spawn.SpawnTemplatePrefix, "-UC-") then
            spawn:InitAIOnOff(false)
        end
        return spawn
    end
end

function getSpawnWithAlias(name, alias)
    local function f()
        local key = name .. "::" .. alias
        local spawn = SPAWNS[key]
        if spawn then return
            spawn end
        spawn = SPAWN:NewWithAlias(name, alias)
        SPAWNS[key] = spawn
        return spawn
    end

    local success, spawn = pcall(f)
    if success then
        if string.find(spawn.SpawnTemplatePrefix, "-UC-") then
            spawn:InitAIOnOff(false)
        end
        return spawn 
    end
end

function activateNow( source )
    local group = getGroup( source )
    if not group then
        return exitWarning("activateNow :: cannot resolve group from " .. Dump(source))
    end
    if not group:IsActive() then
        Trace("activateNow :: activates group '" .. group.GroupName .. "'")
        group:Activate()
    end
    return group
end

function spawnNow( source )
    local name = nil
    if isGroup(source) then
        name = source.GroupName
    elseif isString(source) then
        name = source
    else
        error("spawnNow :: source is unexpected type: " .. type(source)) end

    local group = getSpawn( name ):Spawn()
    activateNow( group ) -- hack. Not sure why the spawned group is not active but this fixes that
    return group
end

function despawnNow( source )
    local unit = getUnit(source)
    if unit and unit:IsAlive() then
        Debug("despawnNow :: despawns unit '" .. unit.UnitName .. "'")
        unit:Destroy()
        return
    end

    local group = getGroup( source )
    if not group then
        return exitWarning("despawnNow :: cannot resolve group from " .. Dump(source))
    end
    if group:IsAlive() then
        Debug("despawnNow :: despawns group '" .. group.GroupName .. "'")
        group:Activate()
    end
    return group
end

function isSameHeading( group1, group2 )
    return math.abs(group1:GetHeading() - group2:GetHeading()) < 5
end

function isSameAltitude( group1, group2 )
    return math.abs(group1:GetAltitude() - group2:GetAltitude()) < 500
end
function isSameCoalition( group1, group2 ) return group1:GetCoalition() == group2:GetCoalition() end

local function isSubjectivelySameGroup( group1, group2 )
    -- determines whether a group _appears_ to be flying together with another group

    return group1:IsAlive() and group2:IsAlive()
            and isSameCoalition(group1, group2)
            and isSameHeading(group1, group2)
            and isSameAltitude(group1, group2)
end

function COORDINATE:EnsureY(useDefaultY)
    if self.y == nil then
        self.y = useDefaultY or 0
    end
    return self
end

function COORDINATE:GetBearingTo(coordinate)
    local from = self:EnsureY()
    coordinate = coordinate:EnsureY()
    local dirVec3 = from:GetDirectionVec3(coordinate)
    local bearing = from:GetAngleDegrees(dirVec3)
    return bearing
end

DCAF.Location = {
    ClassName = "DCAF.Location",
    Name = nil,         -- #string
    Source = nil,       -- #COORDINATE, #GROUP, #UNIT, #AIRBASE, or #STATIC
    Coordinate = nil,   -- COORDINATE
    Type = nil          -- #string - type of location
}

local DCAF_Location_Delegates = {
    -- list of #DCAF.LocationDelegate
}

DCAF.LocationDelegate = {
    ClassName = "DCAF.LocationDelegate"
    ----
}

function DCAF.LocationDelegate:New()
    return DCAF.clone(DCAF.LocationDelegate)
end

function DCAF.LocationDelegate:ResolveLocation(source)
end

function DCAF.Location.AddDelegate(delegate)
    if not isClass(delegate, DCAF.LocationDelegate) then return Error("DCAF.Location.AddDelegate :: `delegate` must be #" .. DCAF.LocationDelegate.ClassName .. ", but was: " .. DumpPretty(delegate)) end
    DCAF_Location_Delegates[#DCAF_Location_Delegates+1] = delegate
end

function DCAF.Location:NewRaw(name, source, coordinate, coalition)
    local location = DCAF.clone(DCAF.Location)
    location.Name = name
    location.Source = source
    location.Coalition = coalition
    if isFunction(coordinate) then
        location._funcGetCoordinate = coordinate
    else
        location.Coordinate = coordinate
    end
    return location
end

function DCAF.Location:NewNamed(name, source, coalition, throwOnFail, debug)
    if source == nil then
        error("DCAF.Location:New :: `source` cannot be unassigned") end

    if debug then Debug("DCAF.Location:NewNamed :: source: " .. DumpPretty(source)) end

    if not isBoolean(throwOnFail) then
        throwOnFail = true
    end
    local location = DCAF.clone(DCAF.Location)
    location.Source = source
    location.IsAir = false
    if isClass(source, DCAF.Location) then
        return source
    elseif isCoordinate(source) then
        location.Coordinate = source
        location.Name = name or source:ToStringLLDDM()
        return location
    elseif isZone(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = name or source:GetName()
        return location
    elseif isVec2(source) then
        location.Coordinate = COORDINATE:NewFromVec2(source)
        location.Name = "(x="..Dump(source.x)..",y=" .. Dump(source.y) .. ")"
        return location
    elseif isVec3(source) then
        location.Coordinate = COORDINATE:NewFromVec3(source)
        location.Name = "(x="..Dump(source.x)..",y=" .. Dump(source.y) .. ", z=" .. Dump(source.z) .. ")"
        return location
    elseif isAirbase(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = name or source.AirbaseName
        location.IsAir = false
        -- location.IsAirdrome = true
        return location
    elseif isGroup(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = name or source.GroupName
        location.IsAir = source:IsAir()
        location.IsShip = source:IsShip()
        location.IsGround = source:IsGround()
        location.IsControllable = true
        return location
    elseif isUnit(source) or isUnit(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = name or source.UnitName
        location.IsAir = source:IsAir()
        location.IsShip = source:IsShip()
        location.IsGround = source:IsGround()
        location.IsControllable = true
        return location
    elseif isStatic(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = name or source.GroupName
        location.IsStatic = true
        return location
    else
        -- try resolve source...
        for _, delegate in ipairs(DCAF_Location_Delegates) do
            local resolvedLocation = delegate:ResolveLocation(source)
            if resolvedLocation then
                return resolvedLocation
            end
        end
        if coalition then
            local validCoalition = Coalition.Resolve(coalition)
            if not validCoalition then return Error("DCAF.Location:NewNamed :: `coalition` could not be resolved: " .. DumpPretty(coalition)) end
            local refPoint = getRefPoint(source, coalition)
            if refPoint then return refPoint end
        end
        local airbase = getAirbase(source)
        if airbase then return DCAF.Location:New(airbase) end

        local zone = getZone(source)
        if zone then return DCAF.Location:New(zone) end

        local unit = getUnit(source)
        if unit then return DCAF.Location:New(unit) end

        local group = getGroup(source)
        if group then return DCAF.Location:New(group) end

        local static = getStatic(source)
        if static then return DCAF.Location:New(static) end

        if throwOnFail then
            error("DCAF.Location:New :: `source` is unexpected value: " .. DumpPretty(source))
        else
            Error("DCAF.Location:New :: `source` is unexpected value: " .. DumpPretty(source))
            return location
        end
    end
end

function DCAF.Location.ResolveZone(source)
    local zone = getZone(source)
    if zone then return DCAF.Location:New(zone) end
    local group = getGroup(source)
    if group then
        local route = group:CopyRoute()
        if #route > 0 then
            local name = "ZNP " .. group.GroupName
            local zone = ZONE_POLYGON:New(name, group)
            return DCAF.Location:NewNamed(name, zone)
        end
    end
end

function DCAF.Location:New(source, coalition, throwOnFail, debug)
    return DCAF.Location:NewNamed(nil, source, coalition, throwOnFail, debug)
end

function DCAF.Location.Resolve(source, coalition, debug)
    if isClass(source, DCAF.Location.ClassName) then return source end
    local d = DCAF.Location:New(source, coalition, false, debug)
    if d then return d end
end

function DCAF.Location:SetAltitude(value, asl)
    if not isNumber(value) then
        return Error("DCAF.Location:SetAltitude :: `value` must be number, but was: " .. DumpPretty(value)) end

    if asl ~= nil and not isBoolean(asl) then
        return Error("DCAF.Location:SetAltitude :: `asl` must be boolean, but was: " .. DumpPretty(value)) end

    self.Altitude = value
    self.IsAltitudeAsl = asl
    local coordinate = self:GetCoordinate()
    if coordinate then
        self.Coordinate = coordinate:SetAltitude(value, asl)
    end
    if self.IsControllable then
        self.Source:SetAltitude(value)
    end
    return self
end

function DCAF.Location:GetAltitude(realtime)
    if realtime and self.IsControllable then
        return self.Source:GetAltitude(self.IsAltitudeAsl), self.IsAltitudeAsl
    end
    self.Altitude = self.Altitude or self:GetLandHeight()
    return self.Altitude
    -- return self.Altitude or self:GetCoordinate().y, self.IsAltitudeAsl
end

function DCAF.Location:GetLandHeight()
    return self:GetCoordinate():GetLandHeight()
end

function DCAF.Location:CircleToAll(radius, coalition, color, alpha, fillColor, fillAlpha, lineType, readOnly, text)
    return self:GetCoordinate():CircleToAll(radius, coalition, color, alpha, fillColor, fillAlpha, lineType, readOnly, text)
end

function DCAF.Location:Get3DDistance(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return end
    location = validLocation
    local coord = self:GetCoordinate()
    if not coord then return Error("DCAF.Location:Get3DDistance :: cannot get own location coordinate") end
    local coordLocation = location:GetCoordinate()
    if not coordLocation then return Error("DCAF.Location:Get3DDistance :: cannot get other location's coordinate") end
    return coord:Get3DDistance(coordLocation)
end

--- Gets distance (meters) to another location
---@param location any Any object resolvable as #DCAF.Location
---@return any distance The distance to location, if coordinates can be produced; otherwise nil
function DCAF.Location:Get2DDistance(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return end
    location = validLocation
    local coord = self:GetCoordinate()
    if not coord then return Error("DCAF.Location:Get2DDistance :: cannot get own location coordinate") end
    local coordLocation = location:GetCoordinate()
    if not coordLocation then return Error("DCAF.Location:Get2DDistance :: cannot get other location's coordinate") end
    return coord:Get2DDistance(coordLocation)
end

--- Specifies two locations and registers a handler function to be invoked once those locations are inside a specified range
---@param range number The specified range (meters)
---@param location any Any object resolvable as a #DCAF.Location
---@param funcInRange function Handler function to be called back once locations are within range of each other
---@param exitRange number (optional) When specified (meters), function will automatically stop monitoring for locations coming within mutual range
---@param interval number (optional) [default = 1] Specifies an interval (seconds) to be used for monitoring locations coming within mutual range
---@param funcExit function (optional) Handler function to be called back once locations are outside of `exitRange`
---@return self any self
function DCAF.Location:WhenIn2DRange(range, location, funcInRange, exitRange, interval, funcExit)
    if not isNumber(range) or range < 1 then return Error("DCAF.Location:WhenIn2DRange :: `range` must be positive number, but was: " .. DumpPretty(range), self) end
    if not isFunction(funcInRange) then return Error("DCAF.Location:WhenIn2DRange :: `handlerInRange` must be function, but was: " .. DumpPretty(funcInRange), self) end
    if funcExit and not isFunction(funcExit) then return Error("DCAF.Location:WhenIn2DRange :: `handlerExit` must be function, but was: " .. DumpPretty(funcExit)) end

    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error("DCAF.Location:WhenIn2DRange :: could not resolve `locationB`: " .. DumpPretty(location), self) end
    location = validLocation
    Debug("DCAF.Location:WhenIn2DRange :: "..self.Name.." :: range: "..range.." :: location: "..location.Name.." :: interval: "..DumpPretty(interval))

    if isNumber(exitRange) and exitRange <= range then return Error("DCAF.Location:WhenIn2DRange :: `exitRange` must be greater than `range` ("..range.."), but was: "..exitRange) end

    if not isNumber(interval) or interval < 1 then interval = 1 end


    local schedulerID
    local function endScheduler(msg)
        if msg then Error("DCAF.Location:WhenIn2DRange :: " .. msg) end
        pcall(function() DCAF.stopScheduler(schedulerID) end)
    end

    schedulerID = DCAF.startScheduler(function()
        local distance = self:Get2DDistance(location)
        if distance > range then
            if exitRange and distance >= exitRange then
                if funcExit then pcall(function() funcExit(distance) end) end
                return endScheduler()
            end
            return
        end
        -- in range
        endScheduler()
        local ok, err = pcall(function() funcInRange(distance) end)
        if not ok then Error("DCAF.Location:WhenIn2DRange :: error in 'funcInRange' handler: " .. DumpPretty(err)) end
    end, interval)
    return self
end

function DCAF.Location:WhenAirInRange(range, funcInRange, coalition, ignoreAI, breakOnFirst, measureSlantRange, interval)
    if not isNumber(range) or range < 1 then return Error("DCAF.Location:WhenAirIn2DRange :: `range` must be positive number, but was: " .. DumpPretty(range), self) end
    if not isFunction(funcInRange) then return Error("DCAF.Location:WhenAirIn2DRange :: `handlerInRange` must be function, but was: " .. DumpPretty(funcInRange), self) end
    if coalition ~= nil then
        local validCoalition = Coalition.Resolve(coalition)
        if not validCoalition then return Error("DCAF.Location:WhenAirIn2DRange :: cannot resolve coalition: "..DumpPretty(coalition)) end
    end
    if not isNumber(interval) or interval < 1 then interval = 1 end
    if not isBoolean(ignoreAI) then ignoreAI = false end
    if not isBoolean(breakOnFirst) then breakOnFirst = true end
    if not isBoolean(measureSlantRange) then
        if self:IsAirborne() then measureSlantRange = true end
    end
    local shedulerID
    shedulerID = DCAF.startScheduler(function()
        local units = ScanAirborneUnits(self, range, coalition, breakOnFirst, measureSlantRange, nil, true, ignoreAI)
        if not units:Any() then return end
        local scan = { Units = units.Units, EndScan = true }
        local ok, response = pcall(function() funcInRange(scan) end)
        if ok then
            if scan.EndScan then
                pcall(function() DCAF.stopScheduler(shedulerID) end)
            end
        else
            Error("DCAF.Location:WhenAirIn2DRange :: error invoking funcInRange: "..DumpPretty(response))
        end
    end, interval)
end

function DCAF.Location:OffsetDistance(value)
    if not isNumber(value) then
        return Error("DCAF.Location:OffsetHeading :: `value` must be number, but was: " .. DumpPretty(value)) end

    self.Offset = self.Offset or {}
    self.Offset.Distance = value
    return self
end

function DCAF.Location:OffsetBearing(value)
    if not isNumber(value) then
        return Error("DCAF.Location:OffsetHeading :: `value` must be number, but was: " .. DumpPretty(value)) end

    self.Offset = self.Offset or {}
    self.Offset.Heading = nil
    self.Offset.Bearing = value
    return self
end

function DCAF.Location:OffsetHeading(value)
    if not self.IsControllable then
        return Error("DCAF.Location:OffsetHeading :: cannot offset heading for non-controllables") end

    if not isNumber(value) then
        return Error("DCAF.Location:OffsetHeading :: `value` must be number, but was: " .. DumpPretty(value)) end

    self.Offset = self.Offset or {}
    self.Offset.Bearing = nil
    self.Offset.Heading = value
    return self
end

function DCAF.Location:OffsetAltitude(value)
    if not isNumber(value) then
        return Error("DCAF.Location:OffsetHeading :: `value` must be number, but was: " .. DumpPretty(value)) end
        
    self.Offset = self.Offset or {}
    self.Offset.Altitude = value
    return self
end

function DCAF.Location:GetCoordinate(enforceAltitude, asl)
    if self._funcGetCoordinate then
        return self._funcGetCoordinate(self)
    end
    if self.IsControllable then
        self.Coordinate = self.Source:GetCoordinate()
    end
    if enforceAltitude then
        if isNumber(enforceAltitude) then
            self.Coordinate:SetAltitude(enforceAltitude, asl or self.IsAltitudeAsl)
        elseif self.Altitude then
            self.Coordinate:SetAltitude(self.Altitude, asl or self.IsAltitudeAsl)
        end
    end
    return self.Coordinate
end

function DCAF.Location:GetHeading()
    if self.Source.GetHeading then
        return self.Source:GetHeading()
    end
    return self:GetCoordinate():GetHeading()
end

function DCAF.Location:Translate(distance, angle, keepAltitude)
    return DCAF.Location:New(self:GetCoordinate():Translate(distance, angle, keepAltitude))
end

function DCAF.Location:GetOffset(keepAltitude)
    if not self.Offset then
        Warning("DCAF.Location:TranslateOffset :: no Offset specified")
        return self
    end
    if not self.Offset.Distance then
        Warning("DCAF.Location:TranslateOffset :: no Offset distance specified")
        return self
    end
    local bearing = self.Offset.Bearing
    if not bearing and self.Offset.Heading then
        bearing = self.Source:GetHeading() + self.Offset.Heading
    end
    if not bearing then
        Warning("DCAF.Location:TranslateOffset :: no Offset specified")
        return self
    end
    return self:Translate(self.Offset.Distance, bearing, keepAltitude)
end

function DCAF.Location:GetAGL()
    if isUnit(self.Source) or isGroup(self.Source) then
        return self.Source:GetAltitude(true)
    end

    return self.Coordinate.y - self.Coordinate:GetLandHeight()
end

--- Examines a 'location' and returns a value to indicate it is airborne
-- See also: DCAF.Location:IsGrounded()
function DCAF.Location:IsAirborne(errorMargin)
    if not self.IsAir then
        return false
    end
    if not isNumber(errorMargin) then
        errorMargin = 5
    end
    return self.Source:IsAirborne()
end

--- Examines a 'location' and returns a value to indicate it is "grounded" (not airborne)
-- See also: DCAF.Location:IsAirborne()
function DCAF.Location:IsGrounded(errorMargin)
    return not self:IsAirborne(errorMargin)
end

function DCAF.Location:HeadingTo(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error("DCAF.Location:HeadingTo :: cannot resolve `location`: " .. DumpPretty(location)) end
    return self:GetCoordinate():HeadingTo(validLocation:GetCoordinate())
end

DCAF.ClosestUnits = {
    ClassName = "DCAF.ClosestUnits",
    Count = 0,
    Units = { -- list
        -- value = { Unit = #UNIT, Distance = #number (meters) }
    }
}

function DCAF.ClosestUnits:New()
    return DCAF.clone(DCAF.ClosestUnits)
end

function DCAF.ClosestUnits:Get(coalition, sortOnDistance)
    local validCoaliton = Coalition.Resolve(coalition)
    if not validCoaliton then
        error("DCAF.ClosestUnits:Get :: cannot resolve #Coalition from: " .. DumpPretty(coalition)) end

    local units = self.Units[validCoaliton]
    if units and sortOnDistance == true then
        table.sort(units, function(a, b)
            return a.Distance <= b.Distance
        end)
    end
    return units
end

function DCAF.ClosestUnits:GetSortedOnDistance()
    local units = DCAF.clone(self.Units, false)
    table.sort(units, function(a, b)
        return a.Distance <= b.Distance
    end)
    return units
end

function DCAF.ClosestUnits:Any()
    return self.Count > 0
end

function DCAF.ClosestUnits:AnyPlayer()
    if not self:Any() then return end
    for _, info in ipairs(self.Units) do
        local unit = info.Unit
Debug("nisse - DCAF.ClosestUnits:AnyPlayer :: unit:IsPlayer(): " .. Dump(unit:IsPlayer()))
        if unit:IsPlayer() then return true end
    end
end

function DCAF.ClosestUnits:First()
    if self.Count == 0 then return end
    local info = self.Units[1]
    return info.Unit, info.Distance
end

function DCAF.ClosestUnits:Set(unit, distance)
    self.Units[#self.Units+1] = { Unit = unit, Distance = distance, DistanceNM = UTILS.MetersToNM(distance) }
    self.Count = self.Count+1
    return self
end

function DCAF.ClosestUnits:ForEachUnit(func, coalition, sortOnDistance)
    local units = self.Units
    if sortOnDistance then
        units = self:GetSortedOnDistance()
    end
    if not isFunction(func) then return Error("DCAF.ClosestUnits:ForEachUnit :: `func` must be function, but was: " .. DumpPretty(func)) end
    for _, info in ipairs(units) do
        func(info.Unit, info.Distance)
    end
end

function DCAF.ClosestUnits:GetUnitList(coalition, sortOnDistance)
    local units = self.Units
    if sortOnDistance then
        units = self:GetSortedOnDistance()
    end
    local list = {}
    for _, info in ipairs(units) do
        list[#list+1] = info.Unit
    end
    return list
end

DCAF_GetAirborneUnits_Cache_TTL = 1
local DCAF_GetAirborneUnits_Cache = {
    --[[
    -- key   = coalition
    -- value = { 
        TTL = 1, -- Time To Live, in seconds
        Timestamp = 0,
        Units = {}
    }
    ]]
}

function GetAirborneUnits(coalition, cacheTTL, skip)
    local now = UTILS.SecondsOfToday()
    local isSkipGroups
    if skip then
        if isListOfClass(skip, GROUP) then
            isSkipGroups = true
        elseif not isListOfClass(skip, UNIT) then
            Warning("GetAirborneUnits :: ignore was of unexpected type: " .. DumpPrettyDeep(skip, 2) .. " :: IGNORES")
            skip = nil
        end
    end
    cacheTTL = cacheTTL or DCAF_GetAirborneUnits_Cache_TTL
    local cacheKey
    if not coalition then
        cacheKey = "(none)"
    else
        local validCoalition = Coalition.Resolve(coalition, true)
        if validCoalition then
            coalition = validCoalition
            cacheKey = coalition
        else
            Error("GetAirborneUnits :: cannot resolve `coalition`: " .. DumpPretty(coalition))
            return {}
        end
    end
    local cache = DCAF_GetAirborneUnits_Cache[cacheKey]
    if cache and cache.Timestamp + cacheTTL > now then
        return cache.Units -- cache is still valid
    end

    local airborneUnits = {}
    local function testMatch(group)
        if not group:IsActive() or not group:IsAlive() or not group:IsAirborne(false) then
            return end

        if isSkipGroups and tableIndexOf(skip, function(skipGroup) return skipGroup == group end) then
            return end

        if coalition then
            local coalitionGroup = group:GetCoalition()
            if coalitionGroup ~= coalition then
                return end
        end

        local function isSkipped(unit)
            if not skip then return false end
            return tableIndexOf(skip, function(skipUnit) return skipUnit == unit end)
        end

        for _, unit in ipairs(group:GetUnits()) do
            if unit:IsAlive() and unit:InAir() and not isSkipped(unit) then
                airborneUnits[#airborneUnits+1] = unit
            end
        end
    end

    for _, group in pairs(_DATABASE.GROUPS) do
        local dcsObject = Group.getByName( group.GroupName )
        if dcsObject then testMatch(group) end
    end
    cache = {
        TTL = cacheTTL,
        Timestamp = now,
        Units = airborneUnits
    }
    DCAF_GetAirborneUnits_Cache[cacheKey] = cache
    return airborneUnits
end

function ScanAirborneUnits(location, range, coalition, breakOnFirst, measureSlantRange, cacheTTL, ignoreOwn, ignoreAI)
    local closestUnits = DCAF.ClosestUnits:New()
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then
        Error("ScanAirborneUnits :: could not resolve valid location from: " .. DumpPretty(location))
        return closestUnits
    end
    local location = validLocation
    if not isNumber(range) or range < 1 then return Error("ScanAirborneUnits :: `range` must be positive number, but was: " .. DumpPretty(range), closestUnits) end
    if not isBoolean(ignoreOwn) then ignoreOwn = true end
    if not isBoolean(ignoreAI) then ignoreAI = false end

    local coordinate = location:GetCoordinate()
    if not coordinate then return Error("ScanAirborneUnits :: cannot get coordinate from location: " .. location.Name, closestUnits) end
    local skip
    if ignoreOwn and location:IsGroup() or location:IsUnit() then
        skip = { location.Source }
    end
    local airborneUnits = GetAirborneUnits(coalition, cacheTTL, skip)

    local function isMatch(unit)
        local coordUnit = unit:GetCoordinate()
        if not coordUnit then return end
        if ignoreAI and unit:GetPlayerName() == nil then return end

        local distance
        if measureSlantRange then
            distance = coordinate:Get3DDistance(coordUnit)
        else
            distance = coordinate:Get2DDistance(coordUnit)
        end
-- Debug("nisse - ScanAirborneUnits :: unit: " .. unit.UnitName .. " :: range: " .. Dump(range) .. " :: distance: " .. Dump(distance))
        if distance > 0 and distance <= range then
            return true, distance
        end
    end

    for _, unit in ipairs(airborneUnits) do
        local matching, distance = isMatch(unit)
        if matching then
            closestUnits:Set(unit, distance)
            if breakOnFirst then
                break end
        end
    end
    return closestUnits
end

function DCAF.Location:GetUnitsInRange(range, coalitions, filterFunc, isShapeCylinder)
    local isMultipleCoalitions = false
    if isNumber(coalitions) then
        local validCoalition = Coalition.Resolve(coalitions)
        if not validCoalition then
            return Error("DCAF.Location:GetUnitsInRange :: cannot resolve coalition from: " .. DumpPretty(coalitions))
        end
        coalitions = validCoalition
    elseif isList(coalitions) then
        local cList = {}
        for i, c in ipairs(coalitions) do
            local validCoalition = Coalition.Resolve(c)
            if not validCoalition then
                return Error("DCAF.Location:GetUnitsInRange :: cannot resolve coalition #" .. Dump(i) .. "; from: " .. DumpPretty(c))
            end
            table.insert(cList, validCoalition)
        end
        if #cList > 1 then
            coalitions = cList
            isMultipleCoalitions = true
        else
            coalitions = cList[1]
        end
    else
        local validCoalition = Coalition.Resolve(coalitions)
        if not validCoalition then
            return Error("DCAF.Location:GetUnitsInRange :: cannot resolve coalition from: " .. DumpPretty(coalitions)) 
        end
        coalitions = validCoalition
    end

    local unitsInRange = DCAF.ClosestUnits:New()
    local coordOwn = self:GetCoordinate()
    if not coordOwn then return end
    local units = coordOwn:ScanUnits(range)
    local function isCoalition(unitCoalition)
        if not isMultipleCoalitions then
            return unitCoalition == coalitions
        end
        for _, testCoalition in ipairs(coalitions) do
            if testCoalition == unitCoalition then
                return true
            end
        end
    end
    local hasFilterFunc = isFunction(filterFunc)
    units:ForEachUnit(function(u)
        if not u:IsAlive() then return end
        local unitCoalition = Coalition.Resolve(u:GetCoalition())
        if not isCoalition(unitCoalition) then
            return
        end
        local distance 
        if isShapeCylinder == true then
            distance = self.Coordinate:Get2DDistance(u:GetCoordinate())
        else
            distance = self.Coordinate:Get3DDistance(u:GetCoordinate())
        end
        if not hasFilterFunc or filterFunc(u, distance) then
            local info = unitsInRange:Get(unitCoalition)
            if not info or info.Distance > distance then
                unitsInRange:Set(u, distance)
            end
        end
    end)
    return unitsInRange
end

--- Gets the closest units for specified coalition(s)
-- @maxDistance : #numeric (meters)
-- @param #Coalition coalitions : #string, #number (DCS) or table of these types
-- @param function filterFunc : (optional) custom callback function. Passes #UNIT as single parameter, to be included when function returns `true`
-- @param boolen isShapeCylinder : (optional) when true, only lateral range is considered (not slante range)
-- returns #DCAF.ClosestUnits
function DCAF.Location:GetClosestUnits(maxDistance, coalitions, filterFunc, isShapeCylinder)

    if not isNumber(maxDistance) then
        maxDistance = NauticalMiles(50)
    end
    local isMultipleCoalitions = false
    if isNumber(coalitions) then
        local testCoalition = Coalition.Resolve(coalitions)
        if not testCoalition then
            error("DCAF.Location:GetClosestUnit :: cannot resolve coalition from: " .. DumpPretty(coalitions)) end

        coalitions = testCoalition
    elseif isList(coalitions) then
        local cList = {}
        for i, c in ipairs(coalitions) do
            local testCoalition = Coalition.Resolve(c)
            if not testCoalition then
                error("DCAF.Location:GetClosestUnit :: cannot resolve coalition #" .. Dump(i) .. "; from: " .. DumpPretty(c)) end

            table.insert(cList, testCoalition)
        end
        if #cList > 1 then
            coalitions = cList
            isMultipleCoalitions = true
        else
            coalitions = cList[1]
        end
    else
        local testCoalition = Coalition.Resolve(coalitions)
        if not testCoalition then
            error("DCAF.Location:GetClosestUnit :: cannot resolve coalition from: " .. DumpPretty(coalitions)) end

        coalitions = testCoalition
    end

    local closest = DCAF.ClosestUnits:New()
    local units = self.Coordinate:ScanUnits(maxDistance)
    local function isCoalition(unitCoalition)

-- Debug("DCAF.Location:GetClosestUnits :: unitCoalition: " .. DumpPretty(unitCoalition))

        if not isMultipleCoalitions then
            return unitCoalition == coalitions
        end
        for _, testCoalition in ipairs(coalitions) do
            if testCoalition == unitCoalition then
                return true
            end
        end
    end
    local hasFilterFunc = isFunction(filterFunc)
    units:ForEachUnit(function(u)

-- Debug("DCAF.Location:GetClosestUnits :: unit: " .. DumpPretty(u.UnitName))

        if not u:IsAlive() then
            return end

        local unitCoalition = Coalition.Resolve(u:GetCoalition())
        if not isCoalition(unitCoalition) then
-- Debug("DCAF.Location:GetClosestUnits :: unit: " .. DumpPretty(u.UnitName) .. " is not filtered coalition")
            return end

        local distance 
        if isShapeCylinder == true then
            distance = self.Coordinate:Get2DDistance(u:GetCoordinate())
        else
            distance = self.Coordinate:Get3DDistance(u:GetCoordinate())
        end
        if not hasFilterFunc or filterFunc(u, distance) then
            local info = closest:Get(unitCoalition)
            if not info or info.Distance > distance then
-- Debug("DCAF.Location:GetClosestUnits_ForEachUnit :: sets closest: " .. DumpPretty(u.UnitName) .. " : distance: " .. Dump(distance))
                closest:Set(u, distance)
            end
        end
    end)
-- Debug("DCAF.Location:GetClosestUnits_ForEachUnit :: closest: " .. DumpPretty(closest))
    return closest
end

function DCAF.Location:ScanAirborneUnits(range, coalitions, breakOnFirst, measureSlantRange, cacheTTL, ignoreOwn)
    return ScanAirborneUnits(self, range, coalitions, breakOnFirst, measureSlantRange, cacheTTL, ignoreOwn)
end

function DCAF.Location:OnUnitTypesInRange(types, range, coalition, callbackFunc, interval)
    if not isNumber(range) then
        return Error("DCAF.Location:ScanTypesInRange :: `range` must be #number, but was: " .. DumpPretty(range))
    end
    if not isFunction(callbackFunc) then
        return Error("DCAF.Location:ScanTypesInRange :: `callbackFunc` must be #function, but was: " .. DumpPretty(callbackFunc))
    end
    if isListOfClass(types, DCAF_UnitTypeInfo) then
        local typeNames = {}
        for i, info in ipairs(types) do
            typeNames[i] = info.TypeName
        end
        types = typeNames
    end
    if isAssignedString(types) then
        types = {types}
    end
    if not isListOfAssignedStrings(types) then
        return Error("DCAF.Location:ScanTypesInRange :: `type` must be #string or list of #strings, but was: " .. DumpPretty(types))
    end

    local key = Dump(math.random(35535)) .. "_OnUnitTypesInRange"
    while self[key] do
        key = Dump(math.random(35535)) .. "_OnUnitTypesInRange"
    end

    local function filterFunc(unit, distance)
        for _, type in ipairs(types) do
            if IsUnitType(unit, type) then
                return true
            end
        end
    end

    local function filter(units)
        local result = DCAF.ClosestUnits:New()
        for _, info in ipairs(units.Units) do
            if filterFunc(info.Unit, info.Distance) then result:Set(info.Unit, info.Distance) end
        end
        return result
    end

    local isAirborneUnits = IsAirborneUnitType(types)
    local units
    if isAirborneUnits then
        units = filter(ScanAirborneUnits(self, range, coalition, false, false))
    else
        units = self:GetUnitsInRange(range, coalition, filterFunc, true)
    end
    if units and units:Any() then
        callbackFunc(units)
    end
    if not isNumber(interval) then interval = 5 end
    local monitorInfo = {
        _isTriggered = false
    }
    self[key] = monitorInfo
    monitorInfo._schedulerID = DCAF.startScheduler(function()
        if monitorInfo._isTriggered then return end
        if isAirborneUnits then
            units = filter(ScanAirborneUnits(self, range, coalition, false, false))
        else
            units = self:GetUnitsInRange(range, coalition, filterFunc, true)
        end
        if units and units:Any() then
            monitorInfo._isTriggered = true
            DCAF.stopScheduler(monitorInfo._schedulerID)
            self[key] = nil
            callbackFunc(units)
        end
    end, interval)
    return self
end

function DCAF.Location:IsCoordinate() return isCoordinate(self.Source) end
function DCAF.Location:IsVec2() return isVec2(self.Source) end
function DCAF.Location:IsVec3() return isVec3(self.Source) end
function DCAF.Location:IsZone() return isZone(self.Source) end
function DCAF.Location:IsAirbase() return isAirbase(self.Source) end
function DCAF.Location:IsGroup() return isGroup(self.Source) end
function DCAF.Location:IsUnit() return isUnit(self.Source) end

function GetClosestFriendlyUnit(source, maxDistance, ownCoalition)
    local coord
    local unit = getUnit(source)
    if unit then
        coord = unit:GetCoordinate()
    else
        local group = getGroup(source)
        if not group then
            error("GetClosestFriendlyUnit :: cannot resolve UNIT or GROUp from: " .. DumpPretty(source)) end

        coord = group:GetCoordinate()
    end
    if not isNumber(maxDistance) then
        maxDistance = NauticalMiles(50)
    end
    local ownCoalition = ownCoalition or unit:GetCoalition()
    local closestDistance = maxDistance
    local closestFriendlyUnit
    local units = coord:ScanUnits(maxDistance)
    for _, u in ipairs(units) do
        if u:GetCoalition() == ownCoalition then
            local distance = coord:Get3DDistance(u:GetCoordinate())
            if distance < closestDistance then
                closestDistance = distance
                closestFriendlyUnit = u
            end
        end
    end
    return closestFriendlyUnit, closestDistance
end

function GetBearingAndDistance(from, to)
    local dFrom = DCAF.Location.Resolve(from)
    if not dFrom then
        error("GetBearing :: cannot resolve `from`: " .. DumpPretty(from)) end

    local dTo = DCAF.Location.Resolve(to)
    if not dTo then
        error("GetBearing :: cannot resolve `to`: " .. DumpPretty(dTo)) end

    local fromCoord = dFrom:GetCoordinate()
    local toCoord = dTo:GetCoordinate()
    local distance = fromCoord:Get2DDistance(toCoord)
    return fromCoord:GetBearingTo(toCoord), distance
end

function GetBearingAndSlantRange(from, to)
    local dFrom = DCAF.Location.Resolve(from)
    if not dFrom then
        error("GetBearing :: cannot resolve `from`: " .. DumpPretty(from)) end

    local dTo = DCAF.Location.Resolve(to)
    if not dTo then
        error("GetBearing :: cannot resolve `to`: " .. DumpPretty(dTo)) end

    local fromCoord = dFrom:GetCoordinate()
    if not fromCoord then return end
    local toCoord = dTo:GetCoordinate()
    if not toCoord then return end
    local distance = fromCoord:Get3DDistance(toCoord)
    return fromCoord:GetBearingTo(toCoord), distance
end

function COORDINATE:GetHeadingTo(location)
    local d = DCAF.Location.Resolve(location)
    if d then
        return self:GetCoordinate():GetBearingTo(d:GetCoordinate()) end

    return errorOnDebug("COORDINATE:GetHeadingTo :: cannot resolve location: " .. DumpPretty(location))
end

-- returns : #COORDINATE (or nil)
function COORDINATE:ScanSurfaceType(surfaceType, startAngle, maxDistance, scanOutward, angleInterval, scanInterval)
    -- surfaceTye = land.SurfaceType (numeric: LAND=1, SHALLOW_WATER=2, WATER=3, ROAD=4, RUNWAY=5)
    if not isNumber(surfaceType) then
        error("COORDINATE:GetClosesSurfaceType :: `surfaceType` must be #number, but was: " .. DumpPretty(surfaceType)) end

    local testSurfaceType = self:GetSurfaceType()
    if surfaceType == testSurfaceType then
        return self end

    if not isNumber(maxDistance) then
        maxDistance = 500
    end
    if not isBoolean(scanOutward) then
        scanOutward = false
    end
    if not isNumber(angleInterval) then
        angleInterval = 10
    end
    if not isNumber(scanInterval) then
        scanInterval = 10
    end
    if not isNumber(startAngle) then
        startAngle = math.random(360)
    end
    local distanceStart
    local distanceEnd
    if scanOutward then
        distanceStart = scanInterval
        distanceEnd = maxDistance
    else
        distanceStart = maxDistance
        scanInterval = -math.abs(scanInterval)
        distanceEnd = scanInterval
    end
    for angle = startAngle, (startAngle-1) % 360, angleInterval do
        for distance = distanceStart, distanceEnd, scanInterval do
            local coordTest = self:Translate(distance, angle)
            testSurfaceType = coordTest:GetSurfaceType()
            if surfaceType == testSurfaceType then
                return coordTest
            end
        end
    end
end

function IsHeadingFor( source, target, maxDistance, tolerance )
    if source == nil then
        error("IsHeadingFor :: source not specified")
        return
    end
    if target == nil then
        error("IsHeadingFor :: target not specified")
        return
    end

    local sourceCoordinate = nil
    local sourceUnit = getUnit(source)
    if sourceUnit == nil then
        local g = getGroup(source)
        if g == nil then
            error("IsHeadingFor :: source unit could not be resolved from " .. Dump(source))
            return
        end
        sourceUnit = g:GetUnit(1)
    end
    sourceCoordinate = sourceUnit:GetCoordinate()

    local targetCoordinate = nil
    local targetUnit = getUnit(target)
    if targetUnit == nil then
        local g = getGroup(target)
        if g == nil then
            error("IsHeadingFor :: target coordinate could not be resolved from " .. Dump(target))
            return
        end
        targetCoordinate = g:GetCoordinate()
    else
        targetCoordinate = targetUnit:GetCoordinate()
    end

    if maxDistance ~= nil then
        local distance = sourceCoordinate:Get2DDistance(targetCoordinate)
        if distance > maxDistance then
            return flase end
    end

    if not isNumber(tolerance) then tolerance = 1 end

    local dirVec3 = sourceCoordinate:GetDirectionVec3( targetCoordinate )
    local angleRadians = sourceCoordinate:GetAngleRadians( dirVec3 )
    local bearing = UTILS.Round( UTILS.ToDegree( angleRadians ), 0 )
    local minHeading = bearing - tolerance % 360
    local maxHeading = bearing + tolerance % 360
    local heading = sourceUnit:GetHeading()
    return heading <= maxHeading and heading >= minHeading
end

local function isEscortingFromTask( escortGroup, clientGroup )
    -- determines whether a group is tasked with escorting a 'client' group ...
    -- TODO the below logic only find out if there's a task somewhere in the group's route that escorts the source group. See if we can figure out whether it's a _current_ task
    local route = escortGroup:GetTaskRoute()

    for k,wp in pairs(route) do
        local tasks = wp.task.params.tasks
        if tasks then
            for _, task in ipairs(tasks) do
                if (task.id == ENUMS.MissionTask.ESCORT and task.params.groupId == clientGroup:GetID()) then
                    return true
                end
            end
        end
    end
end

--- Retrieves the textual form of MOOSE's
function CALLSIGN.Tanker:ToString(callsign, number)
    local name
    if isNumber(callsign) then
        if     callsign == CALLSIGN.Tanker.Arco then name = "Arco"
        elseif callsign == CALLSIGN.Tanker.Shell then name = "Shell"
        elseif callsign == CALLSIGN.Tanker.Texaco then name = "Texaco"
        end
    elseif isAssignedString(callsign) then
        name = callsign
    end
    if isNumber(number) then
        return name .. " " .. tostring(number)
    else
        return name
    end
end

function CALLSIGN.Tanker:FromString(sCallsign)
    if     sCallsign == "Arco" then return CALLSIGN.Tanker.Arco
    elseif sCallsign == "Shell" then return CALLSIGN.Tanker.Shell
    elseif sCallsign == "Texaco" then return CALLSIGN.Tanker.Texaco
    end
end

function CALLSIGN.AWACS:ToString(nCallsign, number)
    local name
    if     nCallsign == CALLSIGN.AWACS.Darkstar then name = "Darkstar"
    elseif nCallsign == CALLSIGN.AWACS.Focus then name = "Focus"
    elseif nCallsign == CALLSIGN.AWACS.Magic then name = "Magic"
    elseif nCallsign == CALLSIGN.AWACS.Overlord then name = "Overlord"
    elseif nCallsign == CALLSIGN.AWACS.Wizard then name = "Wizard"
    end
    if isNumber(number) then
        return name .. " " .. tostring(number)
    else
        return name
    end
end

function CALLSIGN.AWACS:FromString(sCallsign)
    if     sCallsign == "Darkstar" then return CALLSIGN.AWACS.Darkstar
    elseif sCallsign == "Focus" then return CALLSIGN.AWACS.Focus
    elseif sCallsign == "Magic" then return CALLSIGN.AWACS.Magic
    elseif sCallsign == "Overlord" then return CALLSIGN.AWACS.Overlord
    elseif sCallsign == "Wizard" then return CALLSIGN.AWACS.Wizard
    end
end

function GetTwoLetterCallsign(name)
    local len = string.len(name)
    if isAssignedString(name) and len >= 2 then
        return string.sub(name, 1, 1) .. string.sub(name, len)
    end
end

-- getEscortingGroup :: Resolves one or more GROUPs that is escorting a specified (arbitrary) source
-- @param source

function GetEscortingGroups( source, subjectiveOnly )
    if (subjectiveOnly == nil) then
        subjectiveOnly = false
    end
    local group = getGroup(source)
    if not group then
        return exitWarning("GetEscortingGroups :: cannot resolve group from " .. Dump(source))
    end

    local zone = ZONE_GROUP:New(group.GroupName.."-escorts", group, NauticalMiles(5))
    local nearbyGroups = SET_GROUP:New()
    if (group:IsAirPlane()) then
        nearbyGroups:FilterCategoryAirplane()
    end
    if (group:IsHelicopter()) then
        nearbyGroups:FilterCategoryHelicopter()
    end
    nearbyGroups
        :FilterZones({ zone })
        :FilterCoalitions({ string.lower( group:GetCoalitionName() ) })
        :FilterActive()
        :FilterOnce()

    local escortingGroups = {}

    nearbyGroups:ForEach(
        function(g)

            if g == group or not g:IsAlive() or not isSubjectivelySameGroup( g, group ) then
                return
            end

            if subjectiveOnly or isEscortingFromTask( g, group ) then
                table.insert(escortingGroups, g)
            end
        end)

    return escortingGroups
end

function IsEscorted( source, subjectiveOnly )

    local escorts = GetEscortingGroups( source, subjectiveOnly )
    return #escorts > 0

end

function GetEscortClientGroup( source, maxDistance, resolveSubjective )

    if (maxDistance == nil) then
        maxDistance = NauticalMiles(1.5)
    end
    if (resolveSubjective == nil) then
        resolveSubjective = false
    end
    local group = getGroup(source)
    if not group then
        return exitWarning("GetEscortClientGroup :: cannot resolve group from " .. Dump(source))
    end

    local zone = ZONE_GROUP:New(group.GroupName.."-escorts", group, maxDistance)
    local nearbyGroups = SET_GROUP:New()
    if (group:IsAirPlane()) then
        nearbyGroups:FilterCategoryAirplane()
    end
    if (group:IsHelicopter()) then
        nearbyGroups:FilterCategoryHelicopter()
    end
    nearbyGroups:FilterZones({ zone }):FilterActive():FilterOnce()

    local escortedGroup = {}
    local clientGroup = nil

    nearbyGroups:ForEachGroupAlive(
        function(g)

            if clientGroup or g == group then return end -- client group was alrady resolved

            if not isSubjectivelySameGroup( group, g ) then
                return
            end

            if resolveSubjective or isEscortingFromTask( group, g ) then
                clientGroup = g
                return
            end
        end)
    return clientGroup

end

function GetOtherCoalitions( source, excludeNeutral )
    local c
    if isAssignedString(source) then
        local group = getGroup( source )
        if group then
            c = Coalition.Resolve(group:GetCoalition())
        else
            c = Coalition.Resolve(source)
        end
    elseif isGroup(source) then
        c = Coalition.Resolve(source:GetCoalition())
    else
        c = Coalition.Resolve(source)
    end
    if (c == nil) then
        return exitWarning("GetOtherCoalitions :: cannot resolve coalition from: " .. DumpPretty(source))
    end

    if excludeNeutral == nil then
        excludeNeutral = false end

    if c == Coalition.Red or c == coalition.side.RED then
        if excludeNeutral then
            return { Coalition.Blue } end
        return { Coalition.Blue, Coalition.Neutral }
    elseif c == Coalition.Blue or c == coalition.side.BLUE then
        if excludeNeutral then
            return { Coalition.Red } end
        return { Coalition.Red, Coalition.Neutral }
    elseif c == Coalition.Neutral or c == coalition.side.NEUTRAL then
        return { Coalition.Red, Coalition.Blue }
    end
end

function GetHostileCoalition(source)
    return GetOtherCoalitions(source, true)[1]
end

--[[
Compares two groups and returns a numeric value to reflect their relative strength/superiority

Parameters
    a :: first group
    b :: second group

Returns
    Zero (0) if groups are considered equal in strength
    A negative value if group a is considered superior to group b
    A positive value if group b is considered superior to group a
]]--
function GetGroupSuperiority( a, b, aSize, aMissiles, bSize, bMissiles )
    local aGroup = getGroup(a)
    local bGroup = getGroup(b)
    if (aGroup == nil) then
        if (bGroup == nil) then return 0 end
        return 1
    end

    if (bGroup == nil) then
        return -1
    end

    -- todo consider more interesting ways to compare groups relative superiority/inferiority
    local aSize = aSize or aGroup:CountAliveUnits()
    local bSize = bSize or bGroup:CountAliveUnits()
    if (aSize > bSize) then return -1 end

    -- b is equal or greater in size; compare missiles loadout ...
    if aMissiles == nil then
        local _, _, _, _, countMissiles = aGroup:GetAmmunition()
        aMissiles = countMissiles
    end
    if bMissiles == nil then
        local _, _, _, _, countMissiles = bGroup:GetAmmunition()
        bMissiles = countMissiles
    end
    -- todo Would be great to check type of missiles here, depending on groups' distance from each other
    local missileRatio = (aMissiles / aSize) / (bMissiles / bSize)
-- Debug("GetGroupSuperiority-"..aGroup.GroupName.." / "..bGroup.GroupName.." :: " .. string.format("size: %d / %d :: missiles: %d / %d", aSize, bSize, aMissiles, bMissiles)) -- nisse
-- Debug("GetGroupSuperiority-"..aGroup.GroupName.." / "..bGroup.GroupName.." :: missileRatio: "..tostring(missileRatio)) -- nisse
    if (aSize < bSize) then
        if missileRatio > 2 then
            -- A is smaller than B but a is strongly superior in armament ...
            return -1
        end
        if (missileRatio > 1.5) then
            -- A is smaller than B but a is slightly superior in armament ...
            return 0
        end
        return 1
    end
    return 0
end

NoMessage = "_none_"

DebugAudioMessageToAll = false -- set to true to debug audio messages

--local ignoreMessagingGroups = {}
--[[
Sends a simple message to groups, clients or lists of groups or clients
]]--
function MessageTo(recipient, message, duration)
    if (message == nil) then
        return Warning("MessageTo :: Message was not specified") end

    duration = duration or 5

    local RECIPIENT_SCOPE = {
        All = "all",
        Unit = "unit",
        Group = "group",
        Coalition = "coalition",
        List = "list"
    }
    local recipientScope
    local dcafCoalition
    local dcsCoalition

    local function resolveRecipient()
        if not recipient then
            recipientScope = RECIPIENT_SCOPE.All
            return true
        end

        local unit = getUnit(recipient)
        if unit then
            recipientScope = RECIPIENT_SCOPE.Unit
            return unit
        end

        local group = getGroup(recipient)
        if group then
            recipientScope = RECIPIENT_SCOPE.Group
            return group end
            
        dcafCoalition = Coalition.Resolve(recipient)
        if dcafCoalition then
            recipientScope = RECIPIENT_SCOPE.Coalition
            dcsCoalition = Coalition.ToNumber(dcafCoalition)
            return dcafCoalition
        end

        if isList(recipient) then
            recipientScope = RECIPIENT_SCOPE.List
            return recipient
        end
    end

    local validRecipient = resolveRecipient()
    if not validRecipient then
        return exitWarning("MessageTo-?".. Dump(recipient) .. " :: recipient could not be resolved") end

    local output
    local trace = "MessageTo"
    if recipientScope == RECIPIENT_SCOPE.List then
        for _, r in pairs(recipient) do
            MessageTo( r, message, duration )
        end
        return
    end

    if (string.match(message, ".%.ogg") or string.match(message, ".%.wav")) then
Debug("nisse - MessageTo :: sound: " .. message)
        trace = trace .. " (audio)"
        output = USERSOUND:New(message)
    else
Debug("nisse - MessageTo :: message: " .. message)
        output = MESSAGE:New(message, duration)
    end
    if recipientScope == RECIPIENT_SCOPE.All then
        trace = trace .. " :: (all)"
        output:ToAll()
    elseif recipientScope == RECIPIENT_SCOPE.Coalition then
        trace = trace .. " :: (coalition: " .. dcafCoalition .. ")"
        output:ToCoalition(dcsCoalition)
    elseif recipientScope == RECIPIENT_SCOPE.Group then
        trace = trace .. " :: (group: " .. validRecipient.GroupName .. ")"
        output:ToGroup(validRecipient)
    elseif recipientScope == RECIPIENT_SCOPE.Unit then
        trace = trace .. " :: (unit: " .. validRecipient.UnitName .. ")"
        output:ToUnit(validRecipient)
    end
end

function DebugMessageTo(recipient, message, duration)
    if not DCAF.Debug then
        return end
        
    if string.find(message, ".ogg") then
        return MessageTo(recipient, message)
    end
    return MessageTo(recipient, "DBG //" .. message, duration)
end

local function SendMessageToClient( recipient )
    local unit = CLIENT:FindByName( recipient )
    if (unit ~= nil) then
        Trace("MessageTo-"..recipient.." :: "..message)
        MESSAGE:New(message, duration):ToClient(unit)
        return
    end

    if (pcall(SendMessageToClient(recipient))) then
        return end

    Warning("MessageTo-"..recipient.." :: Recipient not found")
end

function SetFlag( name, value, menuKey )
    value = value or true
    trigger.action.setUserFlag(name, value)
    Trace("SetFlag :: "..name.." :: " .. DumpPretty(value))
end

function GetFlag( name )
    return trigger.misc.getUserFlag( name )
end

function IncreaseFlag( name, increment )
    if not isNumber(increment) then increment = 1 end
    local value = GetFlag(name)
    value = (value or 0) + increment
    trigger.action.setUserFlag(name, value)
    Trace("IncrementFlag :: '"..name.."' :: value: ".. value)
end

function GetGroupTemplateName(group)
    local s = group.GroupName
    local c = string.sub(s, string.len(s))
    local isDigit = isStringNumber(c)
    if not isDigit then return s end
    local len = string.len(s)
    for i = len-1, 1, -1 do
        c = string.sub(s, i, i)
        if c == '#' then
            s = string.sub(s, 1, i-1)
            return s
        end
        isDigit = isStringNumber(c)
        if not isDigit then return s end
    end
end

function GetCallsign(source)
    local includeUnitNumber = false
    local unit = getUnit(source)
    if unit then
        includeUnitNumber = true
    else
        local group = getGroup(source)
        if not group then
            error("GetCallsign :: cannot resolve unit or group from " .. DumpPretty(source)) end

        unit = group:GetUnit(1)
    end

    local callsign = unit:GetCallsign()
    local name
    local number
    local sNumber = string.match(callsign, "%d+")
    if sNumber then
        local numberAt = string.find(callsign, sNumber)
        name = string.sub(callsign, 1, numberAt-1)
        if not includeUnitNumber then
            return name, tonumber(sNumber) end

        local sUnitNumber = string.sub(callsign, numberAt)
        local dashAt = string.find(sNumber, ".-.")
        if dashAt then
            sUnitNumber = string.sub(sUnitNumber, dashAt+1)
            sUnitNumber = string.match(sUnitNumber, "%d+")
            return name, tonumber(sNumber), tonumber(sUnitNumber)
        end
    end
    return callsign
end

function GetGroupOrUnitName(source, mooseSuffixPattern)
    mooseSuffixPattern = mooseSuffixPattern or "#%d%d%d"
    if isAssignedString(source) then
        local suffixAt = string.find(source, mooseSuffixPattern)
        if not suffixAt then
            return source end

        return string.sub(source, 1, suffixAt-1)
    end
    local unit = getUnit(source)
    if unit then
        return GetGroupOrUnitName(unit.UnitName) end

    local group = getGroup(source)
    if group then
        return GetGroupOrUnitName(group.GroupName) end
end

function GetGroupType(group)
    local validGroup = getGroup(group)
    if not validGroup then return Error("GetGroupType :: cannot resolve `group`: " .. DumpPretty(group)) end
    
end

function IsTankerCallsign(controllable, ...)
    local group = getGroup(controllable)
    if not group then
        return false end

    local groupCallsign, number = GetCallsign(group)
    local tankerCallsign = CALLSIGN.Tanker:FromString(groupCallsign)
    if not tankerCallsign then
        return end

    if #arg == 0 then
        return tankerCallsign, number
    end

    for i = 1, #arg, 1 do
       if tankerCallsign == arg[i] then
          return tankerCallsign, number
       end
    end
 end

 function IsAWACSCallsign(controllable, ...)
    local group = getGroup(controllable)
    if not group then
        return false end

    local groupCallsign, number = GetCallsign(group)
    local awacsCallsign = CALLSIGN.AWACS:FromString(groupCallsign)
    if not awacsCallsign then
        return end

    if #arg == 0 then
        return awacsCallsign, number
    end

    for i = 1, #arg, 1 do
       if awacsCallsign == arg[i] then
          return awacsCallsign, number
       end
    end
    -- local callsign = CALLSIGN.AWACS:FromString(GetCallsign(group))
    -- for i = 1, #arg, 1 do
    --    if callsign == arg[i] then
    --       return true
    --    end
    -- end
 end

 function IsAirService(controllable, ...)
    return IsTankerCallsign(controllable, ...) or IsAWACSCallsign(controllable, ...)
 end

function GetRTBAirbaseFromRoute(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("GetRTBAirbaseFromRoute :: could not resolve group from " .. DumpPretty(group)) end

    local homeBase
    local route = forGroup:CopyRoute()
    local lastWp = route[#route]
    if lastWp.airdromeId then
        homeBase = AIRBASE:FindByID(lastWp.airdromeId)
    else
        local wp0 = route[1]
        if wp0.airdromeId then
            homeBase = AIRBASE:FindByID(wp0.airdromeId)
        else
            local coord = forGroup:GetCoordinate()
            homeBase = coord:GetClosestAirbase(Airbase.Category.AIRDROME, forGroup:GetCoalition())
        end
    end
    return homeBase
end

function GetUnitFromGroupName( groupName, unitNumber )
    unitNumber = unitNumber or 1
    local group = GROUP:FindByName( groupName )
    if (group == nil) then return nil end
    return group.GetUnit( unitNumber )
end

--- Resolves a location's coordinates and then removes the location (if #GROUP, #UNIT, or #STATIC)
-- @param Any location - any valid source for a location (see DCAF.Location.Resolve)
-- @param bool destroySource - (optional, default=false) When set, the operation removed the source after resolving coordinate (if #GROUP, #UNIT, or #STATIC)
function GetCoordinate(location, destroySource)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error("GetCoordinateThenDestroy :: cound not resolve `source`: " .. DumpPretty(location)) end
    local coordinate = validLocation:GetCoordinate()
    if not destroySource then return coordinate end
    local source = validLocation.Source
    if isGroup(source) or isUnit(source) or isStatic(source) then
        source:Destroy()
    end
    return coordinate
end

--- Resolves a location's coordinates and then removes the location (if #GROUP, #UNIT, or #STATIC)
-- @param Any location - any valid source for a location (see DCAF.Location.Resolve)
function GetCoordinateThenDestroy(location)
    return GetCoordinate(location, true)
end

function EstimatedDistance( feet )
    if (not isNumber(feet)) then error( "<feet> must be a number" ) end

    local f = nil
    if (feet < 10) then return feet end
    if (feet < 100) then
      -- nearest 10 ...
      return UTILS.Round(feet / 10) * 10

    elseif (feet < 1000) then f = 100
    elseif (feet < 10000) then f = 1000
    elseif (feet < 100000) then f = 10000
    elseif (feet < 1000000) then f = 100000 end
    local calc = feet / f + 1
    calc = UTILS.Round(calc * 2, 0) / 2 - 1
    return calc * f
end

function DistanceToStringA2A( meters, estimated )
    if (not isNumber(meters)) then error( "<meters> must be a number" ) end
    local feet = UTILS.MetersToFeet( meters )
    if (feet < FeetPerNauticalMile / 2) then
        if (estimated or false) then
        feet = EstimatedDistance( feet )
        end
        return tostring( math.modf(feet) ) .. " feet"
    end
    local nm = UTILS.Round( feet / FeetPerNauticalMile, 1)
    if (estimated) then
        -- round nm to nearest 0.5
        nm = UTILS.Round(nm * 2) / 2
    end
    if (nm < 2) then
        return tostring( nm ) .. " mile"
    end
        return tostring( nm ) .. " miles"
end

function GetAltitudeAsAngelsOrCherubs( value )
    local feet
    if isTable(value) and value.ClassName == "COORDINATE" then
        feet = UTILS.MetersToFeet( value.y )
    elseif isNumber( value ) then
        feet = UTILS.MetersToFeet( value )
    elseif isAssignedString( value ) then
        feet = UTILS.MetersToFeet( tonumber(value) )
    else
        error("GetAltitudeAsAngelsOrCherubs :: unexpected value: " .. DumpPretty(value) )
    end
    if (feet >= 1000) then
        local angels = feet / 1000
        return "angels " .. tostring(UTILS.Round( angels, 0 ))
    end

    local cherubs = feet / 100
    return "cherubs " .. tostring(UTILS.Round( cherubs, 0 ))
end

function GetRelativeDirection(heading, bearing)
        local rd = bearing - heading -- rd = relative direction
    if rd < -180 then
        return rd + 360
    elseif rd > 180 then
        return rd - 360
    end
    return rd
end

--- Returns an object with three values to describe the relative position between two locations
function GetRelativePosition(source, target)
    local sourceLocation = DCAF.Location.Resolve(source)
    local targetLocation = DCAF.Location.Resolve(target)
    if not sourceLocation then
        return Error("GetRelativeDirectionAndDistance :: cannot resolve `source`: " .. DumpPretty(source)) end
    if not targetLocation then
        return Error("GetRelativeDirectionAndDistance :: cannot resolve `target`: " .. DumpPretty(target)) end

    local heading = sourceLocation:GetHeading()
    local bearing, slantRange = GetBearingAndSlantRange(source, target)
    local rd = GetRelativeDirection(heading, bearing)
    local sourceCoordinate = sourceLocation:GetCoordinate()
    local targetCoordinate = targetLocation:GetCoordinate()
    return {
        Direction = rd,
        SlantRange = slantRange,
        VerticalDiff = sourceCoordinate.y - targetCoordinate.y
    }
end

-- GetRelativeLocation :: Produces information to represent the subjective, relative, location between two locations
-- @param sourceCoordinate :: The subject location
-- @param targetLocation :: The 'other' location
-- @returns object ::
--    {
--      Bearing :: The bearing from source to target
--      Distance :: The distance between source and target
--      TextDistance :: Textual distance between source and target
--      TextPosition :: Textual (o'clock) position of target, relative to source
--      TextLevel :: Textual, relative (high, level or low), vertical position of target relative to source
--      TextAngels :: Textual altitude in angels or sherubs
--      ToString() :: function; Returns standardized textual relative location, including all of the above
--    }
function GetRelativeLocation( source, target )
    local sourceLocation = DCAF.Location.Resolve(source)
    if not sourceLocation then
        return exitWarning("GetRelativeLocation :: cannot resolve source location from " .. Dump(source)) end

    local targetLocation = DCAF.Location.Resolve(target)
    if not targetLocation then
        return exitWarning("GetRelativeLocation :: cannot resolve target location from " .. Dump(target)) end

    -- local sourceGroup = getGroup(source)
    -- if not sourceGroup then
    --     return exitWarning("GetRelativeLocation :: cannot resolve source group from " .. Dump(source))
    -- end
    -- local targetGroup = getGroup(target)
    -- if not targetGroup then
    --     return exitWarning("GetRelativeLocation :: cannot resolve target group from " .. Dump(target))
    -- end

    local sourceCoordinate = sourceLocation:GetCoordinate()
    local targetCoordinate = targetLocation:GetCoordinate()

    -- bearing
    local dirVec3 = sourceCoordinate:GetDirectionVec3( targetCoordinate )
    local angleRadians = sourceCoordinate:GetAngleRadians( dirVec3 )
    local bearing = UTILS.Round( UTILS.ToDegree( angleRadians ), 0 )
    local heading = sourceCoordinate:GetHeading() -- sourceGroup:GetUnit(1):GetHeading()

    --  o'clock position
    local sPosition = GetClockPosition( heading, bearing )

    -- distance
    local distance = sourceCoordinate:Get2DDistance(targetCoordinate)
    local sDistance = DistanceToStringA2A( distance, true )

    -- level position
    local sLevelPos = GetLevelPosition( sourceCoordinate, targetCoordinate )

    -- angels
    local sAngels = GetAltitudeAsAngelsOrCherubs( targetCoordinate )

    return {
        Bearing = bearing,
        Distance = distance,
        TextDistance = sDistance,
        TextPosition = sPosition,
        TextLevel = sLevelPos,
        TextAngels = sAngels,
        ToString = function()
            return string.format( "%s %s for %s, %s", sPosition, sLevelPos, sDistance, sAngels )
        end
    }
end

local _numbers = {
    [1] = "one",
    [2] = "two",
    [3] = "three",
    [4] = "four",
    [5] = "five",
    [6] = "six",
    [7] = "seven",
    [8] = "eight",
    [9] = "nine",
    [10] = "ten",
    [11] = "eleven",
    [12] = "twelve"
}
   
local _clockPositions = {
     [0] = { Text = _numbers[12], Value = 12 },
     [1] = { Text = _numbers[1],  Value = 1 },
     [2] = { Text = _numbers[1],  Value = 1 },
     [3] = { Text = _numbers[2],  Value = 2 },
     [4] = { Text = _numbers[2],  Value = 2 },
     [5] = { Text = _numbers[2],  Value = 3 },
     [6] = { Text = _numbers[2],  Value = 3 },
     [7] = { Text = _numbers[4],  Value = 4 },
     [8] = { Text = _numbers[4],  Value = 4 },
     [9] = { Text = _numbers[5],  Value = 5 },
    [10] = { Text = _numbers[5],  Value = 5 },
    [11] = { Text = _numbers[6],  Value = 6 },
    [12] = { Text = _numbers[6],  Value = 6 },
    [13] = { Text = _numbers[7],  Value = 7 },
    [14] = { Text = _numbers[7],  Value = 7 },
    [15] = { Text = _numbers[8],  Value = 8 },
    [16] = { Text = _numbers[8],  Value = 8 },
    [17] = { Text = _numbers[9],  Value = 9 },
    [18] = { Text = _numbers[9],  Value = 9 },
    [19] = { Text = _numbers[10], Value = 10 },
    [20] = { Text = _numbers[10], Value = 10 },
    [21] = { Text = _numbers[11], Value = 11 },
    [22] = { Text = _numbers[11], Value = 11 },
    [23] = { Text = _numbers[12], Value = 12 },
}

math.round = function(num)
    local floor = math.floor(num)
    local ceil = math.ceil(num)
    if num - floor < ceil - num then
        return floor
    else
        return ceil
    end
end

function GetClockPosition( heading, bearing )
    local pos
    if not isNumber(heading) then
        heading = 0
    end
    local brg = ((bearing + heading) % 360) / 15
    pos = math.floor(brg)
    return _clockPositions[pos].Value, _clockPositions[pos].Text .. " o'clock"
end

function GetLevelPosition( coord1, coord2 )
    local vDiff = coord1.y - coord2.y -- vertical difference
    local lDiff = math.max(math.abs(coord1.x - coord2.x), math.abs(coord1.z - coord2.z)) -- lateral distance
    local angle = math.deg(math.atan(vDiff / lDiff))

    if (math.abs(angle) <= 15) then
      return "level"
    end

    if (angle < 0) then
      return "high"
    end

    return "low"
end

function GetMSL( controllable )
    local group = getGroup( controllable )
    if (group == nil) then
        return exitWarning("GetMSL :: cannot resolve group from "..Dump(controllable), false)
    end

    return UTILS.MetersToFeet( group:GetCoordinate().y )
end

function GetFlightLevel( controllable )
    local msl = GetMSL(controllable)
    return UTILS.Round(msl / 100, 0)
end

function GetAGL( source )
    -- local location = DCAF.Location:New(source)
    if isClass(source, DCAF.Location.ClassName) then
        coord = source.Coordinate
    else
        local unit = getUnit(source)
        if unit then
            return unit:GetAltitude(true)
        end
        local group = getGroup( source )
        if (group == nil) then
            return exitWarning("GetAGL :: cannot resolve group from "..Dump(source), false)
        end
        coord = group:GetCoordinate()
    end
    return coord.y - coord:GetLandHeight()
end

function IsGroupAirborne( controllable, tolerance )
    tolerance = tolerance or 10
    local agl = GetAGL(controllable)
    return agl > tolerance
end

local _navyAircrafts = {
    ["FA-18C_hornet"] = 1,
    ["F-14A-135-GR"] = 2,
    ["AV8BNA"] = 3,
    ["SH-60B"] = 4
}

function IsNavyAircraft( source )
    if isUnit(source) then
        source = source:GetTypeName()
    elseif isTable(source) then
        -- assume event
        source = source.IniUnitTypeName
        if not source then
            return false end
    end
    if isString(source) then
        return _navyAircrafts[source] ~= nil end

    return false
end

--------------------------------------------- [[ ROUTING ]] ---------------------------------------------


--[[
Gets the index of a named waypoint and returns a table containing it and its internal route index

Parameters
  source :: An arbitrary source. This can be a route, group, unit, or the name of group/unit
  name :: The name of the waypoint to look for

Returns
  On success, an object; otherwise nil
  (object)
  {
    waypoint :: The requested waypoint object
    index :: The waypoints internal route index0
  }
]]--
function FindWaypointByName( source, name )
    local route = nil
    if isTable(source) and source.ClassName == nil then
        -- assume route ...
        route = source
    end

    if route == nil then
        -- try get route from group ...
        local group = getGroup( source )
        if ( group ~= nil ) then
            route = group:CopyRoute()
        else
            return nil end
    end

    for k,v in pairs(route) do
        if (v["name"] == name) then
        return { data = v, index = k }
        end
    end
    return nil
end

function FindWaypointByPattern( source, pattern )
    local route = nil
    if isTable(source) and source.ClassName == nil then
        -- assume route ...
        route = source
    end

    if route == nil then
        -- try get route from group ...
        local group = getGroup( source )
        if ( group ~= nil ) then
            route = group:CopyRoute()
        else
            return nil end
    end

    for k, wp in pairs(route) do
        if wp.name and string.find(wp.name, pattern) then
            return { data = wp, index = k }
        end
    end
    return nil
end

function FindWaypointsByName( source, ... )
    local route = nil
    if isTable(source) and source.ClassName == nil then
        -- assume route ...
        route = source
    end

    if route == nil then
        -- try get route from group ...
        local group = getGroup( source )
        if ( group ~= nil ) then
            route = group:CopyRoute()
        else
            return nil
        end
    end

    local result = {}
    for _, name in ipairs(arg) do
        local info = FindWaypointByName( source, name )
        if info then
            result[#result+1] = info
        end
    end
    return result
end

--- Returns estimated total time needed to execute a route
-- @param #table Two or more waypoints
-- @param #number (optional) A start coordinate (assuming time is required to reach 1st waypoint)
-- @return #number Estimated total time (seconds) to fly/drive the route
function CalculateRouteTime(waypoints, startCoordinate)
    local time = 0
    local wpStart = waypoints[1]
    local coordPrev = COORDINATE_FromWaypoint(wpStart)
    if isCoordinate(startCoordinate) then
        local distance = coordPrev:Get2DDistance(startCoordinate)
        local speed = wpStart.speed
        local timeLeg = distance / speed;
        time = time + timeLeg
    end
    if #waypoints < 2 then
        return time
    end
    for i = 2, #waypoints, 1 do
        local wp = waypoints[i]
        local coord = COORDINATE_FromWaypoint(wp)
        local distance = coordPrev:Get2DDistance(coord)
        local speed = wp.speed
        local timeLeg = distance / speed;
        time = time + timeLeg
        coordPrev = coord
    end
    return time
end

--- Returns estimated time of arrival, assuming a route is started at a specified time
-- @param #table Two or more waypoints
-- @param #number (optional) A start coordinate (assuming time is required to reach 1st waypoint)
-- @param #number (optional) A start time. Default = current mission time (see: UTILS.SecondsOfToday())
-- @return #number Estimated time, specified as seconds since midnight
-- @return #string Estimated time in format Hours:Minutes:Seconds+Days (HH:MM:SS+D).
function CalculateRouteETA( waypoints, startCoordinate, startTime )
    if not isNumber(startTime) then
        startTime = UTILS.SecondsOfToday()
    end
    local eta = startTime + CalculateRouteTime(waypoints, startCoordinate)
    return eta, UTILS.SecondsToClock(eta)
end

--- Returns estimated total time needed to execute a route
-- @param #table Two or more waypoints
-- @return #number Estimated total time (seconds) to fly/drive the route
function COORDINATE:CalculateRouteTime(waypoints)
    return CalculateRouteTime(waypoints, self)
end

--- Returns estimated time of arrival, assuming a route is started at a specified time
-- @param #table Two or more waypoints
-- @param #number (optional) A start time. Default = current mission time (see: UTILS.SecondsOfToday())
-- @return #number Estimated time, specified as seconds since midnight
-- @return #string Estimated time in format Hours:Minutes:Seconds+Days (HH:MM:SS+D).
function COORDINATE:CalculateRouteETA(waypoints, startTime)
    return CalculateRouteETA(waypoints, self, startTime)
end

local function calcGroupOffset( group1, group2 )

    local coord1 = group1:GetCoordinate()
    local coord2 = group2:GetCoordinate()
    return {
        x = coord1.x-coord2.x,
        y = coord1.y-coord2.y,
        z = coord1.z-coord2.z
    }

end

FollowOffsetLimits = {
    -- longitudinal offset limits
    xMin = 200,
    xMax = 1000,

    -- vertical offset limits
    yMin = 0,
    yMax = 100,

    -- latitudinal offset limits
    zMin = -30,
    zMax = -1000
}

function FollowOffsetLimits:New()
    return DCAF.clone(FollowOffsetLimits)
end

function FollowOffsetLimits:Normalize( vec3 )

    if (math.abs(vec3.x) < math.abs(self.xMin)) then
        if (vec3.x < 0) then
            vec3.x = -self.xMin
        else
            vec3.x = math.abs(self.xMin)
        end
    elseif (math.abs(vec3.x) > math.abs(self.xMax)) then
        if (vec3.x < 0) then
            vec3.x = -self.xMax
        else
            vec3.x = math.abs(self.xMax)
        end
    end

    if (math.abs(vec3.y) < math.abs(self.yMin)) then
        if (vec3.y < 0) then
            vec3.y = -self.yMin
        else
            vec3.y = math.abs(self.yMin)
        end
    elseif (math.abs(vec3.y) > math.abs(self.yMax)) then
        if (vec3.y < 0) then
            vec3.y = -self.yMax
        else
            vec3.y = math.abs(self.yMax)
        end
    end

    if (math.abs(vec3.z) < math.abs(self.zMin)) then
        vec3.z = self.zMin
    elseif (math.abs(vec3.z) > math.abs(self.zMax)) then
        vec3.z = self.xMax
    end

    return vec3
end

--[[
Follow
  Simplifies forcing a group to follow another group to a specified waypoint

Parameters
  follower :: (arbitrary) Specifies the group to be tasked with following the leader group
  leader :: (arbitrary) Specifies the group to be followed
  offset :: (Vec3) When set (individual elements can be set to force separation in that dimension) the follower will take a position, relative to the leader, offset by this value
  lastWaypoint :: (integer; default=last waypoint) When specifed the follower will stop following the leader when this waypont is reached
]]--
function TaskFollow( follower, leader, offsetLimits, lastWaypoint )

    if (follower == nil) then
        return exitWarning("Follow-? :: Follower was not specified")
    end
    local followerGrp = getGroup(follower)
    if (followerGrp == nil) then
        return exitWarning("Follow-? :: Cannot find follower: "..Dump(follower))
    end

    if (leader == nil) then
        return exitWarning("Follow-? :: Leader was not specified")
    end
    local leaderGrp = getGroup(leader)
    if (leaderGrp == nil) then
        return exitWarning("Follow-? :: Cannot find leader: "..Dump(leader))
    end

    if (lastWaypoint == nil) then
        local route = leaderGrp:CopyRoute()
        lastWaypoint = #route
    end

    local off = calcGroupOffset(leaderGrp, followerGrp)

--Debug( "TaskFollow :: off: " .. DumpPretty( off ) )

    if offsetLimits then
        off = offsetLimits:Normalize(off)
--Debug( "TaskFollow :: normalized off: " .. DumpPretty( off ) )
    end

    local task = followerGrp:TaskFollow( leaderGrp, off, lastWaypoint)
    followerGrp:SetTask( task )
    Trace("FollowGroup-"..followerGrp.GroupName.." ::  Group is now following "..leaderGrp.GroupName.." to WP #"..tostring(lastWaypoint))

end

function GetRTBWaypoint( group )
    -- TODO consider returning -true- if last WP in route is landing WP
    return FindWaypointByName( group, DCAF.WaypointNames.RTB ) ~= nil
end

function CanRTB( group )
    return GetDivertWaypoint( group ) ~= nil
end

function RTB( controllable, steerpointName )

    local steerpointName = steerpointName or DCAF.WaypointNames.RTB
    local route = RouteDirectTo(controllable, steerpointName)
    return SetRoute( controllable, route )

end

function GetDivertWaypoint( group )
    return FindWaypointByName( group, DCAF.WaypointNames.Divert ) ~= nil
end

function CanDivert( group )
    return GetDivertWaypoint( group ) ~= nil
end

local _onDivertFunc = nil

function Divert( controllable, steerpointName )
    local steerpointName = steerpointName or DCAF.WaypointNames.Divert
    local divertRoute = RouteDirectTo(controllable, steerpointName)
    local route = SetRoute( controllable, divertRoute )
    if _onDivertFunc then
        _onDivertFunc( controllable, divertRoute )
    end
    return route
end

function GotoWaypoint( controllable, from, to, offset)
    local group = nil
    if not controllable then
        return exitWarning("GotoWaypoint :: missing controllable")
    else
        group = getGroup(controllable)
        if not group then
            return exitWarning("GotoWaypoint :: cannot resolve group from "..Dump(controllable))
        end
    end
    if not from then
        return exitWarning("GotoWaypoint :: missing 'from'")
    elseif not isNumber(from) then
        return exitWarning("GotoWaypoint :: 'from' is not a number")
    end
    if not to then
        return exitWarning("GotoWaypoint :: missing 'to'")
    elseif not isNumber(to) then
        return exitWarning("GotoWaypoint :: 'to' is not a number")
    end
    if isNumber(offset) then
        from = from + offset
        to = to + offset
    end
    Trace("GotoWaypoint-" .. group.GroupName .. " :: goes direct from waypoint " .. tostring(from) .. " --> " .. tostring(to))
    local dcsCommand = {
        id = 'SwitchWaypoint',
        params = {
          fromWaypointIndex = from,
          goToWaypointIndex = to,
        },
    }
    if not group:IsAir() then
        dcsCommand.id = "GoToWaypoint"
    end
    group:SetCommand( dcsCommand )
    -- group:SetCommand(group:CommandSwitchWayPoint( from, to ))
end

function LandHere( controllable, category, coalition )

    local group = getGroup( controllable )
    if (group == nil) then
        return exitWarning("LandHere-? :: group not found: "..Dump(controllable))
    end

    category = category or Airbase.Category.AIRDROME

    local ab = group:GetCoordinate():GetClosestAirbase2( category, coalition )
    if (ab == nil) then
        return exitWarning("LandHere-"..group.GroupName.." :: no near airbase found")
    end

    local abCoord = ab:GetCoordinate()
    local landHere = {
        ["airdromeId"] = ab.AirdromeID,
        ["action"] = "Landing",
        ["alt_type"] = COORDINATE.WaypointAltType.BARO,
        ["y"] = abCoord.y,
        ["x"] = abCoord.x,
        ["alt"] = ab:GetAltitude(),
        ["type"] = "Land",
    }
    group:Route( { landHere } )
    Trace("LandHere-"..group.GroupName.." :: is tasked with landing at airbase ("..ab.AirbaseName..") :: DONE")
    return ab

end

local _onGroupLandedHandlers = { -- dictionary
    -- key = group name
    -- value = handler function
}

function OnGroupLandedEvent(group, func, bOnce)
    if not isFunction(func) then
        error("OnLandedEvent :: expected function but got: " .. DumpPretty(func)) end

    local forGroup = getGroup(group)
    if not forGroup then
        error("OnLandedEvent :: cannot resolve group from: " .. DumpPretty(group)) end

    if _onGroupLandedHandlers[forGroup.GroupName] then
        return
    else
        _onGroupLandedHandlers[group.GroupName] = func
    end

    local _onLandedFuncWrapper
    local function onLandedFuncWrapper(event)
        if event.IniGroupName ~= group.GroupName then
            return end

        func(event)
        MissionEvents:EndOnAircraftLanded(_onLandedFuncWrapper)
        _onGroupLandedHandlers[group.GroupName] = nil
    end
    _onLandedFuncWrapper = onLandedFuncWrapper
    MissionEvents:OnAircraftLanded(_onLandedFuncWrapper)
end

function DestroyOnLanding(group, delaySeconds)
    OnGroupLandedEvent(group, function(event)
        if isNumber(delaySeconds) then
            Delay(delaySeconds, function()
                group:Destroy()
            end)
        else
            group:Destroy()
        end
    end)
end

local function resolveUnitInGroup(group, nsUnit, defaultIndex)
    local unit = nil
    if isNumber(nsUnit) then
        nsUnit = math.max(1, nsUnit)
        unit = group:GetUnit(nsUnit)
    elseif isAssignedString(nsUnit) then
        local index = tableIndexOf(group:GetUnits(), function(u) return u.UnitName == nsUnit end)
        if index then
            unit = group:GetUnit(index)
        else
            return "group '" .. group.GroupName .. " have no unit with name '" .. nsUnit .. "'"
        end
    elseif isUnit(nsUnit) then
        unit = nsUnit
    end
    if unit then
        return unit
    end
    if not isNumber(defaultIndex) then
        defaultIndex = 1
    end
    return group:GetUnit(defaultIndex)
end

-- Activates TACAN beacon for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nChannel The TACAN channel (eg. 39 in 30X)
-- @param #string sModeChannel The TACAN mode ('X' or 'Y'). Optional; default = 'X'
-- @param #string sIdent The TACAN Ident (a.k.a. "callsign"). Optional
-- @param #boolean bBearing Specifies whether the beacon will provide bearing information. Optional; default = true
-- @param #boolean bAA Specifies whether the beacon is airborne. Optional; default = true for air group, otherwise false
-- @param #any nsAttachToUnit Specifies unit to attach TACAN to; either its internal index or its name. Optional; default = 1
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandActivateTACAN(group, nChannel, sModeChannel, sIdent, bBearing, bAA, nsAttachToUnit)

    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandActivateTACAN :: cannot resolve group from: " .. DumpPretty(group)) end
    if not isNumber(nChannel) then
        error("CommandActivateTACAN :: `nChannel` was unassigned/unexpected value: " .. DumpPretty(nChannel)) end
    if sModeChannel == nil or not isAssignedString(sModeChannel) then
        sModeChannel = "X"
    elseif sModeChannel ~= "X" and sModeChannel ~= "Y" then
        error("CommandActivateTACAN :: invalid `sModeChannel`: " .. Dump(sModeChannel))
    end
    local unit = resolveUnitInGroup(forGroup, nsAttachToUnit)
    if isAssignedString(unit) then
        error("CommandActivateTACAN :: " .. unit)
    end
    if not isAssignedString(sIdent) then
        sIdent = tostring(nChannel) .. sModeChannel end
    if not isBoolean(bBearing) then
        bBearing = true end

    local beacon = unit:GetBeacon()
    beacon:ActivateTACAN(nChannel, sModeChannel, sIdent, bBearing)
    local traceDetails = string.format("%d%s (%s)", nChannel, sModeChannel, sIdent or "---")
    if bAA then
        traceDetails = traceDetails .. " A-A" end
    if bBearing then
        traceDetails = traceDetails .. " with bearing information"
    else
        traceDetails = traceDetails .. " with NO bearing information"
    end
    if unit then
        traceDetails = traceDetails .. ", attached to unit: " .. unit.UnitName end
    local message = "TACAN was set for group '" .. forGroup.GroupName .. "' :: " .. traceDetails
    Trace("CommandActivateTACAN :: " .. message)
    return message
end

--- Deactivates an active beacon for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nDelay Specifies a delay (seconds) before the beacon is deactivated
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandDeactivateBeacon(group, nDelay)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandDeactivateBeacon :: cannot resolve group from: " .. DumpPretty(group)) end

    forGroup:CommandDeactivateBeacon(nDelay)

    local message = "beacon was deactivated for " .. forGroup.GroupName
    Trace("CommandDeactivateBeacon-" .. forGroup.GroupName .. " :: " .. message)
    return message
end

--- Activates ICLS beacon for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nChannel The TACAN channel (eg. 39 in 30X)
-- @param #string sIdent The TACAN Ident (a.k.a. "callsign"). Optional
-- @param #number nDuration Specifies a duration for the TACAN to be active. Optional; when not set the TACAN srtays on indefinitely
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandActivateICLS(group, nChannel, sIdent, nsAttachToUnit, nDuration)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandActivateICLS :: cannot resolve group from: " .. DumpPretty(group)) end
    if not isNumber(nChannel) then
        error("CommandActivateICLS :: `nChannel` was unassigned/unexpected value: " .. DumpPretty(nChannel)) end
    local unit = resolveUnitInGroup(forGroup, nsAttachToUnit)
    if isAssignedString(unit) then
        error("CommandActivateICLS :: " .. unit)
    end
    unit:GetBeacon():ActivateICLS(nChannel, sIdent, nDuration)
    local traceDetails = string.format("%d (%s)", nChannel, sIdent or "---")
    traceDetails = traceDetails .. ", attached to unit: " .. unit.UnitName
    local message = "ICLS was set for group '" .. forGroup.GroupName .. "' :: " .. traceDetails
    Trace("CommandActivateICLS :: " .. message)
    return message
end

--- Deactivates ICLS for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nDuration Specifies a nDelay before the ICLS is deactivated
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandDeactivateICLS(group, nDelay)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandDeactivateICLS :: cannot resolve group from: " .. DumpPretty(group)) end

    forGroup:CommandDeactivateICLS(nDelay)
    local message = "ICLS was deactivated group '" .. forGroup.GroupName
    Trace("CommandDeactivateICLS :: " .. message)
    return message
end

--- Starts or stops a group
function CommandStartStop(controllable, value)
    if not isBoolean(value) then
        error("CommandStartStop :: `value` must be boolean, but was " .. type(value)) end

    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("CommandStartStop :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    group:SetCommand({ id = 'StopRoute', params = { value = value } })
end

function CommandStart(controllable, delay, startedFunc)
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("CommandStart :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    local function start(startDelayed)
        if group:IsAir() then
            group:StartUncontrolled(startDelayed)
        else
            group:SetAIOn()
        end
    end

    if isNumber(delay) then
        -- need to make the delay 'manually', beacuse we must invoke custom handler, or because it's a ground group...
        if isFunction(startedFunc) or not group:IsAir() then
            Delay(delay, function()
                start()
                if isFunction(startedFunc) then
                    startedFunc(group)
                end
            end)
        else
            start(delay)
        end
    else
        start()
    end
end

-- function ActivateWeapons(source, value)
--     if not isBoolean(value) then value = true end
--     local group
--     if isGroup(source) then
--         group = source
--     elseif isAssignedString(source) then
--         group = GROUP:FindByName(source)
--     end
--     if group then
--         local units = group:GetUnits()
--         for _, unit in ipairs(units) do
--             ActivateWeapons(unit, value)
--         end
--         return
--     end

--     local function setWeaponCount(dcsUnit, setCount)
--         local index = {}
--         local ammo = dcsUnit:getAmmo()
-- Debug("nisse - ActivateWeapons_setWeaponCount :: ammo: " .. DumpPrettyDeep(ammo, 2))
--         for _, weapon in ipairs(ammo) do
--             index[weapon.desc.typeName] = weapon.count
--             if isNumber(setCount) then
--                 weapon.count = setCount
--             else
--                 weapon.count = setCount[weapon.desc.typeName]
--             end
--         end
--         return index
--     end

--     local unit = getUnit(source)
--     local msgVerb
--     if value then msgVerb = "reactivate" else msgVerb = "deactivate" end
--     local dcsUnit = unit:GetDCSObject()
--     local ammo = {}
--     if not dcsUnit then return Error("ActivateWeapons :: cannot " .. msgVerb .. " weapons (no DCS object found for unit: " .. unit.UnitName .. ")") end
--     if not unit then return Error("ActivateWeapons :: cannot activate ") end
--     if value then
--         ammo = unit._DCAF_ammo_index
--         if not ammo then return Error("ActivateWeapons :: cannot reactivate weapons (seems weapons was not deactivated previously)") end
--         setWeaponCount(dcsUnit, ammo)
--         unit._DCAF_ammo_index = nil
--     else

--         unit._DCAF_ammo_index = setWeaponCount(dcsUnit, 0)
--     end
-- end

-- function DeactivateWeapons(source)


--     return ActivateWeapons(source, false)
-- end

local FeintAttackEvent = {
    IniUnit = nil,  -- #UNIT (initiating the feint atack)
    TgtUnit = nil   -- feint attack target (#UNIT)
}

function FeintAttackEvent:New(iniUnit, tgtUnit)
    local obj = DCAF.clone(FeintAttackEvent)
    obj.IniGroup = iniUnit:GetGroup()
    obj.IniGroupName = obj.IniGroup.GroupName
    obj.IniUnit = iniUnit
    obj.TgtUnit = tgtUnit
    return obj
end

--- Ends the Feint Attack. Please note the "feint attacking" group will not be affected, which will mean it is likely to initiate lethal attacks. Please call FeintAttackEvent:Deactivate to prevent that 
function FeintAttackEvent:End()
    Debug("FeintAttackEvent:End :: " .. self.IniGroupName)
    if self.IsEventEnded then return self end
    self.IsEventEnded = true
    self.IniGroup:UnHandleEvent(EVENTS.Shot)
    return self
end 

--- Deactivates the 'feint attacking' group; leaving it in a pacified state. For ground/naval units emission is turned off. Air unirs are set to ROE="Hold Fire". Calling this function will also end the feint attack, unless a 'false' value is passed in
--- @param endEvent boolean (optional) [default=true] Will also automatically end the Feint Attack (see FeintAttackEvent:End())
function FeintAttackEvent:Deactivate(endEvent)
    local iniGroup = self.IniGroup
    if endEvent == nil then endEvent = true end
    Debug("FeintAttackEvent:Deactivate :: " .. self.IniGroupName)
    if iniGroup:IsGround() or iniGroup:IsShip() then
        iniGroup:EnableEmission(false) -- OptionAlarmStateGreen()
    elseif iniGroup:IsAir() then
        iniGroup:OptionROEHoldFire()
    end
    if endEvent then return self:End() end
    return self
end

local DCAF_FeintAttackInfo = {
    ClassName = "DCAF_FeintAttackInfo",
    ----
    Group = nil,
    Name = nil,
    _funcDone = nil,
    _hasEnded = false
}

function DCAF_FeintAttackInfo:End(event)
    if self._hasEnded then return end
    self._hasEnded = true
    local group = self.Group
    if not group then return Error("DCAF_FeintAttackInfo:End :: no Group available", self) end
    local coord = group:GetCoordinate()
    if not coord then
        -- group no longer alive 
        self._hasEnded = true
        return self
    end

    event = event or FeintAttackEvent:New(group:GetUnit(1))
    event:End()
    local funcDone = self._funcDone
    if funcDone ~= nil and isFunction(funcDone) then
        pcall(function()
            funcDone(event)
        end)
    end
    return self, event
end

function DCAF_FeintAttackInfo:EndAndDeactivate()
    local _, event = self:End()
    event:Deactivate()
    return self
end

--- Makes a group appear to attack but weapons are immediately neutralized, emulating provocation or signalling "final warning" etc.
--- @param group any - #GROUP, or name of #GROUP
--- @param maxShots number - (optional) [default = 1] specifies max number of feined attacks. A value > 10 specifies time (seconds) before group ALARM state is set to green
--- @param shootAllowance any - (optional) if null; no shot will be allowed (group will only lock). If number then shot weapon is elimitaed after as many seconds. If boolean allowShot = 1 second
--- @param maxTime number - (optional) specifies maximum time for the feined attack. Oncec it times out it will end (see `funcDone`)
--- @param funcDone function - (optional) function to be called back when all feint attacks are complete
--- @param funcEvent function - (optional) function to be called back for each feint attack (see max)
function FeintAttack(group, maxShots, shootAllowance, maxTime, funcDone, funcEvent)
    Debug("FeintAttack :: maxShots: " .. Dump(maxShots) .. " :: shootAllowance: " .. Dump(shootAllowance) .. " :: maxTime: " .. Dump(maxTime) .. " :: funcDone: " .. Dump(funcDone) .. " :: funcEvent: " .. Dump(funcEvent))
    local validGroup = getGroup(group)
    if not validGroup then return Error("FeintAttack :: could not resolve a group from: " .. DumpPretty(group)) end
    group = validGroup
    Debug("FeintAttack :: group: " .. group.GroupName)
    if not group:IsActive() then return Error("FeintAttack :: group was not active: " .. group.GroupName) end
    local feintAttack = group._dcaf_feintAttack
    if feintAttack then feintAttack:End() end
    group:EnableEmission(true)
    group:OptionAlarmStateRed()
    group:OptionROEOpenFire()

    local countShots = 0
    local endTime

    feintAttack = DCAF.clone(DCAF_FeintAttackInfo)
    feintAttack.Group = group
    feintAttack._funcDone = funcDone
    group._dcaf_feintAttack = feintAttack

    if not isNumber(maxShots) then
        maxShots = 0
        group:OptionROEHoldFire()
    end
    if isNumber(maxTime) and maxTime > 1 then
Debug("nisse - FeintAttack :: sets timeout to " .. maxTime .. " seconds")
        endTime = UTILS.SecondsOfToday() + maxTime
        DCAF.delay(function()
Debug("nisse - FeintAttack :: times out :: group: " .. group.GroupName)
            feintAttack:End()
            -- endFeintAttack()
        end, maxTime)
    end
    if not shootAllowance then shootAllowance = 0 end
    if shootAllowance == true then shootAllowance = 0.2 end

Debug("nisse - FeintAttack :: shootAllowance: " .. shootAllowance)
    group:HandleEvent(EVENTS.Shot, function(_, e)
Debug("nisse - FeintAttack :: SHOT event :: e: " .. DumpPretty(e))

        local event = FeintAttackEvent:New(e.IniUnit, e.TgtUnit)
        local weapon = e.weapon

        local function neutralizeWeapon(countAttempt)
            weapon:destroy()
            group:EnableEmission(false)
            Debug("FeintAttack :: " .. group.GroupName .. " :: weapon neutralized :: countAttempt: " .. (countAttempt or 1))
            -- DCAF.delay(function()
            --     if not event.IsEventEnded then
            --         group:EnableEmission(true)
            --     end
            --     local success, position = pcall(function() return weapon:getPoint() end)
            --     if success then
            --         trigger.action.explosion(position, 5)
            --         Debug("FeintAttack :: " .. group.GroupName .. " :: exploded weapon")
            --     end
            -- end, 0.5)
        end
        DCAF.delay(function()
            neutralizeWeapon()
        end, shootAllowance)
        if maxShots then
            countShots = countShots+1
            if countShots >= maxShots then
                Debug("FeintAttack :: " .. group.GroupName .. " :: max number of shots fired: " .. maxShots)
                feintAttack:End(event)
            end
        elseif endTime and UTILS.SecondsOfToday() >= endTime then
            Debug("FeintAttack :: " .. group.GroupName .. " :: times out after " .. maxShots .. " seconds")
            feintAttack:End(event)
        elseif isFunction(funcEvent) then
            pcall(function()
                funcEvent(event)
            end)
        end
    end)
end

function DamageUnit(unit, damage)
    local validUnit = getUnit(unit)
    if not validUnit then return Error("DamageUnit :: cannot resolve unit from: " .. DumpPretty(unit)) end
    unit = validUnit
    local coord = unit:GetCoordinate()
    if not coord then return Error("DamageUnit :: cannot get coordinate from unit: " .. DumpPretty(unit.UnitName)) end
    Debug("nisse - DamageUnit :: (aaa) life: " .. unit:GetLife() .. " :: life0: " .. unit:GetLife0() .. " :: lifeRelative: " .. unit:GetLifeRelative())

    local translateHeading
    local translateDistance
    local altitude
    if unit:IsAir() then
        if not isNumber(damage) then damage = 10 end -- TODO consider calculating size of explosion based on total life
        translateHeading = (unit:GetHeading() - 180) % 360
        translateDistance = 15
        altitude = 15
    end

    if not isNumber(damage) then damage = 6 end

    if translateHeading then
        coord = coord:Translate(translateDistance, translateHeading)
    end
    if altitude then
        coord:SetAltitude(unit:GetAltitude(false) + altitude, true)
    end
    coord:Explosion(damage)

MessageTo(nil, "nisse - DamageUnit :: *BOOM*!!!")
DCAF.delay(function()
    Debug("nisse - DamageUnit :: (bbb) life: " .. unit:GetLife() .. " :: life0: " .. unit:GetLife0() .. " :: lifeRelative: " .. unit:GetLifeRelative())
end, 1)

    return unit
end

--- Activates a LATE ACTIVATED group and returns it
function Activate(controllable)
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("Activate :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    if not group:IsActive() then
        group:Activate()
    end
    return group
end

--- Activates an Uncontrolled group (at its current location). Please note that Air groups needs to be set to 'UNCONTROLLED' in ME
function ActivateUncontrolled(controllable)
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("ActivateUncontrolled :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    -- if isNumber(delayStart) and group:IsGround() then
    if group:IsGround() then
        group:SetAIOff()
    end

    if not group:IsActive() then
        group:Activate()
    end
    return group
end

--- Activates an Uncontrolled group (at its current location) and then starts it, optionally after a delay.
--- Please note that Air groups needs to be set to 'UNCONTROLLED' in ME
function ActivateUncontrolledThenStart(controllable, delayStart, startedFunc)
    return CommandStart(ActivateUncontrolled(controllable), delayStart, startedFunc)
end

--- Spawns a group as Uncontrolled and then starts it, optionally after a delay
function SpawnUncontrolledThenStart(controllable, delayStart, startedFunc) -- todo Need to be able to set parking spot
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("CommandStart :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    local spawn = getSpawn(group.GroupName) -- << -- gets SPAWN for group
    if isNumber(delayStart) and group:IsAir() then
        spawn:InitUnControlled(true)
    end

    group = spawn:Spawn()
    return ActivateUncontrolledThenStart(group, delayStart, startedFunc)
end

function ROEHoldFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEHoldFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else

            group:OptionROEHoldFire()
            Trace("ROEHoldFire"..group.GroupName.." :: holds fire")
        end
    end
end

function ROEReturnFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEReturnFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionROEReturnFire()
            Trace("ROEReturnFire"..group.GroupName.." :: holds fire unless fired upon")
        end
    end
end

function ROTEvadeFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROTEvadeFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            Trace("ROTEvadeFire-"..group.GroupName.." :: evades fire")
            group:OptionROTEvadeFire()
        end
    end
end

function ROEOpenFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEOpenFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionAlarmStateRed()
            Trace("ROEOpenFire-"..group.GroupName.." :: is alarm state RED")
            group:OptionROEOpenFire()
            Trace("ROEOpenFire-"..group.GroupName.." :: can open fire at designated targets")
        end
    end
end

function ROEOpenFireWeaponFree( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEOpenFireWeaponFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionAlarmStateRed()
            Trace("ROEOpenFireWeaponFree-"..group.GroupName.." :: is alarm state RED")
            group:OptionROEOpenFireWeaponFree()
            Trace("ROEOpenFireWeaponFree-"..group.GroupName.." :: can open fire at designated targets, or targets of opportunity")
        end
    end
end

function ROEWeaponFree( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            if (group:IsShip()) then
                ROEOpenFireWeaponFree( group )
                return
            end
            group:OptionAlarmStateAuto()
            Trace("ROEWeaponFree-"..group.GroupName.." :: is alarm state AUTO")
            group:OptionROEWeaponFree()
            Trace("ROEWeaponFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEDefensive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEDefensive-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Trace("ROEDefensive-"..group.GroupName.." :: is alarm state RED")
            ROEHoldFire( group )
            Trace("ROEDefensive-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEActiveDefensive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponsFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is alarm state RED")
            ROEReturnFire( group )
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEAggressive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponsFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Debug("ROEWeaponsFree-"..group.GroupName.." :: is alarm state RED")
            ROEWeaponFree( group )
            Debug("ROEWeaponsFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function SetAIOn( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("SetAIOn-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            Trace("SetAIOn-" .. group.GroupName .. " :: sets AI=ON :: DONE")
            group:SetAIOn()
        end
    end
end

function SetAIOff( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("SetAIOff-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            Trace("SetAIOff-" .. group.GroupName .. " :: sets AI=OFF :: DONE")
            group:SetAIOff()
        end
    end
end

function Stop( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("Stop-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            if group:IsAir() and group:InAir() then
                Trace("Stop-"..group.GroupName.." :: lands at nearest aeorodrome :: DONE")
                LandHere(group)
            else
                Trace("Stop-"..group.GroupName.." :: sets AI=OFF :: DONE")
                group:SetAIOff()
            end
        end
    end
end

function Resume( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("Resume-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:SetAIOn()
        end
    end
end

function TaskAttackGroup( attacker, target )
    local ag = getGroup(attacker)
    if (ag == nil) then
        return exitWarning("TaskAttackGroup-? :: cannot resolve attacker group "..Dump(attacker))
    end
    local tg = getGroup(target)
    if (tg == nil) then
        return exitWarning("TaskAttackGroup-? :: cannot resolve target group "..Dump(tg))
    end

    if (ag:OptionROEOpenFirePossible()) then
        ROEOpenFire(ag)
    end
    ag:SetTask(ag:TaskAttackGroup(tg))
    Trace("TaskAttackGroup-"..ag.GroupName.." :: attacks group "..tg.GroupName..":: DONE")
end

function TaskAttackUnit( attacker, target, unitIndex )
    local ag = getGroup(attacker)
    if (ag == nil) then
        return exitWarning("TaskAttackUnit-? :: cannot resolve attacker group "..Dump(attacker))
    end
    local tg = getUnit(target)
    if not tg and isNumber(unitIndex) then
        local group = getGroup(target)
        if not group then
            return exitWarning("TaskAttackUnit-? :: expected `target` to be #GROUP when `unitIndex` is specified, but was: "..DumpPretty(target))
        end
        tg = group:GetUnit(unitIndex)
    end
    if (tg == nil) then
        return exitWarning("TaskAttackUnit-? :: cannot resolve target unit :: attacker: " .. ag.GroupName ..  " :: target: " .. DumpPretty(target) .. " :: unitIndex: " .. DumpPretty(unitIndex))
    end
    if (ag:OptionROEOpenFirePossible()) then
        ROEOpenFire(ag)
    end
    ag:SetTask(ag:TaskAttackUnit(tg))
    Trace("TaskAttackUnit-"..ag.GroupName.." :: attacks unit "..tg.UnitName..":: DONE")
end


function IsAARTanker(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("IsAARTanker :: cannot resolve group from " .. DumpPretty(group)) end

    local route = forGroup:CopyRoute()
    -- check for 'Tanker' task ...
    for _, wp in ipairs(route) do
        local task = wp.task
        if task and task.id == "ComboTask" and task.params and task.params.tasks then -- todo Can task be other than 'ComboTask' here?
            for _, task in ipairs(task.params.tasks) do
                if task.id == "Tanker" then
                    return true end
            end
        end
    end
    return false
end

function HasTask(controllabe, sTaskId, wpIndex) -- todo move higher up, to more general part of the file
    local group = getGroup(controllabe)
    if not group then
        error("HasTask :: cannot resolve group from: " .. DumpPretty(controllabe)) end

    local route = group:CopyRoute()
    local function hasWpTask(wp)
        for index, task in ipairs(wp.task.params.tasks) do
            if task.id == sTaskId then
                return index end
        end
    end

    if not wpIndex then
        for wpIndex, wp in ipairs(route) do
            if hasWpTask(wp) then
                return wpIndex end
        end
    elseif hasWpTask(route[wpIndex]) then
        return wpIndex
    end
end

function IsTakeoffWaypoint(waypoint) 
    return string.find(waypoint.type, "TakeOff")
end

function IsLandingWaypoint(waypoint)
    return waypoint.type == "Land"
end

function GetLandingWaypoint(waypoints)
    if not isList(waypoints) then
        return Error("GetLandingWaypoint :: `waypoints` must be list, but was: " .. DumpPretty(waypoints)) end

    for i = #waypoints, 1, -1 do
        local wp = waypoints[i]
        if IsLandingWaypoint(wp) then
            return wp end
    end
end

function HasWaypointAction(waypoints, sActionId, wpIndex) -- todo move higher up, to more general part of the file
    local function hasWpAction(wp)
        for index, task in ipairs(wp.task.params.tasks) do
            if task.id == "WrappedAction" and task.params.action.id == sActionId then
                return index end
        end
    end

    if not wpIndex then
        for wpIndex, wp in ipairs(waypoints) do
            if hasWpAction(wp) then
                return wpIndex end
        end
    elseif hasWpAction(route[wpIndex]) then
        return wpIndex
    end
end

function HasAction(controllabe, sActionId, wpIndex) -- todo move higher up, to more general part of the file
    local group = getGroup(controllabe)
    if not group then
        error("HasTask :: cannot resolve group from: " .. DumpPretty(controllabe)) end

    local route = group:CopyRoute()
    local function hasWpAction(wp)
        for index, task in ipairs(wp.task.params.tasks) do
            if task.id == "WrappedAction" and task.params.action.id == sActionId then
                return index end
        end
    end

    if not wpIndex then
        for wpIndex, wp in ipairs(route) do
            if hasWpAction(wp) then
                return wpIndex end
        end
    elseif hasWpAction(route[wpIndex]) then
        return wpIndex
    end
end

function HasLandingTask(controllabe)
    -- note: The way I understand it a landing task can be a WrappedAction or a special type of "Land" waypint
    local wrappedLandingWpIndex = HasAction(controllabe, "Landing")
    if wrappedLandingWpIndex then
        return wrappedLandingWpIndex
    end

    local group = getGroup(controllabe)
    if not group then
        error("HasLandingTask :: cannot resolve group from: " .. DumpPretty(controllabe)) end

    local route = group:CopyRoute()
    for wpIndex, wp in ipairs(route) do
        if wp.type == "Land" then
            return wpIndex, AIRBASE:FindByID(wp.airdromeId), wp
        end
    end
end
function HasOrbitTask(controllabe) return HasTask(controllabe, "Orbit") end
function HasTankerTask(controllabe) return HasTask(controllabe, "Tanker") end
function HasSetFrequencyTask(controllabe) return HasAction(controllabe, "SetFrequency") end
function HasActivateBeaconTask(controllabe) return HasAction(controllabe, "ActivateBeacon") end
function HasDeactivateBeaconTask(controllabe) return HasAction(controllabe, "DeactivateBeacon") end

--------------------------------------------- [[ MISSION EVENTS ]] ---------------------------------------------


MissionEvents = { }

MissionEvents.MapMark = {
    EventID = nil,                      -- #number - event id
    Coalition = nil,                    -- #Coalition
    Index = nil,                        -- #number - mark identity
    Time = nil,                         -- #number - game world time in seconds (UTILS.SecondsOfToday)
    Text = nil,                         -- #string - map mark text
    GroupID = nil,                      -- #number - I have NOOO idea what this is (doesn't seem to identify who added the mark)
    Location = nil,                     -- DCAF.Location
}

function MissionEvents.MapMark:New(event)
    local mark = DCAF.clone(MissionEvents.MapMark)
    mark.ID = event.id
    mark.Coalition = Coalition.Resolve(event.coalition)
    mark.Index = event.index
    mark.Time = event.time
    mark.Text = event.text
    mark.GroupID = event.groupID
    local coord = COORDINATE:New(event.pos.x, event.pos.y, event.pos.z)
    mark.Location = DCAF.Location:New(coord)
    return mark
end

local _missionEventsHandlers = {
    _missionEndHandlers = {},
    _groupSpawnedHandlers = {},
    _unitSpawnedHandlers = {},
    _unitDeadHandlers = {},
    _unitDestroyedHandlers = {},
    _unitKilledHandlers = {},
    _unitCrashedHandlers = {},
    _playerEnteredUnitHandlers = {},
    _playerLeftUnitHandlers = {},
    _ejectionHandlers = {},
    _groupDivertedHandlers = {},
    _weaponFiredHandlers = {},
    _shootingStartHandlers = {},
    _shootingStopHandlers = {},
    _unitHitHandlers = {},
    _aircraftTakeOffHandlers = {},
    _aircraftLandedHandlers = {},
    _unitEnteredZone = {},
    _unitInsideZone = {},
    _unitLeftZone = {},
    _mapMarkAddedHandlers = {},
    _mapMarkChangedHandlers = {},
    _mapMarkDeletedHandlers = {},
    _startAAR = {},
    _stopAAR = {}
}

local PlayersAndUnits = { -- dictionary
    -- key = <unit name>
    -- value = { Unit = #UNIT, PlayerName = <player name> }
}

function PlayersAndUnits:Add(unit, playerName)
    PlayersAndUnits[unit.UnitName] = { Unit = unit, PlayerName = playerName}
end

function PlayersAndUnits:Remove(unitName)
    PlayersAndUnits[unitName] = nil
end

function PlayersAndUnits:Get(unitName)
    local info = PlayersAndUnits[unitName]
    if info then
        return info.Unit, info.PlayerName
    end
end

local isMissionEventsListenerRegistered = false
local _e = {}

function MissionEvents:Invoke(handlers, data)
    for _, handler in ipairs(handlers) do
        handler( data )
    end
end

-- hack - this event often seems to be triggered twice
local _enteredUnitTimestamps = {
    -- key   = #string - player name
    -- value = #number - timestamp
}

function _e:onEvent( event )
-- Debug("nisse - _e:onEvent-? :: event: " .. DumpPretty(event))

    if event.id == world.event.S_EVENT_MISSION_END then
        MissionEvents:Invoke( _missionEventsHandlers._missionEndHandlers, event )
        return
    end

    local function getDCSTarget(event)
        local dcsTarget = event.target
        if not dcsTarget and event.weapon then
            dcsTarget = event.weapon:getTarget()
        end
        return dcsTarget
    end

    local function safeGetPlayerName(unit)
        local playerName
        pcall(function()
            playerName = unit:GetPlayerName()
        end)
        return playerName
    end

    local function safeGetGroup(unit)
        local group
        pcall(function()
            group = unit:GetGroup()
        end)
        return group
    end

    local function addInitiatorAndTarget( event )
        if event.initiator then
            if event.initiator and not event.IniUnit then
                local unitName = event.initiator:getName()
                event.IniUnit = getUnit(unitName)
            end
            if event.IniUnit then
                event.IniUnitName = event.IniUnit.UnitName
                event.IniPlayerName = safeGetPlayerName(event.IniUnit) --:GetPlayerName()
                event.IniGroup = safeGetGroup(event.IniUnit)-- event.IniUnit:GetGroup()
                if event.IniGroup then
                    event.IniGroupName = event.IniGroup.GroupName
                end
            end
        end

        local dcsTarget = getDCSTarget(event)
        if event.TgtUnit == nil and dcsTarget ~= nil then
            event.TgtUnit = UNIT:Find(dcsTarget)
            if not event.TgtUnit then
                -- Warning("_e:onEvent :: event: " .. Dump(event.id) .. " :: could not resolve TgtUnit from DCS object")
                return event
            end
            event.TgtUnitName = event.TgtUnit.UnitName
            event.TgtGroup = event.TgtUnit:GetGroup()
            if not event.TgtGroup then
                Warning("_e:onEvent :: event: " .. Dump(event.id) .. " :: could not resolve TgtGroup from UNIT:GetGroup()" )
                return event
            end
            event.TgtGroupName = event.TgtGroup.GroupName
        end
        return event
    end

    local function addPlace( event )
        if event.place == nil or event.Place ~= nil then
            return event
        end
        event.Place = AIRBASE:Find( event.place )
        event.PlaceName = event.Place:GetName()
        return event
    end

    if event.id == world.event.S_EVENT_BIRTH then
        -- todo consider supporting MissionEvents:UnitBirth(...)

        if isAssignedString(event.IniPlayerName) then
            -- event.id = world.event.S_EVENT_PLAYER_ENTER_UNIT
        elseif event.IniUnit and isClass(event.IniUnit, UNIT) then 
            local playerName = event.IniUnit:GetPlayerName()
            if playerName then
                event.IniPlayerName = playerName
                -- event.id = world.event.S_EVENT_PLAYER_ENTER_UNIT
            end
        end
        return
    end

    -- if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then --  event
    --     if not event.initiator then
    --         return end -- weird!

    --     local unit = UNIT:Find(event.initiator)
    --     if not unit then
    --         return end -- weird!

    --     if PlayersAndUnits:Get(event.IniUnitName) then
    --         return end

    --     -- hack - this event often seems to be triggered twice
    --     local iniPlayerName = unit:GetPlayerName()
    --     local now = UTILS.SecondsOfToday()
    --     local previousEvent = _enteredUnitTimestamps[iniPlayerName]
    --     if previousEvent and now - previousEvent < 2 then
    --         -- avoids firing same unit multiple times
    --         return end
            
    --     _enteredUnitTimestamps[iniPlayerName] = now

    --     PlayersAndUnits:Add(unit, event.IniPlayerName)
    --     MissionEvents:Invoke(_missionEventsHandlers._playerEnteredUnitHandlers, {
    --         time = MissionTime(),
    --         IniPlayerName = unit:GetPlayerName(),
    --         IniUnit = unit,
    --         IniUnitName = unit.UnitName,
    --         IniGroupName = unit:GetGroup().GroupName,
    --         IniUnitTypeName = unit:GetTypeName(),
    --         IniCategoryName = unit:GetCategoryName(),
    --         IniCategory = unit:GetCategory()
    --     })
    -- end

    if event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
        if event.IniUnitName then
            PlayersAndUnits:Remove(event.IniUnitName)
            MissionEvents:Invoke( _missionEventsHandlers._playerLeftUnitHandlers, event )
        end
    end

    local function invokeUnitDestroyed(event)
        if event.TgtUnit then
            local rootEvent = DCAF.clone(event)
            event = {
                RootEvent = rootEvent,
                IniUnit = rootEvent.TgtUnit,
                IniUnitName = rootEvent.TgtUnitName,
                IniGroup = rootEvent.TgtGroup,
                IniGroupName = rootEvent.TgtGroupName
            }
        end
        MissionEvents:Invoke(_missionEventsHandlers._unitDestroyedHandlers, event)
    end

    if event.id == world.event.S_EVENT_DEAD then
        if event.IniUnit then
            event = addInitiatorAndTarget(event)
            if #_missionEventsHandlers._unitDeadHandlers > 0 then
                MissionEvents:Invoke( _missionEventsHandlers._unitDeadHandlers, event)
            end
            invokeUnitDestroyed(event)
        end
        return
    end

    if event.id == world.event.S_EVENT_KILL then
        -- unit was killed by other unit
        event = addInitiatorAndTarget(event)
        MissionEvents:Invoke(_missionEventsHandlers._unitKilledHandlers, event)
        invokeUnitDestroyed(event)
        return
    end

    if event.id == world.event.S_EVENT_EJECTION then
        MissionEvents:Invoke(_missionEventsHandlers._ejectionHandlers, addInitiatorAndTarget(event))
        return
    end

    if event.id == world.event.S_EVENT_CRASH then
        event = addInitiatorAndTarget(event)
        MissionEvents:Invoke( _missionEventsHandlers._unitCrashedHandlers, event)
        invokeUnitDestroyed(event)
        return
    end

    if event.id == world.event.S_EVENT_SHOT then
        if #_missionEventsHandlers._weaponFiredHandlers > 0 then
            local dcsTarget = event.target
            if not dcsTarget and event.weapon then
                dcsTarget = event.weapon:getTarget()
            end
            MissionEvents:Invoke( _missionEventsHandlers._weaponFiredHandlers, addInitiatorAndTarget(event))
        end
        return
    end

    if event.id == world.event.S_EVENT_SHOOTING_START then
        MissionEvents:Invoke( _missionEventsHandlers._shootingStartHandlers, addInitiatorAndTarget(event))
        return
    end

    if event.id == world.event.S_EVENT_SHOOTING_END then
        MissionEvents:Invoke( _missionEventsHandlers._shootingStopHandlers, addInitiatorAndTarget(event))
        return
    end

    if event.id == world.event.S_EVENT_HIT then
        MissionEvents:Invoke( _missionEventsHandlers._unitHitHandlers, event)
        return
    end

    if event.id == world.event.S_EVENT_TAKEOFF then
        addInitiatorAndTarget(addPlace(event))
        MissionEvents:Invoke(_missionEventsHandlers._aircraftTakeOffHandlers, addInitiatorAndTarget(addPlace(event)))
        return
    end

    if event.id == world.event.S_EVENT_LAND then
        addInitiatorAndTarget(addPlace(event))
        MissionEvents:Invoke(_missionEventsHandlers._aircraftLandedHandlers, addInitiatorAndTarget(addPlace(event)))
        return
    end

    if event.id == world.event.S_EVENT_MARK_ADDED then
        MissionEvents:Invoke(_missionEventsHandlers._mapMarkAddedHandlers, MissionEvents.MapMark:New(event))
        return
    end
    if event.id == world.event.S_EVENT_MARK_CHANGE then
        MissionEvents:Invoke(_missionEventsHandlers._mapMarkChangedHandlers, MissionEvents.MapMark:New(event))
        return
    end
    if event.id == world.event.S_EVENT_MARK_REMOVED then
        MissionEvents:Invoke(_missionEventsHandlers._mapMarkDeletedHandlers, MissionEvents.MapMark:New(event))
        return
    end

    if event.id == world.event.S_EVENT_REFUELING then
        MissionEvents:Invoke(_missionEventsHandlers._startAAR, addInitiatorAndTarget(event))
        return
    end
    if event.id == world.event.S_EVENT_REFUELING_STOP then
        MissionEvents:Invoke(_missionEventsHandlers._stopAAR, addInitiatorAndTarget(event))
        return
    end
end

function MissionEvents:AddListener(listeners, func, predicateFunc, insertFirst )
    if insertFirst == nil then
        insertFirst = false
    end
    if insertFirst then
        table.insert(listeners, 1, func)
    else
        table.insert(listeners, func)
    end
    if isMissionEventsListenerRegistered then
        return
    end
    isMissionEventsListenerRegistered = true
    world.addEventHandler(_e)
end

function MissionEvents:RemoveListener(listeners, func)
    local idx
    for i, f in ipairs(listeners) do
        if func == f then
            idx = i
        end
    end
    if idx then
        table.remove(listeners, idx)
    end
end

function MissionEvents:OnMissionEnd( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._missionEndHandlers, func, nil, insertFirst) end

function MissionEvents:OnGroupSpawned( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._groupSpawnedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnGroupSpawned( func ) MissionEvents:RemoveListener(_missionEventsHandlers._groupSpawnedHandlers, func) end

function MissionEvents:OnUnitSpawned( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitSpawnedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitSpawned( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitSpawnedHandlers, func) end

function MissionEvents:OnUnitDead( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitDeadHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitDead( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitDeadHandlers, func) end

function MissionEvents:OnUnitKilled( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitKilledHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitKilled( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitKilledHandlers, func) end

function MissionEvents:OnUnitCrashed( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitCrashedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitCrashed( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitCrashedHandlers, func) end

function MissionEvents:OnEjection( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._ejectionHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnEjection( func ) MissionEvents:RemoveListener(_missionEventsHandlers._ejectionHandlers, func) end

function MissionEvents:OnWeaponFired( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._weaponFiredHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnWeaponFired( func ) MissionEvents:RemoveListener(_missionEventsHandlers._weaponFiredHandlers, func) end

function MissionEvents:OnShootingStart( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._shootingStartHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnShootingStart( func ) MissionEvents:RemoveListener(_missionEventsHandlers._shootingStartHandlers, func) end

function MissionEvents:OnShootingStop( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._shootingStopHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnShootingStop( func ) MissionEvents:RemoveListener(_missionEventsHandlers._shootingStopHandlers, func) end

function MissionEvents:OnUnitHit( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitHitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitHit( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitHitHandlers, func) end

function MissionEvents:OnAircraftTakeOff( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._aircraftTakeOffHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnAircraftTakeOff( func ) MissionEvents:RemoveListener(_missionEventsHandlers._aircraftTakeOffHandlers, func) end

function MissionEvents:OnAircraftLanded( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._aircraftLandedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnAircraftLanded( func ) MissionEvents:RemoveListener(_missionEventsHandlers._aircraftLandedHandlers, func) end

function MissionEvents:OnMapMarkAdded( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._mapMarkAddedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnMapMarkAdded( func ) MissionEvents:RemoveListener(_missionEventsHandlers._mapMarkAddedHandlers, func) end

function MissionEvents:OnMapMarkChanged( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._mapMarkChangedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnMapMarkChanged( func ) MissionEvents:RemoveListener(_missionEventsHandlers._mapMarkChangedHandlers, func) end

function MissionEvents:OnMapMarkDeleted( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._mapMarkDeletedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnMapMarkDeleted( func ) MissionEvents:RemoveListener(_missionEventsHandlers._mapMarkDeletedHandlers, func) end

--- CUSTOM EVENTS
--- A "collective" event to capture a unit getting destroyed, regardless of how it happened
-- @param #function fund The event handler function
-- @param #boolean Specifies whether to insert the event handler at the front, ensuring it will get invoked first
function MissionEvents:OnUnitDestroyed( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._unitDestroyedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnUnitDestroyed( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitDestroyedHandlers, func) end

-- function MissionEvents:OnPlayerEnteredUnit( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers, func, nil, insertFirst) end
-- function MissionEvents:EndOnPlayerEnteredUnit( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func) end

-- function MissionEvents:OnPlayerLeftUnit( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers, func, nil, insertFirst) end
-- function MissionEvents:EndOnPlayerLeftUnit( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) end

local _isPlayerEnterUnitSubscribed
function MissionEvents:OnPlayerEnteredUnit( func, insertFirst, removeAutomatically) 
    MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers, func, nil, insertFirst)
    if _isPlayerEnterUnitSubscribed then
        return end

    _isPlayerEnterUnitSubscribed = true
    BASE:HandleEvent(EVENTS.PlayerEnterUnit, function(_, event)
        event.time = MissionTime()
        MissionEvents:Invoke(_missionEventsHandlers._playerEnteredUnitHandlers, event)
        if removeAutomatically == true then
            MissionEvents:EndOnPlayerEnteredUnit(func)
        end
    end)
end
function MissionEvents:EndOnPlayerEnteredUnit( func ) 
    MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func) 
    if #_missionEventsHandlers._playerEnteredUnitHandlers == 0 then
        BASE:UnHandleEvent(EVENTS.PlayerEnterUnit)
        _isPlayerEnterUnitSubscribed = false
    end
end

local _isPlayerLeftUnitSubscribed
function MissionEvents:OnPlayerLeftUnit( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers, func, nil, insertFirst)
    if _isPlayerLeftUnitSubscribed then
        return end

    _isPlayerLeftUnitSubscribed = true
    BASE:HandleEvent(EVENTS.PlayerLeaveUnit, function(_, event)
        event.time = MissionTime()
        MissionEvents:Invoke(_missionEventsHandlers._playerLeftUnitHandlers, event)
    end)
end
function MissionEvents:EndOnPlayerLeftUnit( func ) 
    MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) 
    if #_missionEventsHandlers._playerLeftUnitHandlers == 0 then
        BASE:UnHandleEvent(EVENTS.PlayerLeaveUnit)
        _isPlayerLeftUnitSubscribed = false
    end
end

local _isPlayerEnterAircraftSubscribed
function MissionEvents:OnPlayerEnteredAirplane( func, insertFirst )

    MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers,
        function( event )
            if event.IniUnit:IsAirPlane() then
                func( event )
            end
        end,
        nil,
        insertFirst)

    if _isPlayerEnterAircraftSubscribed then
        return end

    _isPlayerEnterAircraftSubscribed = true
    BASE:HandleEvent(EVENTS.PlayerEnterAircraft, function(_, event)
        event.time = MissionTime()
        MissionEvents:Invoke(_missionEventsHandlers._playerEnteredUnitHandlers, event)
        -- MissionEvents:Invoke(_missionEventsHandlers._playerEnteredUnitHandlers, {
        --     time = MissionTime(),
        --     IniPlayerName = unit:GetPlayerName(),
        --     IniUnit = unit,
        --     IniUnitName = unit.UnitName,
        --     IniGroupName = unit:GetGroup().GroupName,
        --     IniUnitTypeName = unit:GetTypeName(),
        --     IniCategoryName = unit:GetCategoryName(),
        --     IniCategory = unit:GetCategory()
        -- })
    end)
end
function MissionEvents:EndOnPlayerEnteredAirplane( func )
    MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func)
    if #_missionEventsHandlers._playerEnteredUnitHandlers == 0 then
        BASE:UnHandleEvent(EVENTS.PlayerEnterAircraft)
        _isPlayerEnterAircraftSubscribed = nil
    end
end

function MissionEvents:OnPlayerLeftAirplane( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers,
        function( event )
            if event.IniUnit:IsAirPlane() then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerLeftAirplane( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) end

function MissionEvents:OnPlayerEnteredHelicopter( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers,
        function( event )
            if (event.IniUnit:IsHelicopter()) then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerEnteredHelicopter( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftHelicopter( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers,
        function( event )
            if (event.IniUnit:IsHelicopter()) then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerLeftHelicopter( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) end

function MissionEvents:OnGroupDiverted( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._groupDivertedHandlers,
        func,
        nil,
        insertFirst)
end
function MissionEvents:EndOnGroupDiverted( func ) MissionEvents:RemoveListener(_missionEventsHandlers._groupDivertedHandlers, func) end


_onDivertFunc = function( controllable, route ) -- called by Divert()
    MissionEvents:Invoke(_missionEventsHandlers._groupDivertedHandlers, { Controllable = controllable, Route = route })
end

function MissionEvents:OnStartAAR( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._startAAR,
        func,
        nil,
        insertFirst)
end
function MissionEvents:EndOnStartAAR( func ) MissionEvents:RemoveListener(_missionEventsHandlers._startAAR, func) end

function MissionEvents:OnStopAAR( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._stopAAR,
        func,
        nil,
        insertFirst)
end
function MissionEvents:EndOnStopAAR( func ) MissionEvents:RemoveListener(_missionEventsHandlers._stopAAR, func) end

---- CSTOM EVENT: FUEL STATE

local _missionEventsAircraftFuelStateMonitor = {

    UnitInfo = {
        Units = {},           -- list of #UNIT; monitored units
        State = nil,          -- #number (0 - 1); the fuel state being monitored
        Func = nil            -- #function; the event handler
    },

    Timer = nil,              -- assigned by _missionEventsAircraftFuelStateMonitor:Start()
    Monitored = {
        -- dictionary
        --   key   = #string (group or unit name)
        --   value = {
        --       list of #UnitInfo
        --  }
    },
    CountMonitored = 0,           -- ¤number; no. of items in $self.Units
}

function GROUP:GetFuelLowState()
    local lowState = 35535
    for _, unit in ipairs(self:GetUnits()) do
        local state = unit:GetFuel()
        if state < lowState then
            lowState = state
        end
    end
    return lowState
end 

function setGroupRoute(group, waypoints)
    local validGroup = getGroup(group)
    if not validGroup then return Error("SetGroupRoute :: cannot resolve #GROUP from: " .. DumpPretty(group)) end
    if not isList(waypoints) then return Error("GROUP:SetRoute :: `waypoints` must be a list, but was: " .. DumpPretty(waypoints)) end

    group = validGroup
    group._route = waypoints
    group:Route(waypoints)
    Debug("setGroupRoute :: "..group.GroupName.." :: group route was set :: DONE")
    if not group._DCAF_setRouteHandlers then return end
    -- trigger OnRoute event...
    for _, handler in ipairs(group._DCAF_setRouteHandlers) do
        pcall(function() handler(group, waypoints) end)
    end
    return group
end

function getGroupRoute(group)
    local validGroup = getGroup(group)
    if not validGroup then
        if isClass(group, DCAF.Convoy) then
            validGroup = group.Group
        else
            return Error("getGroupRoute :: cannot resolve #GROUP from: " .. DumpPretty(group))
        end
    end
    return validGroup._route or validGroup:CopyRoute()
end

function GROUP:SetRoute(waypoints)
    return setGroupRoute(self, waypoints)
end

function GROUP:GetRoute()
    return getGroupRoute(self)
end

function SetRoute( controllable, route )
    -- NOTE method is among the oldest. Retained only for backward compatibility
    local group = getGroup(controllable)
    if not group then return Error("SetRoute :: group not found: "..Dump(controllable)) end
    setGroupRoute(group, route)
end

function HandleSetRouteEvent( controllable, handler )
    local group = getGroup(controllable)
    if not group then return Error("HandleSetRouteEvent :: cannot resolve group from: " .. DumpPretty(controllable)) end
    if not isFunction(handler) then return Error("HandleSetRouteEvent :: `handler` must be function, but was: " .. DumpPretty(handler)) end
    group._DCAF_setRouteHandlers = group._DCAF_setRouteHandlers or {}
    group._DCAF_setRouteHandlers[#group._DCAF_setRouteHandlers+1] = handler
    return group
end

function RouteDirectTo( controllable, waypoint, setRoute )
    if (controllable == nil) then
        return exitWarning("DirectTo-? :: controllable not specified")
    end
    if (waypoint == nil) then
        return exitWarning("DirectTo-? :: steerpoint not specified")
    end

    local route = nil
    local group = getGroup( controllable )
    if ( group == nil ) then
        return exitWarning("DirectTo-? :: cannot resolve group: "..Dump(controllable))
    end

    route = group:CopyRoute()
    if (route == nil) then
        return exitWarning("DirectTo-" .. group.GroupName .." :: cannot resolve route from controllable: "..Dump(controllable)) end

    local wpIndex = nil
    if (isString(waypoint)) then
        local wp = FindWaypointByName( route, waypoint )
        if (wp == nil) then
            return exitWarning("DirectTo-" .. group.GroupName .." :: no waypoint found with name '"..waypoint.."'") end

        wpIndex = wp.index
    elseif (isNumber(waypoint)) then
        wpIndex = waypoint
    else
        return exitWarning("DirectTo-" .. group.GroupName .." :: cannot resolved steerpoint: "..Dump(waypoint))
    end

    local directToRoute = {}
    for i=wpIndex,#route,1 do
        table.insert(directToRoute, route[i])
    end

    if setRoute == true then
        SetRoute(group, directToRoute)
    end
    return directToRoute
end

function ChangeSpeed( controllable, changeMPS )

Debug("ChangeSpeed :: changeMPS: " .. Dump(changeMPS))
    local validGroup = getGroup(controllable)
    if not validGroup then
        return Error("ChangeSpeed-? :: `controllable` must specify a unit or group, but was: " .. DumpPretty(controllable))
    end
    if not isNumber(changeMPS) then
        return Error("ChangeSpeed-? :: `changeMPS` must be number, but was: " .. DumpPretty(changeMPS))
    end
    local speedMPS = controllable:GetVelocityMPS()
Debug("ChangeSpeed :: controllable: " .. controllable.UnitName .. " :: speedMPS: " .. Dump(speedMPS))
    local speedMPS = speedMPS + changeMPS
Debug("ChangeSpeed :: controllable: " .. controllable.UnitName .. " :: changeMPS: " .. Dump(speedMPS))
    validGroup:SetSpeed(speedMPS, true)
Debug("ChangeSpeed :: sets speed: " .. Dump(speedMPS))
--     local controller = controllable:_GetController()
--     if controller then 
-- Debug("ChangeSpeed :: sets speed: " .. Dump(speedMPS))
--         controller:setSpeed(speedMPS)
--     end
    return controllable
end

function getGroupClosestUnit(group, location)
    local loc = DCAF.Location.Resolve(location)
    if not loc then
        error("GROUP:GetClosestUnit :: cannot resolve #DCAF.Location from: " .. DumpPretty(location)) end

    local coord = loc:GetCoordinate()
    local minDistance = 65535
    local closestUnit
    for _, unit in ipairs(self:GetUnits()) do
        local coordUnit = unit:GetCoordinate()
        if coordUnit then
            local distance = coord:Get2DDistance(coordUnit)
            if distance < minDistance then
                minDistance = distance
                closestUnit = unit
            end
        end
    end
    return closestUnit
end

--- Gets the unit that is closest to a specified coordinate
function GROUP:GetClosestUnit(location)
    return getGroupClosestUnit(self, location)
end

function _missionEventsAircraftFuelStateMonitor:Start(key, units, fuelState, func)

    local monitored = _missionEventsAircraftFuelStateMonitor.Monitored[key]
    if monitored then
        if  monitored.State == fuelState then
            return errorOnDebug("MissionEvents:OnFuelState :: key was already monitored for same fuel state ("..Dump(fuelState)..")") end
    else
        monitored = {}
        _missionEventsAircraftFuelStateMonitor.Monitored[key] = monitored
    end

    local info = DCAF.clone(_missionEventsAircraftFuelStateMonitor.UnitInfo)
    info.Units = units
    info.State = fuelState
    info.Func = func
    _missionEventsAircraftFuelStateMonitor.CountMonitored = _missionEventsAircraftFuelStateMonitor.CountMonitored + 1
    table.insert(monitored, info)

    if self.Timer then
        return end

    local function monitorFuelStates()
        local triggeredKeys = {}
        for key, monitored in pairs(_missionEventsAircraftFuelStateMonitor.Monitored) do
            for _, info in ipairs(monitored) do
                for index, unit in pairs(info.Units) do
                    local state = unit:GetFuel()
-- Debug("monitor fuel state :: unit: " .. unit.UnitName .. " :: state: " .. Dump(state) .. " :: info.State: " .. Dump(info.State))
                    if state == nil or info.State == nil then
                        -- stop monitoring (unit was probably despawned)
                        table.insert(triggeredKeys, { Key = key, Index = index })
                    elseif state <= info.State then
-- Debug("monitor fuel state :: TRIGGER :: unit: " .. unit.UnitName .. " :: state: " .. Dump(state) .. " :: info.State: " .. Dump(info.State))
-- Debug("triggers onfuel state :: unit: " .. unit.UnitName .. " :: state: " .. Dump(state) .. " :: info.State: " .. Dump(info.State))
                        info.Func(unit)
                        table.insert(triggeredKeys, { Key = key, Index = index })
                    end
                end
            end
        end

        -- end triggered keys ...
        for i = #triggeredKeys, 1, -1 do
            local triggered = triggeredKeys[i]
            self:End(triggered.Key, triggered.Index)
        end
    end

    self.Timer = TIMER:New(monitorFuelStates):Start(1, 7)
end

function _missionEventsAircraftFuelStateMonitor:End(key, index)

    if not _missionEventsAircraftFuelStateMonitor.Monitored[key] then
        return errorOnDebug("MissionEvents:OnFuelState :: key was not monitored")
    else
        local monitored = _missionEventsAircraftFuelStateMonitor.Monitored[key]
        local info = monitored[index]
        Trace("MissionEvents:OnFuelState :: " .. key .. "/state("..tostring(info.State)..") :: ENDS")
        table.remove(monitored, index)
        _missionEventsAircraftFuelStateMonitor.CountMonitored = _missionEventsAircraftFuelStateMonitor.CountMonitored - 1
        if #monitored == 0 then
            _missionEventsAircraftFuelStateMonitor.Monitored[key] = nil
        end
    end

    if not self.Timer or _missionEventsAircraftFuelStateMonitor.CountMonitored > 0 then
        return end

    Delay(2, function()
        self.Timer:Stop()
        self.Timer = nil
    end)
end

function MissionEvents:OnFuelState( controllable, nFuelState, func )
    if not isNumber(nFuelState) or nFuelState < 0 or nFuelState > 1 then
        error("MissionEvents:OnFuelState :: invalid/unassigned `nFuelState`: " .. DumpPretty(nFuelState)) end

    local units = {}
    local key
    local unit = getUnit(controllable)
    if not unit then
        local group = getGroup(controllable)
        if not group then
            error("MissionEvents:OnFuelState :: could not resolve a unit or group from " .. DumpPretty(controllable)) end
        units = group:GetUnits()
        key = group.GroupName
    else
        key = unit.UnitName
        table.insert(units, unit)
    end
    Trace("MissionEvents:OnFuelState :: " .. key .. " :: state: " .. Dump(nFuelState) .. " :: BEGINS")
    _missionEventsAircraftFuelStateMonitor:Start(key, units, nFuelState, func)
end

------------------------------- [ EVENT PRE-REGISTRATION / LATE ACTIVATION ] -------------------------------
--[[
    This api allows Storylines to accept delegates and postpone their registration
    until the Storyline runs
 ]]

 local DCAFEventActivation = {  -- use to pre-register event handler, to be activated when Storyline runs
    eventName = nil,         -- string (name of MissionEvents:OnXXX function )
    func = nil,              -- event handler function
    notifyFunc = nil,        -- (optional) callback handler, for notifying the event was activated
    insertFirst = nil,       -- boolean; passed to event delegate registration (see StorylineEventDelegate:ActivateFor)
    args = nil                -- (optional) arbitrary arguments with contextual meaning
}

local _DCAFEvents_lateActivations = {} -- { key = storyline name, value = { -- list of <DCAFEventActivation> } }

DCAFEvents = {
    OnAircraftTookOff = "OnAircraftTookOff",
    OnAircraftLanded = "OnAircraftLanded",
    OnGroupDiverted = "OnGroupDiverted",
    OnGroupEntersZone = "OnGroupEntersZone",
    OnGroupInsideZone = "OnGroupInsideZone",
    OnGroupLeftZone = "OnGroupLeftZone",
    OnUnitEntersZone = "OnUnitEntersZone",
    OnUnitInsideZone = "OnUnitInsideZone",
    OnUnitLeftZone = "OnUnitLeftZone",
    OnUnitDestroyed = "OnUnitDestroyed",
    -- todo add more events ...
}

local _DCAFEvents = {
    [DCAFEvents.OnAircraftTookOff] = function(func, insertFirst) MissionEvents:OnAircraftTakeOff(func, insertFirst) end,
    [DCAFEvents.OnAircraftLanded] = function(func, insertFirst) MissionEvents:OnAircraftLanded(func, insertFirst) end,
    [DCAFEvents.OnGroupDiverted] = function(func, insertFirst) MissionEvents:OnGroupDiverted(func, insertFirst) end,
    [DCAFEvents.OnUnitDestroyed] = function(func, insertFirst) MissionEvents:OnUnitDestroyed(func, insertFirst) end,
    -- zone events
    [DCAFEvents.OnGroupEntersZone] = function(func, insertFirst, args) MissionEvents:OnGroupEntersZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnGroupInsideZone] = function(func, insertFirst, args) MissionEvents:OnGroupInsideZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnGroupLeftZone] = function(func, insertFirst, args) MissionEvents:OnGroupLeftZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnUnitEntersZone] = function(func, insertFirst, args) MissionEvents:OnUnitEntersZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnUnitInsideZone] = function(func, insertFirst, args) MissionEvents:OnUnitInsideZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnUnitLeftZone] = function(func, insertFirst, args) MissionEvents:OnUnitLeftZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    -- todo add more events ...
}

function _DCAFEvents:Activate(activation)
    local activator = _DCAFEvents[activation.eventName]
    if activator then
        activator(activation.func, activation.insertFirst, activation.args)

        -- notify event activation, if callback func is registered ...
        if activation.notifyFunc then
            activation.notifyFunc({
                EventName = activation.eventName,
                Func = activation.func,
                InsertFirst = activation.insertFirst
            })
        end
    else
        error("DCAFEvents:Activate :: cannot activate delegate for event '" .. activation.eventName .. " :: event is not supported")
    end
end

function _DCAFEvents:ActivateFor(source)
    local activations = _DCAFEvents_lateActivations[source]
    if not activations then
        return
    end
    _DCAFEvents_lateActivations[source] = nil
    for _, activation in ipairs(activations) do
        _DCAFEvents:Activate(activation)
    end
end

function DCAFEvents:PreActivate(source, eventName, func, onActivateFunc, args)
    if source == nil then
        error("DCAFEvents:LateActivate :: unassigned source") end

    if not isAssignedString(eventName) then
        error("DCAFEvents:LateActivate :: unsupported eventName value: " .. Dump(eventName)) end

    if not DCAFEvents[eventName] then
        error("DCAFEvents:LateActivate :: unsupported event: " .. Dump(eventName)) end

    local activation = deepCopy(DCAFEventActivation)
    activation.eventName = eventName
    activation.func = func
    activation.onActivateFunc = onActivateFunc
    activation.args = args
    local activations = _DCAFEvents_lateActivations[source]
    if not activations then
        activations = {}
        _DCAFEvents_lateActivations[source] = activations
    end
    table.insert(activations, activation)
end

function DCAFEvents:ActivateFor(source) _DCAFEvents:ActivateFor(source) end

--------------------------------------------- [[ ZONE EVENTS ]] ---------------------------------------------

local ZoneEventState = {
    Outside = 1,
    Inside = 2,
    Left = 3,
    _countZoneEventZones = 0,        -- no. of 'zone centric' zone events (as opposed to 'object centric')
    _timer = nil,
}

local ZoneEventStrategy = {
    Named = 'named',
    Any = 'any'
}

local ZoneEventType = {
    Enter = 'enter',
    Inside = 'inside',
    Left = 'left'
}

function ZoneEventType.isValid(value)
    return value == ZoneEventType.Enter
        or value == ZoneEventType.Inside
        or value == ZoneEventType.Left
end

local ZoneEventObjectType = {
    Any = 'any',
    Group = 'group',
    Unit = 'unit'
}

-- local ObjectZoneState = { -- keeps track of all groups/units state in relation to zones
--     Outside = "outside",
--     Inside = "inside",
--     Records = {
--         -- key = group/unit name, value = {
--         --   key = zone name, value = <ZoneEventType>
--         -- }
--     }

-- }

-- function ObjectZoneState:Set(object, zone, state)
--     local name = nil
--     if isGroup(object) then
--         name = object.GroupName
--     else
--         name = object.UnitName
--     end
--     local record = ObjectZoneState.Records[name]
--     if not record then
--         record = {}
--         ObjectZoneState.Records[name] = state
--         record[zone.Name] = state
--         return
--     end
--     record[zone.Name] = state
-- end

-- function ObjectZoneState:Get(object, zone)
--     local name = nil
--     if isGroup(object) then
--         name = object.GroupName
--     else
--         name = object.UnitName
--     end
--     local record = ObjectZoneState.Records[name]
--     if not record then
--         return ObjectZoneState.Outside
--     end
--     local state = record[zone.Name]
--     return state or ObjectZoneState.Outside
-- end

local ZoneEvent = {
    objectName = nil,                -- string; name of group / unit (nil if objectType = 'any')
    objectType = nil,                -- <ZoneEventObjectType>
    object = nil,                    -- UNIT or GROUP
    eventType = nil,                 -- <MonitoredZoneEventType>
    zoneName = nil,                  -- string; name of zone
    zone = nil,                      -- ZONE
    func = nil,                      -- function to be invoked when event triggers
    state = ZoneEventState.Outside,  -- <MonitoredZoneEventState>
    isZoneCentered = false,          -- when set, the ZoneEvent:EvaluateForZone() functon is invoked; otherwise ZoneEvent:EvaluateForObject()
    continous = false,               -- when set, the event is not automatically removed when triggered
    filter = nil,                    --
}

local ConsolidatedZoneCentricZoneEventsInfo = {
    zone = nil,                      -- the monitored zone
    zoneEvents = {},                 -- list of <ZoneEvent>
}

local ObjectCentricZoneEvents = {
    -- list of <ZoneEvent>
}

local FilterCentricZoneEvents = { -- events with Filter (must be resolved individually)
    -- list of <ZoneEvent>
}

local ConsolidatedZoneCentricZoneEvents = { -- events with no Filter attached (can be consolidated for same zone)
    -- key = zoneName,
    -- value = <ConsolidatedZoneCentricZoneEventsInfo>
}

local ZoneEventArgs = {
    EventType = nil,          -- <ZoneEventType>
    ZoneName = nil,           -- string
}

ZoneFilter = {
    _type = "ZoneEventArgs",
    _template = true,
    Item = nil,
    Coalitiona = nil,         -- (optional) one or more <Coalition>
    GroupTypes = nil,         -- (optional) one or more <GroupType>
    Continous = nil,
}

function ZoneFilter:Ensure()
    if not self._template then
        return self end

    local filter = DCAF.clone(ZoneFilter)
    filter._template = nil
    return filter
end

local function addTypesToZoneFilter(filter, item)
    if item == nil then
        return filter
    end
    if item:IsAirPlane() then
        filter.Type = GroupType.Airplane
    elseif item:IsHelicopter() then
        filter.Type = GroupType.Helicopter
    elseif item:IsShip() then
        filter.Type = GroupType.Ship
    elseif item:IsGround() then
        filter.Type = GroupType.Ground
    end
    return filter
end

function ZoneFilter:Group(group)
    local filter = self:Ensure()
    if group == nil then
        return filter
    end
    filter.Item = getGroup(group)
    if not filter.Item then
        error("ZoneFilter:Group :: cannot resolve group from " .. Dump(group)) end

    return addTypesToZoneFilter(filter, filter.Item)
end

function ZoneFilter:Unit(unit)
    local filter = self:Ensure()
    if unit == nil then
        return filter
    end
    filter.Item = unit
    if not filter.Item then
        error("ZoneFilter:Unit :: cannot resolve unit from " .. Dump(unit)) end

    return addTypesToZoneFilter(filter, filter.Item)
end

function ZoneFilter:Coalitions(...)
    local coalitions = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then
            if not Coalition.Resolve(v) then
                error("ZoneOptions:Coalitions :: invalid coalition: " .. Dump(v))
            end
            table.insert(coalitions, v)
        end
    end

    if #coalitions == 0 then
        error("ZoneFilter:Coalitions :: no coalition(s) specified") end

    local filter = self:Ensure()
    filter.Coalitions = coalitions
    return filter
end

function ZoneFilter:GroupType(type)
    if not isAssignedString(type) then
        error("ZoneFilter:GroupType :: group type was unassigned")  end

    if not GroupType.IsValid(type) then
        error("ZoneFilter:GroupType :: invalid group type: " .. Dump(v))  end

    local filter = self:Ensure()
    filter.GroupType = type
    filter.Item = nil
    return filter
end

function ConsolidatedZoneCentricZoneEventsInfo:New(zone, zoneName)
    local info = DCAF.clone(ConsolidatedZoneCentricZoneEventsInfo)
    info.zone = zone
    ZoneEventState._countZoneEventZones = ZoneEventState._countZoneEventZones + 1
    return info
end

function ConsolidatedZoneCentricZoneEventsInfo:Scan()
    local setGroup = SET_GROUP:New():FilterZones({ self.zone }):FilterActive():FilterOnce()
    local groups = {}
    setGroup:ForEachGroup(
        function(g)
            table.insert(groups, g)
        end
    )
    return groups
end

function ZoneEventArgs:New(zoneEvent)
    local args = deepCopy(ZoneEventArgs)
    args.EventType = zoneEvent.eventType
    args.ZoneName = zoneEvent.zoneName
    return args
end

function ZoneEventArgs:End()
    self._terminateEvent = true
    return self
end

local function stopMonitoringZoneEventsWhenEmpty()
    if ZoneEventState._timer ~= nil and #ObjectCentricZoneEvents == 0 and #FilterCentricZoneEvents == 0 and ZoneEventState._countZoneEventZones == 0 then
        Trace("stopMonitoringZoneEventsWhenEmpty :: mission zone events monitoring stopped")
        ZoneEventState._timer:Stop()
        ZoneEventState._timer = nil
    end
end

local function startMonitorZoneEvents()

    local function monitor()

        -- object-centric zone events ...
        local removeZoneEvents = {}
        for _, zoneEvent in ipairs(ObjectCentricZoneEvents) do
            if zoneEvent:EvaluateForObject() then
                table.insert(removeZoneEvents, zoneEvent)
            end
        end
        for _, zoneEvent in ipairs(removeZoneEvents) do
            zoneEvent:Remove()
        end

        -- filter-centric zone events ...
        removeZoneEvents = {}
        for _, zoneEvent in ipairs(FilterCentricZoneEvents) do
            if zoneEvent:EvaluateForFilter() then
                table.insert(removeZoneEvents, zoneEvent)
            end
        end
        for _, zoneEvent in ipairs(removeZoneEvents) do
            zoneEvent:Remove()
        end

        -- zone-centric zone events ...
        removeZoneEvents = {}
        for zoneName, zcEvent in pairs(ConsolidatedZoneCentricZoneEvents) do
            local groups = zcEvent:Scan()
            if #groups > 0 then
                for _, zoneEvent in ipairs(zcEvent.zoneEvents) do
                    if zoneEvent:TriggerMultipleGroups(groups) then
                        table.insert(removeZoneEvents, zoneEvent)
                    end
                end
            end
            for _, zoneEvent in ipairs(removeZoneEvents) do
                local index = tableIndexOf(zcEvent.zoneEvents, zoneEvent)
                if index < 1 then
                    error("startMonitorZoneEvents_monitor :: cannot remove zone event :: event was not found in the internal list") end

                table.remove(zcEvent.zoneEvents, index)
                if #zcEvent.zoneEvents == 0 then
                    ConsolidatedZoneCentricZoneEvents[zoneName] = nil
                    ZoneEventState._countZoneEventZones = ZoneEventState._countZoneEventZones - 1
                end
            end
        end
        stopMonitoringZoneEventsWhenEmpty()
    end

    if not ZoneEventState._timer then
        ZoneEventState._timer = TIMER:New(monitor):Start(1, 1)
    end
end

function ZoneEvent:Trigger(object, objectName)
    local event = ZoneEventArgs:New(self)
    if isGroup(object) then
        event.IniGroup = self.object
        event.IniGroupName = event.IniGroup.GroupName
    elseif isUnit(object) then
        event.IniUnit = self.object
        event.IniUnitName = self.object.UnitName
        event.IniGroup = self.object:GetGroup()
        event.IniGroupName = event.IniGroup.GroupName
    end
    self.func(event)
    return not self.continous or event._terminateEvent
end

function ZoneEvent:TriggerMultipleGroups(groups)
    local event = ZoneEventArgs:New(self)
    event.IniGroups = groups
    self.func(event)
    return not self.continous or event._terminateEvent
end

function ZoneEvent:TriggerMultipleUnits(units)
    local event = ZoneEventArgs:New(self)
    event.IniUnits = units
    self.func(event)
    return not self.continous or event._terminateEvent
end

local function isAnyGroupUnitInZone(group, zone)
    local units = group:GetUnits()
    if not units then
        return end

    for _, unit in ipairs(units) do
        if unit:IsInZone(zone) then
            return true
        end
    end
    return false
end

local function getGrupsInZone(group, zone, filter)
    -- todo
    -- local units = group:GetUnits()
    -- for _, unit in ipairs(units) do
    --     if unit:IsInZone(zone) then
    --         return true
    --     end
    -- end
    -- return false
end

function ZoneEvent:EvaluateForObject()
    -- 'named object perspective'; use <object> to check zone event ...
    -- entered zone ....
    if self.eventType == ZoneEventType.Enter then
        if self.objectType == 'group' then
            if isAnyGroupUnitInZone(self.object, self.zone) then
                return self:Trigger(self.object, self.objectName)
            end
        elseif self.object:IsInZone(self.zone) then
            return self:Trigger(self.object, self.objectName)
        end
        return false
    end

    -- left zone ...
    if self.eventType == ZoneEventType.Left then
        local isInZone = nil
        if self.objectType == ZoneEventObjectType.Group then
            isInZone = isAnyGroupUnitInZone(self.object, self.zone)
        else
            isInZone = self.object:IsInZone(self.zone)
        end
        if isInZone then
            self.state = ZoneEventState.Inside
            return false
        elseif self.state == ZoneEventState.Inside then
            return self:Trigger(self.object, self.objectName)
        end
        return false
    end

    -- inside zone ...
    if self.eventType == ZoneEventType.Inside then
        if self.objectType == ZoneEventObjectType.Group then
            if isAnyGroupUnitInZone(self.object, self.zone) then
                return self:Trigger(self.object, self.objectName)
            end
        elseif self.object:IsInZone(self.zone) then
            return self:Trigger(self.object, self.objectName)
        end
    end
    return false
end

function ZoneEvent:EvaluateForFilter()
    -- 'filter perspective'; use filtered SET_GROUP or SET_UNIT to check zone event ...
    local set = nil
    if self.objectType == ZoneEventObjectType.Group then
        set  = SET_GROUP:New():FilterZones({ self.zone })
    else
        set  = SET_UNIT:New():FilterZones({ self.zone })
    end

    -- filter coalitions ...
    if self.filter.Coalitions then
        set:FilterCoalitions(self.filter.Coalitions)
    end

    -- filter group type ...
    local type = self.filter.GroupType
    if type == GroupType.Air then
        set:FilterCategoryAirplane()
        set:FilterCategoryHelicopter()
    elseif type == GroupType.Airplane then
        set:FilterCategoryAirplane()
    elseif type == GroupType.Helicopter then
        set:FilterCategoryHelicopter()
    elseif type == GroupType.Ship then
        set:FilterCategoryShip()
    elseif type == GroupType.Ground then
        set:FilterCategoryGround()
    elseif type == GroupType.Structure then
        set:FilterCategoryStructure()
    end

    -- scan and trigger events if groups/units where found ...
    set:FilterActive():FilterOnce()
    if self.objectType == ZoneEventObjectType.Group then
        local groups = {}
        set:ForEachGroupAlive(function(group) table.insert(groups, group) end)
        if #groups > 0 then
            return self:TriggerMultipleGroups(groups)
        end
    elseif self.objectType == ZoneEventObjectType.Unit then
        local units = {}
        set:ForEachUnitAlive(function(group)
            table.insert(units, group)
        end)
        if #units > 0 then
            return self:TriggerMultipleUnits(units)
        end
    end
    return false
end

function ZoneEvent:IsFiltered()
    return self.filter ~= nil
end

function ZoneEvent:Insert()
    if self.isZoneCentered then
        if self:IsFiltered() then
            self._eventList = FilterCentricZoneEvents
            table.insert(FilterCentricZoneEvents, self)
        else
            local info = ConsolidatedZoneCentricZoneEvents[self.zoneName]
            if not info then
                info = ConsolidatedZoneCentricZoneEventsInfo:New(self.zone, self.zoneName)
                ConsolidatedZoneCentricZoneEvents[self.zoneName] = info
            end
            self._eventList = FilterCentricZoneEvents
            table.insert(info.zoneEvents, self)
        end
    else
        self._eventList = ObjectCentricZoneEvents
        table.insert(ObjectCentricZoneEvents, self)
    end
-- Debug("ZoneEvent:Insert :: #FilterCentricZoneEvents: " .. Dump(#FilterCentricZoneEvents))
-- Debug("ZoneEvent:Insert :: #ObjectCentricZoneEvents: " .. Dump(#ObjectCentricZoneEvents))
-- Debug("ZoneEvent:Insert :: #ConsolidatedZoneCentricZoneEvents: " .. Dump(#ConsolidatedZoneCentricZoneEvents))
    startMonitorZoneEvents()
end

function ZoneEvent:Remove()
    if self._eventList then
        local index = tableIndexOf(self._eventList, self)
        if not index then
            error("ZoneEvent:Remove :: cannot find zone event")
        end
        table.remove(self._eventList, index)
    end
    -- if self.objectType ~= ZoneEventObjectType.Any then
    --     local index = tableIndexOf(ObjectCentricZoneEvents, self) obsolete
    --     if not index then
    --         error("ZoneEvent:Remove :: cannot find zone event")
    --     end
    --     table.remove(ObjectCentricZoneEvents, index)
    -- end
    stopMonitoringZoneEventsWhenEmpty()
end

function ZoneEvent:NewForZone(objectType, eventType, zone, func, continous, filter--[[ , makeZczes ]])
    local zoneEvent = DCAF.clone(ZoneEvent)
    zoneEvent.isZoneCentered = true
    zoneEvent.objectType = objectType
    if not ZoneEventType.isValid(eventType) then
        error("MonitoredZoneEvent:New :: unexpected event type: " .. Dump(eventType))
    end
    zoneEvent.eventType = eventType

    if isAssignedString(zone) then
        zoneEvent.zone = ZONE:FindByName(zone)
        if not zoneEvent.zone then
            error("MonitoredZoneEvent:New :: could not find zone: '" .. Dump(zone) .. "'")
        end
    elseif isZone(zone) then
        zoneEvent.zone = zone
    else
        error("MonitoredZoneEvent:New :: unexpected/unassigned zone: " .. Dump(zone))
    end
    if not zoneEvent.zone then
        error("MonitoredZoneEvent:New :: unknown zone: " .. Dump(zone))
    end
    zoneEvent.zoneName = zone

    if not isFunction(func) then
        error("MonitoredZoneEvent:New :: unexpected/unassigned callack function: " .. Dump(func))
    end
    zoneEvent.func = func

    if eventType == ZoneEventType.Inside and not isBoolean(continous) then
        continous = true
    end
    if not isBoolean(continous) then
        continous = false
    end
    zoneEvent.continous = continous
    zoneEvent.filter = filter
    return zoneEvent
end

function ZoneEvent:NewForObject(object, objectType, eventType, zone, func, continous)
    local zoneEvent = ZoneEvent:NewForZone(objectType, eventType, zone, func, continous, nil, false)
    zoneEvent.isZoneCentered = false
    if objectType == 'unit' then
        zoneEvent.object = getUnit(object)
        if not zoneEvent.object then
            error("MonitoredZoneEvent:New :: cannot resolve UNIT from " .. Dump(object))
        end
    elseif objectType == 'group' then
        zoneEvent.object = getGroup(object)
        if not zoneEvent.object then
            error("MonitoredZoneEvent:New :: cannot resolve GROUP from " .. Dump(object))
        end
    elseif objectType ~= ZoneEventStrategy.Any then
        error("MonitoredZoneEvent:New :: cannot resolve object from " .. Dump(object))
    end
    zoneEvent.objectType = objectType

    if eventType == ZoneEventType.Inside and not isBoolean(continous) then
        continous = true
    end
    if not isBoolean(continous) then
        continous = false
    end
    zoneEvent.continous = continous
    return zoneEvent
end

function MissionEvents:OnUnitEntersZone( unit, zone, func, continous )
    if unit == nil then
        error("MissionEvents:OnUnitEntersZone :: unit was unassigned") end

    local zoneEvent = ZoneEvent:NewForObject(
        unit,
        ZoneEventObjectType.Unit,
        ZoneEventType.Enter,
        zone,
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnUnitEntersZone( func )
    -- todo Implement MissionEvents:EndOnUnitEntersZone
end

function MissionEvents:OnUnitInsideZone( unit, zone, func, continous )
    if unit == nil then
        error("MissionEvents:OnUnitInsideZone :: unit was unassigned") end

    if not isBoolean(continous) then
        continous = true
    end
    local zoneEvent = ZoneEvent:NewForObject(
        unit,
        ZoneEventObjectType.Unit,
        ZoneEventType.Inside,
        zone,
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnUnitInsideZone( func )
    -- todo Implement MissionEvents:EndOnUnitInsideZone
end

function MissionEvents:OnUnitLeftZone( unit, zone, func, continous )
    if unit == nil then
        error("MissionEvents:OnUnitLeftZone :: unit was unassigned") end

    local zoneEvent = ZoneEvent:NewForObject(
        unit,
        ZoneEventObjectType.Unit,
        ZoneEventType.Left,
        zone,
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnUnitLeftZone( func )
    -- todo Implement MissionEvents:EndOnUnitLeftZone
end

function MissionEvents:OnGroupEntersZone( group, zone, func, continous, filter )
    local zoneEvent = nil
    if group == nil then
        MissionEvents:OnGroupInsideZone(group, zone, func, continous, filter)
    else
        local zoneEvent = ZoneEvent:NewForObject(
            group,
            ZoneEventObjectType.Group,
            ZoneEventType.Enter,
            zone,
            func,
            continous)
        zoneEvent:Insert()
    end
end
function MissionEvents:EndOnGroupEntersZone( func )
    -- todo Implement MissionEvents:EndOnGroupEntersZone
end

function MissionEvents:OnGroupInsideZone( group, zone, func, continous, filter )
    if not isBoolean(continous) then
        continous = true
    end
    local zoneEvent = nil
    if group ~= nil then
        zoneEvent = ZoneEvent:NewForObject(
            group,
            ZoneEventObjectType.Group,
            ZoneEventType.Inside,
            zone,
            func,
            continous)
    else
        zoneEvent = ZoneEvent:NewForZone(
            ZoneEventObjectType.Group,
            ZoneEventType.Inside,
            zone,
            func,
            continous,
            filter)
    end
    zoneEvent:Insert()
end
function MissionEvents:EndOnGroupInsideZone( func )
    -- todo Implement MissionEvents:EndOnGroupInsideZone
end

--- Invokes a functiob when a specified group leaves a specified zone
-- @param #Any group - #GROUP or GROUP name (string)
-- @param #Any zone - #ZONE or ZONE name (string)
-- @param #Any func - #function to be called back
-- @param #boolean continous - (optional; default = true) Specifies whether event should remain active after first occurance (otherwise it will be removed)
function MissionEvents:OnGroupLeftZone( group, zone, func, continous )
    if group == nil then
        error("MissionEvents:OnGroupLeftZone :: group was unassigned") end

    local zoneEvent = ZoneEvent:NewForObject(
        group,
        ZoneEventObjectType.Group,
        ZoneEventType.Left,
        zone,
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnGroupLeftZone( func )
    -- todo Implement MissionEvents:EndOnGroupLeftZone
end

---------------------------------------- NAVY ----------------------------------------

local DCAFCarriers = {
    Count = 0,
    Carriers = {
        -- dictionary
        --   key    = carrier unit name
        --   valuer = #DCAF.Carrier
    }
}

DCAF.Carrier = {
    IsStrict = false,         -- #boolean; when set, an error will be thrown if carrier cannt be resolved (not setting it allows referencing carrier that might not be needed in a particular miz)
    Group = nil,              -- #GROUP (MOOSE object) - the carrier group
    Unit = nil,               -- #UNIT (MOOSE object) - the carrier unit
    DisplayName = nil,        -- #string; name to be used in menus and communication
    TACAN = nil,              -- #DCAF_TACAN; represents the carrier's TACAN (beacon)
    ICLS = nil,               -- #DCAF_ICLS; represents the carrier's ICLS system
    RecoveryTankers = {},     -- { list of #DCAF_RecoveryTankerInfo (not yet activated, gets removed when activated) }
    FinalBearingOffset = 0    -- offset angle of landing (eg. US suprcarriers offset is 10 degrees). This is used to calculate heading into wind (wind direction + offset)
}

local DCAF_Carrier_Database = {
    ["CVN_71"] = {
        FinalBearingOffset = 10,
        TACAN = {
            Channel = 71,
            Mode = 'X',
            Ident = "C71"
        },
        ICLS = {
            Channel = 1
        },
        Frequencies = {
            Marshal = 305.00,
            LandLaunch = 305.10,
        }
    },
    ["CVN_72"] = {
        FinalBearingOffset = 10,
        TACAN = {
            Channel = 71,
            Mode = 'X',
            Ident = "C72"
        },
        ICLS = {
            Channel = 1
        },
        Frequencies = {
            Marshal = 305.00,
            LandLaunch = 305.10,
        }
    },
    ["CVN_73"] = {
        FinalBearingOffset = 10,
        TACAN = {
            Channel = 71,
            Mode = 'X',
            Ident = "C73"
        },
        ICLS = {
            Channel = 1
        },
        Frequencies = {
            Marshal = 305.00,
            LandLaunch = 305.10,
        }
    },
    ["CVN_74"] = {
        FinalBearingOffset = 10,
        TACAN = {
            Channel = 71,
            Mode = 'X',
            Ident = "C74"
        },
        ICLS = {
            Channel = 1
        },
        Frequencies = {
            Marshal = 305.00,
            LandLaunch = 305.10,
        }
    },
    ["CVN_75"] = {
        FinalBearingOffset = 10,
        TACAN = {
            Channel = 71,
            Mode = 'X',
            Ident = "C75"
        },
        ICLS = {
            Channel = 1
        },
        Frequencies = {
            Marshal = 305.00,
            LandLaunch = 305.10,
        }
    },
    ["Forrestal"] = {
        FinalBearingOffset = 10,
        TACAN = {
            Channel = 71,
            Mode = 'X',
            Ident = "C59"
        },
        ICLS = {
            Channel = 1
        },
        Frequencies = {
            Marshal = 305.00,
            LandLaunch = 305.10,
        }
    },
    ["LHA_Tarawa"] = {
        FinalBearingOffset = 0,
        TACAN = {
            Channel = 73,
            Mode = 'X',
            Ident = "LHA"
        },
        ICLS = {
            Channel = 3
        },
        Frequencies = {
            Marshal = 301.00,
            LandLaunch = 301.10,
        }
    },
}

function DCAF_Carrier_Database:GetTACAN(unit)
    local data = DCAF_Carrier_Database[unit:GetTypeName()]
    if data then
        return data.TACAN.Channel, data.TACAN.Mode, data.TACAN.Ident
    end
end

function DCAF_Carrier_Database:GetICLS(unit)
    local data = DCAF_Carrier_Database[unit:GetTypeName()]
    if data then
        return data.ICLS.Channel
    end
end

function DCAF_Carrier_Database:GetMarshalFrequency(unit)
    local data = DCAF_Carrier_Database[unit:GetTypeName()]
    if data then
        return data.Frequencies.Marshal
    end
end

function DCAF_Carrier_Database:GetLandLaunchFrequency(unit)
    local data = DCAF_Carrier_Database[unit:GetTypeName()]
    if data then
        return data.Frequencies.LandLaunch
    end
end

function DCAFCarriers:Add(carrier)
    -- ensure carrier was not already added ...
    local exists = DCAFCarriers[carrier.Unit.UnitName]
    if exists then
        error("DCAFCarriers:Add :: carrier was already added") end

    DCAFCarriers.Carriers[carrier.Unit.UnitName] = carrier
    DCAFCarriers.Count = DCAFCarriers.Count + 1
    return carrier
end

DCAF_TACAN = {
    Group = nil,          -- #GROUP
    Unit = nil,           -- #UNIT
    Channel = nil,        -- #number (eg. 73, for channel 73X)
    Mode = nil,           -- #string (eg. 'X' for channel 73X)
    Ident = nil,          -- #string (eg. 'C73')
    Beaering = true       -- #boolean; Emits bearing information when set
}

DCAF_ICLS = {
    Group = nil,          -- #GROUP
    Unit = nil,           -- #UNIT
    Channel = nil,        -- #number (eg. 11, for channel 11)
    Ident = nil,          -- #string (eg. 'C73')
}

local DCAF_RecoveryTankerState = {
    Parked = "Parked",
    Launched = "Launched",
    RendezVous = "RendezVous",
    RTB = "RTB"
}

local DCAF_RecoveryTanker = {
    Tanker = nil,         -- #RECOVERYTANKER (MOOSE)
    Group = nil,          -- #GROUP (MOOSE)
    IsLaunched = nil,     -- #boolean; True if tanbker has been launched
    OnLaunchedFunc = nil, -- #function; invoked when tanker gets launched
    State = DCAF_RecoveryTankerState.Parked,
    GroupMenus = {
        -- key = group name
        -- value = #MENU_GROUP_COMMAND (MOOSE)
    }
}

local function injectCarrierRouteCallbacks(carrier, waypoints)
    -- record passing each waypoint; this is needed for resuming route after heading into wind
    local CallbackIdent = "carrier_route_callback"
    waypoints = waypoints or getGroupRoute(carrier.Group)
    for i, wp in ipairs(waypoints) do
        if wp.task and wp.task.params and wp.task.params.tasks then
            tableRemoveWhere(wp.task.params.tasks, function(task)  return task.name == CallbackIdent  end)
        end
        WaypointCallback(wp, function()  carrier._lastWaypointIndex = i+1  end, nil, CallbackIdent)
    end
    return waypoints
end

function DCAF.Carrier:New(group, nsUnit, sDisplayName)
    local forGroup = getGroup(group)
    local carrier = DCAF.clone(DCAF.Carrier)
    if not forGroup then
        if DCAF.Carrier.IsStrict then
            error("DCAF.Carrier:New :: cannot resolve group from: " .. DumpPretty(group))
        end
        return carrier
    end

    local forUnit = resolveUnitInGroup(forGroup, nsUnit)
    -- todo: Ensure unit is actually a carrier!
    if isAssignedString(forUnit) then
        error("DCAF.Carrier:New :: cannot resolve unit from: " .. DumpPretty(nsUnit)) end

    if not isAssignedString(sDisplayName) then
        sDisplayName = forUnit.UnitName
    end

    local typeName = forUnit:GetTypeName()
    local data = DCAF_Carrier_Database[typeName]
    if data then
        carrier.FinalBearingOffset = data.FinalBearingOffset
    end
    carrier.Group = forGroup
    carrier.Unit = forUnit
    carrier.DisplayName = sDisplayName
    carrier._route = injectCarrierRouteCallbacks(carrier)
    carrier._lastWaypointIndex = 1

    local tacanChannel, tacanMode, tacanIdent = DCAF_Carrier_Database:GetTACAN(forUnit)
    if tacanChannel then
        carrier:SetTACAN(tacanChannel, tacanMode, tacanIdent)
    end
    local iclsChannel = DCAF_Carrier_Database:GetICLS(forUnit)
    if iclsChannel then
        carrier:SetICLS(iclsChannel)
    end
    setGroupRoute(carrier.Group, carrier._route)
    return DCAFCarriers:Add(carrier)
end

function DCAF.Carrier:IsEmpty()
    return self.Group == nil
end

function DCAF_TACAN:New(group, unit, nChannel, sMode, sIdent, bBearing)
    local tacan = DCAF.clone(DCAF_TACAN)
    tacan.Group = group
    tacan.Unit = unit or group:GetUnit(1)
    tacan.Channel = nChannel
    tacan.Mode = sMode
    tacan.Ident = sIdent
    if isBoolean(bBearing) then
        tacan.Bearing = bBearing end
    return tacan
end

function DCAF_TACAN:IsValidMode(mode)
    if not isAssignedString(mode) then
        error("DCAF_TACAN:IsValidMode :: `mode` must be assigned string but was: " .. DumpPretty(mode)) end

    local test = string.upper(mode)
    return test == 'X' or test == 'Y'
end

function DCAF.Carrier:ActivateTACAN()
    if not self.TACAN then
        return end

    CommandActivateTACAN(self.Group, self.TACAN.Channel, self.TACAN.Mode, self.TACAN.Ident, self.TACAN.Beaering, false, self.Unit)
    return self
end

function DCAF.Carrier:DeactivateTACAN(nDelay)
    if not self.TACAN then
        return end

    if isNumber(nDelay) and nDelay > 0 then
        Delay(nDelay, function()
            CommandDeactivateBeacon(self.Group)
        end)
    else
        CommandDeactivateBeacon(self.Group)
    end
    return self
end

function DCAF.Carrier:ActivateICLS()
    if not self.ICLS then
        return end

    CommandActivateICLS(self.Group, self.ICLS.Channel, self.ICLS.Ident, self.Unit)
    return self
end

function DCAF.Carrier:DeactivateICLS(nDelay)
    if not self.ICLS then
        return end

    if isNumber(nDelay) and nDelay > 0 then
        Delay(nDelay, function()
            CommandDeactivateICLS(self.Group)
        end)
    else
        CommandDeactivateICLS(self.Group)
    end
    return self
end

local function validateTACAN(nChannel, sMode, sIdent, errorPrefix)
    if not isNumber(nChannel) then
        error(errorPrefix .. " :: `nChannel` was unassigned") end
    if nChannel < 1 or nChannel > 99 then
        error(errorPrefix .. " :: `nChannel` was outside valid range (1-99)") end
    if not isAssignedString(sMode) then
        error(errorPrefix .. " :: `sMode` was unassigned") end
    if sMode ~= 'X' and sMode ~= 'Y' then
        error(errorPrefix .. " :: `sMode` was invalid (expected: 'X' or 'Y'") end
    return nChannel, sMode, sIdent
end

local function getCarrierWithTACANChannel(nChannel, sMode)
    for name, carrier in pairs(DCAFCarriers.Carriers) do
        local tacan = carrier.TACAN
        if tacan and tacan.Channel == nChannel and tacan.Mode == sMode then
            return name, carrier
        end
    end
end

local function getCarrierWithICLSChannel(nChannel)
    for name, carrier in pairs(DCAFCarriers.Carriers) do
        local icls = carrier.ICLS
        if icls and icls.Channel == nChannel then
            return name, carrier
        end
    end
end

function DCAF.Carrier:SetTACANInactive(nChannel, sMode, sIdent, bBearing)
    if self:IsEmpty() then
        return self end

    nChannel, sMode, sIdent = validateTACAN(nChannel, sMode, sIdent, "DCAF.Carrier:SetTACANInactive")
    local existingCarrier = getCarrierWithTACANChannel(nChannel, sMode)
    if existingCarrier and existingCarrier ~= self then
        error("Cannot set TACAN " .. tostring(nChannel) .. sMode .. " for carrier '" .. self.DisplayName .. "'. Channel is already in use by '" .. existingCarrier .. "'") end
    if self.TACAN then
        self:DeactivateTACAN()
    end
    self.TACAN = DCAF_TACAN:New(self.Group, self.Unit, nChannel, sMode, sIdent, bBearing)
    return self
end

function DCAF.Carrier:SetTACAN(nChannel, sMode, sIdent, bBearing, nActivateDelay)
    if self:IsEmpty() then
        return self end

    self:SetTACANInactive(nChannel, sMode, sIdent, bBearing)
    if isNumber(nActivateDelay) and nActivateDelay > 0 then
        Delay(nActivateDelay, function()
            self:ActivateTACAN()
        end)
    else
        self:ActivateTACAN()
    end
    return self
end

function DCAF.Carrier:SetICLSInactive(nChannel, sIdent)
    if not isNumber(nChannel) then
        error("DCAF.Carrier:WithTACAN :: `nChannel` was unassigned") end
    if nChannel < 1 or nChannel > 99 then
        error("DCAF.Carrier:WithTACAN :: `nChannel` was outside valid range (1-99)") end

    if self:IsEmpty() then
        return self end

    local existingCarrier = getCarrierWithICLSChannel(nChannel)
    if existingCarrier and existingCarrier ~= self then
        error("Cannot set ICLS " .. tostring(nChannel) .. " for carrier '" .. self.DisplayName .. "'. Channel is already in use by '" .. existingCarrier .. "'") end

    if self.ICLS then
        self:DeactivateICLS()
    end
    self.ICLS = DCAF.clone(DCAF_ICLS)
    self.ICLS.Group = self.Group
    self.ICLS.Unit = self.Unit
    self.ICLS.Channel = nChannel
    self.ICLS.Ident = sIdent
    return self
end

function DCAF.Carrier:SetICLS(nChannel, sIdent, nActivateDelay)
    self:SetICLSInactive(nChannel, sIdent)

    if self:IsEmpty() then
        return self end

    if isNumber(nActivateDelay) and nActivateDelay > 0 then
        Delay(nActivateDelay, function()
            self:ActivateICLS()
        end)
    else
        self:ActivateICLS()
    end
    return self
end

function DCAF.Carrier:WithRescueHelicopter(chopper)
    if self:IsEmpty() then
        return self end

    local rescueheli
    if isAssignedString(chopper) then
        rescueheli = RESCUEHELO:New(self.Unit, chopper)
    elseif isTable(chopper) and chopper.ClassName == "RESCUEHELO" then
        rescueheli = chopper
    end

    if not rescueheli then
        error("DCAF.Carrier:WithResuceHelicopter :: could not resolve a rescue helicopter from '" .. DumpPretty(chopper)) end

    rescueheli:Start()
    return self
end

function DCAF_RecoveryTanker:ToString(bFrequency, bTacan, bAltitude, bSpeed)
    local message = CALLSIGN.Tanker:ToString(self.Tanker.callsignname) .. " " .. tostring(self.Tanker.callsignnumber)

    local isSeparated

    local function separate()
        if isSeparated then
            message = message .. ", "
            return end

        isSeparated = true
        message = message .. " - "
    end

    if bFrequency then
        separate()
        message = message .. string.format("%.3f %s", self.Tanker.RadioFreq, self.Tanker.RadioModu)
    end
    if bTacan then
        separate()
        message = message .. tostring(self.Tanker.TACANchannel) .. self.Tanker.TACANmode
    end
    if bAltitude then
        separate()
        message = message .. GetAltitudeAsAngelsOrCherubs(self.Tanker.altitude)
    end
    if bSpeed then
        separate()
        message = message .. tostring(UTILS.MpsToKnots(self.Tanker.speed))
    end
    return message
end

function DCAF_RecoveryTanker:Launch()
    self.Tanker:Start()
    self.State = DCAF_RecoveryTankerState.Launched
end

function DCAF_RecoveryTanker:RTB()
    -- self.Tanker:_TaskRTB()
    -- todo - refresh all group's menus
    error("todo :: DCAF_RecoveryTanker:RTB")
end

function DCAF_RecoveryTanker:RendezVous(group)
    -- error("todo :: DCAF_RecoveryTanker:RendezVous")
    self.State = DCAF_RecoveryTankerState.RendezVous
    self.RendezVousGroup = group
end

local function makeRecoveryTanker(carrierUnit, tanker, nTacanChannel, sTacanMode, sTacanIdent, nRadioFreq, nAltitude, sCallsign, nCallsignNumber, nTakeOffType)
    local recoveryTanker
    if isAssignedString(tanker) then
        recoveryTanker = RECOVERYTANKER:New(carrierUnit, tanker)
        if isNumber(nTacanChannel) then
            if not isAssignedString(sTacanMode) then
                sTacanMode = 'Y'
            end
            nTacanChannel, sTacanMode, sTacanIdent = validateTACAN(nTacanChannel, sTacanMode)
            recoveryTanker:SetTACAN(37, sTacanIdent)
            recoveryTanker.TACANmode = sTacanMode
        end
        if isNumber(nRadioFreq) then
            recoveryTanker:SetRadio(nRadioFreq)
        end
        if isNumber(nAltitude) then
            recoveryTanker:SetAltitude(nAltitude)
        end
        if not isAssignedString(sCallsign) then
            sCallsign = CALLSIGN.Tanker.Arco
        end
        if not isNumber(nCallsignNumber) then
            nCallsignNumber = 1
        end
        recoveryTanker:SetCallsign(sCallsign, nCallsignNumber)
        if isNumber(nTakeOffType) then
            recoveryTanker:SetTakeoff(nTakeOffType)
        end
    elseif isTable(tanker) and tanker.ClassName == "RECOVERYTANKER" then
        recoveryTanker = tanker
    end
    if not recoveryTanker then
        error("cannot resolve recovery tanker from " .. DumpPretty(tanker)) end

    local info = DCAF.clone(DCAF_RecoveryTanker)
    info.Tanker = recoveryTanker
    return info
end

local DCAF_ArcosInfo = {
    [1] = {
        Frequency = 290,
        TACANChannel = 37,
        TACANMode = 'Y',
        TACANIdent = 'ACA',
        TrackBlock = 8,
        TrackSpeed = 350
    },
    [2] = {
        Frequency = 290.25,
        TACANChannel = 38,
        TACANMode = 'Y',
        TACANIdent = 'ACB',
        TrackBlock = 10,
        TrackSpeed = 350
    }
}

function DCAF.Carrier:WithArco1(sGroupName, nTakeOffType, bLaunchNow, nAltitudeFeet)
    if self:IsEmpty() then
        return self end

    if not isNumber(nAltitudeFeet) then
        nAltitudeFeet = DCAF_ArcosInfo[1].TrackBlock * 1000
    end
    local tanker = makeRecoveryTanker(
        self.Unit,
        sGroupName,
        DCAF_ArcosInfo[1].TACANChannel,
        DCAF_ArcosInfo[1].TACANMode,
        DCAF_ArcosInfo[1].TACANIdent,
        DCAF_ArcosInfo[1].Frequency,
        nAltitudeFeet,
        CALLSIGN.Tanker.Arco, 1,
        nTakeOffType)
    table.insert(self.RecoveryTankers, tanker)
    if bLaunchNow then
        tanker:Launch()
    end
    return self
end

function DCAF.Carrier:WithArco2(sGroupName, nTakeOffType, bLaunchNow, nAltitudeFeet)
    if self:IsEmpty() then
        return self end

    if not isNumber(nAltitudeFeet) then
        nAltitudeFeet = DCAF_ArcosInfo[1].TrackBlock*1000
    end
    local tanker = makeRecoveryTanker(
        self.Unit,
        sGroupName,
        DCAF_ArcosInfo[2].TACANChannel,
        DCAF_ArcosInfo[2].TACANMode,
        DCAF_ArcosInfo[2].TACANIdent,
        DCAF_ArcosInfo[2].Frequency,
        nAltitudeFeet,
        CALLSIGN.Tanker.Arco, 2,
        nTakeOffType)
    table.insert(self.RecoveryTankers, tanker)
    if bLaunchNow then
        tanker:Launch()
    end
    return self
end

local DCAFNavyF10Menus = {
    -- dicionary
    --  key = GROUP name (player aircraft group)
    --  value
}

local DCAFNavyUnitPlayerMenus = { -- item of #DCAFNavyF10Menus; one per player in Navy aircraft
    MainMenu = nil,               -- #MENU_GROUP    eg. "F10 >> Carriers"
    IsValid = true,               -- boolean; when set all menus are up to date; othwerise needs to be rebuilt
    CarriersMenus = {
        -- dictionary
        --  key    = carrier UNIT name
        --  value  = #DCAFNavyPlayerCarrierMenus
    }
}

local DCAFNavyPlayerCarrierMenus = {
    Carrier = nil,                -- #DCAF.Carrier
    CarrierMenu = nil,            -- #MENU_GROUP     eg. "F10 >> Carriers >> CVN-73 Washington"
    SubMenuActivateSystems = nil, -- #MENU_GROUP_COMMAND  eg. "F10 >> Carriers >> CVN-73 Washington >> Activate systems"
}

local function getTankerMenuData(tanker, scope)
    if tanker.State ==  DCAF_RecoveryTankerState.Parked then
        return "Launch " .. tanker:ToString(), function()
            tanker:Launch()
            tanker:RefreshGroupMenus(scope)
        end
    elseif tanker.State == DCAF_RecoveryTankerState.Launched then
        return tanker:ToString() .. " (launched)", function()
            MessageTo(scope, tanker:ToString(true, true, true))
        end
    elseif tanker.State ==  DCAF_RecoveryTankerState.RTB then
        return "(" .. tanker:ToString() .. " is RTB)", function()
            MessageTo(scope, tanker:ToString() .. " is RTB")
        end
    elseif tanker.State ==  DCAF_RecoveryTankerState.RendezVous then
        return "(" .. tanker:ToString() .. " is rendezvousing with " .. tanker.RendezVousGroup.GroupName .. ")", function()
            MessageTo(scope, tanker:ToString() .. " is rendezvousing with " .. tanker.RendezVousGroup.GroupName)
        end
    end
end

function DCAF_RecoveryTanker:RefreshGroupMenus(scope)
    local menuText, menuFunc = getTankerMenuData(self, scope)
    for groupName, menu in pairs(self.GroupMenus) do
        local parentMenu = menu.ParentMenu
        menu:Remove()
        menu = MenuCommand(scope, menuText, parentMenu, menuFunc)
    end
end

function DCAF.Carrier:HeadIntoWind(timeSeconds, scope, onResumeFunc)

    local function rebuildRouteFromLastWaypoint()
        if self._lastWaypointIndex == 1 then
            return self._route end

        local offset = self._lastWaypointIndex
        local tasks = {
            -- key   = original waypoint index
            -- value = "GoToWaypoint" task 
        }
        local waypoints = {}
        local countWaypoints = #self._route
        for i = 1, countWaypoints do
            local wp = self._route[i]
            local idx = ((i - offset) % countWaypoints) + 1
            waypoints[idx] = wp
            if wp.task then
                tasks[i] = wp.task
                wp.task = nil
            end
        end
        for idx, task in pairs(tasks) do
            waypoints[idx].task = task
        end
        return injectCarrierRouteCallbacks(self, waypoints)
    end

    local coord = self.Group:GetCoordinate()
    if not coord then
        return Warning("DCAF.Carrier:HeadIntoWind :: carrier returns no coordinate :: EXITS") end


    -- Boat will first turn roughly into wind, and then, when established, plot the actual course...
    local function plotCourseWaypoints(warn)
        local coord = self.Group:GetCoordinate()
        if not coord then
            return Warning("DCAF.Carrier:HeadIntoWind :: carrier returns no coordinate :: EXITS") end

        if not isNumber(timeSeconds) then
            timeSeconds = Minutes(40)
        end
        local direction, strengthMps = coord:GetWind()
        strengthMps = UTILS.MpsToKnots(strengthMps)
        local speedMps = Knots(27) - strengthMps
        local timeWarningSeconds = timeSeconds - Minutes(10)
        if timeWarningSeconds < 0 then
            timeWarningSeconds = timeSeconds * .85
        end
        local distance = timeSeconds * speedMps
        local distanceWarning = timeWarningSeconds * speedMps
        local brc = math.floor(direction + self.FinalBearingOffset)
        local finalBearing = math.floor(direction)
        local coordWarning, wpWarning
        if warn then
            coordWarning = coord:Translate(distanceWarning, brc)
-- if warn then            
-- coordWarning:CircleToAll(nil, nil, {0,0,1})     -- nisse --
-- end
            wpWarning = coordWarning:WaypointNaval(UTILS.MpsToKmph(speedMps))
            WaypointCallback(wpWarning, function()
                local timeWarningMinutes = math.floor((timeSeconds - timeWarningSeconds) / 60)
                local name = self.DisplayName or self.Group.GroupName
                MessageTo(scope, name .. " will resume route in " .. timeWarningMinutes .. " minutes")
            end)
        end
        local coordEnd = coord:Translate(distance, brc)
-- if warn then            
-- coordEnd:CircleToAll()     -- nisse --
-- end
        local wpEnd = coordEnd:WaypointNaval(UTILS.MpsToKmph(speedMps))
        WaypointCallback(wpEnd, function()
            -- resumes route when reaching end of head-into-wind waypoint
            self:ResumeRoute()
            if isFunction(onResumeFunc) then
                onResumeFunc(self)
            end
        end)
        local waypoints = { coord:WaypointNaval(UTILS.MpsToKmph(speedMps)) }
        if warn then 
            table.insert(waypoints, wpWarning)
        end
        table.insert(waypoints, wpEnd)
        setGroupRoute(self.Group, waypoints)
        local magneticDeclination = coord:GetMagneticDeclination()
        self._brc = brc - (magneticDeclination or 0)
        self._finalBearing = finalBearing - (magneticDeclination or 0)
    end

    local function turnIntoWind()
-- MessageTo(nil, "CVN turns into wind...")
        plotCourseWaypoints()
        -- monitor establishing course, then re-plot when established...
        local hdgPrev = self.Group:GetHeading()
        self._intoWindScheduleId = DCAF.startScheduler(function()
            local hdgCurrent = self.Group:GetHeading()
-- MessageTo(nil, "monitors CVN turning into wind :: hdgCurrent: " .. hdgCurrent)
            if hdgCurrent == hdgPrev then
-- MessageTo(nil, "CVN is established into wind :: refines course...")
                self._isIntoWindEstablished = true
                plotCourseWaypoints(true)
                DCAF.stopScheduler(self._intoWindScheduleId)
                self._intoWindScheduleId = nil
                return
            end
            hdgPrev = hdgCurrent
        end, 30)
    end

    if self._isIntoWindEstablished then
        plotCourseWaypoints(true)
    else
        if not self._isIntoWind then
            self._route = rebuildRouteFromLastWaypoint()
        end
        self._isIntoWind = true
        turnIntoWind()
    end
end

function DCAF.Carrier:ResumeRoute()
    SetRoute(self.Group, self._route)
    self._lastWaypointIndex = 1
    if self._intoWindScheduleId then
        DCAF.stopScheduler(self._intoWindScheduleId)
        self._intoWindScheduleId = nil
    end
    self._isIntoWind = false
    self._isIntoWindEstablished = false
end

local function getNavyMenuKey(scope)
    if isGroup(scope) then
        return scope.GroupName
    elseif isCoalition(scope) then
        return scope
    end
    error("getNavyMenuKey :: unsupported `scope`: " .. DumpPretty(scope))
end

function DCAFNavyF10Menus:Build(scope)

    local menuKey = getNavyMenuKey(scope)
    local function buildRecoveryTankersMenu(parentMenu)
        for _, carrier in pairs(DCAFCarriers.Carriers) do
            for _, tanker in ipairs(carrier.RecoveryTankers) do
                local menuText, menuFunc = getTankerMenuData(tanker, scope)
                local menu = MenuCommand(scope, menuText, parentMenu, menuFunc)
                tanker.GroupMenus[menuKey] = menu
            end
        end
    end

    local function buildCarrierIntoWindMenu(carrier, parentMenu)
        local TimeintoWind = Minutes(40)
        if carrier._isIntoWind then
            MenuCommand(scope, "Extend into wind", parentMenu, function()
                carrier:HeadIntoWind(TimeintoWind, scope, function()
                    self:Rebuild(carrier, scope)
                end)
                self:Rebuild(carrier, scope)
            end)
            MenuCommand(scope, "Resume navigation", parentMenu, function()
                carrier:ResumeRoute()
                self:Rebuild(carrier, scope)
            end)
        else
            MenuCommand(scope, "Head into wind", parentMenu, function()
                carrier:HeadIntoWind(TimeintoWind, scope, function()
                    self:Rebuild(carrier, scope)
                end)
                self:Rebuild(carrier, scope)
            end)
        end
    end

    local function buildCarrierMenu(carrier, parentMenu)
        buildCarrierIntoWindMenu(carrier, parentMenu)
        if carrier.TACAN or carrier.ICLS then
            MenuCommand(scope, "Activate ICLS & TACAN", parentMenu, function()
                carrier:ActivateTACAN()
                carrier:ActivateICLS()
            end)
        end
    end

    -- remove existing menus
    local menus = DCAFNavyF10Menus[menuKey]
    if menus then
        menus.MainMenu:Remove()
        menus.MainMenu = nil
    else
        menus = DCAF.clone(DCAFNavyUnitPlayerMenus)
        DCAFNavyF10Menus[menuKey] = menus
    end

    local function getCarrierMenuText(carrier)
        local text = carrier.DisplayName
        if carrier._isIntoWind then
            text = text .. " | BRC=" .. math.round(carrier._brc) .. " | FB=" .. math.round(carrier._finalBearing)
        end
        return text
    end

    if DCAFCarriers.Count == 0 then
        error("DCAF.Carrier:AddF10PlayerMenus :: no carriers was added")
    elseif DCAFCarriers.Count == 1 then
        -- just use a single 'Carriers' F10 menu (no individual carriers sub menus) ...
        for carrierName, carrier in pairs(DCAFCarriers.Carriers) do
            menus.MainMenu = Menu(scope, getCarrierMenuText(carrier))
            buildRecoveryTankersMenu(menus.MainMenu)
            buildCarrierMenu(carrier, menus.MainMenu)
            break
        end
    else
        -- build a 'Carriers' main menu and individual sub menus for each carrier ...
        menus.MainMenu = Menu(scope, "Carriers")
        buildRecoveryTankersMenu(menus.MainMenu)
        for carrierName, carrier in pairs(DCAFCarriers.Carriers) do
            local carrierMenu = Menu(scope, getCarrierMenuText(carrier), menus.MainMenu)
            buildCarrierMenu(carrier, carrierMenu)
        end
    end
end

function DCAFNavyF10Menus:Rebuild(carrier, scope)
    if not scope then
        -- update for all player groups
        for _, g in ipairs(DCAFNavyF10Menus) do
            DCAFNavyF10Menus:Rebuild(carrier, g)
        end
        return
    end

    local menuKey = getNavyMenuKey(scope)
    local menus = DCAFNavyF10Menus[menuKey]
    if menus then
        DCAFNavyF10Menus:Build(scope)
    end
end

-- note: This should be invoked at start of mission, before players start entering slots
function DCAF.Carrier:AddF10PlayerMenus(coalition)
    if coalition then
        local validCoalition = Coalition.Resolve(coalition, true)
        if not validCoalition then
            error("DCAF.Carrier:AddF10PlayerMenus :: invalid `coalition`: " .. DumpPretty(coalition)) end

        DCAFNavyF10Menus:Build(validCoalition)
        return
    end

    -- build cockpit-centric menus for naval aircraft only...
    MissionEvents:OnPlayerEnteredAirplane(
        function( event )
            if not IsNavyAircraft(event.IniUnit) then
                return end

            if not DCAFNavyF10Menus[event.IniGroupName] then
                DCAFNavyF10Menus:Build(event.IniUnit:GetGroup())
            end
        end, true)
end

-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                              BIG (air force) TANKERS & AWACS
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local DCAF_Tankers = {
    [CALLSIGN.Tanker.Shell] = {
        [1] = {
            Frequency = 270,
            TACANChannel = 39,
            TACANMode = 'Y',
            TACANIdent = 'SHA',
            TrackBlock = 22,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [2] = {
            Frequency = 270.25,
            TACANChannel = 40,
            TACANMode = 'Y',
            TACANIdent = 'SHB',
            TrackBlock = 24,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [3] = {
            Frequency = 270.5,
            TACANChannel = 41,
            TACANMode = 'Y',
            TACANIdent = 'SHC',
            TrackBlock = 23,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [4] = {
            Frequency = 270.75,
            TACANChannel = 42,
            TACANMode = 'Y',
            TACANIdent = 'SHD',
            TrackBlock = 25,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
    },
    [CALLSIGN.Tanker.Texaco] = {
        [1] = {
            Frequency = 280,
            TACANChannel = 43,
            TACANMode = 'Y',
            TACANIdent = 'TXA',
            TrackBlock = 18,  -- x1000 feet
            TrackSpeed = 410, -- knots
        },
        [2] = {
            Frequency = 280.25,
            TACANChannel = 44,
            TACANMode = 'Y',
            TACANIdent = 'TXB',
            TrackBlock = 20,  -- x1000 feet
            TrackSpeed = 410, -- knots
        },
        [3] = {
            Frequency = 280.5,
            TACANChannel = 45,
            TACANMode = 'Y',
            TACANIdent = 'TXC',
            TrackBlock = 16,  -- x1000 feet
            TrackSpeed = 410, -- knots
        },
        [4] = {
            Frequency = 280.75,
            TACANChannel = 46,
            TACANMode = 'Y',
            TACANIdent = 'TXD',
            TrackBlock = 19,  -- x1000 feet
            TrackSpeed = 410, -- knots
        },
    },
    [CALLSIGN.Tanker.Arco] = {
        [1] = DCAF_ArcosInfo[1],
        [2] = DCAF_ArcosInfo[2]
    }
}

local DCAF_TankerMonitor = {
    Timer = nil,
}

local DCAF_ServiceTrack = {
    ClassName = "DCAF_ServiceTrack"
}

function DCAF_ServiceTrack:New(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if not isNumber(nStartWp) then
        error("DCAF.<service>:SetTrack :: start waypoint was unassigned/unexpected value: " .. Dump(nStartWp)) end
    if nStartWp < 1 then
        error("DCAF.<service>:SetTrack :: start waypoint must be 1 or more (was: " .. Dump(nStartWp) .. ")") end

    local track = DCAF.clone(DCAF_ServiceTrack)
    track.StartWpIndex = nStartWp
    track.Heading = nHeading
    track.Length = nLength
    track.Block = nBlock
    track.Color = rgbColor
    track.TrackName = sTrackName
    return track
end

local DCAF_SERVICE_TYPE = {
    Tanker = "DCAF.Tanker",
    AWACS = "DCAF.AWACS"
}

DCAF.Tanker = {
    _isTemplate = true,
    ClassName = DCAF_SERVICE_TYPE.Tanker,
    Group = nil,              -- #GROUP (the tanker group)
    TACANChannel = nil,       -- #number; TACAN channel
    TACANMode = nil,          -- #string; TACAN mode
    TACANIdent = nil,         -- #string; TACAN ident
    FuelStateRtb = 0.15,      --
    Frequency = nil,          -- #number; radio frequency
    StartFrequency = nil,     -- #number; radio frequency tuned at start and during RTB/landing
    RTBAirbase = nil,         -- #AIRBASE; the last WP landing airbase; or starting/closest airbase otherwise
    RTBWaypoint = nil,        -- #number; first waypoint after track waypoints (set by :SetTrack()
    TrackBlock = nil,         -- #number; x1000 feet
    TrackSpeed = nil,         -- #number; knots
    Track = nil,
    Events = {},              -- dictionary; key = name of event (eg. 'OnFuelState'), value = event arguments
    MaxFuelLbs = {
        ["KC130"] = 66139,
        ["KC-135"] = 199959,
        ["KC135MPRS"] = 199959,
        ["S-3B Tanker"] = 17225,
        ["KC_10_Extender"] = 353181
    }
}

local DCAF_AWACS = {
    [CALLSIGN.AWACS.Magic] = {
        [1] = {
            TrackBlock = 35,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [2] = {
            TrackBlock = 34,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [3] = {
            TrackBlock = 33,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
    }
}

DCAF.AWACS = {
    _isTemplate = true,
    ClassName = DCAF_SERVICE_TYPE.AWACS,
    Group = nil,              -- #GROUP (the tanker group)
    FuelStateRtb = 0.15,      --
    RTBAirbase = nil,         -- #AIRBASE; the last WP landing airbase; or starting/closest airbase otherwise
    RTBWaypoint = nil,        -- #number; first waypoint after track waypoints (set by :SetTrack)
    TrackBlock = nil,         -- #number; x1000 feet
    TrackSpeed = nil,         -- #number; knots
    Track = nil,
    Events = {},              -- dictionary; key = name of event (eg. 'OnFuelState'), value = event arguments
}

function DCAF.Tanker:IsMissing()
    return not self.Group
end

function DCAF.Tanker:New(controllable, replicate, callsign, callsignNumber)
    local tanker = DCAF.clone(replicate or DCAF.Tanker)
    tanker._isTemplate = false
    local group = getGroup(controllable)
    if not group then
        -- note: To make code API more versatile we accept missing tankers. This allows for reusing same script in missions where not all tankers are present
        Warning("DCAF.Tanker:New :: cannot resolve group from " .. DumpPretty(controllable))
        return tanker
    end

    -- initiate tanker ...
    tanker.Group = group
    local defaults
    if callsign ~= nil then
        if not isNumber(callsign) then
            error("DCAF.Tanker:New :: `callsign` must be number but was " .. type(callsign))  end
        if not isNumber(callsignNumber) then
            error("DCAF.Tanker:New :: `callsignNumber` must be number but was " .. type(callsignNumber))  end
        defaults = DCAF_Tankers[callsign][callsignNumber]
    else
        callsign, callsignNumber = GetCallsign(group)
        defaults = DCAF_Tankers[CALLSIGN.Tanker:FromString(callsign)][callsignNumber]
    end
    Trace("DCAF.Tanker:New :: callsign: " .. Dump(callsign) .. " " .. Dump(callsignNumber) .. " :: defaults: " .. DumpPrettyDeep(defaults))
    tanker.TACANChannel = defaults.TACANChannel
    tanker.TACANMode = defaults.TACANMode
    tanker.TACANIdent = defaults.TACANIdent
    tanker.Frequency = defaults.Frequency
    tanker.RTBAirbase = GetRTBAirbaseFromRoute(group)
    tanker.TrackBlock = defaults.TrackBlock
    tanker.TrackSpeed = defaults.TrackSpeed
    tanker.DisplayName = CALLSIGN.Tanker:ToString(callsign, callsignNumber)

    if tanker.Track and tanker.Track.Route then
        -- replicate route from previous tanker ...
        group:Route(tanker.Track.Route)
    end

    -- register all events (from replicate)
    for _, event in pairs(tanker.Events) do
        event.EventFunc(event.Args)
    end

    return tanker
end

function DCAF.Tanker:InitFrequency(frequency)
    if not isNumber(frequency) then
        error("DCAF.Tanker:WithFrequency :: `frequency` must be a number but was " .. type(frequency)) end

    self.Frequency = frequency
    return self
end

function DCAF.Tanker:FindGroupWithCallsign(callsign, callsignNumber)
    local callsignName = CALLSIGN.Tanker:ToString(callsign)
    local groups = _DATABASE.GROUPS
    for _, g in pairs(groups) do
        if g:IsAir() then
            local u = g:GetUnit(1)
            if u then
                local csName, csNumber = GetCallsign(u)
                if csName == callsignName and csNumber == callsignNumber then
                    return g
                end
            end
        end
    end
end

function DCAF.Tanker:NewFromCallsign(callsign, callsignNumber)
    if callsign == nil then
        error("DCAF.Tanker:New :: callsign group was not specified") end

    local group = self:FindGroupWithCallsign(callsign, callsignNumber)
    if not group then
        error("DCAF.Tanker:NewFromCallsign :: cannot resolve Tanker from callsign: " .. CALLSIGN.Tanker:ToString(callsign, callsignNumber)) end

    return DCAF.Tanker:New(group)
end

function DCAF_ServiceTrack:IsTanker()
    return self.Service.ClassName == DCAF_SERVICE_TYPE.Tanker
end

function DCAF_ServiceTrack:IsAWACS()
    return self.Service.ClassName == DCAF_SERVICE_TYPE.AWACS
end

function InsertWaypointTask(waypoint, task)
    task.number = #waypoint.task.params.tasks+1
    table.insert(waypoint.task.params.tasks, task)
end

function TankerTask()
    return {
        auto = false,
        id = "Tanker",
        enabled = true,
        params = { },
    }
end

local function FrequencyAction(nFrequency, nPower, modulation)
    if not isNumber(nFrequency) then
        error("FrequencyAction :: `nFrequency` must be number but was " .. type(nFrequency)) end

    if not isNumber(nPower) then
        nPower = 10
    end

    if not modulation then
        modulation = radio.modulation.AM
    end

    return
    {
        id = 'SetFrequency',
        params = {
            power = nPower,
            frequency = nFrequency * 1000000,
            modulation = modulation
        },
    }
end

function ActivateBeaconAction(beaconType, nChannel, nFrequency, sModeChannel, sCallsign, nBeaconSystem, bBearing, bAA)
    if not isNumber(beaconType) then
        beaconType = BEACON.Type.TACAN
    end
    if not isBoolean(bBearing) then
        bBearing = true
    end
    if not isBoolean(bAA) then
        bAA = false
    end

    return {
        id = "ActivateBeacon",
        params = {
            modeChannel = sModeChannel,
            type = beaconType,
            system = nBeaconSystem,
            AA = bAA,
            callsign = sCallsign,
            channel = nChannel,
            bearing = bBearing,
            frequency = nFrequency
        }
    }
end

local function ActivateTankerTacanAction(nChannel, sModeChannel, sCallsign, bBearing, bAA)
    local tacanSystem
    if sModeChannel == "X" then
        tacanSystem = BEACON.System.TACAN_TANKER_X
    else
        tacanSystem = BEACON.System.TACAN_TANKER_Y
    end
    return ActivateBeaconAction(
        BEACON.Type.TACAN,
        nChannel,
        UTILS.TACANToFrequency(nChannel, sModeChannel),
        sModeChannel,
        sCallsign,
        tacanSystem,
        bBearing,
        bAA)
end

function InsertWaypointAction(waypoint, action, name)
    table.insert(waypoint.task.params.tasks, {
        number = #waypoint.task.params.tasks+1,
        name = name,
        auto = false,
        id = "WrappedAction",
        enabled = true,
        params = { action = action },
      })
end

function ScriptAction(script)
    if not isAssignedString(script) then
        error("ScriptAction :: `script` must be assigned string, but was " .. type(script)) end

    return {
        id = "Script",
        params =
        {
            command = script
        }
    }
end

local DCAF_CALLBACK_INFO = {
    ClassName = "DCAF_CALLBACK_INFO",
    NextId = 1,
    Id = 0,              -- #int
    Func = nil           -- #function
}

local DCAF_CALLBACKS = { -- dictionary
    -- key   = #string
    -- value = #AIR_ROUTE_CALLBACK_INFO
}

function DCAF_CALLBACK_INFO:New(func, oneTime)
    local info = DCAF.clone(DCAF_CALLBACK_INFO)
    if not isBoolean(oneTime) then
        oneTime = true
    end
    info.Func = func
    info.Id = DCAF_CALLBACK_INFO.NextId
    info.OneTime = oneTime
    DCAF_CALLBACKS[tostring(info.Id)] = info
    DCAF_CALLBACK_INFO.NextId = DCAF_CALLBACK_INFO.NextId + 1
    return info
end

function DCAF_CALLBACKS:Callback(id)
    local key = tostring(id)
    local info = DCAF_CALLBACKS[key]
    if not info then
        Warning("DCAF_CALLBACKS:Callback :: no callback found with id: " .. Dump(id) .. " :: IGNORES")
        return
    end
    info.Func()
    if info.OneTime then
        DCAF_CALLBACKS[key] = nil
    end
end

function ___dcaf_callback___(id)
    DCAF_CALLBACKS:Callback(id)
end

--- Returns the waypoint of a group that is closest to a specified location
-- @param #Any group - a GROUP, UNIT, or the name of a group/unit
-- @param #Any group - a GROUP, UNIT, or the name of a group/unit
-- returns #waypoint, #num (index of waypoint), #num (distance from location to waypoint), #route (table of waypoints)
function GetClosestWaypoint(group, location)
    local validGroup = getGroup(group)
    if not validGroup then return Error("getClosestWaypoint :: cannot resolve GROUP from `source`: " .. DumpPretty(group)) end
    local route = getGroupRoute(validGroup)
    local validLocation
    if location == nil then
        validLocation = DCAF.Location.Resolve(validGroup)
    else
        validLocation = DCAF.Location.Resolve(location)
        if not validLocation then return Error("getClosestWaypoint :: cannot resolve location from `loc`: " .. DumpPretty(location)) end
    end
    local minDistance = 9999999999
    local closestWP
    local closestWPIndex
    local coordSource = validLocation:GetCoordinate()
    for index, wp in ipairs(route) do
        local coordWP = COORDINATE_FromWaypoint(wp)
        local distance = coordSource:Get2DDistance(coordWP)
        if distance < minDistance then
            closestWP = wp
            closestWPIndex = index
            minDistance = distance
        end
    end
    return closestWP, closestWPIndex, minDistance, route
end

function WaypointCallback(waypoint, func, oneTime, name)
    if func == nil then return waypoint end
    if not isFunction(func) then
        return exitWarning("WaypointCallback :: `func` must be function, but was: " .. DumpPretty(func))
    end
    local info
    info = DCAF_CALLBACK_INFO:New(function()
        func(waypoint)
    end, oneTime)
    InsertWaypointAction(waypoint, ScriptAction("___dcaf_callback___(" ..Dump(info.Id) .. ")"), name)
    return waypoint
end

function WaypointSwitchWaypoint(waypoint, toWpIndex, fromWpIndex, name)
    if not isNumber(fromWpIndex) then
        return Error("WaypointSwitchWaypoint :: `fromWpIndex` must be number, but was: " .. DumpPretty(fromWpIndex)) end
    if not isNumber(fromWpIndex) then
        return Error("WaypointSwitchWaypoint :: `toWpIndex` must be number, but was: " .. DumpPretty(toWpIndex)) end

    InsertWaypointAction(waypoint,
        {
            ["id"] = "SwitchWaypoint",
            ["params"] = {
                ["goToWaypointIndex"] = toWpIndex,
                ["fromWaypointIndex"] = fromWpIndex,
            },
        }, name)

--[[
        {
            ["enabled"] = true,
            ["auto"] = false,
            ["id"] = "WrappedAction",
            ["number"] = 1,
            ["params"] = 
            {
                ["action"] = 
                {
                    ["id"] = "SwitchWaypoint",
                    ["params"] = 
                    {
                        ["goToWaypointIndex"] = 1,
                        ["fromWaypointIndex"] = 3,
                    }, -- end of ["params"]
                }, -- end of ["action"]
            }, -- end of ["params"]
        }
    ]]
end

function DCAF_ServiceTrack:Execute(direct) -- direct = service will proceed direct to track
    if not isBoolean(direct) then
        direct = false
    end

    local waypoints, route = self.Service:GetWaypoints() -- .Route or self.Service.Group:CopyRoute()
    local wpOffset = 1
    local startWpIndex = self.StartWpIndex
    startWpIndex = startWpIndex + wpOffset -- this is to harmonize with WP numbers on map (1st WP on map is zero - 0)
    if startWpIndex > #waypoints then
        error("DCAF.Tanker:SetTrack :: start waypoint must be within route (route is " .. Dump(#waypoints) .. " waypoints, startWp was ".. Dump(startWpIndex) .. ")") end

    local startWp = waypoints[startWpIndex]

    local trackLength = self.Length
    local trackAltitude
    local trackHeading = self.Heading
    if not isNumber(trackLength) then
        trackLength = NauticalMiles(30)
    end
    if isNumber(self.Block) then
        trackAltitude = Feet(self.Block * 1000)
    elseif isNumber(self.Service.TrackBlock) then
        trackAltitude = Feet(self.Service.TrackBlock * 1000)
    end
    startWp.alt = trackAltitude
    if DCAF.Debug then
        startWp.name = "TRACK IP"
    end

    local startWpCoord = COORDINATE:NewFromWaypoint(startWp)
    local endWpCoord

    if not isNumber(trackHeading) then
        if startWpIndex == #waypoints then
            error(self.Service.ClassName.."SetTrackFromWaypoint :: heading was unassigned/unexpected value and start of track was also last waypoint")
        else
            endWpCoord = COORDINATE:NewFromWaypoint(waypoints[startWpIndex+1])
            self.RTBWaypoint = startWpIndex+2 -- note, if last WP in track was also last waypoint in route, this will point 'outside' the route
        end
    else
        endWpCoord = startWpCoord:Translate(trackLength, trackHeading, trackAltitude)
    end

    local function drawActiveTrack(color)
        
        if not isList(color) then color = self.Color end
        if not color then
            return end

        local rgbColor
        if self.IsTrackDrawn then
            self.Color = color or { 1, 0, 0 }
        end

        self.IsTrackDrawn = true
        if isTable(self.Color) then
            rgbColor = self.Color
        else
            rgbColor = {0,1,1}
        end
        local trackHeading = startWpCoord:GetAngleDegrees(startWpCoord:GetDirectionVec3(endWpCoord))
        local trackDistance = startWpCoord:Get2DDistance(endWpCoord)
        local wp1 = startWpCoord:Translate(trackDistance + NauticalMiles(7), trackHeading, trackAltitude)
        local perpHeading = (trackHeading - 90) % 360
        local wp2 = wp1:Translate(NauticalMiles(13), perpHeading, trackAltitude)
        perpHeading = (perpHeading - 90) % 360
        local wp3 = wp2:Translate(trackDistance + NauticalMiles(14), perpHeading, trackAltitude)
        perpHeading = (perpHeading - 90) % 360
        local wp4 = wp3:Translate(NauticalMiles(13), perpHeading, trackAltitude)
        wp1:MarkupToAllFreeForm({wp2, wp3, wp4}, self.Service.Group:GetCoalition(), rgbColor, 0.5, nil, 0, 3)
        wp4:SetHeading(trackHeading)
        if isAssignedString(self.TrackName) then
            wp4:TextToAll(self.TrackName, self.Service.Group:GetCoalition(), rgbColor, 0.5, nil, 0)
        end
    end

    local function hasOrbitTask() return HasTask(self.Service.Group, "Orbit") end                          -- todo consider elevating this func to global
    local function hasTankerTask() return HasTask(self.Service.Group, "Tanker") end                        -- todo consider elevating this func to global
    local function hasSetFrequencyTask() return HasWaypointAction(self.Service:GetWaypoints(), "SetFrequency") end  -- todo consider elevating this func to global
    local function hasActivateBeaconTask() return HasAction(self.Service.Group, "ActivateBeacon") end      -- todo consider elevating this func to global
    local function hasDeactivateBeaconTask() return HasAction(self.Service.Group, "DeactivateBeacon") end  -- todo consider elevating this func to global

    drawActiveTrack()

    if self:IsTanker() then
        local tankerTask = hasTankerTask()
        if not tankerTask or tankerTask > startWpIndex then
            InsertWaypointTask(startWp, TankerTask())
        end
    end

    local setFrequencyTask = hasSetFrequencyTask()
    if self.Service.Frequency and (not setFrequencyTask or setFrequencyTask > startWpIndex) then
        local frequencyAction = FrequencyAction(self.Service.Frequency)
        InsertWaypointAction(startWp, frequencyAction)
    end

    local orbitTask = hasOrbitTask()
    if not orbitTask or orbitTask ~= startWpIndex then
        InsertWaypointTask(startWp, self.Service.Group:TaskOrbit(startWpCoord, trackAltitude, Knots(self.Service.TrackSpeed), endWpCoord))
        if orbitTask and orbitTask ~= startWpIndex then
            Warning(self.Service.ClassName..":SetTrack :: there is an orbit task set to a different WP (" .. Dump(orbitTask) .. ") than the one starting the tanker track (" .. Dump(startWpIndex) .. ")") end

        self.Service.RTBWaypoint = startWpIndex+1 -- note, if 1st WP in track was also last waypoint in route, this will point 'outside' the route
    end

    local tacanWpIndex
    local tacanWpSpeed = UTILS.KnotsToKmph(self.Service.TrackSpeed)

    local isAlreadyActivated = false
    if isNumber(self.Service._serviceWP) then
        isAlreadyActivated = self.Service._serviceWP < startWpIndex
    end
    if self:IsTanker() and not hasActivateBeaconTask() and not isAlreadyActivated then
        -- ensure TACAN gets activated _before_ the first Track WP (some weird bug in DCS otherwise may cause it to not activate)
        -- inject a new waypoint 2 nm before the tanker track, or use the previous WP if < 10nm from the tanker track
        local prevWp = waypoints[startWpIndex - wpOffset]
        local prevWpCoord = COORDINATE:NewFromWaypoint(prevWp)
        local distance = prevWpCoord:Get2DDistance(startWpCoord)
        local tacanWp
        if distance <= NauticalMiles(10) then
            tacanWp = prevWp
            tacanWpIndex = startWpIndex-1
        else
            local dirVec3 = prevWpCoord:GetDirectionVec3(startWpCoord)
            local heading = prevWpCoord:GetAngleDegrees(dirVec3)
            local tacanWpCoord = prevWpCoord:Translate(distance - NauticalMiles(2), heading, trackAltitude)
            tacanWp = tacanWpCoord:WaypointAir(
                COORDINATE.WaypointAltType.BARO,
                COORDINATE.WaypointType.TurningPoint,
                COORDINATE.WaypointAction.TurningPoint,
                tacanWpSpeed)
            tacanWp.alt = trackAltitude
            table.insert(waypoints, startWpIndex, tacanWp)
            tacanWpIndex = startWpIndex
        end
        if DCAF.Debug and not tacanWp.name then
            tacanWp.name = "ACTIVATE"
        end

        local tacanSystem
        if self.TACANMode == "X" then
            tacanSystem = BEACON.System.TACAN_TANKER_X
        else
            tacanSystem = BEACON.System.TACAN_TANKER_Y
        end

        InsertWaypointAction(tacanWp, ActivateTankerTacanAction(
            self.Service.TACANChannel,
            self.Service.TACANMode,
            self.Service.TACANIdent,
            true,
            false
        ))
        startWpIndex = startWpIndex+1
    end

    if startWpIndex == #waypoints or startWpIndex == #waypoints-1 then
        -- add waypoint for end of track ...
        local endWp = endWpCoord:WaypointAir(
            COORDINATE.WaypointAltType.BARO,
            COORDINATE.WaypointType.TurningPoint,
            COORDINATE.WaypointAction.TurningPoint,
            tacanWpSpeed)
        endWp.alt = trackAltitude
        if DCAF.Debug then
            endWp.name = "TRACK END"
        end
        table.insert(waypoints, startWpIndex+1, endWp)
    end
    if direct then
        waypoints = listCopy(waypoints, nil, tacanWpIndex)
    end
    self.Route = waypoints
    self.Service:SetRoute(route or waypoints)
end

local function setServiceTrack(service, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
    if not isNumber(nStartWp) then
        error("DCAF.Tanker:SetTrack :: start waypoint was unassigned/unexpected value: " .. Dump(nStartWp)) end
    if nStartWp < 1 then
        error("DCAF.Tanker:SetTrack :: start waypoint must be 1 or more (was: " .. Dump(nStartWp) .. ")") end

    if service:IsMissing() then
        return service end

    service.Track = DCAF_ServiceTrack:New(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    service.Track.Service = service
    service.Track:Execute(direct)
    return service
end

function SetAirServiceRoute(service, route)
    if DCAF.AIR_ROUTE and isClass(route, DCAF.AIR_ROUTE.ClassName) then
        service._waypoints = route.Waypoints
        service._airRoute = route
    elseif isTable(route) then
        service._waypoints = route
    end
    setGroupRoute(service.Group, service._waypoints)
end

local function getAirServiceWaypoints(service)
    if isTable(service._waypoints) then
        return service._waypoints, service._airRoute
    else
        return service.Group:CopyRoute()
    end
end

function DCAF.Tanker:GetWaypoints()
    return getAirServiceWaypoints(self)
end

function DCAF.Tanker:SetRoute(route)
    SetAirServiceRoute(self, route)
    return self
end

--- Activates Tanker at specified waypoint (if not set, the tanker will activate as it enters its track - see: SetTrack)
--- Please note that the WP should preceed the Track start WP for this to make sense
function DCAF.Tanker:ActivateService(nServiceWp, waypoints)
    if not isNumber(nServiceWp) then
        error("DCAF.Tanker:ActivateService :: `nActivateWp` must be number but was " .. type(nServiceWp)) end

    if nServiceWp < 1 then
        error("DCAF.Tanker:ActivateService :: `nActivateWp` must be a positive non-zero value") end

    nServiceWp = nServiceWp+1
    local route
    if not isTable(waypoints) then
        waypoints, route = self:GetWaypoints()
    end
    if nServiceWp > #waypoints then
        error("DCAF.Tanker:ActivateService :: `nActivateWp` must be a WP of the (currently there are " .. #waypoints .. " waypoints in route") end

    -- activate TACAN, Frequency and 'Tanker' task at specified WP
    self._serviceWP = nServiceWp
    local serviceWp = waypoints[nServiceWp]
    if DCAF.Debug then
        serviceWp.name = "ACTIVATE"
    end
    InsertWaypointTask(serviceWp, TankerTask())
    InsertWaypointAction(serviceWp, ActivateTankerTacanAction(
        self.TACANChannel,
        self.TACANMode,
        self.TACANIdent,
        true,
        false
    ))

    InsertWaypointAction(serviceWp, FrequencyAction(self.Frequency))
    self:SetRoute(route or waypoints)
    return self
end

function DCAF.Tanker:SetTrack(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 1, 1, 0 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
end

function DCAF.Tanker:SetTrackDirect(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 0, 1, 1 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, true)
end

local function DCAF_Service_OnFuelState(args)
    MissionEvents:OnFuelState(args.Service.Group, args.State, function() args.Func(args.Service) end)
end

local DCAF_AttackedHVAA = { -- dictionary
    -- key = #string :: HVAA group name
}

function AttackHVAA(controllable, nRadius, callsign, callsignNo)
    local group = getGroup(controllable)
    if not group then
        return Warning("AttackAirService :: cannot resolve group from `controlable`: " .. DumpPretty(ControlledPlane))
    end
    if not isNumber(nRadius) then
        nRadius = NauticalMiles(60)
        local coord = group:GetCoordinate()
    end
    local zone = ZONE_GROUP:New(group.GroupName, group, nRadius)
    local set_groups = SET_GROUP:New():FilterZones({ zone }):FilterOnce()
    local hvaaGroups = {}

    local function setupAttack(hvaaGroup)
Debug("AttackAirHVAA :: '" .. group.GroupName .. " attacks " .. hvaaGroup.GroupName)
        local countAttacks = DCAF_AttackedHVAA[hvaaGroup.GroupName]
        if not countAttacks then
            countAttacks = 1
        else
            countAttacks = countAttacks + 1
        end
        DCAF_AttackedHVAA[hvaaGroup.GroupName] = countAttacks
        TaskAttackGroup(group, hvaaGroup)
    end

    local function sortHVAAGroupsForAttack()
        table.sort(hvaaGroups, function(a, b)
            if a == nil then
                return false end

            if b == nil then
                return true end

            local countA = DCAF_AttackedHVAA[a.GroupName]
            local countB = DCAF_AttackedHVAA[b.GroupName]
            if not countA then countA = 0 end
            if not countB then countB = 0 end
            return countA < countB

        end)
        return hvaaGroups
    end

    set_groups:ForEachGroup(function(hvaaGroup)
        local hvaaCallsign, number = IsAirService(hvaaGroup)
        if not hvaaCallsign then
            return end

        if callsign then
            if callsign ~= hvaaCallsign then
                return end

            if callsignNo then
                if callsignNo ~= number then
                    return end

                return setupAttack(hvaaGroup)
            else
                return setupAttack(hvaaGroup)
            end
        end

        table.insert(hvaaGroups, hvaaGroup)
    end)

    local sortedHVAA = sortHVAAGroupsForAttack()
    setupAttack(sortedHVAA[1])

end

local function onFuelState(service, state, func)
    local self = service
    if self:IsMissing() then
        return self end

    local args = {
        Service = self,
        State = state,
        Func = func
    }
    DCAF_Service_OnFuelState(args)
    self.Events["OnFuelState"] = { EventFunc = DCAF_Service_OnFuelState, Args = args }
    return self
end

function DCAF.Tanker:OnFuelState(state, func)
    if not isFunction(func) then
        error("DCAF.Tanker:OnFuelState :: func was unassigned/unexpected value: " .. DumpPretty(func)) end

    if self:IsMissing() then
        return self end

    local args = {
        Service = self,
        State = state,
        Func = func
    }
    DCAF_Service_OnFuelState(args)
    self.Events["OnFuelState"] = { EventFunc = DCAF_Service_OnFuelState, Args = args }
    return self
end

function DCAF.Tanker:OnBingoState(func)
    return self:OnFuelState(0.15, func)
end

function DCAF.Tanker:Start(delay)
    if self:IsMissing() then
        return self end

    if isNumber(delay) then
        Delay(delay, function()
            activateNow(self.Group)
        end)
    else
        activateNow(self.Group)
    end
    return self
end

function WaypointLandAt(location, speed)
    local testLocation = DCAF.Location.Resolve(location)
    if not testLocation then
        error("WaypointLandAt :: cannot resolve `location`: " .. DumpPretty(location)) end

    if not testLocation:IsAirbase() then
        error("WaypointLandAt :: `location` is not an airbase") end

    location = testLocation
    local airbase = location.Source
    return location:GetCoordinate():WaypointAirLanding(speed, airbase)
end

function IsOnGround(source)
    local unit = getUnit(source)
    if unit then
        local dcsUnit = unit:GetDCSObject()
        return not dcsUnit:inAir()
    end
    local group = getGroup(source)
    if group then
        return group:AllOnGround() end
    return Warning("IsOnGround :: cannot resolve `source` as UNIT nor GROUP")
end

function IsOnAirbase(source, airbase)
    local location = DCAF.Location:New(source)
    if not location:IsGrounded() then
        return false end

    if airbase and not isAirbase(airbase) then
        if isAssignedString(airbase) then
            local testAirbase = AIRBASE:FindByName(airbase)
            if not testAirbase then
                Warning("IsOnAirbase :: cannot resolve airbase from: " .. DumpPretty(airbase))
            end
            airbase = testAirbase
        else
            error("IsOnAirbase :: `airbase` must be #AIRBASE or assigned string, but was: " .. DumpPretty(airbase))
        end
    end

    -- source is on the ground; check nearest airbase...
    local closestAirbase = location.Coordinate:GetClosestAirbase()
    local coordClosestAirbase = closestAirbase:GetCoordinate()
    if not airbase then
        return coordClosestAirbase:Get2DDistance(location.Coordinate) < NauticalMiles(2.5)
    end
    if closestAirbase.AirbaseName ~= airbase.AirbaseName then
        return false end

    return coordClosestAirbase:Get2DDistance(location.Coordinate) < NauticalMiles(2.5)
end

function UNIT:IsParked()
    local kmh = self:GetVelocityKMH()
    local agl = GetAGL(self)
    return agl < 4 and kmh < 1
end

--- Sends the group to land on an airbase. The function builds a route to set up the group to land on the active runway, a bit more "structured" than the default AI behavior
-- @param #Any source - a #CONTROLLABLE or name of controllable (must be translateable to a #GROUP); the group to be sent to land
-- @param #Any airbase - an #AIRBASE, name of airbase, or a table - { Airbase, Runway } - to specify airbase and runway
-- @speed #boolean approach - (optional; default=true) When true the RTB will include an initial point and simple approach for active runway
-- @speed #number speed - (optional) The approach speed (KM/Hour)
-- @param #function onLandedFunc - (optional) A function to be called back then AI has landed
-- @param #number altitude - (optional) An approach altitude
-- @param #string altitudeType - (optional) The altitude type ("BARO" or "RADIO")
function RTBNow(source, airbase, approach, speed, onLandedFunc, altitude, altitudeType)
    local group = getGroup(source)
    if not group then
        return errorOnDebug("RTBNow :: cannot resolve group from " .. DumpPretty(source)) end

    local function resolveRunway(runway, airbase)
        if not runway then return end
        if isAssignedString(runway) then
            return airbase:GetRunwayByName(runway)
        end
        return runway -- I dunno how to figure out if runway is actually a MOOSE runway -Jonas
    end

    local function resolveAirbase(airbase, runway)
        if isAirbase(airbase) then
            return airbase, resolveRunway(runway, airbase)
        elseif isAssignedString(airbase) then
            airbase = AIRBASE:FindByName(airbase)
            if airbase then
                return airbase, resolveRunway(runway, airbase)
            end
        elseif isTable(airbase) and airbase.Airbase then
            return resolveAirbase(airbase.Airbase, airbase.Runway)
        end
    end

    local validAirbase, landingRWY = resolveAirbase(airbase)
    if airbase ~= nil and not validAirbase then
        Warning("RTBNow :: group: " .. group.GroupName .. " :: airbase cannot be resolved: '" .. DumpPretty(airbase) .. "' :: falls back to closest airbase")
        airbase = nil
    end

    airbase = validAirbase
    if IsOnAirbase(source, airbase) then
        -- controllable is already on specified airbase - despawn
        group:Destroy()
        return
    end

    -- local coord = group:GetCoordinate()
    if isFunction(onLandedFunc) then
        local _onLandedFuncWrapper
        local function onLandedFuncWrapper(event)
            if event.IniGroup.GroupName == group.GroupName then
                onLandedFunc(event.IniGroup)
                MissionEvents:EndOnAircraftLanded(_onLandedFuncWrapper)
            end
        end
        _onLandedFuncWrapper = onLandedFuncWrapper
        MissionEvents:OnAircraftLanded(_onLandedFuncWrapper)
    end

    local function buildRoute(airbase, wpLanding, enforce_alsoForShips) -- note the @enforce_alsoForShips is only a tamporary hack until we support CASE I, II, and III
        if airbase:IsShip() and not enforce_alsoForShips then
            return end

        if not isAirbase(airbase) then
            error("RTBNow-"..group.GroupName.." :: not an #AIRBASE: " .. DumpPretty(airbase)) end

        -- local wpArrive
        local wpInitial
        wpLanding = wpLanding or WaypointLandAt(airbase)
        if not wpLanding then
            error("RTBNow-"..group.GroupName.." :: cannot create landing waypoint for airbase: " .. DumpPretty(airbase)) end

        if not approach then
            return { wpLanding }
        end

        local abCoord = airbase:GetCoordinate()
        local bearing, distance = GetBearingAndDistance(airbase, group)
        local coordApproach
        local appoachAltType = altitudeType or COORDINATE.WaypointAltType.RADIO
        local distApproach
        local altApproach
        local altDefault
        if isNumber(altitude) then
            altDefault = altitude
        elseif group:IsAirPlane() then
            altDefault = Feet(15000)
        elseif group:IsHelicopter() then
            altDefault = Feet(500)
        end
        altApproach = altitude or altDefault
        if airbase.isHelipad and group:IsHelicopter() then
            distApproach = 1000
        elseif distance > NauticalMiles(25) or group:GetAltitude(true) > Feet(15000) then
            -- approach waypoint 25nm from airbase...
            distApproach = NauticalMiles(25)
            appoachAltType = COORDINATE.WaypointAltType.BARO
        else
            -- approach 10nm from airbase...
            distApproach = NauticalMiles(15)
        end
        landingRWY = landingRWY or airbase:GetActiveRunwayLanding()
        if landingRWY then
            bearing = ReciprocalAngle(landingRWY.heading)
        else
            bearing = ReciprocalAngle(bearing)
        end
        coordApproach = abCoord:Translate(distApproach, bearing)
        coordApproach:SetAltitude(altApproach)
        -- we need an 'initial' waypoint (or the approachWP is ignored by DCS) ...

        local speedInitial = speed or math.max(UTILS.KnotsToKmph(Knots(250)), group:GetVelocityKMH())
        local coordInitial = coordApproach:Translate(NauticalMiles(1), bearing, altApproach)
        coordInitial:SetAltitude(math.max(group:GetAltitude(), altApproach))
        local wpApproach = coordInitial:WaypointAirTurningPoint(appoachAltType, speedInitial)
        wpInitial = coordApproach:WaypointAirTurningPoint(appoachAltType, Knots(250))
        wpApproach.name = "APPROACH"
        wpInitial.name = "INITIAL"
        return { wpApproach, wpInitial, wpLanding }
    end

    local function buildCarrierRoute(carrier, wpLanding)
        local altType = COORDINATE.WaypointAltType.RADIO
        if group:IsHelicopter() then
            local hdg3oclock = (carrier:GetHeading() + 90) % 360
            local wpDummy = group:GetCoordinate():WaypointAirFlyOverPoint(altType, group:GetVelocityKMH())
            local coordInitial = carrier:GetCoordinate():Translate(NauticalMiles(2), hdg3oclock)
            coordInitial:SetAltitude(Feet(200))
            local wpInitial = coordInitial:WaypointAirTurningPoint(altType, UTILS.KnotsToKmph(100))
            wpInitial.name = "INITIAL"
            if not wpLanding then
                wpLanding = WaypointLandAt(carrier)
            end
            return { wpDummy, wpInitial, wpLanding }
        else
--         -- todo Implement CASE I, II, and III approaches for RTB to carriers
            -- Carriers require custom approach
            local wpDummy = group:GetCoordinate():WaypointAirFlyOverPoint(altType, group:GetVelocityKMH())
            wpLanding = wpLanding or WaypointLandAt(carrier)
            return { wpDummy, wpLanding }
        end
    end

    local wpLanding
    if airbase ~= nil then
        -- landing location was specified, build route to specified airbase ...
        local ab = getAirbase(airbase)
        if not ab then
            return error("RTBNow :: cannot resolve AIRBASE from " .. DumpPretty(airbase)) end
        airbase = ab
    else
        local landingWpIndex, airdrome, wp = HasLandingTask(group)
        if landingWpIndex then
            -- the route ends in a landing WP, just reuse it
            if airdrome then
                -- landing WP was "Landing" type waypoint, with airdrome - not wrapped action. We have the airbase...
                airbase = airdrome
                wpLanding = wp
            else
                -- todo ...
                error("nisse - todo")
            end
        end
    end
    local waypoints = buildRoute(airbase, wpLanding) or buildCarrierRoute(airbase, wpLanding)
    setGroupRoute(group, waypoints)
    return group, waypoints
end

local DCAF_AirServiceBase = {
    ClassName = "DCAF_AirServiceBase",
    ----
    Airbase = nil,          -- #AIRBASE
    ParkingSpots = nil,     -- list of parking slots (numbers)
    Routes = nil,           -- list of #DCAF.AIR_ROUTE
    RTBRoutes = nil         -- list of #DCAF.AIR_ROUTE
}

local DCAF_ParkingSpotInfo = {
    ClassName = "DCAF_ParkingSlotInfo",
    ----
    Number = -1,            -- the DCS parking spot number (has to be relevant to airbase)
}

function DCAF_ParkingSpotInfo:New(number, airbase)
    local slot = DCAF.clone(DCAF_ParkingSpotInfo)
    slot.Number = number
    slot.Airbase = airbase
    return slot
end

function DCAF_ParkingSpotInfo:IsOccupied()
    local freeSpots = self.Airbase:GetFreeParkingSpotsTable(AIRBASE.TerminalType.FighterAircraft) -- actually means "fixed wing aircraft"
    local function isInFreeSpots()
        for _, spot in ipairs(freeSpots) do
            if spot.TerminalID == self.Number then return spot end
        end
    end
    return not isInFreeSpots()
end

function DCAF_AirServiceBase:New(airbase, parkingSpots)
    local base = DCAF.clone(DCAF_AirServiceBase)
    base.Airbase = airbase
    if isList(parkingSpots) then
        local spots = {}
        for _, number in ipairs(parkingSpots) do
            spots[#spots+1] = DCAF_ParkingSpotInfo:New(number, airbase)
        end
        base.ParkingSpots = spots
    end
    return base
end

function DCAF_AirServiceBase:AddRoute(route)
    if not isList(self.Routes) then
        self.Routes = {}
    end
    table.insert(self.Routes, route)
    return self
end

function DCAF_AirServiceBase:AddRTBRoute(rtbRoute)
    if not isList(self.RTBRoutes) then
        self.RTBRoutes = {}
    end
    table.insert(self.RTBRoutes, rtbRoute)
    return self
end

function DCAF_AirServiceBase:_getAvailableParkingSpots()
    if not self.ParkingSpots then return end
    local spots = {}
    for _, spot in ipairs(self.ParkingSpots) do
        if not spot:IsOccupied() then
            spots[#spots+1] = spot
        end
    end
    if #spots == 0 then return end
    return spots
end

local function serviceRTB(service, airbase, onLandedFunc)
    local _, waypoints = RTBNow(service.Group, airbase or service.RTBAirbase, onLandedFunc)
    CommandDeactivateBeacon(service.Group)
    return service, waypoints
end

local function serviceSpawnReplacement(service, funcOnSpawned, nDelay)
    local self = service
    if self:IsMissing() then
        return self end

    local function spawnNow()
        service.Spawner = service.Spawner or getSpawn(self.Group.GroupName)
        local group = service.Spawner:Spawn()
        if isClass(service, DCAF_SERVICE_TYPE.Tanker) then
            DCAF.Tanker:New(group, self)
        elseif isClass(service, DCAF_SERVICE_TYPE.AWACS) then
            DCAF.AWACS:New(group, self)
        end
        if isFunction(funcOnSpawned) then
            funcOnSpawned(group)
        end
    end

    if isNumber(nDelay) then
        Delay(nDelay, spawnNow)
    else
        return spawnNow()
    end
    return self
end

function DCAF.Tanker:RTB(airbase, onLandedFunc, route)
    local waypoints
    if isTable(route) then
        self:SetRoute(route)
        if isFunction(onLandedFunc) then
            local wpLanding = GetLandingWaypoint(route)
            if wpLanding then
                WaypointCallback(wpLanding, onLandedFunc)
            end
        end
        waypoints = route.Waypoints
    else
        _, waypoints = serviceRTB(self, airbase, onLandedFunc)
    end
    if self.Behavior.Availability == DCAF.AirServiceAvailability.Always and not self.IsBingo then
        -- inject new 'ACTIVATE' WP, to ensure tankers keeps serving fuel while RTB...
        local wp1 = waypoints[1]
        local coord = self.Group:GetCoordinate()
        local hdg = self.Group:GetHeading() --  coord:GetHeadingTo(COORDINATE_FromWaypoint(wp1))
        local speed = self.Group:GetUnit(1):GetVelocityKMH()
        local wpStart = coord:WaypointAirTurningPoint(COORDINATE.WaypointAltType.BARO, speed)
        local wpActivate = coord:Translate(NauticalMiles(1), hdg):WaypointAirTurningPoint(COORDINATE.WaypointAltType.BARO, speed)
        table.insert(waypoints, 1, wpStart)
        table.insert(waypoints, 2, wpActivate)
        -- todo consider deactivating at some waypoint near the homeplate
        self:ActivateService(1, waypoints)
    end
    self.IsRTB = true
    if isFunction(self._onRTBFunc) then
        self._onRTBFunc(self._onRTBFuncArg)
    end
    return self
end

function DCAF.Tanker:OnRTB(func, arg)
    if not isFunction(func) then
        return Error("DCAF.Ranker:OnRTB :: `func` must be function, bus was: " .. DumpPretty(func)) end

    self._onRTBFunc = func
    self._onRTBFuncArg = arg
    return self
end

-- function DCAF.Tanker:RTBBingo(airbase, onLandedFunc, route) obsolete
--     self.IsBingo = true
--     local asb
--     if isClass(airbase, DCAF_AirServiceBase) then
--         asb = airbase
--         airbase = asb.Airbase
--         -- todo Consider automatically pick an RTB route when available...
--     end
--     return self:RTB(airbase, onLandedFunc, route)
-- end

function DCAF.Tanker:DespawnOnLanding(nDelaySeconds)
    DestroyOnLanding(self.Group, nDelaySeconds)
    return self
end

function DCAF.Tanker:SpawnReplacement(funcOnSpawned, nDelay)
    return serviceSpawnReplacement(self, funcOnSpawned, nDelay)
end

function DCAF.AWACS:IsMissing()
    return not self.Group
end

function DCAF.AWACS:New(controllable, replicate, callsign, callsignNumber)
    local awacs = DCAF.clone(replicate or DCAF.AWACS)
    awacs._isTemplate = false
    local group = getGroup(controllable)
    if not group then
        -- note: To make code API more versatile we accept a missing group. This allows for reusing same script in missions where not all AWACS are present
        Warning("DCAF.AWACS:New :: cannot resolve group from " .. DumpPretty(controllable))
        return awacs
    end

    -- initiate AWACS ...
    awacs.Group = group
    local defaults
    if callsign ~= nil then
        if not isNumber(callsign) then
            error("DCAF.AWACS:New :: `callsign` must be number but was " .. type(callsign))  end
        if not isNumber(callsignNumber) then
            error("DCAF.AWACS:New :: `callsignNumber` must be number but was " .. type(callsignNumber))  end
        defaults = DCAF_AWACS[callsign][callsignNumber]
    else
        callsign, callsignNumber = GetCallsign(group)
        defaults = DCAF_AWACS[CALLSIGN.AWACS:FromString(callsign)][callsignNumber]
    end
    Trace("DCAF.DCAF_AWACS:New :: callsign: " .. Dump(callsign) .. " " .. Dump(callsignNumber) .. " :: defaults: " .. DumpPrettyDeep(defaults))
    if defaults then
        awacs.TrackBlock = defaults.TrackBlock
        awacs.TrackSpeed = defaults.TrackSpeed
    else
        awacs.TrackBlock = 35
        awacs.TrackSpeed = 430
    end
    awacs.RTBAirbase = GetRTBAirbaseFromRoute(group)

    if awacs.Track and awacs.Track.Route then
        -- replicate route from previous AWACS ...
        group:Route(awacs.Track.Route)
    end

    -- register all events (from replicate)
    for _, event in pairs(awacs.Events) do
        event.EventFunc(event.Args)
    end

    return awacs
end

function DCAF.AWACS:NewFromCallsign(callsign, callsignNumber)
    if callsign == nil then
        error("DCAF.AWACS:New :: callsign group was not specified") end

    local group
    local groups = _DATABASE.GROUPS
    local callsignName = CALLSIGN.AWACS:ToString(callsign)
    for _, g in pairs(groups) do
        if g:IsAir() then
            local csName, csNumber = GetCallsign(g:GetUnit(1))
            if csName == callsignName and csNumber == callsignNumber then
                group = g
                break
            end
        end
    end

    return DCAF.AWACS:New(group)
end

function DCAF.AWACS:GetWaypoints()
    return getAirServiceWaypoints(self)
end

function DCAF.AWACS:SetTrack(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 0, 1, 1 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
end

function DCAF.AWACS:SetTrackDirect(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 0, 1, 1 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, true)
end

function DCAF.AWACS:OnFuelState(state, func)
    if not isFunction(func) then
        error("DCAF.Tanker:OnFuelState :: func was unassigned/unexpected value: " .. DumpPretty(func)) end

    return onFuelState(self, state, func)
end

function DCAF.AWACS:OnBingoState(func)
    return self:OnFuelState(0.15, func)
end

function DCAF.AWACS:Start(delay)
    if self:IsMissing() then
        return self end

    if isNumber(delay) then
        Delay(delay, function()
            activateNow(self.Group)
        end)
    else
        activateNow(self.Group)
    end
    return self
end

function DCAF.AWACS:SetRoute(route)
    SetAirServiceRoute(self, route)
    return self
end

function DCAF.AWACS:RTB(airbase, onLandedFunc)
    return serviceRTB(self, airbase, onLandedFunc)
end

function DCAF.AWACS:DespawnOnLanding(nDelaySeconds)
    DestroyOnLanding(self.Group, nDelaySeconds)
    return self
end

function DCAF.AWACS:SpawnReplacement(funcOnSpawned, nDelay)
    return serviceSpawnReplacement(self)
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                         AIR SERVICE TRACKS / ASSIGNMENTS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.AirServiceAvailability = {
    InTrack = "In Track",
    Always = "Always"
}

DCAF.AirServiceBehavior = {
    ClassName = "DCAF.AirServiceBehavior",
    SpawnReplacementFuelState = 0, --.22,
    BingoFuelState = .17,    -- #number - percentage of full fuel that defines BINGO fuel state
    RtbAirdrome = nil,       --
    Availability = DCAF.AirServiceAvailability.InTrack,
    NotifyAssignmentScope = '_none_', -- #Any - coalition (eg. coalition.side.BLUE), #GROUP (or group name) or '_none_'
    MaxExtendDownwindLeg = nil,       -- meters - specifies how much the tanker can extend the downwind leg when someone's plugged in
    MaxExtendHeadwindLeg = nil,       -- meters - specifies how much the tanker can extend the headwind leg when someone's plugged in
}

function DCAF.AirServiceBehavior:New()
    return DCAF.clone(DCAF.AirServiceBehavior)
end

function DCAF.AirServiceBehavior:RTB(airdrome, fuelState)
    if airdrome ~= nil and not isAssignedString(airdrome) then
        error("DCAF.AirServiceBehavior:RTB :: `airdrome` is expected to be a string, but was " .. type(airdrome)) end

    if not isNumber(fuelState) then
        fuelState = DCAF.AirServiceBehavior.BingoFuelState
    end
    self.RtbAirdrome = AIRBASE:FindByName(airdrome)
    self.BingoFuelState = fuelState
    return self
end

function DCAF.AirServiceBehavior:NotifyAssignment(recipient)
    self.NotifyAssignmentScope = recipient
    return self
end

function DCAF.AirServiceBehavior:SpawnReplacement(fuelState)
    if not isNumber(fuelState) then
        error("DCAF.AirServiceBehavior:SpawnReplacement :: `fuelState` is expected to be number, but was " .. type(fuelState)) end

   self.SpawnReplacementFuelState = fuelState
   return self
end

function DCAF.AirServiceBehavior:WithAvailability(availability, delaySeconds)
    if not DCAF.AirServiceAvailability:IsValid(availability) then
        error("DCAF.AirServiceBehavior:SetAvailability :: invalid value: " .. DumpPretty(availability)) end

    if availability == DCAF.AirServiceAvailability.Delayed then
        if not isNumber(delaySeconds) or delaySeconds < 1 then
            error("DCAF.AirServiceBehavior:SetAvailability :: `delaySeconds` musty be positive value, but was: " .. Dump(delaySeconds)) end

        self.AvailabilityDelay = delaySeconds
    end
    self.Availability = availability
    return self
end

function DCAF.AirServiceBehavior:SetMaxExtendLegs(downwind, headwind)
    if isNumber(downwind) and downwind > 0 then
        self.MaxExtendDownwindLeg = downwind
    end
    if isNumber(headwind) and headwind > 0 then
        self.MaxExtendHeadwindLeg = headwind
    end
    return self
end

function DCAF.AirServiceAvailability:IsValid(value)
    if not isAssignedString(value) then
        return false end

    for k, v in pairs(DCAF.AirServiceAvailability) do
        if value == v then
            return true
        end
    end
    return false
end

DCAF.AvailableTanker = {
    ClassName = "DCAF.AvailableTanker",
    Callsign = nil,       -- #number
    Number = nil,         -- #number
    Group = nil,          -- #GROUP
    Track = nil,          -- #DCAF.TankerTrack
    Unlimited = false,    -- #bool - true = any number of this tanker can be spawned; false = tanker can be respawned 15 mins after landing
    PendingCommand = nil, -- #DCAF_TankerCommand
    DelayAvailability = Minutes(15), -- #int (seconds) - < 0 = can be spawned when goes active; 0 = can be spawned when landed; > 0 = can be spawned after delay
    DelayPendingCommands = Minutes(3), --  #int (seconds) - specifies how long to delay pending commands (Reassign/RTB...) after 'chick' unplugs
    TurnaroundTime = Minutes(5), -- #number - time needed for a tanker until it becomes available for new tasking after RTB
    TrackBlock = 16      -- #number - block (1000x feet)
}

local AAR_TANKERS = {
    -- list of #DCAF.AvailableTanker
}

DCAF.TankerTracks = {
    -- list of #DCAF.TankerTrack
}

DCAF.TrackAppearance = {
    IdleColor = {0, .5, .5},
    ActiveColor = {0, 1, 1},
}

function DCAF.TrackAppearance:New(idleColor, activeColor)
    local appearance = DCAF.clone(DCAF.TrackAppearance)
    appearance.IdleColor = idleColor or DCAF.TrackAppearance.IdleColor
    appearance.ActiveColor = activeColor or DCAF.TrackAppearance.ActiveColor
    return appearance
end

local DCAF_TankerCommand = {
    ClassName = "DCAF_TankerCommand",
    ------------
    Command = nil,          -- #string - can be 'Reassign' or 'RTB'
}

function DCAF_TankerCommand:NewReassign(toTrack)
    local cmd = DCAF.clone(DCAF_TankerCommand)
    cmd.Command = "Reassign"
    cmd.ReassignTrack = toTrack
    return cmd
end

function DCAF_TankerCommand:NewRTB(airdromeName, onLandedFunc, route)
    local cmd = DCAF.clone(DCAF_TankerCommand)
    cmd.Command = "RTB"
    cmd.RTBAirdromeName = airdromeName
    cmd.RTBLandedFunc = onLandedFunc
    cmd.RTBRoute = route
    return cmd
end

function DCAF_TankerCommand:NewUpdateMobileTrackRoute(track)
    local cmd = DCAF.clone(DCAF_TankerCommand)
    cmd.Command = "NewUpdateMobileTrackRoute"
    cmd.Track = track
    return cmd
end

--- Creates and returns a new #DCAF.AvailableTanker object
-- @param #number callsign : The tanker callsign (please refer to core #CALLSIGN.Tanker enumerator)
-- @param #number number : Callsign number, must be positive value
-- @param #number number : (optional) Specifies turnaround time (see: DCAF.AvailableTanker:InitTurnaroundTime)
-- @param #string or #list of #string/#AIRBASE : (optional) Specifies one or more #AIRBASEs (see: DCAF.AvailableTanker:FromAirbase)
function DCAF.AvailableTanker:New(callsign, number, turnaroundTime, airbases)
    if not isNumber(callsign) then
        error("DCAF.AvailableTanker:New :: `callsign` must be number, but was: " .. DumpPretty(callsign)) end
    if not isNumber(number) then
        error("DCAF.AvailableTanker:New :: `number` must be number, but was: " .. DumpPretty(number)) end

    local tanker = DCAF.clone(DCAF.AvailableTanker)
    tanker.Callsign = callsign
    tanker.Number = number
    if isNumber(turnaroundTime) then
        tanker:InitTurnaroundTime(turnaroundTime)
    end
    if isAssignedString(airbases) then
        airbases = { airbases }
    end
    if (isList(airbases)) then
        for _, airbase in ipairs(airbases) do
            tanker:FromAirbase(airbase)
        end
    end
    table.insert(AAR_TANKERS, tanker)
    return tanker
end

function DCAF.AvailableTanker:Find(callsign, number)
    for _, tanker in ipairs(AAR_TANKERS) do
        if tanker.Callsign == callsign and tanker.Number == number then return tanker end
    end
end

function DCAF.AvailableTanker:_getAirbaseInfo(airbase)
    if not self.Airbases then return end
    local airbaseName
    if isAssignedString(airbase) then
        airbaseName = airbase
    elseif isAirbase(airbase) then
        airbaseName = airbase.AirbaseName
    else
        return Error("DCAF.AvailableTanker:_getAirbaseInfo :: cannot resolve airbase from: " .. DumpPretty(airbase))
    end
    for _, airServiceBase in ipairs(self.Airbases) do
        if airServiceBase.Airbase.AirbaseName == airbaseName then return airServiceBase end
    end
end

function DCAF.AvailableTanker:_enforceCallsign(spawn)
    spawn:InitCallSign(self.Callsign, CALLSIGN.Tanker:ToString(self.Callsign), self.Number, 1)
end

--- Sets the amount of time needed for a tanker until it becomes available for new tasking after RTB
-- @param #number value : Time in seconds
function DCAF.AvailableTanker:InitTurnaroundTime(value)
    if not isNumber(value) then
        return Error("DCAF.AvailableTanker:InitTurnaroundTime :: `value` must be number, but was: " .. DumpPretty()) end

    self.TurnaroundTime = math.max(1, value)
end

--- Sets the default track altitude. This value will override the default for the specified callsign
-- @param #number value : Altitude in 1000 feet
function DCAF.AvailableTanker:InitTrackBlock(value)
    if not isNumber(value) then
        return Error("DCAF.AvailableTanker:InitBlock :: `value` must be number, but was: " .. DumpPretty()) end

    self.TrackBlock = value
    return self
end

--- Sets the default track speed. This value will override the default for the specified callsign
-- @param #number value - Speed, as knots
-- @param #Any altitudeCorrect - (optional) When set as boolean, if a track block was set, speed will be corrected for that altitude. If a number (feet) is specified speed will be corrected for that altitude
function DCAF.AvailableTanker:InitTrackSpeed(value, altitudeCorrect)
    if not isNumber(value) then
        return Error("DCAF.AvailableTanker:InitTrackSpeed :: `value` must be number, but was: " .. DumpPretty()) end

    if not altitudeCorrect then
        self.TrackSpeed = value
        return self
    end
    if isBoolean(altitudeCorrect) then
        if not self.TrackBlock then
            Warning("DCAF.AvailableTanker:InitTrackSpeed :: was not altitude corrected; no track block has been specified")
            self.TrackSpeed = value
            return self
        end
        value = UTILS.KnotsToAltKIAS(value, self.TrackBlock * 1000)
    elseif isNumber(altitudeCorrect) then
        value = UTILS.KnotsToAltKIAS(value, altitudeCorrect)
    end
    self.TrackSpeed = value
    return self
end

--- Specifies whether air starts should be available or not
-- @param #boolean value : (optional; default = true), true = makes air starts available, false = air starts will not be available
function DCAF.AvailableTanker:InitAirStartAvailable(value)
    if value == nil then
        value = true
    end
    if not isBoolean(value) then
        return Error("DCAF.AvailableTanker:InitAirStartAvailable :: `value` must be boolean, but was: " .. DumpPretty(value)) end

    self.IsAirStartEnabled = value
    return self
end

function DCAF.AvailableTanker:SetPendingCommand(command)
    self.PendingCommand = command
end

function DCAF.AvailableTanker:IsActive()
    return self.Group
end

function DCAF.AvailableTanker:GetRTBAirbase()
    local airbase = self.Tanker.Behavior.RtbAirdrome
    if airbase then
        return airbase end

    local distanceNearestAirbase = 999999999
    for _, airServiceBase in ipairs(self.Airbases) do
        local ab = airServiceBase.Airbase
        local distance = ab:GetCoordinate():Get2DDistance(self.Tanker.Group:GetCoordinate())
        if distance < distanceNearestAirbase then
            distanceNearestAirbase = distance
            airbase = airServiceBase
        end
    end
    return airbase
end

local rebuildTankerMenus

function DCAF.AvailableTanker:OnRTB(func, arg)
    if not isFunction(func) then
        return Error("DCAF.AvailableTanker:OnRTB :: `func` must be function, but was: " .. DumpPretty(func)) end

    self._onRTBFunc = function(a)
        self.IsRTB = true
        if self.Track then
            self.Track:RemoveTanker(self)
        end
        self._onTankerRTBFunc(a)
        rebuildTankerMenus()
    end
    self._onTankerRTBFunc = func
    self._onRTBFuncArg = arg
    if self.Tanker then
        self.Tanker:OnRTB(self._onRTBFunc, arg)
    end
    return self
end

function DCAF.AvailableTanker:OnStartAAR(chick)
end

function DCAF.AvailableTanker:OnStopAAR(chick)
end

local function findClosestAvailableTanker(location)
    local loc = DCAF.Location.Resolve(location)
    if not loc then
        return Error("findClosestAvalableTanker :: cannot resolve `location`: " .. DumpPretty(location)) end

    local closestAvblTanker
    local closestAvblTankerDistance = 9999999
    local coord = location:GetCoordinate()
    for _, avblTanker in ipairs(AAR_TANKERS) do
        if avblTanker:IsActive() then
            local distance = coord:Get2DDistance(avblTanker.Group:GetCoordinate())
            if distance < closestAvblTankerDistance then
                closestAvblTanker = avblTanker
                closestAvblTankerDistance = distance
            end
        end
    end
    return closestAvblTanker, closestAvblTankerDistance
end

function DCAF.AvailableTanker:Activate(group, track)
    self.Group = group
    self.GroupRTB = nil
    self.Track = track

    self._onStartAAR = function(event)
        local closestTanker = findClosestAvailableTanker(event.IniUnit)
        if closestTanker == self then
            self.ChickInTow = event.IniUnit
            self:OnStartAAR(event.IniUnit)
        end
    end

    self._onStopAAR = function(event)
        local closestTanker, distance = findClosestAvailableTanker(event.IniUnit)
        if closestTanker == self then
            self:OnStopAAR(event.IniUnit)
            self.ChickInTow = nil
            self:ExecutePendingCommand(self.DelayPendingCommands or Minutes(3))
        end
    end

    MissionEvents:OnStartAAR(self._onStartAAR)
    MissionEvents:OnStopAAR(self._onStopAAR)

    return self
end

function DCAF.AvailableTanker:Deactivate(isRTB)
    if not isBoolean(isRTB) then
        isRTB = true
    end
    if isRTB then
        self.GroupRTB = self.Group
    end
    self.Group = nil
    self.Track = nil

    MissionEvents:EndOnStartAAR(self._onStartAAR)
    MissionEvents:EndOnStopAAR(self._onStopAAR)
    self._onStartAAR = nil
    self._onStopAAR = nil

    return self
end

function DCAF.AvailableTanker:ExecutePendingCommand(delay)
    if not self.PendingCommand or self.ChickInTow then
        return end

    if isNumber(delay) then
        DCAF.delay(function()
            self:ExecutePendingCommand()
        end, delay)
        return
    end

    if self.PendingCommand.Command == "RTB" then
        local cmd = self.PendingCommand
        self:RTB(cmd.RTBAirdromeName, cmd.RTBLandedFunc, cmd.RTBRoute)
    elseif self.PendingCommand.Command == "Reassign" then
        self.PendingCommand.ReassignTrack:Reassign(self)
    end
    self.PendingCommand = nil
end

local function DCAF_AvailableTanker_ReEnable(availableTanker)
    availableTanker.IsRTB = nil
    availableTanker.GroupTurnaround = availableTanker.GroupRTB
    availableTanker.GroupRTB = nil
    availableTanker.TurnaroundReadyTime = UTILS.SecondsToClock(UTILS.SecondsOfToday(), true, true)
    DCAF.delay(function()
            availableTanker.TurnaroundReadyTime = nil
-- DebugMessageTo(nil, "Tanker is now available", 120)
            rebuildTankerMenus()
        end,
    availableTanker.TurnaroundTime)
    rebuildTankerMenus()
end

function DCAF.AvailableTanker:RTB(airdromeName, onLandedFunc, route, allowPostpone)
    if not airdromeName and self.Tanker.Behavior.RtbAirdrome then
        airdromeName = self.Tanker.Behavior.RtbAirdrome.AirbaseName
    end
    if not isBoolean(allowPostpone) then
        allowPostpone = true
    end
    if self.ChickInTow and allowPostpone then
        -- can't RTB when someone's refueling...
        self:SetPendingCommand(DCAF_TankerCommand:NewRTB(airdromeName, onLandedFunc, route))
        return
    end
    local airdrome
    if airdromeName then
        airdrome = AIRBASE:FindByName(airdromeName)
    end

    local function onLanded()
        DCAF_AvailableTanker_ReEnable(self)
        if isFunction(onLandedFunc) then
            onLandedFunc()
        end
    end

    if self.Track then
        self.Track:RemoveTanker(self, true)
        self:Deactivate(true)
    end
    self.Tanker:RTB(airdrome, onLanded, route)
end

function DCAF.AvailableTanker:RTBBingo()
    local airbase = self:GetRTBAirbase()
    if isClass(airbase, DCAF_AirServiceBase) then
        airbase = airbase.Airbase
    end
    self:RTB(airbase.AirbaseName, nil, nil, false)
end

function DCAF.AvailableTanker:RTBImmediately(airdromeName, onLandedFunc, route)
    self:RTB(airdromeName, onLandedFunc, route, false)
end

function DCAF.AvailableTanker:ToString()
    return CALLSIGN.Tanker:ToString(self.Callsign, self.Number)
end

function DCAF.AvailableTanker:FromAirbases(airbases)
    if not isList(airbases) then
        error("DCAF.AvailableTanker:FromAirbases :: `airbases` must be a list, but was: " .. DumpPretty) end

    for _, airbase in ipairs(airbases) do
        self:FromAirbase(airbase)
    end
    return self
end

--- Enables the use of one or more airbases for the tanker
-- @param #Any airbase - specifies an #AIRBASE, or a list of #AIRBASE objects
-- @param #list depRoutes - (optional) a list of #DCAF.AIR_ROUTE to be used for departures (requires DCAF.AIRAC)
-- @param #list arrRoutes - (optional) a list of #DCAF.AIR_ROUTE to be used for recoveries (requires DCAF.AIRAC)
-- @param #list parkingSlots - (optional) a list of parking slots to be available for spawning tanker
function DCAF.AvailableTanker:FromAirbase(airbase, depRoutes, arrRoutes, parkingSlots)
    if isList(airbase) then
        if #airbase == 1 then
            return self:FromAirbase(airbase[1], depRoutes, arrRoutes)
        end
        -- special case: Caller passed multiple airbases at once. This means it cannot also specify dep/arr routes, as those are dependent on individual airbases
        if depRoutes or arrRoutes then
            return Error("DCAF.AvailableTanker:FromAirbase :: passing a list of airbases prohibits also passing `depRoutes` or `arrRoutes`") end

        for _, a in ipairs(airbase) do
            self:FromAirbase(a)
        end
        return self
    end

    if not isList(self.Airbases) then
        self.Airbases = {}
    end
    if isAssignedString(airbase) then
        local testAirbase = AIRBASE:FindByName(airbase)
        if not testAirbase then
            error("DCAF.AvailableTanker:FromAirbase :: cannot resolve airbase from: " .. DumpPretty(airbase)) end

        airbase = testAirbase
    elseif not isAirbase(airbase) then
        error("DCAF.AvailableTanker:FromAirbase :: expected `airbase` to be #AIRBASE, or assigned string (airbase name), but was: " .. DumpPretty(airbase))
    end
    local base = DCAF_AirServiceBase:New(airbase, parkingSlots)
    table.insert(self.Airbases, base)
    if not isList(depRoutes) and DCAF.AIRAC then
        depRoutes = DCAF.AIRAC:GetDepartureRoutes(airbase)
    end
    local hasRoutes = isList(depRoutes)
    if hasRoutes then
        for i, route in ipairs(depRoutes) do
            if isClass(route, DCAF.AIR_ROUTE.ClassName) then
                base:AddRoute(route)
            else
                error("DCAF.AvailableTanker:FromAirbase :: route #" .. Dump(i) .. " was not type '" .. DCAF.AIR_ROUTE.ClassName .. "'")
            end
        end
    end
    if not isList(arrRoutes) then
        if DCAF.AIRAC then
            arrRoutes = DCAF.AIRAC:GetArrivalRoutes(airbase)
        elseif hasRoutes then
            -- use reversed routes for RTB...
            arrRoutes = {}
            for _, route in ipairs(depRoutes) do
                local revRoute = route:CloneReversed("(rev) " .. route.Name)
                local coordLanding = route.DepartureAirbase:GetCoordinate()
                local wpLanding = coordLanding:WaypointAirLanding(250, route.DepartureAirbase)
                table.insert(revRoute.Waypoints, #revRoute.Waypoints+1, wpLanding)
                table.insert(arrRoutes, revRoute)
            end
        end
    end
    if isList(arrRoutes) then
        for i, arrRoute in ipairs(arrRoutes) do
            if isClass(arrRoute, DCAF.AIR_ROUTE.ClassName) then
                base:AddRTBRoute(arrRoute)
            else
                Error("DCAF.AvailableTanker:FromAirbase :: route #" .. Dump(i) .. " was not type '" .. DCAF.AIR_ROUTE.ClassName .. "'")
            end
        end
    end

    return self
end

--- Makes the tanker automatically take off on mission start, with an optional delay
-- @param #Any airbaseOrRoute - (optional) #AIRASE or #DCAF.AIR_ROUTE (that must originate at airbase). Pass nil for air start (CAUTION: Air start must be enabled or command is ignored)
-- @param #DCAF.TankerTrack track - assigns the tanker to fly a track (this is mandatory)
-- @param #number delaySeconds - (optional; default = 0) specifies a delay after mission start before tanker is activated for takeoff
-- @param #DCAF.AirServiceBehavior behavior - (optional) specifies tanker behavior
function DCAF.AvailableTanker:Start(track, airbaseOrRoute, delaySeconds, behavior)
    if not isClass(track, DCAF.TankerTrack) then
        return Error("DCAF.AvailableTanker:StartFromAirbase :: `track` must be #" .. DCAF.TankerTrack.ClassName .. ", but was: " .. DumpPretty(track)) end

    if airbaseOrRoute == nil and not not self.IsAirStartEnabled then
        return Error("DCAF.AvailableTanker:StartNow  :: cannot start tanker " .. self:ToString() .. ". No airbase or route was specified, and air start is not available") end

    if isVariableValue(delaySeconds) then
        delaySeconds = delaySeconds:GetValue()
    end
    if not isNumber(delaySeconds) then
        delaySeconds = 0
    end
    DCAF.delay(function()
-- MessageTo(nil, "Tanker " .. self:ToString() .. " takes off from " .. airbaseOrRoute.AirbaseName .. " for " .. track.Name .. " track") -- nisse
        if airbaseOrRoute then
            track:ActivateAirbase(self, airbaseOrRoute, behavior)
        else
            track:ActivateAir(self, behavior)
        end
    end, delaySeconds)

    return self
end

function DCAF.AvailableTanker:StartAir(track, delaySeconds, behavior)
    if not isClass(track, DCAF.TankerTrack) then
        return Error("DCAF.AvailableTanker:StartAir :: `track` must be #" .. DCAF.TankerTrack.ClassName .. ", but was: " .. DumpPretty(track)) end

    if isVariableValue(delaySeconds) then
        delaySeconds = delaySeconds:GetValue()
    end
    if not isNumber(delaySeconds) then
        delaySeconds = 0
    end
    DCAF.delay(function()
-- MessageTo(nil, "Tanker " .. self:ToString() .. " takes off from " .. airbaseOrRoute.AirbaseName .. " for " .. track.Name .. " track") -- nisse
        track:ActivateAir(self, behavior)
    end, delaySeconds)
    return self
end

DCAF.TankerTrack = {
    ClassName = "DCAF.TankerTrack",
    Name = nil,
    CoordIP = nil,
    Heading = nil,
    Length = nil,
    Capacity = 99,          -- #number - no. of tankers thack can work this track
    DefaultBehavior = nil,  -- #DCAF.AirServiceBehavior
    DrawIdle = true,
    IsDynamic = false,      -- #boolean - true = track was created from a F10 map marker
    Tankers = {
        -- list of #DCAF.AvailableTanker (currently active in track)
    },
    RestrictTankers = {
        -- list of ##DCAF.AvailableTanker allowed to work the track (a typical use if to restrict naval recovery tracks to carrier tankers)
    },
    Frequencies = {
        -- list of #number (primary + secondary frequency, if used)
    },
    Blocks = {
        -- list i #number (primary + secondary altitude block [in K of feet MSL], is used)
    },
    Width = NauticalMiles(13),
    InfoAnchorPoint = nil        -- #number - nil = (auto), 1..4 = Southeast, Northeast, Northwest, and Southwest corner in north-facing track (rotates with track heading)
}

local function getFrequency(track)
    if not track.Frequencies or #track.Frequencies == nil then
        return end

    local index = #track.Tankers+1
    return track.Frequencies[index]
end

local function getBlock(track)
    if not track.Blocks or #track.Blocks == nil then
        return end

    local index = #track.Tankers+1
    return track.Blocks[index]
end

function DCAF.TankerTrack:New(name, coalition, heading, ip, length, frequencies, blocks, capacity, behavior, appearance)
    local coordIP

    local function processIP_and_heading()
        local locIP = DCAF.Location.Resolve(ip)
        if not locIP then
            error("DCAF.TankerTrack:New :: cannot resolve track IP location from `ip`: " .. DumpPretty(locIP)) end

        coordIP = locIP:GetCoordinate()
        if isNumber(length) then
            return end

        local locEnd = DCAF.Location.Resolve(length)
        if not locEnd then
            error("DCAF.TankerTrack:New :: cannot resolve track length from: " .. DumpPretty(locIP)) end

        local coordEnd = locEnd:GetCoordinate()
        length = coordEnd:Get2DDistance(coordIP)
        heading = coordIP:GetHeadingTo(locEnd)
    end
    processIP_and_heading()

    local track = DCAF.clone(DCAF.TankerTrack)
    track.Name = name
    track.Heading = heading
    track.IsMobile = ip.IsControllable
    if track.IsMobile then
        track.MobileIP = ip
        track.CoordIP = ip:GetOffset():GetCoordinate()
    else
        track.CoordIP = coordIP
    end
    track.Length = length or NauticalMiles(30)
    track.Capacity = capacity or DCAF.TankerTrack.Capacity
    track.DefaultBehavior = behavior or DCAF.TankerTrack.DefaultBehavior
    track.Appearance = appearance or DCAF.TrackAppearance:New()
    track.Coalition = Coalition.ToNumber(coalition)
    if isTable(frequencies) then
        track.Frequencies = frequencies
    else
        track.Frequencies = {}
    end
    if isTable(blocks) then
        track.Blocks = blocks
    else
        track.Blocks = {}
    end
    table.insert(DCAF.TankerTracks, track)
    return track
end

function DCAF.TankerTrack:Find(name)
    for _, track in ipairs(DCAF.TankerTracks) do
        if track.Name == name then return track end
    end
end

function DCAF.TankerTrack:AddTanker(tankerInfo, drawUpdate)
    if not isBoolean(drawUpdate) then
        drawUpdate = true
    end
    table.insert(self.Tankers, tankerInfo)
    if (drawUpdate and self.IsDrawn) then
        self:Draw()
    end
end

function DCAF.TankerTrack:RemoveTanker(tankerInfo, drawUpdate)
    if not isBoolean(drawUpdate) then
        drawUpdate = true
    end
    local index = tableIndexOf(self.Tankers, function(info)
        return info.Callsign == tankerInfo.Callsign and info.Number == tankerInfo.Number
    end)
    if index then
        table.remove(self.Tankers, index)
        if #self.Tankers == 0 then
            self:Deactivate()
        end
        if (drawUpdate and self.IsDrawn) then
            self:Draw()
        end
    end
end

local function notifyTankerAssignment(track, tanker, isReassigned, airbase)
    local behavior = tanker.Behavior
    if behavior.NotifyAssignmentScope == '_none_' then
        return end

    local freq = tanker.Frequency
    local msg1, msg2
    if airbase then
        msg1 = tanker.DisplayName .. " is departing " .. airbase.AirbaseName .. " for track '" .. track.Name .. "' (freq: " .. string.format("%.3f", freq) .. ")"
        if behavior.Availability == DCAF.AirServiceAvailability.Always then
            msg2 = tanker.DisplayName .. " should be available in 10 minutes or less"
        else
            msg2 = tanker.DisplayName .. " will become available once it reaches the track"
        end
    elseif isReassigned then
        msg1 = tanker.DisplayName .. " was reassigned to track '" .. track.Name .. "' (freq: " .. string.format("%.3f", freq) .. ")"
    else
        msg1 = tanker.DisplayName .. " is approaching track '" .. track.Name .. "' (freq: " .. string.format("%.3f", freq)
    end

    local duration = 12
    MessageTo(behavior.NotifyAssignmentScope, msg1, duration)
    if not msg2 then
        msg2 = tanker.DisplayName .. " should be available in a minute or less"
        if behavior.Availability == DCAF.AirServiceAvailability.InTrack then
            msg2 = tanker.DisplayName .. " will become available once it reaches the track"
        end
    end
    MessageTo(behavior.NotifyAssignmentScope, msg2, duration)
end

--- Activates a tanker in air to work this track
--- @param tankerInfo DCAF.AvailableTanker  the tanker to be activated for the track
--- @param behavior DCAF.AirServiceBehavior  describes the tanker's behavior (such as availability etc)
--- @param location DCAF.Location  (optional; default=a few miles from track anchor) specifies start location
--- @param altitude number (optional; default=20000 feet) specifies start location altitude
function DCAF.TankerTrack:ActivateAir(tankerInfo, behavior, location, altitude)
    if tankerInfo.GroupRTB then
        self:Reassign(tankerInfo)
        return self
    end

    if tankerInfo.GroupTurnaround then
        tankerInfo.GroupTurnaround:Destroy()
    end

    local revHdg = ReciprocalAngle(self.Heading)
    local coordSpawn
Debug("nisse - DCAF.TankerTrack:ActivateAir :: location: " .. DumpPretty(location))
    if location == nil then
        coordSpawn = self.CoordIP:Translate(NauticalMiles(15), revHdg)
    else
        local validLocation = DCAF.Location.Resolve(location)
Debug("nisse - DCAF.TankerTrack:ActivateAir :: validLocation: " .. DumpPretty(validLocation))
        if not validLocation then
            Warning("DCAF.TankerTrack:ActivateAir :: cannot resolve `location` :: defaults to behind track anchor point")
            coordSpawn = self.CoordIP:Translate(NauticalMiles(15), revHdg)
        else
            coordSpawn = validLocation:GetCoordinate()
        end
    end
    if isNumber(altitude) then
        coordSpawn:SetAltitude(altitude)
    else
        coordSpawn:SetAltitude(Feet(20000))
    end
    local group = DCAF.Tanker:FindGroupWithCallsign(tankerInfo.Callsign, tankerInfo.Number)
    local spawn = getSpawn(group.GroupName)
    tankerInfo:_enforceCallsign(spawn)
Debug("nisse - DCAF.TankerTrack:ActivateAir :: group.GroupName: " .. group.GroupName .. " :: spawn: " .. DumpPretty(spawn))
    spawn:InitHeading(self.Heading, self.Heading)
    local speed = UTILS.KnotsToKmph(MachToKnots(.8))
    local wp0 = coordSpawn:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    local wp1 = self.CoordIP:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    local wp2
    if not isClass(behavior, DCAF.AirServiceBehavior) then
        behavior = self.DefaultBehavior or DCAF.AirServiceBehavior:New()
    end
    local availability = behavior.Availability
    local trackIP = 1
    if availability ~= DCAF.AirServiceAvailability.InTrack then
        if availability == DCAF.AirServiceAvailability.Always then
            -- inject nearby WP to activate service ...
            wp2 = wp1
            local coordActivate = coordSpawn:Translate(NauticalMiles(.5), self.Heading)
            wp1 = coordActivate:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
            trackIP = 2
        else
            error("DCAF.TankerTrack:ActivateAir :: unsupported availabilty behavior: " .. DumpPretty(availability))
        end
    end
Debug("nisse - DCAF.TankerTrack:ActivateAir :: coordSpawn: " .. DumpPretty(coordSpawn))
    local group = spawn:SpawnFromCoordinate(coordSpawn)
    group:CommandSetCallsign(tankerInfo.Callsign, tankerInfo.Number)
    tankerInfo.Tanker = DCAF.Tanker:New(group, nil, tankerInfo.Callsign, tankerInfo.Number)
                                   :SetRoute({ wp0, wp1, wp2 })
    if tankerInfo.TrackBlock then
        tankerInfo.Tanker.TrackBlock = tankerInfo.TrackBlock
    end
    if tankerInfo.TrackSpeed then
        tankerInfo.Tanker.TrackSpeed = tankerInfo.TrackSpeed
    end
    tankerInfo.Tanker.Behavior = behavior
    if tankerInfo._onRTBFunc then
        tankerInfo.Tanker:OnRTB(tankerInfo._onRTBFunc, tankerInfo._onRTBFuncArg)
    end
    local freq = getFrequency(self) or tankerInfo.Tanker.Frequency
    local block = getBlock(self) or tankerInfo.Tanker.TrackBlock
    if freq then
        tankerInfo.Tanker:InitFrequency(freq)
    end
    if availability == DCAF.AirServiceAvailability.Always then
        tankerInfo.Tanker:ActivateService(1)
    end
    tankerInfo.Tanker:SetTrack(trackIP, self.Heading, self.Length, block)
    if tankerInfo.Tanker.Behavior.SpawnReplacementFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.SpawnReplacementFuelState, function(tanker)
            tanker:SpawnReplacement()
        end)
    end
    if tankerInfo.Tanker.Behavior.BingoFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.BingoFuelState, function(tanker)
            tankerInfo:RTBBingo()
        end)
    end
    tankerInfo.Tanker:Start()
    tankerInfo:Activate(group, self)
    self:AddTanker(tankerInfo)
    notifyTankerAssignment(self, tankerInfo.Tanker)
    if DCAF.TankerTracks._isControllerMenusBuilt then
        rebuildTankerMenus()
    end
    return self
end

--- Activates a tanker at an airbase to work this track
-- @param #DCAF.AvailableTanker tankerInfo :: The activated tanker
-- @param #table waypoints :: can be #table of waypoints or #AIRBASE
-- @param #DCAF.AirServiceBehavior behavior :: Describes the tanker behavior (such as availability etc.)
function DCAF.TankerTrack:ActivateAirbase(tankerInfo, route, behavior)
    -- resolve route...
    local airbase
    local wpIP
    local waypoints
    local speed = UTILS.KnotsToKmph(MachToKnots(.8))

    local function trackIngressWaypoints()
        local revHdg = ReciprocalAngle(self.Heading)
        wpIP = self.CoordIP:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
        wpIP.name = "TRACK IP"
        local coordIngress = self.CoordIP:Translate(NauticalMiles(15), revHdg)
        coordIngress:SetAltitude(Feet(20000))
        local wpIngress = coordIngress:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
        wpIngress.name = "TRACK INGRESS"
        wpIngress.speed = speed
        return { wpIngress, wpIP }
    end

    if DCAF.AIR_ROUTE and isRoute(route) then
        airbase = route.DepartureAirbase
        waypoints = listJoin(route.Waypoints, trackIngressWaypoints())
        wpIP = #route.Waypoints
    elseif isAirbase(route) then
        airbase = route
        local coordAirbase = airbase:GetCoordinate()
        local wpDeparture = coordAirbase:WaypointAirTakeOffParkingHot(COORDINATE.WaypointAltType.BARO) -- todo consider ability to configure type of takeoff
        wpDeparture.airdromeId = airbase:GetID()
        waypoints = listJoin({ wpDeparture }, trackIngressWaypoints())
        wpIP = 2
    else
        local msg = "DCAF.TankerTrack:ActivateAirbase :: `route` must be an " .. AIRBASE.ClassName
        if DCAF.AIR_ROUTE then
            msg = msg .. " or " ..  DCAF.AIR_ROUTE.ClassName
        end
        error(msg)
    end
    if not isNumber(wpIP) then
        wpIP = 1
    end

    -- spawn...
    -- todo if GroupTurnaround exists, then respawn that group instead
    local group
    if tankerInfo.GroupTurnaround then
        group = tankerInfo.GroupTurnaround:RespawnAtCurrentAirbase()
    else
        group = DCAF.Tanker:FindGroupWithCallsign(tankerInfo.Callsign, tankerInfo.Number)
        local spawn = getSpawn(group.GroupName)
        tankerInfo:_enforceCallsign(spawn)
        spawn:InitGroupHeading(self.Heading)
        local airbaseInfo = tankerInfo:_getAirbaseInfo(airbase)
        local parkingSpots
        if airbaseInfo then
            parkingSpots = airbaseInfo:_getAvailableParkingSpots()
        end
        if parkingSpots then
            local freeParkingSpot = parkingSpots[1]
            local spots = { freeParkingSpot.Number }
            group = spawn:SpawnAtParkingSpot(airbaseInfo.Airbase, spots)
        else
            group = spawn:SpawnAtAirbase(airbase)
        end
    end
    tankerInfo.Tanker = DCAF.Tanker:New(group, nil, tankerInfo.Callsign, tankerInfo.Number)
    if tankerInfo._onRTBFunc then
        tankerInfo.Tanker:OnRTB(tankerInfo._onRTBFunc, tankerInfo._onRTBFuncArg)
    end
    if isClass(behavior, DCAF.AirServiceBehavior.ClassName) then
        tankerInfo.Tanker.Behavior = behavior
    else
        tankerInfo.Tanker.Behavior = self.DefaultBehavior or DCAF.AirServiceBehavior:New()
    end

    behavior = tankerInfo.Tanker.Behavior
    if behavior.Availability == DCAF.AirServiceAvailability.Always then
        -- inject WP 10nm from airbase, where the tanker activates...
        local coord0 = COORDINATE_FromWaypoint(waypoints[1])
        local coordIP = COORDINATE_FromWaypoint(waypoints[2])
        local distance = UTILS.MetersToNM(coord0:Get2DDistance(coordIP))
        if distance > 20 then
            local heading = coord0:HeadingTo(coordIP)
            local coordActivate = coord0:Translate(NauticalMiles(10))
            local wpActivate = coord0:Translate(NauticalMiles(10), heading):SetAltitude(Feet(15000)):WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
            table.insert(waypoints, 2, wpActivate)
            wpIP = wpIP+1
        end
    end
    tankerInfo.Tanker:SetRoute(waypoints)
    tankerInfo.Tanker.Behavior.RtbAirdrome = airbase

    local freq = getFrequency(self) or tankerInfo.Tanker.Frequency
    local block = getBlock(self) or tankerInfo.Tanker.TrackBlock
    if freq then
        tankerInfo.Tanker:InitFrequency(freq)
    end
    if behavior.Availability == DCAF.AirServiceAvailability.Always then
        tankerInfo.Tanker:ActivateService(1)
    end
    tankerInfo.Tanker:SetTrack(wpIP, self.Heading, self.Length, block):Start()
    if tankerInfo.Tanker.Behavior.SpawnReplacementFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.SpawnReplacementFuelState, function(tanker)
            tanker:SpawnReplacement()
        end)
    end
    if tankerInfo.Tanker.Behavior.BingoFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.BingoFuelState, function(tanker)
            tankerInfo:RTBBingo()
        end)
    end
    tankerInfo.Tanker:Start()
    tankerInfo:Activate(group, self)
    self:AddTanker(tankerInfo)
    notifyTankerAssignment(self, tankerInfo.Tanker, false, airbase)
    return self
end

--- Reassigns an already active tanker from its current track to this track
function DCAF.TankerTrack:Reassign(tankerInfo)
    if tankerInfo.ChickInTow then
        -- can't reassign when someone's refueling...
-- DebugMessageTo(nil, "reassignment pending...")
        tankerInfo:SetPendingCommand(DCAF_TankerCommand:NewReassign(self))
        return
    end

    if tankerInfo.GroupRTB then
        tankerInfo.Group = tankerInfo.GroupRTB
        tankerInfo.GroupRTB = nil
    end
    local speed = UTILS.KnotsToKmph(350)
    local coord = tankerInfo.Group:GetCoordinate()
    local alt = tankerInfo.Group:GetAltitude()
    local revHdg = ReciprocalAngle(self.Heading)
    local block = getBlock(self) or tankerInfo.Tanker.TrackBlock
    local coordIngress = self.CoordIP:Translate(NauticalMiles(15), revHdg):SetAltitude(Feet(block*1000))
    local heading = tankerInfo.Group:GetHeading()
    local group = tankerInfo.Group
    local wp0 = coord:Translate(100, heading):SetAltitude(alt):WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed) -- pointless "inital" waypoint
    wp0.name = "INIT"
    local wpReassign = coord:Translate(NauticalMiles(.5), heading):SetAltitude(alt):WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    wpReassign.Name = "REASSIGN"
    local wpIngress = coordIngress:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    wpIngress.name = "INGRESS"
    local wpTrack = self.CoordIP:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    local waypoints = { wp0, wpIngress, wpTrack }
    local trackIP = 2
    local availability = tankerInfo.Tanker.Behavior.Availability
    if availability == DCAF.AirServiceAvailability.Always then
        -- inject nearby WP to activate service ...
        table.insert(waypoints, 2, wpReassign)
        trackIP = 3
    elseif availability ~= DCAF.AirServiceAvailability.InTrack then
        error("DCAF.TankerTrack:ActivateAir :: unsupported availabilty behavior: " .. DumpPretty(availability))
    end
    tankerInfo.Tanker:SetRoute(waypoints)

--Debug_DrawWaypoints(waypoints)

    if availability == DCAF.AirServiceAvailability.Always then
        local freq = getFrequency(self) or tankerInfo.Tanker.Frequency
        if freq then
            tankerInfo.Tanker:InitFrequency(freq)
        end
        tankerInfo.Tanker:ActivateService(1)
    end
    tankerInfo.Tanker:SetTrack(trackIP, self.Heading, self.Length, block):Start()
    if tankerInfo.Track then
        tankerInfo.Track:RemoveTanker(tankerInfo)
    end
    self:AddTanker(tankerInfo)
    tankerInfo:Activate(group, self)
    notifyTankerAssignment(self, tankerInfo.Tanker, true)
    return self
end

-- local function buildMobileTrackRoute(track, speed, altitude, onCompleteFunc)
--     local baro = COORDINATE.WaypointAltType.BARO
--     local coordTurnStart = track.CoordIP:Translate(track.Length, track.Heading)
--     local coordTurnEnd = coordTurnStart:Translate(track.Width, (track.Heading - 90) % 360)
--     local turn = getReversedTurnCoordinates(coordTurnStart, false, coordTurnEnd)
--     local route = { track.CoordIP:WaypointAirFlyOverPoint(baro, speed) }
--     for _, coord in ipairs(turn) do
--         table.insert(route, coord:WaypointAirFlyOverPoint(baro, speed))
--     end
--     coordTurnStart = track.CoordIP:Translate(track.Width, (track.Heading - 90) % 360)
--     coordTurnEnd = track.CoordIP
--     turn = getReversedTurnCoordinates(coordTurnStart, false, coordTurnEnd)
--     for _, coord in ipairs(turn) do
--         table.insert(route, coord:WaypointAirFlyOverPoint(baro, speed))
--     end
--     WaypointCallback(route[#route], onCompleteFunc)
--     return route
-- end

function DCAF.TankerTrack:UpdateMobileTrackRoute(tankerInfo)
    if tankerInfo.Tanker.IsBingo then
        return end

    if tankerInfo.ChickInTow then
        -- can't update when someone's refueling...
-- DebugMessageTo(nil, "update track pending...")
        tankerInfo:SetPendingCommand(DCAF_TankerCommand:NewUpdateMobileTrackRoute(self))
        return
    end

    if tankerInfo.GroupRTB then
        tankerInfo.Group = tankerInfo.GroupRTB
        tankerInfo.GroupRTB = nil
    end

    local speed
    if tankerInfo.Tanker.TrackSpeed then
        speed = UTILS.KnotsToKmph(tankerInfo.Tanker.TrackSpeed)
    else
        speed = tankerInfo.Group:GetVelocityKMH()
    end
    local alt = Feet(tankerInfo.Tanker.TrackBlock * 1000)
    local coordLegEnd = self.CoordIP:Translate(self.Length, self.Heading)
    local baro = COORDINATE.WaypointAltType.BARO

-- if tankerInfo._nisse_markID1 then
--     COORDINATE:RemoveMark(tankerInfo._nisse_markID1)
--     COORDINATE:RemoveMark(tankerInfo._nisse_markID2)
-- end
-- tankerInfo._nisse_markID1 = self.CoordIP:CircleToAll(nil, nil, {0,1,0})
-- tankerInfo._nisse_markID2 = coordLegEnd:CircleToAll(nil, nil, {0,0,1})
-- DebugMessageTo(nil, "DCAF.TankerTrack:UpdateMobileTrackRoute :: alt: " .. Dump(alt) .. " :: speed: " .. speed, 60)

    local function hasSetFrequencyTask() 
        return HasWaypointAction(tankerInfo.Tanker:GetWaypoints(), "SetFrequency") 
    end

    local waypoints =
    {
        tankerInfo.Group:GetCoordinate():WaypointAirTurningPoint(baro, speed),
        self.CoordIP:WaypointAirTurningPoint(baro, speed),
        coordLegEnd:WaypointAirTurningPoint(baro, speed)
    }
    for _, wp in ipairs(waypoints) do
        wp.alt = alt
    end
    InsertWaypointTask(waypoints[1], TankerTask())
    tankerInfo.Tanker.Group:SetOption(19, true) -- << -- avoids 'On Station' at 1st waypoint
    InsertWaypointTask(waypoints[2], tankerInfo.Group:TaskOrbit(self.CoordIP, alt, UTILS.KmphToMps(speed), coordLegEnd))
-- DebugMessageTo(nil, "Arco track UPDATE", 40)
    tankerInfo.Tanker:SetRoute(waypoints)
    return self
end

function DCAF.TankerTrack:Deactivate()
    for _, tankerInfo in pairs(self.Tankers) do
        tankerInfo:RTB()
        -- tankerInfo:Deactivate()
    end
    self.Tankers = {}
    if self.IsDrawn then
        self:Draw()
    end
end

function getReversedTurnCoordinates(coordStart, rightTurn, coordEnd, countPoints) -- used to calculate '(rtr)' and '(rtl)' (reversed turn right / reversed turn left) in routes (for example)
    local dist = coordStart:Get2DDistance(coordEnd)
    local radius = dist * .5
    local headingCenter = coordStart:GetHeadingTo(coordEnd)
    local coordCenter = coordStart:Translate(radius, headingCenter)
    local heading = coordCenter:GetHeadingTo(coordStart)
    if not isNumber(countPoints) then
        -- TODO consider using more/less points depending on distance between coordStart <--> coordEnd
        countPoints = 8
    end
    local incHeading = 180 / countPoints
    if not isBoolean(rightTurn) then
        rightTurn = true
    end
    if not rightTurn then
        incHeading = -incHeading
    end
    local coordinates = {} -- list of #COORDINATE
    local hdg = heading + incHeading
    for i = 1, countPoints-1, 1 do
        local coord = coordCenter:Translate(radius, hdg)
        table.insert(coordinates, coord)
        hdg = hdg + incHeading
    end
    return coordinates
end

--- Generates list of #COORDINATE from reference location, two radial values, normally from left to right, and an interval distance
--- @param refLocation number Can be anything compatible with #DCAF.Location
--- @param distance number Arc distance from refLocation
--- @param radialStart number Start radial of arc
--- @param radialEnd number (optional) [default = radialStart] End radial of arc
--- @param interval number (optional) [default = 15] Number of degrees between generated coordinates
--- @param rightToLeft boolean rightToLeft (optional) [default = false] Specifies whther arc coordinates should be generated from right to left
function getArcCoordinates(refLocation, distance, radialStart, radialEnd, interval, rightToLeft)
    Debug("getArcCoordinates :: refLocation: " .. DumpPretty(refLocation) .. " :: distance: "..Dump(distance).." :: radialStart: "..DumpPretty(radialStart).." :: radialEnd: "..DumpPretty(radialEnd).." :: interval: "..DumpPretty(interval).." :: rightToLeft: "..DumpPretty(rightToLeft))
    local validLocation = DCAF.Location.Resolve(refLocation)
    if not validLocation then return Error("getArcCoordinates :: could not resolve `refLocation`: " .. DumpPretty(refLocation)) end
    local coord = validLocation:GetCoordinate()
-- Debug("nisse - getArcCoordinates :: coord: " .. DumpPretty(coord))
    if not isNumber(distance) then return Error("getArcCoordinates :: `distance` must be number, but was: " .. DumpPretty(distance)) end
    if not isNumber(radialStart) then return Error("getArcCoordinates :: `radialStart` must be number, but was: " .. DumpPretty(radialStart)) end
    if not isNumber(radialEnd) then radialEnd = radialStart end -- return Error("getArcCoordinates :: `radialEnd` must be number, but was: " .. DumpPretty(radialEnd)) end
    if not isNumber(interval) then interval = 15 end

    local inc = 1
    if rightToLeft then
        inc = -1
    end
    local coordinates = {}
    local r = math.floor(radialStart)
    local next = r
    local last = (math.floor(radialEnd) + inc) % 360
    -- if last == 0 then last = 360 end
-- Debug("nisse - getArcCoordinates :: inc: " .. inc .. " :: start: " .. r .. " :: last: " .. last .. " :: ========================================================")
    while r ~= last do
        if r == next then
            local c = coord:Translate(distance, r)
            coordinates[#coordinates+1] = c
            next = (r + interval*inc) % 360
-- Debug("nisse - getArcCoordinates :: r: " .. r .. " :: next: " .. next)
        end
        r = (r + inc) % 360
        -- if r == 0 then r = 360
    end
    return coordinates
end

local function drawArc(coordCenter, radius, heading, coalition, rgbColor, lineType, alpha, readOnly, countPoints)
    if not isNumber(countPoints) then
        countPoints = 10
    end
    local perpHeading = (heading + 90) % 360
    local incHeading = 180 / countPoints
    local wp1 = coordCenter:Translate(radius, perpHeading)
    local hdg2 = (perpHeading - incHeading) % 360
    local markIDs = {}
    local wp2
    local markID
    for i = 1, countPoints, 1 do
        wp2 = coordCenter:Translate(radius, hdg2)
        markID = wp1:LineToAll(wp2, coalition, rgbColor, alpha, lineType, readOnly)
        table.insert(markIDs, markID)
        wp1 = wp2
        hdg2 = hdg2 - incHeading
    end
    return markIDs
end

local function drawServiceTrackInfo(track, options)
    local rgbColor
    if isTable(track.Color) then
        rgbColor = track.Color
    else
        rgbColor = {0,1,1}
    end
    local width = track.Width
    local heading = track.Heading
    local revHeading = (heading - 180) % 360
    local length = track.Length
    local perpHeading = (heading - 90) % 360
    local radius = width * .5

    local function getAnchorPoint()
        local hdg = heading
        if track.InfoAnchorPoint == 1 then
            hdg = 45
        elseif track.InfoAnchorPoint == 2 then
            hdg = 135
        elseif track.InfoAnchorPoint == 3 then
            hdg = 215
        elseif track.InfoAnchorPoint == 4 then
            hdg = 315
        end

        if hdg > 0 and hdg < 90 then
            return track.CoordIP:Translate(radius, revHeading)
        elseif hdg >= 90 and hdg < 180 then
            return track.CoordIP:Translate(length + radius, heading)
        elseif hdg >= 180 and hdg < 270 then
            return track.CoordIP:Translate(length + radius, heading):Translate(width, perpHeading)
        else
            return track.CoordIP:Translate(radius, revHeading):Translate(width, perpHeading)
        end
    end

    local text = "\n" .. track.Name
    local tankersText = ""
    local alpha = .5
    for _, tankerInfo in ipairs(track.Tankers) do
        alpha = 1
        local tanker = tankerInfo.Tanker
        tankersText = tankersText .. "\n" .. tanker.DisplayName

        DCAF.TankerTrackOptions = {
            ClassName = "DCAF.TankerTrackOptions",
            DrawFuelState = true,
            UpdateInterval = Minutes(1)
        }
        if options.DrawFuelState then
            local lowState = tanker.Group:GetFuelLowState() * 100
            tankersText = tankersText .. " (" .. string.format("%d%%", lowState) .. ")"
        end
        local prefix = '\n  '
        if (tanker.Frequency) then
            tankersText = tankersText .. prefix .. string.format("%.3f", tanker.Frequency)
            prefix = "  "
        end
        if tanker.TACANChannel and tanker.TACANMode then
            tankersText = tankersText .. prefix .. tostring(tanker.TACANChannel) .. tanker.TACANMode
            prefix = " "
        end
        if isAssignedString(tanker.TACANIdent) then
            tankersText = tankersText .. prefix .. "[" .. tanker.TACANIdent .. "]"
        end
    end
    if isAssignedString(tankersText) then
        text = text .. "\n" .. newString('=', 15) .. tankersText
    end
    local anchor = getAnchorPoint()
    return anchor:TextToAll(text, track.Coalition, rgbColor, alpha, nil, 0, 11, true)
end

local function drawActiveServiceTrack(track, options)
    local rgbColor
    if isTable(track.Color) then
        rgbColor = track.Color
    else
        rgbColor = {0,1,1}
    end
    local width = track.Width
    local heading = track.Heading
    local revHeading = (heading - 180) % 360
    local length = track.Length
    local perpHeading = (heading - 90) % 360
    local radius = width * .5

    -- first leg
    local wp1 = track.CoordIP
    local wp2 = wp1:Translate(length, heading)
    local markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 1, true)
    --table.insert(markIDs, markID)

    -- end arc
    local coordCenter = wp2:Translate(radius, perpHeading)
    local arcMarkIDs = drawArc(coordCenter, radius, heading, track.Coalition, rgbColor, 1, .5, true)
    local markIDs = listJoin({ markID }, arcMarkIDs)

    -- second leg
    wp1 = wp1:Translate(width, perpHeading)
    wp2 = wp1:Translate(length, heading)
    markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 1, true)
    table.insert(markIDs, markID)

    -- end arc
    coordCenter = track.CoordIP:Translate(radius, perpHeading)
    arcMarkIDs = drawArc(coordCenter, radius, revHeading, track.Coalition, rgbColor, 1, .5, true)
    markIDs = listJoin(markIDs, arcMarkIDs)

    -- info block
    markID = drawServiceTrackInfo(track, options)
    table.insert(markIDs, markID)

    return markIDs
end

local function drawIdleServiceTrack(track, options)
    if track.MobileIP then
        return end  -- we don't paint inactive mobile tracks

    local markIDs = {}
    local rgbColor
    if isTable(track.Color) then
        rgbColor = track.Color
    else
        rgbColor = {0,1,1}
    end
    local width = track.Width
    local heading = track.Heading
    local revHeading = (heading - 180) % 360
    local length = track.Length
    local perpHeading = (heading - 90) % 360
    local radius = width * .5

    -- base triangle
    local wp1 = track.CoordIP:Translate(radius, perpHeading)
    local wp2 = track.CoordIP:Translate(radius * .5, revHeading)
    local wp3 = wp2:Translate(width, perpHeading)
    local markID = wp1:MarkupToAllFreeForm({wp2, wp3}, track.Coalition, rgbColor, .5, nil, .15, 3, true)
    table.insert(markIDs, markID)

    -- line
    wp2 = wp1:Translate(length + radius, heading)
    markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 3, true)
    table.insert(markIDs, markID)

    -- end line
    wp1 = track.CoordIP:Translate(length + radius, heading)
    wp2 = wp1:Translate(width, perpHeading)
    markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 3, true)
    table.insert(markIDs, markID)

    -- info block
    markID = drawServiceTrackInfo(track, options)
    table.insert(markIDs, markID)

    return markIDs
end

DCAF.TankerTrackOptions = {
    ClassName = "DCAF.TankerTrackOptions",
    DrawFuelState = true,
    UpdateInterval = Minutes(1)
}

function DCAF.TankerTrackOptions:New()
    local options = DCAF.clone(DCAF.TankerTrackOptions)
    return options
end

local function updateTrackPosition(track)
    if not track.MobileIP then
        return end

    track.CoordIP = track.MobileIP:GetOffset():GetCoordinate()
    if track.MobileIP.Offset.Heading then
        track.Heading = track.MobileIP.Source:GetHeading()
    end
    local now = UTILS.SecondsOfToday()
    if not track._nextMobileTrackUpdate or now >= track._nextMobileTrackUpdate then
        for _, tankerInfo in ipairs(track.Tankers) do
            track:UpdateMobileTrackRoute(tankerInfo)
        end
        track._nextMobileTrackUpdate = now + Minutes(10)
    end
end

function DCAF.TankerTrack:InitWidth(value)
    if not isNumber(value) then
        return Error("DCAF.TankerTrack:InitWidth :: `value` must be nunber, but was: " .. DumpPretty(value)) end

    self.Width = value
    return self
end

function DCAF.TankerTrack:InitRestrictTankers(...)
    for i = 1, #arg, 1 do
        local aTanker = arg[i]
        if not isClass(aTanker, DCAF.AvailableTanker) then
            return Error("DCAF.TankerTrack:InitRestrictTankers :: item #" .. i .. " must be #" .. DCAF.AvailableTanker.ClassName .. ", bust was: " .. DumpPretty(aTanker))
        end
        table.insert(self.RestrictTankers, aTanker)
    end
    return self
end

function DCAF.TankerTrack:IsTankerAllowed(availableTanker)
    if #self.RestrictTankers == 0 then
        return true end

-- local index = tableIndexOf(self.RestrictTankers, availableTanker)
-- if index then
--     Debug("DCAF.TankerTrack:IsTankerAllowed :: allowed: " .. DumpPretty(availableTanker))
-- else
--     Debug("DCAF.TankerTrack:IsTankerAllowed :: NOT allowed: " .. DumpPretty(availableTanker))
-- end
    return tableIndexOf(self.RestrictTankers, availableTanker)
end

function DCAF.TankerTrack:Draw(infoAnchorPoint, options)
    if not isClass(options, DCAF.TankerTrackOptions.ClassName) then
        options = DCAF.TankerTrackOptions--:New() hack - super weird! Calling the :New() methid gives error: "attempt to call method 'New' (a nil value)"
    end
    self.IsDrawn = true
    if isNumber(infoAnchorPoint) then
        self.InfoAnchorPoint = infoAnchorPoint
    end
    self:EraseTrack()
    if self:IsActive() then
        self._isActiveMarkIDs = true
        self._markIDs = drawActiveServiceTrack(self, options)
        self._drawSchedulerID = DCAF.startScheduler(function(track)
            -- update active track data block...
            track:EraseTrack()
            updateTrackPosition(self)
            track._markIDs = drawActiveServiceTrack(track, options)
        end, options.UpdateInterval, nil, self)
    else
        self._isActiveMarkIDs = false
        updateTrackPosition(self)
        self._markIDs = drawIdleServiceTrack(self)
        if self._drawSchedulerID then
            DCAF.stopScheduler(self._drawSchedulerID)
            self._drawSchedulerID = nil
        end
    end
    return self
end

function DCAF.TankerTrack:EraseTrack(hide)
    if isBoolean(hide) and hide then
        self.IsDrawn = false
    end
    if isTable(self._markIDs) then
        for _, markID in ipairs(self._markIDs) do
            self.CoordIP:RemoveMark(markID)
        end
    end
    self._markIDs = nil
end

function DCAF.TankerTrack:IsActive()
    return #self.Tankers > 0
end

function DCAF.TankerTrack:IsFull()
    return #self.Tankers == self.Capacity
end

function DCAF.TankerTrack:IsBlocked()
    return self.BlockedWhenActive and self.BlockedWhenActive:IsActive()
end

function DCAF.TankerTracks:GetActiveTankers()
    local result = {}
    for _, track in ipairs(DCAF.TankerTracks) do
        for _, tanker in pairs(track.Tankers) do
            table.insert(result, { Tanker = tanker, Track = track })
        end
    end
    return result
end

local _tanker_menu

local function sortedTracks()
    table.sort(DCAF.TankerTracks, function(a, b)
        if a and b then
            if a.IsActive and not b.IsActive then
                return true
            elseif b.IsActive and not a.IsActive then
                return false
            else
                local result = a.Name < b.Name
                return result
            end
        elseif a then
            return true
        else
            return false
        end
    end)
    return DCAF.TankerTracks
end

local isDynamicTankerTracksSupported = false
local _defaultTankerMenuCaption
local _defaultTankerMenuScope
local _defaultParentMenu
local function buildControllerTankerMenus(caption, scope, parentMenu)
    if not isAssignedString(caption) then
        caption = _defaultTankerMenuCaption or "Tankers"
    end
    _defaultTankerMenuCaption = caption
    parentMenu = parentMenu or _defaultParentMenu
    _defaultParentMenu = parentMenu
    local dcafCoalition = Coalition.Resolve(scope or _defaultTankerMenuScope, true)
    local group
    if not dcafCoalition then
        group = getGroup(scope)
        if not group then
            error("buildControllerTankerMenus :: unrecognized `scope` (expected #Coalition or #GROUP/group name): " .. DumpPretty(scope)) end

        dcafCoalition = group:GetCoalition()
    end
    _defaultTankerMenuScope = group or dcafCoalition
    local tracks = sortedTracks()
    if _tanker_menu then
        _tanker_menu:RemoveSubMenus()
    else
        if group then
            _tanker_menu = MENU_GROUP:New(group, caption, _defaultParentMenu)
        else
            _tanker_menu = MENU_COALITION:New(dcafCoalition, caption, _defaultParentMenu)
        end
    end

    for _, track in ipairs(tracks) do
        local menuTrack
        if group then
            menuTrack = MENU_GROUP:New(group, track.Name, _tanker_menu)
        else
            menuTrack = MENU_COALITION:New(dcafCoalition, track.Name, _tanker_menu)
        end

        if not track:IsBlocked() then
            if track:IsActive() then
                local function deactivateTrack()
                    track:Deactivate()
                    rebuildTankerMenus(caption, scope)
                end

                if group then
                    MENU_GROUP_COMMAND:New(group, "DEACTIVATE", menuTrack, deactivateTrack)
                else
                    MENU_COALITION_COMMAND:New(dcafCoalition, "DEACTIVATE", menuTrack, deactivateTrack)
                end
            end

            local function rtbMenu(tankerInfo)
                local tanker = tankerInfo.Tanker

                if IsOnAirbase(tanker.Group) then
                    local _onAircraftTakeOff
                    local function abortTakeoff()
                        track:RemoveTanker(tankerInfo)
                        tankerInfo.Tanker.Group:Destroy()
                        tankerInfo:Deactivate()
                        tankerInfo.Tanker = nil
                        MissionEvents:EndOnAircraftTakeOff(_onAircraftTakeOff)
                        rebuildTankerMenus(caption, scope)
                    end

                    if group then
                        MENU_GROUP_COMMAND:New(group, "Abort Takeoff: " .. tanker.DisplayName, menuTrack, abortTakeoff)
                    else
                        MENU_COALITION_COMMAND:New(dcafCoalition, "Abort Takeoff: " .. tanker.DisplayName, menuTrack, abortTakeoff)
                    end
                    _onAircraftTakeOff = function(event)
                        if event.IniGroup.GroupName == tanker.Group.GroupName then
                            MissionEvents:EndOnAircraftTakeOff(_onAircraftTakeOff)
                            rebuildTankerMenus(caption, scope)
                        end
                    end
                    MissionEvents:OnAircraftTakeOff(_onAircraftTakeOff)
                    return
                end

                if tanker.IsRTB then
                    return end

                tankerInfo:OnRTB(function(arg)
                    rebuildTankerMenus(arg.Caption, arg.Scope)
                end, {Caption = caption, Scope = scope})

                local function sendTankerHome(airbaseName, route, allowPostpone)
                    track:RemoveTanker(tankerInfo)
                    tankerInfo:RTB(airbaseName, nil, route, allowPostpone)
                    rebuildTankerMenus(caption, scope)
                end

                local airdromes
                if tanker.Behavior and tanker.Behavior.RTBAirbase then
                    airdromes = { tanker.Behavior.RTBAirbase }
                else
                    airdromes = tankerInfo.Airbases
                end

                local function rtbAirdromes(menuTextPrefix, allowPostpone)
                    local menu
                    if group then
                        menu = MENU_GROUP:New(group, menuTextPrefix, menuTrack)
                     else
                        menu = MENU_COALITION:New(dcafCoalition, menuTextPrefix, menuTrack)
                     end
                    for _, airServiceBase in ipairs(airdromes) do
                        local airbaseName = airServiceBase.Airbase.AirbaseName
                        local menuText = menuTextPrefix .. " >> " .. airbaseName
                        local rtbMenu = DCAF.MENU:New(menu or menuTrack)
                        if airServiceBase.RTBRoutes and #airServiceBase.RTBRoutes > 0 then
                            for _, rtbRoute in ipairs(airServiceBase.RTBRoutes) do
                                 if group then
                                    rtbMenu:GroupCommand(group, menuText .. " (" .. rtbRoute.Name .. ")", sendTankerHome, airbaseName, rtbRoute, allowPostpone)
                                 else
                                    rtbMenu:CoalitionCommand(dcafCoalition, menuText .. " (" .. rtbRoute.Name .. ")", sendTankerHome, airbaseName, rtbRoute, allowPostpone)
                                 end
                            end
                        else
                            local parentMenu = (rtbMenu or menuTrack)._parentMenu
                            if group then
                                MENU_GROUP_COMMAND:New(group, menuText, parentMenu, sendTankerHome, airbaseName, nil, allowPostpone)
                            else
                                MENU_COALITION_COMMAND:New(dcafCoalition, menuText, parentMenu, sendTankerHome, airbaseName, nil, allowPostpone)
                            end
                        end
                    end
                end

                if airdromes then
                    rtbAirdromes("RTB " .. tanker.DisplayName)
                    rtbAirdromes("!RTB NOW! " .. tanker.DisplayName, false)
                end
            end

            local function altitudeMenu(tankerInfo, parentMenu)
                local function changeAltitude(change)
                    local newAltitude = tankerInfo.Group:GetAltitude() + Feet(change)
                    tankerInfo.Group:SetAltitude(newAltitude, true, COORDINATE.WaypointAltType.BARO)
                end

                local function changeMenu(text, factor, parentMenu)
                    local changeFeet = { 500, 1000, 2000, 4000 }
                    for _, feet in ipairs(changeFeet) do
                        if group then
                            MENU_GROUP_COMMAND:New(group, text .. " " .. feet .. " feet", parentMenu, changeAltitude, feet * factor)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, text .. " " .. feet .. " feet", parentMenu, changeAltitude, feet * factor)
                        end
                    end
                end

                local menuAltitude
                if group then
                    menuAltitude = MENU_GROUP:New(group, "Change altitude " .. tankerInfo.ToString(), parentMenu)
                else
                    menuAltitude = MENU_COALITION:New(dcafCoalition, "Change altitude " .. tankerInfo:ToString(), parentMenu)
                end
                changeMenu("Increase", 1, menuAltitude)
                changeMenu("Decrease", -1, menuAltitude)
            end

            local function speedMenu(tankerInfo, parentMenu)
                local function changeSpeed(change)
                    local newSpeed = tankerInfo.Group:GetVelocityKNOTS() + change
                    tankerInfo.Group:SetSpeed(Knots(newSpeed), true)
                end

                local function changeMenu(text, factor, parentMenu)
                    local changeKnots = { 10, 20, 50, 100 }
                    for _, knots in ipairs(changeKnots) do
                        if group then
                            MENU_GROUP_COMMAND:New(group, text .. " " .. knots .. " kt", parentMenu, changeSpeed, knots * factor)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, text .. " " .. knots .. " kt", parentMenu, changeSpeed, knots * factor)
                        end
                    end
                end

                local menuSpeed
                if group then
                    menuSpeed = MENU_GROUP:New(group, "Change speed " .. tankerInfo.ToString(), parentMenu)
                else
                    menuSpeed = MENU_COALITION:New(dcafCoalition, "Change speed " .. tankerInfo:ToString(), parentMenu)
                end
                changeMenu("Increase", 1, menuSpeed)
                changeMenu("Decrease", -1, menuSpeed)
            end

            local function activateMenu(tankerInfo, activeTankers)
                if not track:IsTankerAllowed(tankerInfo) then
                    return end

                if not tankerInfo:IsActive() then
                    local function activateAir()
                        track:ActivateAir(tankerInfo)
                        rebuildTankerMenus(caption, scope)
                    end
                    local function activateGround(airbase, route)
                        track:ActivateAirbase(tankerInfo, route or airbase, nil)
                        rebuildTankerMenus(caption, scope)
                    end

                    if tankerInfo.IsRTB then
                        if group then
                            MENU_GROUP_COMMAND:New(group, "[" .. tankerInfo:ToString() .. " is RTB]", menuTrack, function() end)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, "[" .. tankerInfo:ToString() .. " is RTB]", menuTrack, function() end)
                        end
                        return
                    end

                    if tankerInfo.TurnaroundReadyTime then
                        local text = "[" .. tankerInfo:ToString() .. " ready at " .. tankerInfo.TurnaroundReadyTime .. "]"
                        if group then
                            MENU_GROUP_COMMAND:New(group, text, menuTrack, function() end)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, text, menuTrack, function() end)
                        end
                        return
                    end

                    local menuTanker
                    if group then
                        menuTanker = MENU_GROUP:New(group, tankerInfo:ToString(), menuTrack)
                    else
                        menuTanker = MENU_COALITION:New(dcafCoalition, tankerInfo:ToString(), menuTrack)
                    end
                    if tankerInfo.IsAirStartEnabled then
                        if group then
                            MENU_GROUP_COMMAND:New(group, "Activate AIR", menuTanker, activateAir)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, "Activate AIR", menuTanker, activateAir)
                        end
                    end
                    if isList(tankerInfo.Airbases) then
                        local mnuAirbases = DCAF.MENU:New(menuTanker)
                        for _, airServiceBase in ipairs(tankerInfo.Airbases) do  -- #DCAF_AirServiceBase
                            local airbaseName = airServiceBase.Airbase.AirbaseName
                            if isList(airServiceBase.Routes) then
                                for _, route in ipairs(airServiceBase.Routes) do -- #DCAF.AIR_ROUTE
                                    local mnuText = "Activate from " .. airbaseName .. " (" .. route.Name  .. ")"
                                    if group then
                                        mnuAirbases:GroupCommand(group, mnuText,  activateGround, route)
                                    else
                                        mnuAirbases:CoalitionCommand(dcafCoalition, mnuText,  activateGround, route)
                                    end
                                end
                            else
                                if group then
                                    mnuAirbases:GroupCommand(group, "Activate from " .. airbaseName, activateGround, airServiceBase.Airbase)
                                else
                                    mnuAirbases:CoalitionCommand(dcafCoalition, "Activate from " .. airbaseName, activateGround, airServiceBase.Airbase)
                                end
                            end
                        end
                        -- end
                    end
                elseif tankerInfo.Track.Name ~= track.Name then
                    table.insert(activeTankers, tankerInfo)
                end
            end

            local function altitudeAndSpeedMenu(tankerInfo)
                local menu
                if group then
                    menu = MENU_GROUP:New(group, "Change alt/speed " .. tankerInfo.ToString(), menuTrack)
                else
                    menu = MENU_COALITION:New(dcafCoalition, "Change alt/speed " .. tankerInfo:ToString(), menuTrack)
                end
                altitudeMenu(tankerInfo, menu)
                speedMenu(tankerInfo, menu)
            end

            -- active tankers
            for _, tankerInfo in ipairs(track.Tankers) do
                rtbMenu(tankerInfo)
                if not tankerInfo.IsRTB then
                    altitudeAndSpeedMenu(tankerInfo)
                end
            end

            -- available tankers..
            if not track:IsFull() then
                local activeTankers = {}
                for _, tankerInfo in ipairs(AAR_TANKERS) do
                    activateMenu(tankerInfo, activeTankers)
                end
                if #activeTankers > 0 then
                    local function reassignTanker(tanker)
                        track:Reassign(tanker)
                        rebuildTankerMenus(caption, scope)
                    end
                    for _, tanker in ipairs(activeTankers) do
                        if group then
                            MENU_GROUP_COMMAND:New(group, "REASSIGN " .. tanker:ToString() .. " @ " .. tanker.Track.Name, menuTrack, reassignTanker, tanker)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, "REASSIGN " .. tanker:ToString() .. " @ " .. tanker.Track.Name, menuTrack, reassignTanker, tanker)
                        end
                    end
                end
            end
        end
    end
end
rebuildTankerMenus = buildControllerTankerMenus

-- Adds a menu for each tanker to the F10 menu that displays important tanker info to the player's group
local function buildPlayerTankerMenus(playerUnitName)

    local function displayTankerState(group, tanker)
        local noTankers = true
        for _, track in ipairs(sortedTracks()) do
            for _, tankerInfo in ipairs(track.Tankers) do
                local tanker = tankerInfo.Tanker
                local unit = tanker.Group:GetUnit(1)
                local fuel = unit:GetFuel()
                local maxFuel = DCAF.Tanker.MaxFuelLbs[unit:GetTypeName()]
                if not maxFuel then
                    error("Unknown tanker type: " .. unit:GetTypeName())
                end

                local remainingFuel = math.floor(fuel * maxFuel)
                local bingoFuel = math.floor(DCAF.Tanker.FuelStateRtb * maxFuel)
                local msg = string.format("%s (%s):\n  Freq: %s Mhz\n  TCN: %s%s\n",
                                tanker.DisplayName,
                                unit:GetTypeName(),
                                tanker.Frequency,
                                tanker.TACANChannel,
                                tanker.TACANMode)
                local msg = msg .. string.format("  Fuel state:\n    Current: %s lbs\n    Bingo: %s lbs\n    Remaining for AAR: %s lbs\n",
                                remainingFuel,
                                bingoFuel,
                                remainingFuel - bingoFuel)
                MESSAGE:New(msg, 15):ToGroup(group)
                noTankers = false
            end
        end
        if noTankers then MESSAGE:New("No active tankers available", 5):ToGroup(group) end
    end

    local playerGroup = UNIT:FindByName(playerUnitName):GetGroup()
    MENU_GROUP_COMMAND:New(playerGroup, "Tanker info", nil, displayTankerState, playerGroup)
end

 --- Build AAR menus for each player group when player enters plane. Recommended to use with
  -- default parameters.
  -- @param #string caption The title of the menu. Default is "AAR"
  -- @param scope Blue coalition by default for controller menus.
function DCAF.TankerTracks:BuildF10Menus(caption, scope, parentMenu)
    buildControllerTankerMenus(caption or "AAR", scope or Coalition.Blue, parentMenu)
    DCAF.TankerTracks._isControllerMenusBuilt = true

    MissionEvents:OnPlayerEnteredAirplane(function(event)
        buildPlayerTankerMenus(event["IniUnitName"])
    end)
    return self
end

function DCAF.TankerTracks:AllowDynamicTracks(value)
    if  not isBoolean(value) then
        value = true
    end
    if value == isDynamicTankerTracksSupported then
        return end

    isDynamicTankerTracksSupported = value

    local function getLastStationaryTrack()
        local index = tableIndexOf(DCAF.TankerTracks, function(i)   return not i.IsMobile    end)
        if index then
            return DCAF.TankerTracks[index]
        end
        return #DCAF.TankerTracks[#DCAF.TankerTracks]
    end

    local function listenForDynamicTrackMarks(event)
        -- format: AAR <name> <heading> <length> <capacity>  
        if string.len(event.Text) < 3 then
            return end

        local tokens = {}
        for word in event.Text:gmatch("%w+") do
            table.insert(tokens, word)
        end

        -- requires as a minimum the ident 'AAR' and a name for the new track... 
        if #tokens < 2 or string.upper(tokens[1]) ~= "AAR" then
            return end

        local default = getLastStationaryTrack() -- DCAF.TankerTracks[#DCAF.TankerTracks]
        local name = tokens[2]

        local function resolveNumeric(name, sValue, fallback)
            local value
            if isAssignedString(sValue) then
                value = tonumber(sValue)
            elseif default then 
                value = default[name]
            end
            return value or fallback
        end

        local heading = resolveNumeric("Heading", tokens[3], default.Heading or 360)
        local length = resolveNumeric("Length", tokens[4], default.Length)
        local capacity = resolveNumeric("Capacity", tokens[5], 2)

        DCAF.TankerTrack:New(name, event.Coalition, heading, event.Location.Source, length, nil, nil, capacity):Draw()
        rebuildTankerMenus()
    end

    if value then
        MissionEvents:OnMapMarkChanged(listenForDynamicTrackMarks)
    else
        MissionEvents:EndOnMapMarkChanged(listenForDynamicTrackMarks)
    end
end
 
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
--                                                             MENU BUILDING - HELPERS 
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
 
DCAF.MENU = {
    ClassName = "DCAF.MENU"
    ----
}

function getMenuText(menu)
    if isList(menu.MenuPath) then
        return menu.MenuPath[#menu.MenuPath]
    end
end

function DCAF.MENU:New(parentMenu, maxCount, count, nestedMenuCaption)
    local menu = DCAF.clone(DCAF.MENU)
    if not isNumber(maxCount) then
        maxCount = 9
    end
    if not isNumber(count) then
        count = 0
    end
    menu._maxCount = maxCount
    menu._count = count
    menu._parentMenu = parentMenu
    menu._nestedMenuCaption = "(more)"
    return menu
end

function DCAF.MENU:Blue(text)
    return self:Coalition(coalition.side.BLUE, text)
end

function DCAF.MENU:BlueCommand(text, func, ...)
    return self:CoalitionCommand(coalition.side.BLUE, text, func, ...)
end

function DCAF.MENU:CoalitionCommand(dcsCoalition, text, func, ...)
    local dcafCoalition = Coalition.Resolve(dcsCoalition)
    if dcafCoalition then
       dcsCoalition = Coalition.ToNumber(dcafCoalition)
    elseif not isNumber(dcsCoalition) then
        error("DCAf.Menu:CoalitionCommand :: `coalition` must be #Coalition or #number (eg. coalition.side.RED), but was: " .. type(dcsCoalition))
    end

    if not isAssignedString(text) then
        error("DCAF.MENU:CoalitionCommand :: `text` must be assigned string") end

    if not isFunction(func) then
        error("DCAF.MENU:CoalitionCommand :: `func` must be a function but was: " .. type(func)) end

    if self._count == self._maxCount then
        self._parentMenu = MENU_COALITION:New(dcsCoalition, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_COALITION_COMMAND:New(dcsCoalition, text, self._parentMenu, func, ...)
end

function DCAF.MENU:Coalition(coalition, text)
    local dcafCoalition = Coalition.Resolve(coalition)
    if dcafCoalition then
       coalition = Coalition.ToNumber(dcafCoalition)
    elseif not isNumber(coalition) then
        error("DCAf.Menu:Coalition :: `coalition` must be #Coalition or #number (eg. coalition.side.RED), but was: " .. type(coalition))
    end

    if not isAssignedString(text) then
        error("DCAF.MENU:Blue :: `text` must be assigned string") end

    if self._count == self._maxCount then
        self._parentMenu = MENU_COALITION:New(coalition, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_COALITION:New(coalition, text, self._parentMenu)
end

function DCAF.MENU:Group(group, text)
    local testGroup = getGroup(group)
    if not testGroup then
        error("DCAF.MENU:Group :: cannot resolve group from: " .. DumpPretty(group)) end

    if not isAssignedString(text) then
        error("DCAF.MENU:Group :: `text` must be assigned string") end

    group = testGroup
    if self._count == self._maxCount then
        self._parentMenu = MENU_GROUP:New(group, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_GROUP:New(group, text, self._parentMenu)
end

function DCAF.MENU:GroupCommand(group, text, func, ...)
    local testGroup = getGroup(group)
    if not testGroup then
        error("DCAF.MENU:GroupCommand :: cannot resolve group from: " .. DumpPretty(group)) end

    if not isAssignedString(text) then
        error("DCAF.MENU:GroupCommand :: `text` must be assigned string") end

    if not isFunction(func) then
        error("DCAF.MENU:GroupCommand :: `func` must be a function but was: " .. type(func)) end

    group = testGroup
    if self._count == self._maxCount then
        self._parentMenu = MENU_GROUP:New(group, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_GROUP_COMMAND:New(group, text, self._parentMenu, func, ...)
end


-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                             WEAPONS SIMULATION
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local __wpnSim_count = 0
local __wpnSim_minSafetyDistance = 300
local __wpnSim_simulations = { -- list
  -- #DCAF.WeaponSimulation
}

DCAF.WeaponSimulationConfig = {
  ClassName = "DCAF.WeaponSimulationConfig",
  IniCoalitions = { Coalition.Red },
  IniTypes = { GroupType.Air, GroupType.Ground, GroupType.Ship },
  TgtTypes = { GroupType.Air, GroupType.Ground, GroupType.Ship },
  ExcludeAiTargets = true,
  ExcludePlayerTargets = false,
  SafetyDistance = 300, -- (meters) missiles deactivates at this distance to target
  InhibitFratricideDetection = false,       -- when set, the weapons simulation will not detect and notify fratricide events
  AudioSimulatedHitSelf = "SimulatedWpnHitSelf.ogg",
  AudioSimulatedHitTarget = "SimulatedWpnHitTarget.ogg",
  AudioSimulatedHitFratricide = "SimulatedWpnHitFratricide.ogg",
  AudioSimulatedMiss = "SimulatedWeaponMiss.ogg",
}

DCAF.WeaponSimulation = {
    ClassName = "DCAF.WeaponSimulation",
    Name = "WPN_SIM",
    Config = nil, -- #DCAF.MissileSimulationConfig
    __scheduler = nil,
    __managers = { }
}

function DCAF.WeaponSimulationConfig:New(iniCoalitions, iniTypes, tgtTypes, safetyDistance, bExcludeAiTargets, bExcludePlayerTargets)
    if isAssignedString(iniCoalitions) and Coalition.Resolve(iniCoalitions) then
        iniCoalitions = { iniCoalitions }
    elseif not isTable(iniCoalitions) then
        iniCoalitions = DCAF.WeaponSimulationConfig.IniCoalitions
    end
    if isAssignedString(iniTypes) and GroupType.IsValid(iniTypes) then
        iniTypes = { iniTypes }
    elseif not isTable(iniTypes) then
        iniTypes = DCAF.WeaponSimulationConfig.IniTypes
    end
    if isAssignedString(tgtTypes) and GroupType.IsValid(tgtTypes) then
        tgtTypes = { tgtTypes }
    elseif not isTable(tgtTypes) then
        tgtTypes = DCAF.WeaponSimulationConfig.TgtTypes
    end
    if not isNumber(safetyDistance) then
        safetyDistance = DCAF.WeaponSimulationConfig.SafetyDistance
    else
        safetyDistance = math.max(__wpnSim_minSafetyDistance, safetyDistance)
    end
    if not isBoolean(bExcludeAiTargets) then
        bExcludeAiTargets = DCAF.WeaponSimulationConfig.ExcludeAiTargets
    end
    if not isBoolean(bExcludePlayerTargets) then
        bExcludePlayerTargets = DCAF.WeaponSimulationConfig.ExcludePlayerTargets
    end
    local cfg = DCAF.clone(DCAF.WeaponSimulationConfig)
    cfg.IniCoalitions = iniCoalitions
    cfg.IniTypes = iniTypes
    cfg.TgtTypes = tgtTypes
    cfg.ExcludeAiTargets = bExcludeAiTargets
    cfg.ExcludePlayerTargets = bExcludePlayerTargets
    cfg.SafetyDistance = safetyDistance
    return cfg
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedHitTarget(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedHitTarget :: `filename` must be assigned string") end

    self.AudioSimulatedHitTarget = filename
    return self
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedHitFratricide(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedHitFratricide :: `filename` must be assigned string") end

    self.AudioSimulatedHitFratricide = filename
    return self
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedHitSelf(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedHitSelf :: `filename` must be assigned string") end

    self.AudioSimulatedHitSelf = filename
    return self
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedMiss(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedMiss :: `filename` must be assigned string") end

    self.AudioSimulatedMiss = filename
    return self
end

function DCAF.WeaponSimulation:New(name, config)
   __wpnSim_count = __wpnSim_count+1
   if not isAssignedString(name) then
      name = DCAF.WeaponSimulation.Name .. "-" .. Dump(__wpnSim_count)
   end
   if config ~= nil then
      if not isClass(config, DCAF.WeaponSimulationConfig.ClassName) then
        error("DCAF.WeaponSimulation:New :: `config` must be of type " .. DCAF.WeaponSimulationConfig.ClassName)
        return
      end
   else
      config = DCAF.WeaponSimulationConfig:New()
   end
   local sim = DCAF.clone(DCAF.WeaponSimulation)
   sim.Name = name
   sim.Config = config
   return sim
end

function DCAF.WeaponSimulation:Manage(func) -- #function(weapon, iniUnit, tgtUnit, config)
    if not isFunction(func) then
        error("DCAF.WeaponSimulation:Manage :: `func` must be function, but was " .. type(func)) end

    table.insert(self.__managers, func)
    return self
end

function DCAF.WeaponSimulation:IsManaged(weapon, iniUnit, tgtUnit, config)
    -- the rule here is that if there are managers added, one of them needs to return true for the weapon to be managed (simulated)
    -- if no managers are registered; the weapon is automatically managed (simulated)
    if #self.__managers == 0 then
        return true end

    for _, manager in ipairs(self.__managers) do
        local result, msg = manager(weapon, iniUnit, tgtUnit, config)
        if isBoolean(result) and result then
            return result, msg end
    end
    return false, "No manager found for weapon"
end

function DCAF.WeaponSimulation:_IsSimulated(weapon, iniUnit, tgtUnit, config)

   -- note: 'weapon' is currently not included in filtering; just passed for future proofing
--    local iniCoalition = iniUnit:GetCoalition()
--    if not Coalition.IsAny(iniCoalition, config.IniCoalitions) then
--       return false, "Initiator is excluded coaltion: '" .. iniUnit:GetCoalitionName() end

   if config.ExcludeAiTargets and not tgtUnit:IsPlayer() then
      return false, "AI targets are excluded" end

   if config.ExcludePlayerTargets and tgtUnit:IsPlayer() then
      return false, "Player targets are excluded" end

   if iniUnit:IsGround() and not GroupType.IsAny(GroupType.Ground, config.IniTypes) then
      return false, "Initiator type is excluded: 'Ground'" end

   if iniUnit:IsAir() and not GroupType.IsAny(GroupType.Air, config.IniTypes) then
      return false, "Initiator type is excluded: 'Air'" end

   if iniUnit:IsShip() and not GroupType.IsAny(GroupType.Ship, config.IniTypes) then
      return false, "Initiator type is excluded: 'Ship'" end

   if tgtUnit:IsGround() and not GroupType.IsAny(GroupType.Ground, config.TgtTypes) then
      return false, "Target type is excluded: 'Ground'" end

   if tgtUnit:IsAir() and not GroupType.IsAny(GroupType.Air, config.TgtTypes) then
      return false, "Target type is excluded: 'Air'" end

   if tgtUnit:IsShip() and not GroupType.IsAny(GroupType.Ship, config.TgtTypes) then
      return false, "Target type is excluded: 'Ship'" end

   return true, ""
end

function DCAF.WeaponSimulation:IsSimulated(weapon, iniUnit, tgtUnit, config)
   return self:_IsSimulated(weapon, iniUnit, tgtUnit, config)
end

function DCAF.WeaponSimulation:_OnWeaponMisses(wpnType, iniUnit, tgtUnit)
    if isFunction(self.OnWeaponMisses) then
        local isMiss = self:OnWeaponMisses(wpnType, iniUnit, tgtUnit)
        if not isMiss then
            return end
    end

    local tgtGroup = tgtUnit:GetGroup()
    local tgtActor
    if tgtUnit:IsPlayer() then
        tgtActor = string.format("%s (%s)", tgtUnit:GetPlayerName(), tgtUnit.UnitName)
    else
        tgtActor = tgtUnit.UnitName
    end
    local iniGroup = iniUnit:GetGroup()
    local msg = string.format("%s defeated %s by %s (%s)", tgtActor, wpnType, iniGroup.GroupName, iniGroup:GetTypeName())

    MessageTo(tgtUnit, msg)
    MessageTo(tgtUnit, self.Config.AudioSimulatedMiss)
end

function DCAF.WeaponSimulation:_OnWeaponHits(wpn, iniUnit, tgtUnit)
    if isFunction(self.OnWeaponHits) then
        local isHit = self:OnWeaponHits(wpn, iniUnit, tgtUnit)
        if isBoolean(isHit) and not isHit then
            return end
    end

    local tgtGroup = tgtUnit:GetGroup()
    if isFunction(tgtGroup.OnHitBySimulatedWeapon) then
        local success, err = pcall(tgtGroup.OnHitBySimulatedWeapon(tgtGroup, tgtUnit, iniUnit, wpn))
        if not success then
            Warning("DCAF.WeaponSimulation:_OnWeaponHits :: error when invoking targeted group's `OnSimulatedHit` function: " .. DumpPretty(err))
        end
    end

    local tgtActor
    if tgtUnit:IsPlayer() then
        tgtActor = string.format("%s (%s)", tgtUnit:GetPlayerName(), tgtUnit.UnitName)
    else
        tgtActor = tgtUnit.UnitName
    end
    local iniGroup = iniUnit:GetGroup()
    local iniCoalition = iniGroup:GetCoalitionName()
    local tgtCoalition = tgtGroup:GetCoalitionName()
    local msg = string.format("%s was hit by %s (%s)", tgtActor, iniGroup.GroupName, iniGroup:GetTypeName())
    if tgtCoalition == iniCoalition and not self.Config.InhibitFratricideDetection then
        -- todo What sound for fratricide?
        msg = "FRATRICIDE! :: " .. msg
        MessageTo(iniGroup, self.Config.AudioSimulatedHitFratricide)
    else
        -- different sounds for initiating/target group ...
        MessageTo(iniGroup, self.Config.AudioSimulatedHitTarget)
        MessageTo(tgtGroup, self.Config.AudioSimulatedHitSelf)
        -- MessageTo(iniCoalition, self.Config.AudioSimulatedHitTarget) obsolete
        -- MessageTo(tgtCoalition, self.Config.AudioSimulatedHitSelf)
    end
    MessageTo(iniGroup, msg)
    MessageTo(tgtGroup, msg)
    -- MessageTo(nil, msg)
end

function DCAF.WeaponSimulation:OnWeaponMisses(wpnType, iniUnit, tgtUnit)
    return true
end

function DCAF.WeaponSimulation:OnWeaponHits(wpn, iniUnit, tgtUnit)
    return true
end

function DCAF.WeaponSimulation:Start(safetyDistance)
    local scheduler = SCHEDULER:New()
    self.__scheduler = scheduler
    self.__countTrackedWeapons = 0
    if not isNumber(safetyDistance) then
        safetyDistance = self.Config.SafetyDistance
    else
        safetyDistance = math.max(__wpnSim_minSafetyDistance, safetyDistance)
    end

    self.__monitorFunc = function(event)
        local wpn = event.weapon
        local wpnType = wpn:getTypeName()
        local tgt = wpn:getTarget()
        local iniUnit = event.IniUnit
        local tgtUnit = event.TgtUnit

        local isManaged, msg = self:IsManaged(wpn, iniUnit, tgtUnit, self.Config)

        local function debugMessage(resolution)
            local dbgMsg = "DCAF.WeaponSimulation(" .. self.Name .. ") :: " .. resolution .. " '" .. wpnType .."'"
            if iniUnit then
                dbgMsg = dbgMsg .. " fired by '" .. iniUnit.UnitName .. "'"
            end
            if tgtUnit then
                dbgMsg = dbgMsg .. " at '" .. tgtUnit.UnitName .. "'"
            end
            return dbgMsg .. " (" .. msg .. ")"
        end

        if not isManaged then
            -- local dbgMsg = "DCAF.WeaponSimulation(" .. self.Name .. ") :: is NOT managing '" .. wpnType .."'"
            -- if iniUnit then
            --     dbgMsg = dbgMsg .. " fired by '" .. iniUnit.UnitName .. "'"
            -- end
            -- if tgtUnit then
            --     dbgMsg = dbgMsg .. " at '" .. tgtUnit.UnitName .. "'"
            -- end
            Debug(debugMessage("is NOT managing"))
            return
        end

        local isSimulated, msg = self:IsSimulated(wpn, iniUnit, tgtUnit, self.Config)
        if not isSimulated then
            Debug(debugMessage("will NOT deactive"))
            -- Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: will NOT deactive '" .. wpnType .."' fired by '" .. iniUnit.UnitName .. "' at " .. tgtUnit.UnitName .. " (" .. msg .. ")")
            return
        end

        local function getDistance3D(pos1, pos2)
            local xDiff = pos1.x - pos2.x
            local yDiff = pos1.y - pos2.y
            local zDiff = pos1.z - pos2.z
            return math.sqrt(xDiff * xDiff + yDiff * yDiff + zDiff*zDiff)
        end

        local scheduleId
        local function trackWeapon()
            local mslAlive, mslPos = pcall(function() return wpn:getPoint() end)
            if not mslAlive then
                -- weapon missed/was defeated...
                Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: weapon no longer alive :: IGNORES")
                scheduler:Stop(scheduleId)
                scheduler:Remove(scheduleId)
                self.__countTrackedWeapons = self.__countTrackedWeapons - 1
                self:_OnWeaponMisses(wpnType, iniUnit, tgtUnit)
                return
            end

            local tgtAlive, tgtPos = pcall(function() return tgt:getPoint() end)
            if not tgtAlive then
                -- target is (no longer) alive...
                Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: target no longer alive :: IGNORES")
                scheduler:Stop(scheduleId)
                scheduler:Remove(scheduleId)
                self.__countTrackedWeapons = self.__countTrackedWeapons - 1
                return
            end

            local distance = getDistance3D(mslPos, tgtPos)
            if distance <= safetyDistance then
                -- weapon hit ...
                wpn:destroy()
                Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: weapon would have hit " .. tgtUnit.UnitName .. " (fired by " .. iniUnit.UnitName .. ") :: WPN TRACKING END")
                scheduler:Stop(scheduleId)
                scheduler:Remove(scheduleId)
                self.__countTrackedWeapons = self.__countTrackedWeapons - 1
                self:_OnWeaponHits(wpn, iniUnit, tgtUnit)
            end
        end
        scheduleId = scheduler:Schedule(self, trackWeapon, { }, 1, .05)
        scheduler:Start(scheduleId)
        self.__countTrackedWeapons = self.__countTrackedWeapons+1
    end

    MissionEvents:OnWeaponFired(self.__monitorFunc)
    table.insert( __wpnSim_simulations, self )
    if isFunction(self.OnStarted) then
        self:OnStarted()
    end
    return self
end

function DCAF.WeaponSimulation:Stop()
    if not self.__scheduler then
        return end

    MissionEvents:EndOnWeaponFired(self.__monitorFunc)
    if self.__countTrackedWeapons > 0 then
        self.__scheduler:Clear()
    end
    self.__monitorFunc = nil
    self.__scheduler = nil
    local idx = tableIndexOf(__wpnSim_simulations, self)
    if idx then
        table.remove(__wpnSim_simulations, idx)
    end
    if isFunction(self.OnStopped) then
        self:OnStopped()
    end
end

function DCAF.WeaponSimulation:IsActive()
    return self.__scheduler ~= nil
end

function DCAF.WeaponSimulation:OnStarted()
end

function DCAF.WeaponSimulation:OnStopped()
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                           CODEWORDS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.Codewords = {
    FlashGordon = { "Flash Gordon", "Prince Barin", "Ming", "Princess Aura", "Zarkov", "Klytus", "Vultan" },
    JamesBond = { "Moneypenny", "Jaws", "Swann", "Gogol", "Tanner", "Blofeld", "Leiter" },
    RockHeroes = { "Idol", "Dio", "Vaughan", "Lynott", "Lemmy", "Mercury", "Fogerty" },
    Disney = { "Goofy", "Donald Duck", "Mickey", "Snow White", "Peter Pan", "Cinderella", "Baloo" },
    Princesses = { "Cinderella", "Pocahontas", "Ariel", "Anastasia", "Leia", "Astrid", "Fiona" },
    Poets = { "Eliot", "Blake", "Poe", "Keats", "Shakespeare", "Yeats", "Byron", "Wilde" },
    Painters = { "da Vinci", "van Gogh", "Rembrandt", "Monet", "Matisse", "Picasso", "Boticelli" },
    Marvel = { "Wolverine", "Iron Man", "Thor", "Captain America", "Spider Man", "Black Widow", "Star-Lord" },
}

DCAF.CodewordType = {
    Person = {
        DCAF.Codewords.FlashGordon,
        DCAF.Codewords.JamesBond,
        DCAF.Codewords.FlashGordon,
        DCAF.Codewords.JamesBond,
        DCAF.Codewords.RockHeroes,
        DCAF.Codewords.Disney,
        DCAF.Codewords.Princesses,
        DCAF.Codewords.Poets,
        DCAF.Codewords.Painters,
        DCAF.Codewords.Marvel
    }
}

DCAF.CodewordTheme = {
    ClassName = "DCAF.CodewordTheme",
    Name = nil,
    Codewords = {}
}

function DCAF.Codewords:RandomTheme(type, singleUse)
    local themes
    if isAssignedString(type) then
        themes = DCAF.CodewordType[type]
        if not themes then
            error("DCAF.Codewords:RandomTheme :: `type` is not supported: " .. type) end
    else
        themes = DCAF.Codewords
    end

    local key = dictRandomKey(themes)
    local codewords = themes[key]
    local theme = DCAF.CodewordTheme:New(key, codewords, singleUse)
    if isBoolean(singleUse) and singleUse == true then
        DCAF.Codewords[key] = nil
    end
    return theme
end

function DCAF.CodewordTheme:New(name, codewords, singleUse)
    local theme = DCAF.clone(DCAF.CodewordTheme)
    theme.Name = name
    if isBoolean(singleUse) then
        theme.SingleUse = singleUse
    else
        theme.SingleUse = true
    end
    listCopy(codewords, theme.Codewords)
    return theme
end

function DCAF.CodewordTheme:GetNextRandom()
    local codeword, index = listRandomItem(self.Codewords)
    if self.SingleUse then
        table.remove(self.Codewords, index)
    end
    return codeword
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                      WEAPON TRACKING
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local DCAF_TrackWeaponsScheduleID
local DCAF_TrackHandlersCount = 0
local DCAF_WpnTracksCount = 0
local DCAF_WpnTrackersCount = 0

local DCAF_WpnTrackers = {
    -- list of #DCAF.WpnTracker (contains ALL Wpn trackers)
}

local DCAF_WpnTrackers = {
    -- list of #DCAF.WpnTracker (only contains trackers that also tracks trajectories - for performance)
}

local DCAF_WeaponTracks = {
    -- key   - #string (weapon id)
    -- value - #DCAF.WpnTrack
}

DCAF.WpnTracking = {
    Interval = .1,
}

DCAF.WpnTrack = {
    ClassName = "DCAF.WpnTrack",
    ----
    ID = nil,                   -- #string - weapon's ID
    Weapon = nil,               -- DCS object - representing the tracked weapon
    Type = nil,                 -- DCS weapon type
    Category = nil,             -- DCS weapon category
    Point = nil,                -- DCS object - last known position
    Direction = nil,            -- DCS direction
    Velocity = nil,             -- #number - weapon velocity
    IniUnit = nil,              -- #UNIT - the unit who shot/dropped/launched the weapon
    TgtUnit = nil               -- #UNIT - weapon's designated target (if any)
}

DCAF.WpnTracker = {
    ClassName = "DCAF.WpnTracker",
    Name = nil,
}

local function addWpnTracker(tracker)
    table.insert(DCAF_WpnTrackers, tracker)
    return #DCAF_WpnTrackers
end

local function removeWpnTrajectoryTracker(name)
    local idx = tableIndexOf(DCAF_WpnTrackers, function(wt) return name == wt.Name end)
    if idx then
        table.remove(DCAF_WpnTrackers, idx)
    end
    return #DCAF_WpnTrackers
end

local function removeWpnTracker(name)
    removeWpnTrajectoryTracker(name)
    local idx = tableIndexOf(DCAF_WpnTrackers, function(wt) return name == wt.Name end)
    if idx then
        table.remove(DCAF_WpnTrackers, idx)
    end
    return #DCAF_WpnTrackers
end

local function trackWeapons()

    local function vec3Mag(speedVec)
        local mag = speedVec.x*speedVec.x + speedVec.y*speedVec.y+speedVec.z*speedVec.z
        mag = math.sqrt(mag)
        return mag
    end

    local function lookahead(speedVec)
        local speed = vec3Mag(speedVec)
        local dist = speed * DCAF.WpnTracking.Interval * 1.5
        return dist
    end

    for _, wpnTrack in pairs(DCAF_WeaponTracks) do
        if wpnTrack.Weapon:isExist() then
            local countTrackers = 0
            wpnTrack.Point = wpnTrack.Weapon:getPosition().p
            wpnTrack.Direction = wpnTrack.Weapon:getPosition().x
            wpnTrack.Velocity = wpnTrack.Weapon:getVelocity()
            for _, wpnTracker in ipairs(DCAF_WpnTrackers) do
                if wpnTracker:IsTracking(wpnTrack) then
                    countTrackers = countTrackers+1
                    wpnTracker:OnUpdate(wpnTrack)
                end
            end
            if countTrackers == 0 then
                Debug("DCAF.WpnTrack :: no tracker is tracking weapon '" .. wpnTrack.ID .. " [" .. wpnTrack.Type .. "] :: ends weapon track")
                wpnTrack:End()
            end
        elseif not wpnTrack._isEnded then
            -- we have impact...
            local ip = land.getIP(wpnTrack.Point, wpnTrack.Direction, lookahead(wpnTrack.Velocity))  -- terrain intersection point with weapon's nose.  Only search out 20 meters though.
            local impactPoint
            if ip then
                impactPoint = ip
            else
                -- use last calculated Point for impact point
                ip = wpnTrack.Point
            end
            wpnTrack.ImpactCoordinate = COORDINATE:New( ip.x, ip.y, ip.z )
            wpnTrack.ImpactTime = UTILS.SecondsOfToday()
            for _, wpnTracker in ipairs(DCAF_WpnTrackers) do
                if wpnTracker:IsTracking(wpnTrack) then
                    wpnTracker:OnImpact(wpnTrack)
                end
            end
            wpnTrack:End()
        end
    end
end

local function startScheduler()
    DCAF_TrackWeaponsScheduleID = DCAF.startScheduler(trackWeapons, DCAF.WpnTracking.Interval)
end

local function stopScheduler()
    if DCAF_TrackWeaponsScheduleID then
        DCAF.stopScheduler(DCAF_TrackWeaponsScheduleID)
        DCAF_TrackWeaponsScheduleID = nil
    end
end

local function addWpnTrack(wpnTrack)
    DCAF_WeaponTracks[wpnTrack.ID] = wpnTrack
    DCAF_WpnTracksCount = DCAF_WpnTracksCount + 1
    if DCAF_WpnTracksCount == 1 then
        startScheduler()
    end
end

local function removeTrackedWeapon(tw)
    DCAF_WeaponTracks[tw.ID] = nil
    DCAF_WpnTracksCount = DCAF_WpnTracksCount - 1
    if DCAF_WpnTracksCount == 0 and DCAF_TrackWeaponsScheduleID then
        stopScheduler()
    end
end

local function newWpnTrack(event)
    local wpnTrack = DCAF.clone(DCAF.WpnTrack)
    wpnTrack.ID = event.weapon["id_"]
    wpnTrack.Weapon = event.weapon
    wpnTrack.Type = event.weapon:getTypeName()
    wpnTrack.Category = event.weapon:getCategory()
    wpnTrack.Point = event.weapon:getPoint()
    wpnTrack.Direction = event.weapon:getPosition()
    wpnTrack.Velocity = event.weapon:getVelocity()
    wpnTrack.DeployCoordinate = event.IniUnit:GetCoordinate()
    wpnTrack.DeployHeading = event.IniUnit:GetHeading()
    wpnTrack.DeployPitch = event.IniUnit:GetPitch()
    wpnTrack.DeployAltitudeMSL = event.IniUnit:GetAltitude()
    wpnTrack.DeployVelocityKMH = event.IniUnit:GetVelocityKMH()
    wpnTrack.DeployTime = UTILS.SecondsOfToday()
    wpnTrack.IniPoint = wpnTrack.Point
    wpnTrack.IniTime = UTILS:SecondsOfToday()
    wpnTrack.IniGroup = event.IniUnit:GetGroup()
    wpnTrack.IniGroupName = wpnTrack.IniGroup.GroupName
    wpnTrack.IniUnit = event.IniUnit
    wpnTrack.IniUnitType = event.IniUnit:GetTypeName()
    wpnTrack.PlayerName = event.IniUnit:GetPlayerName()
    wpnTrack.Target = event.weapon:getTarget()
    wpnTrack.IniTgt = event.TgtUnit
    wpnTrack.Power = getWeaponExplosive(wpnTrack.Type)
    addWpnTrack(wpnTrack)
    return wpnTrack
end

function DCAF.WpnTrack:GetWeaponCoordinate()
    return COORDINATE:NewFromVec3(self.Point)
end

local function getDistance3D(pos1, pos2)
    local xDiff = pos1.x - pos2.x
    local yDiff = pos1.y - pos2.y
    local zDiff = pos1.z - pos2.z
    return math.sqrt(xDiff * xDiff + yDiff * yDiff + zDiff*zDiff)
end

function DCAF.WpnTrack:Get3DDistance(source)
    local location = DCAF.Location.Resolve(source)
    if not location then return end
    local coordinate = location:GetCoordinate()
    local sourcePos = coordinate:ToPointVec3()
    return getDistance3D(self.Point, sourcePos)
end

function DCAF.WpnTrack:GetDistanceFlown()
    return getDistance3D(self.IniPoint, self.Point)
end

function DCAF.WpnTrack:GetDistanceToTarget()
    local tgtAlive, tgtPos = pcall(function() return self.Target:getPoint() end)
    if not tgtAlive then
        -- target is (no longer) alive...
        Debug("DCAF.WpnTrack:GetDistanceToTarget :: target no longer alive :: IGNORES")
        return
    end
    return getDistance3D(self.Point, tgtPos)
end

function DCAF.WpnTrack:ExplodeWeapon(power)
    local coord = self:GetWeaponCoordinate()
    if coord then 
        coord:Explosion(power or 100)
    end
end

function DCAF.WpnTrack:End()
    if self._isEnded then return self end
    self._isEnded = true
    removeTrackedWeapon(self)
end

function DCAF.WpnTracker:New(name)
    if not isAssignedString(name) then
        error("DCAF.WpnTracker:New :: `name` must be string, but was: " .. DumpPretty(name)) end

    if DCAF.WpnTracker:FindByName(name) then
        error("DCAF.WpnTracker:New :: tracker with name '" .. name .. "' was already created") end

    local tracker = DCAF.clone(DCAF.WpnTracker)
    tracker.Name = name
    addWpnTracker(tracker)
    return tracker
end

--- Starts the weapon tracker
--- @param monitor any bool or number specifies whether tracker should be sent weapon trajectory updates
function DCAF.WpnTracker:Start(monitor)
    if monitor == true then
        table.insert(DCAF_WpnTrackers, self)
    elseif isNumber(monitor) then
        self._updateInterval = monitor
        table.insert(DCAF_WpnTrackers, self)
    end
    DCAF.WpnTracking:Start(self)
    self.IsRunning = true
    return self
end

function DCAF.WpnTracker:IgnoreIniGroups(groups)
    if isAssignedString(groups) then 
        return self:IgnoreIniGroups({ groups })
    end
    if isClass(groups, GROUP) then
        return self:IgnoreIniGroups({ groups })
    end
    if isClass(groups, UNIT) then
        return self:IgnoreIniGroups({ groups:GetGroup() })
    end
    if isListOfAssignedStrings(groups) then
        local listOfGroups = {}
        local index = self._ignoreIniGroups or {}
        for _, name in ipairs(groups) do
            local group = getGroup(name)
            if group and not index[group.GroupName] then
                listOfGroups[#listOfGroups+1] = group
            end
        end
        return self:IgnoreIniGroups(listOfGroups)
    end
    if not isListOfClass(groups, GROUP) then return Error("DCAF.WpnTracker:IgnoreIniGroups :: `groups` could not be resolved as a list of groups", self) end
    self._ignoreIniGroups = self._ignoreIniGroups or {}
    local index = self._ignoreIniGroups
    for _, group in ipairs(groups) do
        if not index[group.GroupName] then
            index[group.GroupName] = group
        end
    end
    return self
end

function DCAF.WpnTracker:IsTracking(wpnTrack)
    -- check for ignore initializing group...
    return not self._ignoreIniGroups or not self._ignoreIniGroups[wpnTrack.IniGroupName]
end

--- Looks up tracker with specified name
-- @param #DCAF.WpnTracker self
-- @param #string name Specifies name of tracker
function DCAF.WpnTracker:FindByName(name)
    if not isAssignedString(name) then
        error("DCAF.FindByName:New :: `name` must be string, but was: " .. DumpPretty(name)) end

    for _, t in ipairs(DCAF_WpnTrackers) do
        if t.Name == name then
            return t end
    end
end

--- For trackers that monitors trajectory (see DCAF.WpnTracker:IsTrackingTrajectory), this method will be called back once per update
function DCAF.WpnTracker:OnUpdate(wpnTrack)
    return true
end

function DCAF.WpnTracker:EndUpdate()
    removeWpnTrajectoryTracker(self.Name)
end

--- Invoked when weapon impacts
function DCAF.WpnTracker:OnImpact(wpnTrack)
    -- to be overridden
end

function DCAF.WpnTracker:End()
    self.IsRunning = false
    local countTrackers = removeWpnTracker(self.Name)
    if countTrackers == 0 then
        -- no trackers remaining - stop tracking weapons
        MissionEvents:EndOnWeaponFired(newWpnTrack)
        stopScheduler()
    end
end

function DCAF.WpnTracking:Start(tracker)
    if not isClass(tracker, DCAF.WpnTracker.ClassName) then
        error("DCAF.WeaponTracking:Start :: `tracker` must be #" .. DCAF.WpnTracker.ClassName .. ", but was: " .. DumpPretty(tracker)) end

    local isRunning = DCAF_TrackWeaponsScheduleID ~= nil
    local restart
    if isNumber(tracker._updateInterval) and tracker._updateInterval < DCAF.WpnTracking.Interval then
        DCAF.WpnTracking.Interval = tracker._updateInterval
        restart = true
    end
    if not isRunning then
        MissionEvents:OnWeaponFired(newWpnTrack)
    end
    if not restart then
        return end

    stopScheduler()
    if DCAF_WpnTracksCount > 0 then
        startScheduler()
    end
end

function DCAF.WpnTracking:Stop(name)
    if not isAssignedString(name) then
        error("DCAF.WeaponTracking:Stop :: `name` must be string, but was: " .. DumpPretty(name)) end

    removeWpnTracker(name)
end

function DCAF.WpnTracking:OnImpact(func, ...)
end


-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                    DCAF.Artillery
--
--                                                         ****

DCAF.Artillery = {
    ClassName = "DCAF.Artillery"
    ----
}

function DCAF.Artillery:StrikeZone(location, delay, radius, count, explosiveStrength, interval)
    local testLocation = DCAF.Location.Resolve(location)
    if not testLocation then
        return Warning("HZB_RocketArtillery:StrikeZone :: cannot resolve location from: " .. DumpPretty(location)) end

    if not isNumber(radius) then
        radius = 250
    end
    if not isNumber(count) then
        count = 10
    end
    if not isNumber(explosiveStrength) then
        explosiveStrength = 250
    end
    if not isNumber(delay) then
        delay = 1
    end
    local vInterval
    if isNumber(interval) then
        vInterval = VariableValue:New(interval, 0)
    elseif isClass(interval, VariableValue) then
        vInterval = interval
    else
        vInterval = VariableValue:New(1, .5)
    end

    local vec2 = testLocation:GetCoordinate():GetVec2()
    local zoneRadius = ZONE_RADIUS:New(DCAF.Artillery.ClassName .. "_StrikeZone_" .. testLocation.Name, vec2, radius, true)

    Debug("HZB_RocketArtillery:StrikeZone :: location: " .. testLocation.Name ..  " :: delay: " .. delay .. " :: count: " .. count .. " :: explosiveStrength: " .. explosiveStrength)

    local function explosion()
        local coord = zoneRadius:GetRandomCoordinate()
-- coord:CircleToAll(100)
        coord:Explosion(explosiveStrength)
    end

    DCAF.delay(function()
        explosion()
        local delay = vInterval:GetValue()
        for _ = 2, count, 1 do
            DCAF.delay(explosion, delay)
            delay = delay + vInterval:GetValue()
        end
    end, delay)
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                   DCAF.BlastDamage
--
--                                                          ****
--
--  This functionality is just a DCAF adaptation/optimization of FrozenDroid's 'splash_damage.lua' script.
--  The reason DCAF opted to include the script into the "DCAF Core" library is because splash_damage.lua relies on
--  internal schedulers to track weapon trajectories. This process can put strain on the sim engine and DCAF Core
--  already does this through the internal #DCAF.WpnTracker system (used by other DCAF Core features, such as #DCAF.WpnSimulation
--  and the target scoring in DCAF.TrainingRanges). So, instead of running a separate trajectory tracker in parallel with the
--  ones used by DCAF Core, the splash damage logic embedded in DCAF Core instead relies on DCAF's weapon tracking mechanism.
--
--  All credits, and our sincere gratitude belongs to FrozenDroid!
--
--  Jonas 'Wife' Rembratt,
--    119th FS, DCAF
--    June 19, 2023
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


--require("DCAF.WpnTracking.lua")

DCAF.BlastDamageOptions = {
    ClassName = "DCAF.BlastDamageOptions",
    --
    LargerExplosions = false,       -- secondary explosions on top of weapon impact points, dictated by the values in the explTable
    GlobalMultiplier = .4,          -- multiplier applied to all blast damage effect
    RocketMultiplier = 1.3,         -- multiplied by the explTable value for rockets
    BlastSearchRadius = 100,        -- this is the max size of any blast wave radius, since we will only find objects within this zone
    BlastStun = false,              -- not implemented
    WaveExplosions = true,          -- secondary explosions on top of game objects, radiating outward from the impact point and scaled based on size of object and distance from weapon impact point
    DamageModel = false,            -- allow blast wave to affect ground unit movement and weapons
    CascadeDamageThreshold = 0.1,   -- if the calculated blast damage doesn't exeed this value, there will be no secondary explosion damage on the unit.  If this value is too small, the appearance of explosions far outside of an expected radius looks incorrect.
    StaticDamageBoost = 2000,       -- apply extra damage to Unit.Category.STRUCTUREs with wave explosions
    InfantryCantFireHealth = 90,    -- if health is below this value after our explosions, set ROE to HOLD to simulate severe injury
    UnitCantFireHealth = 50,        -- if health is below this value after our explosions, set ROE to HOLD to simulate damage weapon systems
    UnitDisabledHealth = 30,        -- if health is below this value after our explosions, disable its movement
}

DCAF.BlastDamage = {
    ClassName = "DCAF.BlastDamage",
    --
    UpdateInterval = .1,
    WpnTracker = nil -- DCAF.WpnTracker:New("Splash Damage")
}

local DCAF_Ordnance = {
    Name = nil,                 -- #string - ordnance internal (DCS) name
    Description = nil,          -- #string - a short description of the ordnance
    Explosive = nil             -- #number - explosive power
}

function DCAF_Ordnance:New(name, explosive, description)
    local o = DCAF.clone(DCAF_Ordnance)
    o.Name = name
    o.Explosive = explosive
    o.Description = description
    return o
end

local explTable = {
    ["FAB_100"] = 45,
    ["FAB_250"] = 100,
    ["FAB_250M54TU"]= 100,
    ["FAB_500"] = 213,
    ["FAB_1500"]  = 675,
    ["BetAB_500"] = 98,
    ["BetAB_500ShP"]= 107,
    ["KH-66_Grom"]  = 108,
    ["M_117"] = 201,
    ["Mk_81"] = 60,
    ["Mk_82"] = 118,
    ["AN_M64"]  = 121,
    ["Mk_83"] = 274,
    ["Mk_84"] = 582,
    ["MK_82AIR"]  = 118,
    ["MK_82SNAKEYE"]= 118,
    ["GBU_10"]  = 582,
    ["GBU_12"]  = 118,
    ["GBU_16"]  = 274,
    ["KAB_1500Kr"]  = 675,
    ["KAB_500Kr"] = 213,
    ["KAB_500"] = 213,
    ["GBU_31"]  = 582,
    ["GBU_31_V_3B"] = 582,
    ["GBU_31_V_2B"] = 582,
    ["GBU_31_V_4B"] = 582,
    ["GBU_32_V_2B"] = 202,
    ["GBU_38"]  = 118,
    ["AGM_62"]  = 400,
    ["GBU_24"]  = 582,
    ["X_23"]  = 111,
    ["X_23L"] = 111,
    ["X_28"]  = 160,
    ["X_25ML"]  = 89,
    ["X_25MP"]  = 89,
    ["X_25MR"]  = 140,
    ["X_58"]  = 140,
    ["X_29L"] = 320,
    ["X_29T"] = 320,
    ["X_29TE"]  = 320,
    ["AGM_84E"] = 488,
    ["AGM_88C"] = 89,
    ["AGM_122"] = 15,
    ["AGM_123"] = 274,
    ["AGM_130"] = 582,
    ["AGM_119"] = 176,
    ["AGM_154C"]  = 305,
    ["S-24A"] = 24,
    --["S-24B"] = 123,
    ["S-25OF"]  = 194,
    ["S-25OFM"] = 150,
    ["S-25O"] = 150,
    ["S_25L"] = 190,
    ["S-5M"]  = 1,
    ["C_8"]   = 4,
    ["C_8OFP2"] = 3,
    ["C_13"]  = 21,
    ["C_24"]  = 123,
    ["C_25"]  = 151,
    ["HYDRA_70M15"] = 3,
    ["Zuni_127"]  = 5,
    ["ARAKM70BHE"]  = 4,
    ["BR_500"]  = 118,
    ["Rb 05A"]  = 217,
    ["HEBOMB"]  = 40,
    ["HEBOMBD"] = 40,
    ["MK-81SE"] = 60,
    ["AN-M57"]  = 56,
    ["AN-M64"]  = 180,
    ["AN-M65"]  = 295,
    ["AN-M66A2"]  = 536,
    ["HYDRA_70_M151"] = 4,
    ["HYDRA_70_MK5"] = 4,
    ["Vikhr_M"] = 11,
    ["British_GP_250LB_Bomb_Mk1"] = 100,           --("250 lb GP Mk.I")
    ["British_GP_250LB_Bomb_Mk4"] = 100,           --("250 lb GP Mk.IV")
    ["British_GP_250LB_Bomb_Mk5"] = 100,           --("250 lb GP Mk.V")
    ["British_GP_500LB_Bomb_Mk1"] = 213,           --("500 lb GP Mk.I")
    ["British_GP_500LB_Bomb_Mk4"] = 213,           --("500 lb GP Mk.IV")
    ["British_GP_500LB_Bomb_Mk4_Short"] = 213,     --("500 lb GP Short tail")
    ["British_GP_500LB_Bomb_Mk5"] = 213,           --("500 lb GP Mk.V")
    ["British_MC_250LB_Bomb_Mk1"] = 100,           --("250 lb MC Mk.I")
    ["British_MC_250LB_Bomb_Mk2"] = 100,           --("250 lb MC Mk.II")
    ["British_MC_500LB_Bomb_Mk1_Short"] = 213,     --("500 lb MC Short tail")
    ["British_MC_500LB_Bomb_Mk2"] = 213,           --("500 lb MC Mk.II")
    ["British_SAP_250LB_Bomb_Mk5"] = 100,          --("250 lb S.A.P.")
    ["British_SAP_500LB_Bomb_Mk5"] = 213,          --("500 lb S.A.P.")
    ["British_AP_25LBNo1_3INCHNo1"] = 4,           --("RP-3 25lb AP Mk.I")
    ["British_HE_60LBSAPNo2_3INCHNo1"] = 4,        --("RP-3 60lb SAP No2 Mk.I")
    ["British_HE_60LBFNo1_3INCHNo1"] = 4,          --("RP-3 60lb F No1 Mk.I")
    ["WGr21"] = 4,                                 --("Werfer-Granate 21 - 21 cm UnGd air-to-air rocket")
    ["3xM8_ROCKETS_IN_TUBES"] = 4,                 --("4.5 inch M8 UnGd Rocket")
    ["AN_M30A1"] = 45,                             --("AN-M30A1 - 100lb GP Bomb LD")
    ["AN_M57"] = 100,                              --("AN-M57 - 250lb GP Bomb LD")
    ["AN_M65"] = 400,                              --("AN-M65 - 1000lb GP Bomb LD")
    ["AN_M66"] = 800,                              --("AN-M66 - 2000lb GP Bomb LD")
    ["SC_50"] = 20,                                --("SC 50 - 50kg GP Bomb LD")
    ["ER_4_SC50"] = 20,                            --("4 x SC 50 - 50kg GP Bomb LD")
    ["SC_250_T1_L2"] = 100,                        --("SC 250 Type 1 L2 - 250kg GP Bomb LD")
    ["SC_501_SC250"] = 100,                        --("SC 250 Type 3 J - 250kg GP Bomb LD")
    ["Schloss500XIIC1_SC_250_T3_J"] = 100,         --("SC 250 Type 3 J - 250kg GP Bomb LD")
    ["SC_501_SC500"] = 213,                        --("SC 500 J - 500kg GP Bomb LD")
    ["SC_500_L2"] = 213,                           --("SC 500 L2 - 500kg GP Bomb LD")
    ["SD_250_Stg"] = 100,                          --("SD 250 Stg - 250kg GP Bomb LD")
    ["SD_500_A"] = 213,                            --("SD 500 A - 500kg GP Bomb LD")
    ["AB_250_2_SD_2"] = 100,                       --("AB 250-2 - 144 x SD-2, 250kg CBU with HE submunitions")
    ["AB_250_2_SD_10A"] = 100,                     --("AB 250-2 - 17 x SD-10A, 250kg CBU with 10kg Frag/HE submunitions")
    ["AB_500_1_SD_10A"] = 213,                     --("AB 500-1 - 34 x SD-10A, 500kg CBU with 10kg Frag/HE submunitions")
    ["AGM_114K"] = 10,
    ["HYDRA_70_M229"] = 8,
    ["AGM_65H"] = 130,
    ["AGM_65D"] = 130,
    ["AGM_65E"] = 300,
    ["AGM_65F"] = 300,
    ["HOT3"] = 15,
    ["AGR_20A"] = 8,
    ["GBU_54_V_1B"] = 118,
}

local function getDistance(point1, point2)
    local x1 = point1.x
    local y1 = point1.y
    local z1 = point1.z
    local x2 = point2.x
    local y2 = point2.y
    local z2 = point2.z
    local dX = math.abs(x1-x2)
    local dZ = math.abs(z1-z2)
    local distance = math.sqrt(dX*dX + dZ*dZ)
    return distance
end

local function vec3Mag(speedVec)
    local mag = speedVec.x*speedVec.x + speedVec.y*speedVec.y + speedVec.z*speedVec.z
    mag = math.sqrt(mag)
    return mag
end

local function tableHasKey(table, key)
    return table[key] ~= nil
end

local function explodeObject(table)
    local point = table[1]
    local distance = table[2]
    local power = table[3]
    trigger.action.explosion(point, power)
end

function getWeaponExplosive(name)
    if explTable[name] then
        return explTable[name]
    else
        return 0
    end
end

local function lookahead(speedVec)
    local speed = vec3Mag(speedVec)
    local dist = speed * DCAF.BlastDamage.UpdateInterval * 1.5
    return dist
end

--controller is only at group level for ground units.  we should itterate over the group and only apply effects if health thresholds are met by all units in the group
local function modelUnitDamage(units, options)
    for i, unit in ipairs(units) do
        if unit:isExist() then  --if units are not already dead
            local health = (unit:getLife() / unit:getDesc().life) * 100
            -- Debug(unit:getTypeName() .. " health %" .. Dump(health))
            if unit:hasAttribute("Infantry") == true and health > 0 then  --if infantry
                if health <= options.InfantryCantFireHealth then
                    ---disable unit's ability to fire---
                    unit:getController():setOption(AI.Option.Ground.id.ROE , AI.Option.Ground.val.ROE.WEAPON_HOLD)
                end
            end
            if unit:getDesc().category == Unit.Category.GROUND_UNIT == true and unit:hasAttribute("Infantry") == false and health > 0 then  --if ground unit but not infantry
                if health <= options.UnitCantFireHealth then
                    ---disable unit's ability to fire---
                    unit:getController():setOption(AI.Option.Ground.id.ROE , AI.Option.Ground.val.ROE.WEAPON_HOLD)
                    -- gameMsg(unit:getTypeName().." weapons disabled")
                end
                if health <= options.UnitDisabledHealth and health > 0 then
                    ---disable unit's ability to move---
                    unit:getController():setTask({ id = 'Hold', params = { } } )
                    unit:getController():setOnOff(false)
                    -- gameMsg(unit:getTypeName().." disabled")
                end
            end
        end
    end
end

local function blastWave(point, radius, weapon, power)

    local foundUnits = {}
    local volS = {
        id = world.VolumeType.SPHERE,
        params = {
            point = point,
            radius = radius
        }
    }
    local options = DCAF.BlastDamage.Options

    local function ifFound(foundObject, val)
        local obj = foundObject
        if foundObject:getDesc().category == Unit.Category.GROUND_UNIT and foundObject:getCategory() == Object.Category.UNIT then
            foundUnits[#foundUnits + 1] = foundObject
        end
        if foundObject:getDesc().category == Unit.Category.GROUND_UNIT then --if ground unit
            if options.BlastStun == true then
                --suppressUnit(foundObject, 2, weapon)
            end
        end
        if options.WaveExplosions == true then
            local obj_location = obj:getPoint()
            local distance = getDistance(point, obj_location)
            local timing = distance/500
            if obj:isExist() then
                if tableHasKey(obj:getDesc(), "box") then
                    local length = (obj:getDesc().box.max.x + math.abs(obj:getDesc().box.min.x))
                    local height = (obj:getDesc().box.max.y + math.abs(obj:getDesc().box.min.y))
                    local depth = (obj:getDesc().box.max.z + math.abs(obj:getDesc().box.min.z))
                    local _length = length
                    local _depth = depth
                    if depth > length then
                        _length = depth
                        _depth = length
                    end
                    local surface_distance = distance - _depth/2
                    local scaled_power_factor = 0.006 * power + 1 --this could be reduced into the calc on the next line
                    local intensity = (power * scaled_power_factor) / (4 * 3.14 * surface_distance * surface_distance )
                    local surface_area = _length * height --Ideally we should roughly calculate the surface area facing the blast point, but we'll just find the largest side of the object for now
                    local damage_for_surface = intensity * surface_area
Debug(obj:getTypeName().." sa:"..surface_area.." distance:"..surface_distance.." dfs:"..damage_for_surface.." pw:"..power)
                    if damage_for_surface > options.CascadeDamageThreshold then
                        local explosion_size = damage_for_surface
                        if obj:getDesc().category == Unit.Category.STRUCTURE then
                            explosion_size = intensity * options.StaticDamageBoost --apply an extra damage boost for static objects. should we factor in surface_area?
                            --debugMsg("static obj :"..obj:getTypeName())
                        end
                        if explosion_size > power then explosion_size = power end --secondary explosions should not be larger than the explosion that created it
                        Delay(timing, function()
                            --create the explosion on the object location
                            explodeObject({ obj_location, distance, explosion_size })
                        end)
                        -- local id = timer.scheduleFunction(explodeObject, {obj_location, distance, explosion_size}, timer.getTime() + timing)  --create the explosion on the object location
                    end
                else
                    Debug("blastWave :: obj has no 'box' property: " .. obj:getTypeName())
                    --debugMsg(obj:getTypeName().." object does not have box property")
                end
            end
        end
        return true
    end

    world.searchObjects(Object.Category.UNIT, volS, ifFound)
    world.searchObjects(Object.Category.STATIC, volS, ifFound)
    world.searchObjects(Object.Category.SCENERY, volS, ifFound)
    world.searchObjects(Object.Category.CARGO, volS, ifFound)
    --world.searchObjects(Object.Category.BASE, volS, ifFound)

    if options.DamageModel == true then
        Delay(1.5, function()
            modelUnitDamage(foundUnits, options) -- allow some time for the game to adjust health levels before running our function
        end)
        -- local id = timer.scheduleFunction(modelUnitDamage, foundUnits, timer.getTime() + 1.5) --allow some time for the game to adjust health levels before running our function
    end
end

function DCAF.BlastDamage:_initWpnTracker()

    function DCAF.BlastDamage.WpnTracker:OnImpact(wpnTrack)
        if not wpnTrack._blastDamageExplosion or wpnTrack._blastDamageExplosion == 0 then
            return end
    
        local options = DCAF.BlastDamage.Options
        local impactPoint = wpnTrack.ImpactCoordinate
        local explosive = wpnTrack._blastDamageExplosion -- getWeaponExplosive(wpnTrack.Type)
        if options.LargerExplosions == true then
            trigger.action.explosion(impactPoint, explosive)
        end
        if options.RocketMultiplier > 0 and wpnTrack.Weapon.cat == Weapon.Category.ROCKET then
            explosive = explosive * options.RocketMultiplier
        end
        blastWave(impactPoint, options.BlastSearchRadius, wpnTrack.Weapon.ordnance, explosive)
    end
    
    function DCAF.BlastDamage.WpnTracker:OnUpdate(wpnTrack)
    -- Debug("DCAF.BlastDamage.WpnTracker:OnUpdate (aaa) :: wpn: '" .. wpnTrack.Type .. "' :: _blastDamageExplosion: " .. Dump(wpnTrack._blastDamageExplosion))
        if wpnTrack._blastDamageExplosion then
            return
        else
            -- ensure we do not track trajectories for unsupported ordnance...
            wpnTrack._blastDamageExplosion = wpnTrack.Power
            if wpnTrack._blastDamageExplosion then
                wpnTrack._blastDamageExplosion = wpnTrack._blastDamageExplosion * DCAF.BlastDamage.Options.GlobalMultiplier
            end
    
    -- Debug("DCAF.BlastDamage.WpnTracker:OnUpdate (bbb) :: wpn: '" .. wpnTrack.Type .. "' :: _blastDamageExplosion: " .. Dump(wpnTrack._blastDamageExplosion))
            if wpnTrack._blastDamageExplosion > 0 then
                return end
    
            Debug("DCAF.BlastDamage.WpnTracker:OnUpdate :: ordnance '" .. wpnTrack.Type .. "' is not supported :: tracking ends")
            self:EndUpdate()
        end
    end
end

function DCAF.BlastDamageOptions:New()
    local o = DCAF.clone(DCAF.BlastDamageOptions)
    return o
end

function DCAF.BlastDamage.Start(options)
    if not isClass(options, DCAF.BlastDamageOptions) then
        DCAF.BlastDamage.Options = DCAF.BlastDamageOptions:New()
    else
        DCAF.BlastDamage.Options = options
    end
    DCAF.BlastDamage.WpnTracker = DCAF.WpnTracker:New("Blast Damage")
    DCAF.BlastDamage:_initWpnTracker()
    DCAF.BlastDamage.WpnTracker:Start(DCAF.BlastDamage.UpdateInterval)
    Trace(DCAF.BlastDamage.ClassName .. " :: started :: options: " .. DumpPretty(DCAF.BlastDamage.Options))
end

---- IR STROBE ----

DCAF.Lase = {
    ClassName = "DCAF.Lase",
    ----
    Name = "",
    IsActive = false
}

DCAF.StrobeProgram = {
    ClassName = "DCAF.LaseStrobeProgram",
    ---
    Count = 1,                      -- no. of times in 'ON' state in each burst sequence
    Duration = .5,                  -- time in 'ON' state
    BurstInterval = .4,             -- time bewteen individual 'blinks' in a burst sequence
    Interval = 2,                   -- time between burst sequences
    RippleUnits = false             -- when true (and source is group), automatically increased no of 'blinks' in each burst sequence, just like with fighters
}

function DCAF.StrobeProgram:New(count, duration, burstInterval, sequenceInterval, rippleUnits)
    local program = DCAF.clone(DCAF.StrobeProgram)
    if not isNumber(count) then count = DCAF.StrobeProgram.Count end
    if not isNumber(duration) then duration = DCAF.StrobeProgram.Duration end
    if not isNumber(burstInterval) then burstInterval = DCAF.StrobeProgram.BurstInterval end
    if not isNumber(sequenceInterval) then sequenceInterval = DCAF.StrobeProgram.Interval end
    if not isBoolean(rippleUnits) then rippleUnits = DCAF.StrobeProgram.RippleUnits end
    program.Count = count
    program.BurstInterval = burstInterval
    program.Interval = sequenceInterval
    program.RippleUnits = rippleUnits
    return program
end

function DCAF.Lase:New(source, code, strobeProgram)
    local lase = DCAF.clone(DCAF.Lase)
    if isClass(strobeProgram, DCAF.StrobeProgram) then
        lase._strobeProgram = strobeProgram
    end

    if not isNumber(code) then code = 1688 end
    lase._code = code
    local unit = getUnit(source)
    if unit then
        lase._source = unit
        lase.Name = unit.UnitName
        return lase
    end
    local group = getGroup(source)
    if not group then return Error("DCAF.IrStrobe:New :: `source` must be #UNIT or #GROUP, but was: " .. DumpPretty(source)) end
    lase._source = group
    lase._isGroup = true
    lase.Name = group.GroupName
    return lase
end

function DCAF.Lase:Start(target, duration, strobeProgram)
    if not isClass(strobeProgram, DCAF.StrobeProgram) then strobeProgram = self._strobeProgram end
    if self.IsActive then
        self:_endLase()
    end

    local tgtUnit = getUnit(target)
    if not tgtUnit then
        local tgtGroup = getGroup(target)
        if tgtGroup then
            tgtUnit = tgtGroup:GetUnit(1)
        end
    end
    if not tgtUnit then return Error("DCAF.Lase:Start :: cannot resolve unit: " .. DumpPretty(target), self) end
    if not tgtUnit:IsActive() then return Error("DCAF.Lase:Start :: cannot lase inactive unit: " .. tgtUnit.UnitName)  end

-- Debug("nisse - DCAF.Lase:Start :: ._isGroup: " .. Dump(self._isGroup))
    if not self._isGroup then
        self:_start(self._source, tgtUnit, 1, strobeProgram)
    else
        local units = self._source:GetUnits()
        for index, unit in ipairs(units) do
            self:_start(unit, tgtUnit, index, strobeProgram)
        end
    end
    if isNumber(duration) then
        DCAF.delay(function()
            self:_endLase()
        end, duration)
    end
    return self
end

function DCAF.Lase:StartStrobe(strobeProgram, duration)
-- Debug("nisse - DCAF.Lase:StartStrobe :: duration: " .. Dump(duration) .. " :: strobeProgram: " .. DumpPretty(strobeProgram))
    if not strobeProgram then strobeProgram = self._strobeProgram or DCAF.StrobeProgram end
    return self:Start(self._source, duration, strobeProgram)
end

function DCAF.Lase:Stop()
    self:_endLase()
end

function DCAF.Lase:_endLase()
    if not self._isGroup then
        self:_stop(self._source)
        return
    end
    for _, unit in ipairs(self._source:GetUnits()) do
        self:_stop(unit)
    end
end

function DCAF.Lase:_start(unit, target, unitIndex, strobeProgram)
-- Debug("nisse - DCAF.Lase:_start :: unit: " .. unit.UnitName .. " :: target: " .. target.UnitName .. " :: unitIndex: " .. unitIndex)
    local duration = Hours(99)
    local bursts
    local blinkInterval
    local sequenceInterval
-- Debug("nisse - DCAF.Lase:_start :: strobeProgram: " .. DumpPretty(strobeProgram))
    if strobeProgram then
        bursts = strobeProgram.Count
        duration = strobeProgram.Duration
        blinkInterval = strobeProgram.BurstInterval + duration
        sequenceInterval = strobeProgram.Interval
        if strobeProgram.RippleUnits then
            bursts = bursts + (unitIndex-1)
        end
    end
    if not bursts then
        unit:LaseUnit(target, self._code, duration)
        return
    end

    -- strobe...

Debug("nisse - DCAF.Lase:_start :: strobe settings: " .. DumpPretty({
    bursts = bursts,
    blinkInterval = blinkInterval,
    sequenceInterval = sequenceInterval,
    duration = duration,
    target = DumpPretty(target)
}))
    local function burstSequence(count)
        unit:LaseUnit(target, self._code, duration)
        for index = 2, count do
-- Debug("nisse - DCAF.Lase:_start :: sequence :: index: " .. index .. " :: ._code: " .. Dump(self._code) .. " :: duration: " .. Dump(duration))
            local delay = (duration + blinkInterval) * index
            BASE:ScheduleOnce(delay, function()
                unit:LaseUnit(target, self._code, duration)
            end)
        end
    end

    sequenceInterval = sequenceInterval + bursts * blinkInterval
    unit._dcafLaseBurstScheduleID = DCAF.startScheduler(function()
        burstSequence(bursts)
    end, sequenceInterval)
end

function DCAF.Lase:_stop(unit)
    if unit._dcafLaseBurstScheduleID then
        pcall(function()
Debug("nisse - DCAF.Lase:_stop :: stops scheduler")
            local id = unit._dcafLaseBurstScheduleID
            unit._dcafLaseBurstScheduleID = nil
            DCAF.stopScheduler(id)
        end)
    end
Debug("nisse - DCAF.Lase:_stop :: " .. unit.UnitName .. " :: laser OFF")
    unit:LaseOff()
end


------- SUBSTITUTE UNITS WITH EQUIVALENT STATIC  ----------

local function getSpawnStaticFrom(unit)
    local typeName = unit:GetTypeName()
    local categoryName = unit:GetCategoryName()
    local spawnStatic = SPAWNSTATIC:NewFromType(typeName, categoryName)
    local coord = unit:GetCoordinate()
    if coord then
        spawnStatic:InitCoordinate(coord)
    end
    local heading = unit:GetHeading()
    if heading then
        spawnStatic:InitHeading(heading)
    end
    spawnStatic:InitCountry(unit:GetCountry())
    -- TODO -- getSpawnStaticFrom :: initialize SPAWNSTATIC with unit livery (when figured out how to do that)
    if not spawnStatic then
        return Error("getSpawnStaticFrom :: cannot get SPAWNSTATIC from type: '" .. Dump(typeName) .. "' :: categoryName: " .. Dump(categoryName)) end

    return spawnStatic, coord
end

--- Attempts replacing a unit with a static equivalent
--- @param source any - name of UNIT/GROUP, or a UNIT/GROUP
--- @param damage number - specifies damage [0,1] (0 = no damage; 1 = fully destroyed)
--- @param damageAge number - specifies how long (seconds) since damage was sustained (is used to create smoke effects)
--- @return table - list of #STATIC
function SubstituteWithStatic(source, damage, damageAge)
    local unit = getUnit(source)
    if not unit then
        local group = getGroup(source)
        if not group then
            return Warning("SubstituteWithStatic :: cannot resolve `source`: " .. DumpPretty(source) .. " :: IGNORES") end

        local statics = {}
        for _, u in ipairs(group:GetUnits()) do
            local static = SubstituteWithStatic(u, damage, damageAge)
            if static then
                table.insert(statics, static[1])
            end
        end
        return statics
    end

    if not isNumber(damage) then
        damage = 0
    end

    if isVariableValue(damageAge) then
        damageAge = damageAge:GetValue()
    end
    if not isNumber(damageAge) then
        if damage == 0 then
            damageAge = 0
        else
            damageAge = 9999
        end
    end

    local spawnStatic, coord = getSpawnStaticFrom(unit)
    if not spawnStatic then return Error("SubstituteWithStatic :: cannot resolve static from '" .. unit.UnitName .. "'") end

    if unit:IsAlive() then
        unit:Destroy()
    end
    if damage > 0 then
        spawnStatic:InitDead(damage >= 0.6)
    end
    local static = spawnStatic:Spawn(nil, unit.UnitName .. " (static)")
    if not static then return Error("SubstituteWithStatic :: could not spawn static from unit: '" .. unit.UnitName) end
    if coord and damage > 0 and damageAge < Minutes(20) then
        if damageAge > Minutes(10) then
            coord:BigSmokeSmall(.05)
        elseif damageAge > Minutes(5) then
            coord:BigSmokeSmall(.3)
        elseif damageAge > Minutes(3) then
            coord:BigSmokeSmall(.5)
        else
            coord:BigSmokeSmall(1)
        end
    end
    Debug("SubstituteWithStatic :: substituted unit '" .. unit.UnitName .. "' with static: " .. Dump(static.StaticName))
    return { static }
end

--- Attempts replacing all units of a #GROUP with a static equivalent
-- @param #number damage - specifies damage [0,1] (0 = no damage; 1 = fully destroyed)
-- @param #number damageTime - (can also be #VariableValue) specifies how long (seconds) since damage was sustained (is used to create smoke effects)
-- @return #table - list of #STATIC
function GROUP:SubstituteWithStatic(damage, damageAge)
    return SubstituteWithStatic(self, damage, damageAge)
end

--- Attempts replacing the #UNIT with a static equivalent
-- @param #number damage - specifies damage [0,1] (0 = no damage; 1 = fully destroyed)
-- @param #number damageTime - (can also be #VariableValue) specifies how long (seconds) since damage was sustained (is used to create smoke effects)
-- @return #table - list of #STATIC
function UNIT:SubstituteWithStatic(damage, damageAge)
    return SubstituteWithStatic(self, damage, damageAge)
end

-------------- LOADED

Trace("\\\\\\\\\\ DCAF.Core.lua was loaded //////////")