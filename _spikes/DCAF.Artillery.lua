--[[
    WIP
]]

DCAF.Artillery = {
    ClassName = "DCAF.Artillery",
    ----
    DeployLocations = {
        -- #list of #DCAF.Location
    }
}

DCAF.ArtilleryObserver = {
    ClassName = "DCAF.ArtilleryObserver",
    ----
    DeployLocations = {
        -- #list of #DCAF.Location
    },
    RoutingLocations = {
        -- #list of #DCAF.Location - locations to be routed through (to avoid detection)
    },
    Orders = {
        -- #list of #DCAF.AertilleryOrder
    },
    ArtyGroups = {

    },
    _orderIndex = -1,               -- #number - index into Orders list
}

DCAF.ArtilleryOrderType = {
    SalvoCount = "Salvo Count",     -- order is complete when # of salvos has been fired
    Time = "Time",                  -- order completes after a set time (clock starts at first salvo)
    Indefinite = "Indefinite",      -- order never completes (but can be cancelled)
}

DCAF.ArtilleryRedeploy = {
    Artillery = "Artillery",        -- artillery will redeploy
    Observer = "Observer",          -- observer will redeploy
    Both = "Both",                  -- artillery and observer will redeploy
}

DCAF.ArtilleryOrder = {
    ClassName = "DCAF.ArtilleryOrder",
    ----
    Type = DCAF.ArtilleryOrderType.Indefinite,
    Location = nil,                 -- #DCAF.Location,
    Radius = 150,                   -- #number (meters) - radius from Location
    Altitude = 0,                   -- #number (meters) - for air bursts (set to 0 otherwise) 
    AltitudeType = DCAF.AltitudeType.AGL, -- #DCAF.AltitudeType - for air bursts; when Altitude > 0 (otherwise ignored)
    SalvoCount = -1,                -- #number - only applicable when Type == DCAF.ArtilleryOrderType.SalvoCount
    Time = -1,                      -- #number - only applicable when Type == DCAF.ArtilleryOrderType.Time
    Redeploy = false,               -- #boolean - when true, the arty group will redeploy after order completion. Only applicable if artillery group also has at least two deploy locations
}

local function validateRedeploy(value)
    if value == DCAF.ArtilleryRedeploy.Artillery
    or value == DCAF.ArtilleryRedeploy.Observer
    or value == DCAF.ArtilleryRedeploy.Both then return value end
    Error("validateRedeploy :: invalid value: " .. DumpPretty(value))
end

function DCAF.Artillery:New(source, name)
    if isClass(source, DCAF.Artillery) then return source end
    local validGroup = getGroup(source)
    if not validGroup then return Error(DCAF.Artillery.ClassName .. ":New :: `source` could not be resolved from: " .. DumpPretty(source)) end
    if not validGroup:IsActive() then
        Warning(DCAF.Artillery.ClassName .. ":New :: group '" .. validGroup.GroupName .. "' is not active :: assumes activation will happen later")
    end
    local arty = DCAF.clone(DCAF.Artillery)
    arty.Group = validGroup
    if isAssignedString(name) then
        arty.Name = name
    else
        arty.Name = validGroup.GroupName
    end
    return arty
end

