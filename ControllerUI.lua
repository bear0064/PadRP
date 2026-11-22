local _, ns = ...

local mainFrame
local inspectorFrame
local activeTab = 1
local tabButtons = {}
local tabPanels = {}

local activeIdentityPage = 1
local activeBioMode = "APPEARANCE"
local knownListPage = 1
local knownSearchFilter = ""
local knownNotableOnly = false
local knownSortMode = "RECENT"
local collapsedBuckets = {}
local profileListPage = 1

local editPoolIdx = 1
local editPhraseIdx = 1
local phrasePage = 1

local confirmDeleteProfileUntil = 0
local confirmClearBioUntil = 0
local confirmClearCacheUntil = 0
local lastEditFocusTime = 0
local lastConfirmTime = 0
local lastConfirmTarget = nil
local lastPickerApplyTime = 0
local pickerReopenGuardUntil = 0

local RP_EXPERIENCE_LIST = {
    { code = "1", label = "Normal" },
    { code = "2", label = "Casual" },
    { code = "3", label = "Experienced" },
    { code = "4", label = "Roleplay-Focused / Veteran" },
    { code = "5", label = "New" },
}

local TOPIC_CONSENT_OPTIONS = {
    "With player permission",
    "Yes",
    "No",
    "Do not show",
}

local RP_STYLE_TOPICS = {
    { key = "injury",        label = "Accept character injury",   defaultVal = "With player permission" },
    { key = "death",         label = "Accept character death",    defaultVal = "No" },
    { key = "romance",       label = "Accept character romance",  defaultVal = "Do not show" },
    { key = "criminal",      label = "Accept criminal activity",  defaultVal = "Yes" },
    { key = "lossOfControl", label = "Accept loss of control",    defaultVal = "No" },
    { key = "guild",         label = "Guild membership",          defaultVal = "Do not show" },
}

local MODE_LIST = {
    { key = "DEFAULT_NO_WHISPER", label = "Default (No Whisper: Pool Emote / /thank)" },
    { key = "DO_EMOTE",           label = "Blizzard Voice Emote (/thank)" },
    { key = "MANUAL",             label = "Manual Only (Quick-Thank Controller Bind)" },
    { key = "WHISPER",            label = "Opt-In Whisper (/w)" },
    { key = "OFF",                label = "Disabled (Off)" },
}

local POOL_LIST = {
    { key = "IC",      label = "1. In-Character: Buffs & Heals (IC)" },
    { key = "OOC",     label = "2. Out-of-Character: Buffs & Heals (OOC)" },
    { key = "RES",     label = "3. Resurrections (Combat & Spirit Res)" },
    { key = "SUMMON",  label = "4. Warlock Summons & Soulstones" },
    { key = "SPECIAL", label = "5. Portals, Healthstones & Major Cooldowns" },
}

local BASE_STANDING_BUCKETS = {
    { key = "Ally",       label = "Ally",       colorHex = "ff81c995", tone = "MINT" },
    { key = "Friendly",   label = "Friendly",   colorHex = "ff81c995", tone = "MINT" },
    { key = "Neutral",    label = "Neutral",    colorHex = "ff8ab4f8", tone = "PRIMARY" },
    { key = "Unfriendly", label = "Unfriendly", colorHex = "fff28b82", tone = "CORAL" },
    { key = "Rival",      label = "Rival",      colorHex = "fff28b82", tone = "CORAL" },
    { key = "Marked",     label = "Marked",     colorHex = "fffdd663", tone = "AMBER" },
}

local function GetDefaultIconFallback()
    return (ns.IconPool and ns.IconPool.defaultFallback) or 134400
end

local function GetStandingBuckets()
    local buckets = {}
    local seen = {}
    for _, b in ipairs(BASE_STANDING_BUCKETS) do
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

local function FormatCheckbox(label, isChecked, activeColorHex)
    local box = isChecked and ("|c" .. (activeColorHex or "ff81c995") .. "[X]|r ") or "|cff9aa0a6[ ]|r "
    return box .. label
end

local function NormalizeIconInput(icon)
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

local function UnpackIconEntry(entry)
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

local function SetIconTextureSafe(tex, icon, fallback)
    if not tex then return end
    local fbDefault = fallback or GetDefaultIconFallback()
    local target = nil
    if ns.IconPool and ns.IconPool.ResolveTexture then
        target = ns.IconPool:ResolveTexture(icon, fbDefault)
    else
        target = NormalizeIconInput(icon) or NormalizeIconInput(fbDefault) or 134400
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
            or NormalizeIconInput(fbDefault)
            or 134400
        pcall(function() tex:SetTexture(fb) end)
    end
end

local function FormatPickerIconReadout(prefix, iconVal, knownID, texObj)
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

local function EnsureTopicConsentTable()
    if not ns.profile then return {} end
    if type(ns.profile.rpStyleTopics) ~= "table" then
        ns.profile.rpStyleTopics = {}
    end
    for _, t in ipairs(RP_STYLE_TOPICS) do
        if not ns.profile.rpStyleTopics[t.key] then
            ns.profile.rpStyleTopics[t.key] = t.defaultVal
        end
    end
    if ns.profile.lgbtqFriendly == nil then ns.profile.lgbtqFriendly = true end
    if ns.profile.erpFriendly == nil then ns.profile.erpFriendly = false end
    if ns.profile.mdni == nil then ns.profile.mdni = false end
    return ns.profile.rpStyleTopics
end

local function GetTopicConsentValue(topicKey, fallback)
    local tbl = EnsureTopicConsentTable()
    return tbl[topicKey] or fallback or "With player permission"
end

local function CycleTopicConsent(topicKey, defaultVal)
    local tbl = EnsureTopicConsentTable()
    local cur = tbl[topicKey] or defaultVal
    local nextIdx = 1
    for i, opt in ipairs(TOPIC_CONSENT_OPTIONS) do
        if opt == cur then
            nextIdx = (i % #TOPIC_CONSENT_OPTIONS) + 1
            break
        end
    end
    tbl[topicKey] = TOPIC_CONSENT_OPTIONS[nextIdx]
    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
    if ns.SyncMSP then ns:SyncMSP() end
    return tbl[topicKey]
end

local function FormatTopicButtonText(topicLabel, val)
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

local function HexToRGB(hex6)
    local h = NormalizeHex6(hex6) or "8ab4f8"
    local r = tonumber(string.sub(h, 1, 2), 16) / 255
    local g = tonumber(string.sub(h, 3, 4), 16) / 255
    local b = tonumber(string.sub(h, 5, 6), 16) / 255
    return r, g, b
end

local function RGBToHex6(r, g, b)
    local function ClampByte(v)
        v = math.max(0, math.min(1, tonumber(v) or 0))
        return math.floor(v * 255 + 0.5)
    end
    return string.format("%02x%02x%02x", ClampByte(r), ClampByte(g), ClampByte(b))
end

local function GetWoWClassHex6()
    local _, classFile = UnitClass("player")
    local classStr = (classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] and RAID_CLASS_COLORS[classFile].colorStr) or "ffffffff"
    return NormalizeHex6(classStr) or "ffffff"
end

local function GetPlayerActiveClassColorHex()
    local custom = NormalizeHex6(ns.profile and (ns.profile.classColorHex or ns.profile.nameColorHex))
    if custom then
        return "ff" .. custom
    end
    return "ff" .. GetWoWClassHex6()
end

function ns:GetPlayerClassColorCode()
    return GetPlayerActiveClassColorHex()
end

function ns:GetPlayerNameColorCode()
    return GetPlayerActiveClassColorHex()
end

local function StripColorCodes(str)
    if not str then return "" end
    local clean = string.gsub(tostring(str), "|c%x%x%x%x%x%x%x%x", "")
    clean = string.gsub(clean, "|r", "")
    return clean
end

local function IsPlayerSelfKey(k)
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

local function SyncSelfProfileToLocalCache()
    if not ns.profile then return end
    ns.mspCache = ns.mspCache or {}
    local p = ns.profile
    local custom = NormalizeHex6(p.classColorHex or p.nameColorHex)
    local eyeHex = NormalizeHex6(p.eyeColorHex)
    local cuText = tostring(p.currently or "")
    local fullName = BuildSelfFullName()
    local matchedAny = false

    local eyeFormatted = p.eyeColor or ""
    if strtrim(StripColorCodes(eyeFormatted)) ~= "" and eyeHex then
        eyeFormatted = "|cff" .. eyeHex .. strtrim(StripColorCodes(eyeFormatted)) .. "|r"
    end

    for k, rec in pairs(ns.mspCache) do
        if type(rec) == "table" and IsPlayerSelfKey(k) then
            matchedAny = true
            rec.CU = cuText
            if p.title and p.title ~= "" then rec.NT = p.title end
            if p.houseName and p.houseName ~= "" then rec.NH = p.houseName end
            if p.race and p.race ~= "" then rec.RA = p.race end
            if p.gender and p.gender ~= "" then rec.GN = p.gender end
            if eyeFormatted ~= "" then rec.AE = eyeFormatted end
            rec.FC = p.isIC and "2" or "1"
            if rec.RC and strtrim(StripColorCodes(rec.RC)) ~= "" then
                local plainRC = StripColorCodes(rec.RC)
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

local function ApplySwatchVisual(swatch, hex6, isFocused)
    if not swatch or not ns.M3 then return end
    local M3 = ns.M3
    if hex6 then
        local r, g, b = HexToRGB(hex6)
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

local function RefreshEyeSwatchBox()
    local p1 = tabPanels[1]
    local swatch = p1 and p1.eyeSwatchBtn
    if not swatch then return end
    local eyeHex = NormalizeHex6((ns.profile and ns.profile.eyeColorHex) or (ns.profile and ns.profile.eyeColor))
    swatch.activeHex6 = eyeHex
    ApplySwatchVisual(swatch, eyeHex, ns.currentFocus == swatch)
    if p1.eyBox and p1.eyBox.SetTextColor then
        if eyeHex then
            local r, g, b = HexToRGB(eyeHex)
            p1.eyBox:SetTextColor(r, g, b, 1)
        else
            p1.eyBox:SetTextColor(0.91, 0.92, 0.93, 1)
        end
    end
end

local function RefreshClassSwatchBox()
    local p1 = tabPanels[1]
    local swatch = p1 and p1.classSwatchBtn
    if not swatch then return end
    local hex6 = NormalizeHex6(ns.profile and (ns.profile.classColorHex or ns.profile.nameColorHex)) or GetWoWClassHex6()
    swatch.activeHex6 = hex6
    ApplySwatchVisual(swatch, hex6, ns.currentFocus == swatch)
    if p1.clBox and p1.clBox.SetTextColor then
        local r, g, b = HexToRGB(hex6)
        p1.clBox:SetTextColor(r, g, b, 1)
    end
end

local function AttachWheelScroller(frame, onWheelStep)
    if not frame or not frame.EnableMouseWheel then return end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta and delta ~= 0 and onWheelStep then
            onWheelStep(delta > 0 and -1 or 1)
        end
    end)
end

local function GetRPExperienceLabelText(code)
    local c = tostring(code or (ns.profile and ns.profile.rpStyle) or "1")
    for _, item in ipairs(RP_EXPERIENCE_LIST) do
        if item.code == c then
            return item.label
        end
    end
    if ns.GetRPStyleLabel then
        return ns:GetRPStyleLabel(c)
    end
    return "Normal"
end

local function ApplyRPExperienceSelection(code)
    if not ns.profile then return end
    ns.profile.rpStyle = tostring(code or "1")
    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
    if ns.SyncMSP then ns:SyncMSP() end
    if mainFrame and mainFrame.bannerExpBtn then
        mainFrame.bannerExpBtn:SetText("|cff8ab4f8RP:|r " .. GetRPExperienceLabelText(ns.profile.rpStyle) .. " [v]")
    end
    if tabPanels[1] and tabPanels[1].styleBtn then
        tabPanels[1].styleBtn:SetText("RP Style: |cff8ab4f8" .. GetRPExperienceLabelText(ns.profile.rpStyle) .. "|r")
    end
    ns:ShowStatusToast("RP Experience: " .. GetRPExperienceLabelText(ns.profile.rpStyle))
end

local function LayoutRow(parent, y, items, padLeft, padRight, gap)
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

local function UpdateControlStripLayout()
    if not mainFrame or not mainFrame.controlBar then return end
    local bar = mainFrame.controlBar
    local barW = bar:GetWidth()
    if not barW or barW < 200 then return end

    local pad = 8
    local gap = 6
    local closeW = 28
    local icW = 126
    local wuW = 128
    local expW = 104
    local arrowW = 20

    local closeBtn = mainFrame.closeBtn
    local icSwitch = mainFrame.icSwitch
    local walkUpBtn = mainFrame.walkUpBtn
    local bannerExpBtn = mainFrame.bannerExpBtn
    local profNextBtn = mainFrame.profNextBtn
    local profChip = mainFrame.profChip
    local profPrevBtn = mainFrame.profPrevBtn

    if closeBtn then
        closeBtn:ClearAllPoints()
        closeBtn:SetSize(closeW, 26)
        closeBtn:SetPoint("RIGHT", bar, "RIGHT", -pad, 0)
    end
    if icSwitch then
        icSwitch:ClearAllPoints()
        icSwitch:SetSize(icW, 26)
        icSwitch:SetPoint("RIGHT", closeBtn, "LEFT", -gap, 0)
    end
    if walkUpBtn then
        walkUpBtn:ClearAllPoints()
        walkUpBtn:SetSize(wuW, 26)
        walkUpBtn:SetPoint("RIGHT", icSwitch, "LEFT", -gap, 0)
    end
    if bannerExpBtn then
        bannerExpBtn:ClearAllPoints()
        bannerExpBtn:SetSize(expW, 26)
        bannerExpBtn:SetPoint("RIGHT", walkUpBtn, "LEFT", -gap, 0)
    end

    local rightUsed = pad + closeW + gap + icW + gap + wuW + gap + expW + gap + pad
    local chipW = math.max(64, math.min(120, barW - rightUsed - (arrowW * 2) - 4))

    if profPrevBtn then
        profPrevBtn:ClearAllPoints()
        profPrevBtn:SetSize(arrowW, 24)
        profPrevBtn:SetPoint("LEFT", bar, "LEFT", pad, 0)
    end
    if profChip then
        profChip:ClearAllPoints()
        profChip:SetSize(chipW, 24)
        profChip:SetPoint("LEFT", profPrevBtn, "RIGHT", 2, 0)
    end
    if profNextBtn then
        profNextBtn:ClearAllPoints()
        profNextBtn:SetSize(arrowW, 24)
        profNextBtn:SetPoint("LEFT", profChip, "RIGHT", 2, 0)
    end
end

local function LayoutGlanceCards()
    local p2 = tabPanels[2]
    if not p2 or not p2.cards or not p2.glanceScroll or not p2.glanceChild then return end
    local scrollW = p2.glanceScroll:GetWidth()
    if not scrollW or scrollW < 180 then
        scrollW = math.max(300, (p2:GetWidth() or 656) - 44)
    end
    local childW = math.max(200, scrollW - 4)
    p2.glanceChild:SetWidth(childW)

    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local topY = -4 - (slot - 1) * 112
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", p2.glanceChild, "TOPLEFT", 0, topY)
            card:SetWidth(childW)
            LayoutRow(card, -38, {
                { w = card.titleBox,  weight = 0.34 },
                { w = card.detailBox, weight = 0.66 },
                { w = card.clrBtn,    fixed = 56 },
            }, 74, 12, 10)
        end
    end
    p2.glanceChild:SetHeight(5 * 112 + 12)
    if p2.glanceScroll.UpdateScrollChildRect then
        p2.glanceScroll:UpdateScrollChildRect()
    end
end

local function UpdateResponsiveLayouts()
    if not mainFrame or not tabPanels[1] then return end
    UpdateControlStripLayout()

    local p1 = tabPanels[1]
    if p1 and p1.subTabCore then
        LayoutRow(p1, -10, {
            { w = p1.subTabCore,   weight = 1 },
            { w = p1.subTabVitals, weight = 1 },
            { w = p1.subTabExtras, weight = 1.15 },
        }, 16, 16, 8)

        local pc = p1.pageCore
        if pc then
            LayoutRow(pc, -22, {
                { w = p1.pxBox, weight = 0.16 },
                { w = p1.fnBox, weight = 0.25 },
                { w = p1.lnBox, weight = 0.25 },
                { w = p1.tiBox, weight = 0.34 },
            }, 16, 16, 10)

            LayoutRow(pc, -76, {
                { w = p1.raBox,          weight = 0.32 },
                { w = p1.clBox,          weight = 0.36 },
                { w = p1.classSwatchBtn, fixed = 28 },
                { w = p1.prBox,          weight = 0.32 },
            }, 16, 16, 8)

            LayoutRow(pc, -132, {
                { w = p1.cuBox,         weight = 1 },
                { w = p1.presetBtn,     fixed = 82 },
                { w = p1.cycleCuBtn,    fixed = 58 },
                { w = p1.savePresetBtn, fixed = 60 },
                { w = p1.clearCuBtn,    fixed = 54 },
            }, 16, 16, 6)

            if p1.oocNotesBox then
                local curH = p1.oocNotesBox:GetHeight() or 92
                LayoutRow(pc, -184, {
                    { w = p1.oocNotesBox, weight = 1 },
                }, 16, 16, 0)
                p1.oocNotesBox:SetHeight(curH)
            end
        end

        local pv = p1.pageVitals
        if pv then
            LayoutRow(pv, -20, {
                { w = p1.hoBox, weight = 0.50 },
                { w = p1.moBox, weight = 0.50 },
            }, 16, 16, 10)

            LayoutRow(pv, -68, {
                { w = p1.gnBox, weight = 0.22 },
                { w = p1.agBox, weight = 0.18 },
                { w = p1.htBox, weight = 0.28 },
                { w = p1.wtBox, weight = 0.32 },
            }, 16, 16, 10)

            LayoutRow(pv, -116, {
                { w = p1.eyBox,           weight = 1 },
                { w = p1.eyeSwatchBtn,    fixed = 28 },
                { w = p1.portraitPickBtn, fixed = 140 },
            }, 16, 16, 8)

            LayoutRow(pv, -162, {
                { w = p1.faceBox,  weight = 0.34 },
                { w = p1.tatBox,   weight = 0.33 },
                { w = p1.voiceBox, weight = 0.33 },
            }, 16, 16, 10)

            LayoutRow(pv, -208, {
                { w = p1.hbBox, weight = 1 },
                { w = p1.hhBox, weight = 1 },
            }, 16, 16, 10)
        end

        local pe = p1.pageExtras
        if pe then
            LayoutRow(pe, -22, {
                { w = p1.relBtn,   weight = 1 },
                { w = p1.styleBtn, weight = 1 },
            }, 16, 16, 10)

            if p1.topicBtns then
                LayoutRow(pe, -68, {
                    { w = p1.topicBtns.injury,  weight = 1 },
                    { w = p1.topicBtns.death,   weight = 1 },
                    { w = p1.topicBtns.romance, weight = 1 },
                }, 16, 16, 8)

                LayoutRow(pe, -104, {
                    { w = p1.topicBtns.criminal,      weight = 1 },
                    { w = p1.topicBtns.lossOfControl, weight = 1 },
                    { w = p1.topicBtns.guild,         weight = 1 },
                }, 16, 16, 8)
            end

            LayoutRow(pe, -148, {
                { w = p1.lgbtqBtn, weight = 1 },
                { w = p1.erpBtn,   weight = 1 },
            }, 16, 16, 8)

            if p1.mdniBtn then
                LayoutRow(pe, -182, {
                    { w = p1.mdniBtn, weight = 1 },
                }, 16, 16, 8)
            end
        end
    end

    LayoutGlanceCards()

    local p3 = tabPanels[3]
    if p3 and p3.appTabBtn then
        LayoutRow(p3, -12, {
            { w = p3.appTabBtn,   weight = 1 },
            { w = p3.hisTabBtn,   weight = 1 },
            { w = p3.clearBioBtn, fixed = 104 },
        }, 16, 16, 8)
    end

    local p4 = tabPanels[4]
    if p4 and p4.searchBox then
        LayoutRow(p4, -38, {
            { w = p4.searchBox,     weight = 1 },
            { w = p4.notableOnlyBtn, fixed = 96 },
            { w = p4.sortBtn,        fixed = 92 },
            { w = p4.prevPageBtn,    fixed = 54 },
            { w = p4.pageLabel,      fixed = 74, yOffset = -6 },
            { w = p4.nextPageBtn,    fixed = 54 },
        }, 16, 16, 6)
    end

    local pProf = tabPanels[5]
    if pProf and pProf.profNameBox then
        LayoutRow(pProf, -42, {
            { w = pProf.profNameBox, weight = 1 },
            { w = pProf.newProfBtn,  fixed = 148 },
            { w = pProf.delProfBtn,  fixed = 166 },
        }, 16, 16, 10)

        LayoutRow(pProf, -80, {
            { w = pProf.exportBtn, weight = 1 },
            { w = pProf.prevBtn,   fixed = 60 },
            { w = pProf.pageLabel, fixed = 78, yOffset = -6 },
            { w = pProf.nextBtn,   fixed = 60 },
        }, 16, 16, 8)
    end

    local p6 = tabPanels[6]
    if p6 and p6.modeBtn then
        LayoutRow(p6, -10, {
            { w = p6.modeBtn, weight = 1 },
        }, 16, 16, 0)
        if mainFrame.modeDropdown then
            local mw = p6.modeBtn:GetWidth()
            if mw and mw > 200 then
                mainFrame.modeDropdown:SetWidth(mw)
                for _, r in ipairs(mainFrame.modeDropdown.rows or {}) do
                    r:SetWidth(mw - 16)
                end
            end
        end

        LayoutRow(p6, -46, {
            { w = p6.buffBtn,    weight = 1 },
            { w = p6.healBtn,    weight = 1 },
            { w = p6.resBtn,     weight = 1 },
            { w = p6.specialBtn, weight = 1.1 },
            { w = p6.sessionBtn, weight = 1 },
        }, 16, 16, 6)

        LayoutRow(p6, -78, {
            { w = p6.cdMinusBtn,   fixed = 52 },
            { w = p6.cdLabel,      weight = 1, yOffset = -5 },
            { w = p6.cdPlusBtn,    fixed = 52 },
            { w = p6.healMinusBtn, fixed = 52 },
            { w = p6.healPctLabel, weight = 1, yOffset = -5 },
            { w = p6.healPlusBtn,  fixed = 52 },
        }, 16, 16, 8)

        LayoutRow(p6, -110, {
            { w = p6.poolToggleBtn,   weight = 1 },
            { w = p6.addPhraseBtn,    fixed = 100 },
            { w = p6.prevPhraseBtn,   fixed = 28 },
            { w = p6.phrasePageLabel, fixed = 86, yOffset = -6 },
            { w = p6.nextPhraseBtn,   fixed = 28 },
        }, 16, 16, 6)

        LayoutRow(p6, -247, {
            { w = p6.phraseBox, weight = 1 },
        }, 16, 16, 0)

        local tokRow = {}
        for _, tb in ipairs(p6.tokenBtns or {}) do
            table.insert(tokRow, { w = tb, weight = 1 })
        end
        table.insert(tokRow, { w = p6.savePhraseBtn, fixed = 90 })
        table.insert(tokRow, { w = p6.previewBtn,    fixed = 84 })
        LayoutRow(p6, -284, tokRow, 16, 16, 6)
    end

    local p7 = tabPanels[7]
    if p7 and p7.minimapBtn then
        LayoutRow(p7, -14, {
            { w = p7.scaleMinusBtn, fixed = 68 },
            { w = p7.scaleLabel,    weight = 1, yOffset = -7 },
            { w = p7.scalePlusBtn,  fixed = 68 },
            { w = p7.stdSizeBtn,    fixed = 88 },
            { w = p7.wideSizeBtn,   fixed = 80 },
            { w = p7.largeSizeBtn,  fixed = 80 },
        }, 16, 16, 6)

        local pairs7 = {
            { -50,  p7.minimapBtn, p7.hudBtn },
            { -84,  p7.hudRPBtn,   p7.npClassBtn },
            { -118, p7.npTagBtn,   p7.npRPNameBtn },
            { -152, p7.npCircleBtn, p7.combatBtn },
            { -186, p7.soundBtn,   p7.partyBtn },
            { -220, p7.rpNameBtn,  p7.chatRPBtn },
            { -254, p7.afkOOCBtn,  nil },
            { -294, p7.openExpBtn, p7.devModeBtn },
        }
        for _, row in ipairs(pairs7) do
            if row[3] then
                LayoutRow(p7, row[1], {
                    { w = row[2], weight = 1 },
                    { w = row[3], weight = 1 },
                }, 16, 16, 12)
            else
                LayoutRow(p7, row[1], {
                    { w = row[2], weight = 1 },
                }, 16, 16, 12)
            end
        end
    end

    local p8 = tabPanels[8]
    if p8 and p8.chkDebug then
        LayoutRow(p8, -34, {
            { w = p8.chkDebug, weight = 1 },
            { w = p8.chkSniff, weight = 1 },
            { w = p8.chkEcho,  weight = 1 },
        }, 16, 16, 8)

        LayoutRow(p8, -68, {
            { w = p8.popOutBtn,     weight = 1 },
            { w = p8.selfTestBtn,   weight = 1 },
            { w = p8.clearCacheBtn, weight = 1 },
        }, 16, 16, 8)
    end
end

function ns:ShowStatusToast(msg)
    if not mainFrame or not mainFrame.statusToast then return end
    mainFrame.statusToast:SetText("|cff81c995" .. (msg or "Saved") .. "|r")
    if C_Timer and C_Timer.After then
        C_Timer.After(3.5, function()
            if mainFrame and mainFrame.statusToast then
                mainFrame.statusToast:SetText("|cff9aa0a6Saved in PadRPDB|r")
            end
        end)
    end
end

