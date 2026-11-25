local selectedAction = 1
local selectedEntity
local pendingUseEntity
local pendingUseHasItem = false
local pendingUseTime = 0
local physicalHoldActive = false
local physicalHoldPending = false
local weaponSelectPatchApplied = false

local actionNames = {
    "Взять в руки",
    "Положить в инвентарь"
}

local function PlayUI(kind)
    if (MYRP and MYRP.UI and MYRP.UI.PlaySound) then
        MYRP.UI.PlaySound(kind)
    end
end

local function GetWeaponTarget()
    local client = LocalPlayer()

    if (!IsValid(client) or !client:Alive()) then
        return
    end

    local trace = client:GetEyeTrace()
    local entity = trace.Entity

    if (!IsValid(entity)) then
        return
    end

    local class = entity:GetClass()
    local itemName
    local hasItem = false

    if (class == "ix_item") then
        local item = entity:GetItemTable()

        if (!item or !item.isWeapon) then
            return
        end

        itemName = item.name or "Оружие"
        hasItem = true
    else
        local isWeapon = (entity.IsWeapon and entity:IsWeapon())
            or string.sub(class, 1, 7) == "weapon_"

        if (!isWeapon) then
            return
        end

        for _, item in pairs(ix.item.list or {}) do
            if (item.isWeapon and item.class == class) then
                itemName = item.name
                hasItem = true
                break
            end
        end

        if (!itemName) then
            local weaponData = weapons.GetStored(class)
            itemName = weaponData and weaponData.PrintName or class

            if (string.sub(itemName, 1, 1) == "#") then
                itemName = language.GetPhrase(string.sub(itemName, 2))
            end
        end
    end

    return entity, itemName, hasItem
end

local function DrawConnector(entity, x, y, width, height, accent)
    if (!IsValid(entity)) then return end

    local anchor = entity:WorldSpaceCenter():ToScreen()

    if (!anchor.visible) then return end

    -- Find the nearest edge of the menu.
    local centerX = x + width * 0.5
    local centerY = y + height * 0.5

    local dx = anchor.x - centerX
    local dy = anchor.y - centerY

    local attachX
    local attachY

    if (math.abs(dx) / width > math.abs(dy) / height) then
        attachX = dx < 0 and x or x + width
        attachY = math.Clamp(anchor.y, y + 12, y + height - 12)
    else
        attachY = dy < 0 and y or y + height
        attachX = math.Clamp(anchor.x, x + 12, x + width - 12)
    end

    -- Subtle shadow under the connecting line.
    surface.SetDrawColor(0, 0, 0, 150)
    surface.DrawLine(anchor.x, anchor.y + 1, attachX, attachY + 1)

    -- Main faction-colored line.
    surface.SetDrawColor(accent.r, accent.g, accent.b, 190)
    surface.DrawLine(anchor.x, anchor.y, attachX, attachY)

    -- Small marker on the weapon.
    surface.DrawCircle(anchor.x, anchor.y, 4, accent)
    surface.DrawCircle(anchor.x, anchor.y, 2, color_white)
end

