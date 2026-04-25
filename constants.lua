local Constants = {}

Constants.ADDON_ID = "nuzi_ownersmark"
Constants.ADDON_NAME = "Crp Car Alarm"
Constants.ADDON_AUTHOR = "Nuzi"
Constants.ADDON_VERSION = "2.0.0"
Constants.ADDON_DESC = "Keeps an eye on Owner's Mark for Crp's ride"
Constants.SETTINGS_FILE_PATH = "nuzi-ownersmark/.data/settings.txt"
Constants.LEGACY_SETTINGS_FILE_PATH = "nuzi-ownersmark/settings.txt"

Constants.WINDOW_ID = "NuziOwnersMarkMain"
Constants.TOGGLE_WINDOW_ID = "NuziOwnersMarkToggle"

Constants.UPDATE_INTERVAL_MS = 100
Constants.PENDING_BUFF_ID = 14470
Constants.ACTIVE_BUFF_ID = 4867
Constants.OWNER_MARK_NAME = "Owner's Mark"
Constants.ACTIVE_WARNING_THRESHOLD_MS = 60000
Constants.ACTIVE_CRITICAL_THRESHOLD_MS = 15000
Constants.PLAYER_UNIT_TOKEN = "player"
Constants.VEHICLE_UNIT_TOKENS = {
    "slave",
    "playerpet",
    "playerpet1",
    "playerpet2"
}
Constants.TARGET_FALLBACK_UNIT_TOKEN = "target"
Constants.PLAYER_FALLBACK_PRIORITY = 100
Constants.CACHE_GRACE_MS = 600
Constants.WARNING_TEXT_MIN_SIZE = 14
Constants.WARNING_TEXT_MAX_SIZE = 40
Constants.WARNING_TEXT_SIZE_STEP = 2
Constants.WARNING_ICON_MIN_SIZE = 24
Constants.WARNING_ICON_MAX_SIZE = 80
Constants.WARNING_ICON_SIZE_STEP = 4
Constants.WARNING_TEXT_COLORS = {
    { name = "Gold", rgba = { 1, 0.86, 0.4, 1 } },
    { name = "Red", rgba = { 1, 0.35, 0.35, 1 } },
    { name = "Green", rgba = { 0.35, 1, 0.45, 1 } },
    { name = "Blue", rgba = { 0.45, 0.75, 1, 1 } },
    { name = "White", rgba = { 1, 1, 1, 1 } }
}

Constants.DEFAULT_SETTINGS = {
    enabled = true,
    x = 340,
    y = 240,
    button_x = 40,
    button_y = 260,
    button_size = 48,
    show_main_window = true,
    show_toggle_button = true,
    show_warning_text = true,
    warning_text_x = 340,
    warning_text_y = 210,
    warning_text_size = 26,
    warning_text_color_index = 1,
    show_warning_icon = true,
    warning_icon_x = 300,
    warning_icon_y = 210,
    warning_icon_size = 44
}

return Constants
