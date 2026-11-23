local _, ns = ...

-- PadRP UI widgets, theme engine, and controller focus management.
-- Native gamepad focus integration is intentionally cooperative: PadRP never
-- registers its windows with Blizzard's private FrameControlsManager and never
-- binds PADBACK (Xbox View / Change Focus Frame).

ns.focusables = ns.focusables or {}
ns.currentFocus = nil
ns.activeEditBox = nil
ns.lastFocusByScope = ns.lastFocusByScope or {}

local lastPadInputTime = 0
local focusRing = nil
local bindingOwner = nil
local pendingBindingSync = false
local focusCallbackOwner = {}
local focusCallbackRegistered = false
local focusRefreshQueued = false
local focusVisualsSuspended = false

local themedSurfaces = setmetatable({}, { __mode = "k" })
local themedButtons  = setmetatable({}, { __mode = "k" })
local themedInputs   = setmetatable({}, { __mode = "k" })

local THEME_PALETTES = {
    MODERN = {
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
        inputBarIdle   = { 0.37, 0.40, 0.46, 0.85 },
        focusBg        = { 0.54, 0.71, 0.97, 0.06 },
        focusBorder    = { 0.54, 0.71, 0.97, 0.92 },
        typingBg       = { 0.51, 0.79, 0.58, 0.08 },
        typingBorder   = { 0.51, 0.79, 0.58, 0.98 },
    },
    NATIVE = {
        surfaceDim     = { 0.07, 0.06, 0.04, 0.99 },
        surfaceLow     = { 0.11, 0.09, 0.06, 1.00 },
        surface        = { 0.15, 0.12, 0.08, 1.00 },
        surfaceHigh    = { 0.20, 0.16, 0.11, 1.00 },
        surfaceBright  = { 0.27, 0.21, 0.13, 1.00 },
        outline        = { 0.58, 0.46, 0.22, 0.85 },
        outlineFocus   = { 1.00, 0.82, 0.18, 0.95 },
        primary        = { 0.96, 0.78, 0.24, 1.00 },
        primaryTonal   = { 0.26, 0.19, 0.07, 1.00 },
        amber          = { 1.00, 0.84, 0.32, 1.00 },
        amberTonal     = { 0.30, 0.21, 0.07, 1.00 },
        mint           = { 0.44, 0.82, 0.48, 1.00 },
        mintTonal      = { 0.10, 0.23, 0.11, 1.00 },
        coral          = { 0.90, 0.38, 0.34, 1.00 },
        coralTonal     = { 0.30, 0.10, 0.09, 1.00 },
        inputBarIdle   = { 0.58, 0.46, 0.22, 0.90 },
        focusBg        = { 1.00, 0.82, 0.18, 0.08 },
        focusBorder    = { 1.00, 0.82, 0.18, 0.96 },
        typingBg       = { 0.44, 0.82, 0.48, 0.10 },
        typingBorder   = { 0.44, 0.82, 0.48, 0.98 },
    },
}

-- Shared live palette table (mutated in-place by ApplyTheme so cached `local M3 = ns.M3` references update automatically)
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
    inputBarIdle   = { 0.37, 0.40, 0.46, 0.85 },
    focusBg        = { 0.54, 0.71, 0.97, 0.06 },
    focusBorder    = { 0.54, 0.71, 0.97, 0.92 },
    typingBg       = { 0.51, 0.79, 0.58, 0.08 },
    typingBorder   = { 0.51, 0.79, 0.58, 0.98 },
}

local SOLID_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local NATIVE_WINDOW_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false,
    edgeSize = 14,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
}

local NATIVE_CONTROL_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

function ns:GetUITheme()
    local ui = ns.db and ns.db.ui
    if ui and ui.theme == "NATIVE" then
        return "NATIVE"
    end
    return "MODERN"
end

function ns:IsHighContrastFocus()
    local ui = ns.db and ns.db.ui
    return (ui and ui.highContrastFocus == true) or false
end

local function FindM3Key(colorTable)
    if type(colorTable) ~= "table" then return nil end
    for k, tbl in pairs(ns.M3) do
        if tbl == colorTable then
            return k
        end
    end
    return nil
