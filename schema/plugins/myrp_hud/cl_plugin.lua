-- MYRP Custom HUD v0.3 - faction-tinted translucent HUD with smooth values and fade transitions
-- Client-only. Keeps the current faction selection, scoreboard and inventory
-- plugin untouched. All values are read from live Helix/player state.

local BASE_W, BASE_H = 1920, 1080
local UPDATE_INTERVAL = 0.10
local HUD_HOOK = "MYRP.CustomHUD.Paint"
local DEBUG_PREFIX = "[MYRP:HUD][CLIENT]"

local colors = {
    -- Lower alpha values keep the HUD readable without dominating the scene.
    panel = Color(7, 13, 20, 84),
    panelInner = Color(13, 22, 32, 92),
    border = Color(78, 105, 130, 62),
    text = Color(225, 233, 241, 218),
    muted = Color(135, 153, 170, 172),
    faint = Color(83, 101, 119, 142),
    health = Color(194, 78, 70, 198),
    armor = Color(76, 139, 192, 198),
    stamina = Color(196, 166, 76, 190),
    credits = Color(145, 218, 165, 215),
    anamnecites = Color(232, 199, 82, 215),
    combine = Color(91, 164, 225, 205),
    resistance = Color(214, 135, 91, 205),
    neutral = Color(135, 155, 174, 190)
}

local factionColors = {
    combine = colors.combine,
    resistance = colors.resistance
}

local hudCache = nil
local hudCacheReady = false
local nextUpdate = 0
local lastDebugSignature = ""
local debugEnabled = false

local function Log(level, message)
    local levelColors = {
        INFO = Color(90, 190, 140),
        WARN = Color(235, 175, 75),
        ERROR = Color(235, 90, 80),
        DEBUG = Color(115, 170, 220)
    }

    MsgC(levelColors[level] or color_white,
        DEBUG_PREFIX .. "[" .. tostring(level) .. "] " .. tostring(message) .. "\n")
end

local function SX(value)
    return math.floor(value * ScrW() / BASE_W)
end

local function SY(value)
    return math.floor(value * ScrH() / BASE_H)
end

local function UIResolution()
    return tostring(ScrW()) .. "x" .. tostring(ScrH())
end

