-- local DCAF_SPAWNSTATIC_MAP = {
    
-- }

local function getSpawnStaticFrom(unit)
    local typeName = unit:GetTypeName()
    local categoryName = unit:GetCategoryName()
    local spawnStatic = SPAWNSTATIC:NewFromType(typeName, categoryName)
    if not spawnStatic then
        return Error("getSpawnStaticFrom :: cannot get SPAWNSTATIC from type: '" .. Dump(typeName) .. "' :: categoryName: " .. Dump(categoryName)) end

    return spawnStatic
end

--- Attempts replacing a unit with a static equivalent
-- @param #Any source :: name of UNIT/GROUP, or a UNIT/GROUP
-- @param #number damage :: specifies damage [0,1] (0 = no damage; 1 = fully destroyed)
-- @param #number damageAge :: specifies how long (seconds) since damage was sustained (is used to create smoke effects)
-- @return #table :: list of #STATIC
function SubstituteWithStatic(source, damage, damageAge)
Debug("nisse - SubstituteWithStatic :: (aaa)...")
    local unit = getUnit(source)
    if not unit then
        local group = getGroup(source)
        if not group then 
            return Warning("SubstituteWithStatic :: cannot resolve source: " .. DumpPretty(source) .. " :: IGNORES") end

        local statics = {}
        for _, u in ipairs(group:GetUnits()) do
            local static = SubstituteWithStatic(u, damage, damageAge)
            table.insert(statics, static[1])
        end
        return statics
    end

    if not isNumber(damage) then
        damage = 0
    end

    if isVariableValue(damageAge) then
        damageAge = damageAge:GetValue()
    end
    if not isNumber(damageAge) then
        if damage == 0 then
            damageAge = 0
        else
            damageAge = 9999
        end
    end

    local spawnStatic = getSpawnStaticFrom(unit)
    if not spawnStatic then
        return Error("SubstituteWithStatic :: cannot resolve static from '" .. unit.UnitName .. "'") end

    local coord = unit:GetCoordinate()
    if damage > 0 then
        spawnStatic:InitDead(damage >= 0.6)
    end
    if damageAge > Minutes(20) then
        -- no effect
    elseif damageAge > Minutes(10) then
        coord:BigSmokeSmall(.05)
    elseif damageAge > Minutes(5) then
        coord:BigSmokeSmall(.3)
    elseif damageAge > Minutes(3) then
        coord:BigSmokeSmall(.5)
    else
        coord:BigSmokeSmall(1)
    end

    local heading = unit:GetHeading()
Debug("nisse - SubstituteWithStatic :: substitutes unit '" .. unit.UnitName .. "' with static")
    if unit:IsAlive() then
        unit:Destroy()
    end
    return { spawnStatic:SpawnFromCoordinate(coord, heading) }
end

--- Attempts replacing all units of a #GROUP with a static equivalent
-- @param #number damage - specifies damage [0,1] (0 = no damage; 1 = fully destroyed)
-- @param #number damageTime - (can also be #VariableValue) specifies how long (seconds) since damage was sustained (is used to create smoke effects)
-- @return #table - list of #STATIC
function GROUP:SubstituteWithStatic(damage, damageAge)
    return SubstituteWithStatic(self, damage, damageAge)
end

--- Attempts replacing the #UNIT with a static equivalent
-- @param #number damage - specifies damage [0,1] (0 = no damage; 1 = fully destroyed)
-- @param #number damageTime - (can also be #VariableValue) specifies how long (seconds) since damage was sustained (is used to create smoke effects)
-- @return #table - list of #STATIC
function UNIT:SubstituteWithStatic(damage, damageAge)
    return SubstituteWithStatic(self, damage, damageAge)
end