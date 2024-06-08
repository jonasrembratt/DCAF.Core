-- Relies on MOOSE, and Google voice synthetization https://cloud.google.com/text-to-speech/docs/voices)

DCAF.Frequency = {
    Freq = 0,
    Mod = radio.modulation.AM
}

function DCAF.Frequency:New(freq, mod)
    local f = DCAF.clone(DCAF.Frequency)
    if not isNumber(freq) then return Error("DCAF.Frequency:New :: ") end
    f.Freq = freq
    f.Mod = mod or DCAF.Frequency.Mod
    return f
end

Frequencies = {
    Guard = DCAF.Frequency:New(243)
}

local TTSChannel_DEFAULTS = {
    VoiceNormal = "en-GB-Wavenet-F",
    VoiceActual = "en-GB-Wavenet-D",
    Frequency = 357.0,
    Modulation = radio.modulation.AM,
    Callsign = "TOP DOG",
    Coalition = Coalition.Blue,
    MGRS_OmitMapComponent = false,
    _variables = {}
}

DCAF.TTSVoices = {
    AU = {
        "en-AU-Standard-A",
        "en-AU-Standard-B",
        "en-AU-Standard-C",
        "en-AU-Standard-D",
    },
    GB = {
        "en-GB-Standard-A",
        "en-GB-Standard-B",
        "en-GB-Standard-C",
        "en-GB-Standard-D",
        "en-GB-Standard-E",
        "en-GB-Standard-F",
    },
    US = {
        "en-us-Standard-A",
        "en-us-Standard-B",
        "en-us-Standard-C",
        "en-us-Standard-D",
        "en-us-Standard-E",
        "en-us-Standard-F",
        "en-us-Standard-G",
        "en-us-Standard-H",
        "en-us-Standard-I",
        "en-us-Standard-J",
        "en-US-Casual-K"
    },
    All = {
        "en-AU-Standard-A",
        "en-AU-Standard-B",
        "en-AU-Standard-C",
        "en-AU-Standard-D",
        "en-GB-Standard-A",
        "en-GB-Standard-B",
        "en-GB-Standard-C",
        "en-GB-Standard-D",
        "en-GB-Standard-E",
        "en-GB-Standard-F",
        "en-us-Standard-A",
        "en-us-Standard-B",
        "en-us-Standard-C",
        "en-us-Standard-D",
        "en-us-Standard-E",
        "en-us-Standard-F",
        "en-us-Standard-G",
        "en-us-Standard-H",
        "en-us-Standard-I",
        "en-us-Standard-J",
        "en-US-Casual-K"
    }
}

function DCAF.TTSVoices:GetRandom(pattern)
    if isAssignedString(pattern) then
        local voice = listRandomItemWhere(DCAF.TTSVoices.All, function(i)
Debug("nisse - listRandomItemWhere :: i: " .. Dump(i) .. " :: pattern: " .. pattern .. " :: find: " .. Dump(string.find(i, pattern)))
            return string.find(i, pattern)
        end)
Debug("nisse - DCAF.TTSVoices:GetRandom :: voice: " .. Dump(voice))
        return voice
    end
    return listRandomItem(DCAF.TTSVoices.All)
end

DCAF.TTSChannel = {
    ClassName = "DCAF.TTSChannel",
    ---
    Frequency = TTSChannel_DEFAULTS.Frequency,
    Callsign = TTSChannel_DEFAULTS.Callsign,
    Modulation = TTSChannel_DEFAULTS.Modulation,
    Voice = TTSChannel_DEFAULTS.VoiceNormal,        -- please note; when Voice is set Gender and Culture values are ignored
    VoiceNormal = TTSChannel_DEFAULTS.VoiceNormal,
    VoiceSpeedNormal = 1,
    VoiceActual = TTSChannel_DEFAULTS.VoiceActual,
    VoiceSpeedActual = 1,
    Gender = "female",
    Culture = "en-US",
    Coalition = TTSChannel_DEFAULTS.Coalition,
    Interval = 1 -- Minutes(1) -- ensures no message gets sent less than this interval from the last one
}

