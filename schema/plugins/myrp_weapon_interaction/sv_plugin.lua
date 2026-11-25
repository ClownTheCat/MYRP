-- A new MYRP round starts clean: do not restore dropped world items after a server restart.
function PLUGIN:ShouldDeleteSavedItems()
    return true
end

util.AddNetworkString("MYRP_WeaponInteraction_Action")

local pendingPickups = {}

local blockedWorldClasses = {
    gmod_tool = true,
    weapon_physgun = true
}

local supportedEntityClasses = {
    item_healthkit = true,
    item_healthvial = true,
    item_battery = true,
    item_ammo_357 = true,
    item_ammo_357_large = true,
    item_ammo_ar2 = true,
    item_ammo_ar2_large = true,
    item_ammo_smg1 = true,
    item_ammo_smg1_large = true,
    item_box_buckshot = true,
    item_ammo_pistol = true,
    item_ammo_pistol_large = true,
    item_ammo_smg1_grenade = true,
    item_rpg_round = true,
    item_ammo_crossbow = true,
    item_ammo_ar2_altfire = true,
    npc_grenade_frag = true,
    combine_mine = true,
    combine_mine_resistance = true
}

local function FindWeaponItem(class)
    for uniqueID, item in pairs(ix.item.list or {}) do
        if (item.isWeapon and item.class == class) then
            return uniqueID, item
        end
    end
end

local function GetHands(client)
    local hands = client:GetWeapon("ix_hands")

    if (IsValid(hands) and hands.CanHoldObject and hands.PickupObject) then
        return hands
    end
end

local function IsWeaponEntity(entity)
    if (!IsValid(entity)) then return false end

    local class = entity:GetClass()
    if (blockedWorldClasses[class]) then return false end

    return class == "gmod_camera" or (entity.IsWeapon and entity:IsWeapon()) or string.sub(class, 1, 7) == "weapon_"
end

local function IsPhysicalWorldObject(entity)
    if (!IsValid(entity) or entity:IsPlayer() or entity:IsNPC()) then return false end
    if (entity.IsNextBot and entity:IsNextBot()) then return false end
    if (entity.IsVehicle and entity:IsVehicle()) then return false end

    local class = entity:GetClass()
    if (blockedWorldClasses[class] or class == "ix_item" or IsWeaponEntity(entity)) then return false end
    if (string.StartWith(class, "prop_vehicle") or string.StartWith(class, "vehicle_")) then return false end
    if (string.StartWith(class, "func_") or string.StartWith(class, "trigger_")) then return false end

    local model = entity:GetModel()
    if (!isstring(model) or !util.IsValidModel(model)) then return false end

    local physics = entity:GetPhysicsObject()
    return entity:GetMoveType() == MOVETYPE_VPHYSICS and IsValid(physics)
end

local function IsInventoryWorldObject(entity)
    if (!IsValid(entity)) then return false end

    local class = entity:GetClass()
    if (supportedEntityClasses[class]) then
        local model = entity:GetModel()
        return isstring(model) and util.IsValidModel(model)
    end

    return IsPhysicalWorldObject(entity)
end

local function IsHoldableEntity(entity)
    if (!IsValid(entity) or blockedWorldClasses[entity:GetClass()]) then return false end

    if (entity:GetClass() == "ix_item") then
        local item = entity:GetItemTable()
        return item and !blockedWorldClasses[item.class] and (item.isWeapon or item.uniqueID == "myrp_world_object") or false
    end

    return IsWeaponEntity(entity) or IsPhysicalWorldObject(entity)
end

local function Notify(client, message)
    if (IsValid(client)) then
        client:Notify(message)
    end
end

hook.Add("InventoryItemAdded", "MYRP_WeaponInteraction_CompletePickup", function(oldInventory, newInventory, item)
    if (!item) then return end

    local token = item:GetData("myrpPickupToken")

    if (!token) then return end

    local pending = pendingPickups[token]

    if (!pending) then return end

    pendingPickups[token] = nil

    item:SetData("myrpPickupToken", nil)

    if (IsValid(pending.entity)) then
        pending.entity.myrpWeaponInteractionPending = nil
        pending.entity:Remove()
    end

    if (pending.action == "equip" and item.isWeapon and IsValid(pending.client)) then
        if (item:Equip(pending.client) == false) then
            Notify(pending.client, "Оружие добавлено в инвентарь, но экипировать его не удалось.")
        end
    elseif (IsValid(pending.client)) then
        Notify(pending.client, pending.kind == "object" and "Предмет помещён в инвентарь." or "Оружие помещено в инвентарь.")
    end
end)

