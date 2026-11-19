local _, ns = ...

local recentThanks = {}
local recentEventDedup = {}
local sessionThanked = {}
local lastPhraseUsed = ""
ns.lastHelper = nil

local MODES = { "SMART", "AUTO_EMOTE", "AUTO_WHISPER", "DO_EMOTE", "MANUAL", "OFF" }
local MODE_LABELS = {
    SMART        = "Smart Auto (Emote Nearby / Whisper Far)",
    AUTO_EMOTE   = "Auto Custom Emote (/e)",
    AUTO_WHISPER = "Auto Custom Whisper (/w)",
    DO_EMOTE     = "Blizzard Voice Emote (/thank)",
    MANUAL       = "Manual Only (Quick-Thank Controller Bind)",
    OFF          = "Disabled (Off)",
}

local function NormalizeWhisperTarget(rawName)
    if not rawName or rawName == "" then return nil end
    local localRealm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not localRealm or localRealm == "" then
        localRealm = string.gsub(GetRealmName() or "Realm", "%s+", "")
    end
    local shortName, realmPart = strsplit("-", rawName)
    if realmPart and realmPart ~= "" then
        local cleanRealm = string.gsub(realmPart, "%s+", "")
        if string.lower(cleanRealm) ~= string.lower(localRealm) then
            return shortName .. "-" .. cleanRealm
        end
    end
    return shortName
end

function ns:GetGratitudeModeLabel()
    return MODE_LABELS[ns.db.gratitude.mode] or ns.db.gratitude.mode
end

