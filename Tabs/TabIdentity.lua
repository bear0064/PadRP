local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[1] = mod

local function AutoCommitTab1()
    UI:CommitModifiedBoxesToProfile(false)
    if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
    UI:RefreshEyeSwatchBox()
    UI:RefreshClassSwatchBox()
    ns:ShowStatusToast("Saved character vitals to PadRPDB")
end

function mod.Build(p1, picker)
    local mf = UI.mainFrame
    local M3 = ns.M3

    p1.subTabCore = ns:CreateMaterialButton(p1, "1. Core", 180, 26, 16, -12, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(false)
        if mf and mf.presetDropdown then mf.presetDropdown:Hide() end
        if mf and mf.expDropdown then mf.expDropdown:Hide() end
        UI.activeIdentityPage = 1
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p1.subTabVitals = ns:CreateMaterialButton(p1, "2. Details", 180, 26, 204, -12, nil, function()
        UI:CommitModifiedBoxesToProfile(false)
        if mf and mf.presetDropdown then mf.presetDropdown:Hide() end
        if mf and mf.expDropdown then mf.expDropdown:Hide() end
        UI.activeIdentityPage = 2
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p1.subTabExtras = ns:CreateMaterialButton(p1, "3. Extras / RP Options", 200, 26, 392, -12, nil, function()
        UI:CommitModifiedBoxesToProfile(false)
        if mf and mf.presetDropdown then mf.presetDropdown:Hide() end
        if mf and mf.expDropdown then mf.expDropdown:Hide() end
        UI.activeIdentityPage = 3
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)

    -- Sub-page 1: Core Identity
    local pageCore = CreateFrame("Frame", nil, p1)
    pageCore:SetPoint("TOPLEFT", 0, -42)
    pageCore:SetPoint("BOTTOMRIGHT", 0, 52)
    p1.pageCore = pageCore

    p1.pxBox = ns:CreateMaterialEditBox(pageCore, "Prefix", "e.g., Sir / Sister", 16, -6, 90, 28, AutoCommitTab1)
    p1.fnBox = ns:CreateMaterialEditBox(pageCore, "First Name", "e.g., Malachar", 116, -6, 136, 28, AutoCommitTab1)
    p1.lnBox = ns:CreateMaterialEditBox(pageCore, "Last Name", "e.g., Gray", 262, -6, 136, 28, AutoCommitTab1)
    p1.tiBox = ns:CreateMaterialEditBox(pageCore, "Full RP Title", "e.g., Master Arcanist", 408, -6, 180, 28, AutoCommitTab1)

    p1.raBox = ns:CreateMaterialEditBox(pageCore, "RP Race (Blank = Default)", "e.g., Human", 16, -60, 176, 28, AutoCommitTab1)
    p1.clBox = ns:CreateMaterialEditBox(pageCore, "RP Class / Occupation", "e.g., Warlock", 202, -60, 156, 28, AutoCommitTab1)
    p1.classSwatchBtn = UI:CreateColorSwatchButton(pageCore, 366, -75, "CLASS", function()
        ns.profile.classColorHex = nil
        ns.profile.nameColorHex = nil
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        UI:RefreshClassSwatchBox()
        if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
        UI:SyncSelfProfileToLocalCache()
        if ns.RefreshTargetCard then ns:RefreshTargetCard() end
        ns:ShowStatusToast("Class & Name color reset to default")
    end)
    p1.prBox = ns:CreateMaterialEditBox(pageCore, "Pronouns", "e.g., He/Him", 404, -60, 184, 28, AutoCommitTab1)

    p1.cuBox = ns:CreateMaterialEditBox(pageCore, "Currently (Select Preset, Cycle, or Type Custom)", "What is your character doing right now?", 16, -116, 290, 28, AutoCommitTab1)
    p1.presetBtn = ns:CreateMaterialButton(pageCore, "Presets [v]", 82, 28, 312, -131, "AMBER", function()
        if mf and mf.expDropdown then mf.expDropdown:Hide() end
        if mf and mf.presetDropdown:IsShown() then
            mf.presetDropdown:Hide()
            ns:SetControllerFocus(p1.presetBtn)
        elseif mf and mf.presetDropdown then
            mf.presetDropdown.page = 1
            mf.presetDropdown:Rebuild()
            mf.presetDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p1.cycleCuBtn = ns:CreateMaterialButton(pageCore, "Cycle", 58, 28, 400, -131, "PRIMARY", function()
        if ns.CycleCurrentlyPreset then ns:CycleCurrentlyPreset() end
        p1.cuBox:SetCleanText((ns.profile and ns.profile.currently) or "")
        UI:SyncSelfProfileToLocalCache()
        ns:ShowStatusToast("Cycled Currently status")
    end)
    p1.savePresetBtn = ns:CreateMaterialButton(pageCore, "+ Save", 60, 28, 464, -131, "MINT", function()
        local customTxt = strtrim(p1.cuBox:GetText() or "")
        if customTxt == "" or not ns.db then return end
        ns.db.currentlyPresets = ns.db.currentlyPresets or {}
        for _, existing in ipairs(ns.db.currentlyPresets) do
            if existing == customTxt then ns:ShowStatusToast("Preset already in list!"); return end
        end
        table.insert(ns.db.currentlyPresets, customTxt)
        ns.profile.currently = customTxt
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        UI:SyncSelfProfileToLocalCache()
        if mf and mf.presetDropdown and mf.presetDropdown:IsShown() then mf.presetDropdown:Rebuild() end
        ns:ShowStatusToast("Added new Currently preset!")
    end)
    p1.clearCuBtn = ns:CreateMaterialButton(pageCore, "Clear", 54, 28, 530, -131, nil, function()
        p1.cuBox:SetCleanText("")
        ns.profile.currently = ""
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        UI:SyncSelfProfileToLocalCache()
        ns:ShowStatusToast("Cleared Currently status")
    end)

    p1.oocNotesBox = ns:CreateScrollableTextEditor(
        pageCore,
        "Add spaced notes, paragraphs, or RP boundaries...",
        16, -188, 572, 84,
        AutoCommitTab1
    )

    p1.oocNotesLabel = pageCore:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p1.oocNotesLabel:SetPoint("BOTTOMLEFT", p1.oocNotesBox, "TOPLEFT", 0, 3)
    p1.oocNotesLabel:SetJustifyH("LEFT")
    p1.oocNotesLabel:SetWordWrap(false)
    p1.oocNotesLabel:SetText("|cff9aa0a6Other Information (OOC)|r")

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
        local presets = (ns.db and ns.db.currentlyPresets) or {}
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
                    if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
                    if ns.SyncMSP then ns:SyncMSP() end
                    UI:SyncSelfProfileToLocalCache()
                    dropdown:Hide()
                    ns:SetControllerFocus(p1.presetBtn)
                end)
                r.selectBtn.label:SetJustifyH("LEFT")
                UI:AttachWheelScroller(r.selectBtn, function(step)
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
                UI:AttachWheelScroller(r.delBtn, function(step)
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
    UI:AttachWheelScroller(dropdown, function(step)
        dropdown.page = dropdown.page + step
        dropdown:Rebuild()
    end)
    if mf then mf.presetDropdown = dropdown end

    -- Sub-page 2: Details & Vitals
    local pageVitals = CreateFrame("Frame", nil, p1)
    pageVitals:SetPoint("TOPLEFT", 0, -42)
    pageVitals:SetPoint("BOTTOMRIGHT", 0, 52)
    pageVitals:Hide()
    p1.pageVitals = pageVitals

    p1.hoBox = ns:CreateMaterialEditBox(pageVitals, "House / Clan / Guild Name", "e.g., House Gray", 16, -6, 280, 26, AutoCommitTab1)
    p1.moBox = ns:CreateMaterialEditBox(pageVitals, "Motto / Catchphrase", "e.g., It isn't fraud if they're impressed.", 308, -6, 280, 26, AutoCommitTab1)

    p1.gnBox = ns:CreateMaterialEditBox(pageVitals, "Gender", "e.g., Male", 16, -54, 120, 26, AutoCommitTab1)
    p1.agBox = ns:CreateMaterialEditBox(pageVitals, "Age", "e.g., 32", 146, -54, 100, 26, AutoCommitTab1)
    p1.htBox = ns:CreateMaterialEditBox(pageVitals, "Height", "e.g., 6'0\" / Tall", 256, -54, 150, 26, AutoCommitTab1)
    p1.wtBox = ns:CreateMaterialEditBox(pageVitals, "Build / Body Shape", "e.g., Athletic", 416, -54, 172, 26, AutoCommitTab1)

    p1.eyBox = ns:CreateMaterialEditBox(pageVitals, "Eye Color", "e.g., Pale amber / Luminous", 16, -102, 396, 26, AutoCommitTab1)
    p1.eyeSwatchBtn = UI:CreateColorSwatchButton(pageVitals, 420, -117, "EYE", function()
        ns.profile.eyeColorHex = nil
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        UI:RefreshEyeSwatchBox()
        UI:SyncSelfProfileToLocalCache()
        ns:ShowStatusToast("Eye color swatch cleared")
    end)

    local portraitPickBtn = ns:CreateMaterialButton(pageVitals, "Portrait", 140, 26, 456, -117, nil, function(self)
        if picker then picker:OpenForPortrait(self) end
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

    p1.faceBox = ns:CreateMaterialEditBox(pageVitals, "Facial Features", "e.g., Sharp smirk, manicured beard", 16, -148, 184, 26, AutoCommitTab1)
    p1.tatBox = ns:CreateMaterialEditBox(pageVitals, "Tattoos / Markings", "e.g., Arcane sigil on left forearm", 210, -148, 184, 26, AutoCommitTab1)
    p1.voiceBox = ns:CreateMaterialEditBox(pageVitals, "Voice Reference", "e.g., Calm, measured cadence", 404, -148, 184, 26, AutoCommitTab1)

    p1.hbBox = ns:CreateMaterialEditBox(pageVitals, "Birthplace", "e.g., Lordaeron (Allegedly)", 16, -194, 280, 26, AutoCommitTab1)
    p1.hhBox = ns:CreateMaterialEditBox(pageVitals, "Residence", "e.g., The Mage Quarter, Stormwind", 308, -194, 280, 26, AutoCommitTab1)

    -- Sub-page 3: Extras & RP Options
    local pageExtras = CreateFrame("Frame", nil, p1)
    pageExtras:SetPoint("TOPLEFT", 0, -42)
    pageExtras:SetPoint("BOTTOMRIGHT", 0, 52)
    pageExtras:Hide()
    p1.pageExtras = pageExtras

    p1.relBtn = ns:CreateMaterialButton(pageExtras, "Relationship: Not Specified", 280, 26, 16, -22, "AMBER", function()
        local code = ns:CycleRelationshipStatus()
        ns:RefreshControllerUI()
        ns:ShowStatusToast("Relationship: " .. ns:GetRelationshipLabel(code))
    end)
    p1.styleBtn = ns:CreateMaterialButton(pageExtras, "RP Style: Normal", 280, 26, 308, -22, "PRIMARY", function()
        local cur = tostring((ns.profile and ns.profile.rpStyle) or "1")
        local nextIdx = 1
        for idx, item in ipairs(UI.RP_EXPERIENCE_LIST) do
            if item.code == cur then
                nextIdx = (idx % #UI.RP_EXPERIENCE_LIST) + 1
                break
            end
        end
        UI:ApplyRPExperienceSelection(UI.RP_EXPERIENCE_LIST[nextIdx].code)
        ns:RefreshControllerUI()
    end)

    p1.topicBtns = {}
    for idx, t in ipairs(UI.RP_STYLE_TOPICS) do
        local rowIdx = (idx <= 3) and 0 or 1
        local colIdx = (idx - 1) % 3
        local btnX = 16 + colIdx * 194
        local btnY = -68 - rowIdx * 36
        local tBtn = ns:CreateMaterialButton(pageExtras, "", 186, 26, btnX, btnY, nil, function(self)
            local updated = UI:CycleTopicConsent(t.key, t.defaultVal)
            self:SetText(UI:FormatTopicButtonText(t.label, updated))
            if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
            ns:ShowStatusToast(t.label .. ": " .. updated)
        end)
        tBtn.label:SetJustifyH("LEFT")
        p1.topicBtns[t.key] = tBtn
    end

    p1.lgbtqBtn = ns:CreateMaterialButton(pageExtras, "", 280, 26, 16, -148, "MINT", function()
        ns.profile.lgbtqFriendly = not (ns.profile.lgbtqFriendly ~= false)
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        ns:RefreshControllerUI()
    end)
    p1.erpBtn = ns:CreateMaterialButton(pageExtras, "", 280, 26, 308, -148, nil, function()
        ns.profile.erpFriendly = not (ns.profile.erpFriendly and true or false)
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        ns:RefreshControllerUI()
    end)
    p1.mdniBtn = ns:CreateMaterialButton(pageExtras, "", 280, 26, 16, -182, nil, function()
        ns.profile.mdni = not (ns.profile.mdni and true or false)
        if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
        if ns.SyncMSP then ns:SyncMSP() end
        ns:RefreshControllerUI()
    end)

    local saveIdentityBtn = ns:CreateMaterialButton(p1, "Save Profile", 420, 36, 16, -354, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(true)
        if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
        ns:ShowStatusToast("Profile permanently saved & synced!")
    end)
    saveIdentityBtn:ClearAllPoints()
    saveIdentityBtn:SetPoint("BOTTOMLEFT", p1, "BOTTOMLEFT", 16, 14)
    saveIdentityBtn:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", -168, 14)

    local revertBtn = ns:CreateMaterialButton(p1, "Revert Unsaved", 144, 36, 0, 0, nil, function()
        ns:LoadProfileIntoUI()
        if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
    end)
    revertBtn:ClearAllPoints()
    revertBtn:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", -16, 14)
end

function mod.Layout(p1)
    if not p1 or not p1.subTabCore then return end
    UI:LayoutRow(p1, -12, {
        { w = p1.subTabCore,   weight = 1 },
        { w = p1.subTabVitals, weight = 1 },
        { w = p1.subTabExtras, weight = 1.15 },
    }, 16, 16, 8)

    local pc = p1.pageCore
    if pc then
        UI:LayoutRow(pc, -22, {
            { w = p1.pxBox, weight = 0.16 },
            { w = p1.fnBox, weight = 0.25 },
            { w = p1.lnBox, weight = 0.25 },
            { w = p1.tiBox, weight = 0.34 },
        }, 16, 16, 10)

        UI:LayoutRow(pc, -76, {
            { w = p1.raBox,          weight = 0.32 },
            { w = p1.clBox,          weight = 0.36 },
            { w = p1.classSwatchBtn, fixed = 28 },
            { w = p1.prBox,          weight = 0.32 },
        }, 16, 16, 8)

        UI:LayoutRow(pc, -132, {
            { w = p1.cuBox,         weight = 1 },
            { w = p1.presetBtn,     fixed = 82 },
            { w = p1.cycleCuBtn,    fixed = 58 },
            { w = p1.savePresetBtn, fixed = 60 },
            { w = p1.clearCuBtn,    fixed = 54 },
        }, 16, 16, 6)

        if p1.oocNotesBox then
            local curH = p1.oocNotesBox:GetHeight() or 84
            UI:LayoutRow(pc, -192, {
                { w = p1.oocNotesBox, weight = 1 },
            }, 16, 16, 0)
            p1.oocNotesBox:SetHeight(curH)
        end
    end

    local pv = p1.pageVitals
    if pv then
        UI:LayoutRow(pv, -20, {
            { w = p1.hoBox, weight = 0.50 },
            { w = p1.moBox, weight = 0.50 },
        }, 16, 16, 10)

        UI:LayoutRow(pv, -68, {
            { w = p1.gnBox, weight = 0.22 },
            { w = p1.agBox, weight = 0.18 },
            { w = p1.htBox, weight = 0.28 },
            { w = p1.wtBox, weight = 0.32 },
        }, 16, 16, 10)

        UI:LayoutRow(pv, -116, {
            { w = p1.eyBox,           weight = 1 },
            { w = p1.eyeSwatchBtn,    fixed = 28 },
            { w = p1.portraitPickBtn, fixed = 140 },
        }, 16, 16, 8)

        UI:LayoutRow(pv, -162, {
            { w = p1.faceBox,  weight = 0.34 },
            { w = p1.tatBox,   weight = 0.33 },
            { w = p1.voiceBox, weight = 0.33 },
        }, 16, 16, 10)

        UI:LayoutRow(pv, -208, {
            { w = p1.hbBox, weight = 1 },
            { w = p1.hhBox, weight = 1 },
        }, 16, 16, 10)
    end

    local pe = p1.pageExtras
    if pe then
        UI:LayoutRow(pe, -22, {
            { w = p1.relBtn,   weight = 1 },
            { w = p1.styleBtn, weight = 1 },
        }, 16, 16, 10)

        if p1.topicBtns then
            UI:LayoutRow(pe, -68, {
                { w = p1.topicBtns.injury,  weight = 1 },
                { w = p1.topicBtns.death,   weight = 1 },
                { w = p1.topicBtns.romance, weight = 1 },
            }, 16, 16, 8)

            UI:LayoutRow(pe, -104, {
                { w = p1.topicBtns.criminal,      weight = 1 },
                { w = p1.topicBtns.lossOfControl, weight = 1 },
                { w = p1.topicBtns.guild,         weight = 1 },
            }, 16, 16, 8)
        end

        UI:LayoutRow(pe, -148, {
            { w = p1.lgbtqBtn, weight = 1 },
            { w = p1.erpBtn,   weight = 1 },
        }, 16, 16, 8)

        if p1.mdniBtn then
            UI:LayoutRow(pe, -182, {
                { w = p1.mdniBtn, weight = 1 },
            }, 16, 16, 8)
        end
    end
end

function mod.Refresh(p1)
    if not p1 or not ns.profile then return end
    local p = ns.profile
    UI:EnsureTopicConsentTable()

    local page = UI.activeIdentityPage or 1
    p1.subTabCore:SetTone(page == 1 and "PRIMARY" or nil)
    p1.subTabVitals:SetTone(page == 2 and "PRIMARY" or nil)
    p1.subTabExtras:SetTone(page == 3 and "PRIMARY" or nil)
    p1.pageCore:SetShown(page == 1)
    p1.pageVitals:SetShown(page == 2)
    p1.pageExtras:SetShown(page == 3)

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

    UI:RefreshEyeSwatchBox()
    UI:RefreshClassSwatchBox()

    SyncBox(p1.hoBox, p.houseName)
    SyncBox(p1.moBox, p.motto)
    SyncBox(p1.hbBox, p.birthplace)
    SyncBox(p1.hhBox, p.residence)
    SyncBox(p1.faceBox, p.facialFeatures)
    SyncBox(p1.tatBox, p.tattoos)
    SyncBox(p1.voiceBox, p.voiceReference)

    p1.relBtn:SetText("Relationship: |cfffdd663" .. ns:GetRelationshipLabel(p.relationship) .. "|r")
    p1.styleBtn:SetText("RP Style: |cff8ab4f8" .. UI:GetRPExperienceLabelText(p.rpStyle) .. "|r")

    local fallbackIcon = UI:GetDefaultIconFallback()
    if p1.portraitPickBtn then
        UI:SetIconTextureSafe(p1.portraitPickBtn.iconTex, p.icon, fallbackIcon)
        p1.portraitPickBtn:SetText("Portrait")
    end

    if p1.topicBtns then
        for _, t in ipairs(UI.RP_STYLE_TOPICS) do
            local btn = p1.topicBtns[t.key]
            if btn then
                local curVal = UI:GetTopicConsentValue(t.key, t.defaultVal)
                btn:SetText(UI:FormatTopicButtonText(t.label, curVal))
            end
        end
    end

    if p1.lgbtqBtn then
        p1.lgbtqBtn:SetText(UI:FormatCheckbox("LGBTQIA2S+ Friendly", p.lgbtqFriendly ~= false, "ff81c995"))
        p1.lgbtqBtn:SetTone(p.lgbtqFriendly ~= false and "MINT" or nil)
    end
    if p1.erpBtn then
        p1.erpBtn:SetText(UI:FormatCheckbox("ERP Friendly", p.erpFriendly and true or false, "fffdd663"))
        p1.erpBtn:SetTone(p.erpFriendly and "AMBER" or nil)
    end
    if p1.mdniBtn then
        p1.mdniBtn:SetText(UI:FormatCheckbox("MDNI (Minors Do Not Interact)", p.mdni and true or false, "fff28b82"))
        p1.mdniBtn:SetTone(p.mdni and "CORAL" or nil)
    end
end