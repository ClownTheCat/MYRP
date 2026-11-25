if not CLIENT then return end

local SUPPLY = MYRP.Supply
local activeTerminal
local status = {available = false, remaining = 0, activeCrate = false}
local lastStatusRequest = 0
local loadingUntil = 0
local lastTerminalUse = false
local lastCrateUse = false
local openingSound
local clicker = false
local configs = {}
local openingProgress = 0

surface.CreateFont("MYRP_Supply_Title", {font = "Consolas", size = 21, weight = 800, antialias = true})
surface.CreateFont("MYRP_Supply_Body", {font = "Consolas", size = 14, weight = 600, antialias = true})
surface.CreateFont("MYRP_Supply_Log", {font = "Consolas", size = 11, weight = 500, antialias = true})

local function Config(faction)
    if configs[faction] then return configs[faction] end
    local path = "myrp/supply_ui_" .. faction .. ".json"
    local saved = file.Exists(path, "DATA") and util.JSONToTable(file.Read(path, "DATA") or "") or nil
    configs[faction] = istable(saved) and saved or {x = 0, y = 0, z = 0, scale = 1, rotation = 0}
    return configs[faction]
end

local function SaveConfig(faction)
    file.CreateDir("myrp")
    file.Write("myrp/supply_ui_" .. faction .. ".json", util.TableToJSON(Config(faction), true))
end

local function FactionForModel(entity)
    if not IsValid(entity) then return nil end
    local model = string.lower(entity:GetModel() or "")
    if model == string.lower(SUPPLY.Terminals.combine) then return "combine" end
    if model == string.lower(SUPPLY.Terminals.resistance) then return "resistance" end
end

local function LocalFaction()
    return MYRP.UI and MYRP.UI.GetFactionID and MYRP.UI.GetFactionID(LocalPlayer()) or "neutral"
end

local function TargetTerminal()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() then return end
    local entity = client:GetEyeTrace().Entity
    local faction = FactionForModel(entity)
    if not faction or client:GetPos():DistToSqr(entity:GetPos()) > 220 * 220 then return end
    return entity, faction
end

local function SetClicker(enabled)
    if clicker ~= enabled then
        clicker = enabled
        gui.EnableScreenClicker(enabled)
    end
end

