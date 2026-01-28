SWEP.PrintName = "Chaos Ice Skates"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Move to Glide | Jump to BHop | Primary: Boost | Secondary: Brake"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_fists.mdl"
SWEP.WorldModel = "" 
SWEP.UseHands = true 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1.0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.5

function SWEP:Initialize()
    self:SetHoldType("fist") 
end

function SWEP:Deploy()
    if SERVER then
        -- Friction: 1.0 is normal. 
        -- 0.05 was too slippery (impossible to accelerate).
        -- 0.2 gives a good balance of "Ice" glide but enough grip to start moving.
        self.Owner:SetFriction(0.2) 
        self.Owner:ChatPrint("[Skates] Ice Physics Enabled. Jump to preserve speed.")
    end
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end

function SWEP:Holster()
    if SERVER and IsValid(self.Owner) then
        self.Owner:SetFriction(1.0)
    end
    return true
end

function SWEP:OnRemove()
    if SERVER and IsValid(self.Owner) then
        self.Owner:SetFriction(1.0)
    end
end

-- Primary Fire: Manual Turbo Boost
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.6) -- Slightly faster cooldown
    
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK) 
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    if SERVER then
        local aim = self.Owner:GetAimVector()
        aim.z = 0 
        aim = aim:GetNormalized()
        
        -- Add velocity to existing momentum
        local currentVel = self.Owner:GetVelocity()
        self.Owner:SetVelocity(aim * 800) -- Increased boost slightly
        
        self:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1,3) .. ".wav")
    end
end

-- Secondary Fire: Emergency Brake
function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
    
    if SERVER then
        local vel = self.Owner:GetVelocity()
        self.Owner:SetVelocity(-vel * 0.5) -- Cut speed in half
        self:EmitSound("physics/metal/metal_box_scrape_smooth1.wav")
    end
end

-- HOOK: Physics Logic
hook.Add("Move", "ChaosIceSkatesMove", function(ply, mv)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_ice_skates" then return end

    -- 1. UNCAP SPEED
    -- This prevents the engine from forcefully slowing you down to "Walk Speed"
    -- whenever you jump or touch the ground, allowing you to build infinite momentum.
    mv:SetMaxSpeed(10000)
    mv:SetMaxClientSpeed(10000)

    -- 2. JUMP MOMENTUM PRESERVATION
    -- Standard Source behavior clamps speed on jump. We override that here.
    if mv:KeyPressed(IN_JUMP) and ply:IsOnGround() then
        local vel = mv:GetVelocity()
        -- Ensure we jump UP, but keep all horizontal speed
        vel.z = ply:GetJumpPower() 
        mv:SetVelocity(vel) 
    end
    
    -- NOTE: We removed the manual "Momentum Builder" code.
    -- We now rely on the Engine's native acceleration combined with the 0.2 Friction.
    -- This means WASD will accelerate you slowly (natural skating), 
    -- preventing the "instant breakneck speed" issue.
end)