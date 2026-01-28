-- SWEP (Scripted Weapon) Metadata
SWEP.PrintName = "Crowbar Cannon"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Launch Crowbar | Secondary: Special Round | R: Toggle Mode"
SWEP.Category = "Chaos Weapon Pack" -- UPDATED: Changed from 'Experimental Weaponry'

SWEP.Spawnable = true
SWEP.AdminOnly = false

-- View Models (What you see)
SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true

-- Stats
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 1.0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Delay = 2.0

-- Physics Constants
local LAUNCH_FORCE = 50000

function SWEP:Initialize()
    self:SetHoldType("melee")
    self.EMPMode = false
    self.NextReloadTime = 0
end

-- NEW: Reload function handles Mode Switching
function SWEP:Reload()
    if CurTime() < self.NextReloadTime then return end
    self.NextReloadTime = CurTime() + 0.5

    self.EMPMode = not self.EMPMode

    if SERVER then
        if self.EMPMode then
            self.Owner:ChatPrint("[Crowbar Cannon] Switched to EMP Mode (Anti-Mech)")
            self:EmitSound("Weapon_StunStick.Activate")
        else
            self.Owner:ChatPrint("[Crowbar Cannon] Switched to Explosive Mode (High Damage)")
            self:EmitSound("Weapon_Pistol.Reload")
        end
    end
end

function SWEP:FireCrowbar(isSpecial)
    self:SendWeaponAnim(ACT_VM_MISSCENTER)
    self.Owner:SetAnimation(PLAYER_ATTACK1)

    self:EmitSound("Weapon_Crowbar.Single")

    if CLIENT then return end

    local projectile = ents.Create("ent_projectile_crowbar")
    if not IsValid(projectile) then return end

    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    local spawnPos = eyePos + (aimVec * 40)

    projectile:SetPos(spawnPos)
    projectile:SetAngles(self.Owner:EyeAngles())
    projectile:SetOwner(self.Owner)

    if isSpecial then
        if self.EMPMode then
            projectile:SetEMP(true)
            projectile:SetColor(Color(0, 255, 255))
        else
            projectile:SetExplosive(true)
            projectile:SetColor(Color(255, 100, 100))
        end
    end

    projectile:Spawn()

    local phys = projectile:GetPhysicsObject()
    if IsValid(phys) then
        phys:ApplyForceCenter(aimVec * LAUNCH_FORCE)
        phys:AddAngleVelocity(Vector(0, 500, 0))
    end
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:FireCrowbar(false)
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
    self:FireCrowbar(true)
end