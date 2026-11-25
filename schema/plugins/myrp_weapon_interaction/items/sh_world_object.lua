ITEM.name = "Физический предмет"
ITEM.description = "Подобранный физический объект."
ITEM.model = "models/props_junk/popcan01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Прочее"
ITEM.noBusiness = true

function ITEM:GetName()
    return self:GetData("myrpWorldName", self.name)
end

function ITEM:GetDescription()
    return self:GetData("myrpWorldDescription", self.description)
end

function ITEM:GetModel()
    local model = self:GetData("myrpWorldModel", self.model)

    if (isstring(model) and util.IsValidModel(model)) then
        return model
    end

    return self.model
end

function ITEM:GetSkin()
    return math.max(tonumber(self:GetData("myrpWorldSkin", 0)) or 0, 0)
end
