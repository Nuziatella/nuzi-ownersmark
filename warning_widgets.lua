local api = require("api")
local Constants = require("nuzi-ownersmark/constants")

local WarningWidgets = {}
local cachedWarningIconPath = nil

---Creates an item-style icon button when supported by the runtime.
---@param id string
---@param parent table|nil
---@param helpers table
---@return table|nil
local function createWarningIcon(id, parent, helpers)
    if type(CreateItemIconButton) ~= "function" or parent == nil then
        return nil
    end
    local icon = helpers.safeCall(function()
        return CreateItemIconButton(id, parent)
    end)
    if icon == nil then
        return nil
    end
    if F_SLOT ~= nil and F_SLOT.ApplySlotSkin ~= nil and SLOT_STYLE ~= nil and icon.back ~= nil then
        local style = SLOT_STYLE.DEFAULT or SLOT_STYLE.BUFF or SLOT_STYLE.ITEM
        if style ~= nil then
            helpers.safeCall(function()
                F_SLOT.ApplySlotSkin(icon, icon.back, style)
            end)
        end
    end

    if icon.CreateColorDrawable ~= nil then
        local overlay = helpers.safeCall(function()
            return icon:CreateColorDrawable(0, 0, 0, 0, "overlay")
        end)
        if overlay ~= nil then
            helpers.safeCall(function()
                overlay:AddAnchor("TOPLEFT", icon, 0, 0)
                overlay:AddAnchor("BOTTOMRIGHT", icon, 0, 0)
            end)
            icon.statusOverlay = overlay
        end
    end

    local timerLabel = nil
    if api.Interface ~= nil and api.Interface.CreateWidget ~= nil then
        timerLabel = helpers.safeCall(function()
            return api.Interface:CreateWidget("label", id .. "Timer", icon)
        end)
    end
    if timerLabel == nil and icon.CreateChildWidget ~= nil then
        timerLabel = helpers.safeCall(function()
            return icon:CreateChildWidget("label", id .. "Timer", 0, true)
        end)
    end
    if timerLabel ~= nil then
        helpers.safeCall(function()
            timerLabel:SetExtent(64, 22)
            timerLabel:AddAnchor("CENTER", icon, 0, 0)
            if timerLabel.style ~= nil then
                timerLabel.style:SetFontSize(18)
                timerLabel.style:SetAlign(ALIGN.CENTER)
                timerLabel.style:SetShadow(true)
            end
            timerLabel:Show(false)
        end)
        icon.timerLabel = timerLabel
    end

    helpers.safeShow(icon, true)
    return icon
end

---Applies an icon texture path when supported.
---@param icon table|nil
---@param path string|nil
---@param helpers table
---@return nil
local function safeSetWarningIcon(icon, path, helpers)
    if icon == nil or type(path) ~= "string" or path == "" then
        return
    end
    if icon.__nuzi_icon_path ~= path then
        icon.__nuzi_icon_path = path
        if F_SLOT ~= nil and F_SLOT.SetIconBackGround ~= nil then
            helpers.safeCall(function()
                F_SLOT.SetIconBackGround(icon, path)
            end)
        end
    end
end

