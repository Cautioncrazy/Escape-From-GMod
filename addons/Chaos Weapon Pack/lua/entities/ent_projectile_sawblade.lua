AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Spinning Sawblade"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

local DAMAGE_SLICE = 75
local FLIGHT_MODEL = "models/props_c17/TrapPropeller_Blade.mdl" 

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(FLIGHT_MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
            phys:SetMass(50) 
            phys:SetMaterial("metal")
        end
        
        self.IsHeated = false
    end

    function ENT:SetHeated(bool)
        self.IsHeated = bool
        if bool then
            -- VISUAL: Ignite the sawblade itself!
            -- This creates the Source Engine fire particle effect attached to the blade.
            self:Ignite(30, 0) 
            
            -- Add an orange trail to complement the fire
            util.SpriteTrail(self, 0, Color(255, 100, 0), false, 40, 0, 1, 1/(15+1)*0.5, "trails/plasma")
            
            -- Change color to look hot
            self:SetColor(Color(255, 150, 150))
        end
    end

    function ENT:PhysicsCollide(data, phys)
        -- Audio/Visual impact effects
        if data.Speed > 100 then
            self:EmitSound("Physics.Metal.ImpactHard")
        end

        if data.Speed > 200 and data.DeltaTime > 0.2 then
            local effect = EffectData()
            effect:SetOrigin(data.HitPos)
            effect:SetNormal(data.HitNormal)
            util.Effect("ManhackSparks", effect)
        end

        -- Damage Logic
        local ent = data.HitEntity
        if IsValid(ent) then
            local attacker = self:GetOwner()
            if not IsValid(attacker) then attacker = self end

            local dmg = DamageInfo()
            dmg:SetDamage(DAMAGE_SLICE)
            dmg:SetAttacker(attacker)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH) 

            ent:TakeDamageInfo(dmg)

            -- FIRE LOGIC: Ignite Props, NPCs, and Players
            if self.IsHeated then
                -- Check if the entity is valid and not the world
                if not ent:IsWorld() then
                    ent:Ignite(10) -- Set them on fire for 10 seconds
                    self:EmitSound("General.BurningObject")
                else
                    -- If we hit the world (wall/floor), leave a scorch mark
                    util.Decal("Scorch", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal)
                end
            end
        end
        
        SafeRemoveEntityDelayed(self, 10)
    end
end