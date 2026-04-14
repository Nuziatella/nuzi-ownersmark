local api = require("api")
local Constants = require("nuzi-ownersmark/constants")
local WarningWidgets = require("nuzi-ownersmark/warning_widgets")

local Ui = {
    window = nil,
    toggle_window = nil,
    toggle_icon = nil,
    warning_text_window = nil,
    warning_icon_window = nil,
    labels = {},
    buttons = {},
    sliders = {},
    actions = nil
}

local applyCommonWindowBehavior

---Safely invokes a callback and returns its result when successful.
---@param fn function
---@return any
local function safeCall(fn)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
    return nil
end

---Returns a center alignment token if exposed by the runtime.
---@return any
local function getAlignCenter()
    local alignCenter = type(_G) == "table" and rawget(_G, "ALIGN_CENTER") or nil
    if alignCenter ~= nil then
        return alignCenter
    end
    if ALIGN ~= nil then
        return ALIGN.CENTER
    end
    return nil
end

---Shows or hides a widget when supported.
---@param widget table|nil
---@param visible boolean
---@return nil
local function safeShow(widget, visible)
    if widget ~= nil and widget.Show ~= nil then
        local nextVisible = visible and true or false
        if widget.__nuzi_visible ~= nextVisible then
            widget.__nuzi_visible = nextVisible
            pcall(function()
                widget:Show(nextVisible)
            end)
        end
    end
end

---Sets widget text when supported.
---@param widget table|nil
---@param text any
---@return nil
local function safeSetText(widget, text)
    if widget ~= nil and widget.SetText ~= nil then
        local nextText = tostring(text or "")
        if widget.__nuzi_text ~= nextText then
            widget.__nuzi_text = nextText
            pcall(function()
                widget:SetText(nextText)
            end)
        end
    end
end

---Sets label color when supported.
---@param widget table|nil
---@param color table|nil
---@return nil
local function safeSetColor(widget, color)
    if widget == nil or widget.style == nil or widget.style.SetColor == nil or type(color) ~= "table" then
        return
    end
    local signature = table.concat({
        tostring(color[1] or 1),
        tostring(color[2] or 1),
        tostring(color[3] or 1),
        tostring(color[4] or 1)
    }, ",")
    if widget.__nuzi_color ~= signature then
        widget.__nuzi_color = signature
        pcall(function()
            widget.style:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        end)
    end
end

---Sets label font size when supported.
---@param widget table|nil
---@param fontSize number
---@return nil
local function safeSetFontSize(widget, fontSize)
    if widget == nil or widget.style == nil or widget.style.SetFontSize == nil then
        return
    end
    local nextValue = tonumber(fontSize) or 0
    if widget.__nuzi_font_size ~= nextValue then
        widget.__nuzi_font_size = nextValue
        pcall(function()
            widget.style:SetFontSize(nextValue)
        end)
    end
end

---Sets widget size when supported.
---@param widget table|nil
---@param width number
---@param height number
---@return nil
local function safeSetExtent(widget, width, height)
    if widget ~= nil and widget.SetExtent ~= nil then
        local nextWidth = math.floor((tonumber(width) or 0) + 0.5)
        local nextHeight = math.floor((tonumber(height) or 0) + 0.5)
        if widget.__nuzi_extent_w ~= nextWidth or widget.__nuzi_extent_h ~= nextHeight then
            widget.__nuzi_extent_w = nextWidth
            widget.__nuzi_extent_h = nextHeight
            pcall(function()
                widget:SetExtent(nextWidth, nextHeight)
            end)
        end
    end
end

local function safeSetTexture(drawable, path)
    if drawable ~= nil and drawable.SetTexture ~= nil and type(path) == "string" and path ~= "" then
        if drawable.__nuzi_texture ~= path then
            drawable.__nuzi_texture = path
            pcall(function()
                drawable:SetTexture(path)
            end)
        end
    end
end

