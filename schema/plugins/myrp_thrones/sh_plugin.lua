local PLUGIN = PLUGIN

PLUGIN.name = "MYRP Thrones"
PLUGIN.author = "MYRP"
PLUGIN.description = "Faction radio locators with map-specific persistence."

ix.util.Include(PLUGIN.folder .. "/cl_throne_ui.lua", "client")

if SERVER then
    util.AddNetworkString("MYRP_Thrones_Victory")
    util.AddNetworkString("MYRP_Thrones_Reset")
    local THRONES = {
        combine = {
            class = "myrp_throne_combine",
            label = "COMBINE"
        },

        resistance = {
            class = "myrp_throne_resistance",
            label = "RESISTANCE"
        }
    }

    local function DescribeDamageEntity(entity)
        if not IsValid(entity) then
            return "NULL"
        end

        local result = entity:GetClass() .. "#" .. entity:EntIndex()

        if entity:IsPlayer() then
            result = result .. "[" .. entity:Nick() .. "]"
        end

        return result
    end

    local function GetAttackerFaction(entity, depth, visited)
        depth = depth or 0
        visited = visited or {}

        if depth > 5 or not IsValid(entity) then
            return nil
        end

        if visited[entity] then
            return nil
        end

        visited[entity] = true

        if isstring(entity.ixMYRPTestBotFaction) then
            return string.lower(entity.ixMYRPTestBotFaction)
        end

        if entity:IsPlayer() then
            local factionData = ix.faction.indices[entity:Team()]

            if factionData and factionData.uniqueID then
                return factionData.uniqueID
            end

            local character = entity:GetCharacter()

            if character then
                local characterFaction = ix.faction.indices[character:GetFaction()]

                if characterFaction and characterFaction.uniqueID then
                    return characterFaction.uniqueID
                end
            end
        end

        local ownerMethods = {
            "GetOwner",
            "GetCreator",
            "CPPIGetOwner",
            "GetParent"
        }

        for _, methodName in ipairs(ownerMethods) do
            local method = entity[methodName]

            if isfunction(method) then
                local success, owner = pcall(method, entity)

                if success and IsValid(owner) and owner ~= entity then
                    local faction = GetAttackerFaction(owner, depth + 1, visited)

                    if faction then
                        return faction
                    end
                end
            end
        end

        return nil
    end

    local THRONE_MATCHRESET_DELAY = 15

    local function StartThroneVictory(destroyedFaction, entity)
        if PLUGIN._throneVictoryStarted then
            return
        end

        PLUGIN._throneVictoryStarted = true

        local winnerFaction = destroyedFaction == "combine"
            and "resistance"
            or "combine"

        local origin = IsValid(entity)
            and entity:WorldSpaceCenter()
            or vector_origin

        MsgN("[MYRP:THRONES] ========================================")
        MsgN("[MYRP:THRONES] THRONE DESTROYED: " .. destroyedFaction)
        MsgN("[MYRP:THRONES] WINNER: " .. winnerFaction)
        MsgN("[MYRP:THRONES] New match in " .. THRONE_MATCHRESET_DELAY .. " seconds.")
        MsgN("[MYRP:THRONES] ========================================")

        local explosion = EffectData()
        explosion:SetOrigin(origin)
        util.Effect("HelicopterMegaBomb", explosion, true, true)

        local sparks = EffectData()
        sparks:SetOrigin(origin)
        sparks:SetNormal(Vector(0, 0, 1))
        sparks:SetMagnitude(8)
        sparks:SetScale(4)
        util.Effect("ManhackSparks", sparks, true, true)

        local debrisSparks = EffectData()
        debrisSparks:SetOrigin(origin)
        debrisSparks:SetNormal(Vector(0, 0, 1))
        debrisSparks:SetMagnitude(10)
        debrisSparks:SetScale(5)
        util.Effect("Sparks", debrisSparks, true, true)

        util.ScreenShake(origin, 18, 8, 2.5, 10000)

        if IsValid(entity) then
            entity:EmitSound("ambient/explosions/explode_8.wav", 100, 95, 1)
        end

        net.Start("MYRP_Thrones_Victory")
            net.WriteString(winnerFaction)
            net.WriteUInt(THRONE_MATCHRESET_DELAY, 8)
        net.Broadcast()

        if IsValid(entity) then
            timer.Simple(0.35, function()
                if IsValid(entity) then
                    entity:Remove()
                end
            end)
        end

        timer.Remove("MYRP_Thrones_AutoRestart")
        timer.Remove("MYRP_Thrones_AutoReset")

        timer.Create("MYRP_Thrones_AutoReset", THRONE_MATCHRESET_DELAY, 1, function()
            local started = hook.Run("MYRP_MatchResetStart", "throne", winnerFaction)

            if started ~= true then
                ErrorNoHalt("[MYRP:THRONES] MatchReset plugin did not accept the reset request. Restoring thrones.\n")

                PLUGIN._throneVictoryStarted = nil
                timer.Remove("MYRP_Thrones_AutoReset")

                net.Start("MYRP_Thrones_Reset")
                net.Broadcast()

                timer.Simple(0.5, function()
                    if PLUGIN and PLUGIN.RestoreSavedThrones then
                        PLUGIN:RestoreSavedThrones()
                    end
                end)
            end
        end)
    end
    function PLUGIN:EntityTakeDamage(target, damageInfo)
        if not IsValid(target) then
            return
        end

        local class = target:GetClass()
        local targetFaction

        if class == "myrp_throne_combine" then
            targetFaction = "combine"
        elseif class == "myrp_throne_resistance" then
            targetFaction = "resistance"
        else
            return
        end

        -- Once a throne has been destroyed, no more damage is processed.
        if PLUGIN._throneVictoryStarted or target._myrpDestroying then
            damageInfo:SetDamage(0)
            return true
        end

        local attacker = damageInfo:GetAttacker()
        local inflictor = damageInfo:GetInflictor()
        local weapon = damageInfo:GetWeapon()

        local attackerFaction = GetAttackerFaction(attacker)

        if not attackerFaction then
            attackerFaction = GetAttackerFaction(inflictor)
        end

        if not attackerFaction then
            attackerFaction = GetAttackerFaction(weapon)
        end

        local enemyFaction = targetFaction == "combine"
            and "resistance"
            or "combine"

        -- Friendly fire and unidentified damage are blocked.
        if attackerFaction ~= enemyFaction then
            damageInfo:SetDamage(0)
            damageInfo:SetDamageForce(vector_origin)
            return true
        end

        local incomingDamage = math.max(0, damageInfo:GetDamage())
        local currentHealth = target:Health()
        local maxHealth = target:GetMaxHealth()

        if incomingDamage <= 0 or currentHealth <= 0 then
            damageInfo:SetDamage(0)
            return true
        end

        local appliedDamage = math.min(incomingDamage, currentHealth)
        local newHealth = math.max(0, currentHealth - appliedDamage)

        -- Custom health system: apply damage exactly once.
        target:SetHealth(newHealth)
        target:SetNWInt("myrpThroneHealth", newHealth)
        target:SetNWInt("myrpThroneMaxHealth", maxHealth)

        -- Block the engine's regular damage application.
        damageInfo:SetDamage(0)
        damageInfo:SetDamageForce(vector_origin)

        local now = CurTime()

        -- Short metallic impact effects with throttling.
        if now >= (target._myrpNextHitEffect or 0) then
            target._myrpNextHitEffect = now + 0.12

            local normal = damageInfo:GetDamageForce()

            if normal:LengthSqr() < 0.01 then
                normal = Vector(0, 0, 1)
            else
                normal = normal:GetNormalized()
            end

            local impact = EffectData()
            impact:SetOrigin(target:WorldSpaceCenter())
            impact:SetNormal(normal)
            util.Effect("MetalSpark", impact, true, true)

            if appliedDamage >= 250 then
                local heavyImpact = EffectData()
                heavyImpact:SetOrigin(target:WorldSpaceCenter())
                heavyImpact:SetNormal(normal)
                heavyImpact:SetMagnitude(5)
                heavyImpact:SetScale(2)
                util.Effect("ManhackSparks", heavyImpact, true, true)
            end

            target:EmitSound(
                "physics/metal/metal_box_impact_bullet1.wav",
                78,
                math.random(90, 108),
                0.7
            )
        end

        -- Extra electrical sparks while critically damaged.
        if newHealth > 0
            and newHealth <= maxHealth * 0.20
            and now >= (target._myrpNextCriticalEffect or 0) then

            target._myrpNextCriticalEffect = now + 0.75

            local critical = EffectData()
            critical:SetOrigin(target:WorldSpaceCenter())
            critical:SetNormal(Vector(0, 0, 1))
            critical:SetMagnitude(3)
            critical:SetScale(1.5)
            util.Effect("ElectricSpark", critical, true, true)
        end

        MsgN(string.format(
            "[MYRP:THRONES] Damage applied: %s | %d | HP %d/%d",
            targetFaction,
            appliedDamage,
            newHealth,
            maxHealth
        ))

        -- The other faction wins when this throne reaches zero HP.
        if newHealth <= 0 then
            target._myrpDestroying = true
            StartThroneVictory(targetFaction, target)
        end

        return true
    end
    local function Reply(client, message)
        if IsValid(client) then
            client:ChatPrint(message)
        else
            MsgN(message)
        end
    end

    local function Log(message)
        MsgN("[MYRP:THRONES] " .. tostring(message))
    end

    function PLUGIN:GetSavedThroneData()
        -- Force disk read because Helix's ix.data cache is not map-specific.
        local data = self:GetData({}, false, false, true)

        if not istable(data) then
            return {}
        end

        return data
    end

    function PLUGIN:SaveThronePosition(faction, entity)
        if not IsValid(entity) then
            return false
        end

        local data = self:GetSavedThroneData()

        data[faction] = {
            position = entity:GetPos(),
            angles = entity:GetAngles()
        }

        -- Save under this schema and the current map.
        self:SetData(data, false, false)

        return true
    end

    function PLUGIN:SaveAllThronePositions()
        local data = self:GetSavedThroneData()
        local entities = {}

        -- First validate both entities. Do not partially overwrite saved data.
        for faction, definition in pairs(THRONES) do
            local entity = self:GetThroneEntity(faction)

            if not IsValid(entity) then
                return false, "Missing throne: " .. faction
            end

            entities[faction] = entity
        end

        -- Update both positions in one data write.
        for faction, entity in pairs(entities) do
            data[faction] = {
                position = entity:GetPos(),
                angles = entity:GetAngles()
            }
        end

        self:SetData(data, false, false)

        return true
    end
    function PLUGIN:GetThroneEntity(faction)
        local definition = THRONES[faction]

        if not definition then
            return nil
        end

        local found

        -- Keep one entity per faction and remove accidental duplicates.
        for _, entity in ipairs(ents.FindByClass(definition.class)) do
            if not IsValid(found) then
                found = entity
            else
                entity:Remove()
                Log("Removed duplicate entity: " .. definition.class)
            end
        end

        return found
    end

    hook.Add("PhysgunPickup", "MYRP.Thrones.AdminPhysgunPickup", function(client, entity)
        if not IsValid(entity) then
            return
        end

        local class = entity:GetClass()

        if class ~= THRONES.combine.class and class ~= THRONES.resistance.class then
            return
        end

        return IsValid(client) and client:IsAdmin()
    end)

    hook.Add("PhysgunDrop", "MYRP.Thrones.AdminPhysgunDrop", function(client, entity)
        if not IsValid(entity) then
            return
        end

        local class = entity:GetClass()

        if class ~= THRONES.combine.class and class ~= THRONES.resistance.class then
            return
        end

        local physicsObject = entity:GetPhysicsObject()

        if IsValid(physicsObject) then
            physicsObject:EnableMotion(false)
            physicsObject:Sleep()
        end
    end)
    function PLUGIN:PlaceThrone(faction, hitPosition, angles)
        local definition = THRONES[faction]

        if not definition then
            return nil, "Unknown faction."
        end

        local entity = self:GetThroneEntity(faction)
        local wasExisting = IsValid(entity)

        if not wasExisting then
            entity = ents.Create(definition.class)

            if not IsValid(entity) then
                return nil, "Could not create " .. definition.class
            end

            entity:SetPos(hitPosition)
            entity:SetAngles(angles)
            entity:Spawn()
            entity:Activate()
        else
            entity:SetAngles(angles)
        end

        if not IsValid(entity) then
            return nil, "Entity became invalid during creation."
        end

        -- Place the entity's bottom on the traced surface.
        local mins = entity:OBBMins()
        local finalPosition = hitPosition - Vector(0, 0, mins.z)

        entity:SetPos(finalPosition)

        local physicsObject = entity:GetPhysicsObject()

        if IsValid(physicsObject) then
            physicsObject:EnableMotion(false)
            physicsObject:Sleep()
        end

        self:SaveThronePosition(faction, entity)

        Log(string.format(
            "%s throne %s at %s",
            faction,
            wasExisting and "moved" or "placed",
            tostring(entity:GetPos())
        ))

        return entity, wasExisting
    end

    function PLUGIN:RestoreSavedThrones()
        local data = self:GetSavedThroneData()
        local restored = 0

        for faction, definition in pairs(THRONES) do
            local saved = data[faction]

            if istable(saved)
                and isvector(saved.position)
                and isangle(saved.angles) then

                local entity = self:GetThroneEntity(faction)

                if not IsValid(entity) then
                    entity = ents.Create(definition.class)

                    if IsValid(entity) then
                        entity:SetPos(saved.position)
                        entity:SetAngles(saved.angles)
                        entity:Spawn()
                        entity:Activate()
                    end
                else
                    entity:SetAngles(saved.angles)
                    entity:SetPos(saved.position)
                end

                if IsValid(entity) then
                    local physicsObject = entity:GetPhysicsObject()

                    if IsValid(physicsObject) then
                        physicsObject:EnableMotion(false)
                        physicsObject:Sleep()
                    end

                    restored = restored + 1
                    Log("Restored " .. faction .. " throne.")
                else
                    Log("ERROR: Could not restore " .. faction .. " throne.")
                end
            end
        end

        Log("Restore complete. Entities restored: " .. restored)
    end

    -- Restore after plugin initialization and map entity initialization.
    local function ScheduleThroneRestore(source)
        timer.Remove("MYRP_Thrones_Restore")

        timer.Create("MYRP_Thrones_Restore", 5, 1, function()
            local pendingReset = ix.data.Get("myrp_matchreset_pending", false, false, true)

            if istable(pendingReset) and pendingReset.active == true then
                Log("Skipping standard throne restore; pending round reset is handled by MatchReset.")
                return
            end

            if not PLUGIN or not PLUGIN.RestoreSavedThrones then
                Log("ERROR: Plugin unavailable during restore.")
                return
            end

            PLUGIN:RestoreSavedThrones()
        end)

        Log("Restore scheduled via " .. tostring(source) .. ".")
    end

    hook.Add("MYRP_MatchResetMapReady", "MYRP.Thrones.ResetForNewRound", function()
        timer.Remove("MYRP_Thrones_AutoRestart")
        timer.Remove("MYRP_Thrones_AutoReset")
        timer.Remove("MYRP_Thrones_Restore")

        PLUGIN._throneVictoryStarted = nil
        file.Delete("myrp/throne_restart.txt")

        -- Replace both custom entities so health, network values and all
        -- transient destruction flags are guaranteed to return to defaults.
        for _, definition in pairs(THRONES) do
            for _, entity in ipairs(ents.FindByClass(definition.class)) do
                if IsValid(entity) then
                    entity:Remove()
                end
            end
        end

        timer.Simple(0.1, function()
            if PLUGIN and PLUGIN.RestoreSavedThrones then
                PLUGIN:RestoreSavedThrones()
            end
        end)

        MsgN("[MYRP:THRONES] Round state cleared; fresh throne entities scheduled.")
        return true
    end)

    hook.Add("MYRP_MatchResetAborted", "MYRP.Thrones.RestoreAfterAbort", function(reason)
        timer.Remove("MYRP_Thrones_AutoRestart")
        timer.Remove("MYRP_Thrones_AutoReset")
        PLUGIN._throneVictoryStarted = nil
        file.Delete("myrp/throne_restart.txt")

        net.Start("MYRP_Thrones_Reset")
        net.Broadcast()

        timer.Simple(0.1, function()
            if PLUGIN and PLUGIN.RestoreSavedThrones then
                PLUGIN:RestoreSavedThrones()
            end
        end)

        MsgN("[MYRP:THRONES] Victory state cleared after reset abort: " .. tostring(reason))
    end)
    function PLUGIN:InitializedPlugins()
        ScheduleThroneRestore("InitializedPlugins")
    end

    function PLUGIN:InitPostEntity()
        ScheduleThroneRestore("InitPostEntity")
    end
    concommand.Add("myrp_thrones_restore", function(client)
        if IsValid(client) and not client:IsAdmin() then
            Reply(client, "[MYRP:THRONES] Admin access required.")
            return
        end

        PLUGIN:RestoreSavedThrones()
    end)
    concommand.Add("myrp_throne_testdamage", function(client, command, arguments)
        if not IsValid(client) or not client:IsAdmin() then
            Reply(client, "[MYRP:THRONES] Admin access required.")
            return
        end

        local targetFaction = string.lower(tostring(arguments[1] or ""))
        local amount = math.Clamp(tonumber(arguments[2]) or 1000, 1, 5000)

        if targetFaction ~= "combine" and targetFaction ~= "resistance" then
            Reply(client, "Usage: myrp_throne_testdamage combine/resistance [amount]")
            return
        end

        local entity = PLUGIN:GetThroneEntity(targetFaction)

        if not IsValid(entity) then
            Reply(client, "[MYRP:THRONES] Target throne not found.")
            return
        end

        local simulatedFaction = targetFaction == "combine" and "resistance" or "combine"
        local previousFaction = client.ixMYRPTestBotFaction

        client.ixMYRPTestBotFaction = simulatedFaction

        local damageInfo = DamageInfo()
        damageInfo:SetDamage(amount)
        damageInfo:SetDamageType(DMG_GENERIC)
        damageInfo:SetAttacker(client)
        damageInfo:SetInflictor(client)

        local success, err = pcall(function()
            entity:TakeDamageInfo(damageInfo)
        end)

        client.ixMYRPTestBotFaction = previousFaction

        if not success then
            Reply(client, "[MYRP:THRONES] Test damage error: " .. tostring(err))
            return
        end

        timer.Simple(0.1, function()
            if IsValid(client) and IsValid(entity) then
                Reply(client, string.format(
                    "[MYRP:THRONES] Test hit: %s | HP: %d/%d",
                    targetFaction,
                    entity:Health(),
                    entity:GetMaxHealth()
                ))
            end
        end)
    end)
    concommand.Add("myrp_thrones_save", function(client)
        if IsValid(client) and not client:IsAdmin() then
            Reply(client, "[MYRP:THRONES] Admin access required.")
            return
        end

        local success, reason = PLUGIN:SaveAllThronePositions()

        if not success then
            Reply(client, "[MYRP:THRONES] Save failed: " .. tostring(reason))
            return
        end

        Reply(client, "[MYRP:THRONES] Both throne positions saved successfully.")
        Log("Both throne positions saved by " .. (IsValid(client) and client:Nick() or "console") .. ".")
    end)
    concommand.Add("myrp_thrones_status", function(client)
        if IsValid(client) and not client:IsAdmin() then
            Reply(client, "[MYRP:THRONES] Admin access required.")
            return
        end

        local data = PLUGIN:GetSavedThroneData()

        MsgN("========== MYRP THRONES STATUS ==========")

        for faction, definition in pairs(THRONES) do
            local entity = PLUGIN:GetThroneEntity(faction)

            if IsValid(entity) then
                MsgN(string.format(
                    "%s: PRESENT | HP: %s/%s | Position: %s",
                    faction,
                    tostring(entity:Health()),
                    tostring(entity:GetMaxHealth()),
                    tostring(entity:GetPos())
                ))
            elseif istable(data[faction]) then
                MsgN(string.format(
                    "%s: MISSING | Saved position: %s",
                    faction,
                    tostring(data[faction].position)
                ))
            else
                MsgN(faction .. ": NOT PLACED")
            end
        end

        MsgN("==========================================")
    end)

    Log("Plugin server-side logic loaded.")
end