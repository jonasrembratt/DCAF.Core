Trace("////////// Loading DCAF.AIRAC.lua ... \\\\\\\\\\")

-- DCAF AIRAC 2022-1
--[[
for SRS testing:
C:\Program Files\DCS-SimpleRadio-Standalone>.\\DCS-SR-ExternalAudio.exe -t "Automated Traffic Information Service, Charlie. Hello World, " -f 305 -m AM -c 2
]]

DCAF.AIRAC = {
    DebugUI = false
}

ATIS.Gender = {
    Male = "male",
    Female = "female",
    Random = "random",
}

ATIS.Culture = {
    GB = "en-GB",
    US = "en-US",
    Random = "random",
}

function ATIS.Gender:IsValid(value)
    if value == nil then return true end
    for k, v in pairs(ATIS.Gender) do
        if value == v then
            return true
        end
    end
end

function ATIS.Culture:IsValid(value)
    if value == nil then return true end
    for k, v in pairs(ATIS.Culture) do
        if value == v then
            return true
        end
    end
end

DCAF.AIRAC.Version = "2023-C"
DCAF.AIRAC.Aerodromes = {}
DCAF.AIRAC.ICAO = {}

function DCAF.AIRAC:StartATIS(icao, sCulture, sGender, nFrequency)

    if not DCAF.Environment.IsATISEnabled then
        return Warning("DCAF.AIRAC:StartATIS :: ATIS is not enabled for this environment (see: DCAF.Environment.IsATISEnabled) :: IGNORES") end

    if isAssignedString(icao) then
        local info = DCAF.AIRAC.ICAO[icao]
        if not info then
            return Warning("DCAF.AIRAC:StartATIS :: aerodrome not supported: " .. DumpPretty(icao) .. " :: IGNORES") end

        if info.ATIS then
            info:StartATIS(sCulture, sGender, nFrequency)
        end
        return Warning("DCAF.AIRAC:StartATIS :: aerodrome does not not supported ATIS: " .. DumpPretty(icao) .. " :: IGNORES")
    else
        for icao, info in pairs(DCAF.AIRAC.ICAO) do
            if info.ATIS then
                info:StartATIS(sCulture, sGender, nFrequency)
            end
        end
    end
end

-- local function addAIRACAerodromes(...)
--     for i = 1, #arg, 1 do
--         local aerodrome = arg[i]
--         DCAF.AIRAC.Aerodromes[aerodrome.Id] = aerodrome
--     end
-- end

DCAF.AIR_ROUTE = {
    ClassName = "DCAF.AIR_ROUTE",
    Name = nil,                         -- #string - name of route
    Group = nil,                        -- #GROUP - (when route gets activated from DCAF.AIR_ROUTE:Fly())
    Waypoints = {},
    DepartureAirbase = nil,             -- #AIRBASE
    ArrivalAirbase = nil,               -- #AIRBASE
    Phase = nil,                        -- #DCAF.AIR_ROUTE_PHASE
    Proc = nil,                         -- #DCAF.AIR_ROUTE_PHASE (SID or STAR)
    HasDeparture = nil,                 -- #boolean - indicates a departure route has been added to route (its waypoints are copied to .Waypoints)
    HasArrival = nil,                   -- #boolean - indicates an arival route has been added to route (its waypoints are copied to .Waypoints)
    -- after activation ( :Fly() )...
    DepartureAirbaseInfo = nil,         -- #AIRBASE_INFO
    ArrivalAirbaseInfo = nil,           -- #AIRBASE_INFO
    Takeoff = nil,                      -- #DCAF.AIR_ROUTE_SPAWNMETHOD
}

DCAF.AIR_ROUTE_OPTIONS = {
    ClassName = "DCAF.AIR_ROUTE_OPTIONS",
    InvisibleToHostileAI = true,
    CruiseSpeedKnots = 400,
    CruiseAltitudeFeet = 30000,
    DestroyOnLastTurnpoint = true,     -- #boolean - when set; flight will automatically be removed once it reaches its last turnpoint (landing waypoints are excluded)
    SID = true,                        -- #string or #boolean - when set; a SID procedure is inserted into route. Use #string to specify SID or #boolean to auto-select a SID
    STAR = true,                       -- #string or #boolean - when set; a STAR procedure is inserted into route. Use #string to specify STAR or #boolean to auto-select a STAR
    OnArrivalFunc = nil                -- #function 
}

DCAF.AIR_ROUTE_PHASE = {
    Takeoff = "Takeoff",
    Land = "Land",
    Missed = "Missed",
    Enroute = "Enroute",
    SID = "SID",
    STAR = "STAR"
}

DCAF.AIR_ROUTE_SPAWNMETHOD = {
    Air = "air",
    Hot = "hot",
    Cold = "cold",
    Runway = "runway"
}

local AIRBASE_INFO = {
    ClassName = "AIRBASE_INFO",
    Name = nil,                 -- #string - name of airdrome
    ICAO = nil,                 -- #string - OIDC code 
    Country = nil,              -- DCS#country.id - country where airdrome reside
    ATIS = nil,                 -- #number; eg. 305 (the ATIS frequency)
    TACAN = nil,                -- #number; eg. 27 (for 27X)
    VOR = nil,                  -- #number; eg. 116.7 (the VOR frequency)
    TWR = { -- list
        -- item = #number (TWR frequency)
    },
    GND = { -- list
    -- item = #number (GND frequency)
    },
    DEP_APP = { -- list
    -- item = #number (DEP/APP frequency)
    },
    ILS = { -- dictionary
        -- key = runway (eg. 27)
        -- value = #number; frequency; eg 108.7
    },
    DepartureProcedures = {},            -- list of #DCAF.AIR_ROUTE
    ArrivalProcedures = {},              -- list of #DCAF.AIR_ROUTE
}

local AIRDROME_CONTROLLER = {
    ClassName = "AIRDROME_CONTROLLER",
    Name = nil,                 -- #string - name of airdrome
    ICAO = nil,                 -- #string - OIDC code 
    ActiveDepartures = {},      -- list of #DEPARTURE (aircraft taxiing and taking off)
    ActiveTaxiRequests = {},    -- list of #DEPARTURE (aircraft waitinhg to be spawned and start taxi/depart)
    ActiveArrivals = {},        -- list of #ARRIVAL (aircraft in arrival pattern, to land)
    ActiveHolds = {},           -- list of #ARRIVAL (aircraft holding, while other are departing)
    _log = {},                  -- list of #string
}

local CONSTANTS = {
    RouteProcedure = "proc",
    RouteProcedureName = "proc_name"
}

local AIR_ROUTE_CALLBACK_INFO = {
    ClassName = "AIR_ROUTE_CALLBACK_INFO",
    NextId = 1,
    Id = 0,              -- #int
    Func = nil,          -- #function
}

local AIR_ROUTE_CALLBACKS = { -- dictionary
    -- key   = #string
    -- value = #AIR_ROUTE_CALLBACK_INFO
}

function isRoute(source)
    return source ~= nil and isClass(source, DCAF.AIR_ROUTE.ClassName)
end

local function airTurnpoint(coord, name, speedKmph, altitudeMeters, tasks)
    local waypoint = coord:WaypointAirTurningPoint(
        COORDINATE.WaypointAltType.BARO,
        speedKmph,
        tasks,
        name)
    if isNumber(altitudeMeters) then
        waypoint.alt = altitudeMeters
        waypoint._isAltitudeLocked = true
    else
        waypoint.alt = nil
    end

    if isNumber(speedKmph) then
        waypoint._isSpeedLocked = true
    end
    return waypoint
end

function AIRBASE_INFO:New(icao, country, name, controller)
    if not isAssignedString(icao) then
        error("AIRBASE_INFO:New :: `icao` must be an assigned string, but was:" .. DumpPretty(icao)) end

    if DCAF.AIRAC.ICAO[icao] then
        error("AIRBASE_INFO:New :: airdrome with ICAO code '" .. icao .. "' already exists") end

    local info = DCAF.clone(AIRBASE_INFO)
    info.ICAO = icao
    info.Name = name
    info.Country = country
    if controller then
        info.Controller = controller
        info.Controller.Name = info.Name
        info.Controller.ICAO = icao
    end
    DCAF.AIRAC.ICAO[icao] = info
    return info
end

function AIRBASE_INFO:WithATIS(freq)
    if not isNumber(freq) then
        error("AIRBASE_INFO:WithATIS :: `atis` must be a number but was: " .. DumpPretty(freq)) end

    self.ATIS = freq
    return self
end    
    
function AIRBASE_INFO:WithTWR(freq)
    if freq == nil then
        return self end

    if isNumber(freq) then
        freq = { freq }
    end
    if not isTable(freq) then
        error("AIRBASE_INFO:WithTWR :: `twr` must be a  number or table with numbers, but was: " .. DumpPretty(freq)) end

    for i, frequency in ipairs(freq) do
        if not isNumber(frequency) then
            error("AIRBASE_INFO:WithTWR :: frequency #" .. Dump(i) .. " must be a  number or table with numbers, but was: " .. DumpPretty(frequency)) end
    end

    self.TWR = freq
    return self
end

function AIRBASE_INFO:WithGND(freq)
    if freq == nil then
        return self end

    if isNumber(freq) then
        freq = { freq }
    end
    if not isTable(freq) then
        error("AIRBASE_INFO:WithGND :: `gnd` must be a  number or table with numbers, but was: " .. DumpPretty(freq)) end

    for i, frequency in ipairs(freq) do
        if not isNumber(frequency) then
            error("AIRBASE_INFO:WithGND :: frequency #" .. Dump(i) .. " must be a  number or table with numbers, but was: " .. DumpPretty(frequency)) end
    end

    self.GND = freq
    return self
end

function AIRBASE_INFO:WithDEP(freq)
    if freq == nil then
        return self end

    if isNumber(freq) then
        freq = { freq }
    end
    if not isTable(freq) then
        error("AIRBASE_INFO:WithDepartureAndApproach :: `gnd` must be a number or table with numbers, but was: " .. DumpPretty(freq)) end

    for i, frequency in ipairs(freq) do
        if not isNumber(frequency) then
            error("AIRBASE_INFO:WithDepartureAndApproach :: frequency #" .. Dump(i) .. " must be a  number or table with numbers, but was: " .. DumpPretty(frequency)) end
    end

    self.DEP_APP = freq
    return self
end

function AIRBASE_INFO:WithTACAN(tacan)
    if tacan == nil then
        return self end

    if isNumber(tacan) then
        self.TACAN = tacan
        return self
    end

    if isTable(tacan) and tacan.Channel then
        return self:WithTACAN(tacan.Channel) end

    return Error("AIRBASE_INFO:WithTACAN :: `tacan` was expected to be #number or table with 'Channel', but was: " .. DumpPretty(tacan))
end

function AIRBASE_INFO:WithILS(ils)
    if ils == nil then
        return self end

    if not isTable(ils) then
        error("AIRBASE_INFO:WithILS :: `ils` must be a number or table with numbers, but was: " .. DumpPretty(ils)) end

    for rwy, frequency in pairs(ils) do
        if not isAssignedString(rwy) then
            error("AIRBASE_INFO:WithILS :: runway must be a assigned string but was: " .. DumpPretty(rwy)) end

        if not isNumber(frequency) then
            error("AIRBASE_INFO:WithILS :: frequency for rwy " .. rwy .. " must be a number but was: " .. DumpPretty(frequency)) end
    end

    self.ILS = ils
    return self
end

function AIRBASE_INFO:WithVOR(vor)
    if vor == nil then
        return self end

    if isNumber(vor) then
        self.VOR = vor
        return self
    end

    if isAssignedString(vor) then
        local validVOR = DCAF.AIRAC.NAVAIDS[vor]
        if not validVOR then
            return Warning("AIRBASE_INFO:WithVOR :: could not find `vor`: " .. DumpPretty(vor)) end

        return self:WithVOR(validVOR)
    end

    if not isClass(vor, DCAF.NAVAID) or vor.Type ~= DCAF.NAVAID_TYPE.VOR then
        return Error("AIRBASE_INFO:WithVOR :: `vor` was expected to be #" .. DCAF.NAVAID.ClassName .. ", but was: " .. DumpPretty(vor)) end

    return self:WithVOR(vor.Frequency)
end

function AIRBASE_INFO:WithVoice(culture, gender)
    if not ATIS.Culture:IsValid(culture) then
        error("AIRBASE_INFO:WithVoice :: invalid `culture` value: " .. DumpPretty(culture)) end

    if not ATIS.Gender:IsValid(gender) then
        error("AIRBASE_INFO:WithVoice :: invalid `gender` value: " .. DumpPretty(gender)) end

    self.CultureATIS = culture
    self.GenderATIS = gender
    return self
end

function AIRBASE_INFO:StartATIS(sCulture, sGender, nFrequency)

    Debug("AIRBASE_INFO:StartATIS :: starts ATIS for " .. self.ICAO .. " :: frequency: " .. self.ATIS)

    local icao
    if isAssignedString(self.ICAO) then
        icao = " (" .. self.ICAO .. ")"
    end

    local function getCulture()
        if not isAssignedString(sCulture) then
            sCulture = self.CultureATIS
        end
        if sCulture ~= ATIS.Culture.Random and ATIS.Culture:IsValid(sCulture) then
            return sCulture
        end
        local key = dictRandomKey(ATIS.Culture)
        while key == ATIS.Culture.Random or isFunction(ATIS.Culture[key]) do
            key = dictRandomKey(ATIS.Culture)
        end
        return ATIS.Culture[key]
    end

    local function getGender()
        if not isAssignedString(sGender) then
            sGender = self.GenderATIS
        end
        if sGender ~= ATIS.Gender.Random and ATIS.Gender:IsValid(sGender)  then
            return sGender
        end
        local key = dictRandomKey(ATIS.Gender)
        while key == ATIS.Gender.Random or isFunction(ATIS.Gender[key]) do
          key = dictRandomKey(ATIS.Gender)
        end
        return ATIS.Gender[key]
    end

    local function getATISFrequency()
        if isNumber(nFrequency) then
            return nFrequency 
        end
        return self.ATIS
    end

    local function getGroundFrequencies(text)
        if #self.GND == 0 then
            return text end

        text = text or ""
        text = text .. ". ground frequency "
        for _, frequency in ipairs(self.GND) do
            text = text .. tostring(frequency) .. " "
        end
        return text
    end

    local function getDepartureAndApproachFrequencies(text)
        if #self.DEP_APP == 0 then
            return text end

        text = text or ""
        text = text .. ". departure frequency "
        for _, frequency in ipairs(self.DEP_APP) do
            text = text .. tostring(frequency) .. " "
        end
        return text
    end

    local gender = getGender()
    local culture = getCulture()

    Debug("Starts ATIS for aerodrome '" .. self.Name .. "'" .. icao .. "; AIRAC (v " .. DCAF.AIRAC.Version .. ") @" .. Dump(self.ATIS) .. "; gender=" .. Dump(gender) .. ", culture=" .. Dump(culture) .. " :: SRS path: " .. DCAF.Folders.SRS)

    local atisFrequency = getATISFrequency()
    local atis = ATIS:New(self.Name, atisFrequency)
        :SetSRS(DCAF.Folders.SRS, gender, culture, nil, DCAF.Environment.SRSPort or 5002)
        :SetImperialUnits()
        :SetActiveRunway(self:GetActiveRunwayTakeoff())

    if isTable(self.TWR) then
        atis:SetTowerFrequencies(self.TWR)
    end
    local extra = getGroundFrequencies()
    extra = getDepartureAndApproachFrequencies(extra)
    if extra and string.len(extra) > 0 then
        atis:SetAdditionalInformation(extra)
    end
    if isTable(self.ILS) then
        for runway, frequency in pairs(self.ILS) do
            atis:AddILS(frequency, runway)
        end
    end
    if isNumber(self.TACAN) then
        atis:SetTACAN(self.TACAN)
    end
    if isNumber(self.VOR) then
        atis:SetVOR(self.VOR)
    end
    atis:Start()
end

function AIRBASE_INFO:AddDepartureProcedures(...)
    if not isList(self.DepartureProcedures) then
        self.DepartureProcedures = {}
    end
    for i = 1, #arg, 1 do
        local dep = arg[i]
        if not isClass(dep, DCAF.AIR_ROUTE.ClassName) or dep.Phase ~= DCAF.AIR_ROUTE_PHASE.Takeoff or dep.Proc ~= DCAF.AIR_ROUTE_PHASE.SID then
            error("AIRBASE_INFO:AddDepartureProcedures :: invalid departue route: " .. DumpPretty(dep)) end

        table.insert(self.DepartureProcedures, dep)
    end
    return self
end

