-- WeaveForge Constants
-- All magic numbers, ability ID lookup tables, default settings, and configuration

local WF = WeaveForge

---------------------------------------------------------------------------
-- Addon metadata
---------------------------------------------------------------------------
WF.ADDON_NAME       = "WeaveForge"
WF.ADDON_VERSION    = "1.0.0"
WF.SAVED_VARS_NAME  = "WeaveForge_Data"
WF.SAVED_VARS_VER   = 1

---------------------------------------------------------------------------
-- GCD and timing constants
---------------------------------------------------------------------------
WF.GCD_MS               = 1000     -- Base global cooldown in milliseconds
WF.DEFAULT_DETECT_WINDOW = 1000    -- Max ms between LA and skill to count as weave
WF.BAR_SWAP_GRACE_MS    = 300      -- Grace period after bar swap (suppress miss detection)
WF.COMBAT_END_DELAY_MS  = 3000     -- Delay before finalizing fight after combat ends
WF.FADE_DELAY_DEFAULT   = 2        -- Seconds to keep UI visible after combat ends
WF.MIN_FIGHT_DURATION   = 5        -- Minimum fight length (seconds) to record

---------------------------------------------------------------------------
-- Streak milestone thresholds
---------------------------------------------------------------------------
WF.STREAK_MILESTONES = {
    [10]  = true,
    [25]  = true,
    [50]  = true,
    [100] = true,
}

---------------------------------------------------------------------------
-- Light Attack ability IDs per weapon type
-- These are used for weapon-type classification (secondary detection).
-- Primary detection uses abilityActionSlotType from EVENT_COMBAT_EVENT.
-- IMPORTANT: Verify these IDs against current live API using /wf debugla
---------------------------------------------------------------------------
WF.LA_ABILITY_IDS = {
    -- Melee
    [4858]  = "Two Handed",
    [4859]  = "One Hand and Shield",
    [4861]  = "Dual Wield",
    -- Ranged
    [5262]  = "Bow",
    [4862]  = "Fire Staff",
    [4868]  = "Ice Staff",
    [4867]  = "Lightning Staff",
    [4865]  = "Restoration Staff",
    -- Unarmed
    [7095]  = "Unarmed",
}

---------------------------------------------------------------------------
-- Heavy Attack ability IDs per weapon type
-- Used to detect heavy attack channeling and suppress miss detection
---------------------------------------------------------------------------
WF.HA_ABILITY_IDS = {
    [4860]  = "Two Handed",
    [4857]  = "One Hand and Shield",
    [16420] = "Dual Wield",
    [5261]  = "Bow",
    [4863]  = "Fire Staff",
    [4869]  = "Ice Staff",
    [4866]  = "Lightning Staff",
    [4864]  = "Restoration Staff",
}

---------------------------------------------------------------------------
-- Estimated heavy attack channel durations (ms) per weapon type
-- Used with zo_callLater to know when the HA ends
---------------------------------------------------------------------------
WF.HA_CHANNEL_DURATIONS = {
    ["Two Handed"]          = 1000,
    ["One Hand and Shield"] = 800,
    ["Dual Wield"]          = 1100,
    ["Bow"]                 = 900,
    ["Fire Staff"]          = 1500,
    ["Ice Staff"]           = 1200,
    ["Lightning Staff"]     = 3000,  -- lightning channels longer
    ["Restoration Staff"]   = 1200,
}

---------------------------------------------------------------------------
-- Off-GCD / proc-based abilities to ignore in weave detection
-- These skills fire without consuming GCD and should not count as misses
-- Keyed by ability ID for O(1) hash lookup
---------------------------------------------------------------------------
WF.OFF_GCD_ABILITIES = {
    -- Sorcerer
    [114716] = true,  -- Bound Armaments (proc activation)
    -- Crystal Fragments proc is auto-replaced on the bar, so its slotted
    -- version is what fires. The proc itself doesn't need to be excluded.
    -- Add more as discovered via /wf debugla
}

---------------------------------------------------------------------------
-- Target Dummy detection
-- Target dummies apply Minor Sorcery with a specific source ability ID
---------------------------------------------------------------------------
WF.DUMMY_BUFF_ABILITY_IDS = {
    [61693] = true,   -- Target Dummy Minor Sorcery (6M dummy)
    [62344] = true,   -- Target Dummy Minor Sorcery (3M dummy)
    [62346] = true,   -- Target Dummy Minor Sorcery (21M dummy)
    [62348] = true,   -- Target Dummy Minor Sorcery (25M dummy)
    [61742] = true,   -- Target Iron Atronach Trial Dummy (51M)
}

---------------------------------------------------------------------------
-- Zone type classification for fight tagging
-- Maps zone IDs to content categories
---------------------------------------------------------------------------
WF.ZONE_TYPE = {
    PVP     = "pvp",
    TRIAL   = "trial",
    DUNGEON = "dungeon",
    SOLO    = "solo",
    UNKNOWN = "unknown",
}

