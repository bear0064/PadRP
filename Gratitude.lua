local _, ns = ...

local recentThanks = {}
local recentEventDedup = {}
local sessionThanked = {}
local lastPhraseUsed = ""
ns.lastHelper = nil

local MODES = { "DEFAULT_NO_WHISPER", "DO_EMOTE", "MANUAL", "WHISPER", "OFF" }
local MODE_LABELS = {
    DEFAULT_NO_WHISPER = "Default (No Whisper: Pool Emote / /thank)",
    DO_EMOTE           = "Blizzard Voice Emote (/thank)",
    MANUAL             = "Manual Only (Quick-Thank Controller Bind)",
    WHISPER            = "Opt-In Whisper (/w)",
    OFF                = "Disabled (Off)",
}

local function IsSafeValue(v)
    if v == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(v) then
        return false
    end
    return true
end

local function SafeString(v)
    if not IsSafeValue(v) or type(v) ~= "string" then return nil end
    return v
end

local function SafeNumber(v)
    if not IsSafeValue(v) or type(v) ~= "number" then return nil end
    return v
end

local function SafeBool(v)
    if not IsSafeValue(v) then return false end
    return v == true
end

local function NormalizeGratitudeMode(rawMode)
    local m = tostring(rawMode or "DEFAULT_NO_WHISPER")
    if m == "SMART" or m == "AUTO_EMOTE" then
        return "DEFAULT_NO_WHISPER"
    elseif m == "AUTO_WHISPER" then
        return "WHISPER"
    end
    return MODE_LABELS[m] and m or "DEFAULT_NO_WHISPER"
end

local function NormalizeUnitName(rawName)
    local cleanRaw = SafeString(rawName)
    if not cleanRaw or cleanRaw == "" then return nil end
    local localRealm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not localRealm or localRealm == "" then
        localRealm = string.gsub(GetRealmName() or "Realm", "%s+", "")
    end
    local shortName, realmPart = strsplit("-", cleanRaw)
    if realmPart and realmPart ~= "" then
        local cleanRealm = string.gsub(realmPart, "%s+", "")
        if string.lower(cleanRealm) ~= string.lower(localRealm) then
            return shortName .. "-" .. cleanRealm
        end
    end
    return shortName
end

function ns:GetGratitudeModeLabel()
    local activeMode = NormalizeGratitudeMode(ns.db and ns.db.gratitude and ns.db.gratitude.mode)
    return MODE_LABELS[activeMode] or activeMode
end

