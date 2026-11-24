PLUGIN.name = "MYRP Recognition Policy"
PLUGIN.author = "MYRP"
PLUGIN.description = "Always show player identities and disable F3 recognition."

function PLUGIN:InitializedPlugins()
    local recognizedCount = 0

    -- Both factions must recognize all their members automatically.
    for _, faction in pairs(ix.faction.indices or {}) do
        local factionID = string.lower(tostring(faction.uniqueID or ""))

        if factionID == "combine" or factionID == "resistance" then
            faction.isGloballyRecognized = true
            recognizedCount = recognizedCount + 1
        end
    end

    -- Remove only the Recognition plugin's F3 menu hook.
    -- Other Recognition functionality remains available.
    if SERVER then
        local recognition = ix.plugin.Get("recognition")

        if recognition then
            local hooks = HOOKS_CACHE and HOOKS_CACHE["ShowSpare1"]

            if hooks then
                hooks[recognition] = nil
            end

            recognition.ShowSpare1 = nil

            MsgN("[MYRP:RECOGNITION][INFO] F3 recognition menu disabled.")
        else
            ErrorNoHalt("[MYRP:RECOGNITION] Helix Recognition plugin not found.\n")
        end

        MsgN("[MYRP:RECOGNITION][INFO] Globally recognized factions: "
            .. recognizedCount)
    else
        MsgN("[MYRP:RECOGNITION][CLIENT] Faction recognition policy applied: "
            .. recognizedCount)
    end
end

if SERVER then
    concommand.Add("myrp_recognition_status", function(client)
        if IsValid(client) and not client:IsAdmin() then
            return
        end

        local combine = ix.faction.Get("combine")
        local resistance = ix.faction.Get("resistance")
        local recognition = ix.plugin.Get("recognition")

        local hooks = HOOKS_CACHE and HOOKS_CACHE["ShowSpare1"]
        local f3HookActive = recognition
            and hooks
            and hooks[recognition] ~= nil or false

        MsgN("[MYRP:RECOGNITION][STATUS]"
            .. " combine=" .. tostring(combine and combine.isGloballyRecognized)
            .. "; resistance=" .. tostring(resistance and resistance.isGloballyRecognized)
            .. "; F3RecognitionHook=" .. tostring(f3HookActive))
    end)
end