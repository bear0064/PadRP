local _, ns = ...

local UI = ns.UI
local mod = {}
UI.tabs[2] = mod

function UI:LoadAllGlancesIntoUI()
    local p2 = UI.tabPanels[2]
    if not p2 or not p2.cards or not ns.profile then return end
    local p = ns.profile
    local fallbackIcon = UI:GetDefaultIconFallback()
    local placeholders = {
        { title = "e.g., Singed Cuffs",   detail = "e.g., Faint arcane scorch marks line the hems of his sleeves." },
        { title = "e.g., Worn Satchel",   detail = "e.g., Stuffed with rolled parchment, ink vials, and dried herbs." },
        { title = "e.g., Silver Signet",  detail = "e.g., A tarnished ring bearing an unfamiliar river-crest." },
        { title = "e.g., Steady Voice",   detail = "e.g., Speaks with a calm, measured cadence even under pressure." },
        { title = "e.g., Travel Cloak",   detail = "e.g., Weathered dark wool dusted with road ash from afar." },
    }

    p.glances = p.glances or {}
    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local g = p.glances[slot] or { icon = fallbackIcon, title = "", detail = "" }
            card.slotIndex = slot
            card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. slot .. "|r")
            UI:SetIconTextureSafe(card.iconTex, g.icon, fallbackIcon)
            card.titleBox.placeholder:SetText(placeholders[slot].title)
            card.detailBox.placeholder:SetText(placeholders[slot].detail)
            card.titleBox:SetCleanText(g.title)
            card.detailBox:SetCleanText(g.detail)
            card:Show()
        end
    end
end

function mod.Build(p2, picker)
    local M3 = ns.M3

    local gIntro = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gIntro:SetPoint("TOPLEFT", 16, -12)
    gIntro:SetPoint("TOPRIGHT", -16, -12)
    gIntro:SetJustifyH("LEFT")
    gIntro:SetText("|cff8ab4f8FIRST GLANCES (1 - 5)|r  |cff9aa0a6-  Scroll with D-Pad or wheel to edit all 5 slots; all broadcast to TRP3 / MRP / XRP|r")

    local glanceScroll = CreateFrame("ScrollFrame", "PadRP_GlancesScrollFrame", p2, "UIPanelScrollFrameTemplate")
    glanceScroll:SetPoint("TOPLEFT", 12, -32)
    glanceScroll:SetPoint("BOTTOMRIGHT", -28, 56)
    glanceScroll:EnableMouseWheel(true)
    ns:EnableClipping(glanceScroll)
    p2.glanceScroll = glanceScroll

    local glanceChild = CreateFrame("Frame", nil, glanceScroll)
    glanceChild:SetSize(540, 576)
    glanceScroll:SetScrollChild(glanceChild)
    p2.glanceChild = glanceChild

    local function IsFocusInsideGlanceScroll()
        local f = ns.currentFocus
        if not f then return false end
        if f.glanceScrollFrame == glanceScroll then return true end
        local parent = f.GetParent and f:GetParent()
        while parent do
            if parent == glanceChild or parent == glanceScroll then
                return true
            end
            parent = parent.GetParent and parent:GetParent()
        end
        return false
    end

    local function ClearGlanceFocusHighlight()
        local f = ns.currentFocus
        if not f then return end
        if ns.SetControllerFocus then
            ns:SetControllerFocus(nil)
        end
        if ns.currentFocus == f then
            if f.OnFocusChanged then
                pcall(f.OnFocusChanged, f, false)
            end
            local onLeave = f.GetScript and f:GetScript("OnLeave")
            if onLeave then
                pcall(onLeave, f)
            end
            if f.SetBackdropBorderColor and ns.M3 and ns.M3.outline then
                pcall(f.SetBackdropBorderColor, f, unpack(ns.M3.outline))
            end
            ns.currentFocus = nil
        end
    end

    local function StepGlanceScroll(step)
        if not glanceScroll or not glanceChild then return end
        if IsFocusInsideGlanceScroll() then
            ClearGlanceFocusHighlight()
        end
        local cur = glanceScroll:GetVerticalScroll() or 0
        local viewH = glanceScroll:GetHeight() or 340
        local contentH = glanceChild:GetHeight() or (5 * 112 + 12)
        local maxS = math.max(0, contentH - viewH)
        if glanceScroll.GetVerticalScrollRange then
            local apiRange = glanceScroll:GetVerticalScrollRange() or 0
            if apiRange > maxS then
                maxS = apiRange
            end
        end
        glanceScroll:SetVerticalScroll(math.max(0, math.min(maxS, cur + (step * 72))))
    end

    p2:SetScript("OnShow", function()
        mod.Layout(p2)
    end)
    glanceScroll:SetScript("OnSizeChanged", function()
        mod.Layout(p2)
    end)
    glanceScroll:SetScript("OnMouseWheel", function(_, delta)
        if delta and delta ~= 0 then
            StepGlanceScroll(delta > 0 and -1 or 1)
        end
    end)
    UI:AttachWheelScroller(p2, StepGlanceScroll)
    UI:AttachWheelScroller(glanceChild, StepGlanceScroll)

    p2.cards = {}
    local function AutoCommitGlances() UI:CommitModifiedBoxesToProfile(false) end
    for slot = 1, 5 do
        local card = CreateFrame("Frame", nil, glanceChild, "BackdropTemplate")
        card:SetHeight(104)
        card:SetPoint("TOPLEFT", glanceChild, "TOPLEFT", 0, -4 - (slot - 1) * 112)
        card:SetWidth(536)
        ns:ApplySurface(card, M3.surfaceDim, M3.outline)
        ns:EnableClipping(card)
        card.slotIndex = slot
        card.slotBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.slotBadge:SetPoint("TOPLEFT", 12, -8)
        card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. slot .. "|r")

        local iconBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        iconBtn:SetSize(44, 44)
        iconBtn:SetPoint("TOPLEFT", 14, -44)
        ns:ApplySurface(iconBtn, M3.surface, M3.primary)
        iconBtn.glanceScrollFrame = glanceScroll
        iconBtn.glanceIndex = slot
        card.iconBtn = iconBtn
        card.iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        card.iconTex:SetSize(38, 38)
        card.iconTex:SetPoint("CENTER")
        card.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconBtn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
        iconBtn:SetScript("OnClick", function(self)
            ns:PlayUISound()
            if card.slotIndex and picker then
                picker:OpenForSlot(card.slotIndex, self)
            end
        end)
        ns:RegisterFocusable(iconBtn, function() iconBtn:Click("LeftButton") end)

        card.titleBox = ns:CreateMaterialEditBox(card, "1. Short Hook / Trait Name", "", 74, -24, 150, 26, AutoCommitGlances)
        card.titleBox.glanceScrollFrame = glanceScroll
        card.titleBox.glanceIndex = slot

        card.detailBox = ns:CreateMaterialEditBox(card, "2. Tooltip Description", "", 234, -24, 220, 26, AutoCommitGlances)
        card.detailBox.glanceScrollFrame = glanceScroll
        card.detailBox.glanceIndex = slot

        card.clrBtn = ns:CreateMaterialButton(card, "Clear", 56, 26, 464, -39, nil, function()
            local sIdx = card.slotIndex
            card.titleBox:SetCleanText("")
            card.detailBox:SetCleanText("")
            if sIdx and ns.profile and ns.profile.glances and ns.profile.glances[sIdx] then
                ns.profile.glances[sIdx].title, ns.profile.glances[sIdx].detail = "", ""
            end
            if ns.SnapshotActiveProfile then ns:SnapshotActiveProfile() end
            if ns.SyncMSP then ns:SyncMSP() end
        end)
        card.clrBtn.glanceScrollFrame = glanceScroll
        card.clrBtn.glanceIndex = slot

        UI:AttachWheelScroller(card, StepGlanceScroll)
        UI:AttachWheelScroller(iconBtn, StepGlanceScroll)
        UI:AttachWheelScroller(card.titleBox, StepGlanceScroll)
        UI:AttachWheelScroller(card.titleBox.editBox, StepGlanceScroll)
        UI:AttachWheelScroller(card.titleBox.padBtn, StepGlanceScroll)
        UI:AttachWheelScroller(card.detailBox, StepGlanceScroll)
        UI:AttachWheelScroller(card.detailBox.editBox, StepGlanceScroll)
        UI:AttachWheelScroller(card.detailBox.padBtn, StepGlanceScroll)
        UI:AttachWheelScroller(card.clrBtn, StepGlanceScroll)

        p2.cards[slot] = card
    end

    local saveGlanceBtn = ns:CreateMaterialButton(p2, "Save First Glances", 560, 36, 16, -354, "PRIMARY", function()
        UI:CommitModifiedBoxesToProfile(true)
        ns:ShowStatusToast("All 5 First Glances saved & synced!")
    end)
    saveGlanceBtn:ClearAllPoints()
    saveGlanceBtn:SetPoint("BOTTOMLEFT", p2, "BOTTOMLEFT", 16, 14)
    saveGlanceBtn:SetPoint("BOTTOMRIGHT", p2, "BOTTOMRIGHT", -16, 14)