hook.Add("HUDPaint", "MYRP_WeaponInteraction_TargetUI", function()
    local entity, itemName, hasItem = GetWeaponTarget()

    if (!IsValid(entity)) then
        selectedEntity = nil
        selectedAction = 1
        return
    end

    -- Reset selection when aiming at a different weapon.
    if (selectedEntity != entity) then
        selectedEntity = entity
        selectedAction = 1
    end

    local client = LocalPlayer()

    local width, height = 340, 184
    local x = math.min(ScrW() * 0.5 + 34, ScrW() - width - 18)
    local y = math.min(ScrH() * 0.5 + 34, ScrH() - height - 18)

    x = math.max(18, x)
    y = math.max(18, y)

    local theme
    local accent = Color(110, 175, 255)

    if (MYRP and MYRP.UI) then
        if (MYRP.UI.GetTheme) then
            theme = MYRP.UI.GetTheme(client)
        end

        if (MYRP.UI.GetAccent) then
            local result = MYRP.UI.GetAccent(client)

            if (IsColor(result)) then
                accent = result
            end
        end
    end

    -- Draw the tether before the panel.
    DrawConnector(entity, x, y, width, height, accent)

    if (MYRP and MYRP.UI and MYRP.UI.DrawGlowPanel) then
        MYRP.UI.DrawGlowPanel(x, y, width, height, theme, 245, 8)
    else
        draw.RoundedBox(8, x, y, width, height, Color(12, 17, 27, 240))
    end

    draw.SimpleText(
        "ВЗАИМОДЕЙСТВИЕ",
        "DermaDefaultBold",
        x + 16, y + 13,
        accent,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    draw.SimpleText(
        itemName or "Оружие",
        "DermaDefaultBold",
        x + 16, y + 35,
        color_white,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    for i = 1, #actionNames do
        local rowY = y + 59 + (i - 1) * 23
        local enabled = hasItem
        local selected = selectedAction == i

        if (selected) then
            local backgroundColor = enabled
                and Color(accent.r, accent.g, accent.b, 45)
                or Color(130, 130, 130, 35)

            draw.RoundedBox(4, x + 10, rowY, width - 20, 21, backgroundColor)

            draw.RoundedBox(
                2, x + 10, rowY + 2, 3, 17,
                enabled and accent or Color(130, 130, 130)
            )
        end

        local textColor

        if (!enabled) then
            textColor = Color(115, 115, 115)
        elseif (selected) then
            textColor = color_white
        else
            textColor = Color(190, 195, 205)
        end

        local prefix = selected and "›  " or "   "

        draw.SimpleText(
            prefix .. actionNames[i],
            "DermaDefault",
            x + 19, rowY + 3,
            textColor,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
        )
    end

    draw.SimpleText(
        "Зажми E — физически поднять оружие",
        "DermaDefault",
        x + 16, y + 132,
        Color(210, 215, 225),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    draw.SimpleText(
        "Колесо — выбор  ·  Короткое E — действие",
        "DermaDefault",
        x + 16, y + 151,
        Color(150, 155, 165),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )
end)

-- MYRP_PhysicalHold_Client
local function SendHoldOperation(operation, entity)
    net.Start("MYRP_WeaponInteraction_Hold")
        net.WriteString(operation)

        if (operation == "start") then
            net.WriteEntity(entity)
        end
    net.SendToServer()
end

net.Receive("MYRP_WeaponInteraction_Hold", function()
    local status = net.ReadString()

    if (status == "started") then
        physicalHoldPending = false
        physicalHoldActive = true
    elseif (status == "failed" or status == "released") then
        physicalHoldPending = false
        physicalHoldActive = false
    end
end)

hook.Add("Think", "MYRP_PhysicalHold_Client", function()
    if (!IsValid(LocalPlayer()) or !LocalPlayer():Alive()) then return end

    if (
        IsValid(pendingUseEntity) and
        !physicalHoldActive and
        !physicalHoldPending and
        CurTime() - pendingUseTime >= 0.25 and
        input.IsKeyDown(KEY_E)
    ) then
        SendHoldOperation("start", pendingUseEntity)
        physicalHoldPending = true
    end
end)

hook.Add("HUDPaint", "MYRP_PhysicalHold_Hint", function()
    if (!physicalHoldActive) then return end

    draw.SimpleText(
        "Нажми ЛКМ, чтобы бросить",
        "DermaDefault",
        ScrW() * 0.5,
        ScrH() * 0.79,
        Color(235, 240, 245, 145),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )
end)

hook.Add("PlayerBindPress", "MYRP_WeaponInteraction_Keys", function(client, bind, pressed)
    if (client != LocalPlayer()) then return end

    bind = string.lower(bind or "")

    if (physicalHoldActive and bind == "+attack") then
        if (pressed) then
            SendHoldOperation("throw")
            physicalHoldActive = false
            physicalHoldPending = false
            pendingUseEntity = nil
        end

        return true
    end

    if (bind == "+use") then
        if (pressed) then
            if (IsValid(pendingUseEntity)) then return true end

            local entity, _, hasItem = GetWeaponTarget()

            if (!IsValid(entity)) then return end

            pendingUseEntity = entity
            pendingUseHasItem = hasItem
            pendingUseTime = CurTime()

            return true
        end

        if (!IsValid(pendingUseEntity)) then
            pendingUseEntity = nil
            return
        end

        if (physicalHoldActive or physicalHoldPending) then
            SendHoldOperation("release")
            physicalHoldActive = false
            physicalHoldPending = false
            pendingUseEntity = nil
            return true
        end

        local entity = pendingUseEntity
        pendingUseEntity = nil

        if (!pendingUseHasItem) then
            PlayUI("denied")
            return true
        end

        local actions = {"equip", "store"}

        PlayUI("confirm")

        net.Start("MYRP_WeaponInteraction_Action")
            net.WriteEntity(entity)
            net.WriteString(actions[selectedAction])
        net.SendToServer()

        return true
    end

    -- While E is held, only suppress weapon-wheel binds.
    -- Movement and jump binds must pass through normally.
    if (IsValid(pendingUseEntity) and (bind == "invnext" or bind == "invprev")) then
        return true
    end

    local entity = GetWeaponTarget()

    if (!IsValid(entity)) then return end

    if (bind == "invnext" or bind == "invprev") then
        if (bind == "invnext") then
            selectedAction = selectedAction % 2 + 1
        else
            selectedAction = (selectedAction - 2) % 2 + 1
        end

        PlayUI("hover")
        return true
    end
end)

-- Helix's Weapon Select plugin runs before ordinary hook.Add callbacks.
-- Wrap its cached callback so MYRP gets first refusal over the wheel binds.
hook.Add("InitializedPlugins", "MYRP_WeaponInteraction_PatchWeaponSelect", function()
    local weaponSelect = ix.plugin.Get("wepselect")
    local callbacks = HOOKS_CACHE and HOOKS_CACHE.PlayerBindPress

    if (!weaponSelect or !callbacks or !callbacks[weaponSelect]) then return end

    if (weaponSelectPatchApplied) then return end

    local original = callbacks[weaponSelect]

    local wrapped = function(self, client, bind, pressed)
        local lowerBind = string.lower(bind or "")

        if (client == LocalPlayer() and pressed and
            (lowerBind:find("invnext", 1, true) or lowerBind:find("invprev", 1, true)) and
            IsValid(GetWeaponTarget())) then
            return true
        end

        return original(self, client, bind, pressed)
    end

    callbacks[weaponSelect] = wrapped
    weaponSelectPatchApplied = true
end)

-- Hide Helix's default entity tooltip only for weapons handled by MYRP.
local function IsMYRPWeaponEntity(entity)
    if (!IsValid(entity)) then return false end

    local class = entity:GetClass()

    if (class == "ix_item") then
        local item = entity:GetItemTable()
        return item and item.isWeapon == true or false
    end

    return (entity.IsWeapon and entity:IsWeapon())
        or string.sub(class, 1, 7) == "weapon_"
end

hook.Add("ShouldPopulateEntityInfo", "MYRP_WeaponInteraction_HideHelixWeaponInfo", function(entity)
    if (IsMYRPWeaponEntity(entity)) then
        return false
    end
end)

hook.Add("HUDShouldDraw", "MYRP_WeaponInteraction_HideWeaponSelection", function(name)
    if (name != "CHudWeaponSelection") then return end

    local entity = GetWeaponTarget()

    if (IsValid(entity)) then
        return false
    end
end)