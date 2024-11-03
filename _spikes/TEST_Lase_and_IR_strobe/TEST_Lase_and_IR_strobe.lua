-- requires loaded: 
-- MOOSE
-- DCAF.Core

-- local jtac_strobeProgram = DCAF.StrobeProgram:New(3)
local jtac_lase = DCAF.Lase:New("JTAC"
                                -- , 1688
                                -- , jtac_strobeProgram
                            )
local T80_lased = false
local jtac_strobe_active = false
local ifv_strobe_active = false

local ifv_lase = DCAF.Lase:New("IFV")

local function lase_t80_toggle()
    if T80_lased then
        jtac_lase:Stop()
    else
        jtac_lase:Start("RED MBT T-80")
    end
    T80_lased = not T80_lased
end

local function lase_strobe_toggle()
    -- local su = STROBE_UNIT:FindByName("JTAC-1")
    -- su:StartStrobe(3)
    if jtac_strobe_active then
        jtac_lase:Stop()
    else
        jtac_lase:StartStrobe() --jtac_strobeProgram)
    end
    jtac_strobe_active = not jtac_strobe_active
end

local function lase_strobe_moving_IFV()
    if ifv_strobe_active then
        ifv_lase:Stop()
    else
        ifv_lase:Start("IFV")
    end
    ifv_strobe_active = not ifv_strobe_active
end

MENU_COALITION_COMMAND:New(coalition.side.BLUE, "T-80 - laser toggle", nil, lase_t80_toggle)
MENU_COALITION_COMMAND:New(coalition.side.BLUE, "JTAC - strobe toggle", nil, lase_strobe_toggle)
MENU_COALITION_COMMAND:New(coalition.side.BLUE, "JTAC - strobe moving IFV", nil, lase_strobe_moving_IFV)