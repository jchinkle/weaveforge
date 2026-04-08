-- WeaveForge Missed Weave Alert
-- Visual and optional audio alert when a weave is missed

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local MissedWeaveAlert = {}
WF.MissedWeaveAlert = MissedWeaveAlert

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings      = nil
local iconFlash     = nil     -- icon flash control (X icon near reticle)
local edgeFlashL    = nil     -- left screen edge flash
local edgeFlashR    = nil     -- right screen edge flash
local reticleFlash  = nil     -- reticle area color flash

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function MissedWeaveAlert:Initialize(accountSV)
    settings = accountSV
    if not settings.missedAlert.enabled then return end

    self:CreateUI()
    self:RegisterCallbacks()
end

---------------------------------------------------------------------------
-- Create UI elements
---------------------------------------------------------------------------
function MissedWeaveAlert:CreateUI()
    -- Icon Flash (small X near crosshair)
    iconFlash = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_MissIcon")
    iconFlash:SetDimensions(32, 32)
    iconFlash:SetAnchor(CENTER, GuiRoot, CENTER, 0, 40)
    iconFlash:SetHidden(true)
    iconFlash:SetDrawLayer(DL_OVERLAY)
    iconFlash:SetDrawTier(DT_HIGH)
    iconFlash:SetMouseEnabled(false)

    local iconTexture = WINDOW_MANAGER:CreateControl("$(parent)Tex", iconFlash, CT_TEXTURE)
    iconTexture:SetAnchorFill(iconFlash)
    iconTexture:SetTexture("EsoUI/Art/Miscellaneous/status_offline.dds")
    iconTexture:SetColor(0.9, 0.2, 0.2, 1)

    -- Icon fade animation
    local iconTimeline = ANIMATION_MANAGER:CreateTimeline()
    local iconAnim = iconTimeline:InsertAnimation(ANIMATION_ALPHA, iconFlash, 0)
    iconAnim:SetAlphaValues(1.0, 0)
    iconAnim:SetDuration(400)
    iconTimeline:SetHandler("OnStop", function()
        iconFlash:SetHidden(true)
    end)
    self.iconTimeline = iconTimeline

    -- Screen Edge Flash (left)
    edgeFlashL = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_EdgeL")
    edgeFlashL:SetDimensions(30, GuiRoot:GetHeight())
    edgeFlashL:SetAnchor(LEFT, GuiRoot, LEFT, 0, 0)
    edgeFlashL:SetHidden(true)
    edgeFlashL:SetDrawLayer(DL_OVERLAY)
    edgeFlashL:SetMouseEnabled(false)

    local edgeBgL = WINDOW_MANAGER:CreateControl("$(parent)BG", edgeFlashL, CT_BACKDROP)
    edgeBgL:SetAnchorFill(edgeFlashL)
    edgeBgL:SetCenterColor(0.8, 0.15, 0.15, 0.5)
    edgeBgL:SetEdgeColor(0, 0, 0, 0)

    -- Screen Edge Flash (right)
    edgeFlashR = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_EdgeR")
    edgeFlashR:SetDimensions(30, GuiRoot:GetHeight())
    edgeFlashR:SetAnchor(RIGHT, GuiRoot, RIGHT, 0, 0)
    edgeFlashR:SetHidden(true)
    edgeFlashR:SetDrawLayer(DL_OVERLAY)
    edgeFlashR:SetMouseEnabled(false)

    local edgeBgR = WINDOW_MANAGER:CreateControl("$(parent)BG", edgeFlashR, CT_BACKDROP)
    edgeBgR:SetAnchorFill(edgeFlashR)
    edgeBgR:SetCenterColor(0.8, 0.15, 0.15, 0.5)
    edgeBgR:SetEdgeColor(0, 0, 0, 0)

    -- Edge fade animations
    local edgeTimeline = ANIMATION_MANAGER:CreateTimeline()
    local edgeAnimL = edgeTimeline:InsertAnimation(ANIMATION_ALPHA, edgeFlashL, 0)
    edgeAnimL:SetAlphaValues(0.7, 0)
    edgeAnimL:SetDuration(350)
    local edgeAnimR = edgeTimeline:InsertAnimation(ANIMATION_ALPHA, edgeFlashR, 0)
    edgeAnimR:SetAlphaValues(0.7, 0)
    edgeAnimR:SetDuration(350)
    edgeTimeline:SetHandler("OnStop", function()
        edgeFlashL:SetHidden(true)
        edgeFlashR:SetHidden(true)
    end)
    self.edgeTimeline = edgeTimeline

    -- Reticle color change (circle around crosshair area)
    reticleFlash = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_Reticle")
    reticleFlash:SetDimensions(60, 60)
    reticleFlash:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reticleFlash:SetHidden(true)
    reticleFlash:SetDrawLayer(DL_OVERLAY)
    reticleFlash:SetMouseEnabled(false)

    local reticleBg = WINDOW_MANAGER:CreateControl("$(parent)BG", reticleFlash, CT_BACKDROP)
    reticleBg:SetAnchorFill(reticleFlash)
    reticleBg:SetCenterColor(0.8, 0.15, 0.15, 0.3)
    reticleBg:SetEdgeColor(0.8, 0.15, 0.15, 0.7)
    reticleBg:SetEdgeTexture("", 1, 1, 1, 0)

    local reticleTimeline = ANIMATION_MANAGER:CreateTimeline()
    local reticleAnim = reticleTimeline:InsertAnimation(ANIMATION_ALPHA, reticleFlash, 0)
    reticleAnim:SetAlphaValues(1.0, 0)
    reticleAnim:SetDuration(400)
    reticleTimeline:SetHandler("OnStop", function()
        reticleFlash:SetHidden(true)
    end)
    self.reticleTimeline = reticleTimeline
