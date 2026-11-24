MYRPThroneUI = MYRPThroneUI or {}

local UI = MYRPThroneUI

if UI._initialized then
    return
end

UI._initialized = true

local WIDTH = 928
local HEIGHT = 376

local ACCENTS = {
    combine = Color(90, 170, 255, 255),
    resistance = Color(220, 148, 90, 255)
}

local FACTIONS = {
    {
        id = "combine",
        class = "myrp_throne_combine",
        title = "COMBINE",
        accent = ACCENTS.combine
    },
    {
        id = "resistance",
        class = "myrp_throne_resistance",
        title = "RESISTANCE",
        accent = ACCENTS.resistance
    }
}

surface.CreateFont("MYRP_Throne_RT_Title", {
    font = "Tahoma",
    size = 58,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_Throne_RT_Meta", {
    font = "Tahoma",
    size = 26,
    weight = 700,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_Throne_RT_Number", {
    font = "Tahoma",
    size = 52,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_Throne_RT_Percent", {
    font = "Tahoma",
    size = 48,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_Throne_RT_Status", {
    font = "Tahoma",
    size = 25,
    weight = 800,
    antialias = true,
    extended = true
})

local TARGETS = {
    combine = GetRenderTarget("myrp_throne_combine_panel_v3", WIDTH, HEIGHT),
    resistance = GetRenderTarget("myrp_throne_resistance_panel_v3", WIDTH, HEIGHT)
}

local MATERIALS = {
    combine = CreateMaterial(
        "myrp_throne_combine_panel_material_v3",
        "UnlitGeneric",
        {
            ["$basetexture"] = TARGETS.combine:GetName(),
            ["$vertexcolor"] = "1",
            ["$vertexalpha"] = "1",
            ["$translucent"] = "1",
            ["$nocull"] = "1"
        }
    ),

    resistance = CreateMaterial(
        "myrp_throne_resistance_panel_material_v3",
        "UnlitGeneric",
        {
            ["$basetexture"] = TARGETS.resistance:GetName(),
            ["$vertexcolor"] = "1",
            ["$vertexalpha"] = "1",
            ["$translucent"] = "1",
            ["$nocull"] = "1"
        }
    )
}

UI._debug = {
    hudUpdates = 0,
    worldDrawCalls = 0,
    lastFaction = "none",
    lastHealth = 0
}

local ANIMATION = {
    combine = {},
    resistance = {}
}

local function FormatNumber(value)
    local number = tostring(math.max(0, math.floor(tonumber(value) or 0)))
    local result = {}

    while #number > 3 do
        table.insert(result, 1, string.sub(number, -3))
        number = string.sub(number, 1, -4)
    end

    table.insert(result, 1, number)

    return table.concat(result, " ")
end

local function DrawText(text, font, x, y, color, align)
    draw.SimpleTextOutlined(
        tostring(text or ""),
        font,
        x,
        y,
        color,
        align or TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER,
        2,
        Color(0, 0, 0, 255)
    )
end

local function GetStatus(fraction)
    if fraction <= 0 then
        return "SIGNAL LOST", Color(255, 75, 82)
    elseif fraction <= 0.20 then
        return "CRITICAL DAMAGE", Color(255, 85, 85)
    elseif fraction <= 0.50 then
        return "SIGNAL UNSTABLE", Color(255, 180, 90)
    end

    return "SIGNAL STABLE", Color(122, 219, 170)
end

