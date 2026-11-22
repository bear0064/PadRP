local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[9] = mod

local EMOTE_ROWS = 7

function mod.Build(p, picker)
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
        if (UI.activeTab or 1) ~= 9 or not p:IsShown() then return false end
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

    -- Left column: view switch + search/filter + rows
    p.viewCustomBtn = ns:CreateMaterialButton(p, "Custom /e", 142, 26, 16, -12, "PRIMARY", function()
        CommitEditor(); DisarmAll()
        view, selIdx, page = "custom", 1, 1
        ApplyView()
    end)
    p.viewBaseBtn = ns:CreateMaterialButton(p, "Base Emotes", 142, 26, 164, -12, nil, function()
        CommitEditor(); DisarmAll()
        view, selIdx, page = "base", 1, 1
        ApplyView()
    end)
    p.countFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.countFS:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -18)
    p.countFS:SetJustifyH("RIGHT")

    p.searchBox = ns:CreateMaterialEditBox(p, nil, "Search label or /token...", 16, -42, 160, 24, function(txt)
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

    p.wheelFilterBtn = ns:CreateMaterialButton(p, "Show All", 86, 24, 180, -42, "PRIMARY", function()
        wheelOnly = not wheelOnly
        page = 1
        selIdx = 0
        UpdateFilterButton()
        RefreshList(); LoadEditor()
    end)

    p.clearSearchBtn = ns:CreateMaterialButton(p, "Clr", 42, 24, 270, -42, nil, function()
        searchQuery = ""
        p.searchBox:SetCleanText("")
        page = 1
        selIdx = 0
        RefreshList(); LoadEditor()
    end)

    p.rows = {}
    for i = 1, EMOTE_ROWS do
        local row = ns:CreateMaterialButton(p, "", 290, 28, 16, -70 - (i - 1) * 30, nil, function(self)
            if not self.idx then return end
            CommitEditor(); DisarmAll()
            selIdx = self.idx
            RefreshList(); LoadEditor()
        end)
        row.emoteRowIndex = i
        row.iconTex = row:CreateTexture(nil, "ARTWORK")
        row.iconTex:SetSize(18, 18)
        row.iconTex:SetPoint("LEFT", 8, 0)
        row.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", 32, 0)
        row.label:SetPoint("RIGHT", -8, 0)
        row.label:SetJustifyH("LEFT")
        UI:AttachWheelScroller(row, function(delta) StepPage(delta, nil) end)
        p.rows[i] = row
    end

    p.prevBtn = ns:CreateMaterialButton(p, "< Prev", 76, 26, 16, -284, nil, function() StepPage(-1, nil) end)
    p.pageFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.pageFS:SetPoint("TOPLEFT", 96, -290)
    p.pageFS:SetWidth(124)
    p.pageFS:SetJustifyH("CENTER")
    p.nextBtn = ns:CreateMaterialButton(p, "Next >", 76, 26, 230, -284, nil, function() StepPage(1, nil) end)
    UI:AttachWheelScroller(p.prevBtn, function(delta) StepPage(delta, nil) end)
    UI:AttachWheelScroller(p.nextBtn, function(delta) StepPage(delta, nil) end)
    UI:AttachWheelScroller(p, function(delta) StepPage(delta, nil) end)

    p.addBoxCustom = ns:CreateMaterialEditBox(p, nil, "New emote name...", 16, -316, 206, 26)
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
    p.addBtn = ns:CreateMaterialButton(p, "+ Add", 78, 26, 228, -316, "MINT", DoAdd)

    UpdateResetButton = function()
        if not p.resetBtn then return end
        p.resetBtn:SetText(resetArmed and "Press again to confirm reset" or "Reset Base Emotes to Default")
        p.resetBtn:SetTone(resetArmed and "CORAL" or nil)
    end
    p.resetBtn = ns:CreateMaterialButton(p, "Reset Base Emotes to Default", 290, 26, 16, -316, nil, function()
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
    p.tipFS:SetPoint("TOPLEFT", 16, -348)
    p.tipFS:SetWidth(290)
    p.tipFS:SetJustifyH("LEFT")
    p.tipFS:SetText("|cff9aa0a6On the wheel: LB/RB to reach Custom and Base pages.|r")

    -- Right column: editor
    p.editorHeader = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.editorHeader:SetPoint("TOPLEFT", 320, -48)
    p.editorHeader:SetWidth(290)
    p.editorHeader:SetJustifyH("LEFT")

    local function Caption(text, y)
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 320, y)
        fs:SetText(text)
        return fs
    end
    local capLabel = Caption("Label (shown on the wheel)", -68)
    p.capLabel = capLabel
    p.labelBox = ns:CreateMaterialEditBox(p, nil, "e.g. Look Around", 320, -82, 290, 26, function() CommitEditor(); RefreshList() end)
    if p.labelBox.SetMaxLetters then p.labelBox:SetMaxLetters(40) end

    local capText = Caption("Emote text (appears after your name)", -114)
    p.capText = capText
    p.textBox = ns:CreateMaterialEditBox(p, nil, "e.g. looks around attentively.", 320, -128, 290, 26, function() CommitEditor(); RefreshList() end)
    if p.textBox.SetMaxLetters then p.textBox:SetMaxLetters(240) end
    p.previewFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.previewFS:SetPoint("TOPLEFT", 320, -160)
    p.previewFS:SetWidth(290)
    p.previewFS:SetJustifyH("LEFT")
    p.previewFS:SetJustifyV("TOP")
    p.previewFS:SetHeight(42)
    p.hintFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.hintFS:SetPoint("TOPLEFT", 320, -326)
    p.hintFS:SetWidth(290)
    p.hintFS:SetJustifyH("LEFT")
    p.hintFS:SetText("|cff9aa0a6%name = your RP name   %target = your target's name|r")
    p.textBox:HookScript("OnTextChanged", function(self)
        if view == "custom" and CurItem() then
            p.previewFS:SetText("|cff9aa0a6Preview:|r " .. ns:PreviewFlyoutEmoteText(self:GetText()))
        end
    end)

    p.tokenFS = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.tokenFS:SetPoint("TOPLEFT", 320, -120)
    p.tokenFS:SetWidth(290)
    p.tokenFS:SetJustifyH("LEFT")
    p.enableBtn = ns:CreateMaterialButton(p, "", 290, 28, 320, -142, nil, function()
        local item = CurItem()
        if not item then return end
        item.enabled = not (item.enabled == true)
        if ns.RefreshFlyoutWheel and ns.flyoutWheelFrame and ns.flyoutWheelFrame:IsShown() then
            ns:RefreshFlyoutWheel()
        end
        RefreshList(); LoadEditor()
    end)

    p.iconFrame = CreateFrame("Frame", nil, p, "BackdropTemplate")
    p.iconFrame:SetSize(36, 36)
    p.iconFrame:SetPoint("TOPLEFT", 320, -206)
    ns:ApplySurface(p.iconFrame, ns.M3.surface, ns.M3.outline)
    p.iconTex = p.iconFrame:CreateTexture(nil, "ARTWORK")
    p.iconTex:SetSize(30, 30)
    p.iconTex:SetPoint("CENTER")
    p.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.iconBtn = ns:CreateMaterialButton(p, "Custom Icon", 140, 28, 362, -210, "PRIMARY", function(self)
        local item = CurItem()
        if not item then return end
        CommitEditor()
        local currentActive = ns:GetFlyoutEmoteDisplayIcon(view, item)
        if picker then
            picker:OpenForCallback("SELECT CUSTOM EMOTE ICON", currentActive, function(iconVal)
                local current = CurItem()
                if current then
                    ns:SetFlyoutEmoteCustomIcon(view, selIdx, iconVal)
                end
                RefreshList(); LoadEditor()
                ns:ShowStatusToast("Custom icon applied")
            end, self)
        end
    end)
    p.defaultIconBtn = ns:CreateMaterialButton(p, "Original Icon", 102, 28, 508, -210, nil, function()
        local item = CurItem()
        if not item then return end
        ns:ClearFlyoutEmoteCustomIcon(view, selIdx)
        RefreshList(); LoadEditor()
        ns:ShowStatusToast("Restored original icon")
    end)

    p.moveUpBtn = ns:CreateMaterialButton(p, "Move Up", 92, 26, 320, -254, nil, function()
        if selIdx < 1 then return end
        CommitEditor()
        GoToIndex(ns:MoveFlyoutEmote(view, selIdx, -1))
        RefreshList(); LoadEditor()
    end)
    p.moveDownBtn = ns:CreateMaterialButton(p, "Move Down", 92, 26, 418, -254, nil, function()
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
    p.removeBtn = ns:CreateMaterialButton(p, "Remove", 94, 26, 516, -254, "CORAL", function()
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
    p.saveBtn = ns:CreateMaterialButton(p, "Save Changes", 290, 28, 320, -290, "PRIMARY", function()
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
                UI:SetIconTextureSafe(row.iconTex, ns:ResolveWheelIconTexture(displayIcon, view, item), UI:GetDefaultIconFallback())
                if view == "base" then
                    local on = item.enabled == true
                    local customMark = (ns:GetFlyoutEmoteCustomIcon(item) ~= nil) and " *" or ""
                    row:SetText((on and "|cff81c995ON |r" or "|cfff28b82OFF|r") .. " " .. UI:TruncText(item.label or item.token, 14)
                        .. customMark .. " |cff9aa0a6/" .. string.lower(tostring(item.token or "")) .. "|r")
                else
                    local customMark = (ns:GetFlyoutEmoteCustomIcon(item) ~= nil) and " *" or ""
                    row:SetText(UI:TruncText((item.label or ("Emote " .. actualIdx)) .. customMark, 16)
                        .. "  |cff9aa0a6" .. UI:TruncText(item.text, 18) .. "|r")
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
        UI:SetIconTextureSafe(p.iconTex, ns:ResolveWheelIconTexture(displayIcon, view, item), UI:GetDefaultIconFallback())
        p.defaultIconBtn:SetText(ns:GetFlyoutEmoteCustomIcon(item) and "Reset Icon" or "Original Icon")

        if view == "custom" then
            p.textBox:SetCleanText(item.text or "")
            p.previewFS:SetText("|cff9aa0a6Preview:|r " .. ns:PreviewFlyoutEmoteText(item.text))
        else
            p.tokenFS:SetText("|cff9aa0a6Command:|r /" .. string.lower(tostring(item.token or "")))
            local on = item.enabled == true
            p.enableBtn:SetText(UI:FormatCheckbox("Show on the wheel", on, "ff81c995"))
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
        mod.Layout(p)
    end

    p:HookScript("OnShow", function()
        if ns.EnsureFlyoutDB then ns:EnsureFlyoutDB() end
        DisarmAll()
        ApplyView()
    end)
end

function mod.Layout(p9)
    if not p9 or not p9.rows then return end
    local w = p9:GetWidth()
    if not w or w < 420 then return end

    local pad = 16
    local gap = 14
    local colW = math.floor((w - (pad * 2) - gap) / 2)
    local leftX = pad
    local rightX = pad + colW + gap

    local subTabW = math.floor((colW - 6) / 2)
    if p9.viewCustomBtn then
        p9.viewCustomBtn:ClearAllPoints()
        p9.viewCustomBtn:SetSize(subTabW, 26)
        p9.viewCustomBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -12)
    end
    if p9.viewBaseBtn then
        p9.viewBaseBtn:ClearAllPoints()
        p9.viewBaseBtn:SetSize(subTabW, 26)
        p9.viewBaseBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX + subTabW + 6, -12)
    end

    if p9.searchBox and p9.wheelFilterBtn and p9.clearSearchBtn then
        local filterW = 86
        local clrW = 42
        local searchW = math.max(90, colW - filterW - clrW - 8)
        p9.searchBox:ClearAllPoints()
        p9.searchBox:SetSize(searchW, 24)
        p9.searchBox:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -42)

        p9.wheelFilterBtn:ClearAllPoints()
        p9.wheelFilterBtn:SetSize(filterW, 24)
        p9.wheelFilterBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX + searchW + 4, -42)

        p9.clearSearchBtn:ClearAllPoints()
        p9.clearSearchBtn:SetSize(clrW, 24)
        p9.clearSearchBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX + searchW + filterW + 8, -42)
    end

    for i = 1, EMOTE_ROWS do
        local row = p9.rows[i]
        if row then
            row:ClearAllPoints()
            row:SetSize(colW, 28)
            row:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -70 - (i - 1) * 30)
        end
    end

    local navBtnW = 76
    if p9.prevBtn then
        p9.prevBtn:ClearAllPoints()
        p9.prevBtn:SetSize(navBtnW, 26)
        p9.prevBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -284)
    end
    if p9.pageFS then
        p9.pageFS:ClearAllPoints()
        p9.pageFS:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX + navBtnW + 4, -290)
        p9.pageFS:SetWidth(math.max(60, colW - (navBtnW * 2) - 8))
    end
    if p9.nextBtn then
        p9.nextBtn:ClearAllPoints()
        p9.nextBtn:SetSize(navBtnW, 26)
        p9.nextBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX + colW - navBtnW, -284)
    end

    if p9.addBoxCustom and p9.addBtn then
        local addBtnW = 78
        p9.addBoxCustom:ClearAllPoints()
        p9.addBoxCustom:SetSize(math.max(100, colW - addBtnW - 6), 26)
        p9.addBoxCustom:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -316)

        p9.addBtn:ClearAllPoints()
        p9.addBtn:SetSize(addBtnW, 26)
        p9.addBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX + colW - addBtnW, -316)
    end
    if p9.resetBtn then
        p9.resetBtn:ClearAllPoints()
        p9.resetBtn:SetSize(colW, 26)
        p9.resetBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -316)
    end
    if p9.tipFS then
        p9.tipFS:ClearAllPoints()
        p9.tipFS:SetPoint("TOPLEFT", p9, "TOPLEFT", leftX, -348)
        p9.tipFS:SetWidth(colW)
    end

    if p9.editorHeader then
        p9.editorHeader:ClearAllPoints()
        p9.editorHeader:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -48)
        p9.editorHeader:SetWidth(colW)
    end
    if p9.capLabel then
        p9.capLabel:ClearAllPoints()
        p9.capLabel:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -68)
    end
    if p9.labelBox then
        p9.labelBox:ClearAllPoints()
        p9.labelBox:SetSize(colW, 26)
        p9.labelBox:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -82)
    end
    if p9.capText then
        p9.capText:ClearAllPoints()
        p9.capText:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -114)
    end
    if p9.textBox then
        p9.textBox:ClearAllPoints()
        p9.textBox:SetSize(colW, 26)
        p9.textBox:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -128)
    end
    if p9.previewFS then
        p9.previewFS:ClearAllPoints()
        p9.previewFS:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -160)
        p9.previewFS:SetWidth(colW)
    end
    if p9.tokenFS then
        p9.tokenFS:ClearAllPoints()
        p9.tokenFS:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -120)
        p9.tokenFS:SetWidth(colW)
    end
    if p9.enableBtn then
        p9.enableBtn:ClearAllPoints()
        p9.enableBtn:SetSize(colW, 28)
        p9.enableBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -142)
    end
    if p9.iconFrame and p9.iconBtn and p9.defaultIconBtn then
        local resetW = 102
        local pickW = math.max(96, colW - 42 - resetW - 10)
        p9.iconFrame:ClearAllPoints()
        p9.iconFrame:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -206)

        p9.iconBtn:ClearAllPoints()
        p9.iconBtn:SetSize(pickW, 28)
        p9.iconBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX + 42, -210)

        p9.defaultIconBtn:ClearAllPoints()
        p9.defaultIconBtn:SetSize(resetW, 28)
        p9.defaultIconBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX + colW - resetW, -210)
    end
    if p9.moveUpBtn and p9.moveDownBtn and p9.removeBtn then
        local thirdW = math.floor((colW - 12) / 3)
        p9.moveUpBtn:ClearAllPoints()
        p9.moveUpBtn:SetSize(thirdW, 26)
        p9.moveUpBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -254)

        p9.moveDownBtn:ClearAllPoints()
        p9.moveDownBtn:SetSize(thirdW, 26)
        p9.moveDownBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX + thirdW + 6, -254)

        p9.removeBtn:ClearAllPoints()
        p9.removeBtn:SetSize(colW - (thirdW * 2) - 12, 26)
        p9.removeBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX + (thirdW * 2) + 12, -254)
    end
    if p9.saveBtn then
        p9.saveBtn:ClearAllPoints()
        p9.saveBtn:SetSize(colW, 28)
        p9.saveBtn:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -290)
    end
    if p9.hintFS then
        p9.hintFS:ClearAllPoints()
        p9.hintFS:SetPoint("TOPLEFT", p9, "TOPLEFT", rightX, -326)
        p9.hintFS:SetWidth(colW)
    end
end

function mod.Refresh(p9)
    if p9 and p9:IsShown() and ns.GetFlyoutEmoteList then
        mod.Layout(p9)
    end
end