--
--
-- ### Author: **nielsvaes/coconutcockpit**
--
-- ===
-- @module StrobeUnit


STROBE_UNIT = {
    ClassName = "STROBE_UNIT",
}

-- Function to find a unit by name and initialize it with strobe properties
function STROBE_UNIT:FindByName(unit_name)
    -- Inherit properties from the UNIT class and assign to self
    local self = BASE:Inherit(self, UNIT:FindByName(unit_name))
    -- If the unit is not found, log an error message
    if self == nil then
        self:E("Couldn't find a unit with the name " .. unit_name)
    end
    -- Initialize strobe properties
    self.strobe_active = false
    self.on_time = 0.08 -- Duration the strobe is on
    self.burst_interval = 0.5 -- Interval between strobe bursts
    self.visible_chance = 100 -- Chance for the strobe to be visible
    return self
end

-- Function to start the strobe effect on the unit
function STROBE_UNIT:StartStrobe(bursts)
    self.strobe_active = true -- Activate the strobe
    bursts = bursts or 2 -- Default number of bursts if not specified

    -- Call the private __Strobe function to handle the strobe logic
    self:__Strobe(bursts)
end

-- Function to stop the strobe effect on the unit
function STROBE_UNIT:StopStrobe()
    self.strobe_active = false -- Deactivate the strobe
    self:LaseOff() -- Turn off the laser (strobe effect)
end

-- Private function to handle the strobe logic
function STROBE_UNIT:__Strobe(bursts)
    -- Check if the strobe is active before proceeding
    if self.strobe_active then
        self:LaseOff() -- Ensure the laser is off before starting
        -- Loop through the number of bursts
        for index = 1, bursts do
            -- Check if the strobe should be visible based on chance
            if UTILS.PercentageChance(self.visible_chance) then
                -- Schedule the laser (strobe) to turn on based on timing calculations
                BASE:ScheduleOnce((self.on_time + self.burst_interval) * index, function()
Debug("*** BLINK ***")
                    self:LaseUnit(self, 1688, self.on_time)
                end )
            end
        end

        -- Calculate the total wait time before repeating the strobe effect
        local wait_time = 2 * bursts * (self.on_time + self.burst_interval)
        -- Schedule the next strobe effect after the wait time
        BASE:ScheduleOnce(wait_time, self.__Strobe, self, bursts)
    end
end