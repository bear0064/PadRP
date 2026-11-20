local _, ns = ...

local hudFrame
local ldbObject
local LDBIcon
local fallbackMinimapBtn
local hudDismissedKey = nil

local tooltipState = setmetatable({}, { __mode = "k" })
local isDecoratingTooltip = false

local STANDING_COLORS = {
    Ally         = "|cff81c995[ALLY]|r ",
    Friendly     = "|cff81c995[FRIENDLY]|r ",
    Neutral      = "|cff8ab4f8[NEUTRAL]|r ",
    Unfriendly   = "|cfff28b82[UNFRIENDLY]|r ",
    Rival        = "|cfff28b82[RIVAL]|r ",
    Marked       = "|cfffdd663[MARKED]|r ",
}

local function GetStandingBadgePrefix(standing)
    if not standing or standing == "None" then return "" end
    if STANDING_COLORS[standing] then
        return STANDING_COLORS[standing]
    end
    return "|cfffdd663[" .. string.upper(tostring(standing)) .. "]|r "
end

local function HexToRGB(hex)
    if type(hex) ~= "string" then return nil end
    local clean = hex:gsub("^|c", ""):gsub("^#", "")
    if #clean == 8 then
        clean = clean:sub(3, 8)
    end
    if #clean ~= 6 or not clean:match("^%x%x%x%x%x%x$") then
        return nil
    end
    return tonumber(clean:sub(1, 2), 16) / 255,
           tonumber(clean:sub(3, 4), 16) / 255,
           tonumber(clean:sub(5, 6), 16) / 255
end

local function StripColorCodes(str)
    if not str then return "" end
    local clean = tostring(str):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return clean
end

local function CleanOOCTooltipText(raw)
    if not raw then return "" end
    local clean = strtrim(StripColorCodes(raw))
    clean = clean:gsub("%[Walk%-Ups:[^%]]*%]", "")
    clean = clean:gsub("%[Walk%-Ups Welcome%]", "")
    clean = clean:gsub("%[Walk%-Ups: Ask First%]", "")
    clean = clean:gsub("%[No Walk%-Ups%]", "")
    clean = clean:gsub("%[Pronouns:[^%]]*%]", "")
    clean = clean:gsub("^%s*[•|%-]+%s*", "")
    clean = clean:gsub("%s*[•|%-]+%s*$", "")
    return strtrim(clean)
end

local function BuildTooltipPortraitTag(iconVal)
    local clean = iconVal and strtrim(tostring(iconVal)) or ""
    if clean == "" then return "" end

    local resolved = nil
    if ns.ResolveIconTexture then
        resolved = ns:ResolveIconTexture(clean, nil)
    end

    if type(resolved) == "number" and resolved > 0 then
        return string.format("|T%d:16:16:0:0:64:64:4:60:4:60|t ", resolved)
    elseif type(resolved) == "string" and strtrim(resolved) ~= "" then
        return string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", strtrim(resolved))
    end

    local numId = tonumber(clean)
    if numId and numId > 0 then
        return string.format("|T%d:16:16:0:0:64:64:4:60:4:60|t ", numId)
    end

    local iconPath = string.find(clean, "\\", 1, true) and clean or ("Interface\\Icons\\" .. clean)
    return string.format("|T%s:16:16:0:0:64:64:4:60:4:60|t ", iconPath)
end

local function GetActiveOtherPlayerUnit()
    if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        return "target"
    end
    if UnitExists("mouseover") and UnitIsPlayer("mouseover") and not UnitIsUnit("mouseover", "player") then
        return "mouseover"
    end
    return nil
end

local function IsHardTargetedOtherPlayer()
    return UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player")
end

local function RegisterHUDWithConsolePort()
    if not hudFrame or not ConsolePort then return end
    pcall(function()
        hudFrame:SetAttribute("UIPanelLayout-enabled", true)
        hudFrame:SetAttribute("UIPanelLayout-area", "center")
        if ConsolePort.AddInterfaceCursorFrame then
            ConsolePort:AddInterfaceCursorFrame("PadRP_TargetHUD")
        end
        if ConsolePort.RegisterFrame then
            ConsolePort:RegisterFrame(hudFrame)
        end
    end)
