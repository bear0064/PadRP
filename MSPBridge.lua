local _, ns = ...

ns.mspDebug = false
ns.mspSniff = false
ns.mspStats = { sent = 0, received = 0, liveReplies = 0, lastReplyFrom = "None" }

local WALKUP_CODE_MAP = { WELCOME = "1", ASK = "2", CLOSED = "3" }
local WALKUP_OOC_PREFIX = {
    WELCOME = "[Walk-Ups Welcome]",
    ASK     = "[Walk-Ups: Ask First]",
    CLOSED  = "[No Walk-Ups]",
}

function ns:DebugMSP(msg)
    if ns.mspDebug then
        if ns.LogNet then
            ns:LogNet("DEBUG", "ff8ab4f8", msg)
        else
            print("|cff8ab4f8[PadRP MSP]|r " .. tostring(msg))
        end
    end
end

function ns:GetLocalRealmClean()
    local r = GetNormalizedRealmName and GetNormalizedRealmName()
    if not r or r == "" then
        r = string.gsub(GetRealmName() or "Realm", "[%s%-]", "")
    end
    return r
end

-- Produces the exact "Name-Realm" identifier LibMSP & Chomp expect on this client
function ns:GetMSPUnitID(unitOrName)
    local localRealm = ns:GetLocalRealmClean()

    if UnitExists(unitOrName) then
        local name, realm
        if UnitFullName then
            name, realm = UnitFullName(unitOrName)
        end
        if not name or name == "" then
            name, realm = UnitName(unitOrName)
        end
        if not name or name == "" or name == "Unknown" then return nil end

        if _G.AddOn_Chomp and type(_G.AddOn_Chomp.NameMergedRealm) == "function" then
            local ok, merged = pcall(_G.AddOn_Chomp.NameMergedRealm, name, realm)
            if ok and merged and merged ~= "" then
                return merged
            end
        end

        if realm and realm ~= "" then
            return name .. "-" .. string.gsub(realm, "[%s%-]", "")
        end
        return name .. "-" .. localRealm
    elseif type(unitOrName) == "string" and unitOrName ~= "" then
        local trimmed = strtrim(unitOrName)
        if trimmed == "" then return nil end

        if _G.AddOn_Chomp and type(_G.AddOn_Chomp.NameMergedRealm) == "function" then
            local base, realm = strsplit("-", trimmed)
            local ok, merged = pcall(_G.AddOn_Chomp.NameMergedRealm, base, realm)
            if ok and merged and merged ~= "" then
                return merged
            end
        end

        if string.find(trimmed, "-", 1, true) then
            return trimmed
        end
        return trimmed .. "-" .. localRealm
    end

    return nil
end

function ns:GetUnitKeys(unitOrName)
    local mspID = ns:GetMSPUnitID(unitOrName)
    if not mspID then return nil, nil, nil end

    local baseName, realmPart = strsplit("-", mspID)
    local localRealm = ns:GetLocalRealmClean()

    if realmPart and realmPart ~= "" and string.lower(realmPart) ~= string.lower(localRealm) then
        return mspID, mspID, mspID
    end

    return baseName, mspID, baseName
end

function ns:GetUnitKey(unitOrName)
    local shortKey = ns:GetUnitKeys(unitOrName)
    return shortKey
end

function ns:GetWhisperTarget(unitOrName)
    return ns:GetMSPUnitID(unitOrName)
end

function ns:GetTargetWalkUpInfo(data)
    if not data then return nil, nil end
    if data.WU == "1" then return "|cff81c995[WALK-UPS: OPEN]|r", "WELCOME"
    elseif data.WU == "2" then return "|cfffdd663[WALK-UPS: ASK]|r", "ASK"
    elseif data.WU == "3" then return "|cfff28b82[WALK-UPS: CLOSED]|r", "CLOSED" end

    local combined = string.lower((data.CO or "") .. " " .. (data.CU or ""))
    if string.find(combined, "no walk%-up", 1) or string.find(combined, "walk%-ups closed", 1) then
        return "|cfff28b82[WALK-UPS: CLOSED]|r", "CLOSED"
    elseif string.find(combined, "ask first", 1) or string.find(combined, "whisper first", 1) then
        return "|cfffdd663[WALK-UPS: ASK]|r", "ASK"
    elseif string.find(combined, "walk%-up", 1) or string.find(combined, "walkup", 1) then
        return "|cff81c995[WALK-UPS: OPEN]|r", "WELCOME"
    end
    return nil, nil
