local _, ns = ...

ns.focusables = {}
ns.currentFocus = nil
ns.activeEditBox = nil
local lastPadInputTime = 0
local focusRing = nil
local bindingOwner = nil
local pendingBindingSync = false

ns.M3 = {
    surfaceDim     = { 0.05, 0.06, 0.08, 0.98 },
    surfaceLow     = { 0.08, 0.10, 0.13, 1.00 },
    surface        = { 0.11, 0.13, 0.18, 1.00 },
    surfaceHigh    = { 0.15, 0.18, 0.24, 1.00 },
    surfaceBright  = { 0.19, 0.23, 0.31, 1.00 },
    outline        = { 0.22, 0.26, 0.34, 0.65 },
    outlineFocus   = { 0.54, 0.71, 0.97, 0.85 },
    primary        = { 0.54, 0.71, 0.97, 1.00 },
    primaryTonal   = { 0.11, 0.22, 0.36, 1.00 },
    amber          = { 0.99, 0.84, 0.39, 1.00 },
    amberTonal     = { 0.25, 0.20, 0.09, 1.00 },
    mint           = { 0.51, 0.79, 0.58, 1.00 },
    mintTonal      = { 0.08, 0.23, 0.15, 1.00 },
    coral          = { 0.95, 0.55, 0.51, 1.00 },
    coralTonal     = { 0.28, 0.11, 0.11, 1.00 },
}

local SOLID_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function ScrollFrameByDelta(scrollFrame, deltaPixels)
    if not scrollFrame or not scrollFrame.GetVerticalScroll or not scrollFrame.SetVerticalScroll then return false end
    local cur = scrollFrame:GetVerticalScroll() or 0
    local maxS = (scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange()) or 0
    if maxS <= 2 then return false end
    local nextVal = math.max(0, math.min(maxS, cur + deltaPixels))
    if math.abs(nextVal - cur) < 0.5 then return false end
    scrollFrame:SetVerticalScroll(nextVal)
    return true
end

function ns:ApplySurface(frame, bgColor, borderColor)
    frame:SetBackdrop(SOLID_BACKDROP)
    frame:SetBackdropColor(unpack(bgColor or ns.M3.surface))
    frame:SetBackdropBorderColor(unpack(borderColor or ns.M3.outline))
end

function ns:EnableClipping(frame)
    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
end

function ns:CanProcessPadAction()
    local now = GetTime()
    if (now - lastPadInputTime) < 0.18 then return false end
    lastPadInputTime = now
    return true
end

function ns:RegisterFocusable(widget, activateFn, onFocusChange)
    widget.ActivateFromPad = activateFn
    widget.OnFocusHighlight = onFocusChange
    table.insert(ns.focusables, widget)
end

local function IsFrameDescendantOf(frame, ancestor)
    local p = frame
    while p do
        if p == ancestor then return true end
        p = p:GetParent()
    end
    return false
end

local function GetOrCreateFocusRing()
    if focusRing then return focusRing end
    focusRing = CreateFrame("Frame", "PadRP_FocusRing", UIParent, "BackdropTemplate")
    focusRing:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    focusRing:SetBackdropColor(0.54, 0.71, 0.97, 0.05)
    focusRing:SetBackdropBorderColor(0.54, 0.71, 0.97, 0.90)
    focusRing:EnableMouse(false)
    focusRing:SetScript("OnUpdate", function()
        if not ns.currentFocus or not ns.currentFocus:IsVisible() then
            ns:SetControllerFocus(nil)
        end
    end)
    focusRing:Hide()
    return focusRing
end

local function EnsureBindingOwner()
    if bindingOwner then return bindingOwner end
    bindingOwner = CreateFrame("Frame", "PadRP_PadBindingOwner", UIParent)
    bindingOwner:RegisterEvent("PLAYER_REGEN_DISABLED")
    bindingOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
    bindingOwner:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            ClearOverrideBindings(bindingOwner)
            pendingBindingSync = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingBindingSync then
                pendingBindingSync = false
                ns:UpdateControllerBindings()
            end
        end
    end)
    return bindingOwner
