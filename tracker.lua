local api = require("api")
local Constants = require("nuzi-ownersmark/constants")

local TARGET_UNIT_TOKEN = Constants.TARGET_FALLBACK_UNIT_TOKEN or "target"

local Tracker = {
    state = {
        snapshot = nil,
        tracked_unit_id = nil,
        tracked_unit_name = nil,
        tracked_seen_ms = nil,
        pending_present_cached = false,
        pending_expiration_ms = nil,
        active_expiration_ms = nil,
        last_source_text = nil,
        last_owner_name = nil,
        has_seen_mark = false
    }
}

---Returns the unit tokens that should be tried for a logical unit key.
---@param unitKey string
---@return table
local function getUnitTokens(unitKey)
    if unitKey == "player" then
        return { "player" }
    end
    if unitKey == "target" then
        return { "target" }
    end
    if unitKey == "watchtarget" then
        return { "watchtarget" }
    end
    if unitKey == "target_of_target" then
        return { "targetoftarget", "target_of_target", "targettarget" }
    end
    return { tostring(unitKey) }
end

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

---Returns the current UI time in milliseconds.
---@return number
local function getNowMs()
    if api.Time == nil or api.Time.GetUiMsec == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.Time:GetUiMsec()
    end)) or 0
end

---Calls a unit API method safely.
---@param methodName string
---@param ... any
---@return any
local function callUnitMethod(methodName, ...)
    if api.Unit == nil then
        return nil
    end
    local fn = api.Unit[methodName]
    if type(fn) ~= "function" then
        return nil
    end
    local args = { ... }
    return safeCall(function()
        return fn(api.Unit, unpack(args))
    end)
end

---Normalizes a unit id into a stable comparable string.
---@param unitId any
---@return string|nil
local function normalizeUnitId(unitId)
    if unitId == nil then
        return nil
    end
    local value = tostring(unitId)
    if value == "" then
        return nil
    end
    return value
end

---Returns the current target unit id when available.
---@param unitToken string
---@return string|nil
local function safeGetUnitId(unitToken)
    return normalizeUnitId(callUnitMethod("GetUnitId", unitToken))
end

---Returns live unit info for a token when available.
---@param unitToken string
---@return table|nil
local function safeUnitInfo(unitToken)
    local value = callUnitMethod("UnitInfo", unitToken)
    if type(value) == "table" then
        return value
    end
    return nil
end

---Returns unit info by id when available.
---@param unitId any
---@return table|nil
local function safeGetUnitInfoById(unitId)
    local normalizedId = normalizeUnitId(unitId)
    if normalizedId == nil then
        return nil
    end
    local value = callUnitMethod("GetUnitInfoById", normalizedId)
    if type(value) == "table" then
        return value
    end
    return nil
end

---Returns the number of auras of a given type on a unit token.
---@param unitToken string
---@param auraKind string
---@return number
local function safeAuraCount(unitToken, auraKind)
    if api.Unit == nil then
        return 0
    end
    if auraKind == "debuff" and api.Unit.UnitDeBuffCount ~= nil then
        return tonumber(callUnitMethod("UnitDeBuffCount", unitToken)) or 0
    end
    if auraKind == "buff" and api.Unit.UnitBuffCount ~= nil then
        return tonumber(callUnitMethod("UnitBuffCount", unitToken)) or 0
    end
    return 0
end

---Returns an aura of a given type by token and index.
---@param unitToken string
---@param auraKind string
---@param index number
---@return table|nil
local function safeAura(unitToken, auraKind, index)
    if api.Unit == nil then
        return nil
    end
    local value = nil
    if auraKind == "debuff" and api.Unit.UnitDeBuff ~= nil then
        value = callUnitMethod("UnitDeBuff", unitToken, index)
    elseif auraKind == "buff" and api.Unit.UnitBuff ~= nil then
        value = callUnitMethod("UnitBuff", unitToken, index)
    end
    if type(value) == "table" then
        return value
    end
    return nil
end

