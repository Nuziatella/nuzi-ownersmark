local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")

local Actions = Core.Actions
local Events = Core.Events
local Log = Core.Log
local Render = Core.Render
local Require = Core.Require
local Scheduler = Core.Scheduler

local bootstrapLogger = Log.Create("Nuzi Owner's Mark")
local moduleErrors = {}

local function appendModuleErrors(name, errors)
    if type(errors) ~= "table" or #errors == 0 then
        moduleErrors[#moduleErrors + 1] = string.format("%s: unknown load failure", tostring(name))
        return
    end
    moduleErrors[#moduleErrors + 1] = string.format(
        "%s: %s",
        tostring(name),
        Require.DescribeErrors(errors)
    )
end

local Constants, _, constantErrors = Require.Addon("nuzi-ownersmark", "constants")
if Constants == nil then
    appendModuleErrors("constants", constantErrors)
end

local logger = Log.Create(Constants ~= nil and Constants.ADDON_NAME or "Nuzi Owner's Mark")
local modules = nil
local failures = nil
if Constants ~= nil then
    modules, failures = Require.AddonSet("nuzi-ownersmark", {
        "shared",
        "tracker",
        "ui"
    })
else
    modules = {}
    failures = {}
end

for name, failure in pairs(failures or {}) do
    appendModuleErrors(name, failure.errors)
end

local Shared = modules.shared
local Tracker = modules.tracker
local Ui = modules.ui

local Addon = {
    name = Constants ~= nil and Constants.ADDON_NAME or "Nuzi Owner's Mark",
    author = Constants ~= nil and Constants.ADDON_AUTHOR or "Nuzi",
    version = Constants ~= nil and Constants.ADDON_VERSION or "1.0.0",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Tracks Owner's Mark on the player's summoned vehicle"
}

local renderGate = Render.CreateSignatureGate()
local updateTicker = Scheduler.CreateTicker({
    interval_ms = Constants ~= nil and Constants.UPDATE_INTERVAL_MS or 100,
    max_elapsed_ms = (Constants ~= nil and Constants.UPDATE_INTERVAL_MS or 100) * 4
})
local events = Events.Create({
    logger = logger
})

local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Tracker ~= nil and Ui ~= nil
end

local function logModuleErrors()
    if #moduleErrors == 0 then
        return
    end
    for _, detail in ipairs(moduleErrors) do
        logger:Err("Module load error: " .. tostring(detail))
    end
end

local function buildColorIndexOrder()
    local order = {}
    for index = 1, #(Constants.WARNING_TEXT_COLORS or {}) do
        order[#order + 1] = index
    end
    return order
end

local function renderNow(viewModel, settings)
    if not modulesReady() then
        return
    end

    viewModel = type(viewModel) == "table" and viewModel or Tracker.GetSnapshot()
    settings = type(settings) == "table" and settings or Shared.EnsureSettings()

    local signature = Render.BuildSignature({
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
    })
    if not renderGate:ShouldRender(signature) then
        return
    end
    Ui.Render(viewModel, settings)
end

local function buildActions()
    if not modulesReady() then
        return {}
    end

    local getSettings = function()
        return Shared.EnsureSettings()
    end
    local saveSettings = function()
        return Shared.SaveSettings()
    end
    local rerender = function()
        renderNow()
    end

    return {
        get_settings = getSettings,
        save_settings = saveSettings,
        toggle_main = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_main_window",
            save = saveSettings,
            after = rerender
        }),
        toggle_warning_text = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_warning_text",
            save = saveSettings,
            after = rerender
        }),
        cycle_warning_text_color = Actions.CreateChoiceCycler({
            get_settings = getSettings,
            key = "warning_text_color_index",
            order = buildColorIndexOrder(),
            save = saveSettings,
            after = rerender
        }),
        set_warning_text_size = Actions.CreateClampedNumberSetter({
            get_settings = getSettings,
            key = "warning_text_size",
            min = Constants.WARNING_TEXT_MIN_SIZE,
            max = Constants.WARNING_TEXT_MAX_SIZE,
            save = saveSettings,
            after = rerender,
            skip_if_unchanged = true
        }),
        toggle_warning_icon = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_warning_icon",
            save = saveSettings,
            after = rerender
        }),
        set_warning_icon_size = Actions.CreateClampedNumberSetter({
            get_settings = getSettings,
            key = "warning_icon_size",
            min = Constants.WARNING_ICON_MIN_SIZE,
            max = Constants.WARNING_ICON_MAX_SIZE,
            save = saveSettings,
            after = rerender,
            skip_if_unchanged = true
        }),
        set_button_size = Actions.CreateClampedNumberSetter({
            get_settings = getSettings,
            key = "button_size",
            min = 32,
            max = 96,
            save = saveSettings,
            after = rerender,
            skip_if_unchanged = true
        })
    }
end

local function onUpdate(dt)
    if not modulesReady() then
        return
    end

    local settings = Shared.EnsureSettings()
    local shouldRun = updateTicker:Advance(dt)
    if not shouldRun then
        return
    end

    if not settings.enabled then
        renderNow(Tracker.GetSnapshot(), settings)
        return
    end

    renderNow(Tracker.Update(), settings)
end

local function onUiReloaded()
    if not modulesReady() then
        return
    end

    updateTicker:Reset()
    renderGate:Reset()
    Ui.Destroy()
    Ui.Init(buildActions())
    Ui.ApplyPositions(Shared.EnsureSettings())
    Tracker.Reset()
    Tracker.Update()
    renderNow()
end

local function onLoad()
    if not modulesReady() then
        logModuleErrors()
        bootstrapLogger:Err("Failed to load one or more modules.")
        return
    end

    logModuleErrors()
    Shared.LoadSettings()
    updateTicker:Reset()
    renderGate:Reset()
    Tracker.Reset()
    Ui.Init(buildActions())
    Ui.ApplyPositions(Shared.EnsureSettings())
    Tracker.Update()
    renderNow()

    events:OnSafe("UPDATE", "UPDATE", onUpdate)
    events:OnSafe("UI_RELOADED", "UI_RELOADED", onUiReloaded)
    logger:Info("Loaded v" .. tostring(Addon.version))
end

local function onUnload()
    events:ClearAll()
    updateTicker:Reset()
    renderGate:Reset()
    if Ui ~= nil then
        Ui.Destroy()
    end
    if Tracker ~= nil then
        Tracker.Reset()
    end
end

local function onSettingToggle()
    local actions = buildActions()
    if type(actions.toggle_main) == "function" then
        actions.toggle_main()
    end
end

Addon.OnLoad = onLoad
Addon.OnUnload = onUnload
Addon.OnSettingToggle = onSettingToggle

return Addon
