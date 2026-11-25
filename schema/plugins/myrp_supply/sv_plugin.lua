if not SERVER then return end

util.AddNetworkString("MYRP_Supply_Request")
util.AddNetworkString("MYRP_Supply_OpenStart")
util.AddNetworkString("MYRP_Supply_OpenStop")
util.AddNetworkString("MYRP_Supply_OpenProgress")
util.AddNetworkString("MYRP_Supply_StatusRequest")
util.AddNetworkString("MYRP_Supply_Status")
util.AddNetworkString("MYRP_Supply_CalibrationRequest")
util.AddNetworkString("MYRP_Supply_CalibrationSet")
util.AddNetworkString("MYRP_Supply_CalibrationSync")

local SUPPLY = MYRP.Supply
local cooldowns = {}
local activeCrates = {}
local pendingDeliveries = {}
local openingPlayers = {}

local function Log(level, message)
    MsgN("[MYRP:SUPPLY][" .. tostring(level) .. "] " .. tostring(message))
end

local function GetFactionID(client)
    if not IsValid(client) or not client.GetCharacter then return nil end

    local character = client:GetCharacter()
    if not character then return nil end

    local factionIndex = character:GetFaction()
    local faction = ix.faction.indices[tonumber(factionIndex) or factionIndex]
    local uniqueID = faction and string.lower(tostring(faction.uniqueID or ""))

    if uniqueID == "combine" or uniqueID == "resistance" then
        return uniqueID
    end
end

local function GetDataKey()
    return "myrp_supply_points_" .. game.GetMap()
end

local function ReadPoints()
    local points = ix.data.Get(GetDataKey(), {}, false, true)
    return istable(points) and points or {}
end

local function SavePoints(points)
    ix.data.Set(GetDataKey(), points, false, true)
end

local TERMINAL_PROP_MODELS = {
    ["models/props_lab/workspace002.mdl"] = true,
    ["models/props_combine/combine_intmonitor001.mdl"] = true
}

local function GetTerminalPropsDataKey()
    return "myrp_supply_spawned_terminal_props_" .. game.GetMap()
end

local function IsPersistentTerminalProp(entity)
    if not IsValid(entity) then return false end
    return TERMINAL_PROP_MODELS[string.lower(entity:GetModel() or "")] == true
end

local function ReadTerminalPropRecords()
    local records = ix.data.Get(GetTerminalPropsDataKey(), {}, false, true)
    return istable(records) and records or {}
end

local function WriteTerminalPropRecords(records)
    ix.data.Set(GetTerminalPropsDataKey(), records, false, true)
end

local function FindTerminalPropRecord(records, id)
    for _, record in ipairs(records) do
        if istable(record) and record.id == id then
            return record
        end
    end
end

local function SaveTerminalPropTransform(entity)
    if not IsPersistentTerminalProp(entity) then return end

    local id = entity.MYRP_SupplyPersistentPropID
    if not isstring(id) or id == "" then return end

    local records = ReadTerminalPropRecords()
    local record = FindTerminalPropRecord(records, id)
    if not record then return end

    local position = entity:GetPos()
    local angles = entity:GetAngles()
    record.position = {x = position.x, y = position.y, z = position.z}
    record.angles = {p = angles.p, y = angles.y, r = angles.r}
    WriteTerminalPropRecords(records)
    Log("INFO", "Saved terminal prop transform: " .. entity:GetModel())
end

hook.Add("PlayerSpawnedProp", "MYRP.Supply.TrackSpawnedTerminalProp", function(client, model, entity)
    if not IsValid(client) or not client:IsSuperAdmin() or not IsValid(entity) then return end

    model = string.lower(tostring(model or entity:GetModel() or ""))
    if not TERMINAL_PROP_MODELS[model] then return end

    local id = tostring(os.time()) .. "_" .. tostring(entity:EntIndex()) .. "_" .. tostring(math.random(100000, 999999))
    entity.MYRP_SupplyPersistentPropID = id
    entity:SetNW2String("MYRP_SupplyPersistentPropID", id)

    local position = entity:GetPos()
    local angles = entity:GetAngles()
    local records = ReadTerminalPropRecords()
    records[#records + 1] = {
        id = id,
        model = model,
        position = {x = position.x, y = position.y, z = position.z},
        angles = {p = angles.p, y = angles.y, r = angles.r}
    }
    WriteTerminalPropRecords(records)
    Log("INFO", client:Nick() .. " spawned persistent terminal prop: " .. model)
end)

