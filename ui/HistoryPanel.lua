-- WeaveForge History Panel
-- Session and historical progress viewer with fight list and accuracy trends

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local HistoryPanel = {}
WF.HistoryPanel = HistoryPanel

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings      = nil
local panel         = nil
local summaryLabel  = nil
local trendLabel    = nil
local scrollChild   = nil
local filterButtons = {}
local fightRows     = {}
local isShowing     = false
local currentFilter = "all"

local PANEL_WIDTH   = 580
local PANEL_HEIGHT  = 500
local ROW_HEIGHT    = 22
local HEADER_HEIGHT = 120

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function HistoryPanel:Initialize(accountSV)
    settings = accountSV
    self:CreateUI()
end

---------------------------------------------------------------------------
-- Create the panel UI
---------------------------------------------------------------------------
function HistoryPanel:CreateUI()
    -- Main panel window
    panel = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_HistoryPanel")
    panel:SetDimensions(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    panel:SetMovable(true)
    panel:SetMouseEnabled(true)
    panel:SetClampedToScreen(true)
    panel:SetHidden(true)
    panel:SetDrawLayer(DL_OVERLAY)
    panel:SetDrawTier(DT_HIGH)

    -- Background
    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", panel, CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.92)
    bg:SetEdgeColor(0.6, 0.5, 0.2, 0.8)
    bg:SetEdgeTexture("", 2, 2, 2, 0)

    -- Title
    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 8)
    title:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    title:SetColor(1, 0.84, 0, 1)
    title:SetText(L.HISTORY_TITLE)

    -- Close button
    local closeBtn = WINDOW_MANAGER:CreateControl("$(parent)Close", panel, CT_LABEL)
    closeBtn:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -12, 8)
    closeBtn:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    closeBtn:SetColor(0.8, 0.2, 0.2, 1)
    closeBtn:SetText("X")
    closeBtn:SetMouseEnabled(true)
    closeBtn:SetHandler("OnMouseUp", function()
        self:Hide()
    end)

    -- Summary stats area
    summaryLabel = WINDOW_MANAGER:CreateControl("$(parent)Summary", panel, CT_LABEL)
    summaryLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 32)
    summaryLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -12, 32)
    summaryLabel:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    summaryLabel:SetColor(0.85, 0.85, 0.85, 1)
    summaryLabel:SetMaxLineCount(3)
    summaryLabel:SetText("")

    -- Accuracy trend sparkline (text-based)
    trendLabel = WINDOW_MANAGER:CreateControl("$(parent)Trend", panel, CT_LABEL)
    trendLabel:SetAnchor(TOPLEFT, summaryLabel, BOTTOMLEFT, 0, 4)
    trendLabel:SetAnchor(TOPRIGHT, summaryLabel, BOTTOMRIGHT, 0, 4)
    trendLabel:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    trendLabel:SetColor(0.7, 0.7, 0.7, 0.8)
    trendLabel:SetText("")

    -- Filter buttons
    self:CreateFilterButtons()

    -- Column headers
    self:CreateColumnHeaders()

    -- Scroll container for fight rows
    local scrollContainer = WINDOW_MANAGER:CreateControl("$(parent)Scroll", panel, CT_SCROLL)
    scrollContainer:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, HEADER_HEIGHT + ROW_HEIGHT + 8)
    scrollContainer:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -8, -12)

    scrollChild = WINDOW_MANAGER:CreateControl("$(parent)ScrollChild", scrollContainer, CT_CONTROL)
    scrollChild:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, 0)
    scrollChild:SetWidth(PANEL_WIDTH - 20)
end

