local _, ns = ...

local dossierFrame
local selectedDossierKey = nil
local lastRenderedKey = nil
local activeSubView = "CHAR"
local lastRenderedSubView = nil
local SUB_VIEWS = { "CHAR", "ABOUT", "GLANCES", "NOTES" }

local CORE_STANDINGS = {
    { key = "None",       tone = nil,       colorHex = "ff9aa0a6", rgb = nil },
    { key = "Ally",       tone = "MINT",    colorHex = "ff81c995", rgb = { 0.00, 0.92, 0.95 } },
    { key = "Friendly",   tone = "MINT",    colorHex = "ff81c995", rgb = { 0.22, 0.96, 0.45 } },
    { key = "Neutral",    tone = "PRIMARY", colorHex = "ff8ab4f8", rgb = { 0.38, 0.65, 1.00 } },
    { key = "Unfriendly", tone = "CORAL",   colorHex = "fff28b82", rgb = { 1.00, 0.46, 0.08 } },
    { key = "Rival",      tone = "CORAL",   colorHex = "fff28b82", rgb = { 0.98, 0.14, 0.36 } },
    { key = "Marked",     tone = "AMBER",   colorHex = "fffdd663", rgb = { 1.00, 0.82, 0.10 } },
}

local function GetSubViewTabButton(viewName)
    if not dossierFrame then return nil end
    if viewName == "ABOUT" then return dossierFrame.tabAbout end
    if viewName == "GLANCES" then return dossierFrame.tabGlances end
    if viewName == "NOTES" then return dossierFrame.tabNotes end
    return dossierFrame.tabChar
end

local function FocusActiveDossierTab()
    if not dossierFrame or not dossierFrame:IsShown() then return end
    local btn = GetSubViewTabButton(activeSubView)
    if btn and btn:IsVisible() and ns.SetControllerFocus then
        ns:SetControllerFocus(btn)
    end
end

local function IsValidSubView(viewName)
    if type(viewName) ~= "string" then return false end
    local upper = string.upper(strtrim(viewName))
    for _, v in ipairs(SUB_VIEWS) do
        if v == upper then
            return true, upper
        end
    end
    return false
end

local function GetThemeAccentHex()
    return (ns.GetUITheme and ns:GetUITheme() == "NATIVE") and "fff5c73d" or "ff8ab4f8"
end

local function GetStandingAccentRGB(standingName)
    if standingName and standingName ~= "" and standingName ~= "None" then
        for _, item in ipairs(CORE_STANDINGS) do
            if string.lower(item.key) == string.lower(tostring(standingName)) and item.rgb then
                return item.rgb[1], item.rgb[2], item.rgb[3]
            end
        end
        local tone = ns.GetStandingTone and ns:GetStandingTone(standingName)
        if tone == "MINT" then return ns.M3.mint[1], ns.M3.mint[2], ns.M3.mint[3]
        elseif tone == "CORAL" then return ns.M3.coral[1], ns.M3.coral[2], ns.M3.coral[3]
        elseif tone == "AMBER" then return ns.M3.amber[1], ns.M3.amber[2], ns.M3.amber[3]
        end
    end
    return ns.M3.primary[1], ns.M3.primary[2], ns.M3.primary[3]
end

local function GetActiveCharKey()
    if ns.GetPlayerCharKey then
        return ns:GetPlayerCharKey() or "Default"
    end
    local name = (UnitName and UnitName("player")) or "Player"
    local realm = (GetRealmName and GetRealmName()) or "Realm"
    return name .. "-" .. realm
end

local function NormalizeKey(k)
    return string.lower(strtrim(tostring(k or "")))
end

local function StripColorCodes(str)
    if not str then return "" end
    local clean = string.gsub(tostring(str), "|c%x%x%x%x%x%x%x%x", "")
    clean = string.gsub(clean, "|r", "")
    return clean
end

local function ResolveProfileRecordForKey(key)
    if not key or key == "" then return nil end
    if ns.mspCache and type(ns.mspCache) == "table" then
        if type(ns.mspCache[key]) == "table" then
            return ns.mspCache[key]
        end
        local norm = NormalizeKey(key)
        for cacheKey, rec in pairs(ns.mspCache) do
            if type(rec) == "table" and NormalizeKey(cacheKey) == norm then
                return rec
            end
        end
    end
    if ns.GetCachedMSP then
        local ok, rec = pcall(ns.GetCachedMSP, ns, key)
        if ok and type(rec) == "table" then
            return rec
        end
    end
    return nil
end

local function SanitizeStandingsData()
    ns.db = ns.db or {}
    if type(ns.db.customStandings) == "table" then
        local cleaned = {}
        for _, item in ipairs(ns.db.customStandings) do
            local lbl = type(item) == "table" and item.label or item
            local sLbl = lbl and strtrim(tostring(lbl)) or ""
            if sLbl ~= "" and string.lower(sLbl) ~= "fool" then
                local tone = (type(item) == "table" and item.tone) or "AMBER"
                table.insert(cleaned, { label = sLbl, tone = tone })
            end
        end
        ns.db.customStandings = cleaned
    end
    if type(ns.db.notes) == "table" then
        for _, rec in pairs(ns.db.notes) do
            if type(rec) == "table" then
                if rec.standing and string.lower(tostring(rec.standing)) == "fool" then
                    rec.standing = "None"
                end
                if type(rec.charStandings) == "table" then
                    for ck, st in pairs(rec.charStandings) do
                        if st and string.lower(tostring(st)) == "fool" then
                            rec.charStandings[ck] = "None"
                        end
                    end
                end
            end
        end
    end
end

local function GetAllStandingsList()
    SanitizeStandingsData()
    local list = {}
    local seen = {}
    for _, item in ipairs(CORE_STANDINGS) do
        table.insert(list, item.key)
        seen[string.lower(item.key)] = true
    end
    for _, item in ipairs((ns.db and ns.db.customStandings) or {}) do
        local lbl = type(item) == "table" and item.label or item
        if lbl and strtrim(tostring(lbl)) ~= "" then
            local clean = strtrim(tostring(lbl))
            local lk = string.lower(clean)
            if not seen[lk] then
                seen[lk] = true
                table.insert(list, clean)
            end
        end
    end
    return list
end

function ns:GetStandingTone(standingName)
    if not standingName or standingName == "None" then return nil end
    for _, item in ipairs(CORE_STANDINGS) do
        if string.lower(item.key) == string.lower(tostring(standingName)) then
            return item.tone
        end
    end
    for _, item in ipairs((ns.db and ns.db.customStandings) or {}) do
        if type(item) == "table" and string.lower(tostring(item.label or "")) == string.lower(tostring(standingName)) then
            return item.tone or "AMBER"
        end
    end
    return "AMBER"
