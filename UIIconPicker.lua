local _, ns = ...

local UI = ns.UI
local inspectorFrame

local function PersistColorSelection(mode, hex6, returnWidget)
    if not ns.profile or not hex6 then return end
    local now = (GetTime and GetTime()) or 0
    if (now - (UI.lastPickerApplyTime or 0)) < 0.25 then return end
    UI.lastPickerApplyTime = now
    UI.pickerReopenGuardUntil = now + 0.45

    if mode == "EYE" then
        ns.profile.eyeColorHex = hex6
        UI:RefreshEyeSwatchBox()
    else
        ns.profile.classColorHex = hex6
        ns.profile.nameColorHex = hex6
        UI:RefreshClassSwatchBox()
        if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
        if ns.RefreshTargetCard then ns:RefreshTargetCard() end
    end
    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
    if ns.SyncMSP then ns:SyncMSP() end
    UI:SyncSelfProfileToLocalCache()
    local label = (mode == "EYE") and "Eye color" or "Class & Name color"
    ns:ShowStatusToast(label .. " set to #" .. string.upper(hex6))
    if returnWidget and returnWidget:IsVisible() then
        ns:SetControllerFocus(returnWidget)
    end
end

local function OpenNativeColorPicker(mode, returnWidget)
    if not ColorPickerFrame or not ns.profile then return end
    local now = (GetTime and GetTime()) or 0
    if now < (UI.pickerReopenGuardUntil or 0) or (ColorPickerFrame.IsShown and ColorPickerFrame:IsShown()) then
        return
    end
    UI.pickerReopenGuardUntil = now + 0.25

    local prevHex
    if mode == "EYE" then
        prevHex = UI:NormalizeHex6(ns.profile.eyeColorHex or ns.profile.eyeColor)
    else
        prevHex = UI:NormalizeHex6(ns.profile.classColorHex or ns.profile.nameColorHex)
    end
    local startHex = prevHex or UI:GetWoWClassHex6()
    local r, g, b = UI:HexToRGB(startHex)
    local liveHex6 = startHex
    local openedAt = now
    local userMovedColor = false
    local wasCancelled = false

    local function ApplyLiveRGB(nr, ng, nb, fromUser)
        if fromUser then
            userMovedColor = true
        end
        liveHex6 = UI:RGBToHex6(nr, ng, nb)
        if mode == "EYE" then
            ns.profile.eyeColorHex = liveHex6
            UI:RefreshEyeSwatchBox()
        else
            ns.profile.classColorHex = liveHex6
            ns.profile.nameColorHex = liveHex6
            UI:RefreshClassSwatchBox()
            if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
            if ns.RefreshTargetCard then ns:RefreshTargetCard() end
        end
        UI:SyncSelfProfileToLocalCache()
    end

    local function CancelRGB()
        wasCancelled = true
        UI.pickerReopenGuardUntil = ((GetTime and GetTime()) or 0) + 0.45
        ColorPickerFrame._padRPFinalize = nil
        if mode == "EYE" then
            ns.profile.eyeColorHex = prevHex
            UI:RefreshEyeSwatchBox()
        else
            ns.profile.classColorHex = prevHex
            ns.profile.nameColorHex = prevHex
            UI:RefreshClassSwatchBox()
            if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
            if ns.RefreshTargetCard then ns:RefreshTargetCard() end
        end
        if prevHex and ColorPickerFrame.SetColorRGB then
            local pr, pg, pb = UI:HexToRGB(prevHex)
            ColorPickerFrame:SetColorRGB(pr, pg, pb)
        end
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        UI:SyncSelfProfileToLocalCache()
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
                local picked = UI:RGBToHex6(nr, ng, nb)
                if picked and picked ~= "000000" then
                    liveHex6 = picked
                end
            end
            PersistColorSelection(mode, liveHex6, returnWidget)
        end
        if not ColorPickerFrame._padRPOnHideHooked and ColorPickerFrame.HookScript then
            ColorPickerFrame._padRPOnHideHooked = true
            ColorPickerFrame:HookScript("OnHide", function(self)
                UI.pickerReopenGuardUntil = ((GetTime and GetTime()) or 0) + 0.45
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

function UI:CreateColorSwatchButton(parent, x, y, mode, onReset)
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
        UI:ApplySwatchVisual(self, self.activeHex6, isFocused)
    end)
    return btn
end

