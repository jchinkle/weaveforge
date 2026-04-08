-- WeaveForge — Real-Time Light Attack Weaving Coach for ESO
-- "Hammer your rhythm. Forge your DPS."
--
-- Main entry point: addon initialization, event registration, slash commands

local WF = WeaveForge
local L  = WF.L

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

    -- Startup complete
    if CHAT_SYSTEM and accountSV.enabled then
        CHAT_SYSTEM:AddMessage(
            L.CHAT_PREFIX .. L.ADDON_NAME .. " v" .. WF.ADDON_VERSION .. " loaded."
        )
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

        else
            -- Unknown command - show help
            CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. "Usage:")
            CHAT_SYSTEM:AddMessage("  /wf          - Toggle fight summary")
            CHAT_SYSTEM:AddMessage("  /wf on       - Enable WeaveForge")
            CHAT_SYSTEM:AddMessage("  /wf off      - Disable WeaveForge")
            CHAT_SYSTEM:AddMessage("  /wf reset    - Reset session stats")
            CHAT_SYSTEM:AddMessage("  /wf history  - Toggle history panel")
            CHAT_SYSTEM:AddMessage("  /wf settings - Open settings")
            CHAT_SYSTEM:AddMessage("  /wf practice - Toggle practice mode")
            CHAT_SYSTEM:AddMessage("  /wf streak   - Show best streak")
            CHAT_SYSTEM:AddMessage("  /wf debugla  - Toggle debug mode")
        end
    end
end

---------------------------------------------------------------------------
-- Register for addon loaded event
---------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(WF.ADDON_NAME .. "_Init", EVENT_ADD_ON_LOADED, OnAddonLoaded)