hook.Add("PhysgunDrop", "MYRP.Supply.SaveSpawnedTerminalProp", function(client, entity)
    if not IsValid(client) or not client:IsSuperAdmin() then return end
    if not IsPersistentTerminalProp(entity) then return end

    timer.Simple(0, function()
        if IsValid(entity) then
            SaveTerminalPropTransform(entity)
        end
    end)
end)

local function RestoreSpawnedTerminalProps()
    local records = ReadTerminalPropRecords()
    local restored = 0

    for _, record in ipairs(records) do
        local model = istable(record) and string.lower(tostring(record.model or "")) or ""
        local position = istable(record) and record.position
        local angles = istable(record) and record.angles

        if TERMINAL_PROP_MODELS[model]
            and istable(position)
            and istable(angles)
            and isnumber(position.x) and isnumber(position.y) and isnumber(position.z)
            and isnumber(angles.p) and isnumber(angles.y) and isnumber(angles.r) then

            local entity = ents.Create("prop_physics")
            if IsValid(entity) then
                entity:SetModel(model)
                entity:SetPos(Vector(position.x, position.y, position.z))
                entity:SetAngles(Angle(angles.p, angles.y, angles.r))
                entity:Spawn()
                entity:Activate()

                entity.MYRP_SupplyPersistentPropID = record.id
                entity:SetNW2String("MYRP_SupplyPersistentPropID", tostring(record.id or ""))

                local physics = entity:GetPhysicsObject()
                if IsValid(physics) then
                    physics:EnableMotion(false)
                    physics:Sleep()
                end

                restored = restored + 1
            end
        end
    end

    Log("INFO", "Recreated " .. restored .. " spawned terminal prop(s) from saved data.")
end

local function GetCalibrationKey()
    return "myrp_supply_ui_" .. game.GetMap()
end

local function ReadCalibration()
    local defaults = {
        combine = {x = 0, y = 0, z = 0, scale = 1, rotation = 0, surface = false, pitch = 0, yaw = 0, roll = 0},
        resistance = {x = 0, y = 0, z = 0, scale = 1, rotation = 0, surface = false, pitch = 0, yaw = 0, roll = 0}
    }
    local saved = ix.data.Get(GetCalibrationKey(), defaults, false, true)
    if not istable(saved) then return defaults end
    saved.combine = istable(saved.combine) and saved.combine or defaults.combine
    saved.resistance = istable(saved.resistance) and saved.resistance or defaults.resistance
    return saved
end

local function SendCalibration(client)
    if not IsValid(client) then return end
    net.Start("MYRP_Supply_CalibrationSync")
        net.WriteTable(ReadCalibration())
    net.Send(client)
end

net.Receive("MYRP_Supply_CalibrationRequest", function(_, client)
    SendCalibration(client)
end)

net.Receive("MYRP_Supply_CalibrationSet", function(_, client)
    if not IsValid(client) or not client:IsSuperAdmin() then return end

    local faction = net.ReadString()
    local config = net.ReadTable()
    if (faction ~= "combine" and faction ~= "resistance") or not istable(config) then return end

    local saved = ReadCalibration()
    saved[faction] = {
        x = math.Clamp(tonumber(config.x) or 0, -128, 128),
        y = math.Clamp(tonumber(config.y) or 0, -128, 128),
        z = math.Clamp(tonumber(config.z) or 0, -128, 128),
        scale = math.Clamp(tonumber(config.scale) or 1, 0.5, 1.8),
        rotation = math.Clamp(tonumber(config.rotation) or 0, -180, 180),
        surface = config.surface == true,
        pitch = math.Clamp(tonumber(config.pitch) or 0, -180, 180),
        yaw = math.Clamp(tonumber(config.yaw) or 0, -180, 180),
        roll = math.Clamp(tonumber(config.roll) or 0, -180, 180)
    }
    ix.data.Set(GetCalibrationKey(), saved, false, true)

    net.Start("MYRP_Supply_CalibrationSync")
        net.WriteTable(saved)
    net.Broadcast()

    Log("INFO", client:Nick() .. " updated " .. faction .. " terminal UI calibration.")
end)

