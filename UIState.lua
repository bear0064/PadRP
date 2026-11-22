local _, ns = ...

ns.UI = ns.UI or {}
local UI = ns.UI

UI.activeTab = UI.activeTab or 1
UI.tabButtons = UI.tabButtons or {}
UI.tabPanels = UI.tabPanels or {}
UI.tabs = UI.tabs or {}

UI.activeIdentityPage = UI.activeIdentityPage or 1
UI.activeBioMode = UI.activeBioMode or "APPEARANCE"
UI.knownListPage = UI.knownListPage or 1
UI.knownSearchFilter = UI.knownSearchFilter or ""
UI.knownNotableOnly = UI.knownNotableOnly or false
UI.knownSortMode = UI.knownSortMode or "RECENT"
UI.collapsedBuckets = UI.collapsedBuckets or {}
UI.profileListPage = UI.profileListPage or 1

UI.editPoolIdx = UI.editPoolIdx or 1
UI.editPhraseIdx = UI.editPhraseIdx or 1
UI.phrasePage = UI.phrasePage or 1

UI.confirmDeleteProfileUntil = UI.confirmDeleteProfileUntil or 0
UI.confirmClearBioUntil = UI.confirmClearBioUntil or 0
UI.confirmClearCacheUntil = UI.confirmClearCacheUntil or 0
UI.lastEditFocusTime = UI.lastEditFocusTime or 0
UI.lastConfirmTime = UI.lastConfirmTime or 0
UI.lastConfirmTarget = UI.lastConfirmTarget or nil
UI.lastPickerApplyTime = UI.lastPickerApplyTime or 0
UI.pickerReopenGuardUntil = UI.pickerReopenGuardUntil or 0

UI.SIDEBAR_WIDTH = 132

UI.RP_EXPERIENCE_LIST = {
    { code = "1", label = "Normal" },
    { code = "2", label = "Casual" },
    { code = "3", label = "Experienced" },
    { code = "4", label = "Roleplay-Focused / Veteran" },
    { code = "5", label = "New" },
}

UI.TOPIC_CONSENT_OPTIONS = {
    "With player permission",
    "Yes",
    "No",
    "Do not show",
}

UI.RP_STYLE_TOPICS = {
    { key = "injury",        label = "Accept character injury",   defaultVal = "With player permission" },
    { key = "death",         label = "Accept character death",    defaultVal = "No" },
    { key = "romance",       label = "Accept character romance",  defaultVal = "Do not show" },
    { key = "criminal",      label = "Accept criminal activity",  defaultVal = "Yes" },
    { key = "lossOfControl", label = "Accept loss of control",    defaultVal = "No" },
    { key = "guild",         label = "Guild membership",          defaultVal = "Do not show" },
}

UI.MODE_LIST = {
    { key = "DEFAULT_NO_WHISPER", label = "Default (No Whisper: Pool Emote / /thank)" },
    { key = "DO_EMOTE",           label = "Blizzard Voice Emote (/thank)" },
    { key = "MANUAL",             label = "Manual Only (Quick-Thank Controller Bind)" },
    { key = "WHISPER",            label = "Opt-In Whisper (/w)" },
    { key = "OFF",                label = "Disabled (Off)" },
}

UI.POOL_LIST = {
    { key = "IC",      label = "1. In-Character: Buffs & Heals (IC)" },
    { key = "OOC",     label = "2. Out-of-Character: Buffs & Heals (OOC)" },
    { key = "RES",     label = "3. Resurrections (Combat & Spirit Res)" },
    { key = "SUMMON",  label = "4. Warlock Summons & Soulstones" },
    { key = "SPECIAL", label = "5. Portals, Healthstones & Major Cooldowns" },
}