end

local function BuildGlanceString(glances)
    if type(glances) ~= "table" then return "" end
    local blocks = {}
    for i = 1, 5 do
        local g = glances[i]
        if g and g.title and strtrim(g.title) ~= "" then
            local icon = (g.icon and g.icon ~= "") and g.icon or "INV_Misc_Book_09"
            local detail = (g.detail and g.detail ~= "") and g.detail or "No details provided."
            table.insert(blocks, string.format("|TInterface\\Icons\\%s:32:32|t\n# %s\n%s", icon, strtrim(g.title), detail))
        end
    end
    return table.concat(blocks, "\n\n---\n\n")
end

-- Parses MSP PE into structured entries AND formatted display strings preserving icon textures
function ns:ParseGlancesStructured(peRaw)
    if not peRaw or peRaw == "" then return {} end
    local results = {}
    local curIcon, curTitle, curDesc = nil, nil, {}

    local function FlushBlock()
        if curTitle or #curDesc > 0 then
            table.insert(results, {
                icon = curIcon or "Interface\\Icons\\INV_Misc_Book_09",
                title = curTitle or "First Glance",
                detail = table.concat(curDesc, " "),
            })
        end
        curIcon, curTitle, curDesc = nil, nil, {}
    end

    for line in string.gmatch(peRaw .. "\n", "([^\r\n]*)\r?\n") do
        local trimmed = strtrim(line)
        if trimmed == "---" then
            FlushBlock()
        elseif trimmed ~= "" then
            local texPath = string.match(trimmed, "|T([^:|]+)")
            if texPath then
                if not string.find(texPath, "\\", 1, true) then
                    texPath = "Interface\\Icons\\" .. texPath
                end
                curIcon = texPath
                trimmed = strtrim(string.gsub(trimmed, "|T.-|t", ""))
            end

            if trimmed ~= "" then
                if string.find(trimmed, "^#+%s*") then
                    if curTitle then FlushBlock() end
                    curTitle = strtrim(string.gsub(trimmed, "^#+%s*", ""))
                elseif not curTitle and #curDesc == 0 then
                    curTitle = trimmed
                else
                    table.insert(curDesc, trimmed)
                end
            end
        end
    end
    FlushBlock()
    return results
end

function ns:ParseGlances(peRaw)
    local structured = ns:ParseGlancesStructured(peRaw)
    local out = {}
    for _, g in ipairs(structured) do
        local iconTag = string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t ", g.icon)
        if g.detail and g.detail ~= "" then
            table.insert(out, string.format("%s|cfffdd663%s|r - %s", iconTag, g.title, g.detail))
        else
            table.insert(out, string.format("%s|cfffdd663%s|r", iconTag, g.title))
        end
    end
    return out
end

