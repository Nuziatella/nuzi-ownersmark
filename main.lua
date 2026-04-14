local api = require("api")

local moduleErrors = {}

---Records a module load error for later logging.
---@param name string
---@param path string
---@param err any
---@return nil
local function recordModuleError(name, path, err)
    moduleErrors[#moduleErrors + 1] = string.format("%s via %s: %s", tostring(name), tostring(path), tostring(err))
end

---Attempts to load a module using both supported require path styles.
---@param name string
---@return table|nil
local function loadModule(name)
    local ok, mod = pcall(require, "nuzi-ownersmark/" .. name)
    if ok and mod ~= nil then
        return mod
    end
    if not ok then
        recordModuleError(name, "nuzi-ownersmark/" .. name, mod)
    end
    ok, mod = pcall(require, "nuzi-ownersmark." .. name)
    if ok and mod ~= nil then
        return mod
    end
    if not ok then
        recordModuleError(name, "nuzi-ownersmark." .. name, mod)
    end
    if ok and mod == nil then
        recordModuleError(name, "nuzi-ownersmark." .. name, "module returned nil")
    end
    return nil
end

local Constants = loadModule("constants")
local Shared = loadModule("shared")
local Tracker = loadModule("tracker")
local Ui = loadModule("ui")

local Addon = {
    name = Constants ~= nil and Constants.ADDON_NAME or "Nuzi Owner's Mark",
    author = Constants ~= nil and Constants.ADDON_AUTHOR or "Nuzi",
    version = Constants ~= nil and Constants.ADDON_VERSION or "1.0.0",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Tracks Owner's Mark on the player's summoned vehicle"
}

local updateAccumMs = 0
local lastRenderSignature = nil

---Clamps a numeric setting value into an allowed inclusive range.
---@param value any
---@param minValue number
---@param maxValue number
---@return number
local function clampSetting(value, minValue, maxValue)
    local number = tonumber(value) or minValue
    if number < minValue then
        return minValue
    end
    if number > maxValue then
        return maxValue
    end
    return number
end

---Returns whether all required modules loaded successfully.
---@return boolean
local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Tracker ~= nil and Ui ~= nil
end

---Logs any captured module load errors to chat.
---@return nil
local function logModuleErrors()
    if #moduleErrors == 0 then
        return
    end
    for _, detail in ipairs(moduleErrors) do
        if api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi Owner's Mark] Module load error: " .. tostring(detail))
        end
    end
end

---Renders the latest tracker state into the UI.
---@param viewModel table|nil
---@param settings table|nil
---@return nil
local function renderNow(viewModel, settings)
    if not modulesReady() then
        return
    end
    local ui = Ui
    local tracker = Tracker
    local shared = Shared
    viewModel = type(viewModel) == "table" and viewModel or tracker.GetSnapshot()
    settings = type(settings) == "table" and settings or shared.EnsureSettings()

    local signature = table.concat({
        tostring(settings.enabled),
        tostring(settings.show_main_window),
        tostring(settings.show_toggle_button),
        tostring(settings.show_warning_text),
        tostring(settings.show_warning_icon),
        tostring(settings.warning_text_size),
        tostring(settings.warning_text_color_index),
        tostring(settings.warning_icon_size),
        tostring(settings.button_size),
        tostring(viewModel.current_state),
        tostring(viewModel.current_time_text),
        tostring(viewModel.unit_name),
        tostring(viewModel.owner_name),
        tostring(viewModel.source_text),
        tostring(viewModel.source_label),
        tostring(viewModel.pending_present),
        tostring(viewModel.active_present),
        tostring(viewModel.expiring_present),
        tostring(viewModel.critical_present),
        tostring(viewModel.missing_present)
    }, "|")
    if signature == lastRenderSignature then
        return
    end
    lastRenderSignature = signature
    ui.Render(viewModel, settings)
end

---Persists a window position update.
---@param kind string
---@param x any
---@param y any
---@return nil
local function savePosition(kind, x, y)
    local shared = Shared
    local settings = shared.EnsureSettings()
    if kind == "button" then
        settings.button_x = tonumber(x) or settings.button_x
        settings.button_y = tonumber(y) or settings.button_y
    elseif kind == "warning_text" then
        settings.warning_text_x = tonumber(x) or settings.warning_text_x
        settings.warning_text_y = tonumber(y) or settings.warning_text_y
    elseif kind == "warning_icon" then
        settings.warning_icon_x = tonumber(x) or settings.warning_icon_x
        settings.warning_icon_y = tonumber(y) or settings.warning_icon_y
    else
        settings.x = tonumber(x) or settings.x
        settings.y = tonumber(y) or settings.y
    end
    shared.SaveSettings()
end

---Toggles the main Owner's Mark HUD window.
---@return nil
local function toggleMain()
    local shared = Shared
    local settings = shared.EnsureSettings()
    settings.show_main_window = not (settings.show_main_window and true or false)
    shared.SaveSettings()
    renderNow()
end

---Toggles the standalone warning text widget.
---@return nil
local function toggleWarningText()
    local shared = Shared
    local settings = shared.EnsureSettings()
    settings.show_warning_text = not (settings.show_warning_text and true or false)
    shared.SaveSettings()
    renderNow()
end

---Cycles the warning text color preset.
---@return nil
local function cycleWarningTextColor()
    local shared = Shared
    local settings = shared.EnsureSettings()
    local colors = Constants.WARNING_TEXT_COLORS or {}
    if #colors == 0 then
        return
    end
    local index = math.floor(tonumber(settings.warning_text_color_index) or 1)
    index = index + 1
    if index > #colors then
        index = 1
    end
    settings.warning_text_color_index = index
    shared.SaveSettings()
    renderNow()
end

---Sets the warning text font size and persists the result.
---@param value number
---@return nil
local function setWarningTextSize(value)
    local shared = Shared
    local settings = shared.EnsureSettings()
    settings.warning_text_size = clampSetting(
        value,
        Constants.WARNING_TEXT_MIN_SIZE,
        Constants.WARNING_TEXT_MAX_SIZE
    )
    shared.SaveSettings()
    renderNow()
end

---Toggles the standalone warning icon widget.
---@return nil
local function toggleWarningIcon()
    local shared = Shared
    local settings = shared.EnsureSettings()
    settings.show_warning_icon = not (settings.show_warning_icon and true or false)
    shared.SaveSettings()
    renderNow()
end

---Sets the warning icon size and persists the result.
---@param value number
---@return nil
local function setWarningIconSize(value)
    local shared = Shared
    local settings = shared.EnsureSettings()
    settings.warning_icon_size = clampSetting(
        value,
        Constants.WARNING_ICON_MIN_SIZE,
        Constants.WARNING_ICON_MAX_SIZE
    )
    shared.SaveSettings()
    renderNow()
end

---Sets the launcher icon size and persists the result.
---@param value number
---@return nil
local function setButtonSize(value)
    local shared = Shared
    local settings = shared.EnsureSettings()
    settings.button_size = clampSetting(value, 32, 96)
    shared.SaveSettings()
    renderNow()
end

---Runs the periodic addon update loop.
---@param dt any
---@return nil
local function onUpdate(dt)
    if not modulesReady() then
        return
    end

    local constants = Constants
    local shared = Shared
    local tracker = Tracker
    local settings = shared.EnsureSettings()
    updateAccumMs = updateAccumMs + shared.NormalizeDeltaMs(dt)
    if updateAccumMs < constants.UPDATE_INTERVAL_MS then
        return
    end
    updateAccumMs = 0

    if not settings.enabled then
        renderNow(tracker.GetSnapshot(), settings)
        return
    end

    local snapshot = tracker.Update()
    renderNow(snapshot, settings)
end

---Builds the UI action table.
---@return table
local function buildActions()
    return {
        toggle_main = toggleMain,
        save_position = savePosition,
        toggle_warning_text = toggleWarningText,
        cycle_warning_text_color = cycleWarningTextColor,
        set_warning_text_size = setWarningTextSize,
        toggle_warning_icon = toggleWarningIcon,
        set_warning_icon_size = setWarningIconSize,
        set_button_size = setButtonSize
    }
end

---Rebuilds UI after a client UI reload.
---@return nil
local function onUiReloaded()
    if not modulesReady() then
        return
    end
    local ui = Ui
    local tracker = Tracker
    local shared = Shared
    updateAccumMs = 0
    lastRenderSignature = nil
    ui.Destroy()
    ui.Init(buildActions())
    ui.ApplyPositions(shared.EnsureSettings())
    tracker.Reset()
    tracker.Update()
    renderNow()
end

---Initializes addon state and registers runtime events.
---@return nil
local function onLoad()
    if not modulesReady() then
        logModuleErrors()
        if api.Log ~= nil and api.Log.Err ~= nil then
            api.Log:Err("[Nuzi Owner's Mark] Failed to load one or more modules.")
        end
        return
    end

    local shared = Shared
    local tracker = Tracker
    local ui = Ui
    shared.LoadSettings()
    tracker.Reset()
    lastRenderSignature = nil
    ui.Init(buildActions())
    ui.ApplyPositions(shared.EnsureSettings())
    tracker.Update()
    renderNow()

    api.On("UPDATE", onUpdate)
    api.On("UI_RELOADED", onUiReloaded)
    if api.Log ~= nil and api.Log.Info ~= nil then
        api.Log:Info("[Nuzi Owner's Mark] Loaded v" .. tostring(Addon.version))
    end
end

---Unregisters events and destroys addon UI.
---@return nil
local function onUnload()
    local ui = Ui
    local tracker = Tracker
    api.On("UPDATE", function()
    end)
    api.On("UI_RELOADED", function()
    end)
    if ui ~= nil then
        ui.Destroy()
    end
    if tracker ~= nil then
        tracker.Reset()
    end
    lastRenderSignature = nil
end

---Toggles the addon window from addon settings UI flows.
---@return nil
local function onSettingToggle()
    toggleMain()
end

Addon.OnLoad = onLoad
Addon.OnUnload = onUnload
Addon.OnSettingToggle = onSettingToggle

return Addon