end

local function IsLargeWindowSurface(frame, bgKey)
    if not frame then return false end
    if bgKey == "surfaceDim" then
        local w = (frame.GetWidth and frame:GetWidth()) or 0
        local h = (frame.GetHeight and frame:GetHeight()) or 0
        if w == 0 or h == 0 or (w >= 220 and h >= 110) then
            return true
        end
    end
    return false
end

local function ApplyBackdropForTheme(frame, bgColor, borderColor, bgKey)
    if not frame or not frame.SetBackdrop then return end
    local theme = ns:GetUITheme()
    local useNativeWindow = (theme == "NATIVE") and IsLargeWindowSurface(frame, bgKey)

    if useNativeWindow then
        frame:SetBackdrop(NATIVE_WINDOW_BACKDROP)
        local bg = bgColor or ns.M3.surfaceDim
        local brd = borderColor or ns.M3.outline
        frame:SetBackdropColor(bg[1], bg[2], bg[3], math.max(0.98, bg[4] or 0.99))
        frame:SetBackdropBorderColor(brd[1], brd[2], brd[3], brd[4] or 0.95)
    else
        frame:SetBackdrop(theme == "NATIVE" and NATIVE_CONTROL_BACKDROP or SOLID_BACKDROP)
        frame:SetBackdropColor(unpack(bgColor or ns.M3.surface))
        frame:SetBackdropBorderColor(unpack(borderColor or ns.M3.outline))
    end
end

local function SyncFocusRingAppearance()
    if not focusRing then return end
    local hiContrast = ns:IsHighContrastFocus()
    local edgePx = hiContrast and 3 or 2
    focusRing:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = edgePx,
        insets   = { left = edgePx, right = edgePx, top = edgePx, bottom = edgePx },
    })

    local isTyping = (ns.activeEditBox and ns.currentFocus and ns.activeEditBox == ns.currentFocus)
    if isTyping then
        local bg = ns.M3.typingBg
        local brd = ns.M3.typingBorder
        focusRing:SetBackdropColor(bg[1], bg[2], bg[3], hiContrast and (bg[4] + 0.06) or bg[4])
        focusRing:SetBackdropBorderColor(brd[1], brd[2], brd[3], 1.0)
    else
        local bg = ns.M3.focusBg
        local brd = ns.M3.focusBorder
        focusRing:SetBackdropColor(bg[1], bg[2], bg[3], hiContrast and (bg[4] + 0.08) or bg[4])
        focusRing:SetBackdropBorderColor(brd[1], brd[2], brd[3], hiContrast and 1.0 or brd[4])
    end
end

function ns:ApplyTheme(themeKey)
    if themeKey == "MODERN" or themeKey == "NATIVE" then
        if ns.db and ns.db.ui then
            ns.db.ui.theme = themeKey
        end
    end

    local activeTheme = ns:GetUITheme()
    local src = THEME_PALETTES[activeTheme] or THEME_PALETTES.MODERN
    for k, vals in pairs(src) do
        local dst = ns.M3[k]
        if type(dst) ~= "table" then
            ns.M3[k] = { vals[1], vals[2], vals[3], vals[4] }
        else
            dst[1], dst[2], dst[3], dst[4] = vals[1], vals[2], vals[3], vals[4]
        end
    end

    for frame, meta in pairs(themedSurfaces) do
        local bg  = (meta.bgKey and ns.M3[meta.bgKey]) or meta.bgFallback or ns.M3.surface
        local brd = (meta.borderKey and ns.M3[meta.borderKey]) or meta.borderFallback or ns.M3.outline
        ApplyBackdropForTheme(frame, bg, brd, meta.bgKey)
    end

    for btn in pairs(themedButtons) do
        if btn.SetTone then
            btn:SetTone(btn._padRPTone)
        end
    end

    for inp in pairs(themedInputs) do
        if inp._padRPApplyTheme then
            inp:_padRPApplyTheme()
        end
    end

    SyncFocusRingAppearance()

    if ns.currentFocus and ns.currentFocus.IsVisible and ns.currentFocus:IsVisible() then
        ns:SetControllerFocus(ns.currentFocus)
    end