-- Known trial zone IDs (partial list - extend as needed)
WF.TRIAL_ZONE_IDS = {
    [636] = true,   -- Hel Ra Citadel
    [638] = true,   -- Aetherian Archive
    [639] = true,   -- Sanctum Ophidia
    [725] = true,   -- Maw of Lorkhaj
    [975] = true,   -- Halls of Fabrication
    [1000] = true,  -- Asylum Sanctorium
    [1051] = true,  -- Cloudrest
    [1121] = true,  -- Sunspire
    [1196] = true,  -- Kyne's Aegis
    [1263] = true,  -- Rockgrove
    [1344] = true,  -- Dreadsail Reef
    [1427] = true,  -- Sanity's Edge
    [1478] = true,  -- Lucent Citadel
}

-- Known PvP zone IDs
WF.PVP_ZONE_IDS = {
    [181] = true,   -- Cyrodiil
    [534] = true,   -- Imperial City
    -- Battlegrounds use instanced zone IDs which vary
}

---------------------------------------------------------------------------
-- Color schemes for rhythm bar and alerts
---------------------------------------------------------------------------
WF.COLOR_SCHEMES = {
    default = {
        good    = { 0.2, 0.8, 0.2, 1.0 },   -- green
        warning = { 0.9, 0.9, 0.1, 1.0 },   -- yellow
        bad     = { 0.8, 0.2, 0.2, 1.0 },   -- red
        idle    = { 0.3, 0.3, 0.3, 0.5 },   -- dim grey
    },
    colorblind = {
        good    = { 0.2, 0.5, 0.9, 1.0 },   -- blue
        warning = { 0.9, 0.9, 0.1, 1.0 },   -- yellow
        bad     = { 0.9, 0.5, 0.1, 1.0 },   -- orange
        idle    = { 0.3, 0.3, 0.3, 0.5 },
    },
    monochrome = {
        good    = { 0.9, 0.9, 0.9, 1.0 },   -- bright white
        warning = { 0.6, 0.6, 0.6, 1.0 },   -- medium grey
        bad     = { 0.3, 0.3, 0.3, 1.0 },   -- dark grey
        idle    = { 0.15, 0.15, 0.15, 0.5 },
    },
}

---------------------------------------------------------------------------
-- Alert style enum
---------------------------------------------------------------------------
WF.ALERT_STYLE = {
    ICON_FLASH    = 1,
    EDGE_FLASH    = 2,
    RETICLE_COLOR = 3,
}

WF.ALERT_STYLE_NAMES = {
    [1] = "Icon Flash",
    [2] = "Screen Edge Flash",
    [3] = "Reticle Color Change",
}

---------------------------------------------------------------------------
-- Alert sound enum
---------------------------------------------------------------------------
WF.ALERT_SOUND = {
    NONE  = 1,
    CLICK = 2,
    BUZZ  = 3,
}

WF.ALERT_SOUND_NAMES = {
    [1] = "None",
    [2] = "Soft Click",
    [3] = "Error Buzz",
}

-- Mapping to ESO SOUNDS constants (resolved at runtime)
WF.ALERT_SOUND_MAP = {
    -- [2] = SOUNDS.QUICKSLOT_USE_EMPTY,  -- set in Initialize after SOUNDS is available
    -- [3] = SOUNDS.GENERAL_ALERT_ERROR,
}

---------------------------------------------------------------------------
-- Default settings (account-wide)
---------------------------------------------------------------------------
WF.ACCOUNT_DEFAULTS = {
    enabled             = true,
    enableInPvP         = false,
    combatOnly          = true,
    fadeDelay           = 2,

    -- Missed Weave Detector
    missedAlert = {
        enabled         = true,
        style           = 1,        -- ALERT_STYLE.ICON_FLASH
        sound           = 1,        -- ALERT_SOUND.NONE
        detectionWindow = 1000,     -- ms
        ignoreBarSwap   = true,
        ignoreHeavy     = true,
    },

    -- Rhythm Bar
    rhythmBar = {
        enabled         = true,
        width           = 200,
        height          = 4,
        opacity         = 0.7,
        unlocked        = false,
        colorScheme     = "default",
        offsetX         = 0,
        offsetY         = 80,
    },

    -- Streak Counter
    streakCounter = {
        enabled         = true,
        showSessionBest = true,
        showAllTimeBest = false,
        milestones      = true,
        fontSize        = 18,
        unlocked        = false,
        offsetX         = 110,
        offsetY         = 70,
    },

    -- Fight Summary
    fightSummary = {
        autoShow        = false,
        minDuration     = 5,        -- seconds
        maxStoredFights = 20,
    },

    -- Practice Mode
    practiceMode = {
        autoEnable      = true,
        metronome       = false,
        metronomeVolume = 0.5,
        showHistogram   = true,
        showGhostBar    = false,
    },

    -- Advanced
    advanced = {
        customLAIds     = "",
        debugMode       = false,
    },
}

---------------------------------------------------------------------------
-- Default character data
---------------------------------------------------------------------------
WF.CHARACTER_DEFAULTS = {
    allTimeBestStreak = 0,
    fightHistory      = {},
    pinnedFights      = {},
}
