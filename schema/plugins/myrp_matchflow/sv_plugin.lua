-- MYRP Match Flow
-- Persistent faction lock for the duration of a match and profession selection
-- after a 30-second death timer. This plugin is additive: it does not replace
-- or edit the existing myrp_factionselect plugin.

if not SERVER then return end

local DATA_KEY = "myrp_matchflow_state"
local RESPAWN_DELAY = 30
local REQUEST_COOLDOWN = 1

util.AddNetworkString("myrpMatchflowOpenRespawn")
util.AddNetworkString("myrpMatchflowSelectProfession")
util.AddNetworkString("myrpMatchflowRespawnResult")
util.AddNetworkString("myrpMatchflowRespawnTimer")

local DEFAULT_STATE = {
    active = false,
    factions = {}
}

-- Detect a new server process using persistent server uptime.
-- Map changes keep the same process uptime; a full restart resets it.
local SERVER_UPTIME_KEY = "myrp_server_process_uptime"
local currentServerUptime = SysTime()
local previousServerUptime = tonumber(
    ix.data.Get(SERVER_UPTIME_KEY, -1, false, true)
) or -1

local isNewServerProcess = previousServerUptime < 0
    or currentServerUptime < previousServerUptime

local matchState

if isNewServerProcess then
    matchState = table.Copy(DEFAULT_STATE)
    matchState.kills = {
        combine = 0,
        resistance = 0
    }

    ix.data.Set(DATA_KEY, matchState, false, true)

    MsgN("[MYRP:MATCH][INFO] New server process detected; previous match state reset.")
else
    matchState = ix.data.Get(DATA_KEY, DEFAULT_STATE, false, true)

    MsgN("[MYRP:MATCH][INFO] Same server process detected; match state preserved.")
end

ix.data.Set(SERVER_UPTIME_KEY, currentServerUptime, false, true)

timer.Create("MYRP.MatchFlow.SaveServerUptime", 5, 0, function()
    ix.data.Set(SERVER_UPTIME_KEY, SysTime(), false, true)
end)

if not istable(matchState) then
    matchState = table.Copy(DEFAULT_STATE)
end

matchState.active = matchState.active == true
matchState.factions = istable(matchState.factions) and matchState.factions or {}

local function SaveMatchState()
    ix.data.Set(DATA_KEY, matchState, false, true)
end

local function GetFactionByIndex(factionIndex)
    local index = tonumber(factionIndex) or factionIndex
    return ix.faction.indices[index]
end

local function GetFactionIDFromIndex(factionIndex)
    local faction = GetFactionByIndex(factionIndex)
    return faction and string.lower(tostring(faction.uniqueID)) or nil
end

local function GetCharacterFactionID(character)
    if not character or not character.GetFaction then
        return nil
    end

    return GetFactionIDFromIndex(character:GetFaction())
end

local function GetLockedFaction(client)
    if not IsValid(client) then return nil end

    return matchState.factions[client:SteamID64()]
end

local function SetFactionLock(client, factionID)
    if not matchState.active or not IsValid(client) then
        return true
    end

    factionID = string.lower(tostring(factionID or ""))

    if factionID == "" then
        return false
    end

    local steamID64 = client:SteamID64()
    local lockedFaction = matchState.factions[steamID64]

    if lockedFaction and lockedFaction ~= factionID then
        return false
    end

    if not lockedFaction then
        matchState.factions[steamID64] = factionID
        SaveMatchState()

        MsgN("[MYRP:MATCH][INFO] Faction locked: player=" .. client:SteamName()
            .. ", steamid64=" .. steamID64 .. ", faction=" .. factionID)
    end

    return true
end

local function CanManageMatch(client)
    -- Server console is allowed. In-game, only admins/superadmins may manage it.
    return not IsValid(client) or client:IsAdmin()
end

local function MatchReply(client, message)
    if IsValid(client) then
        client:ChatPrint(message)
    else
        MsgN(message)
    end
end

