DCAF.Draw = {
    ClassName = "DCAF.Draw",
    ----
    IconRadius = {
        Friendly = NauticalMiles(0.3),
        Hostile = NauticalMiles(0.3),
        Unknown = NauticalMiles(0.3)
    },
    IconFillColor = {
        Friendly = Color.NatoFriendly,
        Hostile = Color.NatoHostile,
        Unknown = NauticalMiles(0.3)
    }
}

DCAF.Icon = {
    ClassName = "DCAF.Icon",
    ----
    _markIds = {}
}

local function validateArgs(prefix, location, coalition, radius)
    local validLocation = DCAF.Location.Resolve(location)
    if not validLocation then return Error(prefix .. " :: `location` could not be resolved from: " .. DumpPretty(location)) end
    local validCoalition
    if coalition ~= nil then
        validCoalition = Coalition.Resolve(coalition)
        if not validCoalition then return Error(prefix .. " :: `coalition` could not be resolved from: " .. DumpPretty(coalition)) end
    end
    if radius ~= nil then
        if not isNumber(radius) or radius < 0 then
            return Error(prefix .. " :: `radius` must be positive number, but was: " .. DumpPretty(radius))
        end
    end
    return {
        Location = validLocation,
        Coalition = validCoalition,
        Radius = radius
    }
end

function DCAF.Draw:NatoUnit(unitClass, location, coalition, radius)

end

function DCAF.Draw:NatoFriendly(location, radius)
    return self
end

function DCAF.Draw:NatoHostile(location, radius)
    local args = validateArgs("DCAF.Draw:NatoHostile", location, radius)
    if not args then return end
    radius = args.Radius or self.IconRadius.Hostile
    local coord0 = args.Location:GetCoordinate()
    local coord1 = coord0:Translate(radius, 360)
    local coord2 = coord0:Translate(radius, 90)
    local coord3 = coord0:Translate(radius, 180)
    local coord4 = coord0:Translate(radius, 270)

end

function DCAF.Draw:NatoArmor(coalition, location, radius)
    
end

function DCAF.Draw:NatoCombineManoeuvre(coalition, location, radius)
    
end

function DCAF.Draw:NatoArtillery(coalition, location, radius)

end

function DCAF.Icon:New(location, coalition, colorStroke, colorFill, alpha, readOnly)
    local args = validateArgs("DCAF.Icon:New", location, coalition)
    if not args then return end
    local icon = DCAF.clone(DCAF.Icon)
    icon.Name = args.Location.Name
    icon.Coalition = Coalition.ToNumber(args.Coalition)
    icon.ColorStroke = colorStroke
    icon.ColorFill = colorFill
    icon.Alpha = alpha
    icon.ReadOnly = readOnly
    return icon
end

function DCAF.Icon:NewNamed(name, location, coalition, colorStroke, colorFill)
    if not isAssignedString(name) then return Error("DCAF.Icon:NewNamed :: `name` must be assigned string, but was: " .. DumpPretty(name)) end
    local icon = DCAF.Icon:New(location, coalition, colorStroke, colorFill)
    icon.Name = name
    return icon
end

function DCAF.Icon:Quad(coord0, coord1, coord2, coord3, colorStroke, colorFill, alpha, lineType)
    local coalition = self.Coalition
    colorStroke = colorStroke or self.ColorStroke
    colorFill = colorStroke or self.ColorFill
    alpha = alpha or self.Alpha
    local id = coord0:QuadToAll(coord1, coord2, coord3, coalition, colorStroke, alpha, colorFill, alpha, lineType, self.ReadOnly)
    return self:_addMarkID(id)
end

function DCAF.Icon:_addMarkID(id)
    self._markIds[#self._markIds+1] = id
    return self
end

function DCAF.Icon:Erase()
    for _, id in pairs(self._markIds) do
        COORDINATE:RemoveMark(id)
    end
    return self
end