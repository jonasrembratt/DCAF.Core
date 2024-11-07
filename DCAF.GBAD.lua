-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                     DCAF.GBAD - Build GBAD problems from the cockpit
--                                                Digital Coalition Air Force
--                                                          2022
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--DCAF.Debug = true

local TracePrefix = "DCAF.GBAD :: "             -- used for traces

DCAF.GBAD_DIFFICULTY = {
    Easy = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 0,
        Desc = "Easy (unprotected SAM sites)",
    },
    AAA = {
        ClassName = "GBAD_DIFFICULTY",
        Value = 1,
        Desc = "AAA (SAMs protected with AAA)",
        AAA = {
            Range = 800,
            Min = 1,
            Max = 3
        }
    },
    MANPADS = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 2,
        Desc = "MANPADS (SAMs protected with MANPADS)",
        MANPAD = {
            Range = 800,
            Min = 1,
            Max = 3
        }
    },
    SHORAD = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 3,
        Desc = "SHORAD (SAMs protected with SHORAD)",
        SHORAD = {
            Range = 4000,
            Min = 1,
            Max = 4
        }
    },
    Risky = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 4,
        Desc = "Risky (SAMs protected with MANPADS+AAA)",
        AAA = {
            Range = 800,
            Min = 1,
            Max = 3
        },
        MANPAD = {
            Range = 800,
            Min = 1,
            Max = 3
        }
    },
    Realistic = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 5,
        Desc = "Realistic (SAMs fully protected)",
        AAA = {
            Range = 800,
            Min = 0,
            Max = 3
        },
        MANPAD = {
            Range = 800,
            Min = 0,
            Max = 3
        },
        SHORAD = {
            Range = 4000,
            Min = 1,
            Max = 4
        }
    },   
}