local function IsTerminal(entity)
    if not IsValid(entity) then return false end

    local model = string.lower(entity:GetModel() or "")
    return model == string.lower(SUPPLY.Terminals.combine)
        or model == string.lower(SUPPLY.Terminals.resistance)
end

local function GetTerminalFaction(entity)
    if not IsTerminal(entity) then return nil end

    local model = string.lower(entity:GetModel() or "")
    if model == string.lower(SUPPLY.Terminals.combine) then return "combine" end
    if model == string.lower(SUPPLY.Terminals.resistance) then return "resistance" end
end

local function IsLookingAt(client, entity, distance)
    if not IsValid(client) or not IsValid(entity) then return false end
    if client:GetPos():DistToSqr(entity:GetPos()) > (distance or 180) ^ 2 then return false end
    return client:GetEyeTrace().Entity == entity
end

local function IsAimingAtTerminal(client, entity, distance)
    if not IsValid(client) or not IsValid(entity) then return false end
    if client:GetPos():DistToSqr(entity:GetPos()) > (distance or 180) ^ 2 then return false end

    local direction = (entity:WorldSpaceCenter() - client:EyePos()):GetNormalized()
    if client:GetAimVector():Dot(direction) < 0.93 then return false end

    local trace = util.TraceLine({
        start = client:EyePos(),
        endpos = entity:WorldSpaceCenter(),
        filter = client
    })

    return trace.Entity == entity or trace.Fraction >= 0.99
end

local function Broadcast(message)
    for _, client in ipairs(player.GetAll()) do
        if IsValid(client) then
            client:ChatPrint(message)
        end
    end
end

local function Reply(client, message)
    if IsValid(client) then
        client:ChatPrint("[Снабжение] " .. message)
    else
        MsgN("[Снабжение] " .. message)
    end
end

local function BroadcastSupplyRequest(faction)
    local factionName = faction == "combine" and "Альянс" or "Сопротивление"
    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) then
            if GetFactionID(target) == faction then
                target:ChatPrint("[Снабжение] Ваша фракция запросила груз. Ящик прибудет на точку сброса через 30 секунд.")
            else
                target:ChatPrint("[Радиоперехват] ВНИМАНИЕ: другая фракция (" .. factionName
                    .. ") запросила снабжение. Ящик прибудет через 30 секунд!")
            end
        end
    end
end

local function SpawnCargoItem(class, position, angle)
    local entity = ents.Create(class)
    if not IsValid(entity) then
        Log("WARN", "Could not create cargo entity: " .. class)
        return
    end

    entity:SetPos(position)
    entity:SetAngles(angle or Angle(0, math.random(0, 359), 0))
    entity:Spawn()
    entity:Activate()

    local physics = entity:GetPhysicsObject()
    if IsValid(physics) then
        physics:Wake()
        physics:SetVelocity(VectorRand() * 45 + Vector(0, 0, 35))
    end

    return entity
end

local function DropCargo(crate, faction)
    if not IsValid(crate) then return end

    local origin = crate:GetPos() + Vector(0, 0, 34)
    local yaw = crate:GetAngles().y
    local right = Angle(0, yaw, 0):Right()
    local forward = Angle(0, yaw, 0):Forward()

    -- Initial test loadout. These are native HL2 entities and can be changed later.
    for index = 1, 10 do
        local row = math.floor((index - 1) / 5)
        local column = (index - 1) % 5
        local position = origin + right * ((column - 2) * 22) + forward * (row * 24)
        SpawnCargoItem("weapon_smg1", position, Angle(0, yaw, 0))
    end

    for index = 1, 5 do
        local position = origin - right * 48 + forward * ((index - 3) * 25) + Vector(0, 0, 12)
        SpawnCargoItem("item_healthvial", position, Angle(0, yaw, 0))
    end

    Log("INFO", faction .. " cargo opened; spawned 10 weapon_smg1 and 5 item_healthvial.")
end

local function SendOpenProgress(client, progress, state)
    if not IsValid(client) then return end

    net.Start("MYRP_Supply_OpenProgress")
        net.WriteFloat(math.Clamp(progress or 0, 0, 1))
        net.WriteString(state or "progress")
    net.Send(client)