concommand.Add("myrp_match_start", function(client)
    if not CanManageMatch(client) then
        MatchReply(client, "[MYRP] РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ Р·Р°РїСѓСЃРєР° РјР°С‚С‡Р°.")
        return
    end

    matchState = {
        active = true,
        factions = {}
    }

    -- Players already in the world keep the faction of their active character.
    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) then
            local factionID = GetCharacterFactionID(target:GetCharacter())

            if factionID then
                matchState.factions[target:SteamID64()] = factionID
            end
        end
    end

    SaveMatchState()

    MsgN("[MYRP:MATCH][INFO] Match started; locked players="
        .. tostring(table.Count(matchState.factions)))
    MatchReply(client, "[MYRP] РњР°С‚С‡ РЅР°С‡Р°С‚. Р¤СЂР°РєС†РёРё Р·Р°РєСЂРµРїР»РµРЅС‹ РґРѕ Р·Р°РІРµСЂС€РµРЅРёСЏ РјР°С‚С‡Р°.")
end)

concommand.Add("myrp_match_end", function(client)
    if not CanManageMatch(client) then
        MatchReply(client, "[MYRP] РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ Р·Р°РІРµСЂС€РµРЅРёСЏ РјР°С‚С‡Р°.")
        return
    end

    matchState = {
        active = false,
        factions = {}
    }

    SaveMatchState()

    MsgN("[MYRP:MATCH][INFO] Match ended; all faction locks cleared.")
    MatchReply(client, "[MYRP] РњР°С‚С‡ Р·Р°РІРµСЂС€С‘РЅ. РћРіСЂР°РЅРёС‡РµРЅРёСЏ С„СЂР°РєС†РёР№ СЃРЅСЏС‚С‹.")
end)

concommand.Add("myrp_match_status", function(client)
    if not CanManageMatch(client) then
        MatchReply(client, "[MYRP] РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ.")
        return
    end

    MsgN("[MYRP:MATCH][STATUS] active=" .. tostring(matchState.active)
        .. ", lockedPlayers=" .. tostring(table.Count(matchState.factions)))

    for steamID64, factionID in pairs(matchState.factions) do
        MsgN("[MYRP:MATCH][PLAYER] " .. tostring(steamID64) .. " -> " .. tostring(factionID))
    end
end)

-- Block the custom faction selector before it creates a duplicate character.
-- myrp_factionselect calls CanPlayerCreateCharacter before ix.char.Create.
hook.Add("CanPlayerCreateCharacter", "MYRP.MatchFlow.BlockFactionCreate", function(client, payload)
    if not matchState.active or not IsValid(client) or not istable(payload) then
        return
    end

    local lockedFaction = GetLockedFaction(client)
    if not lockedFaction then
        return
    end

    local requestedFaction = payload.faction

    if isnumber(requestedFaction) then
        requestedFaction = GetFactionIDFromIndex(requestedFaction)
    elseif isstring(requestedFaction) then
        requestedFaction = string.lower(requestedFaction)
    end

    if requestedFaction and requestedFaction ~= lockedFaction then
        MsgN("[MYRP:MATCH][DENY] Character creation blocked: player="
            .. client:SteamName() .. ", locked=" .. lockedFaction
            .. ", requested=" .. tostring(requestedFaction))

        return false, "Р’ СЌС‚РѕРј РјР°С‚С‡Рµ РІС‹ Р·Р°РєСЂРµРїР»РµРЅС‹ Р·Р° С„СЂР°РєС†РёРµР№ "
            .. string.upper(lockedFaction) .. "."
    end
end)

-- Also block loading an already-existing character from the opposing faction.
-- The existing custom selector calls this hook before setting up a character.
hook.Add("CanPlayerUseCharacter", "MYRP.MatchFlow.BlockFactionLoad", function(client, character)
    if not matchState.active or not IsValid(client) or not character then
        return
    end

    local lockedFaction = GetLockedFaction(client)
    if not lockedFaction then
        return
    end

    local requestedFaction = GetCharacterFactionID(character)

    if requestedFaction and requestedFaction ~= lockedFaction then
        MsgN("[MYRP:MATCH][DENY] Character load blocked: player="
            .. client:SteamName() .. ", locked=" .. lockedFaction
            .. ", requested=" .. tostring(requestedFaction))

        return false
    end
end)