function DCAF.Artillery:InitDeploymentLocation(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error(DCAF.Artillery.ClassName .. ":InitDeploymentLocation :: `location` could not be resolved from:"  .. DumpPretty(location)) end
    self.DeployLocations[#self.DeployLocations+1] = validLocation
    return self
end

function DCAF.Artillery:InitDeploymentLocations(...)
    for i = 1, #arg, 1 do
        self:InitDeploymentLocation(arg[i])
    end
    return self
end

function DCAF.Artillery:Redeploy(targetLocation)
    -- TODO redeploy to available location in range of targetLocation
end

function DCAF.ArtilleryOrder:NewTimed(location, timeSeconds, redeployAfter)
    local validLocation = DCAF.Location.Resolve(location)
    if not isNumber(timeSeconds) or timeSeconds < 0 then return Error(DCAF.ArtilleryOrder.ClassName .. ":NewTimed :: `timeSeconds` must be positive number, but was: " .. DumpPretty(timeSeconds)) end
    if not validLocation then return Error(DCAF.ArtilleryOrder.ClassName .. ":NewTimed :: `location` could not be resolved from:"  .. DumpPretty(location)) end
    if not isBoolean(redeployAfter) then redeployAfter = true end

    local order = DCAF.clone(DCAF.ArtilleryOrder)
    order.Type = DCAF.ArtilleryOrderType.Time
    order.Location = validLocation
    order.Redeploy = validateRedeploy(redeployAfter)
    order.Time = timeSeconds
    return order
end

function DCAF.ArtilleryOrder:NewSalvoCount(location, salvoCount, redeployAfter)
    local validLocation = DCAF.Location.Resolve(location)
    if not isNumber(salvoCount) or salvoCount < 1 then return Error(DCAF.ArtilleryOrder.ClassName .. ":NewTimed :: `salvoCount` must integer [1..n], but was: " .. DumpPretty(salvoCount)) end
    if not validLocation then return Error(DCAF.ArtilleryOrder.ClassName .. ":NewTimed :: `location` could not be resolved from:"  .. DumpPretty(location)) end
    if not isBoolean(redeployAfter) then redeployAfter = true end

    local order = DCAF.clone(DCAF.ArtilleryOrder)
    order.Type = DCAF.ArtilleryOrderType.SalvoCount
    order.Location = validLocation
    order.Redeploy = validateRedeploy(redeployAfter)
    order.SalvoCount = salvoCount
    return order
end

function DCAF.ArtilleryOrder:NewIndefinite(location, redeployAfter)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error(DCAF.ArtilleryOrder.ClassName .. ":NewIndefinite :: `location` could not be resolved from:"  .. DumpPretty(location)) end
    if not isBoolean(redeployAfter) then redeployAfter = true end

    local order = DCAF.clone(DCAF.ArtilleryOrder)
    order.Type = DCAF.ArtilleryOrderType.SalvoCount
    order.Location = validLocation
    order.Redeploy = validateRedeploy(redeployAfter)
    return order
end

function DCAF.ArtilleryObserver:New(source, name)
    local validGroup = getGroup(source)
    if not validGroup then return Error(DCAF.ArtilleryObserver.ClassName .. ":New :: `source` could not be resolved from: " .. DumpPretty(source)) end
    if not validGroup:IsActive() then
        Warning(DCAF.ArtilleryObserver.ClassName .. ":New :: group '" .. validGroup.GroupName .. "' is not active :: assumes activation will happen later")
    end
    local observer = DCAF.clone(DCAF.ArtilleryObserver)
    observer.Group = validGroup
    if isAssignedString(name) then
        observer.Name = name
    else
        observer.Name = validGroup.GroupName
    end
    return observer
end

function DCAF.ArtilleryObserver:InitArtillery(arty)
    local validArty = DCAF.Artillery:New(arty)
    if not validArty then return Error(DCAF.ArtilleryObserver.ClassName .. ":InitArtillery :: could not resolve " .. DCAF.Artillery.ClassName .. " from: " .. DumpPretty(arty), self) end
    self.ArtyGroups[#self.ArtyGroups+1] = validArty
    return self
end

function DCAF.ArtilleryObserver:InitDeploymentLocation(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error(DCAF.ArtilleryObserver.ClassName .. ":InitDeploymentLocation :: `location` could not be resolved from:"  .. DumpPretty(location)) end
    self.DeployLocations[#self.DeployLocations+1] = validLocation
    return self
end

function DCAF.ArtilleryObserver:InitDeploymentLocations(...)
    for i = 1, #arg, 1 do
        self:InitDeploymentLocation(arg[i])
    end
    return self
end

function DCAF.ArtilleryObserver:InitRoutingLocation(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error(DCAF.ArtilleryObserver.ClassName .. ":InitRoutingLocation :: `location` could not be resolved from:"  .. DumpPretty(location)) end
    self.RoutingLocations[#self.RoutingLocations+1] = validLocation
    return self
end

function DCAF.ArtilleryObserver:InitRoutingLocations(...)
    for i = 1, #arg, 1 do
        self:InitRoutingLocation(arg[i])
    end
    return self
end

function DCAF.ArtilleryObserver:InitOrder(order)
    if not isClass(order, DCAF.ArtilleryOrder) then return Error(DCAF.ArtilleryObserver.ClassName .. ":InitOrder :: `order` must be " .. DCAF.ArtilleryOrder.ClassName .. ", but was: " .. DumpPretty(order) , self) end
    self.Orders[#self.Orders+1] = order
    return self
end

function DCAF.ArtilleryObserver:InitOrders(...)
    for i = 1, #arg, 1 do
        self:InitOrder(arg[i])
    end
    if self._isProcessingOrders then return self:Start() end
    return self
end

function DCAF.ArtilleryObserver:Start(delay)
    if not isNumber(delay) then delay = 0 end
    DCAF.delay(function()
        self:_processOrders()
    end, delay)
end

function DCAF.ArtilleryObserver:_selectArty(order)
    
end

function DCAF.ArtilleryObserver:_processOrders()
    self._isProcessingOrders = true
    self._orderStart(self:_getNextOrder())
    return self
end

function DCAF.ArtilleryObserver:_getNextOrder()
    for i = 1, #self.Orders, 1 do
        local order = self.Orders[i]
        local arty = self:_selectArty(order)
        if arty then
            table.remove(self.Orders, i)
            order.Arty = arty
            return order
        end
    end
end

function DCAF.ArtilleryObserver:_orderStart(order)
    if not order then return self end
end

function DCAF.ArtilleryObserver._orderEnd(order)
end