end

function ns:UpdateControllerBindings()
    local owner = EnsureBindingOwner()
    local anyOpen = (ns.dossierFrame and ns.dossierFrame:IsShown())
        or (ns.mainFrame and ns.mainFrame:IsShown())

    if not anyOpen then
        ns:SetControllerFocus(nil)
    end

    if InCombatLockdown() then
        pendingBindingSync = true
        return
    end

    if anyOpen then
        SetOverrideBindingClick(owner, true, "PADLSHOULDER", "PadRP_PrevTabBtn")
        SetOverrideBindingClick(owner, true, "PADRSHOULDER", "PadRP_NextTabBtn")
        SetOverrideBindingClick(owner, true, "PADDUP",       "PadRP_PadUpBtn")
        SetOverrideBindingClick(owner, true, "PADDDOWN",     "PadRP_PadDownBtn")
        SetOverrideBindingClick(owner, true, "PADDLEFT",     "PadRP_PadLeftBtn")
        SetOverrideBindingClick(owner, true, "PADDRIGHT",    "PadRP_PadRightBtn")
        SetOverrideBindingClick(owner, true, "PAD1",         "PadRP_PadConfirmBtn")
        SetOverrideBindingClick(owner, true, "PAD2",         "PadRP_PadCancelBtn")
    else
        ClearOverrideBindings(owner)
    end
    pendingBindingSync = false
end

function ns:GetActiveModalScope()
    if ns.dossierFrame and ns.dossierFrame:IsShown() then
        return ns.dossierFrame
    end

    local mf = ns.mainFrame
    if not mf or not mf:IsShown() then return nil end
    if mf.iconPicker and mf.iconPicker:IsShown() then return mf.iconPicker end
    if mf.exportModal and mf.exportModal:IsShown() then return mf.exportModal end
    if mf.presetDropdown and mf.presetDropdown:IsShown() then return mf.presetDropdown end
    if mf.modeDropdown and mf.modeDropdown:IsShown() then return mf.modeDropdown end
    if mf.poolDropdown and mf.poolDropdown:IsShown() then return mf.poolDropdown end
    return mf
end

function ns:SetControllerFocus(widget)
    local ring = GetOrCreateFocusRing()

    if ns.currentFocus and ns.currentFocus ~= widget and ns.currentFocus.OnFocusHighlight then
        ns.currentFocus:OnFocusHighlight(false)
    end

    if not widget or not widget:IsVisible() then
        ns.currentFocus = nil
        ring:Hide()
        return
    end

    ns.currentFocus = widget
    if widget.OnFocusHighlight then widget:OnFocusHighlight(true) end

    local strata = (widget.GetFrameStrata and widget:GetFrameStrata()) or "DIALOG"
    local level = (widget.GetFrameLevel and widget:GetFrameLevel()) or 40
    ring:SetFrameStrata(strata)
    ring:SetFrameLevel(level + 25)
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", widget, "TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", 2, -2)

    if ns.activeEditBox and ns.activeEditBox == widget then
        ring:SetBackdropColor(0.51, 0.79, 0.58, 0.06)
        ring:SetBackdropBorderColor(0.51, 0.79, 0.58, 0.95)
    else
        ring:SetBackdropColor(0.54, 0.71, 0.97, 0.05)
        ring:SetBackdropBorderColor(0.54, 0.71, 0.97, 0.90)
    end
    ring:Show()
end