local function safeSetSliderValue(slider, value)
    if slider ~= nil and slider.SetValue ~= nil then
        local nextValue = tonumber(value) or 0
        if slider.__nuzi_slider_value ~= nextValue then
            slider.__nuzi_slider_value = nextValue
            pcall(function()
                slider:SetValue(nextValue, false)
            end)
        end
    end
end

---Returns a left alignment token if exposed by the runtime.
---@return any
local function getAlignLeft()
    local alignLeft = type(_G) == "table" and rawget(_G, "ALIGN_LEFT") or nil
    if alignLeft ~= nil then
        return alignLeft
    end
    if ALIGN ~= nil then
        return ALIGN.LEFT
    end
    return nil
end

applyCommonWindowBehavior = function(window)
    if window == nil then
        return
    end
    safeCall(function()
        window:SetCloseOnEscape(false)
    end)
    safeCall(function()
        window:EnableHidingIsRemove(false)
    end)
    safeCall(function()
        window:SetUILayer("game")
    end)
end

---Creates an empty HUD window.
---@param id string
---@return table|nil
local function createEmptyWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local window = safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    applyCommonWindowBehavior(window)
    return window
end

---Creates a background panel for a window.
---@param window table|nil
---@return table|nil
local function createBackground(window)
    if window == nil or window.CreateNinePartDrawable == nil then
        return nil
    end
    local background = safeCall(function()
        return window:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    end)
    if background ~= nil then
        safeCall(function()
            background:SetTextureInfo("bg_quest")
            background:SetColor(0, 0, 0, 0.82)
            background:AddAnchor("TOPLEFT", window, 0, 0)
            background:AddAnchor("BOTTOMRIGHT", window, 0, 0)
        end)
    end
    return background
end

---Creates a text label bound to a parent widget.
---@param parent table
---@param id string
---@param x number
---@param y number
---@param width number
---@param height number
---@param fontSize number
---@param color table
---@return table|nil
local function createLabel(parent, id, x, y, width, height, fontSize, color)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local label = safeCall(function()
        return parent:CreateChildWidget("label", id, 0, true)
    end)
    if label == nil then
        return nil
    end
    safeCall(function()
        label:AddAnchor("TOPLEFT", parent, x, y)
    end)
    safeSetExtent(label, width, height)
    if label.style ~= nil then
        safeCall(function()
            label.style:SetFontSize(fontSize)
            label.style:SetAlign(getAlignLeft())
        end)
    end
    safeSetColor(label, color)
    safeShow(label, true)
    return label
end

---Creates a button widget with the default skin if available.
---@param id string
---@param parent table
---@param text string
---@param x number
---@param y number
---@param width number
---@param height number
---@param onClick function|nil
---@return table|nil
local function createButton(id, parent, text, x, y, width, height, onClick)
    if api.Interface == nil or api.Interface.CreateWidget == nil then
        return nil
    end
    local button = safeCall(function()
        return api.Interface:CreateWidget("button", id, parent)
    end)
    if button == nil then
        return nil
    end
    safeCall(function()
        button:AddAnchor("TOPLEFT", x, y)
    end)
    safeSetText(button, text)
    safeSetExtent(button, width, height)
    if BUTTON_BASIC ~= nil and BUTTON_BASIC.DEFAULT ~= nil and api.Interface.ApplyButtonSkin ~= nil then
        safeCall(function()
            api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
        end)
    end
    if onClick ~= nil and button.SetHandler ~= nil then
        button:SetHandler("OnClick", onClick)
    end
    safeShow(button, true)
    return button
end

local function createPlainButton(parent, id, x, y, width, height, onClick)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local button = safeCall(function()
        return parent:CreateChildWidget("button", id, 0, true)
    end)
    if button == nil then
        return nil
    end
    safeCall(function()
        button:AddAnchor("TOPLEFT", parent, x, y)
    end)
    safeSetText(button, "")
    safeSetExtent(button, width, height)
    if onClick ~= nil and button.SetHandler ~= nil then
        button:SetHandler("OnClick", onClick)
    end
    safeShow(button, true)
    return button
