--DCAF.TTSChannel.SimulateAllTTS() -- uncomment to allow text-to-speech (Google synthetic voices)
-- set up text-to-speech for Growler...
local ttsGrowler1 = DCAF.TTSChannel:New("Growler 1", 148.5, radio.modulation.AM):InitVoice("en-GB-Neural2-B")

-- sets up a "Growler" projecting a jamming 'lobe' with a 10nm radius...
Banshee_Jammer = DCAF.Jammer:New("Growler 1", ttsGrowler1, nil, NauticalMiles(10))
                       :Debug(true, true) --, Coalition.Blue)
                        --    :JamLocation("TGT")
                        --    :JamFromTrack("TGT", "JAMMER_1", NauticalMiles(5), Feet(25000), NauticalMiles(30), 360)
                        --    :StartJammer("TGT")

local zoneTrack = ZONE:FindByName("JAMMER_1")
if zoneTrack then
    Banshee_Jammer:JamFromTrack("TGT", zoneTrack, Feet(25000), NauticalMiles(30), 360)
end

-- react to Growler starts jamming...
function Banshee_Jammer:OnStartJammer(locECM, width, types)
    SetFlag("test_hogs") -- activate 2 A-10s as Guinea pigs, flying well inside the SAMs engagement ring
    Banshee_Jammer:Send("[CALLSIGN] is music ON!") -- transmit message on 148.50
end

-- set up F10 player menu to allow activating/deactivating jammer mid flight...
MENU_MISSION_COMMAND:New("Jammer ON/OFF", nil, function()
    if Banshee_Jammer:IsJamming() then
        Banshee_Jammer:StopJammer()
    else
        Banshee_Jammer:StartJammer()
    end
end)


Debug("|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||")
local sam = getGroup("TEST")
for _, u in ipairs(sam:GetUnits()) do
    Debug("nisse - TEST unit: " .. u:GetTypeName())
end