UI.BASE_STANDING_BUCKETS = {
    { key = "Ally",       label = "Ally",       colorHex = "ff81c995", tone = "MINT" },
    { key = "Friendly",   label = "Friendly",   colorHex = "ff81c995", tone = "MINT" },
    { key = "Neutral",    label = "Neutral",    colorHex = "ff8ab4f8", tone = "PRIMARY" },
    { key = "Unfriendly", label = "Unfriendly", colorHex = "fff28b82", tone = "CORAL" },
    { key = "Rival",      label = "Rival",      colorHex = "fff28b82", tone = "CORAL" },
    { key = "Marked",     label = "Marked",     colorHex = "fffdd663", tone = "AMBER" },
}

function UI:GetDefaultIconFallback()
    return (ns.IconPool and ns.IconPool.defaultFallback) or 134400
end

function UI:GetStandingBuckets()
    local buckets = {}
    local seen = {}
    for _, b in ipairs(UI.BASE_STANDING_BUCKETS) do
        table.insert(buckets, b)
        seen[string.lower(b.key)] = true
    end
    for _, item in ipairs((ns.db and ns.db.customStandings) or {}) do
        local lbl = type(item) == "table" and item.label or item
        if lbl and strtrim(tostring(lbl)) ~= "" then
            local clean = strtrim(tostring(lbl))
            local lk = string.lower(clean)
            if not seen[lk] and lk ~= "fool" then
                seen[lk] = true
                local tone = (type(item) == "table" and item.tone) or "AMBER"
                local hex = "fffdd663"
                if tone == "MINT" then hex = "ff81c995"
                elseif tone == "PRIMARY" then hex = "ff8ab4f8"
                elseif tone == "CORAL" then hex = "fff28b82"
                end
                table.insert(buckets, { key = clean, label = clean, colorHex = hex, tone = tone })
            end
        end
    end
    table.insert(buckets, { key = "Other", label = "Other", colorHex = "ff9aa0a6", tone = nil })
    return buckets
end

function UI:FormatCheckbox(label, isChecked, activeColorHex)
    local box = isChecked and ("|c" .. (activeColorHex or "ff81c995") .. "[X]|r ") or "|cff9aa0a6[ ]|r "
    return box .. label
end

function UI:NormalizeIconInput(icon)
    if icon == nil or icon == false then return nil end
    local clean = strtrim(tostring(icon))
    if clean == "" then return nil end
    local num = tonumber(clean)
    if num and num > 0 then
        return num
    end
    if string.find(clean, "\\", 1, true) or string.find(clean, "/", 1, true) then
        return clean
    end
    return "Interface\\Icons\\" .. clean
end

function UI:UnpackIconEntry(entry)
    if type(entry) == "table" then
        local id = tonumber(entry[1])
        local name = entry[2] and strtrim(tostring(entry[2])) or ""
        local displayVal = (name ~= "" and name) or tostring(id or "")
        return id, name, displayVal, entry
    end
    local raw = tostring(entry or "")
    local numId = tonumber(raw)
    return numId, raw, raw, entry
end

function UI:SetIconTextureSafe(tex, icon, fallback)
    if not tex then return end
    local fbDefault = fallback or UI:GetDefaultIconFallback()
    local target = nil
    if ns.IconPool and ns.IconPool.ResolveTexture then
        target = ns.IconPool:ResolveTexture(icon, fbDefault)
    else
        target = UI:NormalizeIconInput(icon) or UI:NormalizeIconInput(fbDefault) or 134400
        if ns.ResolveIconTexture and type(icon) == "string" and strtrim(icon) ~= "" and not tonumber(strtrim(icon)) then
            local resolved = ns:ResolveIconTexture(strtrim(icon), nil)
            if type(resolved) == "number" and resolved > 0 then
                target = resolved
            elseif type(resolved) == "string" and strtrim(resolved) ~= "" then
                target = strtrim(resolved)
            end
        end
    end
    tex:SetTexture(nil)
    pcall(function() tex:SetTexture(target) end)
    if not tex:GetTexture() then
        local fb = (ns.IconPool and ns.IconPool.ResolveTexture and ns.IconPool:ResolveTexture(fbDefault, 134400))
            or UI:NormalizeIconInput(fbDefault)
            or 134400
        pcall(function() tex:SetTexture(fb) end)
    end
