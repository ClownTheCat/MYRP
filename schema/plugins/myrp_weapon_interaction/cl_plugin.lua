local selectedAction = 1
local selectedEntity
local pendingUseEntity
local pendingUseHasItem = false
local pendingUseIsCorpse = false
local pendingUseTime = 0
local physicalHoldActive = false
local physicalHoldPending = false
local weaponSelectPatchApplied = false
local lastCorpseTraceSignature = ""

local function CorpseClientLog(message)
    MsgC(Color(115, 185, 225), "[MYRP:CORPSES][CLIENT] ",
        color_white, tostring(message) .. "\n")
end

local actionNames = {
    "Взять в руки",
    "Положить в инвентарь"
}

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

local function PlayUI(kind)
    if (MYRP and MYRP.UI and MYRP.UI.PlaySound) then
        MYRP.UI.PlaySound(kind)
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

    -- Listed HL2 pickups may have no VPhysics object, but can still be stored.
    if (supportedEntityClasses[class]) then return true end

    local physics = entity:GetPhysicsObject()
    return entity:GetMoveType() == MOVETYPE_VPHYSICS and IsValid(physics)
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
    if (blockedWorldClasses[class]) then return end

    if (class == "prop_ragdoll") then
        local signature = tostring(entity:EntIndex()) .. "|"
            .. tostring(entity:GetNW2Bool("myrp_corpse", false)) .. "|"
            .. entity:GetNW2String("myrp_corpse_name", "")
        if (signature != lastCorpseTraceSignature) then
            lastCorpseTraceSignature = signature
            CorpseClientLog("Trace ragdoll: ent=" .. entity:EntIndex()
                .. ", marked=" .. tostring(entity:GetNW2Bool("myrp_corpse", false))
                .. ", name=" .. entity:GetNW2String("myrp_corpse_name", "<none>"))
        end
    elseif (lastCorpseTraceSignature != "") then
        lastCorpseTraceSignature = ""
    end

    local itemName
    local hasItem = false
    local isCorpse = false

    if (class == "ix_item") then
        local item = entity:GetItemTable()

        if (!item or blockedWorldClasses[item.class] or (!item.isWeapon and item.uniqueID != "myrp_world_object")) then
            return
        end

        itemName = item:GetName() or "Предмет"
        hasItem = true
    elseif (class == "prop_ragdoll" and entity:GetNW2Bool("myrp_corpse", false)) then
        itemName = entity:GetNW2String("myrp_corpse_name", "Труп")
        hasItem = true
        isCorpse = true
    elseif (IsWeaponEntity(entity)) then
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
    elseif (IsPhysicalWorldObject(entity)) then
        itemName = entity.PrintName or "Физический предмет"
        hasItem = true
    else
        return
    end

    return entity, itemName, hasItem, isCorpse == true
end

local menuProgress = 0
local menuDisplayName = "Оружие"
local menuRowProgress = {0, 0}

surface.CreateFont("MYRP_WeaponMenu_Header", {
    font = "Roboto",
    size = 13,
    weight = 800,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_WeaponMenu_Title", {
    font = "Roboto",
    size = 21,
    weight = 700,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_WeaponMenu_Body", {
    font = "Roboto",
    size = 16,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("MYRP_WeaponMenu_Hint", {
    font = "Roboto",
    size = 13,
    weight = 500,
    antialias = true,
    extended = true
})

local function FadeColor(color, alpha)
    return Color(color.r, color.g, color.b, math.Clamp(alpha, 0, 255))
end

local function DrawConnector(entity, x, y, width, height, accent, alpha)
    if (!IsValid(entity)) then return end

    local anchor = entity:WorldSpaceCenter():ToScreen()
    if (!anchor.visible) then return end

    local centerX = x + width * 0.5
    local centerY = y + height * 0.5
    local dx = anchor.x - centerX
    local dy = anchor.y - centerY
    local attachX, attachY

    if (math.abs(dx) / width > math.abs(dy) / height) then
        attachX = dx < 0 and x or x + width
        attachY = math.Clamp(anchor.y, y + 14, y + height - 14)
    else
        attachY = dy < 0 and y or y + height
        attachX = math.Clamp(anchor.x, x + 14, x + width - 14)
    end

    surface.SetDrawColor(0, 0, 0, math.floor(alpha * 0.48))
    surface.DrawLine(anchor.x, anchor.y + 2, attachX, attachY + 2)

    surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(alpha * 0.78))
    surface.DrawLine(anchor.x, anchor.y, attachX, attachY)

    surface.DrawCircle(anchor.x, anchor.y, 5, FadeColor(accent, alpha))
    surface.DrawCircle(anchor.x, anchor.y, 2, Color(235, 244, 252, alpha))
end

local function DrawWeaponMenuPanel(x, y, width, height, theme, accent, alpha)
    local pulse = (math.sin(CurTime() * 2.1) + 1) * 0.5
    local glow = theme.glow or accent
    local panel = theme.panel or Color(8, 15, 22, 220)
    local inner = theme.panelInner or Color(15, 25, 36, 220)

    draw.RoundedBox(11, x - 4, y - 4, width + 8, height + 8,
        Color(glow.r, glow.g, glow.b, math.floor(alpha * (0.07 + pulse * 0.035))))
    draw.RoundedBox(9, x, y, width, height,
        Color(panel.r, panel.g, panel.b, math.floor(alpha * 0.94)))
    draw.RoundedBox(8, x + 1, y + 1, width - 2, height - 2,
        Color(inner.r, inner.g, inner.b, math.floor(alpha * 0.91)))

    surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(alpha * 0.62))
    surface.DrawOutlinedRect(x, y, width, height, 1)

    draw.RoundedBox(3, x + 2, y + 2, width - 4, 3,
        Color(accent.r, accent.g, accent.b, math.floor(alpha * 0.78)))

    -- Small technical corner marks give the panel the MYRP terminal look.
    surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(alpha * 0.65))
    surface.DrawLine(x + 12, y + 12, x + 28, y + 12)
    surface.DrawLine(x + 12, y + 12, x + 12, y + 25)
    surface.DrawLine(x + width - 12, y + height - 12, x + width - 28, y + height - 12)
    surface.DrawLine(x + width - 12, y + height - 12, x + width - 12, y + height - 25)