function AIRBASE_INFO:AddArrivalProcedures(...)
    if not isList(self.ArrivalProcedures) then
        self.ArrivalProcedures = {}
    end
    for i = 1, #arg, 1 do
        local arr = arg[i]
        if not isClass(arr, DCAF.AIR_ROUTE.ClassName) or arr.Phase ~= DCAF.AIR_ROUTE_PHASE.Land or arr.Proc ~= DCAF.AIR_ROUTE_PHASE.STAR then
            error("AIRBASE_INFO:AddArrivalProcedures :: invalid arrival route: " .. DumpPretty(arr)) end

        table.insert(self.ArrivalProcedures, arr)
    end
    return self
end

function AIRBASE_INFO:GetActiveRunwayLanding()
    return DCAF.AIRAC:GetAirdromeController(self.ICAO, true):GetActiveRunwayLanding(self.Name)
end

function AIRBASE_INFO:GetActiveRunwayTakeoff()
    return DCAF.AIRAC:GetAirdromeController(self.ICAO, true):GetActiveRunwayTakeoff(self.Name)
end

local function getRouteCoordinate(route)
    if route.Group then
        return route.Group:GetCoordinate()
    end
end

function DCAF.AIR_ROUTE:GetCoordinate()
    return getRouteCoordinate(self)
end

local function getAirbaseWind(id)
    local airbase = AIRBASE:FindByName(id)
    if airbase then
        local coord = airbase:GetCoordinate()
        local windDir, windMps = coord:GetWind(coord:GetLandHeight() + 10) -- airbase: GetCoordinate():GetWind()
        return windDir, windMps, airbase
    end
error("WTF?!")
end

DCAF.AIRDROME_STATE = {
    Open = "Open",
    Departures = "Departures",
    Arrivals = "Arrivals",
    FinishingArrivals = "Finishing Arrivals"
}

local function isValid_AIRDROME_STATE(state)
    return isAssignedString(state) and dictGetKeyFor(DCAF.AIRDROME_STATE, state)
end

local onEndDepartureMonitor

local function setControllerState(controller, state)
    if controller.State == state then
        return end

    if controller.State == DCAF.AIRDROME_STATE.Departures then
        onEndDepartureMonitor(controller)
    end

    controller:Debug("sets airbase to state: " .. state)
    controller.State = state
    controller.StateTime = UTILS.SecondsOfToday()
    local info = DCAF.AIRAC.ICAO[controller.ICAO]
    if info then 
        info.IsBusy = state ~= DCAF.AIRDROME_STATE.Open
    end
    DCAF.CIV.Menus:Refresh()
    return true
end

function AIRDROME_CONTROLLER:New(name, icao, departureCapacity)
    local controller = DCAF.clone(AIRDROME_CONTROLLER)
    controller.Name = name
    controller.ICAO = icao
    controller.State = DCAF.AIRDROME_STATE.Open
    if not isNumber(departureCapacity) then
        departureCapacity = 4
    end
    controller.DepartureCapacity = departureCapacity
    return controller
end

function AIRDROME_CONTROLLER:ResolveRunwayIntoWind(windDirection, ...)
    local minCrosswind = 999
    local minCrosswindRwy
    for i = 1, #arg, 1 do
        local rwy = arg[i]
        local crossWind = math.abs(windDirection - rwy)
        if crossWind < minCrosswind then
            minCrosswind = crossWind
            minCrosswindRwy = rwy
        end
    end
    return minCrosswindRwy
end

function AIRDROME_CONTROLLER:GetActiveRunwayLanding(id)
    local windDir, windMps, airbase = getAirbaseWind(id) -- airbase:GetCoordinate():GetWind(landHeight)
Debug("nisse - AIRDROME_CONTROLLER:GetActiveRunwayLanding :: id: " .. Dump(id) .. " :: windDirection: " .. windDir .. " :: windStrengthMps: " .. windMps .. " :: WindStrengthKts: " .. UTILS.MpsToKnots(windMps))
    if self._activeRunwayLandingResolverFunc then
        return self._activeRunwayLandingResolverFunc(self, { Airbase = airbase, WindDirection = windDir, WindStrengthKts = UTILS.MpsToKnots(windMps) }) end
 
    if airbase then
        return airbase:GetActiveRunwayTakeoff().name
    end
end

function AIRDROME_CONTROLLER:GetActiveRunwayTakeoff(id)
    local windDir, windMps, airbase = getAirbaseWind(id) -- airbase:GetCoordinate():GetWind(landHeight)
Debug("nisse - AIRDROME_CONTROLLER:GetActiveRunwayTakeoff :: id: " .. Dump(id))
    if self._activeRunwayTakeOffResolverFunc then
        return self._activeRunwayTakeOffResolverFunc(self, { Airbase = airbase, WindDirection = windDir, WindStrengthKts = UTILS.MpsToKnots(windMps) }) end

Debug("nisse - AIRDROME_CONTROLLER:GetActiveRunwayTakeoff :: airbase: " .. Dump(airbase ~= nil))
    if airbase then
        return airbase:GetActiveRunwayTakeoff().name
    end
end

function AIRDROME_CONTROLLER:Log(text)
    local timestamp = UTILS.SecondsOfToday()
    local logText = '[' .. UTILS.SecondsToClock(timestamp) .. "] /" .. self.ICAO .. "/ " .. text
    local logEntry = {
        Timestamp = timestamp,
        Text = logText
    }
    table.insert(self._log, logEntry)
    if DCAF.Debug then
        Debug(logText)
    end
Debug("nisse - DCAF.AIRAC.DebugUI: " .. Dump(DCAF.AIRAC.DebugUI))    
    if DCAF.AIRAC.DebugUI then
        local duration = 60
        if isNumber(DCAF.AIRAC.DebugUI) then
            duration = DCAF.AIRAC.DebugUI
        end
        MessageTo(nil, logText, duration)
    end
    return self
end

function AIRDROME_CONTROLLER:Debug(text)
    if DCAF.Debug then
        return self:Log(text)
    end
end

function AIRDROME_CONTROLLER:DumpLog(maxAge, uiTime)
    local minTimestamp
    if isNumber(maxAge) then
        minTimestamp = UTILS.SecondsOfToday() - maxAge
    end
    if not isNumber(uiTime) and DCAF.AIRAC.DebugUI then
        uiTime = 90
        if isNumber(DCAF.AIRAC.DebugUI) then
            uiTime = DCAF.AIRAC.DebugUI
        end
    end
    for _, logEntry in ipairs(self._log) do
Debug("nisse - AIRDROME_CONTROLLER:DumpLog... :: fromTime: " .. minTimestamp .. " :: logEntry: " .. DumpPretty(logEntry))
        if not minTimestamp or logEntry.Timestamp >= minTimestamp  then
            Debug(logEntry.Text)
            -- if uiTime then
            --     MessageTo(nil, logEntry.Text, uiTime)
            -- end
        end
    end

end

local function onRouteArrival(waypoints, name, func)
    -- get last enroute waypoint...
    local wpArrival
    for i = #waypoints, 1, -1 do
        local wp = waypoints[i]
        local phase = wp[CONSTANTS.RouteProcedure]
        if phase == DCAF.AIR_ROUTE_PHASE.Enroute or phase == DCAF.AIR_ROUTE_PHASE.Missed then
            wpArrival = wp
            break
        end
    end
    if not wpArrival then
        return end

    local callback
    callback = AIR_ROUTE_CALLBACK_INFO:New(function()
        func(wpArrival)
        callback:Remove()
    end)
    InsertWaypointAction(wpArrival, ScriptAction("DCAF.AIR_ROUTE:Callback(" .. Dump(callback.Id) .. ")"), name)
    return wpArrival
end

