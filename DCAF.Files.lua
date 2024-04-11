-- requires DCAF.Folders.lua

DCAF.File = {
    ClassName = "DCAF.File"
}

local function errorIfNotDesanitized(prefix)
    if not os or not io or not lfs then
        error(prefix .. " :: Please desanitize <DCS OpenBeta>\\Scripts\\MissionScripting.lua") 
    end
end

function DCAF.File.MakeName(folder, filename)
    if not isAssignedString(folder) then
        error("DCAF.File.MakeName :: `folder` must be assigned string, but was: " .. DumpPretty(folder)) end
        
    if not isAssignedString(filename) then
        error("DCAF.File.MakeName :: `filename` must be assigned string, but was: " .. DumpPretty(filename)) end
        
    if DCAF.Folders[folder] then 
        folder = DCAF.Folders[folder]
    end
    return folder .. "\\" .. filename
end

function DCAF.File.MakeDayFolder(parentFolder)
    errorIfNotDesanitized("DCAF.File.MakeDayFolder")        

    if not isAssignedString(parentFolder) then
        error("DCAF.File:MakeDayFolder :: `parentFolder` must be assigned string, but was: " .. DumpPretty(parentFolder)) end
    
    return DCAF.File.MakeName(parentFolder, os.date("%Y%m%d"))
end

function DCAF.File:OpenCSV(path, captions)
    errorIfNotDesanitized("DCAF.File:NewCSV")

    local file = DCAF.clone(DCAF.File)
    file._f = assert(io.open(path, "ab"))
    if not DCAF.File.Exists(path) then
        file:WriteCSVLine(captions)
    end
    return file
end

function DCAF.File:WriteCSVLine(data)
Debug("nisse - DCAF.File:WriteCSVLine :: data: " .. DumpPretty(data) .. " :: #data: " .. #data)    
    local line = data[1]
    for i = 2, #data, 1 do
        if data[i] ~= nil then
            line = line .. ',' .. data[i]
        else
            line = line .. ','
        end
    end
    line = line .. "\n"
Debug("nisse - DCAF.File:WriteCSVLine :: line: " .. line)    
    self._f:write(line)
end

function DCAF.File:Close()
    self._f:close()
end

function DCAF.File.IsFolder(name)
    if not isAssignedString(name)~="string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    lfs.chdir(cd)
    return is
end

function DCAF.File.Exists(name)
    local f=io.open(name,"r")
    if f ~= nil then io.close(f) return true else return false end
 end
 
 --- Check if a directory exists in this path
--  function DCAF.File.IsFolder(path)
--     -- "/" works on both Unix and Windows
--     return DCAF.File.Exists(path.."/")
--  end

 function DCAF.File.MakeFolder(path)
    os.execute("mkdir " .. path)
 end