-- WeaveForge FightRecorder
-- Accumulates per-fight data during combat, produces fight summary records

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local FightRecorder = {}
WF.FightRecorder = FightRecorder

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local currentFight      = nil     -- active fight data table
local isRecording       = false
local settings          = nil     -- reference to account saved vars
local combatStartTime   = 0

---------------------------------------------------------------------------
-- Ability name/icon cache (avoid repeated lookups)
---------------------------------------------------------------------------
local abilityNameCache = {}
local abilityIconCache = {}

local function GetCachedAbilityName(abilityId)
    local name = abilityNameCache[abilityId]
    if not name then
        name = GetAbilityName(abilityId) or "Unknown"
        abilityNameCache[abilityId] = name
    end
    return name
end

local function GetCachedAbilityIcon(abilityId)
    local icon = abilityIconCache[abilityId]
    if not icon then
        icon = GetAbilityIcon(abilityId) or ""
        abilityIconCache[abilityId] = icon
    end
    return icon
end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function FightRecorder:Initialize(accountSV)
    settings = accountSV
    self:RegisterCallbacks()
end

---------------------------------------------------------------------------
-- Register for WeaveEngine callbacks
---------------------------------------------------------------------------
function FightRecorder:RegisterCallbacks()
    local cm = CALLBACK_MANAGER

    cm:RegisterCallback(WF.EVENT_COMBAT_START, function()
        self:StartRecording()
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_END, function(sessionBestStreak)
        self:StopRecording(sessionBestStreak)
    end)

    cm:RegisterCallback(WF.EVENT_WEAVE_SUCCESS, function(streak, gapMs, abilityId, slotIndex)
        self:RecordWeave(abilityId, true, gapMs, streak)
    end)

    cm:RegisterCallback(WF.EVENT_WEAVE_MISS, function(abilityId, slotIndex, gapMs)
        self:RecordWeave(abilityId, false, gapMs, 0)
    end)

    cm:RegisterCallback(WF.EVENT_LIGHT_ATTACK, function(timestamp, abilityId, weaponType)
        self:RecordLightAttack(timestamp)
    end)

    cm:RegisterCallback(WF.EVENT_PRACTICE_MODE, function(enabled)
        if currentFight then
            currentFight.isDummy = enabled
        end
    end)
end

---------------------------------------------------------------------------
-- Start a new fight recording
---------------------------------------------------------------------------
function FightRecorder:StartRecording()
    combatStartTime = GetGameTimeMilliseconds()

    currentFight = {
        timestamp       = GetTimeStamp(),
        startTimeMs     = combatStartTime,
        endTimeMs       = 0,
        duration        = 0,
        zone            = GetUnitZone("player") or "Unknown",
        target          = "",
        overallAccuracy = 0,
        laPerSecond     = 0,
        longestStreak   = 0,
        totalSkillCasts = 0,
        totalLAs        = 0,
        totalWeaves     = 0,
        totalMisses     = 0,
        isDummy         = WF.WeaveEngine:IsPracticeMode(),
        skillBreakdown  = {},
        weaveGaps       = {},    -- all gap timings for histogram
        currentStreak   = 0,
    }

    isRecording = true

    -- Try to detect target name from first damage event
    self:DetectTarget()
end

---------------------------------------------------------------------------
-- Detect current target (best effort)
---------------------------------------------------------------------------
function FightRecorder:DetectTarget()
    -- Target detection happens through combat events
    -- We'll pick up the most common target name from damage
    -- For now, use reticle target if available
    if DoesUnitExist("reticleover") then
        currentFight.target = GetUnitName("reticleover") or ""
    end
end

---------------------------------------------------------------------------
-- Record a light attack
---------------------------------------------------------------------------
function FightRecorder:RecordLightAttack(timestamp)
    if not isRecording or not currentFight then return end
    currentFight.totalLAs = currentFight.totalLAs + 1
end