local function CreateHUDFonts()
    local scale = math.min(ScrW() / BASE_W, ScrH() / BASE_H)
    scale = math.Clamp(scale, 0.72, 1.35)

    surface.CreateFont("MYRP_HUD_Header", {
        font = "Arial",
        size = math.floor(19 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_HUD_Label", {
        font = "Arial",
        size = math.floor(13 * scale),
        weight = 700,
        extended = true
    })

    surface.CreateFont("MYRP_HUD_Value", {
        font = "Arial",
        size = math.floor(20 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_HUD_Money", {
        font = "Arial",
        size = math.floor(18 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_HUD_Ammo", {
        font = "Arial",
        size = math.floor(30 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_HUD_Small", {
        font = "Arial",
        size = math.floor(11 * scale),
        weight = 600,
        extended = true
    })
end

CreateHUDFonts()

local function GetFactionInfo(client, character)
    local faction = nil

    if (ix and ix.faction and ix.faction.indices) then
        faction = ix.faction.indices[client:Team()]

        if (!faction and character and character.GetFaction) then
            local factionIndex = character:GetFaction()
            faction = ix.faction.indices[tonumber(factionIndex) or factionIndex]
        end
    end

    local uniqueID = faction and string.lower(tostring(faction.uniqueID or "")) or ""
    local displayName = "UNASSIGNED"
    local accent = colors.neutral

    if (uniqueID == "combine") then
        displayName = "COMBINE"
        accent = factionColors.combine
    elseif (uniqueID == "resistance") then
        displayName = "RESISTANCE"
        accent = factionColors.resistance
    elseif (faction and isstring(faction.name)) then
        displayName = string.upper(faction.name)
        if (IsColor and IsColor(faction.color)) then
            accent = faction.color
        end
    end

    -- Use the shared MYRP theme so HUD panels, scoreboard and inventory
    -- all follow the active character's faction accent.
    local ui = MYRP and MYRP.UI
    if (ui and ui.GetTheme) then
        local theme = ui.GetTheme(client, uniqueID)
        if (theme and theme.accent) then
            accent = theme.accent
        end
    end

    return uniqueID, displayName, accent
end

local function GetClassName(character)
    if (!character or !character.GetClass or !ix or !ix.class or !ix.class.Get) then
        return "NO ROLE"
    end

    local classID = character:GetClass()
    local class = ix.class.Get(classID)

    if (class and isstring(class.name) and class.name != "") then
        return string.upper(class.name), class.uniqueID
    end

    return "NO ROLE", tostring(classID or "")
end

local function ReadOptionalNumber(client, character, localKeys, dataKeys)
    if (IsValid(client) and client.GetLocalVar) then
        for _, key in ipairs(localKeys or {}) do
            local value = client:GetLocalVar(key, nil)
            if (value != nil and tonumber(value) != nil) then
                return tonumber(value), "localvar:" .. key
            end
        end
    end

    if (character and character.GetData) then
        for _, key in ipairs(dataKeys or {}) do
            local value = character:GetData(key, nil)
            if (value != nil and tonumber(value) != nil) then
                return tonumber(value), "characterdata:" .. key
            end
        end
    end

    return nil, "not-available"
end

local function GetCurrency(client, character)
    local credits = 0
    local anamnecites = 0

    if (character and character.GetData) then
        credits = tonumber(character:GetData("credits", 0)) or 0
        anamnecites = tonumber(character:GetData("anamnecites", 0)) or 0
    end

    if (IsValid(client) and client.GetLocalVar) then
        local playerCredits = client:GetLocalVar("myrpCredits", nil)
        local playerAnamnecites = client:GetLocalVar("myrpAnamnecites", nil)

        if (playerCredits != nil) then
            credits = tonumber(playerCredits) or credits
        end

        if (playerAnamnecites != nil) then
            anamnecites = tonumber(playerAnamnecites) or anamnecites
        end
    end

    -- Keep the current inventory convention: credits cannot be negative;
    -- anamnecites may be negative because they also represent penalties.
    return math.max(0, math.floor(credits)), math.floor(anamnecites)
end

local function FormatNumber(value)
    value = math.floor(tonumber(value) or 0)

    if (string.Comma) then
        return string.Comma(value)
    end

    return tostring(value)
end

local function GetWeaponInfo(client)
    local weapon = client:GetActiveWeapon()
    if (!IsValid(weapon)) then
        return nil
    end

    local clip = weapon:Clip1()
    if (!isnumber(clip) or clip < 0) then
        return nil
    end

    local ammoType = weapon:GetPrimaryAmmoType()
    local reserve = ammoType and ammoType >= 0 and client:GetAmmoCount(ammoType) or 0
    local weaponName = weapon.PrintName

    if (!isstring(weaponName) or weaponName == "") then
        weaponName = weapon:GetClass()
    elseif (weaponName:sub(1, 1) == "@") then
        weaponName = weaponName:sub(2)
    end

    weaponName = string.upper(tostring(weaponName))

    return {
        name = weaponName,
        clip = math.max(0, clip),
        reserve = math.max(0, tonumber(reserve) or 0)
    }
end

local function BuildHUDState(client)
    if (!IsValid(client) or !client.GetCharacter) then
        return nil, "LocalPlayer unavailable"
    end

    local character = client:GetCharacter()
    if (!character) then
        return nil, "no active character"
    end

    local factionID, factionName, accent = GetFactionInfo(client, character)
    local className, classID = GetClassName(character)
    local maxHealth = math.max(1, tonumber(client:GetMaxHealth()) or 100)
    local health = math.max(0, tonumber(client:Health()) or 0)
    local armor = math.max(0, tonumber(client:Armor()) or 0)
    local stamina, staminaSource = ReadOptionalNumber(client, character, {"stm"}, {"stamina"})
    local hunger, hungerSource = ReadOptionalNumber(client, character, {"myrpHunger", "hunger"}, {"myrpHunger", "hunger"})
    local credits, anamnecites = GetCurrency(client, character)

    if (stamina != nil) then
        stamina = math.Clamp(stamina, 0, 100)
    end

    if (hunger != nil) then
        hunger = math.Clamp(hunger, 0, 100)
    end

    return {
        characterID = character:GetID(),
        playerName = client:Nick(),
        factionID = factionID,
        factionName = factionName,
        classID = classID,
        className = className,
        accent = accent,
        health = health,
        maxHealth = maxHealth,
        armor = armor,
        stamina = stamina,
        staminaSource = staminaSource,
        hunger = hunger,
        hungerSource = hungerSource,
        credits = credits,
        anamnecites = anamnecites,
        weapon = GetWeaponInfo(client),
        alive = client:Alive()
    }
end

local function GetHUDState(force)
    if (!force and hudCacheReady and CurTime() < nextUpdate) then
        return hudCache
    end

    nextUpdate = CurTime() + UPDATE_INTERVAL

    local state, reason = BuildHUDState(LocalPlayer())
    hudCache = state
    hudCacheReady = true

    if (debugEnabled) then
        local signature = state and table.concat({
            tostring(state.characterID), tostring(state.factionID), tostring(state.classID),
            tostring(state.health), tostring(state.armor), tostring(state.stamina),
            tostring(state.hunger), tostring(state.weapon and state.weapon.clip),
            tostring(state.weapon and state.weapon.reserve)
        }, "|") or tostring(reason)

        if (signature != lastDebugSignature) then
            lastDebugSignature = signature
            Log("DEBUG", "HUD state changed: " .. signature)
        end
    end

    return hudCache, reason
end

local hudSmoothValues = {}

local function SmoothHUDValue(key, target, speed)
    target = tonumber(target) or 0
    local current = hudSmoothValues[key]
    if (current == nil) then
        hudSmoothValues[key] = target
        return target
    end

    local blend = 1 - math.exp(-FrameTime() * (speed or 10))
    current = Lerp(blend, current, target)
    hudSmoothValues[key] = current
    return current
end

local function DrawPanel(x, y, width, height, accent)
    local glow = Color(accent.r, accent.g, accent.b, 18)
    local edge = Color(accent.r, accent.g, accent.b, 58)

    draw.RoundedBox(10, x - SX(2), y - SY(2), width + SX(4), height + SY(4), glow)
    draw.RoundedBox(9, x, y, width, height, colors.panel)
    draw.RoundedBox(8, x + 1, y + 1, width - 2, height - 2, colors.panelInner)
    surface.SetDrawColor(edge)
    surface.DrawOutlinedRect(x, y, width, height, 1)
    draw.RoundedBox(3, x + SX(1), y + SY(2), SX(3), height - SY(4),
        Color(accent.r, accent.g, accent.b, 118))
    draw.RoundedBox(2, x + SX(8), y + SY(2), width - SX(16), SY(1),
        Color(accent.r, accent.g, accent.b, 28))
end

local function DrawBar(label, value, maximum, x, y, width, accent)
    value = SmoothHUDValue("bar_" .. tostring(label), value, 11)
    local fraction = math.Clamp((tonumber(value) or 0) / math.max(1, tonumber(maximum) or 1), 0, 1)
    local labelWidth = SX(39)
    local valueWidth = SX(42)
    local barX = x + labelWidth
    local barWidth = math.max(SX(40), width - labelWidth - valueWidth - SX(8))
    local barY = y + SY(5)
    local barHeight = SY(9)

    draw.SimpleText(label, "MYRP_HUD_Label", x, y + SY(9), colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.RoundedBox(3, barX, barY, barWidth, barHeight, Color(26, 37, 49, 145))

    if (fraction > 0) then
        surface.SetDrawColor(accent.r, accent.g, accent.b, math.min(accent.a or 255, 188))
        draw.RoundedBox(3, barX, barY, math.max(SX(2), barWidth * fraction), barHeight, Color(accent.r, accent.g, accent.b, math.min(accent.a or 255, 188)))
    end

    draw.SimpleText(tostring(math.floor(tonumber(value) or 0)), "MYRP_HUD_Label",
        x + width, y + SY(9), colors.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function ShouldHideCustomHUD()
    local client = LocalPlayer()
    if (!IsValid(client) or !client.GetCharacter or !client:GetCharacter()) then
        return true
    end

    -- Do not draw over MYRP's own inventory, TAB board, or the GMod pause menu.
    if (ix and ix.gui and IsValid(ix.gui.myrpInventoryRoot)) then
        return true
    end

    if (input and input.IsKeyDown and input.IsKeyDown(KEY_TAB)) then
        return true
    end

    if (gui and gui.IsGameUIVisible and gui.IsGameUIVisible()) then
        return true
    end

    return false
end

local function DrawMainHUD(state)
    local screenH = ScrH()
    local x = SX(30)
    local width = math.min(SX(560), ScrW() - SX(60))
    local height = SY(146)
    local y = screenH - height - SY(26)
    local accent = state.accent or colors.neutral

    DrawPanel(x, y, width, height, accent)

    draw.SimpleText(state.factionName .. "  /  " .. state.className, "MYRP_HUD_Header",
        x + SX(18), y + SY(20), colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(state.playerName or "UNKNOWN", "MYRP_HUD_Small",
        x + width - SX(16), y + SY(20), colors.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(colors.border)
    surface.DrawRect(x + SX(16), y + SY(37), width - SX(32), SY(1))

    local leftX = x + SX(18)
    local leftWidth = SX(254)
    DrawBar("HP", state.health, state.maxHealth, leftX, y + SY(48), leftWidth, colors.health)
    DrawBar("ARM", state.armor, 100, leftX, y + SY(77), leftWidth, colors.armor)

    if (state.stamina != nil) then
        DrawBar("STM", state.stamina, 100, leftX, y + SY(106), leftWidth, colors.stamina)
    elseif (state.hunger != nil) then
        DrawBar("HGR", state.hunger, 100, leftX, y + SY(106), leftWidth, colors.stamina)
    else
        draw.SimpleText("VITAL SIGNS // ONLINE", "MYRP_HUD_Small",
            leftX, y + SY(112), colors.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local rightX = x + SX(302)
    local rightWidth = width - SX(320)

    local animatedCredits = SmoothHUDValue("credits", state.credits, 7)
    local animatedAnamnecites = SmoothHUDValue("anamnecites", state.anamnecites, 7)
    draw.SimpleText("CREDITS", "MYRP_HUD_Label", rightX, y + SY(57), colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(FormatNumber(animatedCredits), "MYRP_HUD_Money", x + width - SX(18), y + SY(57),
        colors.credits, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    draw.SimpleText("ANAMNECITES", "MYRP_HUD_Label", rightX, y + SY(88), colors.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(FormatNumber(animatedAnamnecites), "MYRP_HUD_Money", x + width - SX(18), y + SY(88),
        colors.anamnecites, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    if (state.hunger != nil and state.stamina != nil) then
        draw.SimpleText("HUNGER  " .. tostring(math.floor(state.hunger)) .. "%", "MYRP_HUD_Small",
            rightX, y + SY(116), colors.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    elseif (state.stamina != nil and state.hunger == nil) then
        draw.SimpleText("MATCH ECONOMY // ACTIVE", "MYRP_HUD_Small",
            rightX, y + SY(116), colors.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("PERSONNEL // " .. tostring(state.characterID), "MYRP_HUD_Small",
            rightX, y + SY(116), colors.faint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function DrawAmmoHUD(state)
    local weapon = state.weapon
    if (!weapon) then
        return
    end

    local width = SX(292)
    local height = SY(92)
    local x = ScrW() - width - SX(30)
    local y = ScrH() - height - SY(26)
    local accent = state.accent or colors.neutral

    DrawPanel(x, y, width, height, accent)

    local weaponName = weapon.name or "WEAPON"
    local maxNameLength = 28
    if (#weaponName > maxNameLength) then
        weaponName = string.sub(weaponName, 1, maxNameLength - 3) .. "..."
    end

    draw.SimpleText(weaponName, "MYRP_HUD_Label", x + SX(16), y + SY(19), colors.muted,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("MAGAZINE", "MYRP_HUD_Small", x + SX(16), y + SY(62), colors.faint,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    local animatedClip = math.floor(SmoothHUDValue("ammo_clip", weapon.clip, 14) + 0.5)
    local animatedReserve = math.floor(SmoothHUDValue("ammo_reserve", weapon.reserve, 9) + 0.5)
    draw.SimpleText(tostring(animatedClip), "MYRP_HUD_Ammo", x + width - SX(74), y + SY(55),
        colors.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText("/  " .. tostring(animatedReserve), "MYRP_HUD_Value", x + width - SX(62), y + SY(59),
        accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local hudAlpha = 0
local lastDrawableState = nil

local function DrawCustomHUD()
    local state = GetHUDState()
    if (state) then
        lastDrawableState = state
    end

    local shouldDraw = state ~= nil and !ShouldHideCustomHUD()
    local targetAlpha = shouldDraw and 1 or 0
    local blend = 1 - math.exp(-FrameTime() * 9)
    hudAlpha = Lerp(blend, hudAlpha, targetAlpha)

    if (!lastDrawableState or hudAlpha <= 0.008) then
        return
    end

    -- Fades in after spawn and gently fades away under TAB, inventory or pause UI.
    surface.SetAlphaMultiplier(hudAlpha)
    DrawMainHUD(lastDrawableState)
    DrawAmmoHUD(lastDrawableState)
    surface.SetAlphaMultiplier(1)
end

-- Hide the original Source HUD health/armor/ammo widgets. Keep crosshair,
-- chat, voice indicators, death notices and other normal GMod UI elements.
local hiddenDefaultHUD = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudSuitPower = true
}

hook.Remove("HUDShouldDraw", "MYRP.CustomHUD.HideDefaultElements")
hook.Add("HUDShouldDraw", "MYRP.CustomHUD.HideDefaultElements", function(name)
    if (hiddenDefaultHUD[name]) then
        return false
    end
end)

-- Helix's info bar manager uses ShouldHideBars. Its temporary action bar is
-- separate, so timed actions continue to be visible.
hook.Remove("ShouldHideBars", "MYRP.CustomHUD.HideHelixBars")
hook.Add("ShouldHideBars", "MYRP.CustomHUD.HideHelixBars", function()
    return true
end)

-- Prevent Helix's default ammo display; MYRP draws the live weapon/ammo data.
hook.Remove("CanDrawAmmoHUD", "MYRP.CustomHUD.HideHelixAmmo")
hook.Add("CanDrawAmmoHUD", "MYRP.CustomHUD.HideHelixAmmo", function()
    return false
end)

hook.Remove("HUDPaint", HUD_HOOK)
hook.Add("HUDPaint", HUD_HOOK, DrawCustomHUD)

hook.Remove("OnScreenSizeChanged", "MYRP.CustomHUD.ResizeFonts")
hook.Add("OnScreenSizeChanged", "MYRP.CustomHUD.ResizeFonts", function()
    CreateHUDFonts()
    Log("INFO", "Screen resolution changed; HUD fonts rebuilt for " .. UIResolution())
end)

local function GetHUDStatus()
    local client = LocalPlayer()
    local state, reason = BuildHUDState(client)

    if (!state) then
        Log("WARN", "STATUS: HUD unavailable; reason=" .. tostring(reason))
        Log("INFO", "STATUS: resolution=" .. UIResolution()
            .. ", playerValid=" .. tostring(IsValid(client))
            .. ", character=" .. tostring(IsValid(client) and client.GetCharacter and client:GetCharacter() ~= nil))
        return
    end

    local weaponName = state.weapon and state.weapon.name or "none"
    local clip = state.weapon and state.weapon.clip or "n/a"
    local reserve = state.weapon and state.weapon.reserve or "n/a"

    Log("INFO", "STATUS: resolution=" .. UIResolution()
        .. ", characterID=" .. tostring(state.characterID)
        .. ", name=" .. tostring(state.playerName)
        .. ", faction=" .. tostring(state.factionID)
        .. ", class=" .. tostring(state.classID)
        .. ", health=" .. tostring(state.health) .. "/" .. tostring(state.maxHealth)
        .. ", armor=" .. tostring(state.armor)
        .. ", stamina=" .. tostring(state.stamina) .. " (" .. tostring(state.staminaSource) .. ")"
        .. ", hunger=" .. tostring(state.hunger) .. " (" .. tostring(state.hungerSource) .. ")"
        .. ", credits=" .. tostring(state.credits)
        .. ", anamnecites=" .. tostring(state.anamnecites)
        .. ", weapon=" .. tostring(weaponName)
        .. ", clip=" .. tostring(clip)
        .. ", reserve=" .. tostring(reserve))
end

concommand.Add("myrp_hud_status", GetHUDStatus)
concommand.Add("myrp_hud_refresh", function()
    CreateHUDFonts()
    hudCache = nil
    hudCacheReady = false
    nextUpdate = 0
    Log("INFO", "HUD cache/fonts refreshed; resolution=" .. UIResolution())
end)
concommand.Add("myrp_hud_debug", function(_, _, arguments)
    debugEnabled = arguments[1] == "1" or arguments[1] == "on" or arguments[1] == "true"
    lastDebugSignature = ""
    Log("INFO", "HUD debug=" .. tostring(debugEnabled))
end)

Log("INFO", "Custom HUD v0.3 loaded (faction-tinted glass, rounded panels, animated values and fade); resolution=" .. UIResolution())
Log("INFO", "Default health/armor/ammo and Helix info bars hidden; custom HUD hooks registered")
Log("INFO", "HUD data sources: Player Health/Armor/Weapon, character class/faction, character credits/anamnecites; hunger/stamina optional")