function ns:CycleGratitudeMode()
    local cur = ns.db.gratitude.mode
    local idx = 1
    for i, m in ipairs(MODES) do
        if m == cur then idx = (i % #MODES) + 1 break end
    end
    ns.db.gratitude.mode = MODES[idx]
    print("|cff8ab4f8[PadRP]|r Gratitude Mode: |cfffdd663" .. ns:GetGratitudeModeLabel() .. "|r")
    if ns.RefreshControllerUI then ns:RefreshControllerUI() end
end

local function ClassifySpellCategory(subEvent, spellName)
    local s = string.lower(spellName or "")
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

-- Strictly pull from the user's customized pools in PadRPDB
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
    local cleanTarget = NormalizeWhisperTarget(targetRawName)
    if not cleanTarget then return false end

    local mode = ns.db.gratitude.mode
    if mode == "OFF" then return false end
    if mode == "MANUAL" and not isManualHardwarePress then
        return false
    end

    local template = PickRandomPhrase(category or "STANDARD")
    local formatted = ns:FormatTokens(template, cleanTarget, spellLabel or "aid")
    local inInstance = IsInInstance and select(1, IsInInstance())
    local sentOk = false

    if mode == "DO_EMOTE" and not isManualHardwarePress then
        local ok = pcall(DoEmote, "THANK", cleanTarget)
        sentOk = ok and true or false
    elseif mode == "AUTO_WHISPER" then
        local ok = pcall(SendChatMessage, formatted, "WHISPER", nil, cleanTarget)
        sentOk = ok and true or false
    elseif isManualHardwarePress or inInstance then
        local ok = pcall(SendChatMessage, formatted, "EMOTE")
        sentOk = ok and true or false
    else
        -- Open-world automatic trigger: whisper helper instead of protected EMOTE send
        local ok = pcall(SendChatMessage, formatted, "WHISPER", nil, cleanTarget)
        if not ok then
            ok = pcall(DoEmote, "THANK", cleanTarget)
        end
        sentOk = ok and true or false
    end

    if sentOk then
        local displayName = ns:GetUnitRPName(cleanTarget, true)
        print(string.format("|cff81c995[PadRP]|r Thanked |cfffdd663%s|r (%s) with custom pool phrase.", displayName, spellLabel or "aid"))
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
    if not g or g.mode == "OFF" then return end

    local cleanTarget = NormalizeWhisperTarget(sourceName)
    if not cleanTarget then return end

    if g.ignoreParty and (UnitInParty(cleanTarget) or UnitInRaid(cleanTarget)) then
        return
    end

    local cooldownKey = sourceKey or string.lower(cleanTarget)
    local now = GetTime()
    local dedupKey = cooldownKey .. ":" .. tostring(category or "STANDARD") .. ":" .. string.lower(tostring(matchedAction or ""))
    if recentEventDedup[dedupKey] and (now - recentEventDedup[dedupKey]) < 3.0 then
        return
    end
    recentEventDedup[dedupKey] = now

    ns.lastHelper = { name = cleanTarget, spellName = matchedAction, category = category, time = now }
    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end

    if g.mode == "MANUAL" then
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

local function HandleCombatLogEvent()
    local g = ns.db.gratitude
    if not g or g.mode == "OFF" or not CombatLogGetCurrentEventInfo then return end

    local ok, _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, _, spellName, _, arg15, arg16 = pcall(CombatLogGetCurrentEventInfo)
    if not ok or not subEvent then return end

    if destGUID ~= UnitGUID("player") or sourceGUID == UnitGUID("player") or not sourceName then
        return
    end
    if sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == 0 then return end
    if sourceFlags and bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then return end

    local category = ClassifySpellCategory(subEvent, spellName)
    local matchedAction = nil

    if subEvent == "SPELL_RESURRECT" and g.thankRes then
        matchedAction = spellName or "resurrection"
        category = "RES"
    elseif (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH") and arg15 == "BUFF" then
        if (category == "SUMMON" or category == "SPECIAL") and g.thankSpecial then
            matchedAction = spellName or "aid"
        elseif g.thankBuffs then
            matchedAction = spellName or "buff"
        end
    elseif subEvent == "SPELL_HEAL" and g.thankHeals and not InCombatLockdown() then
        local effectiveHeal = (arg15 or 0) - (arg16 or 0)
        local maxHP = UnitHealthMax("player") or 1
        local healPct = (effectiveHeal / maxHP) * 100
        if healPct >= (g.minHealPercent or 15) then
            matchedAction = spellName or "heal"
        end
    end

    if matchedAction then
        QueueGratitudeForHelper(sourceGUID, sourceName, matchedAction, category)
    end
end

local function HandlePlayerAuraUpdate(updateInfo)
    local g = ns.db.gratitude
    if not g or g.mode == "OFF" or not updateInfo or not C_UnitAuras then return end

    local aurasToCheck = {}
    if updateInfo.addedAuras then
        for _, aura in ipairs(updateInfo.addedAuras) do
            table.insert(aurasToCheck, aura)
        end
    end
    if updateInfo.updatedAuraInstanceIDs and C_UnitAuras.GetAuraDataByAuraInstanceID then
        for _, instanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID)
            if aura then
                table.insert(aurasToCheck, aura)
            end
        end
    end

    for _, aura in ipairs(aurasToCheck) do
        if aura.isHelpful and aura.sourceUnit and UnitExists(aura.sourceUnit)
            and UnitIsPlayer(aura.sourceUnit) and not UnitIsUnit(aura.sourceUnit, "player")
            and UnitIsFriend("player", aura.sourceUnit) then

            local casterName = (GetUnitName and GetUnitName(aura.sourceUnit, true)) or UnitName(aura.sourceUnit)
            local casterGUID = UnitGUID(aura.sourceUnit)
            local spellName = aura.name or "buff"
            local category = ClassifySpellCategory("SPELL_AURA_APPLIED", spellName)

            if (category == "SUMMON" or category == "SPECIAL") and g.thankSpecial then
                QueueGratitudeForHelper(casterGUID, casterName, spellName, category)
            elseif g.thankBuffs then
                QueueGratitudeForHelper(casterGUID, casterName, spellName, category)
            end
        end
    end
end

function ns:InitGratitude()
    ns:CreateBindButton("PadRP_QuickThankButton", function() ns:QuickThankAction() end)

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("UNIT_AURA")

    frame:SetScript("OnEvent", function(_, event, unitTarget, updateInfo)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            HandleCombatLogEvent()
        elseif event == "UNIT_AURA" and unitTarget == "player" then
            HandlePlayerAuraUpdate(updateInfo)
        end
    end)
end