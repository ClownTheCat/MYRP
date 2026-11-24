util.AddNetworkString("MYRP_WeaponInteraction_Action")

local pendingPickups = {}

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

    if (pending.action == "equip" and IsValid(pending.client)) then
        if (item:Equip(pending.client) == false) then
            Notify(pending.client, "Оружие добавлено в инвентарь, но экипировать его не удалось.")
        end
    elseif (IsValid(pending.client)) then
        Notify(pending.client, "Оружие помещено в инвентарь.")
    end
end)

net.Receive("MYRP_WeaponInteraction_Action", function(_, client)
    local entity = net.ReadEntity()
    local action = net.ReadString()

    if (!IsValid(client) or !client:GetCharacter() or !IsValid(entity)) then
        return
    end

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

        if (!item or !item.isWeapon) then return end

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
    local isWeapon = (entity.IsWeapon and entity:IsWeapon()) or string.sub(class, 1, 7) == "weapon_"

    if (!isWeapon) then return end

    if (entity.myrpWeaponInteractionPending) then return end

    -- Physical pickup is the third action in the same menu.
    if (action == "grab") then
        local hands = GetHands(client)

        if (!hands or !hands:CanHoldObject(entity)) then
            Notify(client, "Не получается физически поднять это оружие.")
            return
        end

        hands:PickupObject(entity)
        return
    end

    if (action != "equip" and action != "store") then return end

    local uniqueID = FindWeaponItem(class)

    if (!uniqueID) then
        Notify(client, "Для этого оружия пока нет предмета Helix: " .. class)
        return
    end

    local character = client:GetCharacter()
    local inventory = character:GetInventory()

    if (!inventory) then
        Notify(client, "Инвентарь недоступен.")
        return
    end

    local data = {}
    local clip = entity.Clip1 and entity:Clip1() or -1

    if (clip >= 0) then
        data.ammo = clip
    end

    local token = util.CRC(
        tostring(SysTime()) .. client:SteamID64() .. tostring(entity:EntIndex())
    )

    data.myrpPickupToken = token

    pendingPickups[token] = {
        entity = entity,
        client = client,
        action = action
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
        hands:DropObject(shouldThrow == true)
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
    if (!IsValid(entity)) then return end

    local class = entity:GetClass()
    if ((entity.IsWeapon and entity:IsWeapon()) or string.sub(class, 1, 7) == "weapon_") then
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

    if (client:GetEyeTrace().Entity != entity or entity.myrpWeaponInteractionPending) then
        SendHoldStatus(client, "failed")
        return
    end

    local isWeapon = entity:GetClass() == "ix_item"

    if (isWeapon) then
        local item = entity:GetItemTable()
        isWeapon = item and item.isWeapon
    else
        isWeapon = (entity.IsWeapon and entity:IsWeapon())
            or string.sub(entity:GetClass(), 1, 7) == "weapon_"
    end

    if (!isWeapon) then
        SendHoldStatus(client, "failed")
        return
    end

    local hands = GetHands(client)

    if (!hands or !hands:CanHoldObject(entity)) then
        Notify(client, "Это оружие нельзя физически поднять.")
        SendHoldStatus(client, "failed")
        return
    end

    local activeWeapon = client:GetActiveWeapon()
    local previousWeapon = IsValid(activeWeapon) and activeWeapon:GetClass() or nil

    hands:PickupObject(entity)

    if (!hands:IsHoldingObject()) then
        SendHoldStatus(client, "failed")
        return
    end

    heldWeapons[client] = {
        entity = entity,
        hands = hands,
        previousWeapon = previousWeapon
    }

    client:SelectWeapon("ix_hands")
    SendHoldStatus(client, "started")
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