end

local function CancelOpening(client, playError)
    local state = openingPlayers[client]
    if not state then return end

    openingPlayers[client] = nil
    timer.Remove("MYRP.Supply.Open." .. client:EntIndex())
    SendOpenProgress(client, 0, playError and "cancelled" or "stopped")

    if playError and IsValid(client) then
        client:EmitSound("buttons/button10.wav", 55, 100, 0.8)
    end
end

local function FinishOpening(client, state)
    if openingPlayers[client] ~= state then return end
    openingPlayers[client] = nil
    timer.Remove("MYRP.Supply.Open." .. client:EntIndex())

    local crate = state.crate
    if not IsValid(crate) then
        SendOpenProgress(client, 0, "stopped")
        return
    end

    local faction = crate:GetNW2String("MYRP_SupplyFaction", "")
    activeCrates[faction] = nil

    local position = crate:GetPos()
    local angles = crate:GetAngles()
    local effect = EffectData()
    effect:SetOrigin(position)
    effect:SetScale(1)
    effect:SetMagnitude(1)

    if faction == "combine" then
        crate:EmitSound("physics/metal/metal_box_break1.wav", 90, 100)
        util.Effect("MetalSpark", effect, true, true)
    else
        crate:EmitSound("physics/wood/wood_crate_break1.wav", 90, 100)
        util.Effect("WoodDebris", effect, true, true)
    end

    DropCargo(crate, faction)
    crate:Remove()
    SendOpenProgress(client, 1, "completed")
    Broadcast("[Снабжение] Груз " .. (faction == "combine" and "Альянса" or "Сопротивления") .. " вскрыт!")
end

local function StartOpening(client, crate)
    if openingPlayers[client] then return end
    if not IsValid(crate) or crate:GetClass() ~= "prop_physics" then return end
    if crate:GetNW2Bool("MYRP_SupplyOpened", false) then return end
    if not IsLookingAt(client, crate, 150) then return end

    local faction = crate:GetNW2String("MYRP_SupplyFaction", "")
    if faction ~= "combine" and faction ~= "resistance" then return end

    local state = {crate = crate, startedAt = CurTime(), lastUpdate = 0}
    openingPlayers[client] = state
    SendOpenProgress(client, 0, "started")

    timer.Create("MYRP.Supply.Open." .. client:EntIndex(), 0.05, 0, function()
        if not IsValid(client) or not client:Alive() then
            CancelOpening(client, false)
            return
        end

        if openingPlayers[client] ~= state or not IsValid(crate) then
            CancelOpening(client, false)
            return
        end

        if not client:KeyDown(IN_USE) or not IsLookingAt(client, crate, 150) then
            CancelOpening(client, true)
            return
        end

        local progress = math.Clamp((CurTime() - state.startedAt) / SUPPLY.OpenDuration, 0, 1)
        if CurTime() - state.lastUpdate >= 0.1 then
            state.lastUpdate = CurTime()
            SendOpenProgress(client, progress, "progress")
        end

        if progress >= 1 then
            FinishOpening(client, state)
        end
    end)
end

local function SendSupplyStatus(client, faction)
    if not IsValid(client) then return end

    local nextAllowed = cooldowns[faction] or 0
    local remaining = math.max(0, nextAllowed - CurTime())
    local deliveryRemaining = math.max(0, (pendingDeliveries[faction] or 0) - CurTime())
    local deliveryPending = deliveryRemaining > 0
    local activeCrate = IsValid(activeCrates[faction])
    local available = remaining <= 0 and not activeCrate and not deliveryPending

    net.Start("MYRP_Supply_Status")
        net.WriteBool(available)
        net.WriteFloat(remaining)
        net.WriteBool(activeCrate)
        net.WriteBool(deliveryPending)
        net.WriteFloat(deliveryRemaining)
    net.Send(client)
end

net.Receive("MYRP_Supply_StatusRequest", function(_, client)
    local terminal = net.ReadEntity()
    if not IsValid(client) or not client:Alive() or not IsTerminal(terminal) then return end
    if client:GetPos():DistToSqr(terminal:GetPos()) > 2048 * 2048 then return end

    local terminalFaction = GetTerminalFaction(terminal)
    if not terminalFaction or GetFactionID(client) ~= terminalFaction then
        SendSupplyStatus(client, terminalFaction or "combine")
        return
    end

    SendSupplyStatus(client, terminalFaction)
end)

