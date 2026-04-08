-- WeaveForge — Real-Time Light Attack Weaving Coach for ESO
-- "Hammer your rhythm. Forge your DPS."
--
-- Main entry point: addon initialization, event registration, slash commands

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Help text (extracted so /wf help and unknown commands both use it)
---------------------------------------------------------------------------
local function ShowHelp()
    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HELP_HEADER)
    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HELP_WHAT_IS_WEAVING)
    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HELP_HOW_TO_WEAVE)
    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HELP_BAR_EXPLANATION)
    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HELP_STREAK_EXPLANATION)
    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HELP_COMMANDS_HEADER)
    CHAT_SYSTEM:AddMessage("  /wf          - Toggle fight summary")
    CHAT_SYSTEM:AddMessage("  /wf on|off   - Enable or disable WeaveForge")
    CHAT_SYSTEM:AddMessage("  /wf reset    - Reset session stats")
    CHAT_SYSTEM:AddMessage("  /wf history  - Toggle fight history panel")
    CHAT_SYSTEM:AddMessage("  /wf settings - Open settings")
    CHAT_SYSTEM:AddMessage("  /wf practice - Toggle practice mode")
    CHAT_SYSTEM:AddMessage("  /wf streak   - Show best streak")
    CHAT_SYSTEM:AddMessage("  /wf help     - Show this help")
end

---------------------------------------------------------------------------
-- Addon Loaded Handler
---------------------------------------------------------------------------
local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= WF.ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(WF.ADDON_NAME .. "_Init", EVENT_ADD_ON_LOADED)

    -- 1. Initialize SavedVariables
    WF.HistoryManager:Initialize()
    local accountSV   = WF.HistoryManager.accountSV
    local characterSV = WF.HistoryManager.characterSV

    -- 2. Apply localization based on client language
    local lang = GetCVar("Language.2") or "en"
    if lang == "de" and WF.L_de then
        WF.L = WF.L_de
        L = WF.L
    elseif lang == "fr" and WF.L_fr then
        WF.L = WF.L_fr
        L = WF.L
    elseif lang == "ru" and WF.L_ru then
        WF.L = WF.L_ru
        L = WF.L
    end

    -- 3. Initialize core modules
    WF.WeaveEngine:Initialize(accountSV, characterSV)
    WF.FightRecorder:Initialize(accountSV)

    -- 4. Initialize UI elements
    WF.RhythmBar:Initialize(accountSV)
    WF.StreakCounter:Initialize(accountSV, characterSV)
    WF.MissedWeaveAlert:Initialize(accountSV)
    WF.ActionCoach:Initialize(accountSV)
    WF.FightSummaryPanel:Initialize(accountSV)
    WF.HistoryPanel:Initialize(accountSV)
    WF.PracticeModeOverlay:Initialize(accountSV)

    -- 5. Initialize settings panel (requires LibAddonMenu-2.0)
    WF.Settings:Initialize(accountSV)

    -- 6. Start the engine if enabled
    if accountSV.enabled then
        WF.WeaveEngine:Start()
    end

    -- 7. Register slash commands
    WF:RegisterSlashCommands()

    -- 8. Register onboarding hint for streak success
    CALLBACK_MANAGER:RegisterCallback(WF.EVENT_WEAVE_SUCCESS, function(streak)
        if streak == 5 then
            local ob = accountSV.onboarding
            if ob and ob.hintStreakSuccessCount < ob.hintMaxPerType then
                ob.hintStreakSuccessCount = ob.hintStreakSuccessCount + 1
                if CHAT_SYSTEM then
                    CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HINT_STREAK_SUCCESS)
                end
            end
        end
    end)

    -- Startup message
    if CHAT_SYSTEM and accountSV.enabled then
        CHAT_SYSTEM:AddMessage(
            L.CHAT_PREFIX .. L.ADDON_NAME .. " v" .. WF.ADDON_VERSION .. " loaded."
        )
    end

    -- 9. First-run welcome (once per account, delayed so it's visible)
    if not accountSV.firstRunDone then
        accountSV.firstRunDone = true
        zo_callLater(function()
            if CHAT_SYSTEM then
                CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.WELCOME_LINE_1)
                CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.WELCOME_LINE_2)
                CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.WELCOME_LINE_3)
                CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.WELCOME_LINE_4)
            end
        end, 2000)
    end
end

---------------------------------------------------------------------------
-- Slash Command Registration
---------------------------------------------------------------------------
function WF:RegisterSlashCommands()
    SLASH_COMMANDS["/wf"] = function(args)
        local cmd = string.lower(args or ""):match("^%s*(.-)%s*$")

        if cmd == "" then
            -- Toggle fight summary panel
            WF.FightSummaryPanel:Toggle()

        elseif cmd == "on" then
            WF.HistoryManager.accountSV.enabled = true
            WF.WeaveEngine:Start()

        elseif cmd == "off" then
            WF.HistoryManager.accountSV.enabled = false
            WF.WeaveEngine:Stop()

        elseif cmd == "reset" then
            WF.WeaveEngine:ResetSession()
            WF.StreakCounter:ResetSession()

        elseif cmd == "history" then
            WF.HistoryPanel:Toggle()

        elseif cmd == "settings" then
            WF.Settings:OpenPanel()

        elseif cmd == "practice" then
            WF.WeaveEngine:TogglePracticeMode()
            WF.PracticeModeOverlay:Toggle()

        elseif cmd == "streak" then
            local allTime = WF.HistoryManager:GetAllTimeBestStreak()
            local session = WF.WeaveEngine:GetSessionBestStreak()
            CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. string.format(L.STREAK_BEST_ALLTIME, allTime)
                .. " | " .. string.format(L.STREAK_BEST_SESSION, session))

        elseif cmd == "debugla" then
            WF.WeaveEngine:ToggleDebugMode()

        elseif cmd == "help" then
            ShowHelp()

        else
            ShowHelp()
        end
    end
end

---------------------------------------------------------------------------
-- Register for addon loaded event
---------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(WF.ADDON_NAME .. "_Init", EVENT_ADD_ON_LOADED, OnAddonLoaded)
