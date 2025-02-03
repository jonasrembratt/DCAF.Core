-- Relies on MOOSE, and Google voice synthesisation https://cloud.google.com/text-to-speech/docs/voices)

local TTSChannel_DEFAULTS = {
    VoiceNormal = "en-GB-Wavenet-F",
    VoiceActual = "en-GB-Wavenet-D",
    Frequency = 357.0,
    Modulation = radio.modulation.AM,
    Callsign = "TOP DOG",
    Coalition = Coalition.Blue,
    MGRS_OmitMapComponent = false,
    UnitsDistance = DCAF.Units.Imperial,
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
-- Debug("nisse - listRandomItemWhere :: i: " .. Dump(i) .. " :: pattern: " .. pattern .. " :: find: " .. Dump(string.find(i, pattern)))
            return string.find(i, pattern)
        end)
-- Debug("nisse - DCAF.TTSVoices:GetRandom :: voice: " .. Dump(voice))
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
    UnitsDistance = TTSChannel_DEFAULTS.UnitsDistance,
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
--- @param callSign string (optional) [default = 'TOP DOG'] Specifies the channel call sign
--- @param frequency number (optional [default = 357.000] Specifies the frequency for the channel. Number (frequency) -or- a #DCAF.Frequency; if the latter modulation can also be passed in that object
--- @param modulation any (optional) [default = radio.modulation.AM] Specifies the modulation for the channel
--- @param coalition any (optional) [default = coalition.side.BLUE] Specifies the modulation for the channel
function DCAF.TTSChannel:New(callSign, frequency, modulation, coalition)
    local freq, mod = resolveFreqAndMod(frequency, modulation)
    local channel = DCAF.clone(DCAF.TTSChannel)
    initTTSChannel(channel, callSign, freq, mod, coalition)
    return channel
end

--- Sets a location for the (transmitting) channel
---@param location table Any object that can be resolved as a #DCAF.Location
---@return table self
function DCAF.TTSChannel:InitLocation(location)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error("DCAF.TTSChannel:InitLocation :: cannot resolve location: "..DumpPretty(location)) end
    self.Location = validLocation
    return self
end

--- Creates a default variable to be recognized in transmissions
--- @param name string Name of variable (eg. "IDO")
--- @param value string Value to be assigned to variable (eg. "COURTSIDE")
function DCAF.TTSChannel.InitDefaultVariable(name, value)
    TTSChannel_DEFAULTS._variables[name] = value
    return DCAF.TTSChannel
end

--- Creates a variable to be recognized in transmissions
-- @param #string name - name of variable (eg. "IDO")
-- @param #string value - value to be assigned to variable (eg. "COURTSIDE")
function DCAF.TTSChannel:InitVariable(name, value)
    Debug("DCAF.TTSChannel:InitVariable :: Frequency: " .. Dump(self.Frequency) .. " :: name: " .. Dump(name) .. " :: value: " .. Dump(value))
    self._variables[name] = value
-- Debug("nisse - DCAF.TTSChannel:InitVariable :: ._variables: " .. DumpPretty(self._variables))
    return self
end

--- Returns value of a specified variable, if any; otherwise nil
---@param name string Name of requested variable
---@return unknown Value of requested variable, or nil if variable is undefined.
function DCAF.TTSChannel:GetVariableValue(name)
    local value = self._variables[name]
    if value then return value end
    return TTSChannel_DEFAULTS._variables[name]
end

--- Creates/sets a "FLIGHT" variable with the identity to be used for that flight, to be recognized in transmissions. This is a neat way to be able to reference in-game flight callsigns.
---@param flightIdentity string 
---@param index number (optional) Specifies the flight number (1..n). Can be any number but only positive numbers makes sense
---@return self object Returns self (#DCAF.TTSChannel)
function DCAF.TTSChannel:InitFlightVariable(flightIdentity, index)
    Debug("DCAF.TTSChannel:InitFlightVariable :: identity: " .. Dump(flightIdentity) .. " :: index: " .. Dump(index))
    if not isAssignedString(flightIdentity) then return Error("DCAF.TTSChannel:InitFlightCallSign ::  `callSign` must be assigned string, but was: " .. DumpPretty(flightIdentity), self) end
    local variableName = "FLIGHT"
    if isNumber(index) then variableName = variableName .. "-" .. index end
    return self:InitVariable(variableName, flightIdentity)
end

--- Sets the units (#DCAF.Units) used for expressing distance
-- @param #DCAF.Units unit - the unit to be used for expressing distance
function DCAF.TTSChannel:InitUnitsDistance(unit)
    if not isUnits(unit) then return Error("DCAF.TTSChannel:InitUnitsDistance :: `units` must be #DCAF.Units, but was: " .. DumpPretty(unit)) end
    self.UnitsDistance = unit
    return self
end

--- Sets the default units (#DCAF.Units) used for expressing distance, for all TTSChannel objects
-- @param #DCAF.Units unit - the unit to be used for expressing distance
function DCAF.TTSChannel:InitDefaultUnitsDistance(unit)
    if not isUnits(unit) then return Error("DCAF.TTSChannel:InitDefaultUnitsDistance :: `units` must be #DCAF.Units, but was: " .. DumpPretty(unit)) end
    TTSChannel_DEFAULTS.UnitsDistance = unit
    return self
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
-- Debug("nisse - DCAF.TTSChannel:InitTranscript :: self:: " .. DumpPretty(self))
        return self
    end
    self._transcriptScope = getGroup(scope)

    if not self._transcriptScope then
        Error("DCAF.TTSChannel:InitTranscript :: `scope` must be coalition or group/unit, but was: " .. DumpPretty(scope))
        return self
    end
-- Debug("nisse - DCAF.TTSChannel:InitTranscript :: scope: " .. Dump(scope) .. " :: _transcriptDuration: " .. Dump(self._transcriptDuration))
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
--- @param text string The textual message to be transmitted
---@param callSign string (optional) A call sign, to override any already configured call sign (see Callsign)
---@param isActual boolean (optional) [default = false] Specifies whether the "actual" voice should be used see :InitVoiceActual
---@param dash number (optional) Specifies a dash number, to be added to the call sign (allows flexibility and makes it easy to portray mor complex military structure) 
---@param isReplay boolean (optional) [default = false] Specifies whether the message is a replay (has already been transmitted)
function DCAF.TTSChannel:Message(text, callSign, isActual, dash, isReplay)
    Debug("DCAF.TTSChannel:Message :: text: " .. Dump(text) .. " :: callSign: " .. Dump(callSign) .. " :: isActual: " .. Dump(isActual) .. " :: isReplay: " .. Dump(isReplay))
    if not isAssignedString(text) then
        return Error("DCAF.TTSChannel:Message :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

    local function substituteVariables()
        callSign = callSign or self.Callsign
        if self:IsActual() then
            callSign = callSign .. " Actual"    
        end
        text = string.gsub(text, "%[CALLSIGN%]", callSign)
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

    -- local function verbalDistanceThousands(distance, unit) -- todo Consider moving to DCAF.Core
    --     local thousands = math.floor(distance / 1000)
    --     local single = distance - thousands*1000
    --     local token = tostring(thousands) .. " tousand"
    --     if single < 100 then
    --         token = tostring(single)
    --     else
    --         token = token .. tostring(single / 100) .. " hundred"
    --     end
    --     return token .. unit
    -- end

    -- local function verbalDistance(distanceMeters)  -- todo Consider moving to DCAF.Core OBSOLETE (moved to DCAF.Core)
    --     if not isNumber(distanceMeters) then return Error("verbalDistance :: `distanceMeters` must be number, but was: " .. DumpPretty(distanceMeters), "ERROR") end
    --     if self.UnitsDistance == DCAF.Units.Metric then
    --         distanceMeters = math.floor(distanceMeters)
    --         if distanceMeters < 3000 then
    --             return PhoneticAlphabet:ConvertNumber(distanceMeters, PhoneticAlphabet.NumericPrecision.Ten) .. " meters"
    --         else
    --             local km = math.floor(distanceMeters / 1000)
    --             return tostring(km) .. " clicks"
    --         end
    --     elseif self.UnitsDistance == DCAF.Units.Imperial then
    --         local distanceFeet = math.floor(UTILS.MetersToFeet(distanceMeters))
    --         if distanceFeet < 5000 then
    --             return PhoneticAlphabet:ConvertNumber(distanceFeet, PhoneticAlphabet.NumericPrecision.Ten) .. " feet"
    --         else
    --             return tostring(UTILS.MetersToNM(distanceMeters))
    --         end
    --     end
    -- end

    local function substituteLocations()
        local LLDM_QUALIFIER = 'lldm'
        local KEYPAD_QUALIFIER = 'kp'
        local MGRS_QUALIFIER = 'gd'
        local BULLSEYE_QUALIFIER = 'be'
        local REFERENCE_POINT_QUALIFIER = 'rp'
        -- todo consider supporting 'be' (bullseye)
        local TERMINATOR = ']'

        local function findLocation()
            local s = string.find(text, LLDM_QUALIFIER.."%[")
            if not s then
                s = string.find(text, KEYPAD_QUALIFIER.."%[")
                if not s then
                    s = string.find(text, MGRS_QUALIFIER.."%[")
                    if not s then
                        s = string.find(text, BULLSEYE_QUALIFIER.."%[")
                        if not s then
                            s = string.find(text, REFERENCE_POINT_QUALIFIER.."%[")
                            if not s then
                                return
                            end
                        end
                    end
                end
            end
            local e = string.find(text, TERMINATOR, s)
            if e then return s, string.sub(text, s, s+1), e end
        end

        local function getCoordinatesAndIdentifiers(ident)
            if not string.find(ident, "//") then
                local l = DCAF.Location.Resolve(ident)
                if l then return { l:GetCoordinate() }, { ident } end
            end

            local coordinates = {}
            local identifiers = {}
            local idents = stringSplit(ident, "//")
            for _, ident in ipairs(idents) do
                ident = stringTrim(ident)

                local l = DCAF.Location.Resolve(ident)
                if l then
                    coordinates[#coordinates+1] = l:GetCoordinate()
                    identifiers[#identifiers+1] = ident
                end
            end
            return coordinates, identifiers
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
            local coordinates, identifiers = getCoordinatesAndIdentifiers(ident)

            if coordinates then
                local token
                local omitMapElement = self.MGRS_OmitMapComponent or TTSChannel_DEFAULTS.MGRS_OmitMapComponent
                if q == LLDM_QUALIFIER then
                    local coord = coordinates[1]
                    token = PhoneticAlphabet:ConvertLLDM(coord)
                elseif q == KEYPAD_QUALIFIER then
                    -- local map, grid, keypad = coord:ToKeypad()
                    local coord = coordinates[1]
                    token = PhoneticAlphabet:ConvertKeypad(coord, omitMapElement)
                elseif q == MGRS_QUALIFIER then
                    local coord = coordinates[1]
                    token = PhoneticAlphabet:ConvertMGRS(coord, true, omitMapElement)
                elseif q == BULLSEYE_QUALIFIER then
                    local coord = coordinates[1]
                    token = PhoneticAlphabet:ConvertBullseye(coord)
                elseif q == REFERENCE_POINT_QUALIFIER then
                    token = PhoneticAlphabet:ConvertReferencePoint(coordinates, identifiers) -- OBSOLETE (moved to PhoneticAlphabet:ConvertReferencePoint)
                end
                if token then
                    out = out .. token
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

    local function getTranscriptText(message, multiline)
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
                self:AddToMsgLog(text, callSign, isActual, dash)
            end
            Debug("DCAF.TTSChannel:Message :: freq: " .. Dump(self.Frequency) .. " :: mod: " .. self.Modulation .. " :: gender: " .. Dump(gender) .. " :: culture: " .. Dump(culture) .. " :: voice: " .. Dump(voice)  .. " :: coalition: " .. Dump(self.Coalition) .. " :: isSimulatedTTS: " .. Dump(isSimulatedTTS) )
            Debug("DCAF.TTSChannel:Message :: text: '" .. text .. "'")
            if isSimulatedTTS then
                local header = getTranscriptHeader()
                local delay = 0 -- math.random(1, 4)
                local duration = self.TTS_Simulated_Duration or DCAF.TTSChannel.TTS_Simulated_Duration
                MessageTo(nil, header, duration + delay)
                local isMultiLine = self.Is_TTS_Simulated_Multi_Line or DCAF.TTSChannel.Is_TTS_Simulated_Multi_Line
                local text_tts = getTranscriptText(text_processed, isMultiLine)
                DCAF.delay(function()
                    MessageTo(nil, text_tts, duration)
                end, delay)
                return
            end
            MESSAGE:New(text):ToSRS(self.Frequency, self.Modulation, gender, culture, voice, self.Coalition, volume)
            if self._transcriptScope then
                local header = getTranscriptHeader()
                MessageTo(self._transcriptScope, header, self._transcriptDuration)
                local text = getTranscriptText(text_processed, true)
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
-- Debug("nisse - DCAF.TTSChannel:Replay :: offset: " .. offset .. " :: self.MsgLog: " .. DumpPretty(self.MsgLog))
    offset = offset or 1
    if not self.MsgLog or #self.MsgLog == 0 or #self.MsgLog < offset then
-- Debug("nisse - DCAF.TTSChannel:Replay :: self.MsgLog")
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

DCAF.TTSChannel.Call = {
    ClassName = "DCAF.TTSChannel.Call",
    ---
    Channel = nil,      -- #DCAF.TTSChannel
    Message = "",       -- message to be sent
    Seconds = 0,        -- estimated time needed for transmission
    SchedulerID = nil   -- Scheduler (delay) ID, once call has been scheduled for transmission
}

function DCAF.TTSChannel.Call:New(ttsChannel, message, seconds, id, funcCallback)
    if not isClass(ttsChannel, DCAF.TTSChannel) then return Error("DCAF.TTSChannel.Call:New :: `ttsChannel` must be of type #" .. DCAF.TTSChannel.ClassName .. ", but was: " .. DumpPretty(ttsChannel)) end
    if not isAssignedString(message) then return Error("DCAF.TTSChannel.Call:New :: `message` must be assigned string, but was: " .. DumpPretty(message)) end
    if not isNumber(seconds) or seconds < 1 then seconds = 10 end
    if funcCallback and not isFunction(funcCallback) then return Error("DCAF.TTSChannel.Call:New :: `funcCallback` must be function, but was: " .. DumpPretty(funcCallback)) end
    local call = DCAF.clone(DCAF.TTSChannel.Call)
    call.Channel = ttsChannel
    call.Message = message
    call.Seconds = seconds
    call.ID = id
    call.Callback = funcCallback
    return call
end

function DCAF.TTSChannel.Call:Cancel()
    self._isCancelled = true
end

DCAF.TTSChannel.CallSequence = {
    ClassName = "DCAF.TTSChannel.CallSequence",
    ----
    Calls = {}          -- list of #DCAF.TTSChannel.Call
}

function DCAF.TTSChannel.CallSequence:New(...)
    if not isListOfClass(arg, DCAF.TTSChannel.Call) then return Error("DCAF.TTSChannel.CallSequence :: arguments must be list of calls (#" .. DCAF.TTSChannel.Call.ClassName.."), but was: " .. DumpPretty(arg)) end
    local seq = DCAF.clone(DCAF.TTSChannel.CallSequence)
    for index, call in ipairs(arg) do
        if not call.ID then call.ID = index end
        seq.Calls[index] = call
    end
    return seq
end

function DCAF.TTSChannel.CallSequence:Execute()
    local delay = 0
    for _, call in ipairs(self.Calls) do
        call.SchedulerID = DCAF.delay(function()
            if call.Callback then pcall(function() call.Callback(call) end) end
            if not call._isCancelled then
                call.Channel:Send(call.Message)
                call.SchedulerID = nil
            end
        end, delay)
        delay = delay + call.Seconds
    end
    return self
end

function DCAF.TTSChannel.CallSequence:Cancel()
    for _, call in ipairs(self.Calls) do
        if call.SchedulerID then pcall(function() DCAF.stopScheduler(call.SchedulerID) end) end
    end
    return self
end

Trace("\\\\\\\\\\ DCAF.TTSChannel.lua was loaded //////////")
