SWEP.PrintName = "Cryo-Blaster"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary (Hold): Freeze Targets | Secondary: Shatter Frozen Objects"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

-- Using the SMG model for a tactical tool look
SWEP.ViewModel = "models/weapons/c_smg1.mdl"
SWEP.WorldModel = "models/weapons/w_smg1.mdl"
SWEP.UseHands = true 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.05 -- Continuous beam tick

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1.0

function SWEP:Initialize()
    self:SetHoldType("smg")
    self.BeamSound = CreateSound(self, "ambient/energy/force_field_loop1.wav")
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    
    local tr = self.Owner:GetEyeTrace()
    local ent = tr.Entity
    
    -- 1. Audio / Visuals
    self.BeamSound:Play()
    self.BeamSound:ChangePitch(100 + math.sin(CurTime()*10)*10) -- Warbling pitch
    
    local effect = EffectData()
    effect:SetStart(self.Owner:GetShootPos())
    effect:SetOrigin(tr.HitPos)
    effect:SetEntity(self)
    effect:SetAttachment(1) -- Muzzle
    util.Effect("ToolTracer", effect)
    
    -- 2. Range Check
    if self.Owner:GetPos():Distance(tr.HitPos) > 800 then return end

    -- 3. Freeze Logic
    if IsValid(ent) then
        if not ent.IsFrozenState then
            ent.IsFrozenState = true
            
            -- Visual "Ice" Look
            ent:SetMaterial("models/shiny") 
            ent:SetColor(Color(0, 255, 255))
            self:EmitSound("physics/glass/glass_impact_bullet4.wav")
            
            -- Logic: NPCs
            if ent:IsNPC() then
                ent:AddFlags(FL_FROZEN) -- Stops animation and movement
                ent:SetSchedule(SCHED_NPC_FREEZE)
            
            -- Logic: Players
            elseif ent:IsPlayer() then
                ent:Freeze(true)
                ent:ChatPrint("[Cryo] You have been frozen!")
            
            -- Logic: Props (Physics)
            elseif IsValid(ent:GetPhysicsObject()) then
                ent:GetPhysicsObject():EnableMotion(false) -- Freeze in mid-air
            end
        end
    end
    
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    -- Stop sound if we let go of trigger
    if not self.Owner:KeyDown(IN_ATTACK) then
        self.BeamSound:Stop()
    end
end

function SWEP:Holster()
    self.BeamSound:Stop()
    return true
end

function SWEP:SecondaryAttack()
    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    if CLIENT then return end
    
    local tr = self.Owner:GetEyeTrace()
    local impactEnt = tr.Entity
    local hitPos = tr.HitPos
    
    -- "Shatter" Sound
    self:EmitSound("Weapon_Crossbow.BoltFly")
    
    -- Find all frozen things near the impact point (Chain Reaction)
    local targets = ents.FindInSphere(hitPos, 300)
    local shatteredCount = 0
    
    for _, ent in pairs(targets) do
        if IsValid(ent) and ent.IsFrozenState then
            shatteredCount = shatteredCount + 1
            
            -- 1. Unfreeze state logic first
            ent.IsFrozenState = false
            ent:SetMaterial("")
            ent:SetColor(Color(255, 255, 255))
            
            -- 2. Effects
            self:EmitSound("physics/glass/glass_cup_break1.wav")
            local glass = EffectData()
            glass:SetOrigin(ent:GetPos())
            util.Effect("GlassImpact", glass)
            
            -- 3. Damage / Destroy
            if ent:IsNPC() or ent:IsPlayer() then
                -- Deal massive damage
                ent:TakeDamage(5000, self.Owner, self)
                
                if ent:IsNPC() then ent:RemoveFlags(FL_FROZEN) end
                if ent:IsPlayer() then ent:Freeze(false) end
                
            elseif IsValid(ent:GetPhysicsObject()) then
                -- Props: Unfreeze physics and throw them
                ent:GetPhysicsObject():EnableMotion(true)
                ent:GetPhysicsObject():ApplyForceCenter(Vector(0,0,1000))
                ent:TakeDamage(100, self.Owner, self) -- Trigger breakable props
            end
        end
    end
    
    if shatteredCount > 0 then
        self.Owner:ChatPrint("[Cryo] Shattered " .. shatteredCount .. " targets!")
    end

    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
end