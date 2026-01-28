SWEP.PrintName = "Singularity Rifle"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary (Hold): Black Hole | Secondary (Hold): White Hole (Exit Point)"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

-- Use the Pulse Rifle (AR2) model
SWEP.ViewModel = "models/weapons/c_irifle.mdl"
SWEP.WorldModel = "models/weapons/w_irifle.mdl"
SWEP.UseHands = true 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1.0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1.0

function SWEP:Initialize()
    self:SetHoldType("ar2")
    self.IsCharging = false
    self.ChargeStart = 0
    self.ChargeMode = 0 -- 0 = Black Hole, 1 = White Hole
    self.MaxChargeTime = 3.0 
    
    self.ChargeSound = CreateSound(self, "Weapon_PhysCannon.Charge")
end

-- Generic Charge Function
function SWEP:StartCharge(mode)
    if self.IsCharging then return end
    
    self.IsCharging = true
    self.ChargeStart = CurTime()
    self.ChargeMode = mode
    
    if CLIENT then return end
    self.ChargeSound:Play()
end

function SWEP:PrimaryAttack()
    self:StartCharge(0)
end

function SWEP:SecondaryAttack()
    self:StartCharge(1)
end

function SWEP:Think()
    if self.IsCharging then
        -- Calculate charge percentage (0.0 to 1.0)
        local chargeTime = CurTime() - self.ChargeStart
        local charge = math.Clamp(chargeTime / self.MaxChargeTime, 0, 1)

        if CLIENT and charge > 0.2 then
            local shake = charge * 2
            util.ScreenShake(self.Owner:GetPos(), shake, 5, 0.1, 100)
        end
        
        -- Check for release (Primary or Secondary key)
        local released = false
        if self.ChargeMode == 0 and not self.Owner:KeyDown(IN_ATTACK) then released = true end
        if self.ChargeMode == 1 and not self.Owner:KeyDown(IN_ATTACK2) then released = true end
        
        if released then
            self:FireSingularity(charge, self.ChargeMode == 1)
            self.IsCharging = false
            self.ChargeSound:Stop()
        end
    end
end

function SWEP:Holster()
    if self.ChargeSound then self.ChargeSound:Stop() end
    self.IsCharging = false
    return true
end

function SWEP:FireSingularity(charge, isWhiteHole)
    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    local pitch = 150 - (charge * 100)
    if isWhiteHole then pitch = 150 + (charge * 50) end -- Higher pitch for White Hole
    
    self:EmitSound("Weapon_AR2.AltFire", 100, pitch)
    
    if CLIENT then return end

    local ent = ents.Create("ent_projectile_blackhole")
    if not IsValid(ent) then return end
    
    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    local spawnPos = eyePos + (aimVec * 50)

    ent:SetPos(spawnPos)
    ent:SetAngles(self.Owner:EyeAngles())
    ent:SetOwner(self.Owner)
    
    ent:SetCharge(charge)
    ent:SetWhiteHole(isWhiteHole) -- Tell the entity what type it is
    
    ent:Spawn()
    
    -- OVERRIDE DURATION: Make it last longer
    -- Base: 8 seconds (was 3), Charge adds up to 12 seconds (was 5) -> Max 20s
    ent.LifeTime = CurTime() + 8 + (charge * 12)
    
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:ApplyForceCenter(aimVec * 1500)
    end
    
    local cd = CurTime() + 1.0
    self:SetNextPrimaryFire(cd)
    self:SetNextSecondaryFire(cd)
end