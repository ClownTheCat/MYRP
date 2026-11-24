if not SERVER then return end

local PLUGIN = PLUGIN
local MATCHFLOW_DATA_KEY = "myrp_matchflow_state"
local RESET_PENDING_KEY = "myrp_matchreset_pending"
local SAVE_TIMEOUT = 30
local MAP_READY_DELAY = 8

util.AddNetworkString("myrpMatchResetOpenFaction")
util.AddNetworkString("MYRP_Thrones_Reset")

MYRP = MYRP or {}
MYRP.MatchReset = MYRP.MatchReset or {}
local API = MYRP.MatchReset
API.state = API.state or "idle"
API.lastReason = API.lastReason or "none"
API.transientEntities = API.transientEntities or {}

function API.RegisterTransientEntity(entity)
    if not IsValid(entity) then return false end
    API.transientEntities[entity] = true
    return true
end

local function ClearTransientEntities(reason)
    hook.Run("MYRP_MatchResetCleanup", reason)

    for entity in pairs(API.transientEntities) do
        if IsValid(entity) then
            entity:Remove()
        end
    end

    API.transientEntities = {}
end

local function Log(level, message)
    MsgN("[MYRP:MATCHRESET][" .. tostring(level or "INFO") .. "] " .. tostring(message))
end

local function CanManage(client)
    return not IsValid(client) or client:IsAdmin()
end

local function Reply(client, message)
    if IsValid(client) then
        client:ChatPrint(message)
    else
        MsgN(message)
    end
end

local function ReadMatchFlowState()
    local state = ix.data.Get(MATCHFLOW_DATA_KEY, {active = false, factions = {}}, false, true)
    return istable(state) and state or {active = false, factions = {}}
end

local function GetActiveCharacterEntries()
    local entries = {}

    for _, client in ipairs(player.GetAll()) do
        if IsValid(client) and client:IsPlayer() and not client:IsBot() then
            local character = client:GetCharacter()

            if character then
                entries[#entries + 1] = {
                    client = client,
                    character = character,
                    oldCharacterData = {},
                    oldLocalData = {}
                }
            end
        end
    end

    return entries
end

local function ClearRoundCurrency(entry)
    local client = entry.client
    local character = entry.character
    local keys = {
        {characterKey = "credits", localKey = "myrpCredits"},
        {characterKey = "anamnecites", localKey = "myrpAnamnecites"}
    }

    for _, definition in ipairs(keys) do
        local characterValue = character:GetData(definition.characterKey, nil)

        if characterValue ~= nil then
            entry.oldCharacterData[definition.characterKey] = characterValue
            character:SetData(definition.characterKey, 0)
        end

        if IsValid(client) and client.GetLocalVar and client.SetLocalVar then
            local localValue = client:GetLocalVar(definition.localKey, nil)

            if localValue ~= nil then
                entry.oldLocalData[definition.localKey] = localValue
                client:SetLocalVar(definition.localKey, 0)
            end
        end
    end
end

local function RestoreRoundCurrency(entries)
    for _, entry in ipairs(entries or {}) do
        local character = entry.character
        local client = entry.client

        if character and character.SetData then
            for key, value in pairs(entry.oldCharacterData or {}) do
                character:SetData(key, value)
            end
        end

        if IsValid(client) and client.SetLocalVar then
            for key, value in pairs(entry.oldLocalData or {}) do
                client:SetLocalVar(key, value)
            end
        end
    end
end

local function RemoveInventoryReceivers(character, client)
    if not character or not character.GetInventory then return end

    local inventories = character:GetInventory(true)
    if not istable(inventories) then return end

    for _, inventory in ipairs(inventories) do
        if istable(inventory) and inventory.RemoveReceiver then
            inventory:RemoveReceiver(client)
        end
    end
end

local function ClearPlayerRoundState(client)
    client.ixMatchflowRespawnAt = nil
    client.ixMatchflowRespawnMenuSent = nil
    client.ixMatchflowNextRespawnRequest = nil
    client.ixMyRPFactionSelecting = nil

    if client.SetNetVar then
        client:SetNetVar("deathTime", nil)
    end

    if client.SetAction then
        client:SetAction()
    end
