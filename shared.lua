local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")
local Constants = require("nuzi-ownersmark/constants")

local Log = Core.Log
local Runtime = Core.Runtime
local Settings = Core.Settings

local logger = Log.Create(Constants.ADDON_NAME or "Nuzi Owner's Mark")

local Shared = {
    settings = nil
}

local store = Settings.CreateAddonStore(Constants, {
    read_mode = "serialized_then_flat",
    write_mode = "serialized_then_flat",
    read_raw_text_fallback = true,
    write_mirror_paths = {
        Constants.LEGACY_SETTINGS_FILE_PATH
    },
    log_name = Constants.ADDON_NAME or "Nuzi Owner's Mark"
})

Shared.store = store
Shared.NormalizeDeltaMs = Runtime.NormalizeDeltaMs

function Shared.GetStore()
    return store
end

function Shared.LoadSettings()
    local settings = store:Load()
    Shared.settings = settings
    return settings
end

function Shared.EnsureSettings()
    local settings = store:Ensure()
    Shared.settings = settings
    return settings
end

function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    local ok = store:Save()
    Shared.settings = settings
    if not ok then
        logger:Err("Failed to save settings.")
    end
    return ok
end

return Shared