---Extracts an aura id from the runtime object when available.
---@param aura table|nil
---@return number|nil
local function getAuraId(aura)
    if type(aura) ~= "table" then
        return nil
    end
    for _, key in ipairs({
        "buff_id",
        "buffId",
        "id",
        "spellId",
        "spell_id",
        "skillType",
        "skill_type",
        "abilityId",
        "ability_id"
    }) do
        local value = tonumber(aura[key])
        if value ~= nil then
            return value
        end
    end
    return nil
end

---Extracts an aura name from the runtime object when available.
---@param aura table|nil
---@return string|nil
local function getAuraName(aura)
    if type(aura) ~= "table" then
        return nil
    end
    for _, key in ipairs({
        "name",
        "buff_name",
        "buffName",
        "tooltip",
        "title"
    }) do
        local value = aura[key]
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return nil
end

---Returns whether an aura is one of the tracked Owner's Mark states.
---@param aura table|nil
---@return string|nil
local function getTrackedAuraState(aura)
    local auraId = getAuraId(aura)
    if auraId == Constants.PENDING_BUFF_ID then
        return "pending"
    end
    if auraId == Constants.ACTIVE_BUFF_ID then
        return "countdown"
    end

    local auraName = string.lower(tostring(getAuraName(aura) or ""))
    local ownerMarkName = string.lower(tostring(Constants.OWNER_MARK_NAME or "Owner's Mark"))
    if auraName ~= "" and ownerMarkName ~= "" and auraName == ownerMarkName then
        return "owner_mark_unknown"
    end

    return nil
end

---Extracts a unit name from runtime info when present.
---@param unitInfo table|nil
---@return string|nil
local function getUnitName(unitInfo)
    if type(unitInfo) ~= "table" then
        return nil
    end
    local unitName = unitInfo.name or unitInfo.unitName
    if type(unitName) == "string" and unitName ~= "" then
        return unitName
    end
    return nil
end

---Extracts an owner name from runtime info when present.
---@param unitInfo table|nil
---@return string|nil
local function getOwnerName(unitInfo)
    if type(unitInfo) ~= "table" then
        return nil
    end
    local ownerName = unitInfo.owner_name or unitInfo.ownerName or unitInfo.owner
    if type(ownerName) == "string" and ownerName ~= "" then
        return ownerName
    end
    return nil
end

---Returns the player name when available.
---@return string|nil
local function getPlayerName()
    local playerInfo = safeUnitInfo(Constants.PLAYER_UNIT_TOKEN)
    if type(playerInfo) == "table" and type(playerInfo.name) == "string" and playerInfo.name ~= "" then
        return playerInfo.name
    end
    local playerId = safeGetUnitId(Constants.PLAYER_UNIT_TOKEN)
    local playerInfoById = safeGetUnitInfoById(playerId)
    if type(playerInfoById) == "table" and type(playerInfoById.name) == "string" and playerInfoById.name ~= "" then
        return playerInfoById.name
    end
    return nil
end

---Returns the first unit token for a logical key that currently resolves to a live unit id.
---@param unitKey string
---@return string|nil
---@return string|nil
local function resolveUnitKey(unitKey)
    for _, unitToken in ipairs(getUnitTokens(unitKey)) do
        local unitId = safeGetUnitId(unitToken)
        if unitId ~= nil then
            return unitToken, unitId
        end
    end
    return nil, nil
end

---Returns whether a target unit is clearly owned by the player.
---@param unitInfo table|nil
---@param playerName string|nil
---@return boolean
local function isOwnedByPlayer(unitInfo, playerName)
    return type(playerName) == "string"
        and playerName ~= ""
        and type(getOwnerName(unitInfo)) == "string"
        and getOwnerName(unitInfo) == playerName
end

---Returns whether the supplied target matches the remembered tracked vehicle.
---@param unitId any
---@param unitInfo table|nil
---@return boolean
local function matchesTrackedVehicle(unitId, unitInfo)
    local trackedId = normalizeUnitId(Tracker.state.tracked_unit_id)
    local candidateId = normalizeUnitId(unitId)
    if trackedId ~= nil and candidateId ~= nil and trackedId == candidateId then
        return true
    end
    local trackedName = tostring(Tracker.state.tracked_unit_name or "")
    local candidateName = tostring(getUnitName(unitInfo) or "")
    return trackedName ~= "" and candidateName ~= "" and trackedName == candidateName
