local _, ns = ...

local isSplitting = false
local lastMentionPingTime = 0

local SPLITTABLE_TYPES = {
    SAY           = true,
    EMOTE         = true,
    YELL          = true,
    PARTY         = true,
    RAID          = true,
    GUILD         = true,
    OFFICER       = true,
    WHISPER       = true,
    INSTANCE_CHAT = true,
}

local function EnsureChatDefaults()
    if not ns.db then return end
    ns.db.ui = ns.db.ui or {}
    if ns.db.ui.emoteSplitter == nil then ns.db.ui.emoteSplitter = true end
    if ns.db.ui.mentionPing == nil then ns.db.ui.mentionPing = true end
    if ns.db.ui.targetChatHighlight == nil then ns.db.ui.targetChatHighlight = true end
end

-- =========================================================
-- 1. AUTOMATIC EMOTE / SAY / YELL / PARTY SPLITTER
-- =========================================================
local function UnlockChatEditBox(editBox)
    if not editBox then return end
    local enabled = ns.db and ns.db.ui and ns.db.ui.emoteSplitter
    if enabled then
        if editBox.SetMaxBytes then editBox:SetMaxBytes(0) end
        if editBox.SetMaxLetters then editBox:SetMaxLetters(1500) end
    else
        if editBox.SetMaxBytes then editBox:SetMaxBytes(255) end
        if editBox.SetMaxLetters then editBox:SetMaxLetters(255) end
    end
end

function ns:RefreshChatEditBoxLimits()
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then UnlockChatEditBox(eb) end
    end
end

-- Step backward from `limit` if `limit` lands on a UTF-8 continuation byte (10xxxxxx)
-- so multi-byte characters (e.g., accented letters, em-dashes, CJK) are never corrupted.
local function ClampToUTF8Boundary(str, limit)
    local len = #str
    if limit >= len then return len end
    if limit < 1 then return 1 end
    local pos = limit
    while pos > 1 do
        local nextByte = string.byte(str, pos + 1)
        if not nextByte or nextByte < 128 or nextByte >= 192 then
            break
        end
        pos = pos - 1
    end
    return pos
end

local function SplitChatText(msg, maxChunkBytes)
    local chunks = {}
    local remaining = strtrim(msg or "")
    local limit = maxChunkBytes or 240

    while #remaining > limit do
        local safeLimit = ClampToUTF8Boundary(remaining, limit)
        -- Find last space inside the byte limit so words aren't sliced in half
        local cutPos = nil
        local searchSlice = string.sub(remaining, 1, safeLimit)
        for idx = #searchSlice, math.max(1, math.floor(safeLimit * 0.5)), -1 do
            local byte = string.byte(searchSlice, idx)
            if byte == 32 then -- space
                cutPos = idx
                break
            end
        end

        if not cutPos then
            cutPos = safeLimit
        end

        local part = strtrim(string.sub(remaining, 1, cutPos))
        if part ~= "" then
            table.insert(chunks, part)
        end
        remaining = strtrim(string.sub(remaining, cutPos + 1))
    end

    if remaining ~= "" then
        table.insert(chunks, remaining)
    end

    -- Add clean continuation markers between chunks
    local total = #chunks
    if total > 1 then
        for i = 1, total do
            if i == 1 then
                chunks[i] = chunks[i] .. "..."
            elseif i == total then
                chunks[i] = "... " .. chunks[i]
            else
                chunks[i] = "... " .. chunks[i] .. "..."
            end
        end
    end

    return chunks
end

local origSendChatMessage = _G.SendChatMessage
if type(origSendChatMessage) == "function" then
    _G.SendChatMessage = function(msg, chatType, language, channel, ...)
        local cType = string.upper(tostring(chatType or "SAY"))
        local enabled = ns.db and ns.db.ui and ns.db.ui.emoteSplitter

        if enabled and not isSplitting and type(msg) == "string" and #msg > 255 and SPLITTABLE_TYPES[cType] then
            local chunks = SplitChatText(msg, 240)
            if #chunks > 1 then
                isSplitting = true
                for _, chunk in ipairs(chunks) do
                    origSendChatMessage(chunk, chatType, language, channel, ...)
                end
                isSplitting = false
                return
            end
        end

        return origSendChatMessage(msg, chatType, language, channel, ...)
    end
end

-- =========================================================
-- 2. RP NAME MENTION HIGHLIGHTER / PING & TARGET FILTER
-- =========================================================
local function EscapePattern(str)
    return string.gsub(str, "([%(%)%.%%%+%-%*%?%[%]%^%\$])", "%%%1")
end

