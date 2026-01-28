SWEP.PrintName = "The Junk Jet"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Launch Trash | Secondary: Launch Heavy Objects"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

-- Using the RPG model for that "Heavy Launcher" feel
SWEP.ViewModel = "models/weapons/c_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rpg.mdl"
SWEP.UseHands = true 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 2.0

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:FireJunk(isHeavy)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    if isHeavy then
        self:EmitSound("Weapon_RPG.Single")
        -- Add a heavy "heave" sound
        self:EmitSound("physics/metal/metal_box_impact_hard3.wav")
    else
        self:EmitSound("Weapon_GravityGun.Single")
    end

    if CLIENT then return end

    local ent = ents.Create("ent_projectile_junk")
    if not IsValid(ent) then return end
    
    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    
    -- Spawn further out if heavy so the dumpster doesn't kill us instantly
    local offset = 60
    if isHeavy then offset = 100 end
    
    local spawnPos = eyePos + (aimVec * offset)

    ent:SetPos(spawnPos)
    ent:SetAngles(self.Owner:EyeAngles())
    ent:SetOwner(self.Owner)
    
    -- CONFIGURATION
    ent:SetHeavy(isHeavy)
    
    ent:Spawn()
    
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        local force = 2000
        if isHeavy then force = 3000 end -- Needs more oomph to move a dumpster
        
        phys:ApplyForceCenter(aimVec * force * phys:GetMass())
        phys:AddAngleVelocity(VectorRand() * 500) -- Random spin
    end
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:FireJunk(false)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
    self:FireJunk(true)
end