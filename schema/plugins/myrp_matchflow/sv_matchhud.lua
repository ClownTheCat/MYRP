-- MYRP Match HUD v2.0
-- Persists match start time and opposing-faction player kills alongside the
-- existing myrp_matchflow_state. This module does not replace sv_plugin.lua.

if not SERVER then return end

local MATCH_DATA_KEY = "myrp_matchflow_state"
local MATCH_STATE_DEFAULT = {
    active = false,
    factions = {}
}

util.AddNetworkString("myrpMatchflowMatchState")

local function ReadMatchState()
    local state = ix.data.Get(MATCH_DATA_KEY, MATCH_STATE_DEFAULT, false, true)

    if not istable(state) then
        state = table.Copy(MATCH_STATE_DEFAULT)
    end

    state.active = state.active == true
    state.factions = istable(state.factions) and state.factions or {}

    local changed = false

    if state.active then
        if not isnumber(state.startedAt) or state.startedAt <= 0 then
            state.startedAt = os.time()
            changed = true
        end

        if not istable(state.kills) then
            state.kills = {}
            changed = true
        end
    end

    if not istable(state.kills) then
        state.kills = {}
        changed = true
    end

    for _, factionID in ipairs({"combine", "resistance"}) do
        local value = tonumber(state.kills[factionID]) or 0
        value = math.max(0, math.floor(value))

        if state.kills[factionID] ~= value then
            state.kills[factionID] = value
            changed = true
        end
    end

    if changed then
        ix.data.Set(MATCH_DATA_KEY, state, false, true)
    end

    return state
end

local function SaveMatchState(state)
    ix.data.Set(MATCH_DATA_KEY, state, false, true)
end

local function GetFactionIDFromCharacter(character)
    if not character or not character.GetFaction then
        return nil
    end

    local factionIndex = character:GetFaction()
    local index = tonumber(factionIndex) or factionIndex
    local faction = ix.faction.indices[index]

    if not faction or not isstring(faction.uniqueID) then
        return nil
    end

    return string.lower(faction.uniqueID)
end

-- MYRP test bots have no Helix character.
-- Only explicitly tagged MYRP bots use this fallback.
local function GetFactionIDFromPlayer(client)
    if not IsValid(client) or not client:IsPlayer() then
        return nil
    end

    local testFaction = client.ixMYRPTestBotFaction

    if client:IsBot()
        and (testFaction == "combine" or testFaction == "resistance") then
        return testFaction
    end

    return GetFactionIDFromCharacter(client:GetCharacter())
end

local function GetPlayerAnamnecites(client)
    if not IsValid(client) then
        return 0
    end

    -- Match the existing MYRP currency priority:
    -- player-local balance overrides character data.
    local localValue = client:GetLocalVar("myrpAnamnecites", nil)

    if localValue != nil then
        return math.floor(tonumber(localValue) or 0)
    end

    local character = client:GetCharacter()

    if character and character.GetData then
        return math.floor(tonumber(character:GetData("anamnecites", 0)) or 0)
    end

    return 0
end

local function GetFactionAnamnecitesTotals()
    local totals = {
        combine = 0,
        resistance = 0
    }

    for _, client in ipairs(player.GetAll()) do
        if IsValid(client) then
            local factionID = GetFactionIDFromPlayer(client)

            if factionID == "combine" or factionID == "resistance" then
                totals[factionID] = totals[factionID] + GetPlayerAnamnecites(client)
            end
        end
    end

    return totals
end

local function GetElapsedSeconds(state)
    if not state.active or not isnumber(state.startedAt) then
        return 0
    end

    return math.max(0, math.floor(os.time() - state.startedAt))
end

local function WriteMatchState(target)
    local state = ReadMatchState()
    local elapsed = GetElapsedSeconds(state)
    local combineKills = tonumber(state.kills.combine) or 0
    local resistanceKills = tonumber(state.kills.resistance) or 0
    local anamnecites = GetFactionAnamnecitesTotals()

    net.Start("myrpMatchflowMatchState")
        net.WriteBool(state.active)
        net.WriteUInt(math.min(elapsed, 4294967295), 32)
        net.WriteUInt(math.min(combineKills, 4294967295), 32)
        net.WriteUInt(math.min(resistanceKills, 4294967295), 32)
        net.WriteInt(math.Clamp(anamnecites.combine, -2147483648, 2147483647), 32)
        net.WriteInt(math.Clamp(anamnecites.resistance, -2147483648, 2147483647), 32)

    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