---------------------------------------------------------------------------
-- Create filter buttons
---------------------------------------------------------------------------
function HistoryPanel:CreateFilterButtons()
    local filters = {
        { id = "all",     label = L.HISTORY_FILTER_ALL },
        { id = "dummy",   label = L.HISTORY_FILTER_DUMMY },
        { id = "dungeon", label = L.HISTORY_FILTER_DUNGEON },
        { id = "trial",   label = L.HISTORY_FILTER_TRIAL },
        { id = "solo",    label = L.HISTORY_FILTER_SOLO },
        { id = "pvp",     label = L.HISTORY_FILTER_PVP },
    }

    local startX = 12
    local y = 78

    for i, f in ipairs(filters) do
        local btn = WINDOW_MANAGER:CreateControl("WeaveForge_HistFilter" .. i, panel, CT_LABEL)
        btn:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
        btn:SetText(f.label)
        btn:SetMouseEnabled(true)

        if i == 1 then
            btn:SetAnchor(TOPLEFT, panel, TOPLEFT, startX, y)
        else
            btn:SetAnchor(LEFT, filterButtons[i - 1], RIGHT, 10, 0)
        end

        local filterId = f.id
        btn:SetHandler("OnMouseUp", function()
            self:SetFilter(filterId)
        end)
        btn:SetHandler("OnMouseEnter", function(control)
            if filterId ~= currentFilter then
                control:SetColor(1, 0.84, 0, 1)
            end
        end)
        btn:SetHandler("OnMouseExit", function(control)
            if filterId ~= currentFilter then
                control:SetColor(0.6, 0.6, 0.6, 1)
            end
        end)

        filterButtons[i] = btn
    end

    -- Store filter IDs for reference
    self.filterIds = {}
    for i, f in ipairs(filters) do
        self.filterIds[i] = f.id
    end
end

---------------------------------------------------------------------------
-- Create column headers
---------------------------------------------------------------------------
function HistoryPanel:CreateColumnHeaders()
    local headers = {
        { text = L.HISTORY_COL_DATE,     x = 12,  width = 110 },
        { text = L.HISTORY_COL_TARGET,   x = 130, width = 140 },
        { text = L.HISTORY_COL_DURATION, x = 278, width = 65 },
        { text = L.HISTORY_COL_ACCURACY, x = 350, width = 65 },
        { text = L.HISTORY_COL_LA_S,     x = 420, width = 55 },
        { text = L.HISTORY_COL_STREAK,   x = 480, width = 55 },
    }

    local y = HEADER_HEIGHT

    for _, h in ipairs(headers) do
        local label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, h.x, y)
        label:SetWidth(h.width)
        label:SetFont("$(BOLD_FONT)|12|soft-shadow-thin")
        label:SetColor(0.7, 0.6, 0.3, 1)
        label:SetText(h.text)
    end

    -- Divider
    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, y + ROW_HEIGHT)
    divider:SetDimensions(PANEL_WIDTH - 16, 1)
    divider:SetCenterColor(0.5, 0.4, 0.2, 0.6)
    divider:SetEdgeColor(0, 0, 0, 0)
end

---------------------------------------------------------------------------
-- Set filter and refresh
---------------------------------------------------------------------------
function HistoryPanel:SetFilter(filterId)
    currentFilter = filterId
    self:UpdateFilterButtonColors()
    self:Refresh()
end

function HistoryPanel:UpdateFilterButtonColors()
    for i, btn in ipairs(filterButtons) do
        local filterId = self.filterIds[i]
        if filterId == currentFilter then
            btn:SetColor(1, 0.84, 0, 1)  -- gold = active
        else
            btn:SetColor(0.6, 0.6, 0.6, 1)  -- grey = inactive
        end
    end
end

---------------------------------------------------------------------------
-- Refresh display with current data
---------------------------------------------------------------------------
function HistoryPanel:Refresh()
    if not panel then return end

    -- Get aggregate stats
    local stats = WF.HistoryManager:GetAggregateStats(currentFilter)

    -- Update summary
    local summaryText = string.format(L.HISTORY_FIGHTS, stats.totalFights) .. "  |  "
    summaryText = summaryText .. string.format(L.HISTORY_AVG_ACCURACY, stats.avgAccuracy * 100) .. "  |  "
    summaryText = summaryText .. string.format(L.HISTORY_BEST_STREAK, stats.bestStreak)
    summaryLabel:SetText(summaryText)

    -- Update accuracy trend sparkline
    local trend = WF.HistoryManager:GetAccuracyTrend(20, currentFilter)
    self:UpdateTrendDisplay(trend)

    -- Populate fight rows
    local fights = WF.HistoryManager:GetFightHistory(currentFilter)
    self:PopulateFightRows(fights)

    self:UpdateFilterButtonColors()
