local function defaultOnTaxi(unit, crew, distance)
    if distance > 50 or not unit:GetCoordinate() then
        crew:Destroy()
    end
end

DCAF.AircraftGroundAssetLocation = {
    ColdStartAircraft = "Cold Start",
    ArmDearmArea = "Arm/De-arm Area",
}

DCAF.AircraftGroundAssets = {
    ClassName = "DCAF.AircraftGroundAssets",
    AirplaneGroundCrewSpawn = {
        -- list of #SPAWN - templates used for dynamically spawning ground crew
    },         
    MonitorTaxiScheduleID = nil,            -- #number - set when a scheduler is running, to remove gound crew
    FuncOnTaxi = defaultOnTaxi
}

local DCAF_GroundCrewInfo = {
    ChiefDistance = 7,
    ChiefHeading = 145,                     -- #number - subtracted from UNIT's heading (typically the chief is reciprocal heading [180])
    ChiefOffset = 310,                      -- #number - subtracted from UNIT's heading (typically the chief is 12 oc from UNIT [0])
}

local DCAF_GroundCrewDB = {
    -- key   = #string - model type name (from UNIT:GetTypeName())
    -- value = #DCAF_GroundCrewInfo
}

local DCAF_ActiveGroundCrew = {
    ClassName = "DCAF_ActiveGroundCrew",
    Unit = nil,                             -- #GROUP - spawned unit (aircraft)
    ParkingCoordinate = nil,                -- #COORDINATE - Unit's original location
    CroundCrew = {
        -- list of #GROUP
    }
}

local DCAF_ActiveGroundCrews = {
    -- key   = UNIT name
    -- value = #DCAF_ActiveGroundCrew
}
local DCAF_CountActiveGroundCrews = 0

local function stopMonitoringGroundCrew(leftAirplaneFunc)
    if DCAF_CountActiveGroundCrews == 0 then
        Debug(DCAF.AircraftGroundAssets.ClassName .. " :: stops monitoring airplane taxi")
        DCAF.stopScheduler(DCAF.AircraftGroundAssets.MonitorTaxiScheduleID)
        DCAF.AircraftGroundAssets.MonitorTaxiScheduleID = nil
    end
end

local function removeAirplaneGroundCrew(unit)
    local groundCrew = DCAF_ActiveGroundCrew:Get(unit)
    if groundCrew then
        groundCrew:Destroy()
    end
end

local function startMonitoringGroundCrew()
    if DCAF.AircraftGroundAssets.MonitorTaxiScheduleID then
        return end

    Debug(DCAF.AircraftGroundAssets.ClassName .. " :: starts monitoring airplane taxi")
    local schedulerFunc
    schedulerFunc = function()
        local count = 0
-- Debug("nisse - DCAF_ActiveGroundCrews: " .. DumpPretty(DCAF_ActiveGroundCrews))
        for unitName, activeGroundCrew in pairs(DCAF_ActiveGroundCrews) do
            count = count + 1
-- Debug("startMonitoringGroundCrew :: activeGroundCrew.Unit: " .. DumpPretty(activeGroundCrew.Unit))
-- if activeGroundCrew.Unit then
-- Debug("startMonitoringGroundCrew :: activeGroundCrew.Unit:IsAlive: " .. DumpPretty(activeGroundCrew.Unit:IsAlive()))
-- end
            if not activeGroundCrew.Unit or not activeGroundCrew.Unit:IsAlive() then
                removeAirplaneGroundCrew(activeGroundCrew.Unit)
            else
                local coordUnit = activeGroundCrew.Unit:GetCoordinate()
                -- note: VTOL takeoffs amount to "vertical" taxi, so "taxi distance" will be either hotizontal or vertical distance...
                local taxiAltitude = math.abs(coordUnit.y - activeGroundCrew.ParkingCoordinate.y)
                local taxiDistance = math.max(taxiAltitude, activeGroundCrew.ParkingCoordinate:Get2DDistance(coordUnit))
                DCAF.AircraftGroundAssets.FuncOnTaxi(activeGroundCrew.Unit, activeGroundCrew, taxiDistance)
            end
        end
    end
    DCAF.AircraftGroundAssets.MonitorTaxiScheduleID = DCAF.startScheduler(schedulerFunc, .5)
end

