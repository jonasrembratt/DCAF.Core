local DCAF_Story_ID = 0
local DCAF_Stories = {
    -- key   = #string : name of story
    -- value = #DCAF.Story
}

DCAF.Story = {
    ClassName = "DCAF.Story",
    ----
    Name = nil,             -- #string - name of story
}

setmetatable(DCAF.Story, {
    __tostring = function(story) return story.Name end
})

--- Initializes a new, naned, story and returns it
function DCAF.Story:New(name)
    local story = DCAF.clone(DCAF.Story)
    DCAF_Story_ID = DCAF_Story_ID + 1
    story.ID = DCAF_Story_ID
    if isAssignedString(name) then
        local existing = DCAF_Stories[name]
        if existing then
            Error("DCAF.Story:New :: a story named '" .. name .. " was already registered")
            return
        end
        story.Name = name
    else
        story.Name = "Story #" .. story.ID
    end
    return story
end

--- Starts the story. This function will invoke any internal function registered with :OnStart (if any), or it will simply mark the story as started, and then invoke the :OnStarted function
function DCAF.Story:Start()
    if self._isStarted then return self end
    if self._startFunc then
        local args = {}
        if self._startFuncArg then
            args = self._startFuncArg
        end
        table.insert(args, 1, self)
        local started = self._startFunc(unpack(args))
        if started then
           self._isStarted = true
            self:OnStarted()
        end
        return started
    end
    self._isStarted = true
    self:OnStarted()
    return self
end

--- Marks the story as having ended
function DCAF.Story:End()
    if self._isEnded then return self end
    self._isEnded = true
    return self
end

--- Registers a function to be used when the story is to start. This function will be invoked internally by the :Start function
function DCAF.Story:OnStart(func, ...)
    if not isFunction(func) then
        Error("DCAF.Story:OnStart :: `func` must be function, but was: " .. DumpPretty(func))
        return self
    end
    self._startFunc = func
    self._startFuncArg = arg
    return self
end

--- Will be incoked internally when the story starts
function DCAF.Story:OnStarted()
end

--- Gets a value that indicates whether the story has started
function DCAF.Story:IsStarted() return self._isStarted end

--- Gets a value that indicates whether the story has ended
function DCAF.Story:IsEnded() return self._isEnded end

--- Activates groups in a staggered fashion (applying a delay between each activation)
-- @param #table groups - a table where all values are #GROUP objects
-- @param #number interval - (optional; default=5) An interval (seconds) between each activation
-- @param #Any order - (optional) When specified, the `groups` table will be sorted on a value found in each group. Value can be `true` or a string to specify the name of the index to be used for the activation order
-- @param #function onActivatedFunc - (optional) Function to be called back for each activated group. Passes the key and group as arguments
-- @param #number delay - (optional; default=0) Delays the first activation
function DCAF.Story:ActivateStaggered(groups, interval, order, onActivatedFunc, delay)
    activateGroupsStaggered(groups, interval, onActivatedFunc, delay, order)
    return self
end

DCAF.StoryStarter = {
    ClassName = "DCAF.StoryStarter",
    ----
    Stories = {},
}