end

local function createSlider(id, parent, x, y, width, minValue, maxValue, step)
    if api._Library == nil or api._Library.UI == nil or api._Library.UI.CreateSlider == nil then
        return nil
    end
    local slider = safeCall(function()
        return api._Library.UI.CreateSlider(id, parent)
    end)
    if slider == nil then
        return nil
    end
    safeCall(function()
        slider:AddAnchor("TOPLEFT", parent, x, y)
    end)
    safeSetExtent(slider, width, 26)
    safeCall(function()
        slider:SetMinMaxValues(minValue, maxValue)
    end)
    if slider.SetStep ~= nil then
        safeCall(function()
            slider:SetStep(step)
        end)
    elseif slider.SetValueStep ~= nil then
        safeCall(function()
            slider:SetValueStep(step)
        end)
    end
    safeShow(slider, true)
    return slider
end

local function assetPath(relativePath)
    local baseDir = type(api) == "table" and type(api.baseDir) == "string" and api.baseDir or ""
    baseDir = string.gsub(baseDir, "\\", "/")
    if baseDir ~= "" then
        return string.gsub(baseDir .. "/" .. tostring(relativePath or ""), "/+", "/")
    end
    return tostring(relativePath or "")
end

local function createImageDrawable(widget, id, path, layer, width, height)
    if widget == nil then
        return nil
    end
    local drawable = safeCall(function()
        if widget.CreateImageDrawable ~= nil then
            return widget:CreateImageDrawable(id, layer or "artwork")
        end
        if widget.CreateDrawable ~= nil then
            return widget:CreateDrawable(id, layer or "artwork")
        end
        return nil
    end)
    if drawable == nil then
        return nil
    end
    safeSetTexture(drawable, path)
    if drawable.AddAnchor ~= nil then
        safeCall(function()
            drawable:AddAnchor("TOPLEFT", widget, 0, 0)
        end)
    end
    if drawable.SetExtent ~= nil then
        safeCall(function()
            drawable:SetExtent(width, height)
        end)
    end
    if drawable.Show ~= nil then
        safeCall(function()
            drawable:Show(true)
        end)
    end
    return drawable
end

local function getToggleButtonSize(settings)
    local size = math.floor((tonumber(settings ~= nil and settings.button_size or nil) or Constants.DEFAULT_SETTINGS.button_size or 48) + 0.5)
    if size < 32 then
        size = 32
    elseif size > 96 then
        size = 96
    end
    return size
end

local function applyToggleWindowLayout(settings)
    local size = getToggleButtonSize(settings)
    if Ui.toggle_window ~= nil then
        safeSetExtent(Ui.toggle_window, size, size)
    end
    if Ui.buttons.toggle ~= nil then
        safeSetExtent(Ui.buttons.toggle, size, size)
    end
    if Ui.toggle_icon ~= nil then
        safeSetExtent(Ui.toggle_icon, size, size)
    end
end