end

function UI:FormatPickerIconReadout(prefix, iconVal, knownID, texObj)
    local labelStr = tostring(iconVal or "")
    local idStr = knownID and tostring(knownID) or nil
    local appliedTex = texObj and texObj:GetTexture()
    if not idStr and appliedTex and tostring(appliedTex) ~= labelStr then
        idStr = tostring(appliedTex)
    end
    if idStr and idStr ~= labelStr then
        return string.format("|cff8ab4f8%s|r |cffe8eaed%s|r  |cfffdd663(ID: %s)|r", prefix, labelStr, idStr)
    end
    return string.format("|cff8ab4f8%s|r |cffe8eaed%s|r", prefix, labelStr)
end

function UI:EnsureTopicConsentTable()
    if not ns.profile then return {} end
    if type(ns.profile.rpStyleTopics) ~= "table" then
        ns.profile.rpStyleTopics = {}
    end
    for _, t in ipairs(UI.RP_STYLE_TOPICS) do
        if not ns.profile.rpStyleTopics[t.key] then
            ns.profile.rpStyleTopics[t.key] = t.defaultVal
        end
    end
    if ns.profile.lgbtqFriendly == nil then ns.profile.lgbtqFriendly = true end
    if ns.profile.erpFriendly == nil then ns.profile.erpFriendly = false end
    if ns.profile.mdni == nil then ns.profile.mdni = false end
    return ns.profile.rpStyleTopics
end

function UI:GetTopicConsentValue(topicKey, fallback)
    local tbl = UI:EnsureTopicConsentTable()
    return tbl[topicKey] or fallback or "With player permission"
end

function UI:CycleTopicConsent(topicKey, defaultVal)
    local tbl = UI:EnsureTopicConsentTable()
    local cur = tbl[topicKey] or defaultVal
    local nextIdx = 1
    for i, opt in ipairs(UI.TOPIC_CONSENT_OPTIONS) do
        if opt == cur then
            nextIdx = (i % #UI.TOPIC_CONSENT_OPTIONS) + 1
            break
        end
    end
    tbl[topicKey] = UI.TOPIC_CONSENT_OPTIONS[nextIdx]
    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
    if ns.SyncMSP then ns:SyncMSP() end
    return tbl[topicKey]
end

function UI:FormatTopicButtonText(topicLabel, val)
    local colorHex = "ff8ab4f8"
    if val == "Yes" then
        colorHex = "ff81c995"
    elseif val == "No" then
        colorHex = "fff28b82"
    elseif val == "Do not show" then
        colorHex = "ff9aa0a6"
    else
        colorHex = "fffdd663"
    end
    return string.format("%s: |c%s%s|r", topicLabel, colorHex, val)
end

function UI:NormalizeHex6(raw)
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

function UI:HexToRGB(hex6)
    local h = UI:NormalizeHex6(hex6) or "8ab4f8"
    local r = tonumber(string.sub(h, 1, 2), 16) / 255
    local g = tonumber(string.sub(h, 3, 4), 16) / 255
    local b = tonumber(string.sub(h, 5, 6), 16) / 255
    return r, g, b
end

function UI:RGBToHex6(r, g, b)
    local function ClampByte(v)
        v = math.max(0, math.min(1, tonumber(v) or 0))
        return math.floor(v * 255 + 0.5)
    end
    return string.format("%02x%02x%02x", ClampByte(r), ClampByte(g), ClampByte(b))
end

function UI:GetWoWClassHex6()
    local _, classFile = UnitClass("player")
    local classStr = (classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] and RAID_CLASS_COLORS[classFile].colorStr) or "ffffffff"
    return UI:NormalizeHex6(classStr) or "ffffff"
