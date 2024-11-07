local debug = true
DCAF.GBAD.Debug = debug

-- DCAF.GBAD.Regiment:SetDefaultDistances(NauticalMiles(45), NauticalMiles(28), NauticalMiles(60))
-- DCAF.GBAD.Regiment:SetDefaultMaxActiveSAMs(2, 2, 2)
DCAF.GBAD.Regiment:SetDefaultPrefixes("RSAM", "REWR", "RSH")

DCAF.GBAD.Regiment:New("TEST Regiment-1",
                        Coalition.Red,
                        ZONE:FindByName("TEST Regiment-1"),
                        "TEST Regiment HQ-1",
                        DCAF.GBAD.RegimentMode.Static)
                  :Debug(debug)
                  :Start()
DCAF.GBAD.Regiment:New("TEST Regiment-2",
                        Coalition.Red,
                        ZONE:FindByName("TEST Regiment-2"),
                        "TEST Regiment HQ-2",
                        DCAF.GBAD.RegimentMode.OFF)
                  :Debug(debug)
                  :Start()
DCAF.GBAD.Regiment:New("TEST Regiment-3",
                        Coalition.Red,
                        ZONE:FindByName("TEST Regiment-3"),
                        "TEST Regiment HQ-3",
                        DCAF.GBAD.RegimentMode.OFF,
                        nil,
                        "R-EWR")
                  :Debug(debug)
                  :Start()


MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Blow up EWR 1", nil, function()
    local setEWR = SET_GROUP:New():FilterPrefixes("REWR-1"):FilterOnce()
    setEWR:ForEachGroup(function(group)
Debug("nisse - " .. group.GroupName .. " goes ka-BLAM!")
        group:Explode(500)
    end)
end)

MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Blow up HQ 1", nil, function()
    local setEWR = SET_GROUP:New():FilterPrefixes("TEST Regiment HQ-1"):FilterOnce()
    setEWR:ForEachGroup(function(group)
Debug("nisse - " .. group.GroupName .. " goes ka-BLAM!")
        group:Explode(500)
    end)
end)

MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Blow up HQ 2", nil, function()
    local setEWR = SET_GROUP:New():FilterPrefixes("TEST Regiment HQ-2"):FilterOnce()
    setEWR:ForEachGroup(function(group)
Debug("nisse - " .. group.GroupName .. " goes ka-BLAM!")
        group:Explode(500)
    end)
end)