-- WeaveForge Fight Summary Panel
-- Post-fight per-skill breakdown window showing weave accuracy details

local WF = WeaveForge
local L  = WF.L

---------------------------------------------------------------------------
-- Module table
---------------------------------------------------------------------------
local FightSummaryPanel = {}
WF.FightSummaryPanel = FightSummaryPanel

---------------------------------------------------------------------------
-- Local state
---------------------------------------------------------------------------
local settings      = nil
local panel         = nil     -- main panel window
local headerLabel   = nil     -- fight info header
local statsLabel    = nil     -- summary stats
local scrollChild   = nil     -- scroll content area
local skillRows     = {}      -- created row controls
local isShowing     = false
local lastFight     = nil     -- currently displayed fight record
local ROW_HEIGHT    = 24
local PANEL_WIDTH   = 520
local PANEL_HEIGHT  = 450
local HEADER_HEIGHT = 90

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
function FightSummaryPanel:Initialize(accountSV)
    settings = accountSV
    self:CreateUI()
    self:RegisterCallbacks()
end

---------------------------------------------------------------------------
-- Create the panel UI
---------------------------------------------------------------------------
function FightSummaryPanel:CreateUI()
    -- Main panel window
    panel = WINDOW_MANAGER:CreateTopLevelWindow("WeaveForge_FightSummary")
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

    -- Title bar
    local titleBar = WINDOW_MANAGER:CreateControl("$(parent)Title", panel, CT_LABEL)
    titleBar:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 8)
    titleBar:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    titleBar:SetColor(1, 0.84, 0, 1)
    titleBar:SetText(L.FIGHT_SUMMARY_TITLE)

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

    -- Header area (fight info)
    headerLabel = WINDOW_MANAGER:CreateControl("$(parent)Header", panel, CT_LABEL)
    headerLabel:SetAnchor(TOPLEFT, panel, TOPLEFT, 12, 32)
    headerLabel:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -12, 32)
    headerLabel:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    headerLabel:SetColor(0.85, 0.85, 0.85, 1)
    headerLabel:SetMaxLineCount(3)
    headerLabel:SetText("")

    -- Summary stats
    statsLabel = WINDOW_MANAGER:CreateControl("$(parent)Stats", panel, CT_LABEL)
    statsLabel:SetAnchor(TOPLEFT, headerLabel, BOTTOMLEFT, 0, 4)
    statsLabel:SetAnchor(TOPRIGHT, headerLabel, BOTTOMRIGHT, 0, 4)
    statsLabel:SetFont("$(BOLD_FONT)|15|soft-shadow-thin")
    statsLabel:SetColor(1, 0.84, 0, 1)
    statsLabel:SetText("")

    -- Column headers
    local colY = HEADER_HEIGHT
    self:CreateColumnHeaders(colY)

    -- Scroll container for skill rows
    local scrollContainer = WINDOW_MANAGER:CreateControl("$(parent)Scroll", panel, CT_SCROLL)
    scrollContainer:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, colY + ROW_HEIGHT + 4)
    scrollContainer:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -8, -50)

    scrollChild = WINDOW_MANAGER:CreateControl("$(parent)ScrollChild", scrollContainer, CT_CONTROL)
    scrollChild:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, 0)
    scrollChild:SetWidth(PANEL_WIDTH - 20)

    -- Bottom buttons
    self:CreateBottomButtons()
end

---------------------------------------------------------------------------
-- Create column headers
---------------------------------------------------------------------------
function FightSummaryPanel:CreateColumnHeaders(yOffset)
    local headers = {
        { text = L.SKILL_COL_NAME,     x = 12,  width = 160 },
        { text = L.SKILL_COL_CASTS,    x = 180, width = 50 },
        { text = L.SKILL_COL_WEAVED,   x = 235, width = 55 },
        { text = L.SKILL_COL_MISSED,   x = 295, width = 55 },
        { text = L.SKILL_COL_ACCURACY, x = 355, width = 65 },
        { text = L.SKILL_COL_AVG_GAP,  x = 430, width = 75 },
    }

    for _, h in ipairs(headers) do
        local label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, h.x, yOffset)
        label:SetWidth(h.width)
        label:SetFont("$(BOLD_FONT)|13|soft-shadow-thin")
        label:SetColor(0.7, 0.6, 0.3, 1)
        label:SetText(h.text)
    end

    -- Divider line
    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, yOffset + ROW_HEIGHT)
    divider:SetDimensions(PANEL_WIDTH - 16, 1)
    divider:SetCenterColor(0.5, 0.4, 0.2, 0.6)
    divider:SetEdgeColor(0, 0, 0, 0)
