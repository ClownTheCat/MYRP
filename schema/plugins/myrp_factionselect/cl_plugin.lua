-- MYRP faction selection UI v2.2 + animated scoreboard + faction-themed Helix inventory.
-- Separate faction cards, hover/selection effects, Worker role panel and vanilla model picker.

local PLUGIN = PLUGIN

if not istable(PLUGIN) then
    MsgC(Color(235, 90, 80), "[MYRP:UI][CLIENT][ERROR] PLUGIN table unavailable; UI not loaded.\n")
    return
end

local BASE_W, BASE_H = 1920, 1080
local MENU_NAME = "myrpFactionMenu"

local function Log(level, message)
    local colors = {
        INFO = Color(90, 190, 140),
        WARN = Color(235, 175, 75),
        ERROR = Color(235, 90, 80),
        DEBUG = Color(115, 170, 220)
    }

    MsgC(colors[level] or color_white, "[MYRP:UI][CLIENT][" .. tostring(level) .. "] " .. tostring(message) .. "\n")
end

local function GetMYRPUI()
    return MYRP and MYRP.UI or nil
end

local function GetUITheme(factionOverride)
    local ui = GetMYRPUI()
    if (ui and ui.GetTheme) then
        return ui.GetTheme(LocalPlayer(), factionOverride)
    end

    local id = factionOverride
    if (!id and IsValid(LocalPlayer()) and LocalPlayer().GetCharacter) then
        local character = LocalPlayer():GetCharacter()
        if (character and character.GetFaction and ix and ix.faction and ix.faction.indices) then
            local faction = ix.faction.indices[tonumber(character:GetFaction()) or character:GetFaction()]
            id = faction and faction.uniqueID
        end
    end

    if (string.lower(tostring(id or "")) == "resistance") then
        return {accent = Color(214, 135, 91), accentBright = Color(239, 169, 121), glow = Color(218, 127, 78), panel = Color(22, 16, 13, 198), panelInner = Color(37, 26, 20, 170), border = Color(174, 111, 75, 105)}
    end
    return {accent = Color(91, 164, 225), accentBright = Color(139, 198, 245), glow = Color(75, 155, 225), panel = Color(9, 19, 30, 198), panelInner = Color(15, 29, 43, 170), border = Color(89, 145, 188, 105)}
end

local function PlayMYRPSound(kind)
    local ui = GetMYRPUI()
    if (ui and ui.PlaySound) then
        ui.PlaySound(kind)
    else
        surface.PlaySound(kind == "open" and "buttons/combine_button1.wav" or (kind == "close" and "buttons/combine_button2.wav" or "buttons/button15.wav"))
    end
end

local function AnimateMYRPIn(panel, duration, direction)
    local ui = GetMYRPUI()
    if (ui and ui.AnimateIn) then
        return ui.AnimateIn(panel, duration, direction)
    end
    panel:SetAlpha(0)
    panel:AlphaTo(255, duration or 0.22, 0)
    PlayMYRPSound("open")
    return true
end

local function AnimateMYRPOut(panel, duration, direction, callback)
    local ui = GetMYRPUI()
    if (ui and ui.AnimateOut) then
        return ui.AnimateOut(panel, duration, direction, callback)
    end
    panel:AlphaTo(0, duration or 0.16, 0, function() if callback then callback() end end)
    return true
end

local function SX(value)
    return math.floor(value * ScrW() / BASE_W)
end

local function SY(value)
    return math.floor(value * ScrH() / BASE_H)
end

local function UIResolution()
    return tostring(ScrW()) .. "x" .. tostring(ScrH())
end