local function addAirplaneGroundCrew(unit)
    if not DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn or #DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn == 0 then
        Warning(DCAF.AircraftGroundAssets.ClassName .. " :: Cannot add airplane ground crew for " .. unit.UnitName .. " :: template is not specified")
        return
    end

    local typeName = unit:GetTypeName()
    local info = DCAF_GroundCrewDB[typeName]
    if not info then
        Warning(DCAF.AircraftGroundAssets.ClassName .. " :: No ground crew information available for airplane type '" .. typeName .. "' :: IGNORES")
        return
    end

    local groundCrew = {}
    local coordUnit = unit:GetCoordinate()
    local hdgUnit = unit:GetHeading()
    local offsetCrew = (hdgUnit + info.ChiefOffset) % 360
-- Debug("nisse - addAirplaneGroundCrew :: unit hdg: " .. Dump(hdgUnit) .. " :: offsetCrew: " .. Dump(offsetCrew))
    local locCrew = coordUnit:Translate(info.ChiefDistance, offsetCrew)
    local hdgCrew = (offsetCrew + info.ChiefHeading) % 360
    local spawn = listRandomItem(DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn)
    if not spawn then return Warning("addAirplaneGroundCrew :: could not resolve random ground crew spawn object :: IGBORES") end
    spawn:InitHeading(hdgCrew)
    local crew = spawn:SpawnFromCoordinate(locCrew)
    Debug(DCAF.AircraftGroundAssets.ClassName .. " :: spawns airplane ground crew: " .. crew.GroupName)
    table.insert(groundCrew, crew)

    -- todo - consider adding more ground crew

    DCAF_ActiveGroundCrew:New(unit, groundCrew, DCAF.AircraftGroundAssetLocation.ColdStartAircraft)
end

function DCAF.AircraftGroundAssets.SpawnAirplaneGroundCrew(...)

    local function addGroundCrew(groundCrew)
        local group = getGroup(groundCrew)
        if not group then 
            error("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: cannot resolve `ground crew` from: " .. DumpPretty(groundCrew)) end

        local spawn = getSpawn(group.GroupName)
        if not spawn then
            error("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: cannot resolve `ground crew` from: " .. DumpPretty(groundCrew)) end

        Debug("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: adds airplane ground crew: " .. group.GroupName)
        table.insert(DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn, spawn)
    end

    for i = 1, #arg, 1 do
        addGroundCrew(arg[i])
    end

    local _enteredAirplaneTimestamps = {
        -- key   = #string - player name
        -- value = #number - timestamp
    }

    MissionEvents:OnPlayerEnteredAirplane(function(event)
        local unit = event.IniUnit
        if not unit:IsParked() then
            Debug(DCAF.AircraftGroundAssets.ClassName .. " :: player entered non-parked airplane :: EXITS")
            return
        end

        Delay(1.5, function()
            if DCAF_ActiveGroundCrew:FindForUnit(unit) then return end -- seems this callback is sometimes invoked multiple times; avoid creating multiple aircrews
            addAirplaneGroundCrew(unit)
        end)
    end)

    return DCAF.AircraftGroundAssets
end

local function onUnitStopped(unit, func)
    unit._onUnitStoppedSheduleID = DCAF.startScheduler(function()
        local speed = unit:GetVelocityKMH()
        if speed > 0.1 then
            return end

        func(unit)
        DCAF.stopScheduler(unit._onUnitStoppedSheduleID)
        unit._onUnitStoppedSheduleID = nil
    end, 1)

end

local _activatingArmDearmAreaOfficer = {
    -- key   = UNIT.UnitName
    -- value = true
}

function DCAF.AircraftGroundAssets.ActivateArmDearmAreaOfficer(groundCrew, zone)
    local grpCrew = getGroup(groundCrew)
    if not grpCrew then
        return Warning("DCAF.AircraftGroundAssets.Activate :: cannot resolve ground crew from: " .. DumpPretty(groundCrew)) end

    if not isZone(zone) then
        return Warning("DCAF.AircraftGroundAssets.Activate :: cannot resolve zone from: " .. DumpPretty(zone)) end

    if not grpCrew:IsActive() then
        grpCrew:Activate()
    end
    local coord = grpCrew:GetCoordinate()
    if not coord then
        return Warning("DCAF.AircraftGroundAssets.Activate :: cannot get a coordinate from: " .. DumpPretty(groundCrew)) end

    MissionEvents:OnGroupEntersZone(nil, zone, function(event)
-- Debug("nisse - DCAF.AircraftGroundAssets.ActivateArmDearmAreaOfficer_OnGroupEntersZone :: group: " .. DumpPrettyDeep(event, 2))
        local group = event.IniGroups[1]
        if not group or not group:IsAir() then
            return end

        local aircraft = group:GetClosestUnit(coord)
        if not aircraft then
-- Debug("nisse - DCAF.AircraftGroundAssets.Activate :: zone triggered but could not resolve group's closest aircraft")
            return end

        if _activatingArmDearmAreaOfficer[aircraft.UnitName] then
            return end

-- MessageTo(nil, "Activated " .. aircraft.UnitName)
        _activatingArmDearmAreaOfficer[aircraft.UnitName] = true
        onUnitStopped(aircraft, function()
-- MessageTo(nil, aircraft.UnitName .. " stopped")
            DCAF_ActiveGroundCrew:New(aircraft, grpCrew, DCAF.AircraftGroundAssetLocation.ArmDearmArea)
            _activatingArmDearmAreaOfficer[aircraft.UnitName] = nil
        end)
    end)

    return DCAF.AircraftGroundAssets
