AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Junk Projectile"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

-- Lists of random garbage to shoot
-- UPDATED: Corrected file paths to ensure standard HL2 models are used
local MODELS_LIGHT = {
    "models/props_junk/watermelon01.mdl",
    "models/props_junk/TrafficCone001a.mdl", -- Fixed path (was props_c17)
    "models/props_lab/monitor01a.mdl",
    "models/props_c17/FurnitureChair001a.mdl", -- Fixed path to standard chair
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/PlasticCrate01a.mdl",
    "models/props_c17/doll01.mdl"
}

local MODELS_HEAVY = {
    "models/props_c17/Lockers001a.mdl",
    "models/props_wasteland/kitchen_stove001a.mdl",
    "models/props_interiors/BathTub01a.mdl",
    "models/props_junk/TrashDumpster01a.mdl", -- Fixed path (Dumpster_2 is often missing)
    "models/props_wasteland/laundry_dryer002.mdl"
}

function ENT:SetupDataTables()
    -- No networked vars needed, strictly server-side physics
end

if SERVER then
    function ENT:Initialize()
        -- 1. Pick Model based on "Heavy" setting
        local modelList = MODELS_LIGHT
        if self.IsHeavy then 
            modelList = MODELS_HEAVY 
        end
        
        local randomModel = modelList[math.random(#modelList)]
        self:SetModel(randomModel)
        
        -- 2. Physics Init
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        -- 3. Adjust Stats
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            if self.IsHeavy then
                phys:SetMass(500) -- Very Heavy (Crushing damage)
            else
                phys:SetMass(50)  -- Standard
            end
        end
        
        -- Auto-remove after 10 seconds to prevent lag
        SafeRemoveEntityDelayed(self, 10)
    end
    
    -- Allow weapon to set heavy mode before Spawn() is called
    function ENT:SetHeavy(bool)
        self.IsHeavy = bool
    end

    function ENT:PhysicsCollide(data, phys)
        -- Deal physics damage on impact
        -- Source engine calculates impact damage automatically based on mass * speed,
        -- but we can amplify it here if we want specific gameplay rules.
        
        local ent = data.HitEntity
        if IsValid(ent) and (ent:IsNPC() or ent:IsPlayer()) then
            -- Optional: Force extra damage for fun
            local dmg = DamageInfo()
            local damageAmount = data.Speed * 0.1 -- Standard physics calc
            
            if self.IsHeavy then damageAmount = damageAmount * 2 end -- Heavy objects hurt more
            
            dmg:SetDamage(damageAmount)
            dmg:SetAttacker(self:GetOwner() or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CRUSH)
            
            ent:TakeDamageInfo(dmg)
            
            -- Play a satisfying bonk sound
            self:EmitSound("Physics.Flesh.ImpactHard")
        end
        
        if data.Speed > 100 and data.DeltaTime > 0.2 then
             self:EmitSound("Physics.Metal.ImpactHard")
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end