end

function ns:DismissTargetHUDFocus()
    if hudFrame then
        hudDismissedKey = hudFrame.inspectedKey or "__ACTIVE__"
        hudFrame:Hide()
    end
    if ns.SetControllerFocus then
        ns:SetControllerFocus(nil)
    end
    if ns.UpdateControllerBindings then
        ns:UpdateControllerBindings()
    end
end

function ns:GetNoteInfo(key)
    if not key or not ns.db or not ns.db.notes then
        return "None", "", "", false
    end
    local rec = ns.db.notes[key]
    if type(rec) ~= "table" then
        return "None", "", "", false
    end

    local charKey = ns.GetPlayerCharKey and ns:GetPlayerCharKey() or "Default"
    local charNote = (type(rec.charNotes) == "table" and rec.charNotes[charKey]) or ""
    local acctNote = rec.accountNote
    if acctNote == nil then
        acctNote = rec.note or ""
    end

    local hasNote = (strtrim(charNote) ~= "") or (strtrim(acctNote) ~= "")
    return rec.standing or "None", charNote, acctNote, hasNote
end

function ns:HasSavedNote(key)
    local _, _, _, hasNote = ns:GetNoteInfo(key)
    return hasNote
end

local function HandleMinimapClick(button)
    if button == "RightButton" then
        ns:PlayUISound()
        local isIC = ns:ToggleICOOC()
        print("|cff8ab4f8[PadRP]|r Status: " .. (isIC and "|cff81c995In Character (IC)|r" or "|cfff28b82Out of Character (OOC)|r"))
        if ns.RefreshControllerUI then ns:RefreshControllerUI() end
        if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
    elseif button == "MiddleButton" then
        ns:QuickThankAction()
    else
        if ns.ToggleMainFrame then ns:ToggleMainFrame() end
    end
end

local function PopulateMinimapTooltip(tooltip)
    tooltip:AddLine("PadRP - Material Dark RP Suite", 0.54, 0.71, 0.97)
    local status = (ns.profile and ns.profile.isIC) and "|cff81c995In Character (IC)|r" or "|cfff28b82Out of Character (OOC)|r"
    tooltip:AddLine("Status: " .. status, 1, 1, 1)
    tooltip:AddLine("Walk-Ups: |cfffdd663" .. ns:GetWalkUpLabel() .. "|r", 1, 1, 1)
    tooltip:AddLine("Currently: |cffe8eaed" .. ((ns.profile and ns.profile.currently) or "None") .. "|r", 0.8, 0.8, 0.8)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff8ab4f8Left-Click:|r Open PadRP Menu", 0.75, 0.8, 0.88)
    tooltip:AddLine("|cff8ab4f8Right-Click:|r Toggle IC / OOC", 0.75, 0.8, 0.88)
    tooltip:AddLine("|cff8ab4f8Middle-Click:|r Quick-Thank Helper", 0.75, 0.8, 0.88)
    tooltip:AddLine("|cff8ab4f8Drag:|r Move Around Minimap", 0.75, 0.8, 0.88)
end