function ns:BuildLocalMSPFields()
    local p = ns.profile
    local fullName = (p.firstName and p.firstName ~= "") and p.firstName or UnitName("player")
    if p.lastName and strtrim(p.lastName) ~= "" then
        fullName = fullName .. " " .. strtrim(p.lastName)
    end

    local wuMode = p.walkUp or "WELCOME"
    local wuPrefix = WALKUP_OOC_PREFIX[wuMode] or "[Walk-Ups Welcome]"
    local coParts = { wuPrefix }
    if p.pronouns and strtrim(p.pronouns) ~= "" then
        table.insert(coParts, "[Pronouns: " .. strtrim(p.pronouns) .. "]")
    end
    local oocText = strtrim(p.oocInfo or "")
    if oocText ~= "" then
        table.insert(coParts, oocText)
    end

    return {
        VP = "3",
        VA = "PadRP/5.8",
        IC = (p.icon and p.icon ~= "") and p.icon or "INV_Helmet_46",
        PX = p.titlePrefix or "",
        NA = fullName,
        NH = p.houseName or "",
        NI = p.nickname or "",
        NT = p.title or "",
        RA = (p.race and p.race ~= "") and p.race or (UnitRace("player") or ""),
        RC = (p.class and p.class ~= "") and p.class or (UnitClass("player") or ""),
        AG = p.age or "",
        AH = p.height or "",
        AW = p.weight or "",
        AE = p.eyeColor or "",
        HB = p.birthplace or "",
        HH = p.residence or "",
        MO = p.motto or "",
        RS = tostring(p.relationship or "0"),
        CU = p.currently or "",
        CO = table.concat(coParts, " "),
        DE = p.description or "",
        HI = p.history or "",
        PE = BuildGlanceString(p.glances),
        FR = tostring(p.rpStyle or "1"),
        FC = p.isIC and "2" or "1",
        WU = WALKUP_CODE_MAP[wuMode] or "1",
    }
end

function ns:ConvertTRP3ToMSP(trpProf)
    if type(trpProf) ~= "table" then return nil end
    local playerBlock = trpProf.player or trpProf
    local c = playerBlock.characteristics
    if type(c) ~= "table" then return nil end

    local ch = playerBlock.character or {}
    local ab = playerBlock.about or {}
    local misc = playerBlock.misc or {}

    local fullName = (c.FN or "") .. ((c.LN and c.LN ~= "") and (" " .. c.LN) or "")
    if strtrim(fullName) == "" then return nil end

    local houseName, nickname, motto = "", "", ""
    if type(c.MI) == "table" then
        for _, mi in ipairs(c.MI) do
            if type(mi) == "table" and mi.VA and mi.VA ~= "" then
                local lbl = string.lower(mi.NA or "")
                if string.find(lbl, "house", 1, true) or string.find(lbl, "clan", 1, true) then
                    houseName = mi.VA
                elseif string.find(lbl, "nick", 1, true) then
                    nickname = mi.VA
                elseif string.find(lbl, "motto", 1, true) then
                    motto = mi.VA
                elseif houseName == "" then
                    houseName = mi.VA
                end
            end
        end
    end

    local deText, hiText = "", ""
    local te = ab.TE or 1
    if te == 1 and type(ab.T1) == "table" then
        deText = ab.T1.TX or ""
    elseif te == 2 and type(ab.T2) == "table" then
        local parts = {}
        for _, f in ipairs(ab.T2) do
            if type(f) == "table" and f.TX and f.TX ~= "" then table.insert(parts, f.TX) end
        end
        deText = table.concat(parts, "\n\n")
    elseif te == 3 and type(ab.T3) == "table" then
        local ph = (type(ab.T3.PH) == "table" and ab.T3.PH.TX) or ""
        local ps = (type(ab.T3.PS) == "table" and ab.T3.PS.TX) or ""
        deText = (ph ~= "" and ps ~= "") and (ph .. "\n\n" .. ps) or ((ph ~= "") and ph or ps)
        hiText = (type(ab.T3.HI) == "table" and ab.T3.HI.TX) or ""
    end

    local glances = {}
    if type(misc.PE) == "table" then
        for i = 1, 5 do
            local slot = misc.PE[tostring(i)] or misc.PE[i]
            if type(slot) == "table" and slot.AC and slot.TI and slot.TI ~= "" then
                table.insert(glances, string.format("|TInterface\\Icons\\%s:32:32|t\n# %s\n%s", slot.IC or "INV_Misc_Book_09", slot.TI, slot.TX or ""))
            end
        end
    end

    local xpToFR = { [1] = "4", [2] = "1", [3] = "3" }

    return {
        VP = "3",
        VA = "TotalRP3",
        IC = c.IC or "",
        PX = c.TI or "",
        NA = strtrim(fullName),
        NT = c.FT or "",
        NH = houseName,
        NI = nickname,
        MO = motto,
        RA = c.RA or "",
        RC = c.CL or "",
        AG = c.AG or "",
        AH = c.HE or "",
        AW = c.WE or "",
        AE = c.EC or "",
        HB = c.BP or "",
        HH = c.RE or "",
        RS = c.RS and tostring(c.RS) or "0",
        CU = ch.CU or "",
        CO = ch.CO or "",
        DE = deText,
        HI = hiText,
        PE = table.concat(glances, "\n\n---\n\n"),
        FR = (ch.XP and xpToFR[ch.XP]) or "1",
        FC = (ch.RP == 2) and "1" or "2",
        WU = (ch.WU == 2) and "3" or ((ch.WU == 1) and "1" or nil),
        lastSeen = time(),
    }