---Creates helper controls for warning text and icon configuration.
---@param parent table|nil
---@param uiState table
---@param helpers table
---@return table
function WarningWidgets.AttachControls(parent, uiState, helpers)
    if parent == nil then
        return {}
    end

    uiState.labels.text_controls = helpers.createLabel(
        parent,
        "NuziOwnersMarkTextControls",
        14,
        312,
        92,
        18,
        12,
        { 1, 1, 1, 1 }
    )
    uiState.labels.icon_controls = helpers.createLabel(
        parent,
        "NuziOwnersMarkIconControls",
        14,
        336,
        92,
        18,
        12,
        { 1, 1, 1, 1 }
    )
    uiState.labels.text_size_value = helpers.createLabel(
        parent,
        "NuziOwnersMarkTextSizeValue",
        398,
        312,
        36,
        18,
        12,
        { 0.95, 0.95, 0.95, 1 }
    )
    uiState.labels.icon_size_value = helpers.createLabel(
        parent,
        "NuziOwnersMarkIconSizeValue",
        398,
        336,
        36,
        18,
        12,
        { 0.95, 0.95, 0.95, 1 }
    )

    uiState.buttons.warning_text_toggle = helpers.createButton(
        "NuziOwnersMarkWarningTextToggle",
        parent,
        "On",
        66,
        310,
        44,
        22,
        function()
            if uiState.actions ~= nil and uiState.actions.toggle_warning_text ~= nil then
                uiState.actions.toggle_warning_text()
            end
        end
    )
    uiState.buttons.warning_text_color = helpers.createButton(
        "NuziOwnersMarkWarningTextColor",
        parent,
        "Color",
        118,
        310,
        78,
        22,
        function()
            if uiState.actions ~= nil and uiState.actions.cycle_warning_text_color ~= nil then
                uiState.actions.cycle_warning_text_color()
            end
        end
    )
    uiState.sliders.warning_text_size = helpers.createSlider(
        "NuziOwnersMarkWarningTextSlider",
        parent,
        204,
        308,
        186,
        Constants.WARNING_TEXT_MIN_SIZE,
        Constants.WARNING_TEXT_MAX_SIZE,
        1
    )
    uiState.buttons.warning_icon_toggle = helpers.createButton(
        "NuziOwnersMarkWarningIconToggle",
        parent,
        "On",
        66,
        334,
        44,
        22,
        function()
            if uiState.actions ~= nil and uiState.actions.toggle_warning_icon ~= nil then
                uiState.actions.toggle_warning_icon()
            end
        end
    )
    uiState.sliders.warning_icon_size = helpers.createSlider(
        "NuziOwnersMarkWarningIconSlider",
        parent,
        118,
        332,
        272,
        Constants.WARNING_ICON_MIN_SIZE,
        Constants.WARNING_ICON_MAX_SIZE,
        1
    )

    if uiState.sliders.warning_text_size ~= nil and uiState.sliders.warning_text_size.SetHandler ~= nil then
        uiState.sliders.warning_text_size:SetHandler("OnSliderChanged", function(_, raw)
            local numeric = math.floor((tonumber(raw) or Constants.WARNING_TEXT_MIN_SIZE) + 0.5)
            if helpers.safeSetText ~= nil then
                helpers.safeSetText(uiState.labels.text_size_value, tostring(numeric))
            end
            if uiState.actions ~= nil and uiState.actions.set_warning_text_size ~= nil then
                uiState.actions.set_warning_text_size(numeric)
            end
        end)
    end
    if uiState.sliders.warning_icon_size ~= nil and uiState.sliders.warning_icon_size.SetHandler ~= nil then
        uiState.sliders.warning_icon_size:SetHandler("OnSliderChanged", function(_, raw)
            local numeric = math.floor((tonumber(raw) or Constants.WARNING_ICON_MIN_SIZE) + 0.5)
            if helpers.safeSetText ~= nil then
                helpers.safeSetText(uiState.labels.icon_size_value, tostring(numeric))
            end
            if uiState.actions ~= nil and uiState.actions.set_warning_icon_size ~= nil then
                uiState.actions.set_warning_icon_size(numeric)
            end
        end)
    end

    return {
        uiState.labels.text_controls,
        uiState.labels.icon_controls,
        uiState.labels.text_size_value,
        uiState.labels.icon_size_value,
        uiState.buttons.warning_text_toggle,
        uiState.buttons.warning_text_color,
        uiState.sliders.warning_text_size,
        uiState.buttons.warning_icon_toggle,
        uiState.sliders.warning_icon_size
    }
end

---Returns a preview-friendly text overlay position when the widget still uses defaults.
---@param settings table
---@return number
---@return number
local function resolveWarningTextPosition(settings)
    return tonumber(settings.warning_text_x) or 340, tonumber(settings.warning_text_y) or 210
end

