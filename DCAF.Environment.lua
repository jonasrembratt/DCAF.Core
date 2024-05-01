DCAF.Environment = {
    IsServer = false,
    IsATISEnabled = false,
    SRS = {
        Port = 5004,
        GoogleKeyPath = [[C:\DCAF\Auth\dcaf-google-317928189eb0.json]]
    }
}

DCAF.Folders = {
    GoogleDrive = "C:\\DCAF\\_test_fileOutput",
    SRS = [[C:\Program Files\DCS-SimpleRadio-Standalone]]
    -- SRS = [[C:\Program Files\DCS-SimpleRadio-Standalone]] -- (standard)
}

local function updateMSRS()
    MESSAGE.SetMSRS(DCAF.Folders.SRS, DCAF.Environment.SRS.Port, DCAF.Environment.SRS.GoogleKeyPath, 305, radio.modulation.FM, "female", "en-US", nil, coalition.side.BLUE)
    Debug("SRS was configured :: port: " .. Dump(DCAF.Environment.SRS.Port) .. " :: folder: " .. Dump(DCAF.Folders.SRS))
end

function DCAF.Environment:ConfigureSRS(path, port, googleKeyPath)
    DCAF.Folders.SRS = path or DCAF.Folders.SRS
    DCAF.Environment.SRS.Port = port or DCAF.Environment.SRS.Port
    DCAF.Environment.SRS.GoogleKeyPath = googleKeyPath or DCAF.Environment.SRS.GoogleKeyPath
    updateMSRS()
end

function DCAF.Environment.SRS:IsSSML()
    return fileExists(DCAF.Environment.SRS.GoogleKeyPath)
end

--- Set up SRS messages ---
if MESSAGE then
    updateMSRS()
end

Trace("\\\\\\\\\\ DCAF.Environment.lua was loaded //////////")