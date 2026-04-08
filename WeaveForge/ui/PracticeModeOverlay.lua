-- WeaveForge Practice Mode Overlay
-- Enhanced UI for target dummy training: metronome, timing histogram, ghost bar

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local PracticeModeOverlay = {}
WF.PracticeModeOverlay = PracticeModeOverlay

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings          = nil
local panel             = nil     -- practice mode info overlay
local lapsLabel         = nil     -- live LA/s display
local timeSinceLALabel  = nil     -- ms since last LA
local histogramPanel    = nil     -- post-fight histogram window
local histogramRows     = {}
local ghostBar          = nil     -- ghost bar overlay on rhythm bar
local isActive          = false
local isMetronomeOn     = false
local metronomeTimer    = nil
local lastLATime        = 0
local laCount           = 0
local combatStartTime   = 0
local UPDATE_NS         = "WeaveForge_PracticeModeUpdate"

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function PracticeModeOverlay:Initialize(accountSV)
    settings = accountSV
    self:CreateUI()
    self:CreateHistogramPanel()
    self:CreateGhostBar()
    self:RegisterCallbacks()
end

---------------------------------------------------------------------------
-- Create the practice mode overlay UI
---------------------------------------------------------------------------
function PracticeModeOverlay:CreateUI()
    -- Practice info panel (positioned near the rhythm bar)
    panel = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_PracticeOverlay")
    panel:SetDimensions(180, 50)
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 120)
    panel:SetHidden(true)
    panel:SetDrawLayer(DL_OVERLAY)
    panel:SetDrawTier(DT_HIGH)
    panel:SetMouseEnabled(false)

    -- Background
    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", panel, CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.75)
    bg:SetEdgeColor(0.5, 0.4, 0.2, 0.5)
    bg:SetEdgeTexture("", 1, 1, 1, 0)

    -- Practice mode label
    local titleLbl = WINDOW_MANAGER:CreateControl("$(parent)Title", panel, CT_LABEL)
    titleLbl:SetAnchor(TOP, panel, TOP, 0, 3)
    titleLbl:SetFont("$(BOLD_FONT)|11|soft-shadow-thin")
    titleLbl:SetColor(1, 0.84, 0, 0.8)
    titleLbl:SetText(L.PRACTICE_TITLE)
    titleLbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- LA/s display
    lapsLabel = WINDOW_MANAGER:CreateControl("$(parent)LAps", panel, CT_LABEL)
    lapsLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 18)
    lapsLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    lapsLabel:SetColor(0.4, 0.9, 0.4, 1)
    lapsLabel:SetText(string.format(L.PRACTICE_LA_PER_SEC, 0))

    -- Time since last LA
    timeSinceLALabel = WINDOW_MANAGER:CreateControl("$(parent)TimeSince", panel, CT_LABEL)
    timeSinceLALabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 34)
    timeSinceLALabel:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    timeSinceLALabel:SetColor(0.7, 0.7, 0.7, 1)
    timeSinceLALabel:SetText(string.format(L.PRACTICE_TIME_SINCE_LA, 0))
end

---------------------------------------------------------------------------
-- Create the timing histogram panel (shown after practice fight ends)
---------------------------------------------------------------------------
function PracticeModeOverlay:CreateHistogramPanel()
    histogramPanel = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_Histogram")
    histogramPanel:SetDimensions(350, 300)
    histogramPanel:SetAnchor(CENTER, GuiRoot, CENTER, 200, 0)
    histogramPanel:SetMovable(true)
    histogramPanel:SetMouseEnabled(true)
    histogramPanel:SetClampedToScreen(true)
    histogramPanel:SetHidden(true)
    histogramPanel:SetDrawLayer(DL_OVERLAY)
    histogramPanel:SetDrawTier(DT_HIGH)

    -- Background
    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", histogramPanel, CT_BACKDROP)
    bg:SetAnchorFill(histogramPanel)
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.92)
    bg:SetEdgeColor(0.6, 0.5, 0.2, 0.8)
    bg:SetEdgeTexture("", 2, 2, 2, 0)

    -- Title
    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", histogramPanel, CT_LABEL)
    title:SetAnchor(TOPLEFT, histogramPanel, TOPLEFT, 12, 8)
    title:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    title:SetColor(1, 0.84, 0, 1)
    title:SetText(L.PRACTICE_HISTOGRAM_TITLE)

    -- Close button
    local closeBtn = WINDOW_MANAGER:CreateControl("$(parent)Close", histogramPanel, CT_LABEL)
    closeBtn:SetAnchor(TOPRIGHT, histogramPanel, TOPRIGHT, -12, 8)
    closeBtn:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    closeBtn:SetColor(0.8, 0.2, 0.2, 1)
    closeBtn:SetText("X")
    closeBtn:SetMouseEnabled(true)
    closeBtn:SetHandler("OnMouseUp", function()
        histogramPanel:SetHidden(true)
    end)
end

