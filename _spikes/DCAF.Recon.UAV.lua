DCAF.Recon.UAV = {
    ClassName = "OVS_Reapers",
    ----
    Count = 4,
    Sensors = {
        Radar = NauticalMiles(15),
        Optical = true,
        RWR = true,
        IRST = true,
        Datalink = false
    },
    Spawned = 0,
    Spawn = getSpawn("BLU Reaper"),
    Groups = {},
    Menus = {},
    HomeBase = AIRBASE:FindByName(AIRBASE.Syria.Deir_ez_Zor),
    C2 = getGroup("BLU Reaper C2")
}
DCAF.Recon.UAV._maxDetectionRange = DCAF.Recon.UAV.Sensors.Radar

function DCAF.Recon.UAV:_make(group, index)
    if not isGroup(group) then return Error("DCAF.Recon.UAV:_make :: `group` must be #GROUP, but was: " .. DumpPretty(group), self) end
    local maxRange = self._maxDetectionRange
    if isNumber(self.Sensors.Radar) and self.Sensors.Radar > maxRange then maxRange = self.Sensors.Radar end
    local drawOptions = DCAF.ReconDrawOptions:New()
                                             :InitIconSize(100) -- meters
                                             :InitTextFillColor(Color.Black)
                                             :InitMaxAlpha(0.8) -- ensures icons never completely blocks what's underneath
    DCAF.Recon:New(group)
              :InitDrawDetected(drawOptions)
              :InitDeadZone(40)
              :Start(nil, maxRange, self.Sensors.Optical, self.Sensors.RWR, self.Sensors.IRST, self.Sensors.Datalink)
    
    local menu = self.MainMenu:AddMenu("Reaper " .. index)
    self.Menus[index] = menu
    self.Groups[index] = group
    menu:AddCommand("RTB now", function()
        DCAF.Recon.UAV:Rtb(index)
    end)
    menu:AddCommand("Orbit here", function()
        DCAF.Recon.UAV:Orbit(index)
    end)
end

