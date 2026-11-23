local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[7] = mod

local STANDING_STYLE_ORDER = {
    { key = "CIRCLE",  label = "Circle" },
    { key = "STRIPE",  label = "Accent Stripe" },
    { key = "CHEVRON", label = "Chevron" },
    { key = "PILL",    label = "Pill Tag" },
    { key = "OFF",     label = "Off" },
}

local function GetStandingStyleLabel(styleKey)
    for _, item in ipairs(STANDING_STYLE_ORDER) do
        if item.key == styleKey then
            return item.label
        end
    end
    return "Circle"
end

local function CycleStandingStyle()
    local cur = (ns.GetNameplateStandingStyle and ns:GetNameplateStandingStyle()) or "CIRCLE"
    local nextIdx = 1
    for i, item in ipairs(STANDING_STYLE_ORDER) do
        if item.key == cur then
            nextIdx = (i % #STANDING_STYLE_ORDER) + 1
            break
        end
    end
    local chosen = STANDING_STYLE_ORDER[nextIdx]
    ns.db.ui.nameplateStandingStyle = chosen.key
    ns.db.ui.nameplateStandingCircle = (chosen.key ~= "OFF")
    return chosen
end

function mod.Build(p7)
    local mf = UI.mainFrame
    local M3 = ns.M3

    p7.scaleMinusBtn = ns:CreateMaterialButton(p7, "Scale -", 64, 28, 16, -14, nil, function()
        ns.db.ui.scale = math.max(0.8, (ns.db.ui.scale or 1.0) - 0.05)
        ns:RefreshControllerUI()
        if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    end)
    p7.scaleLabel = p7:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p7.scaleLabel:SetJustifyH("CENTER")
    p7.scalePlusBtn = ns:CreateMaterialButton(p7, "Scale +", 64, 28, 240, -14, nil, function()
        ns.db.ui.scale = math.min(1.3, (ns.db.ui.scale or 1.0) + 0.05)
        ns:RefreshControllerUI()
        if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    end)
    p7.stdSizeBtn = ns:CreateMaterialButton(p7, "Standard", 82, 28, 320, -14, nil, function() ns:SetWindowDimensions(760, 580) end)
    p7.wideSizeBtn = ns:CreateMaterialButton(p7, "Wide", 72, 28, 410, -14, "PRIMARY", function() ns:SetWindowDimensions(880, 620) end)
    p7.largeSizeBtn = ns:CreateMaterialButton(p7, "Large", 72, 28, 490, -14, "AMBER", function() ns:SetWindowDimensions(980, 700) end)

    p7.minimapBtn   = ns:CreateMaterialButton(p7, "", 280, 28, 16, -50, nil, function()
        ns.db.ui.showMinimap = not ns.db.ui.showMinimap
        if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
        ns:RefreshControllerUI()
    end)
    p7.hudBtn       = ns:CreateMaterialButton(p7, "", 280, 28, 308, -50, nil, function()
        ns.db.ui.showTargetHUD = not (ns.db.ui.showTargetHUD ~= false)
        ns:RefreshControllerUI()
        if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    end)

    p7.hudRPBtn     = ns:CreateMaterialButton(p7, "", 280, 28, 16, -84, nil, function()
        ns.db.ui.rpTooltip = not ns.db.ui.rpTooltip
        ns:RefreshControllerUI()
    end)
    p7.npClassBtn   = ns:CreateMaterialButton(p7, "", 280, 28, 308, -84, nil, function()
        ns.db.ui.nameplateClassColors = not ns.db.ui.nameplateClassColors
        if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
        ns:RefreshControllerUI()
    end)

    p7.npTagBtn     = ns:CreateMaterialButton(p7, "", 280, 28, 16, -118, nil, function()
        ns.db.ui.nameplateStatusTags = not (ns.db.ui.nameplateStatusTags ~= false)
        if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
        ns:RefreshControllerUI()
    end)
    p7.npRPNameBtn  = ns:CreateMaterialButton(p7, "", 280, 28, 308, -118, nil, function()
        ns.db.ui.nameplateRPNames = not ns.db.ui.nameplateRPNames
        if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
        ns:RefreshControllerUI()
    end)

    p7.npStyleBtn   = ns:CreateMaterialButton(p7, "", 280, 28, 16, -152, "AMBER", function()
        local chosen = CycleStandingStyle()
        if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
        ns:RefreshControllerUI()
        ns:ShowStatusToast("Nameplate Standing Style: " .. chosen.label)
    end)
    p7.npColorsBtn  = ns:CreateMaterialButton(p7, "", 280, 28, 308, -152, "PRIMARY", function()
        local cur = (ns.GetNameplateStandingColorMode and ns:GetNameplateStandingColorMode()) or "7COLOR"
        ns.db.ui.nameplateStandingColorMode = (cur == "7COLOR") and "4BUCKET" or "7COLOR"
        if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
        ns:RefreshControllerUI()
        ns:ShowStatusToast(ns.db.ui.nameplateStandingColorMode == "4BUCKET"
            and "Standing Colors: 4-Bucket Grouping"
            or "Standing Colors: All 7 Colors")
    end)

    p7.combatBtn    = ns:CreateMaterialButton(p7, "", 280, 28, 16, -186, nil, function()
        ns.db.ui.hideInCombat = not ns.db.ui.hideInCombat
        ns:RefreshControllerUI()
    end)
    p7.soundBtn     = ns:CreateMaterialButton(p7, "", 280, 28, 308, -186, nil, function()
        ns.db.ui.soundEffects = not ns.db.ui.soundEffects
        ns:RefreshControllerUI()
    end)

    p7.partyBtn     = ns:CreateMaterialButton(p7, "", 280, 28, 16, -220, nil, function()
        ns.db.gratitude.ignoreParty = not ns.db.gratitude.ignoreParty
        ns:RefreshControllerUI()
    end)
    p7.rpNameBtn    = ns:CreateMaterialButton(p7, "", 280, 28, 308, -220, nil, function()
        ns.db.gratitude.useRPNames = not ns.db.gratitude.useRPNames
        ns:RefreshControllerUI()
    end)

    p7.chatRPBtn    = ns:CreateMaterialButton(p7, "", 280, 28, 16, -254, nil, function()
        ns.db.ui.chatRPNames = not ns.db.ui.chatRPNames
        ns:RefreshControllerUI()
    end)
    p7.afkOOCBtn    = ns:CreateMaterialButton(p7, "", 280, 28, 308, -254, nil, function()
        ns.db.ui.autoAFKOOC = not ns.db.ui.autoAFKOOC
        ns:RefreshControllerUI()
    end)

    p7.openExpBtn = ns:CreateMaterialButton(p7, "Export / Import Profile String", 280, 30, 16, -294, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(false)
        if mf and mf.exportModal then
            mf.exportModal.box:SetCleanText(ns:ExportCurrentProfileString())
            mf.exportModal:Show()
            ns:FocusFirstInScope()
        end
    end)

    p7.devModeBtn = ns:CreateMaterialButton(p7, "", 280, 30, 308, -294, nil, function()
        ns.db.ui.devMode = not ns.db.ui.devMode
        ns:RefreshControllerUI()
        ns:ShowStatusToast(ns.db.ui.devMode and "Developer Mode enabled (Dev Console unlocked)" or "Developer Mode hidden")
    end)

    local expModal = CreateFrame("Frame", nil, p7, "BackdropTemplate")
    expModal:SetSize(540, 260)
    expModal:SetPoint("CENTER", p7, "CENTER", 0, 0)
    expModal:SetFrameLevel(p7:GetFrameLevel() + 30)
    ns:ApplySurface(expModal, M3.surfaceDim, M3.primary)
    ns:EnableClipping(expModal)
    expModal:EnableMouse(true)
    expModal:Hide()
    ns:CreateMaterialButton(expModal, "X", 28, 24, 500, -8, "CORAL", function() expModal:Hide(); ns:SetControllerFocus(p7.openExpBtn) end)
    expModal.box = ns:CreateScrollableTextEditor(expModal, "Paste a PADRP5~ or PADRP4~ profile string here...", 16, -40, 508, 165)
    ns:CreateMaterialButton(expModal, "Highlight String for Copy", 248, 30, 16, -216, "AMBER", function()
        expModal.box:SetCleanText(ns:ExportCurrentProfileString())
        expModal.box.editBox:HighlightText()
        expModal.box.editBox:SetFocus()
    end)
    ns:CreateMaterialButton(expModal, "Import String as New Profile", 248, 30, 276, -216, "MINT", function()
        local ok, msg = ns:ImportProfileString(strtrim(expModal.box:GetText() or ""))
        if ok then
            expModal:Hide()
            ns:SetControllerFocus(p7.openExpBtn)
            ns:ShowStatusToast("Imported: " .. msg)
        else
            ns:ShowStatusToast(msg or "Import failed")
        end
    end)
    if mf then mf.exportModal = expModal end
end

function mod.Layout(p7)
    if not p7 or not p7.minimapBtn then return end
    UI:LayoutRow(p7, -14, {
        { w = p7.scaleMinusBtn, fixed = 64 },
        { w = p7.scaleLabel,    weight = 1, yOffset = -7 },
        { w = p7.scalePlusBtn,  fixed = 64 },
        { w = p7.stdSizeBtn,    fixed = 82 },
        { w = p7.wideSizeBtn,   fixed = 72 },
        { w = p7.largeSizeBtn,  fixed = 72 },
    }, 16, 16, 6)

    local pairs7 = {
        { -50,  p7.minimapBtn, p7.hudBtn },
        { -84,  p7.hudRPBtn,   p7.npClassBtn },
        { -118, p7.npTagBtn,   p7.npRPNameBtn },
        { -152, p7.npStyleBtn, p7.npColorsBtn },
        { -186, p7.combatBtn,  p7.soundBtn },
        { -220, p7.partyBtn,   p7.rpNameBtn },
        { -254, p7.chatRPBtn,  p7.afkOOCBtn },
        { -294, p7.openExpBtn, p7.devModeBtn },
    }
    for _, row in ipairs(pairs7) do
        if row[3] then
            UI:LayoutRow(p7, row[1], {
                { w = row[2], weight = 1 },
                { w = row[3], weight = 1 },
            }, 16, 16, 12)
        else
            UI:LayoutRow(p7, row[1], {
                { w = row[2], weight = 1 },
            }, 16, 16, 12)
        end
    end
end

function mod.Refresh(p7)
    local mf = UI.mainFrame
    if not p7 or not mf or not ns.db or not ns.db.ui then return end
    local ui = ns.db.ui
    local grat = ns.db.gratitude or {}

    local curW, curH = math.floor(mf:GetWidth() + 0.5), math.floor(mf:GetHeight() + 0.5)
    p7.scaleLabel:SetText(string.format("Scale: |cfffdd663%.0f%%|r  (|cff8ab4f8%dx%d|r)", (ui.scale or 1.0) * 100, curW, curH))
    p7.minimapBtn:SetText(UI:FormatCheckbox("Minimap Icon", ui.showMinimap, "ff81c995"))
    p7.hudBtn:SetText(UI:FormatCheckbox("Toast Notification (Target HUD)", ui.showTargetHUD ~= false, "ff81c995"))
    p7.hudRPBtn:SetText(UI:FormatCheckbox("TRP3-Style Player Tooltip", ui.rpTooltip, "ff8ab4f8"))
    p7.npClassBtn:SetText(UI:FormatCheckbox("Class-Color Nameplates", ui.nameplateClassColors, "ff8ab4f8"))
    p7.npTagBtn:SetText(UI:FormatCheckbox("Nameplate OOC | IC", ui.nameplateStatusTags ~= false, "ff81c995"))
    p7.npRPNameBtn:SetText(UI:FormatCheckbox("RP Names on Nameplates", ui.nameplateRPNames, "ff8ab4f8"))

    local styleKey = (ns.GetNameplateStandingStyle and ns:GetNameplateStandingStyle()) or "CIRCLE"
    if p7.npStyleBtn then
        p7.npStyleBtn:SetText("Standing Style: |cfffdd663" .. GetStandingStyleLabel(styleKey) .. "|r")
        p7.npStyleBtn:SetTone(styleKey ~= "OFF" and "AMBER" or nil)
    end

    local colorMode = (ns.GetNameplateStandingColorMode and ns:GetNameplateStandingColorMode()) or "7COLOR"
    if p7.npColorsBtn then
        local modeLabel = (colorMode == "4BUCKET") and "|cff81c9954-Bucket Grouping|r" or "|cff8ab4f8All 7 Colors|r"
        p7.npColorsBtn:SetText("Standing Colors: " .. modeLabel)
        p7.npColorsBtn:SetTone(colorMode == "4BUCKET" and "MINT" or "PRIMARY")
    end

    p7.combatBtn:SetText(UI:FormatCheckbox("Auto-Hide in Combat", ui.hideInCombat, "ff81c995"))
    p7.soundBtn:SetText(UI:FormatCheckbox("UI Sound Effects", ui.soundEffects, "ff81c995"))
    p7.partyBtn:SetText(UI:FormatCheckbox("Ignore Party/Raid Buffs", grat.ignoreParty, "ff81c995"))
    p7.rpNameBtn:SetText(UI:FormatCheckbox("Thank Helper RP Name", grat.useRPNames, "ff81c995"))
    p7.chatRPBtn:SetText(UI:FormatCheckbox("Show [RP Names] in Chat", ui.chatRPNames, "ff81c995"))
    p7.afkOOCBtn:SetText(UI:FormatCheckbox("Auto-OOC When AFK", ui.autoAFKOOC, "ff81c995"))

    p7.devModeBtn:SetText(UI:FormatCheckbox("Developer Mode (Show Dev Tab)", ui.devMode, "fffdd663"))
    p7.devModeBtn:SetTone(ui.devMode and "AMBER" or nil)
end