net.Receive("MYRP_Supply_Request", function(_, client)
    local terminal = net.ReadEntity()
    if not IsValid(client) or not client:Alive() or not client:GetCharacter() then return end
    if not IsTerminal(terminal) or client:GetPos():DistToSqr(terminal:GetPos()) > 2048 * 2048 then return end

    local terminalFaction = GetTerminalFaction(terminal)
    local faction = GetFactionID(client)

    if not terminalFaction or faction ~= terminalFaction then
        client:ChatPrint("[Снабжение] Терминал не распознаёт ваш идентификатор фракции.")
        return
    end

    local now = CurTime()
    local nextAllowed = cooldowns[faction] or 0
    if now < nextAllowed then
        local remaining = math.ceil(nextAllowed - now)
        client:ChatPrint("[Снабжение] Запрос недоступен. Повторите через " .. string.FormattedTime(remaining, "%02i:%02i") .. ".")
        return
    end

    if IsValid(activeCrates[faction]) then
        client:ChatPrint("[Снабжение] Предыдущий груз ещё находится в зоне доставки.")
        return
    end

    local points = ReadPoints()
    local point = points[faction]
    if not istable(point) or not isnumber(point.x) or not isnumber(point.y) or not isnumber(point.z) then
        client:ChatPrint("[Снабжение] Точка доставки не настроена. Обратитесь к администратору.")
        return
    end

    cooldowns[faction] = now + SUPPLY.RequestCooldown
    pendingDeliveries[faction] = now + SUPPLY.DeliveryDelay
    client:ChatPrint("[Снабжение] Запрос отправлен. Ящик прибудет на точку сброса через 30 секунд.")
    BroadcastSupplyRequest(faction)

    local deliveryTimer = "MYRP.Supply.Deliver." .. faction
    timer.Remove(deliveryTimer)
    timer.Create(deliveryTimer, SUPPLY.DeliveryDelay, 1, function()
        pendingDeliveries[faction] = nil
        if not game or not game.GetMap then return end

        local currentPoints = ReadPoints()
        local currentPoint = currentPoints[faction]
        if not istable(currentPoint) then return end

        -- Drop the crate from above the saved landing point so players can see it descend.
        local position = Vector(currentPoint.x, currentPoint.y, currentPoint.z) + Vector(0, 0, 600)
        local angles = Angle(0, currentPoint.yaw or 0, 0)
        local crate = ents.Create("prop_physics")

        if not IsValid(crate) then
            Log("ERROR", "Failed to create " .. faction .. " supply crate.")
            return
        end

        crate:SetModel(SUPPLY.Crates[faction])
        crate:SetPos(position)
        crate:SetAngles(angles)
        crate:Spawn()
        crate:Activate()
        crate:SetNW2String("MYRP_SupplyFaction", faction)
        crate:SetNW2Bool("MYRP_SupplyOpened", false)
        crate:SetCollisionGroup(COLLISION_GROUP_NONE)

        local physics = crate:GetPhysicsObject()
        if IsValid(physics) then
            physics:Wake()
            physics:SetVelocity(Vector(0, 0, -120))
        end

        activeCrates[faction] = crate
        if MYRP.MatchReset and MYRP.MatchReset.RegisterTransientEntity then
            MYRP.MatchReset.RegisterTransientEntity(crate)
        end

        Broadcast("[Снабжение] Груз " .. (faction == "combine" and "Альянса" or "Сопротивления") .. " прибыл!")
        Log("INFO", faction .. " supply crate delivered at " .. tostring(position))
    end)
end)

net.Receive("MYRP_Supply_OpenStart", function(_, client)
    local crate = net.ReadEntity()
    if not IsValid(client) or not client:Alive() or not client:GetCharacter() then return end
    StartOpening(client, crate)
end)

net.Receive("MYRP_Supply_OpenStop", function(_, client)
    if not IsValid(client) then return end
    if openingPlayers[client] then
        CancelOpening(client, true)
    end
end)

