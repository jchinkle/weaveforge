-- WeaveForge Streak Counter
-- Displays the current consecutive perfect-weave count with milestone effects

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local StreakCounter = {}
WF.StreakCounter = StreakCounter

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings      = nil
local tlw           = nil     -- top-level window
local streakLabel   = nil     -- main streak number
local bestLabel     = nil     -- session/all-time best display
local milestoneGlow = nil     -- milestone celebration overlay
local isVisible     = false
local currentStreak = 0
local sessionBest   = 0

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function StreakCounter:Initialize(accountSV, characterSV)
    settings = accountSV
    if not settings.streakCounter.enabled then return end

    self:CreateUI()
    self:RegisterCallbacks()
end

---------------------------------------------------------------------------
-- Create UI elements
---------------------------------------------------------------------------
function StreakCounter:CreateUI()
    local scSettings = settings.streakCounter
    local fontSize = scSettings.fontSize or 18

    -- Top-level window
    tlw = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_StreakCounter")
    tlw:SetDimensions(150, 50)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, scSettings.offsetX, scSettings.offsetY)
    tlw:SetMovable(scSettings.unlocked)
    tlw:SetMouseEnabled(scSettings.unlocked)
    tlw:SetClampedToScreen(true)
    tlw:SetHidden(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)

    -- Save position on move
    tlw:SetHandler("OnMoveStop", function(control)
        local _, _, _, _, offsetX, offsetY = control:GetAnchor(0)
        settings.streakCounter.offsetX = offsetX
        settings.streakCounter.offsetY = offsetY
    end)

    -- "Weave Streak" title label (small, above the counter)
    local titleLabel = WINDOW_MANAGER:CreateControl("$(parent)Title", tlw, CT_LABEL)
    titleLabel:SetAnchor(TOP, tlw, TOP, 0, 0)
    titleLabel:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", math.max(10, fontSize - 8)))
    titleLabel:SetColor(0.6, 0.6, 0.6, 0.7)
    titleLabel:SetText(L.LABEL_WEAVE_STREAK)
    titleLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Main streak number
    streakLabel = WINDOW_MANAGER:CreateControl("$(parent)Streak", tlw, CT_LABEL)
    streakLabel:SetAnchor(CENTER, tlw, CENTER, 0, 2)
    streakLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
    streakLabel:SetColor(1, 0.84, 0, 1)  -- gold
    streakLabel:SetText("0")
    streakLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Best streak display (smaller, below main number)
    bestLabel = WINDOW_MANAGER:CreateControl("$(parent)Best", tlw, CT_LABEL)
    bestLabel:SetAnchor(TOP, streakLabel, BOTTOM, 0, 2)
    bestLabel:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", math.max(12, fontSize - 6)))
    bestLabel:SetColor(0.7, 0.7, 0.7, 0.8)
    bestLabel:SetText("")
    bestLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Milestone glow overlay
    milestoneGlow = WINDOW_MANAGER:CreateControl("$(parent)Glow", tlw, CT_BACKDROP)
    milestoneGlow:SetAnchor(CENTER, streakLabel, CENTER, 0, 0)
    milestoneGlow:SetDimensions(80, 40)
    milestoneGlow:SetCenterColor(1, 0.84, 0, 0)
    milestoneGlow:SetEdgeColor(0, 0, 0, 0)
    milestoneGlow:SetHidden(true)

    -- Create milestone glow animation
    local glowTimeline = ANIMATION_MANAGER:CreateTimeline()
    local glowAnim = glowTimeline:InsertAnimation(ANIMATION_ALPHA, milestoneGlow, 0)
    glowAnim:SetAlphaValues(0.8, 0)
    glowAnim:SetDuration(800)
    glowTimeline:SetHandler("OnStop", function()
        milestoneGlow:SetHidden(true)
    end)
    self.glowTimeline = glowTimeline

    -- Create streak reset shake animation
    local shakeTimeline = ANIMATION_MANAGER:CreateTimeline()
    local shakeAnim = shakeTimeline:InsertAnimation(ANIMATION_TRANSLATE, streakLabel, 0)
    shakeAnim:SetTranslateDeltas(5, 0)
    shakeAnim:SetDuration(50)
    local shakeBack = shakeTimeline:InsertAnimation(ANIMATION_TRANSLATE, streakLabel, 50)
    shakeBack:SetTranslateDeltas(-10, 0)
    shakeBack:SetDuration(50)
    local shakeReturn = shakeTimeline:InsertAnimation(ANIMATION_TRANSLATE, streakLabel, 100)
    shakeReturn:SetTranslateDeltas(5, 0)
    shakeReturn:SetDuration(50)
    self.shakeTimeline = shakeTimeline
end

