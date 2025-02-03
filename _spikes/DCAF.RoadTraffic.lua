DCAF.RoadTraffic = {
    ClassName = "DCAF.RoadTraffic",
    ----
    Nodes = {
        -- list of #DCAF.Location
    }
}

local DCAF_RoadTraffic = {
    Count = 0,
    IndexGroups = {}
}

function DCAF.RoadTraffic:New(name)
    local roadTraffic = DCAF.clone(DCAF.RoadTraffic)
    DCAF_RoadTraffic.Count = DCAF_RoadTraffic + 1
    roadTraffic.Name = name or DCAF.RoadTraffic..DCAF_RoadTraffic.Count
    return roadTraffic
end

--- Generates nodes from UNITs and then (optionally) removes the units from the map
---@param groups any
---@param destroy any
function DCAF.RoadTraffic:InitGroupNodes(groups, destroy, activate)
    local groupList = {}
    if isAssignedString(groups) then
        groups = SET_GROUP:New():FilterPrefixes(groups):FilterOnce()
    end
    if isClass(groups, SET_GROUP) then
        groups:ForEachGroup(function(group)
            groupList[#groupList+1] = group
        end)
        groups = groupList
    end
    if not isListOfClass(groups, GROUP) then return Error("DCAF.RoadTraffic:InitGroupNodes :: `units` must be list of UNITs, unit names, or a SET_UNIT, but was: " .. DumpPretty(groups), self) end
    if not isBoolean(destroy) then destroy = false end
    if not isBoolean(activate) then activate = false end

    local function processActiveGroup(group)
        local node = DCAF.Location.Resolve(group)
        if not node then Error("DCAF.RoadTraffic:InitGroupNodes :: cannot resolve location for group: " .. group.GroupName) end
        node._units = group:GetUnits()
        if destroy then
            local coord = group:GetCoordinate()
            if not coord then return Error("DCAF.RoadTraffic:InitGroupNodes :: cannot resolve coordinate for group: " .. group.GroupName) end
            node.Coordinate = coord
            group:Destroy()
        end
        self.Nodes[#self.Nodes+1] = node
    end

    local function process(group)
        local groupName = group.GroupName
        local node = DCAF_RoadTraffic.IndexGroups[groupName]
        if node then
            if node == true then
                DCAF.delay(function()
                    process(group)
                end, 0.2)
            end
            self.Nodes[#self.Nodes+1] = node
            return
        end
        if not group:IsActive() then
            if not activate then return Error("DCAF.RoadTraffic:InitGroupNodes :: cannot resolve location for inactive group: " .. groupName) end
            self.Nodes[#self.Nodes+1] = true -- just a placeholder, to signal group is about to activate
            group:Activate()
            DCAF.delay(function()
                return processActiveGroup(group)
            end, .1)
            return
        end
        processActiveGroup(group)
    end

    for _, unit in ipairs(groups) do
        process(unit)
    end
end

function DCAF.RoadTraffic:Start()
end