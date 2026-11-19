local _, ns = ...

local dossierFrame
local selectedDossierKey = nil
local activeSubView = "CHAR"
local STANDINGS = { "None", "Ally", "Acquaintance", "Rival", "Marked" }

local function EnsureNoteRecord(key)
    ns.db.notes = ns.db.notes or {}
    local rec = ns.db.notes[key]
    if type(rec) ~= "table" then
        rec = { standing = "None", accountNote = "", charNotes = {} }
        ns.db.notes[key] = rec
    end
    rec.standing = rec.standing or "None"
    rec.charNotes = rec.charNotes or {}
    if rec.accountNote == nil then
        rec.accountNote = rec.note or ""
    end
    return rec
end

local function SaveCurrentNotes()
    if not dossierFrame or not selectedDossierKey then return end
    local rec = EnsureNoteRecord(selectedDossierKey)
    local charKey = ns:GetPlayerCharKey()
    local charTxt = dossierFrame.charNoteBox:GetText() or ""
    local acctTxt = dossierFrame.acctNoteBox:GetText() or ""
    rec.charNotes[charKey] = charTxt
    rec.accountNote = acctTxt
    rec.note = acctTxt -- Keep legacy field synced for backward compatibility
    dossierFrame.charNoteBox.isDirty = false
    dossierFrame.acctNoteBox.isDirty = false
    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshTargetCard then
        ns:RefreshTargetCard()
    end
end

local function FormatRow(label, value)
    if not value or strtrim(tostring(value)) == "" then return nil end
    return string.format("|cff9aa0a6%s:|r  |cffe8eaed%s|r", label, strtrim(tostring(value)))
end

local function BuildCharacteristicsText(data)
    local lines = {}
    local basic = {}
    local function AddBasic(lbl, val)
        local r = FormatRow(lbl, val)
        if r then table.insert(basic, r) end
    end

    AddBasic("Race", data.RA)
    AddBasic("Class", data.RC)
    AddBasic("Age", data.AG)
    AddBasic("Height", data.AH)
    AddBasic("Build / Body Shape", data.AW)
    AddBasic("Eye Color", data.AE)
    AddBasic("Birthplace", data.HB)
    AddBasic("Residence", data.HH)
    if data.RS and data.RS ~= "" and data.RS ~= "0" then
        AddBasic("Relationship", ns:GetRelationshipLabel(data.RS))
    end
    if data.FR and data.FR ~= "" and data.FR ~= "0" then
        AddBasic("RP Proficiency", ns:GetRPStyleLabel(data.FR))
    end

    if #basic > 0 then
        table.insert(lines, "|cff8ab4f8BASIC INFORMATION|r\n" .. table.concat(basic, "\n"))
    end

    local extra = {}
    local function AddExtra(lbl, val)
        local r = FormatRow(lbl, val)
        if r then table.insert(extra, r) end
    end
    AddExtra("Nickname", data.NI)
    AddExtra("House / Clan", data.NH)
    AddExtra("Motto", data.MO)

    if #extra > 0 then
        table.insert(lines, "|cfffdd663ADDITIONAL INFORMATION|r\n" .. table.concat(extra, "\n"))
    end

    if data.CU and data.CU ~= "" then
        table.insert(lines, "|cff81c995CURRENTLY|r\n" .. data.CU)
    end

    if #lines == 0 then
        return "|cff9aa0a6No characteristics fields listed in this profile yet. Try 'Pull Full Bio' below.|r"
    end
    return table.concat(lines, "\n\n")
end

local function BuildAboutText(data)
    local lines = {}
    if data.DE and strtrim(data.DE) ~= "" then
        table.insert(lines, "|cff8ab4f8PHYSICAL DESCRIPTION & PERSONALITY|r\n" .. data.DE)
    end
    if data.HI and strtrim(data.HI) ~= "" then
        table.insert(lines, "|cfffdd663CHARACTER HISTORY|r\n" .. data.HI)
    end
    if #lines == 0 then
        return "|cff9aa0a6No Physical Description or History written in this profile.|r"
    end
    return table.concat(lines, "\n\n")
