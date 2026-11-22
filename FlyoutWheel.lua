local _, ns = ...

BINDING_HEADER_PADRP = "PadRP"
BINDING_NAME_PADRP_TOGGLE_FLYOUT = "PadRP: Open / Close RP Flyout Wheel"
BINDING_NAME_PADRP_TOGGLE_UI = "PadRP: Open / Close Main Menu"
BINDING_NAME_PADRP_TOGGLE_IC = "PadRP: Toggle IC / OOC"
BINDING_NAME_PADRP_CYCLE_WALKUP = "PadRP: Cycle Walk-Up Status"
BINDING_NAME_PADRP_DO_SIT = "PadRP: Sit / Rest (/sit)"
BINDING_NAME_PADRP_QUICK_THANK = "PadRP: Quick Thank Helper"
BINDING_NAME_PADRP_INSPECT_TARGET = "PadRP: Inspect Target RP"

local wheelFrame
local headerTitleFS
local pageCountFS
local pageDotTextures = {}
local hubTitleFS
local hubSubFS
local footerHintFS

local spokeLines = {}
local activeArcOuter = {}
local activeArcInner = {}
local activeSpokeLeft
local activeSpokeRight
local activeGlowTex
local sliceButtons = {}

-- Dynamic page list built on open:
-- MAIN -> STD (1..N) -> CUSTOM (1..N) -> STANDING -> DICE
-- Sub-views (not in LB/RB ring): WALKUP, CURRENTLY
local pageList = {}
local activePageIndex = 1
local subViewMode = nil -- nil, "WALKUP", or "CURRENTLY"
local currentSlices = {}
local selectedIdx = 1

local SLICES_PER_PAGE = 8
local OUTER_R = 176
local INNER_R = 56
local CONTENT_R = 118
local DEBOUNCE_SECONDS = 0.14
local STICK_DEADZONE = 0.45
local lastActionTime = 0
local lastStickEventTime = 0
local initialized = false
local cameraLocked = false