end

---------------------------------------------------------------------------
-- Update accuracy trend display (text-based sparkline)
---------------------------------------------------------------------------
function HistoryPanel:UpdateTrendDisplay(trend)
    if not trendLabel or #trend == 0 then
        if trendLabel then trendLabel:SetText("") end
        return
    end

    -- Build text-based sparkline using unicode block characters
    local blocks = { "\226\150\129", "\226\150\130", "\226\150\131", "\226\150\132",
                     "\226\150\133", "\226\150\134", "\226\150\135", "\226\150\136" }
    local sparkline = "Trend: "

    -- Reverse so oldest is first (left)
    for i = #trend, 1, -1 do
        local pct = trend[i]
        local blockIndex = math.max(1, math.min(8, math.floor(pct * 8) + 1))
        sparkline = sparkline .. (blocks[blockIndex] or "|")
    end

    trendLabel:SetText(sparkline)
end

---------------------------------------------------------------------------
-- Populate fight rows
---------------------------------------------------------------------------
function HistoryPanel:PopulateFightRows(fights)
    -- Clear existing rows
    for _, row in ipairs(fightRows) do
        row:SetHidden(true)
    end

    if not fights or #fights == 0 then
        -- Show "no data" message
        local row = self:GetOrCreateFightRow(1)
        row.dateLabel:SetText(L.HISTORY_NO_DATA)
        row.targetLabel:SetText("")
        row.durationLabel:SetText("")
        row.accuracyLabel:SetText("")
        row.lapsLabel:SetText("")
        row.streakLabel:SetText("")
        row:SetHidden(false)
        if scrollChild then
            scrollChild:SetHeight(ROW_HEIGHT + 10)
        end
        return
    end

    for i, fight in ipairs(fights) do
        local row = self:GetOrCreateFightRow(i)
        self:UpdateFightRow(row, fight)
        row:SetHidden(false)
    end

    if scrollChild then
        scrollChild:SetHeight(#fights * ROW_HEIGHT + 10)
    end
end

---------------------------------------------------------------------------
-- Get or create a fight row
---------------------------------------------------------------------------
function HistoryPanel:GetOrCreateFightRow(index)
    if fightRows[index] then return fightRows[index] end

    local row = WINDOW_MANAGER:CreateControl("WeaveForge_HistRow" .. index, scrollChild, CT_CONTROL)
    row:SetDimensions(PANEL_WIDTH - 24, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (index - 1) * ROW_HEIGHT)

    -- Alternate background
    if index % 2 == 0 then
        local rowBg = WINDOW_MANAGER:CreateControl("$(parent)BG", row, CT_BACKDROP)
        rowBg:SetAnchorFill(row)
        rowBg:SetCenterColor(0.15, 0.15, 0.15, 0.3)
        rowBg:SetEdgeColor(0, 0, 0, 0)
    end

    -- Date
    local dateL = WINDOW_MANAGER:CreateControl("$(parent)Date", row, CT_LABEL)
    dateL:SetAnchor(LEFT, row, LEFT, 4, 0)
    dateL:SetWidth(110)
    dateL:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    dateL:SetColor(0.7, 0.7, 0.7, 1)
    row.dateLabel = dateL

    -- Target
    local targetL = WINDOW_MANAGER:CreateControl("$(parent)Target", row, CT_LABEL)
    targetL:SetAnchor(LEFT, row, LEFT, 122, 0)
    targetL:SetWidth(140)
    targetL:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    targetL:SetColor(0.85, 0.85, 0.85, 1)
    row.targetLabel = targetL

    -- Duration
    local durL = WINDOW_MANAGER:CreateControl("$(parent)Dur", row, CT_LABEL)
    durL:SetAnchor(LEFT, row, LEFT, 270, 0)
    durL:SetWidth(65)
    durL:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    durL:SetColor(0.7, 0.7, 0.7, 1)
    durL:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.durationLabel = durL

    -- Accuracy
    local accL = WINDOW_MANAGER:CreateControl("$(parent)Acc", row, CT_LABEL)
    accL:SetAnchor(LEFT, row, LEFT, 342, 0)
    accL:SetWidth(65)
    accL:SetFont("$(BOLD_FONT)|12|soft-shadow-thin")
    accL:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.accuracyLabel = accL

    -- LA/s
    local lapsL = WINDOW_MANAGER:CreateControl("$(parent)LAs", row, CT_LABEL)
    lapsL:SetAnchor(LEFT, row, LEFT, 412, 0)
    lapsL:SetWidth(55)
    lapsL:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    lapsL:SetColor(0.7, 0.7, 0.7, 1)
    lapsL:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.lapsLabel = lapsL

    -- Streak
    local streakL = WINDOW_MANAGER:CreateControl("$(parent)Streak", row, CT_LABEL)
    streakL:SetAnchor(LEFT, row, LEFT, 472, 0)
    streakL:SetWidth(55)
    streakL:SetFont("$(MEDIUM_FONT)|12|soft-shadow-thin")
    streakL:SetColor(1, 0.84, 0, 1)
    streakL:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.streakLabel = streakL

    -- Click handler to view fight details
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseUp", function()
        local fights = WF.HistoryManager:GetFightHistory(currentFilter)
        if fights[index] then
            WF.FightSummaryPanel:ShowFight(fights[index])
        end
    end)
    row:SetHandler("OnMouseEnter", function(control)
        if control.dateLabel then
            control.dateLabel:SetColor(1, 0.84, 0, 1)
        end
    end)
    row:SetHandler("OnMouseExit", function(control)
        if control.dateLabel then
            control.dateLabel:SetColor(0.7, 0.7, 0.7, 1)
        end
    end)

    fightRows[index] = row
    return row