local function DecorateUnitTooltipInternal(tooltip, tooltipData, skipRequest)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if not ns.db or not ns.db.ui or not ns.db.ui.rpTooltip then return end
    if InCombatLockdown() and ns.db.ui.hideInCombat then return end

    local _, unit = tooltip:GetUnit()
    if (not unit or not UnitExists(unit)) and tooltipData and tooltipData.guid and UnitTokenFromGUID then
        unit = UnitTokenFromGUID(tooltipData.guid)
    end
    if (not unit or not UnitExists(unit)) and UnitExists("mouseover") then
        unit = "mouseover"
    end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local isSelf = UnitIsUnit(unit, "player")
    if not skipRequest and not isSelf and ns.RequestUnitMSP then
        ns:RequestUnitMSP(unit, false, false, true)
    end

    local data, key = ns:GetCachedMSP(unit)
    local standing, charNote, acctNote, hasNote = ns:GetNoteInfo(key)

    if (not data or not data.NA or data.NA == "") and not hasNote and standing == "None" and not isSelf then
        return
    end

    local customIcon = isSelf and (ns.profile and ns.profile.icon) or (data and data.IC)
    local portraitTag = BuildTooltipPortraitTag(customIcon)

    local state = tooltipState[tooltip]
    if state and state.taggedKey == key and state.portraitTag == portraitTag then
        return
    end

    local _, classFile = UnitClass(unit)
    local r, g, b = 0.54, 0.71, 0.97
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        r, g, b = RAID_CLASS_COLORS[classFile].r, RAID_CLASS_COLORS[classFile].g, RAID_CLASS_COLORS[classFile].b
    end
    if isSelf and ns.GetPlayerClassColorCode then
        local cr, cg, cb = HexToRGB(ns:GetPlayerClassColorCode())
        if cr then r, g, b = cr, cg, cb end
    end

    local standingTag = GetStandingBadgePrefix(standing)
    local noteIcon = hasNote and " |TInterface\\Icons\\INV_Misc_Note_01:14:14:0:0:64:64:4:60:4:60|t" or ""

    local tName = tooltip:GetName()
    local line1 = tName and _G[tName .. "TextLeft1"]

    if data and data.NA and data.NA ~= "" then
        local isIC = (data.FC == "2")
        local icFlag = isIC and "|cff81c995[IC]|r" or "|cfff28b82[OOC]|r"
        local wuBadge = ns:GetTargetWalkUpInfo(data)

        local displayName = StripColorCodes(data.NA)
        if data.PX and strtrim(data.PX) ~= "" and not string.find(displayName, strtrim(data.PX), 1, true) then
            displayName = strtrim(data.PX) .. " " .. displayName
        end

        if line1 then
            local rightBadges = wuBadge and (icFlag .. " " .. wuBadge) or icFlag
            line1:SetText(portraitTag .. standingTag .. displayName .. "  " .. rightBadges .. noteIcon)
            line1:SetTextColor(r, g, b)
        end

        if data.NT and data.NT ~= "" then
            tooltip:AddLine("< " .. data.NT .. " >", 0.99, 0.84, 0.39, true)
        end

        local raceClass = strtrim((data.RA or "") .. " " .. (data.RC and StripColorCodes(data.RC) or ""))
        if raceClass ~= "" then
            tooltip:AddLine(raceClass, r, g, b, false)
        end
        if data.NH and data.NH ~= "" then
            tooltip:AddLine("House / Clan: |cfffdd663" .. data.NH .. "|r", 0.80, 0.84, 0.90, false)
        end
        if data.MO and data.MO ~= "" then
            tooltip:AddLine("\"" .. data.MO .. "\"", 0.72, 0.78, 0.86, true)
        end

        local cuVal = (isSelf and ns.profile and ns.profile.currently) or data.CU
        if cuVal and strtrim(StripColorCodes(cuVal)) ~= "" then
            tooltip:AddLine(" ")
            tooltip:AddLine("Currently", 1.0, 1.0, 1.0, false)
            tooltip:AddLine(strtrim(StripColorCodes(cuVal)), 0.99, 0.84, 0.39, true)
        end

        local oocRaw = (isSelf and ns.profile and (ns.profile.oocNotes or ns.profile.oocInfo)) or data.CO
        local oocClean = CleanOOCTooltipText(oocRaw)
        local oocBlock = {}
        if oocClean ~= "" then
            table.insert(oocBlock, oocClean)
        end
        if isSelf and ns.profile then
            local lgbtqText = (ns.profile.lgbtqFriendly ~= false) and "|cff81c995Yes|r" or "|cff9aa0a6No|r"
            local erpText = ns.profile.erpFriendly and "|cfffdd663Yes|r" or "|cff9aa0a6No|r"
            table.insert(oocBlock, "|cff9aa0a6LGBTQIA2S+ friendly:|r " .. lgbtqText)
            table.insert(oocBlock, "|cff9aa0a6ERP:|r " .. erpText)
        end
        if #oocBlock > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Other information (OOC)", 1.0, 1.0, 1.0, false)
            tooltip:AddLine(table.concat(oocBlock, "\n"), 0.99, 0.84, 0.39, true)
        end

        local glances = ns:ParseGlances(data.PE)
        if #glances > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("At First Glance", 0.54, 0.71, 0.97, false)
            for idx = 1, math.min(5, #glances) do
                tooltip:AddLine(glances[idx], 0.85, 0.88, 0.92, true)
            end
        end
    elseif line1 then
        local rawName = UnitName(unit) or key or "Player"
        line1:SetText(portraitTag .. standingTag .. rawName .. noteIcon)
        line1:SetTextColor(r, g, b)
    end

    if hasNote then
        local preview = (strtrim(charNote) ~= "") and strtrim(charNote) or strtrim(acctNote)
        preview = string.gsub(preview, "[\r\n]+", " ")
        if #preview > 90 then
            preview = string.sub(preview, 1, 87) .. "..."
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("|TInterface\\Icons\\INV_Misc_Note_01:13:13:0:0:64:64:4:60:4:60|t |cff81c995Note:|r " .. preview, 0.85, 0.90, 0.86, true)
    end

    tooltipState[tooltip] = { taggedKey = key, portraitTag = portraitTag }
    tooltip:Show()
end

local function DecorateUnitTooltip(tooltip, tooltipData, skipRequest)
    if isDecoratingTooltip then return end
    isDecoratingTooltip = true
    pcall(DecorateUnitTooltipInternal, tooltip, tooltipData, skipRequest)
    isDecoratingTooltip = false
end

function ns:RefreshUnitTooltipNow()
    if InCombatLockdown() or isDecoratingTooltip then return end
    if GameTooltip and GameTooltip:IsShown() and UnitExists("mouseover") and UnitIsPlayer("mouseover") then
        local _, currentUnit = GameTooltip:GetUnit()
        if currentUnit and UnitIsUnit(currentUnit, "mouseover") then
            DecorateUnitTooltip(GameTooltip, nil, true)
        end
    end
end

local function InitTooltipHook()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        pcall(function()
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
                if tooltip == GameTooltip then
                    DecorateUnitTooltip(tooltip, data, false)
                end
            end)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(function()
            GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
                DecorateUnitTooltip(tooltip, nil, false)
            end)
        end)
    end

    if GameTooltip and GameTooltip.HookScript then
        pcall(function()
            GameTooltip:HookScript("OnTooltipCleared", function(self)
                tooltipState[self] = nil
            end)
        end)
    end