local function BuildDirectoryRows()
    local seen, entries = {}, {}
    local q = strtrim(string.lower(knownSearchFilter or ""))
    local buckets = GetStandingBuckets()
    local bucketLookup = {}
    for _, b in ipairs(buckets) do
        bucketLookup[string.lower(b.key)] = b.key
    end

    local function CheckNoteStatus(k)
        if ns.GetNoteInfo then
            local standing, charNote, acctNote, hasNote = ns:GetNoteInfo(k)
            return standing, charNote, acctNote, hasNote
        end
        local rec = ns.db and ns.db.notes and ns.db.notes[k]
        local txt = (rec and rec.note) or ""
        return (rec and rec.standing) or "None", "", txt, (strtrim(txt) ~= "")
    end

    local function AddCandidate(k, v, lastSeen)
        if seen[k] then return end
        seen[k] = true
        local standing, charNote, acctNote, hasNote = CheckNoteStatus(k)
        local matchedBucket = standing and bucketLookup[string.lower(tostring(standing))] or nil
        local bucketKey = matchedBucket or "Other"
        local isNotable = (bucketKey ~= "Other") or hasNote

        if knownNotableOnly and not isNotable then return end

        local hay = string.lower(table.concat({
            tostring(k or ""),
            StripColorCodes(v.NA or ""),
            StripColorCodes(v.NT or ""),
            StripColorCodes(v.NH or ""),
            StripColorCodes(v.CU or ""),
            tostring(standing or ""),
            tostring(charNote or ""),
            tostring(acctNote or ""),
        }, " "))
        if q == "" or string.find(hay, q, 1, true) then
            table.insert(entries, {
                key = k,
                data = v,
                lastSeen = tonumber(lastSeen) or 0,
                standing = standing,
                bucketKey = bucketKey,
                hasNote = hasNote,
            })
        end
    end

    for k, v in pairs(ns.mspCache or {}) do
        if v and v.NA and v.NA ~= "" then
            AddCandidate(k, v, v.lastSeen)
        end
    end

    for k in pairs(ns.db.notes or {}) do
        AddCandidate(k, { NA = strsplit("-", k) }, 0)
    end

    table.sort(entries, function(a, b)
        if knownSortMode == "RECENT" then
            if a.lastSeen ~= b.lastSeen then
                return a.lastSeen > b.lastSeen
            end
        end
        return string.lower(StripColorCodes(a.data.NA or a.key)) < string.lower(StripColorCodes(b.data.NA or b.key))
    end)

    if not knownNotableOnly then
        local flatRows = {}
        for _, item in ipairs(entries) do
            table.insert(flatRows, {
                kind = "ENTRY",
                key = item.key,
                data = item.data,
                lastSeen = item.lastSeen,
                standing = item.standing,
                hasNote = item.hasNote,
                indented = false,
            })
        end
        return flatRows, #entries
    end

    local groups = {}
    for _, bInfo in ipairs(buckets) do
        groups[bInfo.key] = {}
    end
    for _, item in ipairs(entries) do
        table.insert(groups[item.bucketKey] or groups.Other, item)
    end

    local rows = {}
    for _, bInfo in ipairs(buckets) do
        local members = groups[bInfo.key]
        if #members > 0 then
            local isCollapsed = collapsedBuckets[bInfo.key] and true or false
            local arrow = isCollapsed and ">" or "v"
            table.insert(rows, {
                kind = "HEADER",
                bucketKey = bInfo.key,
                label = bInfo.label,
                colorHex = bInfo.colorHex,
                tone = bInfo.tone,
                count = #members,
                text = string.format("|c%s%s %s|r  |cff9aa0a6(%d)|r", bInfo.colorHex, arrow, bInfo.label, #members),
            })
            if not isCollapsed then
                for _, item in ipairs(members) do
                    table.insert(rows, {
                        kind = "ENTRY",
                        bucketKey = bInfo.key,
                        key = item.key,
                        data = item.data,
                        lastSeen = item.lastSeen,
                        standing = item.standing,
                        hasNote = item.hasNote,
                        indented = true,
                    })
                end
            end
        end
    end

    return rows, #entries
end

local function RefreshProfilesTab()
    local pProf = tabPanels[5]
    if not pProf or not pProf.rows or not ns.db or not ns.db.profiles then return end

    local ids = {}
    for id in pairs(ns.db.profiles) do
        table.insert(ids, id)
    end
    table.sort(ids, function(a, b)
        local na = string.lower((ns.db.profiles[a] and ns.db.profiles[a].profileName) or a)
        local nb = string.lower((ns.db.profiles[b] and ns.db.profiles[b].profileName) or b)
        return na < nb
    end)

    local perPage = 6
    local totalPages = math.max(1, math.ceil(#ids / perPage))
    profileListPage = math.max(1, math.min(totalPages, profileListPage))
    pProf.pageLabel:SetText(string.format("Page %d / %d", profileListPage, totalPages))

    local startIdx = (profileListPage - 1) * perPage
    for i = 1, perPage do
        local row = pProf.rows[i]
        local profId = ids[startIdx + i]
        if profId and ns.db.profiles[profId] then
            local prof = ns.db.profiles[profId]
            local isActive = (profId == ns.activeProfileId)
            local pLabel = prof.profileName or profId
            local charLine = strtrim(((prof.firstName or "") .. " " .. (prof.lastName or "")))
            local summary = isActive and ("|cff81c995[ACTIVE]|r  |cfffdd663" .. pLabel .. "|r") or ("|cffe8eaed" .. pLabel .. "|r")
            if charLine ~= "" then
                summary = summary .. "  |cff9aa0a6(" .. charLine .. ")|r"
            end
            row.selectBtn.profileId = profId
            row.selectBtn:SetText(summary)
            row.selectBtn:SetTone(isActive and "MINT" or nil)
            row.selectBtn:Show()
        else
            row.selectBtn.profileId = nil
            row.selectBtn:Hide()
        end
    end
end

-- Display / LB-RB order: tabs 1-7, then Emotes (9), then Dev (8) when Developer Mode is on.
function ns:GetTabDisplayOrder()
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local order = { 1, 2, 3, 4, 5, 6, 7, 9 }
    if showDev then order[#order + 1] = 8 end
    return order
end

local function UpdateTabBarLayout()
    if not mainFrame or not tabButtons[1] then return end
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local order = ns:GetTabDisplayOrder()
    local visibleCount = #order
    local totalWidth = mainFrame:GetWidth() - 24
    local gap = 3
    local btnW = math.floor((totalWidth - (gap * (visibleCount - 1))) / visibleCount)

    for i = 1, 9 do
        if tabButtons[i] then tabButtons[i]:Hide() end
    end
    for slot, i in ipairs(order) do
        local tb = tabButtons[i]
        if tb then
            tb:SetWidth(btnW)
            tb:ClearAllPoints()
            tb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12 + (slot - 1) * (btnW + gap), -108)
            tb:Show()
        end
    end

    if not showDev and activeTab == 8 then
        ns:SelectTab(7)
    end
end

function ns:RefreshNetInspector(newLine)
    if not inspectorFrame then return end

    local _, knownCount = BuildDirectoryRows()
    local engineLabel = (type(_G.msp) == "table") and "|cff81c995LibMSP|r" or "|cfff28b82Missing LibMSP|r"
    inspectorFrame.statusBar:SetText(string.format(
        "Engine: %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
        engineLabel,
        (ns.mspStats and ns.mspStats.sent) or 0,
        (ns.mspStats and ns.mspStats.liveReplies) or 0,
        knownCount,
        (ns.mspStats and ns.mspStats.lastReplyFrom) or "None"
    ))

    inspectorFrame.chkDebug:SetText(FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
    inspectorFrame.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)

    inspectorFrame.chkSniff:SetText(FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
    inspectorFrame.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)

    inspectorFrame.chkEcho:SetText(FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
    inspectorFrame.chkEcho:SetTone(ns.mspEchoChat and "PRIMARY" or nil)

    if newLine and inspectorFrame.msgFrame then
        inspectorFrame.msgFrame:AddMessage(newLine)
    end
    if inspectorFrame.copyEditor and inspectorFrame.copyEditor:IsShown() then
        inspectorFrame.copyEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
    end
end

local function InitNetInspectorWindow()
    if inspectorFrame then return end
    local M3 = ns.M3

    inspectorFrame = CreateFrame("Frame", "PadRP_NetInspector", UIParent, "BackdropTemplate")
    inspectorFrame:SetSize(540, 340)
    inspectorFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -110)
    inspectorFrame:SetFrameStrata("HIGH")
    inspectorFrame:SetMovable(true)
    inspectorFrame:EnableMouse(true)
    inspectorFrame:RegisterForDrag("LeftButton")
    inspectorFrame:SetScript("OnDragStart", inspectorFrame.StartMoving)
    inspectorFrame:SetScript("OnDragStop", inspectorFrame.StopMovingOrSizing)
    ns:ApplySurface(inspectorFrame, M3.surfaceDim, M3.primary)
    ns:EnableClipping(inspectorFrame)
    inspectorFrame:Hide()

    local title = inspectorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("|cff8ab4f8PADRP NETWORK & WIRE INSPECTOR|r  |cff9aa0a6(Noise-Free Console)|r")

    local closeBtn = ns:CreateMaterialButton(inspectorFrame, "X", 28, 24, 504, -6, "CORAL", function()
        inspectorFrame:Hide()
    end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", inspectorFrame, "TOPRIGHT", -8, -6)

    inspectorFrame.statusBar = inspectorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inspectorFrame.statusBar:SetPoint("TOPLEFT", 12, -30)
    inspectorFrame.statusBar:SetPoint("TOPRIGHT", -12, -30)
    inspectorFrame.statusBar:SetJustifyH("LEFT")

    inspectorFrame.chkDebug = ns:CreateMaterialButton(inspectorFrame, "", 132, 24, 12, -48, nil, function()
        ns.mspDebug = not ns.mspDebug
        ns:LogNet("CONFIG", "ff81c995", "Debug Events: " .. (ns.mspDebug and "ENABLED" or "DISABLED"))
        ns:RefreshNetInspector()
        ns:RefreshControllerUI()
    end)

    inspectorFrame.chkSniff = ns:CreateMaterialButton(inspectorFrame, "", 132, 24, 150, -48, nil, function()
        ns.mspSniff = not ns.mspSniff
        if ns.mspSniff then ns.mspDebug = true end
        ns:LogNet("CONFIG", "fffdd663", "Raw Wire Sniffer: " .. (ns.mspSniff and "ENABLED" or "DISABLED"))
        ns:RefreshNetInspector()
        ns:RefreshControllerUI()
    end)

    inspectorFrame.chkEcho = ns:CreateMaterialButton(inspectorFrame, "", 132, 24, 288, -48, nil, function()
        ns.mspEchoChat = not ns.mspEchoChat
        ns:RefreshNetInspector()
        ns:RefreshControllerUI()
    end)

    inspectorFrame.copyBtn = ns:CreateMaterialButton(inspectorFrame, "Copy Log", 102, 24, 426, -48, nil, function(self)
        if inspectorFrame.copyEditor:IsShown() then
            inspectorFrame.copyEditor:Hide()
            inspectorFrame.feedBox:Show()
            self:SetText("Copy Log")
        else
            inspectorFrame.feedBox:Hide()
            inspectorFrame.copyEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
            inspectorFrame.copyEditor:Show()
            inspectorFrame.copyEditor.editBox:HighlightText()
            inspectorFrame.copyEditor.editBox:SetFocus()
            self:SetText("Live Feed")
        end
    end)

    local feedBox = CreateFrame("Frame", nil, inspectorFrame, "BackdropTemplate")
    feedBox:SetPoint("TOPLEFT", 12, -78)
    feedBox:SetPoint("BOTTOMRIGHT", -12, 42)
    ns:ApplySurface(feedBox, M3.surfaceLow, M3.outline)
    ns:EnableClipping(feedBox)
    inspectorFrame.feedBox = feedBox

    local msgFrame = CreateFrame("ScrollingMessageFrame", nil, feedBox)
    msgFrame:SetPoint("TOPLEFT", 10, -8)
    msgFrame:SetPoint("BOTTOMRIGHT", -10, 8)
    msgFrame:SetFontObject("ChatFontSmall")
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetFading(false)
    msgFrame:SetMaxLines(250)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    inspectorFrame.msgFrame = msgFrame

    local copyEditor = ns:CreateScrollableTextEditor(inspectorFrame, "No log entries yet.", 12, -78, 516, 220)
    copyEditor:Hide()
    inspectorFrame.copyEditor = copyEditor

    ns:CreateMaterialButton(inspectorFrame, "Query Target", 122, 26, 12, -306, "PRIMARY", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ns:RequestUnitMSP("target", true, true)
        elseif ns.lastInspectedKey then
            ns:RequestUnitMSP(ns.lastInspectedKey, true, true)
        else
            ns:LogNet("WARN", "fff28b82", "No player targeted to query.")
        end
    end)

    ns:CreateMaterialButton(inspectorFrame, "Run Self-Test", 122, 26, 142, -306, "AMBER", function()
        ns:RunMSPSelfTest()
    end)

    ns:CreateMaterialButton(inspectorFrame, "Clear Log", 126, 26, 272, -306, "CORAL", function()
        wipe(ns.netLogs)
        msgFrame:Clear()
        ns:LogNet("CLEAR", "ff9aa0a6", "Log cleared.")
    end)

    for _, line in ipairs(ns.netLogs or {}) do
        msgFrame:AddMessage(line)
    end
end

function ns:ToggleNetInspector(forceShow)
    InitNetInspectorWindow()
    if forceShow or not inspectorFrame:IsShown() then
        inspectorFrame:Show()
        ns:RefreshNetInspector()
    else
        inspectorFrame:Hide()
    end
end

local function CloseAnyOpenPopup()
    if not mainFrame then return false end
    if ns.dossierFrame and ns.dossierFrame.standingDropdown and ns.dossierFrame.standingDropdown:IsShown() then
        ns.dossierFrame.standingDropdown:Hide()
        if ns.dossierFrame.standingBtn then ns:SetControllerFocus(ns.dossierFrame.standingBtn) end
        return true
    end
    if mainFrame.expDropdown and mainFrame.expDropdown:IsShown() then
        mainFrame.expDropdown:Hide()
        if mainFrame.bannerExpBtn then ns:SetControllerFocus(mainFrame.bannerExpBtn) end
        return true
    end
    if mainFrame.presetDropdown and mainFrame.presetDropdown:IsShown() then
        mainFrame.presetDropdown:Hide()
        if tabPanels[1] and tabPanels[1].presetBtn then ns:SetControllerFocus(tabPanels[1].presetBtn) end
        return true
    end
    if mainFrame.modeDropdown and mainFrame.modeDropdown:IsShown() then
        mainFrame.modeDropdown:Hide()
        if tabPanels[6] and tabPanels[6].modeBtn then ns:SetControllerFocus(tabPanels[6].modeBtn) end
        return true
    end
    if mainFrame.poolDropdown and mainFrame.poolDropdown:IsShown() then
        mainFrame.poolDropdown:Hide()
        if tabPanels[6] and tabPanels[6].poolToggleBtn then ns:SetControllerFocus(tabPanels[6].poolToggleBtn) end
        return true
    end
    if mainFrame.iconPicker and mainFrame.iconPicker:IsShown() then
        local returnTarget = mainFrame.iconPicker.returnFocusWidget
        mainFrame.iconPicker:Hide()
        if returnTarget and returnTarget:IsVisible() then
            ns:SetControllerFocus(returnTarget)
        else
            ns:FocusFirstInScope()
        end
        return true
    end
    if mainFrame.exportModal and mainFrame.exportModal:IsShown() then
        mainFrame.exportModal:Hide()
        ns:FocusFirstInScope()
        return true
    end
    return false
end

function ns:ControllerConfirmAction()
    local scope = ns:GetActiveModalScope()
    if not scope or not ns:CanProcessPadAction() then return end

    if scope == ns.hudFrame and ns.OpenTargetDossier then
        ns:OpenTargetDossier(ns.hudFrame.inspectedKey)
        return
    end

    local now = (GetTime and GetTime()) or 0
    local activeBox = ns.activeEditBox
    if activeBox and activeBox.HasFocus and activeBox:HasFocus() then
        if (now - (lastEditFocusTime or 0)) < 0.25 then
            return
        end
        activeBox:ClearFocus()
        return
    end

    local cur = ns.currentFocus
    if not cur or not cur:IsVisible() then
        ns:FocusFirstInScope()
        return
    end

    if cur == lastConfirmTarget and (now - (lastConfirmTime or 0)) < 0.18 then
        return
    end
    lastConfirmTime = now
    lastConfirmTarget = cur

    if cur.GetObjectType and cur:GetObjectType() == "EditBox" then
        lastEditFocusTime = now
        if cur.SetFocus then cur:SetFocus() end
        return
    end

    if cur.ActivateFromPad then
        cur:ActivateFromPad()
    elseif cur.Click then
        cur:Click("LeftButton")
    end

    if cur and cur:IsVisible() and ns:GetActiveModalScope() == scope then
        ns:SetControllerFocus(cur)
    end
end

function ns:ControllerCancelAction()
    local scope = ns:GetActiveModalScope()
    if not scope or not ns:CanProcessPadAction() then return end
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
        return
    end
    if CloseAnyOpenPopup() then
        ns:PlayUISound()
        return
    end
    if ns.dossierFrame and ns.dossierFrame:IsShown() then
        ns.dossierFrame:Hide()
        return
    end
    if scope == ns.hudFrame then
        if ns.DismissTargetHUDFocus then
            ns:DismissTargetHUDFocus()
        elseif ns.SetControllerFocus then
            ns:SetControllerFocus(nil)
        end
        return
    end
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    end
end

function ns:CycleTab(delta)
    if not ns:CanProcessPadAction() then return end
    if ns.dossierFrame and ns.dossierFrame:IsShown() and ns.CycleDossierTab then
        ns:CycleDossierTab(delta)
        return
    end
    if not mainFrame or not mainFrame:IsShown() then return end
    if mainFrame.iconPicker and mainFrame.iconPicker:IsShown() then
        mainFrame.iconPicker:StepPage(delta)
        return
    end
    local order = ns:GetTabDisplayOrder()
    local pos = 1
    for i, tabIdx in ipairs(order) do
        if tabIdx == activeTab then pos = i break end
    end
    ns:SelectTab(order[((pos - 1 + delta) % #order) + 1])
end

local function GetActiveGratitudePool()
    local g = ns.db.gratitude
    local item = POOL_LIST[editPoolIdx] or POOL_LIST[1]
    if item.key == "IC" then return g.icPhrases
    elseif item.key == "OOC" then return g.oocPhrases
    elseif item.key == "RES" then return g.resPhrases
    elseif item.key == "SUMMON" then return g.summonPhrases
    elseif item.key == "SPECIAL" then return g.specialPhrases end
    return g.icPhrases
end

local function LoadAllGlancesIntoUI()
    local p2 = tabPanels[2]
    if not p2 or not p2.cards or not ns.profile then return end
    local p = ns.profile
    local fallbackIcon = GetDefaultIconFallback()
    local placeholders = {
        { title = "e.g., Singed Cuffs",   detail = "e.g., Faint arcane scorch marks line the hems of his sleeves." },
        { title = "e.g., Worn Satchel",   detail = "e.g., Stuffed with rolled parchment, ink vials, and dried herbs." },
        { title = "e.g., Silver Signet",  detail = "e.g., A tarnished ring bearing an unfamiliar river-crest." },
        { title = "e.g., Steady Voice",   detail = "e.g., Speaks with a calm, measured cadence even under pressure." },
        { title = "e.g., Travel Cloak",   detail = "e.g., Weathered dark wool dusted with road ash from afar." },
    }

    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local g = p.glances[slot] or { icon = fallbackIcon, title = "", detail = "" }
            card.slotIndex = slot
            card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. slot .. "|r")
            SetIconTextureSafe(card.iconTex, g.icon, fallbackIcon)
            card.titleBox.placeholder:SetText(placeholders[slot].title)
            card.detailBox.placeholder:SetText(placeholders[slot].detail)
            card.titleBox:SetCleanText(g.title)
            card.detailBox:SetCleanText(g.detail)
            card:Show()
        end
    end
end

function ns:LoadProfileIntoUI()
    if not mainFrame or not ns.profile then return end
    local p = ns.profile
    EnsureTopicConsentTable()
    local p1 = tabPanels[1]
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
    if tabPanels[5] and tabPanels[5].profNameBox then
        tabPanels[5].profNameBox:SetCleanText(p.profileName)
    end
    RefreshEyeSwatchBox()
    RefreshClassSwatchBox()
    LoadAllGlancesIntoUI()
    local p3 = tabPanels[3]
    if p3 and p3.bioEditor then
        p3.bioEditor:SetCleanText(activeBioMode == "APPEARANCE" and p.description or p.history)
    end
end

local function CommitModifiedBoxesToProfile(forceAll)
    if not ns.profile or not mainFrame then return false end
    local p = ns.profile
    EnsureTopicConsentTable()
    local changed = false
    local p1 = tabPanels[1]
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

    local pProf = tabPanels[5]
    if pProf and pProf.profNameBox and (forceAll or pProf.profNameBox.isDirty) then
        local pName = strtrim(pProf.profNameBox:GetText() or "")
        if pName ~= "" then p.profileName = pName end
        pProf.profNameBox.isDirty = false
        changed = true
    end

    local p2 = tabPanels[2]
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

    local p3 = tabPanels[3]
    if p3 and p3.bioEditor and (forceAll or p3.bioEditor.isDirty) then
        local text = p3.bioEditor:GetText()
        if activeBioMode == "APPEARANCE" then p.description = text else p.history = text end
        p3.bioEditor.isDirty = false
        changed = true
    end

    if changed then
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        SyncSelfProfileToLocalCache()
    end
    return changed
end

function ns:SelectTab(index)
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
    end
    CommitModifiedBoxesToProfile(false)
    activeTab = index
    local M3 = ns.M3
    for i, panel in ipairs(tabPanels) do
        local tb = tabButtons[i]
        if i == index then
            panel:Show()
            tb:SetBackdropColor(unpack(M3.primaryTonal))
            tb.activeBar:Show()
            tb.label:SetTextColor(0.82, 0.90, 1.0)
        else
            panel:Hide()
            tb:SetBackdropColor(unpack(M3.surfaceLow))
            tb.activeBar:Hide()
            tb.label:SetTextColor(0.60, 0.64, 0.70)
        end
    end
    CloseAnyOpenPopup()
    ns:RefreshControllerUI()
    ns:FocusFirstInScope()
end

local function RefreshHeaderBanner()
    if not mainFrame or not ns.profile then return end
    local p = ns.profile
    local M3 = ns.M3
    local activeHex = GetPlayerActiveClassColorHex()
    local fallbackIcon = GetDefaultIconFallback()

    if mainFrame.portraitTex then
        SetIconTextureSafe(mainFrame.portraitTex, p.icon, fallbackIcon)
    end

    local nameParts = {}
    if p.titlePrefix and strtrim(p.titlePrefix) ~= "" then table.insert(nameParts, strtrim(p.titlePrefix)) end
    local baseFirst = (p.firstName and p.firstName ~= "") and p.firstName or UnitName("player")
    table.insert(nameParts, baseFirst)
    if p.lastName and strtrim(p.lastName) ~= "" then table.insert(nameParts, strtrim(p.lastName)) end
    local fullName = table.concat(nameParts, " ")

    mainFrame.bannerName:SetText("|c" .. activeHex .. fullName .. "|r")

    local guildVis = GetTopicConsentValue("guild", "Do not show")
    local wowGuild = (guildVis == "Yes" and GetGuildInfo and GetGuildInfo("player")) or ""
    local houseClean = (p.houseName and strtrim(p.houseName)) or ""
    local guildPart = ""
    if wowGuild ~= "" and string.lower(wowGuild) ~= string.lower(houseClean) then
        guildPart = "  |cff81c995<" .. wowGuild .. ">|r"
    end

    local titlePart = (p.title and p.title ~= "") and ("|cfffdd663<" .. p.title .. ">|r") or "|cff9aa0a6No RP Title|r"
    local housePart = (houseClean ~= "") and ("  |cff8ab4f8-  " .. houseClean .. "|r") or ""
    mainFrame.bannerTitle:SetText(titlePart .. housePart .. guildPart)

    if mainFrame.bannerCurrently then
        local curClean = p.currently and strtrim(StripColorCodes(p.currently)) or ""
        if curClean ~= "" then
            local shortCur = string.sub(curClean, 1, 56)
            if #curClean > 56 then shortCur = shortCur .. "..." end
            mainFrame.bannerCurrently:SetText("|cff9aa0a6Currently:|r |cffe8eaed" .. shortCur .. "|r")
        else
            mainFrame.bannerCurrently:SetText("")
        end
    end

    mainFrame.profChip:SetText(p.profileName or "Default")

    if mainFrame.bannerExpBtn then
        mainFrame.bannerExpBtn:SetText("|cff8ab4f8RP:|r " .. GetRPExperienceLabelText(p.rpStyle) .. " [v]")
    end

    local wuBtn = mainFrame.walkUpBtn
    if wuBtn then
        local wu = p.walkUp or "WELCOME"
        if wu == "WELCOME" then
            wuBtn:SetTone("MINT")
            wuBtn:SetText("|cff81c995WALK-UPS: OPEN|r")
        elseif wu == "ASK" then
            wuBtn:SetTone("AMBER")
            wuBtn:SetText("|cfffdd663WALK-UPS: ASK|r")
        else
            wuBtn:SetTone("CORAL")
            wuBtn:SetText("|cfff28b82WALK-UPS: OFF|r")
        end
    end

    local sw = mainFrame.icSwitch
    sw.thumb:ClearAllPoints()
    if p.isIC then
        sw:SetBackdropColor(unpack(M3.mintTonal))
        sw:SetBackdropBorderColor(unpack(M3.mint))
        sw.thumb:SetPoint("RIGHT", sw, "RIGHT", -3, 0)
        sw.thumb:SetBackdropColor(unpack(M3.mint))
        sw.thumb.label:SetText("|cff061c10IN CHARACTER|r")
        sw.bgLabel:ClearAllPoints()
        sw.bgLabel:SetPoint("LEFT", sw, "LEFT", 10, 0)
        sw.bgLabel:SetText("|cff689f78OOC|r")
    else
        sw:SetBackdropColor(unpack(M3.coralTonal))
        sw:SetBackdropBorderColor(unpack(M3.coral))
        sw.thumb:SetPoint("LEFT", sw, "LEFT", 3, 0)
        sw.thumb:SetBackdropColor(unpack(M3.coral))
        sw.thumb.label:SetText("|cff240808OUT OF CHAR|r")
        sw.bgLabel:ClearAllPoints()
        sw.bgLabel:SetPoint("RIGHT", sw, "RIGHT", -12, 0)
        sw.bgLabel:SetText("|cff9e625eIC|r")
    end
end

local function FormatDirectoryEntryText(k, d, item)
    local parts = {}
    local sep = " |cff5f6368•|r "

    if item.hasNote then
        table.insert(parts, "|TInterface\\Icons\\INV_Misc_Note_01:13:13:0:0:64:64:4:60:4:60|t")
    end
    if not item.indented and item.standing and item.standing ~= "None" then
        local bInfo
        for _, sb in ipairs(GetStandingBuckets()) do
            if string.lower(sb.key) == string.lower(item.standing) then bInfo = sb break end
        end
        if bInfo then
            table.insert(parts, "|c" .. bInfo.colorHex .. "[" .. string.upper(bInfo.label) .. "]|r")
        else
            table.insert(parts, "|cfffdd663[" .. string.upper(tostring(item.standing)) .. "]|r")
        end
    end

    local rawName = d.NA or k
    local activeHex = nil
    if IsPlayerSelfKey(k) then
        activeHex = GetPlayerActiveClassColorHex()
    elseif type(rawName) == "string" then
        local embeddedHex = string.match(rawName, "^|c(%x%x%x%x%x%x%x%x)")
        if embeddedHex then
            activeHex = embeddedHex
        end
    end

    local cleanName = StripColorCodes(rawName)
    local charOnly = strsplit("-", k)
    local realmPart = (charOnly and charOnly ~= cleanName) and (" |cff8ab4f8(" .. k .. ")|r") or ""
    local displayColor = activeHex or "ffe8eaed"
    table.insert(parts, "|c" .. displayColor .. cleanName .. "|r" .. realmPart)

    local assignedRel = ns.GetAssignedRelationship and ns:GetAssignedRelationship(k) or ""
    if assignedRel ~= "" then
        table.insert(parts, "|cfffdd663[" .. assignedRel .. "]|r")
    end

    local statusBadges = {}
    if d.FC == "2" then
        table.insert(statusBadges, "|cff81c995[IC]|r")
    elseif d.FC == "1" then
        table.insert(statusBadges, "|cfff28b82[OOC]|r")
    end

    local _, wuCode = ns:GetTargetWalkUpInfo(d)
    if wuCode == "WELCOME" then
        table.insert(statusBadges, "|cff81c995[WU]|r")
    elseif wuCode == "ASK" then
        table.insert(statusBadges, "|cfffdd663[Ask]|r")
    elseif wuCode == "CLOSED" then
        table.insert(statusBadges, "|cfff28b82[Off]|r")
    end

    if UnitInRaid and UnitInRaid(k) then
        table.insert(statusBadges, "|cfffdd663[Raid]|r")
    elseif UnitInParty and UnitInParty(k) then
        table.insert(statusBadges, "|cff8ab4f8[Party]|r")
    end

    if #statusBadges > 0 then
        table.insert(parts, table.concat(statusBadges, " "))
    end

    local titleClean = d.NT and strtrim(StripColorCodes(d.NT)) or ""
    local guildClean = d.NH and strtrim(StripColorCodes(d.NH)) or ""
    local curClean = d.CU and strtrim(StripColorCodes(d.CU)) or ""

    if titleClean ~= "" then
        table.insert(parts, "|cfffdd663<" .. titleClean .. ">|r")
    end
    if guildClean ~= "" then
        table.insert(parts, "|cff8ab4f8{" .. guildClean .. "}|r")
    end
    if curClean ~= "" then
        local shortCur = string.sub(curClean, 1, 34)
        if #curClean > 34 then shortCur = shortCur .. "..." end
        table.insert(parts, "|cff9aa0a6\"" .. shortCur .. "\"|r")
    end

    local prefix = item.indented and "  - " or ""
    return prefix .. table.concat(parts, sep)
end

function ns:RefreshTargetCard()
    if not mainFrame or not tabPanels[4] then return end
    local p4 = tabPanels[4]

    local rows, totalEntries = BuildDirectoryRows()
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#rows / perPage))
    if knownListPage > totalPages then knownListPage = totalPages end
    if knownListPage < 1 then knownListPage = 1 end

    local bucketLabel = knownNotableOnly and "NOTABLE ACCORDION" or "RP DIRECTORY"
    p4.countLabel:SetText(string.format("|cff8ab4f8%s (%d)|r  -  Select any player to open Dossier & Notes", bucketLabel, totalEntries))
    p4.pageLabel:SetText(string.format("Page %d / %d", knownListPage, totalPages))

    p4.notableOnlyBtn:SetText(FormatCheckbox("Notable", knownNotableOnly, "fffdd663"))
    p4.notableOnlyBtn:SetTone(knownNotableOnly and "AMBER" or nil)
    p4.sortBtn:SetText(knownSortMode == "RECENT" and "Sort: Recent" or "Sort: A-Z")
    p4.sortBtn:SetTone(knownSortMode == "RECENT" and "PRIMARY" or nil)

    local startIdx = (knownListPage - 1) * perPage
    for i = 1, perPage do
        local rowBtn = p4.knownRows[i]
        local item = rows[startIdx + i]
        if item then
            if item.kind == "HEADER" then
                rowBtn.profileKey = nil
                rowBtn.bucketKey = item.bucketKey
                rowBtn:SetTone(item.tone)
                rowBtn:SetText(item.text)
                rowBtn.seenLabel:SetText("")
            else
                rowBtn.profileKey = item.key
                rowBtn.bucketKey = nil
                rowBtn:SetTone(nil)
                rowBtn:SetText(FormatDirectoryEntryText(item.key, item.data, item))
                local seenStr = (item.lastSeen and item.lastSeen > 0) and date("%m/%d %H:%M", item.lastSeen) or "--/--"
                rowBtn.seenLabel:SetText("|cff9aa0a6" .. seenStr .. "|r")
            end
            rowBtn:Show()
        else
            rowBtn.profileKey = nil
            rowBtn.bucketKey = nil
            rowBtn.seenLabel:SetText("")
            rowBtn:Hide()
        end
    end
end

function ns:TrySeamlessDirectoryStep(rowIndex, dir)
    if activeTab ~= 4 then return false end
    local p4 = tabPanels[4]
    if not p4 or not p4:IsShown() or not p4.knownRows then return false end

    local rows = BuildDirectoryRows()
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#rows / perPage))

    local lastShownIdx = 0
    for i = 1, perPage do
        if p4.knownRows[i] and p4.knownRows[i]:IsShown() then
            lastShownIdx = i
        end
    end
    if lastShownIdx == 0 then return false end

    if dir == "DOWN" and rowIndex >= lastShownIdx and knownListPage < totalPages then
        knownListPage = knownListPage + 1
        ns:RefreshTargetCard()
        ns:PlayUISound()
        if p4.knownRows[1] and p4.knownRows[1]:IsShown() then
            ns:SetControllerFocus(p4.knownRows[1])
        end
        return true
    elseif dir == "UP" and rowIndex <= 1 and knownListPage > 1 then
        knownListPage = knownListPage - 1
        ns:RefreshTargetCard()
        ns:PlayUISound()
        local targetRow = p4.knownRows[perPage]
        if targetRow and targetRow:IsShown() then
            ns:SetControllerFocus(targetRow)
        end
        return true
    end
    return false
end

local function RefreshGratitudeStudio()
    local p6 = tabPanels[6]
    if not p6 then return end
    local g = ns.db.gratitude

    p6.modeBtn:SetText("|cff9aa0a6GRATITUDE MODE:|r   |cff8ab4f8" .. ns:GetGratitudeModeLabel() .. "|r   |cfffdd663[Open Dropdown v]|r")
    p6.buffBtn:SetText("Buffs: " .. (g.thankBuffs and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.healBtn:SetText("Heals: " .. (g.thankHeals and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.resBtn:SetText("Res: " .. (g.thankRes and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.specialBtn:SetText("Portals/CDs: " .. (g.thankSpecial and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.sessionBtn:SetText("1x/Session: " .. (g.oncePerSession and "|cff81c995ON|r" or "|cff9aa0a6OFF|r"))
    p6.cdLabel:SetText(string.format("Cooldown: |cfffdd663%ds|r", g.cooldown or 60))
    p6.healPctLabel:SetText(string.format("Min Heal: |cfffdd663%d%% HP|r", g.minHealPercent or 15))

    local pool = GetActiveGratitudePool()
    if #pool == 0 then table.insert(pool, "thanks %name for the %spell.") end
    if editPhraseIdx > #pool then editPhraseIdx = #pool end
    if editPhraseIdx < 1 then editPhraseIdx = 1 end

    local totalPages = math.max(1, math.ceil(#pool / 3))
    phrasePage = math.min(totalPages, math.ceil(editPhraseIdx / 3))

    local poolItem = POOL_LIST[editPoolIdx] or POOL_LIST[1]
    p6.poolToggleBtn:SetText("|cff9aa0a6PHRASE POOL:|r  |cfffdd663" .. poolItem.label .. "|r  |cff8ab4f8[v]|r")
    p6.phrasePageLabel:SetText(string.format("Page %d/%d (%d)", phrasePage, totalPages, #pool))

    local startIdx = (phrasePage - 1) * 3
    for i = 1, 3 do
        local actualIdx = startIdx + i
        local row = p6.phraseRows[i]
        local phraseStr = pool[actualIdx]
        if phraseStr then
            row.phraseIndex = actualIdx
            local isSelected = (actualIdx == editPhraseIdx)
            local prefix = isSelected and "|cff8ab4f8> " or "|cff9aa0a6  "
            row.selectBtn:SetText(string.format("%s#%d: |r%s", prefix, actualIdx, phraseStr))
            row.selectBtn:SetTone(isSelected and "PRIMARY" or nil)
            row.selectBtn:Show()
            row.delBtn:Show()
        else
            row.selectBtn:Hide()
            row.delBtn:Hide()
        end
    end

    if not p6.phraseBox:HasFocus() then
        p6.phraseBox:SetCleanText(pool[editPhraseIdx] or "")
    end
end

local function RefreshProfilesTab()
    local pProf = tabPanels[5]
    if not pProf or not pProf.rows or not ns.db or not ns.db.profiles then return end

    local ids = {}
    for id in pairs(ns.db.profiles) do
        table.insert(ids, id)
    end
    table.sort(ids, function(a, b)
        local na = string.lower((ns.db.profiles[a] and ns.db.profiles[a].profileName) or a)
        local nb = string.lower((ns.db.profiles[b] and ns.db.profiles[b].profileName) or b)
        return na < nb
    end)

    local perPage = 6
    local totalPages = math.max(1, math.ceil(#ids / perPage))
    profileListPage = math.max(1, math.min(totalPages, profileListPage))
    pProf.pageLabel:SetText(string.format("Page %d / %d", profileListPage, totalPages))

    local startIdx = (profileListPage - 1) * perPage
    for i = 1, perPage do
        local row = pProf.rows[i]
        local profId = ids[startIdx + i]
        if profId and ns.db.profiles[profId] then
            local prof = ns.db.profiles[profId]
            local isActive = (profId == ns.activeProfileId)
            local pLabel = prof.profileName or profId
            local charLine = strtrim(((prof.firstName or "") .. " " .. (prof.lastName or "")))
            local summary = isActive and ("|cff81c995[ACTIVE]|r  |cfffdd663" .. pLabel .. "|r") or ("|cffe8eaed" .. pLabel .. "|r")
            if charLine ~= "" then
                summary = summary .. "  |cff9aa0a6(" .. charLine .. ")|r"
            end
            row.selectBtn.profileId = profId
            row.selectBtn:SetText(summary)
            row.selectBtn:SetTone(isActive and "MINT" or nil)
            row.selectBtn:Show()
        else
            row.selectBtn.profileId = nil
            row.selectBtn:Hide()
        end
    end
end

-- Display / LB-RB order: tabs 1-7, then Emotes (9), then Dev (8) when Developer Mode is on.
function ns:GetTabDisplayOrder()
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local order = { 1, 2, 3, 4, 5, 6, 7, 9 }
    if showDev then order[#order + 1] = 8 end
    return order
end

local function UpdateTabBarLayout()
    if not mainFrame or not tabButtons[1] then return end
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local order = ns:GetTabDisplayOrder()
    local visibleCount = #order
    local totalWidth = mainFrame:GetWidth() - 24
    local gap = 3
    local btnW = math.floor((totalWidth - (gap * (visibleCount - 1))) / visibleCount)

    for i = 1, 9 do
        if tabButtons[i] then tabButtons[i]:Hide() end
    end
    for slot, i in ipairs(order) do
        local tb = tabButtons[i]
        if tb then
            tb:SetWidth(btnW)
            tb:ClearAllPoints()
            tb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12 + (slot - 1) * (btnW + gap), -108)
            tb:Show()
        end
    end

    if not showDev and activeTab == 8 then
        ns:SelectTab(7)
    end
end

function ns:RefreshNetInspector(newLine)
    if not inspectorFrame then return end

    local _, knownCount = BuildDirectoryRows()
    local engineLabel = (type(_G.msp) == "table") and "|cff81c995LibMSP|r" or "|cfff28b82Missing LibMSP|r"
    inspectorFrame.statusBar:SetText(string.format(
        "Engine: %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
        engineLabel,
        (ns.mspStats and ns.mspStats.sent) or 0,
        (ns.mspStats and ns.mspStats.liveReplies) or 0,
        knownCount,
        (ns.mspStats and ns.mspStats.lastReplyFrom) or "None"
    ))

    inspectorFrame.chkDebug:SetText(FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
    inspectorFrame.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)

    inspectorFrame.chkSniff:SetText(FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
    inspectorFrame.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)

    inspectorFrame.chkEcho:SetText(FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
    inspectorFrame.chkEcho:SetTone(ns.mspEchoChat and "PRIMARY" or nil)

    if newLine and inspectorFrame.msgFrame then
        inspectorFrame.msgFrame:AddMessage(newLine)
    end
    if inspectorFrame.copyEditor and inspectorFrame.copyEditor:IsShown() then
        inspectorFrame.copyEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
    end
end

local function InitNetInspectorWindow()
    if inspectorFrame then return end
    local M3 = ns.M3

    inspectorFrame = CreateFrame("Frame", "PadRP_NetInspector", UIParent, "BackdropTemplate")
    inspectorFrame:SetSize(540, 340)
    inspectorFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -110)
    inspectorFrame:SetFrameStrata("HIGH")
    inspectorFrame:SetMovable(true)
    inspectorFrame:EnableMouse(true)
    inspectorFrame:RegisterForDrag("LeftButton")
    inspectorFrame:SetScript("OnDragStart", inspectorFrame.StartMoving)
    inspectorFrame:SetScript("OnDragStop", inspectorFrame.StopMovingOrSizing)
    ns:ApplySurface(inspectorFrame, M3.surfaceDim, M3.primary)
    ns:EnableClipping(inspectorFrame)
    inspectorFrame:Hide()

    local title = inspectorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("|cff8ab4f8PADRP NETWORK & WIRE INSPECTOR|r  |cff9aa0a6(Noise-Free Console)|r")

    local closeBtn = ns:CreateMaterialButton(inspectorFrame, "X", 28, 24, 504, -6, "CORAL", function()
        inspectorFrame:Hide()
    end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", inspectorFrame, "TOPRIGHT", -8, -6)

    inspectorFrame.statusBar = inspectorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    inspectorFrame.statusBar:SetPoint("TOPLEFT", 12, -30)
    inspectorFrame.statusBar:SetPoint("TOPRIGHT", -12, -30)
    inspectorFrame.statusBar:SetJustifyH("LEFT")

    inspectorFrame.chkDebug = ns:CreateMaterialButton(inspectorFrame, "", 132, 24, 12, -48, nil, function()
        ns.mspDebug = not ns.mspDebug
        ns:LogNet("CONFIG", "ff81c995", "Debug Events: " .. (ns.mspDebug and "ENABLED" or "DISABLED"))
        ns:RefreshNetInspector()
        ns:RefreshControllerUI()
    end)

    inspectorFrame.chkSniff = ns:CreateMaterialButton(inspectorFrame, "", 132, 24, 150, -48, nil, function()
        ns.mspSniff = not ns.mspSniff
        if ns.mspSniff then ns.mspDebug = true end
        ns:LogNet("CONFIG", "fffdd663", "Raw Wire Sniffer: " .. (ns.mspSniff and "ENABLED" or "DISABLED"))
        ns:RefreshNetInspector()
        ns:RefreshControllerUI()
    end)

    inspectorFrame.chkEcho = ns:CreateMaterialButton(inspectorFrame, "", 132, 24, 288, -48, nil, function()
        ns.mspEchoChat = not ns.mspEchoChat
        ns:RefreshNetInspector()
        ns:RefreshControllerUI()
    end)

    inspectorFrame.copyBtn = ns:CreateMaterialButton(inspectorFrame, "Copy Log", 102, 24, 426, -48, nil, function(self)
        if inspectorFrame.copyEditor:IsShown() then
            inspectorFrame.copyEditor:Hide()
            inspectorFrame.feedBox:Show()
            self:SetText("Copy Log")
        else
            inspectorFrame.feedBox:Hide()
            inspectorFrame.copyEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
            inspectorFrame.copyEditor:Show()
            inspectorFrame.copyEditor.editBox:HighlightText()
            inspectorFrame.copyEditor.editBox:SetFocus()
            self:SetText("Live Feed")
        end
    end)

    local feedBox = CreateFrame("Frame", nil, inspectorFrame, "BackdropTemplate")
    feedBox:SetPoint("TOPLEFT", 12, -78)
    feedBox:SetPoint("BOTTOMRIGHT", -12, 42)
    ns:ApplySurface(feedBox, M3.surfaceLow, M3.outline)
    ns:EnableClipping(feedBox)
    inspectorFrame.feedBox = feedBox

    local msgFrame = CreateFrame("ScrollingMessageFrame", nil, feedBox)
    msgFrame:SetPoint("TOPLEFT", 10, -8)
    msgFrame:SetPoint("BOTTOMRIGHT", -10, 8)
    msgFrame:SetFontObject("ChatFontSmall")
    msgFrame:SetJustifyH("LEFT")
    msgFrame:SetFading(false)
    msgFrame:SetMaxLines(250)
    msgFrame:EnableMouseWheel(true)
    msgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    inspectorFrame.msgFrame = msgFrame

    local copyEditor = ns:CreateScrollableTextEditor(inspectorFrame, "No log entries yet.", 12, -78, 516, 220)
    copyEditor:Hide()
    inspectorFrame.copyEditor = copyEditor

    ns:CreateMaterialButton(inspectorFrame, "Query Target", 122, 26, 12, -306, "PRIMARY", function()
        if UnitExists("target") and UnitIsPlayer("target") then
            ns:RequestUnitMSP("target", true, true)
        elseif ns.lastInspectedKey then
            ns:RequestUnitMSP(ns.lastInspectedKey, true, true)
        else
            ns:LogNet("WARN", "fff28b82", "No player targeted to query.")
        end
    end)

    ns:CreateMaterialButton(inspectorFrame, "Run Self-Test", 122, 26, 142, -306, "AMBER", function()
        ns:RunMSPSelfTest()
    end)

    ns:CreateMaterialButton(inspectorFrame, "Clear Log", 126, 26, 272, -306, "CORAL", function()
        wipe(ns.netLogs)
        msgFrame:Clear()
        ns:LogNet("CLEAR", "ff9aa0a6", "Log cleared.")
    end)

    for _, line in ipairs(ns.netLogs or {}) do
        msgFrame:AddMessage(line)
    end
end

function ns:ToggleNetInspector(forceShow)
    InitNetInspectorWindow()
    if forceShow or not inspectorFrame:IsShown() then
        inspectorFrame:Show()
        ns:RefreshNetInspector()
    else
        inspectorFrame:Hide()
    end
end

local function CloseAnyOpenPopup()
    if not mainFrame then return false end
    if ns.dossierFrame and ns.dossierFrame.standingDropdown and ns.dossierFrame.standingDropdown:IsShown() then
        ns.dossierFrame.standingDropdown:Hide()
        if ns.dossierFrame.standingBtn then ns:SetControllerFocus(ns.dossierFrame.standingBtn) end
        return true
    end
    if mainFrame.expDropdown and mainFrame.expDropdown:IsShown() then
        mainFrame.expDropdown:Hide()
        if mainFrame.bannerExpBtn then ns:SetControllerFocus(mainFrame.bannerExpBtn) end
        return true
    end
    if mainFrame.presetDropdown and mainFrame.presetDropdown:IsShown() then
        mainFrame.presetDropdown:Hide()
        if tabPanels[1] and tabPanels[1].presetBtn then ns:SetControllerFocus(tabPanels[1].presetBtn) end
        return true
    end
    if mainFrame.modeDropdown and mainFrame.modeDropdown:IsShown() then
        mainFrame.modeDropdown:Hide()
        if tabPanels[6] and tabPanels[6].modeBtn then ns:SetControllerFocus(tabPanels[6].modeBtn) end
        return true
    end
    if mainFrame.poolDropdown and mainFrame.poolDropdown:IsShown() then
        mainFrame.poolDropdown:Hide()
        if tabPanels[6] and tabPanels[6].poolToggleBtn then ns:SetControllerFocus(tabPanels[6].poolToggleBtn) end
        return true
    end
    if mainFrame.iconPicker and mainFrame.iconPicker:IsShown() then
        local returnTarget = mainFrame.iconPicker.returnFocusWidget
        mainFrame.iconPicker:Hide()
        if returnTarget and returnTarget:IsVisible() then
            ns:SetControllerFocus(returnTarget)
        else
            ns:FocusFirstInScope()
        end
        return true
    end
    if mainFrame.exportModal and mainFrame.exportModal:IsShown() then
        mainFrame.exportModal:Hide()
        ns:FocusFirstInScope()
        return true
    end
    return false
end

function ns:ControllerConfirmAction()
    local scope = ns:GetActiveModalScope()
    if not scope or not ns:CanProcessPadAction() then return end

    if scope == ns.hudFrame and ns.OpenTargetDossier then
        ns:OpenTargetDossier(ns.hudFrame.inspectedKey)
        return
    end

    local now = (GetTime and GetTime()) or 0
    local activeBox = ns.activeEditBox
    if activeBox and activeBox.HasFocus and activeBox:HasFocus() then
        if (now - (lastEditFocusTime or 0)) < 0.25 then
            return
        end
        activeBox:ClearFocus()
        return
    end

    local cur = ns.currentFocus
    if not cur or not cur:IsVisible() then
        ns:FocusFirstInScope()
        return
    end

    if cur == lastConfirmTarget and (now - (lastConfirmTime or 0)) < 0.18 then
        return
    end
    lastConfirmTime = now
    lastConfirmTarget = cur

    if cur.GetObjectType and cur:GetObjectType() == "EditBox" then
        lastEditFocusTime = now
        if cur.SetFocus then cur:SetFocus() end
        return
    end

    if cur.ActivateFromPad then
        cur:ActivateFromPad()
    elseif cur.Click then
        cur:Click("LeftButton")
    end

    if cur and cur:IsVisible() and ns:GetActiveModalScope() == scope then
        ns:SetControllerFocus(cur)
    end
end

function ns:ControllerCancelAction()
    local scope = ns:GetActiveModalScope()
    if not scope or not ns:CanProcessPadAction() then return end
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
        return
    end
    if CloseAnyOpenPopup() then
        ns:PlayUISound()
        return
    end
    if ns.dossierFrame and ns.dossierFrame:IsShown() then
        ns.dossierFrame:Hide()
        return
    end
    if scope == ns.hudFrame then
        if ns.DismissTargetHUDFocus then
            ns:DismissTargetHUDFocus()
        elseif ns.SetControllerFocus then
            ns:SetControllerFocus(nil)
        end
        return
    end
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    end
end

function ns:CycleTab(delta)
    if not ns:CanProcessPadAction() then return end
    if ns.dossierFrame and ns.dossierFrame:IsShown() and ns.CycleDossierTab then
        ns:CycleDossierTab(delta)
        return
    end
    if not mainFrame or not mainFrame:IsShown() then return end
    if mainFrame.iconPicker and mainFrame.iconPicker:IsShown() then
        mainFrame.iconPicker:StepPage(delta)
        return
    end
    local order = ns:GetTabDisplayOrder()
    local pos = 1
    for i, tabIdx in ipairs(order) do
        if tabIdx == activeTab then pos = i break end
    end
    ns:SelectTab(order[((pos - 1 + delta) % #order) + 1])
end

local function GetActiveGratitudePool()
    local g = ns.db.gratitude
    local item = POOL_LIST[editPoolIdx] or POOL_LIST[1]
    if item.key == "IC" then return g.icPhrases
    elseif item.key == "OOC" then return g.oocPhrases
    elseif item.key == "RES" then return g.resPhrases
    elseif item.key == "SUMMON" then return g.summonPhrases
    elseif item.key == "SPECIAL" then return g.specialPhrases end
    return g.icPhrases
end

local function LoadAllGlancesIntoUI()
    local p2 = tabPanels[2]
    if not p2 or not p2.cards or not ns.profile then return end
    local p = ns.profile
    local fallbackIcon = GetDefaultIconFallback()
    local placeholders = {
        { title = "e.g., Singed Cuffs",   detail = "e.g., Faint arcane scorch marks line the hems of his sleeves." },
        { title = "e.g., Worn Satchel",   detail = "e.g., Stuffed with rolled parchment, ink vials, and dried herbs." },
        { title = "e.g., Silver Signet",  detail = "e.g., A tarnished ring bearing an unfamiliar river-crest." },
        { title = "e.g., Steady Voice",   detail = "e.g., Speaks with a calm, measured cadence even under pressure." },
        { title = "e.g., Travel Cloak",   detail = "e.g., Weathered dark wool dusted with road ash from afar." },
    }

    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local g = p.glances[slot] or { icon = fallbackIcon, title = "", detail = "" }
            card.slotIndex = slot
            card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. slot .. "|r")
            SetIconTextureSafe(card.iconTex, g.icon, fallbackIcon)
            card.titleBox.placeholder:SetText(placeholders[slot].title)
            card.detailBox.placeholder:SetText(placeholders[slot].detail)
            card.titleBox:SetCleanText(g.title)
            card.detailBox:SetCleanText(g.detail)
            card:Show()
        end
    end
end

function ns:LoadProfileIntoUI()
    if not mainFrame or not ns.profile then return end
    local p = ns.profile
    EnsureTopicConsentTable()
    local p1 = tabPanels[1]
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
    if tabPanels[5] and tabPanels[5].profNameBox then
        tabPanels[5].profNameBox:SetCleanText(p.profileName)
    end
    RefreshEyeSwatchBox()
    RefreshClassSwatchBox()
    LoadAllGlancesIntoUI()
    local p3 = tabPanels[3]
    if p3 and p3.bioEditor then
        p3.bioEditor:SetCleanText(activeBioMode == "APPEARANCE" and p.description or p.history)
    end
end

local function CommitModifiedBoxesToProfile(forceAll)
    if not ns.profile or not mainFrame then return false end
    local p = ns.profile
    EnsureTopicConsentTable()
    local changed = false
    local p1 = tabPanels[1]
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

    local pProf = tabPanels[5]
    if pProf and pProf.profNameBox and (forceAll or pProf.profNameBox.isDirty) then
        local pName = strtrim(pProf.profNameBox:GetText() or "")
        if pName ~= "" then p.profileName = pName end
        pProf.profNameBox.isDirty = false
        changed = true
    end

    local p2 = tabPanels[2]
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

    local p3 = tabPanels[3]
    if p3 and p3.bioEditor and (forceAll or p3.bioEditor.isDirty) then
        local text = p3.bioEditor:GetText()
        if activeBioMode == "APPEARANCE" then p.description = text else p.history = text end
        p3.bioEditor.isDirty = false
        changed = true
    end

    if changed then
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        SyncSelfProfileToLocalCache()
    end
    return changed
end

function ns:SelectTab(index)
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
    end
    CommitModifiedBoxesToProfile(false)
    activeTab = index
    local M3 = ns.M3
    for i, panel in ipairs(tabPanels) do
        local tb = tabButtons[i]
        if i == index then
            panel:Show()
            tb:SetBackdropColor(unpack(M3.primaryTonal))
            tb.activeBar:Show()
            tb.label:SetTextColor(0.82, 0.90, 1.0)
        else
            panel:Hide()
            tb:SetBackdropColor(unpack(M3.surfaceLow))
            tb.activeBar:Hide()
            tb.label:SetTextColor(0.60, 0.64, 0.70)
        end
    end
    CloseAnyOpenPopup()
    ns:RefreshControllerUI()
    ns:FocusFirstInScope()
end

local function RefreshHeaderBanner()
    if not mainFrame or not ns.profile then return end
    local p = ns.profile
    local M3 = ns.M3
    local activeHex = GetPlayerActiveClassColorHex()
    local fallbackIcon = GetDefaultIconFallback()

    if mainFrame.portraitTex then
        SetIconTextureSafe(mainFrame.portraitTex, p.icon, fallbackIcon)
    end

    local nameParts = {}
    if p.titlePrefix and strtrim(p.titlePrefix) ~= "" then table.insert(nameParts, strtrim(p.titlePrefix)) end
    local baseFirst = (p.firstName and p.firstName ~= "") and p.firstName or UnitName("player")
    table.insert(nameParts, baseFirst)
    if p.lastName and strtrim(p.lastName) ~= "" then table.insert(nameParts, strtrim(p.lastName)) end
    local fullName = table.concat(nameParts, " ")

    mainFrame.bannerName:SetText("|c" .. activeHex .. fullName .. "|r")

    local guildVis = GetTopicConsentValue("guild", "Do not show")
    local wowGuild = (guildVis == "Yes" and GetGuildInfo and GetGuildInfo("player")) or ""
    local houseClean = (p.houseName and strtrim(p.houseName)) or ""
    local guildPart = ""
    if wowGuild ~= "" and string.lower(wowGuild) ~= string.lower(houseClean) then
        guildPart = "  |cff81c995<" .. wowGuild .. ">|r"
    end

    local titlePart = (p.title and p.title ~= "") and ("|cfffdd663<" .. p.title .. ">|r") or "|cff9aa0a6No RP Title|r"
    local housePart = (houseClean ~= "") and ("  |cff8ab4f8-  " .. houseClean .. "|r") or ""
    mainFrame.bannerTitle:SetText(titlePart .. housePart .. guildPart)

    if mainFrame.bannerCurrently then
        local curClean = p.currently and strtrim(StripColorCodes(p.currently)) or ""
        if curClean ~= "" then
            local shortCur = string.sub(curClean, 1, 56)
            if #curClean > 56 then shortCur = shortCur .. "..." end
            mainFrame.bannerCurrently:SetText("|cff9aa0a6Currently:|r |cffe8eaed" .. shortCur .. "|r")
        else
            mainFrame.bannerCurrently:SetText("")
        end
    end

    mainFrame.profChip:SetText(p.profileName or "Default")

    if mainFrame.bannerExpBtn then
        mainFrame.bannerExpBtn:SetText("|cff8ab4f8RP:|r " .. GetRPExperienceLabelText(p.rpStyle) .. " [v]")
    end

    local wuBtn = mainFrame.walkUpBtn
    if wuBtn then
        local wu = p.walkUp or "WELCOME"
        if wu == "WELCOME" then
            wuBtn:SetTone("MINT")
            wuBtn:SetText("|cff81c995WALK-UPS: OPEN|r")
        elseif wu == "ASK" then
            wuBtn:SetTone("AMBER")
            wuBtn:SetText("|cfffdd663WALK-UPS: ASK|r")
        else
            wuBtn:SetTone("CORAL")
            wuBtn:SetText("|cfff28b82WALK-UPS: OFF|r")
        end
    end

    local sw = mainFrame.icSwitch
    sw.thumb:ClearAllPoints()
    if p.isIC then
        sw:SetBackdropColor(unpack(M3.mintTonal))
        sw:SetBackdropBorderColor(unpack(M3.mint))
        sw.thumb:SetPoint("RIGHT", sw, "RIGHT", -3, 0)
        sw.thumb:SetBackdropColor(unpack(M3.mint))
        sw.thumb.label:SetText("|cff061c10IN CHARACTER|r")
        sw.bgLabel:ClearAllPoints()
        sw.bgLabel:SetPoint("LEFT", sw, "LEFT", 10, 0)
        sw.bgLabel:SetText("|cff689f78OOC|r")
    else
        sw:SetBackdropColor(unpack(M3.coralTonal))
        sw:SetBackdropBorderColor(unpack(M3.coral))
        sw.thumb:SetPoint("LEFT", sw, "LEFT", 3, 0)
        sw.thumb:SetBackdropColor(unpack(M3.coral))
        sw.thumb.label:SetText("|cff240808OUT OF CHAR|r")
        sw.bgLabel:ClearAllPoints()
        sw.bgLabel:SetPoint("RIGHT", sw, "RIGHT", -12, 0)
        sw.bgLabel:SetText("|cff9e625eIC|r")
    end
end

local function FormatDirectoryEntryText(k, d, item)
    local parts = {}
    local sep = " |cff5f6368•|r "

    if item.hasNote then
        table.insert(parts, "|TInterface\\Icons\\INV_Misc_Note_01:13:13:0:0:64:64:4:60:4:60|t")
    end
    if not item.indented and item.standing and item.standing ~= "None" then
        local bInfo
        for _, sb in ipairs(GetStandingBuckets()) do
            if string.lower(sb.key) == string.lower(item.standing) then bInfo = sb break end
        end
        if bInfo then
            table.insert(parts, "|c" .. bInfo.colorHex .. "[" .. string.upper(bInfo.label) .. "]|r")
        else
            table.insert(parts, "|cfffdd663[" .. string.upper(tostring(item.standing)) .. "]|r")
        end
    end

    local rawName = d.NA or k
    local activeHex = nil
    if IsPlayerSelfKey(k) then
        activeHex = GetPlayerActiveClassColorHex()
    elseif type(rawName) == "string" then
        local embeddedHex = string.match(rawName, "^|c(%x%x%x%x%x%x%x%x)")
        if embeddedHex then
            activeHex = embeddedHex
        end
    end

    local cleanName = StripColorCodes(rawName)
    local charOnly = strsplit("-", k)
    local realmPart = (charOnly and charOnly ~= cleanName) and (" |cff8ab4f8(" .. k .. ")|r") or ""
    local displayColor = activeHex or "ffe8eaed"
    table.insert(parts, "|c" .. displayColor .. cleanName .. "|r" .. realmPart)

    local assignedRel = ns.GetAssignedRelationship and ns:GetAssignedRelationship(k) or ""
    if assignedRel ~= "" then
        table.insert(parts, "|cfffdd663[" .. assignedRel .. "]|r")
    end

    local statusBadges = {}
    if d.FC == "2" then
        table.insert(statusBadges, "|cff81c995[IC]|r")
    elseif d.FC == "1" then
        table.insert(statusBadges, "|cfff28b82[OOC]|r")
    end

    local _, wuCode = ns:GetTargetWalkUpInfo(d)
    if wuCode == "WELCOME" then
        table.insert(statusBadges, "|cff81c995[WU]|r")
    elseif wuCode == "ASK" then
        table.insert(statusBadges, "|cfffdd663[Ask]|r")
    elseif wuCode == "CLOSED" then
        table.insert(statusBadges, "|cfff28b82[Off]|r")
    end

    if UnitInRaid and UnitInRaid(k) then
        table.insert(statusBadges, "|cfffdd663[Raid]|r")
    elseif UnitInParty and UnitInParty(k) then
        table.insert(statusBadges, "|cff8ab4f8[Party]|r")
    end

    if #statusBadges > 0 then
        table.insert(parts, table.concat(statusBadges, " "))
    end

    local titleClean = d.NT and strtrim(StripColorCodes(d.NT)) or ""
    local guildClean = d.NH and strtrim(StripColorCodes(d.NH)) or ""
    local curClean = d.CU and strtrim(StripColorCodes(d.CU)) or ""

    if titleClean ~= "" then
        table.insert(parts, "|cfffdd663<" .. titleClean .. ">|r")
    end
    if guildClean ~= "" then
        table.insert(parts, "|cff8ab4f8{" .. guildClean .. "}|r")
    end
    if curClean ~= "" then
        local shortCur = string.sub(curClean, 1, 34)
        if #curClean > 34 then shortCur = shortCur .. "..." end
        table.insert(parts, "|cff9aa0a6\"" .. shortCur .. "\"|r")
    end

    local prefix = item.indented and "  - " or ""
    return prefix .. table.concat(parts, sep)
end

function ns:RefreshTargetCard()
    if not mainFrame or not tabPanels[4] then return end
    local p4 = tabPanels[4]

    local rows, totalEntries = BuildDirectoryRows()
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#rows / perPage))
    if knownListPage > totalPages then knownListPage = totalPages end
    if knownListPage < 1 then knownListPage = 1 end

    local bucketLabel = knownNotableOnly and "NOTABLE ACCORDION" or "RP DIRECTORY"
    p4.countLabel:SetText(string.format("|cff8ab4f8%s (%d)|r  -  Select any player to open Dossier & Notes", bucketLabel, totalEntries))
    p4.pageLabel:SetText(string.format("Page %d / %d", knownListPage, totalPages))

    p4.notableOnlyBtn:SetText(FormatCheckbox("Notable", knownNotableOnly, "fffdd663"))
    p4.notableOnlyBtn:SetTone(knownNotableOnly and "AMBER" or nil)
    p4.sortBtn:SetText(knownSortMode == "RECENT" and "Sort: Recent" or "Sort: A-Z")
    p4.sortBtn:SetTone(knownSortMode == "RECENT" and "PRIMARY" or nil)

    local startIdx = (knownListPage - 1) * perPage
    for i = 1, perPage do
        local rowBtn = p4.knownRows[i]
        local item = rows[startIdx + i]
        if item then
            if item.kind == "HEADER" then
                rowBtn.profileKey = nil
                rowBtn.bucketKey = item.bucketKey
                rowBtn:SetTone(item.tone)
                rowBtn:SetText(item.text)
                rowBtn.seenLabel:SetText("")
            else
                rowBtn.profileKey = item.key
                rowBtn.bucketKey = nil
                rowBtn:SetTone(nil)
                rowBtn:SetText(FormatDirectoryEntryText(item.key, item.data, item))
                local seenStr = (item.lastSeen and item.lastSeen > 0) and date("%m/%d %H:%M", item.lastSeen) or "--/--"
                rowBtn.seenLabel:SetText("|cff9aa0a6" .. seenStr .. "|r")
            end
            rowBtn:Show()
        else
            rowBtn.profileKey = nil
            rowBtn.bucketKey = nil
            rowBtn.seenLabel:SetText("")
            rowBtn:Hide()
        end
    end
end

function ns:TrySeamlessDirectoryStep(rowIndex, dir)
    if activeTab ~= 4 then return false end
    local p4 = tabPanels[4]
    if not p4 or not p4:IsShown() or not p4.knownRows then return false end

    local rows = BuildDirectoryRows()
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#rows / perPage))

    local lastShownIdx = 0
    for i = 1, perPage do
        if p4.knownRows[i] and p4.knownRows[i]:IsShown() then
            lastShownIdx = i
        end
    end
    if lastShownIdx == 0 then return false end

    if dir == "DOWN" and rowIndex >= lastShownIdx and knownListPage < totalPages then
        knownListPage = knownListPage + 1
        ns:RefreshTargetCard()
        ns:PlayUISound()
        if p4.knownRows[1] and p4.knownRows[1]:IsShown() then
            ns:SetControllerFocus(p4.knownRows[1])
        end
        return true
    elseif dir == "UP" and rowIndex <= 1 and knownListPage > 1 then
        knownListPage = knownListPage - 1
        ns:RefreshTargetCard()
        ns:PlayUISound()
        local targetRow = p4.knownRows[perPage]
        if targetRow and targetRow:IsShown() then
            ns:SetControllerFocus(targetRow)
        end
        return true
    end
    return false
end

local function RefreshGratitudeStudio()
    local p6 = tabPanels[6]
    if not p6 then return end
    local g = ns.db.gratitude

    p6.modeBtn:SetText("|cff9aa0a6GRATITUDE MODE:|r   |cff8ab4f8" .. ns:GetGratitudeModeLabel() .. "|r   |cfffdd663[Open Dropdown v]|r")
    p6.buffBtn:SetText("Buffs: " .. (g.thankBuffs and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.healBtn:SetText("Heals: " .. (g.thankHeals and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.resBtn:SetText("Res: " .. (g.thankRes and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.specialBtn:SetText("Portals/CDs: " .. (g.thankSpecial and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.sessionBtn:SetText("1x/Session: " .. (g.oncePerSession and "|cff81c995ON|r" or "|cff9aa0a6OFF|r"))
    p6.cdLabel:SetText(string.format("Cooldown: |cfffdd663%ds|r", g.cooldown or 60))
    p6.healPctLabel:SetText(string.format("Min Heal: |cfffdd663%d%% HP|r", g.minHealPercent or 15))

    local pool = GetActiveGratitudePool()
    if #pool == 0 then table.insert(pool, "thanks %name for the %spell.") end
    if editPhraseIdx > #pool then editPhraseIdx = #pool end
    if editPhraseIdx < 1 then editPhraseIdx = 1 end

    local totalPages = math.max(1, math.ceil(#pool / 3))
    phrasePage = math.min(totalPages, math.ceil(editPhraseIdx / 3))

    local poolItem = POOL_LIST[editPoolIdx] or POOL_LIST[1]
    p6.poolToggleBtn:SetText("|cff9aa0a6PHRASE POOL:|r  |cfffdd663" .. poolItem.label .. "|r  |cff8ab4f8[v]|r")
    p6.phrasePageLabel:SetText(string.format("Page %d/%d (%d)", phrasePage, totalPages, #pool))

    local startIdx = (phrasePage - 1) * 3
    for i = 1, 3 do
        local actualIdx = startIdx + i
        local row = p6.phraseRows[i]
        local phraseStr = pool[actualIdx]
        if phraseStr then
            row.phraseIndex = actualIdx
            local isSelected = (actualIdx == editPhraseIdx)
            local prefix = isSelected and "|cff8ab4f8> " or "|cff9aa0a6  "
            row.selectBtn:SetText(string.format("%s#%d: |r%s", prefix, actualIdx, phraseStr))
            row.selectBtn:SetTone(isSelected and "PRIMARY" or nil)
            row.selectBtn:Show()
            row.delBtn:Show()
        else
            row.selectBtn:Hide()
            row.delBtn:Hide()
        end
    end

    if not p6.phraseBox:HasFocus() then
        p6.phraseBox:SetCleanText(pool[editPhraseIdx] or "")
    end
end

function ns:RefreshControllerUI()
    if not mainFrame or not ns.profile then return end
    mainFrame:SetScale(ns.db.ui.scale or 1.0)
    UpdateTabBarLayout()
    UpdateResponsiveLayouts()
    RefreshHeaderBanner()

    local p = ns.profile
    EnsureTopicConsentTable()
    local p1 = tabPanels[1]
    p1.subTabCore:SetTone(activeIdentityPage == 1 and "PRIMARY" or nil)
    p1.subTabVitals:SetTone(activeIdentityPage == 2 and "PRIMARY" or nil)
    p1.subTabExtras:SetTone(activeIdentityPage == 3 and "PRIMARY" or nil)
    p1.pageCore:SetShown(activeIdentityPage == 1)
    p1.pageVitals:SetShown(activeIdentityPage == 2)
    p1.pageExtras:SetShown(activeIdentityPage == 3)

    local function SyncBox(box, val)
        if box and not box:HasFocus() and not box.isDirty then
            box:SetCleanText(val)
        end
    end
    SyncBox(p1.pxBox, p.titlePrefix)
    SyncBox(p1.fnBox, p.firstName)
    SyncBox(p1.lnBox, p.lastName)
    SyncBox(p1.tiBox, p.title)
    SyncBox(p1.raBox, p.race)
    SyncBox(p1.clBox, p.class)
    SyncBox(p1.gnBox, p.gender)
    SyncBox(p1.prBox, p.pronouns)
    SyncBox(p1.agBox, p.age)
    SyncBox(p1.htBox, p.height)
    SyncBox(p1.wtBox, p.weight)
    SyncBox(p1.eyBox, p.eyeColor)
    SyncBox(p1.cuBox, p.currently)
    SyncBox(p1.oocNotesBox, p.oocNotes or p.oocInfo)

    RefreshEyeSwatchBox()
    RefreshClassSwatchBox()

    SyncBox(p1.hoBox, p.houseName)
    SyncBox(p1.moBox, p.motto)
    SyncBox(p1.hbBox, p.birthplace)
    SyncBox(p1.hhBox, p.residence)
    SyncBox(p1.faceBox, p.facialFeatures)
    SyncBox(p1.tatBox, p.tattoos)
    SyncBox(p1.voiceBox, p.voiceReference)

    if tabPanels[5] and tabPanels[5].profNameBox then
        SyncBox(tabPanels[5].profNameBox, p.profileName)
    end

    p1.relBtn:SetText("Relationship: |cfffdd663" .. ns:GetRelationshipLabel(p.relationship) .. "|r")
    p1.styleBtn:SetText("RP Style: |cff8ab4f8" .. GetRPExperienceLabelText(p.rpStyle) .. "|r")
    local fallbackIcon = GetDefaultIconFallback()
    if p1.portraitPickBtn then
        SetIconTextureSafe(p1.portraitPickBtn.iconTex, p.icon, fallbackIcon)
        p1.portraitPickBtn:SetText("Portrait")
    end

    if p1.topicBtns then
        for _, t in ipairs(RP_STYLE_TOPICS) do
            local btn = p1.topicBtns[t.key]
            if btn then
                local curVal = GetTopicConsentValue(t.key, t.defaultVal)
                btn:SetText(FormatTopicButtonText(t.label, curVal))
            end
        end
    end

    if p1.lgbtqBtn then
        p1.lgbtqBtn:SetText(FormatCheckbox("LGBTQIA2S+ Friendly", p.lgbtqFriendly ~= false, "ff81c995"))
        p1.lgbtqBtn:SetTone(p.lgbtqFriendly ~= false and "MINT" or nil)
    end
    if p1.erpBtn then
        p1.erpBtn:SetText(FormatCheckbox("ERP Friendly", p.erpFriendly and true or false, "fffdd663"))
        p1.erpBtn:SetTone(p.erpFriendly and "AMBER" or nil)
    end
    if p1.mdniBtn then
        p1.mdniBtn:SetText(FormatCheckbox("MDNI (Minors Do Not Interact)", p.mdni and true or false, "fff28b82"))
        p1.mdniBtn:SetTone(p.mdni and "CORAL" or nil)
    end

    RefreshProfilesTab()

    local p2 = tabPanels[2]
    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local g = p.glances[slot] or { icon = fallbackIcon, title = "", detail = "" }
            SetIconTextureSafe(card.iconTex, g.icon, fallbackIcon)
            if not card.titleBox:HasFocus() and not card.titleBox.isDirty then card.titleBox:SetCleanText(g.title) end
            if not card.detailBox:HasFocus() and not card.detailBox.isDirty then card.detailBox:SetCleanText(g.detail) end
        end
    end

    local p3 = tabPanels[3]
    if activeBioMode == "APPEARANCE" then
        p3.appTabBtn:SetTone("PRIMARY")
        p3.hisTabBtn:SetTone(nil)
        p3.sectionHint:SetText("|cff8ab4f8PHYSICAL APPEARANCE:|r Describe your character's build, attire, voice, and demeanor.")
        p3.bioEditor:SetPlaceholder("Write your character's physical appearance here...")
        if not p3.bioEditor:HasFocus() and not p3.bioEditor.isDirty then p3.bioEditor:SetCleanText(p.description) end
    else
        p3.hisTabBtn:SetTone("PRIMARY")
        p3.appTabBtn:SetTone(nil)
        p3.sectionHint:SetText("|cff8ab4f8CHARACTER HISTORY & BACKGROUND:|r Write your character's origins, homeland, and story.")
        p3.bioEditor:SetPlaceholder("Write your character's backstory and history here...")
        if not p3.bioEditor:HasFocus() and not p3.bioEditor.isDirty then p3.bioEditor:SetCleanText(p.history) end
    end

    ns:RefreshTargetCard()
    RefreshGratitudeStudio()

    local p7 = tabPanels[7]
    local curW, curH = math.floor(mainFrame:GetWidth() + 0.5), math.floor(mainFrame:GetHeight() + 0.5)
    p7.scaleLabel:SetText(string.format("Scale: |cfffdd663%.0f%%|r  (|cff8ab4f8%dx%d|r)", (ns.db.ui.scale or 1.0) * 100, curW, curH))
    p7.minimapBtn:SetText(FormatCheckbox("Minimap Icon", ns.db.ui.showMinimap, "ff81c995"))
    p7.hudBtn:SetText(FormatCheckbox("Toast Notification (Target HUD)", ns.db.ui.showTargetHUD ~= false, "ff81c995"))
    p7.hudRPBtn:SetText(FormatCheckbox("TRP3-Style Player Tooltip", ns.db.ui.rpTooltip, "ff8ab4f8"))
    p7.npClassBtn:SetText(FormatCheckbox("Class-Color Nameplates", ns.db.ui.nameplateClassColors, "ff8ab4f8"))
    p7.npTagBtn:SetText(FormatCheckbox("Nameplate OOC | IC", ns.db.ui.nameplateStatusTags ~= false, "ff81c995"))
    p7.npRPNameBtn:SetText(FormatCheckbox("RP Names on Nameplates", ns.db.ui.nameplateRPNames, "ff8ab4f8"))
    if p7.npCircleBtn then
        p7.npCircleBtn:SetText(FormatCheckbox("Nameplate Standing Circle", ns.db.ui.nameplateStandingCircle ~= false, "fffdd663"))
    end
    p7.combatBtn:SetText(FormatCheckbox("Auto-Hide in Combat", ns.db.ui.hideInCombat, "ff81c995"))
    p7.soundBtn:SetText(FormatCheckbox("UI Sound Effects", ns.db.ui.soundEffects, "ff81c995"))
    p7.partyBtn:SetText(FormatCheckbox("Ignore Party/Raid Buffs", ns.db.gratitude.ignoreParty, "ff81c995"))
    p7.rpNameBtn:SetText(FormatCheckbox("Thank Helper RP Name", ns.db.gratitude.useRPNames, "ff81c995"))
    p7.chatRPBtn:SetText(FormatCheckbox("Show [RP Names] in Chat", ns.db.ui.chatRPNames, "ff81c995"))
    p7.afkOOCBtn:SetText(FormatCheckbox("Auto-OOC When AFK", ns.db.ui.autoAFKOOC, "ff81c995"))

    p7.devModeBtn:SetText(FormatCheckbox("Developer Mode (Show Dev Tab)", ns.db.ui.devMode, "fffdd663"))
    p7.devModeBtn:SetTone(ns.db.ui.devMode and "AMBER" or nil)

    local p8 = tabPanels[8]
    if p8 and p8.diagText and ns.mspStats then
        local engState = (type(_G.msp) == "table") and "|cff81c995LibMSP ACTIVE|r" or "|cfff28b82LibMSP MISSING|r"
        p8.diagText:SetText(string.format(
            "|cff8ab4f8ENGINE:|r %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
            engState,
            ns.mspStats.sent or 0,
            ns.mspStats.liveReplies or 0,
            select(2, BuildDirectoryRows()),
            ns.mspStats.lastReplyFrom or "None"
        ))
        p8.chkDebug:SetText(FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
        p8.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)
        p8.chkSniff:SetText(FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
        p8.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)
        p8.chkEcho:SetText(FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
        p8.chkEcho:SetTone(ns.mspEchoChat and "PRIMARY" or nil)
        p8.logEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
    end

    if inspectorFrame and inspectorFrame:IsShown() then
        ns:RefreshNetInspector()
    end
end

function ns:SetWindowDimensions(w, h)
    if not mainFrame then return end
    w = math.max(660, math.min(1050, w or 680))
    h = math.max(540, math.min(840, h or 560))
    ns.db.ui.width, ns.db.ui.height = w, h
    mainFrame:SetSize(w, h)
    ns:RefreshControllerUI()
end

function ns:ToggleMainFrame()
    if not mainFrame then return end

    if mainFrame:IsShown() then
        mainFrame:Hide()
        return
    end

    if ns.LoadProfileIntoUI then
        ns:LoadProfileIntoUI()
    end
    if ns.RefreshControllerUI then
        ns:RefreshControllerUI()
    end

    mainFrame:Show()
end

local function PersistColorSelection(mode, hex6, returnWidget)
    if not ns.profile or not hex6 then return end
    local now = (GetTime and GetTime()) or 0
    if (now - (lastPickerApplyTime or 0)) < 0.25 then return end
    lastPickerApplyTime = now
    pickerReopenGuardUntil = now + 0.45

    if mode == "EYE" then
        ns.profile.eyeColorHex = hex6
        RefreshEyeSwatchBox()
    else
        ns.profile.classColorHex = hex6
        ns.profile.nameColorHex = hex6
        RefreshClassSwatchBox()
        RefreshHeaderBanner()
        ns:RefreshTargetCard()
    end
    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
    if ns.SyncMSP then ns:SyncMSP() end
    SyncSelfProfileToLocalCache()
    local label = (mode == "EYE") and "Eye color" or "Class & Name color"
    ns:ShowStatusToast(label .. " set to #" .. string.upper(hex6))
    if returnWidget and returnWidget:IsVisible() then
        ns:SetControllerFocus(returnWidget)
    end
end

local function OpenNativeColorPicker(mode, returnWidget)
    if not ColorPickerFrame or not ns.profile then return end
    local now = (GetTime and GetTime()) or 0
    if now < (pickerReopenGuardUntil or 0) or (ColorPickerFrame.IsShown and ColorPickerFrame:IsShown()) then
        return
    end
    pickerReopenGuardUntil = now + 0.25

    local prevHex
    if mode == "EYE" then
        prevHex = NormalizeHex6(ns.profile.eyeColorHex or ns.profile.eyeColor)
    else
        prevHex = NormalizeHex6(ns.profile.classColorHex or ns.profile.nameColorHex)
    end
    local startHex = prevHex or GetWoWClassHex6()
    local r, g, b = HexToRGB(startHex)
    local liveHex6 = startHex
    local openedAt = now
    local userMovedColor = false
    local wasCancelled = false

    local function ApplyLiveRGB(nr, ng, nb, fromUser)
        if fromUser then
            userMovedColor = true
        end
        liveHex6 = RGBToHex6(nr, ng, nb)
        if mode == "EYE" then
            ns.profile.eyeColorHex = liveHex6
            RefreshEyeSwatchBox()
        else
            ns.profile.classColorHex = liveHex6
            ns.profile.nameColorHex = liveHex6
            RefreshClassSwatchBox()
            RefreshHeaderBanner()
            ns:RefreshTargetCard()
        end
        SyncSelfProfileToLocalCache()
    end

    local function CancelRGB()
        wasCancelled = true
        pickerReopenGuardUntil = ((GetTime and GetTime()) or 0) + 0.45
        ColorPickerFrame._padRPFinalize = nil
        if mode == "EYE" then
            ns.profile.eyeColorHex = prevHex
            RefreshEyeSwatchBox()
        else
            ns.profile.classColorHex = prevHex
            ns.profile.nameColorHex = prevHex
            RefreshClassSwatchBox()
            RefreshHeaderBanner()
            ns:RefreshTargetCard()
        end
        if prevHex and ColorPickerFrame.SetColorRGB then
            local pr, pg, pb = HexToRGB(prevHex)
            ColorPickerFrame:SetColorRGB(pr, pg, pb)
        end
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        SyncSelfProfileToLocalCache()
        ns:RefreshControllerUI()
        ns:ShowStatusToast("Color change cancelled")
        if returnWidget and returnWidget:IsVisible() then
            ns:SetControllerFocus(returnWidget)
        end
    end

    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.opacity = 1
    ColorPickerFrame.previousValues = { r = r, g = g, b = b, opacity = 1 }

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame._padRPFinalize = function()
            if wasCancelled then return end
            local tNow = (GetTime and GetTime()) or 0
            if not userMovedColor and (tNow - openedAt) < 0.25 then
                return
            end
            if ColorPickerFrame.GetColorRGB then
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local picked = RGBToHex6(nr, ng, nb)
                if picked and picked ~= "000000" then
                    liveHex6 = picked
                end
            end
            PersistColorSelection(mode, liveHex6, returnWidget)
        end
        if not ColorPickerFrame._padRPOnHideHooked and ColorPickerFrame.HookScript then
            ColorPickerFrame._padRPOnHideHooked = true
            ColorPickerFrame:HookScript("OnHide", function(self)
                pickerReopenGuardUntil = ((GetTime and GetTime()) or 0) + 0.45
                if self._padRPFinalize then
                    local fn = self._padRPFinalize
                    self._padRPFinalize = nil
                    fn()
                end
            end)
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            hasOpacity = false,
            swatchFunc = function()
                local tNow = (GetTime and GetTime()) or 0
                local fromUser = (tNow - openedAt) > 0.12
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                ApplyLiveRGB(nr, ng, nb, fromUser)
            end,
            cancelFunc = function()
                CancelRGB()
            end,
            opacityFunc = nil,
        })
    else
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.func = function()
            local tNow = (GetTime and GetTime()) or 0
            local fromUser = (tNow - openedAt) > 0.12
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            ApplyLiveRGB(nr, ng, nb, fromUser)
        end
        ColorPickerFrame.cancelFunc = function()
            CancelRGB()
        end
        ColorPickerFrame:Show()
    end
end

local function CreateColorSwatchButton(parent, x, y, mode, onReset)
    local M3 = ns.M3
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(28, 28)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns:ApplySurface(btn, M3.surfaceHigh, M3.outline)
    btn.fillTex = btn:CreateTexture(nil, "ARTWORK")
    btn.fillTex:SetPoint("TOPLEFT", 4, -4)
    btn.fillTex:SetPoint("BOTTOMRIGHT", -4, 4)
    btn.fillTex:Hide()
    btn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    btn:SetScript("OnClick", function(self, mouseBtn)
        ns:PlayUISound()
        if mouseBtn == "RightButton" and onReset then
            onReset()
        else
            OpenNativeColorPicker(mode, self)
        end
    end)
    ns:RegisterFocusable(btn, function() btn:Click("LeftButton") end, function(self, isFocused)
        ApplySwatchVisual(self, self.activeHex6, isFocused)
    end)
    return btn
end

function PadRP_ActionBarToggle()
    if ns and ns.ToggleMainFrame then
        ns:ToggleMainFrame()
    end
end

-- ---------------------------------------------------------------------------
-- Emotes tab (tab 9): manage the emotes shown on the RP Flyout Wheel.
-- Data lives in ns.db.flyout and is edited through the ns:*FlyoutEmote API in
-- FlyoutWheel.lua. Left: search/filter + list. Right: editor + icon.
-- ---------------------------------------------------------------------------
local EMOTE_ROWS = 7

local function TruncText(str, maxLen)
    str = strtrim(tostring(str or ""))
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

local function BuildEmotesTab(p, picker)
    if not p then return end
    if not ns.GetFlyoutEmoteList then
        local msg = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("TOPLEFT", 16, -16)
        msg:SetText("|cfff28b82Flyout wheel module not loaded - make sure FlyoutWheel.lua is in the .toc|r")
        return
    end

    local view, selIdx, page = "custom", 1, 1
    local searchQuery = ""
    local wheelOnly = false
    local filteredIndices = {}
    local removeArmed, removeToken, resetArmed, resetToken = false, 0, false, 0
    local RefreshList, LoadEditor, ApplyView, UpdateRemoveButton, UpdateResetButton, UpdateFilterButton

    local function CurList() return ns:GetFlyoutEmoteList(view) end

    local function RebuildFilteredIndices()
        wipe(filteredIndices)
        local list = CurList()
        local q = strtrim(string.lower(searchQuery or ""))
        q = string.gsub(q, "^/+", "")
        for idx, item in ipairs(list) do
            local matchesWheel = true
            if view == "base" and wheelOnly then
                matchesWheel = (item.enabled == true)
            end
            local matchesQuery = true
            if q ~= "" then
                local lbl = string.lower(tostring(item.label or ""))
                local tok = string.lower(tostring(item.token or ""))
                local txt = string.lower(tostring(item.text or ""))
                matchesQuery = (string.find(lbl, q, 1, true) ~= nil)
                    or (string.find(tok, q, 1, true) ~= nil)
                    or (string.find(txt, q, 1, true) ~= nil)
            end
            if matchesWheel and matchesQuery then
                table.insert(filteredIndices, idx)
            end
        end
    end

    local function CurItem()
        local list = CurList()
        if selIdx and selIdx > 0 and list[selIdx] then
            return list[selIdx]
        end
        return nil
    end

    local function ClampSelection()
        RebuildFilteredIndices()
        local count = #filteredIndices
        if count == 0 then
            selIdx = 0
            page = 1
            return
        end

        local totalPages = math.max(1, math.ceil(count / EMOTE_ROWS))
        page = math.max(1, math.min(totalPages, page))

        local foundPos = nil
        for pos, actualIdx in ipairs(filteredIndices) do
            if actualIdx == selIdx then
                foundPos = pos
                break
            end
        end
        if not foundPos then
            local startPos = (page - 1) * EMOTE_ROWS + 1
            selIdx = filteredIndices[startPos] or filteredIndices[1]
        end
    end

    local function GoToIndex(idx)
        selIdx = idx or 0
        RebuildFilteredIndices()
        local foundPos = 1
        for pos, actualIdx in ipairs(filteredIndices) do
            if actualIdx == selIdx then
                foundPos = pos
                break
            end
        end
        page = math.max(1, math.ceil(math.max(1, foundPos) / EMOTE_ROWS))
    end

    local function DisarmAll()
        removeArmed, resetArmed = false, false
        removeToken, resetToken = removeToken + 1, resetToken + 1
        if UpdateRemoveButton then UpdateRemoveButton() end
        if UpdateResetButton then UpdateResetButton() end
    end

    local function CommitEditor()
        local item = CurItem()
        if not item or not p.labelBox then return end
        local lbl = strtrim(p.labelBox:GetText() or "")
        if lbl ~= "" then item.label = string.sub(lbl, 1, 40) end
        if view == "custom" then
            local txt = strtrim(p.textBox:GetText() or "")
            if txt ~= "" then item.text = string.sub(txt, 1, 240) end
        end
    end

    local function StepPage(delta, focusRowIdx)
        CommitEditor()
        DisarmAll()
        RebuildFilteredIndices()
        local pages = math.max(1, math.ceil(#filteredIndices / EMOTE_ROWS))
        local nextPage = math.max(1, math.min(pages, page + delta))
        if nextPage == page then return false end
        page = nextPage
        local startPos = (page - 1) * EMOTE_ROWS + 1
        local pickPos = startPos
        if focusRowIdx and focusRowIdx > 1 then
            pickPos = math.min(#filteredIndices, startPos + focusRowIdx - 1)
        end
        if filteredIndices[pickPos] then
            selIdx = filteredIndices[pickPos]
        end
        RefreshList()
        LoadEditor()
        if ns.PlayUISound then ns:PlayUISound() end
        if focusRowIdx and p.rows[focusRowIdx] and p.rows[focusRowIdx]:IsShown() and ns.SetControllerFocus then
            ns:SetControllerFocus(p.rows[focusRowIdx])
        end
        return true
    end

    function ns:TrySeamlessEmoteStep(rowIndex, dir)
        if activeTab ~= 9 or not p:IsShown() then return false end
        local lastShownIdx = 0
        for i = 1, EMOTE_ROWS do
            if p.rows[i] and p.rows[i]:IsShown() then
                lastShownIdx = i
            end
        end
        if lastShownIdx == 0 then return false end
        if dir == "DOWN" and rowIndex >= lastShownIdx then
            return StepPage(1, 1)
        elseif dir == "UP" and rowIndex <= 1 then
            return StepPage(-1, EMOTE_ROWS)
        end
        return false
    end

    -- ----- list + search/filter (left column) ----------------------------------
    p.viewCustomBtn = ns:CreateMaterialButton(p, "Custom /e", 150, 24, 16, -8, "PRIMARY", function()
        CommitEditor(); DisarmAll()
        view, selIdx, page = "custom", 1, 1
        ApplyView()
    end)
    p.viewBaseBtn = ns:CreateMaterialButton(p, "Base Emotes", 150, 24, 170, -8, nil, function()
        CommitEditor(); DisarmAll()
        view, selIdx, page = "base", 1, 1
        ApplyView()
    end)
    p.countFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.countFS:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -14)
    p.countFS:SetJustifyH("RIGHT")

    p.searchBox = ns:CreateMaterialEditBox(p, nil, "Search label or /token...", 16, -34, 164, 22, function(txt)
        searchQuery = txt or ""
        page = 1
        selIdx = 0
        RefreshList(); LoadEditor()
    end)
    p.searchBox:SetScript("OnTextChanged", function(self)
        searchQuery = self:GetText() or ""
        page = 1
        selIdx = 0
        RefreshList(); LoadEditor()
    end)

    UpdateFilterButton = function()
        if not p.wheelFilterBtn then return end
        if view ~= "base" then
            p.wheelFilterBtn:Hide()
            return
        end
        p.wheelFilterBtn:Show()
        if wheelOnly then
            p.wheelFilterBtn:SetText("Wheel Only")
            p.wheelFilterBtn:SetTone("MINT")
        else
            p.wheelFilterBtn:SetText("Show All")
            p.wheelFilterBtn:SetTone("PRIMARY")
        end
    end

    p.wheelFilterBtn = ns:CreateMaterialButton(p, "Show All", 88, 22, 184, -34, "PRIMARY", function()
        wheelOnly = not wheelOnly
        page = 1
        selIdx = 0
        UpdateFilterButton()
        RefreshList(); LoadEditor()
    end)

    p.clearSearchBtn = ns:CreateMaterialButton(p, "Clr", 44, 22, 276, -34, nil, function()
        searchQuery = ""
        p.searchBox:SetCleanText("")
        page = 1
        selIdx = 0
        RefreshList(); LoadEditor()
    end)

    p.rows = {}
    for i = 1, EMOTE_ROWS do
        local row = ns:CreateMaterialButton(p, "", 304, 26, 16, -60 - (i - 1) * 28, nil, function(self)
            if not self.idx then return end
            CommitEditor(); DisarmAll()
            selIdx = self.idx
            RefreshList(); LoadEditor()
        end)
        row.emoteRowIndex = i
        row.iconTex = row:CreateTexture(nil, "ARTWORK")
        row.iconTex:SetSize(18, 18)
        row.iconTex:SetPoint("LEFT", 6, 0)
        row.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", 30, 0)
        row.label:SetPoint("RIGHT", -6, 0)
        row.label:SetJustifyH("LEFT")
        AttachWheelScroller(row, function(delta) StepPage(delta, nil) end)
        p.rows[i] = row
    end

    p.prevBtn = ns:CreateMaterialButton(p, "< Prev", 80, 24, 16, -260, nil, function() StepPage(-1, nil) end)
    p.pageFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.pageFS:SetPoint("TOPLEFT", 100, -265)
    p.pageFS:SetWidth(124)
    p.pageFS:SetJustifyH("CENTER")
    p.nextBtn = ns:CreateMaterialButton(p, "Next >", 80, 24, 240, -260, nil, function() StepPage(1, nil) end)
    AttachWheelScroller(p.prevBtn, function(delta) StepPage(delta, nil) end)
    AttachWheelScroller(p.nextBtn, function(delta) StepPage(delta, nil) end)
    AttachWheelScroller(p, function(delta) StepPage(delta, nil) end)

    -- add row (Custom /e only)
    p.addBoxCustom = ns:CreateMaterialEditBox(p, nil, "New emote name...", 16, -290, 214, 26)
    local function DoAdd()
        if view ~= "custom" then return end
        CommitEditor()
        local idx, err = ns:AddFlyoutEmote("custom", { label = p.addBoxCustom:GetText() })
        if idx then p.addBoxCustom:SetCleanText("") end
        if not idx then
            ns:ShowStatusToast((err == "limit" and "Emote limit reached - remove one first")
                or "Enter a name for the custom emote")
            return
        end
        DisarmAll()
        GoToIndex(idx)
        RefreshList(); LoadEditor()
        ns:ShowStatusToast("Custom emote added - write its text on the right")
    end
    p.addBtn = ns:CreateMaterialButton(p, "+ Add", 84, 26, 236, -290, "MINT", DoAdd)

    UpdateResetButton = function()
        if not p.resetBtn then return end
        p.resetBtn:SetText(resetArmed and "Press again to confirm reset" or "Reset Base Emotes to Default")
        p.resetBtn:SetTone(resetArmed and "CORAL" or nil)
    end
    p.resetBtn = ns:CreateMaterialButton(p, "Reset Base Emotes to Default", 304, 26, 16, -292, nil, function()
        if not resetArmed then
            resetArmed = true
            resetToken = resetToken + 1
            local token = resetToken
            UpdateResetButton()
            if C_Timer and C_Timer.After then
                C_Timer.After(3, function()
                    if resetToken == token then resetArmed = false; UpdateResetButton() end
                end)
            end
            return
        end
        resetArmed = false
        ns:ResetFlyoutBaseEmotes()
        selIdx, page = 1, 1
        UpdateResetButton()
        RefreshList(); LoadEditor()
        ns:ShowStatusToast("Base emotes reset to starter set")
    end)
    p.tipFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.tipFS:SetPoint("TOPLEFT", 16, -326)
    p.tipFS:SetWidth(304)
    p.tipFS:SetJustifyH("LEFT")
    p.tipFS:SetText("|cff9aa0a6On the wheel: LB/RB to reach Custom and Base pages.|r")

    -- ----- editor (right column) ----------------------------------------------
    p.editorHeader = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.editorHeader:SetPoint("TOPLEFT", 336, -52)
    p.editorHeader:SetWidth(304)
    p.editorHeader:SetJustifyH("LEFT")

    local function Caption(text, y)
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 336, y)
        fs:SetText(text)
        return fs
    end
    local capLabel = Caption("Label (shown on the wheel)", -72)
    p.labelBox = ns:CreateMaterialEditBox(p, nil, "e.g. Look Around", 336, -86, 304, 26, function() CommitEditor(); RefreshList() end)
    if p.labelBox.SetMaxLetters then p.labelBox:SetMaxLetters(40) end

    -- custom-only widgets
    local capText = Caption("Emote text (appears after your name)", -118)
    p.textBox = ns:CreateMaterialEditBox(p, nil, "e.g. looks around attentively.", 336, -132, 304, 26, function() CommitEditor(); RefreshList() end)
    if p.textBox.SetMaxLetters then p.textBox:SetMaxLetters(240) end
    p.previewFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.previewFS:SetPoint("TOPLEFT", 336, -164)
    p.previewFS:SetWidth(304)
    p.previewFS:SetJustifyH("LEFT")
    p.previewFS:SetJustifyV("TOP")
    p.previewFS:SetHeight(42)
    p.hintFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.hintFS:SetPoint("TOPLEFT", 336, -336)
    p.hintFS:SetWidth(304)
    p.hintFS:SetJustifyH("LEFT")
    p.hintFS:SetText("|cff9aa0a6%name = your RP name   %target = your target's name|r")
    p.textBox:HookScript("OnTextChanged", function(self)
        if view == "custom" and CurItem() then
            p.previewFS:SetText("|cff9aa0a6Preview:|r " .. ns:PreviewFlyoutEmoteText(self:GetText()))
        end
    end)

    -- base-only widgets
    p.tokenFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.tokenFS:SetPoint("TOPLEFT", 336, -124)
    p.tokenFS:SetWidth(304)
    p.tokenFS:SetJustifyH("LEFT")
    p.enableBtn = ns:CreateMaterialButton(p, "", 304, 26, 336, -146, nil, function()
        local item = CurItem()
        if not item then return end
        item.enabled = not (item.enabled == true)
        if ns.RefreshFlyoutWheel and ns.flyoutWheelFrame and ns.flyoutWheelFrame:IsShown() then
            ns:RefreshFlyoutWheel()
        end
        RefreshList(); LoadEditor()
    end)

    -- icon row (custom icon override + restore original icon)
    p.iconFrame = CreateFrame("Frame", nil, p, "BackdropTemplate")
    p.iconFrame:SetSize(36, 36)
    p.iconFrame:SetPoint("TOPLEFT", 336, -210)
    ns:ApplySurface(p.iconFrame, ns.M3.surface, ns.M3.outline)
    p.iconTex = p.iconFrame:CreateTexture(nil, "ARTWORK")
    p.iconTex:SetSize(30, 30)
    p.iconTex:SetPoint("CENTER")
    p.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.iconBtn = ns:CreateMaterialButton(p, "Custom Icon", 150, 26, 380, -215, "PRIMARY", function(self)
        local item = CurItem()
        if not item then return end
        CommitEditor()
        local currentActive = ns:GetFlyoutEmoteDisplayIcon(view, item)
        picker:OpenForCallback("SELECT CUSTOM EMOTE ICON", currentActive, function(iconVal)
            local current = CurItem()
            if current then
                ns:SetFlyoutEmoteCustomIcon(view, selIdx, iconVal)
            end
            RefreshList(); LoadEditor()
            ns:ShowStatusToast("Custom icon applied")
        end, self)
    end)
    p.defaultIconBtn = ns:CreateMaterialButton(p, "Original Icon", 104, 26, 536, -215, nil, function()
        local item = CurItem()
        if not item then return end
        ns:ClearFlyoutEmoteCustomIcon(view, selIdx)
        RefreshList(); LoadEditor()
        ns:ShowStatusToast("Restored original icon")
    end)

    -- order / remove / save
    p.moveUpBtn = ns:CreateMaterialButton(p, "Move Up", 96, 26, 336, -256, nil, function()
        if selIdx < 1 then return end
        CommitEditor()
        GoToIndex(ns:MoveFlyoutEmote(view, selIdx, -1))
        RefreshList(); LoadEditor()
    end)
    p.moveDownBtn = ns:CreateMaterialButton(p, "Move Down", 96, 26, 436, -256, nil, function()
        if selIdx < 1 then return end
        CommitEditor()
        GoToIndex(ns:MoveFlyoutEmote(view, selIdx, 1))
        RefreshList(); LoadEditor()
    end)
    UpdateRemoveButton = function()
        if not p.removeBtn then return end
        local item = CurItem()
        if item and view == "base" and ns:IsDefaultBaseEmoteToken(item.token) then
            p.removeBtn:SetText("Built-in")
            p.removeBtn:SetTone(nil)
        elseif removeArmed then
            p.removeBtn:SetText("Confirm?")
            p.removeBtn:SetTone("CORAL")
        else
            p.removeBtn:SetText("Remove")
            p.removeBtn:SetTone("CORAL")
        end
    end
    p.removeBtn = ns:CreateMaterialButton(p, "Remove", 104, 26, 536, -256, "CORAL", function()
        local item = CurItem()
        if not item then return end
        if view == "base" and ns:IsDefaultBaseEmoteToken(item.token) then
            ns:ShowStatusToast("Built-in emote - switch 'Show on the wheel' off instead")
            return
        end
        if not removeArmed then
            removeArmed = true
            removeToken = removeToken + 1
            local token = removeToken
            UpdateRemoveButton()
            if C_Timer and C_Timer.After then
                C_Timer.After(3, function()
                    if removeToken == token then removeArmed = false; UpdateRemoveButton() end
                end)
            end
            return
        end
        removeArmed = false
        local name = item.label or "Emote"
        if ns:RemoveFlyoutEmote(view, selIdx) then
            ns:ShowStatusToast("Removed: " .. name)
        end
        RefreshList(); LoadEditor()
    end)
    p.saveBtn = ns:CreateMaterialButton(p, "Save Changes", 304, 28, 336, -292, "PRIMARY", function()
        CommitEditor()
        if ns.RefreshFlyoutWheel and ns.flyoutWheelFrame and ns.flyoutWheelFrame:IsShown() then
            ns:RefreshFlyoutWheel()
        end
        RefreshList()
        ns:ShowStatusToast("Emote saved")
    end)

    p.commonWidgets = { p.labelBox, p.iconFrame, p.iconBtn, p.defaultIconBtn, p.moveUpBtn, p.moveDownBtn, p.removeBtn, p.saveBtn, capLabel }
    p.customWidgets = { p.textBox, p.previewFS, p.hintFS, capText }
    p.baseWidgets = { p.tokenFS, p.enableBtn }

    p.labelBox:HookScript("OnEditFocusLost", function()
        if p:IsShown() then CommitEditor(); RefreshList() end
    end)
    p.textBox:HookScript("OnEditFocusLost", function()
        if p:IsShown() then CommitEditor(); RefreshList() end
    end)

    -- ----- refresh / load ------------------------------------------------------
    RefreshList = function()
        ClampSelection()
        local list = CurList()
        local pages = math.max(1, math.ceil(#filteredIndices / EMOTE_ROWS))
        for i = 1, EMOTE_ROWS do
            local row = p.rows[i]
            local actualIdx = filteredIndices[(page - 1) * EMOTE_ROWS + i]
            local item = actualIdx and list[actualIdx] or nil
            if item then
                row.idx = actualIdx
                local displayIcon = ns:GetFlyoutEmoteDisplayIcon(view, item)
                SetIconTextureSafe(row.iconTex, ns:ResolveWheelIconTexture(displayIcon, view, item), GetDefaultIconFallback())
                if view == "base" then
                    local on = item.enabled == true
                    local customMark = (ns:GetFlyoutEmoteCustomIcon(item) ~= nil) and " *" or ""
                    row:SetText((on and "|cff81c995ON |r" or "|cfff28b82OFF|r") .. " " .. TruncText(item.label or item.token, 14)
                        .. customMark .. " |cff9aa0a6/" .. string.lower(tostring(item.token or "")) .. "|r")
                else
                    local customMark = (ns:GetFlyoutEmoteCustomIcon(item) ~= nil) and " *" or ""
                    row:SetText(TruncText((item.label or ("Emote " .. actualIdx)) .. customMark, 16)
                        .. "  |cff9aa0a6" .. TruncText(item.text, 18) .. "|r")
                end
                row:SetTone(actualIdx == selIdx and "PRIMARY" or nil)
                row:Show()
            else
                row.idx = nil
                row:Hide()
            end
        end
        p.pageFS:SetText(string.format("Page %d / %d (%d)", page, pages, #filteredIndices))

        local baseList = ns:GetFlyoutEmoteList("base")
        local enabledCount = 0
        for _, e in ipairs(baseList) do
            if e.enabled == true then enabledCount = enabledCount + 1 end
        end
        p.countFS:SetText(string.format("|cff8ab4f8Custom:|r %d   |cff8ab4f8Base:|r %d (%d on)",
            #ns:GetFlyoutEmoteList("custom"), #baseList, enabledCount))
    end

    LoadEditor = function()
        local item = CurItem()
        local has = item ~= nil
        p.editorHeader:SetText(has
            and string.format("|cff8ab4f8EDITING|r  %s #%d", (view == "base") and "Base Emote" or "Custom Emote", selIdx)
            or "|cff9aa0a6No matching emote - adjust search/filter or add one|r")
        for _, w in ipairs(p.commonWidgets) do w:SetShown(has) end
        for _, w in ipairs(p.customWidgets) do w:SetShown(has and view == "custom") end
        for _, w in ipairs(p.baseWidgets) do w:SetShown(has and view == "base") end
        if not has then return end

        p.labelBox:SetCleanText(item.label or "")
        local displayIcon = ns:GetFlyoutEmoteDisplayIcon(view, item)
        SetIconTextureSafe(p.iconTex, ns:ResolveWheelIconTexture(displayIcon, view, item), GetDefaultIconFallback())
        p.defaultIconBtn:SetText(ns:GetFlyoutEmoteCustomIcon(item) and "Reset Icon" or "Original Icon")

        if view == "custom" then
            p.textBox:SetCleanText(item.text or "")
            p.previewFS:SetText("|cff9aa0a6Preview:|r " .. ns:PreviewFlyoutEmoteText(item.text))
        else
            p.tokenFS:SetText("|cff9aa0a6Command:|r /" .. string.lower(tostring(item.token or "")))
            local on = item.enabled == true
            p.enableBtn:SetText(FormatCheckbox("Show on the wheel", on, "ff81c995"))
            p.enableBtn:SetTone(on and "MINT" or nil)
        end
        UpdateRemoveButton()
    end

    ApplyView = function()
        local isCustom = (view == "custom")
        p.viewCustomBtn:SetTone(isCustom and "PRIMARY" or nil)
        p.viewBaseBtn:SetTone(isCustom and nil or "PRIMARY")
        p.searchBox:SetShown(not isCustom)
        p.clearSearchBtn:SetShown(not isCustom)
        p.addBoxCustom:SetShown(isCustom)
        p.addBtn:SetShown(isCustom)
        p.tipFS:SetShown(isCustom)
        p.resetBtn:SetShown(not isCustom)
        UpdateFilterButton()
        ClampSelection()
        UpdateResetButton()
        RefreshList()
        LoadEditor()
    end

    p:HookScript("OnShow", function()
        ns:EnsureFlyoutDB()
        DisarmAll()
        ApplyView()
    end)
end

-- Open the main window straight onto the Emotes tab (used by the wheel's "Add in PadRP" slice).
function ns:OpenEmotesTab()
    if not mainFrame then return end
    if not mainFrame:IsShown() then ns:ToggleMainFrame() end
    ns:SelectTab(9)
end

function ns:InitControllerUI()
    local M3 = ns.M3
    ns:CreateBindButton("PadRP_ToggleUIButton", function() ns:ToggleMainFrame() end)
    ns:CreateBindButton("PadRP_PrevTabBtn",     function() ns:CycleTab(-1) end)
    ns:CreateBindButton("PadRP_NextTabBtn",     function() ns:CycleTab(1) end)
    ns:CreateBindButton("PadRP_PadUpBtn",       function() ns:MoveControllerFocus("UP") end)
    ns:CreateBindButton("PadRP_PadDownBtn",     function() ns:MoveControllerFocus("DOWN") end)
    ns:CreateBindButton("PadRP_PadLeftBtn",     function() ns:MoveControllerFocus("LEFT") end)
    ns:CreateBindButton("PadRP_PadRightBtn",    function() ns:MoveControllerFocus("RIGHT") end)
    ns:CreateBindButton("PadRP_PadConfirmBtn",  function() ns:ControllerConfirmAction() end)
    ns:CreateBindButton("PadRP_PadCancelBtn",   function() ns:ControllerCancelAction() end)

    local savedW = (ns.db.ui and ns.db.ui.width) or 680
    local savedH = (ns.db.ui and ns.db.ui.height) or 560

    mainFrame = CreateFrame("Frame", "PadRP_MainFrame", UIParent, "BackdropTemplate")
    ns.mainFrame = mainFrame
    mainFrame:SetSize(savedW, savedH)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(15)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    if mainFrame.SetResizeBounds then mainFrame:SetResizeBounds(660, 540, 1050, 840) end
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if self:IsMovable() then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    mainFrame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)
    ns:EnableClipping(mainFrame)
    mainFrame:Hide()
    ns:ApplySurface(mainFrame, M3.surfaceDim, M3.outline)

    local topAccent = mainFrame:CreateTexture(nil, "OVERLAY")
    topAccent:SetHeight(2)
    topAccent:SetPoint("TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", -1, -1)
    topAccent:SetColorTexture(0.54, 0.71, 0.97, 0.85)

    tinsert(UISpecialFrames, "PadRP_MainFrame")

    mainFrame:SetScript("OnShow", function()
        ns:PlayUISound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        UpdateTabBarLayout()
        UpdateResponsiveLayouts()
        ns:UpdateControllerBindings()
        ns:FocusFirstInScope()
    end)
    mainFrame:SetScript("OnHide", function()
        mainFrame:StopMovingOrSizing()
        if ns.activeEditBox and ns.activeEditBox:HasFocus() then ns.activeEditBox:ClearFocus() end
        CommitModifiedBoxesToProfile(false)
        ns:PlayUISound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        CloseAnyOpenPopup()
        ns:UpdateControllerBindings()
    end)
    mainFrame:SetScript("OnSizeChanged", function(self, w, h)
        if ns.db and ns.db.ui then
            ns.db.ui.width, ns.db.ui.height = math.floor(w + 0.5), math.floor(h + 0.5)
        end
        UpdateTabBarLayout()
        UpdateResponsiveLayouts()
        if self:IsShown() then
            ns:RefreshTargetCard()
            if ns.currentFocus then ns:SetControllerFocus(ns.currentFocus) end
        end
    end)
    mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    mainFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" and self:IsShown() and ns.db.ui.hideInCombat then
            self:Hide()
        end
    end)

    if _G.CharacterFrame and _G.CharacterFrame.HookScript then
        pcall(function()
            _G.CharacterFrame:HookScript("OnShow", function()
                if mainFrame and mainFrame:IsShown() and mainFrame.Lower then
                    mainFrame:Lower()
                end
            end)
        end)
    end

    local picker = CreateFrame("Frame", "PadRP_IconPicker", mainFrame, "BackdropTemplate")
    picker:SetSize(512, 412)
    picker:SetPoint("CENTER", mainFrame, "CENTER", 0, -4)
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(mainFrame:GetFrameLevel() + 45)
    ns:ApplySurface(picker, M3.surfaceDim, M3.primary)
    ns:EnableClipping(picker)
    picker:EnableMouse(true)
    picker:Hide()

    picker.mode = "GLANCE"
    picker.targetSlot = 1
    picker.page = 1
    picker.searchQuery = ""
    picker.filteredIcons = {}
    picker.cells = {}

    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    picker.title:SetPoint("TOPLEFT", 16, -12)

    ns:CreateMaterialButton(picker, "X", 28, 24, 476, -8, "CORAL", function()
        picker:Hide()
        if picker.returnFocusWidget and picker.returnFocusWidget:IsVisible() then
            ns:SetControllerFocus(picker.returnFocusWidget)
        else
            ns:FocusFirstInScope()
        end
    end)

    local poolCount = (ns.IconPool and ns.IconPool.entries and #ns.IconPool.entries) or 0
    picker.catalogBadge = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    picker.catalogBadge:SetPoint("TOPLEFT", 16, -39)
    picker.catalogBadge:SetText(string.format("|cff8ab4f8Catalog (%d)|r", poolCount))

    picker.searchBox = ns:CreateMaterialEditBox(picker, nil, "Search by name or ID...", 150, -34, 300, 24, function(txt)
        picker.searchQuery = txt or ""
        picker.page = 1
        picker:RebuildFilter()
    end)
    picker.searchBox:SetScript("OnTextChanged", function(self)
        picker.searchQuery = self:GetText() or ""
        picker.page = 1
        picker:RebuildFilter()
    end)

    ns:CreateMaterialButton(picker, "Clr", 40, 24, 456, -34, nil, function()
        picker.searchBox:SetCleanText("")
        picker.searchQuery = ""
        picker.page = 1
        picker:RebuildFilter()
    end)

    local function ApplyPickedIcon(iconValue)
        local clean = strtrim(tostring(iconValue or ""))
        if clean == "" then return end
        if picker.mode == "CALLBACK" then
            local cb = picker.pickCallback
            picker:Hide()
            if cb then cb(clean) end
            if picker.returnFocusWidget and picker.returnFocusWidget:IsVisible() then
                ns:SetControllerFocus(picker.returnFocusWidget)
            else
                ns:FocusFirstInScope()
            end
            return
        end
        if picker.mode == "PORTRAIT" then
            ns.profile.icon = clean
            RefreshHeaderBanner()
            ns:RefreshControllerUI()
            ns:ShowStatusToast("Portrait icon updated!")
        else
            local slot = picker.targetSlot or 1
            if ns.profile.glances[slot] then
                ns.profile.glances[slot].icon = clean
            end
            LoadAllGlancesIntoUI()
            ns:ShowStatusToast("Glance #" .. slot .. " icon updated!")
        end
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        picker:Hide()
        if picker.returnFocusWidget and picker.returnFocusWidget:IsVisible() then
            ns:SetControllerFocus(picker.returnFocusWidget)
        else
            ns:FocusFirstInScope()
        end
    end

    local ICONS_PER_PAGE = 40
    for idx = 1, ICONS_PER_PAGE do
        local col, row = (idx - 1) % 8, math.floor((idx - 1) / 8)
        local cell = CreateFrame("Button", nil, picker, "BackdropTemplate")
        cell:SetSize(50, 48)
        cell:SetPoint("TOPLEFT", 16 + col * 60, -66 - row * 52)
        ns:ApplySurface(cell, M3.surface, M3.outline)
        cell.tex = cell:CreateTexture(nil, "ARTWORK")
        cell.tex:SetSize(40, 40)
        cell.tex:SetPoint("CENTER")
        cell.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cell:SetScript("OnEnter", function(self)
            ns:SetControllerFocus(self)
            if self.iconName then
                picker.hoverLabel:SetText(FormatPickerIconReadout("Selected:", self.iconName, self.iconID, self.tex))
            end
        end)
        cell:SetScript("OnClick", function(self)
            if not self.iconName then return end
            ns:PlayUISound()
            ApplyPickedIcon(self.iconName)
        end)
        ns:RegisterFocusable(cell, function() cell:Click("LeftButton") end, function(self, isFocused)
            if isFocused then
                self:SetBackdropColor(unpack(M3.surfaceBright))
                self:SetBackdropBorderColor(unpack(M3.primary))
                if self.iconName then
                    picker.hoverLabel:SetText(FormatPickerIconReadout("Selected:", self.iconName, self.iconID, self.tex))
                end
            else
                self:SetBackdropColor(unpack(M3.surface))
                self:SetBackdropBorderColor(unpack(M3.outline))
            end
        end)
        picker.cells[idx] = cell
    end

    picker.hoverLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    picker.hoverLabel:SetPoint("TOPLEFT", 16, -328)
    picker.hoverLabel:SetPoint("TOPRIGHT", -16, -328)
    picker.hoverLabel:SetJustifyH("LEFT")
    picker.hoverLabel:SetWordWrap(false)

    ns:CreateMaterialButton(picker, "<< -10", 58, 24, 16, -346, nil, function() picker:StepPage(-10) end)
    ns:CreateMaterialButton(picker, "< [LB]", 62, 24, 80, -346, nil, function() picker:StepPage(-1) end)

    picker.pageText = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    picker.pageText:SetPoint("TOPLEFT", 148, -352)
    picker.pageText:SetWidth(216)
    picker.pageText:SetJustifyH("CENTER")

    ns:CreateMaterialButton(picker, "[RB] >", 62, 24, 370, -346, nil, function() picker:StepPage(1) end)
    ns:CreateMaterialButton(picker, "+10 >>", 58, 24, 438, -346, nil, function() picker:StepPage(10) end)

    picker.customBox = ns:CreateMaterialEditBox(picker, nil, "Or enter custom icon name / FileDataID...", 16, -376, 374, 24)
    ns:CreateMaterialButton(picker, "Use Custom", 100, 24, 396, -376, "PRIMARY", function()
        local raw = strtrim(picker.customBox:GetText() or "")
        if raw ~= "" then ApplyPickedIcon(raw) end
    end)

    picker.StepPage = function(self, delta)
        local totalPages = math.max(1, math.ceil(#self.filteredIcons / ICONS_PER_PAGE))
        self.page = math.max(1, math.min(totalPages, self.page + (delta or 1)))
        self:RefreshGrid()
    end
    AttachWheelScroller(picker, function(step) picker:StepPage(step) end)

    picker.RebuildFilter = function(self)
        wipe(self.filteredIcons)
        local q = strtrim(string.lower(self.searchQuery or ""))

        if ns.IconPool and ns.IconPool.Search then
            local matches = ns.IconPool:Search(q)
            for _, entry in ipairs(matches or {}) do
                table.insert(self.filteredIcons, entry)
            end
        end

        local totalPool = (ns.IconPool and ns.IconPool.entries and #ns.IconPool.entries) or #self.filteredIcons
        if self.catalogBadge then
            self.catalogBadge:SetText(string.format("|cff8ab4f8Catalog (%d)|r", totalPool))
        end

        self:RefreshGrid()
    end

    picker.RefreshGrid = function(self)
        local fallbackIcon = GetDefaultIconFallback()
        local currentIcon
        if self.mode == "PORTRAIT" then
            currentIcon = tostring((ns.profile and ns.profile.icon) or fallbackIcon)
            self.title:SetText("|cff8ab4f8SELECT CHARACTER PORTRAIT ICON|r")
        elseif self.mode == "CALLBACK" then
            currentIcon = tostring(self.callbackIcon or fallbackIcon)
            self.title:SetText("|cff8ab4f8" .. (self.callbackTitle or "SELECT ICON") .. "|r")
        else
            local slot = self.targetSlot or 1
            currentIcon = tostring((ns.profile.glances[slot] and ns.profile.glances[slot].icon) or fallbackIcon)
            self.title:SetText("|cff8ab4f8SELECT ICON FOR GLANCE #" .. slot .. "|r")
        end

        local pageItems, totalPages, total, clampedPage = {}, 1, #self.filteredIcons, self.page
        if ns.IconPool and ns.IconPool.GetPage then
            pageItems, totalPages, total, clampedPage = ns.IconPool:GetPage(self.filteredIcons, self.page, ICONS_PER_PAGE)
            self.page = clampedPage
        else
            totalPages = math.max(1, math.ceil(total / ICONS_PER_PAGE))
            self.page = math.max(1, math.min(totalPages, self.page))
            local startIndex = (self.page - 1) * ICONS_PER_PAGE
            for i = 1, ICONS_PER_PAGE do
                local item = self.filteredIcons[startIndex + i]
                if item then table.insert(pageItems, item) end
            end
        end

        self.pageText:SetText(string.format("Page %d / %d  (|cff9aa0a6%d icons|r)", self.page, totalPages, total))
        if not self.customBox:HasFocus() then
            self.customBox:SetCleanText(currentIcon)
        end
        self.hoverLabel:SetText(FormatPickerIconReadout("Current:", currentIcon, nil, nil))

        for i = 1, ICONS_PER_PAGE do
            local cell = self.cells[i]
            local rawItem = pageItems[i]
            if rawItem then
                local id, _, displayVal = UnpackIconEntry(rawItem)
                cell.iconName = displayVal
                cell.iconID = id
                SetIconTextureSafe(cell.tex, id or displayVal, fallbackIcon)
                cell:Show()
            else
                cell.iconName = nil
                cell.iconID = nil
                cell:Hide()
            end
        end
    end

    picker.OpenForSlot = function(self, slotIndex, returnWidget)
        self.mode, self.targetSlot, self.page, self.returnFocusWidget = "GLANCE", slotIndex, 1, returnWidget
        self.searchQuery = ""
        self.searchBox:SetCleanText("")
        self:RebuildFilter()
        self:Show()
        ns:SetControllerFocus(self.cells[1]:IsShown() and self.cells[1] or self.searchBox)
    end

    picker.OpenForPortrait = function(self, returnWidget)
        self.mode, self.page, self.returnFocusWidget = "PORTRAIT", 1, returnWidget
        self.searchQuery = ""
        self.searchBox:SetCleanText("")
        self:RebuildFilter()
        self:Show()
        ns:SetControllerFocus(self.cells[1]:IsShown() and self.cells[1] or self.searchBox)
    end
    -- Generic picker: onPick(iconString) is called with the chosen icon name / FileDataID.
    picker.OpenForCallback = function(self, title, currentIcon, onPick, returnWidget)
        self.mode, self.page, self.returnFocusWidget = "CALLBACK", 1, returnWidget
        self.callbackTitle, self.callbackIcon, self.pickCallback = title, currentIcon, onPick
        self.searchQuery = ""
        self.searchBox:SetCleanText("")
        self:RebuildFilter()
        self:Show()
        ns:SetControllerFocus(self.cells[1]:IsShown() and self.cells[1] or self.searchBox)
    end
    mainFrame.iconPicker = picker

    local banner = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    banner:SetHeight(50)
    banner:SetPoint("TOPLEFT", 12, -10)
    banner:SetPoint("TOPRIGHT", -12, -10)
    ns:ApplySurface(banner, M3.surfaceLow, M3.outline)
    ns:EnableClipping(banner)

    local portraitBtn = CreateFrame("Button", nil, banner, "BackdropTemplate")
    portraitBtn:SetSize(38, 38)
    portraitBtn:SetPoint("LEFT", banner, "LEFT", 6, 0)
    ns:ApplySurface(portraitBtn, M3.surface, M3.primary)
    mainFrame.portraitBtn = portraitBtn
    mainFrame.portraitTex = portraitBtn:CreateTexture(nil, "ARTWORK")
    mainFrame.portraitTex:SetSize(32, 32)
    mainFrame.portraitTex:SetPoint("CENTER")
    mainFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portraitBtn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    portraitBtn:SetScript("OnClick", function(self) ns:PlayUISound(); picker:OpenForPortrait(self) end)
    ns:RegisterFocusable(portraitBtn, function() portraitBtn:Click("LeftButton") end)

    mainFrame.bannerName = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainFrame.bannerName:SetPoint("TOPLEFT", banner, "TOPLEFT", 52, -6)
    mainFrame.bannerName:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
    mainFrame.bannerName:SetJustifyH("LEFT")
    mainFrame.bannerName:SetWordWrap(false)

    mainFrame.bannerTitle = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.bannerTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 52, -23)
    mainFrame.bannerTitle:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
    mainFrame.bannerTitle:SetJustifyH("LEFT")
    mainFrame.bannerTitle:SetWordWrap(false)

    mainFrame.bannerCurrently = banner:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mainFrame.bannerCurrently:SetPoint("TOPLEFT", banner, "TOPLEFT", 52, -37)
    mainFrame.bannerCurrently:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
    mainFrame.bannerCurrently:SetJustifyH("LEFT")
    mainFrame.bannerCurrently:SetWordWrap(false)

    local controlBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    controlBar:SetHeight(34)
    controlBar:SetPoint("TOPLEFT", 12, -64)
    controlBar:SetPoint("TOPRIGHT", -12, -64)
    ns:ApplySurface(controlBar, M3.surface, M3.outline)
    ns:EnableClipping(controlBar)
    mainFrame.controlBar = controlBar

    local profPrevBtn = ns:CreateMaterialButton(controlBar, "<", 20, 24, 8, -5, nil, function() CommitModifiedBoxesToProfile(false); ns:CycleProfile(-1) end)
    local profChip = ns:CreateMaterialButton(controlBar, "Profile", 84, 24, 30, -5, nil, function() CommitModifiedBoxesToProfile(false); ns:CycleProfile(1) end)
    local profNextBtn = ns:CreateMaterialButton(controlBar, ">", 20, 24, 116, -5, nil, function() CommitModifiedBoxesToProfile(false); ns:CycleProfile(1) end)
    mainFrame.profPrevBtn = profPrevBtn
    mainFrame.profChip = profChip
    mainFrame.profNextBtn = profNextBtn

    local closeBtn = ns:CreateMaterialButton(controlBar, "X", 28, 26, 0, -4, "CORAL", function() mainFrame:Hide() end)
    closeBtn.label:ClearAllPoints()
    closeBtn.label:SetPoint("CENTER", 0, 0)
    mainFrame.closeBtn = closeBtn

    local icSwitch = CreateFrame("Button", nil, controlBar, "BackdropTemplate")
    icSwitch:SetSize(126, 26)
    ns:ApplySurface(icSwitch, M3.mintTonal, M3.mint)
    icSwitch.bgLabel = icSwitch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icSwitch.thumb = CreateFrame("Frame", nil, icSwitch, "BackdropTemplate")
    icSwitch.thumb:SetSize(84, 20)
    ns:ApplySurface(icSwitch.thumb, M3.mint, M3.outline)
    icSwitch.thumb.label = icSwitch.thumb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icSwitch.thumb.label:SetPoint("CENTER")
    icSwitch:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    icSwitch:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:ToggleICOOC()
        RefreshHeaderBanner()
        ns:ShowStatusToast(ns.profile.isIC and "Switched to In-Character (IC)" or "Switched to Out-of-Character (OOC)")
    end)
    ns:RegisterFocusable(icSwitch, function() icSwitch:Click("LeftButton") end)
    mainFrame.icSwitch = icSwitch

    local walkUpBtn = ns:CreateMaterialButton(controlBar, "WALK-UPS: OPEN", 128, 26, 0, -4, "MINT", function()
        local code = ns:CycleWalkUpStatus()
        RefreshHeaderBanner()
        if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
        ns:ShowStatusToast("Walk-Up Flag: " .. ns:GetWalkUpLabel(code))
    end)
    mainFrame.walkUpBtn = walkUpBtn

    local expDropdown = CreateFrame("Frame", "PadRP_TopExpDropdown", mainFrame, "BackdropTemplate")
    expDropdown:SetSize(196, 164)
    expDropdown:SetFrameStrata("DIALOG")
    expDropdown:SetFrameLevel(mainFrame:GetFrameLevel() + 40)
    ns:ApplySurface(expDropdown, M3.surfaceDim, M3.primary)
    ns:EnableClipping(expDropdown)
    expDropdown:EnableMouse(true)
    expDropdown:Hide()
    expDropdown.rows = {}

    for i, item in ipairs(RP_EXPERIENCE_LIST) do
        local optBtn = ns:CreateMaterialButton(expDropdown, "", 182, 26, 7, -8 - (i - 1) * 30, nil, function()
            ApplyRPExperienceSelection(item.code)
            expDropdown:Hide()
            if mainFrame.bannerExpBtn then ns:SetControllerFocus(mainFrame.bannerExpBtn) end
        end)
        optBtn.label:SetJustifyH("LEFT")
        expDropdown.rows[i] = optBtn
    end

    expDropdown.Rebuild = function(self)
        local curCode = tostring((ns.profile and ns.profile.rpStyle) or "1")
        for i, item in ipairs(RP_EXPERIENCE_LIST) do
            local r = self.rows[i]
            local isSel = (item.code == curCode)
            r:SetText((isSel and "|cff81c995> |r" or "  ") .. item.label)
            r:SetTone(isSel and "PRIMARY" or nil)
        end
    end
    mainFrame.expDropdown = expDropdown

    local bannerExpBtn = ns:CreateMaterialButton(controlBar, "|cff8ab4f8RP:|r Normal [v]", 104, 26, 0, -4, nil, function(self)
        if mainFrame.presetDropdown then mainFrame.presetDropdown:Hide() end
        if mainFrame.modeDropdown then mainFrame.modeDropdown:Hide() end
        if mainFrame.poolDropdown then mainFrame.poolDropdown:Hide() end
        if expDropdown:IsShown() then
            expDropdown:Hide()
            ns:SetControllerFocus(self)
        else
            expDropdown:ClearAllPoints()
            expDropdown:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
            expDropdown:Rebuild()
            expDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    mainFrame.bannerExpBtn = bannerExpBtn

    local tabTitles = { "[LB] Identity", "First Glances", "Bio & Lore", "Directory", "Profiles", "Gratitude", "Settings", "Dev", "Emotes [RB]" }
    for i, title in ipairs(tabTitles) do
        local tb = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
        tb:SetSize(92, 30)
        tb:SetPoint("TOPLEFT", 12 + (i - 1) * 95, -108)
        ns:ApplySurface(tb, M3.surfaceLow, { 0, 0, 0, 0 })
        ns:EnableClipping(tb)
        tb.isTabBarBtn = true
        tb.activeBar = tb:CreateTexture(nil, "OVERLAY")
        tb.activeBar:SetHeight(3)
        tb.activeBar:SetPoint("BOTTOMLEFT", 8, 0)
        tb.activeBar:SetPoint("BOTTOMRIGHT", -8, 0)
        tb.activeBar:SetColorTexture(i == 8 and 0.99 or 0.54, i == 8 and 0.84 or 0.71, i == 8 and 0.39 or 0.97, 1)
        tb.activeBar:Hide()
        tb.label = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tb.label:SetPoint("CENTER", 0, 1)
        tb.label:SetText(title)
        tb:SetScript("OnClick", function() ns:PlayUISound(); ns:SelectTab(i) end)
        tabButtons[i] = tb

        local panel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 12, -142)
        panel:SetPoint("BOTTOMRIGHT", -12, 40)
        ns:ApplySurface(panel, M3.surfaceLow, M3.outline)
        ns:EnableClipping(panel)
        panel:Hide()
        tabPanels[i] = panel
    end

    BuildEmotesTab(tabPanels[9], picker)

    local p1 = tabPanels[1]
    local function AutoCommitTab1()
        CommitModifiedBoxesToProfile(false)
        RefreshHeaderBanner()
        RefreshEyeSwatchBox()
        RefreshClassSwatchBox()
        ns:ShowStatusToast("Saved character vitals to PadRPDB")
    end

    p1.subTabCore = ns:CreateMaterialButton(p1, "1. Core", 200, 26, 16, -10, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        if mainFrame.presetDropdown then mainFrame.presetDropdown:Hide() end
        if mainFrame.expDropdown then mainFrame.expDropdown:Hide() end
        activeIdentityPage = 1
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p1.subTabVitals = ns:CreateMaterialButton(p1, "2. Details", 200, 26, 224, -10, nil, function()
        CommitModifiedBoxesToProfile(false)
        if mainFrame.presetDropdown then mainFrame.presetDropdown:Hide() end
        if mainFrame.expDropdown then mainFrame.expDropdown:Hide() end
        activeIdentityPage = 2
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p1.subTabExtras = ns:CreateMaterialButton(p1, "3. Extras / RP Options", 224, 26, 432, -10, nil, function()
        CommitModifiedBoxesToProfile(false)
        if mainFrame.presetDropdown then mainFrame.presetDropdown:Hide() end
        if mainFrame.expDropdown then mainFrame.expDropdown:Hide() end
        activeIdentityPage = 3
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)

    local pageCore = CreateFrame("Frame", nil, p1)
    pageCore:SetPoint("TOPLEFT", 0, -40)
    pageCore:SetPoint("BOTTOMRIGHT", 0, 52)
    p1.pageCore = pageCore

    p1.pxBox = ns:CreateMaterialEditBox(pageCore, "Prefix", "e.g., Sir / Sister", 16, -6, 96, 28, AutoCommitTab1)
    p1.fnBox = ns:CreateMaterialEditBox(pageCore, "First Name", "e.g., Malachar", 122, -6, 150, 28, AutoCommitTab1)
    p1.lnBox = ns:CreateMaterialEditBox(pageCore, "Last Name", "e.g., Gray", 282, -6, 150, 28, AutoCommitTab1)
    p1.tiBox = ns:CreateMaterialEditBox(pageCore, "Full RP Title", "e.g., Master Arcanist", 442, -6, 198, 28, AutoCommitTab1)

    p1.raBox = ns:CreateMaterialEditBox(pageCore, "RP Race (Blank = Default)", "e.g., Human", 16, -60, 196, 28, AutoCommitTab1)
    p1.clBox = ns:CreateMaterialEditBox(pageCore, "RP Class / Occupation", "e.g., Warlock", 222, -60, 168, 28, AutoCommitTab1)
    p1.classSwatchBtn = CreateColorSwatchButton(pageCore, 398, -75, "CLASS", function()
        ns.profile.classColorHex = nil
        ns.profile.nameColorHex = nil
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        RefreshClassSwatchBox()
        RefreshHeaderBanner()
        SyncSelfProfileToLocalCache()
        ns:RefreshTargetCard()
        ns:ShowStatusToast("Class & Name color reset to default")
    end)
    p1.prBox = ns:CreateMaterialEditBox(pageCore, "Pronouns", "e.g., He/Him", 436, -60, 204, 28, AutoCommitTab1)

    p1.cuBox = ns:CreateMaterialEditBox(pageCore, "Currently (Select Preset, Cycle, or Type Custom)", "What is your character doing right now?", 16, -116, 336, 28, AutoCommitTab1)
    p1.presetBtn = ns:CreateMaterialButton(pageCore, "Presets [v]", 82, 28, 358, -131, "AMBER", function()
        if mainFrame.expDropdown then mainFrame.expDropdown:Hide() end
        if mainFrame.presetDropdown:IsShown() then
            mainFrame.presetDropdown:Hide()
            ns:SetControllerFocus(p1.presetBtn)
        else
            mainFrame.presetDropdown.page = 1
            mainFrame.presetDropdown:Rebuild()
            mainFrame.presetDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p1.cycleCuBtn = ns:CreateMaterialButton(pageCore, "Cycle", 58, 28, 448, -131, "PRIMARY", function()
        ns:CycleCurrentlyPreset()
        p1.cuBox:SetCleanText(ns.profile.currently or "")
        SyncSelfProfileToLocalCache()
        ns:ShowStatusToast("Cycled Currently status")
    end)
    p1.savePresetBtn = ns:CreateMaterialButton(pageCore, "+ Save", 60, 28, 516, -131, "MINT", function()
        local customTxt = strtrim(p1.cuBox:GetText() or "")
        if customTxt == "" then return end
        for _, existing in ipairs(ns.db.currentlyPresets) do
            if existing == customTxt then ns:ShowStatusToast("Preset already in list!"); return end
        end
        table.insert(ns.db.currentlyPresets, customTxt)
        ns.profile.currently = customTxt
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        SyncSelfProfileToLocalCache()
        if mainFrame.presetDropdown:IsShown() then mainFrame.presetDropdown:Rebuild() end
        ns:ShowStatusToast("Added new Currently preset!")
    end)
    p1.clearCuBtn = ns:CreateMaterialButton(pageCore, "Clear", 54, 28, 584, -131, nil, function()
        p1.cuBox:SetCleanText("")
        ns.profile.currently = ""
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        SyncSelfProfileToLocalCache()
        ns:ShowStatusToast("Cleared Currently status")
    end)

    p1.oocNotesBox = ns:CreateScrollableTextEditor(
        pageCore,
        "Other Information (OOC) — add spaced notes, paragraphs, or boundaries...",
        16, -174, 624, 92,
        AutoCommitTab1
    )

    local dropdown = CreateFrame("Frame", nil, pageCore, "BackdropTemplate")
    dropdown:SetSize(426, 194)
    dropdown:SetPoint("TOPLEFT", p1.cuBox, "BOTTOMLEFT", 0, -2)
    dropdown:SetFrameLevel(p1:GetFrameLevel() + 25)
    ns:ApplySurface(dropdown, M3.surfaceDim, M3.primary)
    ns:EnableClipping(dropdown)
    dropdown:EnableMouse(true)
    dropdown:Hide()
    dropdown.page, dropdown.rows = 1, {}
    dropdown.headerText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdown.headerText:SetPoint("TOPLEFT", 10, -8)
    dropdown.prevBtn = ns:CreateMaterialButton(dropdown, "<", 28, 20, 326, -5, nil, function() dropdown.page = math.max(1, dropdown.page - 1); dropdown:Rebuild() end)
    dropdown.nextBtn = ns:CreateMaterialButton(dropdown, ">", 28, 20, 358, -5, nil, function() dropdown.page = dropdown.page + 1; dropdown:Rebuild() end)
    ns:CreateMaterialButton(dropdown, "X", 28, 20, 392, -5, "CORAL", function() dropdown:Hide(); ns:SetControllerFocus(p1.presetBtn) end)
    dropdown.Rebuild = function(self)
        for _, r in ipairs(self.rows) do r.selectBtn:Hide(); r.delBtn:Hide() end
        local presets = ns.db.currentlyPresets or {}
        local perPage = 6
        local totalPages = math.max(1, math.ceil(#presets / perPage))
        self.page = math.max(1, math.min(totalPages, self.page))
        self.headerText:SetText(string.format("|cff8ab4f8SAVED PRESETS (%d)|r - Page %d/%d", #presets, self.page, totalPages))
        local startIdx = (self.page - 1) * perPage
        local visibleCount = math.min(perPage, math.max(0, #presets - startIdx))
        self:SetHeight(math.max(58, visibleCount * 26 + 34))
        for i = 1, visibleCount do
            local actualIdx = startIdx + i
            local r = self.rows[i]
            if not r then
                r = {}
                r.selectBtn = ns:CreateMaterialButton(self, "", 378, 24, 6, -28 - (i - 1) * 26, nil, function(btn)
                    ns.profile.currently = btn.presetText
                    p1.cuBox:SetCleanText(btn.presetText)
                    ns:SnapshotActiveProfile()
                    ns:SyncMSP()
                    SyncSelfProfileToLocalCache()
                    dropdown:Hide()
                    ns:SetControllerFocus(p1.presetBtn)
                end)
                r.selectBtn.label:SetJustifyH("LEFT")
                AttachWheelScroller(r.selectBtn, function(step)
                    dropdown.page = dropdown.page + step
                    dropdown:Rebuild()
                end)
                r.delBtn = ns:CreateMaterialButton(self, "X", 30, 24, 388, -28 - (i - 1) * 26, "CORAL", function(btn)
                    if btn.presetIndex and ns.db.currentlyPresets[btn.presetIndex] then
                        table.remove(ns.db.currentlyPresets, btn.presetIndex)
                        dropdown:Rebuild()
                        ns:FocusFirstInScope()
                    end
                end)
                AttachWheelScroller(r.delBtn, function(step)
                    dropdown.page = dropdown.page + step
                    dropdown:Rebuild()
                end)
                self.rows[i] = r
            end
            r.selectBtn.presetText = presets[actualIdx]
            r.selectBtn:SetText(presets[actualIdx])
            r.selectBtn:Show()
            r.delBtn.presetIndex = actualIdx
            r.delBtn:Show()
        end
    end
    AttachWheelScroller(dropdown, function(step)
        dropdown.page = dropdown.page + step
        dropdown:Rebuild()
    end)
    mainFrame.presetDropdown = dropdown

    local pageVitals = CreateFrame("Frame", nil, p1)
    pageVitals:SetPoint("TOPLEFT", 0, -40)
    pageVitals:SetPoint("BOTTOMRIGHT", 0, 52)
    pageVitals:Hide()
    p1.pageVitals = pageVitals

    p1.hoBox = ns:CreateMaterialEditBox(pageVitals, "House / Clan / Guild Name", "e.g., House Gray", 16, -6, 306, 26, AutoCommitTab1)
    p1.moBox = ns:CreateMaterialEditBox(pageVitals, "Motto / Catchphrase", "e.g., It isn't fraud if they're impressed.", 334, -6, 306, 26, AutoCommitTab1)

    p1.gnBox = ns:CreateMaterialEditBox(pageVitals, "Gender", "e.g., Male", 16, -54, 130, 26, AutoCommitTab1)
    p1.agBox = ns:CreateMaterialEditBox(pageVitals, "Age", "e.g., 32", 156, -54, 110, 26, AutoCommitTab1)
    p1.htBox = ns:CreateMaterialEditBox(pageVitals, "Height", "e.g., 6'0\" / Tall", 276, -54, 160, 26, AutoCommitTab1)
    p1.wtBox = ns:CreateMaterialEditBox(pageVitals, "Build / Body Shape", "e.g., Athletic", 446, -54, 194, 26, AutoCommitTab1)

    p1.eyBox = ns:CreateMaterialEditBox(pageVitals, "Eye Color", "e.g., Pale amber / Luminous", 16, -102, 446, 26, AutoCommitTab1)
    p1.eyeSwatchBtn = CreateColorSwatchButton(pageVitals, 470, -117, "EYE", function()
        ns.profile.eyeColorHex = nil
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        RefreshEyeSwatchBox()
        SyncSelfProfileToLocalCache()
        ns:ShowStatusToast("Eye color swatch cleared")
    end)

    local portraitPickBtn = ns:CreateMaterialButton(pageVitals, "Portrait", 140, 26, 506, -117, nil, function(self)
        picker:OpenForPortrait(self)
    end)
    portraitPickBtn.iconTex = portraitPickBtn:CreateTexture(nil, "OVERLAY")
    portraitPickBtn.iconTex:SetSize(20, 20)
    portraitPickBtn.iconTex:SetPoint("LEFT", portraitPickBtn, "LEFT", 8, 0)
    portraitPickBtn.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portraitPickBtn.label:ClearAllPoints()
    portraitPickBtn.label:SetPoint("LEFT", portraitPickBtn.iconTex, "RIGHT", 8, 0)
    portraitPickBtn.label:SetPoint("RIGHT", portraitPickBtn, "RIGHT", -8, 0)
    portraitPickBtn.label:SetJustifyH("LEFT")
    p1.portraitPickBtn = portraitPickBtn

    p1.faceBox = ns:CreateMaterialEditBox(pageVitals, "Facial Features", "e.g., Sharp smirk, manicured beard", 16, -148, 202, 26, AutoCommitTab1)
    p1.tatBox = ns:CreateMaterialEditBox(pageVitals, "Tattoos / Markings", "e.g., Arcane sigil on left forearm", 228, -148, 202, 26, AutoCommitTab1)
    p1.voiceBox = ns:CreateMaterialEditBox(pageVitals, "Voice Reference", "e.g., Calm, measured cadence", 440, -148, 200, 26, AutoCommitTab1)

    p1.hbBox = ns:CreateMaterialEditBox(pageVitals, "Birthplace", "e.g., Lordaeron (Allegedly)", 16, -194, 306, 26, AutoCommitTab1)
    p1.hhBox = ns:CreateMaterialEditBox(pageVitals, "Residence", "e.g., The Mage Quarter, Stormwind", 334, -194, 306, 26, AutoCommitTab1)

    local pageExtras = CreateFrame("Frame", nil, p1)
    pageExtras:SetPoint("TOPLEFT", 0, -40)
    pageExtras:SetPoint("BOTTOMRIGHT", 0, 52)
    pageExtras:Hide()
    p1.pageExtras = pageExtras

    p1.relBtn = ns:CreateMaterialButton(pageExtras, "Relationship: Not Specified", 306, 26, 16, -22, "AMBER", function()
        local code = ns:CycleRelationshipStatus()
        ns:RefreshControllerUI()
        ns:ShowStatusToast("Relationship: " .. ns:GetRelationshipLabel(code))
    end)
    p1.styleBtn = ns:CreateMaterialButton(pageExtras, "RP Style: Normal", 306, 26, 334, -22, "PRIMARY", function()
        local cur = tostring((ns.profile and ns.profile.rpStyle) or "1")
        local nextIdx = 1
        for idx, item in ipairs(RP_EXPERIENCE_LIST) do
            if item.code == cur then
                nextIdx = (idx % #RP_EXPERIENCE_LIST) + 1
                break
            end
        end
        ApplyRPExperienceSelection(RP_EXPERIENCE_LIST[nextIdx].code)
        ns:RefreshControllerUI()
    end)

    p1.topicBtns = {}
    for idx, t in ipairs(RP_STYLE_TOPICS) do
        local rowIdx = (idx <= 3) and 0 or 1
        local colIdx = (idx - 1) % 3
        local btnX = 16 + colIdx * 212
        local btnY = -68 - rowIdx * 36
        local tBtn = ns:CreateMaterialButton(pageExtras, "", 202, 26, btnX, btnY, nil, function(self)
            local updated = CycleTopicConsent(t.key, t.defaultVal)
            self:SetText(FormatTopicButtonText(t.label, updated))
            RefreshHeaderBanner()
            ns:ShowStatusToast(t.label .. ": " .. updated)
        end)
        tBtn.label:SetJustifyH("LEFT")
        p1.topicBtns[t.key] = tBtn
    end

    p1.lgbtqBtn = ns:CreateMaterialButton(pageExtras, "", 304, 26, 16, -148, "MINT", function()
        ns.profile.lgbtqFriendly = not (ns.profile.lgbtqFriendly ~= false)
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        ns:RefreshControllerUI()
    end)
    p1.erpBtn = ns:CreateMaterialButton(pageExtras, "", 304, 26, 336, -148, nil, function()
        ns.profile.erpFriendly = not (ns.profile.erpFriendly and true or false)
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        ns:RefreshControllerUI()
    end)
    p1.mdniBtn = ns:CreateMaterialButton(pageExtras, "", 304, 26, 16, -182, nil, function()
        ns.profile.mdni = not (ns.profile.mdni and true or false)
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        ns:RefreshControllerUI()
    end)

    local saveIdentityBtn = ns:CreateMaterialButton(p1, "Save Profile", 470, 36, 16, -354, "PRIMARY", function()
        CommitModifiedBoxesToProfile(true)
        RefreshHeaderBanner()
        ns:ShowStatusToast("Profile permanently saved & synced!")
    end)
    saveIdentityBtn:ClearAllPoints()
    saveIdentityBtn:SetPoint("BOTTOMLEFT", p1, "BOTTOMLEFT", 16, 14)
    saveIdentityBtn:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", -168, 14)

    local revertBtn = ns:CreateMaterialButton(p1, "Revert Unsaved", 144, 36, 0, 0, nil, function()
        ns:LoadProfileIntoUI()
        RefreshHeaderBanner()
    end)
    revertBtn:ClearAllPoints()
    revertBtn:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", -16, 14)

    local p2 = tabPanels[2]
    local gIntro = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gIntro:SetPoint("TOPLEFT", 16, -12)
    gIntro:SetPoint("TOPRIGHT", -16, -12)
    gIntro:SetJustifyH("LEFT")
    gIntro:SetText("|cff8ab4f8FIRST GLANCES (1 - 5)|r  |cff9aa0a6-  Scroll with D-Pad or wheel to edit all 5 slots; all broadcast to TRP3 / MRP / XRP|r")

    local glanceScroll = CreateFrame("ScrollFrame", "PadRP_GlancesScrollFrame", p2, "UIPanelScrollFrameTemplate")
    glanceScroll:SetPoint("TOPLEFT", 12, -32)
    glanceScroll:SetPoint("BOTTOMRIGHT", -28, 56)
    glanceScroll:EnableMouseWheel(true)
    ns:EnableClipping(glanceScroll)
    p2.glanceScroll = glanceScroll

    local glanceChild = CreateFrame("Frame", nil, glanceScroll)
    glanceChild:SetSize(580, 576)
    glanceScroll:SetScrollChild(glanceChild)
    p2.glanceChild = glanceChild

    local function IsFocusInsideGlanceScroll()
        local f = ns.currentFocus
        if not f then return false end
        if f.glanceScrollFrame == glanceScroll then return true end
        local parent = f.GetParent and f:GetParent()
        while parent do
            if parent == glanceChild or parent == glanceScroll then
                return true
            end
            parent = parent.GetParent and parent:GetParent()
        end
        return false
    end

    local function ClearGlanceFocusHighlight()
        local f = ns.currentFocus
        if not f then return end
        if ns.SetControllerFocus then
            ns:SetControllerFocus(nil)
        end
        if ns.currentFocus == f then
            if f.OnFocusChanged then
                pcall(f.OnFocusChanged, f, false)
            end
            local onLeave = f.GetScript and f:GetScript("OnLeave")
            if onLeave then
                pcall(onLeave, f)
            end
            if f.SetBackdropBorderColor and ns.M3 and ns.M3.outline then
                pcall(f.SetBackdropBorderColor, f, unpack(ns.M3.outline))
            end
            ns.currentFocus = nil
        end
    end

    local function StepGlanceScroll(step)
        if not glanceScroll or not glanceChild then return end
        if IsFocusInsideGlanceScroll() then
            ClearGlanceFocusHighlight()
        end
        local cur = glanceScroll:GetVerticalScroll() or 0
        local viewH = glanceScroll:GetHeight() or 340
        local contentH = glanceChild:GetHeight() or (5 * 112 + 12)
        local maxS = math.max(0, contentH - viewH)
        if glanceScroll.GetVerticalScrollRange then
            local apiRange = glanceScroll:GetVerticalScrollRange() or 0
            if apiRange > maxS then
                maxS = apiRange
            end
        end
        glanceScroll:SetVerticalScroll(math.max(0, math.min(maxS, cur + (step * 72))))
    end

    p2:SetScript("OnShow", function()
        LayoutGlanceCards()
    end)
    glanceScroll:SetScript("OnSizeChanged", function()
        LayoutGlanceCards()
    end)
    glanceScroll:SetScript("OnMouseWheel", function(_, delta)
        if delta and delta ~= 0 then
            StepGlanceScroll(delta > 0 and -1 or 1)
        end
    end)
    AttachWheelScroller(p2, StepGlanceScroll)
    AttachWheelScroller(glanceChild, StepGlanceScroll)

    p2.cards = {}
    local function AutoCommitGlances() CommitModifiedBoxesToProfile(false) end
    for slot = 1, 5 do
        local card = CreateFrame("Frame", nil, glanceChild, "BackdropTemplate")
        card:SetHeight(104)
        card:SetPoint("TOPLEFT", glanceChild, "TOPLEFT", 0, -4 - (slot - 1) * 112)
        card:SetWidth(576)
        ns:ApplySurface(card, M3.surfaceDim, M3.outline)
        ns:EnableClipping(card)
        card.slotIndex = slot
        card.slotBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.slotBadge:SetPoint("TOPLEFT", 12, -8)
        card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. slot .. "|r")

        local iconBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        iconBtn:SetSize(44, 44)
        iconBtn:SetPoint("TOPLEFT", 14, -44)
        ns:ApplySurface(iconBtn, M3.surface, M3.primary)
        iconBtn.glanceScrollFrame = glanceScroll
        iconBtn.glanceIndex = slot
        card.iconBtn = iconBtn
        card.iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        card.iconTex:SetSize(38, 38)
        card.iconTex:SetPoint("CENTER")
        card.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconBtn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
        iconBtn:SetScript("OnClick", function(self)
            ns:PlayUISound()
            if card.slotIndex then
                picker:OpenForSlot(card.slotIndex, self)
            end
        end)
        ns:RegisterFocusable(iconBtn, function() iconBtn:Click("LeftButton") end)

        card.titleBox = ns:CreateMaterialEditBox(card, "1. Short Hook / Trait Name", "", 74, -24, 170, 26, AutoCommitGlances)
        card.titleBox.glanceScrollFrame = glanceScroll
        card.titleBox.glanceIndex = slot

        card.detailBox = ns:CreateMaterialEditBox(card, "2. Tooltip Description", "", 254, -24, 240, 26, AutoCommitGlances)
        card.detailBox.glanceScrollFrame = glanceScroll
        card.detailBox.glanceIndex = slot

        card.clrBtn = ns:CreateMaterialButton(card, "Clear", 56, 26, 510, -39, nil, function()
            local sIdx = card.slotIndex
            card.titleBox:SetCleanText("")
            card.detailBox:SetCleanText("")
            if sIdx and ns.profile.glances[sIdx] then
                ns.profile.glances[sIdx].title, ns.profile.glances[sIdx].detail = "", ""
            end
            ns:SnapshotActiveProfile()
            ns:SyncMSP()
        end)
        card.clrBtn.glanceScrollFrame = glanceScroll
        card.clrBtn.glanceIndex = slot

        AttachWheelScroller(card, StepGlanceScroll)
        AttachWheelScroller(iconBtn, StepGlanceScroll)
        AttachWheelScroller(card.titleBox, StepGlanceScroll)
        AttachWheelScroller(card.titleBox.editBox, StepGlanceScroll)
        AttachWheelScroller(card.titleBox.padBtn, StepGlanceScroll)
        AttachWheelScroller(card.detailBox, StepGlanceScroll)
        AttachWheelScroller(card.detailBox.editBox, StepGlanceScroll)
        AttachWheelScroller(card.detailBox.padBtn, StepGlanceScroll)
        AttachWheelScroller(card.clrBtn, StepGlanceScroll)

        p2.cards[slot] = card
    end

    local saveGlanceBtn = ns:CreateMaterialButton(p2, "Save First Glances", 624, 36, 16, -354, "PRIMARY", function()
        CommitModifiedBoxesToProfile(true)
        ns:ShowStatusToast("All 5 First Glances saved & synced!")
    end)
    saveGlanceBtn:ClearAllPoints()
    saveGlanceBtn:SetPoint("BOTTOMLEFT", p2, "BOTTOMLEFT", 16, 14)
    saveGlanceBtn:SetPoint("BOTTOMRIGHT", p2, "BOTTOMRIGHT", -16, 14)

    local p3 = tabPanels[3]
    p3.appTabBtn = ns:CreateMaterialButton(p3, "1. Physical Appearance & Attire", 254, 32, 16, -12, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        activeBioMode = "APPEARANCE"
        p3.bioEditor:SetCleanText(ns.profile.description)
        ns:RefreshControllerUI()
    end)
    p3.hisTabBtn = ns:CreateMaterialButton(p3, "2. Character History & Background", 254, 32, 278, -12, nil, function()
        CommitModifiedBoxesToProfile(false)
        activeBioMode = "HISTORY"
        p3.bioEditor:SetCleanText(ns.profile.history)
        ns:RefreshControllerUI()
    end)
    p3.clearBioBtn = ns:CreateMaterialButton(p3, "Clear Text", 104, 32, 540, -12, "CORAL", function(self)
        local now = GetTime()
        if now < confirmClearBioUntil then
            confirmClearBioUntil = 0
            self:SetText("Clear Text")
            p3.bioEditor:SetCleanText("")
            if activeBioMode == "APPEARANCE" then ns.profile.description = "" else ns.profile.history = "" end
            ns:SnapshotActiveProfile()
            ns:SyncMSP()
        else
            confirmClearBioUntil = now + 4
            self:SetText("|cfff28b82Confirm?|r")
        end
    end)
    p3.sectionHint = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p3.sectionHint:SetPoint("TOPLEFT", 16, -52)
    p3.bioEditor = ns:CreateScrollableTextEditor(p3, "", 16, -72, 624, 268, function() CommitModifiedBoxesToProfile(false) end)
    p3.bioEditor:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -16, 58)
    local saveBioBtn = ns:CreateMaterialButton(p3, "Save Physical Appearance & Character History", 624, 36, 16, -354, "PRIMARY", function()
        CommitModifiedBoxesToProfile(true)
        ns:ShowStatusToast("Appearance & History saved!")
    end)
    saveBioBtn:ClearAllPoints()
    saveBioBtn:SetPoint("BOTTOMLEFT", p3, "BOTTOMLEFT", 16, 14)
    saveBioBtn:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -16, 14)

    local p4 = tabPanels[4]
    p4.countLabel = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p4.countLabel:SetPoint("TOPLEFT", 16, -12)

    local openLiveBtn = ns:CreateMaterialButton(p4, "Open Target Dossier", 142, 24, 0, 0, "PRIMARY", function()
        ns:OpenTargetDossier()
    end)
    openLiveBtn:ClearAllPoints()
    openLiveBtn:SetPoint("TOPRIGHT", p4, "TOPRIGHT", -16, -8)

    p4.searchBox = ns:CreateMaterialEditBox(p4, nil, "Search by Name, Title, House, or Note...", 16, -38, 220, 26, function(txt)
        knownSearchFilter = txt or ""
        knownListPage = 1
        ns:RefreshTargetCard()
    end)
    p4.searchBox:SetScript("OnTextChanged", function(self)
        knownSearchFilter = self:GetText() or ""
        knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.notableOnlyBtn = ns:CreateMaterialButton(p4, "[ ] Notable", 96, 26, 242, -38, nil, function()
        knownNotableOnly = not knownNotableOnly
        knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.sortBtn = ns:CreateMaterialButton(p4, "Sort: Recent", 92, 26, 344, -38, "PRIMARY", function()
        knownSortMode = (knownSortMode == "RECENT") and "NAME" or "RECENT"
        knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.prevPageBtn = ns:CreateMaterialButton(p4, "< Prev", 54, 26, 442, -38, nil, function()
        knownListPage = math.max(1, knownListPage - 1)
        ns:RefreshTargetCard()
    end)

    p4.pageLabel = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p4.pageLabel:SetJustifyH("CENTER")

    p4.nextPageBtn = ns:CreateMaterialButton(p4, "Next >", 54, 26, 586, -38, nil, function()
        knownListPage = knownListPage + 1
        ns:RefreshTargetCard()
    end)

    AttachWheelScroller(p4, function(step)
        knownListPage = knownListPage + step
        ns:RefreshTargetCard()
    end)

    p4.knownRows = {}
    for i = 1, 8 do
        local rowY = -72 - (i - 1) * 35
        local rowBtn = ns:CreateMaterialButton(p4, "", 624, 32, 16, rowY, nil, function(self)
            if self.bucketKey then
                collapsedBuckets[self.bucketKey] = not collapsedBuckets[self.bucketKey]
                knownListPage = 1
                ns:RefreshTargetCard()
            elseif self.profileKey and ns.OpenTargetDossier then
                ns:OpenTargetDossier(self.profileKey)
            end
        end)
        rowBtn:SetPoint("RIGHT", p4, "RIGHT", -16, 0)
        rowBtn.directoryRowIndex = i

        rowBtn.seenLabel = rowBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rowBtn.seenLabel:SetPoint("RIGHT", -12, 0)
        rowBtn.seenLabel:SetJustifyH("RIGHT")

        rowBtn.label:ClearAllPoints()
        rowBtn.label:SetPoint("LEFT", rowBtn, "LEFT", 12, 0)
        rowBtn.label:SetPoint("RIGHT", rowBtn.seenLabel, "LEFT", -12, 0)
        rowBtn.label:SetJustifyH("LEFT")
        rowBtn.label:SetWordWrap(false)

        AttachWheelScroller(rowBtn, function(step)
            knownListPage = knownListPage + step
            ns:RefreshTargetCard()
        end)

        p4.knownRows[i] = rowBtn
    end

    local pProf = tabPanels[5]
    local profHeader = pProf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profHeader:SetPoint("TOPLEFT", 16, -10)
    profHeader:SetText("|cff8ab4f8PROFILE MANAGER|r  -  Switch, create, rename, or delete saved profiles")

    pProf.profNameBox = ns:CreateMaterialEditBox(pProf, "Active Profile Name", "e.g., Main Character", 16, -42, 260, 26, function()
        CommitModifiedBoxesToProfile(false)
        RefreshHeaderBanner()
        RefreshProfilesTab()
    end)
    pProf.newProfBtn = ns:CreateMaterialButton(pProf, "+ New Profile", 148, 26, 288, -42, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        ns:CreateNewProfile()
        RefreshProfilesTab()
    end)
    pProf.delProfBtn = ns:CreateMaterialButton(pProf, "Delete Active Profile", 166, 26, 448, -42, "CORAL", function(self)
        local now = GetTime()
        if now < confirmDeleteProfileUntil then
            confirmDeleteProfileUntil = 0
            self:SetText("Delete Active Profile")
            ns:DeleteCurrentProfile()
            RefreshProfilesTab()
        else
            confirmDeleteProfileUntil = now + 4
            self:SetText("|cfff28b82Confirm Delete?|r")
        end
    end)

    pProf.exportBtn = ns:CreateMaterialButton(pProf, "Export / Import Profile String", 280, 26, 16, -80, "AMBER", function()
        CommitModifiedBoxesToProfile(false)
        if tabPanels[7] and tabPanels[7].openExpBtn then
            tabPanels[7].openExpBtn:Click("LeftButton")
        end
    end)
    pProf.prevBtn = ns:CreateMaterialButton(pProf, "< Prev", 60, 26, 310, -80, nil, function()
        profileListPage = math.max(1, profileListPage - 1)
        RefreshProfilesTab()
    end)
    pProf.pageLabel = pProf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pProf.pageLabel:SetJustifyH("CENTER")
    pProf.nextBtn = ns:CreateMaterialButton(pProf, "Next >", 60, 26, 460, -80, nil, function()
        profileListPage = profileListPage + 1
        RefreshProfilesTab()
    end)

    pProf.rows = {}
    for i = 1, 6 do
        local row = {}
        row.selectBtn = ns:CreateMaterialButton(pProf, "", 624, 32, 16, -116 - (i - 1) * 38, nil, function(btn)
            if btn.profileId and ns.SwitchProfile then
                CommitModifiedBoxesToProfile(false)
                ns:SwitchProfile(btn.profileId)
                RefreshProfilesTab()
                ns:ShowStatusToast("Switched to profile: " .. (ns.profile.profileName or btn.profileId))
            end
        end)
        row.selectBtn:SetPoint("RIGHT", pProf, "RIGHT", -16, 0)
        row.selectBtn.label:SetJustifyH("LEFT")
        pProf.rows[i] = row
    end

    local p6 = tabPanels[6]
    p6.modeBtn = ns:CreateMaterialButton(p6, "Gratitude Mode [v]", 624, 30, 16, -10, "PRIMARY", function()
        if mainFrame.expDropdown then mainFrame.expDropdown:Hide() end
        if mainFrame.poolDropdown then mainFrame.poolDropdown:Hide() end
        if mainFrame.modeDropdown:IsShown() then
            mainFrame.modeDropdown:Hide()
            ns:SetControllerFocus(p6.modeBtn)
        else
            mainFrame.modeDropdown:Rebuild()
            mainFrame.modeDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p6.modeBtn.label:SetJustifyH("LEFT")

    local modeDropdown = CreateFrame("Frame", nil, p6, "BackdropTemplate")
    modeDropdown:SetSize(624, 196)
    modeDropdown:SetPoint("TOPLEFT", p6.modeBtn, "BOTTOMLEFT", 0, -2)
    modeDropdown:SetFrameLevel(p6:GetFrameLevel() + 30)
    ns:ApplySurface(modeDropdown, M3.surfaceDim, M3.primary)
    ns:EnableClipping(modeDropdown)
    modeDropdown:EnableMouse(true)
    modeDropdown:Hide()
    modeDropdown.rows = {}
    for i, m in ipairs(MODE_LIST) do
        local rowBtn = ns:CreateMaterialButton(modeDropdown, "", 608, 25, 8, -28 - (i - 1) * 27, nil, function()
            ns.db.gratitude.mode = m.key
            modeDropdown:Hide()
            RefreshGratitudeStudio()
            ns:SetControllerFocus(p6.modeBtn)
        end)
        rowBtn.label:SetJustifyH("LEFT")
        modeDropdown.rows[i] = rowBtn
    end
    modeDropdown.Rebuild = function(self)
        local cur = ns.db.gratitude.mode
        for i, m in ipairs(MODE_LIST) do
            local r = self.rows[i]
            local isCur = (m.key == cur)
            r:SetText((isCur and "|cff81c995[ACTIVE]  |r" or "          ") .. m.label)
            r:SetTone(isCur and "MINT" or nil)
        end
    end
    mainFrame.modeDropdown = modeDropdown

    p6.buffBtn = ns:CreateMaterialButton(p6, "Buffs", 118, 26, 16, -46, nil, function() ns.db.gratitude.thankBuffs = not ns.db.gratitude.thankBuffs; RefreshGratitudeStudio() end)
    p6.healBtn = ns:CreateMaterialButton(p6, "Heals", 118, 26, 142, -46, nil, function() ns.db.gratitude.thankHeals = not ns.db.gratitude.thankHeals; RefreshGratitudeStudio() end)
    p6.resBtn = ns:CreateMaterialButton(p6, "Res", 118, 26, 268, -46, nil, function() ns.db.gratitude.thankRes = not ns.db.gratitude.thankRes; RefreshGratitudeStudio() end)
    p6.specialBtn = ns:CreateMaterialButton(p6, "Portals/CDs", 124, 26, 394, -46, nil, function() ns.db.gratitude.thankSpecial = not ns.db.gratitude.thankSpecial; RefreshGratitudeStudio() end)
    p6.sessionBtn = ns:CreateMaterialButton(p6, "1x/Session", 114, 26, 526, -46, nil, function() ns.db.gratitude.oncePerSession = not ns.db.gratitude.oncePerSession; RefreshGratitudeStudio() end)

    p6.cdMinusBtn = ns:CreateMaterialButton(p6, "-15s", 52, 24, 16, -78, nil, function() ns.db.gratitude.cooldown = math.max(15, (ns.db.gratitude.cooldown or 60) - 15); RefreshGratitudeStudio() end)
    p6.cdLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.cdLabel:SetJustifyH("CENTER")
    p6.cdPlusBtn = ns:CreateMaterialButton(p6, "+15s", 52, 24, 185, -78, nil, function() ns.db.gratitude.cooldown = math.min(600, (ns.db.gratitude.cooldown or 60) + 15); RefreshGratitudeStudio() end)

    p6.healMinusBtn = ns:CreateMaterialButton(p6, "-5%", 52, 24, 332, -78, nil, function() ns.db.gratitude.minHealPercent = math.max(1, (ns.db.gratitude.minHealPercent or 15) - 5); RefreshGratitudeStudio() end)
    p6.healPctLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.healPctLabel:SetJustifyH("CENTER")
    p6.healPlusBtn = ns:CreateMaterialButton(p6, "+5%", 52, 24, 520, -78, nil, function() ns.db.gratitude.minHealPercent = math.min(80, (ns.db.gratitude.minHealPercent or 15) + 5); RefreshGratitudeStudio() end)

    p6.poolToggleBtn = ns:CreateMaterialButton(p6, "Phrase Pool [v]", 336, 26, 16, -110, "AMBER", function()
        if mainFrame.expDropdown then mainFrame.expDropdown:Hide() end
        if mainFrame.modeDropdown then mainFrame.modeDropdown:Hide() end
        if mainFrame.poolDropdown:IsShown() then
            mainFrame.poolDropdown:Hide()
            ns:SetControllerFocus(p6.poolToggleBtn)
        else
            mainFrame.poolDropdown:Rebuild()
            mainFrame.poolDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p6.poolToggleBtn.label:SetJustifyH("LEFT")

    local poolDropdown = CreateFrame("Frame", nil, p6, "BackdropTemplate")
    poolDropdown:SetSize(440, 170)
    poolDropdown:SetPoint("TOPLEFT", p6.poolToggleBtn, "BOTTOMLEFT", 0, -2)
    poolDropdown:SetFrameLevel(p6:GetFrameLevel() + 30)
    ns:ApplySurface(poolDropdown, M3.surfaceDim, M3.amber)
    ns:EnableClipping(poolDropdown)
    poolDropdown:EnableMouse(true)
    poolDropdown:Hide()
    poolDropdown.rows = {}
    for i, item in ipairs(POOL_LIST) do
        local rowBtn = ns:CreateMaterialButton(poolDropdown, "", 424, 25, 8, -28 - (i - 1) * 27, nil, function()
            editPoolIdx, editPhraseIdx = i, 1
            poolDropdown:Hide()
            RefreshGratitudeStudio()
            ns:SetControllerFocus(p6.poolToggleBtn)
        end)
        rowBtn.label:SetJustifyH("LEFT")
        poolDropdown.rows[i] = rowBtn
    end
    poolDropdown.Rebuild = function(self)
        for i, item in ipairs(POOL_LIST) do
            local r = self.rows[i]
            local isCur = (i == editPoolIdx)
            r:SetText((isCur and "|cfffdd663[EDITING] |r" or "          ") .. item.label)
            r:SetTone(isCur and "AMBER" or nil)
        end
    end
    mainFrame.poolDropdown = poolDropdown

    p6.addPhraseBtn = ns:CreateMaterialButton(p6, "+ Add Phrase", 100, 26, 358, -110, "PRIMARY", function()
        local pool = GetActiveGratitudePool()
        table.insert(pool, "nods warmly to %name in thanks for the %spell.")
        editPhraseIdx = #pool
        RefreshGratitudeStudio()
    end)
    p6.prevPhraseBtn = ns:CreateMaterialButton(p6, "<", 28, 26, 468, -110, nil, function() editPhraseIdx = math.max(1, editPhraseIdx - 3); RefreshGratitudeStudio() end)
    p6.phrasePageLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.phrasePageLabel:SetJustifyH("CENTER")
    p6.nextPhraseBtn = ns:CreateMaterialButton(p6, ">", 28, 26, 612, -110, nil, function()
        local pool = GetActiveGratitudePool()
        editPhraseIdx = math.min(#pool, editPhraseIdx + 3)
        RefreshGratitudeStudio()
    end)

    local function StepPhrasePage(step)
        local pool = GetActiveGratitudePool()
        editPhraseIdx = math.max(1, math.min(#pool, editPhraseIdx + (step * 3)))
        RefreshGratitudeStudio()
    end
    AttachWheelScroller(p6, StepPhrasePage)

    p6.phraseRows = {}
    for i = 1, 3 do
        local rowY = -142 - (i - 1) * 28
        local r = {}
        r.delBtn = ns:CreateMaterialButton(p6, "X", 32, 25, 0, 0, "CORAL", function()
            local pool = GetActiveGratitudePool()
            if #pool > 1 and r.phraseIndex and pool[r.phraseIndex] then
                table.remove(pool, r.phraseIndex)
                editPhraseIdx = math.min(#pool, math.max(1, editPhraseIdx))
                RefreshGratitudeStudio()
            end
        end)
        r.delBtn:ClearAllPoints()
        r.delBtn:SetPoint("TOPRIGHT", p6, "TOPRIGHT", -16, rowY)
        AttachWheelScroller(r.delBtn, StepPhrasePage)

        r.selectBtn = ns:CreateMaterialButton(p6, "", 586, 25, 16, rowY, nil, function()
            if r.phraseIndex then editPhraseIdx = r.phraseIndex; RefreshGratitudeStudio() end
        end)
        r.selectBtn:SetPoint("RIGHT", r.delBtn, "LEFT", -6, 0)
        r.selectBtn.label:SetJustifyH("LEFT")
        AttachWheelScroller(r.selectBtn, StepPhrasePage)

        p6.phraseRows[i] = r
    end

    p6.phraseBox = ns:CreateMaterialEditBox(p6, "Edit Selected Phrase", "", 16, -232, 624, 30, function(txt)
        local pool = GetActiveGratitudePool()
        local trimmed = strtrim(txt or "")
        if trimmed ~= "" then pool[editPhraseIdx] = trimmed; RefreshGratitudeStudio() end
    end)

    local tokens = {
        { label = "+ %name",     token = "%name" },
        { label = "+ %fullname", token = "%fullname" },
        { label = "+ %spell",    token = "%spell" },
        { label = "+ %class",    token = "%class" },
        { label = "+ %race",     token = "%race" },
    }
    p6.tokenBtns = {}
    for idx, tk in ipairs(tokens) do
        p6.tokenBtns[idx] = ns:CreateMaterialButton(p6, tk.label, 82, 26, 16 + (idx - 1) * 86, -284, nil, function()
            local cur = p6.phraseBox:GetText() or ""
            local sep = (cur ~= "" and string.sub(cur, -1) ~= " ") and " " or ""
            p6.phraseBox:SetCleanText(cur .. sep .. tk.token)
            GetActiveGratitudePool()[editPhraseIdx] = p6.phraseBox:GetText()
            RefreshGratitudeStudio()
        end)
    end
    p6.savePhraseBtn = ns:CreateMaterialButton(p6, "Save Phrase", 90, 26, 448, -284, "MINT", function()
        local txt = strtrim(p6.phraseBox:GetText() or "")
        if txt ~= "" then GetActiveGratitudePool()[editPhraseIdx] = txt; RefreshGratitudeStudio() end
    end)
    p6.previewBtn = ns:CreateMaterialButton(p6, "Preview", 84, 26, 546, -284, "AMBER", function()
        local preview = ns:FormatTokens(p6.phraseBox:GetText(), UnitExists("target") and "target" or "player", "Mark of the Wild")
        ns:LogNet("PREVIEW", "ff81c995", preview)
        ns:ShowStatusToast("Preview: " .. preview)
    end)
    local quickThankBottom = ns:CreateMaterialButton(p6, "Trigger Quick-Thank Now (Target or Last Helper)", 624, 36, 16, -356, "PRIMARY", function() ns:QuickThankAction() end)
    quickThankBottom:ClearAllPoints()
    quickThankBottom:SetPoint("BOTTOMLEFT", p6, "BOTTOMLEFT", 16, 14)
    quickThankBottom:SetPoint("BOTTOMRIGHT", p6, "BOTTOMRIGHT", -16, 14)

    local p7 = tabPanels[7]
    p7.scaleMinusBtn = ns:CreateMaterialButton(p7, "Scale -", 68, 28, 16, -14, nil, function() ns.db.ui.scale = math.max(0.8, (ns.db.ui.scale or 1.0) - 0.05); ns:RefreshControllerUI(); ns:RefreshTargetHUD() end)
    p7.scaleLabel = p7:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p7.scaleLabel:SetJustifyH("CENTER")
    p7.scalePlusBtn = ns:CreateMaterialButton(p7, "Scale +", 68, 28, 268, -14, nil, function() ns.db.ui.scale = math.min(1.3, (ns.db.ui.scale or 1.0) + 0.05); ns:RefreshControllerUI(); ns:RefreshTargetHUD() end)
    p7.stdSizeBtn = ns:CreateMaterialButton(p7, "Standard", 88, 28, 356, -14, nil, function() ns:SetWindowDimensions(680, 560) end)
    p7.wideSizeBtn = ns:CreateMaterialButton(p7, "Wide", 80, 28, 454, -14, "PRIMARY", function() ns:SetWindowDimensions(820, 620) end)
    p7.largeSizeBtn = ns:CreateMaterialButton(p7, "Large", 80, 28, 552, -14, "AMBER", function() ns:SetWindowDimensions(940, 700) end)

    p7.minimapBtn   = ns:CreateMaterialButton(p7, "", 304, 28, 16, -50, nil, function() ns.db.ui.showMinimap = not ns.db.ui.showMinimap; ns:RefreshMinimapButton(); ns:RefreshControllerUI() end)
    p7.hudBtn       = ns:CreateMaterialButton(p7, "", 304, 28, 336, -50, nil, function() ns.db.ui.showTargetHUD = not (ns.db.ui.showTargetHUD ~= false); ns:RefreshControllerUI(); ns:RefreshTargetHUD() end)

    p7.hudRPBtn     = ns:CreateMaterialButton(p7, "", 304, 28, 16, -84, nil, function() ns.db.ui.rpTooltip = not ns.db.ui.rpTooltip; ns:RefreshControllerUI() end)
    p7.npClassBtn   = ns:CreateMaterialButton(p7, "", 304, 28, 336, -84, nil, function() ns.db.ui.nameplateClassColors = not ns.db.ui.nameplateClassColors; if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)

    p7.npTagBtn     = ns:CreateMaterialButton(p7, "", 304, 28, 16, -118, nil, function() ns.db.ui.nameplateStatusTags = not (ns.db.ui.nameplateStatusTags ~= false); if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)
    p7.npRPNameBtn  = ns:CreateMaterialButton(p7, "", 304, 28, 336, -118, nil, function() ns.db.ui.nameplateRPNames = not ns.db.ui.nameplateRPNames; if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)

    p7.npCircleBtn  = ns:CreateMaterialButton(p7, "", 304, 28, 16, -152, nil, function() ns.db.ui.nameplateStandingCircle = not (ns.db.ui.nameplateStandingCircle ~= false); if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)
    p7.combatBtn    = ns:CreateMaterialButton(p7, "", 304, 28, 336, -152, nil, function() ns.db.ui.hideInCombat = not ns.db.ui.hideInCombat; ns:RefreshControllerUI() end)

    p7.soundBtn     = ns:CreateMaterialButton(p7, "", 304, 28, 16, -186, nil, function() ns.db.ui.soundEffects = not ns.db.ui.soundEffects; ns:RefreshControllerUI() end)
    p7.partyBtn     = ns:CreateMaterialButton(p7, "", 304, 28, 336, -186, nil, function() ns.db.gratitude.ignoreParty = not ns.db.gratitude.ignoreParty; ns:RefreshControllerUI() end)

    p7.rpNameBtn    = ns:CreateMaterialButton(p7, "", 304, 28, 16, -220, nil, function() ns.db.gratitude.useRPNames = not ns.db.gratitude.useRPNames; ns:RefreshControllerUI() end)
    p7.chatRPBtn    = ns:CreateMaterialButton(p7, "", 304, 28, 336, -220, nil, function() ns.db.ui.chatRPNames = not ns.db.ui.chatRPNames; ns:RefreshControllerUI() end)

    p7.afkOOCBtn    = ns:CreateMaterialButton(p7, "", 304, 28, 16, -254, nil, function() ns.db.ui.autoAFKOOC = not ns.db.ui.autoAFKOOC; ns:RefreshControllerUI() end)

    p7.openExpBtn = ns:CreateMaterialButton(p7, "Export / Import Profile String", 304, 30, 16, -294, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        mainFrame.exportModal.box:SetCleanText(ns:ExportCurrentProfileString())
        mainFrame.exportModal:Show()
        ns:FocusFirstInScope()
    end)

    p7.devModeBtn = ns:CreateMaterialButton(p7, "", 304, 30, 336, -294, nil, function()
        ns.db.ui.devMode = not ns.db.ui.devMode
        ns:RefreshControllerUI()
        ns:ShowStatusToast(ns.db.ui.devMode and "Developer Mode enabled (Dev tab unlocked)" or "Developer Mode hidden")
    end)

    local expModal = CreateFrame("Frame", nil, p7, "BackdropTemplate")
    expModal:SetSize(560, 260)
    expModal:SetPoint("CENTER", p7, "CENTER", 0, 0)
    expModal:SetFrameLevel(p7:GetFrameLevel() + 30)
    ns:ApplySurface(expModal, M3.surfaceDim, M3.primary)
    ns:EnableClipping(expModal)
    expModal:EnableMouse(true)
    expModal:Hide()
    ns:CreateMaterialButton(expModal, "X", 28, 24, 520, -8, "CORAL", function() expModal:Hide(); ns:SetControllerFocus(p7.openExpBtn) end)
    expModal.box = ns:CreateScrollableTextEditor(expModal, "Paste a PADRP5~ or PADRP4~ profile string here...", 16, -40, 528, 165)
    ns:CreateMaterialButton(expModal, "Highlight String for Copy", 258, 30, 16, -216, "AMBER", function()
        expModal.box:SetCleanText(ns:ExportCurrentProfileString())
        expModal.box.editBox:HighlightText()
        expModal.box.editBox:SetFocus()
    end)
    ns:CreateMaterialButton(expModal, "Import String as New Profile", 258, 30, 286, -216, "MINT", function()
        local ok, msg = ns:ImportProfileString(strtrim(expModal.box:GetText() or ""))
        if ok then expModal:Hide(); ns:SetControllerFocus(p7.openExpBtn); ns:ShowStatusToast("Imported: " .. msg)
        else ns:ShowStatusToast(msg or "Import failed") end
    end)
    mainFrame.exportModal = expModal

    local p8 = tabPanels[8]
    p8.diagText = p8:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p8.diagText:SetPoint("TOPLEFT", 16, -12)
    p8.diagText:SetPoint("TOPRIGHT", -16, -12)
    p8.diagText:SetJustifyH("LEFT")

    p8.chkDebug = ns:CreateMaterialButton(p8, "", 198, 26, 16, -34, nil, function()
        ns.mspDebug = not ns.mspDebug
        ns:RefreshControllerUI()
    end)
    p8.chkSniff = ns:CreateMaterialButton(p8, "", 198, 26, 222, -34, nil, function()
        ns.mspSniff = not ns.mspSniff
        if ns.mspSniff then ns.mspDebug = true end
        ns:RefreshControllerUI()
    end)
    p8.chkEcho = ns:CreateMaterialButton(p8, "", 212, 26, 428, -34, nil, function()
        ns.mspEchoChat = not ns.mspEchoChat
        ns:RefreshControllerUI()
    end)

    p8.popOutBtn = ns:CreateMaterialButton(p8, "Pop-Out Inspector", 148, 28, 16, -68, "PRIMARY", function()
        ns.mspDebug = true
        ns:ToggleNetInspector(true)
        ns:RefreshControllerUI()
    end)
    p8.selfTestBtn = ns:CreateMaterialButton(p8, "Run Self-Test", 148, 28, 172, -68, "AMBER", function()
        ns:RunMSPSelfTest()
    end)

    p8.clearCacheBtn = ns:CreateMaterialButton(p8, "Clear Profile Cache", 156, 28, 328, -68, "CORAL", function(self)
        local now = GetTime()
        if now < confirmClearCacheUntil then
            confirmClearCacheUntil = 0
            self:SetText("Clear Profile Cache")
            local removed = ns:ClearMSPCache()
            ns:LogNet("CACHE", "fff28b82", string.format("Cleared %d cached profile(s). Ready to test live pulls!", removed))
            ns:ShowStatusToast(string.format("Cleared %d cached profiles", removed))
        else
            confirmClearCacheUntil = now + 4
            self:SetText("|cfff28b82Confirm Wipe?|r")
            if C_Timer and C_Timer.After then
                C_Timer.After(4.1, function()
                    if p8.clearCacheBtn then p8.clearCacheBtn:SetText("Clear Profile Cache") end
                end)
            end
        end
    end)

    p8.logEditor = ns:CreateScrollableTextEditor(p8, "Network & wire logs appear here when Debug Events or Wire Sniffer are checked...", 16, -104, 624, 240)
    p8.logEditor:SetPoint("BOTTOMRIGHT", p8, "BOTTOMRIGHT", -16, 14)

    local footer = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    footer:SetHeight(26)
    footer:SetPoint("BOTTOMLEFT", 12, 10)
    footer:SetPoint("BOTTOMRIGHT", -34, 10)
    ns:ApplySurface(footer, M3.surfaceLow, M3.outline)
    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerText:SetPoint("LEFT", 14, 0)
    footerText:SetText("|cff8ab4f8[LB]/[RB]|r Tabs   |cff8ab4f8[D-Pad]|r Move Focus   |cff8ab4f8[A]|r Edit/Confirm   |cff8ab4f8[B]|r Back/Close")
    mainFrame.statusToast = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.statusToast:SetPoint("RIGHT", -14, 0)
    mainFrame.statusToast:SetText("|cff9aa0a6Saved in PadRPDB|r")

    local resizeGrip = CreateFrame("Button", "PadRP_ResizeGrip", mainFrame, "BackdropTemplate")
    resizeGrip:SetSize(20, 26)
    resizeGrip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
    ns:ApplySurface(resizeGrip, M3.surfaceHigh, M3.outline)
    local gripLabel = resizeGrip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gripLabel:SetPoint("CENTER", 0, 0)
    gripLabel:SetText("//")
    resizeGrip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then mainFrame:StartSizing("BOTTOMRIGHT") end end)
    resizeGrip:SetScript("OnMouseUp", function() mainFrame:StopMovingOrSizing(); ns:RefreshControllerUI() end)

    ns:LoadProfileIntoUI()
    ns:SelectTab(1)

    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        ConsolePort:AddInterfaceCursorFrame("PadRP_MainFrame")
    end
end