local function RenderFactionPanel(faction, entity)
    if not IsValid(entity) then
        return
    end

    local currentHealth = math.Clamp(
        entity:GetNWInt("myrpThroneHealth", 20000),
        0,
        20000
    )

    local maxHealth = math.max(
        1,
        entity:GetNWInt("myrpThroneMaxHealth", 20000)
    )

    local fraction = math.Clamp(currentHealth / maxHealth, 0, 1)
    local accent = faction.accent
    local state = ANIMATION[faction.id]

    -- Detect damage for the short impact animation.
    if state.lastHealth ~= nil and currentHealth < state.lastHealth then
        state.hitUntil = CurTime() + 0.55
    end

    state.lastHealth = currentHealth

    -- Smooth the displayed health.
    if state.displayHealth == nil then
        state.displayHealth = currentHealth
    end

    state.displayHealth = Lerp(
        math.Clamp(FrameTime() * 10, 0, 1),
        state.displayHealth,
        currentHealth
    )

    local displayedHealth = math.Clamp(
        state.displayHealth,
        0,
        maxHealth
    )

    local displayedFraction = displayedHealth / maxHealth
    local percentage = math.floor(displayedFraction * 100 + 0.5)

    local healthColor = accent

    if fraction <= 0.20 then
        healthColor = Color(255, 75, 82)
    elseif fraction <= 0.50 then
        healthColor = Color(255, 180, 90)
    end

    local status, statusColor = GetStatus(fraction)

    -- Render all typography and graphics in a normal 2D context.
    local renderTarget = TARGETS[faction.id]

    render.PushRenderTarget(renderTarget)
    render.Clear(7, 12, 20, 255, true, true)

    cam.Start2D()

        -- Dark glass background.
        draw.RoundedBox(
            24,
            0,
            0,
            WIDTH,
            HEIGHT,
            Color(7, 12, 20, 250)
        )

        -- Main faction accent.
        draw.RoundedBox(
            5,
            0,
            0,
            WIDTH,
            10,
            accent
        )

        -- Inner frame.
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawOutlinedRect(3, 3, WIDTH - 6, HEIGHT - 6, 2)

        -- Technical header.
        draw.RoundedBox(
            3,
            60,
            39,
            48,
            5,
            accent
        )

        DrawText(
            "MYRP  /  STRATEGIC NETWORK",
            "MYRP_Throne_RT_Meta",
            122,
            43,
            Color(157, 174, 194)
        )

        -- Faction badge.
        draw.RoundedBox(
            9,
            700,
            23,
            168,
            48,
            Color(accent.r, accent.g, accent.b, 36)
        )

        surface.SetDrawColor(accent.r, accent.g, accent.b, 170)
        surface.DrawOutlinedRect(700, 23, 168, 48, 2)

        DrawText(
            faction.title,
            "MYRP_Throne_RT_Meta",
            784,
            47,
            accent,
            TEXT_ALIGN_CENTER
        )

        -- Main title.
        DrawText(
            "РАДИО-ЛОКАТОР",
            "MYRP_Throne_RT_Title",
            60,
            119,
            Color(242, 246, 252)
        )

        DrawText(
            "СОСТОЯНИЕ СИСТЕМЫ",
            "MYRP_Throne_RT_Meta",
            60,
            187,
            Color(141, 159, 181)
        )

        -- Health number and percentage.
        DrawText(
            FormatNumber(displayedHealth) .. " / " .. FormatNumber(maxHealth),
            "MYRP_Throne_RT_Number",
            60,
            242,
            Color(244, 247, 252)
        )

        DrawText(
            percentage .. "%",
            "MYRP_Throne_RT_Percent",
            868,
            242,
            healthColor,
            TEXT_ALIGN_RIGHT
        )

        -- Health bar background.
        draw.RoundedBox(
            12,
            60,
            287,
            808,
            25,
            Color(25, 35, 48, 255)
        )

        -- Animated health fill.
        local fillWidth = 808 * displayedFraction

        if fillWidth > 1 then
            draw.RoundedBox(
                11,
                60,
                287,
                fillWidth,
                25,
                healthColor
            )

            draw.RoundedBox(
                4,
                60,
                290,
                fillWidth,
                5,
                Color(255, 255, 255, 38)
            )
        end

        -- Signal status.
        local blink = 0.75 + math.abs(math.sin(CurTime() * 2.5)) * 0.25

        draw.RoundedBox(
            5,
            60,
            342,
            12,
            12,
            Color(
                statusColor.r,
                statusColor.g,
                statusColor.b,
                math.floor(255 * blink)
            )
        )

        DrawText(
            status,
            "MYRP_Throne_RT_Status",
            84,
            348,
            statusColor
        )

        DrawText(
            "LIVE  /  ENCRYPTED LINK",
            "MYRP_Throne_RT_Meta",
            868,
            348,
            Color(112, 133, 157),
            TEXT_ALIGN_RIGHT
        )

        -- Impact highlight.
        if (state.hitUntil or 0) > CurTime() then
            local pulse = math.Clamp(
                (state.hitUntil - CurTime()) / 0.55,
                0,
                1
            )

            surface.SetDrawColor(255, 255, 255, math.floor(180 * pulse))
            surface.DrawOutlinedRect(5, 5, WIDTH - 10, HEIGHT - 10, 4)
        end

    cam.End2D()

    render.PopRenderTarget()

    UI._debug.hudUpdates = UI._debug.hudUpdates + 1
    UI._debug.lastFaction = faction.id
    UI._debug.lastHealth = currentHealth