end

local function CountDisplayChars(str)
    if type(strlenutf8) == "function" then
        return strlenutf8(str or "")
    end
    return #(str or "")
end

local function ScrollFrameByDelta(scrollFrame, deltaPixels)
    if not scrollFrame or not scrollFrame.GetVerticalScroll or not scrollFrame.SetVerticalScroll then
        return false
    end

    local cur = scrollFrame:GetVerticalScroll() or 0
    local maxS = (scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange()) or 0
    if maxS <= 2 then return false end

    local nextVal = math.max(0, math.min(maxS, cur + deltaPixels))
    if math.abs(nextVal - cur) < 0.5 then return false end

    scrollFrame:SetVerticalScroll(nextVal)
    return true
end

local function AttachBlinkingCaret(editBox, offsetX, offsetY)
    local caret = editBox:CreateTexture(nil, "OVERLAY")
    caret:SetWidth(2)
    caret:SetHeight(14)
    caret:SetColorTexture(0.95, 0.97, 1.0, 1.0)
    caret:SetPoint("TOPLEFT", editBox, "TOPLEFT", offsetX or 0, offsetY or 0)
    caret:Hide()

    local elapsedAccum = 0
    local visiblePhase = true
    local lastX, lastY = nil, nil

    local function ResetBlink()
        elapsedAccum = 0
        visiblePhase = true
        if editBox:HasFocus() then
            caret:Show()
        else
            caret:Hide()
        end
    end

    editBox:HookScript("OnCursorChanged", function(_, cx, cy, _, ch)
        local h = (ch and ch > 4) and ch or 14
        caret:SetHeight(h)
        caret:ClearAllPoints()
        caret:SetPoint("TOPLEFT", editBox, "TOPLEFT", (cx or 0) + (offsetX or 0), (cy or 0) + (offsetY or 0))
        if cx ~= lastX or cy ~= lastY then
            lastX, lastY = cx, cy
            ResetBlink()
        elseif editBox:HasFocus() and not caret:IsShown() and visiblePhase then
            caret:Show()
        end
    end)

    editBox:HookScript("OnEditFocusGained", function()
        lastX, lastY = nil, nil
        ResetBlink()
    end)

    editBox:HookScript("OnEditFocusLost", function()
        lastX, lastY = nil, nil
        caret:Hide()
    end)

    editBox:HookScript("OnUpdate", function(_, elapsed)
        if not editBox:HasFocus() then
            if caret:IsShown() then caret:Hide() end
            return
        end
        elapsedAccum = elapsedAccum + (elapsed or 0)
        if elapsedAccum >= 0.5 then
            elapsedAccum = 0
            visiblePhase = not visiblePhase
            caret:SetShown(visiblePhase)
        end
    end)

    return caret
end

function ns:ApplySurface(frame, bgColor, borderColor)
    if not frame then return end
    local bgKey = FindM3Key(bgColor)
    local borderKey = FindM3Key(borderColor)

    themedSurfaces[frame] = {
        bgKey          = bgKey,
        borderKey      = borderKey,
        bgFallback     = bgColor,
        borderFallback = borderColor,
    }

    ApplyBackdropForTheme(frame, bgColor, borderColor, bgKey)
end

function ns:EnableClipping(frame)
    if frame and frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
end

function ns:CanProcessPadAction()
    local now = (GetTime and GetTime()) or 0
    if (now - lastPadInputTime) < 0.14 then return false end
    lastPadInputTime = now
    return true
end

local function IsFrameDescendantOf(frame, ancestor)
    if not frame or not ancestor then return false end

    local p = frame
    while p do
        if p == ancestor then return true end
        if not p.GetParent then break end
        p = p:GetParent()
    end

    return false
end

ns.IsFrameDescendantOf = IsFrameDescendantOf

function ns:IsFocusableInScope(widget, scope)
    if not widget or not scope then return false end
    if not widget.IsVisible or not widget:IsVisible() then return false end
    if widget.IsEnabled and not widget:IsEnabled() then return false end
    return IsFrameDescendantOf(widget, scope)
end

