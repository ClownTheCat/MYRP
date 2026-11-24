-- MYRP v2.0 faction assets and server-side selection/model validation.
if SERVER and resource and resource.AddFile then
    local factionAssets = {
        "materials/myrp/factions/background.jpg",
        "materials/myrp/factions/combine.jpg",
        "materials/myrp/factions/resistance.jpg"
    }

    for _, assetPath in ipairs(factionAssets) do
        if file.Exists(assetPath, "GAME") then
            resource.AddFile(assetPath)
            MsgN("[MYRP:ASSET][SERVER] Added client download: " .. assetPath)
        else
            MsgN("[MYRP:ASSET][SERVER][WARN] Missing faction artwork: " .. assetPath
                .. " (expected under garrysmod/materials/myrp/factions/)")
        end
    end
end

-- MYRP server-side faction selection handler.
MsgN("[MYRP:CHAR][SERVER][INFO] Faction selection handler v2.0 loaded; model validation enabled.")

util.AddNetworkString("myrpFactionSelect")
util.AddNetworkString("myrpFactionSelectResult")

local ALLOWED_FACTIONS = {
    combine = true,
    resistance = true
}

local function GetCleanSteamName(client)
    local name = tostring(client:SteamName() or "Player")
    name = string.Trim(string.gsub(name, "%c", ""))

    if name == "" then
        name = "Player" .. tostring(client:UserID())
    end

    if utf8 and utf8.sub then
        name = utf8.sub(name, 1, 32)
    else
        name = string.sub(name, 1, 32)
    end

    return name
end

local function SendResult(client, success, message, characterID)
    if not IsValid(client) then return end

    net.Start("myrpFactionSelectResult")
        net.WriteBool(success)
        net.WriteString(message or "")
        net.WriteUInt(tonumber(characterID) or 0, 32)
    net.Send(client)
end

local function FindClassByUniqueID(uniqueID)
    for _, class in pairs(ix.class.list or {}) do
        if class.uniqueID == uniqueID then
            return class
        end
    end
end

local function GetAllowedFactionModel(client, faction, requestedModel)
    if (!isstring(requestedModel) or requestedModel == "") then return nil end

    local models = faction.GetModels and faction:GetModels(client) or faction.models or {}
    for _, entry in pairs(models) do
        local modelPath = isstring(entry) and entry or (istable(entry) and entry[1])
        if (isstring(modelPath) and string.lower(modelPath) == string.lower(requestedModel)) then
            if (util.IsValidModel(modelPath) and modelPath ~= "models/error.mdl") then
                return modelPath
            end
        end
    end
end

local function FindCharacterForFaction(client, factionIndex)
    local steamID64 = client:SteamID64()
    local charList = client.ixCharList or ix.char.cache[steamID64] or {}

    for _, id in ipairs(charList) do
        local character = ix.char.loaded[tonumber(id)]

        if character and character:GetFaction() == factionIndex then
            return character
        end
    end
end

local function LoadSelectedCharacter(client, character)
    if not IsValid(client) or not character then return false end
    if client:GetCharacter() then return false end

    local canUse = hook.Run("CanPlayerUseCharacter", client, character)
    if canUse == false then return false end

    hook.Run("PrePlayerLoadedCharacter", client, character, nil)
    character:Setup()
    client:Spawn()
    hook.Run("PlayerLoadedCharacter", client, character, nil)

    return true
end

