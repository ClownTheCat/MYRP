-- MYRP Match Flow client UI.
-- This is an additive respawn menu; the existing faction-selection UI,
-- scoreboard and inventory remain untouched.

if not CLIENT then return end

local RESPAWN_MENU_NAME = "myrpMatchflowRespawnMenu"
local currentMenu
local currentStatus
local selectedClassID
local selectedModel
local selectedFactionID
local previewPanel
local respawnTimerEndsAt
local respawnTimerDuration = 30
local backgroundMaterial = Material("myrp/factions/background.jpg", "smooth")

local function Log(level, message)
    MsgC(Color(100, 185, 220), "[MYRP:MATCHFLOW][CLIENT][" .. tostring(level) .. "] "
        .. tostring(message) .. "\n")
end

local function GetFactionModelOptions(faction, client)
    local source = faction.GetModels and faction:GetModels(client) or faction.models or {}
    local result = {}

    for _, entry in SortedPairs(source) do
        local modelPath = isstring(entry) and entry or (istable(entry) and entry[1])

        if isstring(modelPath)
            and modelPath ~= ""
            and modelPath ~= "models/error.mdl"
            and util.IsValidModel(modelPath) then

            result[#result + 1] = modelPath
        end
    end

    return result
end

local function GetFactionClasses(faction)
    local result = {}

    for _, class in pairs(ix.class.list or {}) do
        if class.faction == faction.index and isstring(class.uniqueID) then
            result[#result + 1] = class
        end
    end

    table.sort(result, function(a, b)
        return string.lower(tostring(a.name or a.uniqueID))
            < string.lower(tostring(b.name or b.uniqueID))
    end)

    return result
end

local function GetModelDisplayName(modelPath)
    local name = string.GetFileFromFilename(modelPath or "") or tostring(modelPath or "")
    name = string.gsub(name, "%.mdl$", "")
    name = string.gsub(name, "_", " ")
    return string.upper(name)
end

local function CloseRespawnMenu()
    if IsValid(currentMenu) then
        currentMenu:Remove()
    end

    currentMenu = nil
    currentStatus = nil
    previewPanel = nil
    selectedClassID = nil
    selectedModel = nil
    selectedFactionID = nil
    respawnTimerEndsAt = nil

    if ix.gui then
        ix.gui[RESPAWN_MENU_NAME] = nil
    end

    gui.EnableScreenClicker(false)
end

local function SetStatus(message, isError)
    if not IsValid(currentStatus) then return end

    currentStatus:SetText(message or "")
    currentStatus:SetTextColor(isError and Color(240, 115, 100) or Color(170, 205, 225))
end

local function UpdatePreview(modelPath)
    if not IsValid(previewPanel) then return end

    previewPanel:SetModel(modelPath)
    previewPanel:SetFOV(34)
    previewPanel:SetLookAt(Vector(0, 0, 36))
    previewPanel:SetCamPos(Vector(82, 0, 39))
end

local function OpenRespawnMenu(factionID)
    local client = LocalPlayer()
    if not IsValid(client) then return end

    factionID = string.lower(tostring(factionID or ""))

    local faction = ix.faction.Get(factionID)
    if not faction then
        Log("ERROR", "Unknown faction received from server: " .. factionID)
        return
    end

    if IsValid(currentMenu) then
        currentMenu:Remove()
    end

    selectedClassID = nil
    selectedModel = nil
    selectedFactionID = factionID
    respawnTimerEndsAt = nil

    local classOptions = GetFactionClasses(faction)
    local modelOptions = GetFactionModelOptions(faction, client)

    local factionColor = faction.color or Color(110, 165, 210)
    local frame = vgui.Create("DPanel")
    if not IsValid(frame) then return end

    frame:SetName("MYRPMatchflowRespawnRoot")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetZPos(32760)
    frame:MakePopup()
    frame:SetMouseInputEnabled(true)
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(self, w, h)
        surface.SetDrawColor(3, 7, 12, 225)
        surface.DrawRect(0, 0, w, h)

        if backgroundMaterial and not backgroundMaterial:IsError() then
            surface.SetMaterial(backgroundMaterial)
            surface.SetDrawColor(170, 185, 200, 55)
            surface.DrawTexturedRect(0, 0, w, h)
            surface.SetDrawColor(2, 6, 11, 190)
            surface.DrawRect(0, 0, w, h)
        end

        draw.SimpleText("MYRP  /  REDEPLOYMENT", "DermaLarge", w * 0.5, h * 0.5 - 245,
            Color(225, 235, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ВЫБОР ПРОФЕССИИ", "Trebuchet24", w * 0.5, h * 0.5 - 205,
            factionColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ФРАКЦИЯ: " .. string.upper(faction.name or factionID), "Trebuchet18",
            w * 0.5, h * 0.5 - 174, Color(180, 197, 212), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    currentMenu = frame
    if ix.gui then
        ix.gui[RESPAWN_MENU_NAME] = frame
    end

    local cardW, cardH = math.min(850, ScrW() - 80), math.min(470, ScrH() - 300)
    local cardX, cardY = (ScrW() - cardW) * 0.5, (ScrH() - cardH) * 0.5 + 35

    local card = vgui.Create("DPanel", frame)
    card:SetPos(cardX, cardY)
    card:SetSize(cardW, cardH)
    card.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(8, 16, 25, 245))
        surface.SetDrawColor(factionColor.r, factionColor.g, factionColor.b, 170)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(factionColor.r, factionColor.g, factionColor.b, 180)
        surface.DrawRect(1, 1, w - 2, 3)
        draw.SimpleText("ДОСТУПНЫЕ ПРОФЕССИИ", "Trebuchet18", 24, 25,
            Color(215, 226, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local classPanel = vgui.Create("DScrollPanel", card)
    classPanel:SetPos(22, 55)
    classPanel:SetSize(math.floor(cardW * 0.43), cardH - 78)

    local classY = 0
    for _, class in ipairs(classOptions) do
        local classButton = classPanel:Add("DButton")
        classButton:SetPos(0, classY)
        classButton:SetSize(classPanel:GetWide() - 12, 76)
        classButton:SetText("")
        classButton:SetCursor("hand")
        classButton.Paint = function(self, w, h)
            local isSelected = selectedClassID == class.uniqueID
            local hovered = self:IsHovered()
            draw.RoundedBox(5, 0, 0, w, h,
                isSelected and Color(factionColor.r, factionColor.g, factionColor.b, 48)
                or Color(18, 29, 41, hovered and 245 or 205))
            surface.SetDrawColor(factionColor.r, factionColor.g, factionColor.b,
                isSelected and 230 or (hovered and 130 or 55))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(string.upper(class.name or class.uniqueID), "Trebuchet24",
                16, 25, Color(235, 241, 247), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(class.description or class.uniqueID, "DermaDefault",
                16, 51, Color(155, 174, 191), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        classButton.DoClick = function()
            selectedClassID = class.uniqueID
            SetStatus("Профессия выбрана. Проверьте модель и подтвердите возвращение.", false)
            classPanel:InvalidateLayout(true)
        end

        classY = classY + 86
    end

    if #classOptions == 0 then
        local noClasses = classPanel:Add("DLabel")
        noClasses:SetPos(4, 8)
        noClasses:SetSize(classPanel:GetWide() - 12, 48)
        noClasses:SetText("Для этой фракции пока нет доступных профессий.")
        noClasses:SetTextColor(Color(235, 120, 105))
        noClasses:SetWrap(true)
    end

    local rightX = math.floor(cardW * 0.48)
    local rightW = cardW - rightX - 24

    local modelLabel = vgui.Create("DLabel", card)
    modelLabel:SetPos(rightX, 62)
    modelLabel:SetSize(rightW, 24)
    modelLabel:SetText("ВНЕШНОСТЬ")
    modelLabel:SetFont("DermaDefaultBold")
    modelLabel:SetTextColor(Color(190, 207, 222))

    local modelCombo = vgui.Create("DComboBox", card)
    modelCombo:SetPos(rightX, 91)
    modelCombo:SetSize(rightW, 30)
    modelCombo:SetValue(#modelOptions > 0 and GetModelDisplayName(modelOptions[1]) or "МОДЕЛИ НЕ НАЙДЕНЫ")

    if #modelOptions > 0 then
        selectedModel = modelOptions[1]
        for index, modelPath in ipairs(modelOptions) do
            modelCombo:AddChoice(GetModelDisplayName(modelPath), modelPath, index == 1)
        end
    end

    previewPanel = vgui.Create("DModelPanel", card)
    previewPanel:SetPos(rightX + 25, 135)
    previewPanel:SetSize(math.max(160, rightW - 50), math.max(150, cardH - 230))
    previewPanel:SetMouseInputEnabled(false)

    if selectedModel then
        UpdatePreview(selectedModel)
    end

    modelCombo.OnSelect = function(_, index, value, data)
        selectedModel = data
        UpdatePreview(selectedModel)
    end

    currentStatus = vgui.Create("DLabel", frame)
    currentStatus:SetPos(0, cardY + cardH + 16)
    currentStatus:SetSize(ScrW(), 26)
    currentStatus:SetFont("DermaDefaultBold")
    currentStatus:SetContentAlignment(5)
    currentStatus:SetText("ВЫБЕРИТЕ ПРОФЕССИЮ И НАЖМИТЕ «ВОЗРОДИТЬСЯ»")
    currentStatus:SetTextColor(Color(170, 205, 225))

    local accept = vgui.Create("DButton", frame)
    accept:SetPos(ScrW() * 0.5 - 145, cardY + cardH + 52)
    accept:SetSize(290, 48)
    accept:SetText("ВОЗРОДИТЬСЯ")
    accept:SetFont("Trebuchet18")
    accept:SetTextColor(Color(245, 248, 250))
    accept.Paint = function(self, w, h)
        draw.RoundedBox(5, 0, 0, w, h,
            self:IsEnabled() and Color(factionColor.r, factionColor.g, factionColor.b, self:IsHovered() and 230 or 175)
            or Color(55, 65, 75, 180))
        surface.SetDrawColor(220, 235, 245, 90)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    accept:SetEnabled(#classOptions > 0 and #modelOptions > 0)
    accept.DoClick = function()
        if not selectedClassID or not selectedModel then
            SetStatus("Сначала выберите профессию и модель.", true)
            return
        end

        accept:SetEnabled(false)
        SetStatus("ОТПРАВКА ЗАПРОСА НА ВОЗРОЖДЕНИЕ...", false)

        net.Start("myrpMatchflowSelectProfession")
            net.WriteString(selectedClassID)
            net.WriteString(selectedModel)
        net.SendToServer()

        Log("INFO", "Respawn selection sent: faction=" .. factionID
            .. ", class=" .. selectedClassID .. ", model=" .. selectedModel)
    end

    frame.OnRemove = function()
        if ix.gui and ix.gui[RESPAWN_MENU_NAME] == frame then
            ix.gui[RESPAWN_MENU_NAME] = nil
        end
        currentMenu = nil
        currentStatus = nil
        previewPanel = nil
        gui.EnableScreenClicker(false)
    end

    frame:MoveToFront()
    gui.EnableScreenClicker(true)

    Log("INFO", "Respawn profession menu opened: faction=" .. factionID
        .. ", classes=" .. #classOptions .. ", models=" .. #modelOptions)
end

-- ---------------------------------------------------------------------------
-- Native Helix ixDeathScreen suppression.
--
-- Helix's stock cl_hooks receiver creates vgui.Create("ixDeathScreen") on
-- ixPlayerDeath. Do not replace that net receiver: keep the real panel alive
-- so Helix's PostDrawHUD continues suppressing its own action bar, but patch
-- the panel at creation time before its first paint.
--
-- We intercept both vgui.Register (to patch the ixDeathScreen class table) and
-- vgui.Create (to patch every live instance). A Think watchdog reinstalls the
-- wrappers if another addon overwrites either function later.
-- ---------------------------------------------------------------------------

local nativeDeathClassPaintPatched = false
local nativeDeathInstancePaintPatched = false
local nativeCreateInterceptorInstalled = false
local nativeRegisterInterceptorInstalled = false
local nativeDeathReceiverInstalled = false
local originalVGUICreate
local createInterceptor
local originalVGUIRegister
local registerInterceptor

local function IsNativeDeathPanelClass(panel)
    if not IsValid(panel) then return false end

    local className = tostring(panel.ClassName or "")
    local panelName = ""

    if panel.GetName then
        panelName = tostring(panel:GetName() or "")
    end

    return className == "ixDeathScreen"
        or panelName == "ixDeathScreen"
        or panelName == "ix.gui.deathScreen"
end

local function PatchNativeDeathPanelInstance(panel, source)
    if not IsValid(panel) then return false end

    panel.ixMyRPNativeDeathPaintSuppressed = true
    panel.ixMyRPDeathPatchSource = source or "unknown"
    panel.Paint = function() end
    panel.PaintOver = function() end

    -- Alpha zero also suppresses any child painting the base Panel may perform.
    -- Keep the panel valid and logically present for Helix's PostDrawHUD and
    -- player_spawn lifecycle checks.
    panel:SetAlpha(0)

    if IsValid(panel.label) then
        panel.label:SetAlpha(0)
        panel.label:SetVisible(false)
    end

    nativeDeathInstancePaintPatched = true
    return true
end

local function PatchNativeDeathPanelClass(control)
    if not istable(control) then return false end

    control.ixMyRPNativePaintSuppressed = true
    control.ixMyRPOriginalPaint = control.ixMyRPOriginalPaint or control.Paint
    control.ixMyRPOriginalPaintOver = control.ixMyRPOriginalPaintOver or control.PaintOver
    control.Paint = function() end
    control.PaintOver = function() end

    nativeDeathClassPaintPatched = true
    return true
end

local function PatchExistingNativeDeathPanels()
    if vgui and vgui.GetControlTable then
        local control = vgui.GetControlTable("ixDeathScreen")
        if istable(control) then
            PatchNativeDeathPanelClass(control)
        end
    end

    if ix and ix.gui and IsValid(ix.gui.deathScreen)
        and not ix.gui.deathScreen.ixMyRPDeathSentinel then
        PatchNativeDeathPanelInstance(ix.gui.deathScreen, "ix.gui.deathScreen")
    end

    if vgui and vgui.GetAll then
        for _, panel in ipairs(vgui.GetAll()) do
            if IsNativeDeathPanelClass(panel) then
                PatchNativeDeathPanelInstance(panel, "vgui.GetAll")
            end
        end
    end
end

local function InstallVGUICreateInterceptor()
    if not vgui or not isfunction(vgui.Create) then return false end
    if vgui.Create == createInterceptor then
        nativeCreateInterceptorInstalled = true
        return true
    end

    originalVGUICreate = vgui.Create
    local previousCreate = originalVGUICreate

    createInterceptor = function(className, parent, name)
        local panel = previousCreate(className, parent, name)

        if isstring(className) and string.lower(className) == "ixdeathscreen" then
            PatchNativeDeathPanelInstance(panel, "vgui.Create interceptor")
            Log("INFO", "Suppressed native ixDeathScreen instance at creation")
        end

        return panel
    end

    vgui.Create = createInterceptor
    nativeCreateInterceptorInstalled = vgui.Create == createInterceptor
    return nativeCreateInterceptorInstalled
end

local function InstallVGUIRegisterInterceptor()
    if not vgui or not isfunction(vgui.Register) then return false end
    if vgui.Register == registerInterceptor then
        nativeRegisterInterceptorInstalled = true
        return true
    end

    originalVGUIRegister = vgui.Register
    local previousRegister = originalVGUIRegister

    registerInterceptor = function(className, panelTable, baseName)
        if isstring(className) and string.lower(className) == "ixdeathscreen" then
            PatchNativeDeathPanelClass(panelTable)
            Log("INFO", "Patched ixDeathScreen class during vgui.Register")
        end

        local result = previousRegister(className, panelTable, baseName)

        if isstring(className) and string.lower(className) == "ixdeathscreen" then
            PatchNativeDeathPanelClass(result or panelTable)
        end

        return result
    end

    vgui.Register = registerInterceptor
    nativeRegisterInterceptorInstalled = vgui.Register == registerInterceptor
    return nativeRegisterInterceptorInstalled
end

local function HandleNativeHelixPlayerDeath()
    -- This mirrors Helix's stock ixPlayerDeath receiver, but vgui.Create is
    -- already wrapped above, so the real native panel is made invisible before
    -- it can paint. Keeping the real instance preserves Helix's lifecycle.
    ix.gui = ix.gui or {}

    if IsValid(ix.gui.deathScreen) then
        ix.gui.deathScreen:Remove()
    end

    ix.gui.deathScreen = vgui.Create("ixDeathScreen")

    if IsValid(ix.gui.deathScreen) then
        PatchNativeDeathPanelInstance(ix.gui.deathScreen, "ixPlayerDeath receiver")
        Log("INFO", "Helix death packet handled; native panel created hidden")
    else
        Log("ERROR", "Could not create ixDeathScreen after ixPlayerDeath")
    end
end

local function InstallNativeDeathReceiver()
    if not net or not istable(net.Receivers) then return false end

    if net.Receivers["ixplayerdeath"] ~= HandleNativeHelixPlayerDeath then
        net.Receive("ixPlayerDeath", HandleNativeHelixPlayerDeath)
    end

    nativeDeathReceiverInstalled = net.Receivers["ixplayerdeath"] == HandleNativeHelixPlayerDeath
    return nativeDeathReceiverInstalled
end

local function InstallNativeDeathScreenSuppression(reason)
    InstallVGUIRegisterInterceptor()
    InstallVGUICreateInterceptor()
    PatchExistingNativeDeathPanels()
    InstallNativeDeathReceiver()

    if nativeCreateInterceptorInstalled or nativeDeathClassPaintPatched then
        Log("INFO", "Native Helix death screen suppression active; source="
            .. tostring(reason or "unknown")
            .. ", classPatched=" .. tostring(nativeDeathClassPaintPatched)
            .. ", createInterceptor=" .. tostring(nativeCreateInterceptorInstalled)
            .. ", deathReceiver=" .. tostring(nativeDeathReceiverInstalled))
    end
end

InstallNativeDeathScreenSuppression("plugin init")
timer.Simple(0, function()
    InstallNativeDeathScreenSuppression("deferred plugin init")
end)

hook.Add("Think", "MYRP.MatchFlow.NativeDeathScreenGuard", function()
    -- A plugin or Helix auto-refresh may replace VGUI functions or the network
    -- receiver. Reclaim them so the stock receiver always creates a hidden panel.
    if not vgui or vgui.Create ~= createInterceptor
        or vgui.Register ~= registerInterceptor
        or not net or not istable(net.Receivers)
        or net.Receivers["ixplayerdeath"] ~= HandleNativeHelixPlayerDeath then
        InstallNativeDeathScreenSuppression("Think watchdog")
    end

    PatchExistingNativeDeathPanels()
end)

-- Let Helix's own player_spawn receiver close its real, but invisible,
-- ixDeathScreen instance. We only clear our countdown state here.
hook.Add("player_spawn", "MYRP.MatchFlow.ClearDeathScreenState", function(data)
    local client = Player(data.userid)
    if client == LocalPlayer() then
        respawnTimerEndsAt = nil
    end
end)

net.Receive("myrpMatchflowRespawnTimer", function()
    local duration = math.Clamp(net.ReadUInt(8), 0, 255)

    -- The stock Helix receiver creates the real ixDeathScreen. The VGUI
    -- interception above hides it while preserving its normal lifecycle.
    PatchExistingNativeDeathPanels()
    respawnTimerDuration = math.max(duration, 1)
    respawnTimerEndsAt = CurTime() + duration

    Log("INFO", "Respawn countdown started: " .. duration .. " seconds")
end)

net.Receive("myrpMatchflowOpenRespawn", function()
    local factionID = net.ReadString()
    respawnTimerEndsAt = nil
    OpenRespawnMenu(factionID)
end)

net.Receive("myrpMatchflowRespawnResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()

    if success then
        Log("INFO", "Respawn accepted by server")
        CloseRespawnMenu()
        return
    end

    Log("WARN", "Respawn rejected: " .. tostring(message))
    SetStatus(message ~= "" and message or "Сервер отклонил запрос.", true)

    if IsValid(currentMenu) then
        for _, child in ipairs(currentMenu:GetChildren()) do
            if IsValid(child) and child:GetClassName() == "DButton" and child:GetText() == "ВОЗРОДИТЬСЯ" then
                child:SetEnabled(true)
            end
        end
    end
end)

concommand.Add("myrp_matchflow_death_status", function()
    local panel = ix and ix.gui and ix.gui.deathScreen
    local className = IsValid(panel) and tostring(panel.ClassName or panel:GetClassName()) or "none"
    Log("INFO", "DEATH_STATUS playerValid=" .. tostring(IsValid(LocalPlayer()))
        .. ", alive=" .. tostring(IsValid(LocalPlayer()) and LocalPlayer():Alive() or false)
        .. ", panelValid=" .. tostring(IsValid(panel))
        .. ", panelVisible=" .. tostring(IsValid(panel) and panel:IsVisible() or false)
        .. ", panelAlpha=" .. tostring(IsValid(panel) and panel:GetAlpha() or -1)
        .. ", panelClass=" .. className
        .. ", instancePaintPatched=" .. tostring(IsValid(panel) and panel.ixMyRPNativeDeathPaintSuppressed or false)
        .. ", nativeDeathClassPaintPatched=" .. tostring(nativeDeathClassPaintPatched)
        .. ", nativeDeathInstancePaintPatched=" .. tostring(nativeDeathInstancePaintPatched)
        .. ", createInterceptor=" .. tostring(nativeCreateInterceptorInstalled)
        .. ", registerInterceptor=" .. tostring(nativeRegisterInterceptorInstalled)
        .. ", deathReceiver=" .. tostring(nativeDeathReceiverInstalled)
        .. ", overlayHook=DrawOverlay")
end)

concommand.Add("myrp_matchflow_ui_status", function()
    local secondsLeft = respawnTimerEndsAt and math.max(0, math.ceil(respawnTimerEndsAt - CurTime())) or nil

    Log("INFO", "menuOpen=" .. tostring(IsValid(currentMenu))
        .. ", faction=" .. tostring(selectedFactionID)
        .. ", class=" .. tostring(selectedClassID)
        .. ", model=" .. tostring(selectedModel)
        .. ", respawnSecondsLeft=" .. tostring(secondsLeft))
end)

-- Minimal death overlay: no panel, background, card or progress bar.
-- The text is drawn directly over the world, centered on the screen.
local DEATH_TITLE_FONT = "MYRP_MatchFlow_DeathTitle"
local DEATH_TIMER_FONT = "MYRP_MatchFlow_DeathTimer"
local deathFontW, deathFontH

local function CreateDeathFonts()
    local width, height = ScrW(), ScrH()
    if deathFontW == width and deathFontH == height then return end

    deathFontW, deathFontH = width, height
    surface.CreateFont(DEATH_TITLE_FONT, {
        font = "Arial",
        size = math.Clamp(math.floor(height * 0.060), 42, 76),
        weight = 1000,
        extended = true,
        antialias = true
    })
    surface.CreateFont(DEATH_TIMER_FONT, {
        font = "Arial",
        size = math.Clamp(math.floor(height * 0.029), 22, 36),
        weight = 800,
        extended = true,
        antialias = true
    })
end

local function DrawCenteredColorSegments(y, font, segments)
    surface.SetFont(font)

    local totalWidth = 0
    for _, segment in ipairs(segments) do
        local width = surface.GetTextSize(segment.text)
        segment.width = width
        totalWidth = totalWidth + width
    end

    local x = (ScrW() - totalWidth) * 0.5

    for _, segment in ipairs(segments) do
        draw.SimpleText(segment.text, font, x + 2, y + 2, Color(0, 0, 0, 210),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(segment.text, font, x, y, segment.color,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        x = x + segment.width
    end
end

hook.Add("DrawOverlay", "MYRP.MatchFlow.RespawnCountdown", function()
    if not respawnTimerEndsAt or IsValid(currentMenu) then
        return
    end

    local client = LocalPlayer()
    if not IsValid(client) or client:Alive() then return end

    CreateDeathFonts()

    local remaining = math.max(0, math.ceil(respawnTimerEndsAt - CurTime()))
    local minutes = math.floor(remaining / 60)
    local seconds = remaining % 60
    local countdown = string.format("%02d:%02d", minutes, seconds)
    local centerY = ScrH() * 0.5

    DrawCenteredColorSegments(centerY - 28, DEATH_TITLE_FONT, {
        {text = "YOU ARE ", color = Color(255, 255, 255)},
        {text = "DEAD", color = Color(255, 255, 255)}
    })

    DrawCenteredColorSegments(centerY + 42, DEATH_TIMER_FONT, {
        {text = "RESPAWN IN  ", color = Color(255, 255, 255)},
        {text = countdown, color = Color(255, 255, 255)}
    })
end)

Log("INFO", "Match Flow client module loaded; ixPlayerDeath creates the real ixDeathScreen through the patched vgui.Create and white countdown is drawn in DrawOverlay.")