end

function DCAF.AircraftGroundAssets.OnTaxi(func) -- function(unit, crew, distance) 
    if not isFunction(func) then
        error("DCAF.AircraftGroundAssets.OnTaxi :: `func` must be a function, but was: " .. type(func)) end

    DCAF.AircraftGroundAssets.FuncOnTaxi = func
    return DCAF.AircraftGroundAssets
end

function DCAF_GroundCrewInfo:New(model, chiefDistance, chiefHeading, chiefOffset)
    local info = DCAF.clone(DCAF_GroundCrewInfo)
    info.ChiefDistance = chiefDistance or DCAF_GroundCrewInfo.ChiefDistance
    info.ChiefHeading = chiefHeading or DCAF_GroundCrewInfo.ChiefHeading
    info.ChiefOffset = chiefOffset or DCAF_GroundCrewInfo.ChiefOffset
    DCAF_GroundCrewDB[model] = info
    return info
end

function DCAF_ActiveGroundCrew:FindForUnit(unit)
    return DCAF_ActiveGroundCrews[unit.UnitName]
end

function DCAF_ActiveGroundCrew:New(unit, groundCrew, location)
    local info = DCAF.clone(DCAF_ActiveGroundCrew)
    info.Unit = unit
    info.ParkingCoordinate = unit:GetCoordinate()
    if isGroup(groundCrew) then
        groundCrew = { groundCrew }
    end
    info.GroundCrew = groundCrew
    info.Location = location
    DCAF_ActiveGroundCrews[unit.UnitName] = info
    DCAF_CountActiveGroundCrews = DCAF_CountActiveGroundCrews + 1
    startMonitoringGroundCrew(unit)
    return info
end

function DCAF_ActiveGroundCrew:Get(unit)
    return DCAF_ActiveGroundCrews[unit.UnitName]
end

function DCAF_ActiveGroundCrew:Deactivate()
    DCAF_ActiveGroundCrews[self.Unit.UnitName] = nil
    DCAF_CountActiveGroundCrews = DCAF_CountActiveGroundCrews-1
    stopMonitoringGroundCrew()
    return self
end

function DCAF_ActiveGroundCrew:Destroy()
    for _, group in ipairs(self.GroundCrew) do
        group:Destroy()
local nisse = _DATABASE.GROUPS[group.GroupName]
if nisse then
Debug("nisse - DCAF_ActiveGroundCrew:Destroy :: found in _DATABASE.GROUPS: " .. DumpPretty(nisse))
_DATABASE.GROUPS[group.GroupName] = nil
Debug("nisse - DCAF_ActiveGroundCrew:Destroy :: removed in _DATABASE.GROUPS")
end
    end
    self:Deactivate()
    -- DCAF_ActiveGroundCrews[self.Unit.UnitName] = nil
    -- DCAF_CountActiveGroundCrews = DCAF_CountActiveGroundCrews-1
    -- stopMonitoringGroundCrew()
    return self
end

function DCAF_ActiveGroundCrew:Salute()
    for _, group in ipairs(self.GroundCrew) do
        group:OptionAlarmStateRed()
    end
end

function DCAF_ActiveGroundCrew:Restore()
    for _, group in ipairs(self.GroundCrew) do
        group:OptionAlarmStateGreen()
    end
end

-- DATABASE

DCAF_GroundCrewInfo:New("F-16C_50")
DCAF_GroundCrewInfo:New("FA-18C_hornet", 8.5, 150)
DCAF_GroundCrewInfo:New("AV8BNA")
DCAF_GroundCrewInfo:New("F-14A-135-GR", 10, 115, 330)
DCAF_GroundCrewInfo:New("F-14B", 10, 115, 330)
DCAF_GroundCrewInfo:New("F-15ESE", 11, 120, 320)

-- Debug("nisse - DCAF_GroundCrewDB: " .. DumpPretty(DCAF_GroundCrewDB))

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Debug("\\\\\\\\\\\\\\\\\\\\ DCAF.GroundAssets.lua was loaded ///////////////////")