end

function UI:GetPlayerActiveClassColorHex()
    local custom = UI:NormalizeHex6(ns.profile and (ns.profile.classColorHex or ns.profile.nameColorHex))
    if custom then
        return "ff" .. custom
    end
    return "ff" .. UI:GetWoWClassHex6()
end

function ns:GetPlayerClassColorCode()
    return UI:GetPlayerActiveClassColorHex()
end

function ns:GetPlayerNameColorCode()
    return UI:GetPlayerActiveClassColorHex()
end

function UI:StripColorCodes(str)
    if not str then return "" end
    local clean = string.gsub(tostring(str), "|c%x%x%x%x%x%x%x%x", "")
    clean = string.gsub(clean, "|r", "")
    return clean
end

function UI:TruncText(str, maxLen)
    str = strtrim(tostring(str or ""))
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

function UI:IsPlayerSelfKey(k)
    if not k or k == "" then return false end
    local lk = string.lower(strtrim(tostring(k)))
    local pName = UnitName("player")
    if pName then
        local shortK = strsplit("-", k)
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

local function BuildSelfFullName()
    local p = ns.profile
    if not p then return UnitName("player") or "" end
    local parts = {}
    local baseFirst = (p.firstName and strtrim(p.firstName) ~= "") and strtrim(p.firstName) or (UnitName("player") or "")
    if baseFirst ~= "" then table.insert(parts, baseFirst) end
    if p.lastName and strtrim(p.lastName) ~= "" then table.insert(parts, strtrim(p.lastName)) end
    return table.concat(parts, " ")
end

function UI:SyncSelfProfileToLocalCache()
    if not ns.profile then return end
    ns.mspCache = ns.mspCache or {}
    local p = ns.profile
    local custom = UI:NormalizeHex6(p.classColorHex or p.nameColorHex)
    local eyeHex = UI:NormalizeHex6(p.eyeColorHex)
    local cuText = tostring(p.currently or "")
    local fullName = BuildSelfFullName()
    local matchedAny = false

    local eyeFormatted = p.eyeColor or ""
    if strtrim(UI:StripColorCodes(eyeFormatted)) ~= "" and eyeHex then
        eyeFormatted = "|cff" .. eyeHex .. strtrim(UI:StripColorCodes(eyeFormatted)) .. "|r"
    end

    for k, rec in pairs(ns.mspCache) do
        if type(rec) == "table" and UI:IsPlayerSelfKey(k) then
            matchedAny = true
            rec.CU = cuText
            if p.title and p.title ~= "" then rec.NT = p.title end
            if p.houseName and p.houseName ~= "" then rec.NH = p.houseName end
            if p.race and p.race ~= "" then rec.RA = p.race end
            if p.gender and p.gender ~= "" then rec.GN = p.gender end
            if eyeFormatted ~= "" then rec.AE = eyeFormatted end
            rec.FC = p.isIC and "2" or "1"
            if rec.RC and strtrim(UI:StripColorCodes(rec.RC)) ~= "" then
                local plainRC = UI:StripColorCodes(rec.RC)
                rec.RC = custom and ("|cff" .. custom .. plainRC .. "|r") or plainRC
            elseif p.class and strtrim(p.class) ~= "" then
                rec.RC = custom and ("|cff" .. custom .. strtrim(p.class) .. "|r") or strtrim(p.class)
            end
            if fullName ~= "" then
                rec.NA = custom and ("|cff" .. custom .. fullName .. "|r") or fullName
            end
            rec.lastSeen = (time and time()) or rec.lastSeen or 0
        end
    end

    if not matchedAny and fullName ~= "" then
        local selfKey = (ns.GetUnitKey and ns:GetUnitKey("player")) or fullName
        ns.mspCache[selfKey] = {
            NA = custom and ("|cff" .. custom .. fullName .. "|r") or fullName,
            NT = p.title or "",
            NH = p.houseName or "",
            RA = p.race or "",
            GN = p.gender or "",
            AE = eyeFormatted,
            RC = (p.class and strtrim(p.class) ~= "") and (custom and ("|cff" .. custom .. strtrim(p.class) .. "|r") or strtrim(p.class)) or "",
            CU = cuText,
            FC = p.isIC and "2" or "1",
            lastSeen = (time and time()) or 0,
        }
    end

    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.RefreshDossierWindow then ns:RefreshDossierWindow() end
    if ns.RefreshTargetCard then ns:RefreshTargetCard() end