function ns:FocusFirstInScope()
    local scope = ns:GetActiveModalScope()
    if not scope or not scope:IsShown() then
        ns:SetControllerFocus(nil)
        return
    end

    local preferredContainer = nil
    if scope == ns.mainFrame and ns.mainFrame.tabPanels and ns.mainFrame.activeTab then
        preferredContainer = ns.mainFrame.tabPanels[ns.mainFrame.activeTab]
    end

    local bestWidget, bestScore = nil, 999999

    if preferredContainer and preferredContainer:IsShown() then
        for _, w in ipairs(ns.focusables) do
            if w:IsVisible() and IsFrameDescendantOf(w, preferredContainer) and not w.isTabBarBtn then
                local l, t = w:GetLeft(), w:GetTop()
                if l and t then
                    local score = (-t * 2) + l
                    if score < bestScore then
                        bestScore = score
                        bestWidget = w
                    end
                end
            end
        end
    end

    if not bestWidget then
        for _, w in ipairs(ns.focusables) do
            if w:IsVisible() and IsFrameDescendantOf(w, scope) and not w.isTabBarBtn then
                local l, t = w:GetLeft(), w:GetTop()
                if l and t then
                    local score = (-t * 2) + l
                    if score < bestScore then
                        bestScore = score
                        bestWidget = w
                    end
                end
            end
        end
    end

    ns:SetControllerFocus(bestWidget)
end

function ns:MoveControllerFocus(dir)
    local scope = ns:GetActiveModalScope()
    if not scope or not ns:CanProcessPadAction() then return end

    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        if not ns.activeEditBox:IsMultiLine() and (dir == "UP" or dir == "DOWN") then
            ns.activeEditBox:ClearFocus()
        else
            return
        end
    end

    local cur = ns.currentFocus

    if dir == "UP" or dir == "DOWN" then
        local stepPx = (dir == "DOWN") and 56 or -56
        if cur and cur.scrollFrame then
            if ScrollFrameByDelta(cur.scrollFrame, stepPx) then
                return
            end
        elseif scope == ns.dossierFrame and ns.dossierFrame.scrollFrame and ns.dossierFrame.readerBox and ns.dossierFrame.readerBox:IsShown() then
            if ScrollFrameByDelta(ns.dossierFrame.scrollFrame, stepPx) then
                return
            end
        end
    end

    if cur and cur.directoryRowIndex and (dir == "UP" or dir == "DOWN") and ns.TrySeamlessDirectoryStep then
        if ns:TrySeamlessDirectoryStep(cur.directoryRowIndex, dir) then
            return
        end
    end

    if not cur or not cur:IsVisible() or not IsFrameDescendantOf(cur, scope) then
        ns:FocusFirstInScope()
        return
    end

    local cx, cy = cur:GetCenter()
    local cl, cr, ct, cb = cur:GetLeft(), cur:GetRight(), cur:GetTop(), cur:GetBottom()
    if not cx or not cy or not cl or not cr or not ct or not cb then
        ns:FocusFirstInScope()
        return
    end

    local bestCandidate, bestScore = nil, 999999
    for _, w in ipairs(ns.focusables) do
        if w ~= cur and w:IsVisible() and IsFrameDescendantOf(w, scope) and not w.isTabBarBtn then
            local wx, wy = w:GetCenter()
            local wl, wr, wt, wb = w:GetLeft(), w:GetRight(), w:GetTop(), w:GetBottom()
            if wx and wy and wl and wr and wt and wb then
                local dx, dy = wx - cx, wy - cy
                local valid, score = false, 999999
                local overlapY = math.min(ct, wt) - math.max(cb, wb)
                local overlapX = math.min(cr, wr) - math.max(cl, wl)

                if dir == "RIGHT" and dx > 12 and wl >= cl + 10 then
                    valid = true
                    local edgeGap = math.max(0, wl - cr)
                    score = (overlapY > 2 or math.abs(dy) <= 18) and (edgeGap + dx * 0.2 + math.abs(dy)) or (5000 + math.abs(dy) * 20 + edgeGap)
                elseif dir == "LEFT" and dx < -12 and wr <= cr - 10 then
                    valid = true
                    local edgeGap = math.max(0, cl - wr)
                    score = (overlapY > 2 or math.abs(dy) <= 18) and (edgeGap - dx * 0.2 + math.abs(dy)) or (5000 + math.abs(dy) * 20 + edgeGap)
                elseif dir == "DOWN" and dy < -10 and wt <= ct - 6 then
                    valid = true
                    local vertGap = math.max(0, cb - wt)
                    score = (overlapX > 2) and (vertGap + math.abs(dx) * 0.15) or (2000 + vertGap + math.abs(dx) * 8)
                elseif dir == "UP" and dy > 10 and wb >= cb + 6 then
                    valid = true
                    local vertGap = math.max(0, wb - ct)
                    score = (overlapX > 2) and (vertGap + math.abs(dx) * 0.15) or (2000 + vertGap + math.abs(dx) * 8)
                end

                if valid and score < bestScore then
                    bestScore = score
                    bestCandidate = w
                end
            end
        end
    end

    if bestCandidate then
        ns:PlayUISound()
        ns:SetControllerFocus(bestCandidate)
    end