---------------------------------------------------------------------------
-- Create ghost bar overlay (ideal timing guide on rhythm bar)
---------------------------------------------------------------------------
function PracticeModeOverlay:CreateGhostBar()
    -- Ghost bar is a translucent overlay on the existing rhythm bar
    -- It shows the "ideal" timing window
    ghostBar = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_GhostBar")
    ghostBar:SetDimensions(settings.rhythmBar.width or 200, (settings.rhythmBar.height or 4) + 4)
    ghostBar:SetAnchor(CENTER, GuiRoot, CENTER, settings.rhythmBar.offsetX or 0, (settings.rhythmBar.offsetY or 80) - 6)
    ghostBar:SetHidden(true)
    ghostBar:SetDrawLayer(DL_OVERLAY)
    ghostBar:SetMouseEnabled(false)

    -- Ideal timing marker (vertical line showing optimal cast point)
    local marker = WINDOW_MANAGER:CreateControl("$(parent)Marker", ghostBar, CT_BACKDROP)
    marker:SetDimensions(3, ghostBar:GetHeight())
    -- Position at ~75% of bar width (ideal timing: LA at 0%, cast around 750ms into 1000ms GCD)
    marker:SetAnchor(LEFT, ghostBar, LEFT, math.floor((settings.rhythmBar.width or 200) * 0.75), 0)
    marker:SetCenterColor(1, 1, 1, 0.4)
    marker:SetEdgeColor(0, 0, 0, 0)

    -- Ideal window zone (green translucent band)
    local zone = WINDOW_MANAGER:CreateControl("$(parent)Zone", ghostBar, CT_BACKDROP)
    local zoneStart = math.floor((settings.rhythmBar.width or 200) * 0.6)
    local zoneEnd = math.floor((settings.rhythmBar.width or 200) * 0.9)
    zone:SetDimensions(zoneEnd - zoneStart, ghostBar:GetHeight())
    zone:SetAnchor(LEFT, ghostBar, LEFT, zoneStart, 0)
    zone:SetCenterColor(0.2, 0.8, 0.2, 0.15)
    zone:SetEdgeColor(0, 0, 0, 0)
end

---------------------------------------------------------------------------
-- Register callbacks
---------------------------------------------------------------------------
function PracticeModeOverlay:RegisterCallbacks()
    local cm = CALLBACK_MANAGER

    cm:RegisterCallback(WF.EVENT_PRACTICE_MODE, function(enabled)
        if enabled then
            self:Activate()
        else
            self:Deactivate()
        end
    end)

    cm:RegisterCallback(WF.EVENT_LIGHT_ATTACK, function(timestamp, abilityId, weaponType)
        lastLATime = timestamp
        laCount = laCount + 1
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_START, function()
        if isActive then
            combatStartTime = GetGameTimeMilliseconds()
            laCount = 0
        end
    end)

    cm:RegisterCallback(WF.EVENT_COMBAT_END, function()
        if isActive and settings.practiceMode.showHistogram then
            self:ShowHistogram()
        end
    end)

    cm:RegisterCallback("WeaveForge_FightEnd", function(fightRecord)
        -- No additional action needed; histogram uses fight data
    end)
end

---------------------------------------------------------------------------
-- Activate practice mode
---------------------------------------------------------------------------
function PracticeModeOverlay:Activate()
    isActive = true
    laCount = 0
    combatStartTime = GetGameTimeMilliseconds()

    -- Show practice overlay
    if panel then
        panel:SetHidden(false)
    end

    -- Show ghost bar if enabled
    if settings.practiceMode.showGhostBar and ghostBar then
        ghostBar:SetHidden(false)
    end

    -- Start live update
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NS, 50, function() self:OnUpdate() end)

    -- Start metronome if enabled
    if settings.practiceMode.metronome then
        self:StartMetronome()
    end

    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.PRACTICE_DUMMY_DETECTED)
    end
end

---------------------------------------------------------------------------
-- Deactivate practice mode
---------------------------------------------------------------------------
function PracticeModeOverlay:Deactivate()
    isActive = false

    if panel then
        panel:SetHidden(true)
    end
    if ghostBar then
        ghostBar:SetHidden(true)
    end

    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NS)
    self:StopMetronome()
end

---------------------------------------------------------------------------
-- Frame update for live stats
---------------------------------------------------------------------------
function PracticeModeOverlay:OnUpdate()
    if not isActive then return end

    local now = GetGameTimeMilliseconds()

    -- Update LA/s
    local elapsed = (now - combatStartTime) / 1000
    if elapsed > 0 and lapsLabel then
        local laps = laCount / elapsed
        lapsLabel:SetText(string.format(L.PRACTICE_LA_PER_SEC, laps))
    end

    -- Update time since last LA
    if lastLATime > 0 and timeSinceLALabel then
        local timeSince = now - lastLATime
        timeSinceLALabel:SetText(string.format(L.PRACTICE_TIME_SINCE_LA, timeSince))

        -- Color code: green if recent, yellow if getting stale, red if too long
        if timeSince < 800 then
            timeSinceLALabel:SetColor(0.4, 0.9, 0.4, 1)
        elseif timeSince < 1200 then
            timeSinceLALabel:SetColor(0.9, 0.9, 0.2, 1)
        else
            timeSinceLALabel:SetColor(0.9, 0.4, 0.4, 1)
        end
    end
