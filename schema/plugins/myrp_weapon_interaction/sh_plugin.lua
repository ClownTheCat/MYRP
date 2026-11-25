PLUGIN.name = "MYRP Weapon Interaction"
PLUGIN.author = "MYRP"
PLUGIN.description = "World weapon interactions and player targeting."

local blockedWorldClasses = {
    gmod_tool = true,
    weapon_physgun = true
}

local function CanUseWorldWeapon(item)
    if (!item or !item.isWeapon or !isstring(item.class) or blockedWorldClasses[item.class]) then
        return false
    end

    if (!IsValid(item.entity) or !IsValid(item.player)) then
        return false
    end

    if (item.entity:GetClass() != "ix_item") then
        return false
    end

    return item.entity:GetPos():DistToSqr(item.player:GetPos()) <= 96 * 96
end

local function GetHands(client)
    if (!IsValid(client)) then return nil end

    local hands = client:GetWeapon("ix_hands")

    if (IsValid(hands) and hands.CanHoldObject and hands.PickupObject) then
        return hands
    end
end

local function TransferToInventory(item)
    local client = item.player
    local character = IsValid(client) and client:GetCharacter()

    if (!character) then return false end

    local inventory = character:GetInventory()

    if (!inventory) then return false end

    local success, errorMessage = item:Transfer(
        inventory:GetID(), nil, nil, client
    )

    if (!success) then
        client:NotifyLocalized(errorMessage or "unknownError")
        return false
    end

    return true
end

local function RegisterWeaponActions()
    local count = 0

    local normalizedCount = 0

    -- MYRP uses a one-slot-per-item inventory, like Minecraft.
    -- Normalize every registered item before players load their inventories.
    for _, item in pairs(ix.item.list or {}) do
        if (item.width != 1 or item.height != 1) then
            item.width = 1
            item.height = 1
            normalizedCount = normalizedCount + 1
        end
    end

    for uniqueID, item in pairs(ix.item.list or {}) do
        if (item.isWeapon and isstring(item.class)) then
            item.functions = item.functions or {}

            item.functions.myrpEquipFromWorld = {
                name = "Взять в руки",
                tip = "Поднять оружие и экипировать его",
                icon = "icon16/gun.png",

                OnCanRun = CanUseWorldWeapon,

                OnRun = function(self)
                    if (!TransferToInventory(self)) then
                        return false
                    end

                    -- If equip fails, the item remains safely in inventory.
                    self:Equip(self.player)

                    return true
                end
            }

            item.functions.myrpStoreFromWorld = {
                name = "Положить в инвентарь",
                tip = "Подобрать оружие без экипировки",
                icon = "icon16/box.png",

                OnCanRun = CanUseWorldWeapon,

                OnRun = function(self)
                    return TransferToInventory(self)
                end
            }

            item.functions.myrpGrabFromWorld = {
                name = "Grab",
                tip = "Физически поднять предмет",
                icon = "icon16/hand.png",

                OnCanRun = CanUseWorldWeapon,

                OnRun = function(self)
                    local client = self.player
                    local entity = self.entity
                    local hands = GetHands(client)

                    if (!IsValid(entity) or !hands or !hands:CanHoldObject(entity)) then
                        if (IsValid(client)) then
                            client:Notify("Не получается поднять этот предмет.")
                        end

                        return false
                    end

                    hands:PickupObject(entity)

                    -- Keep the world entity alive while it is held.
                    return false
                end
            }

            count = count + 1
        end
    end

    print("[MYRP Weapon Interaction] Normalized " .. normalizedCount .. " item(s) to 1x1; registered actions for " .. count .. " weapon items.")
end

hook.Add(
    "InitializedPlugins",
    "MYRP_WeaponInteraction_RegisterActions",
    RegisterWeaponActions
)

ix.util.Include("cl_plugin.lua", "client")

ix.util.Include("sv_plugin.lua", "server")
