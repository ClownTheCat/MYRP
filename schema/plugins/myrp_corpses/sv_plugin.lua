if (not SERVER) then return end

local CORPSE_INVENTORY = "myrp_corpse"
local BOT_INVENTORY = "myrp_testbot"
local CORPSE_LIFETIME = 300
local USE_DISTANCE = 112

ix.inventory.Register(CORPSE_INVENTORY, 10, 10)
ix.inventory.Register(BOT_INVENTORY, 10, 10)

local function IsTestBot(client)
    return IsValid(client) and client:IsPlayer() and client:IsBot()
        and client.ixMYRPTestBot == true
end

local function DeleteTemporaryInventory(inventory)
    if (not inventory or not inventory.GetID) then return end

    local id = inventory:GetID()

    if (inventory.storageInfo) then
        ix.storage.Close(inventory)
    end

    for _, item in pairs(inventory:GetItems(true)) do
        if (item and item.Remove) then
            item:Remove()
        end
    end

    mysql:Delete("ix_inventories")
        :Where("inventory_id", id)
        :Execute()

    ix.item.inventories[id] = nil
end

local function CreateBotInventory(bot)
    if (not IsTestBot(bot) or not bot:Alive() or bot.ixMYRPTestInventoryCreating) then
        return
    end

    if (bot.ixMYRPTestInventory) then
        DeleteTemporaryInventory(bot.ixMYRPTestInventory)
        bot.ixMYRPTestInventory = nil
    end

    bot.ixMYRPTestInventoryCreating = true

    ix.inventory.New(nil, BOT_INVENTORY, function(inventory)
        if (not IsValid(bot) or not IsTestBot(bot) or not bot:Alive()) then
            if (IsValid(bot)) then
                bot.ixMYRPTestInventoryCreating = nil
            end

            DeleteTemporaryInventory(inventory)
            return
        end

        bot.ixMYRPTestInventory = inventory
        bot.ixMYRPTestInventoryCreating = nil

        local added = inventory:Add("smg1")

        if (not added) then
            print("[MYRP:CORPSES] Не удалось выдать тестовый предмет SMG боту " .. bot:Nick())
        else
            print("[MYRP:CORPSES] Выдан тестовый предмет SMG боту " .. bot:Nick())
        end
    end)
end

local function GetSourceInventory(client)
    if (IsTestBot(client)) then
        return client.ixMYRPTestInventory
    end

    local character = client:GetCharacter()

    return character and character:GetInventory() or nil
end

local function MoveInventoryToCorpse(client, ragdoll)
    if (not IsValid(client) or not IsValid(ragdoll) or ragdoll.ixMYRPCorpseInventoryCreating) then
        return
    end

    local source = GetSourceInventory(client)

    if (not source) then
        return
    end

    ragdoll.ixMYRPCorpseInventoryCreating = true
    ragdoll.ixMYRPCorpseOwner = client

    ix.inventory.New(nil, CORPSE_INVENTORY, function(corpseInventory)
        if (not IsValid(ragdoll)) then
            DeleteTemporaryInventory(corpseInventory)
            return
        end

        ragdoll.ixMYRPCorpseInventory = corpseInventory
        ragdoll:SetUseType(SIMPLE_USE)

        local items = source:GetItems(true)
        local moved = 0
        local failed = 0

        for _, item in pairs(items) do
            if (item and item.Transfer and item.invID == source:GetID()) then
                local success = item:Transfer(corpseInventory:GetID(), nil, nil, client)

                if (success) then
                    moved = moved + 1
                else
                    failed = failed + 1
                    print("[MYRP:CORPSES] Не удалось перенести предмет " .. tostring(item.uniqueID)
                        .. " с игрока " .. client:Nick() .. " в инвентарь трупа.")
                end
            end
        end

        if (IsTestBot(client)) then
            client.ixMYRPTestInventory = nil
        end

        print("[MYRP:CORPSES] Труп " .. client:Nick()
            .. ": перенесено предметов " .. moved .. ", ошибок " .. failed)

        ragdoll:CallOnRemove("MYRP_CorpseInventoryCleanup", function(entity)
            local inventory = entity.ixMYRPCorpseInventory

            if (inventory) then
                DeleteTemporaryInventory(inventory)
            end
        end)

        timer.Simple(CORPSE_LIFETIME, function()
            if (IsValid(ragdoll)) then
                ragdoll:Remove()
            end
        end)
    end)
end

hook.Add("CreateEntityRagdoll", "MYRP_CorpseLooting_CreateRagdoll", function(client, ragdoll)
    if (not IsValid(client) or not client:IsPlayer() or not IsValid(ragdoll)) then
        return
    end

    timer.Simple(0, function()
        if (IsValid(client) and IsValid(ragdoll)) then
            MoveInventoryToCorpse(client, ragdoll)
        end
    end)
end)

hook.Add("PlayerDeath", "MYRP_CorpseLooting_DeathFallback", function(client)
    timer.Simple(0.2, function()
        if (not IsValid(client)) then return end

        local ragdoll = client:GetRagdollEntity()

        if (IsValid(ragdoll)) then
            MoveInventoryToCorpse(client, ragdoll)
        end
    end)
end)

hook.Add("PlayerSpawn", "MYRP_CorpseLooting_TestBotInventory", function(client)
    if (not IsTestBot(client)) then return end

    timer.Simple(0.1, function()
        if (IsValid(client) and IsTestBot(client) and client:Alive()) then
            CreateBotInventory(client)
        end
    end)
end)

hook.Add("PlayerUse", "MYRP_CorpseLooting_Use", function(client, entity)
    if (not IsValid(client) or not client:Alive() or not client:GetCharacter()) then
        return
    end

    if (not IsValid(entity) or entity:GetClass() != "prop_ragdoll") then
        return
    end

    local inventory = entity.ixMYRPCorpseInventory

    if (not inventory) then
        return
    end

    if (client:GetPos():DistToSqr(entity:GetPos()) > USE_DISTANCE * USE_DISTANCE) then
        return false
    end

    ix.storage.Open(client, inventory, {
        entity = entity,
        name = "Обыск тела",
        bMultipleUsers = true
    })

    return false
end)

hook.Add("PlayerDisconnected", "MYRP_CorpseLooting_TestBotCleanup", function(client)
    if (IsTestBot(client) and client.ixMYRPTestInventory) then
        DeleteTemporaryInventory(client.ixMYRPTestInventory)
        client.ixMYRPTestInventory = nil
    end
end)

-- Remove temporary inventories left behind by an unclean server shutdown.
hook.Add("InitializedPlugins", "MYRP_CorpseLooting_CleanupOldInventories", function()
    local query = mysql:Select("ix_inventories")
        :Select("inventory_id")
        :WhereIn("inventory_type", {CORPSE_INVENTORY, BOT_INVENTORY})

    query:Callback(function(rows)
        if (not istable(rows)) then return end

        for _, row in ipairs(rows) do
            local id = tonumber(row.inventory_id)

            if (id) then
                mysql:Delete("ix_items")
                    :Where("inventory_id", id)
                    :Execute()

                mysql:Delete("ix_inventories")
                    :Where("inventory_id", id)
                    :Execute()

                ix.item.inventories[id] = nil
            end
        end
    end)

    query:Execute()
end)

print("[MYRP:CORPSES][SERVER] Corpse looting loaded.")