local STANDING_ITEMS = {
    { name = "Ally",         icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",         color = "|cff00e5ff" },
    { name = "Friendly",     icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength",  color = "|cff2ef280" },
    { name = "Neutral",      icon = "Interface\\Icons\\INV_Jewelry_Ring_03",            color = "|cff5cadff" },
    { name = "Acquaintance", icon = "Interface\\Icons\\INV_Misc_GroupLooking",          color = "|cff948cff" },
    { name = "Marked",       icon = "Interface\\Icons\\Ability_Hunter_SniperShot",      color = "|cffffcc1f" },
    { name = "Unfriendly",   icon = "Interface\\Icons\\Ability_DualWield",              color = "|cffff731a" },
    { name = "Rival",        icon = "Interface\\Icons\\INV_Sword_04",                   color = "|cffff2959" },
    { name = "None",         icon = "Interface\\Icons\\INV_Misc_QuestionMark",          color = "|cff9aa0a6" },
}

local DICE_ITEMS = {
    { label = "Roll d20",  sub = "1 - 20",  min = 1, max = 20,  icon = "Interface\\Icons\\INV_Misc_Dice_02" },
    { label = "Roll d100", sub = "1 - 100", min = 1, max = 100, icon = "Interface\\Icons\\INV_Misc_Dice_01" },
    { label = "Roll d12",  sub = "1 - 12",  min = 1, max = 12,  icon = "Interface\\Icons\\INV_Misc_Dice_02" },
    { label = "Roll d10",  sub = "1 - 10",  min = 1, max = 10,  icon = "Interface\\Icons\\INV_Misc_Dice_01" },
    { label = "Roll d8",   sub = "1 - 8",   min = 1, max = 8,   icon = "Interface\\Icons\\INV_Misc_Dice_02" },
    { label = "Roll d6",   sub = "1 - 6",   min = 1, max = 6,   icon = "Interface\\Icons\\INV_Misc_Dice_01" },
    { label = "Roll d4",   sub = "1 - 4",   min = 1, max = 4,   icon = "Interface\\Icons\\INV_Misc_Dice_02" },
    { label = "Coin Flip", sub = "1 - 2",   min = 1, max = 2,   icon = "Interface\\Icons\\INV_Misc_Coin_01" },
}

local CURRENTLY_ICONS = {
    "Interface\\Icons\\INV_Misc_GroupLooking",
    "Interface\\Icons\\Ability_Rogue_Sprint",
    "Interface\\Icons\\INV_Drink_05",
    "Interface\\Icons\\INV_Misc_Book_09",
    "Interface\\Icons\\INV_Scroll_02",
    "Interface\\Icons\\INV_Sword_04",
    "Interface\\Icons\\INV_Misc_Lantern_01",
    "Interface\\Icons\\INV_Letter_15",
}

local DEFAULT_CUSTOM_ICON = "Interface\\Icons\\INV_Letter_15"
local DEFAULT_BASE_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Note_01"

-- 16 curated starter RP base emotes enabled by default (2 wheel pages);
-- all remaining WoW emotes are retained in the catalog with enabled = false by default.
-- All emotes use the standard normal icon (DEFAULT_BASE_FALLBACK_ICON) unless the player picks a custom override (`icon`).
local DEFAULT_BASE_EMOTES = {
    -- Starter Page 1: Core RP Social
    { label = "Wave",          token = "WAVE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Bow",           token = "BOW",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Nod",           token = "NOD",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Shrug",         token = "SHRUG",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Cheer",         token = "CHEER",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Point",         token = "POINT",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Kneel",         token = "KNEEL",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Salute",        token = "SALUTE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },

    -- Starter Page 2: Expressive RP
    { label = "Laugh",         token = "LAUGH",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Sigh",          token = "SIGH",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Applaud",       token = "APPLAUD",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Ponder",        token = "PONDER",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Thank",         token = "THANK",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Cry",           token = "CRY",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Dance",         token = "DANCE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },
    { label = "Toast",         token = "TOAST",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = true },

    -- Full WoW Emote Catalog (disabled by default; toggleable in Emotes tab)
    { label = "Absent",        token = "ABSENT",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Agree",         token = "AGREE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Amaze",         token = "AMAZE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Angry",         token = "ANGRY",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Apologize",     token = "APOLOGIZE",      defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Attack Target", token = "ATTACKMYTARGET", defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Bark",          token = "BARK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bashful",       token = "BASHFUL",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Beckon",        token = "BECKON",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Beg",           token = "BEG",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bite",          token = "BITE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bleed",         token = "BLEED",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Blink",         token = "BLINK",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Blush",         token = "BLUSH",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Boggle",        token = "BOGGLE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bonk",          token = "BONK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bored",         token = "BORED",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bounce",        token = "BOUNCE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Be Right Back", token = "BRB",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Burp",          token = "BURP",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Bye",           token = "BYE",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Cackle",        token = "CACKLE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Calm Down",     token = "CALM",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Challenge",     token = "CHALLENGE",      defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Charge",        token = "CHARGE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Chicken",       token = "CHICKEN",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Chuckle",       token = "CHUCKLE",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Clap",          token = "CLAP",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Cold",          token = "COLD",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Comfort",       token = "COMFORT",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Commend",       token = "COMMEND",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Confused",      token = "CONFUSED",       defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Congratulate",  token = "CONGRATULATE",   defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Cough",         token = "COUGH",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Cower",         token = "COWER",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Crack Knuckles",token = "CRACK",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Cringe",        token = "CRINGE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Cuddle",        token = "CUDDLE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Curious",       token = "CURIOUS",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Curtsey",       token = "CURTSEY",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Doom",          token = "DOOM",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Drink",         token = "DRINK",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Duck",          token = "DUCK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Eat",           token = "EAT",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Eye / Size Up", token = "EYE",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Fart",          token = "FART",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Fidget",        token = "FIDGET",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Flee",          token = "FLEE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Flex",          token = "FLEX",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Flirt",         token = "FLIRT",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Flop",          token = "FLOP",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Follow Me",     token = "FOLLOW",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Frown",         token = "FROWN",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Gasp",          token = "GASP",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Gaze",          token = "GAZE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Giggle",        token = "GIGGLE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Glare",         token = "GLARE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Gloat",         token = "GLOAT",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Golf Clap",     token = "GOLFCLAP",       defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Greet",         token = "GREET",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Grin",          token = "GRIN",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Groan",         token = "GROAN",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Grovel",        token = "GROVEL",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Growl",         token = "GROWL",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Guffaw",        token = "GUFFAW",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Hail",          token = "HAIL",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Happy",         token = "HAPPY",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Heal Me",       token = "HEALME",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Hello",         token = "HELLO",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Help Me",       token = "HELPME",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Hug",           token = "HUG",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Hungry",        token = "HUNGRY",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Incoming",      token = "INCOMING",       defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Insult",        token = "INSULT",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Introduce",     token = "INTRODUCE",      defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Just Kidding",  token = "JK",             defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Kiss",          token = "KISS",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Lay Down",      token = "LAYDOWN",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Lick",          token = "LICK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Listen",        token = "LISTEN",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Lost",          token = "LOST",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Love",          token = "LOVE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Massage",       token = "MASSAGE",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Moan",          token = "MOAN",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Mock",          token = "MOCK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Moo",           token = "MOO",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Moon",          token = "MOON",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Mourn",         token = "MOURN",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "No",            token = "NO",             defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Pick Nose",     token = "NOSEPICK",       defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Out of Mana",   token = "OOM",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Open Fire",     token = "OPENFIRE",       defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Panic",         token = "PANIC",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Pat",           token = "PAT",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Peer",          token = "PEER",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Pity",          token = "PITY",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Plead",         token = "PLEAD",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Poke",          token = "POKE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Pounce",        token = "POUNCE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Pout",          token = "POUT",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Praise",        token = "PRAISE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Pray",          token = "PRAY",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Purr",          token = "PURR",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Puzzle",        token = "PUZZLE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Raise Hand",    token = "RAISE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Rasp",          token = "RASP",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Ready",         token = "READY",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Roar",          token = "ROAR",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "ROFL",          token = "ROFL",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Rude",          token = "RUDE",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Scared",        token = "SCARED",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Scratch",       token = "SCRATCH",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Sexy",          token = "SEXY",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Shake Fist",    token = "SHAKE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Shimmy",        token = "SHIMMY",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Shiver",        token = "SHIVER",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Shoo",          token = "SHOO",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Shy",           token = "SHY",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Sit",           token = "SIT",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Slap",          token = "SLAP",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Sleep",         token = "SLEEP",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Smile",         token = "SMILE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Smirk",         token = "SMIRK",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Snarl",         token = "SNARL",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Snicker",       token = "SNICKER",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Sniff",         token = "SNIFF",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Snub",          token = "SNUB",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Soothe",        token = "SOOTHE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Spit",          token = "SPIT",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Stand",         token = "STAND",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Stare",         token = "STARE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Surprised",     token = "SURPRISED",      defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Surrender",     token = "SURRENDER",      defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Talk",          token = "TALK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Talk Excited",  token = "TALKEX",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Talk Question", token = "TALKQ",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Tap Foot",      token = "TAP",            defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Taunt",         token = "TAUNT",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Tease",         token = "TEASE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Thirsty",       token = "THIRSTY",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Threaten",      token = "THREATEN",       defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Tickle",        token = "TICKLE",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Tired",         token = "TIRED",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Train",         token = "TRAIN",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Victory",       token = "VICTORY",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Play Violin",   token = "VIOLIN",         defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Wait",          token = "WAIT",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Welcome",       token = "WELCOME",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Whine",         token = "WHINE",          defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Whistle",       token = "WHISTLE",        defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Wink",          token = "WINK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
    { label = "Work",          token = "WORK",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },

    { label = "Yawn",          token = "YAWN",           defaultIcon = DEFAULT_BASE_FALLBACK_ICON, enabled = false },
}

local DEFAULT_BASE_BY_TOKEN = {}
for _, item in ipairs(DEFAULT_BASE_EMOTES) do
    DEFAULT_BASE_BY_TOKEN[item.token] = item
end

local DEFAULT_CUSTOM_EMOTES = {
    { label = "Look Around",  text = "looks around attentively, taking in the surroundings.", icon = nil },
    { label = "Lean / Rest",  text = "shifts weight comfortably, leaning against nearby cover.", icon = nil },
    { label = "Greet Target", text = "offers a warm greeting toward %target.", icon = nil },
    { label = "Check Gear",   text = "glances down to inspect their gear.", icon = nil },
    { label = "Sigh Quietly", text = "lets out a quiet, thoughtful sigh.", icon = nil },
    { label = "Take Notes",   text = "jots a brief note into a worn journal.", icon = nil },
}

local function GetCVarSafe(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, val = pcall(C_CVar.GetCVar, name)
        if ok then return val end
    end
    if type(GetCVar) == "function" then
        local ok, val = pcall(GetCVar, name)
        if ok then return val end
    end
    return nil
end

local function SetCVarSafe(name, value)
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, name, tostring(value))
    elseif type(SetCVar) == "function" then
        pcall(SetCVar, name, tostring(value))
    end
end

local function StripColorCodes(str)
    if not str then return "" end
    return (tostring(str):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function ShortenLabel(str, maxLen)
    local clean = strtrim(StripColorCodes(str or ""))
    if #clean <= maxLen then return clean end
    return string.sub(clean, 1, maxLen - 2) .. ".."
end

local function NormalizeRawIconValue(iconVal)
    if iconVal == nil or iconVal == false then return nil end
    if type(iconVal) == "number" then
        return (iconVal > 0 and iconVal < 2147483647) and iconVal or nil
    end
    local clean = strtrim(tostring(iconVal))
    if clean == "" then return nil end
    local num = tonumber(clean)
    if num then
        return (num > 0 and num < 2147483647) and num or nil
    end
    return clean
end

local function GetDefaultIconForEmote(kind, item)
    if kind == "custom" then
        return DEFAULT_CUSTOM_ICON
    end
    if type(item) == "table" then
        local defOrig = item.defaultIcon
            or (item.token and DEFAULT_BASE_BY_TOKEN[string.upper(tostring(item.token))]
                and DEFAULT_BASE_BY_TOKEN[string.upper(tostring(item.token))].defaultIcon)
        if defOrig then
            return defOrig
        end
    end
    return DEFAULT_BASE_FALLBACK_ICON
end

function ns:GetFlyoutEmoteOriginalIcon(kind, item)
    return GetDefaultIconForEmote(kind, item)
end

function ns:GetFlyoutEmoteCustomIcon(item)
    if type(item) ~= "table" then return nil end
    return NormalizeRawIconValue(item.icon)
end

function ns:GetFlyoutEmoteDisplayIcon(kind, item)
    local orig = GetDefaultIconForEmote(kind, item)
    if type(item) == "table" then
        local custom = NormalizeRawIconValue(item.icon)
        if custom and custom ~= orig then
            return custom
        end
    end
    return orig
end

function ns:ResolveWheelIconTexture(iconVal, kind, item)
    local fallback = GetDefaultIconForEmote(kind, item)
    local raw = (iconVal ~= nil) and NormalizeRawIconValue(iconVal) or nil
    if raw == nil then
        return fallback
    end
    if type(raw) == "number" then
        return raw
    end
    if ns.IconPool and type(ns.IconPool.ResolveTexture) == "function" then
        local ok, res = pcall(ns.IconPool.ResolveTexture, ns.IconPool, raw, fallback)
        if ok and res then return res end
    end
    if ns.ResolveIconTexture then
        local ok, res = pcall(ns.ResolveIconTexture, ns, raw, nil)
        if ok and res then
            if type(res) == "number" then
                return (res > 0 and res < 2147483647) and res or fallback
            end
            return tostring(res)
        end
    end
    if string.find(raw, "\\", 1, true) or string.find(raw, "/", 1, true) then
        return raw
    end
    return "Interface\\Icons\\" .. raw
end

local function CanAct()
    local now = (GetTime and GetTime()) or 0
    if (now - lastActionTime) < DEBOUNCE_SECONDS then
        return false
    end
    lastActionTime = now
    return true
end

local function Notify(msg)
    if ns.ShowStatusToast then
        pcall(ns.ShowStatusToast, ns, msg)
    elseif msg then
        print("|cff8ab4f8[PadRP]|r " .. tostring(msg))
    end
    if ns.PlayUISound then
        pcall(ns.PlayUISound, ns)
    end
end

local function SanitizeBaseEmoteRecord(item, fallbackDef, forceNormalIconReset)
    if type(item) ~= "table" then return nil end
    local token = string.upper(strtrim(tostring(item.token or (fallbackDef and fallbackDef.token) or "")))
    if token == "" then return nil end

    local def = fallbackDef or DEFAULT_BASE_BY_TOKEN[token]
    local origIcon = DEFAULT_BASE_FALLBACK_ICON
    local cleanedCustom = NormalizeRawIconValue(item.icon)
    if forceNormalIconReset or cleanedCustom == origIcon then
        cleanedCustom = nil
    end

    local isDefaultStarter = (def and def.enabled == true) or false
    local enabledVal
    if item.enabled == true or item.enabled == false then
        enabledVal = item.enabled
    else
        enabledVal = isDefaultStarter
    end

    return {
        label = tostring(item.label or (def and def.label) or token),
        token = token,
        defaultIcon = origIcon,
        icon = cleanedCustom,
        enabled = enabledVal,
    }
end

function ns:EnsureFlyoutDB()
    ns.db = ns.db or _G.PadRPDB or {}
    if type(ns.db.flyout) ~= "table" then
        ns.db.flyout = {}
    end

    -- One-time migration: switch all emotes to the normal default icon unless the player
    -- explicitly picks a custom icon afterward.
    local needsNormalIconMigration = (ns.db.flyout.starterSetMigratedV3 ~= true)
        and (type(ns.db.flyout.standardEmotes) == "table" and #ns.db.flyout.standardEmotes > 0)

    if type(ns.db.flyout.standardEmotes) ~= "table" or #ns.db.flyout.standardEmotes == 0 then
        ns.db.flyout.standardEmotes = {}
        for i, item in ipairs(DEFAULT_BASE_EMOTES) do
            ns.db.flyout.standardEmotes[i] = SanitizeBaseEmoteRecord(item, item, false)
        end
    else
        local merged = {}
        local indexByToken = {}
        for _, item in ipairs(ns.db.flyout.standardEmotes) do
            local cleanItem = SanitizeBaseEmoteRecord(item, nil, needsNormalIconMigration)
            if cleanItem and not indexByToken[cleanItem.token] then
                indexByToken[cleanItem.token] = #merged + 1
                table.insert(merged, cleanItem)
            end
        end
        for _, def in ipairs(DEFAULT_BASE_EMOTES) do
            if not indexByToken[def.token] then
                indexByToken[def.token] = #merged + 1
                table.insert(merged, SanitizeBaseEmoteRecord(def, def, false))
            end
        end
        ns.db.flyout.standardEmotes = merged
    end
    ns.db.flyout.starterSetMigrated = true
    ns.db.flyout.starterSetMigratedV2 = true
    ns.db.flyout.starterSetMigratedV3 = true

    if type(ns.db.flyout.customEmotes) ~= "table" then
        ns.db.flyout.customEmotes = {}
        for i, item in ipairs(DEFAULT_CUSTOM_EMOTES) do
            ns.db.flyout.customEmotes[i] = {
                label = item.label,
                text = item.text,
                icon = NormalizeRawIconValue(item.icon),
            }
        end
    else
        for _, item in ipairs(ns.db.flyout.customEmotes) do
            if type(item) == "table" then
                local raw = NormalizeRawIconValue(item.icon)
                item.icon = (needsNormalIconMigration or raw == DEFAULT_CUSTOM_ICON) and nil or raw
            end
        end
    end

    return ns.db.flyout
end

local function SuppressRightStickCamera()
    if type(SetGamePadCursorControl) == "function" then
        pcall(SetGamePadCursorControl, false)
    end
    if type(SetGamePadFreeLook) == "function" then
        pcall(SetGamePadFreeLook, false)
    end
    if type(MouselookStop) == "function" then
        pcall(MouselookStop)
    end
end

local function IsRightStickName(stick)
    local s = string.lower(tostring(stick or ""))
    return s == "r" or s == "rstick" or s == "padrstick"
        or string.find(s, "right", 1, true) ~= nil
        or string.find(s, "camera", 1, true) ~= nil
end

local function WheelCaptureEnabled()
    return ns:EnsureFlyoutDB().captureRightStick ~= false
end

local function SetWheelStickCapture(frame, enabled)
    if not frame or type(frame.EnableGamePadStick) ~= "function" then return end
    pcall(frame.EnableGamePadStick, frame, enabled and true or false)
end

local function LockRightStickToWheel()
    local db = ns:EnsureFlyoutDB()
    if not cameraLocked then
        if type(db.savedCamera) ~= "table" then
            local curYaw = tonumber(GetCVarSafe("GamePadCameraYawSpeed"))
            local curPitch = tonumber(GetCVarSafe("GamePadCameraPitchSpeed"))
            local wasFreeLook = true
            if type(IsGamePadFreelookEnabled) == "function" then
                local ok, fl = pcall(IsGamePadFreelookEnabled)
                if ok then wasFreeLook = (fl == true) end
            end
            db.savedCamera = {
                yaw         = (curYaw and curYaw > 0.01) and curYaw or 1,
                pitch       = (curPitch and curPitch > 0.01) and curPitch or 1,
                wasFreeLook = wasFreeLook,
            }
        end
        SetCVarSafe("GamePadCameraYawSpeed", 0.0001)
        SetCVarSafe("GamePadCameraPitchSpeed", 0.0001)
        cameraLocked = true
    end
    SuppressRightStickCamera()
end

local function UnlockRightStickCamera(forceDefault)
    local db = ns:EnsureFlyoutDB()
    if type(db.savedCamera) == "table" then
        SetCVarSafe("GamePadCameraYawSpeed", db.savedCamera.yaw or 1)
        SetCVarSafe("GamePadCameraPitchSpeed", db.savedCamera.pitch or 1)
        if db.savedCamera.wasFreeLook and type(SetGamePadFreeLook) == "function" then
            pcall(SetGamePadFreeLook, true)
        end
        db.savedCamera = nil
    elseif forceDefault then
        SetCVarSafe("GamePadCameraYawSpeed", 1)
        SetCVarSafe("GamePadCameraPitchSpeed", 1)
        if type(SetGamePadFreeLook) == "function" then
            pcall(SetGamePadFreeLook, true)
        end
    end
    cameraLocked = false
end

local function HasOtherPlayerTarget()
    return UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player")
end

local function ResolveTargetKeyAndName()
    if not HasOtherPlayerTarget() then
        return nil, nil, false
    end

    local key = nil
    local mspData = nil
    if ns.GetCachedMSP then
        local ok, data, activeKey = pcall(ns.GetCachedMSP, ns, "target")
        if ok then
            if type(data) == "table" then mspData = data end
            if activeKey and activeKey ~= "" then key = activeKey end
        end
    end

    if not key and ns.GetUnitKey then
        local ok, k = pcall(ns.GetUnitKey, ns, "target")
        if ok and k and k ~= "" then key = k end
    end

    if not key then
        local uName, uRealm = UnitName("target")
        if uName and uName ~= "" then
            key = (uRealm and uRealm ~= "") and (uName .. "-" .. uRealm) or uName
        end
    end

    local hasRPProfile = (type(mspData) == "table" and mspData.NA and strtrim(mspData.NA) ~= "") and true or false
    local displayName = hasRPProfile and StripColorCodes(mspData.NA) or (UnitName("target") or key or "Target")
    return key, displayName, hasRPProfile
end

local function GetTargetStandingValue(key)
    if not key then return "None" end
    if ns.GetNoteInfo then
        local ok, standing = pcall(ns.GetNoteInfo, ns, key)
        if ok and standing and standing ~= "" then return standing end
    end
    local rec = ns.db and ns.db.notes and ns.db.notes[key]
    return (type(rec) == "table" and rec.standing) or "None"
end

local function SetTargetStandingValue(key, standing)
    if not key or key == "" then return false end
    ns.db = ns.db or {}
    ns.db.notes = ns.db.notes or {}
    if type(ns.db.notes[key]) ~= "table" then
        ns.db.notes[key] = {}
    end
    ns.db.notes[key].standing = (standing == "None") and nil or standing

    if ns.RefreshAllNameplates then pcall(ns.RefreshAllNameplates, ns) end
    if ns.RefreshUnitTooltipNow then pcall(ns.RefreshUnitTooltipNow, ns) end
    if ns.RefreshTargetHUD then pcall(ns.RefreshTargetHUD, ns) end
    if ns.RefreshControllerUI then pcall(ns.RefreshControllerUI, ns) end
    return true
end

local function OpenTargetedPlayerDossier(targetKey)
    if not targetKey or targetKey == "" then return end
    if HasOtherPlayerTarget() and ns.RequestUnitMSP then
        pcall(ns.RequestUnitMSP, ns, "target", true, false)
    end
    if ns.OpenTargetDossier then
        pcall(ns.OpenTargetDossier, ns, targetKey)
    elseif _G.PadRP_InspectTargetButton and _G.PadRP_InspectTargetButton.Click then
        _G.PadRP_InspectTargetButton:Click()
    end
end

local function GetPlayerRPDisplayName()
    if ns.profile then
        local first = strtrim(tostring(ns.profile.firstName or ""))
        local last = strtrim(tostring(ns.profile.lastName or ""))
        local combined = strtrim(first .. " " .. last)
        if combined ~= "" then return StripColorCodes(combined) end
    end
    return UnitName("player") or "Player"
end

local function FormatCustomEmoteText(rawText)
    local out = tostring(rawText or "")
    local playerName = GetPlayerRPDisplayName()
    local targetName = "someone"

    if UnitExists("target") then
        targetName = UnitName("target") or targetName
        if ns.GetCachedMSP then
            local ok, mspData = pcall(ns.GetCachedMSP, ns, "target")
            if ok and type(mspData) == "table" and mspData.NA and strtrim(mspData.NA) ~= "" then
                targetName = StripColorCodes(mspData.NA)
            end
        end
    end

    out = out:gsub("%%name", playerName)
    out = out:gsub("%%target", targetName)
    return strtrim(out)
end

function ns:TriggerFlyoutStandardEmote(token)
    if not CanAct() then return end
    local cleanToken = string.upper(strtrim(tostring(token or "")))
    if cleanToken == "" then return end
    if type(DoEmote) == "function" then pcall(DoEmote, cleanToken) end
    if ns.PlayUISound then pcall(ns.PlayUISound, ns) end
end

function ns:TriggerFlyoutCustomEmote(rawText)
    if not CanAct() then return end
    local formatted = FormatCustomEmoteText(rawText)
    if formatted == "" then return end
    if type(SendChatMessage) == "function" then pcall(SendChatMessage, formatted, "EMOTE") end
    if ns.PlayUISound then pcall(ns.PlayUISound, ns) end
end

-- Emote list management (used by the Emotes tab in ControllerUI.lua)
local MAX_CUSTOM_EMOTES = 64
local MAX_BASE_EMOTES = 250
local DEFAULT_BASE_TOKENS = {}
for _, item in ipairs(DEFAULT_BASE_EMOTES) do DEFAULT_BASE_TOKENS[item.token] = true end

local function GetEmoteList(kind)
    local db = ns:EnsureFlyoutDB()
    return (kind == "base") and db.standardEmotes or db.customEmotes
end

local function CleanEmoteToken(token)
    local t = string.upper(strtrim(tostring(token or "")))
    t = t:gsub("^/+", "")
    if t == "" or not t:match("^[A-Z0-9_]+$") then return nil end
    return t
end

function ns:GetFlyoutEmoteList(kind)
    return GetEmoteList(kind)
end

function ns:IsDefaultBaseEmoteToken(token)
    return DEFAULT_BASE_TOKENS[string.upper(tostring(token or ""))] == true
end

function ns:SetFlyoutEmoteCustomIcon(kind, idx, iconVal)
    local list = GetEmoteList(kind)
    local item = list[idx]
    if not item then return false end
    local orig = GetDefaultIconForEmote(kind, item)
    local cleaned = NormalizeRawIconValue(iconVal)
    if cleaned == orig then
        item.icon = nil
    else
        item.icon = cleaned
    end
    if kind == "base" and not item.defaultIcon then
        item.defaultIcon = orig
    end
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
    return true
end

function ns:ClearFlyoutEmoteCustomIcon(kind, idx)
    local list = GetEmoteList(kind)
    local item = list[idx]
    if not item then return false end
    item.icon = nil
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
    return true
end

function ns:AddFlyoutEmote(kind, fields)
    local list = GetEmoteList(kind)
    local limit = (kind == "base") and MAX_BASE_EMOTES or MAX_CUSTOM_EMOTES
    if #list >= limit then return nil, "limit" end
    fields = fields or {}
    local label = string.sub(strtrim(tostring(fields.label or "")), 1, 40)
    local customIcon = NormalizeRawIconValue(fields.icon)
    local item
    if kind == "base" then
        local token = CleanEmoteToken(fields.token)
        if not token then return nil, "token" end
        for _, e in ipairs(list) do
            if e.token == token then return nil, "duplicate" end
        end
        local origIcon = DEFAULT_BASE_FALLBACK_ICON
        if customIcon == origIcon then customIcon = nil end
        item = {
            label = (label ~= "") and label or (token:sub(1, 1) .. token:sub(2):lower()),
            token = token,
            defaultIcon = origIcon,
            icon = customIcon,
            enabled = true,
        }
    else
        local text = string.sub(strtrim(tostring(fields.text or "")), 1, 240)
        if customIcon == DEFAULT_CUSTOM_ICON then customIcon = nil end
        item = {
            label = (label ~= "") and label or "New Emote",
            text = (text ~= "") and text or "does something memorable.",
            icon = customIcon,
        }
    end
    table.insert(list, item)
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
    return #list
end

function ns:RemoveFlyoutEmote(kind, idx)
    local list = GetEmoteList(kind)
    local item = list[idx]
    if not item then return false, "missing" end
    if kind == "base" and ns:IsDefaultBaseEmoteToken(item.token) then return false, "default" end
    table.remove(list, idx)
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
    return true
end

function ns:MoveFlyoutEmote(kind, idx, delta)
    local list = GetEmoteList(kind)
    local to = idx + delta
    if not list[idx] or to < 1 or to > #list then return idx end
    list[idx], list[to] = list[to], list[idx]
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
    return to
end

function ns:ResetFlyoutBaseEmotes()
    local db = ns:EnsureFlyoutDB()
    db.standardEmotes = {}
    for i, item in ipairs(DEFAULT_BASE_EMOTES) do
        db.standardEmotes[i] = {
            label = item.label,
            token = item.token,
            defaultIcon = DEFAULT_BASE_FALLBACK_ICON,
            icon = nil,
            enabled = (item.enabled == true),
        }
    end
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
end

function ns:SetAllFlyoutBaseEmotesEnabled(enabled)
    local db = ns:EnsureFlyoutDB()
    for _, item in ipairs(db.standardEmotes) do
        item.enabled = (enabled == true)
    end
    if wheelFrame and wheelFrame:IsShown() then ns:RefreshFlyoutWheel() end
end

function ns:PreviewFlyoutEmoteText(raw)
    local formatted = FormatCustomEmoteText(raw)
    if formatted == "" then return "" end
    return GetPlayerRPDisplayName() .. " " .. formatted
end

local function ToggleICState()
    if not CanAct() then return end
    local isIC = false
    if ns.ToggleICOOC then
        isIC = ns:ToggleICOOC()
    elseif ns.profile then
        ns.profile.isIC = not ns.profile.isIC
        isIC = ns.profile.isIC
        if ns.SnapshotActiveProfile then pcall(ns.SnapshotActiveProfile, ns) end
        if ns.SyncMSP then pcall(ns.SyncMSP, ns) end
    end
    if ns.RefreshControllerUI then pcall(ns.RefreshControllerUI, ns) end
    if ns.RefreshMinimapButton then pcall(ns.RefreshMinimapButton, ns) end
    if ns.RefreshAllNameplates then pcall(ns.RefreshAllNameplates, ns) end
    if ns.RefreshTargetHUD then pcall(ns.RefreshTargetHUD, ns) end
    Notify("Status: " .. (isIC and "|cff81c995In Character (IC)|r" or "|cfff28b82Out of Character (OOC)|r"))
end

local function SetWalkUpState(code)
    if not CanAct() then return end
    if ns.profile then ns.profile.walkUp = code end
    if ns.SnapshotActiveProfile then pcall(ns.SnapshotActiveProfile, ns) end
    if ns.SyncMSP then pcall(ns.SyncMSP, ns) end
    if ns.RefreshControllerUI then pcall(ns.RefreshControllerUI, ns) end
    if ns.RefreshMinimapButton then pcall(ns.RefreshMinimapButton, ns) end
    if ns.RefreshAllNameplates then pcall(ns.RefreshAllNameplates, ns) end
    if ns.RefreshTargetHUD then pcall(ns.RefreshTargetHUD, ns) end
    local label = (ns.GetWalkUpLabel and ns:GetWalkUpLabel(code)) or code
    Notify("Walk-Ups: |cfffdd663" .. tostring(label) .. "|r")
end

local function SetCurrentlyStatus(text)
    if not CanAct() then return end
    if ns.profile then
        ns.profile.currently = text or ""
    end
    if ns.SnapshotActiveProfile then pcall(ns.SnapshotActiveProfile, ns) end
    if ns.SyncMSP then pcall(ns.SyncMSP, ns) end
    if ns.LoadProfileIntoUI then pcall(ns.LoadProfileIntoUI, ns) end
    if ns.RefreshControllerUI then pcall(ns.RefreshControllerUI, ns) end
    if ns.RefreshMinimapButton then pcall(ns.RefreshMinimapButton, ns) end
    Notify("Currently: |cfffdd663" .. ((text and text ~= "") and text or "Cleared") .. "|r")
end

local function GetEnabledBaseEmotes()
    local db = ns:EnsureFlyoutDB()
    local enabled = {}
    for _, item in ipairs(db.standardEmotes) do
        if item.enabled == true then
            table.insert(enabled, item)
        end
    end
    return enabled
end

local function RebuildPageRing()
    local db = ns:EnsureFlyoutDB()
    local baseEnabled = GetEnabledBaseEmotes()
    local basePages = math.max(1, math.ceil(#baseEnabled / SLICES_PER_PAGE))
    local customPages = math.max(1, math.ceil(#db.customEmotes / SLICES_PER_PAGE))

    pageList = {
        { kind = "MAIN", title = "RP Wheel" },
    }
    for p = 1, basePages do
        table.insert(pageList, {
            kind = "STD",
            subPage = p,
            totalSubPages = basePages,
            title = (basePages > 1) and string.format("Base Emotes (%d/%d)", p, basePages) or "Base Emotes",
        })
    end
    for p = 1, customPages do
        table.insert(pageList, {
            kind = "CUSTOM",
            subPage = p,
            totalSubPages = customPages,
            title = (customPages > 1) and string.format("Custom Emotes (%d/%d)", p, customPages) or "Custom Emotes",
        })
    end
    table.insert(pageList, { kind = "STANDING", title = "Target Standing" })
    table.insert(pageList, { kind = "DICE",     title = "Dice Roller" })
end

local function FindFirstPageOfKind(kind)
    for idx, entry in ipairs(pageList) do
        if entry.kind == kind then
            return idx
        end
    end
    return 1
end

local function DrawCircleRing(parent, radius, segments, thickness, r, g, b, a, layer, sublevel)
    if not parent.CreateLine then return end
    local step = (2 * math.pi) / segments
    for i = 1, segments do
        local a1 = (i - 1) * step
        local a2 = i * step
        local line = parent:CreateLine(nil, layer or "BORDER", nil, sublevel or 0)
        line:SetThickness(thickness)
        line:SetColorTexture(r, g, b, a)
        line:SetStartPoint("CENTER", parent, math.cos(a1) * radius, math.sin(a1) * radius)
        line:SetEndPoint("CENTER", parent, math.cos(a2) * radius, math.sin(a2) * radius)
    end
end

local function SliceCenterAngle(index, total)
    local step = (2 * math.pi) / total
    return (math.pi / 2) - ((index - 1) * step)
end

local function BuildCurrentSlices()
    local db = ns:EnsureFlyoutDB()
    local isIC = ns.profile and ns.profile.isIC
    local curWU = (ns.profile and ns.profile.walkUp) or "WELCOME"
    local wuShort = (curWU == "WELCOME" and "Welcome") or (curWU == "ASK" and "Ask First") or "Closed"
    local curText = (ns.profile and ns.profile.currently and strtrim(ns.profile.currently) ~= "")
        and ShortenLabel(ns.profile.currently, 13)
        or "None"
    local targetKey, targetName, targetHasRP = ResolveTargetKeyAndName()
    local curStanding = targetKey and GetTargetStandingValue(targetKey) or nil

    if subViewMode == "WALKUP" then
        return "Walk-Up Status", {
            {
                label = "Welcome",
                sub = (curWU == "WELCOME") and "|cff81c995Active|r" or "Open RP",
                icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",
                onSelect = function() SetWalkUpState("WELCOME"); ns:CloseFlyoutWheel() end,
            },
            {
                label = "Ask First",
                sub = (curWU == "ASK") and "|cfffdd663Active|r" or "Whisper",
                icon = "Interface\\Icons\\INV_Misc_QuestionMark",
                onSelect = function() SetWalkUpState("ASK"); ns:CloseFlyoutWheel() end,
            },
            {
                label = "Closed",
                sub = (curWU == "CLOSED") and "|cfff28b82Active|r" or "No Walk-Ups",
                icon = "Interface\\Icons\\Spell_Shadow_SacrificialShield",
                onSelect = function() SetWalkUpState("CLOSED"); ns:CloseFlyoutWheel() end,
            },
        }
    elseif subViewMode == "CURRENTLY" then
        local presets = (ns.db and type(ns.db.currentlyPresets) == "table" and ns.db.currentlyPresets) or {
            "Available for walk-up RP.",
            "Traveling the road.",
            "Resting at the tavern.",
            "Deep in thought.",
            "Looking for work / contracts.",
            "Busy / In combat.",
        }
        local activeCurrently = (ns.profile and ns.profile.currently) or ""
        local list = {}
        for i, line in ipairs(presets) do
            if i > 7 then break end
            local presetText = line
            local isCur = (activeCurrently == presetText)
            table.insert(list, {
                label = ShortenLabel(presetText, 14),
                sub = isCur and "|cff81c995Active|r" or "Set Status",
                icon = CURRENTLY_ICONS[i] or "Interface\\Icons\\INV_Misc_Lantern_01",
                onSelect = function() SetCurrentlyStatus(presetText); ns:CloseFlyoutWheel() end,
            })
        end
        table.insert(list, {
            label = "Clear Status",
            sub = (activeCurrently == "") and "|cff81c995Empty|r" or "Erase",
            icon = "Interface\\Icons\\INV_Misc_QuestionMark",
            onSelect = function() SetCurrentlyStatus(""); ns:CloseFlyoutWheel() end,
        })
        return "Currently Status", list
    end

    local meta = pageList[activePageIndex] or { kind = "MAIN", title = "RP Wheel" }

    if meta.kind == "MAIN" then
        local baseEnabled = GetEnabledBaseEmotes()
        local targetColor = targetHasRP and "|cff81c995" or "|cff8ab4f8"
        return meta.title, {
            {
                label = "IC / OOC",
                sub = isIC and "|cff81c995In Character|r" or "|cfff28b82Out of Char|r",
                icon = "Interface\\Icons\\INV_Misc_Book_09",
                onSelect = function() ToggleICState(); ns:CloseFlyoutWheel() end,
            },
            {
                label = "Walk-Ups",
                sub = "|cfffdd663" .. wuShort .. "|r",
                icon = "Interface\\Icons\\INV_Misc_GroupLooking",
                onSelect = function() subViewMode = "WALKUP"; ns:RefreshFlyoutWheel() end,
            },
            {
                label = "Currently",
                sub = "|cff8ab4f8" .. curText .. "|r",
                icon = "Interface\\Icons\\INV_Misc_Lantern_01",
                onSelect = function() subViewMode = "CURRENTLY"; ns:RefreshFlyoutWheel() end,
            },
            {
                label = "Sit / Rest",
                sub = "/sit",
                icon = "Interface\\Icons\\INV_Drink_05",
                onSelect = function() ns:TriggerFlyoutStandardEmote("SIT"); ns:CloseFlyoutWheel() end,
            },
            {
                label = "PadRP Menu",
                sub = "Open Suite",
                icon = "Interface\\Icons\\INV_Scroll_02",
                onSelect = function()
                    ns:CloseFlyoutWheel()
                    if ns.ToggleMainFrame then ns:ToggleMainFrame() end
                end,
            },
            {
                label = "View Profile",
                sub = targetKey and (targetColor .. ShortenLabel(targetName, 13) .. "|r") or "|cff888888No Target|r",
                icon = "Interface\\Icons\\Ability_Spy",
                disabled = (targetKey == nil),
                onSelect = function()
                    if targetKey and CanAct() then
                        local keyToOpen = targetKey
                        ns:CloseFlyoutWheel()
                        OpenTargetedPlayerDossier(keyToOpen)
                    end
                end,
            },
            {
                label = "Standing",
                sub = targetKey and ("|cff8ab4f8" .. tostring(curStanding) .. "|r") or "|cff888888No Target|r",
                icon = "Interface\\Icons\\INV_Jewelry_Ring_03",
                disabled = (targetKey == nil),
                onSelect = function()
                    activePageIndex = FindFirstPageOfKind("STANDING")
                    ns:RefreshFlyoutWheel()
                end,
            },
            {
                label = "Custom /e",
                sub = tostring(#db.customEmotes) .. " saved",
                icon = DEFAULT_CUSTOM_ICON,
                onSelect = function()
                    activePageIndex = FindFirstPageOfKind("CUSTOM")
                    ns:RefreshFlyoutWheel()
                end,
            },
            {
                label = "Base Emotes",
                sub = tostring(#baseEnabled) .. " on wheel",
                icon = DEFAULT_BASE_FALLBACK_ICON,
                onSelect = function()
                    activePageIndex = FindFirstPageOfKind("STD")
                    ns:RefreshFlyoutWheel()
                end,
            },
        }
    elseif meta.kind == "STD" then
        local enabledList = GetEnabledBaseEmotes()
        local startIdx = ((meta.subPage - 1) * SLICES_PER_PAGE) + 1
        local endIdx = math.min(#enabledList, startIdx + SLICES_PER_PAGE - 1)
        local list = {}
        for i = startIdx, endIdx do
            local item = enabledList[i]
            local token = item.token
            local chosenIcon = ns:GetFlyoutEmoteDisplayIcon("base", item)
            table.insert(list, {
                label = ShortenLabel(item.label or token, 13),
                sub = "/" .. string.lower(tostring(token or "")),
                icon = ns:ResolveWheelIconTexture(chosenIcon, "base", item),
                onSelect = function() ns:TriggerFlyoutStandardEmote(token); ns:CloseFlyoutWheel() end,
            })
        end
        if #list == 0 then
            table.insert(list, {
                label = "Enable in PadRP",
                sub = "Emotes Tab",
                icon = DEFAULT_BASE_FALLBACK_ICON,
                onSelect = function()
                    ns:CloseFlyoutWheel()
                    if ns.OpenEmotesTab then
                        ns:OpenEmotesTab()
                    elseif ns.ToggleMainFrame then
                        ns:ToggleMainFrame()
                    end
                end,
            })
        end
        return meta.title, list
    elseif meta.kind == "CUSTOM" then
        local startIdx = ((meta.subPage - 1) * SLICES_PER_PAGE) + 1
        local endIdx = math.min(#db.customEmotes, startIdx + SLICES_PER_PAGE - 1)
        local list = {}
        for i = startIdx, endIdx do
            local item = db.customEmotes[i]
            local line = item.text
            local chosenIcon = ns:GetFlyoutEmoteDisplayIcon("custom", item)
            table.insert(list, {
                label = ShortenLabel(item.label or ("Emote " .. i), 13),
                sub = "/e custom",
                icon = ns:ResolveWheelIconTexture(chosenIcon, "custom", item),
                onSelect = function() ns:TriggerFlyoutCustomEmote(line); ns:CloseFlyoutWheel() end,
            })
        end
        if #list == 0 then
            table.insert(list, {
                label = "Add in PadRP",
                sub = "Emotes Tab",
                icon = DEFAULT_CUSTOM_ICON,
                onSelect = function()
                    ns:CloseFlyoutWheel()
                    if ns.OpenEmotesTab then
                        ns:OpenEmotesTab()
                    elseif ns.ToggleMainFrame then
                        ns:ToggleMainFrame()
                    end
                end,
            })
        end
        return meta.title, list
    elseif meta.kind == "STANDING" then
        local list = {}
        for _, st in ipairs(STANDING_ITEMS) do
            local isCur = targetKey and ((curStanding == st.name) or (st.name == "None" and (not curStanding or curStanding == "None")))
            table.insert(list, {
                label = (st.name == "None") and "Clear" or st.name,
                sub = isCur and "|cff81c995Active|r" or (targetKey and (st.color .. ShortenLabel(targetName, 11) .. "|r") or "|cff888888No Target|r"),
                icon = st.icon,
                disabled = (targetKey == nil),
                onSelect = function()
                    if targetKey and CanAct() then
                        SetTargetStandingValue(targetKey, st.name)
                        Notify("Standing for " .. targetName .. ": " .. ((st.name == "None") and "Cleared" or st.name))
                        ns:CloseFlyoutWheel()
                    end
                end,
            })
        end
        return targetKey and ("Standing: " .. ShortenLabel(targetName, 16)) or "Target Standing (No Player)", list
    else
        local list = {}
        for _, d in ipairs(DICE_ITEMS) do
            local dMin, dMax, dLabel = d.min, d.max, d.label
            table.insert(list, {
                label = dLabel,
                sub = d.sub,
                icon = d.icon,
                onSelect = function()
                    if CanAct() then
                        if type(RandomRoll) == "function" then
                            pcall(RandomRoll, dMin, dMax)
                        end
                        if ns.PlayUISound then pcall(ns.PlayUISound, ns) end
                        ns:CloseFlyoutWheel()
                    end
                end,
            })
        end
        return meta.title, list
    end
end

local function SyncPageDots()
    local total = #pageList
    if total > 12 then
        for _, dot in ipairs(pageDotTextures) do
            dot:Hide()
        end
        if pageCountFS then
            if subViewMode ~= nil then
                pageCountFS:SetText("|cff9aa0a6Sub-Menu|r")
            else
                pageCountFS:SetText(string.format("|cfffdd663Page %d / %d|r", activePageIndex, total))
            end
            pageCountFS:Show()
        end
        return
    end

    if pageCountFS then pageCountFS:Hide() end
    for i = 1, 12 do
        local dot = pageDotTextures[i]
        if not dot then
            dot = wheelFrame:CreateTexture(nil, "OVERLAY")
            dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            pageDotTextures[i] = dot
        end
        if i <= total then
            local spacing = math.min(16, math.floor(140 / math.max(1, total)))
            local offsetX = (i - ((total + 1) / 2)) * spacing
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", wheelFrame, "CENTER", offsetX, OUTER_R + 20)
            if subViewMode == nil and activePageIndex == i then
                dot:SetVertexColor(0.98, 0.80, 0.22, 1.0)
                dot:SetSize(9, 9)
            else
                dot:SetVertexColor(0.42, 0.38, 0.32, 0.75)
                dot:SetSize(6, 6)
            end
            dot:Show()
        else
            dot:Hide()
        end
    end
end

local function UpdateActiveSliceVisuals()
    local count = #currentSlices
    if count == 0 then return end

    local activeItem = currentSlices[selectedIdx]
    local centerAngle = SliceCenterAngle(selectedIdx, count)
    local halfStep = math.pi / count
    local aStart = centerAngle + halfStep
    local aEnd = centerAngle - halfStep

    if activeGlowTex then
        if activeItem and not activeItem.disabled then
            activeGlowTex:ClearAllPoints()
            activeGlowTex:SetPoint("CENTER", wheelFrame, "CENTER", math.cos(centerAngle) * CONTENT_R, math.sin(centerAngle) * CONTENT_R)
            activeGlowTex:Show()
        else
            activeGlowTex:Hide()
        end
    end

    local arcSegs = #activeArcOuter
    for i = 1, arcSegs do
        local t1 = (i - 1) / arcSegs
        local t2 = i / arcSegs
        local ang1 = aStart + (aEnd - aStart) * t1
        local ang2 = aStart + (aEnd - aStart) * t2

        local lo = activeArcOuter[i]
        lo:SetStartPoint("CENTER", wheelFrame, math.cos(ang1) * (OUTER_R + 1), math.sin(ang1) * (OUTER_R + 1))
        lo:SetEndPoint("CENTER", wheelFrame, math.cos(ang2) * (OUTER_R + 1), math.sin(ang2) * (OUTER_R + 1))
        lo:SetShown(activeItem and not activeItem.disabled)

        local li = activeArcInner[i]
        li:SetStartPoint("CENTER", wheelFrame, math.cos(ang1) * (INNER_R + 1), math.sin(ang1) * (INNER_R + 1))
        li:SetEndPoint("CENTER", wheelFrame, math.cos(ang2) * (INNER_R + 1), math.sin(ang2) * (INNER_R + 1))
        li:SetShown(activeItem and not activeItem.disabled)
    end

    if activeSpokeLeft and activeSpokeRight then
        local showSpokes = activeItem and not activeItem.disabled
        activeSpokeLeft:SetStartPoint("CENTER", wheelFrame, math.cos(aStart) * (INNER_R + 1), math.sin(aStart) * (INNER_R + 1))
        activeSpokeLeft:SetEndPoint("CENTER", wheelFrame, math.cos(aStart) * (OUTER_R - 1), math.sin(aStart) * (OUTER_R - 1))
        activeSpokeLeft:SetShown(showSpokes)

        activeSpokeRight:SetStartPoint("CENTER", wheelFrame, math.cos(aEnd) * (INNER_R + 1), math.sin(aEnd) * (INNER_R + 1))
        activeSpokeRight:SetEndPoint("CENTER", wheelFrame, math.cos(aEnd) * (OUTER_R - 1), math.sin(aEnd) * (OUTER_R - 1))
        activeSpokeRight:SetShown(showSpokes)
    end

    for i, btn in ipairs(sliceButtons) do
        if btn:IsShown() then
            local isSel = (i == selectedIdx)
            if btn._disabled then
                btn.iconFrame:SetSize(32, 32)
                btn.icon:SetDesaturated(true)
                btn.icon:SetAlpha(0.42)
                btn.iconBorder:SetColorTexture(0.28, 0.25, 0.20, 0.55)
                btn.labelFS:SetTextColor(0.50, 0.50, 0.50)
            elseif isSel then
                btn.iconFrame:SetSize(42, 42)
                btn.icon:SetDesaturated(false)
                btn.icon:SetAlpha(1.0)
                btn.iconBorder:SetColorTexture(1.00, 0.84, 0.28, 1.00)
                btn.labelFS:SetTextColor(1.00, 0.90, 0.40)
            else
                btn.iconFrame:SetSize(34, 34)
                btn.icon:SetDesaturated(false)
                btn.icon:SetAlpha(0.90)
                btn.iconBorder:SetColorTexture(0.55, 0.45, 0.26, 0.85)
                btn.labelFS:SetTextColor(0.92, 0.78, 0.36)
            end
        end
    end

    if activeItem then
        hubTitleFS:SetText(activeItem.disabled and ("|cff777777" .. activeItem.label .. "|r") or activeItem.label)
        hubSubFS:SetText(activeItem.sub or "")
    else
        hubTitleFS:SetText("PadRP")
        hubSubFS:SetText("")
    end

    SyncPageDots()
end

local function RebuildSpokes(count)
    for _, pair in ipairs(spokeLines) do
        pair.shadow:Hide()
        pair.core:Hide()
    end
    if not wheelFrame.CreateLine or count <= 1 then return end

    local step = (2 * math.pi) / count
    local halfStep = step / 2
    for i = 1, count do
        local ang = (math.pi / 2) - ((i - 1) * step) + halfStep
        local pair = spokeLines[i]
        if not pair then
            local sh = wheelFrame:CreateLine(nil, "BORDER", nil, 1)
            sh:SetThickness(5)
            sh:SetColorTexture(0.05, 0.04, 0.03, 0.95)
            local co = wheelFrame:CreateLine(nil, "BORDER", nil, 2)
            co:SetThickness(2)
            co:SetColorTexture(0.52, 0.43, 0.26, 0.88)
            pair = { shadow = sh, core = co }
            spokeLines[i] = pair
        end
        local x1, y1 = math.cos(ang) * INNER_R, math.sin(ang) * INNER_R
        local x2, y2 = math.cos(ang) * OUTER_R, math.sin(ang) * OUTER_R
        pair.shadow:SetStartPoint("CENTER", wheelFrame, x1, y1)
        pair.shadow:SetEndPoint("CENTER", wheelFrame, x2, y2)
        pair.shadow:Show()
        pair.core:SetStartPoint("CENTER", wheelFrame, x1, y1)
        pair.core:SetEndPoint("CENTER", wheelFrame, x2, y2)
        pair.core:Show()
    end
end

local function GetOrCreateSliceButton(index)
    local btn = sliceButtons[index]
    if btn then return btn end

    btn = CreateFrame("Button", nil, wheelFrame)
    btn:SetSize(88, 74)
    btn:SetFrameLevel(wheelFrame:GetFrameLevel() + 5)

    btn.iconFrame = CreateFrame("Frame", nil, btn)
    btn.iconFrame:SetSize(34, 34)
    btn.iconFrame:SetPoint("CENTER", btn, "CENTER", 0, 8)

    btn.iconBorder = btn.iconFrame:CreateTexture(nil, "BACKGROUND")
    btn.iconBorder:SetAllPoints(btn.iconFrame)
    btn.iconBorder:SetColorTexture(0.55, 0.45, 0.26, 0.85)

    btn.icon = btn.iconFrame:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.labelFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.labelFS:SetPoint("TOP", btn.iconFrame, "BOTTOM", 0, -4)
    btn.labelFS:SetWidth(88)
    btn.labelFS:SetJustifyH("CENTER")
    btn.labelFS:SetWordWrap(false)

    btn.subFS = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.subFS:SetPoint("TOP", btn.labelFS, "BOTTOM", 0, -1)
    btn.subFS:SetWidth(88)
    btn.subFS:SetJustifyH("CENTER")
    btn.subFS:SetWordWrap(false)

    btn:SetScript("OnEnter", function(self)
        selectedIdx = self._idx
        UpdateActiveSliceVisuals()
    end)

    btn:SetScript("OnClick", function(self)
        if self._disabled then return end
        if self._item and type(self._item.onSelect) == "function" then
            self._item.onSelect(self._item)
        end
    end)

    sliceButtons[index] = btn
    return btn
end

function ns:RefreshFlyoutWheel()
    if not wheelFrame then return end
    RebuildPageRing()
    if activePageIndex > #pageList then activePageIndex = #pageList end
    if activePageIndex < 1 then activePageIndex = 1 end

    local title, slices = BuildCurrentSlices()
    currentSlices = slices
    if selectedIdx > #currentSlices or selectedIdx < 1 then
        selectedIdx = 1
    end

    headerTitleFS:SetText(title or "RP Wheel")
    RebuildSpokes(#currentSlices)

    for _, btn in ipairs(sliceButtons) do btn:Hide() end

    local count = #currentSlices
    for i, item in ipairs(currentSlices) do
        local btn = GetOrCreateSliceButton(i)
        local ang = SliceCenterAngle(i, count)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", wheelFrame, "CENTER", math.cos(ang) * CONTENT_R, math.sin(ang) * CONTENT_R)
        btn._idx = i
        btn._item = item
        btn._disabled = item.disabled and true or false
        btn.icon:SetTexture(item.icon or DEFAULT_BASE_FALLBACK_ICON)
        btn.labelFS:SetText(item.label or "")
        btn.subFS:SetText(item.sub or "")
        btn:Show()
    end

    UpdateActiveSliceVisuals()
end

local function StepWheelPage(delta)
    subViewMode = nil
    selectedIdx = 1
    if #pageList > 0 then
        activePageIndex = ((activePageIndex - 1 + delta) % #pageList) + 1
        ns:RefreshFlyoutWheel()
    end
    if ns.PlayUISound then pcall(ns.PlayUISound, ns) end
end

local function AimSliceByStick(vx, vy)
    local count = #currentSlices
    if count == 0 then return end
    local stickAngle = math.atan2(vy, vx)
    local cwOffset = ((math.pi / 2) - stickAngle) % (2 * math.pi)
    local step = (2 * math.pi) / count
    local idx = (math.floor((cwOffset + (step / 2)) / step) % count) + 1
    if idx ~= selectedIdx then
        selectedIdx = idx
        UpdateActiveSliceVisuals()
    end
end

local function GetMappedGamePadState()
    if not C_GamePad or not C_GamePad.GetDeviceMappedState then return nil end
    local ok, state = pcall(C_GamePad.GetDeviceMappedState)
    if (not ok or type(state) ~= "table") and C_GamePad.GetActiveDeviceID then
        local devId = C_GamePad.GetActiveDeviceID()
        if devId then
            ok, state = pcall(C_GamePad.GetDeviceMappedState, devId)
        end
    end
    return (ok and type(state) == "table") and state or nil
end

local function ReadRightStick()
    local state = GetMappedGamePadState()
    if not state then return 0, 0 end

    if type(state.sticks) == "table" then
        local named = state.sticks.Right or state.sticks.Camera
        if type(named) == "table" and named.x ~= nil and named.y ~= nil then
            return tonumber(named.x) or 0, tonumber(named.y) or 0
        end
        for k, s in pairs(state.sticks) do
            if type(s) == "table" and (k == "Right" or k == "Camera" or s.name == "Right" or s.name == "Camera") then
                return tonumber(s.x) or 0, tonumber(s.y) or 0
            end
        end
    end

    local gp = C_GamePad
    if gp and gp.GetConfig then
        local devId = gp.GetActiveDeviceID and gp.GetActiveDeviceID() or nil
        local firstId = gp.GetAllConfigIDs and (gp.GetAllConfigIDs() or {})[1] or nil
        for _, arg in ipairs({ devId or false, firstId or false }) do
            if arg then
                local ok, cfg = pcall(gp.GetConfig, arg)
                if ok and type(cfg) == "table" and type(cfg.stickConfigs) == "table" then
                    for idx, sc in ipairs(cfg.stickConfigs) do
                        if type(sc) == "table" and IsRightStickName(sc.stick) then
                            if type(state.sticks) == "table" and type(state.sticks[idx]) == "table" then
                                return tonumber(state.sticks[idx].x) or 0, tonumber(state.sticks[idx].y) or 0
                            end
                            local ax = tonumber(sc.axisX)
                            local ay = tonumber(sc.axisY)
                            if ax and ay and type(state.axes) == "table" and state.axes[ax + 1] ~= nil and state.axes[ay + 1] ~= nil then
                                return tonumber(state.axes[ax + 1]) or 0, tonumber(state.axes[ay + 1]) or 0
                            end
                        end
                    end
                    break
                end
            end
        end
    end

    if type(state.sticks) == "table" and type(state.sticks[2]) == "table" then
        return tonumber(state.sticks[2].x) or 0, tonumber(state.sticks[2].y) or 0
    end

    if type(state.axes) == "table" and state.axes[3] ~= nil and state.axes[4] ~= nil then
        return tonumber(state.axes[3]) or 0, tonumber(state.axes[4]) or 0
    end

    return 0, 0
end

local function PollWheelStick()
    SuppressRightStickCamera()
    local now = (GetTime and GetTime()) or 0
    if (now - lastStickEventTime) < 0.25 then
        return
    end
    local vx, vy = ReadRightStick()
    if math.sqrt((vx * vx) + (vy * vy)) >= STICK_DEADZONE then
        AimSliceByStick(vx, vy)
    end
end

function ns:CloseFlyoutWheel()
    UnlockRightStickCamera(false)
    subViewMode = nil
    if wheelFrame then
        wheelFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
        wheelFrame:EnableGamePadButton(false)
        SetWheelStickCapture(wheelFrame, false)
        wheelFrame:SetScript("OnUpdate", nil)
        wheelFrame:Hide()
    end
end

function ns:ToggleFlyoutWheel()
    if not initialized then ns:InitFlyoutWheel() end
    if not wheelFrame then return end
    if wheelFrame:IsShown() then
        ns:CloseFlyoutWheel()
        return
    end
    RebuildPageRing()
    activePageIndex = 1
    selectedIdx = 1
    subViewMode = nil
    lastStickEventTime = 0
    ns:RefreshFlyoutWheel()
    LockRightStickToWheel()
    wheelFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    wheelFrame:Show()
    wheelFrame:EnableGamePadButton(true)
    SetWheelStickCapture(wheelFrame, WheelCaptureEnabled())
    wheelFrame:SetScript("OnUpdate", PollWheelStick)
    if ns.PlayUISound then pcall(ns.PlayUISound, ns) end
end

local function HandleWheelSubcommand(cmd)
    if cmd == "resetcam" then
        UnlockRightStickCamera(true)
        Notify("Restored GamePad camera speed.")
        return true
    elseif cmd == "capture" then
        local db = ns:EnsureFlyoutDB()
        db.captureRightStick = not WheelCaptureEnabled()
        if wheelFrame and wheelFrame:IsShown() then
            SetWheelStickCapture(wheelFrame, WheelCaptureEnabled())
        end
        Notify("Right-stick capture: " .. (WheelCaptureEnabled() and "|cff81c995ON|r" or "|cfff28b82OFF|r"))
        return true
    elseif cmd == "debug" then
        _G.PadRP_DebugGamePad = (not _G.PadRP_DebugGamePad) or nil
        Notify("Gamepad debug: " .. (_G.PadRP_DebugGamePad and "ON" or "OFF"))
        return true
    end
    return false
end

local function HookSlashCommands()
    SLASH_PADRPWHEEL1 = "/padwheel"
    SlashCmdList["PADRPWHEEL"] = function(msg)
        local cmd = strtrim(string.lower(msg or ""))
        if HandleWheelSubcommand(cmd) then return end
        ns:ToggleFlyoutWheel()
    end

    if type(SlashCmdList["PADRP"]) == "function" and not ns._flyoutSlashWrapped then
        ns._flyoutSlashWrapped = true
        local prevHandler = SlashCmdList["PADRP"]
        SlashCmdList["PADRP"] = function(msg)
            local cmd = strtrim(string.lower(msg or ""))
            if cmd == "wheel" or cmd == "flyout" then
                ns:ToggleFlyoutWheel()
                return
            elseif cmd == "resetcam" then
                UnlockRightStickCamera(true)
                Notify("Restored GamePad camera speed.")
                return
            end
            return prevHandler(msg)
        end
    end
end

function PadRP_ToggleFlyoutWheel()
    ns:ToggleFlyoutWheel()
end

function PadRP_ToggleMainMenu()
    if ns.ToggleMainFrame then ns:ToggleMainFrame() end
end

function PadRP_ToggleIC()
    ToggleICState()
end

function PadRP_CycleWalkUp()
    if ns.CycleWalkUpStatus then
        local code = ns:CycleWalkUpStatus()
        Notify("Walk-Ups: |cfffdd663" .. (ns.GetWalkUpLabel and ns:GetWalkUpLabel(code) or tostring(code)) .. "|r")
        if ns.RefreshControllerUI then pcall(ns.RefreshControllerUI, ns) end
        if ns.RefreshMinimapButton then pcall(ns.RefreshMinimapButton, ns) end
    end
end

function PadRP_DoSit()
    ns:TriggerFlyoutStandardEmote("SIT")
end

function PadRP_QuickThank()
    if ns.QuickThankAction then ns:QuickThankAction() end
end

function PadRP_InspectTarget()
    local targetKey = ResolveTargetKeyAndName()
    if targetKey then
        OpenTargetedPlayerDossier(targetKey)
    elseif ns.OpenTargetDossier then
        ns:OpenTargetDossier(ns.hudFrame and ns.hudFrame.inspectedKey or ns.lastInspectedKey)
    end
end

function ns:InitFlyoutWheel()
    if initialized then return end
    initialized = true
    ns:EnsureFlyoutDB()

    if ns.db and ns.db.flyout and ns.db.flyout.savedCamera then
        UnlockRightStickCamera(false)
    end

    wheelFrame = CreateFrame("Frame", "PadRP_FlyoutWheel", UIParent)
    wheelFrame:SetSize((OUTER_R * 2) + 32, (OUTER_R * 2) + 110)
    wheelFrame:SetPoint("LEFT", UIParent, "LEFT", 56, 40)
    wheelFrame:SetFrameStrata("DIALOG")
    wheelFrame:Hide()
    ns.flyoutWheelFrame = wheelFrame

    headerTitleFS = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerTitleFS:SetPoint("BOTTOM", wheelFrame, "CENTER", 0, OUTER_R + 36)
    headerTitleFS:SetText("RP Wheel")
    headerTitleFS:SetTextColor(0.98, 0.93, 0.80)

    local lbText = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbText:SetPoint("BOTTOM", wheelFrame, "CENTER", -86, OUTER_R + 15)
    lbText:SetText("|cffd6c49a[LB]|r")

    local rbText = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rbText:SetPoint("BOTTOM", wheelFrame, "CENTER", 86, OUTER_R + 15)
    rbText:SetText("|cffd6c49a[RB]|r")

    pageCountFS = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageCountFS:SetPoint("CENTER", wheelFrame, "CENTER", 0, OUTER_R + 20)
    pageCountFS:SetJustifyH("CENTER")
    pageCountFS:Hide()

    local outerDisc = wheelFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    outerDisc:SetSize(OUTER_R * 2, OUTER_R * 2)
    outerDisc:SetPoint("CENTER", wheelFrame, "CENTER", 0, 0)
    outerDisc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    outerDisc:SetVertexColor(0.05, 0.04, 0.03, 0.84)

    activeGlowTex = wheelFrame:CreateTexture(nil, "ARTWORK", nil, 0)
    activeGlowTex:SetSize(102, 102)
    activeGlowTex:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    activeGlowTex:SetBlendMode("ADD")
    activeGlowTex:SetVertexColor(0.95, 0.72, 0.18, 0.22)
    activeGlowTex:Hide()

    DrawCircleRing(wheelFrame, OUTER_R + 5, 64, 5, 0.06, 0.05, 0.04, 0.96, "BORDER", 2)
    DrawCircleRing(wheelFrame, OUTER_R + 2, 64, 3, 0.56, 0.46, 0.28, 0.95, "BORDER", 3)
    DrawCircleRing(wheelFrame, OUTER_R - 2, 64, 2, 0.12, 0.10, 0.07, 0.92, "BORDER", 3)

    local innerDisc = wheelFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    innerDisc:SetSize(INNER_R * 2, INNER_R * 2)
    innerDisc:SetPoint("CENTER", wheelFrame, "CENTER", 0, 0)
    innerDisc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    innerDisc:SetVertexColor(0.03, 0.02, 0.02, 0.90)

    DrawCircleRing(wheelFrame, INNER_R + 3, 48, 4, 0.06, 0.05, 0.04, 0.96, "ARTWORK", 2)
    DrawCircleRing(wheelFrame, INNER_R,     48, 2.5, 0.58, 0.48, 0.30, 0.95, "ARTWORK", 3)

    if wheelFrame.CreateLine then
        for i = 1, 8 do
            local lo = wheelFrame:CreateLine(nil, "OVERLAY", nil, 4)
            lo:SetThickness(4)
            lo:SetColorTexture(1.00, 0.82, 0.26, 0.98)
            lo:Hide()
            activeArcOuter[i] = lo

            local li = wheelFrame:CreateLine(nil, "OVERLAY", nil, 4)
            li:SetThickness(3)
            li:SetColorTexture(1.00, 0.82, 0.26, 0.92)
            li:Hide()
            activeArcInner[i] = li
        end

        activeSpokeLeft = wheelFrame:CreateLine(nil, "OVERLAY", nil, 4)
        activeSpokeLeft:SetThickness(2.5)
        activeSpokeLeft:SetColorTexture(1.00, 0.82, 0.26, 0.95)
        activeSpokeLeft:Hide()

        activeSpokeRight = wheelFrame:CreateLine(nil, "OVERLAY", nil, 4)
        activeSpokeRight:SetThickness(2.5)
        activeSpokeRight:SetColorTexture(1.00, 0.82, 0.26, 0.95)
        activeSpokeRight:Hide()
    end

    hubTitleFS = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hubTitleFS:SetPoint("CENTER", wheelFrame, "CENTER", 0, 7)
    hubTitleFS:SetWidth((INNER_R * 2) - 12)
    hubTitleFS:SetJustifyH("CENTER")
    hubTitleFS:SetWordWrap(false)

    hubSubFS = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hubSubFS:SetPoint("TOP", hubTitleFS, "BOTTOM", 0, -3)
    hubSubFS:SetWidth((INNER_R * 2) - 10)
    hubSubFS:SetJustifyH("CENTER")
    hubSubFS:SetWordWrap(false)

    footerHintFS = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footerHintFS:SetPoint("TOP", wheelFrame, "CENTER", 0, -(OUTER_R + 16))
    footerHintFS:SetText("|cff81c995[R-Stick/D-Pad]|r Aim  |cff81c995[A]|r Select  |cfff28b82[B]|r Back  |cfffdd663[LB/RB]|r Page  |cfffdd663[LT/RT]|r Skip")

    wheelFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_TARGET_CHANGED" and self:IsShown() then
            ns:RefreshFlyoutWheel()
        end
    end)

    wheelFrame:SetScript("OnHide", function(self)
        UnlockRightStickCamera(false)
        subViewMode = nil
        self:UnregisterEvent("PLAYER_TARGET_CHANGED")
        self:EnableGamePadButton(false)
        SetWheelStickCapture(self, false)
        self:SetScript("OnUpdate", nil)
    end)

    wheelFrame:SetScript("OnGamePadButtonDown", function(self, button)
        local handled = true
        if button == "PADLSHOULDER" then
            StepWheelPage(-1)
        elseif button == "PADRSHOULDER" then
            StepWheelPage(1)
        elseif button == "PADLTRIGGER" then
            StepWheelPage(-3)
        elseif button == "PADRTRIGGER" then
            StepWheelPage(3)
        elseif button == "PADDUP" or button == "PADDLEFT" then
            if #currentSlices > 0 then
                selectedIdx = ((selectedIdx - 2) % #currentSlices) + 1
                UpdateActiveSliceVisuals()
            end
        elseif button == "PADDDOWN" or button == "PADDRIGHT" then
            if #currentSlices > 0 then
                selectedIdx = (selectedIdx % #currentSlices) + 1
                UpdateActiveSliceVisuals()
            end
        elseif button == "PAD1" then
            local item = currentSlices[selectedIdx]
            if item and not item.disabled and type(item.onSelect) == "function" then
                item.onSelect(item)
            end
        elseif button == "PAD2" then
            if subViewMode ~= nil then
                subViewMode = nil
                selectedIdx = 1
                ns:RefreshFlyoutWheel()
            elseif activePageIndex ~= 1 then
                activePageIndex = 1
                selectedIdx = 1
                ns:RefreshFlyoutWheel()
            else
                ns:CloseFlyoutWheel()
            end
        else
            handled = false
        end

        if not InCombatLockdown() and self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(not handled)
        end
    end)

    pcall(wheelFrame.SetScript, wheelFrame, "OnGamePadStick", function(self, stick, x, y, len)
        local isRight = IsRightStickName(stick)
        if _G.PadRP_DebugGamePad then
            print("|cff8ab4f8[PadRP stick]|r", tostring(stick), tostring(x), tostring(y), tostring(len))
        end
        if isRight then
            lastStickEventTime = (GetTime and GetTime()) or 0
            local vx, vy = tonumber(x) or 0, tonumber(y) or 0
            local mag = tonumber(len) or math.sqrt((vx * vx) + (vy * vy))
            if mag >= STICK_DEADZONE then
                AimSliceByStick(vx, vy)
            end
        end
        if not InCombatLockdown() and self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(not isRight)
        end
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "PadRP_FlyoutWheel")
    end

    HookSlashCommands()
end

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("PLAYER_LOGIN")
bootFrame:RegisterEvent("PLAYER_LOGOUT")
bootFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ns:InitFlyoutWheel()
    elseif event == "PLAYER_LOGOUT" then
        UnlockRightStickCamera(false)
    end
end)