---Returns a preview-friendly icon overlay position when the widget still uses defaults.
---@param settings table
---@return number
---@return number
local function resolveWarningIconPosition(settings)
    return tonumber(settings.warning_icon_x) or 300, tonumber(settings.warning_icon_y) or 210
end

---Creates the standalone warning text and icon windows.
---@param uiState table
---@param helpers table
---@return nil
function WarningWidgets.InitStandalone(uiState, helpers)
    uiState.warning_text_window = helpers.createEmptyWindow("NuziOwnersMarkWarningText")
    if uiState.warning_text_window ~= nil then
        helpers.safeSetExtent(uiState.warning_text_window, 320, 42)
        uiState.labels.warning_text = helpers.createLabel(
            uiState.warning_text_window,
            "NuziOwnersMarkWarningTextLabel",
            0,
            0,
            320,
            42,
            26,
            { 1, 0.86, 0.4, 1 }
        )
        if uiState.labels.warning_text ~= nil and uiState.labels.warning_text.style ~= nil then
            helpers.safeCall(function()
                uiState.labels.warning_text.style:SetAlign(helpers.getAlignCenter())
            end)
            helpers.attachDrag(uiState.warning_text_window, uiState.labels.warning_text, "warning_text")
        end
    end

    uiState.warning_icon_window = helpers.createEmptyWindow("NuziOwnersMarkWarningIcon")
    if uiState.warning_icon_window ~= nil then
        helpers.safeSetExtent(uiState.warning_icon_window, 44, 44)
        uiState.buttons.warning_icon = createWarningIcon("NuziOwnersMarkWarningIconButton", uiState.warning_icon_window, helpers)
        if uiState.buttons.warning_icon ~= nil then
            helpers.safeCall(function()
                uiState.buttons.warning_icon:AddAnchor("TOPLEFT", uiState.warning_icon_window, 0, 0)
            end)
            helpers.attachDrag(uiState.warning_icon_window, uiState.buttons.warning_icon, "warning_icon")
        end
    end
end

---Applies persisted positions to the standalone warning widgets.
---@param uiState table
---@param settings table
---@param helpers table
---@return nil
function WarningWidgets.ApplyPositions(uiState, settings, helpers)
    if type(helpers.applyPosition) == "function" then
        helpers.applyPosition(uiState.warning_text_window, "warning_text")
        helpers.applyPosition(uiState.warning_icon_window, "warning_icon")
        return
    end

    if uiState.warning_text_window ~= nil
        and uiState.warning_text_window.RemoveAllAnchors ~= nil
        and uiState.warning_text_window.AddAnchor ~= nil
    then
        local textX, textY = resolveWarningTextPosition(settings)
        helpers.safeCall(function()
            uiState.warning_text_window:RemoveAllAnchors()
            uiState.warning_text_window:AddAnchor(
                "TOPLEFT",
                "UIParent",
                textX,
                textY
            )
        end)
    end

    if uiState.warning_icon_window ~= nil
        and uiState.warning_icon_window.RemoveAllAnchors ~= nil
        and uiState.warning_icon_window.AddAnchor ~= nil
    then
        local iconX, iconY = resolveWarningIconPosition(settings)
        helpers.safeCall(function()
            uiState.warning_icon_window:RemoveAllAnchors()
            uiState.warning_icon_window:AddAnchor(
                "TOPLEFT",
                "UIParent",
                iconX,
                iconY
            )
        end)
    end
end

---Returns the configured warning text color preset.
---@param settings table
---@return table
local function getWarningTextColor(settings)
    local colors = Constants.WARNING_TEXT_COLORS or {}
    local index = math.floor(tonumber(settings.warning_text_color_index) or 1)
    local entry = colors[index]
    if type(entry) == "table" and type(entry.rgba) == "table" then
        return entry.rgba
    end
    return { 1, 0.86, 0.4, 1 }
end

