do -- |||||||||||||||||||||||||    Game Master menu - GM_Menu    |||||||||||||||||||||||||

Blue = coalition.side.BLUE

GM_Menu = {
    ClassName = "GM_Menu",
    ----
}

local menu_ID = 0
local menus_DB = {
    -- key   = menu path
    -- value = #GM_Menu
}

function menus_DB:getNextID()
    menu_ID = menu_ID + 1
    return menu_ID
end

function menus_DB:add(gm_menu)
    self[gm_menu._path] = gm_menu
end

function menus_DB:remove(gm_menu)
    local menuPath = gm_menu._path
    for path, menu in pairs(self) do
        if stringStartsWith(path, menuPath) then
            self[path] = nil
        end
    end
end

function menus_DB:getSubMenus(gm_menu)
Debug("nisse - menus_DB:getSubMenus :: self: "..DumpPretty(self))
    local subMenus = {}
    for path, menu in pairs(self) do
if isFunction(menu) then Debug("nisse - path: "..Dump(path).." "..DCAF.StackTrace()) end
        if menu._parent == gm_menu then
            subMenus[#subMenus+1] = menu
        end
    end
    return subMenus
end

function GM_Menu:New(text, parentMenu, group)
    if not isAssignedString(text) then text = "[GM ONLY!]" end
    Debug("GM_Menu:New :: " .. text .. " :: parentMenu: " .. DumpPretty(parentMenu))
    local gmMenu = DCAF.clone(GM_Menu)
    if not isAssignedString(text) then text = tostring(text) end
    if isGroup(group) then
        gmMenu._menu = MENU_GROUP:New(group, text, parentMenu)
    else
        gmMenu._menu = MENU_COALITION:New(Blue, text, parentMenu)
    end
    gmMenu._text = text
    gmMenu._path = text
    gmMenu._subMenuCount = gmMenu._subMenuCount or 0
    gmMenu.ID = menus_DB:getNextID()
    return gmMenu
end

function GM_Menu:NewCommand(text, parentMenu, func, group)
    if not isAssignedString(text) then text = tostring(text) end
    if not isFunction(func) then return Error("GM_Menu:NewCommand :: `func` must be function, but was: "..DumpPretty(text)) end
    Debug("GM_Menu:NewCommand :: " .. text .. " :: parentMenu: " .. DumpPretty(parentMenu))
    local gmMenu = DCAF.clone(GM_Menu)
    if isGroup(group) then
        gmMenu._menu = MENU_GROUP_COMMAND:New(group, text, parentMenu, func)
    else
        gmMenu._menu = MENU_COALITION_COMMAND:New(Blue, text, parentMenu, func)
    end
    gmMenu._text = text
    gmMenu._path = text
    gmMenu._subMenuCount = gmMenu._subMenuCount or 0
    gmMenu.ID = menus_DB:getNextID()
    return gmMenu
end

function GM_Menu:Ensure()
    if not GM_Menu._root then GM_Menu._root = GM_Menu:New() end
    return GM_Menu._root
end

local nisse_debug_menu

function GM_Menu:AddMenu(text)
    Debug("GM_Menu:AddMenu :: " .. text)
if text == "Select Flight" then
    Debug("nisse - select flight menu (xxx) :: self._parent: "..DumpPretty(self._parent).." self._parent._menu: "..DumpPrettyDeep(self._parent._menu, 2))
    if self._parent._menu == nisse_debug_menu then Error("WTF?! (aaa)") end
end
    
    if self == GM_Menu then
        GM_Menu:Ensure()
    else
        self._subMenuCount = self._subMenuCount or 0
        self._subMenuCount = self._subMenuCount + 1
    end
    local subMenu = DCAF.clone(GM_Menu)
    subMenu.ID = menus_DB:getNextID()
    if not isAssignedString(text) then text = tostring(text) end
    subMenu._menu = MENU_COALITION:New(Blue, text, self._menu or GM_Menu._root._menu)

if text == "DEBUG" then -- NISSE
    Debug("nisse - DEBUG menu...")
    nisse_debug_menu = subMenu._menu
end 
-- if text == "Select Flight" then
--     Debug("nisse - select flight menu (bbb)...")
--     if self._parent._menu == nisse_debug_menu then Error("WTF?!") end
-- end

    subMenu._text = text
    local path = self._path
    if path == nil then
        path = GM_Menu._root._path
    end
    subMenu._path = path .. '/' .. text
    subMenu._parent = self
    menus_DB:add(subMenu)
    return subMenu
end

function GM_Menu:AddCommand(text, func)
    Debug("GM_Menu:AddCommand :: text: "..Dump(text).." :: self: "..DumpPretty(self).." :: self._menu: "..DumpPrettyDeep(self._menu, 2))
    if self == GM_Menu then
        GM_Menu:Ensure()
    end
    self._subMenuCount = self._subMenuCount or 0
    self._subMenuCount = self._subMenuCount + 1
    local subMenu = DCAF.clone(GM_Menu)
    if not isAssignedString(text) then text = tostring(text) end
    local menu
    local parentMenu = self._menu or GM_Menu._root._menu
if text == "Show Progress" then
    local _func = func
    Debug("GM_Menu:AddCommand :: check Show Progress :: menu: "..DumpPrettyDeep(menu))
    func = function(sm)
        MessageTo(nil, "------\n"..DumpPrettyDeep(parentMenu, 2).."\n------")
        _func(sm)
    end
end
    menu = MENU_COALITION_COMMAND:New(Blue, text, parentMenu, function() func(subMenu) end)
    subMenu._menu = menu
    subMenu.ID = menus_DB:getNextID()
    subMenu._text = text
    subMenu._path = (self._path or GM_Menu._root._path) .. '/' .. text
    subMenu._parent = self
    menus_DB:add(subMenu)
    return subMenu
end

function GM_Menu:Remove(removeEmptyParent)
    Debug("GM_Menu:Remove :: " .. self._text .. " :: removeEmptyParent: " .. Dump(removeEmptyParent))
    if self._menu then
        self._menu:Remove()
        self._menu = nil
        menus_DB:remove(self)
        if self._parent then
            self._parent:_notifyRemoveSubMenu(self, removeEmptyParent)
        end
    end
    return self
end

function GM_Menu:RemoveChildren()
    Debug("GM_Menu:RemoveChildren :: " .. self._text)
    local subMenus = menus_DB:getSubMenus(self)
    if #subMenus == 0 then return self end
    for _, subMenu in pairs(subMenus) do
        subMenu:Remove(false)
    end
end

function GM_Menu:_notifyRemoveSubMenu(menu, removeOnEmpty)
    if self == GM_Menu then self = GM_Menu._root end
    self._subMenuCount = self._subMenuCount - 1
    if self._subMenus then
        self._subMenus[menu._text] = nil
    end
    if self._subMenuCount == 0 and removeOnEmpty then
        self:Remove(removeOnEmpty)
    end
end
    
end -- (Game Master menu - GM_Menu)

Debug("nisse - Story (aaa)")

local DCAF_Story_ID = 0
local DCAF_Stories = {
    -- key   = #string : name of story
    -- value = #DCAF.Story
}

DCAF.Story = {
    ClassName = "DCAF.Story",
    ----
    Name = nil,             -- #string - name of story
    gm_menu = nil
}

DCAF.StoryStartOutcome = {
    ClassName = "DCAF.StoryStartOutcome",
    ----
}

function DCAF.StoryStartOutcome:Delay(delay)
    if not isNumber(delay) then return Error("DCAF.StoryStartOutcome:Delay :: `delay` must be number, but was: " .. DumpPretty(delay)) end
    local outcome = DCAF.clone(DCAF.StoryStartOutcome)
    outcome.DelayTime = delay
    return outcome
end

function DCAF.StoryStartOutcome:PreventStart()
    local outcome = DCAF.clone(DCAF.StoryStartOutcome)
    outcome.IsPrevented = true
    return outcome
end

setmetatable(DCAF.Story, {
    __tostring = function(story) return story.Name end
})

--- Initializes a new, named, story and returns it
function DCAF.Story:New(name, startDelayDefault)
    local story = DCAF.clone(DCAF.Story)
    DCAF_Story_ID = DCAF_Story_ID + 1
    story.ID = DCAF_Story_ID
    if startDelayDefault ~= nil then
        if not isNumber(startDelayDefault) or startDelayDefault < 0 then
            Error("DCAF.Story:New :: `startDelayDefault` must be positive number, but was: " .. DumpPretty(startDelayDefault) .. " :: IGNORES value")
        end
        story.StartDelayDefault = startDelayDefault
    end
    Debug("DCAF.Story:New :: name: " .. Dump(name) .. " :: startDelayDefault: " .. Dump(startDelayDefault))
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

function DCAF.Story:_start(delay)
    if self._isStarted then return self end

    local function doStart()
        if not self._startFunc then
            self._isStarted = true
            return self:OnStarted()
        end
        local args = {}
        if self._startFuncArg then
            args = self._startFuncArg
        end
        table.insert(args, 1, self)
        local outcome = self._startFunc(unpack(args))
        if isClass(outcome, DCAF.StoryStartOutcome) then
            if outcome.IsPrevented then return self end
            local delay = 0
            if outcome.DelayTime then
                delay = outcome.DelayTime
            end
            DCAF.delay(function()
                self._isStarted = true
                self:OnStarted()
            end, delay)
            return
        else
            self._isStarted = true
            self:OnStarted()
        end
    end

    if not isNumber(delay) then delay = self.StartDelayDefault end
    if delay then
        DCAF.delay(doStart, delay)
    else
        doStart()
    end
    return self
end

function DCAF.Story:_end(delay)
    Debug("DCAF.Story:_end :: delay: " .. Dump(delay))
    if self._isEnded then return self end
    local function doEnd()
        if not self._endFunc then
            self._isEnded = true
            return self:OnEnded()
        end
        local args = {}
        if self._endFuncArg then
            args = self._endFuncArg
        end
        table.insert(args, 1, self)
        local outcome = self._endFunc(unpack(args))
        if isClass(outcome, DCAF.StoryStartOutcome) then
            if outcome.IsPrevented then return self end
            local delay = 0
            if outcome.DelayTime then
                delay = outcome.DelayTime
            end
            DCAF.delay(function()
                self._isEnded = true
                self:OnEnded()
            end, delay)
        else
            self._isEnded = true
            self:OnEnded()
        end
    end

    if not isNumber(delay) then delay = self.EndDelayDefault end
    if delay then
        DCAF.delay(doEnd, delay)
    else
        doEnd()
    end
    return self
end

--- Starts the story. This function will invoke any internal function registered with :OnStart (if any), or it will simply mark the story as started, and then invoke the :OnStarted function
function DCAF.Story:Start()
    if self:IsRunning() then return end
    Debug("DCAF.Story:Start :: "..self.Name)
    return self:_start()
end

--- Starts the story after a delay. This function will invoke any internal function registered with :OnStart (if any), or it will simply mark the story as started, and then invoke the :OnStarted function
function DCAF.Story:StartDelayed(delay)
    if not isNumber(delay) or delay <= 0 then return Error("DCAF.Story:StartDelayed :: `delay` must be positive number, but was: " .. DumpPretty(delay)) end
    return self:_start(delay)
end

--- Ends the story
function DCAF.Story:End()
    return self:_end(0)
end

--- Ends the story after a delay
function DCAF.Story:EndDelayed(delay)
    if not isNumber(delay) or delay <= 0 then return Error("DCAF.Story:EndDelayed :: `delay` must be positive number, but was: " .. DumpPretty(delay)) end
    return self:_end(delay)
end

--- Registers a function to be used when the story is to start. This function will be invoked internally by the :Start function
function DCAF.Story:OnStart(func, ...)
    Debug("DCAF.Story:OnStart :: func: " .. DumpPretty(func))
    if not isFunction(func) then
        Error("DCAF.Story:OnStart :: `func` must be function, but was: " .. DumpPretty(func))
        return self
    end
    self._startFunc = func
    self._startFuncArg = arg
    return self
end

--- Will be invoked internally when the story starts
function DCAF.Story:OnStarted()
end

--- Registers a function to be used when the story is end. This function will be invoked internally by the :End function
function DCAF.Story:OnEnd(func, ...)
    Debug("DCAF.Story:OnEnd :: func: " .. DumpPretty(func))
    if not isFunction(func) then
        Error("DCAF.Story:OnEnd :: `func` must be function, but was: " .. DumpPretty(func))
        return self
    end
    self._endFunc = func
    self._endFuncArg = arg
    return self
end

function DCAF.Story:OnEnded()
end

--- Gets a value that indicates whether the story has started
function DCAF.Story:IsStarted() return self._isStarted end

--- Gets a value that indicates whether the story has ended
function DCAF.Story:IsEnded() return self._isEnded end

function DCAF.Story:IsRunning() return self:IsStarted() and not self:IsEnded() end

--- Gets a value that indicates whether the story has started, but not ended
function DCAF.Story:IsActive()
    return self._isStarted and not self._isEnded
end

--- Activates groups
--- @param source any A table, SET_GROUP, or SET_STATIC to be activated
--- @param order any (optional) When specified, the `source` will be sorted on a value found in each group. Value can be `true` or a string to specify the name of the index to be used for the activation order
--- @param onActivatedFunc function  (optional) Function to be called back for each activated group. Passes the key and group as arguments
--- @param delay number (optional) [default=0] Delays the first activation
function DCAF.Story:Activate(source, order, onActivatedFunc, delay)
    Debug("DCAF.Story:Activate :: source: " .. DumpPretty(source) .. " :: order: " .. DumpPretty(order) .. " :: delay:" .. DumpPretty(delay))
    if isClass(source, UNIT) then
        source = source:GetGroup()
    end
    if isClass(source, GROUP) then
        if source:IsActive() then return source end
        return source:Activate()
    end
    if isTableOfAssignedStrings(source) or isTableOfClass(source, GROUP) or isTableOfClass(source, STATIC) or isClass(source, SET_GROUP) or isClass(source, SET_STATIC) then
        return self:ActivateStaggered(source, 0, order, onActivatedFunc, delay)
    end
    if not isTable(source) then return Error("DCAF.Story:Activate :: `source` is not expected structure: " .. DumpPrettyDeep(source, 2)) end

    local activatedGroups = {}
    for _, item in pairs(source) do
        local groups = self:Activate(item, order, onActivatedFunc, delay)
        if groups then listJoin(activatedGroups, groups) end
    end
    return activatedGroups
end

--- Activates groups in a staggered fashion (applying a delay between each activation)
--- @param source any A table, SET_GROUP, or SET_STATIC to be activated
--- @param interval number (optional) [default=5] An interval (seconds) between each activation
--- @param order any (optional) When specified, the `source` will be sorted on a value found in each group. Value can be `true` or a string to specify the name of the index to be used for the activation order
--- @param onActivatedFunc function  (optional) Function to be called back for each activated group. Passes the key and group as arguments
--- @param delay number (optional) [default=0] Delays the first activation
function DCAF.Story:ActivateStaggered(source, interval, order, onActivatedFunc, delay)
    Debug("DCAF.Story:ActivateStaggered :: source: " .. DumpPretty(source) .. " :: interval: " .. DumpPretty(interval) .. " :: order: " .. DumpPretty(order) .. " :: delay:" .. DumpPretty(delay))
    return activateStaggered(source, interval, onActivatedFunc, delay, order)
end

--- Returns coordinate for a "reference location" and, optionally, removes the object
--- @param source string A GROUP or STATIC, ort name of a GROUP/STATIC
--- @param destroy boolean (optional) [default = true] Specifies whether to remove the object after acquiring its coordinate
--- @return table The coordinate of the GROUP or STATIC
function DCAF.Story:GetRefLoc(source, destroy)
    Debug("DCAF.Story:GetRefLoc :: source: " .. DumpPretty(source) .. " :: destroy: " .. DumpPretty(destroy))
    local function processSource(object)
        local coordinate = object:GetCoordinate()
        if destroy then object:Destroy() end
        return coordinate
    end

    if not isBoolean(destroy) then destroy = true end
    local group = getGroup(source)
    if group then
        return processSource(group)
    end
    local static = getStatic(source)
    if static then return processSource(group) end
    return Error("DCAF.Story:GetRefLoc :: `source` could not be resolved: " .. DumpPretty(source))
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
--- @param story any #DCAF.Story to be deferred
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
-- Debug("nisse - DCAF.StoryStarter:_startNext :: story: " .. tostring(story))
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
-- Debug("nisse - DCAF.StoryStarter:_startNext :: next story starts " .. UTILS.SecondsToClock(nextStory._startTime) .. " :: delay:" .. delay .. " :: story: " .. tostring(nextStory))
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
    return interval
end

function DCAF.Story:ExpectTTSChannelsAssigned(value)
    if not isBoolean(value) then value = true end
    self._expectTTSChannelsAssigned = value
    return self
end

function DCAF.Story:Send(ttsChannel, message, callSign, isActual, dash, isReplay)
    if not ttsChannel then
        if self._expectTTSChannelsAssigned then Error("DCAF.Story:Send :: `ttsChannel` was unassigned") end
        return
    end
    if not isClass(ttsChannel, DCAF.TTSChannel) then return Error("DCAF.Story:Send :: `ttsChannel` must be type #" .. DCAF.TTSChannel.ClassName .. ", but was: " .. DCAF.TTSChannel.ClassName) end
    ttsChannel:Send(message, callSign, isActual, dash, isReplay)
end

function DCAF.Story:SendDelayed(delay, ttsChannel, message, callSign, isActual, dash, isReplay)
    if not isNumber(delay) then return Error("DCAF.Story:SendDelayed :: `delay` must be positive number, but was: " .. DumpPretty(delay)) end
    DCAF.delay(function()
        self:Send(ttsChannel, message, callSign, isActual, dash, isReplay)
    end, delay)
end

function DCAF.Story:SrsCalls(...)
    return DCAF.TTSChannel.CallSequence:New(...):Execute()
end

function DCAF.Story:Call(ttsChannel, message, seconds, funcCallback, id)
    return DCAF.TTSChannel.Call:New(ttsChannel, message, seconds, id, funcCallback)
end

function DCAF.Story:AssignFlight(flight)
    Debug("DCAF.Story:AssignFlight :: flight: " .. DumpPretty(flight))
    if not isClass(flight, DCAF.Flight) then return Error("DCAF.Story:AssignFlight :: `flight` must be "..DCAF.Flight.ClassName..", but was: "..DumpPretty(flight), self) end
    self.AssignedFlight = flight
    self:OnAssignedFlight(flight)
end

function DCAF.Story:CountAssignedPlayers()
    if not self.AssignedFlight then return 0 end
    return self.AssignedFlight.Group:GetPlayerCount()
end

function DCAF.Story:GetAssignedPlayerNames()
    local units = self:GetAssignedUnits()
    if not units then return end
    local playerNames = {}
    for _, unit in ipairs(units) do
        if unit:IsPlayer() then playerNames[#playerNames+1] = unit:GetPlayerName() end
    end
    return playerNames
end

function DCAF.Story:GetAssignedUnits()
    if not self.AssignedFlight then return end
    return self.AssignedFlight.Group:GetUnits()
end

function DCAF.Story:OnAssignedFlight(flight)
    Debug("DCAF.Story:OnAssignedFlight :: (not overridden; no action)")
end

function DCAF.Story:Get2DDistance(locationA, locationB)
    local validLocationA = DCAF.Location.Resolve(locationA)
    if not validLocationA then return Error("DCAF.Story:Get2DDistance :: `locationA` is not a valid #"..DCAF.Location.ClassName..": "..DumpPretty(locationA)) end
    local validLocationB = DCAF.Location.Resolve(locationB)
    if not validLocationB then return Error("DCAF.Story:Get2DDistance :: `locationB` is not a valid #"..DCAF.Location.ClassName..": "..DumpPretty(locationB)) end
    return validLocationA:Get2DDistance(validLocationB)
end

--- Specifies two locations and registers a handler function to be invoked once those locations are inside a specified range
---@param range number The specified range (meters)
---@param locationA any Can be anything resolvable as a #DCAF.Location
---@param locationB any Can be anything resolvable as a #DCAF.Location
---@param funcInRange function Handler function to be called back once locations are within range of each other
---@param exitRange any (optional) When specified (meters), function will automatically stop monitoring for locations coming within mutual range
---@param interval any (optional) [default = 1] Specifies an interval (seconds) to be used for monitoring locations coming within mutual range
---@param funcExit any (optional) Handler function to be called back once locations are outside of `exitRange`
---@return self any self
function DCAF.Story:WhenIn2DRange(range, locationA, locationB, funcInRange, exitRange, interval, funcExit)
    if not isNumber(range) or range < 1 then return Error("DCAF.Story:WhenIn2DRange :: `range` must be positive number, but was: " .. DumpPretty(range), self) end
    if not isFunction(funcInRange) then return Error("DCAF.Story:WhenIn2DRange :: `funcInRange` must be function, but was: " .. DumpPretty(funcInRange), self) end
    if funcExit and not isFunction(funcExit) then return Error("DCAF.Story:WhenIn2DRange :: `funcExit` must be function, but was: " .. DumpPretty(funcExit)) end
    local validLocationA = DCAF.Location.Resolve(locationA)
    if not validLocationA then return Error("DCAF.Story:WhenIn2DRange :: could not resolve `locationA`: " .. DumpPretty(locationA), self) end
Debug("nisse - DCAF.Story:WhenIn2DRange (eee) :: locationB: "..DumpPretty(locationB))
    local validLocationB = DCAF.Location.Resolve(locationB)
Debug("nisse - DCAF.Story:WhenIn2DRange (fff)")
    if not validLocationB then return Error("DCAF.Story:WhenIn2DRange :: could not resolve `locationB`: " .. DumpPretty(locationB), self) end
Debug("nisse - DCAF.Story:WhenIn2DRange (ggg)")
    locationA = validLocationA
    locationB = validLocationB
    Debug("DCAF.Story:WhenIn2DRange :: range: "..range.." :: locationA: "..locationA.Name.." :: locationB: "..locationB.Name.." :: interval: "..DumpPretty(interval))

    if isNumber(exitRange) and exitRange <= range then return Error("DCAF.Story:WhenIn2DRange :: `exitRange` must be greater than `range` ("..range.."), but was: "..exitRange) end
    if not isNumber(interval) or interval < 1 then interval = 1 end
    if funcExit and not isFunction(funcExit) then return Error("DCAF.Story:WhenIn2DRange :: `handlerExit` must be function, but was: " .. DumpPretty(funcExit)) end
    locationA:WhenIn2DRange(range, locationB, funcInRange, exitRange, interval, funcExit)
    return self
end

function DCAF.Story:Debug(value)
    Debug(self.Name..":Debug :: value: "..Dump(value))
    if not isBoolean(value) then value = true end
    self._debug = value
    value = self:OnDebug(value)
    if not isBoolean(value) then value = true end
    self._debug = value
    if self._debug then
        if not self._menuDebug then
            self:AddDebugCommand("Show Progress", function()
                local flow = self:DebugFunctionsDoneText()
                if not flow then flow = "(pending)" end
                local text = ":::::: "..self.Name.." ::::::\n"..flow
                MessageTo(nil, text)
            end)
        end
    elseif self._gmMenu and self._gmMenu.debug then
        self._gmMenu.debug:Remove(false)
        self._gmMenu.debug = nil
    end
end

function DCAF.Story:OnDebug(value)
Debug("nisse - DCAF.Story:OnDebug :: value: "..Dump(value))
    -- to be overridden
    return value
end

function DCAF.Story:IsDebug()
    return self._debug
end

function DCAF.Story:DebugMessage(message, duration)
    if self:IsDebug() then
        if not isNumber(duration) then duration = 30 end
        MessageTo(nil, message, duration)
    end
end

if DCAF.PlayerReconTask then
function DCAF.Story:EnableReconLocationWithMapMarker(location, distanceTolerance, funcSuccess)
    local me = self.Name
    Debug(me..":EnableReconLocationWithMapMarker :: location: "..DumpPretty(location).." :: distanceTolerance: " .. DumpPretty(distanceTolerance).." :: funcSuccess: "..DumpPretty(funcSuccess))
    if not isFunction(funcSuccess) then return Error(me..":EnableReconLocationWithMapMarker :: no Flight has been assigned") end
    if not self.AssignedFlight then return Error(me..":EnableReconLocationWithMapMarker :: no Flight has been assigned") end
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error(me..":EnableReconLocationWithMapMarker :: cannot resolve location: "..DumpPretty(location)) end
    location = validLocation

    local function isNear(coord)
        local coordLocation = location:GetCoordinate()
        if not coordLocation then return Error(me..":EnableReconLocationWithMapMarker :: cannot get coordinate for location") end
        local distance = coord:Get2DDistance(coordLocation)
        Debug(me..":EnableReconLocationWithMapMarker :: distance: " .. UTILS.MetersToNM(distance).." nm".." :: distanceTolerance: "..UTILS.MetersToNM(distanceTolerance).." nm")
        return distance < distanceTolerance
    end

    return DCAF.PlayerReconTask:New(self.AssignedFlight.Group, location.Name):HandleMapMarker(function(task, event)
        if isNear(event.MarkCoordinate) then
            local ok, err = pcall(function() funcSuccess(task, event) end)
            if not ok then Error("DCAF.Story:EnableReconLocationWithMapMarker :: "..DumpPretty(err)) end
        end
    end)
end
end


do -- |||||||||||||||||||||||||||    Track which Functions has been Called so far    |||||||||||||||||||||||||||

--- Returns the in-game time a function was called, or nil if function hasn't been run
---@param name any (optional) [default = name of calling function] Name of function
---@return any timeFunctionWasInvoked Returns nil if function has not been invoked
function DCAF.Story:IsFunctionDone(name)
    local add
    if not isAssignedString(name) then
        add = true
        local info = debug.getinfo(2, "n")
        if not info.name then
Debug("nisse - DCAF.Story:IsFunctionDone :: WTF?!")
            return nil
        end
        name = info.name
    end
    self._functionFlow = self._functionFlow or {}
    self._functionFlowNextOrder = self._functionFlowNextOrder or 0
    local info = self._functionFlow[name]
    if info or not add then return info end
    Debug(self.Name..":"..name)
    self._functionFlowNextOrder = self._functionFlowNextOrder + 1
    info = {
        FunctionName = name,
        Time = UTILS.SecondsOfToday(),
        Order = self._functionFlowNextOrder
    }
    local previousFunctionInfo = self:GetFunctionDone(info.Order-1)
    if previousFunctionInfo then
        info.PreviousFunction = previousFunctionInfo.FunctionName
    end
    self._functionFlow[name] = info
end

function DCAF.Story:GetFunctionDone(order)
    if not isNumber(order) then return Error("DCAF.Story:GetFunctionDone :: `order` must be number, but was: "..DumpPretty(order)) end
    if not self._functionFlow then return end
    for index, info in ipairs(self._functionFlow) do
        if info.Order == order then return info end
    end
end

function DCAF.Story:DebugFunctionsDoneText()
-- Debug("nisse - DCAF.Story:DebugFunctionsDoneText :: "..DumpPrettyDeep(self._functionFlow))
    local flowSorted = dictToList(self._functionFlow, function(a,b) return a.Order < b.Order end)
    if not flowSorted then return end
    local info = flowSorted[1]
    local text = "[1] "..info.FunctionName.." :: "..UTILS.SecondsToClock(info.Time)
    for i = 2, #flowSorted do
        info = flowSorted[i]
        text = text.."\n["..i.."] "..info.FunctionName.." :: "..UTILS.SecondsToClock(info.Time)
    end
    return text
end

function DCAF.Story:DebugMessageFunctionsDone(duration)
    self:DebugMessage(self:DebugFunctionsDoneText(), duration)
end
end -- (Track which Functions has been Called so far)

function DCAF.Story:_getGameMasterMenu()
    DCAF.Story._gmMenu = DCAF.Story._gmMenu or DCAF.Menu:New("[GM Only]")
    return DCAF.Story._gmMenu
end

function DCAF.Story:AddMenu(name)
    Debug("DCAF.Story:AddMenu :: name: " .. DumpPretty(name))
    name = name or self.Name
    self._menu = self:_getGameMasterMenu():New(name)
    return self._menu
end

function DCAF.Story:GetMenu()
    self._menu = self._menu or self:AddMenu()
    return self._menu
end

function DCAF.Story:AddCommand(text, func)
    Debug("DCAF.Story:AddCommand :: text: " .. DumpPretty(text))
    self:GetMenu():NewCommand(text, func)
end

function DCAF.Story:AddStartMenu(text)
    return self:GetMenu():NewCommand(text or "Start", function(menu)
        self:Start()
        menu:Remove(false)
    end)
end

function DCAF.Story:AddDebugCommand(text, func)
    Debug(self.Name..":AddDebugCommand :: text: "..Dump(text).." :: func: "..Dump(func))
    if not self:IsDebug() then return end
    if not isAssignedString(text) then return Error("DCAF.Story:AddDebugCommand :: `text` must be assigned string, but was: "..DumpPretty(text)) end
    if not isFunction(func) then return Error("DCAF.Story:AddDebugCommand :: `func` must be function, but was: "..DumpPretty(func)) end
    local storyMenu = self:GetMenu()
    if not self._menu.debugMenu then
        self._menu.debugMenu = storyMenu:New("DEBUG")
    end
    return self._menu.debugMenu:NewCommand(text, func)
end

function DCAF.Story:InitFlightMenuSound(file)
    if not isAssignedString(file) then return Error(self.Name..":InitFlightMenuSound :: `file` must be assigned string, but was") end
    self._flightMenuSoundFile = file
end

function DCAF.Story:AddFlightMenu(text, soundFile)
    Debug(self.Name..":AddFlightMenu :: text: "..Dump(text))
    if not self.AssignedFlight then return Error(self.Name..":AddFlightMenu :: no flight was assigned") end
    if not isAssignedString(text) then return Error(self.Name..":AddFlightMenu :: `text` must be assigned string, but was") end
    if not isAssignedString(soundFile) then soundFile = self._flightMenuSoundFile end
    if isAssignedString(soundFile) then MessageTo(self.AssignedFlight.Group, soundFile) end
    return DCAF.Menu:New(text, self.AssignedFlight.Group)
end

function DCAF.Story:AddFlightCommand(text, func, soundFile)
    Debug(self.Name..":AddFlightCommand :: text: "..Dump(text))
    if not self.AssignedFlight then return Error(self.Name..":AddFlightCommand :: no flight was assigned") end
    if not isAssignedString(soundFile) then soundFile = self._flightMenuSoundFile end
    if isAssignedString(soundFile) then MessageTo(self.AssignedFlight.Group, soundFile) end
    return DCAF.Menu:NewCommand(text, func, self.AssignedFlight.Group)
end

do -- ||||||||||||||||||||||    Using a Synthetic Controller    ||||||||||||||||||||||
function DCAF.Story:InitSyntheticController(ttsChannel)
    Debug("DCAF.Story:InitSyntheticController :: "..self.Name.." :: ttsChannel: " .. Dump(ttsChannel))
    if ttsChannel == false then
        self.TTS_Controller = nil
    else
        self.TTS_Controller = ttsChannel
    end
    if self.TTS_Controller then
        self:EnableAssignFlight(function(flight)
            self.TTS_Controller:InitFlightVariable(flight.CallSignPhonetic)
            self:AssignFlight(flight)
        end)
    else
        self:DisableAssignFlight()
    end
    return self
end

function DCAF.Story:IsSyntheticController()
    return self.TTS_Controller
end

function DCAF.Story:SendSyntheticController(message, delay)
    if not self:IsSyntheticController() then return Error("DCAF.Story:SendSyntheticController :: synthetic controller is not enabled") end
    if isNumber(delay) and delay > 0 then 
        return self:SendDelayed(delay, self.TTS_Controller, message)
    else
        return self:Send(self.TTS_Controller, message)
    end
end

function DCAF.Story:EnableSyntheticController(ttsChannel, preSelect, allowReSelect, textHumanController, textSyntheticController)
    Debug("DCAF.Story:EnableSyntheticController :: "..self.Name.." :: ttsChannel: " .. Dump(ttsChannel).." :: preSelect: "..DumpPretty(preSelect).." :: allowReSelect: "..DumpPretty(allowReSelect))
    if not isClass(ttsChannel, DCAF.TTSChannel) then return Error("DCAF.Story:EnableSyntheticController :: `ttsChannel` must be #"..DCAF.TTSChannel.ClassName..", but was: "..DumpPretty(ttsChannel)) end
    if not isBoolean(allowReSelect) then allowReSelect = true end
    if not isAssignedString(textHumanController) then textHumanController = "Use Human Controller" end
    if not isAssignedString(textSyntheticController) then textSyntheticController = "Use Synthetic Controller" end
    local text
    if preSelect == true and not self._isSyntheticControllerInitialized then
        self:InitSyntheticController(ttsChannel)
        self._isSyntheticControllerInitialized = true
    end
    if self.TTS_Controller then text = textHumanController else text = textSyntheticController end
    local story = self
    self:AddCommand(text, function(menu)
        if story.TTS_Controller then
            story:InitSyntheticController(false)
        else
            story:InitSyntheticController(ttsChannel)
        end
        menu:Remove(false)
        if allowReSelect then
            story:EnableSyntheticController(ttsChannel)
        end
    end)
end
end -- (Using a Synthetic Controller)

do -- ||||||||||||||||||||||    Assigning Flight from GM Menu    ||||||||||||||||||||||
DCAF.Story.CallSign =
{
    Squadrons = {
        ["75th"] = {
            Names = {
                [1] = "Blackbird",
                [2] = "Condor",
                [3] = "Magpie",
            },
            Numbers = { 1, 2, 3, 4, 5 }
        },
        ["119th"] = {
            Names = {
                [1] = "Devil",
                [2] = "Hell",
                [3] = "Satan",
            },
            Numbers = { 1, 2, 3, 4, 5 }
        },
        ["335th"] = {
            Names = {
                [1] = "Chief",
                [2] = "Dallas",
                [3] = "Eagle",
            },
            Numbers = { 1, 2, 3, 4, 5 }
        },
    }
}

DCAF.Story.Nicknames = {
    _typeNicknames = {
        ["F-15ESE"] = "Mudhen",
        ["F-16C_50"] = "Viper",
        ["FA-18C_hornet"] = "Hornet"
    }
}

function DCAF.Flight:New(group, callSign, callSignPhonetic)
    local flight = DCAF.clone(DCAF.Flight)
    flight.CallSign = callSign
    flight.CallSignPhonetic = callSignPhonetic
    flight.Group = group
    return flight
end

function DCAF.Story.Nicknames:GetTypeNickname(group)
    local typeName = group:GetTypeName()
Debug("nisse - DCAF.Story.Nicknames :: typeName: " .. typeName)
    return self._typeNicknames[typeName] or typeName
end

function DCAF.Story.CallSign:SelectFromGM_Menu(gm_mainMenu, funcDone, text)
    Debug("DCAF.Story.CallSign:SelectFromMenu")
    if not isAssignedString(text) then text = "Select Flight" end
    local menu = gm_mainMenu:New(text)
    for squadronName, squadronInfo in pairs(DCAF.Story.CallSign.Squadrons) do
        local squadronMenu = menu:AddMenu(squadronName)
        for _, name in ipairs(squadronInfo.Names) do
            local nameMenu = squadronMenu:New(name)
            for _, number in ipairs(squadronInfo.Numbers) do
                nameMenu:NewCommand(number, function()
                    local phoneticNumber = PhoneticAlphabet:ConvertNumber(number)
                    local callSign = name .. " " .. phoneticNumber
                    local ok, err = pcall(function() funcDone(callSign) end)
                    if not ok then Error("DCAF.Story.CallSign:SelectFromGM_Menu_AddCommand :: error when invoking menu function: "..DumpPretty(err)) end
                end)
            end
        end
    end
    return menu
end

--- Builds GM menus to select a flight call-sign from a standardized structure
---@param funcOnSelected any
function DCAF.Story:EnableSelectCallsign(funcOnSelected)
    if not isFunction(funcOnSelected) then return Error("DCAF.Story:EnableSelectCallsign :: `funcOnSelected` must be function, but was: " .. DumpPretty(funcOnSelected)) end
    local selectCallSign
    local function _selectCallSign(callSign)
        self._menuSelectCallSign:Remove(false)
        Debug(self.Name .. ":EnableSelectCallsign_selectCallSign :: callSign: " .. Dump(callSign))
        DCAF.delay(function()
            Debug(self.Name .. ":EnableSelectCallsign_selectCallSign :: re-creating call sign selection")
            self._menuSelectCallSign = DCAF.Story.CallSign:SelectFromGM_Menu(self._menu, selectCallSign, "Flight: " .. callSign)
        end, .1)
        pcall(function() funcOnSelected(callSign) end)
    end
    selectCallSign = _selectCallSign
    self._menuSelectCallSign = DCAF.Story.CallSign:SelectFromGM_Menu(self._menu, selectCallSign)
end

function DCAF.Story:EnableSelectCallsign(removeParentMenu)
    if not isBoolean(removeParentMenu) then removeParentMenu = false end
    if self._menuSelectCallSign then
        self._menuSelectCallSign:Remove(removeParentMenu)
        self._menuSelectCallSign = nil
    end
end

local function getCallSign(group)
    local groupName = group.GroupName
    local split = stringSplit(groupName, '-')

    local function parseNumber()
        local text = split[2]
        local number = tonumber(text)
        if number then return number end
        local testText = string.sub(text, 1, 1)
        number = tonumber(testText)
        if not number then return end

        for i = 2, #text do
            testText = text.sub(1, i)
            local testNumber = tonumber(testText)
            if not testNumber then break end
            number = testNumber
        end
        return number
    end

    if #split == 1 then split = stringSplit(groupName, ' ') end
    if #split == 1 then return groupName end
    local number = parseNumber()
    if not number then return Error("getCallSign :: unexpected group name format: " .. groupName, groupName) end
    local phoneticNumber = PhoneticAlphabet:ConvertNumber(number)
    local callSign = split[1] .. "-" .. number
    local callSignPhonetic = split[1] .. " " .. phoneticNumber
    return callSign, callSignPhonetic, groupName
end

local function getClientFlights(filterCoalition)
    if filterCoalition ~= nil then
        local validCoalition = Coalition.Resolve(filterCoalition, true)
        if not validCoalition then return Error("getClientFlights :: cannot resolve coalition: " .. DumpPretty(filterCoalition)) end
        filterCoalition = validCoalition
    else
        filterCoalition = coalition.side.BLUE
    end
    local setClients = SET_CLIENT:New():FilterOnce() -- FilterCoalitions(filterCoalition):FilterOnce()
    local typesIndex = {
        -- key   = group type
        -- value = dictionary { key = call-sign, value = GROUP }
    }
    local groupsIndex = {
        -- key   = group name
        -- value = GROUP
    }
    setClients:ForEachClient(function(client)
        if client:CountPlayers() == 0 then return end
        local groupName = client:GetClientGroupName()
        if groupsIndex[groupName] then return end
        local group = getGroup(groupName)
        if not group then return Error("getClientFlights :: cannot get group from name '" .. groupName .. " :: ODD") end
        groupsIndex[groupName] = group
        local typeName = DCAF.Story.Nicknames:GetTypeNickname(group)
        local typesDict = typesIndex[typeName]
        local callSign, callSignPhonetic = getCallSign(group)
        if not callSignPhonetic then return Error("getClientFlights :: cannot get call-sign from group '" .. groupName) end
        if not typesDict then
            typesDict = {}
            typesIndex[typeName] = typesDict
        end
        typesDict[groupName] = DCAF.Flight:New(group, callSign, callSignPhonetic)
    end)
    return typesIndex
end

local function assignFlightFromGM_Menu(story, funcDone, text, filterCoalition)
    local gm_menu = story:GetMenu()
    local clientFlights = getClientFlights(filterCoalition)
    local menu
    for type, callSigns in pairs(clientFlights) do
        menu = menu or gm_menu:New(text)
        local typeMenu = menu:New(type)
        for groupName, flight in pairs(callSigns) do
            typeMenu:NewCommand(groupName, function()
                funcDone(flight)
                -- local ok, err = pcall(function() funcDone(flight) end)
                -- if not ok then Error("DCAF.Story/assignFlightFromGM_Menu :: error when invoking menu function: "..DumpPretty(err)) end
            end)
        end
    end
    return menu
end

function DCAF.Story:EnableAssignFlight(funcOnAssigned, text)
    Debug("DCAF.Story:EnableAssignFlight :: "..self.Name.." :: funcOnSelected: "..DumpPretty(funcOnAssigned).." :: text: "..DumpPretty(text))
    local assignFlight
    if self._menuAssignFlightPlaceHolder then self._menuAssignFlightPlaceHolder:Remove(false) end

    local function _assignFlight(flight)
        self._menuAssignFlight:Remove(false)
        Debug(self.Name .. ":EnableAssignFlight :: callSign: " .. Dump(flight.CallSign))
        DCAF.delay(function()
            Debug(self.Name .. ":EnableAssignFlight_selectCallSign :: re-creating call sign selection")
            self._menuAssignFlight = assignFlightFromGM_Menu(self, assignFlight, "Flight: "..flight.CallSign)
        end, .1)
        self:AssignFlight(flight)
    end

    assignFlight = _assignFlight
    if not isAssignedString(text) then text = "Select Flight" end
    self._menuAssignFlight = assignFlightFromGM_Menu(self, assignFlight, text)
    if not self._menuAssignFlight then
        local storyMenu = self:GetMenu()
        self._menuAssignFlightPlaceHolder = storyMenu:NewCommand("(no flights available)", function() --[[ ignore ]] end)
    end
    if not self._playerEntersUnitEventSink then
        local story = self
        self._playerEntersUnitEventSink = BASE:New()
        self._playerEntersUnitEventSink:HandleEvent(EVENTS.PlayerEnterAircraft, function(_, _)
            if self._menuAssignFlight then self._menuAssignFlight:Remove(false) end
            story:EnableAssignFlight(funcOnAssigned, text)
        end)
    end
end

function DCAF.Story:DisableAssignFlight(removeParentMenu)
    if not isBoolean(removeParentMenu) then removeParentMenu = false end
    if self._menuAssignFlight then
        self._menuAssignFlight:Remove(removeParentMenu)
        self._menuAssignFlight = nil
    end
end
end -- (Assigning Flight from GM Menu)

do -- ||||||||||||||||||||||    GBAD - SAM Ambush     ||||||||||||||||||||||
function DCAF.Story:SetupSamAmbushForTarget(sam, target, options)
    if not DCAF.GBAD then return Error("DCAF.Story:SetupSamAmbushForTarget :: DCAF.GBAD is not loaded") end
    Debug(self.Name..":SetupSamAmbushForTarget")
    return DCAF.GBAD.Ambush:NewForTarget(sam, target, options)
end
end -- (GBAD - SAM Ambush)

Trace("\\\\\\\\\\ DCAF.Story.lua was loaded //////////")
