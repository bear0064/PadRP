local _, ns = ...

local Pool = {
    entries = {},
    byID = {},
    byName = {},
    defaultFallback = 134400,
    initialized = false,
}
ns.IconPool = Pool

local function Trim(s)
    if s == nil then return "" end
    return string.gsub(tostring(s), "^%s*(.-)%s*$", "%1")
end

local function AddEntry(seen, idVal, nameVal)
    local numID = tonumber(idVal)
    local cleanName = Trim(nameVal)

    local primaryID = (numID and numID > 0) and numID or nil
    local displayName = cleanName ~= "" and cleanName or (primaryID and tostring(primaryID) or nil)
    if not primaryID and not displayName then
        return
    end

    local dedupKey = primaryID and ("id:" .. tostring(primaryID)) or ("name:" .. string.lower(displayName))
    if seen[dedupKey] then
        return
    end
    seen[dedupKey] = true

    local entry = { primaryID or displayName, displayName or tostring(primaryID) }
    Pool.entries[#Pool.entries + 1] = entry

    if primaryID then
        Pool.byID[primaryID] = entry
    end
    if cleanName ~= "" then
        Pool.byName[string.lower(cleanName)] = entry
    end
end

local function HarvestMacroIcons(seen)
    local fnSpell = _G.GetMacroIcons or (C_MacroInfo and C_MacroInfo.GetMacroIcons)
    local fnItem  = _G.GetMacroItemIcons or (C_MacroInfo and C_MacroInfo.GetMacroItemIcons)

    local temp = {}
    if type(fnSpell) == "function" then
        pcall(fnSpell, temp)
    end
    if type(fnItem) == "function" then
        pcall(fnItem, temp)
    end

    for _, raw in ipairs(temp) do
        if raw ~= nil and raw ~= false then
            local clean = Trim(raw)
            if clean ~= "" then
                local num = tonumber(clean)
                if num and num > 0 then
                    AddEntry(seen, num, tostring(num))
                else
                    local lower = string.lower(clean)
                    local stripped = string.gsub(lower, "^interface\\icons\\", "")
                    stripped = string.gsub(stripped, "^interface/icons/", "")
                    stripped = string.gsub(stripped, "%.blp$", "")
                    AddEntry(seen, nil, stripped)
                end
            end
        end
    end
end

local function RebuildIndex()
    wipe(Pool.entries)
    wipe(Pool.byID)
    wipe(Pool.byName)

    local seen = {}
    local catalogEntries = (ns.IconCatalog and ns.IconCatalog.entries) or {}
    for _, rawEntry in ipairs(catalogEntries) do
        if type(rawEntry) == "table" then
            AddEntry(seen, rawEntry[1], rawEntry[2])
        elseif rawEntry ~= nil then
            AddEntry(seen, tonumber(rawEntry), tostring(rawEntry))
        end
    end

    HarvestMacroIcons(seen)
end

function Pool:Init()
    RebuildIndex()
    self.initialized = true
end

function Pool:Search(query)
    if not self.initialized or (#self.entries == 0 and ns.IconCatalog and ns.IconCatalog.entries and #ns.IconCatalog.entries > 0) then
        self:Init()
    end

    local q = string.lower(Trim(query))
    if q == "" then
        return self.entries
    end

    local results = {}
    local numericID = tonumber(q)
    local exactEntry = numericID and self.byID[numericID] or nil

    if exactEntry then
        results[#results + 1] = exactEntry
    end

    for _, entry in ipairs(self.entries) do
        local id = entry[1]
        local name = string.lower(tostring(entry[2] or ""))
        if entry ~= exactEntry then
            if string.find(name, q, 1, true) or string.find(tostring(id or ""), q, 1, true) then
                results[#results + 1] = entry
            end
        end
    end

    return results
end

function Pool:GetPage(results, page, pageSize)
    if not self.initialized then
        self:Init()
    end

    local list = results or self.entries or {}
    page = math.max(1, tonumber(page) or 1)
    pageSize = math.max(1, tonumber(pageSize) or 40)

    local total = #list
    local totalPages = math.max(1, math.ceil(total / pageSize))
    page = math.min(page, totalPages)

    local output = {}
    local first = ((page - 1) * pageSize) + 1
    local last = math.min(first + pageSize - 1, total)

    for i = first, last do
        output[#output + 1] = list[i]
    end

    return output, totalPages, total, page
end

function Pool:ResolveTexture(iconVal, fallback)
    if not self.initialized then
        self:Init()
    end

    local fb = fallback or self.defaultFallback
    if iconVal == nil or iconVal == false then
        return fb
    end

    local clean = Trim(iconVal)
    if clean == "" then
        return fb
    end

    local num = tonumber(clean)
    if num and num > 0 then
        return num
    end

    local matched = self.byName[string.lower(clean)]
    if matched and tonumber(matched[1]) then
        return tonumber(matched[1])
    end

    if ns.ResolveIconTexture then
        local ok, resolved = pcall(ns.ResolveIconTexture, ns, clean, nil)
        if ok and resolved then
            local rNum = tonumber(resolved)
            if rNum and rNum > 0 then
                return rNum
            end
            if type(resolved) == "string" and Trim(resolved) ~= "" then
                return Trim(resolved)
            end
        end
    end

    if string.find(clean, "\\", 1, true) or string.find(clean, "/", 1, true) then
        return clean
    end

    return "Interface\\Icons\\" .. clean
end

Pool:Init()