end

---Normalizes buff countdown values into milliseconds.
---@param rawValue any
---@return number|nil
local function normalizeTimeLeftMs(rawValue)
    local value = tonumber(rawValue)
    if value == nil or value <= 0 then
        return nil
    end
    if value <= 300 then
        return value * 1000
    end
    return value
end

---Extracts a tracked buff countdown from a buff or debuff object.
---@param aura table|nil
---@return number|nil
local function extractTrackedTimeLeftMs(aura)
    if type(aura) ~= "table" then
        return nil
    end
    return normalizeTimeLeftMs(aura.timeLeft or aura.leftTime or aura.remainTime)
end

---Returns the remaining time for a cached expiration timestamp.
---@param expirationMs number|nil
---@param nowMs number
---@return number|nil
local function getRemainingExpirationMs(expirationMs, nowMs)
    local expiration = tonumber(expirationMs)
    if expiration == nil then
        return nil
    end
    local remaining = expiration - (tonumber(nowMs) or 0)
    if remaining <= 0 then
        return nil
    end
    return remaining
end

---Formats a millisecond countdown for display.
---@param remainingMs any
---@return string
local function formatTimeLeft(remainingMs)
    local value = tonumber(remainingMs)
    if value == nil or value <= 0 then
        return "--"
    end
    local seconds = value / 1000
    seconds = math.floor((seconds * 10) + 0.5) / 10
    if seconds >= 3600 then
        return string.format(
            "%d:%02d:%02d",
            math.floor(seconds / 3600),
            math.floor((seconds % 3600) / 60),
            math.floor(seconds % 60)
        )
    end
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
    end
    if seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    end
    return string.format("%.1f", seconds)
end

---Returns the preferred color for the current state label.
---@param pendingPresent boolean
---@param criticalPresent boolean
---@param expiringPresent boolean
---@param missingPresent boolean
---@param activePresent boolean
---@return table
local function buildStatusColor(pendingPresent, criticalPresent, expiringPresent, missingPresent, activePresent)
    if pendingPresent then
        return { 1, 0.86, 0.4, 1 }
    end
    if criticalPresent then
        return { 1, 0.28, 0.28, 1 }
    end
    if expiringPresent then
        return { 1, 0.65, 0.28, 1 }
    end
    if missingPresent then
        return { 1, 0.42, 0.42, 1 }
    end
    if activePresent then
        return { 0.65, 0.82, 1, 1 }
    end
    return { 0.82, 0.86, 0.92, 1 }
end

---Returns a readable label for the source currently driving the snapshot.
---@param unitKey string|nil
---@return string
local function formatSourceLabel(unitKey)
    if unitKey == "target" then
        return "Target"
    end
    if unitKey == "watchtarget" then
        return "Watch Target"
    end
    if unitKey == "target_of_target" then
        return "Target of Target"
    end
    if type(unitKey) == "string" and unitKey ~= "" then
        return unitKey
    end
    return "Unknown"
end

---Scans a token for the tracked Owner's Mark auras.
---@param unitToken string
---@return table
local function findTrackedAuras(unitToken)
    local output = {
        pending_buff = nil,
        active_buff = nil,
        unknown_owner_mark_buff = nil
    }

    for _, auraKind in ipairs({ "buff", "debuff" }) do
        local auraCount = safeAuraCount(unitToken, auraKind)
        for index = 1, auraCount do
            local aura = safeAura(unitToken, auraKind, index)
            if aura ~= nil then
                local auraState = getTrackedAuraState(aura)
                if auraState == "pending" and output.pending_buff == nil then
                    output.pending_buff = aura
                elseif auraState == "countdown" and output.active_buff == nil then
                    output.active_buff = aura
                elseif auraState == "owner_mark_unknown" and output.unknown_owner_mark_buff == nil then
                    output.unknown_owner_mark_buff = aura
                end
            end
        end
    end

    if output.pending_buff == nil and output.active_buff == nil and output.unknown_owner_mark_buff ~= nil then
        output.pending_buff = output.unknown_owner_mark_buff
    end

    return output