end

function ns:GetStandingColorHex(standingName)
    if not standingName or standingName == "None" then return "ff9aa0a6" end
    for _, item in ipairs(CORE_STANDINGS) do
        if string.lower(item.key) == string.lower(tostring(standingName)) then
            return item.colorHex or "fffdd663"
        end
    end
    local tone = ns:GetStandingTone(standingName)
    if tone == "MINT" then return "ff81c995"
    elseif tone == "PRIMARY" then return "ff8ab4f8"
    elseif tone == "CORAL" then return "fff28b82"
    end
    return "fffdd663"
end

function ns:AddCustomStanding(label, tone)
    local clean = strtrim(tostring(label or ""))
    if clean == "" or string.lower(clean) == "fool" then return nil end
    ns.db = ns.db or {}
    ns.db.customStandings = ns.db.customStandings or {}
    for _, item in ipairs(ns.db.customStandings) do
        if type(item) == "table" and string.lower(tostring(item.label or "")) == string.lower(clean) then
            if tone then item.tone = tone end
            return clean
        end
    end
    table.insert(ns.db.customStandings, { label = clean, tone = tone or "AMBER" })
    return clean
end

local function EnsureNoteRecord(key)
    SanitizeStandingsData()
    ns.db.notes = ns.db.notes or {}
    local rec = ns.db.notes[key]
    if type(rec) ~= "table" then
        rec = {
            standing = "None",
            charStandings = {},
            accountNote = "",
            charNotes = {},
            charRelationships = {},
            customRelationship = "",
        }
        ns.db.notes[key] = rec
    end
    rec.standing = rec.standing or "None"
    rec.charStandings = rec.charStandings or {}
    rec.charNotes = rec.charNotes or {}
    rec.charRelationships = rec.charRelationships or {}
    rec.customRelationship = rec.customRelationship or ""
    if rec.accountNote == nil then
        rec.accountNote = rec.note or ""
    end
    return rec
end

local function IsNoteRecordEmpty(rec)
    if type(rec) ~= "table" then return true end
    if rec.standing and rec.standing ~= "" and rec.standing ~= "None" then
        return false
    end
    if type(rec.charStandings) == "table" then
        for _, st in pairs(rec.charStandings) do
            if st and st ~= "" and st ~= "None" then
                return false
            end
        end
    end
    if strtrim(tostring(rec.accountNote or "")) ~= "" or strtrim(tostring(rec.note or "")) ~= "" then
        return false
    end
    if strtrim(tostring(rec.customRelationship or "")) ~= "" then
        return false
    end
    if type(rec.charNotes) == "table" then
        for _, v in pairs(rec.charNotes) do
            if strtrim(tostring(v or "")) ~= "" then
                return false
            end
        end
    end
    if type(rec.charRelationships) == "table" then
        for _, v in pairs(rec.charRelationships) do
            if strtrim(tostring(v or "")) ~= "" then
                return false
            end
        end
    end
    return true
end

function ns:GetNoteInfo(key)
    local charKey = GetActiveCharKey()
    local rec = key and ns.db and ns.db.notes and ns.db.notes[key]
    if type(rec) ~= "table" then
        return "None", "", "", false, false, false
    end

    local charStanding = "None"
    if type(rec.charStandings) == "table" and rec.charStandings[charKey] and rec.charStandings[charKey] ~= "" then
        charStanding = rec.charStandings[charKey]
    end

    local charNote = (type(rec.charNotes) == "table" and rec.charNotes[charKey]) or ""
    local acctNote = rec.accountNote
    if acctNote == nil then
        acctNote = rec.note or ""
    end

    local hasCharNote = strtrim(tostring(charNote or "")) ~= ""
    local hasAcctNote = strtrim(tostring(acctNote or "")) ~= ""
    local hasCharStanding = (charStanding ~= nil and charStanding ~= "" and charStanding ~= "None")
    local hasAnyNote = hasCharNote or hasAcctNote

    return charStanding, charNote, acctNote, hasAnyNote, hasAcctNote, hasCharStanding
end

local function SyncNoteWidgetsToKey(key)
    if not dossierFrame then return end
    local _, charNote, acctNote = ns:GetNoteInfo(key)
    local assignedRel = ns:GetAssignedRelationship(key)

    if dossierFrame.relEditBox then
        dossierFrame.relEditBox:SetCleanText(assignedRel)
        dossierFrame.relEditBox.isDirty = false
    end
    if dossierFrame.charNoteBox then
        dossierFrame.charNoteBox:SetCleanText(charNote)
        dossierFrame.charNoteBox.isDirty = false
    end
    if dossierFrame.acctNoteBox then
        dossierFrame.acctNoteBox:SetCleanText(acctNote)
        dossierFrame.acctNoteBox.isDirty = false
    end
end

function ns:GetAssignedRelationship(key)
    if not key or not ns.db or not ns.db.notes then return "" end
    local rec = ns.db.notes[key]
    if type(rec) ~= "table" then return "" end
    local charKey = GetActiveCharKey()
    local cRel = type(rec.charRelationships) == "table" and strtrim(tostring(rec.charRelationships[charKey] or "")) or ""
    if cRel ~= "" then return cRel end
    return strtrim(tostring(rec.customRelationship or ""))
end

local function SaveCurrentNotes()
    if not dossierFrame or not selectedDossierKey then return end
    if dossierFrame._isLoadingNotes then return end
    if activeSubView ~= "NOTES" then return end

    local charDirty = dossierFrame.charNoteBox and dossierFrame.charNoteBox.isDirty
    local acctDirty = dossierFrame.acctNoteBox and dossierFrame.acctNoteBox.isDirty
    local relDirty = dossierFrame.relEditBox and dossierFrame.relEditBox.isDirty
    if not (charDirty or acctDirty or relDirty) then
        return
    end

    local charKey = GetActiveCharKey()
    local charTxt = dossierFrame.charNoteBox:GetText() or ""
    local acctTxt = dossierFrame.acctNoteBox:GetText() or ""
    local relTxt = strtrim(dossierFrame.relEditBox and dossierFrame.relEditBox:GetText() or "")

    local existing = ns.db and ns.db.notes and ns.db.notes[selectedDossierKey]
    if not existing and strtrim(charTxt) == "" and strtrim(acctTxt) == "" and relTxt == "" then
        dossierFrame.charNoteBox.isDirty = false
        dossierFrame.acctNoteBox.isDirty = false
        if dossierFrame.relEditBox then dossierFrame.relEditBox.isDirty = false end
        return
    end

    local rec = EnsureNoteRecord(selectedDossierKey)
    rec.charNotes[charKey] = charTxt
    rec.accountNote = acctTxt
    rec.note = acctTxt
    rec.charRelationships[charKey] = relTxt
    rec.customRelationship = relTxt

    if IsNoteRecordEmpty(rec) then
        ns.db.notes[selectedDossierKey] = nil
    end

    dossierFrame.charNoteBox.isDirty = false
    dossierFrame.acctNoteBox.isDirty = false
    if dossierFrame.relEditBox then
        dossierFrame.relEditBox.isDirty = false
    end

    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshTargetCard then
        ns:RefreshTargetCard()
    end
