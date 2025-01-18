local debugMenu = DCAF.Menu:New("DEBUG")
debugMenu:NewCommand("Debug Cmd 1", function(menu)
    MessageTo(nil, "Debug Cmd 1", 10)
    menu:Remove(true)
end)
local debug_child_1 = debugMenu:New("DEBUG Child 1")
debug_child_1:NewCommand("Debug Child Cmd 1", function(menu)
    MessageTo(nil, "Debug Child Cmd 1", 10)
    menu:Remove(true)
end)
debug_child_1:NewCommand("Debug Child Cmd 2", function(menu)
    MessageTo(nil, "Debug Child Cmd 2", 10)
    menu:Remove(false)
end)

local function addFlightMenus(group)

    local function dumpMenus()
        Debug("------------------------------ GROUP MENUS ------------------------------")
        Debug(DumpPrettyDeep(DCAF.Menu:GetAll(group), 1))
        -- Debug(DumpPrettyDeep(DCAF.Menu:GetAll(), 1))
        Debug("-------------------------------------------------------------------------")
    end

    local function command(menu, removeParent)
        local text = menu:GetText()
        MessageTo(nil, text, 10)
        menu:Remove(removeParent)
        dumpMenus()
    end

    if not group then return end
    local flightMenu = DCAF.Menu:New("FLIGHT", group)
        flightMenu:NewCommand("FLIGHT Cmd 1", function(menu) command(menu, true) end)

    local flight_child_1 = flightMenu:New("FLIGHT Child 1")
        flight_child_1:NewCommand("FLIGHT Child Cmd 1", function(menu) command(menu, true) end)
        flight_child_1:NewCommand("FLIGHT Child Cmd 2", function(menu) command(menu, true) end)

    dumpMenus()
end

local eventSink = BASE:New()
eventSink:HandleEvent(EVENTS.PlayerEnterAircraft, function(_,e)
    DCAF.delay(function()
        addFlightMenus(e.IniGroup)
    end, 1)
end)
