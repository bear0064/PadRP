local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[3] = mod

function mod.Build(p3)
    p3.appTabBtn = ns:CreateMaterialButton(p3, "1. Physical Appearance & Attire", 220, 32, 16, -12, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(false)
        UI.activeBioMode = "APPEARANCE"
        if ns.profile and p3.bioEditor then
            p3.bioEditor:SetCleanText(ns.profile.description)
        end
        ns:RefreshControllerUI()
    end)

    p3.hisTabBtn = ns:CreateMaterialButton(p3, "2. Character History & Background", 220, 32, 244, -12, nil, function()
        UI:CommitModifiedBoxesToProfile(false)
        UI.activeBioMode = "HISTORY"
        if ns.profile and p3.bioEditor then
            p3.bioEditor:SetCleanText(ns.profile.history)
        end
        ns:RefreshControllerUI()
    end)

    p3.clearBioBtn = ns:CreateMaterialButton(p3, "Clear Text", 104, 32, 472, -12, "CORAL", function(self)
        local now = GetTime()
        if now < (UI.confirmClearBioUntil or 0) then
            UI.confirmClearBioUntil = 0
            self:SetText("Clear Text")
            p3.bioEditor:SetCleanText("")
            if ns.profile then
                if UI.activeBioMode == "APPEARANCE" then ns.profile.description = "" else ns.profile.history = "" end
            end
            if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
            if ns.SyncMSP then ns:SyncMSP() end
        else
            UI.confirmClearBioUntil = now + 4
            self:SetText("|cfff28b82Confirm?|r")
        end
    end)

    p3.sectionHint = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p3.sectionHint:SetPoint("TOPLEFT", 16, -52)

    p3.bioEditor = ns:CreateScrollableTextEditor(p3, "", 16, -72, 572, 268, function()
        UI:CommitModifiedBoxesToProfile(false)
    end)
    p3.bioEditor:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -16, 58)

    local saveBioBtn = ns:CreateMaterialButton(p3, "Save Physical Appearance & Character History", 572, 36, 16, -354, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(true)
        ns:ShowStatusToast("Appearance & History saved!")
    end)
    saveBioBtn:ClearAllPoints()
    saveBioBtn:SetPoint("BOTTOMLEFT", p3, "BOTTOMLEFT", 16, 14)
    saveBioBtn:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -16, 14)
end

function mod.Layout(p3)
    if not p3 or not p3.appTabBtn then return end
    UI:LayoutRow(p3, -12, {
        { w = p3.appTabBtn,   weight = 1 },
        { w = p3.hisTabBtn,   weight = 1 },
        { w = p3.clearBioBtn, fixed = 104 },
    }, 16, 16, 8)
end

function mod.Refresh(p3)
    if not p3 or not ns.profile then return end
    local p = ns.profile
    if (UI.activeBioMode or "APPEARANCE") == "APPEARANCE" then
        p3.appTabBtn:SetTone("PRIMARY")
        p3.hisTabBtn:SetTone(nil)
        p3.sectionHint:SetText("|cff8ab4f8PHYSICAL APPEARANCE:|r Describe your character's build, attire, voice, and demeanor.")
        p3.bioEditor:SetPlaceholder("Write your character's physical appearance here...")
        if not p3.bioEditor:HasFocus() and not p3.bioEditor.isDirty then
            p3.bioEditor:SetCleanText(p.description)
        end
    else
        p3.hisTabBtn:SetTone("PRIMARY")
        p3.appTabBtn:SetTone(nil)
        p3.sectionHint:SetText("|cff8ab4f8CHARACTER HISTORY & BACKGROUND:|r Write your character's origins, homeland, and story.")
        p3.bioEditor:SetPlaceholder("Write your character's backstory and history here...")
        if not p3.bioEditor:HasFocus() and not p3.bioEditor.isDirty then
            p3.bioEditor:SetCleanText(p.history)
        end
    end
end