---Returns the configured warning text color label.
---@param settings table
---@return string
local function getWarningTextColorLabel(settings)
    local colors = Constants.WARNING_TEXT_COLORS or {}
    local index = math.floor(tonumber(settings.warning_text_color_index) or 1)
    local entry = colors[index]
    if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
        return entry.name
    end
    return "Color"
end

---Returns whether the warning overlay should currently be visible.
---@param viewModel table
---@return boolean
local function shouldShowWarning(viewModel)
    return viewModel.warning_visible and true or false
end

---Returns the warning text shown in the standalone overlay.
---@param viewModel table
---@return string
local function getWarningText(viewModel)
    if viewModel.pending_present then
        return "OWNER'S MARK ARMED"
    end
    if viewModel.critical_present then
        return string.format(
            "OWNER'S MARK CRITICAL: %s",
            tostring(viewModel.active_time_text or "--")
        )
    end
    if viewModel.expiring_present then
        return string.format(
            "OWNER'S MARK LOW: %s",
            tostring(viewModel.active_time_text or "--")
        )
    end
    if viewModel.active_present then
        return string.format(
            "OWNER'S MARK RUNNING: %s",
            tostring(viewModel.active_time_text or "--")
        )
    end
    if viewModel.missing_present then
        return "OWNER'S MARK GONE"
    end
    return ""
end

---Returns the buff id whose icon should be shown for the current state.
---@param viewModel table
---@return number|nil
local function getWarningIconBuffId(viewModel)
    if viewModel.pending_present then
        return Constants.PENDING_BUFF_ID
    end
    if viewModel.active_present or viewModel.expiring_present then
        return Constants.ACTIVE_BUFF_ID
    end
    if viewModel.missing_present then
        return Constants.PENDING_BUFF_ID
    end
    return nil
end

---Attempts to resolve an icon path for the warning overlay.
---@param viewModel table
---@param helpers table
---@return string|nil
local function resolveWarningIconPath(viewModel, helpers)
    if api.Ability == nil or api.Ability.GetBuffTooltip == nil then
        return cachedWarningIconPath
    end

    local buffId = getWarningIconBuffId(viewModel)
    if buffId ~= nil then
        local tooltip = helpers.safeCall(function()
            return api.Ability:GetBuffTooltip(buffId, 1)
        end)
        if type(tooltip) == "table" then
            local iconPath = tooltip.path or tooltip.icon or tooltip.iconPath
            if type(iconPath) == "string" and iconPath ~= "" then
                cachedWarningIconPath = iconPath
                return iconPath
            end
        end
    end
    return cachedWarningIconPath
end

---Returns a tint for the icon overlay based on the current state.
---@param viewModel table
---@return table
local function getWarningIconOverlayColor(viewModel)
    if viewModel.pending_present then
        return { 1, 0.75, 0.15, 0.2 }
    end
    if viewModel.critical_present then
        return { 1, 0.08, 0.08, 0.42 }
    end
    if viewModel.expiring_present then
        return { 1, 0.45, 0.12, 0.3 }
    end
    if viewModel.active_present then
        return { 0.22, 0.8, 0.35, 0.16 }
    end
    if viewModel.missing_present then
        return { 1, 0.2, 0.2, 0.35 }
    end
    return { 0, 0, 0, 0 }
end

---Returns the timer text to overlay on the icon.
---@param viewModel table
---@return string
local function getWarningIconTimerText(viewModel)
    if viewModel.active_present then
        return tostring(viewModel.active_time_text or "")
    end
    return ""
end