local SAM_AREA = {
    ClassName = "",
    Name = nil,
    Zones = {
        -- list of #ZONE
    },
    SetZones = nil, -- #SET_ZONE (contains self.Zones)
    SpawnedSamSites = { -- dictionary
        -- key = SAM type (eg. 'SA-5')
        -- value = { list of #SPAWNED_SAM_SITE }
    },
    EWR = {
        -- list of #string (template name for EWR groups)
    },
    SAM = {
        -- list of #string (template name for SAM groups)
    },
    AAA = {
        -- list of #SPAWN (for AAA groups)
    },
    MANPAD = {
        -- list of #SPAWN (for MANPAD groups)
    },
    SHORAD = {
        -- list of #SPAWN (for SHORAD groups)
    },
    MANTIS_Info = nil,
    Skynet_Info = nil,
    IADS = nil,
    IADS_Type = nil,
    _refreshMenusFunc = nil
}

DCAF.GBAD = {
    Debug = false,           -- #boolean - can be used to debug GBAD/IADS related features
    Difficulty = DCAF.GBAD_DIFFICULTY.Realistic,
    WeaponsSimulation = nil, -- #DCAF.WeaponSimulationConfig (only set when simulation is active)
    Areas = {
        -- list of #SAM_AREA
    }
}

local IADS_INFO = {
    Type = nil,
    Name = nil,
    SAMPrefix = nil,
    SHORADPrefix = nil,
    EWRPrefix = nil,
    HQ = nil,
    Spawned_HQ = nil,
    Debug = false
}

local IADS_Types = {
    MANTIS = "MANTIS",
    Skynet = "Skynet"
}

function IADS_INFO:New(type, sSAMPrefix, sSHORADPrefix, sEWRPrefix, sHQ, bDebug)
    local info = DCAF.clone(IADS_INFO)
    info.Type = type
    info.SAMPrefix = sSAMPrefix
    info.SHORADPrefix = sSHORADPrefix
    info.EWRPrefix = sEWRPrefix
    info.HQ = sHQ
    info.Debug = bDebug
    return info
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                            GBAD DATABASE
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


DCAF_GBADDatabase = {
    -- dictionary (key = type name, value = #DCAF_RadarInfo)
}

--- Returns a list of information blocks for a specified (GBAD) source (type name, GROUP, UNIT, or name of GROUP or UNIT)
function DCAF_GBADDatabase:GetInfo(source, includeDeadUnits)
    local info
    if isAssignedString(source) then
        info = DCAF_GBADDatabase[source]
        if info then return { info } end
    end
    if not isBoolean(includeDeadUnits) then includeDeadUnits = true end
    local unit = getUnit(source)
    if unit then
        if not includeDeadUnits and not unit:IsAlive() then return end
        info = DCAF_GBADDatabase[unit:GetTypeName()]
        if info then return { info } end
    end

    local group = getGroup(source)
    if group then
Debug("nisse - DCAF_GBADDatabase:GetInfo :: group: " .. group.GroupName)
        local infos = {}
        local units = group:GetUnits()
        for _, unit in ipairs(units) do
            if includeDeadUnits or unit:IsAlive() then return end
            info = DCAF_GBADDatabase[unit:GetTypeName()]
Debug("nisse - DCAF_GBADDatabase:GetInfo :: unit type: " .. unit:GetTypeName() .. " :: info: " .. DumpPretty(info))
            if info then
                infos[#infos+1] = info
            end
        end
        return infos
    end
end

local DCAF_GBADInfo = {
    ClassName = "DCAF_GBADInfo",
    ----
    TypeName = nil,                     -- #string - DCS Unit type name
    NatoName = nil,                     -- #string - NATO reporting name of radar
    RangeLateral = 0,                   -- #number - Radar/system engagement range (meters)
    RangeVertical = 0,                  -- #number - Radar/system engagement ceiling (meters)
    IsEWR = false,                      -- #boolean - Specifies whether unit can be Warly Warning Radar
    Radar = nil,                        -- dictonary (key = radar type [#DCAF.RadarType], value = { list of bands } )

    -- IsSearchRadar = false,              -- #boolean - Specifies whether unit has search radar capability
    -- IsTrackingRadar = false,            -- #boolean - Specifies whether unit has tracking radar capability
    -- IsLauncher = false,                 -- #boolean - Specifies whether unit is an G-A nissile launcher
}

local DCAF_RadarInfo = {
    ClassName = "DCAF_RadarInfo",
    ----
    Type = nil,
    Bands = {}
}

function DCAF_RadarInfo:New(type, bands)
    local info = DCAF.clone(DCAF_RadarInfo)
    info.Type = type
    info.Bands = bands
end

DCAF.RadarType = {
    EarlyWarning = "EWR",
    Search = "SR",
    Tracking = "TR"
}
local function resolveRadarType(value)
    if not isAssignedString(value) then return Error("DCAF.RadarType :: could not resolve radar type: " .. DumpPretty(value)) end
    return tableIndexOf(DCAF.RadarType, value)
end

function DCAF_GBADInfo:New(typeName, natoName)
    local info = DCAF.clone(DCAF_GBADInfo)
    info.TypeName = typeName
    info.NatoName = natoName
    DCAF_GBADDatabase[typeName] = info
    return info
end

function DCAF_GBADInfo:InitEWR(bands)
    self.Radar = self.Radar or {}
    self.Radar[DCAF.RadarType.EarlyWarning] = bands
    return self
end

function DCAF_GBADInfo:InitSR(bands)
    self.Radar = self.Radar or {}
    self.Radar[DCAF.RadarType.Search] = bands
    return self
end

function DCAF_GBADInfo:InitTR(bands)
    self.Radar = self.Radar or {}
    self.Radar[DCAF.RadarType.Tracking] = bands
    return self
end

function DCAF_GBADInfo:InitLauncher()
    self.IsLauncher = true
    return self
end

function DCAF_GBADInfo:InitRange(lateral, vertical)
    self.RangeLateral = lateral
    self.RangeVertical = vertical
    return self
end

--- Gets information about unit's radar capability (if any)
-- @param string type - (#DCAF.RadarType) Optional. Can be used to query a specific radar type
function DCAF_GBADInfo:IsRadar(type)
    if isAssignedString(type) then return self.Radar[type] end
    return self.Radar
end


-- EWR radars
DCAF_GBADInfo:New("FPS-117", "FPS-117 'Seek Igloo'"):InitEWR():InitRange(NauticalMiles(250), Feet(100000))    -- https://www.radartutorial.eu/19.kartei/02.surv/karte007.en.html
DCAF_GBADInfo:New("FPS-117 Dome", "FPS-117 Dome"):InitEWR():InitRange(NauticalMiles(215), Feet(100000))
DCAF_GBADInfo:New("EWR P-37 BAR LOCK", "Bar Lock"):InitEWR():InitRange(NauticalMiles(275), Feet(100000))      -- https://www.radartutorial.eu/19.kartei/11.ancient/karte051.en.html
DCAF_GBADInfo:New("L13 EWR", "Box Spring"):InitEWR():InitRange(NauticalMiles(160), Feet(100000))              -- https://www.radartutorial.eu/19.kartei/11.ancient3/karte071.en.html
DCAF_GBADInfo:New("55G6 EWR", "Tall Rack"):InitEWR():InitRange(NauticalMiles(215), Feet(100000))              -- https://www.radartutorial.eu/19.kartei/02.surv/karte039.en.html
DCAF_GBADInfo:New("EWR Generic radar tower", "EWR Generic radar tower"):InitEWR():InitRange(NauticalMiles(188), Feet(100000))
-- SA-2 Guideline
DCAF_GBADInfo:New("SNR_75V", "SA-2 Fan Song TR"):InitTR():InitRange(NauticalMiles(28), Feet(60000))
DCAF_GBADInfo:New("p-19 s-125 sr", "SA-2 Flat Face SR"):InitSR():InitRange(NauticalMiles(28), Feet(60000))
-- SA-3 Goa
DCAF_GBADInfo:New("snr s-125 tr", "SA-3 Low Blow TR"):InitTR():InitRange(NauticalMiles(13), Feet(60000))
-- SA-5 Gammon
DCAF_GBADInfo:New("RPC_5N62V", "SA-5 Square Pair TR"):InitTR():InitRange(NauticalMiles(73), Feet(60000))
DCAF_GBADInfo:New("RLS_19J6", "SA-5 Tin Shield SR"):InitSR():InitRange(NauticalMiles(73), Feet(60000))  
-- SA-6 Gainful
DCAF_GBADInfo:New("Kub 1S91 str", "SA-6 Straight Flush STR"):InitSR():InitTR():InitRange(NauticalMiles(22), Feet(26000))
DCAF_GBADInfo:New("Kub 2P25 ln", "SA-6 Gainful LN"):InitTR():InitLauncher():InitRange(NauticalMiles(22), Feet(26000))
-- SA-8 Gecko
DCAF_GBADInfo:New("Osa 9A33 ln", "SA-8 Gecko SHORAD"):InitTR():InitLauncher():InitRange(NauticalMiles(9), Feet(16000))
-- SA-10 Grumble
DCAF_GBADInfo:New("S-300PS 40B6MD sr", "SA-10 Clam Shell SR"):InitSR():InitRange(NauticalMiles(46), Feet(99000))
DCAF_GBADInfo:New("S-300PS 40B6M tr", "SA-10 Flap Lid TR"):InitTR():InitRange(NauticalMiles(46), Feet(99000))
DCAF_GBADInfo:New("S-300PS 64H6E sr", "SA-10 Big Bird SR"):InitSR():InitRange(NauticalMiles(46), Feet(99000))
-- SA-11 Gadfly
DCAF_GBADInfo:New("SA-11 Buk SR 9S18M1", "SA-11 Snow Drift SR"):InitSR():InitRange(NauticalMiles(23), Feet(60000))
DCAF_GBADInfo:New("SA-11 Buk LN 9A310M1", "SA-11 Fire Dome TEL"):InitTR():InitLauncher():InitRange(NauticalMiles(23), Feet(60000))
-- SA-13 Gopher
DCAF_GBADInfo:New("Strela-10M3", "SA-13 Gopher SHORAD"):InitTR():InitLauncher():InitRange(NauticalMiles(5), Feet(12000))
-- SA-15 Gauntlet
DCAF_GBADInfo:New("Tor 9A331", "SA-15 Gauntlet SHORAD"):InitTR():InitLauncher():InitRange(NauticalMiles(9), Feet(20000))
-- SA-19 Grison
DCAF_GBADInfo:New("2S6 Tunguska", "SA-19 Grison SHORAD"):InitTR():InitLauncher():InitRange(NauticalMiles(5), Feet(12000))
-- Patriot
DCAF_GBADInfo:New("Patriot str", "Patriot STR"):InitSR():InitTR():InitRange(NauticalMiles(48), Feet(99000))
DCAF_GBADInfo:New("Patriot ln", "Patriot LN"):InitSR():InitTR():InitRange(NauticalMiles(48), Feet(99000))

------------- AAA -------------
-- ZSU-23-4 Shilka 
DCAF_GBADInfo:New("ZSU-23-4 Shilka", "Gun Dish"):InitTR():InitRange(NauticalMiles(1.3), Feet(6500))
-- ZSU-23-4 Shilka 
DCAF_GBADInfo:New("SON_9", "Fire Can"):InitTR():InitRange(NauticalMiles(50), Feet(60000))

local function dcafGbadQueryIsSAM(infos)
end

--- Returns true if source is a funcitonal SAM site (can track and shoot)
function DCAF.GBAD:QueryIsSAM(source, includeDeadUnits)
    local infos = DCAF_GBADDatabase:GetInfo(source, includeDeadUnits)
    if not infos then
Debug("nisse - DCAF.GBAD:QueryIsSAM :: no info: " .. source.GroupName)
    return end
    local isLN, isTR
    for _, info in ipairs(infos) do
        isLN = isLN or info.IsLauncher
        isTR = isTR or info.IsTrackingRadar
        if isTR and isLN then
Debug("nisse - DCAF.GBAD:QueryIsSAM :: is functional: " .. source.GroupName)
            return true
        end
    end
Debug("nisse - DCAF.GBAD:QueryIsSAM :: is non-functional: " .. source.GroupName)
end

--- Returns true if source is a functional SAM site (can track and shoot). Dead units will not be considered
function DCAF.GBAD:QueryIsSAMFunctional(source)
    return self:QueryIsSAM(source, false)
end


--- Queries GBAD database to check for max range of a GBAD source
-- @param #Any source - specifies the GBAD to be queried
-- @return #number, #number - max lateral range and max vertical range
function DCAF.GBAD:QueryRange(source)
    local infos = DCAF_GBADDatabase:GetInfo(source)
    local maxLateral = 0
    local maxVertical = 0
    for _, info in ipairs(infos) do
        if info.RangeLateral and info.RangeLateral > maxLateral then maxLateral = info.RangeLateral end
        if info.RangeVertical and info.RangeVertical > maxVertical then maxVertical = info.RangeVertical end
    end
    return maxLateral, maxVertical
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                IADS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local TracePrefix = "BadLand :: "             -- used for traces

local function teardownMantisIADS(area, force)
Debug("nisse - teardownMantisIADS :: area.IADS: " .. DumpPretty(area.IADS))
    if not area.IADS then
        return end
    
    area.IADS:Stop(1)
end

local function teardownSkynetIADS(area, force)
    if not area.IADS then
        return end
    
    area.IADS:deactivate()
    area.IADS:removeRadioMenu()
end

local function teardownIADS(area, force)
    if not area.IADS then
        return end

    if area.IADS_Type == "Skynet" then
        teardownSkynetIADS(area, force)
    elseif area.IADS_Type == "MANTIS" then
        teardownMantisIADS(area, force)
    end
    area.IADS = nil
    local message = area.IADS_Type .. " IADS was removed"
    area.IADS_Type = nil
    -- MessageTo(nil, message)
    Trace(TracePrefix .. message)
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                            MANTIS IADS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function SAM_AREA:WithMANTIS(sSAMPrefix, sSHORADPrefix, sEWRPrefix, sHQ, bDebug)
    if not isAssignedString(sSAMPrefix) then
        error("SAM_AREA:WithMANTIS :: `sSAMPrefix` must be assigned string") end

    self.MANTIS_Info = IADS_INFO:New(IADS_Types.MANTIS, sSAMPrefix, sSHORADPrefix, sEWRPrefix, sHQ, bDebug)
    return self
end


--- MANTIS IMPROVEMENTS ---

local GBAD_PROPERTIES = {
    ClassName = "GBAD_PROPERTIES",
    ----
    TypeName = nil,                 -- type name
    SuppressionTime = nil,          -- time (seconds) for this type to remain suppressed before wakng up again
    SkillFactors = {                -- used to add/cut to `SuppressionTime`
        VariableValue:New(1.8, .5), -- Average
        VariableValue:New(1.2, .5), -- Good
        VariableValue:New(1.0, .5), -- High
        VariableValue:New(0.7, .5), -- Excellent
    }
}

local GBAD_DB = {
    TypeProperties = {
        -- key   - #string - GBAD type name
        -- value - #GBAD_PROPERTIES
    }
}

function GBAD_DB:GetGBADProperties(source)
    local group
    if isAssignedString(source) then
        local properties = self.TypeProperties[source]
        if properties then
            return properties end

        group = getGroup(source)
    end
    if group then
        return self:GetGBADProperties(group:GetTypeName())
    end
end

function GBAD_PROPERTIES:New(typeName, suppressionTime)
    local props = DCAF.clone(GBAD_PROPERTIES)
    props.TypeName = typeName
    props.SuppressionTime = suppressionTime
    GBAD_DB.TypeProperties[typeName] = props
    return props
end

GBAD_PROPERTIES:New("S-300PS 40B6M tr", 30)    -- SA-10 :: 30 seconds suppression time
GBAD_PROPERTIES:New("Hawk pcp", Minutes(1.5))  -- HAWK  :: 90 seconds suppression time
GBAD_PROPERTIES:New("SNR_75V", Minutes(3))     -- SA-2  :: 180 seconds suppression time
GBAD_PROPERTIES:New("RPC_5N62V", Minutes(3))   -- SA-5  :: 180 seconds suppression time

function mantis_hackSuppression(iads)
    if not iads.mysead then
        return iads end

    function iads.mysead:onafterManageEvasion(From,Event,To,_targetskill,_targetgroup,SEADPlanePos,SEADWeaponName,SEADGroup,timeoffset)
        -- local targetProperties = GBAD_DB.GetGBADProperties(_targetgroup)
        local timeoffset = timeoffset  or 0
Debug("nisse - mantis_hackSuppression_onafterManageEvasion :: group: " .. _targetgroup.GroupName .. " :: typeName: " .. _targetgroup:GetTypeName() .. " :: skill: " .. _targetskill)
-- Debug("nisse - improveSuppression_onafterManageEvasion :: group: " .. _targetgroup.GroupName .. " :: typeName: " .. _targetgroup:GetTypeName() .. " :: properties: " .. DumpPrettyDeep(targetProperties))
        if self.TargetSkill[_targetskill] then
            local _evade = math.random (1,100) -- random number for chance of evading action
            if (_evade > self.TargetSkill[_targetskill].Evade) then
                self:T("*** SEAD - Evading")
                -- calculate distance of attacker
                local _targetpos = _targetgroup:GetCoordinate()
                local _distance = self:_GetDistance(SEADPlanePos, _targetpos)
                -- weapon speed
                local hit, data = self:_CheckHarms(SEADWeaponName)
                local wpnspeed = 666 -- ;)
                local reach = 10
                if hit then
                    local wpndata = SEAD.HarmData[data]
                    reach = wpndata[1] * 1.1
                    local mach = wpndata[2]
                    wpnspeed = math.floor(mach * 340.29)
                end
                -- time to impact
                -- local _tti = math.floor(_distance / wpnspeed) * 1.85 - timeoffset -- estimated impact time - hacked (temporary fix)
                local _tti = math.floor(_distance / wpnspeed) - timeoffset -- estimated impact time
if DCAF.GBAD.Debug then
DebugMessageTo(nil, "SUPPRESSION PLANNED :: group: " .. _targetgroup.GroupName ..  " :: tti: " .. _tti .. "\n:: distance: " .. _distance .. "\n:: wpnspeed: " .. wpnspeed)
end
                if _distance > 0 then
                    _distance = math.floor(_distance / 1000) -- km
                else
                    _distance = 0
                end

                self:T( string.format("*** SEAD - target skill %s, distance %dkm, reach %dkm, tti %dsec", _targetskill, _distance, reach, _tti ))

                if reach >= _distance then
                    self:T("*** SEAD - Shot in Reach")

                    local function SuppressionStart(args)
                        self:T(string.format("*** SEAD - %s Radar Off & Relocating", args[2]))
                        local grp = args[1] -- Wrapper.Group#GROUP
                        local name = args[2] -- #string Group Name
                        local attacker = args[3] -- Wrapper.Group#GROUP
if DCAF.GBAD.Debug then
DebugMessageTo(nil, "nisse - SUPPRESSION START :: name: " .. name .. " now: " .. timer.getTime())
end
Debug("nisse - mantis_hackSuppression :: self.UseEmissionsOnOff: " .. Dump(self.UseEmissionsOnOff))
                        if self.UseEmissionsOnOff then
                            grp:EnableEmission(false)
                        end
                        grp:OptionAlarmStateGreen() -- needed else we cannot move around
Debug("nisse - mantis_hackSuppression :: iads.UseEvasiveRelocation: " .. Dump(iads.UseEvasiveRelocation))
                        if iads.UseEvasiveRelocation then
                            grp:RelocateGroundRandomInRadius(20,300,false,false,"Diamond")
                        end
                        if self.UseCallBack then
                            local object = self.CallBack
                            object:SeadSuppressionStart(grp,name,attacker)
                        end
                    end

                    local function SuppressionStop(args)
                        self:T(string.format("*** SEAD - %s Radar On",args[2]))
                        local grp = args[1]  -- Wrapper.Group#GROUP
                        local name = args[2] -- #string Group Nam
if DCAF.GBAD.Debug then
DebugMessageTo(nil, "nisse - SUPPRESSION STOP :: name: " .. name .. " :: now: " .. timer.getTime())
end
                        if self.UseEmissionsOnOff then
                            grp:EnableEmission(true)
                        end
                        grp:OptionAlarmStateRed()
                        grp:OptionEngageRange(self.EngagementRange)
                        self.SuppressedGroups[name] = false
                        if self.UseCallBack then
                            local object = self.CallBack
                            object:SeadSuppressionEnd(grp,name)
                        end
                    end

                    -- randomize switch-on time
                    local delay = math.random(self.TargetSkill[_targetskill].DelayOn[1], self.TargetSkill[_targetskill].DelayOn[2])
                    if delay > _tti then delay = delay / 2 end -- speed up
                    if _tti > 600 then delay =  _tti - 90 end -- shot from afar, 600 is default shorad ontime

                    local now = timer.getTime()
                    local SuppressionStartTime = now + delay
                    local SuppressionEndTime = now + delay*2 + _tti + self.Padding
Debug("nisse - SUPPRESSION :: delay: " .. Dump(delay) .. " :: _tti: " .. Dump(_tti) .. " :: START time: " .. SuppressionStartTime .. " :: END time: " .. SuppressionEndTime)
                    local _targetgroupname = _targetgroup:GetName()
                    if not self.SuppressedGroups[_targetgroupname] then
                        self:T(string.format("*** SEAD - %s | Parameters TTI %ds | Switch-Off in %ds", _targetgroupname, _tti, delay))
                        timer.scheduleFunction(SuppressionStart,{_targetgroup,_targetgroupname, SEADGroup}, SuppressionStartTime)
                        timer.scheduleFunction(SuppressionStop,{_targetgroup,_targetgroupname}, SuppressionEndTime)
                        self.SuppressedGroups[_targetgroupname] = true
                        if self.UseCallBack then
                            local object = self.CallBack
                            object:SeadSuppressionPlanned(_targetgroup, _targetgroupname, SuppressionStartTime, SuppressionEndTime, SEADGroup)
                        end
                    end
                end
            end
        end
        return self
    end

    return iads
end

function SAM_AREA:OnRefreshMenus(func)
    self._refreshMenusFunc = func
end

local function refreshAreaMenus(area, defaultFunc)
    if isFunction(area._refreshMenusFunc) then
        area._refreshMenusFunc(area)
    else
        defaultFunc(area)
    end
end

local function buildMANTIS_IADS(area)
    if area.IADS then
        teardownIADS(area)
    end
    if area.IADS_Type ~= IADS_Types.MANTIS then
        return end

    local info = area.MANTIS_Info
    local isAdvanced = isAssignedString(info.HQ)
    if not info.Spawned_HQ then
        info.Spawned_HQ = area:Spawn(info.HQ)
    end
    area.IADS = MANTIS:New(area.Name .. " IADS", info.SAMPrefix, info.EWRPrefix, info.HQ, "red", isAdvanced)
    if info.SHORADPrefix then
        local setSAMs = SET_GROUP:New():FilterPrefixes(info.SAMPrefix):FilterCoalitions({"red"}):FilterStart()
        local shorad = SHORAD:New(area.Name .. " SHORADS", info.SHORADPrefix, setSAMs, nil, nil, "red")
        area.IADS:AddShorad(shorad, 720)
    end
    area.IADS:SetAdvancedMode(isAdvanced)
    area.IADS:SetDetectInterval(10)

function area.IADS:OnAfterSeadSuppressionPlanned(From, Event, To, Group, Name, SuppressionStartTime, SuppressionEndTime)
    Debug("nisse - GBAD / buildMANTIS_IADS :: SAM Suppression planned for '" .. Name  .. "'")
end

    if info.Debug then
        area.IADS:Debug(true)
    end
    area.IADS:Start()
    local message = "MANTIS IADS is active"
    -- MessageTo(nil, message)
    Trace(TracePrefix .. message)
end


-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                            SKYNET IADS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function SAM_AREA:WithSkynet(sSAMPrefix, sSHORADPrefix, sEWRPrefix, sHQ)
    if not isAssignedString(sSAMPrefix) then
        error("SAM_AREA:WithSkynet :: `sSAMPrefix` must be assigned string") end

    self.Skynet_Info = IADS_INFO:New(sSAMPrefix, sSHORADPrefix, sEWRPrefix, sHQ)
    return self
end

local function buildSkynet_IADS(area)
    if area.IADS then
        teardownIADS(area)
    end
    if area.IADS_Type ~= IADS_Types.Skynet then
        return end

    local info = area.MANTIS_Info
    area.IADS = SkynetIADS:create(area.Name .. " IADS")
    area.IADS:addSAMSitesByPrefix(info.SAMPrefix)
    area.IADS:addEarlyWarningRadarsByPrefix(info.EWRPrefix)
    area.IADS:activate()
    area.IADS:addRadioMenu()
    Trace(TracePrefix .. "Skynet IADS is active")
end


-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                            SAM SITES
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local SAM_SITE_BASE = {
    ClassName = "SAM_SITE_BASE",
    Group = nil,
    AAA = {
        -- list of #GROUP (AAA groups)
    },
    MANPADS = {
        -- list of #GROUP (MANPAD groups)
    }
}

function SAM_SITE_BASE:New(area, group, aaaGroups, manpadGroups)
    local samSite = DCAF.clone(SAM_SITE_BASE)
    samSite.Group = group
    samSite.AAA = aaaGroups or {}
    samSite.MANPAD = manpadGroups or {}
    if not group:IsActive() then
        group:Activate()
    end
    for _, aaa in ipairs(samSite.AAA) do
        if not aaa:IsActive() then
            aaa:Activate()
        end
    end
    for _, manpad in ipairs(samSite.MANPAD) do
        if not manpad:IsActive() then
            manpad:Activate()
        end
    end
    buildSkynet_IADS(area)
    return samSite
end

function SAM_SITE_BASE:Destroy()
    if self.Group then
        self.Group:Destroy()
    end
    if isTable(self.AAA) then
        for _, aaa in ipairs(self.AAA) do
            aaa:Destroy()
        end
    end
    if isTable(self.MANPAD) then
        for _, manpad in ipairs(self.MANPAD) do
            manpad:Destroy()
        end
    end
end

function SAM_SITE_BASE:IsManaged(group)
    if self.Group.GroupName == group.GroupName then
        return true end

    if isTable(self.AAA) then
        for _, aaa in ipairs(self.AAA) do
            if aaa.GroupName == group.GroupName then return true end
        end
    end
    if isTable(self.MANPAD) then
        for _, manpad in ipairs(self.MANPAD) do
            if manpad.GroupName == group.GroupName then return true end
        end
    end
end

local SAM_SITE = { -- inherits SAM_SITE_BASE
    ClassName = "SAM_SITE",
    Shorads = {
        -- list of #SAM_SITE
    }
}

function SAM_SITE:New(area, group, shoradSites, aaaGroups, manpadGroups)
    local samSite = DCAF.clone(SAM_SITE)
    samSite.Group = group
    samSite._base = SAM_SITE_BASE:New(area, group, aaaGroups, manpadGroups)
    samSite.Shorads = shoradSites or {}
    for _, shoradSite in ipairs(samSite.Shorads) do
        if not shoradSite.Group:IsActive() then
            shoradSite.Group:Activate()
        end
    end
    return samSite
end

function SAM_SITE:Destroy()
    self._base:Destroy()
    for _, shorad in ipairs(self.Shorads) do
        shorad:Destroy()
    end
end

function SAM_SITE:IsManaged(group)
    if self._base:IsManaged(group) then
        return true end

    for _, shoradGroup in ipairs(self.Shorads) do
        if not shoradGroup.Group:IsActive() then
            if shoradGroup.GroupName == group.GroupName then return true end
        end
    end
end

local SPAWNED_SAM_SITE = {
    Spawner = nil,              -- #SPAWN (MOOSE object)
    SamSites = { 
                                -- list of #SAM_SITE
    }
}

function SPAWNED_SAM_SITE:New(template, alias)
    local s3 = DCAF.clone(SPAWNED_SAM_SITE)
    s3.Spawner = SPAWN:NewWithAlias(template, alias)
    return s3
end

function SPAWNED_SAM_SITE:IsManaged(group)
    for _, samSite in ipairs(self.SamSites) do
        if samSite:IsManaged(group) then 
            return true end
    end 
end

local TRAINING_SAM_SITES = { -- dictionary
    -- key = SAM type (eg. 'SA-5')
    -- value = { list of #SPAWNED_SAM_SITE }
}

local function destroySAMSites(area, template)

    local function destroyAllForTenplate(template)
        local s3 = area.SpawnedSamSites[template]
        if not s3 then
            return end
    
        local countRemoved = 0
        for _, samSite in ipairs(s3.SamSites) do
            samSite:Destroy()
            countRemoved = countRemoved+1
        end
        if countRemoved > 0 then
            local message = "Removed " .. Dump(countRemoved) .. " '" .. template .. "' SAM sites from '" .. area.Name .. "'"
            -- MessageTo(nil, message)
            Trace(TracePrefix .. message)
        end
    end

    if isAssignedString(template) then
        destroyAllForTenplate(template)
        return
    end

    for template, _ in pairs(area.SpawnedSamSites) do
        destroyAllForTenplate(template)
    end

end

local function spawnRandomAAA(area, samGroup)
    local aaaGroups = {}
    if #area.AAA == 0 then
        return aaaGroups end

    local aaa = DCAF.GBAD.Difficulty.AAA
    if not isTable(aaa) then
        return aaaGroups end

    local count = math.random(aaa.Min, aaa.Max)
    if count == 0 then
        return aaaGroups end
    
    local coord = samGroup:GetCoordinate()
    local range = DCAF.GBAD.Difficulty.AAA.Range
    for i = 1, count, 1 do
        local vec2 = coord:GetRandomVec2InRadius(range)
        local aaaCoord = COORDINATE:NewFromVec2(vec2)
        local countRetry = 6
        while not aaaCoord:IsSurfaceTypeLand() and countRetry > 0 do
            aaaCoord = COORDINATE:NewFromVec2(coord:GetRandomVec2InRadius(range))
            countRetry = countRetry-1
        end
        if countRetry == 0 then
            break end -- just protecting from locking the sim due to some unforseen use case where there's no land available (should never happen)

        local spawn = listRandomItem(area.AAA) --  math.random(1, #area.AAA) obsolete
        -- local spawn = area.AAA[index] obsolete
        table.insert(aaaGroups, spawn:SpawnFromVec2(vec2))
    end
    return aaaGroups 
end

local function spawnRandomMANPADS(area, samGroup)
    local manpadGroups = {}
    if #area.MANPAD == 0 then
        return manpadGroups end

    local manpad = DCAF.GBAD.Difficulty.MANPAD
    if not isTable(manpad) then
        return manpadGroups end

    local count = math.random(manpad.Min, manpad.Max)
    if count == 0 then
        return manpadGroups end
    
    local coord = samGroup:GetCoordinate()
    local range = DCAF.GBAD.Difficulty.MANPAD.Range
    for i = 1, count, 1 do
        local vec2 = coord:GetRandomVec2InRadius(range)
        local manpadCoord = COORDINATE:NewFromVec2(vec2)
        local countRetry = 6
        while not manpadCoord:IsSurfaceTypeLand() and countRetry > 0 do
            manpadCoord = COORDINATE:NewFromVec2(coord:GetRandomVec2InRadius(range))
            countRetry = countRetry-1
        end
        if countRetry == 0 then
            break end -- just protecting from locking the sim due to some unforseen use case where there's no land available (should never happen)

        local index = math.random(1, #area.MANPAD)
        local spawn = area.MANPAD[index]
        table.insert(manpadGroups, spawn:SpawnFromVec2(vec2))
    end
    return manpadGroups
end

local function spawnRandomSHORADs(area, samGroup)
    local shoradSites = {}
    if #area.SHORAD == 0 then
        return shoradSites end

    local shorad = DCAF.GBAD.Difficulty.SHORAD
    if not isTable(shorad) then
        return shoradSites end

    local count = math.random(shorad.Min, shorad.Max)
    if count == 0 then
        return shoradSites end
    
    local coord = samGroup:GetCoordinate()
    local range = DCAF.GBAD.Difficulty.SHORAD.Range
    for i = 1, count, 1 do
        local vec2 = coord:GetRandomVec2InRadius(range)
        local shoradCoord = COORDINATE:NewFromVec2(vec2)
        local countRetry = 6
        while not shoradCoord:IsSurfaceTypeLand() and countRetry > 0 do
            shoradCoord = COORDINATE:NewFromVec2(coord:GetRandomVec2InRadius(range))
            countRetry = countRetry-1
        end
        if countRetry == 0 then
            break end -- just protecting from locking the sim due to some unforseen use case where there's no land available (should never happen)

        local index = math.random(1, #area.MANPAD)
        local spawn = area.SHORAD[index]
        local shoradGroup = spawn:SpawnFromVec2(vec2)
        local aaaGroups = spawnRandomAAA(area, shoradGroup)
        local manpadGroups = spawnRandomMANPADS(area, shoradGroup)
        local shoradSite = SAM_SITE:New(area, shoradGroup, nil, aaaGroups, manpadGroups)
        table.insert(shoradSites, shoradSite)
    end
    return shoradSites
end

local function makeAlias(area, template)
    return template .. "@".. area.Name
end

local function spawnSAMSite(area, template, vec2, destroyExisting, shorads)
    local alias = makeAlias(area, template)
    local s3 = area.SpawnedSamSites[alias]
    if s3 then 
        if destroyExisting then
            for _, samSite in ipairs(s3.SamSites) do
                samSite:Destroy()
            end
        end
    else
        s3 = SPAWNED_SAM_SITE:New(template, alias)
        area.SpawnedSamSites[alias] = s3
    end
    local samGroup = s3.Spawner:SpawnFromVec2(vec2)
    local aaaGroups = spawnRandomAAA(area, samGroup)
    local manpadGroups = spawnRandomMANPADS(area, samGroup)
    local shorads = spawnRandomSHORADs(area, samGroup)
    table.insert(s3.SamSites, SAM_SITE:New(area, samGroup, shorads, aaaGroups, manpadGroups))
    local message
    if area.IADS then
        message = "SAM site was spawned: " .. template .. " (" .. area.IADS_Type .. " IADS is ON)"
    else
        message = "SAM site was spawned: " .. template .. " (IADS is OFF)"
    end
    -- MessageTo(nil, message)
    Trace(TracePrefix .. message)
    return samGroup
end

function SAM_AREA:Spawn(template, destroyExisting)
    if #self.Zones == 0 then
        return self end

    local zoneIndex = math.random(1, #self.Zones)
    local zone = self.Zones[zoneIndex]
    local vec2 = zone:GetRandomVec2()
    local coord = COORDINATE:NewFromVec2(vec2)

    -- only spawn on land and no closer to "scenery" than 100 meters (right now I don't know how to filter on different types of scenery -Jonas)
    while not coord:IsSurfaceTypeLand() or coord:FindClosestScenery(100) do
        vec2 = zone:GetRandomVec2()
        coord = COORDINATE:NewFromVec2(vec2)
    end

    return spawnSAMSite(self, template, vec2, destroyExisting)
end

function SAM_AREA:Destroy(template)
    if isAssignedString(template) then
        destroySAMSites(self, template)
        return
    end

    -- destroy all SAM sites ...
    for template, s3 in pairs(self.SpawnedSamSites) do
        destroySAMSites(self, template)
    end
end

--- returns a value indicating whether a controllable is currently in the SAM_AREA
function SAM_AREA:IsManaged(source)
    local group = getGroup(source)
-- Debug("nisse - SAM_AREA:IsManaged :: area: " .. self.Name .. " :: group: " .. Dump(group.GroupName))
    if group ~= nil then
        local key = string.gsub("@"..self.Name, "[(]+", "%%(")
        key = string.gsub(key, "[)]+", "%%)")
        local isManaged  = string.find(group.GroupName, key) ~= nil
-- Debug("nisse - SAM_AREA:IsManaged : " .. Dump(isManaged))
        return isManaged
    end

    local location = DCAF.Location:Resolve(source)
    if not location then
        errorOnDebug("SAM_AREA:IsIn :: cannot resolve source: " .. DumpPretty(source))
        return
    end
    local provider = location.Source
    for _, s3 in pairs(self.SpawnedSamSites) do
        if s3:IsManaged(provider) then return true end
    end
end

------------------------- AAA, MANPAD and SHORAD templates ----------------------------

function DCAF.GBAD:WithDifficulty(difficulty)
    if not isTable(difficulty) or difficulty.ClassName ~= "GBAD_DIFFICULTY" then
        error("SAM_TRAINING:WithDifficulty :: unexpected difficulty value: " .. DumpPretty(difficulty)) end

    DCAF.GBAD.Difficulty = difficulty
    return DCAF.GBAD
end

function DCAF.GBAD:WithSimulatedSAMMissiles(weaponSimulation)
    if weaponSimulation ~= nil then
        if not isClass(weaponSimulation, DCAF.WeaponSimulation.ClassName) then
            error("DCAF.GBAD:WithSimulatedSAMMissiles :: `weaponSimulation` must be of type " .. DCAF.WeaponSimulation.ClassName) end

        DCAF.GBAD.WeaponsSimulation = weaponSimulation
    else
        local config = DCAF.WeaponSimulationConfig:New(Coalition.Red, GroupType.Ground)
        DCAF.GBAD.WeaponsSimulation = DCAF.WeaponSimulation:New(nil, config):Start()
    end
    return DCAF.GBAD
end

local function addArea(sName, bIsInvisible, ...)
    if not isAssignedString(sName) then
        error("SAM_TRAINING:AddArea :: `sName` must be assigned string but was: " .. DumpPretty(sName)) end

    local area = DCAF.clone(SAM_AREA)
    area.Name = sName
    area.SetZones = SET_ZONE:New()
    area.IsInvisible = bIsInvisible
    for i = 1, #arg, 1 do
        local zoneName = arg[i]
        if isAssignedString(zoneName) then
            local zone = ZONE:FindByName(zoneName)
            if zone then
                table.insert(area.Zones, zone)
                area.SetZones:AddZone(zone)
            else
                local group = GROUP:FindByName(zoneName)
                if not group then
                    error("SAM_TRAINING:AddArea :: zone/group could not be found: '" .. zoneName .. "'")
                    return 
                end
                zone = ZONE_POLYGON:New(sName, group)
                table.insert(area.Zones, zone)
                area.SetZones:AddZone(zone)
            end
        end
    end
    table.insert(DCAF.GBAD.Areas, area)
    return area
end

function DCAF.GBAD:AddArea(sName, ...)
    return addArea(sName, false, ...)
end

function DCAF.GBAD:AddInvisibleArea(sName, ...)
    return addArea(sName, true, ...)
end

function SAM_AREA:WithEWR(displayName, template)
    self.EWR[displayName] = template
    return self
end

function SAM_AREA:WithSAM(displayName, template)
    self.SAM[displayName] = template
    return self
end

function SAM_AREA:WithAAA(template)
    local alias = makeAlias(self, template)
    table.insert(self.AAA, SPAWN:NewWithAlias(template, alias))
    return self
end

function SAM_AREA:WithMANPAD(template)
    local alias = makeAlias(self, template)
    table.insert(self.MANPAD, SPAWN:NewWithAlias(template, alias))
    return self
end

function SAM_AREA:WithSHORAD(template)
    local alias = makeAlias(self, template)
    table.insert(self.SHORAD, SPAWN:NewWithAlias(template, alias))
    return self
end

----------------------------- F10 MENUS (great for training) -----------------------------

local _menuBuiltFor = nil

-- Settings ...
local SETTINGS_MENUS = {
    MainMenu = nil,
    SkyNetMenu = nil
}

local _buildCoalitionSettings
local function buildCoalitionSettings(gbad, menus, parentMenu, forCoalition)
    if not menus.MainMenu then
        menus.MainMenu = MENU_COALITION:New(forCoalition, "Settings", parentMenu)
    else
        menus.MainMenu:RemoveSubMenus()
    end

    -- Difficulty...
    local difficultyMenu = MENU_COALITION:New(forCoalition, DCAF.GBAD.Difficulty.Desc, menus.MainMenu)
    for key, difficulty in pairs(DCAF.GBAD_DIFFICULTY) do
        MENU_COALITION_COMMAND:New(forCoalition, difficulty.Desc, difficultyMenu, function() 
            DCAF.GBAD.Difficulty = difficulty
            _buildCoalitionSettings(gbad, menus, parentMenu, forCoalition)
        end)
    end
end
_buildCoalitionSettings = buildCoalitionSettings

function SETTINGS_MENUS:BuildCoalition(gbad, parentMenu, forCoalition)
    if not isNumber(forCoalition) then
        forCoalition = coalition.side.BLUE
    end
    buildCoalitionSettings(gbad, self, parentMenu, forCoalition)
end

function SETTINGS_MENUS:BuildGroup(parentMenu, group)
    if not self.MainMenu then
        self.MainMenu = MENU_GROUP:New(group, "Settings", parentMenu)
    end

    self.MainMenu:RemoveSubMenus()

    -- Difficulty
    local difficultyMenu = MENU_GROUP:New(group, DCAF.GBAD.Difficulty.Desc, self.MainMenu)
    for key, difficulty in pairs(DCAF.GBAD_DIFFICULTY) do
        MENU_GROUP_COMMAND:New(group, difficulty.Desc, difficultyMenu, function() 
            DCAF.GBAD.Difficulty = difficulty
            self:BuildGroup(group)
        end)
    end
end

function SETTINGS_MENUS:Reset()
    self.MainMenu = nil
    self.SkyNetMenu = nil
end

local _area_buildMANTISCoalitionMenuFunc
local _area_buildMANTISCoalitionMenuParentMenu
local function buildMANTISCoalitionMenu(area, forCoalition, parentMenu, rebuildMenusFunc)
    if not area.MANTIS_Info then
        return end

    if rebuildMenusFunc == nil then
        rebuildMenusFunc = _area_buildMANTISCoalitionMenuFunc
    end
    parentMenu = parentMenu or _area_buildMANTISCoalitionMenuParentMenu
    _area_buildMANTISCoalitionMenuParentMenu = parentMenu
    if area.IADS_Type == IADS_Types.MANTIS then
        MENU_COALITION_COMMAND:New(forCoalition, "Deactivate " .. IADS_Types.MANTIS, parentMenu, function()
            -- MessageTo(nil, IADS_Types.MANTIS .. " is turned OFF in '" .. area.Name .. "'")
            teardownIADS(area, true)
            rebuildMenusFunc(area, forCoalition, parentMenu, rebuildMenusFunc)
        end)
    else
        MENU_COALITION_COMMAND:New(forCoalition, "Activate " .. IADS_Types.MANTIS, parentMenu, function() 
            area.IADS_Type = IADS_Types.MANTIS
            -- MessageTo(nil, IADS_Types.MANTIS .. " is activated in '" .. area.Name .. "'")
            buildMANTIS_IADS(area) 
            rebuildMenusFunc(area, forCoalition, parentMenu, rebuildMenusFunc)
        end)
    end
end
_area_buildMANTISCoalitionMenuFunc = buildMANTISCoalitionMenu

local _area_buildMANTISGroupMenuFunc
local function buildMANTISGroupMenu(area, forGroup, parentMenu, rebuildMenusFunc)
    if not area.Skynet_Info then
        return end

    if rebuildMenusFunc == nil then
        rebuildMenusFunc = _area_buildMANTISGroupMenuFunc
    end
    if area.IADS_Type == IADS_Types.MANTIS then
        MENU_GROUP_COMMAND:New(forGroup, "Deactivate " .. IADS_Types.MANTIS, parentMenu, function()
            -- MessageTo(nil, IADS_Types.MANTIS .. " is turned OFF in '" .. area.Name .. "'")
            teardownIADS(area)
            rebuildMenusFunc(area, forGroup, parentMenu)
        end)
    else
        MENU_GROUP_COMMAND:New(forGroup, "Activate " .. IADS_Types.MANTIS, parentMenu, function() 
            area.IADS_Type = IADS_Types.MANTIS
            -- MessageTo(nil, IADS_Types.MANTIS .. " is activated in '" .. area.Name .. "'")
            buildMANTIS_IADS(area) 
            rebuildMenusFunc(area, forGroup, parentMenu)
        end)
    end
end
_area_buildMANTISGroupMenuFunc = buildMANTISGroupMenu

local _area_buildSkynetCoalitionMenuFunc
local function buildSkynetCoalitionMenu(area, forCoalition, parentMenu, rebuildFunc)

-- Debug("nisse - buildMANTISCoalitionMenu :: area.IADS_Type: " .. Dump(area.IADS_Type))

    if not area.Skynet_Info then
        return end

    if area.IADS_Type == IADS_Types.Skynet then
        MENU_COALITION_COMMAND:New(forCoalition, "Deactivate " .. IADS_Types.Skynet, parentMenu, function()
            -- MessageTo(nil, "Skynet is turned OFF in '" .. area.Name .. "'")
            teardownIADS(area)
            _area_buildSkynetCoalitionMenuFunc(area, forCoalition, parentMenu)
        end)
    else
        MENU_COALITION_COMMAND:New(forCoalition, "Activate " .. IADS_Types.Skynet, parentMenu, function() 
            area.IADS_Type = IADS_Types.Skynet
            -- MessageTo(nil, IADS_Types.Skynet .. " is activated in '" .. area.Name)
            buildSkynet_IADS(area) 
            _area_buildSkynetCoalitionMenuFunc(area, forCoalition, parentMenu)
        end)
    end
end
_area_buildSkynetCoalitionMenuFunc = buildSkynetCoalitionMenu

local _area_buildSkynetGroupMenuFunc
local function buildSkynetGroupMenu(area, forGroup, parentMenu)
    if not area.Skynet_Info then
        return end

    if area.IADS_Type == IADS_Types.MANTIS then
        MENU_GROUP_COMMAND:New(forGroup, "Deactivate Skynet", parentMenu, function()
            MessageTo(forGroup, "Skynet is turned OFF in '" .. area.Name .. "'")
            teardownIADS(area)
            refreshAreaMenus(area, function()
                _area_buildSkynetGroupMenuFunc(area, forGroup, parentMenu)
            end)
        end)
    else
        MENU_GROUP_COMMAND:New(forGroup, "Activate Skynet", parentMenu, function() 
            area.IADS_Type = IADS_Types.Skynet
            MessageTo(forGroup, "Skynet is activated in '" .. area.Name .. "' (all SAMs are added to IADS)")
            buildSkynet_IADS(area) 
            refreshAreaMenus(area, function()
                _area_buildSkynetGroupMenuFunc(area, forGroup, parentMenu)
            end)
        end)
    end
end
_area_buildSkynetGroupMenuFunc = buildSkynetGroupMenu

function DCAF.GBAD:BuildF10CoalitionIADSMenus(area, menuText, parentMenu, forCoalition, rebuildMenusFunc)
    if not isClass(area, SAM_AREA.ClassName) then
        error("DCAF.GBAD:BuildF10CoalitionIADSMenus :: `area` must be a #" .. SAM_AREA.ClassName .. ", but was: " .. DumpPretty(area)) end

    if not isAssignedString(menuText) then
        menuText = "IADS"
    end
    if forCoalition == nil then
        forCoalition = coalition.side.BLUE
    end
    -- if parentMenu == nil then
    --     parentMenu = MENU_COALITION:New(forCoalition, menuText)
    -- end
    if not area.IADS_Type or area.IADS_Type == IADS_Types.MANTIS then
        buildMANTISCoalitionMenu(area, forCoalition, parentMenu, rebuildMenusFunc)
    end
    if not area.IADS_Type or area.IADS_Type == IADS_Types.Skynet then
        buildSkynetCoalitionMenu(area, forCoalition, parentMenu, rebuildMenusFunc)
    end
-- Debug("nisse - DCAF.GBAD:BuildF10CoalitionIADSMenus :: parentMenu: " .. DumpPrettyDeep(parentMenu, 2))
end

function DCAF.GBAD:BuildF10GroupIADSMenus(area, menuText, parentMenu, forGroup, rebuildMenusFunc)
    if not isClass(area, SAM_AREA.ClassName) then
        error("DCAF.GBAD:BuildF10CoalitionIADSMenus :: `area` must be a #" .. SAM_AREA.ClassName .. ", but was: " .. DumpPretty(area)) end

    local group = getGroup(forGroup)
    if not group then
        error("DCAF.GBAD:BuildF10CoalitionIADSMenus :: could not resolve `group` from: " .. DumpPretty(forGroup)) end
    
    if not isAssignedString(menuText) then
        menuText = "IADS"
    end
    if forCoalition == nil then
        forCoalition = coalition.side.BLUE
    end
    if parentMenu == nil then
        parentMenu = MENU_COALITION:New(forCoalition, menuText)
    end
    if not area.IADS_Type or area.IADS_Type == IADS_Types.MANTIS then
        buildMANTISGroupMenu(area, group, parentMenu, rebuildMenusFunc)
    end
    if not area.IADS_Type or area.IADS_Type == IADS_Types.Skynet then
        buildSkynetGroupMenu(area, group, parentMenu, rebuildMenusFunc)
    end
end

local _DEFAULT_menuText = "GBAD"
local _coalition_area_menus = { -- ductionary
  -- key = <area name>
  -- value = MENU_COALITION
}
function DCAF.GBAD:BuildF10CoalitionMenus(menuText, parentMenu, forCoalition, addAreaIADS)
    if _menuBuiltFor then
        error("DCAF.GBAD:BuildF10CoalitionMenus :: menu was already built") end

    if not isAssignedString(menuText) then
        menuText = _DEFAULT_menuText
    end
    if forCoalition == nil then
        forCoalition = coalition.side.BLUE
    end
    if parentMenu == nil then
        parentMenu = MENU_COALITION:New(forCoalition, menuText)
    end
    if not isBoolean(addAreaIADS) then
        addAreaIADS = true
    end
    SETTINGS_MENUS:BuildCoalition(self, parentMenu, forCoalition)

    local buildAreaMenuFunc
    local function buildAreaMenu(area)
        local areaMenu = _coalition_area_menus[area.Name]
        if areaMenu then
            areaMenu:RemoveSubMenus()
        else
            areaMenu = MENU_COALITION:New(forCoalition, area.Name, parentMenu)
            _coalition_area_menus[area.Name] = areaMenu
        end
        if addAreaIADS then
            buildMANTISCoalitionMenu(area, forCoalition, areaMenu, buildAreaMenuFunc)
            buildSkynetCoalitionMenu(area, forCoalition, areaMenu, buildAreaMenuFunc)
        end
        MENU_COALITION_COMMAND:New(forCoalition, "Remove all", areaMenu, function() 
            area:Destroy()
        end)
        local parentMenu
        if area.EWR then
            if not area.SAM then
                parentMenu = areaMenu
            else
                parentMenu = MENU_COALITION:New(forCoalition, "EWR", areaMenu)
            end
            for displayName, template in pairs(area.EWR) do
                local samMenu = MENU_COALITION:New(forCoalition, displayName, parentMenu)
                MENU_COALITION_COMMAND:New(forCoalition, "Add", samMenu, function() 
                    area:Spawn(template)
                end)
                MENU_COALITION_COMMAND:New(forCoalition, "Remove all", samMenu, function() 
                    area:Destroy(template)
                end)
            end
        end
        if area.SAM then
            if not area.EWR then
                parentMenu = areaMenu
            else
                parentMenu = MENU_COALITION:New(forCoalition, "SAM", areaMenu)
            end
            for displayName, template in pairs(area.SAM) do
                local samMenu = MENU_COALITION:New(forCoalition, displayName, parentMenu)
                MENU_COALITION_COMMAND:New(forCoalition, "Add", samMenu, function() 
                    area:Spawn(template)
                end)
                MENU_COALITION_COMMAND:New(forCoalition, "Remove all", samMenu, function() 
                    area:Destroy(template)
                end)
            end
        end
    end
    buildAreaMenuFunc = buildAreaMenu

    for i, area in ipairs(DCAF.GBAD.Areas) do
        if not area.IsInvisible then
            buildAreaMenu(area)
        end
    end
end


function DCAF.GBAD:BuildF10GroupMenus(menuText, parentMenu, group, addAreaIADS)
    if _menuBuiltFor then
        error("DCAF.GBAD:BuildF10CoalitionMenus :: menu was already built") end

    local forGroup = getGroup(group)
    if forGroup == nil then
        error("DCAF.GBAD:BuildF10GroupMenus :: cannot resolve group from: " .. DumpPretty(group)) end
    
    if not isAssignedString(menuText) then
        menuText = _DEFAULT_menuText
    end
    if parentMenu == nil then
        parentMenu = MENU_GROUP:New(forGroup, menuText)
    end
    if not isBoolean(addAreaIADS) then
        addAreaIADS = true
    end
    SETTINGS_MENUS:BuildCoalition(self, parentMenu)
    for i, area in ipairs(DCAF.GBAD.Areas) do
        local areaMenu = MENU_GROUP:New(forGroup, area.Name, parentMenu)
        if addAreaIADS then
            buildMANTISGroupMenu(area, forGroup, areaMenu)
            buildSkynetGroupMenu(area, forGroup, areaMenu)
        end
        MENU_GROUP_COMMAND:New(forGroup, "Remove all", areaMenu, function() 
            area:Destroy()
        end)
        for displayName, template in pairs(area.SAM) do
            local samMenu = MENU_GROUP:New(forGroup, displayName, areaMenu)
            MENU_GROUP_COMMAND:New(forGroup, "Add", samMenu, function() 
                area:Spawn(template)
            end)
            MENU_GROUP_COMMAND:New(forGroup, "Remove all", samMenu, function() 
                area:Destroy(template)
            end)
        end
    end
end

function DCAF.GBAD:RemoveF10AreaCoalitionMenus(area)
    if area == nil then
        _coalition_area_menus = {}
    else
        _coalition_area_menus[area.Name] = nil
    end
end

function DCAF.GBAD:ResetSettingsMenu()
    SETTINGS_MENUS:Reset()
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                              SAM MISSILE SIMULATION BEHAVIOR
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Trace("\\\\\\\\\\ DCAF.GBAD.lua was loaded //////////")