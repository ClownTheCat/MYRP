-- MYRP UI Core v1.0 — client helpers shared by faction menu, scoreboard, HUD and inventory.

MYRP = MYRP or {}
MYRP.UI = MYRP.UI or {}

local UI = MYRP.UI
UI.Version = "1.0"
UI.DebugEnabled = false
UI.LastSoundAt = UI.LastSoundAt or {}

local PREFIX = "[MYRP:UI_CORE][CLIENT]"
local function Log(level, message)
    local palette = {
        INFO = Color(90, 190, 140),
        WARN = Color(235, 175, 75),
        ERROR = Color(235, 90, 80),
        DEBUG = Color(115, 170, 220)
    }

    MsgC(palette[level] or color_white, PREFIX .. "[" .. tostring(level) .. "] " .. tostring(message) .. "\n")
end

local THEMES = {
    combine = {
        id = "combine",
        name = "COMBINE",
        accent = Color(91, 164, 225),
        accentBright = Color(139, 198, 245),
        accentDim = Color(47, 91, 128),
        glow = Color(75, 155, 225),
        panel = Color(9, 19, 30, 198),
        panelInner = Color(15, 29, 43, 170),
        panelSoft = Color(20, 43, 63, 142),
        border = Color(89, 145, 188, 105),
        muted = Color(145, 171, 193),
        text = Color(229, 238, 246)
    },
    resistance = {
        id = "resistance",
        name = "RESISTANCE",
        accent = Color(214, 135, 91),
        accentBright = Color(239, 169, 121),
        accentDim = Color(126, 75, 49),
        glow = Color(218, 127, 78),
        panel = Color(22, 16, 13, 198),
        panelInner = Color(37, 26, 20, 170),
        panelSoft = Color(62, 39, 27, 142),
        border = Color(174, 111, 75, 105),
        muted = Color(188, 155, 132),
        text = Color(241, 232, 224)
    },
    neutral = {
        id = "neutral",
        name = "UNASSIGNED",
        accent = Color(135, 158, 180),
        accentBright = Color(180, 198, 215),
        accentDim = Color(79, 99, 120),
        glow = Color(115, 150, 180),
        panel = Color(8, 15, 22, 198),
        panelInner = Color(15, 25, 36, 170),
        panelSoft = Color(24, 37, 51, 142),
        border = Color(100, 128, 151, 105),
        muted = Color(146, 164, 181),
        text = Color(229, 236, 242)
    }
}

local function ResolveFactionID(client)
    if (!IsValid(client)) then return "neutral" end

    if (client.GetCharacter) then
        local character = client:GetCharacter()
        if (character and character.GetFaction and ix and ix.faction and ix.faction.indices) then
            local factionValue = character:GetFaction()
            local faction = ix.faction.indices[tonumber(factionValue) or factionValue]
            local uniqueID = faction and string.lower(tostring(faction.uniqueID or "")) or ""
            if (THEMES[uniqueID]) then return uniqueID end
        end
    end

    if (ix and ix.faction and ix.faction.indices) then
        local faction = ix.faction.indices[client:Team()]
        local uniqueID = faction and string.lower(tostring(faction.uniqueID or "")) or ""
        if (THEMES[uniqueID]) then return uniqueID end
    end

    return "neutral"
end

function UI.GetFactionID(client, overrideID)
    if (isstring(overrideID) and THEMES[string.lower(overrideID)]) then
        return string.lower(overrideID)
    end
    return ResolveFactionID(client or LocalPlayer())
end

function UI.GetTheme(client, overrideID)
    local id = UI.GetFactionID(client, overrideID)
    return THEMES[id] or THEMES.neutral
end

function UI.GetAccent(client, overrideID)
    return UI.GetTheme(client, overrideID).accent
end

-- Source / Half-Life 2 UI sounds; all are part of the standard game content.
local SOUND_MAP = {
    open = "buttons/combine_button1.wav",
    close = "buttons/combine_button2.wav",
    hover = "ui/buttonrollover.wav",
    click = "buttons/button15.wav",
    select = "buttons/button15.wav",
    confirm = "buttons/combine_button5.wav",
    denied = "buttons/combine_button_locked.wav"
}