net.Receive("MYRP_WeaponInteraction_Action", function(_, client)
    local entity = net.ReadEntity()
    local action = net.ReadString()

    if (!IsValid(client) or !client:GetCharacter() or !IsValid(entity)) then
        return
    end

    -- Toolgun and physgun are never interactable world pickups.
    if (blockedWorldClasses[entity:GetClass()]) then return end

    if (client:GetPos():DistToSqr(entity:GetPos()) > 160 * 160) then
        return
    end

    local trace = client:GetEyeTrace()

    if (trace.Entity != entity) then
        return
    end

    -- Native Helix world items.
    if (entity:GetClass() == "ix_item") then
        local item = entity:GetItemTable()

        if (!item or blockedWorldClasses[item.class]) then return end

        if (item.uniqueID == "myrp_world_object") then
            if (action == "equip" or action == "store") then
                ix.item.PerformInventoryAction(client, "take", entity)
            end
            return
        end

        if (!item.isWeapon) then return end

        local actionID = ({
            equip = "myrpEquipFromWorld",
            store = "myrpStoreFromWorld",
            grab = "myrpGrabFromWorld"
        })[action]

        if (actionID) then
            ix.item.PerformInventoryAction(client, actionID, entity)
        end

        return
    end

    local class = entity:GetClass()
    local isWeapon = IsWeaponEntity(entity)
    local isWorldObject = IsInventoryWorldObject(entity)

    if (!isWeapon and !isWorldObject) then return end

    if (entity.myrpWeaponInteractionPending) then return end

    -- Physical pickup is the third action in the same menu.
    if (action == "grab") then
        local hands = GetHands(client)

        if (!IsPhysicalWorldObject(entity) or !hands or !hands:CanHoldObject(entity)) then
            Notify(client, "Не получается физически поднять это оружие.")
            return
        end

        hands:PickupObject(entity)
        return
    end

    if (action != "equip" and action != "store") then return end

    local character = client:GetCharacter()
    local inventory = character:GetInventory()

    if (!inventory) then
        Notify(client, "Инвентарь недоступен.")
        return
    end

    local uniqueID
    local data = {}

    if (isWorldObject) then
        uniqueID = "myrp_world_object"
        data.myrpWorldModel = entity:GetModel()
        data.myrpWorldName = entity.PrintName or (class == "prop_physics" and "Физический предмет" or class)
        data.myrpWorldSkin = entity:GetSkin() or 0

        if (entity:GetMaterial() != "") then
            data.myrpWorldMaterial = entity:GetMaterial()
        end
    else
        uniqueID = FindWeaponItem(class)

        if (!uniqueID) then
            Notify(client, "Для этого оружия пока нет предмета Helix: " .. class)
            return
        end

        local clip = entity.Clip1 and entity:Clip1() or -1
        if (clip >= 0) then
            data.ammo = clip
        end
    end

    local token = util.CRC(
        tostring(SysTime()) .. client:SteamID64() .. tostring(entity:EntIndex())
    )

    data.myrpPickupToken = token

    pendingPickups[token] = {
        entity = entity,
        client = client,
        action = action,
        kind = isWorldObject and "object" or "weapon"
    }

    entity.myrpWeaponInteractionPending = token

    local x, y, inventoryID = inventory:Add(uniqueID, 1, data)

    if (!x or !y or !inventoryID) then
        pendingPickups[token] = nil
        entity.myrpWeaponInteractionPending = nil
        Notify(client, "Не удалось подобрать оружие. Возможно, в инвентаре нет места.")
        return
    end
end)

-- MYRP_WeaponInteraction_PhysicalHold
util.AddNetworkString("MYRP_WeaponInteraction_Hold")

local heldWeapons = {}

local function SendHoldStatus(client, status)
    if (!IsValid(client)) then return end

    net.Start("MYRP_WeaponInteraction_Hold")
        net.WriteString(status)
    net.Send(client)
end

