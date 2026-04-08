-- WeaveForge English Localization
-- This file establishes the global WeaveForge namespace and all UI strings

WeaveForge = WeaveForge or {}

WeaveForge.L = {
    -- General
    ADDON_NAME                  = "WeaveForge",
    ADDON_TAGLINE               = "Hammer your rhythm. Forge your DPS.",
    ENABLED                     = "Enabled",
    DISABLED                    = "Disabled",
    ON                          = "On",
    OFF                         = "Off",

    -- Chat messages
    CHAT_PREFIX                 = "|cFFD700[WeaveForge]|r ",
    CHAT_ENABLED                = "WeaveForge enabled.",
    CHAT_DISABLED               = "WeaveForge disabled.",
    CHAT_RESET                  = "Session stats reset.",
    CHAT_STREAK_BEST            = "All-time best streak: %d",
    CHAT_DEBUG_ON               = "Debug mode enabled. LA/HA ability IDs will print to chat.",
    CHAT_DEBUG_OFF              = "Debug mode disabled.",
    CHAT_DEBUG_LA               = "LA detected: abilityId=%d name=%s weapon=%s",
    CHAT_DEBUG_HA               = "HA detected: abilityId=%d name=%s",
    CHAT_DEBUG_SKILL            = "Skill used: slotIndex=%d abilityId=%d name=%s",
    CHAT_PRACTICE_ON            = "Practice mode enabled.",
    CHAT_PRACTICE_OFF           = "Practice mode disabled.",
    CHAT_FIGHT_SAVED            = "Fight pinned to history.",
    CHAT_EXPORT_HEADER          = "--- WeaveForge Fight Export ---",

    -- Missed weave
    MISSED_WEAVE                = "Missed Weave!",

    -- Streak
    STREAK_LABEL                = "Streak",
    STREAK_BEST_SESSION         = "best: %d",
    STREAK_BEST_ALLTIME         = "record: %d",
    STREAK_MILESTONE            = "Streak milestone: %d!",

    -- Rhythm bar
    RHYTHM_BAR_CAST_NOW         = "Cast Now!",

    -- Fight summary panel
    FIGHT_SUMMARY_TITLE         = "WeaveForge - Fight Summary",
    FIGHT_SUMMARY_DURATION      = "Duration: %s",
    FIGHT_SUMMARY_TARGET        = "Target: %s",
    FIGHT_SUMMARY_ZONE          = "Zone: %s",
    FIGHT_SUMMARY_OVERALL       = "Overall Weave Accuracy",
    FIGHT_SUMMARY_LA_PER_SEC    = "LA/s: %.2f",
    FIGHT_SUMMARY_TOTAL_LA      = "Light Attacks: %d",
    FIGHT_SUMMARY_TOTAL_SKILLS  = "Skill Casts: %d",
    FIGHT_SUMMARY_LONGEST_STREAK = "Longest Streak: %d",

    -- Skill breakdown columns
    SKILL_COL_NAME              = "Skill",
    SKILL_COL_CASTS             = "Casts",
    SKILL_COL_WEAVED            = "Weaved",
    SKILL_COL_MISSED            = "Missed",
    SKILL_COL_ACCURACY          = "Accuracy",
    SKILL_COL_AVG_GAP           = "Avg Gap (ms)",

    -- Fight summary buttons
    BTN_CLOSE                   = "Close",
    BTN_PIN_FIGHT               = "Pin Fight",
    BTN_EXPORT                  = "Export to Chat",

    -- History panel
    HISTORY_TITLE               = "WeaveForge - History",
    HISTORY_SESSION             = "This Session",
    HISTORY_ALL_TIME            = "All Time",
    HISTORY_FIGHTS              = "Fights: %d",
    HISTORY_AVG_ACCURACY        = "Avg Accuracy: %.1f%%",
    HISTORY_BEST_STREAK         = "Best Streak: %d",
    HISTORY_NO_DATA             = "No fight data recorded yet.",
    HISTORY_FILTER_ALL          = "All",
    HISTORY_FILTER_DUMMY        = "Target Dummy",
    HISTORY_FILTER_DUNGEON      = "Dungeon",
    HISTORY_FILTER_TRIAL        = "Trial",
    HISTORY_FILTER_SOLO         = "Solo/Overland",
    HISTORY_FILTER_PVP          = "PvP",

    -- History list columns
    HISTORY_COL_DATE            = "Date",
    HISTORY_COL_TARGET          = "Target",
    HISTORY_COL_DURATION        = "Duration",
    HISTORY_COL_ACCURACY        = "Accuracy",
    HISTORY_COL_LA_S            = "LA/s",
    HISTORY_COL_STREAK          = "Streak",

    -- Practice mode
    PRACTICE_TITLE              = "Practice Mode",
    PRACTICE_DUMMY_DETECTED     = "Target dummy detected - Practice mode active!",
    PRACTICE_LA_PER_SEC         = "LA/s: %.1f",
    PRACTICE_TIME_SINCE_LA      = "Last LA: %dms ago",
    PRACTICE_HISTOGRAM_TITLE    = "Timing Distribution",
    PRACTICE_HISTOGRAM_BUCKET   = "%d-%dms: %s (%d)",

    -- Settings panel
    SETTINGS_PANEL_NAME         = "WeaveForge",

    -- Settings: General
    SETTINGS_GENERAL            = "General",
    SETTINGS_ENABLE             = "Enable WeaveForge",
    SETTINGS_ENABLE_TT          = "Master toggle for the addon.",
    SETTINGS_ENABLE_PVP         = "Enable in PvP",
    SETTINGS_ENABLE_PVP_TT      = "Enable weave tracking in Cyrodiil, Battlegrounds, and Imperial City. Disabled by default since latency makes weaving different in PvP.",
    SETTINGS_COMBAT_ONLY        = "Combat Only",
    SETTINGS_COMBAT_ONLY_TT     = "Hide all UI elements when out of combat.",
    SETTINGS_FADE_DELAY         = "Fade Delay (seconds)",
    SETTINGS_FADE_DELAY_TT      = "How long to keep UI visible after combat ends.",

    -- Settings: Missed Weave Detector
    SETTINGS_MISSED_WEAVE       = "Missed Weave Detector",
    SETTINGS_MISSED_ENABLE      = "Enable Missed Weave Alerts",
    SETTINGS_MISSED_ENABLE_TT   = "Show a visual alert when you cast a skill without a preceding light attack.",
    SETTINGS_MISSED_STYLE       = "Alert Style",
    SETTINGS_MISSED_STYLE_TT    = "How the missed weave alert is displayed.",
    SETTINGS_MISSED_STYLE_ICON  = "Icon Flash",
    SETTINGS_MISSED_STYLE_EDGE  = "Screen Edge Flash",
    SETTINGS_MISSED_STYLE_RET   = "Reticle Color Change",
    SETTINGS_MISSED_SOUND       = "Alert Sound",
    SETTINGS_MISSED_SOUND_TT    = "Play a sound when a weave is missed.",
    SETTINGS_MISSED_SOUND_NONE  = "None",
    SETTINGS_MISSED_SOUND_CLICK = "Soft Click",
    SETTINGS_MISSED_SOUND_BUZZ  = "Error Buzz",
    SETTINGS_DETECT_WINDOW      = "Detection Window (ms)",
    SETTINGS_DETECT_WINDOW_TT   = "Maximum time between a light attack and skill cast to count as a successful weave.",
    SETTINGS_IGNORE_BARSWAP     = "Ignore Bar Swap Gaps",
    SETTINGS_IGNORE_BARSWAP_TT  = "Don't flag missed weaves immediately after a bar swap.",
    SETTINGS_IGNORE_HEAVY       = "Ignore Heavy Attacks",
    SETTINGS_IGNORE_HEAVY_TT    = "Don't flag missed weaves when a heavy attack is channeling.",

    -- Settings: Rhythm Bar
    SETTINGS_RHYTHM_BAR         = "Rhythm Bar",
    SETTINGS_RHYTHM_ENABLE      = "Enable Rhythm Bar",
    SETTINGS_RHYTHM_ENABLE_TT   = "Show a pulsing bar that visualizes the GCD timing.",
    SETTINGS_RHYTHM_WIDTH       = "Bar Width",
    SETTINGS_RHYTHM_HEIGHT      = "Bar Height",
    SETTINGS_RHYTHM_OPACITY     = "Bar Opacity",
    SETTINGS_RHYTHM_UNLOCK      = "Unlock Position",
    SETTINGS_RHYTHM_UNLOCK_TT   = "Allow dragging the rhythm bar to reposition it.",
    SETTINGS_RHYTHM_COLOR       = "Color Scheme",
    SETTINGS_RHYTHM_COLOR_TT    = "Color palette for the rhythm bar timing indicators.",
    SETTINGS_RHYTHM_COLOR_DEF   = "Default (Green/Yellow/Red)",
    SETTINGS_RHYTHM_COLOR_CB    = "Colorblind (Blue/Yellow/Orange)",
    SETTINGS_RHYTHM_COLOR_MONO  = "Monochrome",

    -- Settings: Streak Counter
    SETTINGS_STREAK             = "Streak Counter",
    SETTINGS_STREAK_ENABLE      = "Enable Streak Counter",
    SETTINGS_STREAK_ENABLE_TT   = "Show the current consecutive perfect-weave count.",
    SETTINGS_STREAK_SESSION     = "Show Session Best",
    SETTINGS_STREAK_SESSION_TT  = "Display the best streak achieved this session.",
    SETTINGS_STREAK_ALLTIME     = "Show All-Time Best",
    SETTINGS_STREAK_ALLTIME_TT  = "Display the all-time best streak for this character.",
    SETTINGS_STREAK_MILESTONE   = "Milestone Celebrations",
    SETTINGS_STREAK_MILESTONE_TT = "Flash a special effect at streak milestones (10, 25, 50, 100).",
    SETTINGS_STREAK_FONTSIZE    = "Font Size",

    -- Settings: Fight Summary
    SETTINGS_FIGHT              = "Fight Summary",
    SETTINGS_FIGHT_AUTOSHOW     = "Auto-Show After Fight",
    SETTINGS_FIGHT_AUTOSHOW_TT  = "Automatically open the fight summary panel when combat ends.",
    SETTINGS_FIGHT_MINDURATION  = "Minimum Fight Duration (seconds)",
    SETTINGS_FIGHT_MINDURATION_TT = "Only record fights longer than this duration. Helps ignore trivial trash pulls.",
    SETTINGS_FIGHT_MAXSTORED    = "Max Stored Fights",
    SETTINGS_FIGHT_MAXSTORED_TT = "Maximum number of fights to keep in history. Oldest fights are removed when the limit is reached.",

    -- Settings: Practice Mode
    SETTINGS_PRACTICE           = "Practice Mode",
    SETTINGS_PRACTICE_AUTO      = "Auto-Enable on Target Dummy",
    SETTINGS_PRACTICE_AUTO_TT   = "Automatically activate practice mode when hitting a target dummy.",
    SETTINGS_PRACTICE_METRO     = "Audio Metronome",
    SETTINGS_PRACTICE_METRO_TT  = "Play a metronome tick at the optimal GCD cadence.",
    SETTINGS_PRACTICE_METRO_VOL = "Metronome Volume",
    SETTINGS_PRACTICE_HISTOGRAM = "Show Timing Histogram After Parse",
    SETTINGS_PRACTICE_HISTOGRAM_TT = "Display a distribution of your LA-to-skill timing gaps after a practice fight.",
    SETTINGS_PRACTICE_GHOST     = "Show Ghost Bar",
    SETTINGS_PRACTICE_GHOST_TT  = "Overlay an ideal timing guide on the rhythm bar.",

    -- Settings: Advanced
    SETTINGS_ADVANCED           = "Advanced",
    SETTINGS_CUSTOM_LA_IDS      = "Custom LA Ability ID Overrides",
    SETTINGS_CUSTOM_LA_IDS_TT   = "Comma-separated list of additional ability IDs to treat as light attacks. For future-proofing new weapon types.",
    SETTINGS_DEBUG              = "Debug Mode",
    SETTINGS_DEBUG_TT           = "Print combat event data to chat for troubleshooting.",
    SETTINGS_EXPORT_BTN         = "Export Last Fight to Chat",
    SETTINGS_EXPORT_BTN_TT      = "Dump the last fight's summary as a copyable string in chat.",
    SETTINGS_RESET_ALL          = "Reset All Data",
    SETTINGS_RESET_ALL_TT       = "Clear all fight history and session data for this character.",
    SETTINGS_RESET_CONFIRM      = "Are you sure? This will delete all saved fight history for this character.",

    -- Time formatting
    TIME_FORMAT_SHORT           = "%dm %ds",
    TIME_FORMAT_SECONDS         = "%ds",

    -- Action Coach prompts
    COACH_LIGHT_ATTACK          = "Light Attack!",
    COACH_CAST_SKILL            = "Cast Skill!",
    COACH_CAST_SKILL_NOW        = "Cast Skill NOW!",
    COACH_CHARGING              = "Charging...",

    -- Onboarding: first-run welcome
    WELCOME_LINE_1              = "Welcome to WeaveForge! This addon coaches you on light attack weaving.",
    WELCOME_LINE_2              = "Weaving = tap light attack BEFORE each skill. This can boost your DPS by 20-40%.",
    WELCOME_LINE_3              = "The prompt near your crosshair tells you what to do: Light Attack -> Cast Skill -> repeat!",
    WELCOME_LINE_4              = "Type /wf help for commands, or /wf settings to customize.",

    -- Onboarding: contextual hints
    HINT_MISSED_WEAVE           = "Tip: That red flash means you cast a skill without a light attack first. Try: light attack -> skill -> light attack -> skill!",
    HINT_STREAK_SUCCESS         = "Nice! You're weaving! Keep that rhythm: light attack, skill, light attack, skill.",

    -- UI labels
    LABEL_WEAVE_STREAK          = "Weave Streak",

    -- Improved /wf help
    HELP_HEADER                 = "--- WeaveForge Help ---",
    HELP_WHAT_IS_WEAVING        = "Weaving = fit a light attack before every skill cast to maximize DPS.",
    HELP_HOW_TO_WEAVE           = "The rhythm: Light Attack -> Skill -> Light Attack -> Skill -> repeat. The prompt near your crosshair guides you!",
    HELP_BAR_EXPLANATION        = "The bar fills after each light attack. Cast your skill while it's green.",
    HELP_STREAK_EXPLANATION     = "The streak counter tracks consecutive perfect weaves. Miss one and it resets.",
    HELP_COMMANDS_HEADER        = "Commands:",

    -- Settings: Action Coach section
    SETTINGS_COACH              = "Action Coach",
    SETTINGS_COACH_ENABLE       = "Enable Action Coach",
    SETTINGS_COACH_ENABLE_TT    = "Show a real-time prompt telling you when to light attack and when to cast a skill.",
    SETTINGS_COACH_FONTSIZE     = "Prompt Font Size",
    SETTINGS_COACH_UNLOCK       = "Unlock Position",
    SETTINGS_COACH_UNLOCK_TT    = "Allow dragging the action coach prompt to reposition it.",
}