hook.Add("PlayerDeath", "MYRP.Supply.CancelOpeningOnDeath", function(client)
    CancelOpening(client, false)
end)

hook.Add("PlayerDisconnected", "MYRP.Supply.CancelOpeningOnDisconnect", function(client)
    CancelOpening(client, false)
end)

hook.Add("EntityRemoved", "MYRP.Supply.ClearRemovedCrate", function(entity)
    for faction, crate in pairs(activeCrates) do
        if crate == entity then
            activeCrates[faction] = nil
        end
    end
end)

local function SetDropPoint(client, faction)
    if not IsValid(client) or not client:IsSuperAdmin() then
        Reply(client, "Эта команда доступна только SuperAdmin.")
        return
    end

    local trace = client:GetEyeTrace()
    if not trace.Hit or trace.HitSky or trace.HitNormal.z < 0.55 then
        Reply(client, "Наведись на пол или достаточно ровную поверхность, куда должен прибывать груз.")
        return
    end

    local points = ReadPoints()
    points[faction] = {
        x = trace.HitPos.x,
        y = trace.HitPos.y,
        z = trace.HitPos.z,
        yaw = client:EyeAngles().y
    }
    SavePoints(points)

    Reply(client, (faction == "combine" and "Комбайнов" or "Сопротивления")
        .. " сохранена: " .. tostring(trace.HitPos))
    Log("INFO", client:Nick() .. " set " .. faction .. " drop point to " .. tostring(trace.HitPos))
end

local function FindPlayerByIdentifier(identifier)
    if not isstring(identifier) or identifier == "" then return nil end
    identifier = string.lower(identifier)

    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) then
            if string.lower(target:SteamID()) == identifier
                or string.lower(target:SteamID64()) == identifier
                or string.lower(target:Nick()) == identifier then
                return target
            end
        end
    end
end

local function ResolvePointCommandPlayer(client, args)
    if IsValid(client) then return client end

    local target = FindPlayerByIdentifier(args and args[1])
    if not IsValid(target) then
        Reply(nil, "Из серверной консоли укажи SteamID64 SuperAdmin: <команда> <SteamID64>.")
        return
    end

    return target
end

concommand.Add("myrp_supply_set_combine", function(client, _, args)
    SetDropPoint(ResolvePointCommandPlayer(client, args), "combine")
end)

concommand.Add("myrp_supply_set_resistance", function(client, _, args)
    SetDropPoint(ResolvePointCommandPlayer(client, args), "resistance")
end)

concommand.Add("myrp_supply_show_points", function(client)
    if IsValid(client) and not client:IsSuperAdmin() then
        Reply(client, "Эта команда доступна только SuperAdmin.")
        return
    end

    local points = ReadPoints()
    for _, faction in ipairs({"combine", "resistance"}) do
        local point = points[faction]
        if istable(point) then
            local position = Vector(point.x, point.y, point.z)
            Reply(client, faction .. ": " .. tostring(position))
            if IsValid(client) then
                debugoverlay.Sphere(position, 18, 10, faction == "combine" and Color(90, 170, 255) or Color(235, 145, 90), true)
                debugoverlay.Cross(position, 30, 10, color_white, true)
            end
        else
            Reply(client, faction .. ": точка не задана.")
        end
    end
end)

hook.Add("MYRP_MatchResetCleanup", "MYRP.Supply.CleanupRound", function()
    for faction, crate in pairs(activeCrates) do
        if IsValid(crate) then crate:Remove() end
        activeCrates[faction] = nil
    end

    for _, faction in ipairs({"combine", "resistance"}) do
        timer.Remove("MYRP.Supply.Deliver." .. faction)
    end
    pendingDeliveries = {}

    for client in pairs(openingPlayers) do
        CancelOpening(client, false)
    end

    cooldowns = {}
end)

hook.Add("InitPostEntity", "MYRP.Supply.RestoreTerminalProps", function()
    timer.Simple(5, function()
        if not ix or not ix.data then return end
        RestoreSpawnedTerminalProps()
    end)
end)

hook.Add("InitPostEntity", "MYRP.Supply.ClearTransientState", function()
    cooldowns = {}
    activeCrates = {}
    pendingDeliveries = {}
    openingPlayers = {}
end)

Log("INFO", "Supply backend loaded. Drop point commands registered.")