local function ReleaseWeaponHold(client, shouldThrow)
    local state = heldWeapons[client]
    heldWeapons[client] = nil

    if (!state) then
        SendHoldStatus(client, "released")
        return
    end

    local hands = state.hands

    if (IsValid(hands) and hands:IsHoldingObject()) then
        if (shouldThrow == true) then
            -- Helix's default throw force can be too weak for some weapon physics objects.
            -- Drop normally, then give the released physics object a clear forward velocity.
            local physics = hands:GetHeldPhysicsObject()
            local throwDirection = IsValid(client) and client:GetAimVector() or vector_origin

            hands:DropObject(false)

            if (IsValid(physics)) then
                physics:Wake()
                physics:SetVelocityInstantaneous(throwDirection * 900)
            end
        else
            hands:DropObject(false)
        end
    end

    if (IsValid(client) and client:Alive() and state.previousWeapon and state.previousWeapon != "ix_hands") then
        timer.Simple(0, function()
            if (IsValid(client) and client:Alive() and client:HasWeapon(state.previousWeapon)) then
                client:SelectWeapon(state.previousWeapon)
            end
        end)
    end

    SendHoldStatus(client, "released")
end

-- Allow Helix hands to use their native physics controller for dropped weapons.
hook.Add("CanPlayerHoldObject", "MYRP_WeaponInteraction_AllowWeapons", function(client, entity)
    if (IsValid(entity) and blockedWorldClasses[entity:GetClass()]) then
        return false
    end

    if (IsHoldableEntity(entity)) then
        return true
    end
end)

net.Receive("MYRP_WeaponInteraction_Hold", function(_, client)
    local operation = net.ReadString()

    if (!IsValid(client)) then return end

    if (operation == "release" or operation == "throw") then
        ReleaseWeaponHold(client, operation == "throw")
        return
    end

    if (operation != "start") then return end

    local entity = net.ReadEntity()

    if (!client:Alive() or !client:GetCharacter() or !IsValid(entity)) then
        SendHoldStatus(client, "failed")
        return
    end

    if (heldWeapons[client] or IsValid(entity.ixHeldOwner)) then
        SendHoldStatus(client, "failed")
        return
    end

    if (client:GetPos():DistToSqr(entity:GetPos()) > 160 * 160) then
        SendHoldStatus(client, "failed")
        return
    end

    if (client:GetEyeTrace().Entity != entity or entity.myrpWeaponInteractionPending
        or blockedWorldClasses[entity:GetClass()]) then
        SendHoldStatus(client, "failed")
        return
    end

    if (!IsHoldableEntity(entity)) then
        SendHoldStatus(client, "failed")
        return
    end

    local hands = GetHands(client)

    if (!hands or !hands:CanHoldObject(entity)) then
        Notify(client, "Этот предмет нельзя физически поднять.")
        SendHoldStatus(client, "failed")
        return
    end

    local activeWeapon = client:GetActiveWeapon()
    local previousWeapon = IsValid(activeWeapon) and activeWeapon:GetClass() or nil

    -- ix_hands:Deploy() calls DropObject(). Switch to hands BEFORE PickupObject,
    -- otherwise Deploy immediately drops the object we just picked up.
    local state = {
        entity = entity,
        hands = hands,
        previousWeapon = previousWeapon
    }

    heldWeapons[client] = state
    client:SelectWeapon("ix_hands")

    timer.Simple(0, function()
        if (heldWeapons[client] != state) then return end

        if (!IsValid(client) or !client:Alive() or !IsValid(entity) or !IsValid(hands)) then
            heldWeapons[client] = nil
            SendHoldStatus(client, "failed")
            return
        end

        if (client:GetActiveWeapon() != hands or !hands:CanHoldObject(entity)) then
            heldWeapons[client] = nil

            if (client:HasWeapon(previousWeapon or "") and previousWeapon != "ix_hands") then
                client:SelectWeapon(previousWeapon)
            end

            SendHoldStatus(client, "failed")
            return
        end

        hands:PickupObject(entity)

        if (!hands:IsHoldingObject()) then
            heldWeapons[client] = nil

            if (previousWeapon and previousWeapon != "ix_hands" and client:HasWeapon(previousWeapon)) then
                client:SelectWeapon(previousWeapon)
            end

            SendHoldStatus(client, "failed")
            return
        end

        SendHoldStatus(client, "started")
    end)
end)

-- Do not let weapon switching holster ix_hands while an object is held.
hook.Add("PlayerSwitchWeapon", "MYRP_WeaponInteraction_LockHands", function(client, oldWeapon, newWeapon)
    if (heldWeapons[client] and IsValid(oldWeapon) and oldWeapon:GetClass() == "ix_hands") then
        return true
    end
end)

hook.Add("PlayerDeath", "MYRP_WeaponInteraction_ReleaseOnDeath", function(client)
    ReleaseWeaponHold(client, false)
end)

hook.Add("PlayerDisconnected", "MYRP_WeaponInteraction_ReleaseOnDisconnect", function(client)
    ReleaseWeaponHold(client, false)
end)