function ns:RegisterFocusable(widget, activateFn, onFocusChange)
    if not widget then return end

    widget.ActivateFromPad = activateFn
    widget.OnFocusHighlight = onFocusChange

    if widget._padRPFocusableRegistered then return end
    widget._padRPFocusableRegistered = true
    table.insert(ns.focusables, widget)
end

local function GetNativeGamepadFocusFrame()
    local gamepadMode = _G.GamepadMode
    local manager = gamepadMode and gamepadMode.FrameControlsManager
    if not manager or type(manager.GetActiveFrame) ~= "function" then
        return nil
    end

    local ok, frame = pcall(manager.GetActiveFrame, manager)
    if ok then return frame end
    return nil
end

ns.GetNativeGamepadFocusFrame = GetNativeGamepadFocusFrame

local function HideFocusRingPreservingSelection()
    if not focusVisualsSuspended then
        focusVisualsSuspended = true
        if ns.currentFocus and ns.currentFocus.OnFocusHighlight then
            ns.currentFocus:OnFocusHighlight(false)
        end
    end
    if focusRing then focusRing:Hide() end
end

local function GetOrCreateFocusRing()
    if focusRing then return focusRing end

    focusRing = CreateFrame("Frame", "PadRP_FocusRing", UIParent, "BackdropTemplate")
    SyncFocusRingAppearance()
    focusRing:EnableMouse(false)
    focusRing:SetScript("OnUpdate", function()
        if not ns.currentFocus then
            focusRing:Hide()
            return
        end

        if not ns.currentFocus.IsVisible or not ns.currentFocus:IsVisible() then
            ns:SetControllerFocus(nil)
            return
        end

        if GetNativeGamepadFocusFrame() then
            HideFocusRingPreservingSelection()
        end
    end)
    focusRing:Hide()
    return focusRing
end

local function RestorePadRPFocusAfterNativeHandoff()
    local nativeFrame = GetNativeGamepadFocusFrame()
    if nativeFrame then
        HideFocusRingPreservingSelection()
        return
    end

    local scope = ns:GetActiveModalScope()
    if not scope or not scope.IsShown or not scope:IsShown() then
        ns:UpdateControllerBindings()
        return
    end

    local remembered = ns.lastFocusByScope[scope]
    if ns:IsFocusableInScope(remembered, scope) then
        ns:SetControllerFocus(remembered)
    elseif ns:IsFocusableInScope(ns.currentFocus, scope) then
        ns:SetControllerFocus(ns.currentFocus)
    else
        ns:FocusFirstInScope()
    end

    ns:UpdateControllerBindings()
end

local function QueueGamepadFocusRefresh()
    if focusRefreshQueued then return end
    focusRefreshQueued = true

    local function Refresh()
        focusRefreshQueued = false

        if InCombatLockdown and InCombatLockdown() then
            pendingBindingSync = true
            HideFocusRingPreservingSelection()
            return
        end

        RestorePadRPFocusAfterNativeHandoff()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, Refresh)
    else
        Refresh()
    end
end

local function RegisterGamepadFocusObserver()
    if focusCallbackRegistered then return end
    if not EventRegistry or type(EventRegistry.RegisterCallback) ~= "function" then
        return
    end

    local ok = pcall(function()
        EventRegistry:RegisterCallback(
            "Gamepad.RefreshFrameFocus",
            QueueGamepadFocusRefresh,
            focusCallbackOwner
        )
    end)

    focusCallbackRegistered = ok
end

local function EnsureBindingOwner()
    if bindingOwner then return bindingOwner end

    bindingOwner = CreateFrame("Frame", "PadRP_PadBindingOwner", UIParent)
    bindingOwner:RegisterEvent("PLAYER_REGEN_DISABLED")
    bindingOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
    bindingOwner:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if ClearOverrideBindings then
                pcall(ClearOverrideBindings, bindingOwner)
            end
            pendingBindingSync = true
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingBindingSync then
                pendingBindingSync = false
                ns:UpdateControllerBindings()
            end
        end
    end)

    RegisterGamepadFocusObserver()
    return bindingOwner
end