end

---------------------------------------------------------------------------
-- Metronome
---------------------------------------------------------------------------
function PracticeModeOverlay:StartMetronome()
    if isMetronomeOn then return end
    isMetronomeOn = true

    local interval = WF.GCD_MS  -- tick at GCD rate
    local tickSound = SOUNDS.COUNTDOWN_TICK or SOUNDS.QUICKSLOT_USE_EMPTY

    EVENT_MANAGER:RegisterForUpdate("WeaveForge_Metronome", interval, function()
        if isMetronomeOn and WF.WeaveEngine:IsInCombat() then
            PlaySound(tickSound)
        end
    end)
end

function PracticeModeOverlay:StopMetronome()
    isMetronomeOn = false
    EVENT_MANAGER:UnregisterForUpdate("WeaveForge_Metronome")
end

---------------------------------------------------------------------------
-- Show timing histogram after practice fight
---------------------------------------------------------------------------
function PracticeModeOverlay:ShowHistogram()
    if not histogramPanel then return end

    -- Get the last fight's weave gaps
    local lastFight = WF.HistoryManager:GetLastFight()
    if not lastFight or not lastFight.weaveGaps or #lastFight.weaveGaps == 0 then
        return
    end

    local gaps = lastFight.weaveGaps

    -- Build histogram buckets (50ms each, from 0 to 1500ms)
    local buckets = {}
    local maxCount = 0
    for i = 0, 30 do  -- 0-50, 50-100, ..., 1450-1500
        buckets[i] = 0
    end

    for _, gap in ipairs(gaps) do
        local bucketIndex = math.floor(gap / 50)
        if bucketIndex > 30 then bucketIndex = 30 end
        buckets[bucketIndex] = (buckets[bucketIndex] or 0) + 1
        if buckets[bucketIndex] > maxCount then
            maxCount = buckets[bucketIndex]
        end
    end

    -- Clear existing rows
    for _, row in ipairs(histogramRows) do
        row:SetHidden(true)
    end

    -- Create histogram rows (only show non-empty buckets)
    local rowIndex = 0
    local startY = 34

    for i = 0, 30 do
        if buckets[i] > 0 then
            rowIndex = rowIndex + 1

            local row = histogramRows[rowIndex]
            if not row then
                row = WINDOW_MANAGER:CreateControl("WeaveForge_HistBucket" .. rowIndex, histogramPanel, CT_CONTROL)
                row:SetDimensions(326, 18)

                row.label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
                row.label:SetAnchor(LEFT, row, LEFT, 4, 0)
                row.label:SetWidth(100)
                row.label:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
                row.label:SetColor(0.7, 0.7, 0.7, 1)

                row.bar = WINDOW_MANAGER:CreateControl("$(parent)Bar", row, CT_BACKDROP)
                row.bar:SetAnchor(LEFT, row, LEFT, 110, 0)
                row.bar:SetHeight(12)
                row.bar:SetEdgeColor(0, 0, 0, 0)

                row.countLabel = WINDOW_MANAGER:CreateControl("$(parent)Count", row, CT_LABEL)
                row.countLabel:SetFont("$(MEDIUM_FONT)|11|soft-shadow-thin")
                row.countLabel:SetColor(0.85, 0.85, 0.85, 1)

                histogramRows[rowIndex] = row
            end

            row:SetAnchor(TOPLEFT, histogramPanel, TOPLEFT, 8, startY + (rowIndex - 1) * 20)

            -- Bucket range label
            local rangeStart = i * 50
            local rangeEnd = rangeStart + 50
            row.label:SetText(string.format("%d-%dms", rangeStart, rangeEnd))

            -- Bar width proportional to count
            local barWidth = math.max(2, math.floor((buckets[i] / maxCount) * 190))
            row.bar:SetDimensions(barWidth, 12)

            -- Color based on timing quality
            if rangeStart >= 500 and rangeEnd <= 1000 then
                row.bar:SetCenterColor(0.3, 0.8, 0.3, 0.8)  -- green = good timing
            elseif rangeStart >= 300 and rangeEnd <= 1200 then
                row.bar:SetCenterColor(0.8, 0.8, 0.2, 0.8)  -- yellow = okay
            else
                row.bar:SetCenterColor(0.8, 0.3, 0.3, 0.8)  -- red = bad
            end

            -- Count label
            row.countLabel:SetText(string.format(" (%d)", buckets[i]))
            row.countLabel:ClearAnchors()
            row.countLabel:SetAnchor(LEFT, row.bar, RIGHT, 4, 0)

            row:SetHidden(false)
        end
    end

    -- Resize histogram panel to fit
    histogramPanel:SetHeight(startY + rowIndex * 20 + 20)
    histogramPanel:SetHidden(false)
end

---------------------------------------------------------------------------
-- Toggle practice mode manually
---------------------------------------------------------------------------
function PracticeModeOverlay:Toggle()
    if isActive then
        self:Deactivate()
    else
        self:Activate()
    end
end

function PracticeModeOverlay:IsActive()
    return isActive
end