---------------------------------------------------------------------------
-- Register for WeaveEngine callbacks
---------------------------------------------------------------------------
function StreakCounter:RegisterCallbacks()
    local cm = CALLBACK_MANAGER

    cm:RegisterCallback(WF.EVENT_WEAVE_SUCCESS, function(streak, gapMs, abilityId, slotIndex)
        self:UpdateStreak(streak)
    end)

    cm:RegisterCallback(WF.EVENT_WEAVE_MISS, function(abilityId, slotIndex, gapMs)
        self:OnMiss()
    end)

    cm:RegisterCallback(WF.EVENT_STREAK_MILESTONE, function(streak)
        self:OnMilestone(streak)
    end)

    cm:RegisterCallback(WF.EVENT_STREAK_RESET, function(previousStreak)
        -- Streak just reset, previousStreak was the count before reset
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_START, function()
        currentStreak = 0
        self:Show()
        self:Refresh()
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_END, function()
        self:FadeOut()
    end)
end

---------------------------------------------------------------------------
-- Update streak display
---------------------------------------------------------------------------
function StreakCounter:UpdateStreak(streak)
    currentStreak = streak
    if streak > sessionBest then
        sessionBest = streak
    end

    if not streakLabel then return end

    streakLabel:SetText(tostring(streak))
    streakLabel:SetColor(1, 0.84, 0, 1)  -- gold

    -- Update best label
    self:UpdateBestLabel()
end

function StreakCounter:OnMiss()
    currentStreak = 0

    if not streakLabel then return end

    -- Brief red flash on miss
    streakLabel:SetText("0")
    streakLabel:SetColor(0.8, 0.2, 0.2, 1)  -- red

    -- Shake animation
    if self.shakeTimeline then
        self.shakeTimeline:PlayFromStart()
    end

    -- Fade back to gold after a moment
    zo_callLater(function()
        if streakLabel then
            streakLabel:SetColor(1, 0.84, 0, 1)
        end
    end, 500)
end

function StreakCounter:OnMilestone(streak)
    if not milestoneGlow or not self.glowTimeline then return end

    -- Scale up the streak number briefly
    milestoneGlow:SetHidden(false)
    milestoneGlow:SetCenterColor(1, 0.84, 0, 0.8)
    self.glowTimeline:PlayFromStart()

    -- Chat notification
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. string.format(L.STREAK_MILESTONE, streak))
    end
end

---------------------------------------------------------------------------
-- Update best streak label
---------------------------------------------------------------------------
function StreakCounter:UpdateBestLabel()
    if not bestLabel then return end

    local parts = {}
    if settings.streakCounter.showSessionBest and sessionBest > 0 then
        parts[#parts + 1] = string.format(L.STREAK_BEST_SESSION, sessionBest)
    end
    if settings.streakCounter.showAllTimeBest then
        local allTime = WF.HistoryManager:GetAllTimeBestStreak()
        if allTime > 0 then
            parts[#parts + 1] = string.format(L.STREAK_BEST_ALLTIME, allTime)
        end
    end

    if #parts > 0 then
        bestLabel:SetText(table.concat(parts, " | "))
    else
        bestLabel:SetText("")
    end
end

---------------------------------------------------------------------------
-- Refresh display
---------------------------------------------------------------------------
function StreakCounter:Refresh()
    if streakLabel then
        streakLabel:SetText(tostring(currentStreak))
    end
    self:UpdateBestLabel()
end

---------------------------------------------------------------------------
-- Show / Hide
---------------------------------------------------------------------------
function StreakCounter:Show()
    if not settings.streakCounter.enabled or not tlw then return end
    tlw:SetHidden(false)
    isVisible = true
end

function StreakCounter:Hide()
    if not tlw then return end
    tlw:SetHidden(true)
    isVisible = false
end

function StreakCounter:FadeOut()
    if not tlw then return end
    local delay = (settings.fadeDelay or 2) * 1000
    zo_callLater(function()
        if not WF.WeaveEngine:IsInCombat() then
            self:Hide()
        end
    end, delay)
end

---------------------------------------------------------------------------
-- Settings update handlers
---------------------------------------------------------------------------
function StreakCounter:UpdateMovable()
    if not tlw then return end
    tlw:SetMovable(settings.streakCounter.unlocked)
    tlw:SetMouseEnabled(settings.streakCounter.unlocked)
end

function StreakCounter:UpdateFontSize()
    if not streakLabel then return end
    local fontSize = settings.streakCounter.fontSize or 18
    streakLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
    if bestLabel then
        bestLabel:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", math.max(12, fontSize - 6)))
    end
end

function StreakCounter:SetEnabled(enabled)
    settings.streakCounter.enabled = enabled
    if enabled then
        if not tlw then
            self:CreateUI()
        end
        if WF.WeaveEngine:IsInCombat() then
            self:Show()
        end
    else
        self:Hide()
    end
end

function StreakCounter:ResetSession()
    sessionBest = 0
    currentStreak = 0
    self:Refresh()
end
