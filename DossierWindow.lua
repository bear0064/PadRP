local _, ns = ...

local dossierFrame
local selectedDossierKey = nil
local activeSubView = "CHAR"
local SUB_VIEWS = { "CHAR", "ABOUT", "GLANCES", "NOTES" }
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
    rec.note = acctTxt
    dossierFrame.charNoteBox.isDirty = false
    dossierFrame.acctNoteBox.isDirty = false
    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshTargetCard then
        ns:RefreshTargetCard()
    end
end

local function IsPlayerSelfKey(key)
    if not key or key == "" then return false end
    local lk = string.lower(strtrim(tostring(key)))
    local pName = UnitName("player")
    if pName then
        local shortK = strsplit("-", key)
        if string.lower(strtrim(shortK or "")) == string.lower(pName) then
            return true
        end
    end
    if ns.GetUnitKey then
        local selfKey = ns:GetUnitKey("player")
        if selfKey and string.lower(strtrim(selfKey)) == lk then
            return true
        end
    end
    if ns.profile then
        local parts = {}
        if ns.profile.firstName and strtrim(ns.profile.firstName) ~= "" then
            table.insert(parts, strtrim(ns.profile.firstName))
        end
        if ns.profile.lastName and strtrim(ns.profile.lastName) ~= "" then
            table.insert(parts, strtrim(ns.profile.lastName))
        end
        if #parts > 0 and string.lower(table.concat(parts, " ")) == lk then
            return true
        end
    end
    return false
end

local function StripColorCodes(str)
    if not str then return "" end
    local clean = string.gsub(tostring(str), "|c%x%x%x%x%x%x%x%x", "")
    clean = string.gsub(clean, "|r", "")
    return clean
end

local function CleanOOCDisplayText(raw)
    if not raw then return "" end
    local clean = strtrim(StripColorCodes(raw))
    clean = string.gsub(clean, "%[Walk%-Ups:[^%]]*%]", "")
    clean = string.gsub(clean, "%[Pronouns:[^%]]*%]", "")
    clean = string.gsub(clean, "^%s*[•|%-]+%s*", "")
    clean = string.gsub(clean, "%s*[•|%-]+%s*$", "")
    return strtrim(clean)
end

local function NormalizeHex6(raw)
    if type(raw) ~= "string" then return nil end
    local clean = string.gsub(strtrim(raw), "^#+", "")
    clean = string.gsub(clean, "^|[cC]", "")
    if string.match(clean, "^%x%x%x%x%x%x%x%x$") then
        clean = string.sub(clean, 3, 8)
    end
    if string.match(clean, "^%x%x%x%x%x%x$") then
        return string.lower(clean)
    end
    return nil
end

local function FormatRow(label, value, valueColorHex)
    if not value or strtrim(StripColorCodes(value)) == "" then return nil end
    local raw = strtrim(tostring(value))
    if valueColorHex and not string.find(raw, "|c", 1, true) then
        return string.format("|cff9aa0a6%s:|r  |c%s%s|r", label, valueColorHex, raw)
    end
    return string.format("|cff9aa0a6%s:|r  |cffe8eaed%s|r", label, raw)
end