end

-- Copies live fields out of LibMSP's internal msp.char table into PadRP's persistent cache
function ns:PullFromLibMSPChar(mspUnitID)
    if not mspUnitID or type(_G.msp) ~= "table" or type(_G.msp.char) ~= "table" then return nil end

    local entry = rawget(_G.msp.char, mspUnitID)
    if not entry then
        local shortName = strsplit("-", mspUnitID)
        entry = shortName and rawget(_G.msp.char, shortName)
    end
    if type(entry) ~= "table" or type(entry.field) ~= "table" or next(entry.field) == nil then
        return nil
    end

    local f = entry.field
    local hasAnyData = (f.NA and f.NA ~= "") or (f.VA and f.VA ~= "") or (f.CU and f.CU ~= "")
        or (f.DE and f.DE ~= "") or (f.HI and f.HI ~= "") or (f.FC and f.FC ~= "") or (f.PE and f.PE ~= "")
    if not hasAnyData then return nil end

    local shortKey = ns:GetUnitKey(mspUnitID) or strsplit("-", mspUnitID)
    ns.mspCache = ns.mspCache or {}
    ns.mspCache[shortKey] = ns.mspCache[shortKey] or {}

    local target = ns.mspCache[shortKey]
    for k, v in pairs(f) do
        if type(v) == "string" then
            target[k] = v
        end
    end
    if not target.NA or target.NA == "" then
        target.NA = strsplit("-", mspUnitID)
    end
    target.lastSeen = time()
    target.isLiveFetched = true
    return target, shortKey
end

local function ReadFromTRP3(shortKey, fullID, displayFull)
    if _G.TRP3_API and _G.TRP3_API.register then
        local reg = _G.TRP3_API.register
        local getProfFn = reg.getUnitIDProfile or reg.getUnitIDCurrentProfile
        for _, candidate in ipairs({ fullID, displayFull, shortKey }) do
            if candidate and getProfFn then
                local okProf, trpProf = pcall(getProfFn, candidate)
                if okProf and type(trpProf) == "table" then
                    local converted = ns:ConvertTRP3ToMSP(trpProf)
                    if converted then return converted end
                end
            end
        end
    end
    return nil
end

function ns:GetCachedMSP(unitOrName)
    local shortKey, fullID, displayFull = ns:GetUnitKeys(unitOrName)
    if not shortKey then return nil, nil end

    if fullID then
        ns:PullFromLibMSPChar(fullID)
    end
    if shortKey and shortKey ~= fullID then
        ns:PullFromLibMSPChar(shortKey)
    end

    if _G.TRP3_API then
        local trpData = ReadFromTRP3(shortKey, fullID, displayFull)
        if trpData and trpData.NA and trpData.NA ~= "" then
            ns.mspCache[shortKey] = ns.mspCache[shortKey] or {}
            for k, v in pairs(trpData) do
                if v and v ~= "" then ns.mspCache[shortKey][k] = v end
            end
        end
    end

    local data = (ns.mspCache and ns.mspCache[shortKey])
        or (fullID and ns.mspCache and ns.mspCache[fullID])
        or (displayFull and ns.mspCache and ns.mspCache[displayFull])

    return data, shortKey
end

