-- WeaveForge Action Coach
-- Real-time "Light Attack!" / "Cast Skill!" prompt that guides the weave cycle
-- Also shows timing feedback so players understand WHY they hit or missed

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local ActionCoach = {}
WF.ActionCoach = ActionCoach

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings       = nil
local tlw            = nil     -- top-level window
local promptLabel    = nil     -- the main action text
local feedbackLabel  = nil     -- timing feedback text below prompt
local isVisible      = false
local currentPrompt  = ""      -- "la", "skill", "charging", or ""
local lastLATime     = 0       -- mirrors engine state for timing
local feedbackTimer  = nil     -- handle for clearing feedback text
local UPDATE_NS      = "WeaveForge_ActionCoachUpdate"

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function ActionCoach:Initialize(accountSV)
    settings = accountSV
    if not settings.actionCoach.enabled then return end

    self:CreateUI()
    self:RegisterCallbacks()
end

---------------------------------------------------------------------------
-- Create UI elements
---------------------------------------------------------------------------
function ActionCoach:CreateUI()
    local acSettings = settings.actionCoach
    local fontSize = acSettings.fontSize or 22

    -- Top-level window
    tlw = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_ActionCoach")
    tlw:SetDimensions(300, 55)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, acSettings.offsetX, acSettings.offsetY)
    tlw:SetMovable(acSettings.unlocked)
    tlw:SetMouseEnabled(acSettings.unlocked)
    tlw:SetClampedToScreen(true)
    tlw:SetHidden(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)

    -- Save position on move
    tlw:SetHandler("OnMoveStop", function(control)
        local _, _, _, _, offsetX, offsetY = control:GetAnchor(0)
        settings.actionCoach.offsetX = offsetX
        settings.actionCoach.offsetY = offsetY
    end)

    -- Main prompt label ("Light Attack!" / "Cast Skill!")
    promptLabel = WINDOW_MANAGER:CreateControl("$(parent)Prompt", tlw, CT_LABEL)
    promptLabel:SetAnchor(TOP, tlw, TOP, 0, 0)
    promptLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
    promptLabel:SetColor(1, 0.84, 0, 1)  -- gold default
    promptLabel:SetText("")
    promptLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- Feedback label ("Good! 342ms" / "Too slow! 1247ms")
    feedbackLabel = WINDOW_MANAGER:CreateControl("$(parent)Feedback", tlw, CT_LABEL)
    feedbackLabel:SetAnchor(TOP, promptLabel, BOTTOM, 0, 2)
    feedbackLabel:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", math.max(12, fontSize - 8)))
    feedbackLabel:SetColor(0.7, 0.7, 0.7, 0.9)
    feedbackLabel:SetText("")
    feedbackLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
end

---------------------------------------------------------------------------
-- Register for WeaveEngine callbacks
---------------------------------------------------------------------------
function ActionCoach:RegisterCallbacks()
    local cm = CALLBACK_MANAGER

    -- Light attack detected -> tell player to cast a skill
    cm:RegisterCallback(WF.EVENT_LIGHT_ATTACK, function(timestamp, abilityId, weaponType)
        lastLATime = timestamp
        self:SetPrompt("skill")
        self:ClearFeedback()
    end)

    -- Successful weave -> show timing feedback, then prompt next LA
    cm:RegisterCallback(WF.EVENT_WEAVE_SUCCESS, function(streak, gapMs, abilityId, slotIndex)
        lastLATime = 0
        self:SetPrompt("la")
        self:ShowSuccessFeedback(gapMs)
    end)

    -- Missed weave -> show what went wrong, then prompt LA
    cm:RegisterCallback(WF.EVENT_WEAVE_MISS, function(abilityId, slotIndex, gapMs)
        lastLATime = 0
        self:SetPrompt("la")
        self:ShowMissFeedback(gapMs)
    end)

    -- Heavy attack started -> show charging state
    cm:RegisterCallback(WF.EVENT_HEAVY_ATTACK_START, function(abilityId, weaponType)
        lastLATime = 0
        self:SetPrompt("charging")
        self:ClearFeedback()
    end)

    -- Heavy attack ended -> back to light attack
    cm:RegisterCallback(WF.EVENT_HEAVY_ATTACK_END, function()
        self:SetPrompt("la")
    end)

    -- Bar swap -> need fresh light attack on new bar
    cm:RegisterCallback(WF.EVENT_BAR_SWAP, function(activeWeaponPair)
        lastLATime = 0
        self:SetPrompt("la")
        self:ClearFeedback()
    end)

    -- Combat start -> show and prompt light attack
    cm:RegisterCallback(WF.EVENT_COMBAT_START, function()
        self:Show()
        self:SetPrompt("la")
    end)

    -- Combat end -> fade out
    cm:RegisterCallback(WF.EVENT_COMBAT_END, function()
        self:FadeOut()
    end)
end

