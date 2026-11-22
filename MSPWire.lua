local _, ns = ...

local lastRequested = {}
local pendingScans = {}
local announcedRPUsers = {}
local dirtyReceivers = {}
local flushScheduled = false

local passiveQueue = {}
local passiveQueuedSet = {}
local passiveTickerActive = false

ns.netLogs = ns.netLogs or {}
ns.mspEchoChat = false

local FULL_PROFILE_FIELDS = {
    "TT", "DE", "HI", "IC", "PX", "NI", "NH",
    "AG", "AH", "AW", "AE", "HB", "HH", "MO", "RS", "FR", "PE", "WU",
}

function ns:ResetWireThrottles()
    wipe(lastRequested)
    wipe(pendingScans)
    wipe(announcedRPUsers)
    wipe(dirtyReceivers)
    wipe(passiveQueue)
    wipe(passiveQueuedSet)
    flushScheduled = false
    passiveTickerActive = false
end

function ns:LogNet(tag, colorHex, msg)
    local stamp = date("%H:%M:%S")
    local line = string.format("|cff9aa0a6[%s]|r |c%s[%s]|r %s", stamp, colorHex or "ff8ab4f8", tag or "INFO", tostring(msg))
    table.insert(ns.netLogs, line)
    if #ns.netLogs > 250 then
        table.remove(ns.netLogs, 1)
    end
    if _G.PadRP_NetInspector and _G.PadRP_NetInspector:IsShown() and ns.RefreshNetInspector then
        ns:RefreshNetInspector(line)
    end
    if ns.mspEchoChat then
        print("|cff8ab4f8[PadRP]|r " .. line)
    end
end

function ns:DebugMSP(msg)
    if ns.mspDebug then
        ns:LogNet("DEBUG", "ff8ab4f8", msg)
    end
end

function ns:IsScanPending(key)
    if not key or not pendingScans[key] then return false end
    return (GetTime() - pendingScans[key]) < 4.0
end

local function RefreshAllProfileViews()
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    if ns.RefreshDossierWindow then ns:RefreshDossierWindow() end
    if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshControllerUI then
        ns:RefreshControllerUI()
    elseif _G.PadRP_NetInspector and _G.PadRP_NetInspector:IsShown() and ns.RefreshNetInspector then
        ns:RefreshNetInspector()
    end
    if ns.RefreshUnitTooltipNow then ns:RefreshUnitTooltipNow() end
end

local function FlushDirtyReceivers()
    flushScheduled = false
    local anyUpdated = false
    local myKey = ns:GetUnitKey("player")

    for senderUnitID in pairs(dirtyReceivers) do
        dirtyReceivers[senderUnitID] = nil
        local pulled, shortKey = ns:PullFromLibMSPChar(senderUnitID)
        if pulled and shortKey then
            anyUpdated = true
            pendingScans[shortKey] = nil
            ns.mspStats.received = (ns.mspStats.received or 0) + 1
            ns.mspStats.liveReplies = (ns.mspStats.liveReplies or 0) + 1
            ns.mspStats.lastReplyFrom = shortKey

            if shortKey ~= myKey and not announcedRPUsers[shortKey] then
                announcedRPUsers[shortKey] = true
                ns:LogNet("LIVE REPLY", "ff81c995", string.format("Pulled profile via LibMSP: %s (%s)", pulled.NA or shortKey, senderUnitID))
            elseif ns.mspDebug then
                ns:LogNet("MSP UPDATE", "ff8ab4f8", string.format("Updated %s (%s)", pulled.NA or shortKey, senderUnitID))
            end
        end
    end

    if anyUpdated then
        RefreshAllProfileViews()
    end
end

local function OnLibMSPReceived(senderUnitID)
    if not senderUnitID or senderUnitID == "" then return end
    dirtyReceivers[senderUnitID] = true
    if not flushScheduled then
        flushScheduled = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, FlushDirtyReceivers)
        else
            FlushDirtyReceivers()
        end
    end
end

