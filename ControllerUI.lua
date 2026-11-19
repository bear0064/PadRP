local _, ns = ...

local mainFrame
local inspectorFrame
local activeTab = 1
local tabButtons = {}
local tabPanels = {}

local activeIdentityPage = 1
local activeGlancePage = 1
local activeBioMode = "APPEARANCE"
local knownListPage = 1
local knownSearchFilter = ""
local knownNotesOnly = false
local knownSortMode = "RECENT" -- "RECENT" or "NAME"

local editPoolIdx = 1
local editPhraseIdx = 1
local phrasePage = 1

local confirmDeleteProfileUntil = 0
local confirmClearBioUntil = 0
local confirmClearCacheUntil = 0

local MODE_LIST = {
    { key = "SMART",        label = "Smart Auto (IC Emote Nearby / Whisper Far)" },
    { key = "AUTO_EMOTE",   label = "Auto Custom Emote (/e)" },
    { key = "AUTO_WHISPER", label = "Auto Custom Whisper (/w)" },
    { key = "DO_EMOTE",     label = "Blizzard Voice Emote (/thank)" },
    { key = "MANUAL",       label = "Manual Only (Quick-Thank Controller Bind)" },
    { key = "OFF",          label = "Disabled (Off)" },
}

local POOL_LIST = {
    { key = "IC",      label = "1. In-Character: Buffs & Heals (IC)" },
    { key = "OOC",     label = "2. Out-of-Character: Buffs & Heals (OOC)" },
    { key = "RES",     label = "3. Resurrections (Combat & Spirit Res)" },
    { key = "SUMMON",  label = "4. Warlock Summons & Soulstones" },
    { key = "SPECIAL", label = "5. Portals, Healthstones & Major Cooldowns" },
}

local GLANCE_ICONS = {
    "INV_Misc_Book_09",            "INV_Misc_Book_07",            "INV_Misc_Book_11",            "INV_Scroll_02",
    "INV_Scroll_05",               "INV_Misc_Note_01",            "INV_Feather_16",              "INV_Letter_15",
    "INV_Jewelry_Ring_03",         "INV_Jewelry_Ring_22",         "INV_Jewelry_Necklace_07",     "INV_Jewelry_Talisman_07",
    "INV_Misc_Coin_01",            "INV_Misc_Gem_Ruby_02",        "INV_Misc_Gem_Sapphire_02",    "INV_Misc_PocketWatch_01",
    "INV_Helmet_46",               "INV_Misc_Cape_18",            "INV_Shirt_GuildTabard_01",    "INV_Boots_05",
    "INV_Gauntlets_05",            "INV_Belt_15",                 "INV_Shoulder_23",             "INV_Chest_Cloth_21",
    "INV_Sword_04",                "INV_Sword_39",                "INV_Weapon_ShortBlade_05",    "INV_Staff_13",
    "INV_Shield_06",               "INV_Weapon_Bow_07",           "INV_Weapon_Rifle_08",         "INV_Hammer_05",
    "Spell_Shadow_Charm",          "Spell_Shadow_SoulGem",        "Spell_Shadow_Metamorphosis",  "Spell_Fire_Fire",
    "Spell_Frost_FrostBolt02",     "Spell_Arcane_Blink",          "Spell_Holy_HolyBolt",         "Spell_Nature_Rejuvenation",
    "INV_Potion_54",               "INV_Potion_20",               "INV_Drink_05",                "INV_Drink_03",
    "INV_Misc_Bag_10",             "INV_Misc_Pipe_01",            "INV_Misc_Lantern_01",         "INV_Misc_Key_04",
    "INV_Misc_Bone_HumanSkull_01", "Ability_Racial_BloodRage",    "Ability_Hunter_BeastTaming",  "Ability_Stealth",
    "Ability_DualWield",           "Spell_Shadow_DeathCoil",      "INV_Misc_MonsterClaw_04",     "INV_Misc_Eye_01",
    "INV_Misc_Flower_02",          "INV_Misc_Herb_16",            "INV_Fishingpole_02",          "INV_Torch_Lit",
    "Trade_Engineering",           "Trade_Alchemy",               "Trade_BlackSmithing",         "Trade_Tailoring",
}

local STANDING_BADGES = {
    Ally         = "|cff81c995[ALLY]|r ",
    Acquaintance = "|cff8ab4f8[KNOWN]|r ",
    Rival        = "|cfff28b82[RIVAL]|r ",
    Marked       = "|cfffdd663[MARKED]|r ",
}

local function FormatCheckbox(label, isChecked, activeColorHex)
    local box = isChecked and ("|c" .. (activeColorHex or "ff81c995") .. "[X]|r ") or "|cff9aa0a6[ ]|r "
    return box .. label
end

function ns:ShowStatusToast(msg)
    if not mainFrame or not mainFrame.statusToast then return end
    mainFrame.statusToast:SetText("|cff81c995" .. (msg or "Saved") .. "|r")
    if C_Timer and C_Timer.After then
        C_Timer.After(3.5, function()
            if mainFrame and mainFrame.statusToast then
                mainFrame.statusToast:SetText("|cff9aa0a6Saved in PadRPDB|r")
            end
        end)
    end
end

local function GetFilteredKnownProfiles()
    local seen, list = {}, {}
    local q = strtrim(string.lower(knownSearchFilter or ""))

    local function CheckNoteStatus(k)
        if ns.GetNoteInfo then
            local standing, charNote, acctNote, hasNote = ns:GetNoteInfo(k)
            return standing, charNote, acctNote, hasNote
        end
        local rec = ns.db and ns.db.notes and ns.db.notes[k]
        local txt = (rec and rec.note) or ""
        return (rec and rec.standing) or "None", "", txt, (strtrim(txt) ~= "")
    end

    for k, v in pairs(ns.mspCache or {}) do
        if v and v.NA and v.NA ~= "" and not seen[k] then
            seen[k] = true
            local standing, charNote, acctNote, hasNote = CheckNoteStatus(k)
            if not knownNotesOnly or hasNote then
                local hay = string.lower(k .. " " .. v.NA .. " " .. (v.NT or "") .. " " .. (v.NH or "") .. " " .. (v.CU or "") .. " " .. standing .. " " .. charNote .. " " .. acctNote)
                if q == "" or string.find(hay, q, 1, true) then
                    table.insert(list, {
                        key = k,
                        data = v,
                        lastSeen = tonumber(v.lastSeen) or 0,
                        standing = standing,
                        hasNote = hasNote,
                    })
                end
            end
        end
    end

    for k, noteRec in pairs(ns.db.notes or {}) do
        if not seen[k] then
            seen[k] = true
            local standing, charNote, acctNote, hasNote = CheckNoteStatus(k)
            if not knownNotesOnly or hasNote then
                local hay = string.lower(k .. " " .. standing .. " " .. charNote .. " " .. acctNote)
                if q == "" or string.find(hay, q, 1, true) then
                    table.insert(list, {
                        key = k,
                        data = { NA = strsplit("-", k) },
                        lastSeen = 0,
                        standing = standing,
                        hasNote = hasNote,
                    })
                end
            end
        end
    end

    table.sort(list, function(a, b)
        if knownSortMode == "RECENT" then
            if a.lastSeen ~= b.lastSeen then
                return a.lastSeen > b.lastSeen
            end
        end
        return string.lower(a.data.NA or a.key) < string.lower(b.data.NA or b.key)
    end)

    return list
end

local function UpdateTabBarLayout()
    if not mainFrame or not tabButtons[1] then return end
    local showDev = (ns.db and ns.db.ui and ns.db.ui.devMode) and true or false
    local visibleCount = showDev and 7 or 6
    local totalWidth = mainFrame:GetWidth() - 24
    local gap = 4
    local btnW = math.floor((totalWidth - (gap * (visibleCount - 1))) / visibleCount)

    for i = 1, 7 do
        local tb = tabButtons[i]
        if tb then
            if i == 7 and not showDev then
                tb:Hide()
            else
                tb:SetWidth(btnW)
                tb:ClearAllPoints()
                tb:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12 + (i - 1) * (btnW + gap), -73)
                tb:Show()
            end
        end
    end

    if not showDev and activeTab == 7 then
        ns:SelectTab(6)
    end
end