end

local function RestoreKickedCharacters(entries)
    for _, entry in ipairs(entries or {}) do
        local client = entry.client
        local character = entry.character

        if IsValid(client) and character and not client:GetCharacter() then
            pcall(function()
                hook.Run("PrePlayerLoadedCharacter", client, character, nil)
                character:Setup()
                client:Spawn()
                hook.Run("PlayerLoadedCharacter", client, character, nil)
            end)
        end
    end
end

local function AbortReset(reason, entries)
    timer.Remove("MYRP.MatchReset.SaveTimeout")
    RestoreRoundCurrency(entries or {})
    RestoreKickedCharacters(entries or {})

    API.state = "idle"
    API.lastReason = "aborted: " .. tostring(reason)

    hook.Run("MYRP_MatchResetAborted", reason)
    Log("ERROR", "Reset aborted: " .. tostring(reason))
end

local function BroadcastVictoryClear()
    net.Start("MYRP_Thrones_Reset")
    net.Broadcast()
end

local function BeginMapChange(reason, winnerFaction, entries, mapName)
    -- Every character was saved before this point. Remove the old client-side
    -- inventory subscriptions before using Helix's native character Kick().
    for _, entry in ipairs(entries) do
        local client = entry.client
        local character = entry.character

        if IsValid(client) and client:GetCharacter() == character then
            RemoveInventoryReceivers(character, client)
            ClearPlayerRoundState(client)

            local ok, err = pcall(function()
                character:Kick()
            end)

            -- KillSilent inside Kick() may invoke death-related hooks. Clear
            -- their temporary state again after the native unload operation.
            ClearPlayerRoundState(client)

            if not ok then
                Log("ERROR", "Helix Kick failed for " .. client:SteamName() .. ": " .. tostring(err))
            elseif client:GetCharacter() then
                Log("WARN", "Character remained active after Kick(): " .. client:SteamName()
                    .. "; a second cleanup attempt will run after map load.")
            else
                Log("INFO", "Returned player to character selection: " .. client:SteamName())
            end
        end
    end

    -- Existing MatchFlow owns this state and its commands. Reuse its command
    -- instead of creating a second, competing copy of the match state.
    RunConsoleCommand("myrp_match_end")

    timer.Simple(0.5, function()
        local currentState = ReadMatchFlowState()

        if currentState.active == true then
            AbortReset("myrp_match_end did not deactivate MatchFlow", entries)
            return
        end

        -- Only clear registered temporary objects after MatchFlow accepted
        -- the end command, so an aborted preparation does not destroy builds.
        local cleanupOK, cleanupError = pcall(ClearTransientEntities, reason)
        if not cleanupOK then
            Log("ERROR", "Transient cleanup raised an error; map reload will still clear ordinary entities: " .. tostring(cleanupError))
        end

        local pending = {
            active = true,
            map = mapName,
            reason = tostring(reason or "manual"),
            winner = winnerFaction,
            requestedAt = os.time()
        }

        ix.data.Set(RESET_PENDING_KEY, pending, false, true)
        API.state = "changing_map"
        API.lastReason = tostring(reason or "manual")

        BroadcastVictoryClear()
        file.Delete("myrp/throne_restart.txt")

        for _, client in ipairs(player.GetAll()) do
            if IsValid(client) and client:IsPlayer() then
                client:ChatPrint("[MYRP] Матч завершён. Загружается новый раунд...")
            end
        end

        Log("INFO", "All save callbacks completed. Reloading map " .. mapName
            .. "; reason=" .. tostring(reason)
            .. "; winner=" .. tostring(winnerFaction or "none"))

        timer.Simple(0.5, function()
            game.ConsoleCommand("changelevel " .. mapName .. "\n")
        end)
    end)
end