function ns:RequestUnitMSP(unitOrName, includeFullBio, forceBypassThrottle, isPassive)
    if UnitExists(unitOrName) and not UnitIsPlayer(unitOrName) then return false end

    local mspID = ns:GetMSPUnitID(unitOrName)
    local shortKey = ns:GetUnitKey(unitOrName)
    if not mspID or not shortKey then return false end

    local myKey = ns:GetUnitKey("player")
    if not isPassive and shortKey ~= myKey then
        ns.lastInspectedKey = shortKey
        ns.lastInspectedTime = GetTime()
    end

    if type(_G.msp) ~= "table" or type(_G.msp.Request) ~= "function" then
        if ns.mspDebug then
            ns:LogNet("ERROR", "fff28b82", "LibMSP is not loaded! Copy ChatThrottleLib, Chomp, and LibMSP into PadRP\\Libs\\.")
        end
        return false
    end

    local throttleKey = shortKey .. (includeFullBio and "_FULL" or "_TT")
    local throttleWindow = includeFullBio and 15 or 90
    local now = GetTime()
    if not forceBypassThrottle and lastRequested[throttleKey] and (now - lastRequested[throttleKey]) < throttleWindow then
        return true
    end
    lastRequested[throttleKey] = now

    local existing = ns:GetCachedMSP(shortKey)
    local wasUncached = (not existing or not existing.NA or existing.NA == "")
    if wasUncached and not isPassive then
        pendingScans[shortKey] = now
    elseif not wasUncached then
        pendingScans[shortKey] = nil
    end

    local fields = includeFullBio and FULL_PROFILE_FIELDS or { "TT" }
    local ok, err = pcall(_G.msp.Request, _G.msp, mspID, fields)
    ns.mspStats.sent = (ns.mspStats.sent or 0) + 1

    if ns.mspDebug or ns.mspSniff then
        ns:LogNet(
            isPassive and "RADAR REQ" or "MSP REQ",
            "ff8ab4f8",
            string.format("msp:Request(%s, %s) -> %s", mspID, includeFullBio and "FULL" or "TT", ok and "SENT" or tostring(err))
        )
    end

    if wasUncached and not isPassive and C_Timer and C_Timer.After then
        C_Timer.After(4.1, function()
            if pendingScans[shortKey] then
                pendingScans[shortKey] = nil
                if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
                if ns.RefreshDossierWindow then ns:RefreshDossierWindow() end
            end
        end)
    end
    return true
end

-- Staggered passive queue prevents hub burst-throttling when 20+ nameplates load at once
local function DrainPassiveQueue()
    if #passiveQueue == 0 then
        passiveTickerActive = false
        return
    end

    if InCombatLockdown() then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, DrainPassiveQueue)
        else
            passiveTickerActive = false
        end
        return
    end

    local item = table.remove(passiveQueue, 1)
    if item then
        passiveQueuedSet[item.key] = nil
        ns:RequestUnitMSP(item.target, false, item.force, true)
    end

    if #passiveQueue > 0 and C_Timer and C_Timer.After then
        C_Timer.After(0.25, DrainPassiveQueue)
    else
        passiveTickerActive = false
    end
end

local function EnqueuePassiveScan(unitOrName, forceBypassThrottle)
    if InCombatLockdown() then return false end
    if UnitExists(unitOrName) then
        if not UnitIsPlayer(unitOrName) or not UnitIsFriend("player", unitOrName) or UnitIsUnit(unitOrName, "player") then
            return false
        end
    end

    local mspID = ns:GetMSPUnitID(unitOrName)
    local shortKey = ns:GetUnitKey(unitOrName)
    if not mspID or not shortKey then return false end

    local myKey = ns:GetUnitKey("player")
    if shortKey == myKey then return false end

    local throttleKey = shortKey .. "_TT"
    if not forceBypassThrottle and lastRequested[throttleKey] and (GetTime() - lastRequested[throttleKey]) < 90 then
        return false
    end

    if passiveQueuedSet[shortKey] then return true end
    if #passiveQueue >= 40 then return false end

    passiveQueuedSet[shortKey] = true
    table.insert(passiveQueue, { target = mspID, key = shortKey, force = forceBypassThrottle })

    if not passiveTickerActive then
        passiveTickerActive = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, DrainPassiveQueue)
        else
            DrainPassiveQueue()
        end
    end
    return true
end

function ns:BackgroundSweepNearby(forceAll)
    if InCombatLockdown() then return 0 end
    local units = { "target", "mouseover" }
    for i = 1, 4 do table.insert(units, "party" .. i) end
    for i = 1, 40 do table.insert(units, "raid" .. i) end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unitToken = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if unitToken and UnitExists(unitToken) then
                    table.insert(units, unitToken)
                end
            end
        end
    end

    local scanned = {}
    local count = 0
    local myKey = ns:GetUnitKey("player")

    for _, u in ipairs(units) do
        if UnitExists(u) and UnitIsPlayer(u) and UnitIsFriend("player", u) and not UnitIsUnit(u, "player") then
            local k = ns:GetUnitKey(u)
            if k and k ~= myKey and not scanned[k] then
                scanned[k] = true
                if EnqueuePassiveScan(u, forceAll) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function ns:ScanNearbyPlayers()
    local harvested, totalCached = ns:ImportAllKnownFromTRP3AndMSP()
    local count = ns:BackgroundSweepNearby(true)
    ns:LogNet("RADAR", "ff81c995", string.format("Synced %d profile(s) (%d total cached); queued %d nearby/nameplate player(s).", harvested, totalCached, count))
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, function()
            ns:ImportAllKnownFromTRP3AndMSP()
            RefreshAllProfileViews()
        end)
    end
end

function ns:RunMSPSelfTest()
    ns.mspDebug = true
    ns.mspSniff = true
    local hasMSP = (type(_G.msp) == "table" and type(_G.msp.Request) == "function")
    local hasChomp = (type(_G.AddOn_Chomp) == "table")
    local myMspID = ns:GetMSPUnitID("player") or "nil"

    ns:LogNet(
        "SELF-TEST",
        hasMSP and "ff81c995" or "fff28b82",
        string.format(
            "LibMSP=%s | Chomp=%s | TRP3=%s | PlayerID=%s",
            hasMSP and "LOADED" or "MISSING",
            hasChomp and "LOADED" or "MISSING",
            _G.TRP3_API and "ON" or "OFF",
            myMspID
        )
    )

    if hasMSP then
        ns:SyncMSP()
        ns:RequestUnitMSP("player", true, true)
    else
        print("|cfff28b82[PadRP]|r LibMSP is missing! Copy ChatThrottleLib, Chomp, and LibMSP into Interface\\AddOns\\PadRP\\Libs\\ and /reload.")
    end
    if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshControllerUI then
        ns:RefreshControllerUI()
    end
