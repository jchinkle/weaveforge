-- WeaveForge WeaveEngine
-- Core detection logic: light attack tracking, skill tracking, timing math
-- This is the performance-critical hot path. All state is local for speed.

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local WeaveEngine = {}
WF.WeaveEngine = WeaveEngine

---------------------------------------------------------------------------
-- Local state (file-scope locals for register-level access speed)
---------------------------------------------------------------------------
local lastLATime        = 0       -- GetGameTimeMilliseconds() of last light attack
local lastLAAbilityId   = 0       -- abilityId of last LA (for weapon classification)
local lastSkillTime     = 0       -- timestamp of last ability used
local lastSkillId       = 0       -- abilityId of last skill
local currentStreak     = 0       -- consecutive successful weaves
local sessionBestStreak = 0       -- best streak this session
local isInCombat        = false
local isDead            = false
local isHeavyAttacking  = false
local heavyAttackEndTimer = nil   -- handle for zo_callLater HA end timer
local suppressUntil     = 0       -- suppress miss detection until this time (bar swap grace)
local lastBarSwapTime   = 0
local isRunning         = false   -- whether the engine is actively processing events
local isPracticeMode    = false
local debugMode         = false

-- Cached references (set during Initialize)
local settings          = nil     -- reference to account saved vars
local charData          = nil     -- reference to character saved vars
local LA_IDS            = WF.LA_ABILITY_IDS
local HA_IDS            = WF.HA_ABILITY_IDS
local OFF_GCD           = WF.OFF_GCD_ABILITIES
local HA_DURATIONS      = WF.HA_CHANNEL_DURATIONS
local MILESTONES        = WF.STREAK_MILESTONES

---------------------------------------------------------------------------
-- Callback event names (used with CALLBACK_MANAGER)
---------------------------------------------------------------------------
WF.EVENT_WEAVE_SUCCESS      = "WeaveForge_WeaveSuccess"
WF.EVENT_WEAVE_MISS         = "WeaveForge_WeaveMiss"
WF.EVENT_LIGHT_ATTACK       = "WeaveForge_LightAttack"
WF.EVENT_HEAVY_ATTACK_START = "WeaveForge_HeavyAttackStart"
WF.EVENT_HEAVY_ATTACK_END   = "WeaveForge_HeavyAttackEnd"
WF.EVENT_STREAK_MILESTONE   = "WeaveForge_StreakMilestone"
WF.EVENT_STREAK_RESET       = "WeaveForge_StreakReset"
WF.EVENT_COMBAT_START       = "WeaveForge_CombatStart"
WF.EVENT_COMBAT_END         = "WeaveForge_CombatEnd"
WF.EVENT_BAR_SWAP           = "WeaveForge_BarSwap"
WF.EVENT_PRACTICE_MODE      = "WeaveForge_PracticeMode"
WF.EVENT_SKILL_USED         = "WeaveForge_SkillUsed"

---------------------------------------------------------------------------
-- Namespace constants for event registration
---------------------------------------------------------------------------
local NS_COMBAT     = "WeaveForge_Combat"
local NS_ABILITY    = "WeaveForge_Ability"
local NS_STATE      = "WeaveForge_CombatState"
local NS_BARSWAP    = "WeaveForge_BarSwap"
local NS_DEATH      = "WeaveForge_Death"
local NS_ALIVE      = "WeaveForge_Alive"
local NS_EFFECT     = "WeaveForge_Effect"
local NS_ZONE       = "WeaveForge_Zone"

---------------------------------------------------------------------------
-- Utility: chat output
---------------------------------------------------------------------------
local function ChatMessage(msg)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. msg)
    end
end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function WeaveEngine:Initialize(accountSV, characterSV)
    settings = accountSV
    charData = characterSV
    debugMode = settings.advanced.debugMode

    -- Parse custom LA IDs from settings
    self:ParseCustomLAIds()

    -- Set up sound mappings now that SOUNDS global is available
    if SOUNDS then
        WF.ALERT_SOUND_MAP[2] = SOUNDS.QUICKSLOT_USE_EMPTY
        WF.ALERT_SOUND_MAP[3] = SOUNDS.GENERAL_ALERT_ERROR
    end
end