local function initTTSChannel(channel, callsign, frequency, modulation, coalition)
    channel.Callsign = callsign or channel.Callsign or DCAF.TTSChannel.Callsign
    channel.Frequency = frequency or DCAF.TTSChannel.Frequency
    channel.Modulation = modulation or DCAF.TTSChannel.Modulation
    local dcsCoalition = Coalition.Resolve(coalition or DCAF.TTSChannel.Coalition, true)
    channel.MGRS_OmitMapComponent = TTSChannel_DEFAULTS.MGRS_OmitMapComponent
    channel._variables = TTSChannel_DEFAULTS._variables
    if not dcsCoalition then
        error("initTTSChannel :: cannot resolve coalition: " .. DumpPretty(coalition)) end

    channel.Coalition = dcsCoalition
    return channel
end

local function resolveFreqAndMod(frequency, modulation)
    local freq, mod
    if isClass(frequency, DCAF.Frequency) then
        freq = frequency.Freq
        mod = frequency.Mod
    else
        freq = frequency
        mod = modulation
    end
    return freq, mod
end

--- Creates, initializes, and returns a new #DCAF.TTSChannel
-- @param #string callsign - (optional; default = 'TOP DOG') Specifies the channel callsign
-- @param #Any frequency - (optional; default = 357.000) Specifies the frequency for the channel. Number (frequency) -or- a #DCAF.Frequency; if the latter modulation can also be passed in that object
-- @param #number modulation - (optional; default = radio.modulation.AM) Specifies the modulation for the channel
-- @param #number coalition - (optional; default = coalition.side.BLUE) Specifies the modulation for the channel
function DCAF.TTSChannel:New(callsign, frequency, modulation, coalition)
    local freq, mod = resolveFreqAndMod(frequency, modulation)
    local channel = DCAF.clone(DCAF.TTSChannel)
    initTTSChannel(channel, callsign, freq, mod, coalition)
    return channel
end

--- Creates a default variable to be recognized in transmissions
-- @param #string name - name of variable (eg. "IDO")
-- @param #string value - value to be assigned to variable (eg. "COURTSIDE")
function DCAF.TTSChannel.InitDefaultVariable(name, value)
    TTSChannel_DEFAULTS._variables[name] = value
end

--- Creates a variable to be recognized in transmissions
-- @param #string name - name of variable (eg. "IDO")
-- @param #string value - value to be assigned to variable (eg. "COURTSIDE")
function DCAF.TTSChannel:InitVariable(name, value)
    self._variables[name] = value
end

--- Tunes a frequency/modulation. Current frequency can be restored with Detune()
-- @param #Any frequency - (optional; default = 357.000) Specifies the frequency for the channel. Number (frequency) -or- a #DCAF.Frequency; if the latter modulation can also be passed in that object
-- @param #number modulation - (optional; default = radio.modulation.AM) Specifies the modulation for the channel
function DCAF.TTSChannel:Tune(frequency, modulation)
    local freq, mod = resolveFreqAndMod(frequency, modulation)
    if freq and not isNumber(freq) then return Error("DCAF.TTSChannel:Tune :: `frequency` must be a number, but was: " .. DumpPretty(frequency)) end
    if modulation and modulation ~= radio.modulation.AM and modulation ~= radio.modulation.FM then Error("DCAF.TTSChannel:Tune :: `modulation` is not valid: " .. DumpPretty(modulation)) end
    self:_pushCurrentFreq()
    initTTSChannel(self, self.Callsign, freq, mod)
    return self
end

