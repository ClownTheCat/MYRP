if not CLIENT then return end

local SUPPLY = MYRP.Supply
local activeTerminal
local status = {available = false, remaining = 0, activeCrate = false}
local lastStatusRequest = 0
local loadingUntil = 0
local lastTerminalUse = false
local lastCrateUse = false
local openingSound
local terminalBooted = setmetatable({}, {__mode = "k"})
local bootingTerminal
local bootingFaction
local bootStartedAt = 0
local bootDuration = 6
local terminalPanelState
local bootMusicChannel
local configs = {}
local openingProgress = 0
local openingTargetProgress = 0
local calibrationMode

concommand.Add("myrp_supply_inspect_screen", function()
    local client = LocalPlayer()
    if not IsValid(client) then return end

    local trace = client:GetEyeTrace()
    print("========== MYRP SUPPLY SCREEN INSPECT ==========")
    print("Hit:", trace.Hit, "Texture:", trace.HitTexture or "<none>")
    if IsValid(trace.Entity) then
        print("Entity:", trace.Entity, "Class:", trace.Entity:GetClass())
        print("Model:", trace.Entity:GetModel())
        print("Materials:")
        PrintTable(trace.Entity:GetMaterials())
    else
        print("No valid entity under crosshair.")
    end
    print("================================================")
end)

surface.CreateFont("MYRP_Supply_Title", {font = "Consolas", size = 21, weight = 800, antialias = true})
surface.CreateFont("MYRP_Supply_Body", {font = "Consolas", size = 14, weight = 600, antialias = true})
surface.CreateFont("MYRP_Supply_Log", {font = "Consolas", size = 11, weight = 500, antialias = true})

local function Config(faction)
    if configs[faction] then return configs[faction] end
    local path = "myrp/supply_ui_" .. faction .. ".json"
    local saved = file.Exists(path, "DATA") and util.JSONToTable(file.Read(path, "DATA") or "") or nil
    configs[faction] = istable(saved) and saved or {x = 0, y = 0, z = 0, scale = 1, rotation = 0, surface = false, pitch = 0, yaw = 0, roll = 0}
    return configs[faction]
end

local function SaveConfig(faction)
    net.Start("MYRP_Supply_CalibrationSet")
        net.WriteString(faction)
        net.WriteTable(Config(faction))
    net.SendToServer()
end

net.Receive("MYRP_Supply_CalibrationSync", function()
    local saved = net.ReadTable()
    if not istable(saved) then return end
    for _, faction in ipairs({"combine", "resistance"}) do
        if istable(saved[faction]) then
            configs[faction] = saved[faction]
        end
    end
end)

hook.Add("InitPostEntity", "MYRP.Supply.RequestCalibration", function()
    timer.Simple(2, function()
        net.Start("MYRP_Supply_CalibrationRequest")
        net.SendToServer()
    end)
end)

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

    local traceEntity = client:GetEyeTrace().Entity
    local traceFaction = FactionForModel(traceEntity)
    if traceFaction and client:GetPos():DistToSqr(traceEntity:GetPos()) <= 220 * 220 then
        return traceEntity, traceFaction
    end

    -- While aiming at the floating 3D2D menu, the eye trace hits empty space
    -- instead of the physical monitor. Keep the nearest terminal in the aim cone active.
    local aim = client:GetAimVector()
    local bestEntity, bestFaction
    local bestDot = 0.94
    for _, entity in ipairs(ents.FindInSphere(client:GetPos(), 220)) do
        local faction = FactionForModel(entity)
        if faction then
            local direction = (entity:WorldSpaceCenter() - client:EyePos()):GetNormalized()
            local dot = aim:Dot(direction)
            if dot > bestDot then
                bestDot = dot
                bestEntity = entity
                bestFaction = faction
            end
        end
    end

    return bestEntity, bestFaction
end

