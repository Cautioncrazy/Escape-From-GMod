AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gravity Grenade"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

local MODEL = "models/Combine_Helicopter/helicopter_bomb01.mdl"
local GRAVITY_RADIUS = 600
local GRAVITY_FORCE = 8000
local DURATION = 4.0

if SERVER then
    function ENT:Initialize()
        self:SetModel(MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(10)
        end
        
        self.Detonated = false
        self.EndTime = 0
        
        util.SpriteTrail(self, 0, Color(100, 0, 255), false, 20, 0, 1, 1/(15+1)*0.5, "trails/laser")
    end

    function ENT:PhysicsCollide(data, phys)
        if self.Detonated then return end
        
        if data.Speed > 50 then
            self:Detonate()
        end
    end

    function ENT:Detonate()
        self.Detonated = true
        self.EndTime = CurTime() + DURATION
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false) -- Freeze in place
        end
        
        self:EmitSound("ambient/machines/combine_shield_loop3.wav")
    end

    function ENT:Think()
        if not self.Detonated then return end
        
        if CurTime() > self.EndTime then
            self:Explode()
            return
        end
        
        -- SUCK LOGIC
        local pos = self:GetPos()
        local entities = ents.FindInSphere(pos, GRAVITY_RADIUS)
        
        for _, v in pairs(entities) do
            if IsValid(v) and v ~= self then
                local vPos = v:GetPos()
                local dir = (pos - vPos):GetNormalized()
                local dist = pos:Distance(vPos)
                local force = (GRAVITY_FORCE * (1 - dist/GRAVITY_RADIUS)) * 0.5
                
                local phys = v:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(dir * force)
                elseif v:IsPlayer() or v:IsNPC() then
                    v:SetVelocity(dir * force * 0.05)
                end
            end
        end
        
        -- Shake
        if math.random() > 0.7 then
             local effect = EffectData()
             effect:SetOrigin(pos)
             util.Effect("cball_bounce", effect)
        end
        
        self:NextThink(CurTime() + 0.1)
        return true
    end
    
    function ENT:Explode()
        local pos = self:GetPos()
        local effect = EffectData()
        effect:SetOrigin(pos)
        util.Effect("cball_explode", effect)
        
        self:EmitSound("Weapon_AR2.NPC_Reload")
        util.BlastDamage(self, self:GetOwner() or self, pos, GRAVITY_RADIUS/2, 200)
        self:Remove()
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        if self:GetVelocity():Length() < 10 then -- If stuck/detonating
            local size = 100 + math.sin(CurTime() * 20) * 10
            render.SetMaterial(Material("sprites/light_glow02_add"))
            render.DrawSprite(self:GetPos(), size, size, Color(100, 0, 255, 100))
        end
    end
end