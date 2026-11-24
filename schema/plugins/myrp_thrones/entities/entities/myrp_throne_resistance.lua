ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Resistance Radio Locator"
ENT.Category = "MYRP | Thrones"

ENT.Spawnable = false
ENT.AdminOnly = true
ENT.bNoPersist = true

ENT.Model = "models/props_lab/workspace003.mdl"
ENT.Faction = "resistance"
ENT.MaxThroneHealth = 20000
ENT.FactionColor = Color(220, 148, 90, 255)

if SERVER then
    function ENT:Initialize()
        local model = self.Model

        if not util.IsValidModel(model) then
            model = "models/props_lab/reciever01b.mdl"
            ErrorNoHalt("[MYRP:THRONES] Resistance model unavailable; using fallback.\n")
        end

        self:SetModel(model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        self:SetMaxHealth(self.MaxThroneHealth)
        self:SetHealth(self.MaxThroneHealth)
        self:SetNWInt("myrpThroneHealth", self:Health())
        self:SetNWInt("myrpThroneMaxHealth", self:GetMaxHealth())

        self:SetRenderMode(RENDERMODE_TRANSCOLOR)
        self:SetColor(self.FactionColor)
        self:DrawShadow(true)

        local physicsObject = self:GetPhysicsObject()

        if IsValid(physicsObject) then
            physicsObject:EnableMotion(false)
            physicsObject:Sleep()
        else
            self:SetMoveType(MOVETYPE_NONE)
            self:SetSolid(SOLID_BBOX)
        end
    end
elseif CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end