--- De-tunes current frequency, and re-tunes the previous one. This only makes sense after having invoked Tune() at least once
function DCAF.TTSChannel:Detune()
    if not self._freqStack or #self._freqStack  == 0 then return self end
    local freq = self._freqStack[#self._freqStack]
    self._freqStack[#self._freqStack] = nil
    initTTSChannel(self, nil, freq.Freq, freq.Mod)
    return self
end

function DCAF.TTSChannel:_pushCurrentFreq()
    self._freqStack = self._freqStack or {}
    self._freqStack[#self._freqStack+1] = DCAF.Frequency:New(self.Frequency, self.Modulation)
    return self
end
    
--- Initializes the two voices available (normal and actual) for the channel (see https://cloud.google.com/text-to-speech/docs/voices)
-- @param #string voice - Identifies a supported Google TTS voice
function DCAF.TTSChannel:InitVoice(voice)
    if isAssignedString(voice) then
        self.Voice = voice
        self.VoiceNormal = voice
    end
    return self
end

--- Initializes the two voices available (normal and actual) for the channel (see https://cloud.google.com/text-to-speech/docs/voices)
-- @param #string voice - Identifies a supported Google TTS voice
function DCAF.TTSChannel:InitVoiceActual(voice)
    self.VoiceActual = voice
    return self
end

--- Initializes the two voices available (normal and actual), by specifying gender and culture. This will use Windows TTS
-- @param #string genderNormal - ("female" or "male") - Identifies gender for normal voice
-- @param #string cultureNormal - Identifies culture (eg. "en-GB") for normal voice
-- @param #string genderActual - ("female" or "male") - Identifies gender for "actual" voice
-- @param #string cultureActual - Identifies culture (eg. "en-GB") for "actual" voice
function DCAF.TTSChannel:InitGenderCulture(genderNormal, cultureNormal, genderActual, cultureActual)
    if isAssignedString(genderNormal) then
        self.Voice = nil
        self.Gender = genderNormal
        self.GenderNormal = genderNormal
    end
    if isAssignedString(cultureNormal) then
        self.Voice = nil
        self.Culture = cultureNormal
        self.CultureNormal = cultureNormal
    end
    if isAssignedString(genderActual) then
        self.GenderActual = genderActual
    end
    if isAssignedString(cultureActual) then
        self.CultureActual = cultureActual
    end
    return self
end

--- Activates textual transcripts for all messages to a specified scope
-- @param #Any scope - can be a coalition (DCS number, or #Coalition), or a #UNIT, #GROUP, or name of #UNIT/#GROUP
-- @param #number duration - (optional; default=30 seconds) specifies for how long a transcript is displayed
function DCAF.TTSChannel:InitTranscript(scope, duration)
    if not scope then
        Error("DCAF.TTSChannel:InitTranscript :: `scope` was not specified :: IGNORES")
        return self
    end
    if not isNumber(duration) then duration = 30 end
    self._transcriptDuration = duration

    local validCoalition = Coalition.Resolve(scope)
    if validCoalition then
        self._transcriptScope = validCoalition
Debug("nisse - DCAF.TTSChannel:InitTranscript :: self:: " .. DumpPretty(self))
        return self
    end
    self._transcriptScope = getGroup(scope)

    if not self._transcriptScope then
        Error("DCAF.TTSChannel:InitTranscript :: `scope` must be coalition or group/unit, but was: " .. DumpPretty(scope))
        return self
    end
Debug("nisse - DCAF.TTSChannel:InitTranscript :: scope: " .. Dump(scope) .. " :: _transcriptDuration: " .. Dump(self._transcriptDuration))
    return self
end

--- Swaps all transmissions to use the voice of the 'Actual' role (the 'actual' TOP DOG)
function DCAF.TTSChannel:SetVoiceActual()
    self.Voice = self.VoiceActual
end

--- Swaps all transmissions to use the voice of the normal (not 'Actual') role
function DCAF.TTSChannel:SetVoiceNormal()
    self.Voice = self.VoiceNormal
end

function DCAF.TTSChannel:IsActual()
    return isAssignedString(self.Voice) and self.Voice == self.VoiceActual
end

--- Transmits a message, to be read by a synthetic voice at the specified frequency and modulation (see `:New` function)
-- @param #string text - The textual message to be transmitted
function DCAF.TTSChannel:Message(text, callsign, isActual, dash, isReplay)

Debug("DCAF.TTSChannel:Message :: text: " .. Dump(text))

    if not isAssignedString(text) then
        return Error("DCAF.TTSChannel:Message :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

    local function substituteVariables()
        callsign = callsign or self.Callsign
        if self:IsActual() then
            callsign = callsign .. " Actual"
        end
        text = string.gsub(text, "%[CALLSIGN%]", callsign)
        local greeting = self:GetGreetingPhrase()
        if greeting then
            text = string.gsub(text, "%[GREETING%]", greeting)
        end
        local farewell = self:GetFarewellPhrase()
        if farewell then
            text = string.gsub(text, "%[FAREWELL%]", farewell)
        end
        for key, value in pairs(self._variables) do
            text = string.gsub(text, "%[".. key .. "%]", value)
        end
        for key, value in pairs(self._variables) do
            text = string.gsub(text, "%[".. key .. "%]", value)
        end
        return text
    end

    local function substitutePhonetic()
        local QUALIFIER = 'p%['
        local QUALIFIER_SLOW = 'ps%['
        local TERMINATOR = ']'
        local slowPhonetic
        local qualifierLength
        local function findPhonetic()
            local s = string.find(text, QUALIFIER)
            if s then 
                qualifierLength = 2
            else
                s = string.find(text, QUALIFIER_SLOW)
                if s then
                    slowPhonetic = true
                    qualifierLength = 3
                else
                    return
                end
            end
            local e = string.find(text, TERMINATOR, s)
            if e then return s, e end
        end

        local s, e = findPhonetic()
        if s == nil then
            return text
        end
        local out = ""
        if s > 1 then
            out = string.sub(text, 1, s-1)
        end
        while s and e do
            local p = PhoneticAlphabet:Convert(string.sub(text, s+qualifierLength, e-1), slowPhonetic)
            out = out .. p
            text = string.sub(text, e+1)
            s, e = findPhonetic()
            if s and s > 1 then
                out = out .. string.sub(text, 1, s-1)
            end
        end
        if #text > 0 then
            out = out .. text
        end
        return out
    end

    local function substituteLocations()
        local KEYPAD_QUALIFIER = 'kp'
        local MGRS_QUALIFIER = 'gd'
        local BULLSEYE_QUALIFIER = 'be'
        -- todo consider supporting 'be' (bullseye)
        local TERMINATOR = ']'

        local function findLocation()
            local s = string.find(text, KEYPAD_QUALIFIER.."%[")
            if not s then
                s = string.find(text, MGRS_QUALIFIER.."%[")
                if not s then
                    s = string.find(text, BULLSEYE_QUALIFIER.."%[")
                    if not s then
                        return
                    end
                end
            end
            local e = string.find(text, TERMINATOR, s)
            if e then return s, string.sub(text, s, s+1), e end
        end

        local function getCoordinate(ident)
            local l = DCAF.Location.Resolve(ident)
            if l then return l:GetCoordinate() end
        end

        local s, q, e = findLocation()
        if s == nil then
            return text
        end
        local out = ""
        if s > 1 then
            out = string.sub(text, 1, s-1)
        end

        while s and q and e do
            local ident = string.sub(text, s+string.len(q)+1, e-1)
            local coord = getCoordinate(ident)
            if coord then
                local kp
                local omitMapElement = self.MGRS_OmitMapComponent or TTSChannel_DEFAULTS.MGRS_OmitMapComponent
                if q == KEYPAD_QUALIFIER then
                    -- local map, grid, keypad = coord:ToKeypad()
                    local keypad = coord:ToKeypad()
                    if not keypad then
                        kp = "KEYPAD ERROR"
                    elseif not omitMapElement then
                        kp = "Grid! " .. PhoneticAlphabet:Convert(keypad.Map .. " " .. keypad.Grid, true)  .. " Keypad " .. PhoneticAlphabet:Convert(keypad.Keypad, true)
                    else
                        kp = "Grid! " .. PhoneticAlphabet:Convert(keypad.Grid, true)  .. " Keypad " .. PhoneticAlphabet:Convert(keypad.Keypad, true)
                    end
                elseif q == MGRS_QUALIFIER then
                    local mgrs = coord:ToMGRS()
Debug("nisse - DCAF.TTSChannel_substituteLocations :: map: " .. DumpPretty(mgrs))
                    if not mgrs then
                        kp = "GRID ERROR"
                    elseif not omitMapElement then
                        kp = "Grid! " .. PhoneticAlphabet:Convert(mgrs.Map .. " " .. mgrs.Grid .. " " .. mgrs.X .. " " .. mgrs.Y, true)
                        kp = kp .. " elevation " .. PhoneticAlphabet:Convert(math.floor(mgrs.Elevation), true)
                    else
                        kp = "Grid! " .. PhoneticAlphabet:Convert(mgrs.Grid .. " " .. mgrs.X .. " " .. mgrs.Y, true)
                        kp = kp .. " elevation " .. PhoneticAlphabet:Convert(math.floor(mgrs.Elevation), true)
                    end
                elseif q == BULLSEYE_QUALIFIER then
                    local bearing, distanceNM, name = DCAF.GetBullseye(coord, self.Coalition)
                    if bearing then 
                        kp = name .. ". " .. PhoneticAlphabet:Convert(tostring(UTILS.Round(bearing))) .. ". " .. UTILS.Round(distanceNM)
                    else
                        kp = "BULLSEYE ERROR"
                    end
                end
                if kp then
                    out = out .. kp
                    text = string.sub(text, e+1)
                end
                s, q, e = findLocation()
                if s and s > 1 then
                    out = out .. string.sub(text, 1, s-1)
                end
            else
                Error("DCAF.TTSChannel:Message_substituteLocations :: could not resolve '" .. q .. "' location: " .. ident)
                text = string.sub(text, e+1)
                out = out .. string.sub(ident, 1, s-1)
                s, q, e = findLocation()
                if s and s > 1 then
                    out = out .. string.sub(text, 1, s-1)
                end
            end
        end
        if #text > 0 then
            out = out .. text
        end
        return out
    end

    local function getTranscriptHeader()
        local sFrequency = string.format("%.3f", self.Frequency)
        if self.Modulation == radio.modulation.AM then
            sFrequency = sFrequency .. " AM"
        else
            sFrequency = sFrequency .. " FM"
        end

        local duration = self.TTS_Simulated_Duration or DCAF.TTSChannel.TTS_Simulated_Duration
        return "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| TTS [" .. sFrequency .. "] |||||||||||||||||||||||||||||||||||||||||||||||||||||||||"
    end

    local function getTransctipText(message, multiline)
        local text_tts
        if multiline then
            text_tts = message
        else
            text_tts = string.sub(message, 1, 90)
        end
        return text_tts
    end

    local function send()
        local gender
        local culture
        local voice
        if isActual == true then
            self:SetVoiceActual()
        end
        if isAssignedString(self.Voice) then
            voice = self.Voice
        else
            gender = self.Gender
            culture = self.Culture
        end
        text = substituteLocations()
        text = substitutePhonetic()
        text = substituteVariables()
        local text_processed = text
        self:SetVoiceNormal()

        local function ensureSSMS()
            if stringStartsWith(text, "<speak>") then
                return text
            else
                return "<speak>" .. text .. "</speak>"
            end
        end

        local isSimulatedTTS = self.Is_TTS_Simulated or DCAF.TTSChannel.Is_TTS_Simulated
        if not isSimulatedTTS and DCAF.Environment.SRS:IsSSML() then
            text = ensureSSMS()
        end
        local volume = 1
        local now = UTILS.SecondsOfToday()
        local delay = 0
 
        local function doSend()
            if not isReplay then
                self:AddToMsgLog(text, callsign, isActual, dash)
            end
            Debug("DCAF.TTSChannel:Message :: freq: " .. Dump(self.Frequency) .. " :: mod: " .. self.Modulation .. " :: gender: " .. Dump(gender) .. " :: culture: " .. Dump(culture) .. " :: voice: " .. Dump(voice)  .. " :: coalition: " .. Dump(self.Coalition) .. " :: isSimulatedTTS: " .. Dump(isSimulatedTTS) )
            Debug("DCAF.TTSChannel:Message :: text: '" .. text .. "'")
            if isSimulatedTTS then
                local header = getTranscriptHeader()
                local delay = 0 -- math.random(1, 4)
                local duration = self.TTS_Simulated_Duration or DCAF.TTSChannel.TTS_Simulated_Duration
                MessageTo(nil, header, duration + delay)
                local isMultiLine = self.Is_TTS_Simulated_Multi_Line or DCAF.TTSChannel.Is_TTS_Simulated_Multi_Line
                local text_tts = getTransctipText(text_processed, isMultiLine)
                DCAF.delay(function()
                    MessageTo(nil, text_tts, duration)
                end, delay)
                return
            end
            MESSAGE:New(text):ToSRS(self.Frequency, self.Modulation, gender, culture, voice, self.Coalition, volume)
            if self._transcriptScope then
                local header = getTranscriptHeader()
                MessageTo(self._transcriptScope, header, self._transcriptDuration)
                local text = getTransctipText(text_processed, true)
                MessageTo(self._transcriptScope, text, self._transcriptDuration)
            end
        end

        if not isSimulatedTTS then
            if self._nextTransmit and now < self._nextTransmit then
                delay = self._nextTransmit - now
            end
            self._nextTransmit = now + self.Interval + delay
        end
        DCAF.delay(doSend, delay)
    end

    send()
end

function DCAF.TTSChannel:GetGreetingPhrase()
    local time = UTILS.SecondsToMidnight()
    if time > 15 then return "Good evening" end
    if time > 12 then return "Good morning" end
    if time > 6 then return "Good afternoon" end
    return "Good evening"
end

function DCAF.TTSChannel:GetFarewellPhrase()
    local night = {"Have a good night", "Good Night", "Have a good night", "Bye Bye", "Bye!", "Thank You!"}
    local morning = {"Have a good morning", "Enjoy your moring", "Good Morning", "Bye Bye", "Thank You"}
    local evening = {"Have a good evening", "Good evening", "Have a good night", "Bye Bye", "Bye!", "Thank You!"}
    local day = {"Good Day!", "Have a good good day!", "Enjoy your day", "Bye for now", "Bye Bye", "Bye!", "Thank You!"}

    local time = UTILS.SecondsToMidnight()
    if time > 15 then return listRandomItem(night) end
    if time > 12 then return listRandomItem(morning) end
    if time > 6 then return listRandomItem(day) end
    if time > 2 then return listRandomItem(evening) end
    return listRandomItem(night)
end

--- Prevents actual text-to-speech synthetization, preventing unnecessary cost for the Google TTS service
function DCAF.TTSChannel.SimulateAllTTS(value, multiLine, duration)
    DCAF.TTSChannel.Is_TTS_Simulated = value or true
    DCAF.TTSChannel.Is_TTS_Simulated_Multi_Line = multiLine
    DCAF.TTSChannel.TTS_Simulated_Duration = duration or 15
    Debug("nisse - DCAF.TTSChannel.SimulateAllTTS :: duration: " .. Dump(DCAF.TTSChannel.TTS_Simulated_Duration))
end

function DCAF.TTSChannel.InitDefaultMGRSOmitMapComponent(value)
    if value == nil then value = true end
    if not isBoolean(value) then return Error("DCAF.TTSChannel.SetDefault_MGRS_OmitMapComponent :: `value` must be true/false, but was: " .. DumpPretty(value)) end
    Debug(DCAF.TTSChannel.ClassName .. " :: sets default value: MGRS_OmitMapComponent = " .. Dump(value))
    TTSChannel_DEFAULTS.MGRS_OmitMapComponent = value
end

function DCAF.TTSChannel:InitMGRS_OmitMapComponent(value)
    if not isBoolean(value) then value = true end
    self.MGRS_OmitMapComponent = value
    return self
end

function DCAF.TTSChannel:SimulateTTS(value, multiLine, duration)
    self.Is_TTS_Simulated = value or true
    self.Is_TTS_Simulated_Multi_Line = multiLine
    self.TTS_Simulated_Duration = duration or 15
Debug("DCAF.TTSChannel:SimulateTTS :: Is_TTS_Simulated: " .. Dump(self.Is_TTS_Simulated) .. " :: Is_TTS_Simulated_Multi_Line: " .. Dump(self.Is_TTS_Simulated_Multi_Line) .. " :: TTS_Simulated_Duration: " .. self.TTS_Simulated_Duration)
end

function DCAF.TTSChannel:Send(text, callsign, isActual, dash, isReplay)
    return self:Message(text, callsign, isActual, dash, isReplay)
end

function DCAF.TTSChannel:Message1(text, isActual)
    self:Message(text, self.Callsign .. " one", isActual)
end

function DCAF.TTSChannel:Message2(text, isActual)
    self:Message(text, self.Callsign .. " two", isActual)
end

function DCAF.TTSChannel:Message3(text, isActual)
    self:Message(text, self.Callsign .. " three", isActual)
end

function DCAF.TTSChannel:Message4(text, isActual)
    self:Message(text, self.Callsign .. " four", isActual)
end

function DCAF.TTSChannel:MessageActual(text)
    self:Message(text, nil, true)
end

function DCAF.TTSChannel:SendActual(text)
    self:MessageActual(text)
end

function DCAF.TTSChannel:AddF10MenuReplay(count, parentMenu)
    self.MsgLog = {}
    self.MsgLogMax = math.min(count or 1, 3)

    self.ChannelMenu = MENU_COALITION:New(self.Coalition, self.Callsign, parentMenu)
    for i = 1, self.MsgLogMax, 1 do
        local text
        if i == 1 then
            text = "Replay last msg"
        elseif i == 2 then
            text = "Replay second last msg"
        elseif i == 3 then
            text = "Replay 3rd last msg"
        end
    MENU_COALITION_COMMAND:New(self.Coalition, text, self.ChannelMenu, function() self:Replay(i) end)
    end
end

function DCAF.TTSChannel:Replay(offset)
Debug("nisse - DCAF.TTSChannel:Replay :: offset: " .. offset .. " :: self.MsgLog: " .. DumpPretty(self.MsgLog))
    offset = offset or 1
    if not self.MsgLog or #self.MsgLog == 0 or #self.MsgLog < offset then
Debug("nisse - DCAF.TTSChannel:Replay :: self.MsgLog")
        return end

    local msg = self.MsgLog[offset]
    self:Message(msg.Text, msg.Callsign, msg.IsActual, msg.Dash, true)
end

local DCAF_TTSChannel_Message = {
    Timestamp = nil,
    Text = nil,
    Callsign = nil,
    Dash = nil,
    IsActual = nil
}

function DCAF.TTSChannel:AddToMsgLog(text, callsign, isActual, dash)
    if not self.MsgLog then
        return end

    local msg = DCAF.clone(DCAF_TTSChannel_Message)
    msg.Timestamp = UTILS.SecondsOfToday()
    msg.Text = text
    msg.Callsign = callsign
    msg.Dash = dash
    msg.IsActual = isActual
    table.insert(self.MsgLog, 1, msg)
    return msg
end

Trace("\\\\\\\\\\ DCAF.TTSChannel.lua was loaded //////////")
