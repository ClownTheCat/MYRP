PLUGIN.name = "MYRP Stamina Fix"
PLUGIN.author = "MYRP"
PLUGIN.description = "Restores full stamina after character loading."

if SERVER then
    local RESTORE_DELAY = 0.5

    local function RestoreFullStamina(client, character)
        if not IsValid(client) or not character then
            return
        end

        timer.Simple(RESTORE_DELAY, function()
            if not IsValid(client) or client:GetCharacter() ~= character then
                return
            end

            -- Restore the actual server-side stamina value.
            client:SetLocalVar("stm", 100)

            -- Update the character's saved stamina as well.
            character:SetData("stamina", 100)

            -- Clear the exhausted state left from the previous session.
            if client:GetNetVar("brth", false) then
                client:SetNetVar("brth", nil)
            end

            -- Restore normal running speed, respecting the stamina attribute.
            local runSpeed = ix.config.Get("runSpeed")
                + character:GetAttribute("stm", 0)

            if client:WaterLevel() > 1 then
                runSpeed = runSpeed * 0.775
            end

            client:SetRunSpeed(runSpeed)

            MsgN("[MYRP:STAMINA][INFO] Full stamina restored: player="
                .. client:SteamName()
                .. "; stamina=100; exhausted=false")
        end)
    end

    hook.Add(
        "PlayerLoadedCharacter",
        "MYRP.StaminaFix.RestoreFull",
        RestoreFullStamina
    )

    concommand.Add("myrp_stamina_status", function(client)
        if IsValid(client) and not client:IsAdmin() then
            return
        end

        local targets = IsValid(client) and {client} or player.GetAll()

        for _, target in ipairs(targets) do
            local character = target:GetCharacter()

            MsgN("[MYRP:STAMINA][STATUS] player=" .. target:SteamName()
                .. "; current=" .. tostring(target:GetLocalVar("stm", 0))
                .. "; saved=" .. tostring(character and character:GetData("stamina", 100) or "none")
                .. "; exhausted=" .. tostring(target:GetNetVar("brth", false)))
        end
    end)
end

MsgN("[MYRP:STAMINA][INFO] Stamina fix loaded.")