net.Receive("myrpFactionSelect", function(_, client)
    if not IsValid(client) or not client.ixLoaded then return end

    if (client.ixNextMyRPFactionSelect or 0) > CurTime() then return end
    client.ixNextMyRPFactionSelect = CurTime() + 1.5

    if client.ixMyRPFactionSelecting then return end

    if client:GetCharacter() then
        SendResult(client, false, "Персонаж уже загружен.")
        return
    end

    local factionID = string.lower(net.ReadString() or "")
    local classID = string.lower(net.ReadString() or "")
    local requestedModel = string.Trim(net.ReadString() or "")

    MsgN("[MYRP:CHAR][SERVER][INFO] Selection request: player=" .. tostring(client:SteamName())
        .. ", faction=" .. factionID .. ", class=" .. classID .. ", model=" .. requestedModel)

    if not ALLOWED_FACTIONS[factionID] then
        SendResult(client, false, "Неизвестная фракция.")
        return
    end

    local faction = ix.faction.Get(factionID)
    if not faction then
        SendResult(client, false, "Фракция не найдена. Проверь файлы schema/factions.")
        return
    end

    -- For this first iteration, each faction has exactly one selectable role: Worker.
    if classID ~= factionID .. "_worker" then
        SendResult(client, false, "Эта профессия недоступна.")
        return
    end

    local class = FindClassByUniqueID(classID)
    if not class or class.faction ~= faction.index or not class.isDefault then
        SendResult(client, false, "Класс Worker не найден, привязан к другой фракции или не отмечен как default. Проверь schema/classes.")
        return
    end

    local selectedModel = GetAllowedFactionModel(client, faction, requestedModel)
    if (!selectedModel) then
        MsgN("[MYRP:CHAR][SERVER][WARN] Rejected model not assigned to faction: faction=" .. factionID .. ", model=" .. requestedModel)
        SendResult(client, false, "Выбранная модель недоступна для этой фракции.")
        return
    end

    MsgN("[MYRP:CHAR][SERVER][INFO] Validated model: faction=" .. factionID .. ", model=" .. selectedModel)
    client.ixMyRPFactionSelecting = true

    -- Reuse the player's existing character for this faction rather than creating duplicates.
    local existingCharacter = FindCharacterForFaction(client, faction.index)
    if existingCharacter then
        local steamName = GetCleanSteamName(client)
        if existingCharacter:GetName() ~= steamName then
            existingCharacter:SetName(steamName)
        end
        if existingCharacter:GetModel() ~= selectedModel then
            existingCharacter:SetModel(selectedModel)
        end
        existingCharacter:Save()

        MsgN("[MYRP:CHAR][SERVER][INFO] Reusing existing character id=" .. existingCharacter:GetID()
            .. ", model=" .. selectedModel)
        local success = LoadSelectedCharacter(client, existingCharacter)
        client.ixMyRPFactionSelecting = nil
        SendResult(client, success, success and "" or "Не удалось загрузить персонажа.", existingCharacter:GetID())
        return
    end

    local maxCharacters = hook.Run("GetMaxPlayerCharacter", client) or ix.config.Get("maxCharacters", 5)
    local steamID64 = client:SteamID64()
    client.ixCharList = client.ixCharList or ix.char.cache[steamID64] or {}
    ix.char.cache[steamID64] = client.ixCharList

    if #client.ixCharList >= maxCharacters then
        client.ixMyRPFactionSelecting = nil
        SendResult(client, false, "Достигнут лимит персонажей Helix.")
        return
    end

    local model = selectedModel

    local payload = {
        name = GetCleanSteamName(client),
        description = "",
        model = model,
        faction = faction.uniqueID,
        steamID = steamID64,
        data = {
            myrpClass = class.uniqueID
        }
    }

    -- Respect other plugins that explicitly deny character creation.
    local canCreate, reason = hook.Run("CanPlayerCreateCharacter", client, payload)
    if canCreate == false then
        client.ixMyRPFactionSelecting = nil
        SendResult(client, false, isstring(reason) and reason or "Создание персонажа запрещено.")
        return
    end

    ix.char.Create(payload, function(id)
        if not IsValid(client) then return end

        local character = ix.char.loaded[id]
        if not character then
            client.ixMyRPFactionSelecting = nil
            SendResult(client, false, "Helix не смог сохранить персонажа.")
            return
        end

        hook.Run("OnCharacterCreated", client, character)
        local success = LoadSelectedCharacter(client, character)
        client.ixMyRPFactionSelecting = nil
        SendResult(client, success, success and "" or "Персонаж создан, но не удалось войти в него.", id)

        MsgN("[MYRP:CHAR][SERVER][INFO] Created character id=" .. id .. ", faction=" .. factionID
            .. ", class=" .. class.uniqueID .. ", model=" .. selectedModel .. ", steamName=" .. client:SteamName())
    end)
end)