end

function ns:RefreshMinimapButton()
    if not ns.db or not ns.db.ui then return end
    ns.db.ui.minimapIcon = ns.db.ui.minimapIcon or { hide = false, minimapPos = 215 }
    local shouldShow = (ns.db.ui.showMinimap ~= false)
    local isIC = ns.profile and ns.profile.isIC

    if LDBIcon then
        if fallbackMinimapBtn then fallbackMinimapBtn:Hide() end
        ns.db.ui.minimapIcon.hide = not shouldShow
        if LDBIcon.Refresh then LDBIcon:Refresh("PadRP", ns.db.ui.minimapIcon) end
        if shouldShow then LDBIcon:Show("PadRP") else LDBIcon:Hide("PadRP") end

        local btn = LDBIcon:GetMinimapButton("PadRP")
        if btn and btn.icon then
            if isIC then btn.icon:SetVertexColor(0.55, 1.0, 0.70) else btn.icon:SetVertexColor(1.0, 0.55, 0.55) end
        end
    elseif fallbackMinimapBtn then
        if not shouldShow then fallbackMinimapBtn:Hide(); return end
        fallbackMinimapBtn:Show()
        local angle = math.rad(ns.db.ui.minimapIcon.minimapPos or 215)
        local radius = (Minimap:GetWidth() / 2) + 8
        fallbackMinimapBtn:ClearAllPoints()
        fallbackMinimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
        if isIC then fallbackMinimapBtn:SetBackdropBorderColor(0.51, 0.79, 0.58, 1)
        else fallbackMinimapBtn:SetBackdropBorderColor(0.95, 0.55, 0.51, 1) end
    end
