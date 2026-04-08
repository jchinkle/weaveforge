-- WeaveForge Settings
-- LibAddonMenu-2.0 settings panel with all addon configuration options

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local Settings = {}
WF.Settings = Settings

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function Settings:Initialize(accountSV)
    local LAM = LibAddonMenu2
    if not LAM then return end

    local sv = accountSV

    -- Panel registration
    local panelData = {
        type               = "panel",
        name               = L.SETTINGS_PANEL_NAME,
        displayName        = "|cFFD700WeaveForge|r",
        author             = "WeaveForge Team",
        version            = WF.ADDON_VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel("WeaveForgeOptions", panelData)

    -- Build all option controls
    local optionsData = {}

    -- =====================================================================
    -- General Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_GENERAL,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_ENABLE,
        tooltip = L.SETTINGS_ENABLE_TT,
        getFunc = function() return sv.enabled end,
        setFunc = function(value)
            sv.enabled = value
            if value then
                WF.WeaveEngine:Start()
            else
                WF.WeaveEngine:Stop()
            end
        end,
        default = WF.ACCOUNT_DEFAULTS.enabled,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_ENABLE_PVP,
        tooltip = L.SETTINGS_ENABLE_PVP_TT,
        getFunc = function() return sv.enableInPvP end,
        setFunc = function(value) sv.enableInPvP = value end,
        default = WF.ACCOUNT_DEFAULTS.enableInPvP,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_COMBAT_ONLY,
        tooltip = L.SETTINGS_COMBAT_ONLY_TT,
        getFunc = function() return sv.combatOnly end,
        setFunc = function(value) sv.combatOnly = value end,
        default = WF.ACCOUNT_DEFAULTS.combatOnly,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_FADE_DELAY,
        tooltip = L.SETTINGS_FADE_DELAY_TT,
        min = 0,
        max = 10,
        step = 1,
        getFunc = function() return sv.fadeDelay end,
        setFunc = function(value) sv.fadeDelay = value end,
        default = WF.ACCOUNT_DEFAULTS.fadeDelay,
    }

    -- =====================================================================
    -- Missed Weave Detector Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_MISSED_WEAVE,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_MISSED_ENABLE,
        tooltip = L.SETTINGS_MISSED_ENABLE_TT,
        getFunc = function() return sv.missedAlert.enabled end,
        setFunc = function(value)
            sv.missedAlert.enabled = value
            WF.MissedWeaveAlert:SetEnabled(value)
        end,
        default = WF.ACCOUNT_DEFAULTS.missedAlert.enabled,
    }

    optionsData[#optionsData + 1] = {
        type = "dropdown",
        name = L.SETTINGS_MISSED_STYLE,
        tooltip = L.SETTINGS_MISSED_STYLE_TT,
        choices = { L.SETTINGS_MISSED_STYLE_ICON, L.SETTINGS_MISSED_STYLE_EDGE, L.SETTINGS_MISSED_STYLE_RET },
        choicesValues = { WF.ALERT_STYLE.ICON_FLASH, WF.ALERT_STYLE.EDGE_FLASH, WF.ALERT_STYLE.RETICLE_COLOR },
        getFunc = function() return sv.missedAlert.style end,
        setFunc = function(value) sv.missedAlert.style = value end,
        default = WF.ACCOUNT_DEFAULTS.missedAlert.style,
    }

    optionsData[#optionsData + 1] = {
        type = "dropdown",
        name = L.SETTINGS_MISSED_SOUND,
        tooltip = L.SETTINGS_MISSED_SOUND_TT,
        choices = { L.SETTINGS_MISSED_SOUND_NONE, L.SETTINGS_MISSED_SOUND_CLICK, L.SETTINGS_MISSED_SOUND_BUZZ },
        choicesValues = { WF.ALERT_SOUND.NONE, WF.ALERT_SOUND.CLICK, WF.ALERT_SOUND.BUZZ },
        getFunc = function() return sv.missedAlert.sound end,
        setFunc = function(value) sv.missedAlert.sound = value end,
        default = WF.ACCOUNT_DEFAULTS.missedAlert.sound,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_DETECT_WINDOW,
        tooltip = L.SETTINGS_DETECT_WINDOW_TT,
        min = 600,
        max = 1500,
        step = 50,
        getFunc = function() return sv.missedAlert.detectionWindow end,
        setFunc = function(value) sv.missedAlert.detectionWindow = value end,
        default = WF.ACCOUNT_DEFAULTS.missedAlert.detectionWindow,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_IGNORE_BARSWAP,
        tooltip = L.SETTINGS_IGNORE_BARSWAP_TT,
        getFunc = function() return sv.missedAlert.ignoreBarSwap end,
        setFunc = function(value) sv.missedAlert.ignoreBarSwap = value end,
        default = WF.ACCOUNT_DEFAULTS.missedAlert.ignoreBarSwap,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_IGNORE_HEAVY,
        tooltip = L.SETTINGS_IGNORE_HEAVY_TT,
        getFunc = function() return sv.missedAlert.ignoreHeavy end,
        setFunc = function(value) sv.missedAlert.ignoreHeavy = value end,
        default = WF.ACCOUNT_DEFAULTS.missedAlert.ignoreHeavy,
    }

    -- =====================================================================
    -- Rhythm Bar Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_RHYTHM_BAR,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_RHYTHM_ENABLE,
        tooltip = L.SETTINGS_RHYTHM_ENABLE_TT,
        getFunc = function() return sv.rhythmBar.enabled end,
        setFunc = function(value)
            WF.RhythmBar:SetEnabled(value)
        end,
        default = WF.ACCOUNT_DEFAULTS.rhythmBar.enabled,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_RHYTHM_WIDTH,
        min = 100,
        max = 400,
        step = 10,
        getFunc = function() return sv.rhythmBar.width end,
        setFunc = function(value)
            sv.rhythmBar.width = value
            WF.RhythmBar:UpdateDimensions()
        end,
        default = WF.ACCOUNT_DEFAULTS.rhythmBar.width,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_RHYTHM_HEIGHT,
        min = 2,
        max = 12,
        step = 1,
        getFunc = function() return sv.rhythmBar.height end,
        setFunc = function(value)
            sv.rhythmBar.height = value
            WF.RhythmBar:UpdateDimensions()
        end,
        default = WF.ACCOUNT_DEFAULTS.rhythmBar.height,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_RHYTHM_OPACITY,
        min = 30,
        max = 100,
        step = 5,
        getFunc = function() return math.floor(sv.rhythmBar.opacity * 100) end,
        setFunc = function(value)
            sv.rhythmBar.opacity = value / 100
            WF.RhythmBar:UpdateOpacity()
        end,
        default = math.floor(WF.ACCOUNT_DEFAULTS.rhythmBar.opacity * 100),
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_RHYTHM_UNLOCK,
        tooltip = L.SETTINGS_RHYTHM_UNLOCK_TT,
        getFunc = function() return sv.rhythmBar.unlocked end,
        setFunc = function(value)
            sv.rhythmBar.unlocked = value
            WF.RhythmBar:UpdateMovable()
        end,
        default = WF.ACCOUNT_DEFAULTS.rhythmBar.unlocked,
    }

    optionsData[#optionsData + 1] = {
        type = "dropdown",
        name = L.SETTINGS_RHYTHM_COLOR,
        tooltip = L.SETTINGS_RHYTHM_COLOR_TT,
        choices = { L.SETTINGS_RHYTHM_COLOR_DEF, L.SETTINGS_RHYTHM_COLOR_CB, L.SETTINGS_RHYTHM_COLOR_MONO },
        choicesValues = { "default", "colorblind", "monochrome" },
        getFunc = function() return sv.rhythmBar.colorScheme end,
        setFunc = function(value)
            sv.rhythmBar.colorScheme = value
            WF.RhythmBar:ApplyColorScheme()
        end,
        default = WF.ACCOUNT_DEFAULTS.rhythmBar.colorScheme,
    }

    -- =====================================================================
    -- Streak Counter Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_STREAK,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_STREAK_ENABLE,
        tooltip = L.SETTINGS_STREAK_ENABLE_TT,
        getFunc = function() return sv.streakCounter.enabled end,
        setFunc = function(value)
            WF.StreakCounter:SetEnabled(value)
        end,
        default = WF.ACCOUNT_DEFAULTS.streakCounter.enabled,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_STREAK_SESSION,
        tooltip = L.SETTINGS_STREAK_SESSION_TT,
        getFunc = function() return sv.streakCounter.showSessionBest end,
        setFunc = function(value)
            sv.streakCounter.showSessionBest = value
            WF.StreakCounter:Refresh()
        end,
        default = WF.ACCOUNT_DEFAULTS.streakCounter.showSessionBest,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_STREAK_ALLTIME,
        tooltip = L.SETTINGS_STREAK_ALLTIME_TT,
        getFunc = function() return sv.streakCounter.showAllTimeBest end,
        setFunc = function(value)
            sv.streakCounter.showAllTimeBest = value
            WF.StreakCounter:Refresh()
        end,
        default = WF.ACCOUNT_DEFAULTS.streakCounter.showAllTimeBest,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_STREAK_MILESTONE,
        tooltip = L.SETTINGS_STREAK_MILESTONE_TT,
        getFunc = function() return sv.streakCounter.milestones end,
        setFunc = function(value) sv.streakCounter.milestones = value end,
        default = WF.ACCOUNT_DEFAULTS.streakCounter.milestones,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_STREAK_FONTSIZE,
        min = 12,
        max = 36,
        step = 2,
        getFunc = function() return sv.streakCounter.fontSize end,
        setFunc = function(value)
            sv.streakCounter.fontSize = value
            WF.StreakCounter:UpdateFontSize()
        end,
        default = WF.ACCOUNT_DEFAULTS.streakCounter.fontSize,
    }

    -- =====================================================================
    -- Action Coach Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_COACH,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_COACH_ENABLE,
        tooltip = L.SETTINGS_COACH_ENABLE_TT,
        getFunc = function() return sv.actionCoach.enabled end,
        setFunc = function(value)
            WF.ActionCoach:SetEnabled(value)
        end,
        default = WF.ACCOUNT_DEFAULTS.actionCoach.enabled,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_COACH_FONTSIZE,
        min = 14,
        max = 36,
        step = 2,
        getFunc = function() return sv.actionCoach.fontSize end,
        setFunc = function(value)
            sv.actionCoach.fontSize = value
            WF.ActionCoach:UpdateFontSize()
        end,
        default = WF.ACCOUNT_DEFAULTS.actionCoach.fontSize,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_COACH_UNLOCK,
        tooltip = L.SETTINGS_COACH_UNLOCK_TT,
        getFunc = function() return sv.actionCoach.unlocked end,
        setFunc = function(value)
            sv.actionCoach.unlocked = value
            WF.ActionCoach:UpdateMovable()
        end,
        default = WF.ACCOUNT_DEFAULTS.actionCoach.unlocked,
    }

    -- =====================================================================
    -- Fight Summary Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_FIGHT,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_FIGHT_AUTOSHOW,
        tooltip = L.SETTINGS_FIGHT_AUTOSHOW_TT,
        getFunc = function() return sv.fightSummary.autoShow end,
        setFunc = function(value) sv.fightSummary.autoShow = value end,
        default = WF.ACCOUNT_DEFAULTS.fightSummary.autoShow,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_FIGHT_MINDURATION,
        tooltip = L.SETTINGS_FIGHT_MINDURATION_TT,
        min = 3,
        max = 60,
        step = 1,
        getFunc = function() return sv.fightSummary.minDuration end,
        setFunc = function(value) sv.fightSummary.minDuration = value end,
        default = WF.ACCOUNT_DEFAULTS.fightSummary.minDuration,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_FIGHT_MAXSTORED,
        tooltip = L.SETTINGS_FIGHT_MAXSTORED_TT,
        min = 5,
        max = 50,
        step = 5,
        getFunc = function() return sv.fightSummary.maxStoredFights end,
        setFunc = function(value) sv.fightSummary.maxStoredFights = value end,
        default = WF.ACCOUNT_DEFAULTS.fightSummary.maxStoredFights,
    }

    -- =====================================================================
    -- Practice Mode Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_PRACTICE,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_PRACTICE_AUTO,
        tooltip = L.SETTINGS_PRACTICE_AUTO_TT,
        getFunc = function() return sv.practiceMode.autoEnable end,
        setFunc = function(value) sv.practiceMode.autoEnable = value end,
        default = WF.ACCOUNT_DEFAULTS.practiceMode.autoEnable,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_PRACTICE_METRO,
        tooltip = L.SETTINGS_PRACTICE_METRO_TT,
        getFunc = function() return sv.practiceMode.metronome end,
        setFunc = function(value) sv.practiceMode.metronome = value end,
        default = WF.ACCOUNT_DEFAULTS.practiceMode.metronome,
    }

    optionsData[#optionsData + 1] = {
        type = "slider",
        name = L.SETTINGS_PRACTICE_METRO_VOL,
        min = 10,
        max = 100,
        step = 10,
        getFunc = function() return math.floor(sv.practiceMode.metronomeVolume * 100) end,
        setFunc = function(value) sv.practiceMode.metronomeVolume = value / 100 end,
        default = math.floor(WF.ACCOUNT_DEFAULTS.practiceMode.metronomeVolume * 100),
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_PRACTICE_HISTOGRAM,
        tooltip = L.SETTINGS_PRACTICE_HISTOGRAM_TT,
        getFunc = function() return sv.practiceMode.showHistogram end,
        setFunc = function(value) sv.practiceMode.showHistogram = value end,
        default = WF.ACCOUNT_DEFAULTS.practiceMode.showHistogram,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_PRACTICE_GHOST,
        tooltip = L.SETTINGS_PRACTICE_GHOST_TT,
        getFunc = function() return sv.practiceMode.showGhostBar end,
        setFunc = function(value) sv.practiceMode.showGhostBar = value end,
        default = WF.ACCOUNT_DEFAULTS.practiceMode.showGhostBar,
    }

    -- =====================================================================
    -- Advanced Section
    -- =====================================================================
    optionsData[#optionsData + 1] = {
        type = "header",
        name = L.SETTINGS_ADVANCED,
    }

    optionsData[#optionsData + 1] = {
        type = "editbox",
        name = L.SETTINGS_CUSTOM_LA_IDS,
        tooltip = L.SETTINGS_CUSTOM_LA_IDS_TT,
        isMultiline = false,
        getFunc = function() return sv.advanced.customLAIds end,
        setFunc = function(value)
            sv.advanced.customLAIds = value
            WF.WeaveEngine:ParseCustomLAIds()
        end,
        default = WF.ACCOUNT_DEFAULTS.advanced.customLAIds,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = L.SETTINGS_DEBUG,
        tooltip = L.SETTINGS_DEBUG_TT,
        getFunc = function() return sv.advanced.debugMode end,
        setFunc = function(value)
            WF.WeaveEngine:SetDebugMode(value)
        end,
        default = WF.ACCOUNT_DEFAULTS.advanced.debugMode,
    }

    optionsData[#optionsData + 1] = {
        type = "button",
        name = L.SETTINGS_EXPORT_BTN,
        tooltip = L.SETTINGS_EXPORT_BTN_TT,
        func = function()
            local lastFight = WF.HistoryManager:GetLastFight()
            if lastFight then
                WF.FightRecorder:ExportToChat(lastFight)
            end
        end,
    }

    optionsData[#optionsData + 1] = {
        type = "button",
        name = L.SETTINGS_RESET_ALL,
        tooltip = L.SETTINGS_RESET_ALL_TT,
        isDangerous = true,
        func = function()
            WF.HistoryManager:ResetCharacterData()
            WF.WeaveEngine:ResetSession()
            WF.StreakCounter:ResetSession()
        end,
        warning = L.SETTINGS_RESET_CONFIRM,
    }

    -- Register all controls
    LAM:RegisterOptionControls("WeaveForgeOptions", optionsData)
end

---------------------------------------------------------------------------
-- Open settings panel
---------------------------------------------------------------------------
function Settings:OpenPanel()
    local LAM = LibAddonMenu2
    if LAM then
        LAM:OpenToPanel("WeaveForgeOptions")
    end
end