end

-- Update both render targets from a normal HUD 2D render context.
hook.Remove("HUDPaint", "MYRP_Thrones_UpdateRenderTargets")

hook.Add("HUDPaint", "MYRP_Thrones_UpdateRenderTargets", function()
    for _, faction in ipairs(FACTIONS) do
        local entities = ents.FindByClass(faction.class)
        local entity = entities[1]

        if IsValid(entity) then
            RenderFactionPanel(faction, entity)
        end
    end
end)

function UI.Draw(entity)
    if not IsValid(entity) then
        return
    end

    local localPlayer = LocalPlayer()

    if not IsValid(localPlayer) then
        return
    end

    local faction = entity.Faction

    if faction ~= "combine" and faction ~= "resistance" then
        return
    end

    local modelTop = entity:OBBMaxs().z
    local position = entity:GetPos() + Vector(0, 0, modelTop + 22)

    if EyePos():DistToSqr(position) > (1600 * 1600) then
        return
    end

    local direction = EyePos() - position
    local material = MATERIALS[faction]

    -- This is a true 3D draw operation, not a 2D surface operation.
    render.SetMaterial(material)

    render.DrawQuadEasy(
        position,
        direction:GetNormalized(),
        51.04,
        20.68,
        color_white,
        180
    )
    UI._debug.worldDrawCalls = UI._debug.worldDrawCalls + 1
end

-- Draw world-space panels in a dedicated 3D pass.
hook.Remove("PostDrawTranslucentRenderables", "MYRP_Thrones_WorldUI")

hook.Add("PostDrawTranslucentRenderables", "MYRP_Thrones_WorldUI", function(
    bDrawingDepth,
    bDrawingSkybox
)
    if bDrawingDepth or bDrawingSkybox then
        return
    end

    if not UI or not UI.Draw then
        return
    end

    for _, faction in ipairs(FACTIONS) do
        for _, entity in ipairs(ents.FindByClass(faction.class)) do
            if IsValid(entity) then
                UI.Draw(entity)
            end
        end
    end
end)

concommand.Add("myrp_throne_ui_status", function()
    print("========== MYRP THRONE UI RT ==========")
    print("Initialized:", tostring(UI._initialized))
    print("HUD render updates:", UI._debug.hudUpdates)
    print("World draw calls:", UI._debug.worldDrawCalls)

    for _, faction in ipairs(FACTIONS) do
        local rt = TARGETS[faction.id]
        local texture = MATERIALS[faction.id]:GetTexture("$basetexture")

        print(
            faction.id,
            "RT:",
            rt:Width(),
            "x",
            rt:Height(),
            "material:",
            tostring(MATERIALS[faction.id])
        )

        print(
            "Texture:",
            texture and texture:Width() or -1,
            "x",
            texture and texture:Height() or -1
        )

        local entities = ents.FindByClass(faction.class)

        for _, entity in ipairs(entities) do
            print(
                "HP:",
                entity:GetNWInt("myrpThroneHealth", -1),
                "/",
                entity:GetNWInt("myrpThroneMaxHealth", -1)
            )
        end
    end

    print("=======================================")
end)

print("[MYRP:THRONES][UI] Render-target interface loaded.")
-- Temporary Render Target preview for troubleshooting.
UI._rtPreview = false
UI._rtOverlayCalls = 0

hook.Remove("DrawOverlay", "MYRP_Thrones_RTPreview")