-- First successful character load in a match establishes the lock.
hook.Add("PlayerLoadedCharacter", "MYRP.MatchFlow.RememberFaction", function(client, character)
    if not matchState.active or not IsValid(client) or not character then
        return
    end

    local factionID = GetCharacterFactionID(character)
    if not factionID then return end

    if not SetFactionLock(client, factionID) then
        ErrorNoHalt("[MYRP:MATCH] Character loaded with a faction that conflicts with its match lock: "
            .. client:SteamName() .. " / " .. factionID .. "\n")
    end
end)

local function SendRespawnResult(client, success, message)
    if not IsValid(client) then return end

    net.Start("myrpMatchflowRespawnResult")
        net.WriteBool(success == true)
        net.WriteString(message or "")
    net.Send(client)
end

hook.Add("PlayerDeath", "MYRP.MatchFlow.SetRespawnTimer", function(client)
    if not IsValid(client) or not client:GetCharacter() then
        return
    end

    local factionID = GetCharacterFactionID(client:GetCharacter())
    if not factionID then return end

    client.ixMatchflowRespawnAt = CurTime() + RESPAWN_DELAY
    client.ixMatchflowRespawnMenuSent = false
    client.ixMatchflowNextRespawnRequest = 0

    -- Tell the client to render a visible countdown while the server blocks
    -- automatic respawn. The client starts its own local countdown on receipt.
    net.Start("myrpMatchflowRespawnTimer")
        net.WriteUInt(RESPAWN_DELAY, 8)
    net.Send(client)

    -- Helix's GM:PlayerDeath sets its default spawnTime. Override the netvar
    -- after that gamemode method runs so clients see our actual 30 seconds.
    timer.Simple(0, function()
        if not IsValid(client) or client:Alive() then return end
        if not client.ixMatchflowRespawnAt then return end

        client:SetNetVar("deathTime", client.ixMatchflowRespawnAt)
        if client.SetAction then
            client:SetAction("@respawning", RESPAWN_DELAY)
        end
    end)

    MsgN("[MYRP:RESPAWN][INFO] " .. client:SteamName()
        .. " died; profession selection in " .. RESPAWN_DELAY .. " seconds.")
end)

-- Returning false suppresses Helix/base automatic respawn. The player remains
-- dead until a valid profession/model selection is received from the server.
hook.Add("PlayerDeathThink", "MYRP.MatchFlow.RespawnGate", function(client)
    if not IsValid(client) or not client.ixMatchflowRespawnAt then
        return
    end

    if client:Alive() then
        client.ixMatchflowRespawnAt = nil
        client.ixMatchflowRespawnMenuSent = nil
        return
    end

    if CurTime() >= client.ixMatchflowRespawnAt
        and not client.ixMatchflowRespawnMenuSent then

        local character = client:GetCharacter()
        local factionID = GetCharacterFactionID(character)

        if factionID then
            client.ixMatchflowRespawnMenuSent = true

            net.Start("myrpMatchflowOpenRespawn")
                net.WriteString(factionID)
            net.Send(client)

            MsgN("[MYRP:RESPAWN][INFO] Opening profession menu for "
                .. client:SteamName() .. "; faction=" .. factionID)
        end
    end

    return false
end)

local function FindClassByUniqueID(uniqueID)
    for _, class in pairs(ix.class.list or {}) do
        if class.uniqueID == uniqueID then
            return class
        end
    end
end

local function GetAllowedFactionModel(client, faction, requestedModel)
    if not isstring(requestedModel) or requestedModel == "" then
        return nil
    end

    local models = faction.GetModels and faction:GetModels(client) or faction.models or {}

    for _, entry in pairs(models) do
        local modelPath = isstring(entry) and entry or (istable(entry) and entry[1])

        if isstring(modelPath)
            and string.lower(modelPath) == string.lower(requestedModel)
            and util.IsValidModel(modelPath)
            and modelPath ~= "models/error.mdl" then

            return modelPath
        end
    end
end

