AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Magnet Core"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

-- Using a combine battery model - looks techy and magnetic
local MODEL = "models/Items/combine_rifle_ammo01.mdl"

if SERVER then
    function ENT:Initialize()
        self:SetModel(MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(20)
        end
        
        self.IsActive = false
        self.MagnetRadius = 600
        self.MagnetForce = 4000
        
        -- Trail
        util.SpriteTrail(self, 0, Color(100, 150, 255), false, 20, 0, 1, 1/(15+1)*0.5, "trails/plasma")
    end

    function ENT:PhysicsCollide(data, phys)
        -- If we hit something and we aren't active yet, stick to it!
        if not self.IsActive and data.Speed > 50 then
            self.IsActive = true
            
            -- Freeze in place
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
            end
            
            -- Play activation sound
            self:EmitSound("Weapon_StunStick.Activate")
            self:EmitSound("ambient/machines/combine_shield_loop3.wav")
            
            -- If we hit a movable prop, weld to it so we move with it
            local hitEnt = data.HitEntity
            if IsValid(hitEnt) and not hitEnt:IsWorld() then
                constraint.Weld(self, hitEnt, 0, 0, 0, true, false)
            end
        end
    end

    function ENT:Think()
        if not self.IsActive then return end
        
        local pos = self:GetPos()
        local entities = ents.FindInSphere(pos, self.MagnetRadius)
        
        for _, v in pairs(entities) do
            if IsValid(v) and v ~= self and not v:IsPlayer() then
                -- Check if it has physics
                local phys = v:GetPhysicsObject()
                if IsValid(phys) and phys:IsMotionEnabled() then
                    -- Don't pull the thing we are stuck to
                    if constraint.FindConstraint(self, "Weld") and v == constraint.FindConstraint(self, "Weld").Ent2 then
                        continue
                    end
                    
                    -- Calculate Pull Vector
                    local targetPos = v:GetPos()
                    local dir = (pos - targetPos):GetNormalized()
                    local dist = pos:Distance(targetPos)
                    
                    -- Force gets stronger closer to center
                    local force = self.MagnetForce * (1 - (dist / self.MagnetRadius))
                    
                    -- Apply Force
                    phys:ApplyForceCenter(dir * force)
                    
                    -- Visual Lightning from Magnet to Object
                    if math.random() < 0.1 then -- Don't draw every frame, too spammy
                        local effect = EffectData()
                        effect:SetStart(pos)
                        effect:SetOrigin(targetPos)
                        effect:SetMagnitude(1)
                        effect:SetScale(1)
                        effect:SetRadius(2)
                        util.Effect("tooltracer", effect)
                    end
                end
            end
        end
        
        -- Magnetic Humming Sound pitch shift based on load?
        -- For now, just a loop is fine.
        
        self:NextThink(CurTime() + 0.1)
        return true
    end
    
    function ENT:Detonate()
        local pos = self:GetPos()
        
        -- Explosion
        local effect = EffectData()
        effect:SetOrigin(pos)
        util.Effect("cball_explode", effect)
        self:EmitSound("Weapon_MegaPhysCannon.Drop")
        self:StopSound("ambient/machines/combine_shield_loop3.wav")
        
        -- Push everything away gently (release)
        util.BlastDamage(self, self:GetOwner() or self, pos, 200, 10)
        
        self:Remove()
    end
    
    function ENT:OnRemove()
        self:StopSound("ambient/machines/combine_shield_loop3.wav")
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        
        -- Draw Magnetic Field Sphere
        if self:GetVelocity():Length() < 10 then -- If mostly still (stuck)
            local size = 50 + math.sin(CurTime() * 10) * 5
            
            render.SetMaterial(Material("sprites/light_glow02_add"))
            render.DrawSprite(self:GetPos(), size, size, Color(100, 200, 255, 100))
        end
    end
end