end

hook.Add("HUDPaint", "MYRP_WeaponInteraction_TargetUI", function()
    local entity, itemName, hasItem, isCorpse = GetWeaponTarget()
    local targetVisible = IsValid(entity)
    local currentActionNames = isCorpse and {"Тащить", "Залезть в карманы"} or actionNames

    if (targetVisible) then
        if (selectedEntity != entity) then
            selectedEntity = entity
            selectedAction = 1
            menuRowProgress[1] = 0
            menuRowProgress[2] = 0
        end

        menuDisplayName = itemName or "Оружие"
    end

    local frameTime = math.min(FrameTime(), 0.05)
    local targetProgress = targetVisible and 1 or 0
    menuProgress = Lerp(1 - math.exp(-frameTime * 11), menuProgress, targetProgress)

    if (menuProgress <= 0.005) then
        if (!targetVisible) then
            selectedEntity = nil
            selectedAction = 1
        end
        return
    end

    local client = LocalPlayer()
    local width, height = 356, 202
    local x = math.min(ScrW() * 0.5 + 38, ScrW() - width - 20)
    local y = math.min(ScrH() * 0.5 + 34, ScrH() - height - 20)

    x = math.max(20, x)
    y = math.max(20, y)

    local theme
    local accent = Color(110, 175, 255)

    if (MYRP and MYRP.UI) then
        if (MYRP.UI.GetTheme) then
            theme = MYRP.UI.GetTheme(client)
        end

        if (MYRP.UI.GetAccent) then
            local result = MYRP.UI.GetAccent(client)
            if (IsColor(result)) then accent = result end
        end
    end

    local slide = (1 - menuProgress) * 17
    local drawX, drawY = x + slide, y + slide * 0.35
    local alpha = math.floor(255 * menuProgress)

    if (targetVisible) then
        DrawConnector(entity, drawX, drawY, width, height, accent, alpha)
    end

    DrawWeaponMenuPanel(drawX, drawY, width, height, theme, accent, alpha)

    draw.SimpleText("MYRP  /  ВЗАИМОДЕЙСТВИЕ", "MYRP_WeaponMenu_Header",
        drawX + 19, drawY + 18, FadeColor(accent, alpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    draw.SimpleText(menuDisplayName, "MYRP_WeaponMenu_Title",
        drawX + 19, drawY + 47, Color(235, 242, 249, alpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    draw.SimpleText("ДЕЙСТВИЕ", "MYRP_WeaponMenu_Header",
        drawX + 20, drawY + 78, Color(125, 151, 174, alpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    for i = 1, #currentActionNames do
        local selected = selectedAction == i
        local enabled = targetVisible and hasItem
        local targetRowProgress = selected and 1 or 0
        menuRowProgress[i] = Lerp(1 - math.exp(-frameTime * 14), menuRowProgress[i], targetRowProgress)

        local rowY = drawY + 91 + (i - 1) * 27
        local rowAmount = menuRowProgress[i]
        local rowAlpha = alpha * rowAmount

        if (rowAmount > 0.01) then
            draw.RoundedBox(5, drawX + 12, rowY, width - 24, 24,
                Color(accent.r, accent.g, accent.b, math.floor(rowAlpha * 0.19)))
            draw.RoundedBox(2, drawX + 12, rowY + 4, 3, 16,
                Color(accent.r, accent.g, accent.b, math.floor(rowAlpha * 0.95)))
            draw.RoundedBox(2, drawX + 17, rowY + 4, 1, 16,
                Color(accent.r, accent.g, accent.b, math.floor(rowAlpha * 0.25)))
        end

        local textColor
        if (!enabled) then
            textColor = Color(115, 128, 141, alpha)
        elseif (selected) then
            textColor = Color(242, 247, 252, alpha)
        else
            textColor = Color(180, 196, 210, alpha)
        end

        local prefix = selected and "›" or "·"
        draw.SimpleText(prefix .. "  " .. currentActionNames[i], "MYRP_WeaponMenu_Body",
            drawX + 25, rowY + 12, textColor,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if (selected and !enabled) then
            draw.SimpleText("НЕДОСТУПНО", "MYRP_WeaponMenu_Header",
                drawX + width - 22, rowY + 12, Color(140, 145, 152, alpha),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    surface.SetDrawColor(accent.r, accent.g, accent.b, math.floor(alpha * 0.24))
    surface.DrawLine(drawX + 18, drawY + 151, drawX + width - 18, drawY + 151)

    draw.SimpleText(isCorpse and "УДЕРЖИВАЙ E  /  ТАЩИТЬ" or "УДЕРЖИВАЙ E  /  ФИЗИЧЕСКИ ПОДНЯТЬ", "MYRP_WeaponMenu_Hint",
        drawX + 19, drawY + 166, Color(205, 217, 228, alpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    draw.SimpleText("КОЛЕСО — ВЫБОР     ·     E — ПОДТВЕРДИТЬ", "MYRP_WeaponMenu_Hint",
        drawX + 19, drawY + 186, Color(132, 153, 172, alpha),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
        (!pendingUseIsCorpse or selectedAction == 1) and
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
            pendingUseIsCorpse = false
        end

        return true
    end

    if (bind == "+use") then
        if (pressed) then
            if (IsValid(pendingUseEntity)) then return true end

            local entity, _, hasItem, isCorpse = GetWeaponTarget()

            if (!IsValid(entity)) then return end

            pendingUseEntity = entity
            pendingUseHasItem = hasItem
            pendingUseIsCorpse = isCorpse
            pendingUseTime = CurTime()

            CorpseClientLog("E down: " .. entity:GetClass() .. "#" .. entity:EntIndex()
                .. ", corpse=" .. tostring(isCorpse)
                .. ", hasItem=" .. tostring(hasItem)
                .. ", selectedAction=" .. tostring(selectedAction))

            return true
        end

        if (!IsValid(pendingUseEntity)) then
            pendingUseEntity = nil
            pendingUseIsCorpse = false
            return
        end

        if (physicalHoldActive or physicalHoldPending) then
            SendHoldOperation("release")
            physicalHoldActive = false
            physicalHoldPending = false
            pendingUseEntity = nil
            pendingUseIsCorpse = false
            return true
        end

        local entity = pendingUseEntity
        local isCorpse = pendingUseIsCorpse
        pendingUseEntity = nil
        pendingUseIsCorpse = false

        if (isCorpse) then
            CorpseClientLog("E up: entityValid=" .. tostring(IsValid(entity))
                .. ", selectedAction=" .. tostring(selectedAction)
                .. ", ent=" .. tostring(IsValid(entity) and entity:EntIndex() or -1))

            if (selectedAction == 1) then
                PlayUI("denied")
                return true
            end

            PlayUI("confirm")
            net.Start("MYRP_WeaponInteraction_Action")
                net.WriteEntity(entity)
                net.WriteString("pockets")
            net.SendToServer()
            CorpseClientLog("Sent pockets action to server.")
            return true
        end

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
        return item and (item.isWeapon == true or item.uniqueID == "myrp_world_object") or false
    end

    if (blockedWorldClasses[class]) then return false end

    return (entity.IsWeapon and entity:IsWeapon())
        or string.sub(class, 1, 7) == "weapon_"
end

hook.Add("ShouldPopulateEntityInfo", "MYRP_WeaponInteraction_HideHelixWeaponInfo", function(entity)
    if (IsMYRPWeaponEntity(entity)) then
        return false
    end

    if (IsValid(entity) and entity:IsPlayer() and entity:IsBot()
        and entity:GetNW2Bool("myrp_testbot_dead", false)) then
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