local function BuildCharacteristicsText(data, isSelf)
    local lines = {}
    local basic = {}
    local classHex = (isSelf and ns.GetPlayerClassColorCode and ns:GetPlayerClassColorCode()) or nil
    local eyeHex = (isSelf and ns.profile and NormalizeHex6(ns.profile.eyeColorHex)) or nil
    local eyeColorCode = eyeHex and ("ff" .. eyeHex) or nil

    local function AddBasic(lbl, val, hex)
        local r = FormatRow(lbl, val, hex)
        if r then table.insert(basic, r) end
    end

    AddBasic("Race", data.RA)
    AddBasic("Class", StripColorCodes(data.RC or ""), classHex)
    AddBasic("Gender", data.GN or (isSelf and ns.profile and ns.profile.gender))
    AddBasic("Pronouns", data.PR or (isSelf and ns.profile and ns.profile.pronouns))
    AddBasic("Age", data.AG)
    AddBasic("Height", data.AH)
    AddBasic("Build / Body Shape", data.AW)
    AddBasic("Eye Color", StripColorCodes(data.AE or ""), eyeColorCode)
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
    if isSelf and ns.profile then
        AddExtra("Facial Features", ns.profile.facialFeatures)
        AddExtra("Tattoos / Markings", ns.profile.tattoos)
        AddExtra("Voice Reference", ns.profile.voiceReference)
    end

    if #extra > 0 then
        table.insert(lines, "|cfffdd663ADDITIONAL INFORMATION|r\n" .. table.concat(extra, "\n"))
    end

    if isSelf and ns.profile then
        local styleLines = {}
        if type(ns.profile.rpStyleTopics) == "table" then
            local t = ns.profile.rpStyleTopics
            local function AddStyleRow(lbl, val)
                if val and val ~= "" then
                    table.insert(styleLines, string.format("|cff9aa0a6%s:|r |cffe8eaed%s|r", lbl, val))
                end
            end
            AddStyleRow("Accept character injury", t.injury)
            AddStyleRow("Accept character death", t.death)
            AddStyleRow("Accept character romance", t.romance)
            AddStyleRow("Accept criminal activity", t.criminal)
            AddStyleRow("Accept loss of control", t.lossOfControl)
            if t.guild == "Yes" then
                local wowGuild = (GetGuildInfo and GetGuildInfo("player")) or ""
                AddStyleRow("Guild membership", wowGuild ~= "" and wowGuild or "Yes")
            elseif t.guild and t.guild ~= "" then
                AddStyleRow("Guild membership", t.guild)
            end
        end

        if #styleLines > 0 then
            table.insert(lines, "|cff8ab4f8ROLEPLAY STYLE|r\n" .. table.concat(styleLines, "\n"))
        end

        local oocLines = {}
        local oocRaw = ns.profile.oocNotes or ns.profile.oocInfo
        local oocOnly = CleanOOCDisplayText(oocRaw)
        if oocOnly ~= "" then
            table.insert(oocLines, oocOnly)
        end
        local lgbtqText = (ns.profile.lgbtqFriendly ~= false) and "|cff81c995Yes|r" or "|cff9aa0a6No|r"
        local erpText = ns.profile.erpFriendly and "|cfffdd663Yes|r" or "|cff9aa0a6No|r"
        table.insert(oocLines, "|cff9aa0a6LGBTQIA2S+ friendly:|r " .. lgbtqText)
        table.insert(oocLines, "|cff9aa0a6ERP:|r " .. erpText)
        table.insert(lines, "|cff81c995OTHER INFORMATION (OOC)|r\n" .. table.concat(oocLines, "\n"))
    elseif data.CO and CleanOOCDisplayText(data.CO) ~= "" then
        table.insert(lines, "|cff81c995OTHER INFORMATION (OOC)|r\n" .. CleanOOCDisplayText(data.CO))
    end

    local cuVal = (isSelf and ns.profile and ns.profile.currently) or data.CU
    if cuVal and strtrim(cuVal) ~= "" then
        table.insert(lines, "|cff81c995CURRENTLY|r\n" .. strtrim(cuVal))
    end

    if #lines == 0 then
        return "|cff9aa0a6No characteristics fields listed in this profile yet.|r"
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

local function BuildGlancesStatusText(data, isSelf)
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

    local cuVal = (isSelf and ns.profile and ns.profile.currently) or data.CU
    if cuVal and strtrim(cuVal) ~= "" then
        table.insert(lines, "|cff8ab4f8CURRENTLY|r\n" .. strtrim(cuVal))
    end

    if #lines == 0 then
        return "|cff9aa0a6No First Glances or Currently status listed in this profile.|r"
    end
    return table.concat(lines, "\n\n")
end

