
PLUGIN.name = "MYRP Admin Build Access"
PLUGIN.author = "MYRP"
PLUGIN.description = "Restricts spawn menu and building tools to admins and superadmins."

local function IsBuildAdmin(client)
    if not IsValid(client) or not client:IsPlayer() then
        return false
    end

    local group = client:GetUserGroup()
    return group == "admin" or group == "superadmin"
end

if SERVER then
    local function DenyBuildAction(client, action)
        if IsBuildAdmin(client) then
            return
        end

        if IsValid(client) then
            print(string.format(
                "[MYRP:ADMIN_BUILD][SERVER][DENY] player=%s steamid=%s group=%s action=%s",
                client:Nick(),
                client:SteamID(),
                client:GetUserGroup(),
                action
            ))
        end

        return false
    end

    hook.Add("CanTool", "MYRP.AdminBuildAccess.CanTool", function(client, trace, toolName)
        return DenyBuildAction(client, "tool:" .. tostring(toolName))
    end)

    -- Props are reserved for SuperAdmins; other build permissions remain unchanged.
    hook.Add("PlayerSpawnProp", "MYRP.AdminBuildAccess.PlayerSpawnProp", function(client)
        if (IsValid(client) and client:IsSuperAdmin()) then
            return
        end

        return DenyBuildAction(client, "prop")
    end)

    local spawnHooks = {
        PlayerSpawnSENT = "sent",
        PlayerSpawnNPC = "npc",
        PlayerSpawnVehicle = "vehicle",
        PlayerSpawnRagdoll = "ragdoll",
        PlayerSpawnEffect = "effect",
        PlayerSpawnSWEP = "swep",
        PlayerGiveSWEP = "give_swep"
    }

    for hookName, action in pairs(spawnHooks) do
        hook.Add(hookName, "MYRP.AdminBuildAccess." .. hookName, function(client)
            return DenyBuildAction(client, action)
        end)
    end

    print("[MYRP:ADMIN_BUILD][SERVER][INFO] Shared admin restrictions loaded")
end

if CLIENT then
    local function IsLocalBuildAdmin()
        local client = LocalPlayer()

        if not IsValid(client) then
            return false
        end

        local group = client:GetUserGroup()
        return group == "admin" or group == "superadmin"
    end

    hook.Add("SpawnMenuOpen", "MYRP.AdminBuildAccess.SpawnMenuOpen", function()
        if not IsLocalBuildAdmin() then
            print("[MYRP:ADMIN_BUILD][CLIENT][DENY] Spawn menu blocked")
            return false
        end
    end)

    hook.Add("PlayerBindPress", "MYRP.AdminBuildAccess.BlockQ", function(client, bind, pressed)
        if not pressed then return end

        if string.lower(bind) == "+menu" and not IsLocalBuildAdmin() then
            return true
        end
    end)

    print("[MYRP:ADMIN_BUILD][CLIENT][INFO] Spawn menu restrictions loaded")
end