function ns:CycleGratitudeMode()
    ns.db.gratitude = ns.db.gratitude or {}
    local cur = NormalizeGratitudeMode(ns.db.gratitude.mode)
    local idx = 1
    for i, m in ipairs(MODES) do
        if m == cur then
            idx = (i % #MODES) + 1
            break
        end
    end
    ns.db.gratitude.mode = MODES[idx]
    print("|cff8ab4f8[PadRP]|r Gratitude Mode: |cfffdd663" .. ns:GetGratitudeModeLabel() .. "|r")
    if ns.RefreshControllerUI then ns:RefreshControllerUI() end
end

local function ClassifySpellCategory(subEvent, spellName)
    local s = string.lower(SafeString(spellName) or "")
    if subEvent == "SPELL_RESURRECT"
        or string.find(s, "resurrection", 1, true)
        or string.find(s, "redemption", 1, true)
        or string.find(s, "rebirth", 1, true)
        or string.find(s, "ancestral spirit", 1, true)
        or string.find(s, "revive", 1, true)
        or string.find(s, "reincarnation", 1, true) then
        return "RES"
    end
    if string.find(s, "summon", 1, true)
        or string.find(s, "ritual of", 1, true)
        or string.find(s, "soulstone", 1, true) then
        return "SUMMON"
    end
    if string.find(s, "portal:", 1, true)
        or string.find(s, "innervate", 1, true)
        or string.find(s, "power infusion", 1, true)
        or string.find(s, "fear ward", 1, true)
        or string.find(s, "divine intervention", 1, true)
        or string.find(s, "blessing of protection", 1, true)
        or string.find(s, "healthstone", 1, true)
        or string.find(s, "refreshment", 1, true) then
        return "SPECIAL"
    end
    return "STANDARD"
end

local function PickRandomPhrase(category)
    local g = ns.db.gratitude
    local pool

    if category == "RES" then
        pool = g.resPhrases
    elseif category == "SUMMON" then
        pool = g.summonPhrases
    elseif category == "SPECIAL" then
        pool = g.specialPhrases
    else
        pool = ns.profile.isIC and g.icPhrases or g.oocPhrases
    end

    if not pool or type(pool) ~= "table" or #pool == 0 then
        pool = { "nods respectfully to %name in gratitude for the %spell." }
    end

    local chosen = pool[math.random(1, #pool)]
    if #pool > 1 and chosen == lastPhraseUsed then
        chosen = pool[(math.random(1, #pool - 1) % #pool) + 1]
    end
    lastPhraseUsed = chosen
    return chosen
end

function ns:PerformThank(targetRawName, spellLabel, isManualHardwarePress, category)
    local cleanTarget = NormalizeUnitName(targetRawName)
    if not cleanTarget then return false end

    ns.db.gratitude = ns.db.gratitude or {}
    local mode = NormalizeGratitudeMode(ns.db.gratitude.mode)
    ns.db.gratitude.mode = mode

    if mode == "OFF" then return false end
    if mode == "MANUAL" and not isManualHardwarePress then
        return false
    end

    local inInstance = IsInInstance and select(1, IsInInstance())
    local sentOk = false

    if mode == "WHISPER" then
        local template = PickRandomPhrase(category or "STANDARD")
        local formatted = ns:FormatTokens(template, cleanTarget, spellLabel or "aid")
        sentOk = pcall(SendChatMessage, formatted, "WHISPER", nil, cleanTarget) and true or false
        if not sentOk then
            sentOk = pcall(DoEmote, "THANK", cleanTarget) and true or false
        end
    elseif mode == "DO_EMOTE" and not isManualHardwarePress then
        sentOk = pcall(DoEmote, "THANK", cleanTarget) and true or false
    elseif isManualHardwarePress or inInstance then
        local template = PickRandomPhrase(category or "STANDARD")
        local formatted = ns:FormatTokens(template, cleanTarget, spellLabel or "aid")
        sentOk = pcall(SendChatMessage, formatted, "EMOTE") and true or false
        if not sentOk then
            sentOk = pcall(DoEmote, "THANK", cleanTarget) and true or false
        end
    else
        sentOk = pcall(DoEmote, "THANK", cleanTarget) and true or false
    end

    if sentOk then
        local displayName = ns:GetUnitRPName(cleanTarget, true)
        print(string.format("|cff81c995[PadRP]|r Thanked |cfffdd663%s|r (%s).", displayName, spellLabel or "aid"))
    end
    return sentOk
end

function ns:QuickThankAction()
    if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local targetName = (GetUnitName and GetUnitName("target", true)) or UnitName("target")
        ns:PerformThank(targetName, "assistance", true, "STANDARD")
    elseif ns.lastHelper and (GetTime() - ns.lastHelper.time) < 180 then
        ns:PerformThank(ns.lastHelper.name, ns.lastHelper.spellName, true, ns.lastHelper.category)
    else
        DoEmote("THANK")
    end
end

local function QueueGratitudeForHelper(sourceKey, sourceName, matchedAction, category)
    local g = ns.db.gratitude
    if not g then return end
    local mode = NormalizeGratitudeMode(g.mode)
    g.mode = mode
    if mode == "OFF" then return end

    local cleanTarget = NormalizeUnitName(sourceName)
    if not cleanTarget then return end

    if g.ignoreParty and (UnitInParty(cleanTarget) or UnitInRaid(cleanTarget)) then
        return
    end

    local safeKey = SafeString(sourceKey)
    local cooldownKey = safeKey or string.lower(cleanTarget)
    local now = GetTime()
    local dedupKey = cooldownKey .. ":" .. tostring(category or "STANDARD") .. ":" .. string.lower(tostring(matchedAction or ""))
    if recentEventDedup[dedupKey] and (now - recentEventDedup[dedupKey]) < 3.0 then
        return
    end
    recentEventDedup[dedupKey] = now

    ns.lastHelper = { name = cleanTarget, spellName = matchedAction, category = category, time = now }
    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end

    if mode == "MANUAL" then
        print(string.format("|cff8ab4f8[PadRP]|r %s cast |cfffdd663%s|r on you. Press Quick-Thank to respond!", ns:GetUnitRPName(cleanTarget, true), matchedAction))
        return
    end

    if g.oncePerSession and sessionThanked[cooldownKey] and category == "STANDARD" then
        return
    end

    local lastTime = recentThanks[cooldownKey] or 0
    if category ~= "RES" and (now - lastTime) < (g.cooldown or 60) then
        return
    end

    recentThanks[cooldownKey] = now
    sessionThanked[cooldownKey] = true

    if C_Timer and C_Timer.After then
        C_Timer.After(1.2, function()
            ns:PerformThank(cleanTarget, matchedAction, false, category)
        end)
    else
        ns:PerformThank(cleanTarget, matchedAction, false, category)
    end
end

local function HandleCombatLogEventInternal()
    local g = ns.db and ns.db.gratitude
    if not g or NormalizeGratitudeMode(g.mode) == "OFF" or not CombatLogGetCurrentEventInfo then return end

    local ok, _, rawSubEvent, _, rawSourceGUID, rawSourceName, rawSourceFlags, _, rawDestGUID, _, _, _, _, rawSpellName, _, rawArg15, rawArg16 = pcall(CombatLogGetCurrentEventInfo)
    if not ok then return end

    local subEvent = SafeString(rawSubEvent)
    local sourceGUID = SafeString(rawSourceGUID)
    local sourceName = SafeString(rawSourceName)
    local sourceFlags = SafeNumber(rawSourceFlags)
    local destGUID = SafeString(rawDestGUID)
    local spellName = SafeString(rawSpellName)
    local playerGUID = SafeString(UnitGUID("player"))

    if not subEvent or not playerGUID or destGUID ~= playerGUID or sourceGUID == playerGUID or not sourceName then
        return
    end
    if sourceFlags then
        if bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then return end
        if bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then return end
    end

    local category = ClassifySpellCategory(subEvent, spellName)
    local matchedAction = nil

    if subEvent == "SPELL_RESURRECT" and g.thankRes then
        matchedAction = spellName or "resurrection"
        category = "RES"
    elseif (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH") and SafeString(rawArg15) == "BUFF" then
        if (category == "SUMMON" or category == "SPECIAL") and g.thankSpecial then
            matchedAction = spellName or "aid"
        elseif g.thankBuffs then
            matchedAction = spellName or "buff"
        end
    elseif subEvent == "SPELL_HEAL" and g.thankHeals and not InCombatLockdown() then
        local healAmount = SafeNumber(rawArg15)
        local overhealAmount = SafeNumber(rawArg16) or 0
        local maxHP = SafeNumber(UnitHealthMax("player"))
        if healAmount and maxHP and maxHP > 0 then
            local effectiveHeal = math.max(0, healAmount - overhealAmount)
            local healPct = (effectiveHeal / maxHP) * 100
            if healPct >= (g.minHealPercent or 15) then
                matchedAction = spellName or "heal"
            end
        end
    end

    if matchedAction then
        QueueGratitudeForHelper(sourceGUID, sourceName, matchedAction, category)
    end
end

local function IsFriendlyOtherPlayerUnit(unitToken)
    if not unitToken or unitToken == "" then return false end
    local okEx, ex = pcall(UnitExists, unitToken)
    if not okEx or not SafeBool(ex) then return false end

    local okPl, isPl = pcall(UnitIsPlayer, unitToken)
    if not okPl or not SafeBool(isPl) then return false end

    local okMe, isMe = pcall(UnitIsUnit, unitToken, "player")
    if not okMe or SafeBool(isMe) then return false end

    local okFr, isFr = pcall(UnitIsFriend, "player", unitToken)
    if not okFr or not SafeBool(isFr) then return false end

    return true
end

local function HandlePlayerAuraUpdateInternal(updateInfo)
    local g = ns.db and ns.db.gratitude
    if not g or NormalizeGratitudeMode(g.mode) == "OFF" or not updateInfo or not C_UnitAuras then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local aurasToCheck = {}
    if IsSafeValue(updateInfo.addedAuras) and type(updateInfo.addedAuras) == "table" then
        for _, aura in ipairs(updateInfo.addedAuras) do
            if IsSafeValue(aura) and type(aura) == "table" then
                table.insert(aurasToCheck, aura)
            end
        end
    end
    if IsSafeValue(updateInfo.updatedAuraInstanceIDs) and type(updateInfo.updatedAuraInstanceIDs) == "table"
        and C_UnitAuras.GetAuraDataByAuraInstanceID then
        for _, instanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            if IsSafeValue(instanceID) then
                local okAura, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", instanceID)
                if okAura and IsSafeValue(aura) and type(aura) == "table" then
                    table.insert(aurasToCheck, aura)
                end
            end
        end
    end

    for _, aura in ipairs(aurasToCheck) do
        local sourceUnit = SafeString(aura.sourceUnit)
        local isHelpful = SafeBool(aura.isHelpful)
        if isHelpful and sourceUnit and IsFriendlyOtherPlayerUnit(sourceUnit) then
            local okName, rawCasterName = pcall(function()
                return (GetUnitName and GetUnitName(sourceUnit, true)) or UnitName(sourceUnit)
            end)
            local okGuid, rawCasterGUID = pcall(UnitGUID, sourceUnit)
            local casterName = okName and SafeString(rawCasterName) or nil
            local casterGUID = okGuid and SafeString(rawCasterGUID) or nil
            local spellName = SafeString(aura.name) or "buff"

            if casterName then
                local category = ClassifySpellCategory("SPELL_AURA_APPLIED", spellName)
                if (category == "SUMMON" or category == "SPECIAL") and g.thankSpecial then
                    QueueGratitudeForHelper(casterGUID, casterName, spellName, category)
                elseif g.thankBuffs then
                    QueueGratitudeForHelper(casterGUID, casterName, spellName, category)
                end
            end
        end
    end
end

function ns:InitGratitude()
    ns.db.gratitude = ns.db.gratitude or {}
    ns.db.gratitude.mode = NormalizeGratitudeMode(ns.db.gratitude.mode)
    ns:CreateBindButton("PadRP_QuickThankButton", function() ns:QuickThankAction() end)

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("UNIT_AURA")

    frame:SetScript("OnEvent", function(_, event, unitTarget, updateInfo)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            pcall(HandleCombatLogEventInternal)
        elseif event == "UNIT_AURA" and SafeString(unitTarget) == "player" then
            pcall(HandlePlayerAuraUpdateInternal, updateInfo)
        end
    end)
end