end

---------------------------------------------------------------------------
-- Update a fight row with data
---------------------------------------------------------------------------
function HistoryPanel:UpdateFightRow(row, fight)
    -- Format date
    local dateStr = ""
    if fight.timestamp then
        dateStr = GetDateStringFromTimestamp(fight.timestamp) or ""
    end
    row.dateLabel:SetText(dateStr)

    -- Target
    local target = fight.target or "Unknown"
    if fight.isDummy then
        target = target .. " (Dummy)"
    end
    row.targetLabel:SetText(target)

    -- Duration
    row.durationLabel:SetText(WF.HistoryManager:FormatDuration(fight.duration or 0))

    -- Accuracy with color
    local accPct = (fight.overallAccuracy or 0) * 100
    row.accuracyLabel:SetText(string.format("%.0f%%", accPct))
    if accPct >= 90 then
        row.accuracyLabel:SetColor(0.4, 0.9, 0.4, 1)
    elseif accPct >= 70 then
        row.accuracyLabel:SetColor(0.9, 0.9, 0.2, 1)
    else
        row.accuracyLabel:SetColor(0.9, 0.4, 0.4, 1)
    end

    -- LA/s
    row.lapsLabel:SetText(string.format("%.2f", fight.laPerSecond or 0))

    -- Streak
    row.streakLabel:SetText(tostring(fight.longestStreak or 0))
end

---------------------------------------------------------------------------
-- Show / Hide / Toggle
---------------------------------------------------------------------------
function HistoryPanel:Show()
    if not panel then return end
    self:Refresh()
    panel:SetHidden(false)
    isShowing = true
end

function HistoryPanel:Hide()
    if not panel then return end
    panel:SetHidden(true)
    isShowing = false
end

function HistoryPanel:Toggle()
    if isShowing then
        self:Hide()
    else
        self:Show()
    end
end