function DCAF.Recon.UAV:Launch(index)
    local menu = self.Menus[index]
    menu:Remove(false)
    local group = self.Spawn:Spawn()
    self:_make(group, index)
    -- local maxRange = self._maxDetectionRange
    -- if isNumber(self.Sensors.Radar) and self.Sensors.Radar > maxRange then maxRange = self.Sensors.Radar end
    -- local drawOptions = DCAF.ReconDrawOptions:New()
    --                                          :InitIconSize(100) -- meters
    --                                          :InitTextFillColor(Color.Black)
    --                                          :InitMaxAlpha(0.8) -- ensures icons never completely blocks what's underneath
    -- DCAF.Recon:New(group)
    --           :InitDrawDetected(drawOptions)
    --           :InitDeadZone(40)
    --           :Start(nil, maxRange, self.Sensors.Optical, self.Sensors.RWR, self.Sensors.IRST, self.Sensors.Datalink)
    
    -- menu = self.MainMenu:AddMenu("Reaper " .. index)
    -- self.Menus[index] = menu
    -- self.Groups[#self.Groups+1] = group
    -- menu:AddCommand("RTB now", function()
    --     DCAF.Recon.UAV:Rtb(index)
    -- end)
    -- menu:AddCommand("Orbit here", function()
    --     DCAF.Recon.UAV:Orbit(index)
    -- end)
end

function DCAF.Recon.UAV:InitMaxDetectionRange(value)
    if not isNumber(value) then return Error("OVS_Reapers:InitMaxDetectionRange :: `value` must be number, but was: " .. DumpPretty(value) .. " :: IGNORES", self) end
    DCAF.Recon.UAV._maxDetectionRange = value
    return self
end

function DCAF.Recon.UAV:InitRadar(value)
    if value == nil then
        value = true
    elseif not isBoolean(value) and not isNumber(value) then
        return Error("OVS_Reapers:InitRadar :: `value` must be positive number or boolean (true/false), but was: " .. DumpPretty(value) .. " :: IGNORES", self)
    end
    self.Sensors.Radar = value
    return self
end

function DCAF.Recon.UAV:InitOptical(value)
    if value == nil then
        value = true
    elseif not isBoolean(value) and not isNumber(value) then
        return Error("OVS_Reapers:InitOptical :: `value` must be positive number or boolean (true/false), but was: " .. DumpPretty(value) .. " :: IGNORES", self)
    end
    self.Sensors.Optical = value
    return self
end

function DCAF.Recon.UAV:InitRWR(value)
    if value == nil then
        value = true
    elseif not isBoolean(value) and not isNumber(value) then
        return Error("OVS_Reapers:InitRWR :: `value` must be positive number or boolean (true/false), but was: " .. DumpPretty(value) .. " :: IGNORES", self)
    end
    self.Sensors.RWR = value
    return self
end

function DCAF.Recon.UAV:InitIRST(value)
    if value == nil then
        value = true
    elseif not isBoolean(value) and not isNumber(value) then
        return Error("OVS_Reapers:InitIRST :: `value` must be positive number or boolean (true/false), but was: " .. DumpPretty(value) .. " :: IGNORES", self)
    end
    self.Sensors.IRST = value
    return self
end

function DCAF.Recon.UAV:InitDatalink(value)
    if value == nil then
        value = true
    elseif not isBoolean(value) and not isNumber(value) then
        return Error("OVS_Reapers:InitDatalink :: `value` must be positive number or boolean (true/false), but was: " .. DumpPretty(value) .. " :: IGNORES", self)
    end
    self.Sensors.Datalink = value
    return self
end

function DCAF.Recon.UAV:Rtb(index)
    local menu = self.Menus[index]
    menu:Remove(false)
    self.MainMenu:AddMenu("(Reaper " .. index .. " is RTB)")
    local group = self.Groups[index]
    local route = group:CopyRoute()
    local wpRTB
    for _, wp in ipairs(route) do
        if wp.name == "RTB" then
            wpRTB = wp
            break
        end
    end
    local coordHomeBase = self.HomeBase:GetCoordinate()
    local waypoints = {
        wpRTB,
        coordHomeBase:WaypointAirLanding(UTILS.KnotsToKmph(160), self.HomeBase)
    }
    setGroupRoute(group, waypoints)
end

function DCAF.Recon.UAV:Orbit(index)
    local group = self.Groups[index]
    if not group then return Error("DCAF.Recon.UAV:Orbit :: could not get GROUP for index " .. Dump(index)) end
    local altitude = group:GetAltitude(false)
    local speedMps = group:GetVelocityMPS()
    local taskOrbit = group:TaskOrbitCircle(altitude, speedMps)
    group:SetTask(taskOrbit)
    return self
end

function DCAF.Recon.UAV:Enable(count, parentMenu)
    if self._isEnabled then return Error("DCAF.Recon.UAV:Enable :: was already enabled :: IGNORES", self) end
    self._isEnabled = true
    self.C2:Activate()
    Debug("OVS_Reapers:Enable :: count: " .. Dump(count))
    if isNumber(count) then
        if count < 1 then return end
        DCAF.Recon.UAV.Count = count
    end
    if isClass(parentMenu, MENU_BASE) then
        DCAF.Recon.UAV.MainMenu = GM_Menu:New("Recon UAVs", parentMenu)
    elseif isClass(parentMenu, GM_Menu) then
        DCAF.Recon.UAV.MainMenu = GM_Menu:AddMenu("Recon UAVs")
    else
        DCAF.Recon.UAV.MainMenu = GM_Menu:New("Recon UAVs")
    end

    for i = 1, DCAF.Recon.UAV.Count, 1 do
        local menu = DCAF.Recon.UAV.MainMenu:AddCommand("Launch Reaper " .. i, function()
            DCAF.Recon.UAV:Launch(i)
        end)
        DCAF.Recon.UAV.Menus[#DCAF.Recon.UAV.Menus+1] = menu
    end
end

function DCAF.Recon.UAV:Make(groups, parentMenu)
    if self._isEnabled then return Error("DCAF.Recon.UAV:Make :: was already enabled :: IGNORES", self) end
    self._isEnabled = true
    if self.C2 then
        self.C2:Activate()
    end
    if isListOfAssignedStrings(groups) then
        local listOfGroups = {}
        for _, name in pairs(groups) do
            local group = getGroup(name)
            if group then
                listOfGroups[#listOfGroups+1] = group
                if not group:IsActive() then group:Activate() end
            end
        end
        groups = listOfGroups
    elseif not isListOfClass(groups, GROUP) then
        return Error("DCAF.Recon.UAV:Make :: `groups` must be list of strings (group names) or list of #GROUP, but was: " .. DumpPretty(groups), self)
    end
    Debug("OVS_Reapers:Make :: count: " .. #groups)
    DCAF.Recon.UAV.Count = #groups

    if isClass(parentMenu, MENU_BASE) then
        DCAF.Recon.UAV.MainMenu = GM_Menu:New("Recon UAVs", parentMenu)
    elseif isClass(parentMenu, GM_Menu) then
        DCAF.Recon.UAV.MainMenu = GM_Menu:AddMenu("Recon UAVs")
    else
        DCAF.Recon.UAV.MainMenu = GM_Menu:New("Recon UAVs")
    end
    for i = 1, #groups, 1 do
        local group = groups[i]
        self:_make(group, i)
    end
end

Trace("\\\\\\\\\\ SYR_OVS_Reapers.lua was loaded //////////")