function DCAF.StoryStarter:New(...)
    local starter = DCAF.clone(DCAF.StoryStarter)
    if #arg < 1 then
        Error("StoryStarter:New :: please specify at least one story")
        return starter
    end
    starter.Stories = {}
    for i = 1, #arg, 1 do
        local story = arg[i]
        story._startIndex = i
        if isClass(story, DCAF.Story) then
            story._storyStarter = self
        else
            Error("DCAF.StoryStarter:New :: story #" .. i .. " is not a #" .. DCAF.Story.ClassName)
            return starter
        end
        starter.Stories[#starter.Stories+1] = story
    end
    starter:InitMissionLength(Minutes(120))
    return starter
end

function DCAF.StoryStarter:NewRandomized(...)
    local randomOrderedStories = listRandomizeOrder(arg)
    return DCAF.StoryStarter:New(unpack(randomOrderedStories))
end

--- Finds a convenient time to start an additional story
function DCAF.StoryStarter:StartWhenConvenient(story, requiredInterval)
    local existing = self:GetStory(story.Name)
    if existing then
        Error("DCAF.StoryStarter:StartWhenConvenient :: story is already managed by this starter: " .. tostring(story))
        return self
    end
    local now = UTILS.SecondsOfToday()
    if not isNumber(requiredInterval) and not isVariableValue(requiredInterval) then requiredInterval = VariableValue:New(Minutes(2), .5) end

    local function getRequiredInterval()
        if isVariableValue(requiredInterval) then return requiredInterval:GetValue() end
        return requiredInterval
    end

    local function findConvenientSlot()
-- Debug("nisse - DCAF.StoryStarter:StartWhenConvenient :: self: " .. DumpPretty(self))
        local nextStory = self.Stories[self._index]
        local startTime
        if not nextStory then
Debug("nisse - DCAF.StoryStarter:StartWhenConvenient :: (last story) self: " .. DumpPretty(self))
            -- story will be the last one; just ensure it's not too soon after the last one...
            local timeSinceLastStory = self._lastStartedTime - now
            local interval = getRequiredInterval()
            if timeSinceLastStory >= interval then
                startTime = now
            else
                startTime = timeSinceLastStory + interval
            end
            return #self.Stories+1, startTime
        end
        -- 

        local startIndex
        local interval = getRequiredInterval()
        for i = nextStory._startIndex-1, #self.Stories-1, 1 do
            nextStory = self.Stories[i+1]
            local preceedingStory = self.Stories[i]
            local prevTime 
            if not preceedingStory then
                prevTime = now
            else
                prevTime = preceedingStory._startTime
            end
-- Debug("nisse - DCAF.StoryStarter:StartWhenConvenient :: preceedingStory: " .. DumpPretty(preceedingStory) .. " :: nextStory: " .. DumpPretty(nextStory))
            local timeBetweenStories = nextStory._startTime - prevTime
-- Debug("nisse - DCAF.StoryStarter:StartWhenConvenient :: interval: " .. Dump(interval) .. " :: timeBetweenStories: " .. DumpPretty(timeBetweenStories))
            if timeBetweenStories >= interval*2 then
                -- we've found a good time to slot in a story...
                startIndex = i+1
                startTime = prevTime + interval
                if startTime - now < 0 then
                    startTime = now + 1
                end
                return startIndex, startTime
            end
        end
        -- there was no convenient slot between stories; add after last story...
        local lastStory = self.Stories[#self.Stories]
        startIndex = lastStory._startIndex + 1
        startTime = lastStory._startTime + interval
        return lastStory._startIndex + 1, lastStory._startTime + interval
    end

    local index, startTime = findConvenientSlot()
    story._startIndex = index
    local delay = math.max(0, startTime - now)
    story._startTime = startTime
    Debug("DCAF.StoryStarter:StartWhenConvenient :: story: " .. tostring(story) .. " :: startIndex: " .. index .. " :: startTime: " .. UTILS.SecondsToClock(startTime))
    self:_insert(story, index)
Debug("nisse - DCAF.StoryStarter:StartWhenConvenient :: self: " .. DumpPretty(self))
    if self._startNextScheduleID and startTime < self._startNextTime then
        -- inject this story before the upcoming one... 
        self:_cancelNext()
        self._startNextTime = startTime
        self._startNextScheduleID = DCAF.delay(function()
            self:_startNext()
        end, delay)
    end
    return self
end

function DCAF.StoryStarter:_insert(story, index)
    if index > #self.Stories then
        self.Stories[#self.Stories+1] = story
        return self
    end

    table.insert(self.Stories, index, story)
    for i = index+1, #self.Stories, 1 do
        local story = self.Stories[i]
        story._startIndex = i
    end
    return self
end

-- Looks up and returns the strory that precedes the specified one
-- @param #Any storyOrName - a #DCAF.Story or a #string (name of story)
function DCAF.StoryStarter:GetPreceedingStory(storyOrName)
    local story = self:GetStory(storyOrName)
    if not story then return end
    return self.Stories[story._startIndex-1]
end

-- Looks up and returns the strory that succeeds the specified one
-- @param #Any storyOrName - a #DCAF.Story or a #string (name of story)
function DCAF.StoryStarter:GetSucceedingStory(storyOrName)
    local story = self:GetStory(storyOrName)
    if not story then return end
    return self.Stories[story._startIndex+1]
end

--- Initiates the story sequence with a configured mission length. This will be used to spread out starting of missions somewhat evenly. You can also specify the start interval directly using the :InitInterval function
-- @param #number missionLength - length of mission (seconds)
function DCAF.StoryStarter:InitMissionLength(missionLength)
    if not isNumber(missionLength) then
        Error("StoriesDispatcher:InitMission :: `missionLength` must be number, but was: " .. DumpPretty(missionLength))
        return self
    end
    self.MissionLength = missionLength
    return self:InitInterval(VariableValue:New(missionLength / #self.Stories, .2))
end

--- Specifies an interval to be observed when starting stories in sequence
function DCAF.StoryStarter:InitInterval(interval)
Debug("nisse - DCAF.StoryStarter:InitInterval :: interval: " .. Dump(interval))
    if interval and not isNumber(interval) and not isVariableValue(interval) then
        Error("StoriesDispatcher:InitMission :: `interval` must be number or #VariableValue, but was: " .. DumpPretty(interval))
        return self
    end
    self.Interval = interval
    return self
end

--- Commences starting of managed stories
function DCAF.StoryStarter:Start()
    if self._isStarted then return self end
    self._isStarted = true
    self:_setStoryStartDelays()
    self._index = 1
    local story = self.Stories[self._index]
    if not story then
        Error("DCAF.StoryStarter:Start :: No initial story found :: FAIL")
        return self
    end
Debug("nisse - DCAF.StoryStarter:Start :: first story starts " .. UTILS.SecondsToClock(story._startTime) .. ": " .. tostring(story))
    self._startNextTime = story._startTime
    local delay = story._startTime - UTILS.SecondsOfToday()
    self._startNextScheduleID = DCAF.delay(function()
        self:_startNext()
    end, delay)
    return self
end

--- Defers starting a story
function DCAF.StoryStarter:Defer(story)
    local function suggestNextStory()
        local lowestDeferral = 99999
        local lowestDeferralIndex = -1
        for i = story._startIndex + 1, #self.Stories, 1 do
            local s = self.Stories[i]
            if not self._deferrals then return s end
            if s._deferrals < lowestDeferral then
                lowestDeferral = s._deferrals
                lowestDeferralIndex = i
            end
        end
        if lowestDeferralIndex > 0 then return self.Stories[lowestDeferralIndex] end
    end

    -- swap place with the next story ...
    story._deferrals = story._deferrals or 0
    story._deferrals= story._deferrals + 1
    local suggestedNextStory = suggestNextStory()
    if not suggestedNextStory then return end
    swap(story, suggestNextStory, '_startIndex')
    -- swap(story, suggestNextStory, '_startDelay')
    swap(story, suggestNextStory, '_startTime')
    self.Stories[story._startIndex] = story
    self.Stories[suggestNextStory._startIndex] = suggestNextStory

    return suggestedNextStory
end

--- Returns a value to indicate how many deferrals has been requested for a specified story to be started
function DCAF.StoryStarter:GetDeferrals(story)
    return story._deferrals or 0
end

--- Returns a value to indicate whether a specified story is the last to be started
function DCAF.StoryStarter:IsLast(story)
    return story._startIndex == #self.Stories
end

--- Looks up a story managed by the starter and returns a value to indicate whether the story has been started
function DCAF.StoryStarter:HasStarted(storyOrName)
    local story
    if isAssignedString(storyOrName) then
        story = self:GetStory(storyOrName)
    elseif isClass(storyOrName, DCAF.Story) then
        story = storyOrName
    else
        Error("DCAF.StoryStarter:HasStarted :: `storyOrName` must be #" .. DCAF.Story.ClassName .. " or #string (name of story), but was: " .. DumpPretty(storyOrName))
        return
    end
    return story:HasStarted()
end

--- Looks up and returns a named story that is managed by the starter
function DCAF.StoryStarter:GetStory(storyOrName)
    local story
    if isClass(storyOrName, DCAF.Story) then
        story = storyOrName
    elseif isAssignedString(storyOrName) then
        story = DCAF_Stories[storyOrName]
    end
    if not story or story._storyStarter ~= self then return end
    return story
end

function DCAF.StoryStarter:_setStoryStartDelays()
    local now = UTILS.SecondsOfToday()
    local startTime =  now + self:_getNextInterval()
    local baseInterval
    if isNumber(self.Interval) then
        baseInterval = self.Interval
    else
        baseInterval = self.Interval:GetValue(0)
    end
Debug("nisse - DCAF.StoryStarter:_setStoryStartDelays :: baseInterval: " .. Dump(baseInterval))
    local delay = startTime - now
    for _, story in ipairs(self.Stories) do
        -- story._startDelay = delay
        story._startTime = startTime
        now = now + baseInterval
        startTime = now + self:_getNextInterval()
        delay = startTime - now
Debug("nisse - DCAF.StoryStarter:_setStoryStartDelays :: story: " .. tostring(story) .. " :: now: " .. now .. " :: ")
    end
end

function DCAF.StoryStarter:_startNext()
    local story = self.Stories[self._index]
Debug("nisse - DCAF.StoryStarter:_startNext :: story: " .. tostring(story))
    if not story then return self end
    local startedStory = story:Start()
    if not startedStory then
        if story == self.Stories[self._index] then
            -- story did not start and also didn't defer itself. Just ignore and start next story instead...
            Warning("DCAF.StoryStarter :: IGNORED story that neither started nor Deferred: " .. tostring(story))
            self._index = self._index + 1
            DCAF.delay(function() self:_startNext() end, 1)
        end
        -- story Deferred; start next story...
        DCAF.delay(function() self:_startNext() end, 1)
    else
        -- story started; delay next story...
        self._lastStartedTime = UTILS.SecondsOfToday()
        Debug("DCAF.StoryStarter :: story started: " .. tostring(story))
        self._index = self._index + 1
        local nextStory = self.Stories[self._index]
        if not nextStory then 
            Debug(self.ClassName .. " :: no more stories to be started :: EXITS")
            return
        end
        self._startNextTime = nextStory._startTime
        local now = UTILS.SecondsOfToday()
        local delay = nextStory._startTime - now
Debug("nisse - DCAF.StoryStarter:_startNext :: next story starts " .. UTILS.SecondsToClock(nextStory._startTime) .. " :: delay:" .. delay .. " :: story: " .. tostring(nextStory))
        self._startNextScheduleID = DCAF.delay(function()
            self:_startNext()
        end, delay)
    end
end

function DCAF.StoryStarter:_cancelNext()
    if self._startNextScheduleID then
        DCAF.stopScheduler(self._startNextScheduleID)
        self._startNextScheduleID = nil
    end
end

function DCAF.StoryStarter:_getNextInterval()
    local interval
    if isVariableValue(self.Interval) then
        interval = self.Interval:GetValue()
    else
        interval = self.Interval
    end
Debug("nisse - DCAF.StoryStarter:_getNextInterval :: interval: " .. Dump(interval))
    return interval
end