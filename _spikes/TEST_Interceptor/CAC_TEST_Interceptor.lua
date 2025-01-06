Interceptor = DCAF.Interceptor.Debug(true)

Interceptor = DCAF.Interceptor:New("ICPT-1")
                            --   :AddPlayerMenus()
                              :Start()

DCAF.Interceptor:NewForClient()
                -- :AddPlayerMenus()
                :OnCreated(function(i)

Debug("nisse - OnCreated :: i: " .. DumpPretty(i))
MessageTo(nil, "INTERCEPTOR CREATED: " .. i.Group.GroupName)
    if i.Group.GroupName == "ICPT-2" then
        i:FollowMe(UNIT:FindByName("A320-1"))
    end
end):Start()

-- create automated interception after 10 seconds (test respawning AI follower to align coalition)
DCAF.delay(function()
    DCAF.Interceptor:New("ICPT-3"):Start():FollowMe("A320-3-1")
end, 10)
