local _, ns = ...

local plateState = setmetatable({}, { __mode = "k" })

local SOLID_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- 7 distinct individual standing colors
local STANDING_COLORS_7 = {
    Ally         = { 0.00, 0.92, 0.95, 1.00 }, -- Bright Cyan
    Friendly     = { 0.22, 0.96, 0.45, 1.00 }, -- Spring Mint
    Neutral      = { 0.38, 0.65, 1.00, 1.00 }, -- Cornflower Blue
    Acquaintance = { 0.72, 0.52, 1.00, 1.00 }, -- Violet
    Marked       = { 1.00, 0.82, 0.10, 1.00 }, -- Bright Gold
    Unfriendly   = { 1.00, 0.46, 0.08, 1.00 }, -- Vivid Orange
    Rival        = { 0.98, 0.14, 0.36, 1.00 }, -- Ruby Crimson
}

-- 4 distinct grouped bucket colors (visually distinct from individual shades)
local BUCKET_COLORS_4 = {
    POSITIVE = { 0.10, 0.82, 0.35, 1.00 }, -- Deep Emerald (Ally, Friendly)
    NEUTRAL  = { 0.25, 0.78, 0.98, 1.00 }, -- Ice Sky Blue (Neutral, Acquaintance)
    MARKED   = { 0.98, 0.68, 0.12, 1.00 }, -- Warm Amber (Marked, custom)
    HOSTILE  = { 0.92, 0.18, 0.18, 1.00 }, -- Alert Red (Unfriendly, Rival)
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

local function RGBToHex(r, g, b)
    return string.format("ff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

local function IsICOOCEnabled(ui)
    if not ui then return true end
    if ui.nameplateStatusTags == false or ui.nameplateICOOC == false then
        return false
    end
    return true
end

function ns:GetNameplateStandingStyle()
    local ui = ns.db and ns.db.ui
    if not ui then return "CIRCLE" end
    if ui.nameplateStandingStyle == "GLYPH" or ui.nameplateStandingStyle == "UNDERLINE" then
        ui.nameplateStandingStyle = "CIRCLE"
    end
    if ui.nameplateStandingStyle then
        return ui.nameplateStandingStyle
    end
    if ui.nameplateStandingCircle == false then
        return "OFF"
    end
    return "CIRCLE"
end

function ns:GetNameplateStandingColorMode()
    local ui = ns.db and ns.db.ui
    if ui and ui.nameplateStandingColorMode == "4BUCKET" then
        return "4BUCKET"
    end
    return "7COLOR"
end

local function GetStandingBucket(standingName)
    local lower = string.lower(strtrim(tostring(standingName or "")))
    if lower == "ally" or lower == "friendly" then
        return "POSITIVE"
    elseif lower == "neutral" or lower == "acquaintance" then
        return "NEUTRAL"
    elseif lower == "unfriendly" or lower == "rival" then
        return "HOSTILE"
    end
    if ns.GetStandingTone then
        local tone = ns:GetStandingTone(standingName)
        if tone == "MINT" then return "POSITIVE"
        elseif tone == "PRIMARY" then return "NEUTRAL"
        elseif tone == "CORAL" then return "HOSTILE"
        end
    end
    return "MARKED"
end

local function GetStandingColor(standingName)
    if not standingName or standingName == "" or standingName == "None" then
        return nil
    end

    local colorMode = ns:GetNameplateStandingColorMode()
    if colorMode == "4BUCKET" then
        local bucket = GetStandingBucket(standingName)
        return BUCKET_COLORS_4[bucket] or BUCKET_COLORS_4.MARKED
    end

    if STANDING_COLORS_7[standingName] then
        return STANDING_COLORS_7[standingName]
    end
    local lower = string.lower(strtrim(tostring(standingName)))
    for k, col in pairs(STANDING_COLORS_7) do
        if string.lower(k) == lower then
            return col
        end
    end

    if ns.GetStandingTone then
        local tone = ns:GetStandingTone(standingName)
        if tone == "MINT" then return STANDING_COLORS_7.Friendly
        elseif tone == "PRIMARY" then return STANDING_COLORS_7.Neutral
        elseif tone == "CORAL" then return STANDING_COLORS_7.Rival
        end
    end
    return STANDING_COLORS_7.Marked
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

local function GetOrCreateStandingPill(nameplate, state)
    if state.standingPill then return state.standingPill end

    local pill = CreateFrame("Frame", nil, nameplate, "BackdropTemplate")
    pill:SetHeight(13)
    pill:SetWidth(42)
    pill:SetBackdrop(SOLID_BACKDROP)
    pill:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
    pill:SetBackdropBorderColor(0.54, 0.71, 0.97, 0.95)
    pill:SetFrameStrata("LOW")
    pill:Hide()

    pill.text = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pill.text:SetPoint("CENTER", 0, 0)
    pill.text:SetJustifyH("CENTER")
    pill.text:SetWordWrap(false)

    state.standingPill = pill
    return pill
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

local function GetOrCreateAccentStripe(nameplate, state)
    if state.accentStripe then return state.accentStripe end

    local stripe = nameplate:CreateTexture(nil, "OVERLAY")
    stripe:SetSize(3, 14)
    stripe:SetTexture("Interface\\Buttons\\WHITE8x8")
    stripe:Hide()

    state.accentStripe = stripe
    return stripe
end

local function HideAllStandingVisuals(state)
    if not state then return end
    if state.standingDot then state.standingDot:Hide() end
    if state.accentStripe then state.accentStripe:Hide() end
    if state.standingPill then state.standingPill:Hide() end
end

local function RestoreNameplateDefault(nameplate, unit)
    if not nameplate then return end
    local state = plateState[nameplate]
    if not state then return end

    if state.sideBadge then state.sideBadge:Hide() end
    HideAllStandingVisuals(state)

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
    if ui and ui.hideInCombat and InCombatLockdown and InCombatLockdown() then
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
    local classHex = classColor.colorStr or RGBToHex(classColor.r, classColor.g, classColor.b)

    local data, key = nil, nil
    if ns.GetCachedMSP then
        local okM, dM, kM = pcall(ns.GetCachedMSP, ns, unit)
        if okM then
            data, key = dM, kM
        end
    end

    local cleanRPName = (data and data.NA) and StripColorCodes(strtrim(data.NA)) or ""
    local hasProfile = (cleanRPName ~= "")
    local isIC = hasProfile and (data.FC == "2")

    local standingStyle = ns:GetNameplateStandingStyle()
    local standing = (standingStyle ~= "OFF") and ResolveStanding(key, unit) or nil
    local standingColor = GetStandingColor(standing)

    local plainDisplayName = UnitName(unit) or state.origText
    if nameFS then
        local useRPName = (not ui or ui.nameplateRPNames ~= false)
        local useClassColor = (not ui or ui.nameplateClassColors ~= false)
        plainDisplayName = (useRPName and hasProfile) and cleanRPName or (UnitName(unit) or state.origText)
        local nameHex = "ffffffff"

        if useClassColor then
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

        local formattedName = string.format("|c%s%s|r", nameHex, plainDisplayName)
        if standingColor and standingStyle == "CHEVRON" then
            local sHex = RGBToHex(standingColor[1], standingColor[2], standingColor[3])
            formattedName = string.format("|c%s>>|r %s |c%s<<|r", sHex, formattedName, sHex)
        end

        if nameFS.SetWordWrap then nameFS:SetWordWrap(false) end
        nameFS:SetText(formattedName)
        state.styled = true
    end

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

        local wuCode = nil
        if ns.GetTargetWalkUpInfo then
            local okW, _, codeW = pcall(ns.GetTargetWalkUpInfo, ns, data)
            if okW then wuCode = codeW end
        end
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

    HideAllStandingVisuals(state)

    if standingColor and standingStyle ~= "OFF" then
        local sr, sg, sb, sa = standingColor[1], standingColor[2], standingColor[3], standingColor[4] or 1.0
        local sHex = RGBToHex(sr, sg, sb)

        if standingStyle == "CIRCLE" then
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
            dot:SetVertexColor(sr, sg, sb, sa)
            dot:Show()

        elseif standingStyle == "STRIPE" then
            local stripe = GetOrCreateAccentStripe(nameplate, state)
            stripe:ClearAllPoints()
            if badgeShown and badge then
                stripe:SetHeight(math.max(14, badge:GetHeight() or 14))
                stripe:SetPoint("RIGHT", badge, "LEFT", -3, 0)
            elseif healthBar then
                stripe:SetHeight(math.max(12, healthBar:GetHeight() or 14))
                stripe:SetPoint("RIGHT", healthBar, "LEFT", -4, 0)
            elseif nameFS and nameFS:IsShown() then
                stripe:SetHeight(14)
                stripe:SetPoint("RIGHT", nameFS, "LEFT", -5, 0)
            else
                stripe:SetPoint("LEFT", nameplate, "LEFT", 0, 0)
            end
            stripe:SetVertexColor(sr, sg, sb, sa)
            stripe:Show()

        elseif standingStyle == "PILL" then
            local pill = GetOrCreateStandingPill(nameplate, state)
            pill:ClearAllPoints()
            if badgeShown and badge then
                pill:SetPoint("BOTTOM", badge, "TOP", 0, 2)
            elseif healthBar then
                pill:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", 0, 2)
            elseif nameFS and nameFS:IsShown() then
                pill:SetPoint("CENTER", nameFS, "CENTER", 0, 12)
            else
                pill:SetPoint("TOP", nameplate, "TOP", 0, 0)
            end
            pill:SetBackdropBorderColor(sr, sg, sb, 0.95)
            pill.text:SetText("|c" .. sHex .. string.upper(tostring(standing)) .. "|r")
            local pw = pill.text:GetStringWidth() or 28
            pill:SetWidth(math.max(34, pw + 8))
            pill:Show()
        end
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
    if ns._nameplatesInitialized then
        ns:RefreshAllNameplates()
        return
    end
    ns._nameplatesInitialized = true

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