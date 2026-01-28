SWEP.PrintName = "Quantum Dislocator"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Teleport Target to Random Location"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_sniper.mdl" -- Requires CSS, fallback to crossbow if needed
SWEP.WorldModel = "models/weapons/w_sniper.mdl"
SWEP.UseHands = true

-- If CSS is not mounted, use HL2 crossbow
if not util.IsValidModel(SWEP.ViewModel) then
    SWEP.ViewModel = "models/weapons/c_crossbow.mdl"
    SWEP.WorldModel = "models/weapons/w_crossbow.mdl"
end

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 10
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 3.0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.5

function SWEP:Initialize()
    self:SetHoldType("ar2")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    
    self:EmitSound("Weapon_Sniper.Fire") -- CSS sound, or "Weapon_Crossbow.BoltFly"
    self:EmitSound("ambient/machines/teleport1.wav")
    
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self:TakePrimaryAmmo(1)
    
    if CLIENT then return end
    
    local tr = self.Owner:GetEyeTrace()
    local ent = tr.Entity
    
    -- Beam Effect
    local effect = EffectData()
    effect:SetStart(self.Owner:GetShootPos())
    effect:SetOrigin(tr.HitPos)
    effect:SetEntity(self)
    util.Effect("ToolTracer", effect)
    
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or IsValid(ent:GetPhysicsObject())) then
        -- Find a random nav area or spawn point
        local spawns = ents.FindByClass("info_player_start")
        local dest = Vector(0,0,0)
        
        if #spawns > 0 then
            local randomSpawn = spawns[math.random(#spawns)]
            dest = randomSpawn:GetPos()
        else
            -- Fallback: Random offset from current pos
            dest = ent:GetPos() + Vector(math.random(-2000, 2000), math.random(-2000, 2000), 500)
        end
        
        -- Teleport Effect at OLD position
        local eff1 = EffectData()
        effect:SetOrigin(ent:GetPos())
        util.Effect("cball_explode", eff1)
        
        -- Move
        ent:SetPos(dest)
        
        -- Teleport Effect at NEW position
        local eff2 = EffectData()
        effect:SetOrigin(dest)
        util.Effect("cball_explode", eff2)
        
        if ent:IsPlayer() then
            ent:ChatPrint("You were dislocated!")
        end
    end
    
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:SecondaryAttack()
    -- Scope Logic (Simple FOV change)
    if CLIENT then
        if self.Owner:GetFOV() < 90 then
            self.Owner:SetFOV(0, 0.3)
        else
            self.Owner:SetFOV(20, 0.3)
        end
    end
end