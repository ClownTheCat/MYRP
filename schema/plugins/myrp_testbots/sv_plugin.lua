-- MYRP Test Bots v1.1
-- Test-only player bots. They do not receive Helix characters or database rows.

if not SERVER then return end

local MAX_BOTS = 4
local MAX_PER_FACTION = 2
local BOT_TAG = "ixMYRPTestBot"
local FACTIONS = {
    combine = {
        name = "Combine",
        models = {
            "models/humans/group01/male_01.mdl",
            "models/humans/group01/male_02.mdl",
            "models/humans/group01/male_04.mdl",
            "models/humans/group01/female_01.mdl",
            "models/humans/group01/female_02.mdl"
        }
    },
    resistance = {
        name = "Resistance",
        models = {
            "models/humans/group03/male_01.mdl",
            "models/humans/group03/male_02.mdl",
            "models/humans/group03/male_03.mdl",
            "models/humans/group03/female_01.mdl",
            "models/humans/group03/female_02.mdl"
        }
    }
}

local function IsTestBot(client)
    return IsValid(client) and client:IsPlayer() and client:IsBot()
        and client[BOT_TAG] == true
end

local function GetTestBots()
    local result = {}

    for _, client in ipairs(player.GetAll()) do
        if IsTestBot(client) then
            result[#result + 1] = client
        end
    end

    return result
end

local function CountFaction(factionID)
    local count = 0

    for _, bot in ipairs(GetTestBots()) do
        if bot.ixMYRPTestBotFaction == factionID then
            count = count + 1
        end
    end

    return count
end

local function ConfigureBot(bot, factionID)
    if not IsValid(bot) or not FACTIONS[factionID] then return end

    bot[BOT_TAG] = true
    bot.ixMYRPTestBotFaction = factionID
    bot:SetNW2String("myrp_testbot_faction", factionID)

    local models = FACTIONS[factionID].models
    local model = models[math.random(#models)]

    bot:SetModel(model)
    bot:SetPlayerColor(factionID == "combine"
        and Vector(0.25, 0.55, 0.9)
        or Vector(0.75, 0.48, 0.25))

    bot:SetMaxHealth(100)
    bot:SetHealth(100)
    bot:SetArmor(0)
    bot:GodDisable()
end

local function AddBot(factionID, issuer)
    factionID = isstring(factionID) and string.lower(factionID) or ""

    if not FACTIONS[factionID] then
        local message = "[MYRP:TESTBOTS] Использование: myrp_bot_add combine|resistance"
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
        return
    end

    local bots = GetTestBots()

    if #bots >= MAX_BOTS then
        local message = "[MYRP:TESTBOTS] Достигнут общий лимит: " .. MAX_BOTS
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
        return
    end

    if CountFaction(factionID) >= MAX_PER_FACTION then
        local message = "[MYRP:TESTBOTS] Достигнут лимит для фракции " .. factionID
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
        return
    end

    if not player.CreateNextBot then
        local message = "[MYRP:TESTBOTS] player.CreateNextBot недоступен на этом сервере."
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
        return
    end

    local botName = "MYRP_" .. (factionID == "combine" and "Combine" or "Resistance")
        .. "_" .. tostring(#bots + 1)

    local bot = player.CreateNextBot(botName)

    if not IsValid(bot) then
        local message = "[MYRP:TESTBOTS] Не удалось создать бота. Проверьте свободные слоты."
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
        return
    end

    ConfigureBot(bot, factionID)

    timer.Simple(0, function()
        if IsValid(bot) then
            ConfigureBot(bot, factionID)
            bot:Spawn()
            timer.Simple(0, function()
                if IsValid(bot) then
                    ConfigureBot(bot, factionID)
                end
            end)
        end
    end)

    MsgN("[MYRP:TESTBOTS][INFO] Created bot=" .. bot:Nick()
        .. "; faction=" .. factionID)

    if IsValid(issuer) then
        issuer:ChatPrint("[MYRP] Создан тестовый бот " .. bot:Nick()
            .. " (" .. factionID .. ").")
    end
end

local function RemoveBots(issuer)
    local bots = GetTestBots()
    local removed = 0

    for _, bot in ipairs(bots) do
        if IsValid(bot) then
            local name = bot:Nick()
            bot:Kick("MYRP test bot removed")
            removed = removed + 1
            MsgN("[MYRP:TESTBOTS][INFO] Removed bot=" .. name)
        end
    end

    local message = "[MYRP:TESTBOTS] Удалено ботов: " .. removed
    if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
end

local function RespawnBots(issuer)
    local bots = GetTestBots()

    for _, bot in ipairs(bots) do
        if IsValid(bot) then
            bot:Spawn()
            timer.Simple(0, function()
                if IsValid(bot) then
                    ConfigureBot(bot, bot.ixMYRPTestBotFaction)
                end
            end)
        end
    end

    local message = "[MYRP:TESTBOTS] Возрождены боты: " .. #bots
    if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
end

local function ListBots(issuer)
    local bots = GetTestBots()

    if #bots == 0 then
        local message = "[MYRP:TESTBOTS] Тестовых ботов нет."
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
        return
    end

    for _, bot in ipairs(bots) do
        local message = "[MYRP:TESTBOTS] " .. bot:Nick()
            .. " | faction=" .. tostring(bot.ixMYRPTestBotFaction)
            .. " | alive=" .. tostring(bot:Alive())
        if IsValid(issuer) then issuer:ChatPrint(message) else MsgN(message) end
    end
end

local function CanUse(client)
    return not IsValid(client) or client:IsAdmin()
end

local function AddConsoleCommand(name, callback)
    concommand.Add(name, function(client, _, args)
        if not CanUse(client) then
            client:ChatPrint("[MYRP] Недостаточно прав.")
            return
        end

        callback(client, args or {})
    end)
end

AddConsoleCommand("myrp_bot_add", function(client, args)
    AddBot(args[1], client)
end)

AddConsoleCommand("myrp_bot_list", function(client)
    ListBots(client)
end)

AddConsoleCommand("myrp_bot_respawn", function(client)
    RespawnBots(client)
end)

AddConsoleCommand("myrp_bot_remove", function(client)
    RemoveBots(client)
end)

-- Helix commands for in-game admins.
ix.command.Add("MYRPBotAdd", {
    description = "Создать тестового бота указанной фракции.",
    adminOnly = true,
    arguments = {ix.type.string},
    OnRun = function(self, client, factionID)
        AddBot(factionID, client)
    end
})

ix.command.Add("MYRPBotList", {
    description = "Показать тестовых ботов.",
    adminOnly = true,
    OnRun = function(self, client)
        ListBots(client)
    end
})

ix.command.Add("MYRPBotRespawn", {
    description = "Возродить тестовых ботов.",
    adminOnly = true,
    OnRun = function(self, client)
        RespawnBots(client)
    end
})

ix.command.Add("MYRPBotRemove", {
    description = "Удалить тестовых ботов.",
    adminOnly = true,
    OnRun = function(self, client)
        RemoveBots(client)
    end
})

-- No-character test bots are allowed to take damage; regular clients are untouched.
hook.Add("PlayerShouldTakeDamage", "MYRP.TestBots.AllowDamage", function(target, attacker)
    if IsTestBot(target) then
        return true
    end
end)

-- Keep faction/model assignment after spawn without making a Helix character.
hook.Add("PlayerSpawn", "MYRP.TestBots.ConfigureSpawn", function(client)
    if IsTestBot(client) then
        local factionID = client.ixMYRPTestBotFaction
        timer.Simple(0, function()
            if IsValid(client) and IsTestBot(client) then
                ConfigureBot(client, factionID)
            end
        end)
    end
end)

hook.Add("PlayerDisconnected", "MYRP.TestBots.LogDisconnect", function(client)
    if IsTestBot(client) then
        MsgN("[MYRP:TESTBOTS][INFO] Bot disconnected: " .. client:Nick())
    end
end)

MsgN("[MYRP:TESTBOTS][SERVER][INFO] MYRP Test Bots v1.1 loaded.")
