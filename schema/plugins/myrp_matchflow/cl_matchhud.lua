-- MYRP Match HUD v2.0
-- Compact top-centre glass scoreboard with elapsed match time and faction kills.

if not CLIENT then return end

local MATCH_PANEL_NAME = "myrpMatchflowHUD"
local matchActive = false
local elapsedAtSync = 0
local lastSyncTime = CurTime()
local factionKills = {
    combine = 0,
    resistance = 0
}

local factionAnamnecites = {
    combine = 0,
    resistance = 0
}

local BLUE = Color(105, 181, 232)
local BLUE_BRIGHT = Color(154, 205, 242)
local ORANGE = Color(217, 154, 114)
local ORANGE_BRIGHT = Color(233, 177, 139)
local TEXT = Color(239, 245, 250)
local MUTED = Color(153, 171, 188)
local ANAMNECITES = Color(239, 198, 77)

local function CreateMatchHUDFonts()
    local scale = math.min(ScrW() / 1920, ScrH() / 1080)
    scale = math.Clamp(scale, 0.78, 1.15)

    surface.CreateFont("MYRP_MatchHUDLabel", {
        font = "Arial",
        size = math.floor(12 * scale),
        weight = 800,
        extended = true
    })

    surface.CreateFont("MYRP_MatchHUDScore", {
        font = "Arial",
        size = math.floor(25 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_MatchHUDTime", {
        font = "Arial",
        size = math.floor(24 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_MatchHUDSmall", {
        font = "Arial",
        size = math.floor(10 * scale),
        weight = 600,
        extended = true
    })

    surface.CreateFont("MYRP_MatchHUDAnamnecites", {
        font = "Arial",
        size = math.floor(10 * scale),
        weight = 800,
        extended = true
    })
end

CreateMatchHUDFonts()

local function FormatMatchTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remaining = seconds % 60

    return string.format("%02d:%02d:%02d", hours, minutes, remaining)
end

local function GetCurrentElapsed()
    if not matchActive then
        return 0
    end

    return elapsedAtSync + math.max(0, math.floor(CurTime() - lastSyncTime))
end

local function LayoutMatchPanel(panel)
    if not IsValid(panel) then return end

    local width = math.min(760, ScrW() - 28)
    local height = 76

    panel:SetSize(width, height)
    panel:SetPos(math.floor((ScrW() - width) * 0.5), 18)
end

local matchPanel = vgui.Create("DPanel")
matchPanel:SetName("MYRPMatchFlowHUD")
matchPanel:SetMouseInputEnabled(false)
matchPanel:SetKeyboardInputEnabled(false)
matchPanel:SetVisible(false)
matchPanel:SetZPos(32740)
LayoutMatchPanel(matchPanel)

matchPanel.Paint = function(self, width, height)
    -- One small blur surface for the entire match strip; avoid separate blur
    -- passes for the individual score/time sections.
    if ix and ix.util and ix.util.DrawBlur then
        ix.util.DrawBlur(self, 2, nil, 95)
    end

    draw.RoundedBox(9, 0, 0, width, height, Color(7, 13, 21, 214))
    draw.RoundedBox(8, 1, 1, width - 2, height - 2, Color(13, 23, 34, 190))

    -- Restrained faction-tinted reflections along the top edge.
    surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 125)
    surface.DrawRect(12, 1, math.floor((width - 24) * 0.34), 2)
    surface.SetDrawColor(ORANGE.r, ORANGE.g, ORANGE.b, 125)
    surface.DrawRect(width - 12 - math.floor((width - 24) * 0.34), 1,
        math.floor((width - 24) * 0.34), 2)

    surface.SetDrawColor(220, 235, 248, 34)
    surface.DrawOutlinedRect(0, 0, width, height, 1)

    -- The panel expands symmetrically. Offset the existing faction elements
    -- so their absolute screen positions remain unchanged.
    local expansion = math.max(0, width - 660)
    local sideInset = math.floor(expansion * 0.5)
    local sideWidth = width > 660 and (174 + sideInset) or math.floor(width * 0.265)
    local centerX = math.floor(width * 0.5)
    local separatorColor = Color(210, 226, 240, 35)

    surface.SetDrawColor(separatorColor)
    surface.DrawRect(sideWidth, 13, 1, height - 26)
    surface.DrawRect(width - sideWidth, 13, 1, height - 26)

    -- Combine score. Its original screen position is preserved.
    local combineX = 22 + sideInset
    local resistanceRight = width - 22 - sideInset

    draw.SimpleText("COMBINE", "MYRP_MatchHUDLabel", combineX, 22,
        BLUE_BRIGHT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(factionKills.combine), "MYRP_MatchHUDScore", combineX, 51,
        TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("KILLS", "MYRP_MatchHUDSmall", combineX + 40, 53,
        MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Display only the difference between faction totals.
    -- Hide the indicator when totals are equal or both are zero.
    local combineAnamnecites = tonumber(factionAnamnecites.combine) or 0
    local resistanceAnamnecites = tonumber(factionAnamnecites.resistance) or 0
    local anamnecitesAdvantage = math.abs(combineAnamnecites - resistanceAnamnecites)

    if anamnecitesAdvantage > 0 then
        if combineAnamnecites > resistanceAnamnecites then
            surface.SetFont("MYRP_MatchHUDLabel")
            local combineLabelWidth = surface.GetTextSize("COMBINE")

            draw.SimpleText("an: " .. tostring(anamnecitesAdvantage),
                "MYRP_MatchHUDAnamnecites",
                combineX + combineLabelWidth + 9, 22,
                ANAMNECITES, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        elseif resistanceAnamnecites > combineAnamnecites and width >= 720 then
            -- Place the value immediately after RESISTANCE without moving its heading.
            surface.SetFont("MYRP_MatchHUDLabel")
            local resistanceLabelWidth = surface.GetTextSize("RESISTANCE")

            draw.SimpleText("an: " .. tostring(anamnecitesAdvantage),
                "MYRP_MatchHUDAnamnecites",
                resistanceRight + 9, 22,
                ANAMNECITES, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Match clock.
    draw.SimpleText("MATCH ELAPSED", "MYRP_MatchHUDSmall", centerX, 19,
        MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(FormatMatchTime(GetCurrentElapsed()), "MYRP_MatchHUDTime", centerX, 48,
        TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Resistance score and heading retain their original screen positions.
    draw.SimpleText("RESISTANCE", "MYRP_MatchHUDLabel", resistanceRight, 22,
        ORANGE_BRIGHT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(factionKills.resistance), "MYRP_MatchHUDScore", resistanceRight, 51,
        TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText("KILLS", "MYRP_MatchHUDSmall", resistanceRight - 40, 53,
        MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

net.Receive("myrpMatchflowMatchState", function()
    matchActive = net.ReadBool()
    elapsedAtSync = net.ReadUInt(32)
    factionKills.combine = net.ReadUInt(32)
    factionKills.resistance = net.ReadUInt(32)
    factionAnamnecites.combine = net.ReadInt(32)
    factionAnamnecites.resistance = net.ReadInt(32)
    lastSyncTime = CurTime()

    if IsValid(matchPanel) then
        matchPanel:SetVisible(matchActive)
        LayoutMatchPanel(matchPanel)
    end

    MsgC(Color(110, 190, 225), "[MYRP:MATCHHUD][CLIENT][INFO] Match state received: active="
        .. tostring(matchActive) .. "; elapsed=" .. tostring(elapsedAtSync)
        .. "; combine=" .. tostring(factionKills.combine)
        .. "; resistance=" .. tostring(factionKills.resistance) .. "\n")
end)

hook.Add("OnScreenSizeChanged", "MYRP.MatchHUD.ScreenSize", function()
    CreateMatchHUDFonts()
    LayoutMatchPanel(matchPanel)
end)

concommand.Add("myrp_matchhud_status", function()
    MsgC(Color(110, 190, 225), "[MYRP:MATCHHUD][CLIENT][STATUS] active="
        .. tostring(matchActive)
        .. "; elapsed=" .. FormatMatchTime(GetCurrentElapsed())
        .. "; combineKills=" .. tostring(factionKills.combine)
        .. "; resistanceKills=" .. tostring(factionKills.resistance)
        .. "; combineAnamnecites=" .. tostring(factionAnamnecites.combine)
        .. "; resistanceAnamnecites=" .. tostring(factionAnamnecites.resistance) .. "\n")
end)

MsgC(Color(110, 190, 225), "[MYRP:MATCHHUD][CLIENT][INFO] Glass match scoreboard loaded.\n")