---Renders the standalone warning widgets and control texts.
---@param uiState table
---@param viewModel table
---@param settings table
---@param helpers table
---@return nil
function WarningWidgets.Render(uiState, viewModel, settings, helpers)
    local previewVisible = settings.show_main_window and true or false
    local warningVisible = shouldShowWarning(viewModel) or previewVisible
    local warningTextVisible = settings.show_warning_text ~= false and warningVisible
    local warningIconVisible = settings.show_warning_icon ~= false and warningVisible
    local warningTextSize = math.floor(tonumber(settings.warning_text_size) or 26)
    local warningIconSize = math.floor(tonumber(settings.warning_icon_size) or 44)
    local warningIconPath = resolveWarningIconPath(viewModel, helpers)

    helpers.safeShow(uiState.warning_text_window, warningTextVisible)
    helpers.safeShow(uiState.warning_icon_window, warningIconVisible)

    if uiState.labels.warning_text ~= nil then
        local warningText = getWarningText(viewModel)
        if warningText == "" and previewVisible then
            warningText = "OWNER'S MARK PREVIEW: --"
        end
        helpers.safeSetText(uiState.labels.warning_text, warningText)
        helpers.safeSetFontSize(uiState.labels.warning_text, warningTextSize)
        helpers.safeSetColor(uiState.labels.warning_text, getWarningTextColor(settings))
    end
    if uiState.warning_text_window ~= nil then
        helpers.safeSetExtent(uiState.warning_text_window, 320, math.max(34, warningTextSize + 12))
    end
    if uiState.buttons.warning_icon ~= nil then
        helpers.safeSetExtent(uiState.buttons.warning_icon, warningIconSize, warningIconSize)
        safeSetWarningIcon(uiState.buttons.warning_icon, warningIconPath, helpers)
        helpers.safeShow(uiState.buttons.warning_icon, type(warningIconPath) == "string" and warningIconPath ~= "")
        if uiState.buttons.warning_icon.statusOverlay ~= nil and uiState.buttons.warning_icon.statusOverlay.SetColor ~= nil then
            local rgba = getWarningIconOverlayColor(viewModel)
            helpers.safeCall(function()
                uiState.buttons.warning_icon.statusOverlay:SetColor(rgba[1], rgba[2], rgba[3], rgba[4])
            end)
        end
        if uiState.buttons.warning_icon.timerLabel ~= nil then
            local timerText = getWarningIconTimerText(viewModel)
            helpers.safeCall(function()
                if uiState.buttons.warning_icon.timerLabel.style ~= nil then
                    uiState.buttons.warning_icon.timerLabel.style:SetFontSize(math.max(12, math.floor(warningIconSize * 0.35)))
                    uiState.buttons.warning_icon.timerLabel.style:SetColor(1, 1, 1, 1)
                end
                uiState.buttons.warning_icon.timerLabel:SetText(timerText)
                uiState.buttons.warning_icon.timerLabel:Show(timerText ~= "")
            end)
        end
    end
    if uiState.warning_icon_window ~= nil then
        helpers.safeSetExtent(uiState.warning_icon_window, warningIconSize, warningIconSize)
    end

    if uiState.labels.text_controls ~= nil then
        helpers.safeSetText(uiState.labels.text_controls, "Text")
    end
    if uiState.labels.icon_controls ~= nil then
        helpers.safeSetText(uiState.labels.icon_controls, "Icon")
    end
    if uiState.labels.text_size_value ~= nil then
        helpers.safeSetText(uiState.labels.text_size_value, tostring(warningTextSize))
    end
    if uiState.labels.icon_size_value ~= nil then
        helpers.safeSetText(uiState.labels.icon_size_value, tostring(warningIconSize))
    end
    if uiState.buttons.warning_text_toggle ~= nil then
        helpers.safeSetText(uiState.buttons.warning_text_toggle, settings.show_warning_text ~= false and "On" or "Off")
    end
    if uiState.buttons.warning_text_color ~= nil then
        helpers.safeSetText(uiState.buttons.warning_text_color, getWarningTextColorLabel(settings))
    end
    if uiState.buttons.warning_icon_toggle ~= nil then
        helpers.safeSetText(uiState.buttons.warning_icon_toggle, settings.show_warning_icon ~= false and "On" or "Off")
    end
    if helpers.safeSetSliderValue ~= nil then
        helpers.safeSetSliderValue(uiState.sliders.warning_text_size, warningTextSize)
        helpers.safeSetSliderValue(uiState.sliders.warning_icon_size, warningIconSize)
    end
end

return WarningWidgets