-- =========================================================
-- DEDICATED FLOATING NETWORK INSPECTOR WINDOW
-- =========================================================
function ns:RefreshNetInspector(newLine)
    if not inspectorFrame then return end

    local knownCount = #GetFilteredKnownProfiles()
    local engineLabel = (type(_G.msp) == "table") and "|cff81c995LibMSP|r" or "|cfff28b82Missing LibMSP|r"
    inspectorFrame.statusBar:SetText(string.format(
        "Engine: %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
        engineLabel,
        (ns.mspStats and ns.mspStats.sent) or 0,
        (ns.mspStats and ns.mspStats.liveReplies) or 0,
        knownCount,
        (ns.mspStats and ns.mspStats.lastReplyFrom) or "None"
    ))

    inspectorFrame.chkDebug:SetText(FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
    inspectorFrame.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)

    inspectorFrame.chkSniff:SetText(FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
    inspectorFrame.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)

    inspectorFrame.chkEcho:SetText(FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
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

    local closeBtn = ns:CreateMaterialButton(inspectorFrame, "X", 26, 22, 504, -6, "CORAL", function()
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

    ns:CreateMaterialButton(inspectorFrame, "Sweep Nearby", 122, 26, 142, -306, "MINT", function()
        ns:ScanNearbyPlayers()
    end)

    ns:CreateMaterialButton(inspectorFrame, "Run Self-Test", 122, 26, 272, -306, "AMBER", function()
        ns:RunMSPSelfTest()
    end)

    ns:CreateMaterialButton(inspectorFrame, "Clear Log", 126, 26, 402, -306, "CORAL", function()
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

-- =========================================================
-- CONTROLLER ACTIONS & PROFILE SYNC
-- =========================================================
local function CloseAnyOpenPopup()
    if not mainFrame then return false end
    if mainFrame.presetDropdown and mainFrame.presetDropdown:IsShown() then
        mainFrame.presetDropdown:Hide()
        if tabPanels[1] and tabPanels[1].presetBtn then ns:SetControllerFocus(tabPanels[1].presetBtn) end
        return true
    end
    if mainFrame.modeDropdown and mainFrame.modeDropdown:IsShown() then
        mainFrame.modeDropdown:Hide()
        if tabPanels[5] and tabPanels[5].modeBtn then ns:SetControllerFocus(tabPanels[5].modeBtn) end
        return true
    end
    if mainFrame.poolDropdown and mainFrame.poolDropdown:IsShown() then
        mainFrame.poolDropdown:Hide()
        if tabPanels[5] and tabPanels[5].poolToggleBtn then ns:SetControllerFocus(tabPanels[5].poolToggleBtn) end
        return true
    end
    if mainFrame.iconPicker and mainFrame.iconPicker:IsShown() then
        local returnTarget = mainFrame.iconPicker.returnFocusWidget
        mainFrame.iconPicker:Hide()
        if returnTarget and returnTarget:IsVisible() then
            ns:SetControllerFocus(returnTarget)
        else
            ns:FocusFirstInScope()
        end
        return true
    end
    if mainFrame.exportModal and mainFrame.exportModal:IsShown() then
        mainFrame.exportModal:Hide()
        ns:FocusFirstInScope()
        return true
    end
    return false
end

function ns:ControllerConfirmAction()
    if not mainFrame or not mainFrame:IsShown() or not ns:CanProcessPadAction() then return end
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
        return
    end
    local cur = ns.currentFocus
    if not cur or not cur:IsVisible() then
        ns:FocusFirstInScope()
        return
    end
    if cur.ActivateFromPad then
        cur:ActivateFromPad()
    elseif cur.Click then
        cur:Click("LeftButton")
    end
end

function ns:ControllerCancelAction()
    if not mainFrame or not mainFrame:IsShown() or not ns:CanProcessPadAction() then return end
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
        return
    end
    if CloseAnyOpenPopup() then
        ns:PlayUISound()
        return
    end
    mainFrame:Hide()
end

function ns:CycleTab(delta)
    if not mainFrame or not mainFrame:IsShown() or not ns:CanProcessPadAction() then return end
    local maxTabs = (ns.db and ns.db.ui and ns.db.ui.devMode) and 7 or 6
    local nextTab = ((activeTab - 1 + delta) % maxTabs) + 1
    ns:SelectTab(nextTab)
end

local function GetActiveGratitudePool()
    local g = ns.db.gratitude
    local item = POOL_LIST[editPoolIdx] or POOL_LIST[1]
    if item.key == "IC" then return g.icPhrases
    elseif item.key == "OOC" then return g.oocPhrases
    elseif item.key == "RES" then return g.resPhrases
    elseif item.key == "SUMMON" then return g.summonPhrases
    elseif item.key == "SPECIAL" then return g.specialPhrases end
    return g.icPhrases
end

local function LoadGlancesPageIntoUI()
    local p2 = tabPanels[2]
    if not p2 or not p2.cards or not ns.profile then return end
    local p = ns.profile
    local baseOffset = (activeGlancePage == 2) and 3 or 0
    local placeholders = {
        { title = "e.g., Singed Cuffs",   detail = "e.g., Faint arcane scorch marks line the hems of his sleeves." },
        { title = "e.g., Worn Satchel",   detail = "e.g., Stuffed with rolled parchment, ink vials, and dried herbs." },
        { title = "e.g., Silver Signet",  detail = "e.g., A tarnished ring bearing an unfamiliar river-crest." },
        { title = "e.g., Steady Voice",   detail = "e.g., Speaks with a calm, measured cadence even under pressure." },
        { title = "e.g., Travel Cloak",   detail = "e.g., Weathered dark wool dusted with road ash from afar." },
    }

    for i = 1, 3 do
        local slot = baseOffset + i
        local card = p2.cards[i]
        if slot <= 5 then
            local g = p.glances[slot] or { icon = GLANCE_ICONS[slot], title = "", detail = "" }
            card.slotIndex = slot
            card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. slot .. "|r")
            card.iconTex:SetTexture("Interface\\Icons\\" .. (g.icon or GLANCE_ICONS[1]))
            card.titleBox.placeholder:SetText(placeholders[slot].title)
            card.detailBox.placeholder:SetText(placeholders[slot].detail)
            card.titleBox:SetCleanText(g.title)
            card.detailBox:SetCleanText(g.detail)
            card:Show()
        else
            card.slotIndex = nil
            card:Hide()
        end
    end
end

function ns:LoadProfileIntoUI()
    if not mainFrame or not ns.profile then return end
    local p = ns.profile
    local p1 = tabPanels[1]
    if p1 and p1.fnBox then
        p1.pxBox:SetCleanText(p.titlePrefix)
        p1.fnBox:SetCleanText(p.firstName)
        p1.lnBox:SetCleanText(p.lastName)
        p1.tiBox:SetCleanText(p.title)
        p1.raBox:SetCleanText(p.race)
        p1.clBox:SetCleanText(p.class)
        p1.prBox:SetCleanText(p.pronouns)
        p1.agBox:SetCleanText(p.age)
        p1.htBox:SetCleanText(p.height)
        p1.wtBox:SetCleanText(p.weight)
        p1.eyBox:SetCleanText(p.eyeColor)
        p1.cuBox:SetCleanText(p.currently)
        p1.oocBox:SetCleanText(p.oocInfo)

        p1.niBox:SetCleanText(p.nickname)
        p1.hoBox:SetCleanText(p.houseName)
        p1.moBox:SetCleanText(p.motto)
        p1.hbBox:SetCleanText(p.birthplace)
        p1.hhBox:SetCleanText(p.residence)
        p1.profNameBox:SetCleanText(p.profileName)
    end
    LoadGlancesPageIntoUI()
    local p3 = tabPanels[3]
    if p3 and p3.bioEditor then
        p3.bioEditor:SetCleanText(activeBioMode == "APPEARANCE" and p.description or p.history)
    end
end

local function CommitModifiedBoxesToProfile(forceAll)
    if not ns.profile or not mainFrame then return false end
    local p = ns.profile
    local changed = false
    local p1 = tabPanels[1]
    if p1 and p1.fnBox then
        local function CheckBox(box, key)
            if box and (forceAll or box.isDirty) then
                p[key] = box:GetText()
                box.isDirty = false
                changed = true
            end
        end
        CheckBox(p1.pxBox, "titlePrefix")
        CheckBox(p1.fnBox, "firstName")
        CheckBox(p1.lnBox, "lastName")
        CheckBox(p1.tiBox, "title")
        CheckBox(p1.raBox, "race")
        CheckBox(p1.clBox, "class")
        CheckBox(p1.prBox, "pronouns")
        CheckBox(p1.agBox, "age")
        CheckBox(p1.htBox, "height")
        CheckBox(p1.wtBox, "weight")
        CheckBox(p1.eyBox, "eyeColor")
        CheckBox(p1.cuBox, "currently")
        CheckBox(p1.oocBox, "oocInfo")

        CheckBox(p1.niBox, "nickname")
        CheckBox(p1.hoBox, "houseName")
        CheckBox(p1.moBox, "motto")
        CheckBox(p1.hbBox, "birthplace")
        CheckBox(p1.hhBox, "residence")

        if forceAll or p1.profNameBox.isDirty then
            local pName = strtrim(p1.profNameBox:GetText() or "")
            if pName ~= "" then p.profileName = pName end
            p1.profNameBox.isDirty = false
            changed = true
        end
    end
    local p2 = tabPanels[2]
    if p2 and p2.cards then
        for i = 1, 3 do
            local card = p2.cards[i]
            local slot = card and card.slotIndex
            if card and slot and card:IsShown() and p.glances[slot] then
                if forceAll or card.titleBox.isDirty then
                    p.glances[slot].title = card.titleBox:GetText()
                    card.titleBox.isDirty = false
                    changed = true
                end
                if forceAll or card.detailBox.isDirty then
                    p.glances[slot].detail = card.detailBox:GetText()
                    card.detailBox.isDirty = false
                    changed = true
                end
            end
        end
    end
    local p3 = tabPanels[3]
    if p3 and p3.bioEditor and (forceAll or p3.bioEditor.isDirty) then
        local text = p3.bioEditor:GetText()
        if activeBioMode == "APPEARANCE" then p.description = text else p.history = text end
        p3.bioEditor.isDirty = false
        changed = true
    end
    if changed then
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
    end
    return changed
end

function ns:SelectTab(index)
    if ns.activeEditBox and ns.activeEditBox:HasFocus() then
        ns.activeEditBox:ClearFocus()
    end
    CommitModifiedBoxesToProfile(false)
    activeTab = index
    local M3 = ns.M3
    for i, panel in ipairs(tabPanels) do
        local tb = tabButtons[i]
        if i == index then
            panel:Show()
            tb:SetBackdropColor(unpack(M3.primaryTonal))
            tb.activeBar:Show()
            tb.label:SetTextColor(0.82, 0.90, 1.0)
        else
            panel:Hide()
            tb:SetBackdropColor(unpack(M3.surfaceLow))
            tb.activeBar:Hide()
            tb.label:SetTextColor(0.60, 0.64, 0.70)
        end
    end
    CloseAnyOpenPopup()
    ns:RefreshControllerUI()
    ns:FocusFirstInScope()
end

local function RefreshHeaderBanner()
    if not mainFrame or not ns.profile then return end
    local p = ns.profile
    local M3 = ns.M3
    local _, classFile = UnitClass("player")
    local classHex = (classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] and RAID_CLASS_COLORS[classFile].colorStr) or "ffffffff"

    if mainFrame.portraitTex then
        mainFrame.portraitTex:SetTexture("Interface\\Icons\\" .. ((p.icon and p.icon ~= "") and p.icon or "INV_Helmet_46"))
    end

    local nameParts = {}
    if p.titlePrefix and strtrim(p.titlePrefix) ~= "" then table.insert(nameParts, strtrim(p.titlePrefix)) end
    local baseFirst = (p.firstName and p.firstName ~= "") and p.firstName or UnitName("player")
    table.insert(nameParts, baseFirst)
    if p.lastName and strtrim(p.lastName) ~= "" then table.insert(nameParts, strtrim(p.lastName)) end
    local fullName = table.concat(nameParts, " ")

    mainFrame.bannerName:SetText("|c" .. classHex .. fullName .. "|r")
    local titlePart = (p.title and p.title ~= "") and ("|cfffdd663<" .. p.title .. ">|r") or "|cff9aa0a6No RP Title|r"
    local housePart = (p.houseName and p.houseName ~= "") and ("  |cff8ab4f8-  " .. p.houseName .. "|r") or ""
    mainFrame.bannerTitle:SetText(titlePart .. housePart)
    mainFrame.profChip:SetText(p.profileName or "Default")

    local wuBtn = mainFrame.walkUpBtn
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

    local sw = mainFrame.icSwitch
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

function ns:RefreshTargetCard()
    if not mainFrame or not tabPanels[4] then return end
    local p4 = tabPanels[4]

    local entries = GetFilteredKnownProfiles()
    local perPage = 8
    local totalPages = math.max(1, math.ceil(#entries / perPage))
    if knownListPage > totalPages then knownListPage = totalPages end
    if knownListPage < 1 then knownListPage = 1 end

    p4.countLabel:SetText(string.format("|cff8ab4f8RP DIRECTORY (%d)|r  -  Select any player to open Dossier & Notes", #entries))
    p4.pageLabel:SetText(string.format("Page %d / %d", knownListPage, totalPages))

    p4.notesOnlyBtn:SetText(FormatCheckbox("Notes Only", knownNotesOnly, "ff81c995"))
    p4.notesOnlyBtn:SetTone(knownNotesOnly and "MINT" or nil)
    p4.sortBtn:SetText(knownSortMode == "RECENT" and "Sort: Recent" or "Sort: A-Z")
    p4.sortBtn:SetTone(knownSortMode == "RECENT" and "PRIMARY" or nil)

    local startIdx = (knownListPage - 1) * perPage
    for i = 1, perPage do
        local rowBtn = p4.knownRows[i]
        local item = entries[startIdx + i]
        if item then
            local k = item.key
            local d = item.data
            local standTag = (item.standing and STANDING_BADGES[item.standing]) or ""
            local icTag = (d.FC == "2") and "|cff81c995[IC]|r " or ((d.FC == "1") and "|cfff28b82[OOC]|r " or "")
            local noteTag = item.hasNote and "|TInterface\\Icons\\INV_Misc_Note_01:13:13:0:0:64:64:4:60:4:60|t " or ""

            local _, wuCode = ns:GetTargetWalkUpInfo(d)
            local wuTag = ""
            if wuCode == "WELCOME" then wuTag = " |cff81c995[WU]|r"
            elseif wuCode == "ASK" then wuTag = " |cfffdd663[Ask]|r"
            elseif wuCode == "CLOSED" then wuTag = " |cfff28b82[Off]|r" end

            local titleStr = (d.NT and d.NT ~= "") and ("  |cfffdd663<" .. d.NT .. ">|r") or ""
            local seenStr = (item.lastSeen and item.lastSeen > 0) and date("%m/%d %H:%M", item.lastSeen) or "--/--"

            rowBtn.profileKey = k
            rowBtn:SetText(string.format("%s%s%s|cffe8eaed%s|r |cff8ab4f8(%s)|r%s%s", noteTag, standTag, icTag, d.NA or k, k, wuTag, titleStr))
            rowBtn.seenLabel:SetText("|cff9aa0a6" .. seenStr .. "|r")
            rowBtn:Show()
        else
            rowBtn.profileKey = nil
            rowBtn.seenLabel:SetText("")
            rowBtn:Hide()
        end
    end
end

local function RefreshGratitudeStudio()
    local p5 = tabPanels[5]
    if not p5 then return end
    local g = ns.db.gratitude

    p5.modeBtn:SetText("|cff9aa0a6GRATITUDE MODE:|r   |cff8ab4f8" .. ns:GetGratitudeModeLabel() .. "|r   |cfffdd663[Open Dropdown v]|r")
    p5.buffBtn:SetText("Buffs: " .. (g.thankBuffs and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p5.healBtn:SetText("Heals: " .. (g.thankHeals and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p5.resBtn:SetText("Res: " .. (g.thankRes and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p5.specialBtn:SetText("Portals/CDs: " .. (g.thankSpecial and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
    p5.sessionBtn:SetText("1x/Session: " .. (g.oncePerSession and "|cff81c995ON|r" or "|cff9aa0a6OFF|r"))
    p5.cdLabel:SetText(string.format("Cooldown: |cfffdd663%ds|r", g.cooldown or 60))
    p5.healPctLabel:SetText(string.format("Min Heal: |cfffdd663%d%% HP|r", g.minHealPercent or 15))

    local pool = GetActiveGratitudePool()
    if #pool == 0 then table.insert(pool, "thanks %name for the %spell.") end
    if editPhraseIdx > #pool then editPhraseIdx = #pool end
    if editPhraseIdx < 1 then editPhraseIdx = 1 end

    local totalPages = math.max(1, math.ceil(#pool / 3))
    phrasePage = math.min(totalPages, math.ceil(editPhraseIdx / 3))

    local poolItem = POOL_LIST[editPoolIdx] or POOL_LIST[1]
    p5.poolToggleBtn:SetText("|cff9aa0a6PHRASE POOL:|r  |cfffdd663" .. poolItem.label .. "|r  |cff8ab4f8[v]|r")
    p5.phrasePageLabel:SetText(string.format("Page %d/%d (%d)", phrasePage, totalPages, #pool))

    local startIdx = (phrasePage - 1) * 3
    for i = 1, 3 do
        local actualIdx = startIdx + i
        local row = p5.phraseRows[i]
        local phraseStr = pool[actualIdx]
        if phraseStr then
            row.phraseIndex = actualIdx
            local isSelected = (actualIdx == editPhraseIdx)
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

    if not p5.phraseBox:HasFocus() then
        p5.phraseBox:SetCleanText(pool[editPhraseIdx] or "")
    end
end

function ns:RefreshControllerUI()
    if not mainFrame or not ns.profile then return end
    mainFrame:SetScale(ns.db.ui.scale or 1.0)
    UpdateTabBarLayout()
    RefreshHeaderBanner()

    local p = ns.profile
    local p1 = tabPanels[1]
    if activeIdentityPage == 1 then
        p1.coreSubBtn:SetTone("PRIMARY")
        p1.detailSubBtn:SetTone(nil)
        p1.pageCore:Show()
        p1.pageDetails:Hide()
    else
        p1.coreSubBtn:SetTone(nil)
        p1.detailSubBtn:SetTone("PRIMARY")
        p1.pageCore:Hide()
        p1.pageDetails:Show()
    end

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
    SyncBox(p1.prBox, p.pronouns)
    SyncBox(p1.agBox, p.age)
    SyncBox(p1.htBox, p.height)
    SyncBox(p1.wtBox, p.weight)
    SyncBox(p1.eyBox, p.eyeColor)
    SyncBox(p1.cuBox, p.currently)
    SyncBox(p1.oocBox, p.oocInfo)

    SyncBox(p1.niBox, p.nickname)
    SyncBox(p1.hoBox, p.houseName)
    SyncBox(p1.moBox, p.motto)
    SyncBox(p1.hbBox, p.birthplace)
    SyncBox(p1.hhBox, p.residence)
    SyncBox(p1.profNameBox, p.profileName)

    p1.relBtn:SetText("Relationship: |cfffdd663" .. ns:GetRelationshipLabel(p.relationship) .. "|r")
    p1.styleBtn:SetText("RP Style: |cff8ab4f8" .. ns:GetRPStyleLabel(p.rpStyle) .. "|r")
    p1.portraitPickBtn:SetText("Character Portrait Icon: |cff81c995" .. (p.icon or "INV_Helmet_46") .. "|r  |cff9aa0a6[Browse Icons]|r")

    local p2 = tabPanels[2]
    p2.page1Btn:SetTone(activeGlancePage == 1 and "PRIMARY" or nil)
    p2.page2Btn:SetTone(activeGlancePage == 2 and "PRIMARY" or nil)
    for i = 1, 3 do
        local card = p2.cards[i]
        local slot = card.slotIndex
        if slot and card:IsShown() then
            local g = p.glances[slot] or { icon = GLANCE_ICONS[slot], title = "", detail = "" }
            card.iconTex:SetTexture("Interface\\Icons\\" .. (g.icon or GLANCE_ICONS[1]))
            if not card.titleBox:HasFocus() and not card.titleBox.isDirty then card.titleBox:SetCleanText(g.title) end
            if not card.detailBox:HasFocus() and not card.detailBox.isDirty then card.detailBox:SetCleanText(g.detail) end
        end
    end

    local p3 = tabPanels[3]
    if activeBioMode == "APPEARANCE" then
        p3.appTabBtn:SetTone("PRIMARY")
        p3.hisTabBtn:SetTone(nil)
        p3.sectionHint:SetText("|cff8ab4f8PHYSICAL APPEARANCE:|r Describe your character's build, attire, voice, and demeanor.")
        p3.bioEditor:SetPlaceholder("Write your character's physical appearance here...")
        if not p3.bioEditor:HasFocus() and not p3.bioEditor.isDirty then p3.bioEditor:SetCleanText(p.description) end
    else
        p3.hisTabBtn:SetTone("PRIMARY")
        p3.appTabBtn:SetTone(nil)
        p3.sectionHint:SetText("|cff8ab4f8CHARACTER HISTORY & BACKGROUND:|r Write your character's origins, homeland, and story.")
        p3.bioEditor:SetPlaceholder("Write your character's backstory and history here...")
        if not p3.bioEditor:HasFocus() and not p3.bioEditor.isDirty then p3.bioEditor:SetCleanText(p.history) end
    end

    ns:RefreshTargetCard()
    RefreshGratitudeStudio()

    -- Tab 6: Clean User Settings + Developer Mode Checkbox
    local p6 = tabPanels[6]
    local curW, curH = math.floor(mainFrame:GetWidth() + 0.5), math.floor(mainFrame:GetHeight() + 0.5)
    p6.scaleLabel:SetText(string.format("Scale: |cfffdd663%.0f%%|r  (|cff8ab4f8%dx%d|r)", (ns.db.ui.scale or 1.0) * 100, curW, curH))
    p6.minimapBtn:SetText(FormatCheckbox("Minimap Icon", ns.db.ui.showMinimap, "ff81c995"))
    p6.hudBtn:SetText(FormatCheckbox("Floating Target HUD", ns.db.ui.showTargetHUD, "ff81c995"))
    p6.hudRPBtn:SetText(FormatCheckbox("TRP3-Style Player Tooltip", ns.db.ui.rpTooltip, "ff8ab4f8"))
    p6.npClassBtn:SetText(FormatCheckbox("Class-Color Nameplates", ns.db.ui.nameplateClassColors, "ff8ab4f8"))
    p6.npTagBtn:SetText(FormatCheckbox("Nameplate [IC/OOC] Tags", ns.db.ui.nameplateStatusTags, "ff81c995"))
    p6.npRPNameBtn:SetText(FormatCheckbox("RP Names on Nameplates", ns.db.ui.nameplateRPNames, "ff8ab4f8"))
    p6.combatBtn:SetText(FormatCheckbox("Auto-Hide in Combat", ns.db.ui.hideInCombat, "ff81c995"))
    p6.soundBtn:SetText(FormatCheckbox("UI Sound Effects", ns.db.ui.soundEffects, "ff81c995"))
    p6.partyBtn:SetText(FormatCheckbox("Ignore Party/Raid Buffs", ns.db.gratitude.ignoreParty, "ff81c995"))
    p6.rpNameBtn:SetText(FormatCheckbox("Thank Helper RP Name", ns.db.gratitude.useRPNames, "ff81c995"))
    p6.chatRPBtn:SetText(FormatCheckbox("Show [RP Names] in Chat", ns.db.ui.chatRPNames, "ff81c995"))
    p6.afkOOCBtn:SetText(FormatCheckbox("Auto-OOC When AFK", ns.db.ui.autoAFKOOC, "ff81c995"))

    p6.devModeBtn:SetText(FormatCheckbox("Developer Mode (Show Dev Tab)", ns.db.ui.devMode, "fffdd663"))
    p6.devModeBtn:SetTone(ns.db.ui.devMode and "AMBER" or nil)

    -- Tab 7: Dev Tab (only visible when Developer Mode is checked)
    local p7 = tabPanels[7]
    if p7 and p7.diagText and ns.mspStats then
        local engState = (type(_G.msp) == "table") and "|cff81c995LibMSP ACTIVE|r" or "|cfff28b82LibMSP MISSING|r"
        p7.diagText:SetText(string.format(
            "|cff8ab4f8ENGINE:|r %s  |  Sent: |cfffdd663%d|r  |  Live Replies: |cff81c995%d|r  |  Cached: |cff8ab4f8%d|r  |  Last: |cffe8eaed%s|r",
            engState,
            ns.mspStats.sent or 0,
            ns.mspStats.liveReplies or 0,
            #GetFilteredKnownProfiles(),
            ns.mspStats.lastReplyFrom or "None"
        ))
        p7.chkDebug:SetText(FormatCheckbox("Debug Events", ns.mspDebug, "ff81c995"))
        p7.chkDebug:SetTone(ns.mspDebug and "MINT" or nil)
        p7.chkSniff:SetText(FormatCheckbox("Wire Sniffer", ns.mspSniff, "fffdd663"))
        p7.chkSniff:SetTone(ns.mspSniff and "AMBER" or nil)
        p7.chkEcho:SetText(FormatCheckbox("Echo to Chat", ns.mspEchoChat, "ff8ab4f8"))
        p7.chkEcho:SetTone(ns.mspEchoChat and "PRIMARY" or nil)
        p7.logEditor:SetCleanText(table.concat(ns.netLogs or {}, "\n"))
    end

    if inspectorFrame and inspectorFrame:IsShown() then
        ns:RefreshNetInspector()
    end
end

function ns:SetWindowDimensions(w, h)
    if not mainFrame then return end
    w = math.max(660, math.min(1050, w or 680))
    h = math.max(540, math.min(840, h or 560))
    ns.db.ui.width, ns.db.ui.height = w, h
    mainFrame:SetSize(w, h)
    ns:RefreshControllerUI()
end

function ns:ToggleMainFrame()
    if not mainFrame then return end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        ns:LoadProfileIntoUI()
        mainFrame:Show()
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end
end

function ns:InitControllerUI()
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

    local savedW = (ns.db.ui and ns.db.ui.width) or 680
    local savedH = (ns.db.ui and ns.db.ui.height) or 560

    mainFrame = CreateFrame("Frame", "PadRP_MainFrame", UIParent, "BackdropTemplate")
    ns.mainFrame = mainFrame
    mainFrame:SetSize(savedW, savedH)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    if mainFrame.SetResizeBounds then mainFrame:SetResizeBounds(660, 540, 1050, 840) end
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    ns:EnableClipping(mainFrame)
    mainFrame:Hide()
    ns:ApplySurface(mainFrame, M3.surfaceDim, M3.outline)

    local pendingBindingClear = false

    local function ApplyControllerBindings(frame)
        if InCombatLockdown() then return end
        SetOverrideBindingClick(frame, true, "PADLSHOULDER", "PadRP_PrevTabBtn")
        SetOverrideBindingClick(frame, true, "PADRSHOULDER", "PadRP_NextTabBtn")
        SetOverrideBindingClick(frame, true, "PADDUP",       "PadRP_PadUpBtn")
        SetOverrideBindingClick(frame, true, "PADDDOWN",     "PadRP_PadDownBtn")
        SetOverrideBindingClick(frame, true, "PADDLEFT",     "PadRP_PadLeftBtn")
        SetOverrideBindingClick(frame, true, "PADDRIGHT",    "PadRP_PadRightBtn")
        SetOverrideBindingClick(frame, true, "PAD1",         "PadRP_PadConfirmBtn")
        SetOverrideBindingClick(frame, true, "PAD2",         "PadRP_PadCancelBtn")
        pendingBindingClear = false
    end

    local function RemoveControllerBindings(frame)
        if InCombatLockdown() then
            pendingBindingClear = true
            return
        end
        ClearOverrideBindings(frame)
        pendingBindingClear = false
    end

    local focusRing = CreateFrame("Frame", "PadRP_FocusRing", mainFrame, "BackdropTemplate")
    focusRing:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    focusRing:SetBackdropColor(0.54, 0.71, 0.97, 0.05)
    focusRing:SetBackdropBorderColor(0.54, 0.71, 0.97, 0.90)
    focusRing:Hide()
    mainFrame.focusRing = focusRing

    local topAccent = mainFrame:CreateTexture(nil, "OVERLAY")
    topAccent:SetHeight(2)
    topAccent:SetPoint("TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", -1, -1)
    topAccent:SetColorTexture(0.54, 0.71, 0.97, 0.85)

    tinsert(UISpecialFrames, "PadRP_MainFrame")

    mainFrame:SetScript("OnShow", function(self)
        ns:PlayUISound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        ApplyControllerBindings(self)
        ns:FocusFirstInScope()
    end)
    mainFrame:SetScript("OnHide", function(self)
        if ns.activeEditBox and ns.activeEditBox:HasFocus() then ns.activeEditBox:ClearFocus() end
        CommitModifiedBoxesToProfile(false)
        ns:PlayUISound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        CloseAnyOpenPopup()
        RemoveControllerBindings(self)
    end)
    mainFrame:SetScript("OnSizeChanged", function(self, w, h)
        if ns.db and ns.db.ui then
            ns.db.ui.width, ns.db.ui.height = math.floor(w + 0.5), math.floor(h + 0.5)
        end
        UpdateTabBarLayout()
        if self:IsShown() then
            ns:RefreshTargetCard()
            if ns.currentFocus then ns:SetControllerFocus(ns.currentFocus) end
        end
    end)
    mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    mainFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            RemoveControllerBindings(self)
            if self:IsShown() and ns.db.ui.hideInCombat then
                self:Hide()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingBindingClear and not self:IsShown() then
                RemoveControllerBindings(self)
            elseif self:IsShown() then
                ApplyControllerBindings(self)
            end
        end
    end)

    -- =========================================================
    -- SHARED ICON PICKER MODAL (WORKS FOR PORTRAIT & GLANCES 1-5)
    -- =========================================================
    local picker = CreateFrame("Frame", "PadRP_IconPicker", mainFrame, "BackdropTemplate")
    picker:SetSize(452, 318)
    picker:SetPoint("CENTER", mainFrame, "CENTER", 0, -10)
    picker:SetFrameLevel(mainFrame:GetFrameLevel() + 45)
    ns:ApplySurface(picker, M3.surfaceDim, M3.primary)
    ns:EnableClipping(picker)
    picker:EnableMouse(true)
    picker:Hide()
    picker.mode, picker.targetSlot, picker.page, picker.cells = "GLANCE", 1, 1, {}
    picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    picker.title:SetPoint("TOPLEFT", 16, -12)
    ns:CreateMaterialButton(picker, "X", 26, 24, 416, -8, "CORAL", function()
        picker:Hide()
        if picker.returnFocusWidget and picker.returnFocusWidget:IsVisible() then
            ns:SetControllerFocus(picker.returnFocusWidget)
        else
            ns:FocusFirstInScope()
        end
    end)

    local function ApplyPickedIcon(iconName)
        if not iconName or iconName == "" then return end
        if picker.mode == "PORTRAIT" then
            ns.profile.icon = iconName
            RefreshHeaderBanner()
            ns:RefreshControllerUI()
            ns:ShowStatusToast("Portrait icon updated!")
        else
            local slot = picker.targetSlot or 1
            if ns.profile.glances[slot] then
                ns.profile.glances[slot].icon = iconName
            end
            LoadGlancesPageIntoUI()
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

    local ICONS_PER_PAGE = 32
    for idx = 1, ICONS_PER_PAGE do
        local col, row = (idx - 1) % 8, math.floor((idx - 1) / 8)
        local cell = CreateFrame("Button", nil, picker, "BackdropTemplate")
        cell:SetSize(46, 46)
        cell:SetPoint("TOPLEFT", 16 + col * 53, -40 - row * 51)
        ns:ApplySurface(cell, M3.surface, M3.outline)
        cell.tex = cell:CreateTexture(nil, "ARTWORK")
        cell.tex:SetSize(38, 38)
        cell.tex:SetPoint("CENTER")
        cell.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cell:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
        cell:SetScript("OnClick", function(self)
            if not self.iconName then return end
            ns:PlayUISound()
            ApplyPickedIcon(self.iconName)
        end)
        ns:RegisterFocusable(cell, function() cell:Click("LeftButton") end)
        picker.cells[idx] = cell
    end
    ns:CreateMaterialButton(picker, "< Page 1", 86, 26, 16, -248, nil, function() picker.page = 1; picker:RefreshGrid() end)
    picker.pageText = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    picker.pageText:SetPoint("TOPLEFT", 112, -255)
    ns:CreateMaterialButton(picker, "Page 2 >", 86, 26, 182, -248, nil, function() picker.page = 2; picker:RefreshGrid() end)
    picker.customBox = ns:CreateMaterialEditBox(picker, nil, "Or type icon name...", 16, -280, 318, 26)
    ns:CreateMaterialButton(picker, "Use Custom", 96, 26, 342, -280, "PRIMARY", function()
        local raw = strtrim(picker.customBox:GetText() or "")
        if raw ~= "" then ApplyPickedIcon(raw) end
    end)
    picker.RefreshGrid = function(self)
        local currentIcon
        if self.mode == "PORTRAIT" then
            currentIcon = (ns.profile and ns.profile.icon) or "INV_Helmet_46"
            self.title:SetText("|cff8ab4f8SELECT CHARACTER PORTRAIT ICON|r")
        else
            local slot = self.targetSlot or 1
            currentIcon = (ns.profile.glances[slot] and ns.profile.glances[slot].icon) or GLANCE_ICONS[1]
            self.title:SetText("|cff8ab4f8SELECT ICON FOR GLANCE #" .. slot .. "|r")
        end
        self.pageText:SetText(string.format("Page %d / 2", self.page))
        self.customBox:SetCleanText(currentIcon)
        local startIndex = (self.page - 1) * ICONS_PER_PAGE
        for i = 1, ICONS_PER_PAGE do
            local cell = self.cells[i]
            local iconName = GLANCE_ICONS[startIndex + i]
            if iconName then
                cell.iconName = iconName
                cell.tex:SetTexture("Interface\\Icons\\" .. iconName)
                cell:Show()
            else
                cell:Hide()
            end
        end
    end
    picker.OpenForSlot = function(self, slotIndex, returnWidget)
        self.mode, self.targetSlot, self.page, self.returnFocusWidget = "GLANCE", slotIndex, 1, returnWidget
        self:RefreshGrid()
        self:Show()
        ns:SetControllerFocus(self.cells[1])
    end
    picker.OpenForPortrait = function(self, returnWidget)
        self.mode, self.page, self.returnFocusWidget = "PORTRAIT", 1, returnWidget
        self:RefreshGrid()
        self:Show()
        ns:SetControllerFocus(self.cells[1])
    end
    mainFrame.iconPicker = picker

    -- HEADER BAR
    local banner = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    banner:SetHeight(56)
    banner:SetPoint("TOPLEFT", 12, -12)
    banner:SetPoint("TOPRIGHT", -12, -12)
    ns:ApplySurface(banner, M3.surfaceLow, M3.outline)
    ns:EnableClipping(banner)

    local portraitBtn = CreateFrame("Button", nil, banner, "BackdropTemplate")
    portraitBtn:SetSize(40, 40)
    portraitBtn:SetPoint("TOPLEFT", 8, -8)
    ns:ApplySurface(portraitBtn, M3.surface, M3.primary)
    mainFrame.portraitBtn = portraitBtn
    mainFrame.portraitTex = portraitBtn:CreateTexture(nil, "ARTWORK")
    mainFrame.portraitTex:SetSize(34, 34)
    mainFrame.portraitTex:SetPoint("CENTER")
    mainFrame.portraitTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portraitBtn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    portraitBtn:SetScript("OnClick", function(self) ns:PlayUISound(); picker:OpenForPortrait(self) end)
    ns:RegisterFocusable(portraitBtn, function() portraitBtn:Click("LeftButton") end)

    mainFrame.bannerName = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mainFrame.bannerName:SetPoint("TOPLEFT", 56, -9)
    mainFrame.bannerName:SetWidth(142)
    mainFrame.bannerName:SetJustifyH("LEFT")
    mainFrame.bannerName:SetWordWrap(false)

    mainFrame.bannerTitle = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.bannerTitle:SetPoint("TOPLEFT", 56, -32)
    mainFrame.bannerTitle:SetWidth(142)
    mainFrame.bannerTitle:SetJustifyH("LEFT")
    mainFrame.bannerTitle:SetWordWrap(false)

    ns:CreateMaterialButton(banner, "<", 20, 24, 202, -16, nil, function() CommitModifiedBoxesToProfile(false); ns:CycleProfile(-1) end)
    mainFrame.profChip = ns:CreateMaterialButton(banner, "Profile", 84, 24, 224, -16, nil, function() CommitModifiedBoxesToProfile(false); ns:CycleProfile(1) end)
    ns:CreateMaterialButton(banner, ">", 20, 24, 310, -16, nil, function() CommitModifiedBoxesToProfile(false); ns:CycleProfile(1) end)

    local closeBtn = ns:CreateMaterialButton(banner, "X", 26, 32, 0, -12, "CORAL", function() mainFrame:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("RIGHT", banner, "RIGHT", -8, 0)

    local icSwitch = CreateFrame("Button", nil, banner, "BackdropTemplate")
    icSwitch:SetSize(144, 32)
    icSwitch:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    ns:ApplySurface(icSwitch, M3.mintTonal, M3.mint)
    icSwitch.bgLabel = icSwitch:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icSwitch.thumb = CreateFrame("Frame", nil, icSwitch, "BackdropTemplate")
    icSwitch.thumb:SetSize(96, 26)
    ns:ApplySurface(icSwitch.thumb, M3.mint, M3.outline)
    icSwitch.thumb.label = icSwitch.thumb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icSwitch.thumb.label:SetPoint("CENTER")
    icSwitch:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
    icSwitch:SetScript("OnClick", function()
        ns:PlayUISound()
        ns:ToggleICOOC()
        RefreshHeaderBanner()
        ns:ShowStatusToast(ns.profile.isIC and "Switched to In-Character (IC)" or "Switched to Out-of-Character (OOC)")
    end)
    ns:RegisterFocusable(icSwitch, function() icSwitch:Click("LeftButton") end)
    mainFrame.icSwitch = icSwitch

    local walkUpBtn = ns:CreateMaterialButton(banner, "WALK-UPS: OPEN", 120, 32, 0, -12, "MINT", function()
        local code = ns:CycleWalkUpStatus()
        RefreshHeaderBanner()
        if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
        ns:ShowStatusToast("Walk-Up Flag: " .. ns:GetWalkUpLabel(code))
    end)
    walkUpBtn:ClearAllPoints()
    walkUpBtn:SetPoint("RIGHT", icSwitch, "LEFT", -6, 0)
    mainFrame.walkUpBtn = walkUpBtn

    -- 6 CORE TABS + CONDITIONAL 7TH DEV TAB
    local tabTitles = { "[LB] Identity", "First Glances", "Bio & Lore", "Directory", "Gratitude", "Settings [RB]", "Dev" }
    for i, title in ipairs(tabTitles) do
        local tb = CreateFrame("Button", nil, mainFrame, "BackdropTemplate")
        tb:SetSize(106, 30)
        tb:SetPoint("TOPLEFT", 12 + (i - 1) * 110, -73)
        ns:ApplySurface(tb, M3.surfaceLow, { 0, 0, 0, 0 })
        ns:EnableClipping(tb)
        tb.isTabBarBtn = true
        tb.activeBar = tb:CreateTexture(nil, "OVERLAY")
        tb.activeBar:SetHeight(3)
        tb.activeBar:SetPoint("BOTTOMLEFT", 8, 0)
        tb.activeBar:SetPoint("BOTTOMRIGHT", -8, 0)
        tb.activeBar:SetColorTexture(i == 7 and 0.99 or 0.54, i == 7 and 0.84 or 0.71, i == 7 and 0.39 or 0.97, 1)
        tb.activeBar:Hide()
        tb.label = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tb.label:SetPoint("CENTER", 0, 1)
        tb.label:SetText(title)
        tb:SetScript("OnClick", function() ns:PlayUISound(); ns:SelectTab(i) end)
        tabButtons[i] = tb

        local panel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 12, -106)
        panel:SetPoint("BOTTOMRIGHT", -12, 40)
        ns:ApplySurface(panel, M3.surfaceLow, M3.outline)
        ns:EnableClipping(panel)
        panel:Hide()
        tabPanels[i] = panel
    end

    -- =========================================================
    -- TAB 1: IDENTITY (2 SUB-PAGES: CORE IDENTITY + VITALS/LORE)
    -- =========================================================
    local p1 = tabPanels[1]
    local function AutoCommitTab1()
        CommitModifiedBoxesToProfile(false)
        RefreshHeaderBanner()
        ns:ShowStatusToast("Saved character vitals to PadRPDB")
    end

    p1.coreSubBtn = ns:CreateMaterialButton(p1, "1. Core Identity & Status", 308, 26, 16, -10, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        if mainFrame.presetDropdown then mainFrame.presetDropdown:Hide() end
        activeIdentityPage = 1
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p1.detailSubBtn = ns:CreateMaterialButton(p1, "2. Vitals, Background & Profiles", 308, 26, 332, -10, nil, function()
        CommitModifiedBoxesToProfile(false)
        if mainFrame.presetDropdown then mainFrame.presetDropdown:Hide() end
        activeIdentityPage = 2
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p1.detailSubBtn:SetPoint("TOPRIGHT", p1, "TOPRIGHT", -16, -10)

    local pageCore = CreateFrame("Frame", nil, p1)
    pageCore:SetPoint("TOPLEFT", 0, -38)
    pageCore:SetPoint("BOTTOMRIGHT", 0, 52)
    p1.pageCore = pageCore

    p1.pxBox = ns:CreateMaterialEditBox(pageCore, "Prefix", "e.g., Sir / Sister", 16, -6, 96, 28, AutoCommitTab1)
    p1.fnBox = ns:CreateMaterialEditBox(pageCore, "First Name", "e.g., Malachar", 122, -6, 150, 28, AutoCommitTab1)
    p1.lnBox = ns:CreateMaterialEditBox(pageCore, "Last Name", "e.g., Gray", 282, -6, 150, 28, AutoCommitTab1)
    p1.tiBox = ns:CreateMaterialEditBox(pageCore, "Full RP Title", "e.g., Master Arcanist", 442, -6, 198, 28, AutoCommitTab1)
    p1.tiBox:SetPoint("TOPRIGHT", pageCore, "TOPRIGHT", -16, -21)

    p1.raBox = ns:CreateMaterialEditBox(pageCore, "RP Race (Blank = Default)", "e.g., Human", 16, -58, 196, 28, AutoCommitTab1)
    p1.clBox = ns:CreateMaterialEditBox(pageCore, "RP Class / Occupation", "e.g., Warlock", 222, -58, 204, 28, AutoCommitTab1)
    p1.prBox = ns:CreateMaterialEditBox(pageCore, "Pronouns", "e.g., He/Him", 436, -58, 204, 28, AutoCommitTab1)
    p1.prBox:SetPoint("TOPRIGHT", pageCore, "TOPRIGHT", -16, -73)

    p1.agBox = ns:CreateMaterialEditBox(pageCore, "Age", "e.g., 32", 16, -110, 145, 28, AutoCommitTab1)
    p1.htBox = ns:CreateMaterialEditBox(pageCore, "Height", "e.g., 6'0\" / Tall", 171, -110, 145, 28, AutoCommitTab1)
    p1.wtBox = ns:CreateMaterialEditBox(pageCore, "Build / Body Shape", "e.g., Athletic", 326, -110, 152, 28, AutoCommitTab1)
    p1.eyBox = ns:CreateMaterialEditBox(pageCore, "Eye Color", "e.g., Pale amber", 488, -110, 152, 28, AutoCommitTab1)
    p1.eyBox:SetPoint("TOPRIGHT", pageCore, "TOPRIGHT", -16, -125)

    p1.cuBox = ns:CreateMaterialEditBox(pageCore, "Currently (Select Preset, Cycle, or Type Custom)", "What is your character doing right now?", 16, -162, 336, 28, AutoCommitTab1)

    p1.presetBtn = ns:CreateMaterialButton(pageCore, "Presets [v]", 84, 28, 358, -177, "AMBER", function()
        if mainFrame.presetDropdown:IsShown() then
            mainFrame.presetDropdown:Hide()
            ns:SetControllerFocus(p1.presetBtn)
        else
            mainFrame.presetDropdown.page = 1
            mainFrame.presetDropdown:Rebuild()
            mainFrame.presetDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    ns:CreateMaterialButton(pageCore, "Cycle", 62, 28, 448, -177, "PRIMARY", function()
        ns:CycleCurrentlyPreset()
        p1.cuBox:SetCleanText(ns.profile.currently or "")
        ns:ShowStatusToast("Cycled Currently status")
    end)
    ns:CreateMaterialButton(pageCore, "+ Save", 62, 28, 516, -177, "MINT", function()
        local customTxt = strtrim(p1.cuBox:GetText() or "")
        if customTxt == "" then return end
        for _, existing in ipairs(ns.db.currentlyPresets) do
            if existing == customTxt then ns:ShowStatusToast("Preset already in list!"); return end
        end
        table.insert(ns.db.currentlyPresets, customTxt)
        ns.profile.currently = customTxt
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        if mainFrame.presetDropdown:IsShown() then mainFrame.presetDropdown:Rebuild() end
        ns:ShowStatusToast("Added new Currently preset!")
    end)
    ns:CreateMaterialButton(pageCore, "Clear", 56, 28, 584, -177, nil, function()
        p1.cuBox:SetCleanText("")
        ns.profile.currently = ""
        ns:SnapshotActiveProfile()
        ns:SyncMSP()
        ns:ShowStatusToast("Cleared Currently status")
    end)

    p1.oocBox = ns:CreateMaterialEditBox(pageCore, "Out-of-Character (OOC) Note & RP Preferences", "e.g., Playing on controller.", 16, -218, 624, 28, AutoCommitTab1)
    p1.oocBox:SetPoint("TOPRIGHT", pageCore, "TOPRIGHT", -16, -233)

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
        local presets = ns.db.currentlyPresets or {}
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
                    ns:SnapshotActiveProfile()
                    ns:SyncMSP()
                    dropdown:Hide()
                    ns:SetControllerFocus(p1.presetBtn)
                end)
                r.selectBtn.label:SetJustifyH("LEFT")
                r.delBtn = ns:CreateMaterialButton(self, "X", 30, 24, 388, -28 - (i - 1) * 26, "CORAL", function(btn)
                    if btn.presetIndex and ns.db.currentlyPresets[btn.presetIndex] then
                        table.remove(ns.db.currentlyPresets, btn.presetIndex)
                        dropdown:Rebuild()
                        ns:FocusFirstInScope()
                    end
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
    mainFrame.presetDropdown = dropdown

    local pageDetails = CreateFrame("Frame", nil, p1)
    pageDetails:SetPoint("TOPLEFT", 0, -38)
    pageDetails:SetPoint("BOTTOMRIGHT", 0, 52)
    pageDetails:Hide()
    p1.pageDetails = pageDetails

    p1.niBox = ns:CreateMaterialEditBox(pageDetails, "Nickname", "e.g., Kiyaskiw", 16, -6, 196, 28, AutoCommitTab1)
    p1.hoBox = ns:CreateMaterialEditBox(pageDetails, "House / Clan / Guild Name", "e.g., House Gray", 222, -6, 204, 28, AutoCommitTab1)
    p1.moBox = ns:CreateMaterialEditBox(pageDetails, "Motto / Catchphrase", "e.g., It isn't fraud if they're impressed.", 436, -6, 204, 28, AutoCommitTab1)
    p1.moBox:SetPoint("TOPRIGHT", pageDetails, "TOPRIGHT", -16, -21)

    p1.hbBox = ns:CreateMaterialEditBox(pageDetails, "Birthplace", "e.g., Lordaeron (Allegedly)", 16, -60, 306, 28, AutoCommitTab1)
    p1.hhBox = ns:CreateMaterialEditBox(pageDetails, "Residence", "e.g., The Mage Quarter, Stormwind", 334, -60, 306, 28, AutoCommitTab1)
    p1.hhBox:SetPoint("TOPRIGHT", pageDetails, "TOPRIGHT", -16, -75)

    p1.relBtn = ns:CreateMaterialButton(pageDetails, "Relationship: Not Specified", 306, 30, 16, -118, "AMBER", function()
        local code = ns:CycleRelationshipStatus()
        ns:RefreshControllerUI()
        ns:ShowStatusToast("Relationship: " .. ns:GetRelationshipLabel(code))
    end)
    p1.styleBtn = ns:CreateMaterialButton(pageDetails, "RP Style: Normal", 306, 30, 334, -118, "PRIMARY", function()
        local code = ns:CycleRPStyle()
        ns:RefreshControllerUI()
        ns:ShowStatusToast("RP Style: " .. ns:GetRPStyleLabel(code))
    end)
    p1.styleBtn:SetPoint("TOPRIGHT", pageDetails, "TOPRIGHT", -16, -118)

    p1.portraitPickBtn = ns:CreateMaterialButton(pageDetails, "Character Portrait Icon", 624, 30, 16, -158, nil, function(self)
        picker:OpenForPortrait(self)
    end)
    p1.portraitPickBtn:SetPoint("TOPRIGHT", pageDetails, "TOPRIGHT", -16, -158)

    p1.profNameBox = ns:CreateMaterialEditBox(pageDetails, "Active Profile Name", "e.g., Main Character", 16, -206, 250, 28, AutoCommitTab1)
    ns:CreateMaterialButton(pageDetails, "+ New Profile", 175, 28, 278, -221, "PRIMARY", function() CommitModifiedBoxesToProfile(false); ns:CreateNewProfile() end)
    p1.delProfBtn = ns:CreateMaterialButton(pageDetails, "Delete Active Profile", 178, 28, 462, -221, "CORAL", function(self)
        local now = GetTime()
        if now < confirmDeleteProfileUntil then
            confirmDeleteProfileUntil = 0
            self:SetText("Delete Active Profile")
            ns:DeleteCurrentProfile()
        else
            confirmDeleteProfileUntil = now + 4
            self:SetText("|cfff28b82Confirm Delete?|r")
        end
    end)

    local saveIdentityBtn = ns:CreateMaterialButton(p1, "Save & Broadcast Profile via LibMSP", 470, 36, 16, -354, "PRIMARY", function()
        CommitModifiedBoxesToProfile(true)
        RefreshHeaderBanner()
        ns:ShowStatusToast("Profile permanently saved & synced!")
    end)
    saveIdentityBtn:ClearAllPoints()
    saveIdentityBtn:SetPoint("BOTTOMLEFT", p1, "BOTTOMLEFT", 16, 14)
    saveIdentityBtn:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", -168, 14)

    local revertBtn = ns:CreateMaterialButton(p1, "Revert Unsaved", 144, 36, 0, 0, nil, function()
        ns:LoadProfileIntoUI()
        RefreshHeaderBanner()
    end)
    revertBtn:ClearAllPoints()
    revertBtn:SetPoint("BOTTOMRIGHT", p1, "BOTTOMRIGHT", -16, 14)

    -- =========================================================
    -- TAB 2: FIRST GLANCES (5 SLOTS PAGED 1-3 & 4-5)
    -- =========================================================
    local p2 = tabPanels[2]
    p2.page1Btn = ns:CreateMaterialButton(p2, "Glances 1 - 3", 170, 26, 16, -10, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        activeGlancePage = 1
        LoadGlancesPageIntoUI()
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    p2.page2Btn = ns:CreateMaterialButton(p2, "Glances 4 - 5", 170, 26, 194, -10, nil, function()
        CommitModifiedBoxesToProfile(false)
        activeGlancePage = 2
        LoadGlancesPageIntoUI()
        ns:RefreshControllerUI()
        ns:FocusFirstInScope()
    end)
    local gIntro = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gIntro:SetPoint("LEFT", p2.page2Btn, "RIGHT", 12, 0)
    gIntro:SetText("|cff9aa0a6All 5 slots broadcast to TRP3 / MRP / XRP|r")

    p2.cards = {}
    local function AutoCommitGlances() CommitModifiedBoxesToProfile(false) end
    for i = 1, 3 do
        local card = CreateFrame("Frame", nil, p2, "BackdropTemplate")
        card:SetHeight(94)
        card:SetPoint("TOPLEFT", 16, -42 - (i - 1) * 100)
        card:SetPoint("TOPRIGHT", -16, -42 - (i - 1) * 100)
        ns:ApplySurface(card, M3.surfaceDim, M3.outline)
        ns:EnableClipping(card)
        card.slotIndex = i
        card.slotBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.slotBadge:SetPoint("TOPLEFT", 12, -10)
        card.slotBadge:SetText("|cff8ab4f8GLANCE #" .. i .. "|r")

        local iconBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
        iconBtn:SetSize(44, 44)
        iconBtn:SetPoint("TOPLEFT", 14, -40)
        ns:ApplySurface(iconBtn, M3.surface, M3.primary)
        card.iconBtn = iconBtn
        card.iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        card.iconTex:SetSize(38, 38)
        card.iconTex:SetPoint("CENTER")
        card.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconBtn:SetScript("OnEnter", function(self) ns:SetControllerFocus(self) end)
        iconBtn:SetScript("OnClick", function(self)
            ns:PlayUISound()
            if card.slotIndex then
                picker:OpenForSlot(card.slotIndex, self)
            end
        end)
        ns:RegisterFocusable(iconBtn, function() iconBtn:Click("LeftButton") end)

        card.titleBox = ns:CreateMaterialEditBox(card, "1. Short Hook / Trait Name", "", 76, -12, 180, 28, AutoCommitGlances)
        card.detailBox = ns:CreateMaterialEditBox(card, "2. Tooltip Description", "", 268, -12, 286, 28, AutoCommitGlances)
        card.detailBox:SetPoint("TOPRIGHT", card, "TOPRIGHT", -68, -27)
        local clrBtn = ns:CreateMaterialButton(card, "Clear", 50, 28, 0, 0, nil, function()
            local slot = card.slotIndex
            card.titleBox:SetCleanText("")
            card.detailBox:SetCleanText("")
            if slot and ns.profile.glances[slot] then
                ns.profile.glances[slot].title, ns.profile.glances[slot].detail = "", ""
            end
            ns:SnapshotActiveProfile()
            ns:SyncMSP()
        end)
        clrBtn:ClearAllPoints()
        clrBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -27)
        p2.cards[i] = card
    end

    local saveGlanceBtn = ns:CreateMaterialButton(p2, "Save & Broadcast All 5 First Glances Now", 624, 36, 16, -354, "PRIMARY", function()
        CommitModifiedBoxesToProfile(true)
        ns:ShowStatusToast("All 5 First Glances saved & synced!")
    end)
    saveGlanceBtn:ClearAllPoints()
    saveGlanceBtn:SetPoint("BOTTOMLEFT", p2, "BOTTOMLEFT", 16, 14)
    saveGlanceBtn:SetPoint("BOTTOMRIGHT", p2, "BOTTOMRIGHT", -16, 14)

    -- TAB 3: BIO & LORE
    local p3 = tabPanels[3]
    p3.appTabBtn = ns:CreateMaterialButton(p3, "1. Physical Appearance & Attire", 254, 32, 16, -12, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        activeBioMode = "APPEARANCE"
        p3.bioEditor:SetCleanText(ns.profile.description)
        ns:RefreshControllerUI()
    end)
    p3.hisTabBtn = ns:CreateMaterialButton(p3, "2. Character History & Background", 254, 32, 278, -12, nil, function()
        CommitModifiedBoxesToProfile(false)
        activeBioMode = "HISTORY"
        p3.bioEditor:SetCleanText(ns.profile.history)
        ns:RefreshControllerUI()
    end)
    p3.clearBioBtn = ns:CreateMaterialButton(p3, "Clear Text", 100, 32, 540, -12, "CORAL", function(self)
        local now = GetTime()
        if now < confirmClearBioUntil then
            confirmClearBioUntil = 0
            self:SetText("Clear Text")
            p3.bioEditor:SetCleanText("")
            if activeBioMode == "APPEARANCE" then ns.profile.description = "" else ns.profile.history = "" end
            ns:SnapshotActiveProfile()
            ns:SyncMSP()
        else
            confirmClearBioUntil = now + 4
            self:SetText("|cfff28b82Confirm?|r")
        end
    end)
    p3.clearBioBtn:ClearAllPoints()
    p3.clearBioBtn:SetPoint("TOPRIGHT", p3, "TOPRIGHT", -16, -12)
    p3.sectionHint = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p3.sectionHint:SetPoint("TOPLEFT", 16, -52)
    p3.bioEditor = ns:CreateScrollableTextEditor(p3, "", 16, -72, 624, 268, function() CommitModifiedBoxesToProfile(false) end)
    p3.bioEditor:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -16, 58)
    local saveBioBtn = ns:CreateMaterialButton(p3, "Save Physical Appearance & Character History", 624, 36, 16, -354, "PRIMARY", function()
        CommitModifiedBoxesToProfile(true)
        ns:ShowStatusToast("Appearance & History saved!")
    end)
    saveBioBtn:ClearAllPoints()
    saveBioBtn:SetPoint("BOTTOMLEFT", p3, "BOTTOMLEFT", 16, 14)
    saveBioBtn:SetPoint("BOTTOMRIGHT", p3, "BOTTOMRIGHT", -16, 14)

    -- =========================================================
    -- TAB 4: RP DIRECTORY (LAST SEEN, SORT, NOTES-ONLY FILTER)
    -- =========================================================
    local p4 = tabPanels[4]
    p4.countLabel = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p4.countLabel:SetPoint("TOPLEFT", 16, -12)

    local sweepBtn = ns:CreateMaterialButton(p4, "Sweep Nearby", 104, 24, 0, 0, "MINT", function()
        ns:ScanNearbyPlayers()
        ns:ShowStatusToast("Sweeping nearby players...")
    end)
    sweepBtn:ClearAllPoints()
    sweepBtn:SetPoint("TOPRIGHT", p4, "TOPRIGHT", -16, -8)

    local openLiveBtn = ns:CreateMaterialButton(p4, "Open Target Dossier", 142, 24, 0, 0, "PRIMARY", function()
        ns:OpenTargetDossier()
    end)
    openLiveBtn:ClearAllPoints()
    openLiveBtn:SetPoint("RIGHT", sweepBtn, "LEFT", -6, 0)

    p4.searchBox = ns:CreateMaterialEditBox(p4, nil, "Search by Name, Title, House, or Note...", 16, -38, 250, 26, function(txt)
        knownSearchFilter = txt or ""
        knownListPage = 1
        ns:RefreshTargetCard()
    end)
    p4.searchBox:SetScript("OnTextChanged", function(self)
        knownSearchFilter = self:GetText() or ""
        knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.notesOnlyBtn = ns:CreateMaterialButton(p4, "[ ] Notes Only", 104, 26, 272, -38, nil, function()
        knownNotesOnly = not knownNotesOnly
        knownListPage = 1
        ns:RefreshTargetCard()
    end)

    p4.sortBtn = ns:CreateMaterialButton(p4, "Sort: Recent", 90, 26, 382, -38, "PRIMARY", function()
        knownSortMode = (knownSortMode == "RECENT") and "NAME" or "RECENT"
        knownListPage = 1
        ns:RefreshTargetCard()
    end)

    local nextPageBtn = ns:CreateMaterialButton(p4, "Next >", 54, 26, 0, 0, nil, function()
        knownListPage = knownListPage + 1
        ns:RefreshTargetCard()
    end)
    nextPageBtn:ClearAllPoints()
    nextPageBtn:SetPoint("TOPRIGHT", p4, "TOPRIGHT", -16, -38)

    p4.pageLabel = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p4.pageLabel:SetPoint("RIGHT", nextPageBtn, "LEFT", -6, 0)

    local prevPageBtn = ns:CreateMaterialButton(p4, "< Prev", 54, 26, 0, 0, nil, function()
        knownListPage = math.max(1, knownListPage - 1)
        ns:RefreshTargetCard()
    end)
    prevPageBtn:ClearAllPoints()
    prevPageBtn:SetPoint("RIGHT", p4.pageLabel, "LEFT", -6, 0)

    p4.knownRows = {}
    for i = 1, 8 do
        local rowY = -74 - (i - 1) * 34
        local rowBtn = ns:CreateMaterialButton(p4, "", 624, 30, 16, rowY, nil, function(self)
            if self.profileKey and ns.OpenTargetDossier then
                ns:OpenTargetDossier(self.profileKey)
            end
        end)
        rowBtn:SetPoint("RIGHT", p4, "RIGHT", -16, 0)
        rowBtn.label:SetJustifyH("LEFT")
        rowBtn.label:SetPoint("RIGHT", -92, 0)

        rowBtn.seenLabel = rowBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        rowBtn.seenLabel:SetPoint("RIGHT", -10, 0)
        rowBtn.seenLabel:SetJustifyH("RIGHT")

        p4.knownRows[i] = rowBtn
    end

    -- TAB 5: GRATITUDE STUDIO
    local p5 = tabPanels[5]
    p5.modeBtn = ns:CreateMaterialButton(p5, "Gratitude Mode [v]", 624, 30, 16, -10, "PRIMARY", function()
        if mainFrame.poolDropdown then mainFrame.poolDropdown:Hide() end
        if mainFrame.modeDropdown:IsShown() then
            mainFrame.modeDropdown:Hide()
            ns:SetControllerFocus(p5.modeBtn)
        else
            mainFrame.modeDropdown:Rebuild()
            mainFrame.modeDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p5.modeBtn:SetPoint("TOPRIGHT", p5, "TOPRIGHT", -16, -10)
    p5.modeBtn.label:SetJustifyH("LEFT")

    local modeDropdown = CreateFrame("Frame", nil, p5, "BackdropTemplate")
    modeDropdown:SetSize(624, 196)
    modeDropdown:SetPoint("TOPLEFT", p5.modeBtn, "BOTTOMLEFT", 0, -2)
    modeDropdown:SetFrameLevel(p5:GetFrameLevel() + 30)
    ns:ApplySurface(modeDropdown, M3.surfaceDim, M3.primary)
    ns:EnableClipping(modeDropdown)
    modeDropdown:EnableMouse(true)
    modeDropdown:Hide()
    modeDropdown.rows = {}
    for i, m in ipairs(MODE_LIST) do
        local rowBtn = ns:CreateMaterialButton(modeDropdown, "", 608, 25, 8, -28 - (i - 1) * 27, nil, function()
            ns.db.gratitude.mode = m.key
            modeDropdown:Hide()
            RefreshGratitudeStudio()
            ns:SetControllerFocus(p5.modeBtn)
        end)
        rowBtn.label:SetJustifyH("LEFT")
        modeDropdown.rows[i] = rowBtn
    end
    modeDropdown.Rebuild = function(self)
        local cur = ns.db.gratitude.mode
        for i, m in ipairs(MODE_LIST) do
            local r = self.rows[i]
            local isCur = (m.key == cur)
            r:SetText((isCur and "|cff81c995[ACTIVE]  |r" or "          ") .. m.label)
            r:SetTone(isCur and "MINT" or nil)
        end
    end
    mainFrame.modeDropdown = modeDropdown

    p5.buffBtn = ns:CreateMaterialButton(p5, "Buffs", 118, 26, 16, -46, nil, function() ns.db.gratitude.thankBuffs = not ns.db.gratitude.thankBuffs; RefreshGratitudeStudio() end)
    p5.healBtn = ns:CreateMaterialButton(p5, "Heals", 118, 26, 142, -46, nil, function() ns.db.gratitude.thankHeals = not ns.db.gratitude.thankHeals; RefreshGratitudeStudio() end)
    p5.resBtn = ns:CreateMaterialButton(p5, "Res", 118, 26, 268, -46, nil, function() ns.db.gratitude.thankRes = not ns.db.gratitude.thankRes; RefreshGratitudeStudio() end)
    p5.specialBtn = ns:CreateMaterialButton(p5, "Portals/CDs", 124, 26, 394, -46, nil, function() ns.db.gratitude.thankSpecial = not ns.db.gratitude.thankSpecial; RefreshGratitudeStudio() end)
    p5.sessionBtn = ns:CreateMaterialButton(p5, "1x/Session", 114, 26, 526, -46, nil, function() ns.db.gratitude.oncePerSession = not ns.db.gratitude.oncePerSession; RefreshGratitudeStudio() end)

    ns:CreateMaterialButton(p5, "-15s", 52, 24, 16, -78, nil, function() ns.db.gratitude.cooldown = math.max(15, (ns.db.gratitude.cooldown or 60) - 15); RefreshGratitudeStudio() end)
    p5.cdLabel = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p5.cdLabel:SetPoint("TOPLEFT", 78, -84)
    ns:CreateMaterialButton(p5, "+15s", 52, 24, 185, -78, nil, function() ns.db.gratitude.cooldown = math.min(600, (ns.db.gratitude.cooldown or 60) + 15); RefreshGratitudeStudio() end)

    ns:CreateMaterialButton(p5, "-5%", 52, 24, 332, -78, nil, function() ns.db.gratitude.minHealPercent = math.max(1, (ns.db.gratitude.minHealPercent or 15) - 5); RefreshGratitudeStudio() end)
    p5.healPctLabel = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p5.healPctLabel:SetPoint("TOPLEFT", 396, -84)
    ns:CreateMaterialButton(p5, "+5%", 52, 24, 520, -78, nil, function() ns.db.gratitude.minHealPercent = math.min(80, (ns.db.gratitude.minHealPercent or 15) + 5); RefreshGratitudeStudio() end)

    p5.poolToggleBtn = ns:CreateMaterialButton(p5, "Phrase Pool [v]", 336, 26, 16, -110, "AMBER", function()
        if mainFrame.modeDropdown then mainFrame.modeDropdown:Hide() end
        if mainFrame.poolDropdown:IsShown() then
            mainFrame.poolDropdown:Hide()
            ns:SetControllerFocus(p5.poolToggleBtn)
        else
            mainFrame.poolDropdown:Rebuild()
            mainFrame.poolDropdown:Show()
            ns:FocusFirstInScope()
        end
    end)
    p5.poolToggleBtn.label:SetJustifyH("LEFT")

    local poolDropdown = CreateFrame("Frame", nil, p5, "BackdropTemplate")
    poolDropdown:SetSize(440, 170)
    poolDropdown:SetPoint("TOPLEFT", p5.poolToggleBtn, "BOTTOMLEFT", 0, -2)
    poolDropdown:SetFrameLevel(p5:GetFrameLevel() + 30)
    ns:ApplySurface(poolDropdown, M3.surfaceDim, M3.amber)
    ns:EnableClipping(poolDropdown)
    poolDropdown:EnableMouse(true)
    poolDropdown:Hide()
    poolDropdown.rows = {}
    for i, item in ipairs(POOL_LIST) do
        local rowBtn = ns:CreateMaterialButton(poolDropdown, "", 424, 25, 8, -28 - (i - 1) * 27, nil, function()
            editPoolIdx, editPhraseIdx = i, 1
            poolDropdown:Hide()
            RefreshGratitudeStudio()
            ns:SetControllerFocus(p5.poolToggleBtn)
        end)
        rowBtn.label:SetJustifyH("LEFT")
        poolDropdown.rows[i] = rowBtn
    end
    poolDropdown.Rebuild = function(self)
        for i, item in ipairs(POOL_LIST) do
            local r = self.rows[i]
            local isCur = (i == editPoolIdx)
            r:SetText((isCur and "|cfffdd663[EDITING] |r" or "          ") .. item.label)
            r:SetTone(isCur and "AMBER" or nil)
        end
    end
    mainFrame.poolDropdown = poolDropdown

    ns:CreateMaterialButton(p5, "+ Add Phrase", 104, 26, 358, -110, "PRIMARY", function()
        local pool = GetActiveGratitudePool()
        table.insert(pool, "nods warmly to %name in thanks for the %spell.")
        editPhraseIdx = #pool
        RefreshGratitudeStudio()
    end)
    ns:CreateMaterialButton(p5, "<", 28, 26, 468, -110, nil, function() editPhraseIdx = math.max(1, editPhraseIdx - 3); RefreshGratitudeStudio() end)
    p5.phrasePageLabel = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p5.phrasePageLabel:SetPoint("TOPLEFT", 502, -117)
    ns:CreateMaterialButton(p5, ">", 28, 26, 612, -110, nil, function()
        local pool = GetActiveGratitudePool()
        editPhraseIdx = math.min(#pool, editPhraseIdx + 3)
        RefreshGratitudeStudio()
    end)

    p5.phraseRows = {}
    for i = 1, 3 do
        local rowY = -142 - (i - 1) * 28
        local r = {}
        r.delBtn = ns:CreateMaterialButton(p5, "X", 32, 25, 0, 0, "CORAL", function()
            local pool = GetActiveGratitudePool()
            if #pool > 1 and r.phraseIndex and pool[r.phraseIndex] then
                table.remove(pool, r.phraseIndex)
                editPhraseIdx = math.min(#pool, math.max(1, editPhraseIdx))
                RefreshGratitudeStudio()
            end
        end)
        r.delBtn:ClearAllPoints()
        r.delBtn:SetPoint("TOPRIGHT", p5, "TOPRIGHT", -16, rowY)
        r.selectBtn = ns:CreateMaterialButton(p5, "", 586, 25, 16, rowY, nil, function()
            if r.phraseIndex then editPhraseIdx = r.phraseIndex; RefreshGratitudeStudio() end
        end)
        r.selectBtn:SetPoint("RIGHT", r.delBtn, "LEFT", -6, 0)
        r.selectBtn.label:SetJustifyH("LEFT")
        p5.phraseRows[i] = r
    end

    p5.phraseBox = ns:CreateMaterialEditBox(p5, "Edit Selected Phrase", "", 16, -232, 624, 30, function(txt)
        local pool = GetActiveGratitudePool()
        local trimmed = strtrim(txt or "")
        if trimmed ~= "" then pool[editPhraseIdx] = trimmed; RefreshGratitudeStudio() end
    end)
    p5.phraseBox:SetPoint("TOPRIGHT", p5, "TOPRIGHT", -16, -247)

    local tokens = {
        { label = "+ %name",     token = "%name" },
        { label = "+ %fullname", token = "%fullname" },
        { label = "+ %spell",    token = "%spell" },
        { label = "+ %class",    token = "%class" },
        { label = "+ %race",     token = "%race" },
    }
    for idx, tk in ipairs(tokens) do
        ns:CreateMaterialButton(p5, tk.label, 82, 26, 16 + (idx - 1) * 86, -284, nil, function()
            local cur = p5.phraseBox:GetText() or ""
            local sep = (cur ~= "" and string.sub(cur, -1) ~= " ") and " " or ""
            p5.phraseBox:SetCleanText(cur .. sep .. tk.token)
            GetActiveGratitudePool()[editPhraseIdx] = p5.phraseBox:GetText()
            RefreshGratitudeStudio()
        end)
    end
    ns:CreateMaterialButton(p5, "Save Phrase", 92, 26, 448, -284, "MINT", function()
        local txt = strtrim(p5.phraseBox:GetText() or "")
        if txt ~= "" then GetActiveGratitudePool()[editPhraseIdx] = txt; RefreshGratitudeStudio() end
    end)
    ns:CreateMaterialButton(p5, "Preview", 94, 26, 546, -284, "AMBER", function()
        local preview = ns:FormatTokens(p5.phraseBox:GetText(), UnitExists("target") and "target" or "player", "Mark of the Wild")
        ns:LogNet("PREVIEW", "ff81c995", preview)
        ns:ShowStatusToast("Preview: " .. preview)
    end)
    local quickThankBottom = ns:CreateMaterialButton(p5, "Trigger Quick-Thank Now (Target or Last Helper)", 624, 36, 16, -356, "PRIMARY", function() ns:QuickThankAction() end)
    quickThankBottom:ClearAllPoints()
    quickThankBottom:SetPoint("BOTTOMLEFT", p5, "BOTTOMLEFT", 16, 14)
    quickThankBottom:SetPoint("BOTTOMRIGHT", p5, "BOTTOMRIGHT", -16, 14)

    -- TAB 6: SETTINGS
    local p6 = tabPanels[6]
    ns:CreateMaterialButton(p6, "Scale -", 78, 28, 16, -14, nil, function() ns.db.ui.scale = math.max(0.8, (ns.db.ui.scale or 1.0) - 0.05); ns:RefreshControllerUI(); ns:RefreshTargetHUD() end)
    p6.scaleLabel = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6.scaleLabel:SetPoint("TOPLEFT", 104, -22)
    ns:CreateMaterialButton(p6, "Scale +", 78, 28, 268, -14, nil, function() ns.db.ui.scale = math.min(1.3, (ns.db.ui.scale or 1.0) + 0.05); ns:RefreshControllerUI(); ns:RefreshTargetHUD() end)
    ns:CreateMaterialButton(p6, "Standard Size", 92, 28, 356, -14, nil, function() ns:SetWindowDimensions(680, 560) end)
    ns:CreateMaterialButton(p6, "Wide Size", 92, 28, 454, -14, "PRIMARY", function() ns:SetWindowDimensions(820, 620) end)
    ns:CreateMaterialButton(p6, "Large Size", 88, 28, 552, -14, "AMBER", function() ns:SetWindowDimensions(940, 700) end)

    p6.minimapBtn   = ns:CreateMaterialButton(p6, "", 304, 28, 16, -50, nil, function() ns.db.ui.showMinimap = not ns.db.ui.showMinimap; ns:RefreshMinimapButton(); ns:RefreshControllerUI() end)
    p6.hudBtn       = ns:CreateMaterialButton(p6, "", 304, 28, 336, -50, nil, function() ns.db.ui.showTargetHUD = not ns.db.ui.showTargetHUD; ns:RefreshControllerUI(); ns:RefreshTargetHUD() end)

    p6.hudRPBtn     = ns:CreateMaterialButton(p6, "", 304, 28, 16, -84, nil, function() ns.db.ui.rpTooltip = not ns.db.ui.rpTooltip; ns:RefreshControllerUI() end)
    p6.npClassBtn   = ns:CreateMaterialButton(p6, "", 304, 28, 336, -84, nil, function() ns.db.ui.nameplateClassColors = not ns.db.ui.nameplateClassColors; if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)

    p6.npTagBtn     = ns:CreateMaterialButton(p6, "", 304, 28, 16, -118, nil, function() ns.db.ui.nameplateStatusTags = not ns.db.ui.nameplateStatusTags; if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)
    p6.npRPNameBtn  = ns:CreateMaterialButton(p6, "", 304, 28, 336, -118, nil, function() ns.db.ui.nameplateRPNames = not ns.db.ui.nameplateRPNames; if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end; ns:RefreshControllerUI() end)

    p6.combatBtn    = ns:CreateMaterialButton(p6, "", 304, 28, 16, -152, nil, function() ns.db.ui.hideInCombat = not ns.db.ui.hideInCombat; ns:RefreshControllerUI() end)
    p6.soundBtn     = ns:CreateMaterialButton(p6, "", 304, 28, 336, -152, nil, function() ns.db.ui.soundEffects = not ns.db.ui.soundEffects; ns:RefreshControllerUI() end)

    p6.partyBtn     = ns:CreateMaterialButton(p6, "", 304, 28, 16, -186, nil, function() ns.db.gratitude.ignoreParty = not ns.db.gratitude.ignoreParty; ns:RefreshControllerUI() end)
    p6.rpNameBtn    = ns:CreateMaterialButton(p6, "", 304, 28, 336, -186, nil, function() ns.db.gratitude.useRPNames = not ns.db.gratitude.useRPNames; ns:RefreshControllerUI() end)

    p6.chatRPBtn    = ns:CreateMaterialButton(p6, "", 304, 28, 16, -220, nil, function() ns.db.ui.chatRPNames = not ns.db.ui.chatRPNames; ns:RefreshControllerUI() end)
    p6.afkOOCBtn    = ns:CreateMaterialButton(p6, "", 304, 28, 336, -220, nil, function() ns.db.ui.autoAFKOOC = not ns.db.ui.autoAFKOOC; ns:RefreshControllerUI() end)

    local openExpBtn = ns:CreateMaterialButton(p6, "Export / Import Profile String", 304, 30, 16, -260, "PRIMARY", function()
        CommitModifiedBoxesToProfile(false)
        mainFrame.exportModal.box:SetCleanText(ns:ExportCurrentProfileString())
        mainFrame.exportModal:Show()
        ns:FocusFirstInScope()
    end)

    p6.devModeBtn = ns:CreateMaterialButton(p6, "", 304, 30, 336, -260, nil, function()
        ns.db.ui.devMode = not ns.db.ui.devMode
        ns:RefreshControllerUI()
        ns:ShowStatusToast(ns.db.ui.devMode and "Developer Mode enabled (Dev tab unlocked)" or "Developer Mode hidden")
    end)

    local expModal = CreateFrame("Frame", nil, p6, "BackdropTemplate")
    expModal:SetSize(560, 260)
    expModal:SetPoint("CENTER", p6, "CENTER", 0, 0)
    expModal:SetFrameLevel(p6:GetFrameLevel() + 30)
    ns:ApplySurface(expModal, M3.surfaceDim, M3.primary)
    ns:EnableClipping(expModal)
    expModal:EnableMouse(true)
    expModal:Hide()
    ns:CreateMaterialButton(expModal, "X", 28, 24, 520, -8, "CORAL", function() expModal:Hide(); ns:SetControllerFocus(openExpBtn) end)
    expModal.box = ns:CreateScrollableTextEditor(expModal, "Paste a PADRP5~ or PADRP4~ profile string here...", 16, -40, 528, 165)
    ns:CreateMaterialButton(expModal, "Highlight String for Copy", 258, 30, 16, -216, "AMBER", function()
        expModal.box:SetCleanText(ns:ExportCurrentProfileString())
        expModal.box.editBox:HighlightText()
        expModal.box.editBox:SetFocus()
    end)
    ns:CreateMaterialButton(expModal, "Import String as New Profile", 258, 30, 286, -216, "MINT", function()
        local ok, msg = ns:ImportProfileString(strtrim(expModal.box:GetText() or ""))
        if ok then expModal:Hide(); ns:SetControllerFocus(openExpBtn); ns:ShowStatusToast("Imported: " .. msg)
        else ns:ShowStatusToast(msg or "Import failed") end
    end)
    mainFrame.exportModal = expModal

    -- TAB 7: DEV TAB (HIDDEN UNLESS DEVELOPER MODE IS CHECKED)
    local p7 = tabPanels[7]
    p7.diagText = p7:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p7.diagText:SetPoint("TOPLEFT", 16, -12)
    p7.diagText:SetPoint("TOPRIGHT", -16, -12)
    p7.diagText:SetJustifyH("LEFT")

    p7.chkDebug = ns:CreateMaterialButton(p7, "", 198, 26, 16, -34, nil, function()
        ns.mspDebug = not ns.mspDebug
        ns:RefreshControllerUI()
    end)
    p7.chkSniff = ns:CreateMaterialButton(p7, "", 198, 26, 222, -34, nil, function()
        ns.mspSniff = not ns.mspSniff
        if ns.mspSniff then ns.mspDebug = true end
        ns:RefreshControllerUI()
    end)
    p7.chkEcho = ns:CreateMaterialButton(p7, "", 212, 26, 428, -34, nil, function()
        ns.mspEchoChat = not ns.mspEchoChat
        ns:RefreshControllerUI()
    end)

    ns:CreateMaterialButton(p7, "Pop-Out Inspector", 148, 28, 16, -68, "PRIMARY", function()
        ns.mspDebug = true
        ns:ToggleNetInspector(true)
        ns:RefreshControllerUI()
    end)
    ns:CreateMaterialButton(p7, "Sweep Nearby", 148, 28, 172, -68, "MINT", function()
        ns:ScanNearbyPlayers()
    end)
    ns:CreateMaterialButton(p7, "Run Self-Test", 148, 28, 328, -68, "AMBER", function()
        ns:RunMSPSelfTest()
    end)

    p7.clearCacheBtn = ns:CreateMaterialButton(p7, "Clear Profile Cache", 156, 28, 484, -68, "CORAL", function(self)
        local now = GetTime()
        if now < confirmClearCacheUntil then
            confirmClearCacheUntil = 0
            self:SetText("Clear Profile Cache")
            local removed = ns:ClearMSPCache()
            ns:LogNet("CACHE", "fff28b82", string.format("Cleared %d cached profile(s). Ready to test live pulls!", removed))
            ns:ShowStatusToast(string.format("Cleared %d cached profiles", removed))
        else
            confirmClearCacheUntil = now + 4
            self:SetText("|cfff28b82Confirm Wipe?|r")
            if C_Timer and C_Timer.After then
                C_Timer.After(4.1, function()
                    if p7.clearCacheBtn then p7.clearCacheBtn:SetText("Clear Profile Cache") end
                end)
            end
        end
    end)

    p7.logEditor = ns:CreateScrollableTextEditor(p7, "Network & wire logs appear here when Debug Events or Wire Sniffer are checked...", 16, -104, 624, 240)
    p7.logEditor:SetPoint("BOTTOMRIGHT", p7, "BOTTOMRIGHT", -16, 14)

    -- FOOTER
    local footer = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    footer:SetHeight(26)
    footer:SetPoint("BOTTOMLEFT", 12, 10)
    footer:SetPoint("BOTTOMRIGHT", -34, 10)
    ns:ApplySurface(footer, M3.surfaceLow, M3.outline)
    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footerText:SetPoint("LEFT", 14, 0)
    footerText:SetText("|cff8ab4f8[LB]/[RB]|r Tabs   |cff8ab4f8[D-Pad]|r Move Focus   |cff8ab4f8[A]|r Edit/Confirm   |cff8ab4f8[B]|r Back/Close")
    mainFrame.statusToast = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.statusToast:SetPoint("RIGHT", -14, 0)
    mainFrame.statusToast:SetText("|cff9aa0a6Saved in PadRPDB|r")

    local resizeGrip = CreateFrame("Button", "PadRP_ResizeGrip", mainFrame, "BackdropTemplate")
    resizeGrip:SetSize(20, 26)
    resizeGrip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
    ns:ApplySurface(resizeGrip, M3.surfaceHigh, M3.outline)
    local gripLabel = resizeGrip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    gripLabel:SetPoint("CENTER", 0, 0)
    gripLabel:SetText("//")
    resizeGrip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then mainFrame:StartSizing("BOTTOMRIGHT") end end)
    resizeGrip:SetScript("OnMouseUp", function() mainFrame:StopMovingOrSizing(); ns:RefreshControllerUI() end)

    ns:LoadProfileIntoUI()
    ns:SelectTab(1)

    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        ConsolePort:AddInterfaceCursorFrame("PadRP_MainFrame")
    end
end