end

local function ApplyStandingSelection(standingName)
    if not dossierFrame or not selectedDossierKey then return end
    local newStanding = standingName or "None"
    local charKey = GetActiveCharKey()
    local existing = ns.db and ns.db.notes and ns.db.notes[selectedDossierKey]
    if newStanding == "None" and not existing then
        if dossierFrame.standingDropdown then
            dossierFrame.standingDropdown:Hide()
        end
        ns:RefreshDossierWindow()
        return
    end

    local rec = EnsureNoteRecord(selectedDossierKey)
    if rec.standing and rec.standing ~= "None" and next(rec.charStandings) == nil then
        rec.charStandings[charKey] = rec.standing
    end
    rec.standing = "None"
    rec.charStandings[charKey] = newStanding

    if IsNoteRecordEmpty(rec) then
        ns.db.notes[selectedDossierKey] = nil
    end
    if dossierFrame.standingDropdown then
        dossierFrame.standingDropdown:Hide()
    end
    ns:RefreshDossierWindow()
    ns:RefreshTargetHUD()
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshTargetCard then
        ns:RefreshTargetCard()
    end
    if dossierFrame.standingBtn and dossierFrame.standingBtn:IsVisible() and ns.SetControllerFocus then
        ns:SetControllerFocus(dossierFrame.standingBtn)
    end
end

local function IsPlayerSelfKey(key)
    if not key or key == "" then return false end
    local lk = NormalizeKey(key)
    local pName = UnitName("player")
    if pName then
        local shortK = strsplit("-", key)
        if string.lower(strtrim(shortK or "")) == string.lower(pName) then
            return true
        end
    end
    if ns.GetUnitKey then
        local selfKey = ns:GetUnitKey("player")
        if selfKey and NormalizeKey(selfKey) == lk then
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

local function GetRealCharacterName(key, isSelf)
    if isSelf and UnitName then
        local uName = UnitName("player")
        if uName and strtrim(uName) ~= "" then
            return strtrim(uName)
        end
    end
    local base = strsplit("-", tostring(key or ""))
    return strtrim(tostring(base or ""))
end

local function IsSentinelOrInvalidIconID(numId)
    if type(numId) ~= "number" or numId <= 0 then
        return true
    end
    if numId >= 2147483647 then
        return true
    end
    return false
end

local function ResolveDossierIconValue(iconVal)
    if iconVal == nil or iconVal == false then return nil end
    local clean = strtrim(tostring(iconVal))
    local strippedNum = string.match(clean, "^[Ii]nterface[/\\][Ii]cons[/\\](%d+)$")
    if strippedNum then
        clean = strippedNum
    end

    local lower = string.lower(clean)
    if clean == "" or lower == "nil" or lower == "none" or lower == "0" then
        return nil
    end

    local directNum = tonumber(clean)
    if directNum then
        if IsSentinelOrInvalidIconID(directNum) then
            return nil
        end
        return directNum
    end

    if ns.ResolveIconTexture then
        local resolved = ns:ResolveIconTexture(clean, nil)
        if type(resolved) == "number" then
            if IsSentinelOrInvalidIconID(resolved) then
                return nil
            end
            return resolved
        elseif type(resolved) == "string" then
            local rClean = strtrim(resolved)
            local rStripped = string.match(rClean, "^[Ii]nterface[/\\][Ii]cons[/\\](%d+)$")
            if rStripped then rClean = rStripped end
            local rLower = string.lower(rClean)
            if rClean ~= "" and rLower ~= "nil" and rLower ~= "none" and rLower ~= "0" then
                local rNum = tonumber(rClean)
                if rNum then
                    if not IsSentinelOrInvalidIconID(rNum) then
                        return rNum
                    end
                    return nil
                end
                return rClean
            end
        end
    end

    return string.find(clean, "\\", 1, true) and clean or ("Interface\\Icons\\" .. clean)
end

local function ResolveClassFileToken(rawClass, key, isSelf, isLiveTarget)
    if isSelf and UnitClass then
        local _, pClass = UnitClass("player")
        if pClass and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[pClass] then
            return pClass
        end
    end
    if isLiveTarget and UnitClass then
        local _, tClass = UnitClass("target")
        if tClass and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[tClass] then
            return tClass
        end
    end

    local plainClass = strtrim(StripColorCodes(tostring(rawClass or "")))
    local cleaned = string.upper(plainClass)
    if cleaned ~= "" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cleaned] then
        return cleaned
    end

    local nameToToken = {
        ["WARRIOR"]      = "WARRIOR",
        ["PALADIN"]      = "PALADIN",
        ["HUNTER"]       = "HUNTER",
        ["ROGUE"]        = "ROGUE",
        ["PRIEST"]       = "PRIEST",
        ["DEATH KNIGHT"] = "DEATHKNIGHT",
        ["DEATHKNIGHT"]  = "DEATHKNIGHT",
        ["SHAMAN"]       = "SHAMAN",
        ["MAGE"]         = "MAGE",
        ["WARLOCK"]      = "WARLOCK",
        ["MONK"]         = "MONK",
        ["DRUID"]        = "DRUID",
        ["DEMON HUNTER"] = "DEMONHUNTER",
        ["DEMONHUNTER"]  = "DEMONHUNTER",
        ["EVOKER"]       = "EVOKER",
    }

    if type(LOCALIZED_CLASS_NAMES_MALE) == "table" then
        for token, locName in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            if type(locName) == "string" and string.lower(locName) == string.lower(plainClass) then
                nameToToken[string.upper(locName)] = token
            end
        end
    end
    if type(LOCALIZED_CLASS_NAMES_FEMALE) == "table" then
        for token, locName in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            if type(locName) == "string" and string.lower(locName) == string.lower(plainClass) then
                nameToToken[string.upper(locName)] = token
            end
        end
    end

    local mapped = nameToToken[cleaned]
    if mapped and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[mapped] then
        return mapped
    end

    if key and UnitExists and UnitIsPlayer then
        local shortName = strsplit("-", tostring(key))
        if shortName and UnitExists(shortName) and UnitIsPlayer(shortName) and UnitClass then
            local _, uClass = UnitClass(shortName)
            if uClass and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[uClass] then
                return uClass
            end
        end
    end

    return nil
