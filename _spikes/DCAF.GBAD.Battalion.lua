local DCAF_GBAD_Battalion_DB = {
    Count = 0
}

local IADS_Type = {
    MANTIS = "MANTIS",
    SkyNet = "SkyNet"
}

DCAF.GBAD.Battalion = {
    ClassName = "DCAF.GBAD.Battalion",
    ----
    Name = "DCAF.GBAD.Battalion-0",
    IADS = nil,
    IADS_Type = nil,        -- IADS_Type (enum)
}

function DCAF.GBAD.Battalion:New(iads)
    local btn = DCAF.clone(DCAF.GBAD.Battalion)
    DCAF_GBAD_Battalion_DB.Count = DCAF_GBAD_Battalion_DB.Count+1
    if not isClass(iads, MANTIS) then return Error("DCAF.GBAD.Battalion:NewMANTIS :: `mantis` must be a MANTIS IADS, but was: " .. DumpPretty(iads)) end
    btn.Name = iads.name
    btn.IADS = iads
    btn.IADS_Type = IADS_Type.MANTIS
    btn:_hackMantis()
    return btn
end

function DCAF.GBAD.Battalion:ExcludeSAMGroups(groups)
    if isClass(groups, GROUP) or isAssignedString(groups) then groups = { groups } end
    if isListOfClass(groups, GROUP) then
        local groupNames = {}
        for _, group in ipairs(groups) do
            groupNames[#groupNames+1] = group.GroupName
        end
        groups = groupNames
    end
    if isListOfAssignedStrings(groups) then
        local list = {}
        self.IADS.SAM_Group:ForEachGroup(function(group)
            for _, groupName in ipairs(groups) do
                if groupName == group.GroupName then
                    list[#list+1] = group
                    break
                end
            end
        end)
        for _, group in ipairs(list) do
            self.IADS.SAM_Group:Remove(group.GroupName)
            Debug("DCAF.GBAD.Battalion:ExcludeSAMGroups :: " .. self.Name .. " :: excluded group: " .. group.GroupName)
        end
        self.IADS:_RefreshSAMTable()
        return list
    end
    return Error("DCAF.GBAD.Battalion:ExcludeSAMGroups :: `groups` must be one or more group names, or #GROUP, but was: " .. DumpPretty(groups), self)
end

function DCAF.GBAD.Battalion:ExcludeSAMGroupsByPattern(pattern)
    if not isAssignedString(pattern) then return Error("DCAF.GBAD.Battalion:ExcludeSAMGroupsByPattern :: `pattern` must be string, but was: " .. DumpPretty(pattern), self) end
    local namesList = {}
    self.IADS.SAM_Group:ForEachGroup(function(group)
        if string.find(group.GroupName, pattern) then
            namesList[#namesList+1] = group.GroupName
        end
    end)
    if #namesList > 0 then return self:ExcludeSAMGroups(namesList) end
    return Error("DCAF.GBAD.Battalion:ExcludeSAMGroupsByPattern :: no SAM groups matched pattern '" .. pattern .. "'", self)
end

--- Returns all managed SAM groups, optionally meeting a specified criteria
---@param funcCriteria function Will be called for each group, passing a #GROUP as only argument. Groups will only be included in result if function returns true
---@return table samGroups A table of #GROUP
function DCAF.GBAD.Battalion:GetSAMGroups(funcCriteria)
    local samGroups = {}
    if isFunction(funcCriteria) then
        self.IADS.SAM_Group:ForEachGroup(function(group)
            if funcCriteria(group) then
                samGroups[#samGroups+1] = group
            end
        end)
    else
        self.IADS.SAM_Group:ForEachGroup(function(group)
            samGroups[#samGroups+1] = group
        end)
    end
    return samGroups
end

function DCAF.GBAD.Battalion:_hackMantis()

    function self.IADS:_Check(detection,dlink)
        if self._isInhibited then return self end -- // hack //

        self:T(self.lid .. "Check")
        --get detected set
        local detset = detection:GetDetectedItemCoordinates()
        --self:T("Check:", {detset})
        -- randomly update SAM Table
        local rand = math.random(1,100)
        if rand > 65 then -- 1/3 of cases
          self:_RefreshSAMTable()
        end
        -- switch SAMs on/off if (n)one of the detected groups is inside their reach
        if self.automode then
          local samset = self.SAM_Table_Long -- table of i.1=names, i.2=coordinates, i.3=firing range, i.4=firing height
          self:_CheckLoop(samset,detset,dlink,self.maxlongrange)
          local samset = self.SAM_Table_Medium -- table of i.1=names, i.2=coordinates, i.3=firing range, i.4=firing height
          self:_CheckLoop(samset,detset,dlink,self.maxmidrange)
          local samset = self.SAM_Table_Short -- table of i.1=names, i.2=coordinates, i.3=firing range, i.4=firing height
          self:_CheckLoop(samset,detset,dlink,self.maxshortrange)
        else
          local samset = self:_GetSAMTable() -- table of i.1=names, i.2=coordinates, i.3=firing range, i.4=firing height
          self:_CheckLoop(samset,detset,dlink,self.maxclassic)
        end
        return self
    end
end

function DCAF.GBAD.Battalion:InhibitStart(duration)
    Debug("DCAF.GBAD.Battalion:InhibitStart :: duration: " .. Dump(duration))
    if not isClass(self.IADS, MANTIS) then return Error("DCAF.GBAD.Battalion:InhibitStart :: can only inhibit MANTIS IADS at this time", self) end

    local function inhibitGroup_MANTIS(samGroup)
        if self.IADS.UseEmOnOff then
            Debug("DCAF.GBAD.Battalion:InhibitStart :: inhibits group (emission OFF): " .. samGroup.GroupName)
            samGroup:EnableEmission(false)
        else
            Debug("DCAF.GBAD.Battalion:InhibitStart :: inhibits group (alarm state = green): " .. samGroup.GroupName)
            samGroup:OptionAlarmStateGreen()
        end
    end

    if self._inhibitScheduleID then
        pcall(function() DCAF.stopScheduler(self._inhibitScheduleID) end)
        self._inhibitScheduleID = nil
    end

    self.IADS._isInhibited = true
    self:OnInhibitedChanged(true)

    self.IADS.SAM_Group:ForEachGroup(function(group)
        inhibitGroup_MANTIS(group)
    end)

    if isNumber(duration) then
        self._inhibitScheduleID = DCAF.delay(function()
            self:InhibitEnd()
        end, duration)
    end
    return self
end

function DCAF.GBAD.Battalion:InhibitEnd(delay)
    Debug("DCAF.GBAD.Battalion:InhibitEnd :: delay: " .. Dump(delay))
    if not isClass(self.IADS, MANTIS) then return Error("DCAF.GBAD.Battalion:InhibitEnd :: can only inhibit MANTIS IADS at this time", self) end
    if not isNumber(delay) then delay = 0 end
    DCAF.delay(function()
        self.IADS._isInhibited = false
        self:OnInhibitedChanged(false)
    end, delay)
    return self
end

function DCAF.GBAD.Battalion:IsInhibited()
    return self.IADS._isInhibited
end

function DCAF.GBAD.Battalion:OnInhibitedChanged(isInhibited)
end

function DCAF.GBAD.Battalion:Operate(long, mid, shorad)
    Debug("DCAF.GBAD.Battalion:Operate :: long: " .. Dump(long) .. " :: mid: " .. Dump(mid) .. " :: shorad: " .. Dump(shorad))
    if not isClass(self.IADS, MANTIS) then return Error("DCAF.GBAD.Battalion:MakeOperational :: only MANTIS is supported at this time", self) end

    self.IADS.SAM_Group:ForEachGroup(function(samGroup)
        if not samGroup:IsActive() then samGroup:Activate() end
        local coord = samGroup:GetCoordinate()
        if coord then coord:CircleToAll() end
    end)
    return self
end

Trace("\\\\\\\\\\ DCAF.GBAD.Battalion.lua was loaded //////////")
