local addonName, ns = ...
ns.AddonName = addonName

BINDING_HEADER_PADRP = "PadRP (Controller)"
BINDING_NAME_CLICK_PadRP_ToggleUIButton_LeftButton = "Open / Close PadRP Menu"
BINDING_NAME_CLICK_PadRP_QuickThankButton_LeftButton = "Quick Thank Target / Last Helper"
BINDING_NAME_CLICK_PadRP_InspectTargetButton_LeftButton = "Inspect Target RP & Action Deck"
BINDING_NAME_CLICK_PadRP_ToggleICButton_LeftButton = "Toggle IC / OOC Status"
BINDING_NAME_CLICK_PadRP_CycleWalkUpButton_LeftButton = "Cycle Walk-Up RP Flag (Open / Ask / Closed)"
BINDING_NAME_CLICK_PadRP_ToggleWalkButton_LeftButton = "Toggle RP Walk / Run Speed"
BINDING_NAME_CLICK_PadRP_DoSitButton_LeftButton = "RP Sit / Rest (/sit)"

local defaultSettings = {
    ui = {
        scale = 1.0,
        width = 680,
        height = 560,
        showTargetHUD = true,
        rpTooltip = true,
        nameplateClassColors = true,
        nameplateStatusTags = true,
        nameplateStandingCircle = true,
        nameplateRPNames = true,
        devMode = false,
        hudOnlyRP = false,
        hideInCombat = true,
        soundEffects = true,
        showMinimap = true,
        chatRPNames = true,
        autoAFKOOC = true,
        minimapIcon = {
            hide = false,
            minimapPos = 215,
        },
    },
    gratitude = {
        mode = "SMART",
        cooldown = 60,
        oncePerSession = false,
        thankBuffs = true,
        thankHeals = true,
        minHealPercent = 15,
        thankRes = true,
        thankSpecial = true,
        ignoreParty = false,
        useRPNames = true,
        icPhrases = {
            "nods respectfully to %name, grateful for the %spell.",
            "offers %name a quiet word of thanks for their %spell.",
            "inclines their head toward %name in appreciation of the %spell.",
        },
        oocPhrases = {
            "Thanks for the %spell, %name!",
            "Appreciate the %spell, %name - safe travels!",
            "Cheers for the %spell, %name!",
        },
        resPhrases = {
            "draws a sharp breath as %name's %spell pulls them back from the brink.",
            "steadies themselves and offers %name a deeply grateful nod for the %spell.",
        },
        summonPhrases = {
            "steps through the swirling rift, nodding to %name in thanks for the %spell.",
            "brushes off the planar dust and thanks %name for the %spell.",
        },
        specialPhrases = {
            "accepts the %spell with a grateful nod toward %name.",
            "raises a hand in thanks to %name for the timely %spell.",
        },
    },
    currentlyPresets = {
        "Available for walk-up RP.",
        "Traveling the road.",
        "Resting at the tavern.",
        "Deep in thought.",
        "Looking for work / contracts.",
        "Busy / In combat.",
    },
}

local DEFAULT_GLANCE_ICONS = {
    "INV_Misc_Book_09",
    "INV_Sword_04",
    "INV_Jewelry_Ring_03",
    "INV_Scroll_02",
    "INV_Misc_Lantern_01",
}

local WALKUP_ORDER = { "WELCOME", "ASK", "CLOSED" }
local WALKUP_LABELS = {
    WELCOME = "Walk-Ups Welcome",
    ASK     = "Ask / Whisper First",
    CLOSED  = "No Walk-Ups (Closed)",
}

local RELATIONSHIP_ORDER = { "0", "1", "2", "3", "4", "5" }
local RELATIONSHIP_LABELS = {
    ["0"] = "Not Specified",
    ["1"] = "Single",
    ["2"] = "Taken",
    ["3"] = "Married",
    ["4"] = "Divorced",
    ["5"] = "Widowed",
}

local RPSTYLE_ORDER = { "1", "2", "3", "4" }
local RPSTYLE_LABELS = {
    ["0"] = "Not Specified",
    ["1"] = "Normal",
    ["2"] = "Casual",
    ["3"] = "Full-Time",
    ["4"] = "Newcomer / Beginner",
}