end

---------------------------------------------------------------------------
-- Create bottom buttons
---------------------------------------------------------------------------
function FightSummaryPanel:CreateBottomButtons()
    -- Pin button
    local pinBtn = WINDOW_MANAGER:CreateControl("$(parent)Pin", panel, CT_LABEL)
    pinBtn:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 12, -12)
    pinBtn:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    pinBtn:SetColor(0.8, 0.8, 0.3, 1)
    pinBtn:SetText(L.BTN_PIN_FIGHT)
    pinBtn:SetMouseEnabled(true)
    pinBtn:SetHandler("OnMouseUp", function()
        self:PinCurrentFight()
    end)
    pinBtn:SetHandler("OnMouseEnter", function(control)
        control:SetColor(1, 1, 0.5, 1)
    end)
    pinBtn:SetHandler("OnMouseExit", function(control)
        control:SetColor(0.8, 0.8, 0.3, 1)
    end)

    -- Export button
    local exportBtn = WINDOW_MANAGER:CreateControl("$(parent)Export", panel, CT_LABEL)
    exportBtn:SetAnchor(BOTTOM, panel, BOTTOM, 0, -12)
    exportBtn:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    exportBtn:SetColor(0.5, 0.7, 0.9, 1)
    exportBtn:SetText(L.BTN_EXPORT)
    exportBtn:SetMouseEnabled(true)
    exportBtn:SetHandler("OnMouseUp", function()
        if lastFight then
            WF.FightRecorder:ExportToChat(lastFight)
        end
    end)
    exportBtn:SetHandler("OnMouseEnter", function(control)
        control:SetColor(0.7, 0.9, 1, 1)
    end)
    exportBtn:SetHandler("OnMouseExit", function(control)
        control:SetColor(0.5, 0.7, 0.9, 1)
    end)

    -- Close button at bottom
    local closeBtnBottom = WINDOW_MANAGER:CreateControl("$(parent)CloseBtn", panel, CT_LABEL)
    closeBtnBottom:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -12, -12)
    closeBtnBottom:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    closeBtnBottom:SetColor(0.7, 0.7, 0.7, 1)
    closeBtnBottom:SetText(L.BTN_CLOSE)
    closeBtnBottom:SetMouseEnabled(true)
    closeBtnBottom:SetHandler("OnMouseUp", function()
        self:Hide()
    end)
    closeBtnBottom:SetHandler("OnMouseEnter", function(control)
        control:SetColor(1, 1, 1, 1)
    end)
    closeBtnBottom:SetHandler("OnMouseExit", function(control)
        control:SetColor(0.7, 0.7, 0.7, 1)
    end)
end

---------------------------------------------------------------------------
-- Register callbacks
---------------------------------------------------------------------------
function FightSummaryPanel:RegisterCallbacks()
    CALLBACK_MANAGER:RegisterCallback("WeaveForge_FightEnd", function(fightRecord)
        lastFight = fightRecord
        if settings.fightSummary.autoShow then
            self:ShowFight(fightRecord)
        end
    end)
end