---Attaches drag handlers to a window and one of its child widgets.
---@param window table|nil
---@param dragTarget table|nil
---@param key string
---@return nil
local function attachDrag(window, dragTarget, key)
    if window == nil or dragTarget == nil or dragTarget.SetHandler == nil then
        return
    end

    local function readWindowOffset()
        local ok = false
        local x, y = nil, nil
        if window.GetEffectiveOffset ~= nil then
            ok, x, y = pcall(function()
                return window:GetEffectiveOffset()
            end)
        end
        if (not ok or x == nil or y == nil) and window.GetOffset ~= nil then
            ok, x, y = pcall(function()
                return window:GetOffset()
            end)
        end
        if ok then
            return tonumber(x), tonumber(y)
        end
        return nil, nil
    end

    local function onDragStart()
        if api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil and not api.Input:IsShiftKeyDown() then
            return
        end
        if window.StartMoving ~= nil then
            window:StartMoving()
        end
        if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
            api.Cursor:ClearCursor()
        end
        if api.Cursor ~= nil and api.Cursor.SetCursorImage ~= nil then
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
    end

    local function onDragStop()
        if window.StopMovingOrSizing ~= nil then
            window:StopMovingOrSizing()
        end
        if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
            api.Cursor:ClearCursor()
        end
        if Ui.actions ~= nil and Ui.actions.save_position ~= nil then
            local x, y = readWindowOffset()
            if x == nil or y == nil then
                return
            end
            if window.RemoveAllAnchors ~= nil and window.AddAnchor ~= nil then
                safeCall(function()
                    window:RemoveAllAnchors()
                    window:AddAnchor("TOPLEFT", "UIParent", tonumber(x) or 0, tonumber(y) or 0)
                end)
            end
            Ui.actions.save_position(key, x, y)
        end
    end

    if window.EnableDrag ~= nil then
        safeCall(function()
            window:EnableDrag(true)
        end)
    end
    if window.RegisterForDrag ~= nil then
        safeCall(function()
            window:RegisterForDrag("LeftButton")
        end)
    end
    if dragTarget.EnableDrag ~= nil then
        safeCall(function()
            dragTarget:EnableDrag(true)
        end)
    end
    if dragTarget.RegisterForDrag ~= nil then
        safeCall(function()
            dragTarget:RegisterForDrag("LeftButton")
        end)
    end

    window:SetHandler("OnDragStart", onDragStart)
    window:SetHandler("OnDragStop", onDragStop)
    dragTarget:SetHandler("OnDragStart", onDragStart)
    dragTarget:SetHandler("OnDragStop", onDragStop)
end

---Creates the compact toggle window.
---@return table|nil
local function createToggleWindow()
    local window = createEmptyWindow(Constants.TOGGLE_WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, Constants.DEFAULT_SETTINGS.button_size or 48, Constants.DEFAULT_SETTINGS.button_size or 48)

    local size = getToggleButtonSize(Constants.DEFAULT_SETTINGS)
    local dragBar = createLabel(window, "NuziOwnersMarkToggleDrag", 0, 0, size, size, 12, { 1, 1, 1, 0 })
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "button")

    Ui.buttons.toggle = createPlainButton(window, "NuziOwnersMarkToggleButton", 0, 0, size, size, function()
        if Ui.actions ~= nil and Ui.actions.toggle_main ~= nil then
            Ui.actions.toggle_main()
        end
    end)
    Ui.toggle_icon = createImageDrawable(
        window,
        "NuziOwnersMarkToggleIcon",
        assetPath("nuzi-ownersmark/icon_launcher.png"),
        "artwork",
        size,
        size
    )
    if Ui.buttons.toggle ~= nil then
        attachDrag(window, Ui.buttons.toggle, "button")
    end
    return window
end