end

local function TryRegisterLDBIcon()
    if LDBIcon then return true end
    local LibStub = _G.LibStub
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not LDB or not iconLib then return false end

    LDBIcon = iconLib
    ldbObject = (LDB.GetDataObjectByName and LDB:GetDataObjectByName("PadRP")) or LDB:NewDataObject("PadRP", {
        type = "launcher",
        text = "PadRP",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        OnClick = function(_, button) HandleMinimapClick(button) end,
        OnTooltipShow = function(tooltip) PopulateMinimapTooltip(tooltip) end,
    })

    if not LDBIcon.IsRegistered or not LDBIcon:IsRegistered("PadRP") then
        LDBIcon:Register("PadRP", ldbObject, ns.db.ui.minimapIcon)
    end
    ns:RefreshMinimapButton()
    return true
end

local function InitMinimapButton()
    ns.db.ui.minimapIcon = ns.db.ui.minimapIcon or { hide = not ns.db.ui.showMinimap, minimapPos = 215 }
    ns.db.ui.minimapIcon.hide = not ns.db.ui.showMinimap
    if TryRegisterLDBIcon() then return end

    if Minimap and not fallbackMinimapBtn then
        fallbackMinimapBtn = CreateFrame("Button", "PadRP_FallbackMinimapButton", Minimap, "BackdropTemplate")
        fallbackMinimapBtn:SetSize(32, 32)
        fallbackMinimapBtn:SetFrameStrata("MEDIUM")
        fallbackMinimapBtn:SetFrameLevel(8)
        fallbackMinimapBtn:RegisterForClicks("AnyUp")
        fallbackMinimapBtn:RegisterForDrag("LeftButton")
        fallbackMinimapBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        fallbackMinimapBtn:SetBackdropColor(0.08, 0.10, 0.13, 0.96)
        local icon = fallbackMinimapBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        fallbackMinimapBtn:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                ns.db.ui.minimapIcon.minimapPos = math.deg(math.atan2((cy / scale) - my, (cx / scale) - mx))
                ns:RefreshMinimapButton()
            end)
        end)
        fallbackMinimapBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        fallbackMinimapBtn:SetScript("OnClick", function(_, button) HandleMinimapClick(button) end)
        fallbackMinimapBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            PopulateMinimapTooltip(GameTooltip)
            GameTooltip:Show()
        end)
        fallbackMinimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    ns:RefreshMinimapButton()
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, function() TryRegisterLDBIcon() end)
    end
end

function ns:ResetMinimapButton()
    if not ns.db or not ns.db.ui then return end
    ns.db.ui.showMinimap = true
    ns.db.ui.minimapIcon = ns.db.ui.minimapIcon or {}
    ns.db.ui.minimapIcon.hide = false
    ns.db.ui.minimapIcon.minimapPos = 215
    TryRegisterLDBIcon()
    ns:RefreshMinimapButton()
    if ns.RefreshControllerUI then ns:RefreshControllerUI() end
end

