--- BIRTH...

local mnuBirth = MENU_MISSION:New("Birth")

MENU_MISSION_COMMAND:New("Activate", mnuBirth, function()
    getGroup("TEST-Activate"):Activate()
end)

MENU_MISSION_COMMAND:New("Spawn", mnuBirth, function()
    local spawn = getSpawn("TEST-Activate")
    spawn:InitRandomizePosition(true, NauticalMiles(5), NauticalMiles(1))
    spawn:Spawn()
end)

--- DESTRUCTION...

-- local mnuDestruction = MENU_MISSION:New("Destruction")

MENU_MISSION_COMMAND:New("Spawn Shooter", nil, function()
    getGroup("TEST-Shooter"):Activate()
end)

MENU_MISSION_COMMAND:New("Spawn CAS", nil, function()
    getGroup("TEST-CAS"):Activate()
end)

MENU_MISSION_COMMAND:New("Spawn Bunker", nil, function()
    getGroup("TEST-Bunker"):Activate()
end)

MENU_MISSION_COMMAND:New("Spawn M1A2 (shoot static)", nil, function()
    getGroup("TEST-M1A2"):Activate()
end)


DCAF.MissionState:New(2016, 6, 21, [[C:\DCAF\Core\_spikes\TEST_PersistentState\test_state.lua]]):Monitor()