function PLUGIN:StartReset(reason, winnerFaction)
    if API.state ~= "idle" then
        Log("WARN", "A reset is already in progress; state=" .. tostring(API.state))
        return false
    end

    if not concommand.GetTable()["myrp_match_end"]
        or not concommand.GetTable()["myrp_match_start"] then
        Log("ERROR", "MatchFlow start/end commands are unavailable. Is myrp_matchflow loaded?")
        return false
    end

    local mapName = game.GetMap()

    if not isstring(mapName) or mapName == "" or not string.match(mapName, "^[%w_%-]+$") then
        Log("ERROR", "Current map name is invalid; refusing to execute changelevel.")
        return false
    end

    if winnerFaction ~= nil
        and winnerFaction ~= "combine"
        and winnerFaction ~= "resistance" then
        Log("ERROR", "Invalid winner faction: " .. tostring(winnerFaction))
        return false
    end

    local entries = GetActiveCharacterEntries()
    API.state = "saving"
    API.lastReason = tostring(reason or "manual")

    Log("INFO", "Preparing round reset. map=" .. mapName
        .. "; activeCharacters=" .. #entries
        .. "; reason=" .. tostring(reason or "manual"))

    for _, entry in ipairs(entries) do
        ClearRoundCurrency(entry)
        hook.Run("MYRP_MatchResetClearPlayerData", entry.client, entry.character)
    end

    if #entries == 0 then
        BeginMapChange(reason, winnerFaction, entries, mapName)
        return true
    end

    local remaining = #entries
    local finished = false

    local function FinishSaving(success, failureReason)
        if finished then return end
        finished = true
        timer.Remove("MYRP.MatchReset.SaveTimeout")

        if not success then
            AbortReset(failureReason or "character save failed or timed out", entries)
            return
        end

        Log("INFO", "Character saves completed: " .. #entries .. "/" .. #entries)
        BeginMapChange(reason, winnerFaction, entries, mapName)
    end

    timer.Create("MYRP.MatchReset.SaveTimeout", SAVE_TIMEOUT, 1, function()
        FinishSaving(false, "Timed out while waiting for Helix character saves (" .. SAVE_TIMEOUT .. " seconds).")
    end)

    for _, entry in ipairs(entries) do
        local client = entry.client
        local character = entry.character

        if IsValid(client) and client:GetCharacter() ~= character then
            FinishSaving(false, "An active character changed while reset preparation was running.")
            return true
        end

        local ok, err = pcall(function()
            character:Save(function()
                if finished then return end
                remaining = remaining - 1

                if remaining <= 0 then
                    FinishSaving(true)
                end
            end)
        end)

        if not ok then
            FinishSaving(false, "Helix Save() raised an error: " .. tostring(err))
            return true
        end
    end

    return true
end

-- Called by the throne plugin after the victory countdown.
hook.Add("MYRP_MatchResetStart", "MYRP.MatchReset.StartFromThrones", function(reason, winnerFaction)
    return PLUGIN:StartReset(reason or "throne", winnerFaction)
end)

function PLUGIN:InitPostEntity()
    timer.Remove("MYRP.MatchReset.MapReady")

    timer.Create("MYRP.MatchReset.MapReady", MAP_READY_DELAY, 1, function()
        local pending = ix.data.Get(RESET_PENDING_KEY, false, false, true)

        if not istable(pending) or pending.active ~= true then
            if API.state == "changing_map" then
                API.state = "idle"
            end
            return
        end

        Log("INFO", "Map loaded for a pending round reset; restoring round systems.")
        hook.Run("MYRP_MatchResetMapReady", pending)

        -- Defensive pass: if a character survived the pre-change Kick(), return
        -- that player to the faction selector now that the new map is ready.
        for _, client in ipairs(player.GetAll()) do
            if IsValid(client) and client:IsPlayer() and not client:IsBot() then
                local character = client:GetCharacter()

                if character then
                    RemoveInventoryReceivers(character, client)
                    ClearPlayerRoundState(client)
                    pcall(function() character:Kick() end)
                    ClearPlayerRoundState(client)
                end
            end
        end

        timer.Simple(0.5, function()
            RunConsoleCommand("myrp_match_start")

            timer.Simple(0.5, function()
                local state = ReadMatchFlowState()

                if state.active ~= true then
                    Log("ERROR", "Could not start the next match. Run myrp_match_start from server console.")
                else
                    Log("INFO", "New match started; faction locks will be assigned as players select factions.")
                end

                ix.data.Set(RESET_PENDING_KEY, {active = false}, false, true)
                API.state = "idle"

                for _, client in ipairs(player.GetAll()) do
                    if IsValid(client) and client:IsPlayer() and not client:IsBot() and not client:GetCharacter() then
                        net.Start("myrpMatchResetOpenFaction")
                        net.Send(client)
                    end
                end

                Log("INFO", "Round reset completed. Connected players remain on the server.")
            end)
        end)
    end)
end

concommand.Add("myrp_matchreset_status", function(client)
    if not CanManage(client) then
        Reply(client, "[MYRP] Admin access required.")
        return
    end

    local state = ReadMatchFlowState()
    local pending = ix.data.Get(RESET_PENDING_KEY, false, false, true)
    local playersWithCharacters = #GetActiveCharacterEntries()

    local message = "[MYRP:MATCHRESET][STATUS] resetState=" .. tostring(API.state)
        .. "; map=" .. tostring(game.GetMap())
        .. "; matchActive=" .. tostring(state.active == true)
        .. "; activeCharacters=" .. playersWithCharacters
        .. "; pendingMapReset=" .. tostring(istable(pending) and pending.active == true)
        .. "; lastReason=" .. tostring(API.lastReason)

    MsgN(message)
    Reply(client, message)
end)

concommand.Add("myrp_matchreset_test", function(client)
    if not CanManage(client) then
        Reply(client, "[MYRP] Admin access required.")
        return
    end

    local entries = GetActiveCharacterEntries()
    local combineThrones = #ents.FindByClass("myrp_throne_combine")
    local resistanceThrones = #ents.FindByClass("myrp_throne_resistance")
    local state = ReadMatchFlowState()
    local pending = ix.data.Get(RESET_PENDING_KEY, false, false, true)

    MsgN("========== MYRP MATCH RESET DRY RUN ==========")
    MsgN("No players will be kicked and no map change will be executed.")
    MsgN("state=" .. tostring(API.state) .. "; map=" .. tostring(game.GetMap()))
    MsgN("matchActive=" .. tostring(state.active == true)
        .. "; activeCharacters=" .. #entries
        .. "; combineThrones=" .. combineThrones
        .. "; resistanceThrones=" .. resistanceThrones)
    MsgN("matchEndCommand=" .. tostring(concommand.GetTable()["myrp_match_end"] ~= nil)
        .. "; matchStartCommand=" .. tostring(concommand.GetTable()["myrp_match_start"] ~= nil)
        .. "; registeredTransientEntities=" .. tostring(table.Count(API.transientEntities))
        .. "; pendingReset=" .. tostring(istable(pending) and pending.active == true))

    for _, entry in ipairs(entries) do
        local character = entry.character
        local inventoryCount = 0
        local inventories = character.GetInventory and character:GetInventory(true) or {}

        if istable(inventories) then
            inventoryCount = #inventories
        end

        MsgN("player=" .. entry.client:SteamName()
            .. "; characterID=" .. tostring(character:GetID())
            .. "; inventories=" .. inventoryCount
            .. "; kickMethod=" .. tostring(isfunction(character.Kick))
            .. "; saveMethod=" .. tostring(isfunction(character.Save)))
    end

    MsgN("==============================================")
    Reply(client, "[MYRP] Dry run completed. Check the server console for details.")
end)

concommand.Add("myrp_matchreset_start", function(client, command, arguments)
    if not CanManage(client) then
        Reply(client, "[MYRP] Admin access required.")
        return
    end

    local reason = string.Trim(table.concat(arguments or {}, " "))
    if reason == "" then reason = "manual" end

    local started = PLUGIN:StartReset(reason, nil)
    Reply(client, started and "[MYRP] Round reset preparation started." or "[MYRP] Could not start round reset. Check server console.")
end)

MsgN("[MYRP:MATCHRESET][INFO] Central round reset plugin loaded. Commands: myrp_matchreset_status, myrp_matchreset_test, myrp_matchreset_start.")