---Creates the main HUD window.
---@return table|nil
local function createMainWindow()
    local window = createEmptyWindow(Constants.WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 448, 364)
    createBackground(window)

    local dragBar = createLabel(window, "NuziOwnersMarkDrag", 0, 0, 448, 20, 12, { 1, 1, 1, 0 })
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "main")

    Ui.labels.title = createLabel(window, "NuziOwnersMarkTitle", 14, 8, 260, 18, 14, { 1, 1, 1, 1 })
    Ui.labels.status = createLabel(window, "NuziOwnersMarkStatus", 14, 36, 420, 18, 12, { 1, 0.86, 0.4, 1 })
    Ui.labels.pending = createLabel(window, "NuziOwnersMarkPending", 14, 58, 420, 18, 12, { 0.92, 0.92, 0.92, 1 })
    Ui.labels.active = createLabel(window, "NuziOwnersMarkActive", 14, 80, 420, 18, 12, { 0.78, 0.84, 0.9, 1 })
    Ui.labels.tracked_header = createLabel(window, "NuziOwnersMarkTrackedHeader", 14, 110, 180, 18, 12, { 0.9, 0.94, 1, 1 })
    Ui.labels.source = createLabel(window, "NuziOwnersMarkSource", 14, 130, 420, 66, 11, { 0.78, 0.84, 0.9, 1 })
    Ui.labels.help_header = createLabel(window, "NuziOwnersMarkHelpHeader", 14, 204, 180, 18, 12, { 0.9, 0.94, 1, 1 })
    Ui.labels.help = createLabel(window, "NuziOwnersMarkHelp", 14, 224, 420, 42, 11, { 0.78, 0.84, 0.9, 1 })
    Ui.labels.warning_header = createLabel(window, "NuziOwnersMarkWarningHeader", 14, 274, 160, 18, 12, { 0.9, 0.94, 1, 1 })
    Ui.labels.launcher = createLabel(window, "NuziOwnersMarkLauncherLabel", 14, 330, 80, 18, 12, { 1, 1, 1, 1 })
    Ui.labels.launcher_value = createLabel(window, "NuziOwnersMarkLauncherValue", 398, 330, 36, 18, 12, { 0.95, 0.95, 0.95, 1 })
    Ui.sliders.launcher_size = createSlider("NuziOwnersMarkLauncherSize", window, 104, 328, 286, 32, 96, 1)

    Ui.buttons.close = createButton("NuziOwnersMarkClose", window, "Hide", 374, 8, 60, 22, function()
        if Ui.actions ~= nil and Ui.actions.toggle_main ~= nil then
            Ui.actions.toggle_main()
        end
    end)

    local warningWidgets = WarningWidgets.AttachControls(window, Ui, {
        createLabel = createLabel,
        createButton = createButton,
        createSlider = createSlider,
        safeSetText = safeSetText
    })

    if Ui.sliders.launcher_size ~= nil and Ui.sliders.launcher_size.SetHandler ~= nil then
        Ui.sliders.launcher_size:SetHandler("OnSliderChanged", function(_, value)
            local numeric = math.floor((tonumber(value) or Constants.DEFAULT_SETTINGS.button_size or 48) + 0.5)
            safeSetText(Ui.labels.launcher_value, tostring(numeric))
            applyToggleWindowLayout({ button_size = numeric })
            if Ui.actions ~= nil and Ui.actions.set_button_size ~= nil then
                Ui.actions.set_button_size(numeric)
            end
        end)
    end

    for _, widget in ipairs({
        Ui.labels.title,
        Ui.labels.status,
        Ui.labels.pending,
        Ui.labels.active,
        Ui.labels.tracked_header,
        Ui.labels.source,
        Ui.labels.help_header,
        Ui.labels.help,
        Ui.labels.warning_header,
        Ui.labels.launcher,
        Ui.labels.launcher_value,
        Ui.buttons.close
    }) do
        if widget ~= nil then
            attachDrag(window, widget, "main")
        end
    end

    for _, widget in ipairs(warningWidgets) do
        if widget ~= nil then
            attachDrag(window, widget, "main")
        end
    end

    return window
end

---Initializes UI windows and stores available actions.
---@param actions table
---@return nil
function Ui.Init(actions)
    Ui.actions = actions
    Ui.toggle_window = createToggleWindow()
    WarningWidgets.InitStandalone(Ui, {
        attachDrag = attachDrag,
        createEmptyWindow = createEmptyWindow,
        createLabel = createLabel,
        getAlignCenter = getAlignCenter,
        safeCall = safeCall,
        safeSetExtent = safeSetExtent,
        safeShow = safeShow
    })
    Ui.window = createMainWindow()
    safeShow(Ui.toggle_window, true)
    safeShow(Ui.warning_text_window, true)
    safeShow(Ui.warning_icon_window, true)
    safeShow(Ui.window, true)
end

