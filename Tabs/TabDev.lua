local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[8] = mod

function mod.Build(p8)
    p8.diagText = p8:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p8.diagText:SetPoint("TOPLEFT", 16, -12)
    p8.diagText:SetPoint("TOPRIGHT", -16, -12)
    p8.diagText:SetJustifyH("LEFT")

    p8.chkDebug = ns:CreateMaterialButton(p8, "", 180, 26, 16, -34, nil, function()
        ns.mspDebug = not ns.mspDebug
        ns:RefreshControllerUI()
    end)
    p8.chkSniff = ns:CreateMaterialButton(p8, "", 180, 26, 204, -34, nil, function()
        ns.mspSniff = not ns.mspSniff
        if ns.mspSniff then ns.mspDebug = true end
        ns:RefreshControllerUI()
    end)
    p8.chkEcho = ns:CreateMaterialButton(p8, "", 196, 26, 392, -34, nil, function()
        ns.mspEchoChat = not ns.mspEchoChat
        ns:RefreshControllerUI()
    end)

    p8.popOutBtn = ns:CreateMaterialButton(p8, "Pop-Out Inspector", 140, 28, 16, -68, "PRIMARY", function()
        ns.mspDebug = true
        if ns.ToggleNetInspector then ns:ToggleNetInspector(true) end
        ns:RefreshControllerUI()
    end)
    p8.selfTestBtn = ns:CreateMaterialButton(p8, "Run Self-Test", 140, 28, 164, -68, "AMBER", function()
        if ns.RunMSPSelfTest then ns:RunMSPSelfTest() end
    end)

    p8.clearCacheBtn = ns:CreateMaterialButton(p8, "Clear Profile Cache", 148, 28, 312, -68, "CORAL", function(self)
        local now = GetTime()
        if now < (UI.confirmClearCacheUntil or 0) then
            UI.confirmClearCacheUntil = 0
            self:SetText("Clear Profile Cache")
            local removed = (ns.ClearMSPCache and ns:ClearMSPCache()) or 0
            if ns.LogNet then
                ns:LogNet("CACHE", "fff28b82", string.format("Cleared %d cached profile(s). Ready to test live pulls!", removed))
            end
            ns:ShowStatusToast(string.format("Cleared %d cached profiles", removed))
        else
            UI.confirmClearCacheUntil = now + 4
            self:SetText("|cfff28b82Confirm Wipe?|r")
            if C_Timer and C_Timer.After then
                C_Timer.After(4.1, function()
                    if p8.clearCacheBtn then p8.clearCacheBtn:SetText("Clear Profile Cache") end
                end)
            end
        end
    end)

    p8.logEditor = ns:CreateScrollableTextEditor(p8, "Network & wire logs appear here when Debug Events or Wire Sniffer are checked...", 16, -104, 572, 240)
    p8.logEditor:SetPoint("BOTTOMRIGHT", p8, "BOTTOMRIGHT", -16, 14)
end

function mod.Layout(p8)
    if not p8 or not p8.chkDebug then return end
    UI:LayoutRow(p8, -34, {
        { w = p8.chkDebug, weight = 1 },
        { w = p8.chkSniff, weight = 1 },
        { w = p8.chkEcho,  weight = 1 },
    }, 16, 16, 8)

    UI:LayoutRow(p8, -68, {
        { w = p8.popOutBtn,     weight = 1 },
        { w = p8.selfTestBtn,   weight = 1 },
        { w = p8.clearCacheBtn, weight = 1 },
    }, 16, 16, 8)
end

function mod.Refresh(p8)
    if not p8 or not p8.diagText or not ns.mspStats then return end
    local engState = (type(_G.msp) == "table") and "|cff81c995LibMSP ACTIVE|r" or "|cfff28b82LibMSP MISSING|r"
    local cachedCount = (UI.GetKnownDirectoryCount and UI:GetKnownDirectoryCount()) or 0
    p8.diagText:SetText(string.format(
        "|cff8ab4f8ENGINE:|r %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
        engState,
        ns.mspStats.sent or 0,
        ns.mspStats.liveReplies or 0,
        cachedCount,
        ns.mspStats.lastReplyFrom or "None"
    ))
    p8.chkDebug:SetText(UI:FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
    p8.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)
    p8.chkSniff:SetText(UI:FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
    p8.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)
    p8.chkEcho:SetText(UI:FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
    p8.chkEcho:SetTone(ns.mspEchoChat and "PRIMARY" or nil)
    p8.logEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
end