net.Receive("myrpMatchflowSelectProfession", function(_, client)
    if not IsValid(client) then return end

    if (client.ixMatchflowNextRespawnRequest or 0) > CurTime() then
        return
    end

    client.ixMatchflowNextRespawnRequest = CurTime() + REQUEST_COOLDOWN

    local classID = string.lower(net.ReadString() or "")
    local requestedModel = string.Trim(net.ReadString() or "")

    if client:Alive() then
        SendRespawnResult(client, false, "Р’С‹ СѓР¶Рµ Р¶РёРІС‹.")
        return
    end

    if not client.ixMatchflowRespawnAt
        or CurTime() < client.ixMatchflowRespawnAt
        or not client.ixMatchflowRespawnMenuSent then

        SendRespawnResult(client, false, "Р’СЂРµРјСЏ РѕР¶РёРґР°РЅРёСЏ РµС‰С‘ РЅРµ Р·Р°РєРѕРЅС‡РёР»РѕСЃСЊ.")
        return
    end

    local character = client:GetCharacter()
    if not character then
        SendRespawnResult(client, false, "РџРµСЂСЃРѕРЅР°Р¶ РЅРµ РЅР°Р№РґРµРЅ.")
        return
    end

    local factionID = GetCharacterFactionID(character)
    local faction = factionID and ix.faction.Get(factionID)

    if not faction then
        SendRespawnResult(client, false, "РќРµ СѓРґР°Р»РѕСЃСЊ РѕРїСЂРµРґРµР»РёС‚СЊ РІР°С€Сѓ С„СЂР°РєС†РёСЋ.")
        return
    end

    local lockedFaction = GetLockedFaction(client)
    if matchState.active and lockedFaction and lockedFaction ~= factionID then
        SendRespawnResult(client, false, "Р’С‹ Р·Р°РєСЂРµРїР»РµРЅС‹ Р·Р° РґСЂСѓРіРѕР№ С„СЂР°РєС†РёРµР№.")
        return
    end

    local class = FindClassByUniqueID(classID)
    if not class or class.faction ~= faction.index then
        SendRespawnResult(client, false, "Р­С‚Р° РїСЂРѕС„РµСЃСЃРёСЏ РЅРµРґРѕСЃС‚СѓРїРЅР° РґР»СЏ РІР°С€РµР№ С„СЂР°РєС†РёРё.")
        return
    end

    local selectedModel = GetAllowedFactionModel(client, faction, requestedModel)
    if not selectedModel then
        SendRespawnResult(client, false, "Р’С‹Р±СЂР°РЅРЅР°СЏ РјРѕРґРµР»СЊ РЅРµРґРѕСЃС‚СѓРїРЅР° РґР»СЏ РІР°С€РµР№ С„СЂР°РєС†РёРё.")
        return
    end

    if character:GetClass() ~= class.index then
        if not character:JoinClass(class.index) then
            SendRespawnResult(client, false, "РќРµ СѓРґР°Р»РѕСЃСЊ РїРµСЂРµРєР»СЋС‡РёС‚СЊСЃСЏ РЅР° СЌС‚Сѓ РїСЂРѕС„РµСЃСЃРёСЋ.")
            return
        end
    end

    if not SetFactionLock(client, factionID) then
        SendRespawnResult(client, false, "РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕРґС‚РІРµСЂРґРёС‚СЊ Р·Р°РєСЂРµРїР»С‘РЅРЅСѓСЋ С„СЂР°РєС†РёСЋ.")
        return
    end

    character:SetModel(selectedModel)
    character:Save()

    client.ixMatchflowRespawnAt = nil
    client.ixMatchflowRespawnMenuSent = nil
    client.ixMatchflowNextRespawnRequest = nil
    client:SetNetVar("deathTime", nil)

    MsgN("[MYRP:RESPAWN][INFO] Respawning " .. client:SteamName()
        .. "; faction=" .. factionID
        .. "; class=" .. classID
        .. "; model=" .. selectedModel)

    client:Spawn()
    SendRespawnResult(client, true, "")
end)

-- Death overlay suppression is client-side: the real Helix ixDeathScreen is
-- created through MYRP's wrapped vgui.Create and kept valid but fully hidden.
-- No global net.Start/net.Send monkey-patches are used.
concommand.Add("myrp_matchflow_death_patch_status", function(client)
    local message = "[MYRP:MATCHFLOW][SERVER][STATUS] respawnTimerHooks=true; nativeDeathOverlaySuppression=client-side ixPlayerDeath/vgui.Create interception"
    MsgN(message)

    if IsValid(client) then
        client:ChatPrint(message)
    end
end)

MsgN("[MYRP:MATCH][INFO] Match Flow server module loaded; respawn="
    .. RESPAWN_DELAY .. "s; persistent faction lock ready.")

