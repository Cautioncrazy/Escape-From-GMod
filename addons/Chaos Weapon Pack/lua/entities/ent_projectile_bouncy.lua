AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Kinetic Round"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

-- Use a Combine Helicopter Bomb model (looks like a tech sphere)
local MODEL = "models/Combine_Helicopter/helicopter_bomb01.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Bounces")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(MODEL)
        
        -- Scale it down slightly
        self:SetModelScale(0.5, 0)
        self:Activate()
        
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        -- Use the "Rubber" material for max bounciness
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(10)
            phys:SetMaterial("gmod_bouncy") -- Built-in super bouncy material
            phys:EnableGravity(false) -- Fly straight until bounce
            phys:EnableDrag(false)    -- Disable drag so it doesn't lose speed in air
            phys:SetDamping(0, 0)     -- No air resistance
        end
        
        self:SetBounces(0)
        self.MaxBounces = 1000
        self.BaseDamage = 50
        self.LastBounceTime = 0
        self.CurrentSpeed = nil -- Store speed to ensure it never loses momentum
        
        -- Failsafe: Remove after 30 seconds so we don't lag the server with infinite projectiles
        SafeRemoveEntityDelayed(self, 30)
        
        -- Visual Trail (Store reference to update color later)
        self.Trail = util.SpriteTrail(self, 0, Color(0, 255, 255), false, 30, 0, 1, 1/(15+1)*0.5, "trails/laser")
        self:SetColor(Color(0, 255, 255))
    end

    function ENT:PhysicsCollide(data, phys)
        -- 0. Collision Cooldown (Debounce)
        if CurTime() - self.LastBounceTime < 0.1 then 
            return 
        end
        self.LastBounceTime = CurTime()

        -- 1. Bounce Logic
        local bounces = self:GetBounces()
        
        -- If we hit an enemy (Player/NPC), hurt them and explode
        local hitEnt = data.HitEntity
        if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
            self:Detonate()
            return
        end
        
        -- If we hit a wall/prop, bounce!
        if bounces >= self.MaxBounces then
            self:Detonate() -- Too many bounces, explode
            return
        end

        -- 2. Kinetic Build-up
        self:SetBounces(bounces + 1)
        
        -- Speed calculations
        if not self.CurrentSpeed then
            self.CurrentSpeed = data.OurOldVelocity:Length()
        end
        self.CurrentSpeed = math.min(self.CurrentSpeed * 1.3, 6000)
        
        -- Reflect vector
        local reflect = data.OurOldVelocity - (2 * data.OurOldVelocity:Dot(data.HitNormal) * data.HitNormal)
        local finalVel = reflect:GetNormalized() * self.CurrentSpeed
        
        -- Apply immediately
        timer.Simple(0, function()
            if IsValid(phys) then 
                phys:SetVelocity(finalVel) 
                phys:EnableGravity(false)
                phys:EnableDrag(false)
                phys:SetDamping(0, 0)
            end
        end)

        -- 3. Visual/Audio Feedback
        self:EmitSound("Rubber.ImpactHard", 75, 100 + (bounces * 10))
        
        -- UPDATED: RGB Cycle Logic
        -- We use HSVToColor to cycle through the rainbow based on bounce count.
        -- (bounces * 35) shifts the hue by 35 degrees each hit, creating a distinct color change.
        local hue = (bounces * 35) % 360 
        local col = HSVToColor(hue, 1, 1) -- 100% Saturation, 100% Value
        
        self:SetColor(col)

        -- Update the trail color as well
        if IsValid(self.Trail) then
            self.Trail:SetColor(col)
        end
        
        -- Create a spark at bounce point
        local effect = EffectData()
        effect:SetOrigin(data.HitPos)
        effect:SetNormal(data.HitNormal)
        util.Effect("AR2Impact", effect)
    end
    
    function ENT:Detonate()
        if self.Exploded then return end
        self.Exploded = true
        
        local pos = self:GetPos()
        local bounces = self:GetBounces()
        local dmg = self.BaseDamage + (bounces * 25) 
        
        local effect = EffectData()
        effect:SetOrigin(pos)
        util.Effect("cball_explode", effect)
        self:EmitSound("Weapon_AR2.NPC_Reload")
        
        util.BlastDamage(self, self:GetOwner() or self, pos, 150, dmg)
        
        self:Remove()
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        
        -- Render a glowing sprite over the model
        local bounces = self:GetBounces()
        local size = 32 + (bounces * 5)
        
        -- UPDATED: Use the entity's current color (synced from server)
        -- This ensures the glow matches the RGB trail exactly.
        local col = self:GetColor()
        
        render.SetMaterial(Material("sprites/light_glow02_add"))
        render.DrawSprite(self:GetPos(), size, size, col)
    end
end