end

---------------------------------------------------------------------------
-- Register for WeaveEngine callbacks
---------------------------------------------------------------------------
local lastHintTime = 0

function MissedWeaveAlert:RegisterCallbacks()
    CALLBACK_MANAGER:RegisterCallback(WF.EVENT_WEAVE_MISS, function(abilityId, slotIndex, gapMs)
        self:ShowAlert()
        self:ShowOnboardingHint()
    end)
end

---------------------------------------------------------------------------
-- Onboarding hint (fires max 3 times ever, with 10s cooldown between)
---------------------------------------------------------------------------
function MissedWeaveAlert:ShowOnboardingHint()
    if not settings or not settings.onboarding then return end
    local ob = settings.onboarding
    if ob.hintMissedWeaveCount >= ob.hintMaxPerType then return end

    local now = GetGameTimeMilliseconds()
    if now - lastHintTime < 10000 then return end
    lastHintTime = now

    ob.hintMissedWeaveCount = ob.hintMissedWeaveCount + 1
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.HINT_MISSED_WEAVE)
    end
end

---------------------------------------------------------------------------
-- Show alert based on configured style
---------------------------------------------------------------------------
function MissedWeaveAlert:ShowAlert()
    if not settings.missedAlert.enabled then return end

    local style = settings.missedAlert.style

    if style == WF.ALERT_STYLE.ICON_FLASH then
        self:ShowIconFlash()
    elseif style == WF.ALERT_STYLE.EDGE_FLASH then
        self:ShowEdgeFlash()
    elseif style == WF.ALERT_STYLE.RETICLE_COLOR then
        self:ShowReticleFlash()
    end

    -- Play sound if configured
    self:PlayAlertSound()
end

---------------------------------------------------------------------------
-- Icon Flash alert
---------------------------------------------------------------------------
function MissedWeaveAlert:ShowIconFlash()
    if not iconFlash or not self.iconTimeline then return end
    iconFlash:SetHidden(false)
    iconFlash:SetAlpha(1.0)
    self.iconTimeline:PlayFromStart()
end

---------------------------------------------------------------------------
-- Screen Edge Flash alert
---------------------------------------------------------------------------
function MissedWeaveAlert:ShowEdgeFlash()
    if not edgeFlashL or not self.edgeTimeline then return end
    edgeFlashL:SetHidden(false)
    edgeFlashR:SetHidden(false)
    edgeFlashL:SetAlpha(0.7)
    edgeFlashR:SetAlpha(0.7)
    self.edgeTimeline:PlayFromStart()
end

---------------------------------------------------------------------------
-- Reticle Color Change alert
---------------------------------------------------------------------------
function MissedWeaveAlert:ShowReticleFlash()
    if not reticleFlash or not self.reticleTimeline then return end
    reticleFlash:SetHidden(false)
    reticleFlash:SetAlpha(1.0)
    self.reticleTimeline:PlayFromStart()
end

---------------------------------------------------------------------------
-- Play alert sound
---------------------------------------------------------------------------
function MissedWeaveAlert:PlayAlertSound()
    local soundId = settings.missedAlert.sound
    if soundId == WF.ALERT_SOUND.NONE then return end

    local sound = WF.ALERT_SOUND_MAP[soundId]
    if sound then
        PlaySound(sound)
    end
end

---------------------------------------------------------------------------
-- Settings update handlers
---------------------------------------------------------------------------
function MissedWeaveAlert:SetEnabled(enabled)
    settings.missedAlert.enabled = enabled
end