function UI:CreateIconPicker(parentFrame)
    local M3 = ns.M3
    local picker = CreateFrame("Frame", "PadRP_IconPicker", parentFrame, "BackdropTemplate")
    picker:SetSize(512, 412)
    picker:SetPoint("CENTER", parentFrame, "CENTER", 0, -4)
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(parentFrame:GetFrameLevel() + 45)
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

    picker.searchBox = ns:CreateMaterialEditBox(picker, nil, "Search keyword (owl, vial, cloak) or ID...", 150, -34, 300, 24, function(txt)
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
            if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
            ns:RefreshControllerUI()
            ns:ShowStatusToast("Portrait icon updated!")
        else
            local slot = picker.targetSlot or 1
            if ns.profile.glances[slot] then
                ns.profile.glances[slot].icon = clean
            end
            if UI.LoadAllGlancesIntoUI then UI:LoadAllGlancesIntoUI() end
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
                local readout = (ns.IconPool and ns.IconPool.GetDisplayLabel and ns.IconPool:GetDisplayLabel(self.iconID or self.iconName)) or self.iconName
                picker.hoverLabel:SetText(UI:FormatPickerIconReadout("Selected:", readout, self.iconID, self.tex))
            end
        end)
        cell:SetScript("OnClick", function(self)
            local saveVal = (self.iconID and tostring(self.iconID)) or self.iconName
            if not saveVal or saveVal == "" then return end
            ns:PlayUISound()
            ApplyPickedIcon(saveVal)
        end)
        ns:RegisterFocusable(cell, function() cell:Click("LeftButton") end, function(self, isFocused)
            if isFocused then
                self:SetBackdropColor(unpack(M3.surfaceBright))
                self:SetBackdropBorderColor(unpack(M3.primary))
                if self.iconName then
                    local readout = (ns.IconPool and ns.IconPool.GetDisplayLabel and ns.IconPool:GetDisplayLabel(self.iconID or self.iconName)) or self.iconName
                    picker.hoverLabel:SetText(UI:FormatPickerIconReadout("Selected:", readout, self.iconID, self.tex))
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
    UI:AttachWheelScroller(picker, function(step) picker:StepPage(step) end)

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
        local fallbackIcon = UI:GetDefaultIconFallback()
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
        local currentReadout = (ns.IconPool and ns.IconPool.GetDisplayLabel and ns.IconPool:GetDisplayLabel(currentIcon)) or currentIcon
        self.hoverLabel:SetText(UI:FormatPickerIconReadout("Current:", currentReadout, nil, nil))

        for i = 1, ICONS_PER_PAGE do
            local cell = self.cells[i]
            local rawItem = pageItems[i]
            if rawItem then
                local id, _, displayVal = UI:UnpackIconEntry(rawItem)
                cell.iconName = displayVal
                cell.iconID = id
                UI:SetIconTextureSafe(cell.tex, id or displayVal, fallbackIcon)
                cell:Show()
            else
                cell.iconName = nil
                cell.iconID = nil
                cell:Hide()
            end
        end
    end

    picker.OpenForSlot = function(self, slotIndex, returnWidget)
        if ns.IconPool and ns.IconPool.EnsureLiveNames then ns.IconPool:EnsureLiveNames() end
        self.mode, self.targetSlot, self.page, self.returnFocusWidget = "GLANCE", slotIndex, 1, returnWidget
        self.searchQuery = ""
        self.searchBox:SetCleanText("")
        self:RebuildFilter()
        self:Show()
        ns:SetControllerFocus(self.cells[1]:IsShown() and self.cells[1] or self.searchBox)
    end

    picker.OpenForPortrait = function(self, returnWidget)
        if ns.IconPool and ns.IconPool.EnsureLiveNames then ns.IconPool:EnsureLiveNames() end
        self.mode, self.page, self.returnFocusWidget = "PORTRAIT", 1, returnWidget
        self.searchQuery = ""
        self.searchBox:SetCleanText("")
        self:RebuildFilter()
        self:Show()
        ns:SetControllerFocus(self.cells[1]:IsShown() and self.cells[1] or self.searchBox)
    end

    picker.OpenForCallback = function(self, title, currentIcon, onPick, returnWidget)
        if ns.IconPool and ns.IconPool.EnsureLiveNames then ns.IconPool:EnsureLiveNames() end
        self.mode, self.page, self.returnFocusWidget = "CALLBACK", 1, returnWidget
        self.callbackTitle, self.callbackIcon, self.pickCallback = title, currentIcon, onPick
        self.searchQuery = ""
        self.searchBox:SetCleanText("")
        self:RebuildFilter()
        self:Show()
        ns:SetControllerFocus(self.cells[1]:IsShown() and self.cells[1] or self.searchBox)
    end

    return picker
end

function ns:RefreshNetInspector(newLine)
    if not inspectorFrame then return end

    local knownCount = 0
    if UI.GetKnownDirectoryCount then
        knownCount = UI:GetKnownDirectoryCount()
    end

    local engineLabel = (type(_G.msp) == "table") and "|cff81c995LibMSP|r" or "|cfff28b82Missing LibMSP|r"
    inspectorFrame.statusBar:SetText(string.format(
        "Engine: %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
        engineLabel,
        (ns.mspStats and ns.mspStats.sent) or 0,
        (ns.mspStats and ns.mspStats.liveReplies) or 0,
        knownCount,
        (ns.mspStats and ns.mspStats.lastReplyFrom) or "None"
    ))

    inspectorFrame.chkDebug:SetText(UI:FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
    inspectorFrame.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)

    inspectorFrame.chkSniff:SetText(UI:FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
    inspectorFrame.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)

    inspectorFrame.chkEcho:SetText(UI:FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
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