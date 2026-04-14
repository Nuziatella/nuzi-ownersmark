local api = require("api")
local Constants = require("nuzi-ownersmark/constants")

local Shared = {
    settings = nil
}

local addOnsBasePath = nil
pcall(function()
    if type(api) == "table" and type(api.baseDir) == "string" and api.baseDir ~= "" then
        addOnsBasePath = string.gsub(api.baseDir, "\\", "/")
        return
    end
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local info = debug.getinfo(1, "S")
        local source = type(info) == "table" and tostring(info.source or "") or ""
        if string.sub(source, 1, 1) == "@" then
            source = string.sub(source, 2)
        end
        source = string.gsub(source, "\\", "/")
        local folder = string.match(source, "^(.*)/[^/]+$")
        if folder ~= nil then
            local base = string.match(folder, "^(.*)/[^/]+$")
            if base ~= nil and base ~= "" then
                addOnsBasePath = base
            end
        end
    end
end)

---Returns the absolute path candidate for an addon-relative path.
---@param path string
---@return string|nil
local function getFullPath(path)
    if addOnsBasePath == nil or addOnsBasePath == "" then
        return nil
    end
    local fullPath = tostring(addOnsBasePath) .. "/" .. tostring(path or "")
    local normalizedPath = string.gsub(fullPath, "/+", "/")
    return normalizedPath
end

