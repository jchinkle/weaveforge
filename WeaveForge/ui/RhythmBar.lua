-- WeaveForge Rhythm Bar
-- A horizontal progress bar that pulses at GCD cadence to help time weaves

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local RhythmBar = {}
WF.RhythmBar = RhythmBar

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings      = nil
local tlw           = nil     -- top-level window
local bg            = nil     -- background backdrop
local bar           = nil     -- status bar (fill)
local flashOverlay  = nil     -- flash overlay for success/miss
local isVisible     = false
local isAnimating   = false
local lastLATime    = 0       -- mirrors engine state for animation
local currentColors = nil     -- active color scheme
local fadeAnimation = nil
local UPDATE_NS     = "WeaveForge_RhythmBarUpdate"

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function RhythmBar:Initialize(accountSV)
    settings = accountSV
    if not settings.rhythmBar.enabled then return end

    self:CreateUI()
    self:RegisterCallbacks()
    self:ApplyColorScheme()
end

---------------------------------------------------------------------------
-- Create UI elements (pure Lua, no XML)
---------------------------------------------------------------------------
function RhythmBar:CreateUI()
    local rbSettings = settings.rhythmBar

    -- Top-level window
    tlw = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_RhythmBar")
    tlw:SetDimensions(rbSettings.width, rbSettings.height)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, rbSettings.offsetX, rbSettings.offsetY)
    tlw:SetMovable(rbSettings.unlocked)
    tlw:SetMouseEnabled(rbSettings.unlocked)
    tlw:SetClampedToScreen(true)
    tlw:SetHidden(true)
    tlw:SetAlpha(rbSettings.opacity)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)

    -- Save position on move
    tlw:SetHandler("OnMoveStop", function(control)
        local _, _, _, _, offsetX, offsetY = control:GetAnchor(0)
        settings.rhythmBar.offsetX = offsetX
        settings.rhythmBar.offsetY = offsetY
    end)

    -- Background
    bg = WINDOW_MANAGER:CreateControl("$(parent)BG", tlw, CT_BACKDROP)
    bg:SetAnchorFill(tlw)
    bg:SetCenterColor(0, 0, 0, 0.6)
    bg:SetEdgeColor(0.2, 0.2, 0.2, 0.8)
    bg:SetEdgeTexture("", 1, 1, 1, 0)

    -- Fill bar
    bar = WINDOW_MANAGER:CreateControl("$(parent)Bar", tlw, CT_STATUSBAR)
    bar:SetAnchor(TOPLEFT, tlw, TOPLEFT, 1, 1)
    bar:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -1, -1)
    bar:SetMinMax(0, 1000)
    bar:SetValue(0)

    -- Flash overlay for success/miss feedback
    flashOverlay = WINDOW_MANAGER:CreateControl("$(parent)Flash", tlw, CT_BACKDROP)
    flashOverlay:SetAnchorFill(tlw)
    flashOverlay:SetCenterColor(1, 1, 1, 0)
    flashOverlay:SetEdgeColor(0, 0, 0, 0)
    flashOverlay:SetHidden(true)

    -- Create fade animation for flash
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    fadeAnimation = timeline:InsertAnimation(ANIMATION_ALPHA, flashOverlay, 0)
    fadeAnimation:SetAlphaValues(0.8, 0)
    fadeAnimation:SetDuration(300)
    timeline:SetHandler("OnStop", function()
        flashOverlay:SetHidden(true)
    end)
    self.flashTimeline = timeline
end

---------------------------------------------------------------------------
-- Apply color scheme
---------------------------------------------------------------------------
function RhythmBar:ApplyColorScheme()
    local schemeName = settings.rhythmBar.colorScheme or "default"
    currentColors = WF.COLOR_SCHEMES[schemeName] or WF.COLOR_SCHEMES.default
    if bar then
        bar:SetColor(unpack(currentColors.idle))
    end
end