end

function UI:ApplySwatchVisual(swatch, hex6, isFocused)
    if not swatch or not ns.M3 then return end
    local M3 = ns.M3
    if hex6 then
        local r, g, b = UI:HexToRGB(hex6)
        swatch:SetBackdropColor(r, g, b, 1)
        swatch:SetBackdropBorderColor(isFocused and 0.54 or 1, isFocused and 0.71 or 1, isFocused and 0.97 or 1, 1)
        if swatch.fillTex then
            swatch.fillTex:SetColorTexture(r, g, b, 1)
            swatch.fillTex:Show()
        end
    else
        swatch:SetBackdropColor(unpack(M3.surfaceHigh))
        if isFocused then
            swatch:SetBackdropBorderColor(unpack(M3.primary))
        else
            swatch:SetBackdropBorderColor(unpack(M3.outline))
        end
        if swatch.fillTex then
            swatch.fillTex:Hide()
        end
    end
end

function UI:RefreshEyeSwatchBox()
    local p1 = UI.tabPanels[1]
    local swatch = p1 and p1.eyeSwatchBtn
    if not swatch then return end
    local eyeHex = UI:NormalizeHex6((ns.profile and ns.profile.eyeColorHex) or (ns.profile and ns.profile.eyeColor))
    swatch.activeHex6 = eyeHex
    UI:ApplySwatchVisual(swatch, eyeHex, ns.currentFocus == swatch)
    if p1.eyBox and p1.eyBox.SetTextColor then
        if eyeHex then
            local r, g, b = UI:HexToRGB(eyeHex)
            p1.eyBox:SetTextColor(r, g, b, 1)
        else
            p1.eyBox:SetTextColor(0.91, 0.92, 0.93, 1)
        end
    end
end

function UI:RefreshClassSwatchBox()
    local p1 = UI.tabPanels[1]
    local swatch = p1 and p1.classSwatchBtn
    if not swatch then return end
    local hex6 = UI:NormalizeHex6(ns.profile and (ns.profile.classColorHex or ns.profile.nameColorHex)) or UI:GetWoWClassHex6()
    swatch.activeHex6 = hex6
    UI:ApplySwatchVisual(swatch, hex6, ns.currentFocus == swatch)
    if p1.clBox and p1.clBox.SetTextColor then
        local r, g, b = UI:HexToRGB(hex6)
        p1.clBox:SetTextColor(r, g, b, 1)
    end
end

function UI:AttachWheelScroller(frame, onWheelStep)
    if not frame or not frame.EnableMouseWheel then return end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta and delta ~= 0 and onWheelStep then
            onWheelStep(delta > 0 and -1 or 1)
        end
    end)
end

function UI:GetRPExperienceLabelText(code)
    local c = tostring(code or (ns.profile and ns.profile.rpStyle) or "1")
    for _, item in ipairs(UI.RP_EXPERIENCE_LIST) do
        if item.code == c then
            return item.label
        end
    end
    if ns.GetRPStyleLabel then
        return ns:GetRPStyleLabel(c)
    end
    return "Normal"
end

