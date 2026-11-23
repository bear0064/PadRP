local _, ns = ...

local UI = ns.UI

local function GetAccentHex()
    return (ns.GetUITheme and ns:GetUITheme() == "NATIVE") and "fff5c73d" or "ff8ab4f8"
end

local function CloseAnyOpenPopup()
    local mf = UI.mainFrame
    if not mf then return false end
    if ns.dossierFrame and ns.dossierFrame.standingDropdown and ns.dossierFrame.standingDropdown:IsShown() then
        ns.dossierFrame.standingDropdown:Hide()
        if ns.dossierFrame.standingBtn then ns:SetControllerFocus(ns.dossierFrame.standingBtn) end
        return true
    end
    if mf.expDropdown and mf.expDropdown:IsShown() then
        mf.expDropdown:Hide()
        if mf.bannerExpBtn then ns:SetControllerFocus(mf.bannerExpBtn) end
        return true
    end
    if mf.presetDropdown and mf.presetDropdown:IsShown() then
        mf.presetDropdown:Hide()
        if UI.tabPanels[1] and UI.tabPanels[1].presetBtn then ns:SetControllerFocus(UI.tabPanels[1].presetBtn) end
        return true
    end
    if mf.modeDropdown and mf.modeDropdown:IsShown() then
        mf.modeDropdown:Hide()
        if UI.tabPanels[6] and UI.tabPanels[6].modeBtn then ns:SetControllerFocus(UI.tabPanels[6].modeBtn) end
        return true
    end
    if mf.poolDropdown and mf.poolDropdown:IsShown() then
        mf.poolDropdown:Hide()
        if UI.tabPanels[6] and UI.tabPanels[6].poolToggleBtn then ns:SetControllerFocus(UI.tabPanels[6].poolToggleBtn) end
        return true
    end
    if mf.iconPicker and mf.iconPicker:IsShown() then
        local returnTarget = mf.iconPicker.returnFocusWidget
        mf.iconPicker:Hide()
        if returnTarget and returnTarget:IsVisible() then
            ns:SetControllerFocus(returnTarget)
        else
            ns:FocusFirstInScope()
        end
        return true
    end
    if mf.exportModal and mf.exportModal:IsShown() then
        mf.exportModal:Hide()
        ns:FocusFirstInScope()
        return true
    end
    return false
end

local function ApplyTabVisualStates()
    local M3 = ns.M3
    local isNative = (ns.GetUITheme and ns:GetUITheme() == "NATIVE")
    local activeIdx = UI.activeTab or 1

    for i, tb in ipairs(UI.tabButtons) do
        if tb then
            if i == activeIdx then
                tb:SetBackdropColor(unpack(M3.primaryTonal))
                tb:SetBackdropBorderColor(unpack(M3.primary))
                tb.activeBar:SetColorTexture(
                    i == 8 and M3.amber[1] or M3.primary[1],
                    i == 8 and M3.amber[2] or M3.primary[2],
                    i == 8 and M3.amber[3] or M3.primary[3],
                    1
                )
                tb.activeBar:Show()
                if isNative then
                    tb.label:SetTextColor(1.0, 0.93, 0.72)
                else
                    tb.label:SetTextColor(0.90, 0.95, 1.0)
                end
            else
                tb:SetBackdropColor(unpack(M3.surfaceLow))
                tb:SetBackdropBorderColor(0, 0, 0, 0)
                tb.activeBar:Hide()
                if isNative then
                    tb.label:SetTextColor(0.76, 0.70, 0.58)
                else
                    tb.label:SetTextColor(0.64, 0.68, 0.75)
                end
            end
        end
    end
end

local function RefreshShellThemeAccents()
    local mf = UI.mainFrame
    if not mf then return end
    local M3 = ns.M3
    local accentHex = GetAccentHex()

    if mf.topAccent then
        mf.topAccent:SetColorTexture(M3.primary[1], M3.primary[2], M3.primary[3], 0.92)
    end
    if mf.sbHeader then
        mf.sbHeader:SetText("|c" .. accentHex .. "[LB]  SECTIONS  [RB]|r")
    end
    if mf.footerText then
        mf.footerText:SetText(string.format(
            "|c%s[LB]/[RB]|r Sections   |c%s[D-Pad]|r Move Focus   |c%s[A]|r Edit/Confirm   |c%s[B]|r Back/Close",
            accentHex, accentHex, accentHex, accentHex
        ))
    end
    ApplyTabVisualStates()
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
        if (now - (UI.lastEditFocusTime or 0)) < 0.25 then
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

    if cur == UI.lastConfirmTarget and (now - (UI.lastConfirmTime or 0)) < 0.18 then
        return
    end
    UI.lastConfirmTime = now
    UI.lastConfirmTarget = cur

    if cur.GetObjectType and cur:GetObjectType() == "EditBox" then
        UI.lastEditFocusTime = now
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
    if UI.mainFrame and UI.mainFrame:IsShown() then
        UI.mainFrame:Hide()
    end