local function CreateFonts()
    local scale = math.min(ScrW() / BASE_W, ScrH() / BASE_H)
    scale = math.Clamp(scale, 0.72, 1.35)

    surface.CreateFont("MYRP_SelectTitle", {
        font = "Arial",
        size = math.floor(42 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_SelectSubtitle", {
        font = "Arial",
        size = math.floor(19 * scale),
        weight = 500,
        extended = true
    })

    surface.CreateFont("MYRP_SelectFaction", {
        font = "Arial",
        size = math.floor(31 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_SelectBody", {
        font = "Arial",
        size = math.floor(17 * scale),
        weight = 500,
        extended = true
    })

    surface.CreateFont("MYRP_SelectSmall", {
        font = "Arial",
        size = math.floor(14 * scale),
        weight = 500,
        extended = true
    })
end

CreateFonts()

surface.CreateFont("MYRP_FactionHeader", {
    font = "Arial",
    size = math.floor(44 * math.Clamp(math.min(ScrW() / BASE_W, ScrH() / BASE_H), 0.72, 1.35)),
    weight = 900,
    extended = true
})

surface.CreateFont("MYRP_FactionTagline", {
    font = "Arial",
    size = math.floor(18 * math.Clamp(math.min(ScrW() / BASE_W, ScrH() / BASE_H), 0.72, 1.35)),
    weight = 700,
    extended = true
})

surface.CreateFont("MYRP_FactionDescription", {
    font = "Arial",
    size = math.floor(16 * math.Clamp(math.min(ScrW() / BASE_W, ScrH() / BASE_H), 0.72, 1.35)),
    weight = 500,
    extended = true
})

surface.CreateFont("MYRP_FactionFeature", {
    font = "Arial",
    size = math.floor(14 * math.Clamp(math.min(ScrW() / BASE_W, ScrH() / BASE_H), 0.72, 1.35)),
    weight = 600,
    extended = true
})

surface.CreateFont("MYRP_FactionMark", {
    font = "Arial",
    size = math.floor(38 * math.Clamp(math.min(ScrW() / BASE_W, ScrH() / BASE_H), 0.72, 1.35)),
    weight = 900,
    extended = true
})

Log("INFO", "Faction UI client module v2.2 loaded; faction-aware animated UI core=" .. tostring(GetMYRPUI() ~= nil) .. "; resolution=" .. UIResolution())

local factionInfo = {
    combine = {
        name = "COMBINE",
        subtitle = "ПОРЯДОК. КОНТРОЛЬ. СТАБИЛЬНОСТЬ.",
        description = "Объединённая администрация Земли стремится к порядку и безопасности во всём мире. Сопротивление недопустимо.",
        principles = {"ДИСЦИПЛИНА И ЗАКОН", "СТАБИЛЬНОСТЬ И ПОРЯДОК", "ТЕХНОЛОГИЧЕСКОЕ ПРЕВОСХОДСТВО"},
        mark = "C",
        image = "myrp/factions/combine.jpg",
        color = Color(105, 178, 235),
        dark = Color(20, 43, 65)
    },
    resistance = {
        name = "RESISTANCE",
        subtitle = "СВОБОДА. ЕДИНСТВО. БОРЬБА.",
        description = "Сопротивление — это люди, которые не сдаются. Они борются за свободу, право на выбор и будущее без оккупации.",
        principles = {"СВОБОДА И НЕЗАВИСИМОСТЬ", "ЕДИНСТВО НАРОДА", "БОРЬБА ЗА БУДУЩЕЕ"},
        mark = "λ",
        image = "myrp/factions/resistance.jpg",
        color = Color(220, 145, 100),
        dark = Color(61, 38, 27)
    }
}

local factionArtMaterials = {}
local factionArtWarned = {}
local factionArtLoaded = {}
local factionSelectionScreenMaterial = nil
local factionSelectionScreenWarned = false
local factionSelectionScreenLoaded = false

local function GetFactionArtMaterial(factionID)
    local info = factionInfo[factionID]
    if (!info) then return nil end

    local material = factionArtMaterials[factionID]
    if (!material or material:IsError()) then
        material = Material(info.image, "smooth")
        factionArtMaterials[factionID] = material
    end

    if (!material or material:IsError()) then
        if (!factionArtWarned[factionID]) then
            factionArtWarned[factionID] = true
            Log("WARN", "Faction art is missing or not mounted: " .. tostring(info.image))
        end
        return nil
    end

    if (!factionArtLoaded[factionID]) then
        factionArtLoaded[factionID] = true
        factionArtWarned[factionID] = nil
        Log("INFO", "Faction art material loaded: " .. tostring(info.image))
    end

    return material
end

local function DrawButton(button, title, subtitle, accent)
    button:SetText("")
    button:SetCursor("hand")
    button.Paint = function(self, width, height)
        local hovered = self:IsHovered()
        local disabled = not self:IsEnabled()
        local background = hovered and Color(29, 43, 59, 250) or Color(16, 25, 36, 248)
        local alpha = disabled and 70 or (hovered and 255 or 205)

        draw.RoundedBox(5, 0, 0, width, height, background)
        surface.SetDrawColor(accent.r, accent.g, accent.b, alpha)
        surface.DrawRect(0, height - SY(4), width, SY(4))
        surface.SetDrawColor(210, 225, 240, hovered and 55 or 22)
        surface.DrawOutlinedRect(0, 0, width, height, 1)

        draw.SimpleText(title, "MYRP_SelectFaction", SX(28), height * 0.39, disabled and Color(135, 145, 155) or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "MYRP_SelectBody", SX(30), height * 0.64, Color(180, 197, 213, disabled and 100 or 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if hovered and not disabled then
            surface.SetDrawColor(accent.r, accent.g, accent.b, 18)
            surface.DrawRect(0, 0, width, height - SY(4))
        end
    end
end

local function AddCenteredLabel(parent, text, font, color, y)
    local label = vgui.Create("DLabel", parent)
    label:SetFont(font)
    label:SetText(text)
    label:SetTextColor(color)
    label:SizeToContents()
    label:SetPos(math.floor((ScrW() - label:GetWide()) * 0.5), y)
    return label
end

local function NewContent(frame)
    if IsValid(frame.content) then
        frame.content:Remove()
    end

    frame.content = vgui.Create("DPanel", frame)
    frame.content:Dock(FILL)
    frame.contentStage = "custom-content"
    frame.content:DockMargin(0, 0, 0, 0)
    frame.content:SetAlpha(0)
    frame.content:AlphaTo(255, 0.22, 0)
    frame.content.Paint = nil

    return frame.content
end

local function SetStatus(frame, text, isError)
    if not IsValid(frame) or not IsValid(frame.status) then return end

    frame.status:SetText(text or "")
    frame.status:SetTextColor(isError and Color(238, 110, 95) or Color(180, 205, 220))
    frame.status:SizeToContents()
    frame.status:SetPos(math.floor((ScrW() - frame.status:GetWide()) * 0.5), frame.statusY or SY(770))
end

-- ---------------------------------------------------------------------------
-- MYRP CINEMATIC FACTION / WORKER / MODEL SELECTION UI v2.2
-- Uses separate portrait assets and a standalone city background. All text,
-- cards, hitboxes and previews are real VGUI elements (not baked into artwork).
-- ---------------------------------------------------------------------------

local backgroundMaterial
local backgroundWarned = false
local backgroundLoaded = false

local function GetFactionBackgroundMaterial()
    if (!backgroundMaterial or backgroundMaterial:IsError()) then
        backgroundMaterial = Material("myrp/factions/background.jpg", "smooth")
    end

    if (!backgroundMaterial or backgroundMaterial:IsError()) then
        if (!backgroundWarned) then
            backgroundWarned = true
            Log("WARN", "Background material unavailable: myrp/factions/background.jpg; using dark fallback")
        end
        return nil
    end

    if (!backgroundLoaded) then
        backgroundLoaded = true
        Log("INFO", "Background material loaded: myrp/factions/background.jpg; texture=" ..
            tostring(backgroundMaterial:Width()) .. "x" .. tostring(backgroundMaterial:Height()))
    end

    return backgroundMaterial
end

local function DrawCinematicBackground(panel, width, height, extraDim)
    local material = GetFactionBackgroundMaterial()

    if (material) then
        surface.SetMaterial(material)
        surface.SetDrawColor(190, 205, 220, 255)
        surface.DrawTexturedRect(0, 0, width, height)
    else
        surface.SetDrawColor(8, 13, 20, 255)
        surface.DrawRect(0, 0, width, height)
    end

    -- Keep the art atmospheric and readable without baking any UI into it.
    surface.SetDrawColor(2, 6, 11, 155 + (extraDim or 0))
    surface.DrawRect(0, 0, width, height)

    surface.SetDrawColor(7, 14, 22, 90)
    surface.DrawRect(0, 0, width, SY(150))
    surface.DrawRect(0, height - SY(190), width, SY(190))

    surface.SetDrawColor(95, 145, 185, 35)
    surface.DrawRect(SX(70), SY(139), width - SX(140), 1)
end

local function DrawScreenBrand(content, title, subtitle, factionColor)
    draw.SimpleText("MYRP", "MYRP_SelectTitle", SX(76), SY(62), Color(225, 235, 245, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("MY UNIQUE ROLEPLAY", "MYRP_SelectSmall", SX(80), SY(99), Color(145, 163, 180, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(title, "MYRP_FactionHeader", SX(76), SY(170), Color(236, 242, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if (subtitle and subtitle ~= "") then
        draw.SimpleText(subtitle, "MYRP_SelectSubtitle", SX(80), SY(207), factionColor or Color(165, 181, 196), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    draw.SimpleText("MYRP  /  HALF-LIFE UNIVERSE", "MYRP_SelectSmall", SX(76), ScrH() - SY(42), Color(115, 132, 149, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function DrawWrappedText(text, font, x, y, maxWidth, lineHeight, color, maxLines)
    surface.SetFont(font)
    local words = string.Explode(" ", tostring(text or ""))
    local lines = {}
    local line = ""

    for _, word in ipairs(words) do
        local candidate = line == "" and word or (line .. " " .. word)
        local candidateWidth = surface.GetTextSize(candidate)
        if (candidateWidth > maxWidth and line ~= "") then
            lines[#lines + 1] = line
            line = word
            if (maxLines and #lines >= maxLines) then break end
        else
            line = candidate
        end
    end

    if (line ~= "" and (not maxLines or #lines < maxLines)) then
        lines[#lines + 1] = line
    end

    for index, value in ipairs(lines) do
        draw.SimpleText(value, font, x, y + (index - 1) * lineHeight, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    return #lines
end

local function PlayFactionUISound()
    PlayMYRPSound("click")
end

local function DrawTopAccent(info, x, y, width, alpha)
    surface.SetDrawColor(info.color.r, info.color.g, info.color.b, alpha or 185)
    surface.DrawRect(x, y, width, SY(3))
end

local function CreateFactionCard(parent, frame, factionID, x, y, width, height)
    local info = factionInfo[factionID]
    local card = vgui.Create("DButton", parent)
    card:SetPos(x, y)
    card:SetSize(width, height)
    card:SetText("")
    card:SetCursor("hand")
    card:SetTooltip(info.name .. " — " .. info.subtitle)
    card.OnCursorEntered = function()
        PlayMYRPSound("hover")
    end
    card.hoverLerp = 0
    card.selectedLerp = 0

    card.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        local selected = frame.selectedFaction == factionID
        self.hoverLerp = Lerp(math.min(FrameTime() * 9, 1), self.hoverLerp or 0, hovered and 1 or 0)
        self.selectedLerp = Lerp(math.min(FrameTime() * 8, 1), self.selectedLerp or 0, selected and 1 or 0)

        local imageWidth = math.floor(w * 0.415)
        if (hovered or selected) then
            local glowAlpha = math.floor(16 + self.hoverLerp * 30 + self.selectedLerp * 42)
            draw.RoundedBox(10, -SX(4), -SY(4), w + SX(8), h + SY(8),
                Color(info.color.r, info.color.g, info.color.b, glowAlpha))
        end
        draw.RoundedBox(9, 0, 0, w, h, Color(5, 9, 15, 205))

        local art = GetFactionArtMaterial(factionID)
        if (art) then
            surface.SetMaterial(art)
            local sourceAspect = 900 / 1350
            local targetAspect = imageWidth / h
            local visibleU = math.min(1, targetAspect / sourceAspect)
            local u0 = (1 - visibleU) * 0.5
            surface.SetDrawColor(255, 255, 255, math.floor(190 + self.hoverLerp * 55 + self.selectedLerp * 10))
            surface.DrawTexturedRectUV(0, 0, imageWidth, h, u0, 0, u0 + visibleU, 1)
        else
            surface.SetDrawColor(info.dark.r, info.dark.g, info.dark.b, 255)
            surface.DrawRect(0, 0, imageWidth, h)
        end

        -- Portrait shade and independent translucent information block.
        surface.SetDrawColor(2, 6, 11, 65 - self.hoverLerp * 22)
        surface.DrawRect(0, 0, imageWidth, h)
        surface.SetDrawColor(5, 10, 17, 198)
        surface.DrawRect(imageWidth, 0, w - imageWidth, h)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, 18 + self.hoverLerp * 22 + self.selectedLerp * 18)
        surface.DrawRect(imageWidth, 0, w - imageWidth, h)

        local tx = imageWidth + SX(30)
        local textWidth = w - imageWidth - SX(58)
        local titleY = SY(84)
        local mark = factionID == "combine" and "◉" or "λ"
        draw.SimpleText(mark, "MYRP_FactionMark", tx + SX(18), titleY, info.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(info.name, "MYRP_SelectFaction", tx + SX(55), titleY, Color(242, 246, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText(info.subtitle, "MYRP_FactionTagline", tx, SY(145), info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        DrawTopAccent(info, tx, SY(176), math.min(textWidth, SX(330)), 115)

        local descriptionLines = DrawWrappedText(info.description, "MYRP_FactionDescription", tx, SY(207),
            textWidth, SY(25), Color(194, 205, 216), 4)

        local principleY = math.max(SY(340), SY(207) + descriptionLines * SY(25) + SY(35))
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, 110)
        surface.DrawRect(tx, principleY - SY(18), textWidth, 1)
        draw.SimpleText("ОСНОВНЫЕ ПРИНЦИПЫ", "MYRP_SelectSmall", tx, principleY, info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        for index, principle in ipairs(info.principles) do
            local rowY = principleY + SY(49) + (index - 1) * SY(47)
            surface.SetDrawColor(info.color.r, info.color.g, info.color.b, 220)
            surface.DrawCircle(tx + SX(7), rowY, SX(4), info.color.r, info.color.g, info.color.b, 220)
            draw.SimpleText(principle, "MYRP_FactionFeature", tx + SX(25), rowY, Color(204, 214, 224), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local hintY = h - SY(42)
        surface.SetDrawColor(190, 205, 220, 45)
        surface.DrawRect(tx, hintY - SY(25), textWidth, 1)
        draw.SimpleText(selected and "ФРАКЦИЯ ВЫБРАНА" or (hovered and "ВЫБРАТЬ ЭТУ ФРАКЦИЮ" or "НАЖМИТЕ ДЛЯ ВЫБОРА"),
            "MYRP_SelectSmall", tx, hintY, selected and info.color or Color(155, 170, 185), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("→", "MYRP_SelectFaction", w - SX(35), hintY, info.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Soft animated glow on hover, stronger and steadier when selected.
        local glow = math.floor(38 + self.hoverLerp * 78 + self.selectedLerp * 105)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, math.floor(glow * 0.20))
        surface.DrawOutlinedRect(-3, -3, w + 6, h + 6, 4)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, glow)
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 1 + math.floor(self.selectedLerp * 2))
        surface.SetDrawColor(205, 220, 235, 26)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        if (!selected and !hovered) then
            surface.SetDrawColor(0, 0, 0, 15)
            surface.DrawRect(0, 0, w, h)
        end
    end

    card.DoClick = function()
        if (!IsValid(frame)) then return end
        frame.selectedFaction = factionID
        if (IsValid(frame.continueButton)) then frame.continueButton:SetEnabled(true) end
        PlayFactionUISound()
        Log("INFO", "Faction selected: " .. factionID .. "; hover/selection state updated")
    end

    return card
end

local function DrawFactionScreenBackground(panel, width, height)
    DrawCinematicBackground(panel, width, height, 0)
    DrawScreenBrand(panel, "ВЫБОР ФРАКЦИИ", "ВЫБЕРИТЕ СТОРОНУ, ЗА КОТОРУЮ ХОТИТЕ ИГРАТЬ", nil)
    draw.SimpleText("ВАШ ВЫБОР ОПРЕДЕЛИТ ВАШУ РОЛЬ В ЭТОМ МИРЕ", "MYRP_SelectSmall",
        width - SX(76), SY(86), Color(160, 175, 190, 205), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function GetFactionModelOptions(factionID)
    local faction = ix.faction.Get(factionID)
    local client = LocalPlayer()
    if (!faction or !IsValid(client)) then
        Log("WARN", "Cannot enumerate models: faction or LocalPlayer unavailable; faction=" .. tostring(factionID))
        return {}
    end

    local source = faction.GetModels and faction:GetModels(client) or faction.models or {}
    local result = {}

    for _, entry in SortedPairs(source) do
        local modelPath = isstring(entry) and entry or (istable(entry) and entry[1])
        if (isstring(modelPath) and modelPath ~= "" and modelPath ~= "models/error.mdl" and util.IsValidModel(modelPath)) then
            local exists = false
            for _, option in ipairs(result) do
                if (option.path == modelPath) then exists = true break end
            end
            if (!exists) then
                result[#result + 1] = {path = modelPath, source = entry}
            end
        end
    end

    Log("INFO", "Loaded faction model options: faction=" .. factionID .. ", count=" .. #result)
    for index, option in ipairs(result) do
        Log("DEBUG", "Model option " .. index .. ": " .. option.path)
    end
    return result
end

local function GetModelDisplayName(path)
    local filename = string.GetFileFromFilename(path or "") or tostring(path or "UNKNOWN")
    filename = string.gsub(filename, "%.mdl$", "")
    filename = string.gsub(filename, "_", " ")
    return string.upper(filename)
end

local function UpdateLargeModelPreview(preview, modelPath)
    if (!IsValid(preview) or !isstring(modelPath)) then return end

    preview:SetAlpha(0)
    preview:AlphaTo(255, 0.18, 0)
    preview:SetModel(modelPath)
    preview:SetFOV(38)
    preview:SetAnimated(true)
    preview.LayoutEntity = function(self, entity)
        if (!IsValid(entity)) then return end
        self:RunAnimation()
        entity:SetAngles(Angle(0, 24, 0))
    end

    -- Frame the full body from its actual model bounds instead of assuming
    -- every vanilla citizen model has the exact same origin/height.
    timer.Simple(0, function()
        if (!IsValid(preview)) then return end
        local entity = preview:GetEntity()
        if (!IsValid(entity)) then
            Log("WARN", "Model preview entity was not ready for camera framing: " .. modelPath)
            return
        end

        local mins, maxs = entity:GetRenderBounds()
        local center = (mins + maxs) * 0.5
        local height = math.max(1, maxs.z - mins.z)
        local distance = math.max(88, height * 1.65)

        preview:SetLookAt(center)
        preview:SetCamPos(center + Vector(distance, 0, height * 0.08))
        Log("DEBUG", "Model preview camera framed: model=" .. modelPath
            .. ", height=" .. math.floor(height) .. ", distance=" .. math.floor(distance))
    end)

    Log("DEBUG", "Large model preview updated: " .. modelPath)
end

local function OpenWorkerScreen(frame, factionID)
    if (!IsValid(frame)) then
        Log("WARN", "OpenWorkerScreen aborted: root panel is invalid")
        return
    end

    local info = factionInfo[factionID]
    if (!info) then
        Log("ERROR", "OpenWorkerScreen received unknown factionID=" .. tostring(factionID))
        return
    end

    Log("INFO", "Building Worker and model selection screen; faction=" .. factionID .. ", resolution=" .. UIResolution())
    local content = NewContent(frame)
    PlayMYRPSound("open")
    frame.contentStage = "worker-model"
    frame.selectedClass = nil
    frame.selectedModel = nil
    frame.workerButton = nil
    frame.acceptButton = nil
    frame.modelOptions = GetFactionModelOptions(factionID)
    frame.statusY = SY(945)

    content.Paint = function(self, width, height)
        DrawCinematicBackground(self, width, height, 12)
        DrawScreenBrand(self, "ВЫБОР ПРОФЕССИИ", info.name .. "  /  ВЫБЕРИТЕ РОЛЬ И ВНЕШНОСТЬ", info.color)
    end

    -- Back navigation.
    local back = vgui.Create("DButton", content)
    back:SetPos(SX(76), SY(143))
    back:SetSize(SX(170), SY(46))
    back:SetText("←  НАЗАД")
    back:SetFont("MYRP_SelectSmall")
    back:SetTextColor(Color(218, 229, 240))
    back:SetCursor("hand")
    back.OnCursorEntered = function() PlayMYRPSound("hover") end
    back.Paint = function(self, w, h)
        local hover = self:IsHovered()
        draw.RoundedBox(4, 0, 0, w, h, Color(8, 14, 22, hover and 220 or 170))
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, hover and 220 or 95)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    back.DoClick = function()
        if (!IsValid(frame)) then return end
        PlayMYRPSound("click")
        Log("DEBUG", "Returning to faction screen from Worker/model selection; faction=" .. factionID)
        frame.selectedFaction = factionID
        PLUGIN:OpenFactionScreen(frame)
    end

    local panelY = SY(225)
    local panelH = SY(650)
    local leftX = SX(76)
    local leftW = SX(450)
    local gap = SX(24)
    local rightX = leftX + leftW + gap
    local rightW = ScrW() - rightX - SX(76)

    -- Left: Worker role card, made from a separate live card rather than a baked screenshot.
    local workerCard = vgui.Create("DButton", content)
    workerCard:SetPos(leftX, panelY)
    workerCard:SetSize(leftW, panelH)
    workerCard:SetText("")
    workerCard:SetCursor("hand")
    workerCard.OnCursorEntered = function() PlayMYRPSound("hover") end
    workerCard.hoverLerp = 0
    workerCard.selectedLerp = 0
    frame.workerButton = workerCard

    workerCard.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        local selected = frame.selectedClass == factionID .. "_worker"
        self.hoverLerp = Lerp(math.min(FrameTime() * 9, 1), self.hoverLerp or 0, hovered and 1 or 0)
        self.selectedLerp = Lerp(math.min(FrameTime() * 8, 1), self.selectedLerp or 0, selected and 1 or 0)

        if (hovered or selected) then
            draw.RoundedBox(10, -SX(4), -SY(4), w + SX(8), h + SY(8),
                Color(info.color.r, info.color.g, info.color.b, math.floor(14 + self.hoverLerp * 26 + self.selectedLerp * 36)))
        end
        draw.RoundedBox(9, 0, 0, w, h, Color(5, 10, 16, 208))
        local art = GetFactionArtMaterial(factionID)
        local artH = math.floor(h * 0.48)
        if (art) then
            surface.SetMaterial(art)
            surface.SetDrawColor(205, 215, 225, 185 + math.floor(self.hoverLerp * 50))
            local sourceAspect = 900 / 1350
            local targetAspect = w / artH
            local visibleV = math.min(1, sourceAspect / targetAspect)
            local v0 = (1 - visibleV) * 0.42
            surface.DrawTexturedRectUV(0, 0, w, artH, 0, v0, 1, v0 + visibleV)
        end

        surface.SetDrawColor(4, 8, 14, 78)
        surface.DrawRect(0, 0, w, artH)
        surface.SetDrawColor(5, 10, 17, 214)
        surface.DrawRect(0, artH, w, h - artH)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, 25 + self.hoverLerp * 22)
        surface.DrawRect(0, artH, w, h - artH)

        draw.SimpleText("01  /  ПРОФЕССИЯ", "MYRP_SelectSmall", SX(28), artH + SY(36), info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("WORKER", "MYRP_SelectFaction", SX(28), artH + SY(91), Color(240, 245, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("РАБОЧИЙ", "MYRP_FactionTagline", SX(28), artH + SY(132), info.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        DrawWrappedText("Работник фракции. Занимается производством, добычей ресурсов и снабжением союзников.",
            "MYRP_FactionDescription", SX(28), artH + SY(174), w - SX(56), SY(25), Color(190, 202, 214), 4)

        local bottomY = h - SY(54)
        surface.SetDrawColor(190, 205, 220, 38)
        surface.DrawRect(SX(28), bottomY - SY(25), w - SX(56), 1)
        draw.SimpleText(selected and "ПРОФЕССИЯ ВЫБРАНА" or "НАЖМИТЕ, ЧТОБЫ ВЫБРАТЬ", "MYRP_SelectSmall",
            SX(28), bottomY, selected and info.color or Color(145, 160, 176), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local outlineAlpha = math.floor(45 + self.hoverLerp * 75 + self.selectedLerp * 125)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, outlineAlpha)
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 1 + math.floor(self.selectedLerp * 2))
    end

    workerCard.DoClick = function()
        frame.selectedClass = factionID .. "_worker"
        PlayFactionUISound()
        if (IsValid(frame.acceptButton)) then frame.acceptButton:SetEnabled(#(frame.modelOptions or {}) > 0) end
        Log("INFO", "Worker role selected: class=" .. frame.selectedClass)
    end

    -- Right: appearance panel and native 3D preview.
    local appearance = vgui.Create("DPanel", content)
    appearance:SetPos(rightX, panelY)
    appearance:SetSize(rightW, panelH)
    appearance.Paint = function(self, w, h)
        draw.RoundedBox(5, 0, 0, w, h, Color(5, 10, 16, 222))
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, 85)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, 170)
        surface.DrawRect(SX(28), SY(24), SX(58), SY(3))
        draw.SimpleText("ВЫБЕРИТЕ ВНЕШНОСТЬ", "MYRP_SelectSubtitle", SX(28), SY(56), Color(230, 237, 244), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ДОСТУПНЫЕ ВАНИЛЬНЫЕ МОДЕЛИ", "MYRP_SelectSmall", w - SX(28), SY(56), Color(140, 158, 176), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(185, 200, 215, 30)
        surface.DrawRect(SX(28), SY(89), w - SX(56), 1)
    end

    local options = frame.modelOptions or {}
    if (#options > 0) then
        frame.selectedModel = options[1].path
    else
        Log("ERROR", "No valid vanilla models found for faction=" .. factionID)
    end

    local preview = vgui.Create("DModelPanel", appearance)
    preview:SetPos(SX(20), SY(110))
    preview:SetSize(math.min(SX(500), math.floor(rightW * 0.43)), SY(500))
    preview:SetMouseInputEnabled(false)
    frame.modelPreview = preview
    if (frame.selectedModel) then
        UpdateLargeModelPreview(preview, frame.selectedModel)
    else
        preview:SetVisible(false)
    end

    local modelListX = math.min(SX(545), math.floor(rightW * 0.46))
    local modelList = vgui.Create("DIconLayout", appearance)
    modelList:SetPos(modelListX, SY(125))
    modelList:SetSize(rightW - modelListX - SX(22), SY(490))
    modelList:SetSpaceX(SX(13))
    modelList:SetSpaceY(SY(16))
    frame.modelIcons = {}

    local modelLabel = vgui.Create("DLabel", appearance)
    modelLabel:SetFont("MYRP_SelectSmall")
    modelLabel:SetText(frame.selectedModel and GetModelDisplayName(frame.selectedModel) or "МОДЕЛИ НЕ НАЙДЕНЫ")
    modelLabel:SetTextColor(info.color)
    modelLabel:SetPos(modelListX, SY(95))
    modelLabel:SetSize(rightW - modelListX - SX(22), SY(24))
    frame.modelNameLabel = modelLabel

    for index, option in ipairs(options) do
        local modelPath = option.path
        local modelIndex = index
        local tile = modelList:Add("SpawnIcon")
        tile:SetSize(SX(118), SY(154))
        tile:SetModel(modelPath)
        tile:SetTooltip(GetModelDisplayName(modelPath) .. "\n" .. modelPath)
        tile:SetMouseInputEnabled(true)
        tile.OnCursorEntered = function() PlayMYRPSound("hover") end
        tile.DoClick = function()
            frame.selectedModel = modelPath
            UpdateLargeModelPreview(preview, modelPath)
            if (IsValid(frame.modelNameLabel)) then
                frame.modelNameLabel:SetText(GetModelDisplayName(modelPath))
            end
            PlayFactionUISound()
            Log("INFO", "Player model selected: faction=" .. factionID .. ", model=" .. modelPath .. ", index=" .. modelIndex)
        end
        tile.PaintOver = function(self, w, h)
            local selected = frame.selectedModel == modelPath
            local hovered = self:IsHovered()
            if (selected or hovered) then
                local alpha = selected and 230 or 110
                if (hovered) then
                    draw.RoundedBox(7, 1, 1, w - 2, h - 2,
                        Color(info.color.r, info.color.g, info.color.b, selected and 20 or 12))
                end
                surface.SetDrawColor(info.color.r, info.color.g, info.color.b, alpha)
                surface.DrawOutlinedRect(1, 1, w - 2, h - 2, selected and 2 or 1)
            end
        end
        frame.modelIcons[#frame.modelIcons + 1] = tile
    end

    -- Footer and confirmation.
    frame.status = AddCenteredLabel(content, "", "MYRP_SelectSmall", Color(180, 205, 220), SY(895))
    frame.statusY = SY(895)

    local accept = vgui.Create("DButton", content)
    accept:SetPos(ScrW() - SX(76) - SX(390), SY(920))
    accept:SetSize(SX(390), SY(76))
    accept:SetText("")
    accept:SetCursor("hand")
    accept.OnCursorEntered = function() PlayMYRPSound("hover") end
    accept:SetEnabled(false)
    frame.acceptButton = accept
    accept.Paint = function(self, w, h)
        local enabled = self:IsEnabled()
        local hovered = self:IsHovered()
        self.hoverLerp = Lerp(math.min(FrameTime() * 10, 1), self.hoverLerp or 0, hovered and 1 or 0)
        local alpha = enabled and (hovered and 235 or 170) or 65
        if (enabled and hovered) then
            draw.RoundedBox(8, -SX(3), -SY(3), w + SX(6), h + SY(6),
                Color(info.color.r, info.color.g, info.color.b, math.floor(20 + self.hoverLerp * 34)))
        end
        draw.RoundedBox(8, 0, 0, w, h, Color(5, 12, 20, 194))
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, alpha)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(info.color.r, info.color.g, info.color.b, enabled and (50 + self.hoverLerp * 60) or 12)
        surface.DrawRect(1, 1, w - 2, h - 2)
        draw.SimpleText("ПРИНЯТЬ", "MYRP_SelectFaction", w * 0.5 - SX(10), h * 0.5, enabled and Color(238, 244, 250) or Color(120, 130, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("→", "MYRP_SelectFaction", w - SX(34), h * 0.5, enabled and info.color or Color(90, 100, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    accept.DoClick = function()
        if (!IsValid(frame) or !frame.selectedClass or !frame.selectedModel) then
            Log("WARN", "Accept blocked: role/model not selected; class=" .. tostring(frame.selectedClass) .. ", model=" .. tostring(frame.selectedModel))
            SetStatus(frame, "ВЫБЕРИТЕ ПРОФЕССИЮ И МОДЕЛЬ", true)
            return
        end

        accept:SetEnabled(false)
        if (IsValid(frame.workerButton)) then frame.workerButton:SetEnabled(false) end
        SetStatus(frame, "СОЗДАНИЕ / ЗАГРУЗКА ПЕРСОНАЖА...", false)
        PlayMYRPSound("click")
        Log("INFO", "Submitting character selection: faction=" .. factionID .. ", class=" .. frame.selectedClass .. ", model=" .. frame.selectedModel)

        net.Start("myrpFactionSelect")
            net.WriteString(factionID)
            net.WriteString(frame.selectedClass)
            net.WriteString(frame.selectedModel)
        net.SendToServer()
    end

    local bottomInfo = vgui.Create("DLabel", content)
    bottomInfo:SetFont("MYRP_SelectSmall")
    bottomInfo:SetText("Steam-имя будет назначено автоматически. Модель можно выбрать из доступных для фракции.")
    bottomInfo:SetTextColor(Color(135, 151, 168))
    bottomInfo:SizeToContents()
    bottomInfo:SetPos(SX(76), SY(954))

    Log("INFO", "Worker/model screen built: faction=" .. factionID
        .. ", models=" .. #options .. ", firstModel=" .. tostring(frame.selectedModel)
        .. ", previewValid=" .. tostring(IsValid(preview)) .. ", resolution=" .. UIResolution())
end

function PLUGIN:OpenFactionScreen(frame)
    if (!IsValid(frame)) then
        Log("WARN", "OpenFactionScreen aborted: root panel is invalid")
        return
    end

    local isTransition = IsValid(frame.content)
    Log("INFO", "Building separate-card faction selection screen v2.2; resolution=" .. UIResolution())
    local content = NewContent(frame)
    if (isTransition) then PlayMYRPSound("open") end
    frame.contentStage = "faction"
    content.Paint = function(self, width, height)
        DrawFactionScreenBackground(self, width, height)
    end

    frame.selectedFaction = frame.selectedFaction or nil
    frame.selectedClass = nil
    frame.selectedModel = nil
    frame.continueButton = nil

    local margin = SX(76)
    local gap = SX(36)
    local cardWidth = math.floor((ScrW() - margin * 2 - gap) * 0.5)
    local cardHeight = SY(650)
    local cardY = SY(245)

    frame.combineCard = CreateFactionCard(content, frame, "combine", margin, cardY, cardWidth, cardHeight)
    frame.resistanceCard = CreateFactionCard(content, frame, "resistance", margin + cardWidth + gap, cardY, cardWidth, cardHeight)

    local factionContinueButton = vgui.Create("DButton", content)
    factionContinueButton:SetPos(ScrW() - margin - SX(405), SY(930))
    factionContinueButton:SetSize(SX(405), SY(72))
    factionContinueButton:SetText("")
    factionContinueButton:SetCursor("hand")
    factionContinueButton.OnCursorEntered = function() PlayMYRPSound("hover") end
    factionContinueButton:SetEnabled(frame.selectedFaction ~= nil)
    frame.continueButton = factionContinueButton
    factionContinueButton.Paint = function(self, w, h)
        local info = factionInfo[frame.selectedFaction or "combine"]
        local enabled = self:IsEnabled()
        local hovered = self:IsHovered()
        self.hoverLerp = Lerp(math.min(FrameTime() * 10, 1), self.hoverLerp or 0, hovered and 1 or 0)
        local color = info and info.color or Color(115, 130, 145)
        local alpha = enabled and (hovered and 230 or 160) or 55
        if (enabled and hovered) then
            draw.RoundedBox(8, -SX(3), -SY(3), w + SX(6), h + SY(6),
                Color(color.r, color.g, color.b, math.floor(18 + self.hoverLerp * 34)))
        end
        draw.RoundedBox(8, 0, 0, w, h, Color(5, 11, 18, 195))
        surface.SetDrawColor(color.r, color.g, color.b, alpha)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(color.r, color.g, color.b, enabled and (24 + self.hoverLerp * 48) or 8)
        surface.DrawRect(1, 1, w - 2, h - 2)
        draw.SimpleText("ПРОДОЛЖИТЬ", "MYRP_SelectFaction", w * 0.5 - SX(12), h * 0.5, enabled and color_white or Color(105, 115, 125), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("→", "MYRP_SelectFaction", w - SX(34), h * 0.5, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    factionContinueButton.DoClick = function()
        local factionID = frame.selectedFaction
        if (!factionID or !factionInfo[factionID]) then
            Log("WARN", "Continue pressed without selecting a faction")
            return
        end
        PlayFactionUISound()
        Log("INFO", "Faction confirmed: " .. factionID .. "; opening Worker/model screen")
        OpenWorkerScreen(frame, factionID)
    end

    local hint = vgui.Create("DLabel", content)
    hint:SetFont("MYRP_SelectSmall")
    hint:SetText("ВЫБЕРИТЕ КАРТОЧКУ ФРАКЦИИ, ЗАТЕМ НАЖМИТЕ ПРОДОЛЖИТЬ")
    hint:SetTextColor(Color(145, 161, 177))
    hint:SizeToContents()
    hint:SetPos(margin, SY(961))

    Log("INFO", "Faction selection screen v2.2 built; backgroundLoaded=" .. tostring(GetFactionBackgroundMaterial() ~= nil)
        .. ", combineArt=" .. tostring(GetFactionArtMaterial("combine") ~= nil)
        .. ", resistanceArt=" .. tostring(GetFactionArtMaterial("resistance") ~= nil)
        .. ", cardRects=" .. tostring(margin) .. "," .. tostring(cardY) .. "," .. tostring(cardWidth) .. "," .. tostring(cardHeight)
        .. " | " .. tostring(margin + cardWidth + gap) .. "," .. tostring(cardY)
        .. ", resolution=" .. UIResolution())
end

local function OpenFactionMenu()
    if IsValid(ix.gui[MENU_NAME]) then
        Log("DEBUG", "Faction menu already exists; bringing it to front")
        ix.gui[MENU_NAME]:MoveToFront()
        return ix.gui[MENU_NAME]
    end

    -- Use a borderless DPanel, not DFrame. DFrame has a title-bar/client-area
    -- offset, which caused the previous absolute-positioned UI to drift.
    local frame = vgui.Create("DPanel")
    if not IsValid(frame) then
        Log("ERROR", "vgui.Create(DPanel) returned an invalid panel")
        return nil
    end

    frame:SetName("MYRPFactionSelectionRoot")
    frame:SetAlpha(0)
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:DockPadding(0, 0, 0, 0)
    frame:SetZPos(32760)
    frame.Paint = function(self, width, height)
        if (ix and ix.util and ix.util.DrawBlur) then
            ix.util.DrawBlur(self, 6, nil, 160)
        end

        surface.SetDrawColor(3, 7, 12, 205)
        surface.DrawRect(0, 0, width, height)

        -- Subtle cool/amber ambience at the edges, without baking UI text into the background.
        surface.SetDrawColor(22, 44, 66, 42)
        surface.DrawRect(0, 0, math.floor(width * 0.5), height)
        surface.SetDrawColor(59, 36, 25, 28)
        surface.DrawRect(math.floor(width * 0.5), 0, math.floor(width * 0.5), height)
    end

    ix.gui[MENU_NAME] = frame
    PLUGIN:OpenFactionScreen(frame)

    frame:MakePopup()
    frame:SetVisible(true)
    frame:SetMouseInputEnabled(true)
    frame:SetKeyboardInputEnabled(false)
    frame:MoveToFront()
    AnimateMYRPIn(frame, 0.28, "up")
    gui.EnableScreenClicker(true)

    frame.OnRemove = function(self)
        if ix.gui and ix.gui[MENU_NAME] == self then
            ix.gui[MENU_NAME] = nil
        end
        gui.EnableScreenClicker(false)
        Log("DEBUG", "Faction UI root panel removed")
    end

    Log("INFO", "Faction menu opened successfully; panel=" .. tostring(frame) .. ", resolution=" .. UIResolution())
    return frame
end

local function HideHelixCharacterMenu(panel, reason)
    if not IsValid(panel) then
        Log("WARN", "Cannot hide Helix character menu: invalid panel; reason=" .. tostring(reason))
        return false
    end

    panel:SetMouseInputEnabled(false)
    panel:SetKeyboardInputEnabled(false)
    panel:SetVisible(false)

    -- Keep the Helix menu object and its children alive. This hides the stock
    -- Create / Load / Community / Leave and character-creation pages without
    -- deleting Helix panels or disabling the framework's menu system.
    if IsValid(panel.channel) then
        panel.channel:Stop()
        panel.channel = nil
    end

    Log("DEBUG", "Helix character menu hidden (not removed); reason=" .. tostring(reason))
    return true
end

local menuOpenToken = 0

local function ScheduleFactionMenu(panel)
    menuOpenToken = menuOpenToken + 1
    local token = menuOpenToken
    local attempts = 0

    Log("DEBUG", "Scheduling faction menu; token=" .. token .. ", resolution=" .. UIResolution())
    HideHelixCharacterMenu(panel, "MYRP faction selection owns the entry screen")

    local function TryOpen()
        if token ~= menuOpenToken then return end

        if IsValid(ix.gui[MENU_NAME]) then
            HideHelixCharacterMenu(panel, "custom menu already exists")
            return
        end

        local client = LocalPlayer()
        if not IsValid(client) then
            attempts = attempts + 1
            Log("WARN", "LocalPlayer not ready; retry=" .. attempts)
            if attempts < 80 then
                timer.Simple(0.25, TryOpen)
            else
                Log("ERROR", "LocalPlayer did not become valid; leaving stock menu as fallback")
                if IsValid(panel) then
                    panel:SetVisible(true)
                    panel:SetMouseInputEnabled(true)
                    panel:SetKeyboardInputEnabled(true)
                end
            end
            return
        end

        if client.GetCharacter and client:GetCharacter() then
            Log("INFO", "A character is already active; MYRP faction-selection menu will not open")
            HideHelixCharacterMenu(panel, "character already active")
            return
        end

        local frame = OpenFactionMenu()
        if IsValid(frame) then
            HideHelixCharacterMenu(panel, "custom faction UI opened")
            return
        end

        attempts = attempts + 1
        Log("WARN", "Custom faction UI creation failed; retry=" .. attempts)
        if attempts < 20 then
            timer.Simple(0.25, TryOpen)
        else
            Log("ERROR", "Failed to create custom UI after retries; restoring stock Helix menu as fallback")
            if IsValid(panel) then
                panel:SetVisible(true)
                panel:SetMouseInputEnabled(true)
                panel:SetKeyboardInputEnabled(true)
            end
        end
    end

    timer.Simple(0, TryOpen)
end

function PLUGIN:OnCharacterMenuCreated(panel)
    if not IsValid(panel) then
        Log("ERROR", "OnCharacterMenuCreated received invalid panel")
        return
    end

    Log("INFO", "Helix character menu detected; hiding stock character UI and opening MYRP selection")
    ScheduleFactionMenu(panel)
end

function PLUGIN:OnReloaded()
    if ix.gui and IsValid(ix.gui.characterMenu) then
        Log("DEBUG", "Plugin reload detected; re-opening MYRP faction selection")
        ScheduleFactionMenu(ix.gui.characterMenu)
    end
end

net.Receive("myrpMatchResetOpenFaction", function()
    local attempts = 0

    local function TryOpenAfterReset()
        attempts = attempts + 1

        local client = LocalPlayer()
        if not IsValid(client) or not ix or not ix.gui then
            if attempts < 40 then
                timer.Simple(0.25, TryOpenAfterReset)
            else
                Log("ERROR", "Could not reopen faction selection after map reset: client UI not ready")
            end
            return
        end

        if client.GetCharacter and client:GetCharacter() then
            Log("DEBUG", "Faction menu reopen skipped: a character is already active")
            return
        end

        local helixPanel = ix.gui.characterMenu
        if IsValid(helixPanel) then
            HideHelixCharacterMenu(helixPanel, "round reset faction selection")
        end

        local frame = OpenFactionMenu()
        if IsValid(frame) then
            if IsValid(helixPanel) then
                HideHelixCharacterMenu(helixPanel, "MYRP faction UI reopened after round reset")
            end

            Log("INFO", "Faction selection reopened after round reset")
            return
        end

        if attempts < 40 then
            timer.Simple(0.25, TryOpenAfterReset)
        else
            Log("ERROR", "Could not create faction selection UI after round reset")
        end
    end

    timer.Simple(0, TryOpenAfterReset)
end)
net.Receive("myrpFactionSelectResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    local characterID = net.ReadUInt(32)
    local frame = ix.gui and ix.gui[MENU_NAME]

    Log("INFO", "Server response received; success=" .. tostring(success) .. ", characterID=" .. tostring(characterID) .. ", message=" .. tostring(message))

    if success then
        if characterID > 0 then
            ix.characters = ix.characters or {}
            if not table.HasValue(ix.characters, characterID) then
                table.insert(ix.characters, characterID)
            end
        end

        if IsValid(frame) then
            PlayMYRPSound("confirm")
            AnimateMYRPOut(frame, 0.18, "down", function()
                if IsValid(frame) then frame:Remove() end
                if ix.gui then ix.gui[MENU_NAME] = nil end
                gui.EnableScreenClicker(false)
                Log("INFO", "Faction selection completed; custom UI closed after transition")
            end)
        else
            if ix.gui then ix.gui[MENU_NAME] = nil end
            gui.EnableScreenClicker(false)
            Log("INFO", "Faction selection completed; UI was already closed")
        end
        return
    end

    if IsValid(frame) then
        SetStatus(frame, message ~= "" and message or "Не удалось выбрать фракцию.", true)

        if IsValid(frame.workerButton) then
            frame.workerButton:SetEnabled(true)
        end
        if IsValid(frame.acceptButton) then
            frame.acceptButton:SetEnabled(frame.selectedClass ~= nil and frame.selectedModel ~= nil)
        end
    end
end)

-- In-game diagnostics. Ask the player to run `myrp_ui_status` if the UI fails.
concommand.Add("myrp_ui_theme_status", function()
    local theme = GetUITheme()
    Log("INFO", "THEME faction=" .. tostring(GetMYRPUI() and GetMYRPUI().GetFactionID and GetMYRPUI().GetFactionID(LocalPlayer()) or "fallback")
        .. ", accent=" .. tostring(theme.accent) .. ", panelAlpha=" .. tostring(theme.panel and theme.panel.a))
end)

concommand.Add("myrp_ui_status", function()
    local client = LocalPlayer()
    local characterMenu = ix.gui and ix.gui.characterMenu
    local factionMenu = ix.gui and ix.gui[MENU_NAME]
    local hasCharacter = IsValid(client) and client.GetCharacter and client:GetCharacter() ~= nil

    Log("INFO", "STATUS resolution=" .. UIResolution()
        .. ", localPlayerValid=" .. tostring(IsValid(client))
        .. ", hasCharacter=" .. tostring(hasCharacter)
        .. ", helixMenuValid=" .. tostring(IsValid(characterMenu))
        .. ", helixMenuVisible=" .. tostring(IsValid(characterMenu) and characterMenu:IsVisible() or false)
        .. ", myrpMenuValid=" .. tostring(IsValid(factionMenu))
        .. ", myrpMenuVisible=" .. tostring(IsValid(factionMenu) and factionMenu:IsVisible() or false))
end)

concommand.Add("myrp_faction_art_status", function()
    for factionID, info in pairs(factionInfo) do
        local material = GetFactionArtMaterial(factionID)
        Log("INFO", "ART faction=" .. factionID .. ", path=" .. info.image
            .. ", loaded=" .. tostring(material ~= nil and !material:IsError()))
    end
end)

concommand.Add("myrp_faction_screen_status", function()
    local background = GetFactionBackgroundMaterial()
    local combine = GetFactionArtMaterial("combine")
    local resistance = GetFactionArtMaterial("resistance")
    local frame = ix.gui and ix.gui[MENU_NAME]
    Log("INFO", "SCREEN_ART v2.2 background=myrp/factions/background.jpg, loaded=" .. tostring(background ~= nil and !background:IsError())
        .. ", combine=myrp/factions/combine.jpg, loaded=" .. tostring(combine ~= nil and !combine:IsError())
        .. ", resistance=myrp/factions/resistance.jpg, loaded=" .. tostring(resistance ~= nil and !resistance:IsError())
        .. ", menuValid=" .. tostring(IsValid(frame))
        .. ", stage=" .. tostring(IsValid(frame) and frame.contentStage or "not-open")
        .. ", selectedFaction=" .. tostring(IsValid(frame) and frame.selectedFaction or "none")
        .. ", selectedClass=" .. tostring(IsValid(frame) and frame.selectedClass or "none")
        .. ", selectedModel=" .. tostring(IsValid(frame) and frame.selectedModel or "none")
        .. ", modelCount=" .. tostring(IsValid(frame) and #(frame.modelOptions or {}) or 0)
        .. ", resolution=" .. UIResolution())
end)

concommand.Add("myrp_faction_models_status", function()
    local frame = ix.gui and ix.gui[MENU_NAME]
    if IsValid(frame) and istable(frame.modelOptions) then
        Log("INFO", "MODEL_STATUS stage=" .. tostring(frame.contentStage)
            .. ", selectedFaction=" .. tostring(frame.selectedFaction)
            .. ", selectedClass=" .. tostring(frame.selectedClass)
            .. ", selectedModel=" .. tostring(frame.selectedModel)
            .. ", count=" .. tostring(#frame.modelOptions))
        for index, option in ipairs(frame.modelOptions) do
            Log("INFO", "MODEL_OPTION index=" .. index .. ", path=" .. tostring(option.path))
        end
        return
    end

    local client = LocalPlayer()
    if not IsValid(client) then
        Log("ERROR", "MODEL_STATUS unavailable: LocalPlayer invalid")
        return
    end

    for factionID, _ in pairs(factionInfo) do
        local options = GetFactionModelOptions(factionID)
        Log("INFO", "MODEL_STATUS faction=" .. factionID .. ", count=" .. #options)
        for index, option in ipairs(options) do
            Log("INFO", "MODEL_OPTION faction=" .. factionID .. ", index=" .. index .. ", path=" .. option.path)
        end
    end
end)

concommand.Add("myrp_ui_reopen", function()
    local client = LocalPlayer()
    if not IsValid(client) then
        Log("ERROR", "Cannot reopen UI: LocalPlayer is invalid")
        return
    end

    if client.GetCharacter and client:GetCharacter() then
        Log("WARN", "Cannot reopen faction selection while a character is active")
        return
    end

    HideHelixCharacterMenu(ix.gui and ix.gui.characterMenu, "manual reopen command")
    local frame = OpenFactionMenu()
    if IsValid(frame) then
        Log("INFO", "Faction UI reopened manually")
    else
        Log("ERROR", "Manual faction UI reopen failed")
    end
end)

-- ---------------------------------------------------------------------------
-- MYRP custom scoreboard (TAB) and Helix-backed inventory (C)
-- ---------------------------------------------------------------------------
-- Helix's default GM:ScoreboardShow opens ixMenu. We draw the MYRP roster instead.
-- The inventory module later in this file uses native ixInventory on C.

local scoreboardVisible = false
local scoreboardAlpha = 0
local scoreboardNextRefresh = 0
local scoreboardData = {
    combine = {},
    resistance = {},
    unassigned = {}
}
local scoreboardLastCounts = ""

local function CreateScoreboardFonts()
    local scale = math.min(ScrW() / BASE_W, ScrH() / BASE_H)
    scale = math.Clamp(scale, 0.72, 1.35)

    surface.CreateFont("MYRP_ScoreTitle", {
        font = "Arial",
        size = math.floor(30 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_ScoreFaction", {
        font = "Arial",
        size = math.floor(22 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_ScorePlayer", {
        font = "Arial",
        size = math.floor(18 * scale),
        weight = 600,
        extended = true
    })

    surface.CreateFont("MYRP_ScoreSmall", {
        font = "Arial",
        size = math.floor(14 * scale),
        weight = 500,
        extended = true
    })
end

CreateScoreboardFonts()

local function GetPlayerFactionID(client)
    if (!IsValid(client) or !ix or !ix.faction or !ix.faction.indices) then
        return nil
    end

    local faction = ix.faction.indices[client:Team()]
    if (faction and isstring(faction.uniqueID)) then
        return string.lower(faction.uniqueID)
    end

    -- Fallback for a player whose Team has not updated yet but whose Helix
    -- character data is already available on this client.
    if (client.GetCharacter) then
        local character = client:GetCharacter()
        if (character and character.GetFaction) then
            local factionIndex = character:GetFaction()
            local characterFaction = ix.faction.indices[tonumber(factionIndex) or factionIndex]

            if (characterFaction and isstring(characterFaction.uniqueID)) then
                return string.lower(characterFaction.uniqueID)
            end
        end
    end

    return nil
end

local function RefreshScoreboardData(forceLog)
    local newData = {
        combine = {},
        resistance = {},
        unassigned = {}
    }

    for _, client in ipairs(player.GetAll()) do
        if (IsValid(client)) then
            local entry = {
                name = client:Nick(),
                ping = client:Ping(),
                steamID = client:SteamID()
            }
            local factionID = GetPlayerFactionID(client)

            if (factionID == "combine") then
                table.insert(newData.combine, entry)
            elseif (factionID == "resistance") then
                table.insert(newData.resistance, entry)
            else
                table.insert(newData.unassigned, entry)
            end
        end
    end

    local function SortEntries(entries)
        table.sort(entries, function(a, b)
            return string.lower(a.name or "") < string.lower(b.name or "")
        end)
    end

    SortEntries(newData.combine)
    SortEntries(newData.resistance)
    SortEntries(newData.unassigned)
    scoreboardData = newData

    local counts = string.format("combine=%d resistance=%d unassigned=%d total=%d",
        #newData.combine,
        #newData.resistance,
        #newData.unassigned,
        #newData.combine + #newData.resistance + #newData.unassigned
    )

    if (forceLog or counts ~= scoreboardLastCounts) then
        Log("DEBUG", "Scoreboard roster refreshed: " .. counts)
        scoreboardLastCounts = counts
    end
end

local function DrawScoreboardGroup(x, y, width, title, entries, accent, rowHeight, visibleRows)
    draw.RoundedBox(8, x, y, width, SY(44), Color(20, 31, 44, 218))
    surface.SetDrawColor(accent.r, accent.g, accent.b, 245)
    surface.DrawRect(x, y, SX(4), SY(44))

    draw.SimpleText(title, "MYRP_ScoreFaction", x + SX(18), y + SY(22), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(#entries), "MYRP_ScoreSmall", x + width - SX(18), y + SY(22), accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local listY = y + SY(54)
    local shown = math.min(#entries, visibleRows)

    if (shown == 0) then
        draw.RoundedBox(6, x, listY, width, rowHeight - SY(4), Color(13, 21, 30, 182))
        draw.SimpleText("НЕТ ИГРОКОВ", "MYRP_ScoreSmall", x + SX(16), listY + rowHeight * 0.5, Color(125, 140, 155), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return
    end

    for index = 1, shown do
        local entry = entries[index]
        local rowY = listY + (index - 1) * rowHeight
        local rowColor = (index % 2 == 0) and Color(22, 33, 45, 198) or Color(15, 25, 36, 184)

        draw.RoundedBox(6, x, rowY, width, rowHeight - SY(4), rowColor)
        surface.SetDrawColor(accent.r, accent.g, accent.b, 135)
        surface.DrawRect(x, rowY, SX(2), rowHeight - SY(4))

        draw.SimpleText(entry.name or "Unknown", "MYRP_ScorePlayer", x + SX(16), rowY + (rowHeight - SY(4)) * 0.5,
            Color(225, 233, 241), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(entry.ping or 0) .. " ms", "MYRP_ScoreSmall", x + width - SX(16),
            rowY + (rowHeight - SY(4)) * 0.5, Color(145, 165, 182), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    if (#entries > shown) then
        local extraY = listY + shown * rowHeight
        draw.SimpleText("+ " .. tostring(#entries - shown) .. " ЕЩЁ", "MYRP_ScoreSmall",
            x + SX(12), extraY, Color(165, 180, 195), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

local function DrawCustomScoreboard()
    local targetAlpha = scoreboardVisible and 1 or 0
    local blend = math.min(FrameTime() * 13, 1)
    scoreboardAlpha = Lerp(blend, scoreboardAlpha, targetAlpha)

    if (scoreboardAlpha <= 0.008) then return end

    local screenW, screenH = ScrW(), ScrH()
    local maxCount = math.max(#scoreboardData.combine, #scoreboardData.resistance, 1)
    local rowHeight = math.max(SY(38), 30)
    local titleArea = SY(180)
    local wantedHeight = titleArea + maxCount * rowHeight + SY(100)
    local panelHeight = math.min(screenH - SY(70), math.max(SY(430), wantedHeight))
    local panelWidth = math.min(SX(1160), screenW - SX(80))
    local panelX = math.floor((screenW - panelWidth) * 0.5)
    local panelY = math.floor((screenH - panelHeight) * 0.5 + (1 - scoreboardAlpha) * SY(18))
    local padding = SX(24)
    local gap = SX(22)
    local columnWidth = math.floor((panelWidth - padding * 2 - gap) * 0.5)
    local columnY = panelY + SY(132)
    local listAvailable = panelHeight - (columnY - panelY) - SY(75)
    local visibleRows = math.max(1, math.floor((listAvailable - SY(54)) / rowHeight))
    local theme = GetUITheme()

    surface.SetAlphaMultiplier(scoreboardAlpha)
    surface.SetDrawColor(0, 0, 0, 145)
    surface.DrawRect(0, 0, screenW, screenH)

    -- Faction-tinted glass panel with soft glow and generous corner radius.
    draw.RoundedBox(13, panelX - SX(3), panelY - SY(3), panelWidth + SX(6), panelHeight + SY(6),
        Color(theme.accent.r, theme.accent.g, theme.accent.b, 22))
    draw.RoundedBox(12, panelX, panelY, panelWidth, panelHeight, Color(7, 13, 20, 218))
    draw.RoundedBox(11, panelX + 1, panelY + 1, panelWidth - 2, panelHeight - 2, Color(10, 18, 27, 202))
    surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 105)
    surface.DrawOutlinedRect(panelX, panelY, panelWidth, panelHeight, 1)
    draw.RoundedBox(4, panelX + SX(2), panelY + SY(1), panelWidth - SX(4), SY(3),
        Color(theme.accent.r, theme.accent.g, theme.accent.b, 185))

    draw.SimpleText("MYRP  /  PERSONNEL ROSTER", "MYRP_ScoreTitle", panelX + padding, panelY + SY(38),
        Color(225, 235, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("СОСТАВ ФРАКЦИЙ", "MYRP_ScoreSmall", panelX + padding, panelY + SY(72),
        Color(145, 163, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("ONLINE  " .. tostring(#player.GetAll()), "MYRP_ScoreSmall", panelX + panelWidth - padding,
        panelY + SY(48), Color(150, 190, 165), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    DrawScoreboardGroup(panelX + padding, columnY, columnWidth, "COMBINE", scoreboardData.combine,
        Color(75, 145, 215), rowHeight, visibleRows)
    DrawScoreboardGroup(panelX + padding + columnWidth + gap, columnY, columnWidth, "RESISTANCE", scoreboardData.resistance,
        Color(195, 100, 82), rowHeight, visibleRows)

    if (#scoreboardData.unassigned > 0) then
        local names = {}
        for index = 1, math.min(#scoreboardData.unassigned, 4) do
            names[#names + 1] = scoreboardData.unassigned[index].name
        end
        local extra = #scoreboardData.unassigned > 4 and (" и ещё " .. tostring(#scoreboardData.unassigned - 4)) or ""
        draw.SimpleText("ОЖИДАЮТ НАЗНАЧЕНИЯ: " .. table.concat(names, ", ") .. extra,
            "MYRP_ScoreSmall", panelX + padding, panelY + panelHeight - SY(28),
            Color(195, 165, 105), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("УДЕРЖИВАЙ TAB, ЧТОБЫ ПОСМОТРЕТЬ СОСТАВ", "MYRP_ScoreSmall",
            panelX + padding, panelY + panelHeight - SY(28), Color(120, 143, 163), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    surface.SetAlphaMultiplier(1)
end

hook.Remove("ScoreboardShow", "MYRP.CustomScoreboard")
hook.Add("ScoreboardShow", "MYRP.CustomScoreboard", function()
    local client = LocalPlayer()
    if (!IsValid(client)) then
        Log("WARN", "TAB pressed but LocalPlayer is invalid; Helix scoreboard suppressed")
        return true
    end

    local wasVisible = scoreboardVisible
    scoreboardVisible = true
    scoreboardNextRefresh = 0
    RefreshScoreboardData(true)
    gui.EnableScreenClicker(false)
    if (!wasVisible) then PlayMYRPSound("open") end
    Log("INFO", "TAB pressed: MYRP scoreboard opening smoothly; Helix ixMenu suppressed")
    return true
end)

hook.Remove("ScoreboardHide", "MYRP.CustomScoreboard")
hook.Add("ScoreboardHide", "MYRP.CustomScoreboard", function()
    if (scoreboardVisible) then PlayMYRPSound("close") end
    scoreboardVisible = false
    Log("DEBUG", "TAB released: MYRP scoreboard fading out")
    return true
end)

hook.Remove("HUDPaint", "MYRP.CustomScoreboardPaint")
hook.Add("HUDPaint", "MYRP.CustomScoreboardPaint", DrawCustomScoreboard)

hook.Remove("Think", "MYRP.CustomScoreboardRefresh")
hook.Add("Think", "MYRP.CustomScoreboardRefresh", function()
    if (!scoreboardVisible or CurTime() < scoreboardNextRefresh) then return end
    scoreboardNextRefresh = CurTime() + 0.5
    RefreshScoreboardData(false)
end)

-- ---------------------------------------------------------------------------
-- MYRP INVENTORY v0.1 — Helix-backed inventory on C
-- ---------------------------------------------------------------------------
-- The grid is the native Helix ixInventory panel. This preserves item tooltips,
-- right-click functions, drag/drop and the ixInventory* network handlers.
-- The wallet UI is a read-only display until the economy module is implemented.

local INVENTORY_ROOT_NAME = "myrpInventoryRoot"
local INVENTORY_REFRESH_INTERVAL = 0.5
local inventoryNextRefresh = 0
local inventoryLastToggleAt = 0
local inventoryCKeyWasDown = false
local ToggleInventory -- forward declaration: also used by the focused VGUI panels

local function InventoryLog(level, message)
    Log(level, "[INVENTORY] " .. tostring(message))
end

local function CreateInventoryFonts()
    local scale = math.min(ScrW() / BASE_W, ScrH() / BASE_H)
    scale = math.Clamp(scale, 0.72, 1.35)

    surface.CreateFont("MYRP_InvTitle", {
        font = "Arial",
        size = math.floor(31 * scale),
        weight = 900,
        extended = true
    })

    surface.CreateFont("MYRP_InvSubtitle", {
        font = "Arial",
        size = math.floor(15 * scale),
        weight = 500,
        extended = true
    })

    surface.CreateFont("MYRP_InvSection", {
        font = "Arial",
        size = math.floor(17 * scale),
        weight = 800,
        extended = true
    })

    surface.CreateFont("MYRP_InvBody", {
        font = "Arial",
        size = math.floor(15 * scale),
        weight = 500,
        extended = true
    })

    surface.CreateFont("MYRP_InvMoney", {
        font = "Arial",
        size = math.floor(24 * scale),
        weight = 900,
        extended = true
    })
end

local function GetInventoryCurrency(client, character)
    local credits = 0
    local anamnecites = 0

    -- Credits are character-bound at this stage. The future economy plugin
    -- can update this value using character:SetData("credits", amount).
    if (character and character.GetData) then
        credits = tonumber(character:GetData("credits", 0)) or 0
        anamnecites = tonumber(character:GetData("anamnecites", 0)) or 0
    end

    -- Anamnecites are intended to last for the match, so the planned economy
    -- module can override the character fallback with a player-local value.
    if (IsValid(client) and client.GetLocalVar) then
        local playerCredits = client:GetLocalVar("myrpCredits", nil)
        local playerAnamnecites = client:GetLocalVar("myrpAnamnecites", nil)

        if (playerCredits != nil) then
            credits = tonumber(playerCredits) or credits
        end

        if (playerAnamnecites != nil) then
            anamnecites = tonumber(playerAnamnecites) or anamnecites
        end
    end

    return math.max(0, math.floor(credits)), math.floor(anamnecites)
end

local function FormatInventoryNumber(value)
    value = tonumber(value) or 0
    if (string.Comma) then
        return string.Comma(math.floor(value))
    end

    return tostring(math.floor(value))
end

local function GetMainInventory(client)
    if (!IsValid(client) or !client.GetCharacter) then
        return nil, nil, "LocalPlayer or GetCharacter is not ready"
    end

    local character = client:GetCharacter()
    if (!character) then
        return nil, nil, "no active character"
    end

    if (!character.GetInventory) then
        return character, nil, "character has no GetInventory method"
    end

    local inventory = character:GetInventory()
    if (!istable(inventory) or !inventory.slots or !inventory.GetSize) then
        return character, nil, "Helix inventory object is not synchronized yet"
    end

    return character, inventory
end

local function CloseInventory(reason)
    local root = ix.gui and ix.gui[INVENTORY_ROOT_NAME]
    if (!IsValid(root) or root.myrpClosing) then
        return false
    end

    root.myrpClosing = true
    InventoryLog("INFO", "Closing inventory with smooth transition; reason=" .. tostring(reason or "user"))
    PlayMYRPSound("close")
    gui.EnableScreenClicker(false)

    local function FinishClose()
        if (!IsValid(root)) then return end

        if (ix.gui and ix.gui.inv1 == root.inventoryPanel) then
            local previous = root.previousInv1
            ix.gui.inv1 = IsValid(previous) and previous or nil
        end
        if (ix.gui and ix.gui["inv1"] == root.inventoryPanel) then
            local previous = root.previousInv1
            ix.gui["inv1"] = IsValid(previous) and previous or nil
        end
        if (ix.gui and ix.gui[INVENTORY_ROOT_NAME] == root) then
            ix.gui[INVENTORY_ROOT_NAME] = nil
        end
        root:Remove()
    end

    root:SetMouseInputEnabled(false)
    root:SetKeyboardInputEnabled(false)
    AnimateMYRPOut(root, 0.16, "down", FinishClose)
    return true
end

local function BuildInventoryWindow()
    local client = LocalPlayer()
    local character, inventory, reason = GetMainInventory(client)

    if (!inventory) then
        InventoryLog("WARN", "Cannot open inventory: " .. tostring(reason))
        return nil
    end

    if (!vgui.GetControlTable("ixInventory")) then
        InventoryLog("ERROR", "Helix VGUI control ixInventory is not registered; check Helix item system load order")
        return nil
    end

    CreateInventoryFonts()

    local screenW, screenH = ScrW(), ScrH()
    local windowW = math.min(SX(1080), screenW - SX(48))
    local windowH = math.min(SY(760), screenH - SY(48))
    windowW = math.max(math.min(windowW, screenW), 560)
    windowH = math.max(math.min(windowH, screenH), 440)

    local windowX = math.floor((screenW - windowW) * 0.5)
    local windowY = math.floor((screenH - windowH) * 0.5)
    local pad = SX(34)
    local bodyTop = SY(126)
    local walletHeight = SY(112)
    local bodyBottom = windowH - walletHeight - SY(28)
    local bodyHeight = bodyBottom - bodyTop
    local leftWidth = math.floor(windowW * 0.63)
    local rightX = windowX + leftWidth + SX(18)
    local rightWidth = windowW - leftWidth - SX(18) - pad

    local root = vgui.Create("DPanel")
    if (!IsValid(root)) then
        InventoryLog("ERROR", "Could not create inventory root panel")
        return nil
    end

    root:SetName("MYRPInventoryRoot")
    root:SetSize(screenW, screenH)
    root:SetPos(0, 0)
    root:SetAlpha(0)
    root:SetZPos(32760)
    root:SetMouseInputEnabled(true)
    root:MakePopup()
    -- Keep mouse control but pass movement keys to the game.
    root:SetKeyboardInputEnabled(false)

    root.previousInv1 = ix.gui and ix.gui.inv1 or nil
    root.characterID = character:GetID()

    root.Paint = function(self, width, height)
        local theme = GetUITheme()
        surface.SetDrawColor(0, 0, 0, 178)
        surface.DrawRect(0, 0, width, height)

        draw.RoundedBox(14, windowX - SX(3), windowY - SY(3), windowW + SX(6), windowH + SY(6),
            Color(theme.accent.r, theme.accent.g, theme.accent.b, 24))
        draw.RoundedBox(12, windowX, windowY, windowW, windowH, Color(7, 13, 20, 214))
        draw.RoundedBox(11, windowX + 1, windowY + 1, windowW - 2, windowH - 2, Color(10, 18, 27, 190))
        surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 112)
        surface.DrawOutlinedRect(windowX, windowY, windowW, windowH, 1)
        draw.RoundedBox(4, windowX + SX(2), windowY + SY(1), windowW - SX(4), SY(3),
            Color(theme.accent.r, theme.accent.g, theme.accent.b, 175))

        draw.SimpleText("MYRP  /  INVENTORY", "MYRP_InvTitle",
            windowX + pad, windowY + SY(39), Color(226, 235, 244), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛИЧНЫЕ ВЕЩИ И СНАРЯЖЕНИЕ", "MYRP_InvSubtitle",
            windowX + pad, windowY + SY(73), Color(125, 149, 171), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText(IsValid(client) and client:Nick() or "UNKNOWN",
            "MYRP_InvBody", windowX + windowW - SX(82), windowY + SY(42),
            Color(190, 207, 222), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("C  /  ESC  —  ЗАКРЫТЬ", "MYRP_InvSubtitle",
            windowX + windowW - SX(82), windowY + SY(72), Color(100, 123, 145), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        local gridX = windowX + pad
        local gridY = windowY + bodyTop
        local gridW = leftWidth - pad - SX(12)

        draw.RoundedBox(9, gridX, gridY, gridW, bodyHeight, Color(theme.panelInner.r, theme.panelInner.g, theme.panelInner.b, 172))
        surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 78)
        surface.DrawOutlinedRect(gridX, gridY, gridW, bodyHeight, 1)
        draw.SimpleText("СОДЕРЖИМОЕ", "MYRP_InvSection", gridX + SX(18), gridY + SY(24),
            Color(190, 209, 226), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.RoundedBox(9, rightX, gridY, rightWidth, bodyHeight, Color(theme.panelInner.r, theme.panelInner.g, theme.panelInner.b, 172))
        surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 78)
        surface.DrawOutlinedRect(rightX, gridY, rightWidth, bodyHeight, 1)
        draw.SimpleText("ИНФОРМАЦИЯ", "MYRP_InvSection", rightX + SX(18), gridY + SY(24),
            Color(190, 209, 226), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local itemCount = 0
        if (inventory and inventory.GetItems) then
            itemCount = table.Count(inventory:GetItems() or {})
        end

        draw.SimpleText("ПРЕДМЕТОВ: " .. tostring(itemCount), "MYRP_InvBody",
            rightX + SX(18), gridY + SY(70), Color(145, 169, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ПКМ  —  ДЕЙСТВИЯ", "MYRP_InvBody",
            rightX + SX(18), gridY + SY(122), Color(174, 190, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ПЕРЕТАСКИВАНИЕ  —  ПЕРЕМЕЩЕНИЕ", "MYRP_InvBody",
            rightX + SX(18), gridY + SY(157), Color(174, 190, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Предметы и их действия обрабатываются", "MYRP_InvSubtitle",
            rightX + SX(18), gridY + SY(220), Color(108, 130, 149), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("серверной системой Helix.", "MYRP_InvSubtitle",
            rightX + SX(18), gridY + SY(246), Color(108, 130, 149), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local walletY = windowY + windowH - walletHeight + SY(4)
        local cardGap = SX(16)
        local cardW = math.floor((windowW - pad * 2 - cardGap) * 0.5)
        local cardH = SY(76)
        local credits, anamnecites = GetInventoryCurrency(client, character)

        draw.RoundedBox(9, windowX + pad, walletY, cardW, cardH, Color(13, 28, 24, 215))
        surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 85)
        surface.DrawOutlinedRect(windowX + pad, walletY, cardW, cardH, 1)
        draw.SimpleText("КРЕДИТЫ", "MYRP_InvSubtitle", windowX + pad + SX(18), walletY + SY(20),
            Color(145, 216, 165), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(FormatInventoryNumber(credits), "MYRP_InvMoney",
            windowX + pad + cardW - SX(18), walletY + SY(42), Color(151, 225, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        local anaX = windowX + pad + cardW + cardGap
        draw.RoundedBox(9, anaX, walletY, cardW, cardH, Color(31, 26, 14, 215))
        surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 85)
        surface.DrawOutlinedRect(anaX, walletY, cardW, cardH, 1)
        draw.SimpleText("АНАМНЕЦИТЫ", "MYRP_InvSubtitle", anaX + SX(18), walletY + SY(20),
            Color(232, 202, 105), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(FormatInventoryNumber(anamnecites), "MYRP_InvMoney",
            anaX + cardW - SX(18), walletY + SY(42), Color(245, 211, 111), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        draw.SimpleText("MYRP  /  HALF-LIFE UNIVERSE", "MYRP_InvSubtitle",
            windowX + windowW * 0.5, windowY + windowH - SY(17), Color(79, 98, 117), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    root.OnKeyCodePressed = function(self, keyCode)
        -- PlayerBindPress may not receive C while this popup owns keyboard focus.
        -- Catch the physical key here as a second, debounced close path.
        if (keyCode == KEY_C) then
            InventoryLog("DEBUG", "C captured by inventory root panel")
            ToggleInventory("root panel")
            return true
        end
    end

    root.OnRemove = function(self)
        if (ix.gui and ix.gui.inv1 == self.inventoryPanel) then
            local previous = self.previousInv1
            ix.gui.inv1 = IsValid(previous) and previous or nil
        end

        if (ix.gui and ix.gui["inv1"] == self.inventoryPanel) then
            local previous = self.previousInv1
            ix.gui["inv1"] = IsValid(previous) and previous or nil
        end

        if (ix.gui and ix.gui[INVENTORY_ROOT_NAME] == self) then
            ix.gui[INVENTORY_ROOT_NAME] = nil
        end

        gui.EnableScreenClicker(false)
        InventoryLog("DEBUG", "Inventory root removed")
    end

    ix.gui[INVENTORY_ROOT_NAME] = root

    local gridAreaX = windowX + pad + SX(12)
    local gridAreaY = windowY + bodyTop + SY(58)
    local gridAreaW = leftWidth - pad * 2 - SX(24)
    local gridAreaH = bodyHeight - SY(75)
    local inventoryW, inventoryH = inventory:GetSize()

    if (!inventoryW or !inventoryH or inventoryW < 1 or inventoryH < 1) then
        InventoryLog("ERROR", "Invalid inventory dimensions: " .. tostring(inventoryW) .. "x" .. tostring(inventoryH))
        root:Remove()
        return nil
    end

    local iconSize = math.floor(math.min(gridAreaW / inventoryW, gridAreaH / inventoryH, SX(76)))
    iconSize = math.max(28, iconSize)

    local inventoryPanel = vgui.Create("ixInventory", root)
    if (!IsValid(inventoryPanel)) then
        InventoryLog("ERROR", "vgui.Create(ixInventory) failed")
        root:Remove()
        return nil
    end

    inventoryPanel:SetTitle(nil)
    inventoryPanel:ShowCloseButton(false)
    inventoryPanel:SetDraggable(false)
    inventoryPanel:SetSizable(false)
    inventoryPanel:SetIconSize(iconSize)
    inventoryPanel:SetMouseInputEnabled(true)
    inventoryPanel:SetKeyboardInputEnabled(false)
    inventoryPanel.childPanels = {}
    inventoryPanel.bNoBackgroundBlur = true
    inventoryPanel.Paint = function(self, width, height)
        local theme = GetUITheme()
        draw.RoundedBox(8, 0, 0, width, height, Color(theme.panelInner.r, theme.panelInner.g, theme.panelInner.b, 224))
        surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 105)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    -- ixInventory can own focus on some Helix builds, so catch C here too.
    inventoryPanel.OnKeyCodePressed = function(self, keyCode)
        if (keyCode == KEY_C) then
            InventoryLog("DEBUG", "C captured by ixInventory child panel")
            ToggleInventory("inventory child panel")
            return true
        end
    end

    local oldInv1 = ix.gui.inv1
    inventoryPanel:SetInventory(inventory)
    inventoryPanel:SetZPos(20)
    inventoryPanel:SetPos(
        gridAreaX + math.floor((gridAreaW - inventoryPanel:GetWide()) * 0.5),
        gridAreaY + math.floor((gridAreaH - inventoryPanel:GetTall()) * 0.5)
    )

    -- Helix's ixInventory* net receivers look up ix.gui.inv1 for the active
    -- character inventory. Register our native panel there to keep the grid
    -- synchronized after item moves, additions and removals.
    root.inventoryPanel = inventoryPanel
    root.previousInv1 = oldInv1
    ix.gui.inv1 = inventoryPanel

    root:MoveToFront()
    gui.EnableScreenClicker(true)
    AnimateMYRPIn(root, 0.22, "up")

    local items = inventory.GetItems and inventory:GetItems() or {}
    InventoryLog("INFO", "Opened native Helix inventory; characterID=" .. tostring(character:GetID())
        .. ", inventoryID=" .. tostring(inventory:GetID())
        .. ", grid=" .. tostring(inventoryW) .. "x" .. tostring(inventoryH)
        .. ", items=" .. tostring(table.Count(items))
        .. ", iconSize=" .. tostring(iconSize)
        .. ", panelSize=" .. tostring(inventoryPanel:GetWide()) .. "x" .. tostring(inventoryPanel:GetTall())
        .. ", resolution=" .. UIResolution())

    root.Think = function(self)
        local currentCharacter = IsValid(client) and client.GetCharacter and client:GetCharacter()
        if (!currentCharacter or currentCharacter:GetID() != self.characterID) then
            CloseInventory("character changed or unloaded")
        end
    end

    return root
end

local function OpenInventory()
    if (!ix.gui) then
        InventoryLog("ERROR", "ix.gui is unavailable")
        return nil
    end

    local existing = ix.gui[INVENTORY_ROOT_NAME]
    if (IsValid(existing)) then
        existing:MoveToFront()
        existing:MakePopup()
        gui.EnableScreenClicker(true)
        InventoryLog("DEBUG", "Inventory already open; brought to front")
        return existing
    end

    local root = BuildInventoryWindow()
    if (!IsValid(root)) then
        return nil
    end

    return root
end

ToggleInventory = function(source)
    local now = RealTime()

    -- The same key can be observed by both PlayerBindPress and a focused VGUI
    -- panel. Debounce those duplicate paths so one C press never reopens the UI.
    if (now - inventoryLastToggleAt < 0.20) then
        InventoryLog("DEBUG", "Ignoring duplicate C toggle; source=" .. tostring(source or "unknown"))
        return
    end

    inventoryLastToggleAt = now

    local existing = ix.gui and ix.gui[INVENTORY_ROOT_NAME]
    if (IsValid(existing)) then
        InventoryLog("INFO", "C toggled inventory closed; source=" .. tostring(source or "bind"))
        CloseInventory("C toggled closed")
        return
    end

    InventoryLog("INFO", "C toggled inventory open; source=" .. tostring(source or "bind"))
    OpenInventory()
end

local function GetInventoryStatus()
    local client = LocalPlayer()
    local character, inventory, reason = GetMainInventory(client)
    local root = ix.gui and ix.gui[INVENTORY_ROOT_NAME]

    if (!inventory) then
        InventoryLog("WARN", "STATUS inventory unavailable: " .. tostring(reason))
        return
    end

    local width, height = inventory:GetSize()
    local items = inventory.GetItems and inventory:GetItems() or {}
    local credits, anamnecites = GetInventoryCurrency(client, character)

    InventoryLog("INFO", "STATUS open=" .. tostring(IsValid(root))
        .. ", characterID=" .. tostring(character:GetID())
        .. ", inventoryID=" .. tostring(inventory:GetID())
        .. ", grid=" .. tostring(width) .. "x" .. tostring(height)
        .. ", items=" .. tostring(table.Count(items))
        .. ", credits=" .. tostring(credits)
        .. ", anamnecites=" .. tostring(anamnecites)
        .. ", ix.gui.inv1Valid=" .. tostring(ix.gui and IsValid(ix.gui.inv1)))
end

concommand.Add("myrp_inventory_status", GetInventoryStatus)
concommand.Add("myrp_inventory_reopen", function()
    CloseInventory("manual reopen")
    OpenInventory()
end)
concommand.Add("myrp_inventory_close", function()
    local closed = CloseInventory("console command")
    InventoryLog("INFO", "Manual close command executed; closed=" .. tostring(closed))
end)
concommand.Add("myrp_inventory_debug_items", function()
    local client = LocalPlayer()
    local character, inventory, reason = GetMainInventory(client)
    if (!inventory) then
        InventoryLog("ERROR", "Cannot list items: " .. tostring(reason))
        return
    end

    local items = inventory.GetItems and inventory:GetItems() or {}
    InventoryLog("INFO", "Listing " .. tostring(table.Count(items)) .. " inventory item(s)")

    for _, item in pairs(items) do
        if (item) then
            InventoryLog("DEBUG", "item id=" .. tostring(item.id)
                .. ", uniqueID=" .. tostring(item.uniqueID)
                .. ", name=" .. tostring(item.name)
                .. ", position=" .. tostring(item.gridX) .. "," .. tostring(item.gridY)
                .. ", size=" .. tostring(item.width) .. "x" .. tostring(item.height))
        end
    end
end)

-- Replace the v1.7 temporary C blocker with the actual inventory toggle.
hook.Remove("PlayerBindPress", "MYRP.BlockContextMenu")
hook.Remove("PlayerBindPress", "MYRP.InventoryToggle")
hook.Add("PlayerBindPress", "MYRP.InventoryToggle", function(client, bind, pressed)
    if (client != LocalPlayer()) then return end

    local originalBind = string.lower(tostring(bind or ""))
    local translatedBind = originalBind
    if (input and input.TranslateAlias) then
        translatedBind = string.lower(tostring(input.TranslateAlias(bind) or originalBind))
    end

    local isContextBind = string.find(originalBind, "+menu_context", 1, true)
        or string.find(translatedBind, "+menu_context", 1, true)

    if (isContextBind) then
        InventoryLog("DEBUG", "PlayerBindPress received context bind; bind=" .. originalBind
            .. ", translated=" .. translatedBind
            .. ", pressed=" .. tostring(pressed)
            .. ", panelOpen=" .. tostring(IsValid(ix.gui and ix.gui[INVENTORY_ROOT_NAME])))

        if (pressed) then
            -- Prevent the Think fallback from treating the same physical keydown
            -- as a second close event after this bind handler opens the window.
            inventoryCKeyWasDown = true
            local activeCharacter = client.GetCharacter and client:GetCharacter()
            if (!activeCharacter) then
                InventoryLog("WARN", "C pressed but player has no active character")
            else
                ToggleInventory("PlayerBindPress")
            end
        end

        return true
    end
end)

-- Fallback close path: while the inventory is open, C may be routed to a
-- nested VGUI child instead of PlayerBindPress/root OnKeyCodePressed. Poll the
-- physical key edge only while the window is open. Toggle debounce prevents a
-- duplicate close if another input path observed the same press this frame.
hook.Remove("Think", "MYRP.InventoryCloseKeyFallback")
hook.Add("Think", "MYRP.InventoryCloseKeyFallback", function()
    if (!input or !input.IsKeyDown) then return end

    local isDown = input.IsKeyDown(KEY_C)
    if (isDown and !inventoryCKeyWasDown) then
        local root = ix.gui and ix.gui[INVENTORY_ROOT_NAME]
        if (IsValid(root)) then
            InventoryLog("DEBUG", "C detected by Think fallback while inventory is open")
            ToggleInventory("Think KEY_C fallback")
        end
    end

    inventoryCKeyWasDown = isDown
end)

-- ESC is handled by the game UI before VGUI's OnKeyCodePressed, so a panel
-- key callback cannot catch it. OnPauseMenuShow is the supported GMod hook.
-- Returning false only while our inventory is open closes it and suppresses
-- the pause menu for that one Esc press. Esc works normally everywhere else.
hook.Remove("OnPauseMenuShow", "MYRP.InventoryEscape")
hook.Add("OnPauseMenuShow", "MYRP.InventoryEscape", function()
    local root = ix.gui and ix.gui[INVENTORY_ROOT_NAME]
    if (IsValid(root)) then
        InventoryLog("INFO", "ESC detected by OnPauseMenuShow; closing inventory")
        CloseInventory("escape / OnPauseMenuShow")
        return false
    end
end)

InventoryLog("INFO", "Inventory module registered; C toggles native ixInventory; C fallback active; ESC closes via OnPauseMenuShow")