---Returns possible full path variants for a settings file.
---@param path string
---@return table
local function getFullPathCandidates(path)
    local rawPath = tostring(path or "")
    local candidates = {}
    local seen = {}

    local function add(candidate)
        if type(candidate) ~= "string" or candidate == "" then
            return
        end
        candidate = string.gsub(candidate, "/+", "/")
        if seen[candidate] then
            return
        end
        seen[candidate] = true
        candidates[#candidates + 1] = candidate
    end

    add(getFullPath(rawPath))

    local addonFolder = string.match(rawPath, "^([^/]+)/")
    if addonFolder ~= nil and addOnsBasePath ~= nil then
        local lowerBase = string.lower(tostring(addOnsBasePath))
        local lowerFolder = "/" .. string.lower(addonFolder)
        if string.sub(lowerBase, -string.len(lowerFolder)) == lowerFolder then
            local stripped = string.gsub(rawPath, "^" .. addonFolder .. "/?", "")
            add(tostring(addOnsBasePath) .. "/" .. stripped)
        end
    end

    return candidates
end

---Parses a scalar value from the flat settings file format.
---@param rawValue any
---@return any
local function parseScalar(rawValue)
    local value = tostring(rawValue or "")
    value = string.match(value, "^%s*(.-)%s*$") or value
    if value == "" then
        return nil
    end
    if value == "true" then
        return true
    end
    if value == "false" then
        return false
    end
    local quoted = string.match(value, '^"(.*)"$')
    if quoted ~= nil then
        quoted = string.gsub(quoted, "\\\\", "\\")
        quoted = string.gsub(quoted, '\\"', '"')
        return quoted
    end
    return tonumber(value)
end

---Encodes a scalar Lua value into the flat settings file format.
---@param value any
---@return string|nil
local function encodeScalar(value)
    local valueType = type(value)
    if valueType == "boolean" then
        return value and "true" or "false"
    end
    if valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        local escaped = string.gsub(value, "\\", "\\\\")
        escaped = string.gsub(escaped, '"', '\\"')
        return '"' .. escaped .. '"'
    end
    return nil
end

---Reads a serialized settings table through the addon API if available.
---@param path string
---@return table|nil
local function readSerializedSettings(path)
    if api.File == nil or api.File.Read == nil then
        return nil
    end
    local ok, result = pcall(function()
        return api.File:Read(path)
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

---Reads a flat settings file directly from disk.
---@param path string
---@return table|nil
local function readFlatSettingsFile(path)
    if type(io) ~= "table" or type(io.open) ~= "function" then
        return nil
    end

    for _, fullPath in ipairs(getFullPathCandidates(path)) do
        local file = nil
        local ok = pcall(function()
            file = io.open(fullPath, "rb")
        end)
        if ok and file ~= nil then
            local contents = nil
            pcall(function()
                contents = file:read("*a")
            end)
            pcall(function()
                file:close()
            end)
            if type(contents) == "string" and contents ~= "" then
                local output = {}
                for key, rawValue in string.gmatch(contents, "([%a_][%w_]*)%s*=%s*([^,\r\n}]+)") do
                    local parsed = parseScalar(rawValue)
                    if parsed ~= nil then
                        output[key] = parsed
                    end
                end
                if next(output) ~= nil then
                    return output
                end
            end
        end
    end

    return nil
end

---Returns whether either supported settings file format exists for the path.
---@param path string
---@return boolean
local function hasTableFile(path)
    if type(readSerializedSettings(path)) == "table" then
        return true
    end
    if type(readFlatSettingsFile(path)) == "table" then
        return true
    end
    return false
end

---Writes a settings table in the flat text format.
---@param path string
---@param value table
---@return boolean
local function writeFlatSettingsFile(path, value)
    if type(value) ~= "table" or type(io) ~= "table" or type(io.open) ~= "function" then
        return false
    end

    local keys = {}
    for key, item in pairs(value) do
        if encodeScalar(item) ~= nil then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)

    local lines = { "{" }
    for _, key in ipairs(keys) do
        lines[#lines + 1] = "    " .. tostring(key) .. " = " .. encodeScalar(value[key]) .. ","
    end
    lines[#lines + 1] = "}"
    local payload = table.concat(lines, "\n")

    for _, fullPath in ipairs(getFullPathCandidates(path)) do
        local file = nil
        local ok = pcall(function()
            file = io.open(fullPath, "wb")
        end)
        if ok and file ~= nil then
            local writeOk = pcall(function()
                file:write(payload)
            end)
            pcall(function()
                file:close()
            end)
            if writeOk then
                return true
            end
        end
    end

    return false
end

---Writes a settings table through the addon API if available.
---@param path string
---@param value table
---@return boolean
local function writeSerializedSettings(path, value)
    if api.File == nil or api.File.Write == nil then
        return false
    end
    local ok = pcall(function()
        api.File:Write(path, value)
    end)
    return ok and true or false
end

---Copies missing default values into a settings table.
---@param target table
---@param defaults table
---@return boolean
local function copyDefaults(target, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
                changed = true
            end
            if copyDefaults(target[key], value) then
                changed = true
            end
        elseif target[key] == nil then
            target[key] = value
            changed = true
        end
    end
    return changed
end

---Normalizes frame delta values into milliseconds.
---@param dt any
---@return number
function Shared.NormalizeDeltaMs(dt)
    local value = tonumber(dt) or 0
    if value < 0 then
        value = 0
    end
    if value > 0 and value < 5 then
        value = value * 1000
    end
    return value
end

---Loads and merges persisted settings for the addon.
---@return table
function Shared.LoadSettings()
    local settings = nil
    local migrated = false
    local fileSettings = readSerializedSettings(Constants.SETTINGS_FILE_PATH)
    if type(fileSettings) ~= "table" then
        fileSettings = readFlatSettingsFile(Constants.SETTINGS_FILE_PATH)
    end
    if type(fileSettings) ~= "table" then
        fileSettings = readSerializedSettings(Constants.LEGACY_SETTINGS_FILE_PATH)
        if type(fileSettings) == "table" then
            migrated = true
        end
    end
    if type(fileSettings) ~= "table" then
        fileSettings = readFlatSettingsFile(Constants.LEGACY_SETTINGS_FILE_PATH)
        if type(fileSettings) == "table" then
            migrated = true
        end
    end
    if api.GetSettings ~= nil then
        settings = api.GetSettings(Constants.ADDON_ID)
    end
    if type(settings) ~= "table" then
        settings = {}
    end
    if type(fileSettings) == "table" then
        for key, value in pairs(fileSettings) do
            settings[key] = value
        end
    end

    Shared.settings = settings
    if copyDefaults(settings, Constants.DEFAULT_SETTINGS) or type(fileSettings) ~= "table" or migrated or not hasTableFile(Constants.SETTINGS_FILE_PATH) then
        Shared.SaveSettings()
    end
    return settings
end

---Returns the loaded settings table, loading it first if needed.
---@return table
function Shared.EnsureSettings()
    if Shared.settings == nil then
        return Shared.LoadSettings()
    end
    return Shared.settings
end

---Persists current settings to disk and the addon settings store.
---@return nil
function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    local saved = writeFlatSettingsFile(Constants.SETTINGS_FILE_PATH, settings)
    if not saved then
        saved = writeSerializedSettings(Constants.SETTINGS_FILE_PATH, settings)
    else
        writeSerializedSettings(Constants.SETTINGS_FILE_PATH, settings)
    end
    if api.SaveSettings ~= nil then
        api.SaveSettings()
    end
    if not saved and api.Log ~= nil and api.Log.Err ~= nil then
        pcall(function()
            api.Log:Err("Nuzi Owner's Mark failed to write settings file: " .. tostring(Constants.SETTINGS_FILE_PATH))
        end)
    end
end

return Shared