---------------------------------------------------------------------------
-- Parse custom LA ability IDs from settings text field
---------------------------------------------------------------------------
function WeaveEngine:ParseCustomLAIds()
    local custom = settings.advanced.customLAIds or ""
    for idStr in custom:gmatch("(%d+)") do
        local id = tonumber(idStr)
        if id then
            LA_IDS[id] = "Custom"
        end
    end
end

---------------------------------------------------------------------------
-- Start / Stop engine
---------------------------------------------------------------------------
function WeaveEngine:Start()
    if isRunning then return end
    isRunning = true
    self:RegisterEvents()
    ChatMessage(L.CHAT_ENABLED)
end

function WeaveEngine:Stop()
    if not isRunning then return end
    isRunning = false
    self:UnregisterEvents()

    -- If we were in combat, end the fight
    if isInCombat then
        self:HandleCombatEnd()
    end

    ChatMessage(L.CHAT_DISABLED)
end

---------------------------------------------------------------------------
-- Event Registration
---------------------------------------------------------------------------
function WeaveEngine:RegisterEvents()
    local em = EVENT_MANAGER

    -- Combat events with C-side player filter for performance
    em:RegisterForEvent(NS_COMBAT, EVENT_COMBAT_EVENT, function(...) self:OnCombatEvent(...) end)
    em:AddFilterForEvent(NS_COMBAT, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    em:AddFilterForEvent(NS_COMBAT, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_IS_ERROR, false)

    -- Ability used on action bar
    em:RegisterForEvent(NS_ABILITY, EVENT_ACTION_SLOT_ABILITY_USED, function(...) self:OnAbilityUsed(...) end)

    -- Combat state
    em:RegisterForEvent(NS_STATE, EVENT_PLAYER_COMBAT_STATE, function(...) self:OnCombatState(...) end)

    -- Bar swap
    em:RegisterForEvent(NS_BARSWAP, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function(...) self:OnBarSwap(...) end)

    -- Death / alive
    em:RegisterForEvent(NS_DEATH, EVENT_PLAYER_DEAD, function(...) self:OnPlayerDead(...) end)
    em:RegisterForEvent(NS_ALIVE, EVENT_PLAYER_ALIVE, function(...) self:OnPlayerAlive(...) end)

    -- Effect changes (for dummy detection, CC detection) - filtered to player
    em:RegisterForEvent(NS_EFFECT, EVENT_EFFECT_CHANGED, function(...) self:OnEffectChanged(...) end)
    em:AddFilterForEvent(NS_EFFECT, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")
end

function WeaveEngine:UnregisterEvents()
    local em = EVENT_MANAGER
    em:UnregisterForEvent(NS_COMBAT, EVENT_COMBAT_EVENT)
    em:UnregisterForEvent(NS_ABILITY, EVENT_ACTION_SLOT_ABILITY_USED)
    em:UnregisterForEvent(NS_STATE, EVENT_PLAYER_COMBAT_STATE)
    em:UnregisterForEvent(NS_BARSWAP, EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
    em:UnregisterForEvent(NS_DEATH, EVENT_PLAYER_DEAD)
    em:UnregisterForEvent(NS_ALIVE, EVENT_PLAYER_ALIVE)
    em:UnregisterForEvent(NS_EFFECT, EVENT_EFFECT_CHANGED)
end

---------------------------------------------------------------------------
-- Core Combat Event Handler (HOT PATH - keep lean)
---------------------------------------------------------------------------
function WeaveEngine:OnCombatEvent(eventCode, result, isError, abilityName,
    abilityGraphic, abilityActionSlotType, sourceName, sourceType,
    targetName, targetType, hitValue, powerType, damageType, log,
    sourceUnitId, targetUnitId, abilityId, overflow)

    -- Light attack detection (primary method: slot type check)
    if abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then
        local now = GetGameTimeMilliseconds()
        lastLATime = now
        lastLAAbilityId = abilityId

        -- Cancel any heavy attack state
        if isHeavyAttacking then
            isHeavyAttacking = false
            if heavyAttackEndTimer then
                zo_removeCallLater(heavyAttackEndTimer)
                heavyAttackEndTimer = nil
            end
        end

        -- Fire callback for UI (rhythm bar, practice mode)
        local weaponType = LA_IDS[abilityId] or "Unknown"
        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_LIGHT_ATTACK, now, abilityId, weaponType)

        if debugMode then
            ChatMessage(zo_strformat(L.CHAT_DEBUG_LA, abilityId, abilityName, weaponType))
        end
        return
    end

    -- Heavy attack detection
    if abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
        isHeavyAttacking = true
        local weaponType = HA_IDS[abilityId] or "Unknown"
        local channelTime = HA_DURATIONS[weaponType] or 1500

        -- Set a timer to end heavy attack state
        if heavyAttackEndTimer then
            zo_removeCallLater(heavyAttackEndTimer)
        end
        heavyAttackEndTimer = zo_callLater(function()
            isHeavyAttacking = false
            heavyAttackEndTimer = nil
            CALLBACK_MANAGER:FireCallbacks(WF.EVENT_HEAVY_ATTACK_END)
        end, channelTime)

        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_HEAVY_ATTACK_START, abilityId, weaponType)

        if debugMode then
            ChatMessage(zo_strformat(L.CHAT_DEBUG_HA, abilityId, abilityName))
        end
        return
    end
end

---------------------------------------------------------------------------
-- Ability Used Handler (skill activation from action bar)
-- This fires when the player activates a slotted skill
---------------------------------------------------------------------------
function WeaveEngine:OnAbilityUsed(eventCode, slotIndex)
    if not isInCombat then return end
    if isDead then return end

    -- Get ability info for this slot
    local abilityId = GetSlotBoundId(slotIndex)
    if not abilityId or abilityId == 0 then return end

    -- Skip off-GCD abilities
    if OFF_GCD[abilityId] then return end

    -- Skip light attack and heavy attack slot types
    -- (slots 1-5 are skill slots, 6 is ult, 7/8 are LA/HA on some configs)
    if slotIndex < 3 or slotIndex > 8 then return end

    local now = GetGameTimeMilliseconds()
    local detectionWindow = settings.missedAlert.detectionWindow

    -- Check if we're in bar swap grace period
    if settings.missedAlert.ignoreBarSwap and now < suppressUntil then
        -- Don't evaluate this skill - bar swap grace period
        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_SKILL_USED, abilityId, slotIndex, nil, true)
        return
    end

    -- Check if heavy attacking and we should ignore
    if settings.missedAlert.ignoreHeavy and isHeavyAttacking then
        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_SKILL_USED, abilityId, slotIndex, nil, true)
        return
    end

    local timeSinceLA = now - lastLATime

    if lastLATime > 0 and timeSinceLA <= detectionWindow then
        -- SUCCESSFUL WEAVE
        currentStreak = currentStreak + 1
        if currentStreak > sessionBestStreak then
            sessionBestStreak = currentStreak
        end

        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_WEAVE_SUCCESS,
            currentStreak, timeSinceLA, abilityId, slotIndex)

        -- Check for milestone
        if settings.streakCounter.milestones and MILESTONES[currentStreak] then
            CALLBACK_MANAGER:FireCallbacks(WF.EVENT_STREAK_MILESTONE, currentStreak)
        end
    else
        -- MISSED WEAVE
        local previousStreak = currentStreak
        if currentStreak > 0 then
            CALLBACK_MANAGER:FireCallbacks(WF.EVENT_STREAK_RESET, currentStreak)
        end
        currentStreak = 0

        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_WEAVE_MISS,
            abilityId, slotIndex, timeSinceLA)
    end

    CALLBACK_MANAGER:FireCallbacks(WF.EVENT_SKILL_USED, abilityId, slotIndex, timeSinceLA, false)

    if debugMode then
        local abilityName = GetAbilityName(abilityId) or "Unknown"
        ChatMessage(zo_strformat(L.CHAT_DEBUG_SKILL, slotIndex, abilityId, abilityName))
    end

    lastSkillTime = now
    lastSkillId = abilityId
