SWEP.PrintName = "Napalm Sprayer"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary (Hold): Spray Fire"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_smg1.mdl" -- Placeholder for a flamethrower
SWEP.WorldModel = "models/weapons/w_smg1.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.05

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

function SWEP:Initialize()
    self:SetHoldType("smg")
    self.LoopSound = CreateSound(self, "ambient/fire/fire_big_loop1.wav")
end

function SWEP:PrimaryAttack()
    if CLIENT then return end
    
    -- Visuals: Launch fire entities instead of just particles for persistent fire
    local ent = ents.Create("ent_napalm_glob")
    if IsValid(ent) then
        local aim = self.Owner:GetAimVector()
        local pos = self.Owner:GetShootPos() + (aim * 40) + (self.Owner:GetRight() * 5) - (self.Owner:GetUp() * 5)
        
        ent:SetPos(pos)
        ent:SetOwner(self.Owner)
        ent:Spawn()
        
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(aim * 1500 + VectorRand() * 100) -- Spray spread
        end
    end
    
    if not self.LoopSound:IsPlaying() then
        self.LoopSound:Play()
    end
    
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:Think()
    if not self.Owner:KeyDown(IN_ATTACK) then
        self.LoopSound:Stop()
    end
end

function SWEP:Holster()
    self.LoopSound:Stop()
    return true
end

function SWEP:OnRemove()
    self.LoopSound:Stop()
end