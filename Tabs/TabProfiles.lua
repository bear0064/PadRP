local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[5] = mod

local function RefreshProfilesList(pProf)
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
    UI.profileListPage = math.max(1, math.min(totalPages, UI.profileListPage or 1))
    pProf.pageLabel:SetText(string.format("Page %d / %d", UI.profileListPage, totalPages))

    local startIdx = (UI.profileListPage - 1) * perPage
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

function mod.Build(pProf)
    local profHeader = pProf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profHeader:SetPoint("TOPLEFT", 16, -10)
    profHeader:SetText("|cff8ab4f8PROFILE MANAGER|r  -  Switch, create, rename, or delete saved profiles")

    pProf.profNameBox = ns:CreateMaterialEditBox(pProf, "Active Profile Name", "e.g., Main Character", 16, -42, 240, 26, function()
        UI:CommitModifiedBoxesToProfile(false)
        if UI.RefreshHeaderBanner then UI:RefreshHeaderBanner() end
        RefreshProfilesList(pProf)
    end)

    pProf.newProfBtn = ns:CreateMaterialButton(pProf, "+ New Profile", 136, 26, 264, -42, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(false)
        if ns.CreateNewProfile then ns:CreateNewProfile() end
        RefreshProfilesList(pProf)
    end)

    pProf.delProfBtn = ns:CreateMaterialButton(pProf, "Delete Active Profile", 152, 26, 408, -42, "CORAL", function(self)
        local now = GetTime()
        if now < (UI.confirmDeleteProfileUntil or 0) then
            UI.confirmDeleteProfileUntil = 0
            self:SetText("Delete Active Profile")
            if ns.DeleteCurrentProfile then ns:DeleteCurrentProfile() end
            RefreshProfilesList(pProf)
        else
            UI.confirmDeleteProfileUntil = now + 4
            self:SetText("|cfff28b82Confirm Delete?|r")
        end
    end)

    pProf.exportBtn = ns:CreateMaterialButton(pProf, "Export / Import Profile String", 260, 26, 16, -80, "AMBER", function()
        UI:CommitModifiedBoxesToProfile(false)
        local p7 = UI.tabPanels[7]
        if p7 and p7.openExpBtn then
            p7.openExpBtn:Click("LeftButton")
        end
    end)

    pProf.prevBtn = ns:CreateMaterialButton(pProf, "< Prev", 58, 26, 286, -80, nil, function()
        UI.profileListPage = math.max(1, (UI.profileListPage or 1) - 1)
        RefreshProfilesList(pProf)
    end)

    pProf.pageLabel = pProf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pProf.pageLabel:SetJustifyH("CENTER")

    pProf.nextBtn = ns:CreateMaterialButton(pProf, "Next >", 58, 26, 430, -80, nil, function()
        UI.profileListPage = (UI.profileListPage or 1) + 1
        RefreshProfilesList(pProf)
    end)

    pProf.rows = {}
    for i = 1, 6 do
        local row = {}
        row.selectBtn = ns:CreateMaterialButton(pProf, "", 572, 32, 16, -116 - (i - 1) * 38, nil, function(btn)
            if btn.profileId and ns.SwitchProfile then
                UI:CommitModifiedBoxesToProfile(false)
                ns:SwitchProfile(btn.profileId)
                RefreshProfilesList(pProf)
                ns:ShowStatusToast("Switched to profile: " .. ((ns.profile and ns.profile.profileName) or btn.profileId))
            end
        end)
        row.selectBtn:SetPoint("RIGHT", pProf, "RIGHT", -16, 0)
        row.selectBtn.label:SetJustifyH("LEFT")
        pProf.rows[i] = row
    end
end

function mod.Layout(pProf)
    if not pProf or not pProf.profNameBox then return end
    UI:LayoutRow(pProf, -42, {
        { w = pProf.profNameBox, weight = 1 },
        { w = pProf.newProfBtn,  fixed = 136 },
        { w = pProf.delProfBtn,  fixed = 152 },
    }, 16, 16, 8)

    UI:LayoutRow(pProf, -80, {
        { w = pProf.exportBtn, weight = 1 },
        { w = pProf.prevBtn,   fixed = 58 },
        { w = pProf.pageLabel, fixed = 74, yOffset = -6 },
        { w = pProf.nextBtn,   fixed = 58 },
    }, 16, 16, 8)
end

function mod.Refresh(pProf)
    if not pProf or not ns.profile then return end
    if pProf.profNameBox and not pProf.profNameBox:HasFocus() and not pProf.profNameBox.isDirty then
        pProf.profNameBox:SetCleanText(ns.profile.profileName)
    end
    RefreshProfilesList(pProf)
end