local function BindPadClick(owner, key, buttonName)
    if not SetOverrideBindingClick or not _G[buttonName] then return end
    SetOverrideBindingClick(owner, true, key, buttonName, "LeftButton")
end

function ns:UpdateControllerBindings()
    local owner = EnsureBindingOwner()
    local nativeFrame = GetNativeGamepadFocusFrame()

    local dossierOpen = ns.dossierFrame and ns.dossierFrame:IsShown()
    local mainOpen = ns.mainFrame and ns.mainFrame:IsShown()
    local modalOpen = dossierOpen or mainOpen
    local hudFocused = ns.hudFrame
        and ns.hudFrame:IsShown()
        and ns.currentFocus == ns.hudFrame

    if InCombatLockdown and InCombatLockdown() then
        pendingBindingSync = true
        if nativeFrame then HideFocusRingPreservingSelection() end
        return
    end

    if ClearOverrideBindings then
        ClearOverrideBindings(owner)
    end

    if nativeFrame then
        HideFocusRingPreservingSelection()
        pendingBindingSync = false
        return
    end

    if not modalOpen and not hudFocused then
        ns:SetControllerFocus(nil)
    end

    if modalOpen then
        BindPadClick(owner, "PADLSHOULDER", "PadRP_PrevTabBtn")
        BindPadClick(owner, "PADRSHOULDER", "PadRP_NextTabBtn")
        BindPadClick(owner, "PADDUP",       "PadRP_PadUpBtn")
        BindPadClick(owner, "PADDDOWN",     "PadRP_PadDownBtn")
        BindPadClick(owner, "PADDLEFT",     "PadRP_PadLeftBtn")
        BindPadClick(owner, "PADDRIGHT",    "PadRP_PadRightBtn")
        BindPadClick(owner, "PAD1",         "PadRP_PadConfirmBtn")
        BindPadClick(owner, "PAD2",         "PadRP_PadCancelBtn")
    elseif hudFocused then
        BindPadClick(owner, "PAD1", "PadRP_PadConfirmBtn")
        BindPadClick(owner, "PAD2", "PadRP_PadCancelBtn")
    end

    pendingBindingSync = false
end

function ns:GetActiveModalScope()
    if ns.dossierFrame and ns.dossierFrame:IsShown() then
        if ns.dossierFrame.standingDropdown and ns.dossierFrame.standingDropdown:IsShown() then
            return ns.dossierFrame.standingDropdown
        end
        return ns.dossierFrame
    end

    local mf = ns.mainFrame
    if mf and mf:IsShown() then
        if mf.iconPicker and mf.iconPicker:IsShown() then return mf.iconPicker end
        if mf.exportModal and mf.exportModal:IsShown() then return mf.exportModal end
        if mf.presetDropdown and mf.presetDropdown:IsShown() then return mf.presetDropdown end
        if mf.expDropdown and mf.expDropdown:IsShown() then return mf.expDropdown end
        if mf.modeDropdown and mf.modeDropdown:IsShown() then return mf.modeDropdown end
        if mf.poolDropdown and mf.poolDropdown:IsShown() then return mf.poolDropdown end
        return mf
    end

    if ns.hudFrame and ns.hudFrame:IsShown() and ns.currentFocus == ns.hudFrame then
        return ns.hudFrame
    end

    return nil
end

function ns:SetControllerFocus(widget)
    if ns.currentFocus and ns.currentFocus ~= widget and ns.currentFocus.OnFocusHighlight then
        ns.currentFocus:OnFocusHighlight(false)
    end

    if not widget or not widget.IsVisible or not widget:IsVisible()
        or (widget.IsEnabled and not widget:IsEnabled()) then
        ns.currentFocus = nil
        if focusRing then focusRing:Hide() end
        return
    end

    ns.currentFocus = widget

    local scope = ns:GetActiveModalScope()
    if scope and ns:IsFocusableInScope(widget, scope) then
        ns.lastFocusByScope[scope] = widget
    end

    if GetNativeGamepadFocusFrame() then
        HideFocusRingPreservingSelection()
        return
    end

    focusVisualsSuspended = false
    if widget.OnFocusHighlight then
        widget:OnFocusHighlight(true)
    end

    local ring = GetOrCreateFocusRing()
    local strata = (widget.GetFrameStrata and widget:GetFrameStrata()) or "DIALOG"
    local level = (widget.GetFrameLevel and widget:GetFrameLevel()) or 40
    local pad = ns:IsHighContrastFocus() and 3 or 2
    ring:SetFrameStrata(strata)
    ring:SetFrameLevel(level + 25)
    ring:ClearAllPoints()
    ring:SetPoint("TOPLEFT", widget, "TOPLEFT", -pad, pad)
    ring:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", pad, -pad)

    SyncFocusRingAppearance()
    ring:Show()
