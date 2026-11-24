local samples = {}

local function Log(client, event, extra)
    if not IsValid(client) then return end

    print(string.format(
        "[MYRP:NOCLIP][%s] player=%s steamid=%s pos=%s velocity=%s movetype=%s alive=%s %s",
        event,
        client:Nick(),
        client:SteamID(),
        tostring(client:GetPos()),
        tostring(client:GetVelocity()),
        tostring(client:GetMoveType()),
        tostring(client:Alive()),
        extra or ""
    ))
end

hook.Add("PlayerNoClip", "MYRP.NoclipDebug.Toggle", function(client, desiredState)
    if not IsValid(client) then return end

    Log(client, "TOGGLE_REQUEST", "desiredState=" .. tostring(desiredState))

    return nil
end)

hook.Add("PlayerSpawn", "MYRP.NoclipDebug.Spawn", function(client)
    Log(client, "PLAYER_SPAWN")
end)

hook.Add("PlayerDeath", "MYRP.NoclipDebug.Death", function(client)
    Log(client, "PLAYER_DEATH")
end)

hook.Add("Think", "MYRP.NoclipDebug.Tracker", function()
    for _, client in ipairs(player.GetAll()) do
        if not IsValid(client) then continue end

        local currentMoveType = client:GetMoveType()
        local isNoclip = currentMoveType == MOVETYPE_NOCLIP
        local data = samples[client]

        if not data then
            data = {
                wasNoclip = isNoclip,
                lastPosition = client:GetPos(),
                lastSample = 0
            }

            samples[client] = data
        end

        if isNoclip then
            if CurTime() - data.lastSample >= 0.5 then
                data.lastPosition = client:GetPos()
                data.lastSample = CurTime()

                Log(client, "IN_NOCLIP")
            end
        end

        if data.wasNoclip and not isNoclip then
            Log(
                client,
                "NOCLIP_EXIT",
                "lastNoclipPos=" .. tostring(data.lastPosition)
            )

            print(string.format(
                "[MYRP:NOCLIP][POSITION_DELTA] player=%s distance=%.2f",
                client:Nick(),
                client:GetPos():Distance(data.lastPosition)
            ))
        end

        if not data.wasNoclip and isNoclip then
            Log(client, "NOCLIP_ENTER")
        end

        data.wasNoclip = isNoclip
    end
end)

hook.Add("PlayerDisconnected", "MYRP.NoclipDebug.Cleanup", function(client)
    samples[client] = nil
end)

print("[MYRP:NOCLIP][INFO] Noclip diagnostics loaded.")