end

function mod.Layout(p2)
    if not p2 or not p2.cards or not p2.glanceScroll or not p2.glanceChild then return end
    local scrollW = p2.glanceScroll:GetWidth()
    if not scrollW or scrollW < 180 then
        scrollW = math.max(300, (p2:GetWidth() or 600) - 44)
    end
    local childW = math.max(200, scrollW - 4)
    p2.glanceChild:SetWidth(childW)

    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local topY = -4 - (slot - 1) * 112
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", p2.glanceChild, "TOPLEFT", 0, topY)
            card:SetWidth(childW)
            UI:LayoutRow(card, -38, {
                { w = card.titleBox,  weight = 0.34 },
                { w = card.detailBox, weight = 0.66 },
                { w = card.clrBtn,    fixed = 56 },
            }, 74, 12, 10)
        end
    end
    p2.glanceChild:SetHeight(5 * 112 + 12)
    if p2.glanceScroll.UpdateScrollChildRect then
        p2.glanceScroll:UpdateScrollChildRect()
    end
end

function mod.Refresh(p2)
    if not p2 or not p2.cards or not ns.profile then return end
    local fallbackIcon = UI:GetDefaultIconFallback()
    for slot = 1, 5 do
        local card = p2.cards[slot]
        if card then
            local g = (ns.profile.glances and ns.profile.glances[slot]) or { icon = fallbackIcon, title = "", detail = "" }
            UI:SetIconTextureSafe(card.iconTex, g.icon, fallbackIcon)
            if not card.titleBox:HasFocus() and not card.titleBox.isDirty then card.titleBox:SetCleanText(g.title) end
            if not card.detailBox:HasFocus() and not card.detailBox.isDirty then card.detailBox:SetCleanText(g.detail) end
        end
    end
end