local function TimeString(seconds)
    seconds = math.max(0, math.ceil(seconds or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function DrawTerminal(entity, faction)
    local cfg = Config(faction)
    local anchor = entity:LocalToWorld(entity:OBBCenter() + Vector(cfg.x, cfg.y, cfg.z)):ToScreen()
    if not anchor.visible then return end

    local scale = math.Clamp(tonumber(cfg.scale) or 1, 0.5, 1.8)
    local w, h = 350 * scale, 238 * scale
    local x = math.Clamp(anchor.x - w / 2, 10, ScrW() - w - 10)
    local y = math.Clamp(anchor.y - h / 2, 10, ScrH() - h - 10)
    local combine = faction == "combine"
    local accent = combine and Color(105, 180, 245) or Color(218, 145, 91)
    local bright = combine and Color(174, 218, 255) or Color(245, 188, 132)
    local bg = combine and Color(5, 14, 24, 245) or Color(19, 13, 10, 245)
    local authorized = LocalFaction() == faction

    draw.RoundedBox(3, x - 4, y - 4, w + 8, h + 8, Color(accent.r, accent.g, accent.b, 24))
    draw.RoundedBox(2, x, y, w, h, bg)
    surface.SetDrawColor(accent.r, accent.g, accent.b, 190)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    surface.DrawRect(x + 1, y + 1, w - 2, 3)

    draw.SimpleText(combine and "CITADEL SUPPLY // NODE-07" or "RESISTANCE NET // NODE-03",
        "MYRP_Supply_Title", x + 13, y + 15, bright)
    draw.SimpleText("MYRP FIELD SYSTEM  |  ARCH-LIKE TTY", "MYRP_Supply_Log",
        x + 13, y + 42, Color(145, 173, 192))

    local logs = combine and {
        "[  OK  ] enclave uplink established",
        "[  OK  ] terminal certificate verified",
        "[  OK  ] encrypted channel ready",
        "[ INFO ] supply-daemon: listening",
        "[  OK  ] cargo manifest mounted",
        "[ INFO ] radio: scanning traffic"
    } or {
        "[  OK  ] resistance mesh connected",
        "[  OK  ] node identity verified",
        "[  OK  ] encrypted relay ready",
        "[ INFO ] supplyd: awaiting requisition",
        "[  OK  ] local manifest loaded",
        "[ INFO ] radio: monitoring traffic"
    }

    local shift = math.floor(CurTime() * 1.5) % #logs
    for i = 1, 4 do
        local index = ((shift + i - 1) % #logs) + 1
        draw.SimpleText(logs[index], "MYRP_Supply_Log", x + 13, y + 65 + (i - 1) * 14,
            Color(accent.r, accent.g, accent.b, i == 4 and 220 or 145))
    end

    surface.SetDrawColor(accent.r, accent.g, accent.b, 70)
    surface.DrawLine(x + 13, y + 126, x + w - 13, y + 126)

    local statusText, statusColor
    if not authorized then
        statusText, statusColor = "ACCESS DENIED // WRONG FACTION", Color(255, 125, 125)
    elseif CurTime() < loadingUntil then
        statusText, statusColor = "ОТПРАВЛЯЮ ЗАПРОС...", Color(240, 205, 125)
    elseif status.activeCrate then
        statusText, statusColor = "ЗАПРОС НЕДОСТУПЕН // ГРУЗ В ПОЛЕ", Color(255, 150, 150)
    elseif status.available then
        statusText, statusColor = "ЗАПРОС ГРУЗА ДОСТУПЕН", Color(165, 245, 175)
    else
        statusText, statusColor = "ЗАПРОС ГРУЗА НЕДОСТУПЕН  " .. TimeString(status.remaining), Color(255, 155, 155)
    end
    draw.SimpleText(statusText, "MYRP_Supply_Body", x + 13, y + 148, statusColor)

    local bx, by, bw, bh = x + 13, y + 169, w - 26, 34
    local mx, my = gui.MousePos()
    local hovered = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
    local canRequest = authorized and status.available and not status.activeCrate and CurTime() >= loadingUntil
    local button = canRequest and accent or Color(75, 85, 95)
    if hovered and canRequest then button = bright end

    draw.RoundedBox(2, bx, by, bw, bh, Color(button.r, button.g, button.b, canRequest and 42 or 18))
    surface.SetDrawColor(button.r, button.g, button.b, canRequest and 210 or 75)
    surface.DrawOutlinedRect(bx, by, bw, bh, 1)
    draw.SimpleText(canRequest and "[ E ]  REQUEST SUPPLY" or "[ E ]  REQUEST LOCKED",
        "MYRP_Supply_Body", bx + bw / 2, by + bh / 2, canRequest and bright or Color(130, 140, 150),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText("LINK: " .. (authorized and "SECURE" or "REJECTED"),
        "MYRP_Supply_Log", x + 13, y + h - 13,
        authorized and Color(130, 205, 155) or Color(235, 110, 110))

    return hovered, canRequest
end

hook.Add("HUDPaint", "MYRP.Supply.TerminalUI", function()
    local entity, faction = TargetTerminal()
    if not IsValid(entity) then
        activeTerminal = nil
        SetClicker(false)
        lastTerminalUse = input.IsKeyDown(KEY_E)
        return
    end

    SetClicker(true)
    if activeTerminal ~= entity then
        activeTerminal = entity
        lastStatusRequest = 0
        status = {available = false, remaining = 0, activeCrate = false}
    end

    if CurTime() - lastStatusRequest > 1 then
        lastStatusRequest = CurTime()
        net.Start("MYRP_Supply_StatusRequest")
            net.WriteEntity(entity)
        net.SendToServer()
    end

    local hovered, canRequest = DrawTerminal(entity, faction)
    local useDown = input.IsKeyDown(KEY_E)
    if useDown and not lastTerminalUse and hovered then
        if canRequest then
            loadingUntil = CurTime() + 1.7
            status.available = false
            status.remaining = SUPPLY.RequestCooldown
            if MYRP.UI and MYRP.UI.PlaySound then MYRP.UI.PlaySound("confirm") end
            net.Start("MYRP_Supply_Request")
                net.WriteEntity(entity)
            net.SendToServer()
        elseif MYRP.UI and MYRP.UI.PlaySound then
            MYRP.UI.PlaySound("denied")
        end
    end
    lastTerminalUse = useDown
end)

net.Receive("MYRP_Supply_Status", function()
    status.available = net.ReadBool()
    status.remaining = net.ReadFloat()
    status.activeCrate = net.ReadBool()
end)

net.Receive("MYRP_Supply_OpenProgress", function()
    openingProgress = net.ReadFloat()
    local state = net.ReadString()

    if state == "progress" then
        if not openingSound then
            openingSound = CreateSound(LocalPlayer(), "items/medshot4.wav")
            if openingSound then openingSound:PlayEx(0.35, 85) end
        end

        if openingSound then
            openingSound:ChangeVolume(0.35, 0)
            openingSound:ChangePitch(85 + openingProgress * 55, 0.08)
        end
    elseif openingSound then
        openingSound:Stop()
        openingSound = nil
    end


end)

hook.Add("HUDPaint", "MYRP.Supply.CrateInteraction", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() then return end
    local entity = client:GetEyeTrace().Entity
    local faction = IsValid(entity) and entity:GetNW2String("MYRP_SupplyFaction", "") or ""

    if not IsValid(entity) or (faction ~= "combine" and faction ~= "resistance")
        or client:GetPos():DistToSqr(entity:GetPos()) > 150 * 150 then
        lastCrateUse = input.IsKeyDown(KEY_E)
        return
    end

    local accent = faction == "combine" and Color(115, 185, 250) or Color(220, 150, 95)
    local w, h = 330, 94
    local x, y = ScrW() / 2 - w / 2, ScrH() * 0.66
    draw.RoundedBox(4, x, y, w, h, Color(5, 9, 13, 230))
    surface.SetDrawColor(accent.r, accent.g, accent.b, 185)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText("SUPPLY CONTAINER // " .. string.upper(faction), "MYRP_Supply_Body",
        x + 13, y + 16, accent)
    draw.SimpleText("Зажмите E, чтобы открыть", "MYRP_Supply_Body",
        x + 13, y + 41, color_white)

    local bx, by, bw, bh = x + 13, y + 65, w - 26, 16
    draw.RoundedBox(2, bx, by, bw, bh, Color(48, 20, 23, 230))
    local progress = math.Clamp(openingProgress, 0, 1)
    local shake = math.sin(CurTime() * 35) * progress * 2.2
    if progress > 0 then
        draw.RoundedBox(2, bx + 1 + shake, by + 1, math.max(1, (bw - 2) * progress), bh - 2,
            Color(225, 42, 52, 240))
    end

    local down = input.IsKeyDown(KEY_E)
    if down and not lastCrateUse then
        net.Start("MYRP_Supply_OpenStart")
            net.WriteEntity(entity)
        net.SendToServer()
    elseif not down and lastCrateUse then
        net.Start("MYRP_Supply_OpenStop")
        net.SendToServer()
    end
    lastCrateUse = down
end)

hook.Add("PostDrawTranslucentRenderables", "MYRP.Supply.CrateFactionOutline", function()
    for _, entity in ipairs(ents.FindByClass("prop_physics")) do
        local faction = entity:GetNW2String("MYRP_SupplyFaction", "")
        if faction == "combine" or faction == "resistance" then
            local color = faction == "combine" and Color(75, 165, 255) or Color(235, 135, 75)
            cam.IgnoreZ(true)
            render.SetColorMaterial()
            render.DrawWireframeBox(entity:GetPos(), entity:GetAngles(), entity:OBBMins(), entity:OBBMaxs(), color, true)
            cam.IgnoreZ(false)
        end
    end
end)

local function CalibrationFaction()
    local _, faction = TargetTerminal()
    if faction then return faction end
    local id = LocalFaction()
    if id == "combine" or id == "resistance" then return id end
end

concommand.Add("myrp_supply_ui_offset", function(_, _, args)
    local faction = CalibrationFaction()
    if not faction then print("[MYRP:SUPPLY] Aim at a terminal or use this as a faction character.") return end
    local cfg = Config(faction)
    cfg.x, cfg.y, cfg.z = tonumber(args[1]) or cfg.x, tonumber(args[2]) or cfg.y, tonumber(args[3]) or cfg.z
    SaveConfig(faction)
    print(string.format("[MYRP:SUPPLY] %s offset: %.1f %.1f %.1f", faction, cfg.x, cfg.y, cfg.z))
end)

concommand.Add("myrp_supply_ui_scale", function(_, _, args)
    local faction = CalibrationFaction()
    if not faction then return end
    local cfg = Config(faction)
    cfg.scale = math.Clamp(tonumber(args[1]) or cfg.scale, 0.5, 1.8)
    SaveConfig(faction)
    print("[MYRP:SUPPLY] " .. faction .. " scale: " .. cfg.scale)
end)

concommand.Add("myrp_supply_ui_rotation", function(_, _, args)
    local faction = CalibrationFaction()
    if not faction then return end
    local cfg = Config(faction)
    cfg.rotation = tonumber(args[1]) or cfg.rotation
    SaveConfig(faction)
    print("[MYRP:SUPPLY] Rotation profile saved: " .. cfg.rotation .. " (visual rotation is reserved for 3D2D calibration).")
end)

concommand.Add("myrp_supply_ui_reset", function()
    local faction = CalibrationFaction()
    if not faction then return end
    configs[faction] = {x = 0, y = 0, z = 0, scale = 1, rotation = 0}
    SaveConfig(faction)
    print("[MYRP:SUPPLY] " .. faction .. " calibration reset.")
end)

concommand.Add("myrp_supply_ui_status", function()
    local faction = CalibrationFaction()
    if not faction then return end
    local cfg = Config(faction)
    print(string.format("[MYRP:SUPPLY] %s | offset %.1f %.1f %.1f | scale %.2f | rotation %.1f",
        faction, cfg.x, cfg.y, cfg.z, cfg.scale, cfg.rotation))
end)

hook.Add("ShutDown", "MYRP.Supply.DisableClicker", function()
    SetClicker(false)
end)