function ns:SyncMSP()
    local fields = ns:BuildLocalMSPFields()
    local shortKey = ns:GetUnitKey("player")
    if shortKey and ns.mspCache then ns.mspCache[shortKey] = fields end

    if type(_G.msp) == "table" and type(_G.msp.my) == "table" then
        for k, v in pairs(fields) do
            if k ~= "VP" then
                _G.msp.my[k] = v
            end
        end
        if type(_G.msp.Update) == "function" then
            pcall(_G.msp.Update, _G.msp)
        end
    end
end

function ns:ClearMSPCache()
    if not ns.db then return 0 end
    local removed = 0
    local myShort = ns:GetUnitKey("player")
    for k in pairs(ns.mspCache or {}) do
        if k ~= myShort then
            removed = removed + 1
        end
    end
    wipe(ns.mspCache)
    if type(_G.msp) == "table" and type(_G.msp.char) == "table" then
        wipe(_G.msp.char)
    end
    ns.lastInspectedKey = nil
    ns.mspStats = { sent = 0, received = 0, liveReplies = 0, lastReplyFrom = "None" }
    if ns.ResetWireThrottles then ns:ResetWireThrottles() end
    ns:SyncMSP()
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.RefreshTargetHUD then ns:RefreshTargetHUD() end
    if ns.RefreshTargetCard then ns:RefreshTargetCard() end
    if ns.RefreshDossierWindow then ns:RefreshDossierWindow() end
    if ns.RefreshControllerUI then ns:RefreshControllerUI() end
    return removed
end

function ns:ImportAllKnownFromTRP3AndMSP()
    local importedCount = 0
    if type(_G.msp) == "table" and type(_G.msp.char) == "table" then
        for unitID in pairs(_G.msp.char) do
            local pulled = ns:PullFromLibMSPChar(unitID)
            if pulled then importedCount = importedCount + 1 end
        end
    end
    if type(_G.TRP3_Register) == "table" and type(_G.TRP3_Register.character) == "table" and type(_G.TRP3_Register.profiles) == "table" then
        for unitID, cEntry in pairs(_G.TRP3_Register.character) do
            if type(cEntry) == "table" and cEntry.profileID and _G.TRP3_Register.profiles[cEntry.profileID] then
                local shortKey = ns:GetUnitKey(unitID)
                local conv = ns:ConvertTRP3ToMSP(_G.TRP3_Register.profiles[cEntry.profileID])
                if shortKey and conv and conv.NA and conv.NA ~= "" then
                    ns.mspCache[shortKey] = conv
                    importedCount = importedCount + 1
                end
            end
        end
    end

    local totalCached = 0
    for _, v in pairs(ns.mspCache or {}) do
        if v and v.NA and v.NA ~= "" then totalCached = totalCached + 1 end
    end
    return importedCount, totalCached
end

function ns:GetUnitRPName(unitOrName, firstNameOnly)
    local cached = ns:GetCachedMSP(unitOrName)
    if ns.db.gratitude.useRPNames and cached and cached.NA and cached.NA ~= "" then
        local cleanName = string.gsub(cached.NA, "|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if firstNameOnly then return strsplit(" ", cleanName) end
        return cleanName
    end
    if UnitExists(unitOrName) then return UnitName(unitOrName) end
    return strsplit("-", unitOrName or "friend")
end

function ns:ToggleICOOC()
    ns.profile.isIC = not ns.profile.isIC
    ns:SnapshotActiveProfile()
    ns:SyncMSP()
    if ns.RefreshAllNameplates then ns:RefreshAllNameplates() end
    if ns.RefreshMinimapButton then ns:RefreshMinimapButton() end
    return ns.profile.isIC
end

function ns:CycleCurrentlyPreset()
    local presets = ns.db.currentlyPresets
    if not presets or #presets == 0 then return end
    ns.profile.presetIndex = ((ns.profile.presetIndex or 1) % #presets) + 1
    ns.profile.currently = presets[ns.profile.presetIndex]
    ns:SnapshotActiveProfile()
    ns:SyncMSP()
end