SWEP.PrintName = "Kinetic Ricochet Rifle"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Fire Bouncing Round | Secondary: Detonate All Rounds"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

-- Using the .357 Revolver model for a high-power feel
SWEP.ViewModel = "models/weapons/c_357.mdl"
SWEP.WorldModel = "models/weapons/w_357.mdl"
SWEP.UseHands = true 

SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 12
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1.0

function SWEP:Initialize()
    self:SetHoldType("revolver")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    -- Play a laser-like sound
    self:EmitSound("Weapon_357.Single")
    self:EmitSound("ambient/energy/zap1.wav", 75, 150)
    
    -- Recoil
    self.Owner:ViewPunch(Angle(-2, 0, 0))
    self:TakePrimaryAmmo(1)

    if CLIENT then return end

    local ent = ents.Create("ent_projectile_bouncy")
    if not IsValid(ent) then return end
    
    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    local spawnPos = eyePos + (aimVec * 40) - (self.Owner:GetRight() * 5) -- Adjust spawn to match gun barrel

    ent:SetPos(spawnPos)
    ent:SetAngles(self.Owner:EyeAngles())
    ent:SetOwner(self.Owner)
    ent:Spawn()
    
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        -- Initial speed is fast, but it gets faster!
        phys:ApplyForceCenter(aimVec * 2000)
        phys:AddAngleVelocity(Vector(500, 0, 0))
    end
    
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Detonate command
    if SERVER then
        local bouncyBalls = ents.FindByClass("ent_projectile_bouncy")
        local count = 0
        for _, ball in pairs(bouncyBalls) do
            if ball:GetOwner() == self.Owner then
                ball:Detonate()
                count = count + 1
            end
        end
        
        if count > 0 then
            self:EmitSound("buttons/button3.wav")
            self.Owner:ChatPrint("[Ricochet] Detonated " .. count .. " active rounds.")
        else
            self:EmitSound("buttons/button10.wav")
        end
    end
    self:SetNextSecondaryFire(CurTime() + 1.0)
end