end

local function ReanchorDossierHeader(hasIcon)
    if not dossierFrame or not dossierFrame.headerCard then return end
    local card = dossierFrame.headerCard
    local leftX = hasIcon and 74 or 14

    dossierFrame.modeBadge:ClearAllPoints()
    dossierFrame.modeBadge:SetPoint("TOPLEFT", card, "TOPLEFT", leftX, -9)

    dossierFrame.headerName:ClearAllPoints()
    dossierFrame.headerName:SetPoint("TOPLEFT", card, "TOPLEFT", leftX, -25)
    if dossierFrame.closeBtn then
        dossierFrame.headerName:SetPoint("RIGHT", dossierFrame.closeBtn, "LEFT", -10, 0)
    else
        dossierFrame.headerName:SetPoint("TOPRIGHT", card, "TOPRIGHT", -44, -25)
    end

    dossierFrame.vitalsText:ClearAllPoints()
    dossierFrame.vitalsText:SetPoint("TOPLEFT", card, "TOPLEFT", leftX, -49)
    dossierFrame.vitalsText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -49)
end

local function HideDossierPortrait()
    if not dossierFrame then return end
    if dossierFrame.portraitTex then
        dossierFrame.portraitTex:SetTexture(nil)
        dossierFrame.portraitTex:Hide()
    end
    if dossierFrame.portraitBox then
        dossierFrame.portraitBox:Hide()
    end
    ReanchorDossierHeader(false)
end

local function SetDossierPortraitIcon(iconVal, classToken, hasRPProfile)
    if not dossierFrame or not dossierFrame.portraitBox or not dossierFrame.portraitTex then return end
    dossierFrame.portraitTex:SetTexture(nil)

    local texVal = ResolveDossierIconValue(iconVal)
    if texVal then
        dossierFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ok = pcall(function()
            dossierFrame.portraitTex:SetTexture(texVal)
        end)

        local appliedTex = ok and dossierFrame.portraitTex:GetTexture()
        if appliedTex and appliedTex ~= "" and appliedTex ~= 0 then
            dossierFrame.portraitBox:Show()
            dossierFrame.portraitTex:Show()
            ReanchorDossierHeader(true)
            return
        end
    end

    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        dossierFrame.portraitTex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        dossierFrame.portraitTex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        if dossierFrame.portraitTex:GetTexture() then
            dossierFrame.portraitBox:Show()
            dossierFrame.portraitTex:Show()
            ReanchorDossierHeader(true)
            return
        end
    end

    if hasRPProfile then
        local fallbackIcon = (ns.IconPool and ns.IconPool.defaultFallback) or 134400
        dossierFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ok = pcall(function()
            dossierFrame.portraitTex:SetTexture(fallbackIcon)
        end)
        local appliedTex = ok and dossierFrame.portraitTex:GetTexture()
        if appliedTex and appliedTex ~= "" and appliedTex ~= 0 then
            dossierFrame.portraitBox:Show()
            dossierFrame.portraitTex:Show()
            ReanchorDossierHeader(true)
            return
        end
    end

    HideDossierPortrait()
end

local function CleanOOCDisplayText(raw)
    if not raw then return "" end
    local clean = strtrim(StripColorCodes(raw))
    clean = string.gsub(clean, "%[Walk%-Ups:[^%]]*%]", "")
    clean = string.gsub(clean, "%[Walk%-Ups Welcome%]", "")
    clean = string.gsub(clean, "%[Walk%-Ups: Ask First%]", "")
    clean = string.gsub(clean, "%[No Walk%-Ups%]", "")
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

local function ResolveRelationshipDisplay(rsVal, assignedRel)
    if assignedRel and strtrim(assignedRel) ~= "" then
        return "|cfffdd663" .. strtrim(assignedRel) .. "|r"
    end
    if not rsVal then return nil end
    local s = strtrim(StripColorCodes(tostring(rsVal)))
    if s == "" or s == "0" then return nil end
    if tonumber(s) and ns.GetRelationshipLabel then
        return ns:GetRelationshipLabel(s)
    end
    return s
end

local function BuildCharacteristicsText(data, isSelf, key)
    local accentHex = GetThemeAccentHex()
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

    local assignedRel = (not isSelf and key and ns:GetAssignedRelationship(key)) or ""
    local relText = ResolveRelationshipDisplay(data.RS, assignedRel)
    if relText then
        AddBasic("Relationship", relText)
    end
    if data.FR and data.FR ~= "" and data.FR ~= "0" then
        AddBasic("RP Proficiency", ns:GetRPStyleLabel(data.FR))
    end

    if #basic > 0 then
        table.insert(lines, "|c" .. accentHex .. "BASIC INFORMATION|r\n" .. table.concat(basic, "\n"))
    end

    local extra = {}
    local function AddExtra(lbl, val)
        local r = FormatRow(lbl, val)
        if r then table.insert(extra, r) end
    end
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
                if val and val ~= "" and val ~= "Do not show" then
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
            elseif t.guild and t.guild ~= "" and t.guild ~= "Do not show" then
                AddStyleRow("Guild membership", t.guild)
            end
        end

        if #styleLines > 0 then
            table.insert(lines, "|c" .. accentHex .. "ROLEPLAY STYLE|r\n" .. table.concat(styleLines, "\n"))
        end

        local oocLines = {}
        local oocRaw = ns.profile.oocNotes or ns.profile.oocInfo
        local oocOnly = CleanOOCDisplayText(oocRaw)
        if oocOnly ~= "" then
            table.insert(oocLines, oocOnly)
        end
        local lgbtqText = (ns.profile.lgbtqFriendly ~= false) and "|cff81c995Yes|r" or "|cff9aa0a6No|r"
        local erpText = ns.profile.erpFriendly and "|cfffdd663Yes|r" or "|cff9aa0a6No|r"
        local mdniText = ns.profile.mdni and "|cfff28b82Yes|r" or "|cff9aa0a6No|r"
        table.insert(oocLines, "|cff9aa0a6LGBTQIA2S+ friendly:|r " .. lgbtqText)
        table.insert(oocLines, "|cff9aa0a6ERP:|r " .. erpText)
        table.insert(oocLines, "|cff9aa0a6MDNI:|r " .. mdniText)
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
    local accentHex = GetThemeAccentHex()
    local lines = {}
    if data.DE and strtrim(data.DE) ~= "" then
        table.insert(lines, "|c" .. accentHex .. "PHYSICAL DESCRIPTION & PERSONALITY|r\n" .. data.DE)
    end
    if data.HI and strtrim(data.HI) ~= "" then
        table.insert(lines, "|cfffdd663CHARACTER HISTORY|r\n" .. data.HI)
    end
    if #lines == 0 then
        return "|cff9aa0a6No Physical Description or History written in this profile.|r"
    end
    return table.concat(lines, "\n\n")