function UI.PlaySound(kind, volume, pitch)
    local path = SOUND_MAP[kind] or SOUND_MAP.click
    local now = RealTime()
    local last = UI.LastSoundAt[kind] or 0
    local cooldown = kind == "hover" and 0.075 or 0.035

    if (now - last < cooldown) then return false end
    UI.LastSoundAt[kind] = now

    if (surface and surface.PlaySound) then
        surface.PlaySound(path)
        return true
    end

    return false
end

function UI.AnimateIn(panel, duration, direction, offset)
    if (!IsValid(panel)) then return false end

    duration = duration or 0.22
    offset = offset or 14
    local x, y = panel:GetPos()
    local targetX, targetY = x, y

    if (direction == "left") then targetX = x - offset
    elseif (direction == "right") then targetX = x + offset
    elseif (direction == "up") then targetY = y + offset
    elseif (direction == "down") then targetY = y - offset end

    panel:SetAlpha(0)
    panel:SetPos(targetX, targetY)
    panel:AlphaTo(255, duration, 0)
    panel:MoveTo(x, y, duration, 0, 0.5)
    UI.PlaySound("open")
    return true
end

function UI.AnimateOut(panel, duration, direction, callback, offset)
    if (!IsValid(panel)) then
        if (callback) then callback() end
        return false
    end

    duration = duration or 0.16
    offset = offset or 12
    local x, y = panel:GetPos()
    local targetX, targetY = x, y

    if (direction == "left") then targetX = x - offset
    elseif (direction == "right") then targetX = x + offset
    elseif (direction == "up") then targetY = y - offset
    elseif (direction == "down") then targetY = y + offset end

    panel:SetMouseInputEnabled(false)
    panel:SetKeyboardInputEnabled(false)
    panel:AlphaTo(0, duration, 0, function()
        if (callback) then callback() end
    end)
    panel:MoveTo(targetX, targetY, duration, 0, 0.5)
    return true
end

function UI.DrawGlowPanel(x, y, width, height, theme, alpha, radius)
    theme = theme or THEMES.neutral
    alpha = alpha or 30
    radius = radius or 10

    local accent = theme.glow or theme.accent
    draw.RoundedBox(radius + 2, x - 3, y - 3, width + 6, height + 6,
        Color(accent.r, accent.g, accent.b, math.floor(alpha * 0.22)))
    draw.RoundedBox(radius, x, y, width, height,
        Color(theme.panel.r, theme.panel.g, theme.panel.b, theme.panel.a))
    draw.RoundedBox(radius, x + 1, y + 1, width - 2, height - 2,
        Color(theme.panelInner.r, theme.panelInner.g, theme.panelInner.b, theme.panelInner.a))
    draw.RoundedBox(radius, x, y, width, height,
        Color(accent.r, accent.g, accent.b, math.Clamp(alpha, 0, 255)))
    draw.RoundedBox(math.max(1, radius - 1), x + 1, y + 1, width - 2, height - 2,
        Color(theme.panel.r, theme.panel.g, theme.panel.b, theme.panel.a))
end

function UI.GetStatus()
    local client = LocalPlayer()
    local factionID = UI.GetFactionID(client)
    local theme = UI.GetTheme(client)
    Log("INFO", "STATUS version=" .. UI.Version
        .. ", resolution=" .. ScrW() .. "x" .. ScrH()
        .. ", faction=" .. factionID
        .. ", accent=" .. tostring(theme.accent))
end

concommand.Add("myrp_ui_core_status", UI.GetStatus)
concommand.Add("myrp_ui_core_debug", function(_, _, args)
    UI.DebugEnabled = args[1] == "1" or args[1] == "on" or args[1] == "true"
    Log("INFO", "Debug=" .. tostring(UI.DebugEnabled))
end)

Log("INFO", "MYRP UI Core v" .. UI.Version .. " loaded; themes=combine/resistance/neutral; animations and Source audio ready")