end

function ns:FocusFirstInScope()
    local scope = ns:GetActiveModalScope()
    if not scope or not scope.IsShown or not scope:IsShown() then
        ns:SetControllerFocus(nil)
        return
    end

    if GetNativeGamepadFocusFrame() then
        HideFocusRingPreservingSelection()
        return
    end

    if scope == ns.hudFrame then
        ns:SetControllerFocus(ns.hudFrame)
        return
    end

    local remembered = ns.lastFocusByScope[scope]
    if ns:IsFocusableInScope(remembered, scope) then
        ns:SetControllerFocus(remembered)
        return
    end

    local preferredContainer = nil
    if scope == ns.mainFrame and ns.mainFrame.tabPanels and ns.mainFrame.activeTab then
        preferredContainer = ns.mainFrame.tabPanels[ns.mainFrame.activeTab]
    end

    local bestWidget, bestScore = nil, 999999

    if preferredContainer and preferredContainer:IsShown() then
        for _, w in ipairs(ns.focusables) do
            if ns:IsFocusableInScope(w, preferredContainer) and not w.isTabBarBtn then
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
            if ns:IsFocusableInScope(w, scope) and not w.isTabBarBtn then
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
    if GetNativeGamepadFocusFrame() then
        HideFocusRingPreservingSelection()
        return
    end

    local scope = ns:GetActiveModalScope()
    if not scope or not self:CanProcessPadAction() then return end

    if ns.activeEditBox and ns.activeEditBox.HasFocus and ns.activeEditBox:HasFocus() then
        if not ns.activeEditBox:IsMultiLine() and (dir == "UP" or dir == "DOWN") then
            ns.activeEditBox:ClearFocus()
        else
            return
        end
    end

    local cur = ns.currentFocus
    if not ns:IsFocusableInScope(cur, scope) then
        ns:FocusFirstInScope()
        return
    end

    if cur.directoryRowIndex and (dir == "UP" or dir == "DOWN") and ns.TrySeamlessDirectoryStep then
        if ns:TrySeamlessDirectoryStep(cur.directoryRowIndex, dir) then
            return
        end
    end

    if cur.emoteRowIndex and (dir == "UP" or dir == "DOWN") and ns.TrySeamlessEmoteStep then
        if ns:TrySeamlessEmoteStep(cur.emoteRowIndex, dir) then
            return
        end
    end

    local cx, cy = cur:GetCenter()
    local cl, cr, ct, cb = cur:GetLeft(), cur:GetRight(), cur:GetTop(), cur:GetBottom()
    if not cx or not cy or not cl or not cr or not ct or not cb then
        ns:FocusFirstInScope()
        return
    end

    local bestCandidate, bestScore = nil, 999999

    for _, w in ipairs(ns.focusables) do
        if w ~= cur and ns:IsFocusableInScope(w, scope) and not w.isTabBarBtn then
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
                    score = (overlapY > 2 or math.abs(dy) <= 18)
                        and (edgeGap + dx * 0.2 + math.abs(dy))
                        or (5000 + math.abs(dy) * 20 + edgeGap)
                elseif dir == "LEFT" and dx < -12 and wr <= cr - 10 then
                    valid = true
                    local edgeGap = math.max(0, cl - wr)
                    score = (overlapY > 2 or math.abs(dy) <= 18)
                        and (edgeGap - dx * 0.2 + math.abs(dy))
                        or (5000 + math.abs(dy) * 20 + edgeGap)
                elseif dir == "DOWN" and dy < -10 and wt <= ct - 6 then
                    valid = true
                    local vertGap = math.max(0, cb - wt)
                    score = (overlapX > 2)
                        and (vertGap + math.abs(dx) * 0.15)
                        or (2000 + vertGap + math.abs(dx) * 8)
                elseif dir == "UP" and dy > 10 and wb >= cb + 6 then
                    valid = true
                    local vertGap = math.max(0, wb - ct)
                    score = (overlapX > 2)
                        and (vertGap + math.abs(dx) * 0.15)
                        or (2000 + vertGap + math.abs(dx) * 8)
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

        if bestCandidate.glanceScrollFrame and bestCandidate.glanceIndex then
            local sf = bestCandidate.glanceScrollFrame
            local maxS = (sf.GetVerticalScrollRange and sf:GetVerticalScrollRange()) or 0
            if maxS > 0 then
                local targetScroll = math.max(0, math.min(maxS, (bestCandidate.glanceIndex - 1) * 112))
                sf:SetVerticalScroll(targetScroll)
            end
        end
        return
    end

    if dir == "UP" or dir == "DOWN" then
        local stepPx = (dir == "DOWN") and 96 or -96

        if cur.scrollFrame and ScrollFrameByDelta(cur.scrollFrame, stepPx) then
            return
        elseif cur.glanceScrollFrame and ScrollFrameByDelta(cur.glanceScrollFrame, stepPx) then
            return
        elseif scope == ns.dossierFrame
            and ns.dossierFrame.scrollFrame
            and ns.dossierFrame.readerBox
            and ns.dossierFrame.readerBox:IsShown() then
            ScrollFrameByDelta(ns.dossierFrame.scrollFrame, stepPx)
        end
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
    box.bottomBar:SetColorTexture(unpack(M3.inputBarIdle))

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
    padBtn:SetScript("OnEnter", function()
        if not box:HasFocus() then
            ns:SetControllerFocus(box)
        end
    end)
    padBtn:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:SetControllerFocus(box)
        padBtn:Hide()
        box:SetFocus()
        box:SetCursorPosition(#(box:GetText() or ""))
    end)
    box.padBtn = padBtn

    local function RefreshBoxColors(self)
        if self:HasFocus() then
            self:SetBackdropColor(unpack(M3.surfaceHigh))
            self.bottomBar:SetColorTexture(unpack(M3.mint))
        elseif ns.currentFocus == self then
            self:SetBackdropColor(unpack(M3.surfaceHigh))
            self.bottomBar:SetColorTexture(unpack(M3.primary))
        else
            self:SetBackdropColor(unpack(M3.surface))
            self.bottomBar:SetColorTexture(unpack(M3.inputBarIdle))
        end
    end
    box._padRPApplyTheme = RefreshBoxColors
    themedInputs[box] = true

    local function UpdatePlaceholder(self)
        if self:GetText() == "" and not self:HasFocus() then
            self.placeholder:Show()
        else
            self.placeholder:Hide()
        end
        if not self:HasFocus() then
            padBtn:Show()
        end
    end

    box.SetCleanText = function(self, txt)
        self.isDirty = false
        self:SetText(txt or "")
        if self.SetCursorPosition then self:SetCursorPosition(0) end
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
        RefreshBoxColors(self)
        UpdatePlaceholder(self)
        if ns.ShowStatusToast then
            ns:ShowStatusToast("Typing Mode: Press [A], [B], or [Enter] when finished")
        end
    end)

    box:SetScript("OnEditFocusLost", function(self)
        if ns.activeEditBox == self then ns.activeEditBox = nil end
        padBtn:Show()
        RefreshBoxColors(self)
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

    -- Must be called AFTER all SetScript calls so HookScript is not overwritten
    AttachBlinkingCaret(box, 10, -6)

    ns:RegisterFocusable(box, function()
        ns:PlayUISound()
        padBtn:Hide()
        box:SetFocus()
        box:SetCursorPosition(#(box:GetText() or ""))
    end, function(self)
        RefreshBoxColors(self)
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
    container.bottomBar:SetColorTexture(unpack(M3.inputBarIdle))

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
    editBox:SetHeight(math.max(60, height - 34))
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
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
    padBtn:SetScript("OnEnter", function()
        if not editBox:HasFocus() then
            ns:SetControllerFocus(container)
        end
    end)
    padBtn:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:SetControllerFocus(container)
        padBtn:Hide()
        editBox:SetFocus()
        editBox:SetCursorPosition(#(editBox:GetText() or ""))
    end)
    container.padBtn = padBtn

    local function RefreshContainerColors(self)
        if editBox:HasFocus() then
            self:SetBackdropColor(unpack(M3.surfaceHigh))
            self.bottomBar:SetColorTexture(unpack(M3.mint))
        elseif ns.currentFocus == self then
            self:SetBackdropColor(unpack(M3.surfaceHigh))
            self.bottomBar:SetColorTexture(unpack(M3.primary))
        else
            self:SetBackdropColor(unpack(M3.surface))
            self.bottomBar:SetColorTexture(unpack(M3.inputBarIdle))
        end
    end
    container._padRPApplyTheme = RefreshContainerColors
    themedInputs[container] = true

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        if not delta or delta == 0 then return end
        ScrollFrameByDelta(self, delta > 0 and -36 or 36)
    end)
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        if w and w > 60 then editBox:SetWidth(w - 12) end
    end)

    local function UpdateState()
        local txt = editBox:GetText() or ""
        if txt == "" and not editBox:HasFocus() then
            placeholder:Show()
        else
            placeholder:Hide()
        end
        if not editBox:HasFocus() then
            padBtn:Show()
        end
        counter:SetText(string.format("%d / 2500 chars", CountDisplayChars(txt)))
        local minH = math.max(60, (scrollFrame:GetHeight() or (height - 34)))
        local lineCount = 1
        for _ in string.gmatch(txt, "\n") do
            lineCount = lineCount + 1
        end
        local estWrapped = math.ceil(CountDisplayChars(txt) / 56)
        local estH = math.max(minH, math.max(lineCount, estWrapped) * 16 + 24)
        editBox:SetHeight(estH)
        if scrollFrame.UpdateScrollChildRect then
            scrollFrame:UpdateScrollChildRect()
        end
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
        RefreshContainerColors(container)
        UpdateState()
        if ns.ShowStatusToast then
            ns:ShowStatusToast("Editing Text: Press [B] or [Escape] when finished")
        end
    end)
    editBox:SetScript("OnEditFocusLost", function()
        if ns.activeEditBox == container then ns.activeEditBox = nil end
        padBtn:Show()
        RefreshContainerColors(container)
        if ns.currentFocus == container then ns:SetControllerFocus(container) end
        UpdateState()
        if container.isDirty and onCommit then onCommit(editBox:GetText()) end
    end)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Must be called AFTER all SetScript calls so HookScript is not overwritten
    AttachBlinkingCaret(editBox, 1, 0)

    container.editBox = editBox
    container.SetCleanText = function(self, txt)
        self.isDirty = false
        editBox:SetText(txt or "")
        scrollFrame:SetVerticalScroll(0)
        UpdateState()
    end
    container.SetText = function(_, txt)
        editBox:SetText(txt or "")
        UpdateState()
    end
    container.GetText = function() return editBox:GetText() end
    container.HasFocus = function() return editBox:HasFocus() end
    container.ClearFocus = function() editBox:ClearFocus() end
    container.IsMultiLine = function() return true end
    container.SetPlaceholder = function(_, newHint)
        placeholder:SetText(newHint)
        UpdateState()
    end

    ns:RegisterFocusable(container, function()
        ns:PlayUISound()
        padBtn:Hide()
        editBox:SetFocus()
        editBox:SetCursorPosition(#(editBox:GetText() or ""))
    end, function(self)
        RefreshContainerColors(self)
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
        self._padRPTone = newTone
        local bg, brd = ResolveTone(newTone)
        self.defaultBg, self.defaultBorder = bg, brd
        if ns.currentFocus == self then
            ns:ApplySurface(self, M3.surfaceBright, M3.primary)
        else
            ns:ApplySurface(self, bg, brd)
        end
    end
    btn:SetTone(tone)
    themedButtons[btn] = true

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
        if onClick then onClick(self) end
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