end

local function FormatDossierGlanceIconTag(rawIcon)
    local clean = strtrim(tostring(rawIcon or ""))
    local strippedNum = string.match(clean, "^[Ii]nterface[/\\][Ii]cons[/\\](%d+)$")
    if strippedNum then
        clean = strippedNum
    end
    local resolved = ResolveDossierIconValue(clean)
    if type(resolved) == "number" then
        return string.format("|T%.0f:22:22:0:0:64:64:4:60:4:60|t ", resolved)
    elseif type(resolved) == "string" and resolved ~= "" then
        return string.format("|T%s:22:22:0:0:64:64:4:60:4:60|t ", resolved)
    end
    return "|T134400:22:22:0:0:64:64:4:60:4:60|t "
end

local function BuildGlancesStatusText(data, isSelf)
    local accentHex = GetThemeAccentHex()
    local lines = {}
    local gLines = {}

    if isSelf and ns.profile and type(ns.profile.glances) == "table" then
        for idx = 1, math.min(5, #ns.profile.glances) do
            local g = ns.profile.glances[idx]
            if type(g) == "table" then
                local title = strtrim(tostring(g.title or ""))
                local detail = strtrim(tostring(g.detail or g.text or ""))
                if title ~= "" or detail ~= "" then
                    local iconTag = FormatDossierGlanceIconTag(g.icon)
                    if detail ~= "" then
                        table.insert(gLines, string.format("%s|cfffdd663%s|r\n%s", iconTag, title ~= "" and title or ("Glance #" .. idx), detail))
                    else
                        table.insert(gLines, string.format("%s|cfffdd663%s|r", iconTag, title))
                    end
                end
            end
        end
    end

    if #gLines == 0 and data and ns.ParseGlancesStructured then
        local structured = ns:ParseGlancesStructured(data.PE)
        for idx = 1, math.min(5, #structured) do
            local g = structured[idx]
            local iconTag = FormatDossierGlanceIconTag(g.icon)
            if g.detail and g.detail ~= "" then
                table.insert(gLines, string.format("%s|cfffdd663%s|r\n%s", iconTag, g.title, g.detail))
            else
                table.insert(gLines, string.format("%s|cfffdd663%s|r", iconTag, g.title))
            end
        end
    end

    if #gLines > 0 then
        table.insert(lines, "|cfffdd663AT FIRST GLANCE|r\n" .. table.concat(gLines, "\n\n"))
    end

    local cuVal = (isSelf and ns.profile and ns.profile.currently) or (data and data.CU)
    if cuVal and strtrim(cuVal) ~= "" then
        table.insert(lines, "|c" .. accentHex .. "CURRENTLY|r\n" .. strtrim(cuVal))
    end

    if #lines == 0 then
        return "|cff9aa0a6No First Glances or Currently status listed in this profile.|r"
    end
    return table.concat(lines, "\n\n")
end

function ns:CycleDossierTab(delta)
    if not dossierFrame or not dossierFrame:IsShown() then return end
    if activeSubView == "NOTES" then SaveCurrentNotes() end
    if dossierFrame.standingDropdown then dossierFrame.standingDropdown:Hide() end
    local curIdx = 1
    for i, v in ipairs(SUB_VIEWS) do
        if v == activeSubView then curIdx = i break end
    end
    local nextIdx = ((curIdx - 1 + (delta or 1)) % #SUB_VIEWS) + 1
    activeSubView = SUB_VIEWS[nextIdx]
    ns:RefreshDossierWindow()
    FocusActiveDossierTab()
end

function ns:RefreshDossierWindow()
    if not dossierFrame or not dossierFrame:IsShown() then return end

    local accentHex = GetThemeAccentHex()
    if dossierFrame.footerText then
        dossierFrame.footerText:SetText(string.format(
            "|c%s[LB]/[RB] / [D-Pad L/R]|r Tabs   |c%s[D-Pad U/D]|r Scroll   |c%s[A]|r Edit / Select   |c%s[B]|r Close",
            accentHex, accentHex, accentHex, accentHex
        ))
    end

    local key = selectedDossierKey
    if not key and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        key = (ns.GetUnitKey and ns:GetUnitKey("target")) or UnitName("target")
    end
    key = key or ns.lastInspectedKey

    dossierFrame.tabChar:SetTone(activeSubView == "CHAR" and "PRIMARY" or nil)
    dossierFrame.tabAbout:SetTone(activeSubView == "ABOUT" and "PRIMARY" or nil)
    dossierFrame.tabGlances:SetTone(activeSubView == "GLANCES" and "PRIMARY" or nil)
    dossierFrame.tabNotes:SetTone(activeSubView == "NOTES" and "PRIMARY" or nil)

    if not key then
        if dossierFrame.topAccent then
            dossierFrame.topAccent:SetColorTexture(ns.M3.primary[1], ns.M3.primary[2], ns.M3.primary[3], 0.92)
        end
        SetDossierPortraitIcon(nil, nil, false)
        dossierFrame.modeBadge:SetText("|cff9aa0a6[NO PROFILE SELECTED]|r")
        dossierFrame.headerName:SetText("|cff9aa0a6Select a Player from Known RP or Target Someone|r")
        dossierFrame.vitalsText:SetText("")
        dossierFrame.readerBox:Show()
        dossierFrame.notesPanel:Hide()
        dossierFrame.scrollText:SetText("")
        return
    end

    local keyChanged = (key ~= lastRenderedKey)
    local viewChanged = keyChanged or (activeSubView ~= lastRenderedSubView)
    selectedDossierKey = key
    lastRenderedKey = key
    lastRenderedSubView = activeSubView

    if keyChanged then
        dossierFrame._isLoadingNotes = true
        SyncNoteWidgetsToKey(key)
        dossierFrame._isLoadingNotes = false
    end

    local isSelf = IsPlayerSelfKey(key)
    local realCharName = GetRealCharacterName(key, isSelf)
    local isLiveTarget = UnitExists("target") and UnitIsPlayer("target") and ns.GetUnitKey and (ns:GetUnitKey("target") == key)
    local tHex = "ff8ab4f8"
    if isSelf and ns.GetPlayerClassColorCode then
        tHex = ns:GetPlayerClassColorCode()
    elseif isLiveTarget then
        local _, tClass = UnitClass("target")
        tHex = (tClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tClass] and RAID_CLASS_COLORS[tClass].colorStr) or "ffffffff"
    end

    local data = ResolveProfileRecordForKey(key)
    local standing, charNote, acctNote, hasNote = ns:GetNoteInfo(key)
    local assignedRel = ns:GetAssignedRelationship(key)
    local hasRPProfile = (data and data.NA and data.NA ~= "") and true or false

    if dossierFrame.topAccent then
        local ar, ag, ab = GetStandingAccentRGB(standing)
        dossierFrame.topAccent:SetColorTexture(ar, ag, ab, 0.95)
    end

    local topMetaParts = {}
    if isLiveTarget then
        table.insert(topMetaParts, "|cff81c995[LIVE TARGET]|r")
    end
    if standing and standing ~= "None" then
        local sHex = ns:GetStandingColorHex(standing)
        table.insert(topMetaParts, "|c" .. sHex .. "[" .. string.upper(standing) .. "]|r")
    end
    if realCharName ~= "" then
        table.insert(topMetaParts, "|cff9aa0a6(" .. realCharName .. ")|r")
    end
    dossierFrame.modeBadge:SetText(table.concat(topMetaParts, "  "))

    dossierFrame.tabNotes:SetText(hasNote and "Notes |cff81c995*|r" or "Notes")

    local activeIcon = (isSelf and ns.profile and ns.profile.icon) or (data and data.IC)
    local classToken = ResolveClassFileToken(data and data.RC, key, isSelf, isLiveTarget)
    SetDossierPortraitIcon(activeIcon, classToken, hasRPProfile)

    if not data or not data.NA then
        dossierFrame.headerName:SetText("|c" .. tHex .. (realCharName ~= "" and realCharName or key) .. "|r")
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
        local titleStr = (data.NT and data.NT ~= "") and ("   |cfffdd663<" .. data.NT .. ">|r") or ""
        dossierFrame.headerName:SetText("|c" .. tHex .. displayName .. "|r" .. titleStr)

        local icBadge = (data.FC == "2") and "|cff81c995[IC]|r" or "|cfff28b82[OOC]|r"
        local wuBadge = ns:GetTargetWalkUpInfo(data)
        local statusBadges = wuBadge and (icBadge .. "   " .. wuBadge) or icBadge

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
        local raceClass = strtrim((racePart ~= "" and ("|cffe8eaed" .. racePart .. "|r   ") or "") .. classPart)

        local seenStr = ""
        if data.lastSeen and data.lastSeen > 0 then
            seenStr = "     |cff9aa0a6Seen:|r " .. date("%m/%d %H:%M", data.lastSeen)
        end
        local leftMeta = (raceClass ~= "") and (statusBadges .. "     " .. raceClass) or statusBadges
        dossierFrame.vitalsText:SetText(leftMeta .. seenStr)
    end

    if activeSubView == "NOTES" then
        dossierFrame.readerBox:Hide()
        dossierFrame.notesPanel:Show()
        local sHex = ns:GetStandingColorHex(standing)
        dossierFrame.standingBtn:SetText("Standing: |c" .. sHex .. standing .. "|r")
        dossierFrame.standingBtn:SetTone(ns:GetStandingTone(standing))

        local myCharDisplay = (ns.profile and ns.profile.firstName and ns.profile.firstName ~= "") and ns.profile.firstName or (UnitName("player") or "Character")
        if ns.profile and ns.profile.lastName and strtrim(ns.profile.lastName) ~= "" then
            myCharDisplay = myCharDisplay .. " " .. strtrim(ns.profile.lastName)
        end
        dossierFrame.charNoteLabel:SetText("|cff81c995Notes from " .. myCharDisplay .. "|r  |cff9aa0a6(Character-Specific)|r")

        dossierFrame._isLoadingNotes = true
        if dossierFrame.relEditBox and not dossierFrame.relEditBox:HasFocus() and not dossierFrame.relEditBox.isDirty then
            dossierFrame.relEditBox:SetCleanText(assignedRel)
            dossierFrame.relEditBox.isDirty = false
        end
        if not dossierFrame.charNoteBox:HasFocus() and not dossierFrame.charNoteBox.isDirty then
            dossierFrame.charNoteBox:SetCleanText(charNote)
            dossierFrame.charNoteBox.isDirty = false
        end
        if not dossierFrame.acctNoteBox:HasFocus() and not dossierFrame.acctNoteBox.isDirty then
            dossierFrame.acctNoteBox:SetCleanText(acctNote)
            dossierFrame.acctNoteBox.isDirty = false
        end
        dossierFrame._isLoadingNotes = false
    else
        if dossierFrame.standingDropdown then dossierFrame.standingDropdown:Hide() end
        dossierFrame.notesPanel:Hide()
        dossierFrame.readerBox:Show()

        if activeSubView == "GLANCES" then
            dossierFrame.scrollText:SetText(BuildGlancesStatusText(data, isSelf))
        elseif not data or not data.NA then
            dossierFrame.scrollText:SetText("|cff9aa0a6No RP profile loaded for this player. Switch to the Notes tab to keep private notes.|r")
        elseif activeSubView == "ABOUT" then
            dossierFrame.scrollText:SetText(BuildAboutText(data))
        else
            dossierFrame.scrollText:SetText(BuildCharacteristicsText(data, isSelf, key))
        end

        local scrollW = dossierFrame.scrollFrame:GetWidth()
        if scrollW and scrollW > 60 then
            dossierFrame.scrollChild:SetWidth(scrollW - 10)
            dossierFrame.scrollText:SetWidth(scrollW - 16)
        end
        local textH = dossierFrame.scrollText:GetStringHeight() or 140
        local viewH = dossierFrame.scrollFrame:GetHeight() or 360
        dossierFrame.scrollChild:SetHeight(math.max(viewH, textH + 28))
        if viewChanged and dossierFrame.scrollFrame.SetVerticalScroll then
            pcall(dossierFrame.scrollFrame.SetVerticalScroll, dossierFrame.scrollFrame, 0)
        end
        if dossierFrame.scrollFrame.UpdateScrollChildRect then
            pcall(dossierFrame.scrollFrame.UpdateScrollChildRect, dossierFrame.scrollFrame)
        end
    end
end

function ns:OpenTargetDossier(specificKey, initialSubView)
    if not dossierFrame then ns:InitDossierWindow() end

    if dossierFrame:IsShown() and activeSubView == "NOTES" then
        SaveCurrentNotes()
    end

    local shouldScan = false
    if specificKey and specificKey ~= "" then
        selectedDossierKey = specificKey
        local cached = ResolveProfileRecordForKey(selectedDossierKey)
        local isTargetedUnit = UnitExists("target") and UnitIsPlayer("target") and ns.GetUnitKey and (ns:GetUnitKey("target") == selectedDossierKey)
        if isTargetedUnit or not cached or not cached.NA then
            shouldScan = true
        end
    elseif UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        selectedDossierKey = (ns.GetUnitKey and ns:GetUnitKey("target")) or UnitName("target")
        shouldScan = true
    elseif ns.lastInspectedKey then
        selectedDossierKey = ns.lastInspectedKey
        local cached = ResolveProfileRecordForKey(selectedDossierKey)
        if not cached or not cached.NA then
            shouldScan = true
        end
    end

    if shouldScan and selectedDossierKey and ns.RequestUnitMSP then
        ns:RequestUnitMSP(selectedDossierKey, true, true)
    end

    local isValid, normalizedView = IsValidSubView(initialSubView)
    activeSubView = isValid and normalizedView or "CHAR"
    lastRenderedKey = nil
    lastRenderedSubView = nil
    dossierFrame._isLoadingNotes = true
    SyncNoteWidgetsToKey(selectedDossierKey)
    dossierFrame._isLoadingNotes = false

    if dossierFrame.standingDropdown then dossierFrame.standingDropdown:Hide() end
    dossierFrame:SetScale((ns.db and ns.db.ui and ns.db.ui.scale) or 1.0)
    dossierFrame:Show()
    dossierFrame:Raise()
    ns:RefreshDossierWindow()

    if ns.UpdateControllerBindings then
        ns:UpdateControllerBindings()
    end
    if activeSubView == "GLANCES" then
        FocusActiveDossierTab()
    elseif ns.FocusFirstInScope then
        ns:FocusFirstInScope()
    end
end

function ns:InitDossierWindow()
    if dossierFrame then return end
    local M3 = ns.M3

    dossierFrame = CreateFrame("Frame", "PadRP_DossierWindow", UIParent, "BackdropTemplate")
    ns.dossierFrame = dossierFrame
    dossierFrame:SetSize(664, 552)
    dossierFrame:SetPoint("CENTER", UIParent, "CENTER", 40, -10)
    dossierFrame:SetFrameStrata("DIALOG")
    dossierFrame:SetFrameLevel(40)
    dossierFrame:SetMovable(true)
    dossierFrame:EnableMouse(true)
    dossierFrame:RegisterForDrag("LeftButton")
    dossierFrame:SetScript("OnDragStart", dossierFrame.StartMoving)
    dossierFrame:SetScript("OnDragStop", dossierFrame.StopMovingOrSizing)
    dossierFrame:SetScript("OnHide", function()
        if dossierFrame.standingDropdown then
            dossierFrame.standingDropdown:Hide()
        end

        SaveCurrentNotes()

        if ns.UpdateControllerBindings then
            ns:UpdateControllerBindings()
        end
        if ns.FocusFirstInScope then
            ns:FocusFirstInScope()
        end
    end)

    dossierFrame:SetScript("OnShow", function()
        if ns.UpdateControllerBindings then
            ns:UpdateControllerBindings()
        end
    end)
    ns:ApplySurface(dossierFrame, M3.surfaceDim, M3.primary)
    ns:EnableClipping(dossierFrame)
    dossierFrame:Hide()
    tinsert(UISpecialFrames, "PadRP_DossierWindow")

    local topAccent = dossierFrame:CreateTexture(nil, "OVERLAY")
    topAccent:SetHeight(3)
    topAccent:SetPoint("TOPLEFT", 2, -2)
    topAccent:SetPoint("TOPRIGHT", -2, -2)
    topAccent:SetColorTexture(M3.primary[1], M3.primary[2], M3.primary[3], 0.92)
    dossierFrame.topAccent = topAccent

    -- Elevated Profile Header Card
    local headerCard = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    headerCard:SetHeight(72)
    headerCard:SetPoint("TOPLEFT", 14, -12)
    headerCard:SetPoint("TOPRIGHT", -14, -12)
    ns:ApplySurface(headerCard, M3.surfaceLow, M3.outline)
    ns:EnableClipping(headerCard)
    dossierFrame.headerCard = headerCard

    local portraitBox = CreateFrame("Frame", nil, headerCard, "BackdropTemplate")
    portraitBox:SetSize(54, 54)
    portraitBox:SetPoint("LEFT", headerCard, "LEFT", 10, 0)
    ns:ApplySurface(portraitBox, M3.surface, M3.primary)
    dossierFrame.portraitBox = portraitBox
    dossierFrame.portraitTex = portraitBox:CreateTexture(nil, "OVERLAY")
    dossierFrame.portraitTex:SetSize(48, 48)
    dossierFrame.portraitTex:SetPoint("CENTER")
    dossierFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local closeBtn = ns:CreateMaterialButton(headerCard, "X", 28, 28, 0, -8, "CORAL", function()
        dossierFrame:Hide()
    end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", headerCard, "TOPRIGHT", -8, -8)
    closeBtn.label:ClearAllPoints()
    closeBtn.label:SetPoint("CENTER", 0, 0)
    dossierFrame.closeBtn = closeBtn

    dossierFrame.modeBadge = headerCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dossierFrame.headerName = headerCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dossierFrame.headerName:SetJustifyH("LEFT")
    dossierFrame.headerName:SetWordWrap(false)

    dossierFrame.vitalsText = headerCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dossierFrame.vitalsText:SetJustifyH("LEFT")
    dossierFrame.vitalsText:SetWordWrap(false)

    SetDossierPortraitIcon(nil, nil, false)

    local function SwitchSubView(viewName)
        if activeSubView == "NOTES" then SaveCurrentNotes() end
        if dossierFrame.standingDropdown then dossierFrame.standingDropdown:Hide() end
        activeSubView = viewName
        ns:RefreshDossierWindow()
        FocusActiveDossierTab()
    end

    dossierFrame.tabChar = ns:CreateMaterialButton(dossierFrame, "Characteristics", 154, 28, 14, -90, "PRIMARY", function()
        SwitchSubView("CHAR")
    end)
    dossierFrame.tabAbout = ns:CreateMaterialButton(dossierFrame, "About (Bio)", 154, 28, 174, -90, nil, function()
        SwitchSubView("ABOUT")
    end)
    dossierFrame.tabGlances = ns:CreateMaterialButton(dossierFrame, "Glances & Status", 155, 28, 334, -90, nil, function()
        SwitchSubView("GLANCES")
    end)
    dossierFrame.tabNotes = ns:CreateMaterialButton(dossierFrame, "Notes", 155, 28, 495, -90, nil, function()
        SwitchSubView("NOTES")
    end)

    local readerBox = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    readerBox:SetPoint("TOPLEFT", 14, -124)
    readerBox:SetPoint("BOTTOMRIGHT", -14, 40)
    ns:ApplySurface(readerBox, M3.surfaceLow, M3.outline)
    ns:EnableClipping(readerBox)
    dossierFrame.readerBox = readerBox

    local scrollFrame = CreateFrame("ScrollFrame", "PadRP_DossierScrollFrame", readerBox, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -14)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 14)
    scrollFrame:EnableMouseWheel(true)
    ns:EnableClipping(scrollFrame)
    dossierFrame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(580, 180)
    scrollFrame:SetScrollChild(scrollChild)
    dossierFrame.scrollChild = scrollChild

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if not delta or delta == 0 then return end
        local cur = (self.GetVerticalScroll and self:GetVerticalScroll()) or 0
        local maxS = 0
        if self.ScrollBar and self.ScrollBar.GetMinMaxValues then
            local _, sbMax = self.ScrollBar:GetMinMaxValues()
            maxS = tonumber(sbMax) or 0
        else
            local ok, rng = pcall(self.GetVerticalScrollRange, self)
            if ok and type(rng) == "number" then
                maxS = rng
            else
                local childH = (scrollChild and scrollChild:GetHeight()) or 0
                local frameH = (self.GetHeight and self:GetHeight()) or 0
                maxS = math.max(0, childH - frameH)
            end
        end
        local step = (delta > 0) and -56 or 56
        if self.SetVerticalScroll then
            pcall(self.SetVerticalScroll, self, math.max(0, math.min(maxS, cur + step)))
        end
    end)

    dossierFrame.scrollText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dossierFrame.scrollText:SetPoint("TOPLEFT", 0, 0)
    dossierFrame.scrollText:SetWidth(570)
    dossierFrame.scrollText:SetJustifyH("LEFT")
    dossierFrame.scrollText:SetWordWrap(true)
    dossierFrame.scrollText:SetSpacing(4)

    local notesPanel = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    notesPanel:SetPoint("TOPLEFT", 14, -124)
    notesPanel:SetPoint("BOTTOMRIGHT", -14, 40)
    ns:ApplySurface(notesPanel, M3.surfaceLow, M3.outline)
    ns:EnableClipping(notesPanel)
    notesPanel:Hide()
    dossierFrame.notesPanel = notesPanel

    local standingDropdown = CreateFrame("Frame", "PadRP_DossierStandingDropdown", notesPanel, "BackdropTemplate")
    standingDropdown:SetSize(194, 224)
    standingDropdown:SetFrameStrata("DIALOG")
    standingDropdown:SetFrameLevel(notesPanel:GetFrameLevel() + 30)
    ns:ApplySurface(standingDropdown, M3.surfaceDim, M3.primary)
    ns:EnableClipping(standingDropdown)
    standingDropdown:EnableMouse(true)
    standingDropdown:Hide()
    standingDropdown.rows = {}
    dossierFrame.standingDropdown = standingDropdown

    standingDropdown.Rebuild = function(self)
        for _, r in ipairs(self.rows) do
            r:Hide()
        end
        local options = GetAllStandingsList()
        local curStanding = (selectedDossierKey and select(1, ns:GetNoteInfo(selectedDossierKey))) or "None"
        self:SetHeight(#options * 27 + 12)
        for idx, optName in ipairs(options) do
            local btn = self.rows[idx]
            if not btn then
                btn = ns:CreateMaterialButton(self, "", 178, 24, 8, -6 - (idx - 1) * 27, nil, function(b)
                    ApplyStandingSelection(b.standingValue)
                end)
                btn.label:SetJustifyH("LEFT")
                self.rows[idx] = btn
            end
            btn.standingValue = optName
            local isSel = (string.lower(optName) == string.lower(curStanding))
            local sHex = ns:GetStandingColorHex(optName)
            btn:SetText((isSel and "> " or "  ") .. "|c" .. sHex .. optName .. "|r")
            btn:SetTone(ns:GetStandingTone(optName))
            btn:Show()
        end
    end

    dossierFrame.standingBtn = ns:CreateMaterialButton(notesPanel, "Standing: None", 192, 28, 12, -12, nil, function(self)
        if standingDropdown:IsShown() then
            standingDropdown:Hide()
            if ns.SetControllerFocus then ns:SetControllerFocus(self) end
        else
            standingDropdown:ClearAllPoints()
            standingDropdown:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            standingDropdown:Rebuild()
            standingDropdown:Show()
            if ns.FocusFirstInScope then ns:FocusFirstInScope() end
        end
    end)

    dossierFrame.relEditBox = ns:CreateMaterialEditBox(notesPanel, nil, "Optional relation label (e.g., Oath-Kin)...", 214, -12, 410, 28, function()
        SaveCurrentNotes()
    end)

    dossierFrame.charNoteLabel = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dossierFrame.charNoteLabel:SetPoint("TOPLEFT", 12, -50)
    dossierFrame.charNoteLabel:SetText("|cff81c995Notes from " .. (UnitName("player") or "Character") .. "|r  |cff9aa0a6(Character-Specific)|r")

    dossierFrame.charNoteBox = ns:CreateScrollableTextEditor(
        notesPanel,
        "Private RP notes from this character's perspective (e.g., how you met, debts, impressions)...",
        12, -68, 612, 138,
        function() SaveCurrentNotes() end
    )

    local acctLabel = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    acctLabel:SetPoint("TOPLEFT", 12, -218)
    acctLabel:SetText("|cff8ab4f8Account-Wide Notes|r  |cff9aa0a6(Shared across all your characters)|r")

    dossierFrame.acctNoteBox = ns:CreateScrollableTextEditor(
        notesPanel,
        "OOC / Account-wide notes about this player...",
        12, -236, 612, 138,
        function() SaveCurrentNotes() end
    )

    -- Bottom Controller Footer
    local footer = CreateFrame("Frame", nil, dossierFrame, "BackdropTemplate")
    footer:SetHeight(24)
    footer:SetPoint("BOTTOMLEFT", 14, 10)
    footer:SetPoint("BOTTOMRIGHT", -14, 10)
    ns:ApplySurface(footer, M3.surfaceLow, M3.outline)
    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerText:SetPoint("CENTER", 0, 0)
    dossierFrame.footerText = footerText

    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        ConsolePort:AddInterfaceCursorFrame("PadRP_DossierWindow")
    end
end