---------------------------------------------------------------------------
-- Set the current prompt
---------------------------------------------------------------------------
function ActionCoach:SetPrompt(promptType)
    currentPrompt = promptType

    if not promptLabel then return end

    if promptType == "la" then
        promptLabel:SetText(L.COACH_LIGHT_ATTACK)
        promptLabel:SetColor(1, 0.84, 0, 1)       -- gold
        promptLabel:SetAlpha(1.0)
    elseif promptType == "skill" then
        promptLabel:SetText(L.COACH_CAST_SKILL)
        promptLabel:SetColor(0.2, 0.8, 0.2, 1)    -- green (will be updated by OnUpdate)
    elseif promptType == "charging" then
        promptLabel:SetText(L.COACH_CHARGING)
        promptLabel:SetColor(0.5, 0.5, 0.5, 0.6)  -- dim grey
    end
end

---------------------------------------------------------------------------
-- Timing feedback display
---------------------------------------------------------------------------
function ActionCoach:ShowSuccessFeedback(gapMs)
    if not feedbackLabel then return end

    local text
    if gapMs <= 400 then
        text = string.format(L.COACH_FEEDBACK_PERFECT, gapMs)
        feedbackLabel:SetColor(0.3, 1.0, 0.3, 1)    -- bright green
    else
        text = string.format(L.COACH_FEEDBACK_GOOD, gapMs)
        feedbackLabel:SetColor(0.4, 0.9, 0.4, 0.9)  -- green
    end
    feedbackLabel:SetText(text)

    -- Clear after 1.5 seconds
    self:ScheduleFeedbackClear(1500)
end

function ActionCoach:ShowMissFeedback(gapMs)
    if not feedbackLabel then return end

    local detectionWindow = settings.missedAlert.detectionWindow or WF.GCD_MS
    local text

    if gapMs > 50000 then
        -- Very large gap means no LA was detected at all (lastLATime was 0 or very old)
        text = L.COACH_FEEDBACK_NO_LA
    else
        text = string.format(L.COACH_FEEDBACK_SLOW, gapMs, detectionWindow)
    end

    feedbackLabel:SetColor(0.9, 0.4, 0.4, 1)  -- red
    feedbackLabel:SetText(text)

    -- Keep miss feedback visible longer so they can read it
    self:ScheduleFeedbackClear(2500)
end

function ActionCoach:ClearFeedback()
    if feedbackLabel then
        feedbackLabel:SetText("")
    end
    if feedbackTimer then
        zo_removeCallLater(feedbackTimer)
        feedbackTimer = nil
    end
end

function ActionCoach:ScheduleFeedbackClear(delayMs)
    if feedbackTimer then
        zo_removeCallLater(feedbackTimer)
    end
    feedbackTimer = zo_callLater(function()
        feedbackTimer = nil
        if feedbackLabel then
            feedbackLabel:SetText("")
        end
    end, delayMs)
end

---------------------------------------------------------------------------
-- Frame update: dynamically color "Cast Skill!" based on timing urgency
---------------------------------------------------------------------------
function ActionCoach:OnUpdate()
    if not isVisible or not promptLabel then return end
    if currentPrompt ~= "skill" then return end

    -- Only update color when we're in "cast skill" state
    if lastLATime <= 0 then return end

    local now = GetGameTimeMilliseconds()
    local elapsed = now - lastLATime
    local detectionWindow = settings.missedAlert.detectionWindow or WF.GCD_MS
    local ratio = elapsed / detectionWindow

    if ratio <= 0.7 then
        -- Green: good window, plenty of time
        promptLabel:SetText(L.COACH_CAST_SKILL)
        promptLabel:SetColor(0.2, 0.8, 0.2, 1)
        promptLabel:SetAlpha(1.0)
    elseif ratio <= 1.0 then
        -- Yellow: getting urgent
        promptLabel:SetText(L.COACH_CAST_SKILL)
        promptLabel:SetColor(0.9, 0.9, 0.1, 1)
        promptLabel:SetAlpha(1.0)
    else
        -- Red pulsing: overdue, cast NOW
        promptLabel:SetText(L.COACH_CAST_SKILL_NOW)
        promptLabel:SetColor(0.9, 0.2, 0.2, 1)
        -- Pulse effect
        local pulse = 0.6 + 0.4 * math.sin(elapsed * 0.008)
        promptLabel:SetAlpha(pulse)
    end
end

---------------------------------------------------------------------------
-- Show / Hide
---------------------------------------------------------------------------
function ActionCoach:Show()
    if not settings.actionCoach.enabled or not tlw then return end
    tlw:SetHidden(false)
    isVisible = true
    lastLATime = 0
    currentPrompt = ""
    self:ClearFeedback()

    -- Start frame update for timing-based color changes
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS, 33, function() self:OnUpdate() end)
end

function ActionCoach:Hide()
    if not tlw then return end
    tlw:SetHidden(true)
    isVisible = false
    currentPrompt = ""
    self:ClearFeedback()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS)
end

function ActionCoach:FadeOut()
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
function ActionCoach:UpdateMovable()
    if not tlw then return end
    tlw:SetMovable(settings.actionCoach.unlocked)
    tlw:SetMouseEnabled(settings.actionCoach.unlocked)
end

function ActionCoach:UpdateFontSize()
    if not promptLabel then return end
    local fontSize = settings.actionCoach.fontSize or 22
    promptLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
    if feedbackLabel then
        feedbackLabel:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", math.max(12, fontSize - 8)))
    end
end

function ActionCoach:SetEnabled(enabled)
    settings.actionCoach.enabled = enabled
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