hook.Add("DrawOverlay", "MYRP_Thrones_RTPreview", function()
    if not UI._rtPreview then
        return
    end

    UI._rtOverlayCalls = UI._rtOverlayCalls + 1

    draw.RoundedBox(
        12,
        15,
        65,
        980,
        440,
        Color(5, 8, 14, 245)
    )

    draw.SimpleTextOutlined(
        "MYRP THRONE RENDER TARGET DIAGNOSTIC",
        "DermaLarge",
        35,
        78,
        Color(255, 255, 255),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP,
        2,
        Color(0, 0, 0)
    )

    surface.SetDrawColor(255, 255, 255, 255)

    surface.SetMaterial(MATERIALS.combine)
    surface.DrawTexturedRect(35, 135, 464, 188)

    surface.SetMaterial(MATERIALS.resistance)
    surface.DrawTexturedRect(515, 135, 464, 188)

    draw.SimpleText(
        "COMBINE",
        "DermaDefaultBold",
        35,
        330,
        ACCENTS.combine,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )

    draw.SimpleText(
        "RESISTANCE",
        "DermaDefaultBold",
        515,
        330,
        ACCENTS.resistance,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
end)

concommand.Add("myrp_throne_ui_rtpreview", function()
    UI._rtPreview = not UI._rtPreview
    UI._rtOverlayCalls = 0

    print(
        "[MYRP:THRONES][RT] Preview:",
        UI._rtPreview and "ON" or "OFF"
    )
end)

concommand.Add("myrp_throne_ui_rtinfo", function()
    print("========== RENDER TARGET INFO ==========")

    for _, faction in ipairs(FACTIONS) do
        local rt = TARGETS[faction.id]
        local material = MATERIALS[faction.id]
        local texture = material:GetTexture("$basetexture")

        print("Faction:", faction.id)
        print("RT name:", rt:GetName())
        print("RT size:", rt:Width(), "x", rt:Height())
        print("Material:", tostring(material))
        print("Material error:", tostring(material:IsError()))
        print("Base texture:", tostring(texture))
        print("Texture valid:", tostring(texture ~= nil))

        if texture then
            print("Texture size:", texture:Width(), "x", texture:Height())
        end

        print("Translucent flag:", tostring(material:GetInt("$translucent")))
    end

    print("Overlay hook calls:", UI._rtOverlayCalls)
    print("HUD updates:", UI._debug.hudUpdates)
    print("World draw calls:", UI._debug.worldDrawCalls)
    print("========================================")
end)

print("[MYRP:THRONES][RT] Preview diagnostics loaded.")

-- Cinematic victory announcement with smooth fade-in.
surface.CreateFont("MYRP_Throne_Victory_Title", {
    font = "Tahoma",
    size = 76,
    weight = 1000,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_Throne_Victory_Faction", {
    font = "Tahoma",
    size = 58,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_Throne_Victory_Countdown", {
    font = "Tahoma",
    size = 27,
    weight = 700,
    antialias = true,
    extended = true
})

UI._victory = nil

net.Receive("MYRP_Thrones_Reset", function()
    UI._victory = nil
end)

net.Receive("MYRP_Thrones_Victory", function()
    local winnerFaction = net.ReadString()
    local duration = net.ReadUInt(8)

    if winnerFaction ~= "combine" and winnerFaction ~= "resistance" then
        return
    end

    duration = math.Clamp(duration, 1, 60)

    UI._victory = {
        faction = winnerFaction,
        duration = duration,
        startedAt = CurTime(),
        finishTime = CurTime() + duration,
        fadeDuration = 2.2
    }

    print(
        "[MYRP:THRONES][VICTORY] Winner:",
        winnerFaction,
        "| Restart in:",
        duration
    )
end)

hook.Remove("PostDrawHUD", "MYRP_Thrones_VictoryOverlay")

hook.Add("PostDrawHUD", "MYRP_Thrones_VictoryOverlay", function()
    local victory = UI._victory

    if not victory then
        return
    end

    local elapsed = CurTime() - victory.startedAt

    -- Smoothstep easing: no sudden appearance.
    local t = math.Clamp(elapsed / victory.fadeDuration, 0, 1)
    local fade = t * t * (3 - 2 * t)

    if fade <= 0 then
        return
    end

    local remaining = math.max(
        0,
        math.ceil(victory.finishTime - CurTime())
    )

    if remaining <= 0 then
        return
    end

    local function FadedColor(color, multiplier)
        return Color(
            color.r,
            color.g,
            color.b,
            math.floor((color.a or 255) * fade * (multiplier or 1))
        )
    end

    local accent = victory.faction == "combine"
        and Color(90, 170, 255)
        or Color(220, 148, 90)

    local factionName = victory.faction == "combine"
        and "COMBINE"
        or "RESISTANCE"

    local subtitle = victory.faction == "combine"
        and "АЛЬЯНС УСТАНОВИЛ КОНТРОЛЬ"
        or "СОПРОТИВЛЕНИЕ УСТАНОВИЛО КОНТРОЛЬ"

    local centerX = ScrW() * 0.5
    local centerY = ScrH() * 0.5

    -- Background fades in smoothly.
    draw.RoundedBox(
        0,
        0,
        0,
        ScrW(),
        ScrH(),
        Color(3, 7, 14, math.floor(220 * fade))
    )

    local panelWidth = math.min(940, ScrW() - 50)
    local panelHeight = 390

    -- Panel gently moves into its final position.
    local slideOffset = (1 - fade) * 34

    local panelX = centerX - panelWidth * 0.5
    local panelY = centerY - panelHeight * 0.5 + slideOffset

    draw.RoundedBox(
        18,
        panelX,
        panelY,
        panelWidth,
        panelHeight,
        Color(9, 16, 27, math.floor(250 * fade))
    )

    draw.RoundedBox(
        5,
        panelX,
        panelY,
        panelWidth,
        7,
        FadedColor(accent)
    )

    surface.SetDrawColor(
        accent.r,
        accent.g,
        accent.b,
        math.floor(115 * fade)
    )

    surface.DrawOutlinedRect(
        panelX,
        panelY,
        panelWidth,
        panelHeight,
        2
    )

    draw.SimpleTextOutlined(
        "MATCH CONCLUDED",
        "MYRP_Throne_RT_Meta",
        centerX,
        panelY + 65,
        FadedColor(Color(153, 172, 195)),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        2,
        Color(0, 0, 0, math.floor(255 * fade))
    )

    draw.SimpleTextOutlined(
        "ПОБЕДА",
        "MYRP_Throne_Victory_Title",
        centerX,
        panelY + 145,
        FadedColor(Color(245, 248, 255)),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        3,
        Color(0, 0, 0, math.floor(255 * fade))
    )

    draw.SimpleTextOutlined(
        factionName,
        "MYRP_Throne_Victory_Faction",
        centerX,
        panelY + 225,
        FadedColor(accent),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        3,
        Color(0, 0, 0, math.floor(255 * fade))
    )

    draw.SimpleTextOutlined(
        subtitle,
        "MYRP_Throne_RT_Meta",
        centerX,
        panelY + 275,
        FadedColor(Color(185, 199, 216)),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        2,
        Color(0, 0, 0, math.floor(255 * fade))
    )

    draw.SimpleTextOutlined(
        "НОВЫЙ МАТЧ НАЧНЁТСЯ ЧЕРЕЗ " .. remaining .. " СЕК.",
        "MYRP_Throne_Victory_Countdown",
        centerX,
        panelY + 327,
        FadedColor(Color(245, 245, 250)),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        2,
        Color(0, 0, 0, math.floor(255 * fade))
    )

    local barWidth = panelWidth - 120
    local barX = centerX - barWidth * 0.5
    local progress = math.Clamp(
        remaining / victory.duration,
        0,
        1
    )

    draw.RoundedBox(
        8,
        barX,
        panelY + 358,
        barWidth,
        10,
        Color(32, 43, 58, math.floor(255 * fade))
    )

    draw.RoundedBox(
        8,
        barX,
        panelY + 358,
        barWidth * progress,
        10,
        FadedColor(accent)
    )
end)