function ns:CycleDossierTab(delta)
    if not dossierFrame or not dossierFrame:IsShown() then return end
    if activeSubView == "NOTES" then SaveCurrentNotes() end
    local curIdx = 1
    for i, v in ipairs(SUB_VIEWS) do
        if v == activeSubView then curIdx = i break end
    end
    local nextIdx = ((curIdx - 1 + (delta or 1)) % #SUB_VIEWS) + 1
    activeSubView = SUB_VIEWS[nextIdx]
    ns:RefreshDossierWindow()
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
    local isSelf = IsPlayerSelfKey(key)
    local isLiveTarget = UnitExists("target") and UnitIsPlayer("target") and (ns:GetUnitKey("target") == key)
    local tHex = "ff8ab4f8"
    if isSelf and ns.GetPlayerClassColorCode then
        tHex = ns:GetPlayerClassColorCode()
    elseif isLiveTarget then
        local _, tClass = UnitClass("target")
        tHex = (tClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tClass] and RAID_CLASS_COLORS[tClass].colorStr) or "ffffffff"
    end

    if isLiveTarget then
        dossierFrame.modeBadge:SetText("|cff81c995[LIVE TARGET DOSSIER]|r  |cff9aa0a6(" .. key .. ")|r")
    else
        dossierFrame.modeBadge:SetText("|cff8ab4f8[CACHED PROFILE DOSSIER]|r  |cff9aa0a6(" .. key .. ")|r")
    end

    local data = ns:GetCachedMSP(key)
    local standing, charNote, acctNote, hasNote = ns:GetNoteInfo(key)

    dossierFrame.tabNotes:SetText(hasNote and "Notes |cff81c995*|r" or "Notes")

    local activeIcon = (isSelf and ns.profile and ns.profile.icon) or (data and data.IC)
    if activeIcon and strtrim(tostring(activeIcon)) ~= "" then
        if ns.ResolveIconTexture then
            dossierFrame.portraitTex:SetTexture(ns:ResolveIconTexture(activeIcon, "INV_Helmet_46"))
        else
            local iconPath = string.find(tostring(activeIcon), "\\", 1, true) and tostring(activeIcon) or ("Interface\\Icons\\" .. strtrim(tostring(activeIcon)))
            dossierFrame.portraitTex:SetTexture(iconPath)
        end
    else
        dossierFrame.portraitTex:SetTexture("Interface\\Icons\\INV_Helmet_46")
    end

    if not data or not data.NA then
        local shortName = strsplit("-", key)
        dossierFrame.headerName:SetText("|c" .. tHex .. shortName .. "|r")
        if ns.IsScanPending and ns:IsScanPending(key) then
            dossierFrame.vitalsText:SetText("|cff8ab4f8Scanning LibMSP profile... Waiting for reply...|r")
        else
            dossierFrame.vitalsText:SetText("|cff9aa0a6No RP profile cached yet.|r")
        end
    else
        local displayName = data.NA
        local embeddedHex = type(displayName) == "string" and string.match(displayName, "^|c(%x%x%x%x%x%x%x%x)")
        if embeddedHex and not isSelf then
            tHex = embeddedHex
        end
        displayName = StripColorCodes(displayName)

        if data.PX and strtrim(data.PX) ~= "" and not string.find(displayName, strtrim(data.PX), 1, true) then
            displayName = strtrim(data.PX) .. " " .. displayName
        end
        local titleStr = (data.NT and data.NT ~= "") and ("  |cfffdd663<" .. data.NT .. ">|r") or ""
        dossierFrame.headerName:SetText("|c" .. tHex .. displayName .. "|r" .. titleStr)

        local icBadge = (data.FC == "2") and "|cff81c995[IC]|r" or "|cfff28b82[OOC]|r"
        local wuBadge = ns:GetTargetWalkUpInfo(data)
        local statusBadges = wuBadge and (icBadge .. " " .. wuBadge) or icBadge

        local racePart = strtrim(data.RA or "")
        local rawClass = strtrim(tostring(data.RC or ""))
        local classPart = ""
        if rawClass ~= "" then
            if isSelf and ns.GetPlayerClassColorCode then
                classPart = "|c" .. ns:GetPlayerClassColorCode() .. StripColorCodes(rawClass) .. "|r"
            elseif string.find(rawClass, "|c", 1, true) then
                classPart = rawClass
            else
                classPart = "|cffe8eaed" .. rawClass .. "|r"
            end
        end
        local raceClass = strtrim((racePart ~= "" and ("|cffe8eaed" .. racePart .. "|r ") or "") .. classPart)

        local seenStr = ""
        if data.lastSeen and data.lastSeen > 0 then
            seenStr = "   |cff9aa0a6Seen:|r " .. date("%m/%d %H:%M", data.lastSeen)
        end
        dossierFrame.vitalsText:SetText(string.format("%s   %s%s", statusBadges, raceClass, seenStr))
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
            dossierFrame.scrollText:SetText("|cff9aa0a6No RP profile loaded for this player. Switch to the Notes tab to keep private notes.|r")
        elseif activeSubView == "ABOUT" then
            dossierFrame.scrollText:SetText(BuildAboutText(data))
        elseif activeSubView == "GLANCES" then
            dossierFrame.scrollText:SetText(BuildGlancesStatusText(data, isSelf))
        else
            dossierFrame.scrollText:SetText(BuildCharacteristicsText(data, isSelf))
        end

        local scrollW = dossierFrame.scrollFrame:GetWidth()
        if scrollW and scrollW > 60 then
            dossierFrame.scrollChild:SetWidth(scrollW - 10)
            dossierFrame.scrollText:SetWidth(scrollW - 16)
        end
        local textH = dossierFrame.scrollText:GetStringHeight() or 140
        local viewH = dossierFrame.scrollFrame:GetHeight() or 360
        dossierFrame.scrollChild:SetHeight(math.max(viewH, textH + 28))
        if dossierFrame.scrollFrame.SetVerticalScroll then
            dossierFrame.scrollFrame:SetVerticalScroll(0)
        end

        local sb = dossierFrame.scrollFrame.ScrollBar or _G[dossierFrame.scrollFrame:GetName() .. "ScrollBar"]
        if sb then
            if (textH + 20) > viewH then
                sb:Show()
            else
                sb:Hide()
            end
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
    ns.dossierFrame = dossierFrame
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

    dossierFrame.headerName = dossierFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dossierFrame.headerName:SetPoint("TOPLEFT", 74, -27)
    dossierFrame.headerName:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    dossierFrame.headerName:SetJustifyH("LEFT")
    dossierFrame.headerName:SetWordWrap(false)

    dossierFrame.vitalsText = dossierFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dossierFrame.vitalsText:SetPoint("TOPLEFT", 74, -48)
    dossierFrame.vitalsText:SetPoint("TOPRIGHT", -16, -48)
    dossierFrame.vitalsText:SetJustifyH("LEFT")
    dossierFrame.vitalsText:SetWordWrap(false)

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

    local readerBox = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    readerBox:SetPoint("TOPLEFT", 16, -100)
    readerBox:SetPoint("BOTTOMRIGHT", -16, 16)
    ns:ApplySurface(readerBox, M3.surfaceLow, M3.outline)
    ns:EnableClipping(readerBox)
    dossierFrame.readerBox = readerBox

    local scrollFrame = CreateFrame("ScrollFrame", "PadRP_DossierScrollFrame", readerBox, "UIPanelScrollFrameTemplate")
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

    local notesPanel = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    notesPanel:SetPoint("TOPLEFT", 16, -100)
    notesPanel:SetPoint("BOTTOMRIGHT", -16, 16)
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
        12, -62, 600, 148,
        function() SaveCurrentNotes() end
    )

    local acctLabel = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    acctLabel:SetPoint("TOPLEFT", 12, -220)
    acctLabel:SetText("|cff8ab4f8Account-Wide Notes|r  |cff9aa0a6(Shared across all your characters)|r")

    dossierFrame.acctNoteBox = ns:CreateScrollableTextEditor(
        notesPanel,
        "OOC / Account-wide notes about this player...",
        12, -238, 600, 148,
        function() SaveCurrentNotes() end
    )

    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        ConsolePort:AddInterfaceCursorFrame("PadRP_DossierWindow")
    end
end