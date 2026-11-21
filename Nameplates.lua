local _, ns = ...

local plateState = setmetatable({}, { __mode = "k" })

local SOLID_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local STANDING_COLORS = {
    Ally         = { 0.00, 0.90, 1.00, 1.00 },
    Friendly     = { 0.18, 0.95, 0.50, 1.00 },
    Neutral      = { 0.36, 0.68, 1.00, 1.00 },
    Acquaintance = { 0.58, 0.55, 1.00, 1.00 },
    Marked       = { 1.00, 0.80, 0.12, 1.00 },
    Unfriendly   = { 1.00, 0.45, 0.10, 1.00 },
    Rival        = { 1.00, 0.16, 0.35, 1.00 },
}

local WALKUP_PIP = {
    WELCOME = " |cff81c995*|r",
    ASK     = " |cfffdd663?|r",
    CLOSED  = " |cfff28b82x|r",
}

local function StripColorCodes(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function NormalizeKey(k)
    return string.lower(strtrim(tostring(k or "")))
end

local function IsICOOCEnabled(ui)
    if not ui then return false end
    if ui.nameplateStatusTags ~= nil then
        return ui.nameplateStatusTags ~= false
    end
    return true
end

local function IsStandingCircleEnabled(ui)
    if not ui then return false end
    if ui.nameplateStandingCircle ~= nil then
        return ui.nameplateStandingCircle ~= false
    end
    return true
end

local function GetStandingColor(standingName)
    if not standingName or standingName == "" or standingName == "None" then
        return nil
    end
    if STANDING_COLORS[standingName] then
        return STANDING_COLORS[standingName]
    end
    local lower = string.lower(strtrim(tostring(standingName)))
    for k, col in pairs(STANDING_COLORS) do
        if string.lower(k) == lower then
            return col
        end
    end
    return nil
end

local function ResolveStanding(key, unit)
    local notes = ns.db and ns.db.notes
    if type(notes) ~= "table" then return nil end

    if key and type(notes[key]) == "table" and notes[key].standing and notes[key].standing ~= "None" then
        return notes[key].standing
    end

    local targets = {}
    if key and key ~= "" then
        targets[NormalizeKey(key)] = true
        local shortK = strsplit("-", NormalizeKey(key))
        if shortK and shortK ~= "" then targets[shortK] = true end
    end
    if unit and UnitExists(unit) then
        local uName, uRealm = UnitName(unit)
        if uName and uName ~= "" then
            targets[NormalizeKey(uName)] = true
            if uRealm and uRealm ~= "" then
                targets[NormalizeKey(uName .. "-" .. uRealm)] = true
            end
        end
    end

    for noteKey, rec in pairs(notes) do
        if type(rec) == "table" and rec.standing and rec.standing ~= "None" then
            local nk = NormalizeKey(noteKey)
            local nShort = strsplit("-", nk)
            if targets[nk] or (nShort and targets[nShort]) then
                return rec.standing
            end
        end
    end

    return nil
end

local function GetNameFontString(nameplate)
    if not nameplate then return nil end
    local uf = nameplate.UnitFrame
    if uf and uf.name then return uf.name end
    if nameplate.name and nameplate.name.SetText then return nameplate.name end
    return nil
end

local function GetHealthBarFrame(nameplate)
    if not nameplate then return nil end
    local uf = nameplate.UnitFrame
    if uf then
        if uf.healthBar and uf.healthBar:IsShown() then return uf.healthBar end
        if uf.HealthBarsContainer and uf.HealthBarsContainer:IsShown() then return uf.HealthBarsContainer end
    end
    if nameplate.healthBar and nameplate.healthBar:IsShown() then return nameplate.healthBar end
    return nil
end

local function GetOrCreateSideBadge(nameplate, state)
    if state.sideBadge then return state.sideBadge end

    local badge = CreateFrame("Frame", nil, nameplate, "BackdropTemplate")
    badge:SetHeight(14)
    badge:SetWidth(34)
    badge:SetBackdrop(SOLID_BACKDROP)
    badge:SetBackdropColor(0.05, 0.06, 0.08, 0.90)
    badge:SetBackdropBorderColor(0.22, 0.26, 0.34, 0.90)
    badge:SetFrameStrata("LOW")

    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.text:SetPoint("CENTER", 0, 0)
    badge.text:SetJustifyH("CENTER")
    badge.text:SetWordWrap(false)

    state.sideBadge = badge
    return badge
end

local function GetOrCreateStandingDot(nameplate, state)
    if state.standingDot then return state.standingDot end

    local dot = nameplate:CreateTexture(nil, "OVERLAY")
    dot:SetSize(10, 10)
    dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    dot:Hide()

    state.standingDot = dot
    return dot
end

local function RestoreNameplateDefault(nameplate, unit)
    if not nameplate then return end
    local state = plateState[nameplate]
    if not state then return end

    if state.sideBadge then state.sideBadge:Hide() end
    if state.standingDot then state.standingDot:Hide() end

    local nameFS = GetNameFontString(nameplate)
    if nameFS and state.styled then
        local rawName = (unit and UnitExists(unit) and UnitName(unit)) or state.origText
        if rawName and rawName ~= "" then
            nameFS:SetText(rawName)
        end
        if state.origR and state.origG and state.origB then
            nameFS:SetTextColor(state.origR, state.origG, state.origB)
        else
            nameFS:SetTextColor(1, 1, 1)
        end
        state.styled = false
    end
end

local function StyleFriendlyNameplateInternal(unit)
    if not unit or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    if not string.find(unit, "^nameplate%d+$") then return end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return end

    if nameplate.padRPBadge then
        nameplate.padRPBadge:Hide()
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) or UnitIsUnit(unit, "player") then
        RestoreNameplateDefault(nameplate, unit)
        return
    end

    local ui = ns.db and ns.db.ui
    if not ui or (InCombatLockdown() and ui.hideInCombat) then
        RestoreNameplateDefault(nameplate, unit)
        return
    end

    local nameFS = GetNameFontString(nameplate)
    local healthBar = GetHealthBarFrame(nameplate)

    local state = plateState[nameplate]
    if not state then
        local r, g, b = 1, 1, 1
        if nameFS then r, g, b = nameFS:GetTextColor() end
        state = {
            origText = UnitName(unit) or (nameFS and nameFS:GetText()) or "",
            origR = r or 1,
            origG = g or 1,
            origB = b or 1,
            styled = false,
        }
        plateState[nameplate] = state
    else
        state.origText = UnitName(unit) or state.origText
    end

    local _, classFile = UnitClass(unit)
    local classColor = (classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
        or { r = 0.54, g = 0.71, b = 0.97, colorStr = "ff8ab4f8" }
    local classHex = classColor.colorStr or string.format("ff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)

    local data, key = ns:GetCachedMSP(unit)
    local cleanRPName = (data and data.NA) and StripColorCodes(strtrim(data.NA)) or ""
    local hasProfile = (cleanRPName ~= "")
    local isIC = hasProfile and (data.FC == "2")

    if nameFS then
        local displayName = (ui.nameplateRPNames and hasProfile) and cleanRPName or (UnitName(unit) or state.origText)
        local nameHex = "ffffffff"

        if ui.nameplateClassColors then
            nameHex = classHex
            nameFS:SetTextColor(classColor.r, classColor.g, classColor.b)
        elseif hasProfile then
            if isIC then
                nameHex = "ff81c995"
                nameFS:SetTextColor(0.51, 0.79, 0.58)
            else
                nameHex = "fff28b82"
                nameFS:SetTextColor(0.95, 0.55, 0.51)
            end
        else
            nameFS:SetTextColor(state.origR, state.origG, state.origB)
        end

        if nameFS.SetWordWrap then nameFS:SetWordWrap(false) end
        nameFS:SetText(string.format("|c%s%s|r", nameHex, displayName))
        state.styled = true
    end

    -- 1. Independent OOC | IC badge toggle
    local showICOOC = IsICOOCEnabled(ui)
    local badgeShown = false
    local badge = state.sideBadge

    if showICOOC and hasProfile then
        badge = GetOrCreateSideBadge(nameplate, state)
        badge:ClearAllPoints()
        if healthBar then
            badge:SetPoint("RIGHT", healthBar, "LEFT", -5, 0)
        elseif nameFS and nameFS:IsShown() then
            badge:SetPoint("RIGHT", nameFS, "LEFT", -5, 0)
        else
            badge:SetPoint("LEFT", nameplate, "LEFT", 0, 0)
        end

        local _, wuCode = ns:GetTargetWalkUpInfo(data)
        local wuPip = (wuCode and WALKUP_PIP[wuCode]) or ""

        if isIC then
            badge.text:SetText("|cff81c995IC|r" .. wuPip)
            badge:SetBackdropBorderColor(0.51, 0.79, 0.58, 0.90)
        else
            badge.text:SetText("|cfff28b82OOC|r" .. wuPip)
            badge:SetBackdropBorderColor(0.95, 0.55, 0.51, 0.90)
        end

        local textW = badge.text:GetStringWidth() or 22
        badge:SetWidth(math.max(28, textW + 10))
        badge:Show()
        badgeShown = true
    elseif state.sideBadge then
        state.sideBadge:Hide()
    end

    -- 2. Independent Standing Circle toggle
    local showStandingCircle = IsStandingCircleEnabled(ui)
    local standing = showStandingCircle and ResolveStanding(key, unit) or nil
    local dotColor = GetStandingColor(standing)

    if showStandingCircle and dotColor then
        local dot = GetOrCreateStandingDot(nameplate, state)
        dot:ClearAllPoints()
        if badgeShown and badge then
            dot:SetPoint("BOTTOM", badge, "TOP", 0, 2)
        elseif healthBar then
            dot:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", 0, 3)
        elseif nameFS and nameFS:IsShown() then
            dot:SetPoint("BOTTOM", nameFS, "TOP", 0, 2)
        else
            dot:SetPoint("TOP", nameplate, "TOP", 0, 0)
        end
        dot:SetVertexColor(dotColor[1], dotColor[2], dotColor[3], dotColor[4])
        dot:Show()
    elseif state.standingDot then
        state.standingDot:Hide()
    end
end

function ns:StyleFriendlyNameplate(unit)
    pcall(StyleFriendlyNameplateInternal, unit)
end

function ns:RefreshAllNameplates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame.unit)
        if unit then
            ns:StyleFriendlyNameplate(unit)
        end
    end
end

function ns:InitNameplates()
    local npFrame = CreateFrame("Frame")
    npFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    npFrame:RegisterEvent("UNIT_NAME_UPDATE")
    npFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    npFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    npFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_NAME_UPDATE" then
            ns:StyleFriendlyNameplate(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" and unit and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local np = C_NamePlate.GetNamePlateForUnit(unit)
            if np then
                RestoreNameplateDefault(np, unit)
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            ns:RefreshAllNameplates()
        end
    end)

    if type(hooksecurefunc) == "function" and type(_G.CompactUnitFrame_UpdateName) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
            local unit = frame.unit or frame.displayedUnit
            if unit and string.find(unit, "^nameplate%d+$") then
                ns:StyleFriendlyNameplate(unit)
            end
        end)
    end

    ns:RefreshAllNameplates()
end