local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[6] = mod

local function GetPools()
    return (ns.GratitudeConfig and ns.GratitudeConfig.pools) or {}
end

local function GetModes()
    return (ns.GratitudeConfig and ns.GratitudeConfig.modes) or {}
end

local function GetModeLabel(key)
    local labels = (ns.GratitudeConfig and ns.GratitudeConfig.modeLabels) or {}
    return labels[key] or tostring(key or "")
end

local function GetActiveGratitudePool()
    local g = ns.db and ns.db.gratitude
    if not g then return {} end
    local pools = GetPools()
    local item = pools[UI.editPoolIdx or 1] or pools[1]
    if item and item.field and type(g[item.field]) == "table" then
        return g[item.field]
    end
    return g.icPhrases
end

local function RefreshGratitudeStudio(p6)
    if not p6 or not ns.db or not ns.db.gratitude then return end
    local g = ns.db.gratitude
    g.mode = ns.NormalizeGratitudeMode and ns:NormalizeGratitudeMode(g.mode) or g.mode

    p6.modeBtn:SetText("|cff9aa0a6GRATITUDE MODE:|r   |cff8ab4f8" .. ns:GetGratitudeModeLabel() .. "|r   |cfffdd663[Open Dropdown v]|r")
    p6.buffBtn:SetText("Buffs: " .. (g.thankBuffs and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.healBtn:SetText("Heals: " .. (g.thankHeals and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.resBtn:SetText("Res: " .. (g.thankRes and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.specialBtn:SetText("Portals/CDs: " .. (g.thankSpecial and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p6.sessionBtn:SetText("1x/Session: " .. (g.oncePerSession and "|cff81c995ON|r" or "|cff9aa0a6OFF|r"))
    p6.cdLabel:SetText(string.format("Cooldown: |cfffdd663%ds|r", g.cooldown or 60))
    p6.healPctLabel:SetText(string.format("Min Heal: |cfffdd663%d%% HP|r", g.minHealPercent or 15))

    local pool = GetActiveGratitudePool()
    if type(pool) == "table" and #pool == 0 then
        table.insert(pool, "thanks %name for the %spell.")
    end
    local count = (type(pool) == "table") and #pool or 0
    local curIdx = UI.editPhraseIdx or 1
    if count > 0 then
        if curIdx > count then curIdx = count end
        if curIdx < 1 then curIdx = 1 end
    else
        curIdx = 1
    end
    UI.editPhraseIdx = curIdx

    local totalPages = math.max(1, math.ceil(math.max(1, count) / 3))
    UI.phrasePage = math.min(totalPages, math.ceil(curIdx / 3))

    local pools = GetPools()
    local poolItem = pools[UI.editPoolIdx or 1] or pools[1]
    local poolLabel = (poolItem and poolItem.label) or "Phrase Pool"
    p6.poolToggleBtn:SetText("|cff9aa0a6PHRASE POOL:|r  |cfffdd663" .. poolLabel .. "|r  |cff8ab4f8[v]|r")
    p6.phrasePageLabel:SetText(string.format("Page %d/%d (%d)", UI.phrasePage, totalPages, count))

    local startIdx = (UI.phrasePage - 1) * 3
    for i = 1, 3 do
        local actualIdx = startIdx + i
        local row = p6.phraseRows[i]
        local phraseStr = pool and pool[actualIdx]
        if phraseStr then
            row.phraseIndex = actualIdx
            local isSelected = (actualIdx == UI.editPhraseIdx)
            local prefix = isSelected and "|cff8ab4f8> " or "|cff9aa0a6  "
            row.selectBtn:SetText(string.format("%s#%d: |r%s", prefix, actualIdx, phraseStr))
            row.selectBtn:SetTone(isSelected and "PRIMARY" or nil)
            row.selectBtn:Show()
            row.delBtn:Show()
        else
            row.selectBtn:Hide()
            row.delBtn:Hide()
        end
    end

    if p6.phraseBox and not p6.phraseBox:HasFocus() then
        p6.phraseBox:SetCleanText((pool and pool[UI.editPhraseIdx]) or "")
    end
end

function mod.Build(p6)
    local mf = UI.mainFrame
    local M3 = ns.M3
    local modes = GetModes()
    local pools = GetPools()

    p6.modeBtn = ns:CreateMaterialButton(p6, "Gratitude Mode [v]", 572, 30, 16, -12, "PRIMARY", function()
        if mf and mf.expDropdown then mf.expDropdown:Hide() end
        if mf and mf.poolDropdown then mf.poolDropdown:Hide() end
        if mf and mf.modeDropdown and mf.modeDropdown:IsShown() then
            mf.modeDropdown:Hide()
            ns:SetControllerFocus(p6.modeBtn)
        elseif mf and mf.modeDropdown then
            mf.modeDropdown:Rebuild()
            mf.modeDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p6.modeBtn.label:SetJustifyH("LEFT")

    local modeDropdown = CreateFrame("Frame", nil, p6, "BackdropTemplate")
    modeDropdown:SetSize(572, 196)
    modeDropdown:SetPoint("TOPLEFT", p6.modeBtn, "BOTTOMLEFT", 0, -2)
    modeDropdown:SetFrameLevel(p6:GetFrameLevel() + 30)
    ns:ApplySurface(modeDropdown, M3.surfaceDim, M3.primary)
    ns:EnableClipping(modeDropdown)
    modeDropdown:EnableMouse(true)
    modeDropdown:Hide()
    modeDropdown.rows = {}
    for i, mKey in ipairs(modes) do
        local rowBtn = ns:CreateMaterialButton(modeDropdown, "", 556, 25, 8, -28 - (i - 1) * 27, nil, function()
            ns.db.gratitude.mode = mKey
            modeDropdown:Hide()
            RefreshGratitudeStudio(p6)
            ns:SetControllerFocus(p6.modeBtn)
        end)
        rowBtn.label:SetJustifyH("LEFT")
        modeDropdown.rows[i] = rowBtn
    end
    modeDropdown.Rebuild = function(self)
        local cur = ns.NormalizeGratitudeMode and ns:NormalizeGratitudeMode(ns.db and ns.db.gratitude and ns.db.gratitude.mode)
            or (ns.db and ns.db.gratitude and ns.db.gratitude.mode)
        for i, mKey in ipairs(modes) do
            local r = self.rows[i]
            local isCur = (mKey == cur)
            r:SetText((isCur and "|cff81c995[ACTIVE]  |r" or "          ") .. GetModeLabel(mKey))
            r:SetTone(isCur and "MINT" or nil)
        end
    end
    if mf then mf.modeDropdown = modeDropdown end

    p6.buffBtn = ns:CreateMaterialButton(p6, "Buffs", 108, 26, 16, -48, nil, function() ns.db.gratitude.thankBuffs = not ns.db.gratitude.thankBuffs; RefreshGratitudeStudio(p6) end)
    p6.healBtn = ns:CreateMaterialButton(p6, "Heals", 108, 26, 130, -48, nil, function() ns.db.gratitude.thankHeals = not ns.db.gratitude.thankHeals; RefreshGratitudeStudio(p6) end)
    p6.resBtn = ns:CreateMaterialButton(p6, "Res", 108, 26, 244, -48, nil, function() ns.db.gratitude.thankRes = not ns.db.gratitude.thankRes; RefreshGratitudeStudio(p6) end)
    p6.specialBtn = ns:CreateMaterialButton(p6, "Portals/CDs", 116, 26, 358, -48, nil, function() ns.db.gratitude.thankSpecial = not ns.db.gratitude.thankSpecial; RefreshGratitudeStudio(p6) end)
    p6.sessionBtn = ns:CreateMaterialButton(p6, "1x/Session", 108, 26, 480, -48, nil, function() ns.db.gratitude.oncePerSession = not ns.db.gratitude.oncePerSession; RefreshGratitudeStudio(p6) end)

    p6.cdMinusBtn = ns:CreateMaterialButton(p6, "-15s", 50, 24, 16, -80, nil, function() ns.db.gratitude.cooldown = math.max(15, (ns.db.gratitude.cooldown or 60) - 15); RefreshGratitudeStudio(p6) end)
    p6.cdLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.cdLabel:SetJustifyH("CENTER")
    p6.cdPlusBtn = ns:CreateMaterialButton(p6, "+15s", 50, 24, 175, -80, nil, function() ns.db.gratitude.cooldown = math.min(600, (ns.db.gratitude.cooldown or 60) + 15); RefreshGratitudeStudio(p6) end)

    p6.healMinusBtn = ns:CreateMaterialButton(p6, "-5%", 50, 24, 312, -80, nil, function() ns.db.gratitude.minHealPercent = math.max(1, (ns.db.gratitude.minHealPercent or 15) - 5); RefreshGratitudeStudio(p6) end)
    p6.healPctLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.healPctLabel:SetJustifyH("CENTER")
    p6.healPlusBtn = ns:CreateMaterialButton(p6, "+5%", 50, 24, 480, -80, nil, function() ns.db.gratitude.minHealPercent = math.min(80, (ns.db.gratitude.minHealPercent or 15) + 5); RefreshGratitudeStudio(p6) end)

    p6.poolToggleBtn = ns:CreateMaterialButton(p6, "Phrase Pool [v]", 310, 26, 16, -112, "AMBER", function()
        if mf and mf.expDropdown then mf.expDropdown:Hide() end
        if mf and mf.modeDropdown then mf.modeDropdown:Hide() end
        if mf and mf.poolDropdown and mf.poolDropdown:IsShown() then
            mf.poolDropdown:Hide()
            ns:SetControllerFocus(p6.poolToggleBtn)
        elseif mf and mf.poolDropdown then
            mf.poolDropdown:Rebuild()
            mf.poolDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p6.poolToggleBtn.label:SetJustifyH("LEFT")

    local poolDropdown = CreateFrame("Frame", nil, p6, "BackdropTemplate")
    poolDropdown:SetSize(440, 170)
    poolDropdown:SetPoint("TOPLEFT", p6.poolToggleBtn, "BOTTOMLEFT", 0, -2)
    poolDropdown:SetFrameLevel(p6:GetFrameLevel() + 30)
    ns:ApplySurface(poolDropdown, M3.surfaceDim, M3.amber)
    ns:EnableClipping(poolDropdown)
    poolDropdown:EnableMouse(true)
    poolDropdown:Hide()
    poolDropdown.rows = {}
    for i, item in ipairs(pools) do
        local rowBtn = ns:CreateMaterialButton(poolDropdown, "", 424, 25, 8, -28 - (i - 1) * 27, nil, function()
            UI.editPoolIdx, UI.editPhraseIdx = i, 1
            poolDropdown:Hide()
            RefreshGratitudeStudio(p6)
            ns:SetControllerFocus(p6.poolToggleBtn)
        end)
        rowBtn.label:SetJustifyH("LEFT")
        poolDropdown.rows[i] = rowBtn
    end
    poolDropdown.Rebuild = function(self)
        for i, item in ipairs(pools) do
            local r = self.rows[i]
            local isCur = (i == (UI.editPoolIdx or 1))
            r:SetText((isCur and "|cfffdd663[EDITING] |r" or "          ") .. item.label)
            r:SetTone(isCur and "AMBER" or nil)
        end
    end
    if mf then mf.poolDropdown = poolDropdown end

    p6.addPhraseBtn = ns:CreateMaterialButton(p6, "+ Add Phrase", 96, 26, 332, -112, "PRIMARY", function()
        local pool = GetActiveGratitudePool()
        table.insert(pool, "nods warmly to %name in thanks for the %spell.")
        UI.editPhraseIdx = #pool
        RefreshGratitudeStudio(p6)
    end)
    p6.prevPhraseBtn = ns:CreateMaterialButton(p6, "<", 28, 26, 434, -112, nil, function()
        UI.editPhraseIdx = math.max(1, (UI.editPhraseIdx or 1) - 3)
        RefreshGratitudeStudio(p6)
    end)
    p6.phrasePageLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.phrasePageLabel:SetJustifyH("CENTER")
    p6.nextPhraseBtn = ns:CreateMaterialButton(p6, ">", 28, 26, 558, -112, nil, function()
        local pool = GetActiveGratitudePool()
        UI.editPhraseIdx = math.min(#pool, (UI.editPhraseIdx or 1) + 3)
        RefreshGratitudeStudio(p6)
    end)

    local function StepPhrasePage(step)
        local pool = GetActiveGratitudePool()
        UI.editPhraseIdx = math.max(1, math.min(#pool, (UI.editPhraseIdx or 1) + (step * 3)))
        RefreshGratitudeStudio(p6)
    end
    UI:AttachWheelScroller(p6, StepPhrasePage)

    p6.phraseRows = {}
    for i = 1, 3 do
        local rowY = -144 - (i - 1) * 28
        local r = {}
        r.delBtn = ns:CreateMaterialButton(p6, "X", 32, 25, 0, 0, "CORAL", function()
            local pool = GetActiveGratitudePool()
            if #pool > 1 and r.phraseIndex and pool[r.phraseIndex] then
                table.remove(pool, r.phraseIndex)
                UI.editPhraseIdx = math.min(#pool, math.max(1, UI.editPhraseIdx or 1))
                RefreshGratitudeStudio(p6)
            end
        end)
        r.delBtn:ClearAllPoints()
        r.delBtn:SetPoint("TOPRIGHT", p6, "TOPRIGHT", -16, rowY)
        UI:AttachWheelScroller(r.delBtn, StepPhrasePage)

        r.selectBtn = ns:CreateMaterialButton(p6, "", 534, 25, 16, rowY, nil, function()
            if r.phraseIndex then
                UI.editPhraseIdx = r.phraseIndex
                RefreshGratitudeStudio(p6)
            end
        end)
        r.selectBtn:SetPoint("RIGHT", r.delBtn, "LEFT", -6, 0)
        r.selectBtn.label:SetJustifyH("LEFT")
        UI:AttachWheelScroller(r.selectBtn, StepPhrasePage)

        p6.phraseRows[i] = r
    end

    p6.phraseBox = ns:CreateMaterialEditBox(p6, "Edit Selected Phrase", "", 16, -234, 572, 30, function(txt)
        local pool = GetActiveGratitudePool()
        local trimmed = strtrim(txt or "")
        if trimmed ~= "" and pool then
            pool[UI.editPhraseIdx or 1] = trimmed
            RefreshGratitudeStudio(p6)
        end
    end)

    local tokens = {
        { label = "+ %name",     token = "%name" },
        { label = "+ %fullname", token = "%fullname" },
        { label = "+ %spell",    token = "%spell" },
        { label = "+ %class",    token = "%class" },
        { label = "+ %race",     token = "%race" },
    }
    p6.tokenBtns = {}
    for idx, tk in ipairs(tokens) do
        p6.tokenBtns[idx] = ns:CreateMaterialButton(p6, tk.label, 76, 26, 16 + (idx - 1) * 80, -286, nil, function()
            local cur = p6.phraseBox:GetText() or ""
            local sep = (cur ~= "" and string.sub(cur, -1) ~= " ") and " " or ""
            p6.phraseBox:SetCleanText(cur .. sep .. tk.token)
            local pool = GetActiveGratitudePool()
            if pool then pool[UI.editPhraseIdx or 1] = p6.phraseBox:GetText() end
            RefreshGratitudeStudio(p6)
        end)
    end

    p6.savePhraseBtn = ns:CreateMaterialButton(p6, "Save Phrase", 86, 26, 420, -286, "MINT", function()
        local txt = strtrim(p6.phraseBox:GetText() or "")
        local pool = GetActiveGratitudePool()
        if txt ~= "" and pool then
            pool[UI.editPhraseIdx or 1] = txt
            RefreshGratitudeStudio(p6)
        end
    end)

    p6.previewBtn = ns:CreateMaterialButton(p6, "Preview", 78, 26, 512, -286, "AMBER", function()
        local preview = ns:FormatTokens(p6.phraseBox:GetText(), UnitExists("target") and "target" or "player", "Mark of the Wild")
        if ns.LogNet then ns:LogNet("PREVIEW", "ff81c995", preview) end
        ns:ShowStatusToast("Preview: " .. preview)
    end)

    local quickThankBottom = ns:CreateMaterialButton(p6, "Trigger Quick-Thank Now (Target or Last Helper)", 572, 36, 16, -356, "PRIMARY", function()
        if ns.QuickThankAction then ns:QuickThankAction() end
    end)
    quickThankBottom:ClearAllPoints()
    quickThankBottom:SetPoint("BOTTOMLEFT", p6, "BOTTOMLEFT", 16, 14)
    quickThankBottom:SetPoint("BOTTOMRIGHT", p6, "BOTTOMRIGHT", -16, 14)
end

function mod.Layout(p6)
    if not p6 or not p6.modeBtn then return end
    UI:LayoutRow(p6, -12, {
        { w = p6.modeBtn, weight = 1 },
    }, 16, 16, 0)
    local mf = UI.mainFrame
    if mf and mf.modeDropdown then
        local mw = p6.modeBtn:GetWidth()
        if mw and mw > 200 then
            mf.modeDropdown:SetWidth(mw)
            for _, r in ipairs(mf.modeDropdown.rows or {}) do
                r:SetWidth(mw - 16)
            end
        end
    end

    UI:LayoutRow(p6, -48, {
        { w = p6.buffBtn,    weight = 1 },
        { w = p6.healBtn,    weight = 1 },
        { w = p6.resBtn,     weight = 1 },
        { w = p6.specialBtn, weight = 1.1 },
        { w = p6.sessionBtn, weight = 1 },
    }, 16, 16, 6)

    UI:LayoutRow(p6, -80, {
        { w = p6.cdMinusBtn,   fixed = 50 },
        { w = p6.cdLabel,      weight = 1, yOffset = -5 },
        { w = p6.cdPlusBtn,    fixed = 50 },
        { w = p6.healMinusBtn, fixed = 50 },
        { w = p6.healPctLabel, weight = 1, yOffset = -5 },
        { w = p6.healPlusBtn,  fixed = 50 },
    }, 16, 16, 8)

    UI:LayoutRow(p6, -112, {
        { w = p6.poolToggleBtn,   weight = 1 },
        { w = p6.addPhraseBtn,    fixed = 96 },
        { w = p6.prevPhraseBtn,   fixed = 28 },
        { w = p6.phrasePageLabel, fixed = 84, yOffset = -6 },
        { w = p6.nextPhraseBtn,   fixed = 28 },
    }, 16, 16, 6)

    UI:LayoutRow(p6, -249, {
        { w = p6.phraseBox, weight = 1 },
    }, 16, 16, 0)

    local tokRow = {}
    for _, tb in ipairs(p6.tokenBtns or {}) do
        table.insert(tokRow, { w = tb, weight = 1 })
    end
    table.insert(tokRow, { w = p6.savePhraseBtn, fixed = 86 })
    table.insert(tokRow, { w = p6.previewBtn,    fixed = 78 })
    UI:LayoutRow(p6, -286, tokRow, 16, 16, 6)
end

function mod.Refresh(p6)
    RefreshGratitudeStudio(p6)
end