---------------------------------------------------------------------------
-- Display a fight record
---------------------------------------------------------------------------
function FightSummaryPanel:ShowFight(fightRecord)
    if not panel or not fightRecord then return end
    lastFight = fightRecord

    -- Update header
    local duration = WF.HistoryManager:FormatDuration(fightRecord.duration)
    local headerText = ""
    if fightRecord.target and fightRecord.target ~= "" then
        headerText = headerText .. string.format(L.FIGHT_SUMMARY_TARGET, fightRecord.target) .. "\n"
    end
    headerText = headerText .. string.format(L.FIGHT_SUMMARY_ZONE, fightRecord.zone or "Unknown")
    headerText = headerText .. "  |  " .. string.format(L.FIGHT_SUMMARY_DURATION, duration)
    headerLabel:SetText(headerText)

    -- Update summary stats
    local accuracy = (fightRecord.overallAccuracy or 0) * 100
    local statsText = string.format("%.1f%%  |  ", accuracy)
    statsText = statsText .. string.format(L.FIGHT_SUMMARY_LA_PER_SEC, fightRecord.laPerSecond or 0) .. "  |  "
    statsText = statsText .. string.format(L.FIGHT_SUMMARY_TOTAL_LA, fightRecord.totalLAs or 0) .. "  |  "
    statsText = statsText .. string.format(L.FIGHT_SUMMARY_LONGEST_STREAK, fightRecord.longestStreak or 0)
    statsLabel:SetText(statsText)

    -- Build skill rows sorted by worst accuracy
    self:PopulateSkillRows(fightRecord.skillBreakdown)

    -- Show panel
    panel:SetHidden(false)
    isShowing = true
end