function UI:ApplyRPExperienceSelection(code)
    if not ns.profile then return end
    ns.profile.rpStyle = tostring(code or "1")
    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
    if ns.SyncMSP then ns:SyncMSP() end
    if UI.mainFrame and UI.mainFrame.bannerExpBtn then
        UI.mainFrame.bannerExpBtn:SetText("|cff8ab4f8RP:|r " .. UI:GetRPExperienceLabelText(ns.profile.rpStyle) .. " [v]")
    end
    local p1 = UI.tabPanels[1]
    if p1 and p1.styleBtn then
        p1.styleBtn:SetText("RP Style: |cff8ab4f8" .. UI:GetRPExperienceLabelText(ns.profile.rpStyle) .. "|r")
    end
    ns:ShowStatusToast("RP Experience: " .. UI:GetRPExperienceLabelText(ns.profile.rpStyle))
end

function UI:LayoutRow(parent, y, items, padLeft, padRight, gap)
    if not parent then return end
    local parentW = parent:GetWidth()
    if not parentW or parentW < 180 then return end

    padLeft = padLeft or 16
    padRight = padRight or padLeft
    gap = gap or 8

    local totalFixed = 0
    local totalWeight = 0
    local lastFlexIdx = nil

    for idx, item in ipairs(items) do
        if item.fixed then
            totalFixed = totalFixed + item.fixed
        else
            local w = item.weight or 1
            totalWeight = totalWeight + w
            lastFlexIdx = idx
        end
    end

    local availW = parentW - padLeft - padRight - (gap * math.max(0, #items - 1))
    local flexPool = math.max(40, availW - totalFixed)
    local curX = padLeft
    local usedFlex = 0

    for idx, item in ipairs(items) do
        local colW
        if item.fixed then
            colW = item.fixed
        elseif idx == lastFlexIdx then
            colW = math.max(40, flexPool - usedFlex)
        else
            colW = math.max(40, math.floor(flexPool * ((item.weight or 1) / totalWeight)))
            usedFlex = usedFlex + colW
        end

        local widget = item.w
        if widget then
            widget:ClearAllPoints()
            local yOffset = item.yOffset or 0
            widget:SetPoint("TOPLEFT", parent, "TOPLEFT", curX, y + yOffset)
            widget:SetWidth(colW)
            if widget.fieldLabel then
                widget.fieldLabel:SetWidth(colW)
            end
        end
        curX = curX + colW + gap
    end
end

function UI:CommitModifiedBoxesToProfile(forceAll)
    if not ns.profile or not UI.mainFrame then return false end
    local p = ns.profile
    UI:EnsureTopicConsentTable()
    local changed = false
    local p1 = UI.tabPanels[1]
    if p1 and p1.fnBox then
        local function CheckBox(box, key)
            if box and (forceAll or box.isDirty) then
                p[key] = box:GetText()
                box.isDirty = false
                changed = true
            end
        end
        CheckBox(p1.pxBox, "titlePrefix")
        CheckBox(p1.fnBox, "firstName")
        CheckBox(p1.lnBox, "lastName")
        CheckBox(p1.tiBox, "title")
        CheckBox(p1.raBox, "race")
        CheckBox(p1.clBox, "class")
        CheckBox(p1.gnBox, "gender")
        CheckBox(p1.prBox, "pronouns")
        CheckBox(p1.agBox, "age")
        CheckBox(p1.htBox, "height")
        CheckBox(p1.wtBox, "weight")
        CheckBox(p1.eyBox, "eyeColor")
        CheckBox(p1.cuBox, "currently")
        CheckBox(p1.oocNotesBox, "oocNotes")

        CheckBox(p1.hoBox, "houseName")
        CheckBox(p1.moBox, "motto")
        CheckBox(p1.hbBox, "birthplace")
        CheckBox(p1.hhBox, "residence")
        CheckBox(p1.faceBox, "facialFeatures")
        CheckBox(p1.tatBox, "tattoos")
        CheckBox(p1.voiceBox, "voiceReference")
    end

    local pProf = UI.tabPanels[5]
    if pProf and pProf.profNameBox and (forceAll or pProf.profNameBox.isDirty) then
        local pName = strtrim(pProf.profNameBox:GetText() or "")
        if pName ~= "" then p.profileName = pName end
        pProf.profNameBox.isDirty = false
        changed = true
    end

    local p2 = UI.tabPanels[2]
    if p2 and p2.cards then
        for slot = 1, 5 do
            local card = p2.cards[slot]
            if card and p.glances[slot] then
                if forceAll or card.titleBox.isDirty then
                    p.glances[slot].title = card.titleBox:GetText()
                    card.titleBox.isDirty = false
                    changed = true
                end
                if forceAll or card.detailBox.isDirty then
                    p.glances[slot].detail = card.detailBox:GetText()
                    card.detailBox.isDirty = false
                    changed = true
                end
            end
        end
    end

    local p3 = UI.tabPanels[3]
    if p3 and p3.bioEditor and (forceAll or p3.bioEditor.isDirty) then
        local text = p3.bioEditor:GetText()
        if UI.activeBioMode == "APPEARANCE" then p.description = text else p.history = text end
        p3.bioEditor.isDirty = false
        changed = true
    end

    if changed then
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        UI:SyncSelfProfileToLocalCache()
    end
    return changed
end

function ns:LoadProfileIntoUI()
    if not UI.mainFrame or not ns.profile then return end
    local p = ns.profile
    UI:EnsureTopicConsentTable()
    local p1 = UI.tabPanels[1]
    if p1 and p1.fnBox then
        p1.pxBox:SetCleanText(p.titlePrefix)
        p1.fnBox:SetCleanText(p.firstName)
        p1.lnBox:SetCleanText(p.lastName)
        p1.tiBox:SetCleanText(p.title)
        p1.raBox:SetCleanText(p.race)
        p1.clBox:SetCleanText(p.class)
        p1.gnBox:SetCleanText(p.gender)
        p1.prBox:SetCleanText(p.pronouns)
        p1.agBox:SetCleanText(p.age)
        p1.htBox:SetCleanText(p.height)
        p1.wtBox:SetCleanText(p.weight)
        p1.eyBox:SetCleanText(p.eyeColor)
        p1.cuBox:SetCleanText(p.currently)
        p1.oocNotesBox:SetCleanText(p.oocNotes or p.oocInfo)

        p1.hoBox:SetCleanText(p.houseName)
        p1.moBox:SetCleanText(p.motto)
        p1.hbBox:SetCleanText(p.birthplace)
        p1.hhBox:SetCleanText(p.residence)
        p1.faceBox:SetCleanText(p.facialFeatures)
        p1.tatBox:SetCleanText(p.tattoos)
        p1.voiceBox:SetCleanText(p.voiceReference)
    end
    if UI.tabPanels[5] and UI.tabPanels[5].profNameBox then
        UI.tabPanels[5].profNameBox:SetCleanText(p.profileName)
    end
    UI:RefreshEyeSwatchBox()
    UI:RefreshClassSwatchBox()
    if UI.LoadAllGlancesIntoUI then UI:LoadAllGlancesIntoUI() end
    local p3 = UI.tabPanels[3]
    if p3 and p3.bioEditor then
        p3.bioEditor:SetCleanText(UI.activeBioMode == "APPEARANCE" and p.description or p.history)
    end
end

function ns:ShowStatusToast(msg)
    if not UI.mainFrame or not UI.mainFrame.statusToast then return end
    UI.mainFrame.statusToast:SetText("|cff81c995" .. (msg or "Saved") .. "|r")
    if C_Timer and C_Timer.After then
        C_Timer.After(3.5, function()
            if UI.mainFrame and UI.mainFrame.statusToast then
                UI.mainFrame.statusToast:SetText("|cff9aa0a6Saved in PadRPDB|r")
            end
        end)
    end
end