end

local function BuildGlancesStatusText(data)
    local lines = {}
    local structured = ns:ParseGlancesStructured(data.PE)
    if #structured > 0 then
        local gLines = {}
        for idx = 1, math.min(5, #structured) do
            local g = structured[idx]
            local iconTag = string.format("|T%s:22:22:0:0:64:64:4:60:4:60|t ", g.icon)
            if g.detail and g.detail ~= "" then
                table.insert(gLines, string.format("%s|cfffdd663%s|r\n%s", iconTag, g.title, g.detail))
            else
                table.insert(gLines, string.format("%s|cfffdd663%s|r", iconTag, g.title))
            end
        end
        table.insert(lines, "|cfffdd663AT FIRST GLANCE|r\n" .. table.concat(gLines, "\n\n"))
    end

    if data.CU and strtrim(data.CU) ~= "" then
        table.insert(lines, "|cff8ab4f8CURRENTLY|r\n" .. data.CU)
    end
    if data.CO and strtrim(data.CO) ~= "" then
        table.insert(lines, "|cff81c995OTHER INFORMATION (OOC)|r\n" .. data.CO)
    end

    if #lines == 0 then
        return "|cff9aa0a6No First Glances, Currently, or OOC notes found in this profile.|r"
    end
    return table.concat(lines, "\n\n")
end

function ns:RefreshDossierWindow()
    if not dossierFrame or not dossierFrame:IsShown() then return end

    local key = selectedDossierKey
    if not key and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        key = ns:GetUnitKey("target")
    end
    key = key or ns.lastInspectedKey

    dossierFrame.tabChar:SetTone(activeSubView == "CHAR" and "PRIMARY" or nil)
    dossierFrame.tabAbout:SetTone(activeSubView == "ABOUT" and "PRIMARY" or nil)
    dossierFrame.tabGlances:SetTone(activeSubView == "GLANCES" and "PRIMARY" or nil)
    dossierFrame.tabNotes:SetTone(activeSubView == "NOTES" and "PRIMARY" or nil)

    if not key then
        dossierFrame.portraitTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        dossierFrame.modeBadge:SetText("|cff9aa0a6[NO PROFILE SELECTED]|r")
        dossierFrame.headerName:SetText("|cff9aa0a6Select a Player from Known RP or Target Someone|r")
        dossierFrame.vitalsText:SetText("")
        dossierFrame.readerBox:Show()
        dossierFrame.notesPanel:Hide()
        dossierFrame.scrollText:SetText("")
        return
    end

    selectedDossierKey = key
    local isLiveTarget = UnitExists("target") and UnitIsPlayer("target") and (ns:GetUnitKey("target") == key)
    local tHex = "ff8ab4f8"
    if isLiveTarget then
        local _, tClass = UnitClass("target")
        tHex = (tClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tClass] and RAID_CLASS_COLORS[tClass].colorStr) or "ffffffff"
        dossierFrame.modeBadge:SetText("|cff81c995[LIVE TARGET DOSSIER]|r  |cff9aa0a6(" .. key .. ")|r")
    else
        dossierFrame.modeBadge:SetText("|cff8ab4f8[CACHED PROFILE DOSSIER]|r  |cff9aa0a6(" .. key .. ")|r")
    end

    local data = ns:GetCachedMSP(key)
    local standing, charNote, acctNote, hasNote = ns:GetNoteInfo(key)

    -- Update Notes tab badge indicator
    dossierFrame.tabNotes:SetText(hasNote and "Notes |cff81c995*|r" or "Notes")

    if data and data.IC and strtrim(data.IC) ~= "" then
        local iconPath = string.find(data.IC, "\\", 1, true) and data.IC or ("Interface\\Icons\\" .. strtrim(data.IC))
        dossierFrame.portraitTex:SetTexture(iconPath)
    else
        dossierFrame.portraitTex:SetTexture("Interface\\Icons\\INV_Helmet_46")
    end

    if not data or not data.NA then
        local shortName = strsplit("-", key)
        dossierFrame.headerName:SetText("|c" .. tHex .. shortName .. "|r")
        if ns.IsScanPending and ns:IsScanPending(key) then
            dossierFrame.vitalsText:SetText("|cff8ab4f8Scanning LibMSP profile... Waiting for reply...|r")
        else
            dossierFrame.vitalsText:SetText("|cff9aa0a6No RP profile cached yet. Press 'Pull Full Bio' below if they are online.|r")
        end
    else
        local displayName = data.NA
        if data.PX and strtrim(data.PX) ~= "" and not string.find(displayName, strtrim(data.PX), 1, true) then
            displayName = strtrim(data.PX) .. " " .. displayName
        end
        local titleStr = (data.NT and data.NT ~= "") and ("  |cfffdd663<" .. data.NT .. ">|r") or ""
        dossierFrame.headerName:SetText("|c" .. tHex .. displayName .. "|r" .. titleStr)

        local icBadge = (data.FC == "2") and "|cff81c995[IC]|r" or "|cfff28b82[OOC]|r"
        local wuBadge = ns:GetTargetWalkUpInfo(data)
        local statusBadges = wuBadge and (icBadge .. " " .. wuBadge) or icBadge
        local raceClass = strtrim((data.RA or "") .. " " .. (data.RC or ""))
        local seenStr = ""
        if data.lastSeen and data.lastSeen > 0 then
            seenStr = "   |cff9aa0a6Seen:|r " .. date("%m/%d %H:%M", data.lastSeen)
        end
        dossierFrame.vitalsText:SetText(string.format("%s   |cffe8eaed%s|r%s", statusBadges, raceClass, seenStr))
    end

    if activeSubView == "NOTES" then
        dossierFrame.readerBox:Hide()
        dossierFrame.notesPanel:Show()
        dossierFrame.standingBtn:SetText("Standing: |cfffdd663" .. standing .. "|r")

        local myCharDisplay = (ns.profile and ns.profile.firstName and ns.profile.firstName ~= "") and ns.profile.firstName or (UnitName("player") or "Character")
        if ns.profile and ns.profile.lastName and strtrim(ns.profile.lastName) ~= "" then
            myCharDisplay = myCharDisplay .. " " .. strtrim(ns.profile.lastName)
        end
        dossierFrame.charNoteLabel:SetText("|cff81c995Notes from " .. myCharDisplay .. "|r  |cff9aa0a6(Character-Specific)|r")

        if not dossierFrame.charNoteBox:HasFocus() then
            dossierFrame.charNoteBox:SetCleanText(charNote)
        end
        if not dossierFrame.acctNoteBox:HasFocus() then
            dossierFrame.acctNoteBox:SetCleanText(acctNote)
        end
    else
        dossierFrame.notesPanel:Hide()
        dossierFrame.readerBox:Show()

        if not data or not data.NA then
            dossierFrame.scrollText:SetText("|cff9aa0a6No RP profile loaded for this player. Switch to the Notes tab to keep private notes or click 'Pull Full Bio'.|r")
        elseif activeSubView == "ABOUT" then
            dossierFrame.scrollText:SetText(BuildAboutText(data))
        elseif activeSubView == "GLANCES" then
            dossierFrame.scrollText:SetText(BuildGlancesStatusText(data))
        else
            dossierFrame.scrollText:SetText(BuildCharacteristicsText(data))
        end

        local scrollW = dossierFrame.scrollFrame:GetWidth()
        if scrollW and scrollW > 60 then
            dossierFrame.scrollChild:SetWidth(scrollW - 10)
            dossierFrame.scrollText:SetWidth(scrollW - 16)
        end
        local textH = dossierFrame.scrollText:GetStringHeight() or 140
        dossierFrame.scrollChild:SetHeight(math.max(180, textH + 28))
        if dossierFrame.scrollFrame.SetVerticalScroll then
            dossierFrame.scrollFrame:SetVerticalScroll(0)
        end
    end