---------------------------------------------------------------------------
-- Record a weave attempt (success or miss)
---------------------------------------------------------------------------
function FightRecorder:RecordWeave(abilityId, success, gapMs, streak)
    if not isRecording or not currentFight then return end

    currentFight.totalSkillCasts = currentFight.totalSkillCasts + 1

    -- Update per-skill breakdown
    local skillData = currentFight.skillBreakdown[abilityId]
    if not skillData then
        skillData = {
            name     = GetCachedAbilityName(abilityId),
            icon     = GetCachedAbilityIcon(abilityId),
            casts    = 0,
            weaved   = 0,
            missed   = 0,
            totalGap = 0,   -- running total for average calculation
            avgGapMs = 0,
        }
        currentFight.skillBreakdown[abilityId] = skillData
    end

    skillData.casts = skillData.casts + 1

    if success then
        currentFight.totalWeaves = currentFight.totalWeaves + 1
        skillData.weaved = skillData.weaved + 1
        skillData.totalGap = skillData.totalGap + gapMs
        skillData.avgGapMs = skillData.totalGap / skillData.weaved

        -- Record gap for histogram
        currentFight.weaveGaps[#currentFight.weaveGaps + 1] = gapMs
    else
        currentFight.totalMisses = currentFight.totalMisses + 1
        skillData.missed = skillData.missed + 1
    end

    -- Track longest streak
    if streak > currentFight.longestStreak then
        currentFight.longestStreak = streak
    end
    currentFight.currentStreak = streak
end

---------------------------------------------------------------------------
-- Stop recording and finalize fight data
---------------------------------------------------------------------------
function FightRecorder:StopRecording(sessionBestStreak)
    if not isRecording or not currentFight then return end
    isRecording = false

    local now = GetGameTimeMilliseconds()
    currentFight.endTimeMs = now
    currentFight.duration = (now - currentFight.startTimeMs) / 1000

    -- Check minimum duration
    if currentFight.duration < settings.fightSummary.minDuration then
        currentFight = nil
        return
    end

    -- Calculate summary stats
    if currentFight.totalSkillCasts > 0 then
        currentFight.overallAccuracy = currentFight.totalWeaves / currentFight.totalSkillCasts
    else
        currentFight.overallAccuracy = 0
    end

    if currentFight.duration > 0 then
        currentFight.laPerSecond = currentFight.totalLAs / currentFight.duration
    else
        currentFight.laPerSecond = 0
    end

    -- Track session best streak
    if sessionBestStreak and sessionBestStreak > currentFight.longestStreak then
        currentFight.longestStreak = sessionBestStreak
    end

    -- Classify zone type
    currentFight.zoneType = self:ClassifyZone()

    -- Update target name if we got a better one from reticle
    if (not currentFight.target or currentFight.target == "") and DoesUnitExist("reticleover") then
        currentFight.target = GetUnitName("reticleover") or "Unknown"
    end

    -- Clean up internal tracking fields before storage
    local fightRecord = self:CreateStorageRecord(currentFight)

    -- Store in history
    WF.HistoryManager:StoreFight(fightRecord)

    -- Fire callback for UI (fight summary panel)
    CALLBACK_MANAGER:FireCallbacks("WeaveForge_FightEnd", fightRecord)

    currentFight = nil
end

---------------------------------------------------------------------------
-- Create a clean record suitable for SavedVariables storage
---------------------------------------------------------------------------
function FightRecorder:CreateStorageRecord(fight)
    -- Build clean skill breakdown (convert ability ID keys to data)
    local skillBreakdown = {}
    for abilityId, data in pairs(fight.skillBreakdown) do
        skillBreakdown[abilityId] = {
            name     = data.name,
            icon     = data.icon,
            casts    = data.casts,
            weaved   = data.weaved,
            missed   = data.missed,
            avgGapMs = math.floor(data.avgGapMs + 0.5),
        }
    end

    return {
        timestamp       = fight.timestamp,
        duration        = math.floor(fight.duration + 0.5),
        zone            = fight.zone,
        zoneType        = fight.zoneType,
        target          = fight.target,
        overallAccuracy = fight.overallAccuracy,
        laPerSecond     = fight.laPerSecond,
        longestStreak   = fight.longestStreak,
        totalSkillCasts = fight.totalSkillCasts,
        totalLAs        = fight.totalLAs,
        isDummy         = fight.isDummy,
        skillBreakdown  = skillBreakdown,
        weaveGaps       = fight.weaveGaps,
    }
end

---------------------------------------------------------------------------
-- Classify current zone type
---------------------------------------------------------------------------
function FightRecorder:ClassifyZone()
    local zoneIndex = GetCurrentMapZoneIndex()

    if WF.TRIAL_ZONE_IDS[zoneIndex] then
        return WF.ZONE_TYPE.TRIAL
    elseif WF.PVP_ZONE_IDS[zoneIndex] then
        return WF.ZONE_TYPE.PVP
    end

    -- Check for dungeon via activity finder or map content type
    local activityType = GetCurrentZoneGroupActivityType and GetCurrentZoneGroupActivityType()
    if activityType and activityType == ACTIVITY_TYPE_DUNGEON then
        return WF.ZONE_TYPE.DUNGEON
    end

    return WF.ZONE_TYPE.SOLO
end

---------------------------------------------------------------------------
-- Get current fight data (for live practice mode display)
---------------------------------------------------------------------------
function FightRecorder:GetCurrentFight()
    return currentFight
end

function FightRecorder:IsRecording()
    return isRecording
end

---------------------------------------------------------------------------
-- Export fight data to chat
---------------------------------------------------------------------------
function FightRecorder:ExportToChat(fightRecord)
    if not fightRecord then return end

    local lines = {}
    lines[#lines + 1] = L.CHAT_EXPORT_HEADER
    lines[#lines + 1] = string.format("Target: %s | Zone: %s", fightRecord.target or "Unknown", fightRecord.zone or "Unknown")
    lines[#lines + 1] = string.format("Duration: %ds | Accuracy: %.1f%% | LA/s: %.2f | Streak: %d",
        fightRecord.duration,
        fightRecord.overallAccuracy * 100,
        fightRecord.laPerSecond,
        fightRecord.longestStreak)

    for abilityId, data in pairs(fightRecord.skillBreakdown) do
        local accuracy = 0
        if data.casts > 0 then
            accuracy = (data.weaved / data.casts) * 100
        end
        lines[#lines + 1] = string.format("  %s: %d/%d (%.0f%%) avg %dms",
            data.name, data.weaved, data.casts, accuracy, data.avgGapMs)
    end

    for _, line in ipairs(lines) do
        CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. line)
    end
end