end

---------------------------------------------------------------------------
-- Combat State Handler
---------------------------------------------------------------------------
function WeaveEngine:OnCombatState(eventCode, inCombat)
    if inCombat and not isInCombat then
        -- Entering combat
        isInCombat = true
        self:ResetWeaveState()
        CALLBACK_MANAGER:FireCallbacks(WF.EVENT_COMBAT_START)
    elseif not inCombat and isInCombat then
        -- Leaving combat - delay finalization to catch late events
        zo_callLater(function()
            if not IsUnitInCombat("player") then
                self:HandleCombatEnd()
            end
        end, WF.COMBAT_END_DELAY_MS)
    end
end

function WeaveEngine:HandleCombatEnd()
    if not isInCombat then return end
    isInCombat = false

    -- Save best streak
    if currentStreak > sessionBestStreak then
        sessionBestStreak = currentStreak
    end

    CALLBACK_MANAGER:FireCallbacks(WF.EVENT_COMBAT_END, sessionBestStreak)

    -- Reset for next fight
    self:ResetWeaveState()
end

---------------------------------------------------------------------------
-- Bar Swap Handler
---------------------------------------------------------------------------
function WeaveEngine:OnBarSwap(eventCode, activeWeaponPair, locked)
    local now = GetGameTimeMilliseconds()
    lastBarSwapTime = now
    lastLATime = 0  -- LA on previous bar doesn't count for next bar
    lastLAAbilityId = 0

    -- Set grace period for miss detection suppression
    suppressUntil = now + WF.BAR_SWAP_GRACE_MS

    CALLBACK_MANAGER:FireCallbacks(WF.EVENT_BAR_SWAP, activeWeaponPair)