local function CollectMyMentionTerms()
    local terms = {}
    local seen = {}

    local function AddTerm(raw)
        if type(raw) ~= "string" then return end
        local clean = strtrim(string.gsub(raw, "|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        if #clean < 3 then return end
        local low = string.lower(clean)
        if not seen[low] then
            seen[low] = true
            table.insert(terms, { raw = clean, low = low, pat = "%f[%a]" .. EscapePattern(low) .. "%f[%A]" })
        end
    end

    if ns.profile then
        AddTerm(ns.profile.firstName)
        AddTerm(ns.profile.lastName)
        AddTerm(ns.profile.nickname)
    end
    AddTerm(UnitName("player"))

    return terms
end

local function HighlightMatchedTerm(msg, termLow)
    local msgLow = string.lower(msg)
    local s, e = string.find(msgLow, "%f[%a]" .. EscapePattern(termLow) .. "%f[%A]")
    if not s or not e then return msg, false end
    local originalWord = string.sub(msg, s, e)
    local updated = string.sub(msg, 1, s - 1) .. "|cfffdd663" .. originalWord .. "|r" .. string.sub(msg, e + 1)
    return updated, true
end

local function RPChatMessageFilter(_, _, msg, author, ...)
    if not ns.db or not ns.db.ui or type(msg) ~= "string" or msg == "" then
        return false
    end

    local myKey = ns.GetUnitKey and ns:GetUnitKey("player") or UnitName("player")
    local authorKey = (author and author ~= "" and ns.GetUnitKey and ns:GetUnitKey(author)) or (author and strsplit("-", author))
    if authorKey and myKey and authorKey == myKey then
        return false
    end

    local modified = msg
    local mentioned = false

    if ns.db.ui.mentionPing then
        local terms = CollectMyMentionTerms()
        for _, t in ipairs(terms) do
            if string.find(string.lower(modified), t.pat) then
                local newMsg, didHit = HighlightMatchedTerm(modified, t.low)
                if didHit then
                    modified = newMsg
                    mentioned = true
                    break
                end
            end
        end
    end

    local isTargetSpeaker = false
    if ns.db.ui.targetChatHighlight and authorKey and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local targetKey = ns.GetUnitKey and ns:GetUnitKey("target") or UnitName("target")
        if targetKey and targetKey == authorKey then
            isTargetSpeaker = true
        end
    end

    if mentioned then
        modified = "|cff81c995>>|r " .. modified
        local now = GetTime()
        if (now - lastMentionPingTime) > 3.0 then
            lastMentionPingTime = now
            if ns.db.ui.soundEffects and PlaySound then
                PlaySound((SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master")
            end
        end
    elseif isTargetSpeaker then
        modified = "|cff8ab4f8[Target]|r " .. modified
    end

    if modified ~= msg then
        return false, modified, author, ...
    end
    return false
end

-- =========================================================
-- 3. CONTROLLER LANGUAGE QUICK-TOGGLE
-- =========================================================
function ns:GetAvailableLanguages()
    local langs = {}
    if type(GetNumLanguages) ~= "function" or type(GetLanguageByIndex) ~= "function" then
        return langs
    end
    local count = GetNumLanguages() or 0
    for i = 1, count do
        local name, langID = GetLanguageByIndex(i)
        if name and langID then
            table.insert(langs, { name = name, id = langID })
        end
    end
    return langs
end

function ns:GetSpokenLanguage()
    local eb = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    if eb and eb.language and eb.language ~= "" then
        return eb.language, eb.languageID
    end
    if type(GetDefaultLanguage) == "function" then
        local name, id = GetDefaultLanguage("player")
        return name or "Common", id
    end
    return "Common", nil
end

function ns:CycleSpokenLanguage()
    local langs = ns:GetAvailableLanguages()
    if #langs <= 1 then
        local curName = ns:GetSpokenLanguage()
        if ns.ShowStatusToast then ns:ShowStatusToast("Only one language known: " .. curName) end
        return curName
    end

    local curName, curID = ns:GetSpokenLanguage()
    local nextIdx = 1
    for i, entry in ipairs(langs) do
        if (curID and entry.id == curID) or (entry.name == curName) then
            nextIdx = (i % #langs) + 1
            break
        end
    end

    local chosen = langs[nextIdx]
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then
            eb.language = chosen.name
            eb.languageID = chosen.id
            if eb:IsShown() and ChatEdit_UpdateHeader then
                pcall(ChatEdit_UpdateHeader, eb)
            end
        end
    end

    if ns.ShowStatusToast then
        ns:ShowStatusToast("Spoken Language: " .. chosen.name)
    end
    print("|cff8ab4f8[PadRP]|r Spoken language set to |cfffdd663" .. chosen.name .. "|r.")
    if ns.RefreshDossierWindow then ns:RefreshDossierWindow() end
    return chosen.name
end

-- =========================================================
-- SELF-INITIALIZATION ON PLAYER_LOGIN
-- =========================================================
local chatToolsInit = CreateFrame("Frame")
chatToolsInit:RegisterEvent("PLAYER_LOGIN")
chatToolsInit:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    EnsureChatDefaults()
    ns:RefreshChatEditBoxLimits()

    if type(hooksecurefunc) == "function" and type(ChatEdit_ActivateChat) == "function" then
        hooksecurefunc("ChatEdit_ActivateChat", function(editBox)
            UnlockChatEditBox(editBox)
        end)
    end

    if type(ChatFrame_AddMessageEventFilter) == "function" and not ns._rpChatToolsFilterInstalled then
        ns._rpChatToolsFilterInstalled = true
        local events = {
            "CHAT_MSG_SAY",
            "CHAT_MSG_EMOTE",
            "CHAT_MSG_TEXT_EMOTE",
            "CHAT_MSG_YELL",
            "CHAT_MSG_PARTY",
            "CHAT_MSG_PARTY_LEADER",
        }
        for _, ev in ipairs(events) do
            ChatFrame_AddMessageEventFilter(ev, RPChatMessageFilter)
        end
    end

    if ns.CreateBindButton then
        ns:CreateBindButton("PadRP_CycleLanguageButton", function()
            ns:CycleSpokenLanguage()
        end)
    end
end)