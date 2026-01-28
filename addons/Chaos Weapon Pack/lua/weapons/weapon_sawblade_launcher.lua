SWEP.PrintName = "Sawblade Slinger"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Launch Sawblade | Secondary: Super Heated Blade"
SWEP.Category = "Chaos Weapon Pack" 

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_physcannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"
SWEP.UseHands = true 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.8

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1.5

local LAUNCH_FORCE = 3000 

function SWEP:Initialize()
    self:SetHoldType("physgun")
end

function SWEP:FireSawblade(isHeated)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound("Weapon_PhysCannon.Launch")

    if CLIENT then return end

    local saw = ents.Create("ent_projectile_sawblade")
    if not IsValid(saw) then return end

    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    local spawnPos = eyePos + (aimVec * 60) 

    saw:SetPos(spawnPos)
    saw:SetAngles(Angle(0, self.Owner:EyeAngles().y, 0))
    saw:SetOwner(self.Owner)

    if isHeated then
        saw:SetHeated(true)
    end

    saw:Spawn()

    local phys = saw:GetPhysicsObject()
    if IsValid(phys) then
        phys:ApplyForceCenter(aimVec * LAUNCH_FORCE * phys:GetMass())
        phys:AddAngleVelocity(Vector(0, 0, 2000)) 
    end
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:FireSawblade(false)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
    self:FireSawblade(true)
end