local function onRouteFinal(waypoints, name, func)
    local wpFinal = waypoints[#waypoints-1]
    local callback
    callback = AIR_ROUTE_CALLBACK_INFO:New(function()
        func(wpFinal)
        callback:Remove()
    end)
    InsertWaypointAction(wpFinal, ScriptAction("DCAF.AIR_ROUTE:Callback(" .. Dump(callback.Id) .. ")"), name)
end

local DEPARTURE = {
    ClassName = "DEPARTURE",
    Spawn = nil,            -- #SPAWN
    Route = nil,            -- #DCAF.AIR_ROUTE
    OnSpawnFunc = nil       -- #function - to be called once taxi has been granted
}

local ARRIVAL_ID = 1

local ARRIVAL = {
    ClassName = "ARRIVAL",
    Route = nil,            -- #DCAF.AIR_ROUTE
    HoldAltitude = nil,     -- #number - holding altitude (if holding)
    ArrivalWaypoints = nil, -- #list of waypoints - to be used once cleared for arrival
    -- OnLandedFunc = nil      -- #function - to be called once approach clearance has been granted
}

function DEPARTURE:New(route, spawn, onSpawnFunc)
    local departure = DCAF.clone(DEPARTURE)
    departure.Route = route
    departure.Spawn = spawn
    departure.OnSpawnFunc = onSpawnFunc
    departure.FlightName = route.FlightName
    departure._expires = UTILS.SecondsOfToday() + Minutes(10)
    return departure
end

--- Returns a value indicating whether the departure can be removed (flight is enroute)
function DEPARTURE:HasDeparted()
    return self.Route.Group:IsAirborne()
end

function ARRIVAL:HasArrived()
    return not self.Route.Group:IsAirborne()
end

--- Creates and returns a new #ARRIVAL
-- @param #DCAF.AIR_ROUTE The route
-- @param #number (optional) Calculated ETA (estimated time of arrival, in seconds since midnight)
-- @param #number (optional) A holding altitude (for when the #ARRIVAL represents a holding)
-- @param #table (optional) A route (list of waypoints) to be flown when a hodl is released (for when the #ARRIVAL represents a holding)
-- @return #ARRIVAL The arrival object
function ARRIVAL:New(route, eta, holdAltitude, arrivalWaypoints)
    ARRIVAL_ID = ARRIVAL_ID + 1
    local arrival = DCAF.clone(ARRIVAL)
    arrival.ID = '#' .. tostring(ARRIVAL_ID)
    arrival.Route = route
    arrival.FlightName = route.FlightName
    arrival.HoldAltitude = holdAltitude
    arrival.ArrivalWaypoints = arrivalWaypoints
    arrival.ETA = eta
    return arrival
end

function AIRDROME_CONTROLLER:CountActiveDepartures(purge)
    if #self.ActiveDepartures == 0 then
        return 0 end

    if purge == true then
        tableRemoveWhere(self.ActiveDepartures, function(d)  return d:HasDeparted()  end)
    end
    return #self.ActiveDepartures
end

function AIRDROME_CONTROLLER:GetActiveDepartures()
    return self.ActiveDepartures
end

function AIRDROME_CONTROLLER:CountTaxiRequests()
    return #self.ActiveTaxiRequests
end

function AIRDROME_CONTROLLER:GetTaxiRequests()
    return self.ActiveTaxiRequests
end

local function lockArrivals(controller)
MessageTo("lockArrivals :: " .. controller.ICAO, 60)
    controller._isLockedArrivals = true
end

local function unlockArrivals(controller)
MessageTo("unlockArrivals :: " .. controller.ICAO, 60)
    controller._isLockedArrivals = false
end

function AIRDROME_CONTROLLER:IsLockedForArrivals()
    return self._isLockedArrivals
end

function AIRDROME_CONTROLLER:CountActiveArrivals(purge)
    if #self.ActiveArrivals == 0 then
        return 0 end

    if purge == true then
        tableRemoveWhere(self.ActiveArrivals, function(d)  return d:HasArrived()  end)
    end
    return #self.ActiveArrivals
end

function AIRDROME_CONTROLLER:GetActiveArrivals()
    return self.ActiveArrivals
end

function AIRDROME_CONTROLLER:CountHolds(purge)
    if #self.ActiveHolds == 0 then
        return 0 end

    if purge == true then
        tableRemoveWhere(self.ActiveHolds, function(h)  return h:HasArrived()  end)
    end
    return #self.ActiveHolds
end

function AIRDROME_CONTROLLER:CountTraffic(purge)
    return self:CountActiveDepartures(purge), self:CountActiveArrivals(purge), self:CountHolds(purge)
end

function AIRDROME_CONTROLLER:GetHolds()
    return self.ActiveHolds
end

function AIRDROME_CONTROLLER:GetNextArrivalETA()
    if #self.ActiveArrivals > 0 then
        return self.ActiveArrivals[1].ETA
    end
end

function AIRDROME_CONTROLLER:GetLastArrivalETA()
    return self._lastArrival, self._lastArrivalName
end

local onRemoveActiveDeparture
local onStartDepartureMonitor

local function addDeparture(controller, route)
    if tableIndexOf(controller.ActiveDepartures, function(d)  return d.FlightName == route.FlightName  end) then
        -- departure was already added
        return end

    controller:Debug("Adds departure: " .. route.FlightName .. " :: #taxi requests: " .. controller:CountTaxiRequests())
    table.insert(controller.ActiveDepartures, DEPARTURE:New(route))
    addActiveRoutes(route)
    DCAF.CIV.Menus:Refresh()
    onStartDepartureMonitor(controller)
end

local function addRouteTaxiRequest(controller, route, spawn, onSpawnFunc)
    table.insert(controller.ActiveTaxiRequests, DEPARTURE:New(route, spawn, onSpawnFunc))
    controller:Log("Adds taxi request for route: " .. route.Name .. " :: #taxi requests: " .. controller:CountTaxiRequests())
    DCAF.CIV.Menus:Refresh()
end

local function setControllerLastArrivalETA(controller, eta, flightName)
    controller:Debug("Sets last arrival ETA: " .. flightName .. " @" .. UTILS.SecondsToClock(eta))
    controller._lastArrival = eta
    controller._lastArrivalName = flightName
    return eta
end


local function addArrival(controller, flight, eta)
    local arrival = ARRIVAL:New(flight, eta)
    table.insert(controller.ActiveArrivals, arrival)
    setControllerLastArrivalETA(controller, eta, flight.FlightName)
    local _, arrivals, holds = controller:CountTraffic(true)
    if arrivals + holds > 5 then
        lockArrivals(controller)
    end
    controller:Debug("Adds arrival: " .. flight.FlightName .. " :: ETA: " .. UTILS.SecondsToClock(eta) .. " :: #arrivals: " .. arrivals .. " :: holds: " .. holds)
    DCAF.CIV.Menus:Refresh()
    return arrival
end

local function getHoldAltitude(controller, defaultAltitude, verticalSeparation)
    local alt = defaultAltitude + verticalSeparation

    local function isSufficientSeparation()
        for _, hold in ipairs(controller.ActiveHolds) do
            if math.abs(alt - hold.HoldAltitude) < verticalSeparation then
                return false end
        end
        return true
    end

    for _, hold in ipairs(controller.ActiveHolds) do
        if hold.HoldAltitude ~= alt and isSufficientSeparation() then
            return alt
        end
        alt = alt + verticalSeparation
    end

    if #controller.ActiveHolds == 0 then
        return defaultAltitude
    end
    return controller.ActiveHolds[#controller.ActiveHolds].HoldAltitude
end

local function getHoldIndex(controller, hold)
    if #controller.ActiveHolds > 0 then
        return tableIndexOf(controller.ActiveHolds, function(h)  return h.ID == hold.ID  end)
    end
end

local function addHold(controller, route, altitude, arrivalWaypoints, motivation)
    local hold = ARRIVAL:New(route, nil, altitude, arrivalWaypoints)
    table.insert(controller.ActiveHolds, hold)
    controller._holdAltitude = altitude
    DCAF.CIV.Menus:Refresh()
    return hold
end

local function airbaseControllerArrivalDestroyedEvent(controller, event)
Debug("nisse - airbaseControllerDepartingDestroyedEvent :: event: " .. DumpPrettyDeep(event, 2))    
end

local function airbaseControllerDepartingDestroyedEvent(controller, event) 
Debug("nisse - airbaseControllerDepartingDestroyedEvent :: event: " .. DumpPrettyDeep(event, 2))    
end

local function removeActiveDeparture(controller, group, reason)
Debug("nisse - DEP :: removeActiveDeparture :: group.GroupName: " .. group.GroupName .. " :: departures: " .. DumpPrettyDeep(controller.ActiveDepartures, 1))
    local idx = tableIndexOf(controller.ActiveDepartures, function(a)  return a.Route.FlightName == group.GroupName  end)
    if not idx then
        return Warning("removeActiveDeparture :: controller: " .. controller.Name .. " :: group: " .. group.GroupName .. " :: groups is not AI departure :: IGNORES") end

    table.remove(controller.ActiveDepartures, idx)
    local departures = controller:CountActiveDepartures(true)
    if departures == 0 then -- controller:IsStateExpired() or controller:CountActiveDepartures() == 0 then obsolete
        controller:OpenAirbase()
    end
end

local function removeExpiredDepartures(controller)
    Debug("nisse - DEP :: removeExpiredDepartures :: #controller.ActiveDepartures: " .. #controller.ActiveDepartures)
    for i, departure in ipairs(controller.ActiveDepartures) do
Debug("nisse - DEP :: removeExpiredDepartures :: (has departed): " .. Dump(departure:HasDeparted()) ..  " :: departure: " .. DumpPretty(departure))
        if departure:HasDeparted() then
            removeActiveDeparture(controller, departure.Route.Group, "expired")
        end
    end
end

local function startDepartureMonitor(controller)
    if controller._departureScheduleID then
        return end

    controller._departureScheduleID = DCAF.startScheduler(function()  removeExpiredDepartures(controller)  end, 30)
end
onStartDepartureMonitor = startDepartureMonitor
    
local function endDepartureMonitor(controller)
    if controller._departureScheduleID then
        removeExpiredDepartures(controller)
        DCAF.stopScheduler(controller._departureScheduleID)
        controller._departureScheduleID = nil
    end
end
onEndDepartureMonitor = endDepartureMonitor

local callReleaseHolds
local function removeActiveArrival(controller, groupName)
-- Debug("nisse - removeActiveArrival :: group: " .. groupName .. " :: controller.Arrivals: " .. DumpPrettyDeep(controller.ActiveArrivals, 2))
    local idx = tableIndexOf(controller.ActiveArrivals, function(a)  return a.Route.FlightName == groupName  end)
    if not idx then
        return end -- Warning("removeActiveArrival :: controller: " .. controller.Name .. " :: group: " .. groupName .. " :: groups is not AI arrival :: IGNORES") end

    table.remove(controller.ActiveArrivals, idx)
    if controller:CountActiveArrivals(true) == 0 or controller:IsStateExpired() then
        controller:OpenAirbase()
    end
end

local function airbaseControllerArrivalLandingEvent(controller, event)
-- Debug("nisse - airbaseControllerArrivalLandingEvent :: event: " .. DumpPrettyDeep(event, 2))    
    removeActiveArrival(controller, event.IniGroup.GroupName)
end

local function airbaseControllerTakeoffEvent(controller, event)
    removeActiveDeparture(controller, event.IniGroup)
end

local function clearTaxiRequest(controller, taxiRequest)
    controller:Debug("Clears taxi request for route: " .. taxiRequest.Route.Name)
    table.remove(controller.ActiveTaxiRequests, 1)
    taxiRequest.OnSpawnFunc(taxiRequest.Route)
    addDeparture(controller, taxiRequest.Route)
end

local function clearAllTaxiRequests(controller, interval)
    if controller:CountTaxiRequests() == 0 then
        return end

    if not isNumber(interval) then
        interval = 1
    end

    local function clearNext()
        local taxiRequest = controller.ActiveTaxiRequests[1]
        if not taxiRequest and controller._releaseTaxiRequestScheduleID then
            controller:Debug("All taxi requests have been released")
            DCAF.stopScheduler(controller._releaseTaxiRequestScheduleID)
            return
        end
        clearTaxiRequest(controller, taxiRequest)
    end

    -- release holds with time interval ...
    clearNext()
    controller._releaseTaxiRequestScheduleID = DCAF.startScheduler(function()  clearNext()  end, interval)
end

function AIRDROME_CONTROLLER:ClearTaxi(taxiRequest)
    clearTaxiRequest(self, taxiRequest)
end

local function initiateDepartures(controller)
    if controller.State == DCAF.AIRDROME_STATE.Departures then
        return end

    controller:Log("Initiates departures...")
    setControllerState(controller, DCAF.AIRDROME_STATE.Departures)
    local function onTakeoff(event)
Debug("nisse - onTakeoff :: event: " .. DumpPrettyDeep(event))
        airbaseControllerTakeoffEvent(controller, event)
    end
    local function onDestroyed(event)
        airbaseControllerDepartingDestroyedEvent(controller, event)
    end
    MissionEvents:OnAircraftTakeOff(onTakeoff)
    MissionEvents:OnUnitDestroyed(onDestroyed)
    controller.OnTakeoffFunc = onTakeoff
    controller.OnDestroyedFunc = onDestroyed
    unlockArrivals(controller)
    clearAllTaxiRequests(controller)
end

local function releaseHold(controller, hold)
controller:Debug("nisse - releaseHold :: hold: " .. DumpPretty(hold))
    local holdIndex
    if isNumber(hold) then
        holdIndex = hold
    else
        holdIndex = getHoldIndex(controller, hold)
        if not holdIndex then
controller:Debug("nisse - releaseHold :: cannot resolve hold index")
            return end
    end
    local hold = controller.ActiveHolds[holdIndex]
    if not hold then
controller:Debug("nisse - releaseHold :: was wrong idex")
        return end

    controller:Debug("Releases holding flight: " .. hold.FlightName)

    table.remove(controller.ActiveHolds, holdIndex)
    setGroupRoute(hold.Route.Group, hold.ArrivalWaypoints)
    local eta = hold._eta
    if not eta then
        eta = CalculateRouteETA(hold.ArrivalWaypoints)
    end
    addArrival(controller, hold.Route, eta)
    return hold
end

function AIRDROME_CONTROLLER:ReleaseHold(holdOrFlightName)
    local hold
    if isAssignedString(holdOrFlightName) then
        local idx = tableIndexOf(self.ActiveHolds, function(i)  return i.FlightName == holdOrFlightName  end)
        if idx then
            hold = self.ActiveHolds[idx]
        end
    elseif isClass(holdOrFlightName, ARRIVAL) then
        hold = holdOrFlightName
    end
    if hold then
        releaseHold(self, hold)
    end
end

local function calculateArrivalETA(route, arrivalWP)
    local waypoints = route.Waypoints
    if arrivalWP then
        -- trim waypoints preceeding the 
        local idxArrivalWP = tableIndexOf(waypoints, function(wp)  return wp.name == arrivalWP.name  end)
        if idxArrivalWP then
            waypoints = listCopy(waypoints, {}, idxArrivalWP)
        end
    end
    return CalculateRouteETA(waypoints)
end


local function releaseAllHolds(controller)
controller:Debug("nisse - releaseHolds :: controller.ActiveHolds: " .. DumpPrettyDeep(controller.ActiveHolds, 2))

    if controller:CountHolds() == 0 then
        return end

    local function calcAndSortOnETA()
        local sortedHolds = listCopy(controller.ActiveHolds)
Debug("nisse - releaseAllHolds_calcAndSortOnETA :: sortedHolds: " .. DumpPrettyDeep(sortedHolds, 1))
        table.sort(sortedHolds, function(a, b)
            -- if a == nil then
            --     return b == nil
            -- elseif b == nil then
            --     return true
            -- end
            if not a._eta then
if not a.Route then
    Debug("nisse - WTF?! - a has no Route: " .. DumpPrettyDeep(a, 2))
end 
                a._eta, a._etaClock = calculateArrivalETA(a.Route, a.ArrivalWaypoints)
            end
            if not b._eta then
if not b.Route then
    Debug("nisse - WTF?! - b has no Route: " .. DumpPrettyDeep(b, 2))
end                
                b._eta, b._etaClock = calculateArrivalETA(b.Route, b.ArrivalWaypoints)
            end
            return a._eta <= b._eta
        end)
        return sortedHolds
    end

    local function deconflict(sortedHolds)
        local now = UTILS.SecondsOfToday()
        local lastHold = sortedHolds[1]
        lastHold._release = now
        lastHold._releaseTime = UTILS.SecondsOfToday()
        lastHold._releaseClock = UTILS.SecondsToClock(lastHold._releaseTime)
        for i = 2, #sortedHolds, 1 do
            local hold = sortedHolds[i]
            local diff = hold._eta - lastHold._eta
            if diff >= DCAF.CIV.IntervalArrivalTime then
                hold._release = now
            else
                -- increase release time to deconflict...
                local delay = DCAF.CIV.IntervalArrivalTime - diff
                hold._release = lastHold._release + delay
                hold._eta = hold._eta + delay
                now = hold._release
            end
            hold._releaseTime = UTILS.SecondsToClock(hold._release)
            lastHold = hold
        end
        return sortedHolds
    end

    local deconflictedHoldReleases = deconflict(calcAndSortOnETA())

Debug("nisse - releaseAllHolds :: deconflictedHoldReleases: " .. DumpPrettyDeep(deconflictedHoldReleases, 1))

    if #deconflictedHoldReleases == 1 then
        -- just one hold - no need to schedule...
        releaseHold(controller, deconflictedHoldReleases[1])
        return
    end

    -- release all holds as per scheduled times...
    local idxNextRelease = 1
    local schedulerID
    schedulerID = DCAF.startScheduler(function()
        if idxNextRelease > #deconflictedHoldReleases then
            DCAF.stopScheduler(schedulerID)
            return
        end

        local hold = deconflictedHoldReleases[idxNextRelease]
        if UTILS.SecondsOfToday() < hold._release then
            return end

        releaseHold(controller, hold)
        idxNextRelease = idxNextRelease+1
        if idxNextRelease > #deconflictedHoldReleases then
            DCAF.stopScheduler(schedulerID)
        end
    end, 5)
end
callReleaseHolds = releaseAllHolds

local function initiateArrivals(controller)
    if controller.State == DCAF.AIRDROME_STATE.Arrivals then
        return end

    controller:Log("Initiates arrivals...")
    setControllerState(controller, DCAF.AIRDROME_STATE.Arrivals)
    local function onLanding(event)
        airbaseControllerArrivalLandingEvent(controller, event)
    end
    local function onDestroyed(event)
        airbaseControllerArrivalDestroyedEvent(controller, event)
    end
    MissionEvents:OnAircraftLanded(onLanding)
    MissionEvents:OnUnitDestroyed(onDestroyed)
    controller.OnLandingFunc = onLanding
    controller.OnDestroyedFunc = onDestroyed
    releaseAllHolds(controller)
end

local function finishArrivals(controller)
Debug("nisse - finishArrivals...")
    controller:Log("Finishing arrivals, then initiates departures...")
    callReleaseHolds(controller)

    -- monitor progress...
    local scheduleId
    scheduleId = DCAF.startScheduler(function()
        local arrivals = controller:CountActiveArrivals(true)
Debug("nisse - finishArrivals :: arrivals: " .. arrivals)
        if arrivals > 0 then
            return end

Debug("nisse - finishArrivals :: Opens Airbase :: ENDS")
        controller:OpenAirbase()
        DCAF.stopScheduler(scheduleId)
    end, 30)
Debug("nisse - finishArrivals :: scheduleId: " .. scheduleId)
end

function AIRDROME_CONTROLLER:IsStateExpired()
    if self.State == DCAF.AIRDROME_STATE.FinishingArrivals then
        return false end

    local stateTime = UTILS.SecondsOfToday() - (self.StateTime or 0)
    local maxStateTime = self.MaxStateTime or Minutes(20)
    return stateTime >= maxStateTime
end

local function resetTrafficEvents(controller)
    if controller.OnTakeoffFunc then
        MissionEvents:EndOnAircraftTakeOff(controller.OnTakeoffFunc)
    end
    if controller.OnLandingFunc then
        MissionEvents:EndOnAircraftLanded(controller.OnLandingFunc)
    end
    if controller.OnDestroyedFunc then
        MissionEvents:EndOnUnitDestroyed(controller.OnDestroyedFunc)
    end
end

function AIRDROME_CONTROLLER:OpenAirbase()

Debug("nisse - AIRDROME_CONTROLLER:OpenAirbase :: state: " .. self.State .. " :: #holds: " .. self:CountHolds())

    if self.State == DCAF.AIRDROME_STATE.Arrivals then
        local _, arrivals, holds = self:CountTraffic(true)
        if arrivals + holds == 0 then
            -- initiate departures...
            resetTrafficEvents(self)
            initiateDepartures(self)
        elseif setControllerState(self, DCAF.AIRDROME_STATE.FinishingArrivals) then
            -- finish active arrivals...
            finishArrivals(self)
        end
    elseif self.State == DCAF.AIRDROME_STATE.FinishingArrivals then
        resetTrafficEvents(self)
        initiateDepartures(self)
    elseif self.State == DCAF.AIRDROME_STATE.Departures or self:CountActiveDepartures() == 0 then
        -- initiate arrivals...
        resetTrafficEvents(self)
        initiateArrivals(self)
    else
        self:Log("Opens airbase...")
        resetTrafficEvents(self)
        setControllerState(self, DCAF.AIRDROME_STATE.Open)
    end
end

function AIRDROME_CONTROLLER:FileFlightplan(route)
    -- inject call back function to request arrival...
    onRouteArrival(route.Waypoints, "REQUEST ARRIVAL", function(wpArrival)
        self:RequestArrival(route, wpArrival)
    end)
    onRouteFinal(route.Waypoints, "REQUEST LANDING", function(wpFinal)
        self:RequestLanding(route, wpFinal)
    end)
-- Debug("nisse - AIRDROME_CONTROLLER:FileFlightplan :: last waypoint: " .. DumpPrettyDeep(route.Waypoints[#route.Waypoints-1]))
end

--- Returns a #bool to grant taxi clearance (or not)
function AIRDROME_CONTROLLER:RequestDeparture(spawn, route, onSpawnFunc)
    local function clearedDeparture()
        if not isFunction(onSpawnFunc) then
            return Error("AIRDROME_CONTROLLER:RequestDeparture_clearedForTakeoff :: `onSpawnFunc` must be function, but was: " .. type(onSpawnFunc)) end

        onSpawnFunc(route)
        self:Log("Clears " .. route.FlightName .. " for take off and route: " .. route.Name)
        initiateDepartures(self)
        return true
    end

    if self.State == DCAF.AIRDROME_STATE.Open or self.State == DCAF.AIRDROME_STATE.Departures then
        return clearedDeparture()
    end

    -- stand by (add taxi request)...
    addRouteTaxiRequest(self, route, spawn, onSpawnFunc)
    if self.State == DCAF.AIRDROME_STATE.Arrivals and self:CountTaxiRequests() > 5 then
        setControllerState(self, DCAF.AIRDROME_STATE.FinishingArrivals)
    end
    return false
end

local function getArrivalWaypoints(waypoints)
    -- if route._arrivalWaypoints then
    --     return route._arrivalWaypoints end

    -- get first waypoint after last 'Entroute' waypoint ...
    local oldWaypoints = waypoints
    local isEnroute
    local idxArrival
    for i = 1, #oldWaypoints, 1 do
        local wp = oldWaypoints[i]
        local phase = wp[CONSTANTS.RouteProcedure]
        if phase == DCAF.AIR_ROUTE_PHASE.Enroute or phase == DCAF.AIR_ROUTE_PHASE.Missed then
            isEnroute = true
        elseif isEnroute then
            idxArrival = i-1
            break
        end
    end
    if not idxArrival then
        return Warning("getArrivalWaypoints :: could not find last Enroute/Missed waypoint :: EXITS") end

    local waypoints = listCopy(oldWaypoints, {}, idxArrival)
    -- route._arrivalWaypoints = waypoints
    return waypoints, idxArrival
end

local function goMissedApproach(controller, route)
    if not route.MissedApproachRoute then
        -- todo consider just sending flight back to last 'Enroute' waypoint
        return Warning("goMissed :: route does not support missed approach: " .. route.Name .. " :: IGNORES")
    end

-- Debug("nisse - goMissedApproach :: waypoints:")    
-- for i, wp in ipairs(route.Waypoints) do
--     Debug("      wp #" .. i .. ": " .. DumpPrettyDeep({
--         name = wp.name,
--         proc = wp.proc,
--         task = wp.task
--     }))
-- end    

    -- inject call back function to contact ATC at end of missed approach route...
    route.IsMissedApproach = true
    local waypoints = listJoin(route.MissedApproachRoute.Waypoints, listCopyWhere(route.Waypoints, {}, function(i)
        return i.proc ~= DCAF.AIR_ROUTE_PHASE.Enroute
    end))
    waypoints[1].name = "MISSED APPROACH"

    -- local waypoints, idxArrival = getArrivalWaypoints(waypoints)
    onRouteArrival(waypoints, "MISSED APPROACH", function(wp)
        controller:RequestArrival(route, wp)
    end)

-- Debug("nisse - goMissedApproach :: waypoints:")    
-- for i, wp in ipairs(waypoints) do
--     Debug("      wp #" .. i .. ": " .. DumpPrettyDeep({
--         name = wp.name,
--         proc = wp.proc,
--         task = wp.task
--     }))
-- end

    removeActiveArrival(controller, route.FlightName)
    setGroupRoute(route.Group, waypoints)
    return route
end

local function hold(controller, route, wp, speed, motivation)
    controller:Log("Holds flight " .. route.FlightName .. " :: " .. motivation or "(no motivation)")
    local function buildHoldingWaypoints(alt)
        local waypoints = {}
        local heading = (route.Group:GetHeading() - 180) % 360
        local hdgOffset = (heading + 90) % 360
        local coordDummy = COORDINATE_FromWaypoint(wp)
        local coordStart = coordDummy:Translate(NauticalMiles(3), hdgOffset)
        local coordEnd = coordStart:Translate(NauticalMiles(8), heading)
        local speed = speed or Knots(200)
        local holdTask = route.Group:TaskOrbit(coordStart, alt, speed, coordEnd)
        local waypoints = {
            airTurnpoint(coordDummy, "ARRIVAL", speed, alt),
            airTurnpoint(coordStart, "HOLD START", speed, alt, { holdTask }),
            airTurnpoint(coordStart, "HOLD END", speed, alt)
        }
        return waypoints
    end

    local alt = getHoldAltitude(controller, wp.alt, Feet(2000))
    local holdItem = addHold(controller, route, alt, getArrivalWaypoints(route.Waypoints), motivation)
    setGroupRoute(route.Group, buildHoldingWaypoints(alt))
    return holdItem
end

function AIRDROME_CONTROLLER:Hold(flightNameOrArrival)
    local arrival
    local idx
    if isAssignedString(flightNameOrArrival) then
        local flightName = flightNameOrArrival
        idx = tableIndexOf(self.ActiveArrivals, function(i)  return i.FlightName == flightName   end)
        if idx then
            arrival = self.ActiveArrivals[idx]
        end
    elseif isClass(flightNameOrArrival, ARRIVAL) then
        arrival = flightNameOrArrival
        idx = tableIndexOf(self.ActiveArrivals, function(i)  return i.FlightName == arrival.FlightName   end)
    end
    if arrival then
        -- local alt = getHoldAltitude(self, wp.alt) + Feet(2000)
        addHold(self, arrival.Route, nil, nil, "Held manually, via menu selection")
    end
end

--- Returns a #bool to grant approach clearance (or not)
function AIRDROME_CONTROLLER:RequestArrival(route, wp)

Debug("nisse - AIRDROME_CONTROLLER:RequestArrival /" .. self.ICAO .. "/ :: state: " .. self.State .. " :: #departures: " .. self:CountActiveDepartures())

    self:Log("Request arrival: " .. route.FlightName)
    local function delayArrival(seconds, motivation)
        self:Log("Delays flight " .. route.FlightName .. " " .. seconds .. " seconds...")
        local holdItem = hold(self, route, wp, nil, motivation)
        DCAF.delay(function()
            self:Log("Delayed flight proceeds: " .. holdItem.FlightName)
            releaseHold(self, holdItem)
        end, seconds)
    end

    local function clearedArrival(eta)
        addArrival(self, route, eta)
        initiateArrivals(self)
        return true
    end

    local function processArrival()
        local eta, etaClock = calculateArrivalETA(route, wp)
        local lastETA, flightName = self:GetLastArrivalETA()
        if lastETA and flightName ~= route.FlightName then
            local diff = eta - lastETA
self:Debug("nisse - AIRDROME_CONTROLLER:RequestArrival :: eta: " .. etaClock .. " :: lastETA: " .. UTILS.SecondsToClock(lastETA) .. " :: diff: " .. diff)
            if eta < lastETA then
                local diff = lastETA - eta
                if diff > DCAF.CIV.IntervalArrivalTime then
                    -- overtake last arrival and approach before it...
                    clearedArrival(eta)
                    setControllerLastArrivalETA(self, lastETA, flightName)
                    return
                end
            end
            if diff < DCAF.CIV.IntervalArrivalTime then
                local delay = DCAF.CIV.IntervalArrivalTime - diff
                setControllerLastArrivalETA(self, lastETA + delay, route.FlightName)
                local motivation = "time conflict: " .. etaClock .. " / " .. UTILS.SecondsToClock(lastETA)
                return delayArrival(delay, motivation)
            -- elseif eta < lastETA then
            --     local newETA = lastETA + DCAF.CIV.IntervalArrivalTime
            --     local delay = newETA - eta
            --     local motivation = "Flight would overtake flight " .. flightName .. " (" .. UTILS.SecondsToClock(lastETA) .. ")"
            --     setControllerLastArrivalETA(self, newETA, route.FlightName)
            --     return delayArrival(delay)
            end
        end
        -- cleared to approach ...
        return clearedArrival(eta)
    end 

    if self.State == DCAF.AIRDROME_STATE.Open or self.State == DCAF.AIRDROME_STATE.Arrivals then
        return processArrival()
    end

    if self.State == DCAF.AIRDROME_STATE.Departures then
        if self:CountActiveDepartures() == 0 or self:IsStateExpired() then
            return processArrival()
        end
    end
    return hold(self, route, wp, nil, "airdrome state: " .. self.State)
end

function AIRDROME_CONTROLLER:RequestLanding(route, wp)
    self:Log("Request landing: " .. route.FlightName)
    local now = UTILS.SecondsOfToday()

    local function goMissed(motivation)
        self:Log("Goes missed: " .. route.FlightName .. " (" .. motivation .. ")")
        goMissedApproach(self, route)
    end

    local function clearedToLand()
        self:Log("Cleared to land: " .. route.FlightName .. " :: route: " .. route.Name)
        -- local timeToLand = 
        if not route._calculatedTimeToLand then
            local finalWP = DCAF.clone(route.Waypoints[#route.Waypoints])
            -- finalWP.speed = Knots(180)
            route._timeToLand = CalculateRouteTime({ finalWP }, route.Group:GetCoordinate())
self:Debug("nisse - estimated final route time: " .. route._timeToLand .. " seconds (" .. UTILS.SecondsToClock(now + route._timeToLand) .. ") :: finalWP.speed: " .. UTILS.MpsToKnots(finalWP.speed))
        end
        local landingGroupName = route.FlightName
        DCAF.delay(function()  removeActiveArrival(self, landingGroupName)  end, route._timeToLand)
        self._activeLanding = route
        self._activeLandingName = route.FlightName
        self._activeLandingTime = now
    end

self:Debug("nisse - AIRDROME_CONTROLLER:RequestLanding :: #departures: " .. self:CountActiveDepartures())    

    if self:CountActiveDepartures() > 0 then
        local activeDepartures = {}
        for _, ad in ipairs(self.ActiveDepartures) do
            table.insert(activeDepartures, ad.FlightName)
        end
        return goMissed("# of active departures: " .. self:CountActiveDepartures() .. ": " .. DumpPretty(activeDepartures)) 
    end

    if not self._activeLanding then
        return clearedToLand() end

    local timeSinceLastFinals = now - self._activeLandingTime
    if DCAF.CIV and timeSinceLastFinals < DCAF.CIV.IntervalArrivalTime then
        return goMissed("too close to active landing: " .. self._activeLandingName) end

    local coord = getRouteCoordinate(route)
    local coordActiveLanding = getRouteCoordinate(self._activeLanding)
    local distance = coord:Get2DDistance(coordActiveLanding)

Debug("nisse - AIRDROME_CONTROLLER:RequestLanding :: activeLandingName: " .. Dump(self._activeLandingName) .. " :: _activeLandingTime: " .. Dump(UTILS.SecondsToClock(self._activeLandingTime)) .. " ::  distance: " .. distance)

    local timeSineLastFinals = UTILS.SecondsOfToday
    if DCAF.CIV and distance < DCAF.CIV.IntervalArrivalDistance then
        return goMissed("too close to active landing: " .. self._activeLandingName) end

    return clearedToLand()
end

local function RestrictedAirbaseController(rwyLandingResolverFunc, rwyTakeOffResolveFunc)
    if not isFunction(rwyLandingResolverFunc) then
        return Error("RestrictedAirbaseController :: `rwyResolverFunc` must be function, but was: " .. DumpPretty(rwyLandingResolverFunc)) end

    local controller = AIRDROME_CONTROLLER:New()
    controller._activeRunwayLandingResolverFunc = rwyLandingResolverFunc
    controller._activeRunwayTakeOffResolverFunc = rwyTakeOffResolveFunc or rwyLandingResolverFunc
    return controller
end

local function SimpleAirbaseController(windTakeoffRWY, lullTakeoffRWY, windLandingRWY, lullLandingRWY)
    if not isAssignedString(windTakeoffRWY) then
        error("SimpleAirbaseDelegate :: `windTakeoffRWY` must be assigned string, but was: " .. DumpPretty(windTakeoffRWY)) end

    if not isAssignedString(lullTakeoffRWY) then
        lullTakeoffRWY = windLandingRWY
    end

    if not isAssignedString(windLandingRWY) then
        windLandingRWY = windTakeoffRWY
    end

    if not isAssignedString(lullLandingRWY) then
        lullLandingRWY = lullTakeoffRWY
    end

    local controller = AIRDROME_CONTROLLER:New()
    controller._isSimpleDelegate = true
    controller.WindTakeoffRWY = windTakeoffRWY
    controller.LullTakeoffRWY = lullTakeoffRWY
    controller.WindLandingRWY = windLandingRWY
    controller.LullLandingRWY = lullLandingRWY

    function controller:GetActiveRunwayLanding(id)
        local direction, strength = getAirbaseWind(id)
controller:Debug("nisse - controller:GetActiveRunwayLanding :: strength: " .. Dump(strength) .. " :: controller: " .. DumpPrettyDeep(controller, 1))
        if strength and strength >= 1 then
            return self.WindLandingRWY
        else
            return self.LullLandingRWY
        end
    end

    function controller:GetActiveRunwayTakeoff(id)
        local direction, strength = getAirbaseWind(id)
        if strength and strength >= 1 then
            return self.WindTakeoffRWY
        else
            return self.LullTakeoffRWY
        end
    end

    return controller
end

function DCAF.AIRAC:GetAirbaseICAO(airbase)
    if isClass(airbase, AIRBASE.ClassName) then
        airbase = airbase.AirbaseName
    elseif not isAssignedString(airbase) then
        error("DCAF.AIRAC:GetAirbaseICAO :: `airbase` must be assigned string (airbase name) or of type " .. AIRBASE.ClassName)
    end
    for icao, info in pairs(DCAF.AIRAC.ICAO) do
        if isClass(info, AIRBASE_INFO.ClassName) and info.Name == airbase then
            return info.ICAO end
    end
end

function DCAF.AIRAC:InitiateDepartures(icao)
    if not isAssignedString(icao) then
        error("DCAF.AIRAC:InitiateDepartures :: `icao` must be assigned string, but was: " .. DumpPretty(icao)) end

    local info = DCAF.AIRAC.ICAO[icao]
    if not info then 
        return Warning("DCAF.AIRAC:InitiateDepartures :: aidrome is not recognized: `" .. icao .. "`") end

    initiateDepartures(info.Controller)
end

function DCAF.AIRAC:InitiateArrivals(icao)
    if not isAssignedString(icao) then
        error("DCAF.AIRAC:InitiateArrivals :: `icao` must be assigned string, but was: " .. DumpPretty(icao)) end

    local info = DCAF.AIRAC.ICAO[icao]
    if not info then 
        return Warning("DCAF.AIRAC:InitiateArrivals :: aidrome is not recognized: `" .. icao .. "`") end

    initiateArrivals(info.Controller)
end

--- Returns a list of busy airdromes (items of type #AIRBASE)
function DCAF.AIRAC:GetBusyAirdromes()
    local busyAirdromes = {}
    for icao, info in pairs(DCAF.AIRAC.ICAO) do
        if info.IsBusy then
            table.insert(busyAirdromes, info)
        end
    end
    return busyAirdromes
end

function DCAF.AIRAC:GetAirdromeController(icao, ensure)
    if not isAssignedString(icao) then
        return Warning("DCAF.AIRAC:GetAirdromeController :: `icao` must be assigned string, but was: " .. DumpPretty(icao)) end

    local info = DCAF.AIRAC.ICAO[icao]
    if not info then
        return Warning("DCAF.AIRAC:GetAirdromeController :: no info for airdrome '" .. icao .. "'") end

    if info.Controller then
        return info.Controller
    elseif ensure == true then
        info.Controller = AIRDROME_CONTROLLER:New(info.Name, icao)
        info.Controller.Name = info.Name
        info.Controller.ICAO = icao
        return info.Controller
    end
end

function DCAF.AIRAC:DumpAirdromeControllerLog(icao, maxAge, uiTime)
    local controller = DCAF.AIRAC:GetAirdromeController(icao)
    if controller then
        controller:DumpLog(maxAge, uiTime)
    end
end

function DCAF.AIRAC:GetDepartureInfo(route)
    if not route.DepartureAirbase then
        return Error("DCAF.AIRAC:GetDepartureInfo :: route contains no departure airdrome: " .. route.Name) end
    
    local icao = DCAF.AIRAC:GetAirbaseICAO(route.DepartureAirbase)
    if not icao then
        return Warning("DCAF.AIRAC:GetDepartureInfo :: cannot resolve ICAO from airbase: " .. route.DepartureAirbase.AirbaseName) end

    return DCAF.AIRAC.ICAO[icao]
end

function DCAF.AIRAC:GetDepartureController(route)
    local info = self:GetDepartureInfo(route)
    if not info then
        return Warning("DCAF.AIRAC:GetDepartureController :: cannot resolve departure airbase info from airbase: " .. route.DepartureAirbase.AirbaseName) end
    
    return DCAF.AIRAC:GetAirdromeController(info.ICAO, true)
    -- return info.Controller
end

function DCAF.AIRAC:GetArrivalInfo(route)
    if not route.ArrivalAirbase then
        return end --Error("DCAF.AIRAC:GetArrivalInfo :: route contains no arrival airdrome: " .. route.Name) end

    local icao = DCAF.AIRAC:GetAirbaseICAO(route.ArrivalAirbase)
    if not icao then
        return Warning("DCAF.AIRAC:GetArrivalInfo :: cannot resolve ICAO from airbase: " .. route.ArrivalAirbase.AirbaseName) end

    local info = DCAF.AIRAC.ICAO[icao]
    if not info then
        return Warning("DCAF.AIRAC:GetArrivalInfo :: no info for ICAO '" .. icao .. "'") end

    return info
end

function DCAF.AIRAC:GetArrivalController(route)
    local info = self:GetArrivalInfo(route)
    if not info then
        return Warning("DCAF.AIRAC:GetArrivalController :: cannot resolve arrival airbase info from route: " .. route.Name) end
    
    return DCAF.AIRAC:GetAirdromeController(info.ICAO, true)
    -- return info.Controller
end

local function getAirbaseInfo(airbase, caller)
    if isAssignedString(airbase) then
        local testAirbase = AIRBASE:FindByName(airbase)
        if not testAirbase then
            if string.len(airbase) == 4 then
                -- assume ICAO code
                local info = DCAF.AIRAC.ICAO[airbase]
                if info then 
                    return info
                end
            end
            error(caller .. " :: cannot resolve airbase from '" .. airbase .. "'") end

        airbase = testAirbase
    end
    if not isClass(airbase, AIRBASE.ClassName) then
        error(caller .. " :: `airbase` must be assigned string (airbase name) or #AIRBASE, but was: " .. DumpPretty(airbase)) end

    for icao, info in pairs(DCAF.AIRAC.ICAO) do
        if info.Name == airbase.AirbaseName then
            return info, airbase
        end
    end
end

function DCAF.AIRAC:GetDepartureRoutes(airbase, runway)
    local info, airbase = getAirbaseInfo(airbase, "DCAF.AIRAC:GetDepartureRoutes")
    if not info then
        return end

    if not isAssignedString(runway) then
        runway = airbase:GetActiveRunwayTakeoff()
        runway = runway.name
    end
    local departures = {}
    for _, dep in ipairs(info.DepartureProcedures) do
        for _, rwy in ipairs(dep.Runways) do
            if string.find(rwy, runway) then
                table.insert(departures, dep)
                break
            end
        end
    end 
    return departures
end

function DCAF.AIRAC:GetArrivalRoutes(airbase, runway)
    local info, airbase = getAirbaseInfo(airbase, "DCAF.AIRAC:GetArrivalRoutes")
    if not info then
        return end

    if not isAssignedString(runway) then
        runway = airbase:GetActiveRunwayLanding()
        runway = runway.name
    end
    local arrivals = {}
    for _, arr in ipairs(info.ArrivalProcedures) do
        for _, rwy in ipairs(arr.Runways) do
            if string.find(rwy, runway) then
                table.insert(arrivals, arr)
                break
            end
        end
    end 
    return arrivals
end

function DCAF.AIRAC:GetCountry(airbase)
    if isClass(airbase, AIRBASE.ClassName) then
        airbase = DCAF.AIRAC:GetAirbaseICAO(airbase)
    end
    if not isAssignedString(airbase) then 
        error("DCAF.AIRAC:GetCountry :: unexpected `airbase` value: " .. DumpPretty(airbase)) end

    local info = DCAF.AIRAC.ICAO[airbase]
    if info then
        return info.Country
    end
end

function DCAF.AIRAC:GetLocation(ident)
    local airdrome = DCAF.AIRAC.ICAO[ident]
    if airdrome then
        local airbase = AIRBASE:FindByName(airdrome.Name)
        if airbase then
            return DCAF.Location:New(airbase)
        end
        return
    end
    local navaid = DCAF.AIRAC.NAVAIDS[ident]
    if not navaid then
        return end

    local location = DCAF.Location:NewNamed(ident, navaid, false)
    location.Coordinate = navaid.Coordinate
    return location
end

DCAF.AIRAC.SID = {
    -- list of #DCAF.AIR_ROUTE
}



DCAF.AIRAC.STAR = {
    -- list of #DCAF.AIR_ROUTE
}

--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                        NAVAIDS
--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.AIRAC.NAVAIDS = {}

DCAF.NAVAID_TYPE = {
    FIX = "FIX",
    VOR = "VOR",
    DME = "DME",
    TACAN = "TACAN",
    VORTAC = "VORTAC",
}

DCAF.NAVAID = {
    ClassName = "DCAF.NAVAID",
    Name = nil,                 -- #string - name of NAVAID
    Coordinate = nil,           -- #MOOSE/COORDINATE
    Map = nil,                  -- #string (see MOOSE/DCSMAP)
    Type = DCAF.NAVAID_TYPE.FIX,
    Hidden = nil                -- #bool - true = will not be rendered
}

DCAF.AIRAC.NAVAIDS = {}

function DCAF.NAVAID_TYPE:IsValid(type)
    return type == DCAF.NAVAID_TYPE.VOR
        or type == DCAF.NAVAID_TYPE.DME
        or type == DCAF.NAVAID_TYPE.TACAN
        or type == DCAF.NAVAID_TYPE.FIX
        or type == DCAF.NAVAID_TYPE.VORTAC
end

function DCSMAP:IsValid(map)
    return map == DCSMAP.Caucasus
        or map == DCSMAP.MarianaIslands
        or map == DCSMAP.Normandy
        or map == DCSMAP.NTTR
        or map == DCSMAP.PersianGulf
        or map == DCSMAP.Syria
        or map == DCSMAP.TheChannel
end

function DCAF.NAVAID:New(map, name, coordinate, type, hidden)
    if not isAssignedString(map) then
        error("DCAF.NAVAID:New :: `map` must be assigned string") end
    if not DCSMAP:IsValid(map) then
        error("DCAF.NAVAID:New :: unknown map: " .. map) end
    if not isAssignedString(name) then
        error("DCAF.NAVAID:New :: `name` must be assigned string") end
    if not isClass(coordinate, COORDINATE.ClassName) then
        error("DCAF.NAVAID:New :: `coordinate` must be type: " .. COORDINATE.ClassName) end
    if isAssignedString(type) then
        if not DCAF.NAVAID_TYPE:IsValid(type) then
            error("DCAF.NAVAID:New :: invalid `type`: " .. DumpPretty(type)) end
    else
        type = DCAF.NAVAID_TYPE.FIX
    end
    
    if DCAF.AIRAC.NAVAIDS[name] then
        error("DCAF.NAVAID:NewFix :: navaid was already added: '" .. name .. "'") end

    local navaid = DCAF.clone(DCAF.NAVAID)
    navaid.Map = map
    navaid.Name = name
    navaid.Coordinate = coordinate
    navaid.Type = type
    navaid.Hidden = hidden
    DCAF.AIRAC.NAVAIDS[name] = navaid
    return navaid
end

local _DCAF_defaultMap

function DCAF.NAVAID:NewFix(name, coordinate, map)
    return DCAF.NAVAID:New(map or _DCAF_defaultMap, name, coordinate, DCAF.NAVAID_TYPE.FIX)
end

function DCAF.NAVAID:NewVOR(name, frequency, coordinate, map)
    if not isNumber(frequency) then
        error("DCAF.NAVAID:NewVOR :: `frequency` must be a number but was: " .. DumpPretty(frequency)) end

    local vor = DCAF.NAVAID:New(map or _DCAF_defaultMap, name, coordinate, DCAF.NAVAID_TYPE.VOR)
    vor.Frequency = frequency
    return vor
end

function DCAF.NAVAID:NewDME(name, frequency, coordinate, map)
    if not isNumber(frequency) then
        error("DCAF.NAVAID:NewDME :: `frequency` must be a number but was: " .. DumpPretty(frequency)) end

    local dme = DCAF.NAVAID:New(map or _DCAF_defaultMap, name, coordinate, DCAF.NAVAID_TYPE.DME)
    dme.Frequency = frequency
    return dme
end

function DCAF.NAVAID:NewTACAN(name, channel, mode, coordinate, map)
    if not isNumber(channel) then
        error("DCAF.NAVAID:NewTACAN :: `channel` must be a number but was: " .. DumpPretty(channel)) end
        
    if mode == nil then
        mode = "X"
    end
    if not isAssignedString(mode) then
        error("DCAF.NAVAID:NewTACAN :: `mode` must be assigned string but was: " .. DumpPretty(mode))
    elseif not DCAF_TACAN:IsValidMode(mode) then
        error("DCAF.NAVAID:NewTACAN :: invalid `mode`: " .. DumpPretty(mode))
    end
    
    local tacan = DCAF.NAVAID:New(map or _DCAF_defaultMap, name, coordinate, DCAF.NAVAID_TYPE.TACAN)
    tacan.Channel = channel
    tacan.Mode = mode
    return tacan
end

function DCAF.NAVAID:IsEmitter()
    return self.Type ~= DCAF.NAVAID_TYPE.FIX
end

function DCAF.NAVAID:NewVORTAC(name, frequency, channel, mode, coordinate, map)
    if not isNumber(frequency) then
        error("DCAF.NAVAID:NewVORTAC :: `frequency` must be a number but was: " .. DumpPretty(frequency)) end

    local vortac = DCAF.NAVAID:NewTACAN(name, channel, mode, coordinate, map)
    vortac.Frequency = frequency
    return vortac
end

function DCAF.NAVAID:AirTurnpoint(speedKmph, altitudeMeters, tasks)
    if not isNumber(speedKmph) and isNumber(self.SpeedKt) then
        speedKmph = Knots(self.speedKt) end

    if not isNumber(altitudeMeters) and isNumber(self.AltFt) then
        altitudeMeters = Feet(self.AltFt) end
           
    return airTurnpoint(self.Coordinate, self.Name, speedKmph, altitudeMeters)
end

function DCAF.NAVAID:Draw(coalition, text, color, lineColor, size)
    local validCoalition = Coalition.Resolve(coalition)
    if validCoalition then
        coalition = Coalition.ToNumber(validCoalition)
    end
    if not isTable(color) then
        color = {1,1,1}
    end
    if not isTable(lineColor) then
        lineColor = {0,0,0}
    end
    if isBoolean(text) and text then
        text = self.Name
    end
    if not isNumber(size) then
        size = 2000
    end
    if not self:IsEmitter() then
        local outerSize = .5
        local innerSize = .15
        local coordN = self.Coordinate:Translate(size * outerSize, 0)
        local lineAlpha = 1
        local alpha = .4
        local lineType = 1      -- solid
        local readOnly = true   -- is read only (cannot be removed by user)
        local form = {
            self.Coordinate:Translate(size * innerSize, 45),
            self.Coordinate:Translate(size * outerSize, 90),
            self.Coordinate:Translate(size * innerSize, 135),
            self.Coordinate:Translate(size * outerSize, 180),
            self.Coordinate:Translate(size * innerSize, 225),
            self.Coordinate:Translate(size * outerSize, 270),
            self.Coordinate:Translate(size * innerSize, 315),
            coordN
        }
        coordN:MarkupToAllFreeForm(form, coalition, lineColor, lineAlpha, color, alpha, lineType, readOnly)
    end
    -- self.Coordinate:CircleToAll(size, coalition, color, nil, color, .5, 0, true, self.Name)
    if isAssignedString(text) then
        local coordText = self.Coordinate:Translate(size*.5 + 1000, 180)
        -- coordText = coordText:Translate(size*.5, 270)
        coordText:TextToAll(self.Name, coalition, color, nil, nil, 0, 10)
    end
end

function DCAF.AIRAC:DrawNavaids(map, coalition, text, color, size)
    if not isAssignedString(map) then
        error("DCAF.AIRAC:DrawNavaids :: `map` must be assigned string but was: " .. DumpPretty(map)) end

    if not DCSMAP:IsValid(map) then
        error("DCAF.AIRAC:DrawNavaids :: unknown `map`: " .. map) end

    if not isBoolean(text) then
        text = true 
    end
    for name, navaid in pairs(DCAF.AIRAC.NAVAIDS) do
        if navaid.Map == map then
            navaid:Draw(coalition, text, color, size)
        end
    end
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                        AIR ROUTES 
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


local DCAF_ROUTE_COUNT = 1

function DCAF.AIR_ROUTE_OPTIONS:OnArrival(func)
    if not isFunction(func) then
        error("DCAF.AIR_ROUTE_OPTIONS:OnArrival :: `func` must be functon, but was " .. type(func)) end

    self.OnArrivalFunc = func
end

local function getGroupMaxSpeed(group)
    local lowest = 99999
    for _, unit in ipairs(group:GetUnits()) do
        lowest = math.min(lowest, unit:GetSpeedMax())
    end
    return lowest
end

local function genericRouteName()
    return "ROUTE-" .. Dump(DCAF_ROUTE_COUNT)
end

function DCAF.AIR_ROUTE:New(name, route, phase, proc)
    if not isAssignedString(route) then
        error("DCAF.ROUTE:New :: `route` must be assigned string") end

    local idents = {}
    for ident in route:gmatch("%S+") do
        table.insert(idents, ident)
    end
-- nisse --
Debug("DCAF.AIR_ROUTE:New :: name: " .. name .." :: idents: " .. DumpPretty(idents))
    local airRoute = DCAF.AIR_ROUTE:NewFromNavaids(name, idents, phase, proc)
    airRoute.RouteText = route
    return airRoute
end

function DCAF.AIR_ROUTE:GetDepartureInfo()
    return DCAF.AIRAC:GetDepartureInfo(self)
end

function DCAF.AIR_ROUTE:GetArrivalInfo()
    return DCAF.AIRAC:GetArrivalInfo(self)
end

function DCAF.AIR_ROUTE:GetDepartureController()
    return DCAF.AIRAC:GetDepartureController(self)
end

function DCAF.AIR_ROUTE:GetArrivalController()
    return DCAF.AIRAC:GetArrivalController(self)
end

function DCAF.AIR_ROUTE:IsLockedForArrivals()
    local controller = self:GetArrivalController()
    if controller then
        return controller:IsLockedForArrivals()
    end
end

function DCAF.AIR_ROUTE:GetArrivalProcedure(runwayName, procedureName)
    -- TODO Consider including aircraft size/speed category when selecting arrival procedures (eg. "LTAF ILS RWY 05 (ADA1)" and "LTAF ILS RWY 05 (ADA1)" are for different speed categories)
    local info = self:GetArrivalInfo()
    if not info then
        return Warning("DCAF.AIR_ROUTE:GetArrivalProcedure :: route " .. self.Name .. " cannot resolve airdrome arrival information :: EXITS") end

    if #info.ArrivalProcedures == 0 then
        return Warning("DCAF.AIR_ROUTE:GetArrivalProcedure :: route " .. self.Name .. " has no registered arrivals :: EXITS") end

    if not procedureName then
        -- procedure not specified - procedure that matches runway and is closest to first turnpoint...
        local wpRouteEnd = self.Waypoints[#self.Waypoints]
        local coord = COORDINATE_FromWaypoint(wpRouteEnd)
        local distClosest = 99999
        local arrivalClosest
        for i, arrival in ipairs(info.ArrivalProcedures) do
            for j, rwy in ipairs(arrival.Runways) do
                if rwy == runwayName then
                    local wpArrivalStart = arrival.Waypoints[1]
                    local coordArrival = COORDINATE_FromWaypoint(wpArrivalStart)
                    local dist = UTILS.MetersToNM(coord:Get2DDistance(coordArrival))
                    if dist < distClosest then
                        distClosest = dist
                        arrivalClosest = arrival
                    end
                end
            end
        end
        return arrivalClosest
    end

    -- arrival procedure was specified - just look it up...
    for i, arrival in ipairs(info.ArrivalProcedures) do
        if arrival.Name == procedureName then
            for j, rwy in ipairs(arrival.Runways) do
                if rwy == runwayName then
                    return arrival
                end
            end
        end
    end
end

function DCAF.AIR_ROUTE:GetDepartureProcedure(runwayName, procedureName)
    local info = self:GetDepartureInfo()
    if not info then
        return Warning("DCAF.AIR_ROUTE:GetDepartureProcedure :: route " .. self.Name .. " has no airdrome departure information :: EXITS") end

    if #info.DepartureProcedures == 0 then
        return Warning("DCAF.AIR_ROUTE:GetDepartureProcedure :: route " .. self.Name .. " has no registered departures :: EXITS") end
    
    if not procedureName then
        -- procedure not specified - procedure that matches runway and is closest to first turnpoint...
        local wpRouteStart = self.Waypoints[2]
        local coord = COORDINATE_FromWaypoint(wpRouteStart)
        local distClosest = 99999
        local departureClosest
        for i, departure in ipairs(info.DepartureProcedures) do
Debug("DCAF.AIR_ROUTE:GetDepartureProcedure :: route: " .. self.Name .." :: departure: " .. departure.Name)            
            for j, rwy in ipairs(departure.Runways) do
                if rwy == runwayName then
                    local wpDepartureEnd = departure.Waypoints[#departure.Waypoints]
                    local coordDeparture = COORDINATE_FromWaypoint(wpDepartureEnd)
                    local dist = UTILS.MetersToNM(coord:Get2DDistance(coordDeparture))
Debug("DCAF.AIR_ROUTE:GetDepartureProcedure :: dist: " .. dist)
                    if dist < distClosest then
                        distClosest = dist
                        departureClosest = departure
                    end
                end
            end
        end
Debug("DCAF.AIR_ROUTE:GetDepartureProcedure :: departureClosest: " .. departureClosest.Name)
        return departureClosest
    end

    -- departure procedure was specified - just look it up...
    for i, departure in ipairs(info.DepartureProcedures) do
        if departure.Name == procedureName then
            for j, rwy in ipairs(departure.Runways) do
                if rwy == runwayName then
                    return departure
                end
            end
        end
    end
end

function DCAF.AIR_ROUTE:UseArrival(runwayName, procedureName)
    if not runwayName then
        runwayName = self:GetArrivalInfo():GetActiveRunwayLanding()
        if not runwayName then
            Warning("DCAF.AIR_ROUTE:UseArrival :: route: " .. self.Name .. " :: cannot resolve active RWY :: IGNORES")
            return self
        end
    end
    local arrival = self:GetArrivalProcedure(runwayName, procedureName)
    if not arrival then
        Warning("DCAF.AIR_ROUTE:UseArrival :: route: " .. self.Name .. " :: unknown arrival procedure: '" .. Dump(procedureName))
        return self
    end

    -- replace arrival (last) waypoint with waypoints from procedure...
    local waypoints = {}
        for i = 1, #self.Waypoints-1, 1 do
        table.insert(waypoints, self.Waypoints[i])
    end
    for i, wp in ipairs(arrival.Waypoints) do
        if i == 1 then
            -- name arrival waypoint (clarifies on F10 map) ...
            wp = DCAF.clone(wp)
            if wp.name then
                wp.name = wp.name .. " / " .. arrival.Name
            else
                wp.name = arrival.Name
            end
        end
        table.insert(waypoints, wp)
    end
    local clone = DCAF.clone(self)
    clone.Waypoints = waypoints
    clone.HasArrival = true
    clone.MissedApproachRoute = arrival.MissedApproachRoute
    return clone
end

function DCAF.AIR_ROUTE:UseDeparture(runwayName, procedureName)
    if not runwayName then
        local info = self:GetDepartureInfo()
        if not info then
            return Warning("DCAF.AIR_ROUTE:UseDeparture :: cannot resolve departure information :: IGNORES") end

        runwayName = info:GetActiveRunwayTakeoff()
        if not runwayName then
            Warning("DCAF.AIR_ROUTE:UseDeparture :: route: " .. self.Name .. " :: cannot resolve active RWY :: IGNORES") 
            return self
        end
    end
    local departure = self:GetDepartureProcedure(runwayName, procedureName)
    if not departure then
        Warning("DCAF.AIR_ROUTE:UseDeparture :: route: " .. self.Name .. " :: unknown departure procedure: " .. Dump(procedureName)) 
        return self
    end

    -- replace airdrome (first) waypoint with waypoints from procedure...
    local waypoints = {}
    for i, wp in ipairs(departure.Waypoints) do
        table.insert(waypoints, wp)
    end
    for i = 2, #self.Waypoints, 1 do
        table.insert(waypoints, self.Waypoints[i])
    end
    local clone = DCAF.clone(self)
    clone.Waypoints = waypoints
    clone.HasDeparture = true
    return clone
end

function DCAF.AIR_ROUTE:NewDeparture(name, runways, route)
    if isAssignedString(runways) then
        runways = { runways }
    end
    if not isList(runways) then
        error("DCAF.AIR_ROUTE:NewDeparture :: `runways` must be an assigned string (RWY name) or a list of strings, but was: " .. DumpPretty(runways)) end

    local r = DCAF.AIR_ROUTE:New(name, route, DCAF.AIR_ROUTE_PHASE.Takeoff, DCAF.AIR_ROUTE_PHASE.SID)
    r.Runways = runways
    return r
end

function DCAF.AIR_ROUTE:NewArrival(name, runways, route, routeMissedApproach)
    if isAssignedString(runways) then
        runways = { runways }
    end
    if not isList(runways) then
        error("DCAF.AIR_ROUTE:NewDeparture :: `runways` must be an assigned string (RWY name) or a list of strings, but was: " .. DumpPretty(runways)) end

    local r = DCAF.AIR_ROUTE:New(name, route, DCAF.AIR_ROUTE_PHASE.Land, DCAF.AIR_ROUTE_PHASE.STAR)
    r.Runways = runways
Debug("nisse - DCAF.AIR_ROUTE:NewArrival :: " .. name .. " :: routeMissedApproach: " .. Dump(routeMissedApproach))
    if isAssignedString(routeMissedApproach) then
        r.MissedApproachRoute = DCAF.AIR_ROUTE:New("MISSED APPROACH - " .. name, routeMissedApproach, DCAF.AIR_ROUTE_PHASE.Missed, DCAF.AIR_ROUTE_PHASE.STAR)

Debug("nisse - DCAF.AIR_ROUTE:NewArrival :: " .. name .. " :: has #route: " .. #r.Waypoints, 1)
for i, wp in ipairs(r.Waypoints) do   
Debug("nisse - DCAF.AIR_ROUTE:NewArrival :: " .. name .. " :: wp#" .. i .. ": " .. DumpPretty({ name = wp.name, proc = wp.proc }))
end        
    end
    return r
end

function DCAF.AIR_ROUTE:NewFromWaypoints(name, waypoints)
    if not isAssignedString(name) then
        name = genericRouteName()
    end
    if not isTable(waypoints) then
        error("DCAF.AIR_ROUTE:NewFromWaypoints :: `waypoints` must be table but was: " .. type(waypoints)) end

    local route = DCAF.clone(DCAF.AIR_ROUTE)
    route.Name = name
    route.Waypoints = waypoints
    DCAF_ROUTE_COUNT = DCAF_ROUTE_COUNT+1
    return route
end

--- overrides to support passing DCAF.AIR_ROUTE as `route`
function DCAF.Tanker:Route(route)
    if isClass(route, DCAF.AIR_ROUTE.ClassName) then
        route = route.Waypoints
    elseif not isTable(route) then
        error("DCAF.Tanker:Route :: `route` must be a table but was " .. type(route)) end
        
    setGroupRoute(self.Group, route)
    -- self.Route = route
    -- self.Group:Route(route)
    return self
end

--- overrides to support passing DCAF.AIR_ROUTE as `route`
function DCAF.AWACS:Route(route)
    if isClass(route, DCAF.AIR_ROUTE.ClassName) then
        route = route.Waypoints
    elseif not isTable(route) then
        error("DCAF.AWACS:Route :: `route` must be a table but was " .. type(route)) end
       
    setGroupRoute(self.Group, route)
    -- self.Route = route
    -- self.Group:Route(route)
    return self
end

function DCAF.AIR_ROUTE_SPAWNMETHOD:IsAny(value)
    for _, v in pairs(DCAF.AIR_ROUTE_SPAWNMETHOD) do
        if value == v then
            return v
        end
    end
end

function DCAF.AIR_ROUTE_SPAWNMETHOD:ResolveMOOSETakeoff(value)
    if value == DCAF.AIR_ROUTE_SPAWNMETHOD.Cold then
        return SPAWN.Takeoff.Cold

    elseif DCAF.AIR_ROUTE_SPAWNMETHOD.Hot then
        return SPAWN.Takeoff.Hot

    elseif DCAF.AIR_ROUTE_SPAWNMETHOD.Runway then
        return SPAWN.Takeoff.Runway

    elseif DCAF.AIR_ROUTE_SPAWNMETHOD.Air then
        return SPAWN.Takeoff.Air

    else
        error("DCAF.AIR_ROUTE_SPAWNMETHOD:ResolveMOOSETakeoff :: cannot resolve value: " .. DumpPretty(value))

    end
end

AIRAC_IDENT = {
    ClassName = "AIRAC_IDENT",
    Name = nil,
    SpeedKt = nil,
    AltFt = nil,
    -- if ident is a reference to a navaid with radial and distance...
    -- format : <navaid name>:<radial (degrees), 33 charaters><distance (nm)>
    -- example: SUP-R02519  (navaid = "SUP", 25 degrees, 19 nautical miles)
    NavaidName = nil,       -- #string - name of VOR/TACAN
    Radial = nil,           -- #number - radial from navaid
    Distance = nil,         -- #number - distance from navaid
    Coordinate = nil        -- #COORDINATE
}

local prevIdent

--- Supported formats:
---   <ident>['/'<altitude>]
---   <ident> := <alphanumeric characters>     (eg. RONKY)
---   <ident> := <alphanumeric characters>'-R'<radial; 3 char><distance; 2 char>   (eg. SUP-R02519)
---   <altitude> := 'F'<numeric>  (eg. F250; flight level 250)
---   <altitude> := 'A'<numeric>  (eg. A250; flight level 250)
function AIRAC_IDENT:New(s)
    local arcQualifier = "arc%("
-- local nisse_debug = string.find(s, arcQualifier)
-- if nisse_debug then
-- Debug("nisse_debug - AIRAC_IDENT:New :: s: '" .. s .. "'")
-- end

    if not isAssignedString(s) then
        error("IDENT:New :: `s` must be assigned string but was: " .. DumpPretty(s)) end

    local items = {}
    for e in s:gmatch('[^/]+') do
        table.insert(items, e)
    end

-- if nisse_debug then
-- Debug("nisse_debug - AIRAC_IDENT:New :: items: '" .. DumpPretty(items))
-- end    

    local function eatNum(s, start)
        -- local starts, ends = string.find(s, "%d+")
        local starts, len = string.find(s, "%d+%.?%d*")
        if starts == nil then
            return end

        local subNum = string.sub(s, starts, len)
        -- local num = tonumber(string.sub(s, starts, ends))
        local num = tonumber(subNum)
        return num, len+1
    end

    local function isArc(ident)
        -- format: (arc <ident> <distance> <radial-start> <radial-end>)
        --     eg: (arc LCA 12 119 202) 
        local x = string.find(ident.Name, arcQualifier)
        if not x then
            return end

        local y = string.find(ident.Name, ")")
        if not y then
            return end

        x = x + string.len(arcQualifier)-1
        local aSrc = string.sub(ident.Name, x, y-1)
        local itemsArc = {}
        for e in aSrc:gmatch('[^,]+') do
            table.insert(itemsArc, e)
        end
        -- todo consider supporting speed and altitude items for arcs
        if #itemsArc < 4 then
            error("AIRAC_IDENT:New :: invalid arc in " .. s .. ": " .. ident.Name) end

        ident.ArcIdent = itemsArc[1]
        local n = tonumber(itemsArc[2])
        n = tonumber(itemsArc[2])
        if not n then
            error("AIRAC_IDENT:New :: invalid distance in arc, in " .. s .. ": " .. ident.Name) end
        ident.ArcDistance = NauticalMiles(math.floor(n))
        n = tonumber(itemsArc[3])
        if not n then
            error("AIRAC_IDENT:New :: invalid start radial in arc, in " .. s .. ": " .. ident.Name) end
        ident.ArcRadialStart = math.floor(n)
        n = tonumber(itemsArc[4])
        if not n then
            error("AIRAC_IDENT:New :: invalid end radial in arc, in " .. s .. ": " .. ident.Name) end
        ident.ArcRadialEnd = math.floor(n)
        if #itemsArc >= 5 then
            -- speed (knots)...
            n = tonumber(itemsArc[5])
            if not n then
                error("AIRAC_IDENT:New :: invalid speed in arc, in " .. s .. ": " .. ident.Name) end
            ident.ArcSpeed = UTILS.KnotsToKmph(math.floor(n))
        end
        if #itemsArc >= 6 then
            -- altitude (feet)...
            n = tonumber(itemsArc[6])
            if not n then
                error("AIRAC_IDENT:New :: invalid altitude in arc, in " .. s .. ": " .. ident.Name) end
            ident.ArcAltitude = UTILS.FeetToMeters(math.floor(n))
        end
        return ident
    end

    local function parseTurn(ident)
        if ident.Name == 'rtl()' then
            ident.IsReverseTurn = true
            ident.LeftTurn = true
        elseif ident.Name == 'rtr()' then
            ident.IsReverseTurn = true
            ident.LeftTurn = nil
        -- elseif ident.Name == "(hold)" then
        --     ident.IsHold = true
        elseif isArc(ident) then
            ident.IsArc = true
        end
        return ident
    end

    local function parse(ident)
        -- test navaid radial/distance...
        local radialAt = string.find(ident.Name, '-R')
        if not radialAt then 
            return parseTurn(ident)
        end
        local navaidName = string.sub(ident.Name, 1, radialAt-1)
        local sRadial = string.sub(ident.Name, radialAt+2)
        if string.len(sRadial) < 5 then
            return parseTurn(ident)
        end
        local sDistance = string.sub(sRadial, 4)
        sRadial = string.sub(sRadial, 1, 3)
        ident.NavaidName = navaidName 
        ident.Radial = tonumber(sRadial)
if nisse_debug then
Debug("nisse - parse :: ident.Name: '" .. ident.Name .. "' :: sDistance: " .. Dump(sDistance))
end
        ident.Distance = eatNum(sDistance) --tonumber(sDistance)
        if not ident.Radial or not ident.Distance then
            error("AIRAC_IDENT:New :: invalid radial identifier: " .. ident.Name .. " :: expected format: <ident>-R<radial (3 char)><distance (nm)>") end

        local navaid = DCAF.AIRAC.NAVAIDS[ident.NavaidName]
        if not navaid then
            error("AIRAC_IDENT:New :: unknown navaid: '" .. ident.NavaidName .. "'") end

        local coord = navaid.Coordinate
        ident.Coordinate = coord:Translate(NauticalMiles(ident.Distance), ident.Radial)
        return ident
    end

    -- format: for second item (after '/') is [<speed>][<altitude>]
    --         speed can be stated as 'N'<num> for knots, or 'M'<num> for Mach (eg. N250 for 250 knots, or M05, for Mach 0.5)
    --         altitude can be given as 'F'<num> for flight level, or 'S'<num> for (standard) meters*10 (eg. F180, for 18000 feet, or S100 for 1000 meters)

    -- examples:
    --     MESLO/F160 ALCRO/M100
    --
    -- https://wiki.ivao.aero/en/home/training/documentation/VFR_flight_plan_basics#cruising-speed-maximum-5-characters-field-15
    local ident = DCAF.clone(AIRAC_IDENT)
    ident.Name = items[1]
    ident = parse(ident)
    if #items == 1 then
        return ident end
    
    local item = items[2]
    local speedKt, alt, altUnit
    local qualifier = string.sub(item, 1, 1)
    if qualifier == 'N' then
        -- speed in knots...
        local kt, next = eatNum(item, 2)
        item = string.sub(item, next)
        ident.SpeedKt = kt
    elseif qualifier == 'M' then
        -- speed in MACH...
        local m, next = eatNum(item, 2)
        ident.SpeedKt = MachToKnots(m/100)
        item = string.sub(item, next)
    end
    if string.len(item) == 0 then
        return ident end

    qualifier = string.sub(item, 1, 1)
    if qualifier == 'F' --[[or qualifier == 'A']] then
        -- altitude in Flight level (feet / 100)...
        local ft, next = eatNum(item, 2)
        ident.AltFt = ft * 100
        item = string.sub(item, next)
    elseif qualifier == 'S' --[[or qualifier == 'M']] then
        -- altitude in standard metric (meters / 10)...
        local m, next = eatNum(item, 2)
        ident.AltFt = UTILS.MetersToFeet(m * 10)
        item = string.sub(item, next)
    end
    prevIdent = ident
    return ident
end

function AIRAC_IDENT:AirTurnpoint(speedKmph, altitudeMeters, tasks)
    if not isNumber(speedKmph) and isNumber(self.SpeedKt) then
        speedKmph = Knots(self.SpeedKt) end

    if not isNumber(altitudeMeters) and isNumber(self.AltFt) then
        altitudeMeters = Feet(self.AltFt) end

    return airTurnpoint(self.Coordinate, self.Name, speedKmph, altitudeMeters)
end

function AIRAC_IDENT:IsRestricted()
    return isNumber(self.AltFt) or isNumber(self.SpeedKt)
end

function DCAF.AIR_ROUTE:NewFromNavaids(name, idents, phase, proc)
    if not isAssignedString(name) then
        name = genericRouteName()
    end
    if not isTable(idents) then
        error("DCAF.AIR_ROUTE:NewFromNavaids :: `idents` must be table (list of navaid identifiers)") end

    local departureAirbase, arrivalAirbase
    local departureAirbaseInfo, arrivalAirbaseInfo
    local airbaseInfo

    local function makeRouteWaypoint(waypoint, index)
        local phase = phase or DCAF.AIR_ROUTE_PHASE.Enroute
        if isClass(waypoint, AIRAC_IDENT.ClassName) and waypoint.Coordinate then
            waypoint = waypoint:AirTurnpoint()
        elseif isClass(waypoint, DCAF.NAVAID.ClassName) then
            waypoint = waypoint:AirTurnpoint()
        elseif isAirbase(waypoint) then
            local airbase = waypoint
            local coord = airbase:GetCoordinate()
            if index == 1 then
                departureAirbase = airbase
                departureAirbaseInfo = airbaseInfo
                local departureWP = coord:WaypointAirTakeOffParkingHot(COORDINATE.WaypointAltType.BARO) -- todo consider ability to configure type of takeoff
                departureWP.airdromeId = airbase:GetID()
                waypoint =  departureWP
                waypoint.name = departureAirbaseInfo.ICAO
                phase = DCAF.AIR_ROUTE_PHASE.Takeoff
            else
                waypoint = coord:WaypointAirLanding(250, airbase, nil, DCAF.AIRAC:GetAirbaseICAO(airbase))
                waypoint.speed = 70
                waypoint.name = airbaseInfo.ICAO
                phase = DCAF.AIR_ROUTE_PHASE.Land
                arrivalAirbase = airbase
                arrivalAirbaseInfo = airbaseInfo
            end
        else
            error("DCAF.AIR_ROUTE:New :: arg[" .. Dump(index) .. "] was not type " .. DCAF.NAVAID.ClassName .. " or " .. AIRBASE.ClassName)
        end
        waypoint[CONSTANTS.RouteProcedure] = phase
        waypoint[CONSTANTS.RouteProcedureName] = proc
        return waypoint
    end

    local function generateArcsAndTurns(route)
        local prevWP
        local waypoints = {}
        local countTurnsAndArcs = 0
        local proc
        for i = 1, #route.Waypoints, 1 do
            local wp = route.Waypoints[i]
            if wp[CONSTANTS.RouteProcedure] then
                proc = wp[CONSTANTS.RouteProcedure]
            end
            if not isClass(wp, AIRAC_IDENT) then
                table.insert(waypoints, wp)
            elseif wp.IsArc then
Debug("nisse - generateArcsAndTurns ::wp:" .. DumpPretty(wp))                
                local location = DCAF.AIRAC:GetLocation(wp.ArcIdent)
                local coordinates = getArcCoordinates(location, wp.ArcDistance, wp.ArcRadialStart, wp.ArcRadialEnd)
                local speed = wp.ArcSpeed
                if not speed and prevWP then
                    speed = prevWP.speed
                end
                local alt = wp.ArcAltitude
                if not alt and prevWP then
                    alt = prevWP.alt
                end
                for _, coord in ipairs(coordinates) do
                    wp = airTurnpoint(coord, nil, speed, alt)
                    wp[CONSTANTS.RouteProcedure] = proc
                    table.insert(waypoints, wp)
                end
                countTurnsAndArcs = countTurnsAndArcs + 1
            elseif wp.IsReverseTurn then
                if not prevWP then
                    error("DCAF.AIR_ROUTE:NewFromNavaids :: waypoint #" .. i .. " is Reverse turn/Arc but does not succeed another waypoint")
                end
                if i == #route.Waypoints then
                    error("DCAF.AIR_ROUTE:NewFromNavaids :: waypoint #" .. i .. " is Reverse turn/Arc but does not preceed another waypoint")
                end
                local coordStart = COORDINATE_FromWaypoint(prevWP)
                local coordEnd = COORDINATE_FromWaypoint(route.Waypoints[i+1])
                local coordinates = getReversedTurnCoordinates(coordStart, not wp.LeftTurn, coordEnd)
                for _, coord in ipairs(coordinates) do
                    wp = airTurnpoint(coord, nil, prevWP.speed, prevWP.alt)
                    wp[CONSTANTS.RouteProcedure] = proc
                    table.insert(waypoints, wp)
                end
                countTurnsAndArcs = countTurnsAndArcs + 1
            else
                error("DCAF.AIR_ROUTE:NewFromNavaids :: waypoint #" .. i .. " is #AIRAC_IDENT but neither Reverse, turn, Hold nor Arc")
            end
            prevWP = wp
        end
        if countTurnsAndArcs > 0 then
            route.Waypoints = waypoints
        end
    end

    local route = DCAF.clone(DCAF.AIR_ROUTE)

    local firstIdent = 1
    local spawnMethod = DCAF.AIR_ROUTE_SPAWNMETHOD.Air
    local ignore = false
    local lastAlt
    for i = 1, #idents, 1 do
        local sIdent = idents[i]
        local waypoint
        if isAssignedString(sIdent) then
            local ident = AIRAC_IDENT:New(sIdent)
            if not ident then
                error("Route ident #" .. Dump(i) .. " is invalid: '" .. Dump(sIdent) .. "'") end

            if ident.IsArc or ident.IsReverseTurn then
                -- this will yield multiple waypoints...
                table.insert(route.Waypoints, ident)
                ignore = true
            else
                local navaid = DCAF.AIRAC.NAVAIDS[ident.Name]
                if not navaid and ident.Radial then
                    -- NAVAID radial/distance identifier...
                    navaid = ident
                end
                if not navaid then
                    if i == firstIdent or i == #idents then
                        if DCAF.AIR_ROUTE_SPAWNMETHOD:IsAny(idents[i]) then
                            spawnMethod = idents[i]
                            firstIdent = firstIdent+1
                            ignore = true
                        else
                            airbaseInfo = DCAF.AIRAC.ICAO[ident.Name]
                            if not airbaseInfo then
                                return error("DCAF.AIR_ROUTE:New :: idents[" .. Dump(i) .. "] was unknown AIRDROME/NAVAID: '" .. sIdent .. "'")  end

                            local airbaseName = airbaseInfo.Name
                            if not ignore and airbaseName then
                                local airbase = AIRBASE:FindByName(airbaseName)
                                if airbase then
                                    waypoint = airbase
                                end
                            end
                        end
                    end
                elseif ident:IsRestricted() then
                    -- Fix/Navaid in route specifies SPEED / ALT restriction; clone it and add same restrictions...
                    waypoint = DCAF.clone(navaid)
                    waypoint.AltFt = ident.AltFt
                    waypoint.SpeedKt = ident.SpeedKt
                else
                    waypoint = navaid
                end
                if not ignore and not waypoint then
                    error("DCAF.AIR_ROUTE:New :: idents[" .. Dump(i) .. "] was unknown NAVAID: '" .. sIdent .. "'") end
            end
        end
        if not ignore and not isClass(waypoint, AIRAC_IDENT.ClassName) and not isClass(waypoint, DCAF.NAVAID.ClassName) and not isClass(waypoint, AIRBASE.ClassName) then
            error("DCAF.AIR_ROUTE:New :: idents[" .. Dump(i) .. "] ('" .. Dump(sIdent) .. "') was neither type " .. AIRAC_IDENT.ClassName .. ", " .. DCAF.NAVAID.ClassName .. ", nor " .. AIRBASE.ClassName) end

        if not ignore then
            local wp = makeRouteWaypoint(waypoint, i)
            if not wp.alt then
                wp.alt = lastAlt
            end
            lastAlt = wp.alt
            table.insert(route.Waypoints, wp)
        end
        ignore = false
    end

    route.Name = name
    route.DepartureAirbase = departureAirbase
    if departureAirbaseInfo then
        route.DepartureICAO = departureAirbaseInfo.ICAO
    end
    route.ArrivalAirbase = arrivalAirbase
    if arrivalAirbaseInfo then
        route.ArrivalICAO = arrivalAirbaseInfo.ICAO
    end
    route.Takeoff = DCAF.AIR_ROUTE_SPAWNMETHOD:ResolveMOOSETakeoff(spawnMethod)
    route.Phase = phase
    route.Proc = proc
    generateArcsAndTurns(route)
    DCAF_ROUTE_COUNT = DCAF_ROUTE_COUNT+1
    return route
end

function DCAF.AIR_ROUTE:Clone()
    local route = DCAF.clone(self)
    return route
end

function DCAF.AIR_ROUTE:CloneReversed(name)
    if not isAssignedString(name) then
        name = genericRouteName()
    end
    local idents = {}
    for ident in self.RouteText:gmatch("%S+") do 
        table.insert(idents, ident) 
    end
    local revRouteText = idents[#idents]
    for i = #idents-1, 1, -1 do
        revRouteText = revRouteText .. " " .. idents[i]
    end
    return DCAF.AIR_ROUTE:New(name, revRouteText)
end

function DCAF.AIR_ROUTE:WithCruiseAltitude(altitudeFeet)
    self.CruiseAltitudeFeet = altitudeFeet
    if not isNumber(altitudeFeet) then
        error("DCAF.AIR_ROUTE:WithAltutide :: `altitudeMeters` must be a number but was: " .. DumpPretty(altitudeFeet)) end
    if #self.Waypoints == 0 then
        error("DCAF.AIR_ROUTE:WithAltutide :: route '" .. self.Name .. "' contains no waypoints") end

    for _, wp in ipairs(self.Waypoints) do
        wp.alt = altitudeFeet
    end
    return self 
end

function DCAF.AIR_ROUTE:WithCruiseSpeed(speedKnots)
    self.CruiseSpeedKnots = speedKnots
    if not isNumber(speedKnots) then
        error("DCAF.AIR_ROUTE:WithSpeed :: `speedKmph` must be a number but was: " .. DumpPretty(speedKnots)) end
    if #self.Waypoints == 0 then
        error("DCAF.AIR_ROUTE:WithSpeed :: route '" .. self.Name .. "' contains no waypoints") end

    for _, wp in ipairs(self.Waypoints) do
        wp.speed = Knots(speedKnots)
    end
    return self 
end

local function setCruiseParameters(waypoints, cruiseSpeedKnots, cruiseAltitudeFeet)
    local function set(wp, speedKnots, altitudeFeet)
        if not wp._isAltitudeLocked and (wp[CONSTANTS.RouteProcedure] == DCAF.AIR_ROUTE_PHASE.Enroute or wp.alt == nil or wp.alt == 0) then
            wp.alt = Feet(altitudeFeet)
        end
        if not wp._isSpeedLocked and (wp[CONSTANTS.RouteProcedure] == DCAF.AIR_ROUTE_PHASE.Enroute or wp.speed == nil or wp.speed == 0) then
            wp.speed = Knots(speedKnots)
        end
    end

    local firstWP = waypoints[1]
    set(firstWP, cruiseSpeedKnots, cruiseAltitudeFeet)
    local prevCoord = COORDINATE_FromWaypoint(firstWP)
    for i = 2, #waypoints, 1 do
        local altitude = cruiseAltitudeFeet or 30000
        -- local speed = cruiseSpeedKnots obsolete
        local wp = waypoints[i]
        local coord = COORDINATE_FromWaypoint(wp)
        local heading = prevCoord:GetHeadingTo(coord)
        -- correct cruise altitude for heading...
        if heading > 180 then
            if altitude % 2 ~= 0 then
                -- change to even altitude
                altitude = altitude - 1000
            end
        else
            if altitude % 2 == 0 then
                -- change to uneven altitude
                altitude = altitude + 1000
            end
        end
        set(wp, cruiseSpeedKnots, altitude)
        prevCoord = coord
    end
end

function DCAF.AIR_ROUTE_OPTIONS:New(cruiseSpeedKt, cruiseAltitudeFt, sid, star)
    local options = DCAF.clone(DCAF.AIR_ROUTE_OPTIONS)
    if cruiseSpeedKt ~= nil and not isNumber(cruiseSpeedKt) then
        error("DCAF.AIR_ROUTE_OPTIONS:New :: `cruiseSpeedKt` must be a number (knots)") end
    if cruiseAltitudeFt ~= nil and not isNumber(cruiseAltitudeFt) then
        error("DCAF.AIR_ROUTE_OPTIONS:New :: `cruiseAltitudeFt` must be a number (feet)") end
    if sid ~= nil and not isBoolean(sid) and not isAssignedString(sid) then
        error("DCAF.AIR_ROUTE_OPTIONS:New :: `sid` must be a boolean (true to auto assign SID) or a string (name of SID)") end
    if sid ~= nil and not isBoolean(star) and not isAssignedString(star) then
        error("DCAF.AIR_ROUTE_OPTIONS:New :: `star` must be a boolean (true to auto assign STAR) or a string (name of STAR)") end
                
    if isNumber(cruiseSpeedKt) then
        options.CruiseSpeedKnots = cruiseSpeedKt
    end
    if isNumber(cruiseAltitudeFt) then
        options.CruiseAltitudeFeet = cruiseAltitudeFt
    end
    if sid ~= nil then
        options.SID = sid or DCAF.AIR_ROUTE_OPTIONS.SID
    else
        options.SID = DCAF.AIR_ROUTE_OPTIONS.SID
    end
    if star ~= nil then
        options.STAR = star
    else
        options.STAR = DCAF.AIR_ROUTE_OPTIONS.STAR
    end
    return options
end

local function alignCoalitionWithDestination(spawn, route)
    if not route.ArrivalAirbase then
        return end

    local destinationCoalition = route.ArrivalAirbase:GetCoalition()
    local destinationCountry = DCAF.AIRAC:GetCountry(route.ArrivalAirbase)
    spawn:InitCountry(destinationCountry)
    spawn:InitCoalition(destinationCoalition)
    return destinationCoalition
end

local function destroyOnLastTurnpoint(group, waypoint)
    -- destroy group if last WP is en-route (retain if landing at airport)
    if waypoint.type ~= "Turning Point" then
        return end

    local coordWP = COORDINATE_FromWaypoint(waypoint)
    local coordGP = group:GetCoordinate()
    local distance = coordGP:Get2DDistance(coordWP)
    local speed = waypoint.speed
    local time = distance / speed;
    Delay(time, function()
        group:Destroy()
    end)
end

local function onRouteEnd(waypoints, func)
    local lastWP = waypoints[#waypoints]
    local callback
    callback = AIR_ROUTE_CALLBACK_INFO:New(function()
        func(lastWP)
        callback:Remove()
    end)
    InsertWaypointAction(lastWP, ScriptAction("DCAF.AIR_ROUTE:Callback(" .. Dump(callback.Id) .. ")"))
end

local function fileFlightplan(route)
    if route.ArrivalAirbase then
        route:GetArrivalController():FileFlightplan(route)
    end
end

function DCAF.AIR_ROUTE:Fly(controllable, options)
    if isAssignedString(controllable) then
        local spawn = getSpawn(controllable)
        if spawn then 
            controllable = spawn
        end
    end

    if not isClass(controllable, GROUP.ClassName) and not isClass(controllable, SPAWN.ClassName) then
        error("DCAF.AIR_ROUTE:Fly :: `controllable` must be string, or types: " .. GROUP.ClassName .. ", " .. SPAWN.ClassName .. " but was " .. type(controllable)) end
        
    if #self.Waypoints == 0 then
        error("DCAF.AIR_ROUTE:Fly :: route is empty (no waypoints)") end
    
    if not isClass(options, DCAF.AIR_ROUTE_OPTIONS.ClassName) then
        options = DCAF.AIR_ROUTE_OPTIONS:New()
    end

    local cruiseAltitudeFeet = options.CruiseAltitudeFeet or 30000
    if cruiseAltitudeFeet == 0 then
        cruiseAltitudeFeet = self.CruiseAltitudeFeetFeet or 30000
        -- todo consider optimizing cruise altitude depending on distance
    end
    local cruiseSpeedKnots = options.CruiseSpeedKnots
    if cruiseSpeedKnots == 0 then
        cruiseSpeedKnots = Knots(self.CruiseSpeedKnots) or getGroupMaxSpeed(self.Group) * .8
    end

    -- clone AIR_ROUTE and set speeds and altitudes ...
    local route = self:Clone()

    -- make AI-invisible if configured for it...
    local function makeInvisible(route)
        local groupCoalition = route.Group:GetCoalition()
        local country = route.Group:GetCountry()
        if options.InvisibleToHostileAI and groupCoalition ~= coalition.side.NEUTRAL then
            Trace("DCAF.AIR_ROUTE:Fly :: makes group AI invisible: " .. route.FlightName)
            route.Group:SetCommandInvisible(true)
        end
    end

    -- remove group when reaching last turnpoint...
    local function removeOnLastTurnpoint(route)
-- Debug("nisse - DCAF.AIR_ROUTE:Fly_removeOnLastTurnpoint :: self.Group: " .. Dump(route.Group ~= nil) .. " :: options: " .. DumpPretty(options))

        if options.DestroyOnLastTurnpoint then
            onRouteEnd(route.Waypoints, function(waypoint)
-- Debug("nisse - DCAF.AIR_ROUTE:Fly_onRouteEnd :: self.Group: " .. Dump(route.Group ~= nil))
                destroyOnLastTurnpoint(route.Group, waypoint)
            end)
-- Debug("nisse - DCAF.AIR_ROUTE:Fly_onRouteEnd :: last waypoint: " .. DumpPrettyDeep(route.Waypoints[#route.Waypoints]))
        end
    end

    -- spawn if `group` is SPAWN...
    route.Group = controllable
    if isClass(controllable, SPAWN) then
        -- ensure correct coalition for destination...
        alignCoalitionWithDestination(controllable, route)
        -- spawn group ...
        if route.DepartureAirbase then
            local controller = route:GetDepartureController()
            controller:RequestDeparture(controllable, route, function()
                setCruiseParameters(route.Waypoints, cruiseSpeedKnots, cruiseAltitudeFeet)
                if options.STAR and self.ArrivalAirbase and not self.HasArrival then
                    route:SetSTAR(options.STAR)
                end
                route.Group = controllable:SpawnAtAirbase(route.DepartureAirbase)
                route.FlightName = route.Group.GroupName
                makeInvisible(route)
                removeOnLastTurnpoint(route)
                fileFlightplan(route)
                addDeparture(controller, route)
                setGroupRoute(route.Group, route.Waypoints)
            end)
        else
            local firstWP = route.Waypoints[1]
            local nextWP
            local coordAirSpawn = COORDINATE_FromWaypoint(firstWP)
            if #route.Waypoints > 1 then
                nextWP = route.Waypoints[2]
                local coordNextWP = COORDINATE_FromWaypoint(nextWP)           
                local initialHeading = coordAirSpawn:GetHeadingTo(coordNextWP)
                coordAirSpawn:SetHeading(initialHeading)
            end
            coordAirSpawn:SetVelocity(Knots(cruiseSpeedKnots))
            coordAirSpawn:SetAltitude(Feet(cruiseAltitudeFeet))
            route.Group = controllable:SpawnFromCoordinate(coordAirSpawn)
            route.FlightName = route.Group.GroupName
            setCruiseParameters(route.Waypoints, cruiseSpeedKnots, cruiseAltitudeFeet)
            if options.STAR and self.ArrivalAirbase and not self.HasArrival then
                route:SetSTAR(options.STAR)
            end
            makeInvisible(route)
            removeOnLastTurnpoint(route)
            fileFlightplan(route)
            setGroupRoute(route.Group, route.Waypoints)
        end
    end
    return route
end

--- calls back a handler function when active route's group reaches last waypoint (might be useful to set parking, destroy group etc.)
function DCAF.AIR_ROUTE:OnArrival(func)
    if not isClass(self.Group, GROUP.ClassName) then
        Warning("DCAF.AIR_ROUTE:OnArrival :: not an active route (no Group flying it) :: IGNORES")
        return
    end
    onRouteEnd(self.Waypoints, function(waypoint) 
        func(self.Group, waypoint)
    end)
    return self
end

function AIR_ROUTE_CALLBACK_INFO:New(func)
    local info = DCAF.clone(AIR_ROUTE_CALLBACK_INFO)
    info.Func = func
    AIR_ROUTE_CALLBACK_INFO.NextId = AIR_ROUTE_CALLBACK_INFO.NextId + 1
    info.Id = AIR_ROUTE_CALLBACK_INFO.NextId
    AIR_ROUTE_CALLBACKS[tostring(info.Id)] = info
    return info
end

function AIR_ROUTE_CALLBACK_INFO:Remove()
    AIR_ROUTE_CALLBACKS[tostring(self.Id)] = nil
end

function DCAF.AIR_ROUTE:Callback(id)
    local info = AIR_ROUTE_CALLBACKS[tostring(id)]
    if not info then
        Warning("DCAF.AIR_ROUTE:Callback :: no callback found with id: " .. Dump(id) .. " :: IGNORES")
        return
    end
    info.Func()
end

--- Destroys active route (including GROUP flying it)
function DCAF.AIR_ROUTE:Destroy()
    if isClass(self.Group, GROUP.ClassName) then
        self.Group:Destroy()
    end
end

function DCAF.AIR_ROUTE:GetSTAR()
    return self.STAR
end

function DCAF.AIR_ROUTE:SetSTAR(star)
    if self.ArrivalAirbase == nil then
        error("DCAF.AIR_ROUTE:SetSTAR :: route have no arrival airport") end

    if isBoolean(star) then
        -- todo pick suitable STAR for arrival and active runway and 
        if star then
            star = DCAF.AIR_ROUTE:GetGenericSTAR(self.ArrivalAirbase)
        else
            return
        end
    else
        if isAssignedString(star) then
            local cached = DCAF.AIRAC.STAR[star]
            if not cached then
                error("DCAF.AIR_ROUTE:SetSTAR :: `star` is not in AIRAC: '" .. star .. "'")  end
            star = cached
        elseif not isClass(star, DCAF.AIR_ROUTE.ClassName) then
            error("DCAF.AIR_ROUTE:SetSTAR :: `star` must be type " .. DCAF.AIR_ROUTE.ClassName) 
        end
    end
    if #star.Waypoints == 0 then
        error("DCAF.AIR_ROUTE:SetSTAR :: `star` is empty (no waypoints)") end

    self:DeleteSTAR()
    local starWaypoints = DCAF.clone(star.Waypoints)
    local waypoints = listCopy(starWaypoints, self.Waypoints, 1, #self.Waypoints)
    self.Waypoints = waypoints
    return self
end

function DCAF.AIR_ROUTE:DeleteSTAR()
    if self.STAR == nil then 
        return self end
    
    local isStar = false
    for i = #self.Waypoints, 1, -1 do
        local wp = self.Waypoints[i]
        if wp.Phase == DCAF.AIR_ROUTE_PHASE.STAR then
            isStar = true
            table.remove(self.Waypoints, i)
        elseif isStar then
            -- no more STAR waypoints...
            break
        end
    end
end

--- Returns length of route (meters)
function DCAF.AIR_ROUTE:GetLength()
    local firstWP = self.Waypoints[1]
    local prevCoord = COORDINATE_FromWaypoint(firstWP)
    local distance = 0
    for i = 2, #self.Waypoints, 1 do
        local wp = self.Waypoints[i]
        local coord = COORDINATE_FromWaypoint(wp)
        distance = distance + prevCoord:Get2DDistance(coord)
        prevCoord = coord
    end
    return distance
end

--- generates a 'generic' STAR procedure for specified airbase (just a waypoint 20nm out from, and aligned with, active RWY)
function DCAF.AIR_ROUTE:GetGenericSTAR(airbase, speedKmph)
    local icao = DCAF.AIRAC:GetAirbaseICAO(airbase)
    if not icao then
        error("DCAF.AIR_ROUTE:GetGenericStar :: cannot resolve ICAO code for airbase: " .. DumpPretty(airbase)) end
    
    if not isNumber(speedKmph) then
        speedKmph = UTILS.KnotsToKmph(250) end

    local activeRWY = airbase:GetActiveRunwayLanding()
    local starName = icao .. "-" ..  activeRWY.name
    local star = DCAF.AIRAC.STAR:Get(starName)
    if star then 
        return star end

    local hdg = ReciprocalAngle(activeRWY.heading)
    local coordAirbase = airbase:GetCoordinate()
    local coordWP = coordAirbase:Translate(NauticalMiles(20), hdg)
    local airbaseAltitude = airbase:GetAltitude()
    -- coordWP:SetAltitude(Feet(12000))
    local wp = coordWP:WaypointAirTurningPoint(
        COORDINATE.WaypointAltType.BARO,
        speedKmph,
        nil,
        starName)
    wp.alt = Feet(10000)
    wp.alt_type = COORDINATE.WaypointAltType.RADIO
    return DCAF.AIRAC.STAR:New(starName, { wp }) --   DCAF.AIR_ROUTE:NewFromWaypoints(starName, { wp })
end

--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                        ROUTE POPULATION (spawns traffic along a route)
--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.ROUTE_SPAWN = {
    ClassName = "DCAF.ROUTE_SPAWN",
    Index = 0,                  -- #number - internal index of route spawn
    Coordinate = nil,           -- #CORE.COORDINATE
    Heading = nil,              -- #number
    AltitudeFt = nil,           -- #number (feet)
    Route = nil,                -- #DCAF.AIR_ROUTE
    Method = DCAF.AIR_ROUTE_SPAWNMETHOD.Air,
    Airbase = nil               -- #AIRBASE
}

function DCAF.ROUTE_SPAWN:New(index, coordinate, heading, waypoints, route, method)
    local route_spawn = DCAF.clone(DCAF.ROUTE_SPAWN)
    route_spawn.Name = route.Name
    route_spawn.Index = index
    route_spawn.Coordinate = coordinate
    route_spawn.Heading = heading
    route_spawn.Waypoints = listCopy(waypoints)
    route_spawn.Method = method or DCAF.AIR_ROUTE_SPAWNMETHOD.Air
    route_spawn.Route = route
    route_spawn.HasDeparture = route.HasDeparture
    route_spawn.HasArrival = route.HasArrival
    route_spawn.ArrivalAirbase = route.ArrivalAirbase
    return route_spawn
end

function DCAF.ROUTE_SPAWN:GetArrivalController(route)
    return DCAF.AIRAC:GetArrivalController(self)
end

local ROUTE_SPAWN_TEMPLATES_CACHE = { -- dictionary
    -- key   = #string - name of template
    -- value = #SPAWN
}

function ROUTE_SPAWN_TEMPLATES_CACHE:Get(name)
    local spawn = ROUTE_SPAWN_TEMPLATES_CACHE[name]
    if spawn then 
        return spawn end
        
    spawn = SPAWN:New(name)
    ROUTE_SPAWN_TEMPLATES_CACHE[name] = spawn
    return spawn
end

function DCAF.ROUTE_SPAWN:Spawn(spawn, options)
    if isAssignedString(spawn) then
        spawn = ROUTE_SPAWN_TEMPLATES_CACHE:Get(spawn)
    elseif not isClass(spawn, SPAWN.ClassName) then
        error("DCAF.ROUTE_SPAWN:SpawnFrom :: `spawn` must be type " .. SPAWN.ClassName)
    end
    if not isClass(options, DCAF.AIR_ROUTE_OPTIONS.ClassName) then
        options = DCAF.AIR_ROUTE_OPTIONS:New() 
    end

    spawn:InitGroupHeading(self.Heading)
    local group
    if self.Method == DCAF.AIR_ROUTE_SPAWNMETHOD.Air then
        group = spawn:SpawnFromCoordinate(self.Coordinate)
    else
        local takeoff = DCAF.AIR_ROUTE_SPAWNMETHOD:ResolveMOOSETakeoff(self.Method)
        group = spawn:SpawnAtAirbase(self.Airbase, takeoff)
    end
    self.Group = group
    self.FlightName = group.GroupName

    -- automatically remove on last turn point in route (unless options says otherwise)...
    if options.DestroyOnLastTurnpoint then
        onRouteEnd(self.Waypoints, function(waypoint)
            destroyOnLastTurnpoint(self.Group, waypoint)
        end)
    end

Debug("nisse - DCAF.ROUTE_SPAWN:Spawn :: waypoints: " .. DumpPrettyDeep(self.Waypoints, 1))    
    group:SetRoute(self.Waypoints)
    -- group:Route(self.Waypoints)
    return self
end

function DCAF.ROUTE_SPAWN:OnArrival(func)
    onRouteEnd(self.Waypoints, function(waypoint) 
        func(self.Group, waypoint)
    end)
    return self
end

function DCAF.AIR_ROUTE:Populate(separationNm, spawnFunc, options)
    if not isClass(options, DCAF.AIR_ROUTE_OPTIONS) then
        options = DCAF.AIR_ROUTE_OPTIONS:New()
    end
    if separationNm == nil then
        separationNm = VariableValue:New(NauticalMiles(80), .4)
    elseif isNumber(separationNm) then
        separationNm = VariableValue:New(NauticalMiles(separationNm))
    elseif not isClass(separationNm, VariableValue.ClassName) then
        error("getDistributedRouteSpawns :: `separation` must be type " .. VariableValue.ClassName) 
    end

    local maxCount = options.MaxCount
    if isNumber(maxCount) then
        maxCount = math.max(1, maxCount)
    end

    local route_spawns = {}
    if #self.Waypoints < 2 then
        return route_spawns end

    local prevWP = self.Waypoints[1]
    local coordPrevWP = COORDINATE_FromWaypoint(prevWP)
    local waypoints = listCopy(self.Waypoints, {}, 2) -- copy the list of waypoints (we will affect it)
    local wpEnd = waypoints[#waypoints]
    if IsLandingWaypoint(wpEnd) then
        wpEnd = DCAF.clone(wpEnd)
        wpEnd.speed = Knots(180) -- todo Consider resolving final approach speed depending on flight's max speed/category (https://skybrary.aero/articles/approach-speed-categorisation)
        waypoints[#waypoints] = wpEnd
    end
    local nextWP = waypoints[1]
    local coordNextWP = COORDINATE_FromWaypoint(nextWP)
    local heading = coordPrevWP:GetHeadingTo(coordNextWP)
    local altitude
    local count = 1
    setCruiseParameters(waypoints, options.CruiseSpeedKnots, options.CruiseAltitudeFeet)
    if not prevWP.alt then
        prevWP.alt = waypoints[1].alt
    end
    local function next()
        if isNumber(maxCount) and count == maxCount then
            return end
        
        local sep = separationNm:GetValue()
        local distance = coordPrevWP:Get2DDistance(coordNextWP)
        local effectiveSeparation = sep
        local diff = sep - distance
        while distance < effectiveSeparation do
            -- remove 1st waypoint from route and recalculate initial WP...
            effectiveSeparation = effectiveSeparation - distance
            coordPrevWP = coordNextWP
            local length
            prevWP = waypoints[1]
            waypoints, length = listCopy(waypoints, {}, 2)
            if length == 0 then
                return end -- we're done; terminate 
            
            nextWP = waypoints[1]
            if not nextWP[CONSTANTS.RouteProcedure] or nextWP[CONSTANTS.RouteProcedure] == DCAF.AIR_ROUTE_PHASE.Land then
                return end

-- Debug("nisse - DCAF.AIR_ROUTE:Populate_next :: newtWP.proc: " .. Dump(nextWP.proc))

            coordNextWP = COORDINATE:New(nextWP.x, nextWP.alt, nextWP.y)
            heading = coordPrevWP:GetAngleDegrees(coordPrevWP:GetDirectionVec3(coordNextWP))
            distance = coordPrevWP:Get2DDistance(coordNextWP)
        end

        if prevWP.alt == nextWP.alt then
            altitude = nextWP.alt
        else
Debug("nisse - DCAF.AIR_ROUTE:Populate :: prevWP: " .. DumpPrettyDeep(prevWP, 1))            
            local maxAlt = math.max(prevWP.alt, nextWP.alt)
            local minAlt = math.min(prevWP.alt, nextWP.alt)
            local diff = maxAlt - minAlt
            local factor = effectiveSeparation / distance
            if prevWP.alt > nextWP.alt then
                -- descending
                factor = 1 - factor
            end
            altitude = minAlt + (diff * factor)
        end
        count = count + 1
        return coordPrevWP:Translate(effectiveSeparation, heading)
    end

    local routeSpawns = {
        -- list of #DCAF.AIR_ROUTE_SPAWN
    }

    local function spawn(rs)
        if isFunction(options.OnArrivalFunc) then
            rs:OnArrival(options.OnArrivalFunc)
        end
        rs.MissedApproachRoute = self.MissedApproachRoute
        local spawn = spawnFunc(rs)
        if isAssignedString(spawn) then
            -- function provided a template name; get a SPAWN...
            spawn = getSpawn(spawn)
        end
        if isClass(spawn, SPAWN) then
            -- function provided a SPAWN (rather than spawning a group)...
            alignCoalitionWithDestination(spawn, self)
            spawn:InitHeading(heading)
            fileFlightplan(rs)
            rs:Spawn(spawn, options)
        end
        table.insert(routeSpawns, rs)
    end
    
    coordPrevWP = next()
    while coordPrevWP do
        coordPrevWP:SetAltitude(altitude)
        local routeWaypoints = listClone(waypoints, true)
        if #routeWaypoints > 0 then
            spawn(DCAF.ROUTE_SPAWN:New(count, coordPrevWP, heading, routeWaypoints, self))
        end        
        coordPrevWP = next()
    end

    return routeSpawns
end

--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                   PROCEDURES (SID/STAR)
--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function DCAF.AIRAC.STAR:New(name, waypoints)
    if not isAssignedString(name) then
        error("DCAF.AIRAC.STAR:New :: `name` must be assigned string") end
    if DCAF.AIRAC.STAR[name] then
        error("DCAF.AIRAC.STAR:New :: a STAR was already created with same `name`: '" .. name .. "'") end

    local star = DCAF.AIR_ROUTE:NewFromWaypoints(name, waypoints)
    for _, wp in ipairs(waypoints) do
        wp[CONSTANTS.RouteProcedure] = DCAF.AIR_ROUTE_PHASE.STAR
        wp[CONSTANTS.RouteProcedureName] = name
    end
    DCAF.AIRAC.STAR[name] = star -- cache for future reference
    return star
end

function DCAF.AIRAC.STAR:Get(name)
    return DCAF.AIRAC.STAR[name]
end

-- ////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                              AIRAC DATA
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////

local function loadAirdromes(data)
    for icao, v in pairs(data.Airdromes) do
        local controller
        if v.ATC then
            if v.ATC.Type == "Restricted" then
                if not isFunction(v.ATC.GetActiveRwyLandingFunc) then
                    return Error("loadAirdromes :: airdrome '" .. icao .."' specifies ATC (" .. v.ATC.Type .. ") but no ResolveActiveFunc")
                end
                controller = RestrictedAirbaseController(v.ATC.GetActiveRwyLandingFunc)
-- TODO Support more types of airdrome controllers?
            end
        end

        local info = AIRBASE_INFO:New(icao, v.Country, v.Name, controller)
                    :WithGND(v.GND)
                    :WithTWR(v.TWR)
                    :WithDEP(v.DEP)
                    :WithVOR(v.VOR)
                    :WithTACAN(v.TACAN)
        if v.SID then
            for name, sid in pairs(v.SID) do
                info:AddDepartureProcedures(DCAF.AIR_ROUTE:NewDeparture(name, sid.RWY, sid.RTE))
            end
        end
        if v.APP then
            for name, app in pairs(v.APP) do
                info:AddArrivalProcedures(DCAF.AIR_ROUTE:NewArrival(name, app.RWY, app.RTE, app.MIS))
            end
        end
    end
end

local function loadWaypoints(data, map)
    for name, v in pairs(data.Waypoints) do
        if v.Type == DCAF.NAVAID_TYPE.FIX then
            DCAF.NAVAID:NewFix(name, COORDINATE:NewFromLLDD(v.X, v.Y), map)
        elseif v.Type == DCAF.NAVAID_TYPE.VOR then
            DCAF.NAVAID:NewVOR(name, v.Frequency, COORDINATE:NewFromLLDD(v.X, v.Y), map)
        elseif v.Type == DCAF.NAVAID_TYPE.TACAN then
            DCAF.NAVAID:NewTACAN(name, v.Channel, v.Mode, COORDINATE:NewFromLLDD(v.X, v.Y), map)
        elseif v.Type == DCAF.NAVAID_TYPE.VORTAC then
            DCAF.NAVAID:NewVORTAC(name, v.Frequency, v.Channel, v.Mode, COORDINATE:NewFromLLDD(v.X, v.Y), map)
        else
            return Warning("AIRAC :: loadWaypoints :: unknown waypoint type: '" .. v.Type .. "'")
        end
    end
end

function DCAF.AIRAC.LoadData()
    if not DCAF.AIRAC.DATA then
        return Error("loadAIRAC :: DCAF.AIRAC.DATA was not available. Please ensure the AIRAC data file is loaded") end

    local map = UTILS.GetDCSMap()
    _DCAF_defaultMap = map
    Debug("Loading AIRAC " .. DCAF.AIRAC.DATA.Version .. " for map: " .. map .. "...")
    local data = DCAF.AIRAC.DATA.Maps[map]
    if not data then
        return Warning("DCAF.AIRAC.DATA is not available for map '" .. map .. "'. Please add AIRAC data for that map") end

    loadWaypoints(data, map)
    loadAirdromes(data)
end

----------------------------------------------------------------------------------------------

Trace("\\\\\\\\\\ DCAF.AIRAC.lua was loaded //////////")