local function SanitizeFontText(str)
    if type(str) ~= "string" then return str end
    str = string.gsub(str, "\226\128\148", "-")
    str = string.gsub(str, "\226\128\147", "-")
    str = string.gsub(str, "\226\128\162", "*")
    return str
end

local function SanitizeList(list)
    if type(list) ~= "table" then return end
    for i, val in ipairs(list) do
        list[i] = SanitizeFontText(val)
    end
end

local function CopyTableShallow(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            copy[k] = CopyTableShallow(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function ns:GetPlayerCharKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = string.gsub(GetRealmName() or "Realm", "%s+", "")
    end
    if not name or name == "" or name == "Unknown" then
        return "DefaultPlayer-" .. realm
    end
    return name .. "-" .. realm
end

function ns:CreateBlankProfile(profileName)
    return {
        profileName = profileName or "Main Character",
        icon = "INV_Helmet_46",
        titlePrefix = "",
        firstName = UnitName("player") or "Adventurer",
        lastName = "",
        title = "",
        nickname = "",
        houseName = "",
        motto = "",
        pronouns = "",
        race = "",
        class = "",
        age = "",
        height = "",
        weight = "",
        eyeColor = "",
        birthplace = "",
        residence = "",
        relationship = "0",
        rpStyle = "1",
        currently = "Available for walk-up RP.",
        oocInfo = "Playing on controller via PadRP.",
        description = "",
        history = "",
        glances = {
            { icon = DEFAULT_GLANCE_ICONS[1], title = "", detail = "" },
            { icon = DEFAULT_GLANCE_ICONS[2], title = "", detail = "" },
            { icon = DEFAULT_GLANCE_ICONS[3], title = "", detail = "" },
            { icon = DEFAULT_GLANCE_ICONS[4], title = "", detail = "" },
            { icon = DEFAULT_GLANCE_ICONS[5], title = "", detail = "" },
        },
        isIC = true,
        walkUp = "WELCOME",
        presetIndex = 1,
    }
end

local function EnsureProfileStructure(p)
    if type(p) ~= "table" then return end
    p.profileName  = p.profileName or "Main Character"
    p.icon         = (p.icon and p.icon ~= "") and p.icon or "INV_Helmet_46"
    p.titlePrefix  = p.titlePrefix or ""
    p.firstName    = p.firstName or (UnitName("player") or "")
    p.lastName     = p.lastName or ""
    p.title        = p.title or ""
    p.nickname     = p.nickname or ""
    p.houseName    = p.houseName or ""
    p.motto        = p.motto or ""
    p.pronouns     = p.pronouns or ""
    p.race         = p.race or ""
    p.class        = p.class or ""
    p.age          = p.age or ""
    p.height       = p.height or ""
    p.weight       = p.weight or ""
    p.eyeColor     = p.eyeColor or ""
    p.birthplace   = p.birthplace or ""
    p.residence    = p.residence or ""
    p.relationship = RELATIONSHIP_LABELS[tostring(p.relationship or "0")] and tostring(p.relationship) or "0"
    p.rpStyle      = RPSTYLE_LABELS[tostring(p.rpStyle or "1")] and tostring(p.rpStyle) or "1"
    p.currently    = SanitizeFontText(p.currently or "")
    p.oocInfo      = p.oocInfo or ""
    p.description  = p.description or ""
    p.history      = p.history or ""
    if p.isIC == nil then p.isIC = true end
    if p.walkUp ~= "WELCOME" and p.walkUp ~= "ASK" and p.walkUp ~= "CLOSED" then
        p.walkUp = "WELCOME"
    end
    p.glances = p.glances or {}
    for i = 1, 5 do
        p.glances[i] = p.glances[i] or { icon = DEFAULT_GLANCE_ICONS[i], title = "", detail = "" }
        p.glances[i].icon   = p.glances[i].icon or DEFAULT_GLANCE_ICONS[i]
        p.glances[i].title  = p.glances[i].title or ""
        p.glances[i].detail = p.glances[i].detail or ""
    end
end

local function ProfileHasContent(p)
    if type(p) ~= "table" then return false end
    if (p.lastName and p.lastName ~= "")
        or (p.titlePrefix and p.titlePrefix ~= "")
        or (p.title and p.title ~= "")
        or (p.houseName and p.houseName ~= "")
        or (p.nickname and p.nickname ~= "")
        or (p.motto and p.motto ~= "")
        or (p.birthplace and p.birthplace ~= "")
        or (p.residence and p.residence ~= "")
        or (p.description and p.description ~= "")
        or (p.history and p.history ~= "")
        or (p.age and p.age ~= "") then
        return true
    end
    if type(p.glances) == "table" then
        for i = 1, 5 do
            if p.glances[i] and ((p.glances[i].title and p.glances[i].title ~= "") or (p.glances[i].detail and p.glances[i].detail ~= "")) then
                return true
            end
        end
    end
    return false
end

function ns:SnapshotActiveProfile()
    if not ns.db or not ns.profile or not ns.activeProfileId then return end
    ns.db.profileBackups = ns.db.profileBackups or {}
    if ProfileHasContent(ns.profile) then
        ns.db.profileBackups[ns.activeProfileId] = CopyTableShallow(ns.profile)
    end
end

function ns:GetWalkUpLabel(code)
    return WALKUP_LABELS[code or (ns.profile and ns.profile.walkUp) or "WELCOME"] or "Walk-Ups Welcome"
end

function ns:CycleWalkUpStatus()
    if not ns.profile then return "WELCOME" end
    local cur = ns.profile.walkUp or "WELCOME"
    local nextIdx = 1
    for i, code in ipairs(WALKUP_ORDER) do
        if code == cur then
            nextIdx = (i % #WALKUP_ORDER) + 1
            break
        end
    end
    ns.profile.walkUp = WALKUP_ORDER[nextIdx]
    ns:SnapshotActiveProfile()
    if ns.SyncMSP then ns:SyncMSP() end
    return ns.profile.walkUp
end

function ns:GetRelationshipLabel(code)
    local key = tostring(code or (ns.profile and ns.profile.relationship) or "0")
    return RELATIONSHIP_LABELS[key] or "Not Specified"
end

function ns:CycleRelationshipStatus()
    if not ns.profile then return "0" end
    local cur = tostring(ns.profile.relationship or "0")
    local nextIdx = 1
    for i, code in ipairs(RELATIONSHIP_ORDER) do
        if code == cur then
            nextIdx = (i % #RELATIONSHIP_ORDER) + 1
            break
        end
    end
    ns.profile.relationship = RELATIONSHIP_ORDER[nextIdx]
    ns:SnapshotActiveProfile()
    if ns.SyncMSP then ns:SyncMSP() end
    return ns.profile.relationship
end

function ns:GetRPStyleLabel(code)
    local key = tostring(code or (ns.profile and ns.profile.rpStyle) or "1")
    return RPSTYLE_LABELS[key] or "Normal"
end

function ns:CycleRPStyle()
    if not ns.profile then return "1" end
    local cur = tostring(ns.profile.rpStyle or "1")
    local nextIdx = 1
    for i, code in ipairs(RPSTYLE_ORDER) do
        if code == cur then
            nextIdx = (i % #RPSTYLE_ORDER) + 1
            break
        end
    end
    ns.profile.rpStyle = RPSTYLE_ORDER[nextIdx]
    ns:SnapshotActiveProfile()
    if ns.SyncMSP then ns:SyncMSP() end
    return ns.profile.rpStyle
end

local function DeepMergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            if #v > 0 then
                if #target[k] == 0 then
                    for i, item in ipairs(v) do
                        target[k][i] = item
                    end
                end
            else
                DeepMergeDefaults(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function ns:PlayUISound(soundId)
    if ns.db and ns.db.ui and ns.db.ui.soundEffects and PlaySound then
        local id = soundId or (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856
        pcall(PlaySound, id)
    end
end

function ns:FormatTokens(template, targetRawName, spellName)
    local firstName = ns:GetUnitRPName(targetRawName, true)
    local fullName = ns:GetUnitRPName(targetRawName, false)
    local classStr = "traveler"
    local raceStr = "stranger"

    if UnitExists(targetRawName) then
        classStr = UnitClass(targetRawName) or classStr
        raceStr = UnitRace(targetRawName) or raceStr
    else
        local short = strsplit("-", targetRawName or "")
        if UnitExists(short) then
            classStr = UnitClass(short) or classStr
            raceStr = UnitRace(short) or raceStr
        end
    end

    local out = template or "thanks %name for the %spell."
    out = string.gsub(out, "%%fullname", fullName)
    out = string.gsub(out, "%%name", firstName)
    out = string.gsub(out, "%%spell", spellName or "aid")
    out = string.gsub(out, "%%class", classStr)
    out = string.gsub(out, "%%race", raceStr)
    return SanitizeFontText(out)
end

local function EscapeField(str)
    str = tostring(str or "")
    str = string.gsub(str, "~", " ")
    str = string.gsub(str, "\n", "\\n")
    return str
end

local function UnescapeField(str)
    str = tostring(str or "")
    str = string.gsub(str, "\\n", "\n")
    return str
end

function ns:ExportCurrentProfileString()
    local p = ns.profile
    if not p then return "" end
    local g1 = p.glances[1] or {}
    local g2 = p.glances[2] or {}
    local g3 = p.glances[3] or {}
    local g4 = p.glances[4] or {}
    local g5 = p.glances[5] or {}
    local parts = {
        "PADRP5",
        EscapeField(p.profileName),
        EscapeField(p.firstName),
        EscapeField(p.lastName),
        EscapeField(p.title),
        EscapeField(p.houseName),
        EscapeField(p.race),
        EscapeField(p.class),
        EscapeField(p.age),
        EscapeField(p.height),
        EscapeField(p.weight),
        EscapeField(p.eyeColor),
        EscapeField(p.currently),
        EscapeField(p.oocInfo),
        EscapeField(g1.icon), EscapeField(g1.title), EscapeField(g1.detail),
        EscapeField(g2.icon), EscapeField(g2.title), EscapeField(g2.detail),
        EscapeField(g3.icon), EscapeField(g3.title), EscapeField(g3.detail),
        EscapeField(p.description),
        EscapeField(p.history),
        EscapeField(p.walkUp or "WELCOME"),
        EscapeField(p.icon or "INV_Helmet_46"),
        EscapeField(p.titlePrefix),
        EscapeField(p.nickname),
        EscapeField(p.motto),
        EscapeField(p.pronouns),
        EscapeField(p.birthplace),
        EscapeField(p.residence),
        EscapeField(p.relationship or "0"),
        EscapeField(p.rpStyle or "1"),
        EscapeField(g4.icon), EscapeField(g4.title), EscapeField(g4.detail),
        EscapeField(g5.icon), EscapeField(g5.title), EscapeField(g5.detail),
    }
    return table.concat(parts, "~")
end

function ns:ImportProfileString(raw)
    if type(raw) ~= "string" then
        return false, "Invalid PadRP profile string."
    end
    local isV5 = string.find(raw, "^PADRP5~") ~= nil
    local isV4 = string.find(raw, "^PADRP4~") ~= nil
    if not isV5 and not isV4 then
        return false, "Invalid PadRP v4/v5 profile string."
    end

    local fields = { strsplit("~", raw) }
    local id = "prof_" .. time() .. "_" .. math.random(100, 999)
    local np = ns:CreateBlankProfile(UnescapeField(fields[2] or "Imported Profile"))
    np.firstName   = UnescapeField(fields[3])
    np.lastName    = UnescapeField(fields[4])
    np.title       = UnescapeField(fields[5])
    np.houseName   = UnescapeField(fields[6])
    np.race        = UnescapeField(fields[7])
    np.class       = UnescapeField(fields[8])
    np.age         = UnescapeField(fields[9])
    np.height      = UnescapeField(fields[10])
    np.weight      = UnescapeField(fields[11])
    np.eyeColor    = UnescapeField(fields[12])
    np.currently   = UnescapeField(fields[13])
    np.oocInfo     = UnescapeField(fields[14])
    np.glances[1]  = { icon = UnescapeField(fields[15] or DEFAULT_GLANCE_ICONS[1]), title = UnescapeField(fields[16]), detail = UnescapeField(fields[17]) }
    np.glances[2]  = { icon = UnescapeField(fields[18] or DEFAULT_GLANCE_ICONS[2]), title = UnescapeField(fields[19]), detail = UnescapeField(fields[20]) }
    np.glances[3]  = { icon = UnescapeField(fields[21] or DEFAULT_GLANCE_ICONS[3]), title = UnescapeField(fields[22]), detail = UnescapeField(fields[23]) }
    np.description = UnescapeField(fields[24])
    np.history     = UnescapeField(fields[25])
    np.walkUp      = UnescapeField(fields[26] or "WELCOME")

    if isV5 then
        np.icon         = UnescapeField(fields[27] or "INV_Helmet_46")
        np.titlePrefix  = UnescapeField(fields[28])
        np.nickname     = UnescapeField(fields[29])
        np.motto        = UnescapeField(fields[30])
        np.pronouns     = UnescapeField(fields[31])
        np.birthplace   = UnescapeField(fields[32])
        np.residence    = UnescapeField(fields[33])
        np.relationship = UnescapeField(fields[34] or "0")
        np.rpStyle      = UnescapeField(fields[35] or "1")
        np.glances[4]   = { icon = UnescapeField(fields[36] or DEFAULT_GLANCE_ICONS[4]), title = UnescapeField(fields[37]), detail = UnescapeField(fields[38]) }
        np.glances[5]   = { icon = UnescapeField(fields[39] or DEFAULT_GLANCE_ICONS[5]), title = UnescapeField(fields[40]), detail = UnescapeField(fields[41]) }
    end

    EnsureProfileStructure(np)
    ns.db.profiles[id] = np
    ns:SwitchProfile(id)
    ns:SnapshotActiveProfile()
    return true, np.profileName
end

function ns:SwitchProfile(profileId)
    if not ns.db.profiles[profileId] then return end
    local charKey = ns:GetPlayerCharKey()
    ns.db.activeProfileByChar[charKey] = profileId
    ns.activeProfileId = profileId
    ns.profile = ns.db.profiles[profileId]
    EnsureProfileStructure(ns.profile)
    if ns.LoadProfileIntoUI then ns:LoadProfileIntoUI() end
    if ns.SyncMSP then ns:SyncMSP() end
    if ns.RefreshControllerUI then ns:RefreshControllerUI() end
    if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
end

function ns:CreateNewProfile()
    local id = "prof_" .. time() .. "_" .. math.random(100, 999)
    local count = 1
    for _ in pairs(ns.db.profiles) do count = count + 1 end
    ns.db.profiles[id] = ns:CreateBlankProfile("Profile #" .. count)
    ns:SwitchProfile(id)
    print("|cff8ab4f8[PadRP]|r Created and switched to |cfffdd663" .. ns.profile.profileName .. "|r.")
end

function ns:CycleProfile(delta)
    local ids = {}
    for id in pairs(ns.db.profiles) do table.insert(ids, id) end
    table.sort(ids)
    if #ids <= 1 then return end

    local curIdx = 1
    for i, id in ipairs(ids) do
        if id == ns.activeProfileId then curIdx = i break end
    end
    local nextIdx = ((curIdx - 1 + (delta or 1)) % #ids) + 1
    ns:SwitchProfile(ids[nextIdx])
    ns:PlayUISound()
end

function ns:DeleteCurrentProfile()
    local ids = {}
    for id in pairs(ns.db.profiles) do table.insert(ids, id) end
    if #ids <= 1 then
        print("|cfff28b82[PadRP]|r Cannot delete your only profile.")
        return
    end
    local oldId = ns.activeProfileId
    ns:CycleProfile(1)
    ns.db.profiles[oldId] = nil
    ns:RefreshControllerUI()
end

function ns:CreateBindButton(name, onClick)
    if type(name) ~= "string" or name == "" then
        error("PadRP: CreateBindButton requires a non-empty global button name.")
    end
    if type(onClick) ~= "function" then
        error("PadRP: CreateBindButton requires an OnClick callback for " .. name)
    end

    local btn = _G[name] or CreateFrame("Button", name, UIParent)
    btn:RegisterForClicks("AnyUp")

    local lastFire = 0
    btn:SetScript("OnClick", function(self, button)
        local now = (GetTime and GetTime()) or 0
        if (now - lastFire) < 0.12 then
            return
        end

        lastFire = now
        onClick(self, button)
    end)

    return btn
end

local function InitRPChatFilter()
    if ns._rpNameChatFilterInstalled then return end
    ns._rpNameChatFilterInstalled = true

    local function RPChatFilter(_, _, msg, author, ...)
        if not ns.db or not ns.db.ui or not ns.db.ui.chatRPNames then
            return false
        end
        if not author or author == "" then return false end
        local data = ns:GetCachedMSP(author)
        if data and data.NA and data.NA ~= "" then
            local cleanRP = string.gsub(data.NA, "|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local shortAuthor = strsplit("-", author)
            if cleanRP ~= shortAuthor and not string.find(msg, cleanRP, 1, true) then
                local newMsg = "|cff8ab4f8[" .. cleanRP .. "]|r " .. msg
                return false, newMsg, author, ...
            end
        end
        return false
    end

    local chatEvents = {
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_TEXT_EMOTE",
        "CHAT_MSG_EMOTE",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
    }
    for _, ev in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(ev, RPChatFilter)
    end
end

local wasICBeforeAFK = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        PadRPDB = PadRPDB or {}
        DeepMergeDefaults(PadRPDB, defaultSettings)
        PadRPDB.profiles = PadRPDB.profiles or {}
        PadRPDB.profileBackups = PadRPDB.profileBackups or {}
        PadRPDB.activeProfileByChar = PadRPDB.activeProfileByChar or {}
        PadRPDB.notes = PadRPDB.notes or {}
        PadRPDB.mspCache = PadRPDB.mspCache or {}
        ns.db = PadRPDB

        SanitizeList(ns.db.currentlyPresets)
        SanitizeList(ns.db.gratitude.icPhrases)
        SanitizeList(ns.db.gratitude.oocPhrases)
        SanitizeList(ns.db.gratitude.resPhrases)
        SanitizeList(ns.db.gratitude.summonPhrases)
        SanitizeList(ns.db.gratitude.specialPhrases)
    elseif event == "PLAYER_LOGIN" then
        local charKey = ns:GetPlayerCharKey()
        local profId = ns.db.activeProfileByChar[charKey]

        if not profId or not ns.db.profiles[profId] then
            local playerName = UnitName("player") or "Player"
            for savedCharKey, savedProfId in pairs(ns.db.activeProfileByChar) do
                if string.find(savedCharKey, "^" .. playerName .. "%-") and ns.db.profiles[savedProfId] then
                    profId = savedProfId
                    ns.db.activeProfileByChar[charKey] = profId
                    break
                end
            end
        end

        if not profId or not ns.db.profiles[profId] then
            profId = "default_" .. charKey
            ns.db.profiles[profId] = ns:CreateBlankProfile(UnitName("player") or "Main Character")
            ns.db.activeProfileByChar[charKey] = profId
        end

        if not ProfileHasContent(ns.db.profiles[profId]) and ns.db.profileBackups[profId] then
            ns.db.profiles[profId] = CopyTableShallow(ns.db.profileBackups[profId])
        end

        ns.activeProfileId = profId
        ns.profile = ns.db.profiles[profId]
        EnsureProfileStructure(ns.profile)
        ns:SnapshotActiveProfile()

        if ns.InitMSPProtocol then ns:InitMSPProtocol() end
        if ns.InitNameplates then ns:InitNameplates() end
        if ns.InitGratitude then ns:InitGratitude() end
        if ns.InitTargetHUD then ns:InitTargetHUD() end
        if ns.InitControllerUI then ns:InitControllerUI() end
        if ns.InitDossierWindow then ns:InitDossierWindow() end
        if ns.InitFlyoutWheel then ns:InitFlyoutWheel() end
        InitRPChatFilter()

        ns:CreateBindButton("PadRP_ToggleICButton", function()
            local isIC = ns:ToggleICOOC()
            print("|cff8ab4f8[PadRP]|r Status: " .. (isIC and "|cff81c995In Character (IC)|r" or "|cfff28b82Out of Character (OOC)|r"))
            if ns.RefreshControllerUI then ns:RefreshControllerUI() end
            if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
        end)

        ns:CreateBindButton("PadRP_CycleWalkUpButton", function()
            local code = ns:CycleWalkUpStatus()
            print("|cff8ab4f8[PadRP]|r Walk-Up Flag: |cfffdd663" .. ns:GetWalkUpLabel(code) .. "|r")
            if ns.RefreshControllerUI then ns:RefreshControllerUI() end
            if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
        end)

        ns:CreateBindButton("PadRP_DoSitButton", function()
            DoEmote("SIT")
            ns:PlayUISound()
            if ns.ShowStatusToast then ns:ShowStatusToast("Sitting / Resting (/sit)") end
        end)

        ns:CreateBindButton("PadRP_ToggleWalkButton", function()
            if ToggleSheath or MoveForwardStart then
                RunBinding("TOGGLERUN")
            end
            ns:PlayUISound()
        end)

        print("|cff8ab4f8[PadRP]|r RP Suite v1.1 loaded. Profile: |cfffdd663" .. (ns.profile.firstName or UnitName("player")) .. "|r.")
    elseif event == "PLAYER_LOGOUT" then
        ns:SnapshotActiveProfile()
    elseif event == "PLAYER_FLAGS_CHANGED" and arg1 == "player" then
        if not ns.db or not ns.db.ui.autoAFKOOC or not ns.profile then return end
        local isAFK = UnitIsAFK("player")
        if isAFK and ns.profile.isIC then
            wasICBeforeAFK = true
            ns.profile.isIC = false
            if ns.SyncMSP then ns:SyncMSP() end
            if ns.RefreshControllerUI then ns:RefreshControllerUI() end
            if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
            print("|cff8ab4f8[PadRP]|r Auto-switched to |cfff28b82OOC|r while AFK.")
        elseif not isAFK and wasICBeforeAFK then
            wasICBeforeAFK = false
            ns.profile.isIC = true
            if ns.SyncMSP then ns:SyncMSP() end
            if ns.RefreshControllerUI then ns:RefreshControllerUI() end
            if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
            print("|cff8ab4f8[PadRP]|r Welcome back! Restored |cff81c995In Character (IC)|r status.")
        end
    end
end)

-- Unified /padrp and /padtoggle slash command router across all PadRP modules
function ns:HandleSlashCommand(msg)
    local cmd = strtrim(string.lower(msg or ""))

    if cmd == "minimap" then
        if ns.ResetMinimapButton then
            ns:ResetMinimapButton()
        end
    elseif cmd == "wheel" or cmd == "flyout" then
        if ns.ToggleFlyoutWheel then
            ns:ToggleFlyoutWheel()
        end
    elseif cmd == "resetcam" then
        if SlashCmdList["PADRPWHEEL"] then
            SlashCmdList["PADRPWHEEL"]("resetcam")
        end
    elseif cmd == "scan" then
        if ns.ScanNearbyPlayers then
            ns:ScanNearbyPlayers()
        end
    elseif cmd == "clearcache" and ns.ClearMSPCache then
        local removed = ns:ClearMSPCache()
        print(string.format("|cff8ab4f8[PadRP]|r Cleared |cfffdd663%d|r cached RP profiles.", removed))
    elseif cmd == "dev" or cmd == "console" or cmd == "debug" or cmd == "sniff" then
        if ns.db and ns.db.ui then
            ns.db.ui.devMode = true
        end
        if cmd == "debug" or cmd == "dev" then ns.mspDebug = true end
        if cmd == "sniff" then ns.mspSniff = true; ns.mspDebug = true end
        if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshControllerUI then
            ns:RefreshControllerUI()
        end
        if ns.ToggleNetInspector then
            ns:ToggleNetInspector(true)
        end
    elseif cmd == "test" then
        if ns.db and ns.db.ui then
            ns.db.ui.devMode = true
        end
        if ns.mainFrame and ns.mainFrame:IsShown() and ns.RefreshControllerUI then
            ns:RefreshControllerUI()
        end
        if ns.ToggleNetInspector then
            ns:ToggleNetInspector(true)
        end
        if ns.RunMSPSelfTest then
            ns:RunMSPSelfTest()
        end
    else
        if ns.ToggleMainFrame then
            ns:ToggleMainFrame()
        end
    end
end

SLASH_PADRP1 = "/padrp"
SLASH_PADRP2 = "/padtoggle"
SlashCmdList["PADRP"] = function(msg)
    ns:HandleSlashCommand(msg)
end