end

---Builds a short debug summary for one logical unit source.
---@param unitKey string
---@return string
local function buildUnitDebugLine(unitKey)
    local unitToken, unitId = resolveUnitKey(unitKey)
    if unitToken == nil or unitId == nil then
        return string.format("%s: no unit", tostring(unitKey))
    end

    local buffCount = safeAuraCount(unitToken, "buff")
    local debuffCount = safeAuraCount(unitToken, "debuff")
    local trackedAuras = findTrackedAuras(unitToken)
    local trackedState = "none"
    local trackedAura = trackedAuras.pending_buff or trackedAuras.active_buff or trackedAuras.unknown_owner_mark_buff
    if trackedAuras.pending_buff ~= nil and trackedAuras.active_buff ~= nil then
        trackedState = "pending+countdown"
    elseif trackedAuras.pending_buff ~= nil then
        trackedState = "pending"
    elseif trackedAuras.active_buff ~= nil then
        trackedState = "countdown"
    elseif trackedAuras.unknown_owner_mark_buff ~= nil then
        trackedState = "owner_mark_unknown"
    end

    local auraId = getAuraId(trackedAura)
    local auraName = getAuraName(trackedAura)
    local nameSuffix = ""
    if type(auraName) == "string" and auraName ~= "" then
        nameSuffix = " " .. tostring(auraName)
    end

    return string.format(
        "%s/%s id=%s buffs=%s debuffs=%s tracked=%s aura=%s%s",
        tostring(unitKey),
        tostring(unitToken),
        tostring(unitId),
        tostring(buffCount),
        tostring(debuffCount),
        tostring(trackedState),
        tostring(auraId or "--"),
        nameSuffix
    )
end