---------------------------------------------------------------------------
-- Populate skill breakdown rows
---------------------------------------------------------------------------
function FightSummaryPanel:PopulateSkillRows(skillBreakdown)
    -- Clear existing rows
    for _, row in ipairs(skillRows) do
        row:SetHidden(true)
    end

    if not skillBreakdown then return end

    -- Convert to sortable array
    local skills = {}
    for abilityId, data in pairs(skillBreakdown) do
        local accuracy = 0
        if data.casts > 0 then
            accuracy = data.weaved / data.casts
        end
        skills[#skills + 1] = {
            abilityId = abilityId,
            name      = data.name,
            icon      = data.icon,
            casts     = data.casts,
            weaved    = data.weaved,
            missed    = data.missed,
            accuracy  = accuracy,
            avgGapMs  = data.avgGapMs or 0,
        }
    end

    -- Sort by worst accuracy first
    table.sort(skills, function(a, b)
        return a.accuracy < b.accuracy
    end)

    -- Create/update rows
    for i, skill in ipairs(skills) do
        local row = self:GetOrCreateRow(i)
        self:UpdateRow(row, skill, i)
        row:SetHidden(false)
    end

    -- Update scroll child height
    if scrollChild then
        scrollChild:SetHeight(#skills * ROW_HEIGHT + 10)
    end
end

---------------------------------------------------------------------------
-- Get or create a row control
---------------------------------------------------------------------------
function FightSummaryPanel:GetOrCreateRow(index)
    if skillRows[index] then return skillRows[index] end

    local row = WINDOW_MANAGER:CreateControl("WeaveForge_SkillRow" .. index, scrollChild, CT_CONTROL)
    row:SetDimensions(PANEL_WIDTH - 24, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (index - 1) * ROW_HEIGHT)

    -- Alternate row background
    if index % 2 == 0 then
        local rowBg = WINDOW_MANAGER:CreateControl("$(parent)BG", row, CT_BACKDROP)
        rowBg:SetAnchorFill(row)
        rowBg:SetCenterColor(0.15, 0.15, 0.15, 0.3)
        rowBg:SetEdgeColor(0, 0, 0, 0)
    end

    -- Skill icon
    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", row, CT_TEXTURE)
    icon:SetAnchor(LEFT, row, LEFT, 4, 0)
    icon:SetDimensions(20, 20)
    row.icon = icon

    -- Skill name
    local name = WINDOW_MANAGER:CreateControl("$(parent)Name", row, CT_LABEL)
    name:SetAnchor(LEFT, icon, RIGHT, 4, 0)
    name:SetWidth(140)
    name:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
    name:SetColor(0.9, 0.9, 0.9, 1)
    row.nameLabel = name

    -- Casts
    local casts = WINDOW_MANAGER:CreateControl("$(parent)Casts", row, CT_LABEL)
    casts:SetAnchor(LEFT, row, LEFT, 172, 0)
    casts:SetWidth(50)
    casts:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
    casts:SetColor(0.85, 0.85, 0.85, 1)
    casts:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.castsLabel = casts

    -- Weaved
    local weaved = WINDOW_MANAGER:CreateControl("$(parent)Weaved", row, CT_LABEL)
    weaved:SetAnchor(LEFT, row, LEFT, 227, 0)
    weaved:SetWidth(55)
    weaved:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
    weaved:SetColor(0.4, 0.9, 0.4, 1)
    weaved:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.weavedLabel = weaved

    -- Missed
    local missed = WINDOW_MANAGER:CreateControl("$(parent)Missed", row, CT_LABEL)
    missed:SetAnchor(LEFT, row, LEFT, 287, 0)
    missed:SetWidth(55)
    missed:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
    missed:SetColor(0.9, 0.4, 0.4, 1)
    missed:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.missedLabel = missed

    -- Accuracy
    local acc = WINDOW_MANAGER:CreateControl("$(parent)Acc", row, CT_LABEL)
    acc:SetAnchor(LEFT, row, LEFT, 347, 0)
    acc:SetWidth(65)
    acc:SetFont("$(BOLD_FONT)|13|soft-shadow-thin")
    acc:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.accLabel = acc

    -- Avg Gap
    local gap = WINDOW_MANAGER:CreateControl("$(parent)Gap", row, CT_LABEL)
    gap:SetAnchor(LEFT, row, LEFT, 422, 0)
    gap:SetWidth(75)
    gap:SetFont("$(MEDIUM_FONT)|13|soft-shadow-thin")
    gap:SetColor(0.7, 0.7, 0.7, 1)
    gap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.gapLabel = gap

    skillRows[index] = row
    return row
end

---------------------------------------------------------------------------
-- Update a row with skill data
---------------------------------------------------------------------------
function FightSummaryPanel:UpdateRow(row, skill, index)
    if skill.icon and skill.icon ~= "" then
        row.icon:SetTexture(skill.icon)
        row.icon:SetHidden(false)
    else
        row.icon:SetHidden(true)
    end

    row.nameLabel:SetText(skill.name or "Unknown")
    row.castsLabel:SetText(tostring(skill.casts))
    row.weavedLabel:SetText(tostring(skill.weaved))
    row.missedLabel:SetText(tostring(skill.missed))

    -- Color accuracy based on value
    local accPct = skill.accuracy * 100
    row.accLabel:SetText(string.format("%.0f%%", accPct))
    if accPct >= 90 then
        row.accLabel:SetColor(0.4, 0.9, 0.4, 1)   -- green
    elseif accPct >= 70 then
        row.accLabel:SetColor(0.9, 0.9, 0.2, 1)   -- yellow
    else
        row.accLabel:SetColor(0.9, 0.4, 0.4, 1)   -- red
    end

    row.gapLabel:SetText(tostring(skill.avgGapMs))
end

---------------------------------------------------------------------------
-- Pin the current fight
---------------------------------------------------------------------------
function FightSummaryPanel:PinCurrentFight()
    if not lastFight then return end

    -- Find this fight in history and pin it
    local history = WF.HistoryManager:GetFightHistory()
    for i, fight in ipairs(history) do
        if fight.timestamp == lastFight.timestamp then
            WF.HistoryManager:PinFight(i)
            if CHAT_SYSTEM then
                CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.CHAT_FIGHT_SAVED)
            end
            return
        end
    end

    -- If not found in history, pin directly
    table.insert(WF.HistoryManager.characterSV.pinnedFights, 1, lastFight)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(L.CHAT_PREFIX .. L.CHAT_FIGHT_SAVED)
    end
end

---------------------------------------------------------------------------
-- Show / Hide / Toggle
---------------------------------------------------------------------------
function FightSummaryPanel:Show()
    if not panel then return end
    -- Show last fight if available
    local fight = lastFight or WF.HistoryManager:GetLastFight()
    if fight then
        self:ShowFight(fight)
    else
        panel:SetHidden(false)
        isShowing = true
        headerLabel:SetText(L.HISTORY_NO_DATA)
        statsLabel:SetText("")
    end
end

function FightSummaryPanel:Hide()
    if not panel then return end
    panel:SetHidden(true)
    isShowing = false
end

function FightSummaryPanel:Toggle()
    if isShowing then
        self:Hide()
    else
        self:Show()
    end
end

function FightSummaryPanel:IsShowing()
    return isShowing
end
