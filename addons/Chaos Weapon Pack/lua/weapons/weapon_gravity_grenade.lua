SWEP.PrintName = "Gravity Grenade Launcher"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Launch Gravity Grenade"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 5
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 2.0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1.0

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    self:EmitSound("Weapon_RPG.Single")
    
    self:TakePrimaryAmmo(1)

    if CLIENT then return end

    local ent = ents.Create("ent_gravity_grenade")
    if not IsValid(ent) then return end

    local eyePos = self.Owner:GetShootPos()
    local aimVec = self.Owner:GetAimVector()
    local spawnPos = eyePos + (aimVec * 50) + (self.Owner:GetRight() * 10) - (self.Owner:GetUp() * 5)

    ent:SetPos(spawnPos)
    ent:SetAngles(self.Owner:EyeAngles())
    ent:SetOwner(self.Owner)
    ent:Spawn()

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:ApplyForceCenter(aimVec * 2000 + Vector(0,0,200)) -- slight arc
        phys:AddAngleVelocity(VectorRand() * 500)
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
end