---Destroys all windows owned by the addon.
---@return nil
function Ui.Destroy()
    for _, window in ipairs({ Ui.window, Ui.toggle_window, Ui.warning_text_window, Ui.warning_icon_window }) do
        if window ~= nil then
            safeShow(window, false)
            if window.Destroy ~= nil then
                safeCall(function()
                    window:Destroy()
                end)
            end
        end
    end
    Ui.window = nil
    Ui.toggle_window = nil
    Ui.warning_text_window = nil
    Ui.warning_icon_window = nil
    Ui.labels = {}
    Ui.buttons = {}
    Ui.sliders = {}
    Ui.toggle_icon = nil
    Ui.actions = nil
end

---Applies persisted positions to the addon windows.
---@param settings table
---@return nil
function Ui.ApplyPositions(settings)
    settings = settings or {}
    applyToggleWindowLayout(settings)
    if Ui.window ~= nil and Ui.window.RemoveAllAnchors ~= nil and Ui.window.AddAnchor ~= nil then
        safeCall(function()
            Ui.window:RemoveAllAnchors()
            Ui.window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.x) or 340, tonumber(settings.y) or 240)
        end)
    end
    if Ui.toggle_window ~= nil and Ui.toggle_window.RemoveAllAnchors ~= nil and Ui.toggle_window.AddAnchor ~= nil then
        safeCall(function()
            Ui.toggle_window:RemoveAllAnchors()
            Ui.toggle_window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.button_x) or 40, tonumber(settings.button_y) or 260)
        end)
    end
    WarningWidgets.ApplyPositions(Ui, settings, {
        safeCall = safeCall
    })
end

---Renders the current tracker snapshot into the HUD.
---@param viewModel table
---@param settings table
---@return nil
function Ui.Render(viewModel, settings)
    if type(viewModel) ~= "table" then
        return
    end
    settings = settings or {}

    safeShow(Ui.toggle_window, settings.show_toggle_button ~= false)
    safeShow(Ui.window, settings.show_main_window and true or false)
    WarningWidgets.Render(Ui, viewModel, settings, {
        safeSetColor = safeSetColor,
        safeSetExtent = safeSetExtent,
        safeSetFontSize = safeSetFontSize,
        safeSetText = safeSetText,
        safeShow = safeShow,
        safeCall = safeCall,
        safeSetSliderValue = safeSetSliderValue
    })

    if settings.show_main_window then
        applyToggleWindowLayout(settings)
        safeSetText(Ui.labels.title, Constants.ADDON_NAME)
        safeSetText(Ui.labels.tracked_header, "Tracked Ride")
        safeSetText(Ui.labels.help_header, "Flow")
        safeSetText(Ui.labels.warning_header, "Overlay Controls")
        safeSetText(Ui.labels.launcher, "Launcher")
        safeSetText(Ui.labels.launcher_value, tostring(getToggleButtonSize(settings)))
        safeSetSliderValue(Ui.sliders.launcher_size, getToggleButtonSize(settings))
        safeSetText(
            Ui.labels.status,
            string.format(
                "State: %s | %s",
                tostring(viewModel.current_state or "--"),
                tostring(viewModel.current_time_text or "--")
            )
        )
        safeSetColor(Ui.labels.status, viewModel.status_color or { 1, 1, 1, 1 })
        safeSetText(
            Ui.labels.pending,
            string.format(
                "Vehicle: %s | Owner: %s",
                tostring(viewModel.unit_name or viewModel.unit_id or "--"),
                tostring(viewModel.owner_name or "--")
            )
        )
        safeSetText(
            Ui.labels.active,
            string.format(
                "Source: %s",
                tostring(viewModel.source_label or viewModel.source_text or "None")
            )
        )
        safeSetText(
            Ui.labels.source,
            string.format(
                "%s\n%s\n%s",
                tostring(viewModel.source_text or "Waiting for target"),
                tostring(viewModel.tracking_text or ""),
                tostring(viewModel.vehicle_hint_text or "")
            )
        )
        safeSetText(Ui.labels.help, tostring(viewModel.help_text or ""))
    end
end

return Ui