local function TimeString(seconds)
    seconds = math.max(0, math.ceil(seconds or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function GetPanelTransform(entity, faction)
    local cfg = Config(faction)
    local position = entity:LocalToWorld(entity:OBBCenter() + Vector(cfg.x, cfg.y, cfg.z))
    local angle

    if calibrationMode and calibrationMode.entity == entity and calibrationMode.previewPosition then
        position = calibrationMode.previewPosition
        angle = calibrationMode.previewAngle
    elseif cfg.surface then
        angle = entity:LocalToWorldAngles(Angle(cfg.pitch or 0, cfg.yaw or 0, cfg.roll or 0))
    else
        angle = entity:GetAngles()
        angle:RotateAroundAxis(angle:Forward(), tonumber(cfg.rotation) or 0)
    end

    return position, angle, math.Clamp(tonumber(cfg.scale) or 1, 0.5, 1.8) * 0.075
end

local function DrawTerminalPanel(entity, faction)
    local client = LocalPlayer()
    local position, angle, scale = GetPanelTransform(entity, faction)
    local combine = faction == "combine"
    local accent = combine and Color(105, 180, 245) or Color(218, 145, 91)
    local bright = combine and Color(174, 218, 255) or Color(245, 188, 132)
    local bg = combine and Color(5, 14, 24, 245) or Color(19, 13, 10, 245)
    local authorized = LocalFaction() == faction
    local w, h = 360, 220
    local buttonY = 158
    local buttonH = 42
    local now = CurTime()
    local booted = terminalBooted[entity] == true
    local loadingRequest = now < loadingUntil

    cam.Start3D2D(position, angle, scale)
        draw.RoundedBox(3, -4, -4, w + 8, h + 8, Color(accent.r, accent.g, accent.b, 24))
        draw.RoundedBox(2, 0, 0, w, h, bg)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 190)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 190)
        surface.DrawRect(1, 1, w - 2, 3)

        draw.SimpleText(combine and "CITADEL SUPPLY // NODE-07" or "RESISTANCE NET // NODE-03",
            "MYRP_Supply_Title", 13, 15, bright)
        draw.SimpleText("MYRP FIELD SYSTEM  |  ARCH-LIKE TTY", "MYRP_Supply_Log",
            13, 42, Color(145, 173, 192))

        if not authorized then
            draw.SimpleText("ACCESS DENIED // WRONG FACTION", "MYRP_Supply_Body",
                13, 91, Color(255, 125, 125))
            draw.SimpleText("IDENTITY CHECK FAILED", "MYRP_Supply_Log",
                13, 115, Color(190, 105, 105))
        elseif not booted then
            draw.SimpleText("SYSTEM STATE: POWERED DOWN", "MYRP_Supply_Body",
                13, 91, Color(220, 185, 125))
            draw.SimpleText("Нажмите E на кнопке ниже, чтобы запустить ОС", "MYRP_Supply_Log",
                13, 119, Color(175, 185, 195))
        else
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
            local shift = math.floor(now * 1.5) % #logs
            for i = 1, 3 do
                local index = ((shift + i - 1) % #logs) + 1
                draw.SimpleText(logs[index], "MYRP_Supply_Log", 13, 70 + (i - 1) * 14,
                    Color(accent.r, accent.g, accent.b, i == 3 and 220 or 145))
            end

            surface.SetDrawColor(accent.r, accent.g, accent.b, 70)
            surface.DrawLine(13, 119, w - 13, 119)

            local statusText, statusColor
            if loadingRequest then
                statusText = "ОТПРАВЛЯЮ ЗАПРОС" .. string.rep(".", math.floor(now * 3) % 4)
                statusColor = Color(240, 205, 125)
            elseif status.activeCrate then
                statusText, statusColor = "ЗАПРОС НЕДОСТУПЕН // ГРУЗ В ПОЛЕ", Color(255, 150, 150)
            elseif status.available then
                statusText, statusColor = "ЗАПРОС ГРУЗА ДОСТУПЕН", Color(165, 245, 175)
            else
                statusText = "ЗАПРОС НЕДОСТУПЕН  " .. TimeString(status.remaining)
                statusColor = Color(255, 155, 155)
            end
            draw.SimpleText(statusText, "MYRP_Supply_Body", 13, 139, statusColor)
        end

        local canActivate = authorized and (not booted or (status.available and not status.activeCrate and not loadingRequest))
        local buttonText
        if not authorized then
            buttonText = "ДОСТУП ЗАПРЕЩЁН"
        elseif not booted then
            buttonText = "E   ЗАПУСТИТЬ ОС"
        elseif loadingRequest then
            buttonText = "ЗАПРОС ОТПРАВЛЯЕТСЯ..."
        elseif canActivate then
            buttonText = "E   ЗАПРОСИТЬ ГРУЗ"
        else
            buttonText = "ЗАПРОС НЕДОСТУПЕН"
        end

        local selected = terminalPanelState and terminalPanelState.entity == entity
            and terminalPanelState.hovered == true
        local buttonColor = selected and bright or accent
        draw.RoundedBox(2, 13, buttonY, w - 26, buttonH,
            Color(buttonColor.r, buttonColor.g, buttonColor.b, canActivate and (selected and 75 or 35) or 15))
        surface.SetDrawColor(buttonColor.r, buttonColor.g, buttonColor.b, canActivate and 210 or 65)
        surface.DrawOutlinedRect(13, buttonY, w - 26, buttonH, 1)
        draw.SimpleText(buttonText, "MYRP_Supply_Body", w / 2, buttonY + buttonH / 2,
            canActivate and bright or Color(125, 135, 145), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText("AIM AT OPTION  //  PRESS E", "MYRP_Supply_Log",
            13, h - 10, Color(135, 155, 170))
    cam.End3D2D()

    -- Intersect the player's aim ray with the floating panel to select its single action.
    local hit = util.IntersectRayWithPlane(client:EyePos(), client:GetAimVector(), position, angle:Forward())
    local hovered = false
    if hit then
        local delta = hit - position
        local localX = delta:Dot(angle:Right()) / scale
        local localY = -delta:Dot(angle:Up()) / scale
        hovered = localX >= 13 and localX <= w - 13 and localY >= buttonY and localY <= buttonY + buttonH
    end

    terminalPanelState = {entity = entity, faction = faction, hovered = hovered, canActivate = canActivate}
    return hovered, canActivate
end

local function DrawBootScreen()
    if not IsValid(bootingTerminal) then
        bootingTerminal = nil
        bootingFaction = nil
        if IsValid(bootMusicChannel) then
            bootMusicChannel:Stop()
            bootMusicChannel = nil
        end
        return
    end

    local elapsed = CurTime() - bootStartedAt
    local progress = math.Clamp(elapsed / bootDuration, 0, 1)
    local combine = bootingFaction == "combine"
    local accent = combine and Color(105, 180, 245) or Color(225, 145, 85)
    local bg = combine and Color(3, 9, 17) or Color(12, 8, 6)
    draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), bg)

    local logo = combine and "CMB" or "λ"
    draw.SimpleText(logo, "MYRP_Supply_Title", ScrW() / 2, ScrH() * 0.23, accent,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(combine and "CIVIL PROTECTION // SUPPLY NETWORK" or "RESISTANCE // FIELD NETWORK",
        "MYRP_Supply_Body", ScrW() / 2, ScrH() * 0.23 + 38, color_white,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("BOOTING MYRP FIELD OPERATING SYSTEM", "MYRP_Supply_Body",
        ScrW() / 2, ScrH() * 0.34, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local logs = combine and {
        "[    0.000] CITADEL BIOS v4.2 initializing",
        "[    0.041] CPU: checking secure execution environment",
        "[    0.086] memory: 65536 MB detected",
        "[    0.133] mounting /dev/citadel/root",
        "[    0.190] [ OK ] kernel image signature verified",
        "[    0.244] loading combine network drivers",
        "[    0.301] [ OK ] encrypted uplink established",
        "[    0.358] starting civil protection subsystem",
        "[    0.417] loading requisition database",
        "[    0.476] [ OK ] cargo manifest mounted",
        "[    0.535] starting supply-daemon.service",
        "[    0.594] synchronizing local node clock",
        "[    0.653] [ OK ] radio interception module ready",
        "[    0.712] checking authorization token",
        "[    0.771] [ OK ] identity accepted",
        "[    0.830] starting terminal interface",
        "[    0.889] [ OK ] all systems operational"
    } or {
        "[    0.000] RESISTANCE BIOS initializing",
        "[    0.041] searching for nearby mesh nodes",
        "[    0.086] memory: 8192 MB detected",
        "[    0.133] mounting /dev/resistance/root",
        "[    0.190] [ OK ] kernel image signature verified",
        "[    0.244] loading radio relay drivers",
        "[    0.301] [ OK ] encrypted mesh established",
        "[    0.358] starting field communications",
        "[    0.417] loading requisition database",
        "[    0.476] [ OK ] supply manifest mounted",
        "[    0.535] starting supplyd.service",
        "[    0.594] synchronizing relay clock",
        "[    0.653] [ OK ] resistance channels online",
        "[    0.712] checking operator credentials",
        "[    0.771] [ OK ] identity accepted",
        "[    0.830] starting terminal interface",
        "[    0.889] [ OK ] all systems operational"
    }

    local visibleLines = math.min(#logs, math.floor(elapsed * 5) + 1)
    local first = math.max(1, visibleLines - 9)
    local startY = ScrH() * 0.48
    for i = first, visibleLines do
        local lineIndex = i
        local alpha = i == visibleLines and 255 or 175
        draw.SimpleText(logs[lineIndex], "MYRP_Supply_Log", ScrW() / 2, startY + (i - first) * 17,
            Color(accent.r, accent.g, accent.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local barW = math.min(520, ScrW() * 0.55)
    local barX = (ScrW() - barW) / 2
    local barY = ScrH() * 0.82
    draw.RoundedBox(2, barX, barY, barW, 5, Color(70, 80, 90, 140))
    draw.RoundedBox(2, barX, barY, barW * progress, 5, accent)
    draw.SimpleText(string.format("INITIALIZING... %d%%", math.floor(progress * 100)),
        "MYRP_Supply_Log", ScrW() / 2, barY + 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if progress >= 1 then
        terminalBooted[bootingTerminal] = true
        bootingTerminal = nil
        bootingFaction = nil
        lastStatusRequest = 0
        if IsValid(bootMusicChannel) then
            bootMusicChannel:Stop()
            bootMusicChannel = nil
        end
        surface.PlaySound("buttons/button14.wav")
    end
end

hook.Add("PostDrawTranslucentRenderables", "MYRP.Supply.TerminalPanel3D2D", function(_, drawingSkybox)
    if drawingSkybox or IsValid(bootingTerminal) then return end
    local drawEntity = calibrationMode and calibrationMode.entity or activeTerminal
    if not IsValid(drawEntity) then return end

    local faction = FactionForModel(drawEntity)
    if faction then
        DrawTerminalPanel(drawEntity, faction)
    end
end)

hook.Add("HUDPaint", "MYRP.Supply.TerminalUI", function()
    if calibrationMode then return end
    if IsValid(bootingTerminal) then
        DrawBootScreen()
        return
    end

    local entity, faction = TargetTerminal()
    if not IsValid(entity) then
        activeTerminal = nil
        terminalPanelState = nil
        lastTerminalUse = input.IsKeyDown(KEY_E)
        return
    end

    if activeTerminal ~= entity then
        activeTerminal = entity
        lastStatusRequest = 0
        status = {available = false, remaining = 0, activeCrate = false}
    end

    if terminalBooted[entity] and CurTime() - lastStatusRequest > 1 then
        lastStatusRequest = CurTime()
        net.Start("MYRP_Supply_StatusRequest")
            net.WriteEntity(entity)
        net.SendToServer()
    end

    local useDown = input.IsKeyDown(KEY_E)
    local panel = terminalPanelState
    if useDown and not lastTerminalUse and panel and panel.entity == entity and panel.hovered and panel.canActivate then
        if not terminalBooted[entity] then
            bootingTerminal = entity
            bootingFaction = faction
            bootStartedAt = CurTime()
            if sound and sound.PlayFile then
                sound.PlayFile("sound/music/hl2_song15.mp3", "noplay", function(channel, errorCode)
                    if IsValid(channel) and IsValid(bootingTerminal) then
                        bootMusicChannel = channel
                        channel:Play()
                    else
                        surface.PlaySound("buttons/combine_button1.wav")
                    end
                end)
            else
                surface.PlaySound("buttons/combine_button1.wav")
            end
        else
            loadingUntil = CurTime() + 1.7
            status.available = false
            status.remaining = SUPPLY.RequestCooldown
            if MYRP.UI and MYRP.UI.PlaySound then MYRP.UI.PlaySound("confirm") end
            net.Start("MYRP_Supply_Request")
                net.WriteEntity(entity)
            net.SendToServer()
        end
    elseif useDown and not lastTerminalUse and panel and panel.entity == entity and not panel.hovered then
        if MYRP.UI and MYRP.UI.PlaySound then MYRP.UI.PlaySound("denied") end
    end
    lastTerminalUse = useDown
end)

net.Receive("MYRP_Supply_Status", function()
    status.available = net.ReadBool()
    status.remaining = net.ReadFloat()
    status.activeCrate = net.ReadBool()
end)

net.Receive("MYRP_Supply_OpenProgress", function()
    openingTargetProgress = net.ReadFloat()
    local state = net.ReadString()

    if state == "started" then
        openingProgress = 0
    end

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
    local returnRate = openingTargetProgress < openingProgress and 1.8 or 10
    openingProgress = Lerp(math.Clamp(FrameTime() * returnRate, 0, 1), openingProgress, openingTargetProgress)
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

local cachedSupplyCrates = {}

timer.Create("MYRP.Supply.CacheCrates", 0.5, 0, function()
    local found = {}
    for _, entity in ipairs(ents.FindByClass("prop_physics")) do
        local faction = entity:GetNW2String("MYRP_SupplyFaction", "")
        if faction == "combine" or faction == "resistance" then
            found[entity] = true
        end
    end
    cachedSupplyCrates = found
end)

hook.Add("PostDrawTranslucentRenderables", "MYRP.Supply.CrateFactionOutline", function()
    for entity in pairs(cachedSupplyCrates) do
        if not IsValid(entity) then
            cachedSupplyCrates[entity] = nil
        else
        local faction = entity:GetNW2String("MYRP_SupplyFaction", "")
        if faction == "combine" or faction == "resistance" then
            local color = faction == "combine" and Color(75, 165, 255) or Color(235, 135, 75)
            cam.IgnoreZ(true)
            render.SetColorMaterial()
            render.DrawWireframeBox(entity:GetPos(), entity:GetAngles(), entity:OBBMins(), entity:OBBMaxs(), color, true)
            cam.IgnoreZ(false)
        end
        end
    end
end)


local function SurfaceAngleFromNormal(normal)
    local angle = normal:Angle()
    local targetUp = Vector(0, 0, 1) - normal * normal:Dot(Vector(0, 0, 1))
    if targetUp:LengthSqr() < 0.0001 then
        targetUp = Vector(0, 1, 0) - normal * normal:Dot(Vector(0, 1, 0))
    end
    targetUp:Normalize()

    local currentUp = angle:Up()
    local roll = math.deg(math.atan2(normal:Dot(currentUp:Cross(targetUp)), currentUp:Dot(targetUp)))
    angle:RotateAroundAxis(normal, roll)
    return angle
end

local function StopCalibration(message)
    if not calibrationMode then return end
    gui.EnableScreenClicker(false)
    calibrationMode = nil
    if message then print("[MYRP:SUPPLY] " .. message) end
end

local function CalibrationRay()
    local client = LocalPlayer()
    if not IsValid(client) then return end
    local mx, my = gui.MousePos()
    if mx < 0 or my < 0 then return end

    return client:EyePos(), gui.ScreenToVector(mx, my)
end

local function CalibrationTrace()
    local state = calibrationMode
    if not state then return end

    local origin, direction = CalibrationRay()
    if not origin or not direction then return end

    if state.phase == "selecting" then
        local trace = util.TraceLine({
            start = origin,
            endpos = origin + direction * 1200,
            filter = LocalPlayer()
        })

        if trace.Hit and trace.Entity == state.entity then
            local normal = trace.HitNormal:GetNormalized()
            state.hitPosition = trace.HitPos + normal * 0.45
            state.hitAngle = SurfaceAngleFromNormal(normal)
            state.previewPosition = state.hitPosition
            state.previewAngle = state.hitAngle
        else
            state.hitPosition = nil
            state.hitAngle = nil
            state.previewPosition = nil
            state.previewAngle = nil
        end
    elseif state.phase == "placing" and state.planePosition and state.planeNormal then
        -- Intersect the cursor ray with the one plane selected by the first click.
        -- This prevents the panel from jumping between the monitor, bezel and other
        -- faces of the prop while the cursor moves.
        local denominator = direction:Dot(state.planeNormal)
        if math.abs(denominator) < 0.0001 then return end

        local distance = (state.planePosition - origin):Dot(state.planeNormal) / denominator
        if distance < 0 then return end

        state.previewPosition = origin + direction * distance + state.planeNormal * 0.45
        state.previewAngle = state.planeAngle
        state.hitPosition = state.previewPosition
        state.hitAngle = state.planeAngle
    end
end

local function LockCalibrationPlane()
    local state = calibrationMode
    if not state or not state.hitPosition or not state.hitAngle then
        print("[MYRP:SUPPLY] Сначала наведи курсор на сам экран монитора.")
        return
    end

    state.planePosition = state.hitPosition
    state.planeNormal = state.hitAngle:Forward()
    state.planeAngle = state.hitAngle
    state.phase = "placing"
    print("[MYRP:SUPPLY] Плоскость экрана зафиксирована. Теперь двигай курсор по экрану и нажми ЛКМ для установки панели.")
end

local function CommitCalibrationPosition()
    local state = calibrationMode
    if not state or not state.previewPosition or not state.previewAngle then return end

    local entity = state.entity
    if not IsValid(entity) then StopCalibration("Терминал больше не существует.") return end

    local cfg = Config(state.faction)
    local localPosition = entity:WorldToLocal(state.previewPosition) - entity:OBBCenter()
    local localAngle = entity:WorldToLocalAngles(state.previewAngle)
    cfg.x, cfg.y, cfg.z = localPosition.x, localPosition.y, localPosition.z
    cfg.pitch, cfg.yaw, cfg.roll = localAngle.p, localAngle.y, localAngle.r
    cfg.surface = true

    state.phase = "sizing"
    print("[MYRP:SUPPLY] Положение зафиксировано. Колесо мыши — размер, ЛКМ — сохранить, ПКМ — отменить.")
end

hook.Add("Think", "MYRP.Supply.SurfaceCalibration", function()
    local state = calibrationMode
    if not state then return end
    if not IsValid(state.entity) then StopCalibration("Терминал больше не существует.") return end

    if state.phase == "selecting" or state.phase == "placing" then
        CalibrationTrace()
        if input.WasMousePressed(MOUSE_LEFT) then
            if state.phase == "selecting" then
                LockCalibrationPlane()
            else
                CommitCalibrationPosition()
            end
        elseif input.WasMousePressed(MOUSE_RIGHT) then
            StopCalibration("Настройка отменена.")
        end
    elseif state.phase == "sizing" then
        if input.WasMousePressed(MOUSE_WHEEL_UP) then
            local cfg = Config(state.faction)
            cfg.scale = math.Clamp((tonumber(cfg.scale) or 1) + 0.05, 0.5, 1.8)
        elseif input.WasMousePressed(MOUSE_WHEEL_DOWN) then
            local cfg = Config(state.faction)
            cfg.scale = math.Clamp((tonumber(cfg.scale) or 1) - 0.05, 0.5, 1.8)
        end

        if input.WasMousePressed(MOUSE_LEFT) then
            SaveConfig(state.faction)
            StopCalibration("Положение и размер панели сохранены для всех игроков.")
        elseif input.WasMousePressed(MOUSE_RIGHT) then
            StopCalibration("Настройка отменена. Последняя сохранённая конфигурация не изменена.")
        end
    end
end)

hook.Add("HUDPaint", "MYRP.Supply.SurfaceCalibrationHelp", function()
    local state = calibrationMode
    if not state then return end

    local lines
    if state.phase == "selecting" then
        lines = {
            "MYRP // SURFACE CALIBRATION",
            "Наведи курсор на плоскость экрана монитора",
            "ЛКМ — зафиксировать плоскость    ПКМ — отмена"
        }
    elseif state.phase == "placing" then
        lines = {
            "MYRP // SURFACE CALIBRATION",
            "Плоскость зафиксирована — двигай курсор по экрану",
            "ЛКМ — установить панель    ПКМ — отмена"
        }
    else
        lines = {
            "MYRP // SURFACE CALIBRATION",
            string.format("Размер: %.2f", Config(state.faction).scale),
            "Колесо мыши — изменить размер    ЛКМ — сохранить    ПКМ — отмена"
        }
    end

    local width = 520
    local height = 76
    local x = (ScrW() - width) / 2
    local y = ScrH() - height - 28
    draw.RoundedBox(4, x, y, width, height, Color(4, 10, 17, 235))
    surface.SetDrawColor(110, 180, 235, 220)
    surface.DrawOutlinedRect(x, y, width, height, 1)
    for i, line in ipairs(lines) do
        draw.SimpleText(line, "MYRP_Supply_Body", x + 12, y + 10 + (i - 1) * 21,
            i == 1 and Color(130, 195, 245) or color_white)
    end
end)

local function CalibrationFaction()
    local client = LocalPlayer()
    if not IsValid(client) or not client:IsSuperAdmin() then
        print("[MYRP:SUPPLY] UI calibration is restricted to SuperAdmins.")
        return
    end

    local _, faction = TargetTerminal()
    if faction then return faction end
    local id = LocalFaction()
    if id == "combine" or id == "resistance" then return id end
end

concommand.Add("myrp_supply_ui_calibrate", function()
    if calibrationMode then
        StopCalibration("Режим настройки выключен.")
        return
    end

    local faction = CalibrationFaction()
    if not faction then
        print("[MYRP:SUPPLY] Наведись на терминал нужной фракции и повтори команду.")
        return
    end

    local entity, targetFaction = TargetTerminal()
    if not IsValid(entity) or targetFaction ~= faction then
        print("[MYRP:SUPPLY] Не удалось определить терминал. Наведись на него при запуске команды.")
        return
    end

    calibrationMode = {entity = entity, faction = faction, phase = "selecting"}
    gui.EnableScreenClicker(true)
    print("[MYRP:SUPPLY] Курсор включён. Наведи его на экран монитора и нажми ЛКМ, чтобы зафиксировать плоскость.")
end)

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

