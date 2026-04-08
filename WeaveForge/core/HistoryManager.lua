-- WeaveForge HistoryManager
-- SavedVariables initialization, fight history storage, and aggregation

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local HistoryManager = {}
WF.HistoryManager = HistoryManager

---------------------------------------------------------------------------
-- SavedVariables references
---------------------------------------------------------------------------
HistoryManager.accountSV   = nil    -- account-wide settings
HistoryManager.characterSV = nil    -- per-character data

---------------------------------------------------------------------------
-- Initialize SavedVariables
---------------------------------------------------------------------------
function HistoryManager:Initialize()
    -- Account-wide saved variables (settings)
    self.accountSV = ZO_SavedVars:NewAccountWide(
        WF.SAVED_VARS_NAME,
        WF.SAVED_VARS_VER,
        nil,
        WF.ACCOUNT_DEFAULTS,
        GetWorldName()
    )

    -- Per-character saved variables (fight history, streaks)
    self.characterSV = ZO_SavedVars:NewCharacterIdSettings(
        WF.SAVED_VARS_NAME,
        WF.SAVED_VARS_VER,
        nil,
        WF.CHARACTER_DEFAULTS
    )

    -- Ensure tables exist (migration safety)
    if not self.characterSV.fightHistory then
        self.characterSV.fightHistory = {}
    end
    if not self.characterSV.pinnedFights then
        self.characterSV.pinnedFights = {}
    end
end

---------------------------------------------------------------------------
-- Store a completed fight record
---------------------------------------------------------------------------
function HistoryManager:StoreFight(fightRecord)
    if not fightRecord or not self.characterSV then return end

    local history = self.characterSV.fightHistory
    local maxFights = self.accountSV.fightSummary.maxStoredFights

    -- Insert at the beginning (newest first)
    table.insert(history, 1, fightRecord)

    -- Trim to max size
    while #history > maxFights do
        table.remove(history)
    end

    -- Update all-time best streak
    if fightRecord.longestStreak > self.characterSV.allTimeBestStreak then
        self.characterSV.allTimeBestStreak = fightRecord.longestStreak
    end
end

---------------------------------------------------------------------------
-- Pin a fight (save from rolling deletion)
---------------------------------------------------------------------------
function HistoryManager:PinFight(fightIndex)
    local history = self.characterSV.fightHistory
    if not history[fightIndex] then return false end

    local fight = history[fightIndex]
    table.insert(self.characterSV.pinnedFights, 1, fight)
    return true
end

---------------------------------------------------------------------------
-- Get fight history (with optional filter)
---------------------------------------------------------------------------
function HistoryManager:GetFightHistory(filter)
    local history = self.characterSV.fightHistory
    if not filter or filter == "all" then
        return history
    end

    local filtered = {}
    for i = 1, #history do
        local fight = history[i]
        local match = false

        if filter == "dummy" then
            match = fight.isDummy
        elseif filter == "trial" then
            match = fight.zoneType == WF.ZONE_TYPE.TRIAL
        elseif filter == "dungeon" then
            match = fight.zoneType == WF.ZONE_TYPE.DUNGEON
        elseif filter == "solo" then
            match = fight.zoneType == WF.ZONE_TYPE.SOLO
        elseif filter == "pvp" then
            match = fight.zoneType == WF.ZONE_TYPE.PVP
        end

        if match then
            filtered[#filtered + 1] = fight
        end
    end

    return filtered
end

---------------------------------------------------------------------------
-- Get pinned fights
---------------------------------------------------------------------------
function HistoryManager:GetPinnedFights()
    return self.characterSV.pinnedFights
end

---------------------------------------------------------------------------
-- Get the most recent fight
---------------------------------------------------------------------------
function HistoryManager:GetLastFight()
    local history = self.characterSV.fightHistory
    if #history > 0 then
        return history[1]
    end
    return nil
end

---------------------------------------------------------------------------
-- Get all-time best streak
---------------------------------------------------------------------------
function HistoryManager:GetAllTimeBestStreak()
    return self.characterSV.allTimeBestStreak
end

---------------------------------------------------------------------------
-- Aggregate stats across fight history
---------------------------------------------------------------------------
function HistoryManager:GetAggregateStats(filter)
    local fights = self:GetFightHistory(filter)
    local stats = {
        totalFights     = #fights,
        totalDuration   = 0,
        avgAccuracy     = 0,
        bestStreak      = 0,
        avgLaPerSecond  = 0,
        totalWeaves     = 0,
        totalMisses     = 0,
        totalSkillCasts = 0,
        totalLAs        = 0,
    }

    if #fights == 0 then return stats end

    local sumAccuracy = 0
    local sumLaPerSec = 0

    for i = 1, #fights do
        local f = fights[i]
        stats.totalDuration   = stats.totalDuration + (f.duration or 0)
        sumAccuracy           = sumAccuracy + (f.overallAccuracy or 0)
        sumLaPerSec           = sumLaPerSec + (f.laPerSecond or 0)
        stats.totalSkillCasts = stats.totalSkillCasts + (f.totalSkillCasts or 0)
        stats.totalLAs        = stats.totalLAs + (f.totalLAs or 0)

        if (f.longestStreak or 0) > stats.bestStreak then
            stats.bestStreak = f.longestStreak
        end

        -- Compute weaves/misses from skill casts and accuracy
        local weaves = math.floor((f.overallAccuracy or 0) * (f.totalSkillCasts or 0) + 0.5)
        stats.totalWeaves = stats.totalWeaves + weaves
        stats.totalMisses = stats.totalMisses + ((f.totalSkillCasts or 0) - weaves)
    end

    stats.avgAccuracy    = sumAccuracy / #fights
    stats.avgLaPerSecond = sumLaPerSec / #fights

    return stats
end

---------------------------------------------------------------------------
-- Get accuracy values for recent N fights (for sparkline display)
---------------------------------------------------------------------------
function HistoryManager:GetAccuracyTrend(count, filter)
    local fights = self:GetFightHistory(filter)
    count = math.min(count or 20, #fights)

    local trend = {}
    for i = 1, count do
        trend[i] = fights[i].overallAccuracy or 0
    end

    return trend
end

---------------------------------------------------------------------------
-- Reset all character data
---------------------------------------------------------------------------
function HistoryManager:ResetCharacterData()
    self.characterSV.allTimeBestStreak = 0
    self.characterSV.fightHistory = {}
    self.characterSV.pinnedFights = {}
end

---------------------------------------------------------------------------
-- Delete a specific fight from history
---------------------------------------------------------------------------
function HistoryManager:DeleteFight(index)
    local history = self.characterSV.fightHistory
    if history[index] then
        table.remove(history, index)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Delete a pinned fight
---------------------------------------------------------------------------
function HistoryManager:DeletePinnedFight(index)
    local pinned = self.characterSV.pinnedFights
    if pinned[index] then
        table.remove(pinned, index)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Format duration for display
---------------------------------------------------------------------------
function HistoryManager:FormatDuration(seconds)
    seconds = math.floor(seconds)
    if seconds >= 60 then
        local mins = math.floor(seconds / 60)
        local secs = seconds - (mins * 60)
        return string.format(L.TIME_FORMAT_SHORT, mins, secs)
    else
        return string.format(L.TIME_FORMAT_SECONDS, seconds)
    end
end