local function SyncHUDFocusState(shouldShow, activeKey)
    if not hudFrame then return end
    local modalOpen = (ns.mainFrame and ns.mainFrame:IsShown()) or (ns.dossierFrame and ns.dossierFrame:IsShown())
    local curKey = activeKey or "__ACTIVE__"
    if hudDismissedKey and hudDismissedKey ~= curKey then
        hudDismissedKey = nil
    end

    if shouldShow and hudDismissedKey == curKey then
        hudFrame:Hide()
        if ns.currentFocus == hudFrame and ns.SetControllerFocus then
            ns:SetControllerFocus(nil)
        end
        if ns.UpdateControllerBindings then
            ns:UpdateControllerBindings()
        end
        return
    end

    local shouldAutoFocus = shouldShow and IsHardTargetedOtherPlayer() and not modalOpen

    if shouldAutoFocus then
        RegisterHUDWithConsolePort()
        if ns.SetControllerFocus then
            ns:SetControllerFocus(hudFrame)
        end
        if ns.UpdateControllerBindings then
            ns:UpdateControllerBindings()
        end
    elseif ns.currentFocus == hudFrame then
        if ns.SetControllerFocus then
            ns:SetControllerFocus(nil)
        end
        if ns.UpdateControllerBindings then
            ns:UpdateControllerBindings()
        end
    end
end

function ns:RefreshTargetHUD()
    if not hudFrame then return end
    if not ns.db or not ns.db.ui.showTargetHUD then
        hudFrame:Hide()
        SyncHUDFocusState(false)
        return
    end
    if ns.db.ui.hideInCombat and InCombatLockdown() then
        hudFrame:Hide()
        SyncHUDFocusState(false)
        return
    end

    local activeUnit = GetActiveOtherPlayerUnit()
    if not activeUnit then
        hudDismissedKey = nil
        hudFrame:Hide()
        SyncHUDFocusState(false)
        return
    end

    local data, activeKey = ns:GetCachedMSP(activeUnit)
    if ns.db.ui.hudOnlyRP and (not data or not data.NA) then
        hudFrame:Hide()
        SyncHUDFocusState(false, activeKey)
        return
    end

    if hudDismissedKey and hudDismissedKey == (activeKey or "__ACTIVE__") then
        hudFrame:Hide()
        SyncHUDFocusState(false, activeKey)
        return
    end

    local _, tClass = UnitClass(activeUnit)
    local tHex = (tClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[tClass] and RAID_CLASS_COLORS[tClass].colorStr) or "ff8ab4f8"
    local rawName = UnitName(activeUnit) or "Unknown"
    local standing, _, _, hasNote = ns:GetNoteInfo(activeKey)
    local standingTag = GetStandingBadgePrefix(standing)
    local assignedRel = activeKey and ns.GetAssignedRelationship and ns:GetAssignedRelationship(activeKey) or ""
    local relTag = (assignedRel ~= "") and ("  |cfffdd663[" .. assignedRel .. "]|r") or ""
    local noteTag = hasNote and " |TInterface\\Icons\\INV_Misc_Note_01:13:13:0:0:64:64:4:60:4:60|t" or ""

    if data and data.NA and data.NA ~= "" then
        local cleanNA = StripColorCodes(data.NA)
        local titleStr = (data.NT and data.NT ~= "") and ("  |cfffdd663<" .. data.NT .. ">|r") or ""
        hudFrame.nameText:SetText(standingTag .. "|c" .. tHex .. cleanNA .. "|r" .. titleStr .. relTag .. noteTag)
        local isIC = (data.FC == "2")
        local icDot = isIC and "|cff81c995[IC]|r" or "|cfff28b82[OOC]|r"
        local wuBadge = ns:GetTargetWalkUpInfo(data)
        local prefixBadges = wuBadge and (icDot .. " " .. wuBadge) or icDot
        local cuStr = (data.CU and data.CU ~= "") and StripColorCodes(data.CU) or "|cff9aa0a6Focus / Click to open Dossier|r"
        hudFrame.subText:SetText(prefixBadges .. "  |cffe8eaed" .. cuStr .. "|r")
        hudFrame.hintText:SetText("|cff81c995Focus / Click to Open Dossier|r")
        hudFrame.accentBar:SetColorTexture(isIC and 0.51 or 0.95, isIC and 0.79 or 0.55, isIC and 0.58 or 0.51, 1)
    else
        hudFrame.nameText:SetText(standingTag .. "|c" .. tHex .. rawName .. "|r" .. relTag .. noteTag)
        hudFrame.subText:SetText("|cff9aa0a6Standard Player (No RP Profile Cached)|r")
        hudFrame.hintText:SetText("Focus / Click to Open Dossier")
        hudFrame.accentBar:SetColorTexture(0.35, 0.39, 0.46, 0.65)
    end

    hudFrame.inspectedKey = activeKey
    hudFrame:SetScale(ns.db.ui.scale or 1.0)
    hudFrame:Show()
    SyncHUDFocusState(true, activeKey)