local function GetMatchSignature(state, anamnecites)
    return table.concat({
        state.active and "1" or "0",
        tostring(state.startedAt or 0),
        tostring(state.kills.combine or 0),
        tostring(state.kills.resistance or 0),
        tostring(anamnecites.combine or 0),
        tostring(anamnecites.resistance or 0)
    }, ":")
end

-- Start a match automatically when the server boots into an inactive state.
-- A pending soft reset is handled by MYRP MatchReset after map initialization.
timer.Simple(2, function()
    local pendingReset = ix.data.Get("myrp_matchreset_pending", false, false, true)

    if istable(pendingReset) and pendingReset.active == true then
        MsgN("[MYRP:MATCHHUD][INFO] Pending round reset detected; MatchReset will start the new match.")
        return
    end

    local state = ReadMatchState()

    if not state.active then
        MsgN("[MYRP:MATCHHUD][INFO] No active match found; starting a fresh match.")
        game.ConsoleCommand("myrp_match_start\n")
    else
        MsgN("[MYRP:MATCHHUD][INFO] Restoring active match; elapsed="
            .. GetElapsedSeconds(state) .. "s; combine=" .. state.kills.combine
            .. "; resistance=" .. state.kills.resistance)
    end
end)

-- Detect state changes made by the existing myrp_match_start / myrp_match_end
-- commands. This avoids duplicating or replacing those commands.
local lastSignature

timer.Create("MYRP.MatchHUD.StateSync", 0.5, 0, function()
    local state = ReadMatchState()
    local anamnecites = GetFactionAnamnecitesTotals()
    local signature = GetMatchSignature(state, anamnecites)

    if signature ~= lastSignature then
        lastSignature = signature
        WriteMatchState()
    end
end)

hook.Add("PlayerInitialSpawn", "MYRP.MatchHUD.SendInitialState", function(client)
    timer.Simple(4, function()
        if IsValid(client) then
            WriteMatchState(client)
        end
    end)
end)

hook.Add("PlayerLoadedCharacter", "MYRP.MatchHUD.SendAfterCharacterLoad", function(client)
    timer.Simple(0.5, function()
        if IsValid(client) then
            WriteMatchState(client)
        end
    end)
end)

-- Count only valid kills between opposing MYRP factions. Self-kills,
-- environmental deaths, NPCs and friendly fire do not change the faction score.
hook.Add("PlayerDeath", "MYRP.MatchHUD.TrackFactionKills", function(victim, inflictor, attacker)
    if not IsValid(victim) or not IsValid(attacker) or not attacker:IsPlayer() then
        return
    end

    if victim == attacker then
        return
    end

    local state = ReadMatchState()
    if not state.active then
        return
    end

    local attackerFaction = GetFactionIDFromPlayer(attacker)
    local victimFaction = GetFactionIDFromPlayer(victim)

    if not attackerFaction or not victimFaction or attackerFaction == victimFaction then
        return
    end

    if (attackerFaction ~= "combine" and attackerFaction ~= "resistance")
        or (victimFaction ~= "combine" and victimFaction ~= "resistance") then
        return
    end

    state.kills[attackerFaction] = (tonumber(state.kills[attackerFaction]) or 0) + 1
    SaveMatchState(state)

    MsgN("[MYRP:MATCHHUD][KILL] killer=" .. attacker:SteamName()
        .. "; victim=" .. victim:SteamName()
        .. "; faction=" .. attackerFaction
        .. "; score combine=" .. state.kills.combine
        .. " resistance=" .. state.kills.resistance)

    WriteMatchState()
end)

concommand.Add("myrp_matchhud_status", function(client)
    if IsValid(client) and not client:IsAdmin() then
        client:ChatPrint("[MYRP] РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ.")
        return
    end

    local state = ReadMatchState()
    local anamnecites = GetFactionAnamnecitesTotals()
    local message = "[MYRP:MATCHHUD][STATUS] active=" .. tostring(state.active)
        .. "; elapsed=" .. GetElapsedSeconds(state)
        .. "s; combineKills=" .. state.kills.combine
        .. "; resistanceKills=" .. state.kills.resistance
        .. "; combineAnamnecites=" .. tostring(anamnecites.combine)
        .. "; resistanceAnamnecites=" .. tostring(anamnecites.resistance)
        .. "; startedAt=" .. tostring(state.startedAt or 0)

    MsgN(message)

    if IsValid(client) then
        client:ChatPrint(message)
    end
end)

MsgN("[MYRP:MATCHHUD][SERVER][INFO] Match clock and faction kill tracking loaded.")

