local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[4] = mod

local function BuildDirectoryRows()
    local seen, entries = {}, {}
    local q = strtrim(string.lower(UI.knownSearchFilter or ""))
    local buckets = UI:GetStandingBuckets()
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

        if UI.knownNotableOnly and not isNotable then return end

        local hay = string.lower(table.concat({
            tostring(k or ""),
            UI:StripColorCodes(v.NA or ""),
            UI:StripColorCodes(v.NT or ""),
            UI:StripColorCodes(v.NH or ""),
            UI:StripColorCodes(v.CU or ""),
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

    for k in pairs((ns.db and ns.db.notes) or {}) do
        AddCandidate(k, { NA = strsplit("-", k) }, 0)
    end

    table.sort(entries, function(a, b)
        if (UI.knownSortMode or "RECENT") == "RECENT" then
            if a.lastSeen ~= b.lastSeen then
                return a.lastSeen > b.lastSeen
            end
        end
        return string.lower(UI:StripColorCodes(a.data.NA or a.key)) < string.lower(UI:StripColorCodes(b.data.NA or b.key))
    end)

    if not UI.knownNotableOnly then
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
            local isCollapsed = UI.collapsedBuckets[bInfo.key] and true or false
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

function UI:GetKnownDirectoryCount()
    local _, total = BuildDirectoryRows()
    return total
end

local function FormatDirectoryEntryText(k, d, item)
    local parts = {}
    local sep = " |cff5f6368•|r "

    if item.hasNote then
        table.insert(parts, "|TInterface\\Icons\\INV_Misc_Note_01:13:13:0:0:64:64:4:60:4:60|t")
    end
    if not item.indented and item.standing and item.standing ~= "None" then
        local bInfo
        for _, sb in ipairs(UI:GetStandingBuckets()) do
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
    if UI:IsPlayerSelfKey(k) then
        activeHex = UI:GetPlayerActiveClassColorHex()
    elseif type(rawName) == "string" then
        local embeddedHex = string.match(rawName, "^|c(%x%x%x%x%x%x%x%x)")
        if embeddedHex then
            activeHex = embeddedHex
        end
    end

    local cleanName = UI:StripColorCodes(rawName)
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

    local titleClean = d.NT and strtrim(UI:StripColorCodes(d.NT)) or ""
    local guildClean = d.NH and strtrim(UI:StripColorCodes(d.NH)) or ""
    local curClean = d.CU and strtrim(UI:StripColorCodes(d.CU)) or ""

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
    local p4 = UI.tabPanels[4]
    if not UI.mainFrame or not p4 then return end

    local rows, totalEntries = BuildDirectoryRows()
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#rows / perPage))
    UI.knownListPage = math.max(1, math.min(totalPages, UI.knownListPage or 1))

    local bucketLabel = UI.knownNotableOnly and "NOTABLE ACCORDION" or "RP DIRECTORY"
    p4.countLabel:SetText(string.format("|cff8ab4f8%s (%d)|r  -  Select any player to open Dossier & Notes", bucketLabel, totalEntries))
    p4.pageLabel:SetText(string.format("Page %d / %d", UI.knownListPage, totalPages))

    p4.notableOnlyBtn:SetText(UI:FormatCheckbox("Notable", UI.knownNotableOnly, "fffdd663"))
    p4.notableOnlyBtn:SetTone(UI.knownNotableOnly and "AMBER" or nil)
    p4.sortBtn:SetText((UI.knownSortMode or "RECENT") == "RECENT" and "Sort: Recent" or "Sort: A-Z")
    p4.sortBtn:SetTone((UI.knownSortMode or "RECENT") == "RECENT" and "PRIMARY" or nil)

    local startIdx = (UI.knownListPage - 1) * perPage
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
    if (UI.activeTab or 1) ~= 4 then return false end
    local p4 = UI.tabPanels[4]
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

    if dir == "DOWN" and rowIndex >= lastShownIdx and (UI.knownListPage or 1) < totalPages then
        UI.knownListPage = (UI.knownListPage or 1) + 1
        ns:RefreshTargetCard()
        ns:PlayUISound()
        if p4.knownRows[1] and p4.knownRows[1]:IsShown() then
            ns:SetControllerFocus(p4.knownRows[1])
        end
        return true
    elseif dir == "UP" and rowIndex <= 1 and (UI.knownListPage or 1) > 1 then
        UI.knownListPage = (UI.knownListPage or 1) - 1
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

function mod.Build(p4)
    p4.countLabel = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p4.countLabel:SetPoint("TOPLEFT", 16, -12)

    local openLiveBtn = ns:CreateMaterialButton(p4, "Open Target Dossier", 142, 24, 0, 0, "PRIMARY", function()
        if ns.OpenTargetDossier then ns:OpenTargetDossier() end
    end)
    openLiveBtn:ClearAllPoints()
    openLiveBtn:SetPoint("TOPRIGHT", p4, "TOPRIGHT", -16, -8)

    p4.searchBox = ns:CreateMaterialEditBox(p4, nil, "Search by Name, Title, House, or Note...", 16, -38, 190, 26, function(txt)
        UI.knownSearchFilter = txt or ""
        UI.knownListPage = 1
        ns:RefreshTargetCard()
    end)
    p4.searchBox:SetScript("OnTextChanged", function(self)
        UI.knownSearchFilter = self:GetText() or ""
        UI.knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.notableOnlyBtn = ns:CreateMaterialButton(p4, "[ ] Notable", 92, 26, 212, -38, nil, function()
        UI.knownNotableOnly = not UI.knownNotableOnly
        UI.knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.sortBtn = ns:CreateMaterialButton(p4, "Sort: Recent", 88, 26, 310, -38, "PRIMARY", function()
        UI.knownSortMode = ((UI.knownSortMode or "RECENT") == "RECENT") and "NAME" or "RECENT"
        UI.knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.prevPageBtn = ns:CreateMaterialButton(p4, "< Prev", 52, 26, 404, -38, nil, function()
        UI.knownListPage = math.max(1, (UI.knownListPage or 1) - 1)
        ns:RefreshTargetCard()
    end)

    p4.pageLabel = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p4.pageLabel:SetJustifyH("CENTER")

    p4.nextPageBtn = ns:CreateMaterialButton(p4, "Next >", 52, 26, 536, -38, nil, function()
        UI.knownListPage = (UI.knownListPage or 1) + 1
        ns:RefreshTargetCard()
    end)

    UI:AttachWheelScroller(p4, function(step)
        UI.knownListPage = (UI.knownListPage or 1) + step
        ns:RefreshTargetCard()
    end)

    p4.knownRows = {}
    for i = 1, 8 do
        local rowY = -72 - (i - 1) * 35
        local rowBtn = ns:CreateMaterialButton(p4, "", 572, 32, 16, rowY, nil, function(self)
            if self.bucketKey then
                UI.collapsedBuckets[self.bucketKey] = not UI.collapsedBuckets[self.bucketKey]
                UI.knownListPage = 1
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

        UI:AttachWheelScroller(rowBtn, function(step)
            UI.knownListPage = (UI.knownListPage or 1) + step
            ns:RefreshTargetCard()
        end)

        p4.knownRows[i] = rowBtn
    end
end

function mod.Layout(p4)
    if not p4 or not p4.searchBox then return end
    UI:LayoutRow(p4, -38, {
        { w = p4.searchBox,     weight = 1 },
        { w = p4.notableOnlyBtn, fixed = 92 },
        { w = p4.sortBtn,        fixed = 88 },
        { w = p4.prevPageBtn,    fixed = 52 },
        { w = p4.pageLabel,      fixed = 70, yOffset = -6 },
        { w = p4.nextPageBtn,    fixed = 52 },
    }, 16, 16, 6)
end

function mod.Refresh()
    ns:RefreshTargetCard()
end