end

function ns:InitTargetHUD()
    InitMinimapButton()
    InitTooltipHook()

    hudFrame = CreateFrame("Button", "PadRP_TargetHUD", UIParent, "BackdropTemplate")
    ns.hudFrame = hudFrame
    hudFrame:SetSize(430, 62)
    hudFrame:SetPoint("TOP", UIParent, "TOP", 0, -44)
    hudFrame:SetMovable(true)
    hudFrame:EnableMouse(true)
    hudFrame:RegisterForClicks("LeftButtonUp")
    hudFrame:RegisterForDrag("LeftButton")
    hudFrame:SetScript("OnDragStart", hudFrame.StartMoving)
    hudFrame:SetScript("OnDragStop", hudFrame.StopMovingOrSizing)
    hudFrame:Hide()

    hudFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    hudFrame:SetBackdropColor(0.08, 0.10, 0.13, 0.96)
    hudFrame:SetBackdropBorderColor(0.20, 0.24, 0.31, 0.85)

    hudFrame.accentBar = hudFrame:CreateTexture(nil, "OVERLAY")
    hudFrame.accentBar:SetHeight(3)
    hudFrame.accentBar:SetPoint("BOTTOMLEFT", 1, 1)
    hudFrame.accentBar:SetPoint("BOTTOMRIGHT", -1, 1)
    hudFrame.accentBar:SetColorTexture(0.54, 0.71, 0.97, 1)

    hudFrame.nameText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudFrame.nameText:SetPoint("TOPLEFT", 14, -10)
    hudFrame.nameText:SetWidth(402)
    hudFrame.nameText:SetJustifyH("LEFT")
    hudFrame.nameText:SetWordWrap(false)

    hudFrame.subText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hudFrame.subText:SetPoint("TOPLEFT", 14, -27)
    hudFrame.subText:SetWidth(402)
    hudFrame.subText:SetJustifyH("LEFT")
    hudFrame.subText:SetWordWrap(false)

    hudFrame.hintText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hudFrame.hintText:SetPoint("BOTTOMRIGHT", -12, 7)

    hudFrame:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.54, 0.71, 0.97, 1.0)
        RegisterHUDWithConsolePort()
    end)
    hudFrame:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.20, 0.24, 0.31, 0.85)
    end)
    hudFrame:SetScript("OnClick", function(self)
        if ns.OpenTargetDossier then
            ns:OpenTargetDossier(self.inspectedKey)
        end
    end)

    if ns.RegisterFocusable then
        ns:RegisterFocusable(hudFrame, function(self)
            if ns.OpenTargetDossier then
                ns:OpenTargetDossier(self.inspectedKey)
            end
        end, function(self, isFocused)
            if isFocused then
                self:SetBackdropBorderColor(0.54, 0.71, 0.97, 1.0)
            else
                self:SetBackdropBorderColor(0.20, 0.24, 0.31, 0.85)
            end
        end)
    end

    RegisterHUDWithConsolePort()

    hudFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    hudFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    hudFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    hudFrame:SetScript("OnEvent", function() ns:RefreshTargetHUD() end)

    ns:CreateBindButton("PadRP_InspectTargetButton", function()
        if ns.OpenTargetDossier then
            ns:OpenTargetDossier(hudFrame and hudFrame.inspectedKey or ns.lastInspectedKey)
        end
    end)
end