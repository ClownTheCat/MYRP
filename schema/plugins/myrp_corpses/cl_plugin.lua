if (not CLIENT) then return end

local function Log(message)
    MsgC(Color(115, 185, 225), "[MYRP:CORPSES][CLIENT] ",
        color_white, tostring(message) .. "\n")
end

hook.Add("ShouldPopulateEntityInfo", "MYRP_Corpses_HideDeadBotInfo", function(entity)
    if (IsValid(entity) and entity:IsPlayer() and entity:IsBot()
        and entity:GetNW2Bool("myrp_testbot_dead", false)) then
        Log("Suppressed target info for dead test bot " .. entity:Nick())
        return false
    end
end)

hook.Add("OnEntityCreated", "MYRP_Corpses_TraceRagdollCreated", function(entity)
    if (!IsValid(entity) or entity:GetClass() != "prop_ragdoll") then return end
    timer.Simple(0, function()
        if (IsValid(entity) and entity:GetNW2Bool("myrp_corpse", false)) then
            Log("Corpse received: ent=" .. entity:EntIndex()
                .. ", name=" .. entity:GetNW2String("myrp_corpse_name", "<none>"))
        end
    end)
end)

Log("Client diagnostics loaded.")