---------------------------------------------------------------------------
-- Register for WeaveEngine callbacks
---------------------------------------------------------------------------
function RhythmBar:RegisterCallbacks()
    local cm = CALLBACK_MANAGER

    cm:RegisterCallback(WF.EVENT_LIGHT_ATTACK, function(timestamp, abilityId, weaponType)
        lastLATime = timestamp
    end)

    cm:RegisterCallback(WF.EVENT_WEAVE_SUCCESS, function(streak, gapMs, abilityId, slotIndex)
        self:FlashColor(currentColors.good)
        lastLATime = 0  -- reset bar after successful weave
    end)

    cm:RegisterCallback(WF.EVENT_WEAVE_MISS, function(abilityId, slotIndex, gapMs)
        self:FlashColor(currentColors.bad)
        lastLATime = 0
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_START, function()
        self:Show()
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_END, function()
        self:FadeOut()
    end)

    cm:RegisterCallback(WF.EVENT_BAR_SWAP, function()
        lastLATime = 0
        if bar then
            bar:SetValue(0)
            bar:SetColor(unpack(currentColors.idle))
        end
    end)
end

---------------------------------------------------------------------------
-- Frame update handler (registered only during combat)
---------------------------------------------------------------------------
function RhythmBar:OnUpdate()
    if not bar or not isVisible then return end

    local now = GetGameTimeMilliseconds()

    if lastLATime > 0 then
        local elapsed = now - lastLATime
        local gcdMs = settings.missedAlert.detectionWindow or WF.GCD_MS

        -- Fill the bar based on elapsed time since LA
        local fillValue = math.min(elapsed, gcdMs)
        bar:SetValue(fillValue)

        -- Color transitions based on timing
        local ratio = elapsed / gcdMs
        if ratio <= 0.7 then
            -- Good zone: green (filling up)
            bar:SetColor(unpack(currentColors.good))
        elseif ratio <= 1.0 then
            -- Warning zone: yellow (getting close to expiry)
            bar:SetColor(unpack(currentColors.warning))
        else
            -- Overdue: red (LA happened too long ago)
            bar:SetColor(unpack(currentColors.bad))
            -- Gentle pulse to signal "cast now"
            local pulse = 0.5 + 0.5 * math.sin((elapsed - gcdMs) * 0.005)
            bar:SetAlpha(0.5 + pulse * 0.5)
        end
    else
        -- No recent LA - show idle state
        bar:SetValue(0)
        bar:SetColor(unpack(currentColors.idle))
    end
end

---------------------------------------------------------------------------
-- Show / Hide
---------------------------------------------------------------------------
function RhythmBar:Show()
    if not settings.rhythmBar.enabled or not tlw then return end
    tlw:SetHidden(false)
    isVisible = true
    lastLATime = 0

    -- Start frame update
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS, 33, function() self:OnUpdate() end)
end

function RhythmBar:Hide()
    if not tlw then return end
    tlw:SetHidden(true)
    isVisible = false
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS)
end

function RhythmBar:FadeOut()
    if not tlw then return end
    local delay = (settings.fadeDelay or 2) * 1000
    zo_callLater(function()
        if not WF.WeaveEngine:IsInCombat() then
            self:Hide()
        end
    end, delay)
end

---------------------------------------------------------------------------
-- Flash effect for weave success/miss
---------------------------------------------------------------------------
function RhythmBar:FlashColor(color)
    if not flashOverlay or not self.flashTimeline then return end
    flashOverlay:SetCenterColor(color[1], color[2], color[3], 0.8)
    flashOverlay:SetHidden(false)
    self.flashTimeline:PlayFromStart()
end

---------------------------------------------------------------------------
-- Settings update handlers
---------------------------------------------------------------------------
function RhythmBar:UpdatePosition()
    if not tlw then return end
    tlw:ClearAnchors()
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, settings.rhythmBar.offsetX, settings.rhythmBar.offsetY)
end

function RhythmBar:UpdateDimensions()
    if not tlw then return end
    tlw:SetDimensions(settings.rhythmBar.width, settings.rhythmBar.height)
end

function RhythmBar:UpdateMovable()
    if not tlw then return end
    tlw:SetMovable(settings.rhythmBar.unlocked)
    tlw:SetMouseEnabled(settings.rhythmBar.unlocked)
end

function RhythmBar:UpdateOpacity()
    if not tlw then return end
    tlw:SetAlpha(settings.rhythmBar.opacity)
end

function RhythmBar:SetEnabled(enabled)
    settings.rhythmBar.enabled = enabled
    if enabled then
        if not tlw then
            self:CreateUI()
            self:ApplyColorScheme()
        end
        if WF.WeaveEngine:IsInCombat() then
            self:Show()
        end
    else
        self:Hide()
    end
end
