PLUGIN.name = "MYRP Noclip Fix"
PLUGIN.author = "MYRP"
PLUGIN.description = "Permanently disables observer teleport-back on noclip exit."

if SERVER then
    function PLUGIN:InitializedPlugins()
        local observer = ix.plugin.Get("observer")
        local hooks = HOOKS_CACHE and HOOKS_CACHE["PlayerNoClip"]

        if not observer or not hooks or not isfunction(hooks[observer]) then
            ErrorNoHalt("[MYRP:NOCLIP] Could not find Helix Observer PlayerNoClip hook.\n")
            return
        end

        if observer.myrpNoClipFixApplied then
            return
        end

        local original = hooks[observer]
        observer.myrpNoClipFixApplied = true

        hooks[observer] = function(plugin, client, state, ...)
            if state == false and IsValid(client) and client:IsPlayer() then
                local steamID64 = client:SteamID64()

                ix.option.clients = ix.option.clients or {}
                ix.option.clients[steamID64] = ix.option.clients[steamID64] or {}

                ix.option.clients[steamID64].observerTeleportBack = false

                MsgN("[MYRP:NOCLIP][INFO] Teleport-back disabled for "
                    .. client:SteamName())
            end

            return original(plugin, client, state, ...)
        end

        MsgN("[MYRP:NOCLIP][INFO] Permanent Observer fix installed.")
    end

    concommand.Add("myrp_noclip_fix_status", function(client)
        if IsValid(client) and not client:IsAdmin() then return end

        local observer = ix.plugin.Get("observer")

        MsgN("[MYRP:NOCLIP][STATUS] installed="
            .. tostring(observer and observer.myrpNoClipFixApplied == true))
    end)
end