end

function ns:InitMSPProtocol()
    ns.db.mspCache = ns.db.mspCache or {}
    ns.mspCache = ns.db.mspCache

    local hasMSP = (type(_G.msp) == "table" and type(_G.msp.Request) == "function")
    local hasChomp = (type(_G.AddOn_Chomp) == "table")

    if hasMSP then
        if type(_G.msp.callback) == "table" and type(_G.msp.callback.received) == "table" then
            table.insert(_G.msp.callback.received, OnLibMSPReceived)
        end
        ns:SyncMSP()
        local _, totalCached = ns:ImportAllKnownFromTRP3AndMSP()
        ns:LogNet("INIT", "ff81c995", string.format("Native LibMSP + Chomp ready (Chomp=%s, Cached=%d).", hasChomp and "YES" or "NO", totalCached))
    else
        ns:LogNet("ERROR", "fff28b82", "LibMSP NOT FOUND! Copy ChatThrottleLib, Chomp, and LibMSP into PadRP\\Libs\\.")
        print("|cfff28b82[PadRP]|r LibMSP not found in PadRP\\Libs\\. Copy ChatThrottleLib, Chomp, and LibMSP from totalRP3\\Libs\\ and /reload.")
    end

    local commFrame = CreateFrame("Frame")
    commFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    commFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    commFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    commFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    commFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    commFrame:RegisterEvent("CHAT_MSG_SAY")
    commFrame:RegisterEvent("CHAT_MSG_EMOTE")
    commFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    commFrame:RegisterEvent("CHAT_MSG_YELL")
    commFrame:RegisterEvent("CHAT_MSG_ADDON")
    commFrame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")

    commFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
        if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
            if ns.mspSniff and arg1 and (string.find(arg1, "^MSP") or string.find(arg1, "^TRP")) then
                local preview = string.gsub(string.sub(tostring(arg2 or ""), 1, 64), "[\000-\031]", "|")
                ns:LogNet(event == "CHAT_MSG_ADDON_LOGGED" and "WIRE LOG" or "WIRE STD", "fffdd663", string.format("[%s] %s: %s", arg1, tostring(arg4 or "?"), preview))
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            if C_Timer and C_Timer.After then
                C_Timer.After(2.5, function()
                    ns:BackgroundSweepNearby(false)
                end)
            end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            if arg1 and UnitExists(arg1) and UnitIsPlayer(arg1) and UnitIsFriend("player", arg1) and not UnitIsUnit(arg1, "player") then
                EnqueuePassiveScan(arg1, false)
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
                ns:RequestUnitMSP("target", true, false)
            end
            if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
            if ns.RefreshDossierWindow then ns:RefreshDossierWindow() end
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            if not InCombatLockdown() and UnitExists("mouseover") and UnitIsPlayer("mouseover") and UnitIsFriend("player", "mouseover") and not UnitIsUnit("mouseover", "player") then
                ns:RequestUnitMSP("mouseover", false, false, true)
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            ns:BackgroundSweepNearby(false)
        elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE" or event == "CHAT_MSG_YELL" then
            if arg2 and arg2 ~= "" and not InCombatLockdown() then
                EnqueuePassiveScan(arg2, false)
            end
        end
    end)

    SlashCmdList["PADRP"] = function(msg)
        local cmd = strtrim(string.lower(msg or ""))
        if cmd == "minimap" then
            if ns.ResetMinimapButton then ns:ResetMinimapButton() end
        elseif cmd == "scan" then
            ns:ScanNearbyPlayers()
        elseif cmd == "clearcache" and ns.ClearMSPCache then
            local removed = ns:ClearMSPCache()
            print(string.format("|cff8ab4f8[PadRP]|r Cleared |cfffdd663%d|r cached RP profiles.", removed))
        elseif cmd == "dev" or cmd == "console" or cmd == "debug" or cmd == "sniff" then
            ns.db.ui.devMode = true
            if cmd == "debug" or cmd == "dev" then ns.mspDebug = true end
            if cmd == "sniff" then ns.mspSniff = true; ns.mspDebug = true end
            if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshControllerUI then ns:RefreshControllerUI() end
            if ns.ToggleNetInspector then ns:ToggleNetInspector(true) end
        elseif cmd == "test" then
            ns.db.ui.devMode = true
            if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshControllerUI then ns:RefreshControllerUI() end
            if ns.ToggleNetInspector then ns:ToggleNetInspector(true) end
            ns:RunMSPSelfTest()
        else
            if ns.ToggleMainFrame then ns:ToggleMainFrame() end
        end
    end
end