end

---------------------------------------------------------------------------
-- Death / Alive Handlers
---------------------------------------------------------------------------
function WeaveEngine:OnPlayerDead()
    isDead = true
end

function WeaveEngine:OnPlayerAlive()
    isDead = false
    self:ResetWeaveState()
end

---------------------------------------------------------------------------
-- Effect Changed Handler (for target dummy detection)
---------------------------------------------------------------------------
function WeaveEngine:OnEffectChanged(eventCode, changeType, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType,
    abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)

    -- Check for target dummy buff
    if WF.DUMMY_BUFF_ABILITY_IDS[abilityId] then
        if changeType == EFFECT_RESULT_GAINED and settings.practiceMode.autoEnable then
            if not isPracticeMode then
                isPracticeMode = true
                CALLBACK_MANAGER:FireCallbacks(WF.EVENT_PRACTICE_MODE, true)
            end
        elseif changeType == EFFECT_RESULT_FADED then
            if isPracticeMode then
                isPracticeMode = false
                CALLBACK_MANAGER:FireCallbacks(WF.EVENT_PRACTICE_MODE, false)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Reset Weave State
---------------------------------------------------------------------------
function WeaveEngine:ResetWeaveState()
    lastLATime = 0
    lastLAAbilityId = 0
    lastSkillTime = 0
    lastSkillId = 0
    currentStreak = 0
    isHeavyAttacking = false
    suppressUntil = 0

    if heavyAttackEndTimer then
        zo_removeCallLater(heavyAttackEndTimer)
        heavyAttackEndTimer = nil
    end
end

---------------------------------------------------------------------------
-- Reset Session Stats
---------------------------------------------------------------------------
function WeaveEngine:ResetSession()
    sessionBestStreak = 0
    self:ResetWeaveState()
    ChatMessage(L.CHAT_RESET)
end

---------------------------------------------------------------------------
-- Getters for external modules
---------------------------------------------------------------------------
function WeaveEngine:GetCurrentStreak()
    return currentStreak
end

function WeaveEngine:GetSessionBestStreak()
    return sessionBestStreak
end

function WeaveEngine:IsInCombat()
    return isInCombat
end

function WeaveEngine:IsRunning()
    return isRunning
end

function WeaveEngine:IsPracticeMode()
    return isPracticeMode
end

function WeaveEngine:GetLastLATime()
    return lastLATime
end

---------------------------------------------------------------------------
-- Debug Mode Toggle
---------------------------------------------------------------------------
function WeaveEngine:SetDebugMode(enabled)
    debugMode = enabled
    settings.advanced.debugMode = enabled
    if enabled then
        ChatMessage(L.CHAT_DEBUG_ON)
    else
        ChatMessage(L.CHAT_DEBUG_OFF)
    end
end

function WeaveEngine:ToggleDebugMode()
    self:SetDebugMode(not debugMode)
end

---------------------------------------------------------------------------
-- Practice Mode Manual Toggle
---------------------------------------------------------------------------
function WeaveEngine:TogglePracticeMode()
    isPracticeMode = not isPracticeMode
    CALLBACK_MANAGER:FireCallbacks(WF.EVENT_PRACTICE_MODE, isPracticeMode)
    if isPracticeMode then
        ChatMessage(L.CHAT_PRACTICE_ON)
    else
        ChatMessage(L.CHAT_PRACTICE_OFF)
    end
end