end

function ns:GetTabDisplayOrder()
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local order = { 1, 2, 3, 4, 5, 6, 9, 7 }
    if showDev then order[#order + 1] = 8 end
    return order
end

function ns:SelectTab(index)
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
    end
    UI:CommitModifiedBoxesToProfile(false)
    UI.activeTab = index
    if UI.mainFrame then
        UI.mainFrame.activeTab = index
    end
    for i, panel in ipairs(UI.tabPanels) do
        if i == index then
            panel:Show()
        else
            panel:Hide()
        end
    end
    ApplyTabVisualStates()
    CloseAnyOpenPopup()
    ns:RefreshControllerUI()
    ns:FocusFirstInScope()
end

function ns:CycleTab(delta)
    if not ns:CanProcessPadAction() then return end
    if ns.dossierFrame and ns.dossierFrame:IsShown() and ns.CycleDossierTab then
        ns:CycleDossierTab(delta)
        return
    end
    local mf = UI.mainFrame
    if not mf or not mf:IsShown() then return end
    if mf.iconPicker and mf.iconPicker:IsShown() then
        mf.iconPicker:StepPage(delta)
        return
    end
    local order = ns:GetTabDisplayOrder()
    local pos = 1
    for i, tabIdx in ipairs(order) do
        if tabIdx == UI.activeTab then pos = i break end
    end
    ns:SelectTab(order[((pos - 1 + delta) % #order) + 1])
end

local function UpdateControlStripLayout()
    local mf = UI.mainFrame
    if not mf or not mf.controlBar then return end
    local bar = mf.controlBar
    local barW = bar:GetWidth()
    if not barW or barW < 240 then return end

    local pad = 10
    local gap = 6
    local icW = 132
    local wuW = 136
    local expW = 122
    local arrowW = 24

    if mf.icSwitch then
        mf.icSwitch:ClearAllPoints()
        mf.icSwitch:SetSize(icW, 26)
        mf.icSwitch:SetPoint("RIGHT", bar, "RIGHT", -pad, 0)
    end
    if mf.walkUpBtn then
        mf.walkUpBtn:ClearAllPoints()
        mf.walkUpBtn:SetSize(wuW, 26)
        mf.walkUpBtn:SetPoint("RIGHT", mf.icSwitch, "LEFT", -gap, 0)
    end
    if mf.bannerExpBtn then
        mf.bannerExpBtn:ClearAllPoints()
        mf.bannerExpBtn:SetSize(expW, 26)
        mf.bannerExpBtn:SetPoint("RIGHT", mf.walkUpBtn, "LEFT", -gap, 0)
    end

    local rightUsed = pad + icW + gap + wuW + gap + expW + gap + pad
    local chipW = math.max(76, math.min(180, barW - rightUsed - (arrowW * 2) - 6))

    if mf.profPrevBtn then
        mf.profPrevBtn:ClearAllPoints()
        mf.profPrevBtn:SetSize(arrowW, 26)
        mf.profPrevBtn:SetPoint("LEFT", bar, "LEFT", pad, 0)
    end
    if mf.profChip then
        mf.profChip:ClearAllPoints()
        mf.profChip:SetSize(chipW, 26)
        mf.profChip:SetPoint("LEFT", mf.profPrevBtn, "RIGHT", 3, 0)
    end
    if mf.profNextBtn then
        mf.profNextBtn:ClearAllPoints()
        mf.profNextBtn:SetSize(arrowW, 26)
        mf.profNextBtn:SetPoint("LEFT", mf.profChip, "RIGHT", 3, 0)
    end
end

local function UpdateSidebarLayout()
    local mf = UI.mainFrame
    if not mf or not UI.tabButtons[1] or not mf.sidebar then return end
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local order = ns:GetTabDisplayOrder()
    local sb = mf.sidebar
    local sbW = sb:GetWidth() or UI.SIDEBAR_WIDTH

    for i = 1, 9 do
        if UI.tabButtons[i] then UI.tabButtons[i]:Hide() end
    end

    for slot, i in ipairs(order) do
        local tb = UI.tabButtons[i]
        if tb then
            tb:ClearAllPoints()
            tb:SetSize(sbW - 14, 30)
            tb:SetPoint("TOPLEFT", sb, "TOPLEFT", 7, -28 - (slot - 1) * 34)
            tb:Show()
        end
    end

    if not showDev and UI.activeTab == 8 then
        ns:SelectTab(7)
    end
end

local function UpdateResponsiveLayouts()
    if not UI.mainFrame then return end
    UpdateControlStripLayout()
    for tabIdx, mod in pairs(UI.tabs) do
        if mod and type(mod.Layout) == "function" and UI.tabPanels[tabIdx] then
            mod.Layout(UI.tabPanels[tabIdx])
        end
    end
end

function UI:RefreshHeaderBanner()
    local mf = UI.mainFrame
    if not mf or not ns.profile then return end
    local p = ns.profile
    local M3 = ns.M3
    local accentHex = GetAccentHex()
    local activeHex = UI:GetPlayerActiveClassColorHex()
    local fallbackIcon = UI:GetDefaultIconFallback()

    if mf.portraitTex then
        UI:SetIconTextureSafe(mf.portraitTex, p.icon, fallbackIcon)
    end

    local nameParts = {}
    if p.titlePrefix and strtrim(p.titlePrefix) ~= "" then table.insert(nameParts, strtrim(p.titlePrefix)) end
    local baseFirst = (p.firstName and p.firstName ~= "") and p.firstName or UnitName("player")
    table.insert(nameParts, baseFirst)
    if p.lastName and strtrim(p.lastName) ~= "" then table.insert(nameParts, strtrim(p.lastName)) end
    local fullName = table.concat(nameParts, " ")

    mf.bannerName:SetText("|c" .. activeHex .. fullName .. "|r")

    local guildVis = UI:GetTopicConsentValue("guild", "Do not show")
    local wowGuild = (guildVis == "Yes" and GetGuildInfo and GetGuildInfo("player")) or ""
    local houseClean = (p.houseName and strtrim(p.houseName)) or ""
    local guildPart = ""
    if wowGuild ~= "" and string.lower(wowGuild) ~= string.lower(houseClean) then
        guildPart = "  |cff81c995<" .. wowGuild .. ">|r"
    end

    local titlePart = (p.title and p.title ~= "") and ("|cfffdd663<" .. p.title .. ">|r") or "|cff9aa0a6No RP Title|r"
    local housePart = (houseClean ~= "") and ("  |c" .. accentHex .. "-  " .. houseClean .. "|r") or ""
    mf.bannerTitle:SetText(titlePart .. housePart .. guildPart)

    if mf.bannerCurrently then
        local curClean = p.currently and strtrim(UI:StripColorCodes(p.currently)) or ""
        if curClean ~= "" then
            local shortCur = string.sub(curClean, 1, 64)
            if #curClean > 64 then shortCur = shortCur .. "..." end
            mf.bannerCurrently:SetText("|cff9aa0a6Currently:|r |cffe8eaed" .. shortCur .. "|r")
        else
            mf.bannerCurrently:SetText("|cff9aa0a6Currently:|r |cff5f6368Not set|r")
        end
    end

    mf.profChip:SetText(p.profileName or "Default")

    if mf.bannerExpBtn then
        mf.bannerExpBtn:SetText("|c" .. accentHex .. "RP:|r " .. UI:GetRPExperienceLabelText(p.rpStyle) .. " [v]")
    end

    local wuBtn = mf.walkUpBtn
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

    local sw = mf.icSwitch
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

function ns:RefreshControllerUI()
    local mf = UI.mainFrame
    if not mf or not ns.profile then return end
    mf:SetScale(ns.db.ui.scale or 1.0)
    RefreshShellThemeAccents()
    UpdateSidebarLayout()
    UpdateResponsiveLayouts()
    UI:RefreshHeaderBanner()

    for tabIdx, mod in pairs(UI.tabs) do
        if mod and type(mod.Refresh) == "function" and UI.tabPanels[tabIdx] then
            mod.Refresh(UI.tabPanels[tabIdx])
        end
    end

    if ns.dossierFrame and ns.dossierFrame:IsShown() and ns.RefreshDossierWindow then
        ns:RefreshDossierWindow()
    end

    if ns.netInspectorFrame and ns.netInspectorFrame:IsShown() and ns.RefreshNetInspector then
        ns:RefreshNetInspector()
    end
end

function ns:SetWindowDimensions(w, h)
    local mf = UI.mainFrame
    if not mf then return end
    w = math.max(740, math.min(1120, w or 760))
    h = math.max(540, math.min(840, h or 580))
    ns.db.ui.width, ns.db.ui.height = w, h
    mf:SetSize(w, h)
    ns:RefreshControllerUI()
end

function ns:ToggleMainFrame()
    local mf = UI.mainFrame
    if not mf then return end

    if mf:IsShown() then
        mf:Hide()
        return
    end

    if ns.LoadProfileIntoUI then
        ns:LoadProfileIntoUI()
    end
    if ns.RefreshControllerUI then
        ns:RefreshControllerUI()
    end

    mf:Show()
end

function ns:OpenEmotesTab()
    local mf = UI.mainFrame
    if not mf then return end
    if not mf:IsShown() then ns:ToggleMainFrame() end
    ns:SelectTab(9)
end

function PadRP_ActionBarToggle()
    if ns and ns.ToggleMainFrame then
        ns:ToggleMainFrame()
    end
end

function ns:InitControllerUI()
    if UI.mainFrame then return end
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

    local savedW = math.max(740, (ns.db.ui and ns.db.ui.width) or 760)
    local savedH = math.max(540, (ns.db.ui and ns.db.ui.height) or 580)

    local mainFrame = CreateFrame("Frame", "PadRP_MainFrame", UIParent, "BackdropTemplate")
    UI.mainFrame = mainFrame
    ns.mainFrame = mainFrame
    mainFrame.tabPanels = UI.tabPanels
    mainFrame:SetSize(savedW, savedH)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(15)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    if mainFrame.SetResizeBounds then mainFrame:SetResizeBounds(740, 540, 1120, 840) end
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
    topAccent:SetHeight(3)
    topAccent:SetPoint("TOPLEFT", 2, -2)
    topAccent:SetPoint("TOPRIGHT", -2, -2)
    topAccent:SetColorTexture(M3.primary[1], M3.primary[2], M3.primary[3], 0.92)
    mainFrame.topAccent = topAccent

    tinsert(UISpecialFrames, "PadRP_MainFrame")

    mainFrame:SetScript("OnShow", function()
        ns:PlayUISound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        RefreshShellThemeAccents()
        UpdateSidebarLayout()
        UpdateResponsiveLayouts()
        ns:UpdateControllerBindings()
        ns:FocusFirstInScope()
    end)
    mainFrame:SetScript("OnHide", function()
        mainFrame:StopMovingOrSizing()
        if ns.activeEditBox and ns.activeEditBox:HasFocus() then ns.activeEditBox:ClearFocus() end
        UI:CommitModifiedBoxesToProfile(false)
        ns:PlayUISound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        CloseAnyOpenPopup()
        ns:UpdateControllerBindings()
    end)
    mainFrame:SetScript("OnSizeChanged", function(self, w, h)
        if ns.db and ns.db.ui then
            ns.db.ui.width, ns.db.ui.height = math.floor(w + 0.5), math.floor(h + 0.5)
        end
        UpdateSidebarLayout()
        UpdateResponsiveLayouts()
        if self:IsShown() then
            if ns.RefreshTargetCard then ns:RefreshTargetCard() end
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

    local picker = UI:CreateIconPicker(mainFrame)
    mainFrame.iconPicker = picker

    -- Hero Banner
    local banner = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    banner:SetHeight(62)
    banner:SetPoint("TOPLEFT", 12, -10)
    banner:SetPoint("TOPRIGHT", -12, -10)
    ns:ApplySurface(banner, M3.surfaceLow, M3.outline)
    ns:EnableClipping(banner)
    mainFrame.banner = banner

    local closeBtn = ns:CreateMaterialButton(banner, "X", 28, 28, 0, -8, "CORAL", function() mainFrame:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -8, -8)
    closeBtn.label:ClearAllPoints()
    closeBtn.label:SetPoint("CENTER", 0, 0)
    mainFrame.closeBtn = closeBtn

    local portraitBtn = CreateFrame("Button", nil, banner, "BackdropTemplate")
    portraitBtn:SetSize(46, 46)
    portraitBtn:SetPoint("LEFT", banner, "LEFT", 8, 0)
    ns:ApplySurface(portraitBtn, M3.surface, M3.primary)
    mainFrame.portraitBtn = portraitBtn
    mainFrame.portraitTex = portraitBtn:CreateTexture(nil, "ARTWORK")
    mainFrame.portraitTex:SetSize(40, 40)
    mainFrame.portraitTex:SetPoint("CENTER")
    mainFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portraitBtn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    portraitBtn:SetScript("OnClick", function(self) ns:PlayUISound(); picker:OpenForPortrait(self) end)
    ns:RegisterFocusable(portraitBtn, function() portraitBtn:Click("LeftButton") end)

    mainFrame.bannerName = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainFrame.bannerName:SetPoint("TOPLEFT", banner, "TOPLEFT", 62, -8)
    mainFrame.bannerName:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    mainFrame.bannerName:SetJustifyH("LEFT")
    mainFrame.bannerName:SetWordWrap(false)

    mainFrame.bannerTitle = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.bannerTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 62, -28)
    mainFrame.bannerTitle:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    mainFrame.bannerTitle:SetJustifyH("LEFT")
    mainFrame.bannerTitle:SetWordWrap(false)

    mainFrame.bannerCurrently = banner:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mainFrame.bannerCurrently:SetPoint("TOPLEFT", banner, "TOPLEFT", 62, -44)
    mainFrame.bannerCurrently:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
    mainFrame.bannerCurrently:SetJustifyH("LEFT")
    mainFrame.bannerCurrently:SetWordWrap(false)

    -- Control Strip
    local controlBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    controlBar:SetHeight(38)
    controlBar:SetPoint("TOPLEFT", 12, -78)
    controlBar:SetPoint("TOPRIGHT", -12, -78)
    ns:ApplySurface(controlBar, M3.surface, M3.outline)
    ns:EnableClipping(controlBar)
    mainFrame.controlBar = controlBar

    local profPrevBtn = ns:CreateMaterialButton(controlBar, "<", 24, 26, 10, -6, nil, function() UI:CommitModifiedBoxesToProfile(false); ns:CycleProfile(-1) end)
    local profChip = ns:CreateMaterialButton(controlBar, "Profile", 110, 26, 37, -6, nil, function() UI:CommitModifiedBoxesToProfile(false); ns:CycleProfile(1) end)
    local profNextBtn = ns:CreateMaterialButton(controlBar, ">", 24, 26, 150, -6, nil, function() UI:CommitModifiedBoxesToProfile(false); ns:CycleProfile(1) end)
    mainFrame.profPrevBtn = profPrevBtn
    mainFrame.profChip = profChip
    mainFrame.profNextBtn = profNextBtn

    local icSwitch = CreateFrame("Button", nil, controlBar, "BackdropTemplate")
    icSwitch:SetSize(132, 26)
    ns:ApplySurface(icSwitch, M3.mintTonal, M3.mint)
    icSwitch.bgLabel = icSwitch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icSwitch.thumb = CreateFrame("Frame", nil, icSwitch, "BackdropTemplate")
    icSwitch.thumb:SetSize(88, 20)
    ns:ApplySurface(icSwitch.thumb, M3.mint, M3.outline)
    icSwitch.thumb.label = icSwitch.thumb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icSwitch.thumb.label:SetPoint("CENTER")
    icSwitch:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    icSwitch:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:ToggleICOOC()
        UI:RefreshHeaderBanner()
        ns:ShowStatusToast(ns.profile.isIC and "Switched to In-Character (IC)" or "Switched to Out-of-Character (OOC)")
    end)
    ns:RegisterFocusable(icSwitch, function() icSwitch:Click("LeftButton") end)
    mainFrame.icSwitch = icSwitch

    local walkUpBtn = ns:CreateMaterialButton(controlBar, "WALK-UPS: OPEN", 136, 26, 0, -6, "MINT", function()
        local code = ns:CycleWalkUpStatus()
        UI:RefreshHeaderBanner()
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

    for i, item in ipairs(UI.RP_EXPERIENCE_LIST) do
        local optBtn = ns:CreateMaterialButton(expDropdown, "", 182, 26, 7, -8 - (i - 1) * 30, nil, function()
            UI:ApplyRPExperienceSelection(item.code)
            expDropdown:Hide()
            if mainFrame.bannerExpBtn then ns:SetControllerFocus(mainFrame.bannerExpBtn) end
        end)
        optBtn.label:SetJustifyH("LEFT")
        expDropdown.rows[i] = optBtn
    end

    expDropdown.Rebuild = function(self)
        local curCode = tostring((ns.profile and ns.profile.rpStyle) or "1")
        for i, item in ipairs(UI.RP_EXPERIENCE_LIST) do
            local r = self.rows[i]
            local isSel = (item.code == curCode)
            r:SetText((isSel and "|cff81c995> |r" or "  ") .. item.label)
            r:SetTone(isSel and "PRIMARY" or nil)
        end
    end
    mainFrame.expDropdown = expDropdown

    local bannerExpBtn = ns:CreateMaterialButton(controlBar, "|cff8ab4f8RP:|r Normal [v]", 122, 26, 0, -6, nil, function(self)
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

    -- Left Sidebar Rail
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetWidth(UI.SIDEBAR_WIDTH)
    sidebar:SetPoint("TOPLEFT", 12, -122)
    sidebar:SetPoint("BOTTOMLEFT", 12, 42)
    ns:ApplySurface(sidebar, M3.surfaceLow, M3.outline)
    ns:EnableClipping(sidebar)
    mainFrame.sidebar = sidebar

    local sbHeader = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sbHeader:SetPoint("TOPLEFT", 10, -9)
    sbHeader:SetPoint("TOPRIGHT", -10, -9)
    sbHeader:SetJustifyH("CENTER")
    mainFrame.sbHeader = sbHeader

    local tabTitles = {
        "Identity",
        "First Glances",
        "Bio & Lore",
        "Directory",
        "Profiles",
        "Gratitude",
        "Settings",
        "Dev Console",
        "Emotes & Wheel",
    }

    for i, title in ipairs(tabTitles) do
        local tb = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        tb:SetSize(UI.SIDEBAR_WIDTH - 14, 30)
        tb:SetPoint("TOPLEFT", 7, -28 - (i - 1) * 34)
        ns:ApplySurface(tb, M3.surfaceLow, { 0, 0, 0, 0 })
        ns:EnableClipping(tb)
        tb.isTabBarBtn = true

        tb.activeBar = tb:CreateTexture(nil, "OVERLAY")
        tb.activeBar:SetWidth(3)
        tb.activeBar:SetPoint("TOPLEFT", 2, -5)
        tb.activeBar:SetPoint("BOTTOMLEFT", 2, 5)
        tb.activeBar:Hide()

        tb.label = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tb.label:SetPoint("LEFT", 12, 0)
        tb.label:SetPoint("RIGHT", -6, 0)
        tb.label:SetJustifyH("LEFT")
        tb.label:SetWordWrap(false)
        tb.label:SetText(title)

        tb:SetScript("OnClick", function() ns:PlayUISound(); ns:SelectTab(i) end)
        UI.tabButtons[i] = tb

        local panel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
        panel:SetPoint("BOTTOMRIGHT", -12, 42)
        ns:ApplySurface(panel, M3.surfaceLow, M3.outline)
        ns:EnableClipping(panel)
        panel:Hide()
        UI.tabPanels[i] = panel
    end

    for tabIdx, mod in pairs(UI.tabs) do
        if mod and type(mod.Build) == "function" and UI.tabPanels[tabIdx] then
            mod.Build(UI.tabPanels[tabIdx], picker)
        end
    end

    -- Footer & Resize Grip
    local footer = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    footer:SetHeight(26)
    footer:SetPoint("BOTTOMLEFT", 12, 10)
    footer:SetPoint("BOTTOMRIGHT", -38, 10)
    ns:ApplySurface(footer, M3.surfaceLow, M3.outline)
    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerText:SetPoint("LEFT", 14, 0)
    mainFrame.footerText = footerText
    mainFrame.statusToast = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.statusToast:SetPoint("RIGHT", -14, 0)
    mainFrame.statusToast:SetText("|cff9aa0a6Saved in PadRPDB|r")

    local resizeGrip = CreateFrame("Button", "PadRP_ResizeGrip", mainFrame, "BackdropTemplate")
    resizeGrip:SetSize(22, 26)
    resizeGrip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -12, 10)
    ns:ApplySurface(resizeGrip, M3.surfaceHigh, M3.outline)
    local gripLabel = resizeGrip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gripLabel:SetPoint("CENTER", 0, 0)
    gripLabel:SetText("//")
    resizeGrip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then mainFrame:StartSizing("BOTTOMRIGHT") end end)
    resizeGrip:SetScript("OnMouseUp", function() mainFrame:StopMovingOrSizing(); ns:RefreshControllerUI() end)

    RefreshShellThemeAccents()
    ns:LoadProfileIntoUI()
    ns:SelectTab(1)

    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        ConsolePort:AddInterfaceCursorFrame("PadRP_MainFrame")
    end
end