---Builds live debug text for the supported unit sources.
---@return string
local function buildDebugText()
    local parts = {}
    for _, unitKey in ipairs({ "target", "watchtarget", "target_of_target" }) do
        parts[#parts + 1] = buildUnitDebugLine(unitKey)
    end
    return table.concat(parts, "\n")
end

---Resets cached mark state when the player deliberately swaps to another vehicle.
---@param unitId any
---@param unitInfo table|nil
---@return nil
local function clearTrackedMarkState(unitId, unitInfo)
    local previousId = normalizeUnitId(Tracker.state.tracked_unit_id)
    local nextId = normalizeUnitId(unitId)
    local previousName = tostring(Tracker.state.tracked_unit_name or "")
    local nextName = tostring(getUnitName(unitInfo) or "")
    local changed = false

    if previousId ~= nil and nextId ~= nil then
        changed = previousId ~= nextId
    elseif previousName ~= "" and nextName ~= "" then
        changed = previousName ~= nextName
    end

    if changed then
        Tracker.state.pending_present_cached = false
        Tracker.state.pending_expiration_ms = nil
        Tracker.state.active_expiration_ms = nil
        Tracker.state.has_seen_mark = false
    end
end

---Remembers the tracked vehicle learned from the live target.
---@param candidate table
---@param nowMs number
---@return nil
local function rememberTrackedVehicle(candidate, nowMs)
    clearTrackedMarkState(candidate.unit_id, candidate.unit_info)
    Tracker.state.tracked_unit_id = normalizeUnitId(candidate.unit_id)
    Tracker.state.tracked_unit_name = getUnitName(candidate.unit_info)
    Tracker.state.tracked_seen_ms = tonumber(nowMs) or 0
    Tracker.state.last_source_text = "Live " .. tostring(candidate.unit_key or candidate.unit_token or "target")
    if type(candidate.owner_name) == "string" and candidate.owner_name ~= "" then
        Tracker.state.last_owner_name = candidate.owner_name
    end
end

---Returns whether the current unit is a valid source for learning or refreshing the vehicle.
---@param unitId any
---@param unitInfo table|nil
---@param playerName string|nil
---@param hasTrackedAura boolean
---@return boolean
local function shouldUseCandidate(unitId, unitInfo, playerName, hasTrackedAura)
    if normalizeUnitId(unitId) == nil then
        return false
    end
    return hasTrackedAura
        or isOwnedByPlayer(unitInfo, playerName)
        or matchesTrackedVehicle(unitId, unitInfo)
end

---Builds a candidate from a logical unit key when valid.
---@param unitKey string
---@param nowMs number
---@return table|nil
local function scanUnitKey(unitKey, nowMs)
    local unitToken, unitId = resolveUnitKey(unitKey)
    if unitId == nil then
        return nil
    end

    local unitInfo = safeUnitInfo(unitToken) or safeGetUnitInfoById(unitId)
    local auras = findTrackedAuras(unitToken)
    local hasTrackedAura = auras.pending_buff ~= nil or auras.active_buff ~= nil
    local playerName = getPlayerName()
    if not shouldUseCandidate(unitId, unitInfo, playerName, hasTrackedAura) then
        return nil
    end

    local candidate = {
        unit_key = unitKey,
        unit_token = unitToken,
        unit_id = unitId,
        unit_info = unitInfo,
        unit_name = getUnitName(unitInfo),
        owner_name = getOwnerName(unitInfo),
        pending_buff = auras.pending_buff,
        active_buff = auras.active_buff
    }

    rememberTrackedVehicle(candidate, nowMs)
    return candidate
end

---Scans supported live sources and returns the best available tracked vehicle candidate.
---@param nowMs number
---@return table|nil
local function scanTrackedVehicle(nowMs)
    local scanOrder = { "target", "watchtarget", "target_of_target" }
    local firstRemembered = nil

    for _, unitKey in ipairs(scanOrder) do
        local candidate = scanUnitKey(unitKey, nowMs)
        if candidate ~= nil then
            if candidate.pending_buff ~= nil or candidate.active_buff ~= nil then
                return candidate
            end
            if firstRemembered == nil then
                firstRemembered = candidate
            end
        end
    end

    return firstRemembered
end

---Refreshes cached pending and active timers from the live target scan.
---@param candidate table|nil
---@param nowMs number
---@return nil
local function refreshCachedTimers(candidate, nowMs)
    local pendingPresentNow = candidate ~= nil and candidate.pending_buff ~= nil
    local pendingTimeLeftMs = extractTrackedTimeLeftMs(candidate ~= nil and candidate.pending_buff or nil)
    if candidate ~= nil then
        Tracker.state.pending_present_cached = pendingPresentNow
        if pendingTimeLeftMs ~= nil then
            Tracker.state.pending_expiration_ms = nowMs + pendingTimeLeftMs
            Tracker.state.has_seen_mark = true
        else
            Tracker.state.pending_expiration_ms = nil
        end
    elseif pendingPresentNow then
        Tracker.state.pending_present_cached = true
    elseif pendingTimeLeftMs ~= nil then
        Tracker.state.pending_expiration_ms = nowMs + pendingTimeLeftMs
        Tracker.state.has_seen_mark = true
    elseif getRemainingExpirationMs(Tracker.state.pending_expiration_ms, nowMs) == nil then
        Tracker.state.pending_expiration_ms = nil
    end

    local activePresentNow = candidate ~= nil and candidate.active_buff ~= nil
    local activeTimeLeftMs = extractTrackedTimeLeftMs(candidate ~= nil and candidate.active_buff or nil)
    if candidate ~= nil then
        if activePresentNow then
            Tracker.state.pending_present_cached = false
        end
        if activeTimeLeftMs ~= nil then
            Tracker.state.active_expiration_ms = nowMs + activeTimeLeftMs
            Tracker.state.has_seen_mark = true
        else
            Tracker.state.active_expiration_ms = nil
        end
    elseif activeTimeLeftMs ~= nil then
        Tracker.state.active_expiration_ms = nowMs + activeTimeLeftMs
        Tracker.state.has_seen_mark = true
    elseif getRemainingExpirationMs(Tracker.state.active_expiration_ms, nowMs) == nil then
        Tracker.state.active_expiration_ms = nil
    end
end

---Builds the default view snapshot for the tracker.
---@return table
local function buildEmptySnapshot()
    return {
        vehicle_present = false,
        warning_visible = false,
        critical_present = false,
        expiring_present = false,
        missing_present = false,
        unit_token = nil,
        unit_id = nil,
        unit_name = nil,
        owner_name = nil,
        source_label = "Waiting",
        pending_present = false,
        pending_time_left_ms = nil,
        pending_time_text = "--",
        active_present = false,
        active_time_left_ms = nil,
        active_time_text = "--",
        current_state = "Target your vehicle to start tracking",
        current_time_text = "--",
        status_color = { 0.82, 0.86, 0.92, 1 },
        source_text = "Waiting for a live target scan.",
        tracking_text = "Target your vehicle once so the addon can remember it.",
        vehicle_hint_text = "Once it is learned, the addon can keep warning off cached mark timers.",
        help_text = "1. Target your vehicle once.\n2. Armed means the mark is ready.\n3. Countdown starts after you dismount."
    }
end

---Builds a tracker snapshot from the current target plus cached countdowns.
---@param candidate table|nil
---@param nowMs number
---@return table
local function buildSnapshot(candidate, nowMs)
    local snapshot = buildEmptySnapshot()
    local pendingTimeLeftMs = getRemainingExpirationMs(Tracker.state.pending_expiration_ms, nowMs)
    local activeTimeLeftMs = getRemainingExpirationMs(Tracker.state.active_expiration_ms, nowMs)
    local trackedVehicleKnown = Tracker.state.tracked_unit_id ~= nil or Tracker.state.tracked_unit_name ~= nil
    local pendingPresent = (candidate ~= nil and candidate.pending_buff ~= nil) or Tracker.state.pending_present_cached
    local activePresent = (candidate ~= nil and candidate.active_buff ~= nil) or activeTimeLeftMs ~= nil
    local criticalPresent = activeTimeLeftMs ~= nil
        and activeTimeLeftMs <= (tonumber(Constants.ACTIVE_CRITICAL_THRESHOLD_MS) or 15000)
    local expiringPresent = activeTimeLeftMs ~= nil
        and activeTimeLeftMs <= (tonumber(Constants.ACTIVE_WARNING_THRESHOLD_MS) or 60000)
    local missingPresent = trackedVehicleKnown and not pendingPresent and not activePresent
    local vehiclePresent = trackedVehicleKnown

    snapshot.vehicle_present = vehiclePresent
    snapshot.warning_visible = pendingPresent or activePresent or missingPresent
    snapshot.critical_present = criticalPresent
    snapshot.expiring_present = expiringPresent
    snapshot.missing_present = missingPresent
    snapshot.unit_token = candidate ~= nil and candidate.unit_token or nil
    snapshot.unit_id = candidate ~= nil and candidate.unit_id or Tracker.state.tracked_unit_id
    snapshot.unit_name = (candidate ~= nil and candidate.unit_name) or Tracker.state.tracked_unit_name
    snapshot.owner_name = (candidate ~= nil and candidate.owner_name) or Tracker.state.last_owner_name
    snapshot.pending_present = pendingPresent
    snapshot.pending_time_left_ms = pendingTimeLeftMs
    snapshot.pending_time_text = formatTimeLeft(pendingTimeLeftMs)
    snapshot.active_present = activePresent
    snapshot.active_time_left_ms = activeTimeLeftMs
    snapshot.active_time_text = formatTimeLeft(activeTimeLeftMs)
    snapshot.source_label = candidate ~= nil and formatSourceLabel(candidate.unit_key or candidate.unit_token) or "Cached"

    if candidate ~= nil then
        snapshot.source_text = string.format(
            "Live scan via %s.",
            tostring(formatSourceLabel(candidate.unit_key or candidate.unit_token))
        )
    elseif pendingTimeLeftMs ~= nil or activeTimeLeftMs ~= nil then
        snapshot.source_text = "Using cached mark timers from the last live scan."
        snapshot.source_label = "Cached Timer"
    elseif trackedVehicleKnown then
        snapshot.source_text = "Using the remembered vehicle from the last live scan."
        snapshot.source_label = "Remembered Vehicle"
    else
        snapshot.source_text = tostring(Tracker.state.last_source_text or "Waiting for a live target scan.")
        snapshot.source_label = "Waiting"
    end

    if snapshot.pending_present then
        snapshot.current_state = "Owner's Mark Armed"
        snapshot.current_time_text = "--"
        snapshot.tracking_text = "The mark is armed on the tracked ride."
        snapshot.vehicle_hint_text = "The timer starts after you dismount."
    elseif snapshot.critical_present then
        snapshot.current_state = "Owner's Mark Critical"
        snapshot.current_time_text = snapshot.active_time_text
        snapshot.tracking_text = "The countdown is in the last-chance window."
        snapshot.vehicle_hint_text = "Refresh soon or lose the mark."
    elseif snapshot.expiring_present then
        snapshot.current_state = "Owner's Mark Warning"
        snapshot.current_time_text = snapshot.active_time_text
        snapshot.tracking_text = "The countdown is inside the warning window."
        snapshot.vehicle_hint_text = "You still have time, but it is burning down."
    elseif snapshot.active_present then
        snapshot.current_state = "Owner's Mark Countdown"
        snapshot.current_time_text = snapshot.active_time_text
        snapshot.tracking_text = "The mark is counting down on the tracked ride."
        snapshot.vehicle_hint_text = "Retarget the vehicle anytime to refresh confirmation."
    elseif snapshot.missing_present then
        snapshot.current_state = "Owner's Mark Missing"
        snapshot.current_time_text = "Missing"
        snapshot.tracking_text = "No pending or active mark is tracked on the remembered ride."
        snapshot.vehicle_hint_text = "Either it fell off or the addon needs a fresh scan."
    elseif snapshot.vehicle_present then
        snapshot.current_state = "Tracking Vehicle"
        snapshot.current_time_text = "--"
        if Tracker.state.has_seen_mark then
            snapshot.tracking_text = "Tracking is anchored to the remembered vehicle from your earlier scan."
            snapshot.vehicle_hint_text = "Cached tracking works, but a fresh scan is better."
        else
            snapshot.tracking_text = "Vehicle learned from target. The addon is waiting for Owner's Mark to appear there."
            snapshot.vehicle_hint_text = "Once it shows up, the warning overlays react automatically."
        end
    end

    snapshot.help_text = "1. Target your ride once.\n2. Armed means the mark is ready.\n3. Countdown starts after you dismount."
    snapshot.status_color = buildStatusColor(
        snapshot.pending_present,
        snapshot.critical_present,
        snapshot.expiring_present,
        snapshot.missing_present,
        snapshot.active_present
    )
    snapshot.observed_ms = tonumber(nowMs) or 0
    return snapshot
end

---Updates the tracker state and returns a UI snapshot.
---@return table
function Tracker.Update()
    local nowMs = getNowMs()
    local candidate = scanTrackedVehicle(nowMs)

    refreshCachedTimers(candidate, nowMs)

    local snapshot = buildSnapshot(candidate, nowMs)
    Tracker.state.snapshot = snapshot
    return snapshot
end

---Returns the latest tracker snapshot without rescanning.
---@return table
function Tracker.GetSnapshot()
    if type(Tracker.state.snapshot) == "table" then
        return Tracker.state.snapshot
    end
    return buildEmptySnapshot()
end

---Resets tracker state to its initial value.
---@return nil
function Tracker.Reset()
    Tracker.state.snapshot = nil
    Tracker.state.tracked_unit_id = nil
    Tracker.state.tracked_unit_name = nil
    Tracker.state.tracked_seen_ms = nil
    Tracker.state.pending_present_cached = false
    Tracker.state.pending_expiration_ms = nil
    Tracker.state.active_expiration_ms = nil
    Tracker.state.last_source_text = nil
    Tracker.state.last_owner_name = nil
    Tracker.state.has_seen_mark = false
end

return Tracker
