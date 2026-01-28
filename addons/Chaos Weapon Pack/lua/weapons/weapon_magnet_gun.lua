SWEP.PrintName = "Magnetic Polarity Emitter"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Launch Magnet | Secondary: Demagnetize (Explode)"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

-- Using the Super Gravity Gun (Blue) model
SWEP.ViewModel = "models/weapons/c_superphyscannon.mdl"
SWEP.WorldModel = "models/weapons/w_physics.mdl"
SWEP.UseHands = true 

-- Blue skin for world model
function SWEP:Initialize()
    self:SetHoldType("physgun")
    if CLIENT then
        -- Force world model to skin 1 (Blue) if possible, though physics gun skinning is tricky on world models
        self:SetSkin(1)
    end
end

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.8

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.5

function SWEP:PrimaryAttack()
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    
    self:EmitSound("Weapon_MegaPhysCannon.Launch")

    if CLIENT then return end

    local ent = ents.Create("ent_magnet_core")
    if not IsValid(ent) then return end
    
    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    local spawnPos = eyePos + (aimVec * 50)

    ent:SetPos(spawnPos)
    ent:SetAngles(self.Owner:EyeAngles())
    ent:SetOwner(self.Owner)
    ent:Spawn()
    
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:ApplyForceCenter(aimVec * 1500)
        phys:AddAngleVelocity(VectorRand() * 200)
    end
    
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    if SERVER then
        local magnets = ents.FindByClass("ent_magnet_core")
        local count = 0
        for _, mag in pairs(magnets) do
            if mag:GetOwner() == self.Owner then
                mag:Detonate()
                count = count + 1
            end
        end
        
        if count > 0 then
            self:EmitSound("Weapon_MegaPhysCannon.Drop")
            self.Owner:ChatPrint("[Magnet] Demagnetized " .. count .. " cores.")
        else
            self:EmitSound("buttons/button10.wav")
        end
    end
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)
end