end

function ns:CreateMaterialEditBox(parent, labelText, placeholderText, x, y, width, height, onCommit)
    local M3 = ns.M3
    local hasLabel = (labelText and labelText ~= "")
    local boxY = hasLabel and (y - 15) or y

    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height or 28)
    box:SetPoint("TOPLEFT", x, boxY)
    box:SetFontObject("ChatFontNormal")
    box:SetTextInsets(10, 10, 5, 6)
    box:SetAutoFocus(false)
    ns:ApplySurface(box, M3.surface, { 0, 0, 0, 0 })
    ns:EnableClipping(box)
    box.isDirty = false

    if hasLabel then
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 3)
        label:SetWidth(width)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText("|cff9aa0a6" .. labelText .. "|r")
        box.fieldLabel = label
    end

    box.bottomBar = box:CreateTexture(nil, "OVERLAY")
    box.bottomBar:SetHeight(2)
    box.bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
    box.bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
    box.bottomBar:SetColorTexture(0.37, 0.40, 0.46, 0.85)

    box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.placeholder:SetPoint("LEFT", 10, 0)
    box.placeholder:SetPoint("RIGHT", -10, 0)
    box.placeholder:SetJustifyH("LEFT")
    box.placeholder:SetWordWrap(false)
    box.placeholder:SetText(placeholderText or "")

    local padBtn = CreateFrame("Button", nil, box)
    padBtn:SetAllPoints(box)
    padBtn:SetFrameLevel(box:GetFrameLevel() + 2)
    padBtn:RegisterForClicks("LeftButtonUp")
    padBtn:SetScript("OnEnter", function() ns:SetControllerFocus(box) end)
    padBtn:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:SetControllerFocus(box)
        padBtn:Hide()
        box:SetFocus()
        box:SetCursorPosition(#(box:GetText() or ""))
    end)

    local function UpdatePlaceholder(self)
        if self:GetText() == "" and not self:HasFocus() then self.placeholder:Show() else self.placeholder:Hide() end
    end

    box.SetCleanText = function(self, txt)
        self.isDirty = false
        self:SetText(txt or "")
        UpdatePlaceholder(self)
    end

    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self.isDirty = true end
        UpdatePlaceholder(self)
    end)
    box:SetScript("OnEditFocusGained", function(self)
        ns.activeEditBox = self
        padBtn:Hide()
        ns:SetControllerFocus(self)
        self:SetBackdropColor(unpack(M3.surfaceHigh))
        self.bottomBar:SetColorTexture(0.51, 0.79, 0.58, 1.0)
        UpdatePlaceholder(self)
        if ns.ShowStatusToast then ns:ShowStatusToast("Typing Mode: Press [A], [B], or [Enter] when finished") end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if ns.activeEditBox == self then ns.activeEditBox = nil end
        padBtn:Show()
        self:SetBackdropColor(unpack(ns.currentFocus == self and M3.surfaceHigh or M3.surface))
        self.bottomBar:SetColorTexture(unpack(ns.currentFocus == self and M3.primary or { 0.37, 0.40, 0.46, 0.85 }))
        if ns.currentFocus == self then ns:SetControllerFocus(self) end
        UpdatePlaceholder(self)
        if self.isDirty and onCommit then onCommit(self:GetText()) end
    end)
    box:SetScript("OnEnterPressed", function(self)
        self.isDirty = true
        self:ClearFocus()
        if onCommit then onCommit(self:GetText()) end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    ns:RegisterFocusable(box, function()
        ns:PlayUISound()
        padBtn:Hide()
        box:SetFocus()
        box:SetCursorPosition(#(box:GetText() or ""))
    end, function(self, isFocused)
        if isFocused then
            self:SetBackdropColor(unpack(M3.surfaceHigh))
            self.bottomBar:SetColorTexture(0.54, 0.71, 0.97, 1.0)
        elseif not self:HasFocus() then
            self:SetBackdropColor(unpack(M3.surface))
            self.bottomBar:SetColorTexture(0.37, 0.40, 0.46, 0.85)
        end
    end)
    return box
end

function ns:CreateScrollableTextEditor(parent, placeholderText, x, y, width, height, onCommit)
    local M3 = ns.M3
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(width, height)
    container:SetPoint("TOPLEFT", x, y)
    ns:ApplySurface(container, M3.surface, M3.outline)
    ns:EnableClipping(container)
    container.isDirty = false

    container.bottomBar = container:CreateTexture(nil, "OVERLAY")
    container.bottomBar:SetHeight(2)
    container.bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
    container.bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
    container.bottomBar:SetColorTexture(0.37, 0.40, 0.46, 0.85)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 22)
    scrollFrame:EnableMouseWheel(true)
    ns:EnableClipping(scrollFrame)
    container.scrollFrame = scrollFrame

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(math.max(200, width - 48))
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(2500)
    if editBox.SetWordWrap then editBox:SetWordWrap(true) end
    if editBox.SetNonSpaceWrap then editBox:SetNonSpaceWrap(true) end
    scrollFrame:SetScrollChild(editBox)

    local placeholder = container:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    placeholder:SetPoint("TOPLEFT", 14, -12)
    placeholder:SetPoint("RIGHT", -34, 0)
    placeholder:SetJustifyH("LEFT")
    placeholder:SetWordWrap(true)
    placeholder:SetText(placeholderText or "")

    local counter = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    counter:SetPoint("BOTTOMRIGHT", -30, 6)

    local padBtn = CreateFrame("Button", nil, container)
    padBtn:SetAllPoints(container)
    padBtn:SetFrameLevel(container:GetFrameLevel() + 4)
    padBtn:RegisterForClicks("LeftButtonUp")
    padBtn:SetScript("OnEnter", function() ns:SetControllerFocus(container) end)
    padBtn:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:SetControllerFocus(container)
        padBtn:Hide()
        editBox:SetFocus()
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if not delta or delta == 0 then return end
        ScrollFrameByDelta(self, delta > 0 and -36 or 36)
    end)
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        if w and w > 60 then editBox:SetWidth(w - 12) end
    end)

    local function UpdateState()
        local txt = editBox:GetText() or ""
        if txt == "" and not editBox:HasFocus() then placeholder:Show() else placeholder:Hide() end
        counter:SetText(string.format("%d / 2500 chars", #txt))
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then container.isDirty = true end
        ScrollingEdit_OnTextChanged(self, scrollFrame)
        UpdateState()
    end)
    editBox:SetScript("OnCursorChanged", function(self, cx, cy, cw, ch)
        ScrollingEdit_OnCursorChanged(self, cx, cy, cw, ch)
    end)
    editBox:SetScript("OnEditFocusGained", function()
        ns.activeEditBox = container
        padBtn:Hide()
        ns:SetControllerFocus(container)
        container:SetBackdropColor(unpack(M3.surfaceHigh))
        container.bottomBar:SetColorTexture(0.51, 0.79, 0.58, 1)
        UpdateState()
        if ns.ShowStatusToast then ns:ShowStatusToast("Editing Text: Press [B] or [Escape] when finished") end
    end)
    editBox:SetScript("OnEditFocusLost", function()
        if ns.activeEditBox == container then ns.activeEditBox = nil end
        padBtn:Show()
        container:SetBackdropColor(unpack(ns.currentFocus == container and M3.surfaceHigh or M3.surface))
        container.bottomBar:SetColorTexture(unpack(ns.currentFocus == container and M3.primary or { 0.37, 0.40, 0.46, 0.85 }))
        if ns.currentFocus == container then ns:SetControllerFocus(container) end
        UpdateState()
        if container.isDirty and onCommit then onCommit(editBox:GetText()) end
    end)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    container.editBox = editBox
    container.SetCleanText = function(self, txt) self.isDirty = false; editBox:SetText(txt or ""); UpdateState() end
    container.SetText = function(_, txt) editBox:SetText(txt or ""); UpdateState() end
    container.GetText = function() return editBox:GetText() end
    container.HasFocus = function() return editBox:HasFocus() end
    container.ClearFocus = function() editBox:ClearFocus() end
    container.IsMultiLine = function() return true end
    container.SetPlaceholder = function(_, newHint) placeholder:SetText(newHint); UpdateState() end

    ns:RegisterFocusable(container, function()
        ns:PlayUISound()
        padBtn:Hide()
        editBox:SetFocus()
    end, function(self, isFocused)
        if isFocused then
            self:SetBackdropColor(unpack(M3.surfaceHigh))
            self.bottomBar:SetColorTexture(0.54, 0.71, 0.97, 1.0)
        elseif not editBox:HasFocus() then
            self:SetBackdropColor(unpack(M3.surface))
            self.bottomBar:SetColorTexture(0.37, 0.40, 0.46, 0.85)
        end
    end)
    return container
end

function ns:CreateMaterialButton(parent, text, width, height, x, y, tone, onClick)
    local M3 = ns.M3
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetPoint("TOPLEFT", x, y)
    ns:EnableClipping(btn)

    local function ResolveTone(t)
        if t == "PRIMARY" then return M3.primaryTonal, M3.primary
        elseif t == "AMBER" then return M3.amberTonal, M3.amber
        elseif t == "MINT" then return M3.mintTonal, M3.mint
        elseif t == "CORAL" then return M3.coralTonal, M3.coral
        else return M3.surfaceHigh, M3.outline end
    end

    btn.SetTone = function(self, newTone)
        local bg, brd = ResolveTone(newTone)
        self.defaultBg, self.defaultBorder = bg, brd
        if ns.currentFocus == self then
            ns:ApplySurface(self, M3.surfaceBright, M3.primary)
        else
            ns:ApplySurface(self, bg, brd)
        end
    end
    btn:SetTone(tone)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("LEFT", 8, 0)
    btn.label:SetPoint("RIGHT", -8, 0)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetWordWrap(false)
    btn.label:SetText(text)
    btn.SetText = function(self, newText) self.label:SetText(newText) end

    btn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    btn:SetScript("OnLeave", function(self)
        if ns.currentFocus ~= self then
            self:SetBackdropColor(unpack(self.defaultBg or M3.surfaceHigh))
            self:SetBackdropBorderColor(unpack(self.defaultBorder or M3.outline))
        end
    end)
    btn:SetScript("OnClick", function(self)
        ns:PlayUISound()
        onClick(self)
    end)

    ns:RegisterFocusable(btn, function() btn:Click("LeftButton") end, function(self, isFocused)
        if isFocused then
            self:SetBackdropColor(unpack(M3.surfaceBright))
            self:SetBackdropBorderColor(unpack(M3.primary))
        else
            self:SetBackdropColor(unpack(self.defaultBg or M3.surfaceHigh))
            self:SetBackdropBorderColor(unpack(self.defaultBorder or M3.outline))
        end
    end)
    return btn
end