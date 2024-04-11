DCAF.Visualize = {
}

function DCAF.Visualize:ShowParkingSpots(airbase, terminalType, allowTOAC)
    if isAssignedString(airbase) then
        local validAirbase = AIRBASE:FindByName(airbase)
        if not validAirbase then return Error("DCAF.Visualize:ParkingSpots :: AIRBASE not found: '" .. airbase .. "'") end
        airbase = validAirbase
    elseif not isAirbase(airbase) then
        return Error("DCAF.Visualize:ParkingSpots :: unexpected airbase value: " .. DumpPretty(airbase))
    end
    if not isBoolean(allowTOAC) then allowTOAC = true end
    local spots = airbase:GetParkingSpotsTable(terminalType, allowTOAC)
    for index, spot in ipairs(spots) do
        spot.Coordinate:CircleToAll(8, nil, {0,0,1}, nil, nil, 0, nil, true)
        local coordText = spot.Coordinate:Translate(5, 180)
        local id = "" .. spot.TerminalID
        coordText:TextToAll(id, nil, {0,0,1}, nil, nil, 0, 12, true)
    end
end