end

function ns:OpenTargetDossier(specificKey)
    if not dossierFrame then ns:InitDossierWindow() end

    if specificKey and specificKey ~= "" then
        selectedDossierKey = ns:GetUnitKey(specificKey)
        ns:RequestUnitMSP(selectedDossierKey, true, true)
    elseif UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        selectedDossierKey = ns:GetUnitKey("target")
        ns:RequestUnitMSP("target", true, true)
    elseif ns.lastInspectedKey then
        selectedDossierKey = ns.lastInspectedKey
        ns:RequestUnitMSP(selectedDossierKey, true, true)
    end

    activeSubView = "CHAR"
    dossierFrame:SetScale((ns.db and ns.db.ui and ns.db.ui.scale) or 1.0)
    dossierFrame:Show()
    dossierFrame:Raise()
    ns:RefreshDossierWindow()
end

function ns:InitDossierWindow()
    if dossierFrame then return end
    local M3 = ns.M3

    dossierFrame = CreateFrame("Frame", "PadRP_DossierWindow", UIParent, "BackdropTemplate")
    dossierFrame:SetSize(656, 520)
    dossierFrame:SetPoint("CENTER", UIParent, "CENTER", 40, -10)
    dossierFrame:SetFrameStrata("DIALOG")
    dossierFrame:SetFrameLevel(40)
    dossierFrame:SetMovable(true)
    dossierFrame:EnableMouse(true)
    dossierFrame:RegisterForDrag("LeftButton")
    dossierFrame:SetScript("OnDragStart", dossierFrame.StartMoving)
    dossierFrame:SetScript("OnDragStop", dossierFrame.StopMovingOrSizing)
    dossierFrame:SetScript("OnHide", function()
        SaveCurrentNotes()
    end)
    ns:ApplySurface(dossierFrame, M3.surfaceDim, M3.primary)
    ns:EnableClipping(dossierFrame)
    dossierFrame:Hide()
    tinsert(UISpecialFrames, "PadRP_DossierWindow")

    -- Portrait Box
    local portraitBox = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    portraitBox:SetSize(48, 48)
    portraitBox:SetPoint("TOPLEFT", 16, -12)
    ns:ApplySurface(portraitBox, M3.surface, M3.primary)
    dossierFrame.portraitTex = portraitBox:CreateTexture(nil, "ARTWORK")
    dossierFrame.portraitTex:SetSize(42, 42)
    dossierFrame.portraitTex:SetPoint("CENTER")
    dossierFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    dossierFrame.modeBadge = dossierFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dossierFrame.modeBadge:SetPoint("TOPLEFT", 74, -12)

    local closeBtn = ns:CreateMaterialButton(dossierFrame, "X", 28, 24, 616, -8, "CORAL", function()
        dossierFrame:Hide()
    end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", dossierFrame, "TOPRIGHT", -12, -8)

    local netBtn = ns:CreateMaterialButton(dossierFrame, "Net Console", 88, 24, 0, 0, "AMBER", function()
        if ns.ToggleNetInspector then ns:ToggleNetInspector() end
    end)
    netBtn:ClearAllPoints()
    netBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

    dossierFrame.headerName = dossierFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dossierFrame.headerName:SetPoint("TOPLEFT", 74, -27)
    dossierFrame.headerName:SetPoint("RIGHT", netBtn, "LEFT", -10, 0)
    dossierFrame.headerName:SetJustifyH("LEFT")
    dossierFrame.headerName:SetWordWrap(false)

    dossierFrame.vitalsText = dossierFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dossierFrame.vitalsText:SetPoint("TOPLEFT", 74, -48)
    dossierFrame.vitalsText:SetPoint("TOPRIGHT", -16, -48)
    dossierFrame.vitalsText:SetJustifyH("LEFT")
    dossierFrame.vitalsText:SetWordWrap(false)

    -- 4 TRP3-Style Sub-Tabs
    local function SwitchSubView(viewName)
        if activeSubView == "NOTES" then SaveCurrentNotes() end
        activeSubView = viewName
        ns:RefreshDossierWindow()
    end

    dossierFrame.tabChar = ns:CreateMaterialButton(dossierFrame, "Characteristics", 150, 26, 16, -68, "PRIMARY", function()
        SwitchSubView("CHAR")
    end)
    dossierFrame.tabAbout = ns:CreateMaterialButton(dossierFrame, "About (Bio)", 150, 26, 174, -68, nil, function()
        SwitchSubView("ABOUT")
    end)
    dossierFrame.tabGlances = ns:CreateMaterialButton(dossierFrame, "Glances & Status", 150, 26, 332, -68, nil, function()
        SwitchSubView("GLANCES")
    end)
    dossierFrame.tabNotes = ns:CreateMaterialButton(dossierFrame, "Notes", 150, 26, 490, -68, nil, function()
        SwitchSubView("NOTES")
    end)

    -- Reader Panel (Characteristics / About / Glances)
    local readerBox = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    readerBox:SetPoint("TOPLEFT", 16, -100)
    readerBox:SetPoint("BOTTOMRIGHT", -16, 102)
    ns:ApplySurface(readerBox, M3.surfaceLow, M3.outline)
    ns:EnableClipping(readerBox)
    dossierFrame.readerBox = readerBox

    local scrollFrame = CreateFrame("ScrollFrame", nil, readerBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)
    ns:EnableClipping(scrollFrame)
    dossierFrame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(580, 180)
    scrollFrame:SetScrollChild(scrollChild)
    dossierFrame.scrollChild = scrollChild

    dossierFrame.scrollText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dossierFrame.scrollText:SetPoint("TOPLEFT", 0, 0)
    dossierFrame.scrollText:SetWidth(570)
    dossierFrame.scrollText:SetJustifyH("LEFT")
    dossierFrame.scrollText:SetWordWrap(true)
    dossierFrame.scrollText:SetSpacing(3)

    -- Split Notes Panel (Character-Specific + Account-Wide + Standing)
    local notesPanel = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    notesPanel:SetPoint("TOPLEFT", 16, -100)
    notesPanel:SetPoint("BOTTOMRIGHT", -16, 102)
    ns:ApplySurface(notesPanel, M3.surfaceLow, M3.outline)
    ns:EnableClipping(notesPanel)
    notesPanel:Hide()
    dossierFrame.notesPanel = notesPanel

    dossierFrame.standingBtn = ns:CreateMaterialButton(notesPanel, "Standing: None", 180, 26, 12, -10, "AMBER", function()
        local key = selectedDossierKey
        if not key then return end
        local rec = EnsureNoteRecord(key)
        local cur = rec.standing or "None"
        local nextIdx = 1
        for i, s in ipairs(STANDINGS) do if s == cur then nextIdx = (i % #STANDINGS) + 1 break end end
        rec.standing = STANDINGS[nextIdx]
        ns:RefreshDossierWindow()
        ns:RefreshTargetHUD()
        if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
        if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshTargetCard then ns:RefreshTargetCard() end
    end)

    local noteHint = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteHint:SetPoint("LEFT", dossierFrame.standingBtn, "RIGHT", 10, 0)
    noteHint:SetText("|cff9aa0a6Saved notes display a |TInterface\\Icons\\INV_Misc_Note_01:13:13|t icon in tooltips.|r")

    local saveNotesBtn = ns:CreateMaterialButton(notesPanel, "Save Notes", 96, 26, 0, 0, "MINT", function()
        SaveCurrentNotes()
        ns:RefreshDossierWindow()
        if ns.ShowStatusToast then ns:ShowStatusToast("Saved character & account notes") end
    end)
    saveNotesBtn:ClearAllPoints()
    saveNotesBtn:SetPoint("TOPRIGHT", notesPanel, "TOPRIGHT", -12, -10)

    dossierFrame.charNoteLabel = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dossierFrame.charNoteLabel:SetPoint("TOPLEFT", 12, -44)
    dossierFrame.charNoteLabel:SetText("|cff81c995Character-Specific Notes|r")

    dossierFrame.charNoteBox = ns:CreateScrollableTextEditor(
        notesPanel,
        "Private RP notes from this character's perspective (e.g., how you met, debts, impressions)...",
        12, -62, 600, 108,
        function() SaveCurrentNotes() end
    )

    local acctLabel = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    acctLabel:SetPoint("TOPLEFT", 12, -178)
    acctLabel:SetText("|cff8ab4f8Account-Wide Notes|r  |cff9aa0a6(Shared across all your characters)|r")

    dossierFrame.acctNoteBox = ns:CreateScrollableTextEditor(
        notesPanel,
        "OOC / Account-wide notes about this player...",
        12, -196, 600, 108,
        function() SaveCurrentNotes() end
    )

    -- Controller RP Action Deck
    local deckLabel = dossierFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    deckLabel:SetPoint("BOTTOMLEFT", dossierFrame, "BOTTOMLEFT", 16, 82)
    deckLabel:SetText("|cff8ab4f8TARGET & RP ACTION DECK|r")

    local b1 = ns:CreateMaterialButton(dossierFrame, "Pull Full Bio", 150, 28, 0, 0, "PRIMARY", function()
        if selectedDossierKey then
            ns:RequestUnitMSP(selectedDossierKey, true, true)
            ns:RefreshDossierWindow()
        end
    end)
    b1:ClearAllPoints()
    b1:SetPoint("BOTTOMLEFT", dossierFrame, "BOTTOMLEFT", 16, 46)

    local b2 = ns:CreateMaterialButton(dossierFrame, "IC Greet (/e)", 150, 28, 0, 0, nil, function()
        if selectedDossierKey then
            SendChatMessage("inclines their head toward " .. ns:GetUnitRPName(selectedDossierKey, true) .. " in a polite greeting.", "EMOTE")
        else
            SendChatMessage("glances around the room and offers a polite nod.", "EMOTE")
        end
    end)
    b2:ClearAllPoints()
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)

    local b3 = ns:CreateMaterialButton(dossierFrame, "Thank Target", 150, 28, 0, 0, "MINT", function()
        ns:QuickThankAction()
    end)
    b3:ClearAllPoints()
    b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)

    local b4 = ns:CreateMaterialButton(dossierFrame, "Whisper OOC", 150, 28, 0, 0, nil, function()
        if selectedDossierKey and ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. strsplit("-", selectedDossierKey) .. " ")
        end
    end)
    b4:ClearAllPoints()
    b4:SetPoint("LEFT", b3, "RIGHT", 8, 0)

    local b5 = ns:CreateMaterialButton(dossierFrame, "Sit / Rest (/sit)", 150, 28, 0, 0, "AMBER", function()
        DoEmote("SIT")
    end)
    b5:ClearAllPoints()
    b5:SetPoint("BOTTOMLEFT", dossierFrame, "BOTTOMLEFT", 16, 12)

    local b6 = ns:CreateMaterialButton(dossierFrame, "Roll 1d20", 150, 28, 0, 0, nil, function()
        RandomRoll(1, 20)
    end)
    b6:ClearAllPoints()
    b6:SetPoint("LEFT", b5, "RIGHT", 8, 0)

    local b7 = ns:CreateMaterialButton(dossierFrame, "Tavern Drink", 150, 28, 0, 0, nil, function()
        if selectedDossierKey then
            SendChatMessage("raises a glass toward " .. ns:GetUnitRPName(selectedDossierKey, true) .. " before taking a slow sip.", "EMOTE")
        else
            SendChatMessage("takes a slow sip from their drink, watching the room.", "EMOTE")
        end
    end)
    b7:ClearAllPoints()
    b7:SetPoint("LEFT", b6, "RIGHT", 8, 0)

    local b8 = ns:CreateMaterialButton(dossierFrame, "Sweep Nearby", 150, 28, 0, 0, nil, function()
        ns:ScanNearbyPlayers()
    end)
    b8:ClearAllPoints()
    b8:SetPoint("LEFT", b7, "RIGHT", 8, 0)

    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        ConsolePort:AddInterfaceCursorFrame("PadRP_DossierWindow")
    end
end