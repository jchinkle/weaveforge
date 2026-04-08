-- WeaveForge Action Coach
-- Real-time "Light Attack!" / "Cast Skill!" prompt that guides the weave cycle

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
local settings      = nil
local tlw           = nil     -- top-level window
local promptLabel   = nil     -- the main action text
local isVisible     = false
local currentPrompt = ""      -- "la", "skill", "charging", or ""
local lastLATime    = 0       -- mirrors engine state for timing
local UPDATE_NS     = "WeaveForge_ActionCoachUpdate"

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
    tlw:SetDimensions(250, 40)
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

    -- Main prompt label
    promptLabel = WINDOW_MANAGER:CreateControl("$(parent)Prompt", tlw, CT_LABEL)
    promptLabel:SetAnchor(CENTER, tlw, CENTER, 0, 0)
    promptLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))
    promptLabel:SetColor(1, 0.84, 0, 1)  -- gold default
    promptLabel:SetText("")
    promptLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
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
    end)

    -- Successful weave -> tell player to light attack again
    cm:RegisterCallback(WF.EVENT_WEAVE_SUCCESS, function(streak, gapMs, abilityId, slotIndex)
        lastLATime = 0
        self:SetPrompt("la")
    end)

    -- Missed weave -> restart cycle with light attack
    cm:RegisterCallback(WF.EVENT_WEAVE_MISS, function(abilityId, slotIndex, gapMs)
        lastLATime = 0
        self:SetPrompt("la")
    end)

    -- Heavy attack started -> show charging state
    cm:RegisterCallback(WF.EVENT_HEAVY_ATTACK_START, function(abilityId, weaponType)
        lastLATime = 0
        self:SetPrompt("charging")
    end)

    -- Heavy attack ended -> back to light attack
    cm:RegisterCallback(WF.EVENT_HEAVY_ATTACK_END, function()
        self:SetPrompt("la")
    end)

    -- Bar swap -> need fresh light attack on new bar
    cm:RegisterCallback(WF.EVENT_BAR_SWAP, function(activeWeaponPair)
        lastLATime = 0
        self:SetPrompt("la")
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

    -- Start frame update for timing-based color changes
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS, 33, function() self:OnUpdate() end)
end

function ActionCoach:Hide()
    if not tlw then return end
    tlw:SetHidden(true)
    isVisible = false
    currentPrompt = ""
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
