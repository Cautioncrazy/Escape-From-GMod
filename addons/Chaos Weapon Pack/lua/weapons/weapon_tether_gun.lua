SWEP.PrintName = "Tether Gun"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "Primary: Set Anchor | Secondary: Tether Object | Reload: Reset Anchor"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_crossbow.mdl"
SWEP.WorldModel = "models/weapons/w_crossbow.mdl"
SWEP.UseHands = true 

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true 
SWEP.Secondary.Delay = 0.2

function SWEP:Initialize()
    self:SetHoldType("crossbow")
end

function SWEP:Reload()
    if (not self.Owner:KeyPressed(IN_RELOAD)) then return end
    
    -- Clear Anchor logic
    if SERVER then
        self:SetNWBool("HasAnchor", false)
        self:SetNWEntity("AnchorEntity", NULL)
        self.Owner:ChatPrint("[Tether Gun] Anchor Reset.")
        self:EmitSound("Weapon_PhysCannon.Drop")
    end
end

function SWEP:PrimaryAttack()
    -- Prediction check: Run on both client and server to feel responsive, 
    -- but only server handles the networking/logic.
    
    local tr = self.Owner:GetEyeTrace()
    
    if not IsValid(tr.Entity) or tr.Entity:IsWorld() then 
        if SERVER then self:EmitSound("buttons/button10.wav") end
        return 
    end
    
    -- Set the Anchor (Networked so the client can draw the beam)
    if SERVER then
        self:SetNWBool("HasAnchor", true)
        self:SetNWEntity("AnchorEntity", tr.Entity)
        self:SetNWInt("AnchorBone", tr.PhysicsBone)
        -- Store local pos so the beam sticks to the exact spot we hit
        self:SetNWVector("AnchorPos", tr.Entity:WorldToLocal(tr.HitPos))
        
        self:EmitSound("Weapon_Crossbow.BoltFly")
        self.Owner:ChatPrint("[Tether Gun] Anchor Set! Visual Link Established.")
    end
    
    self:SetNextPrimaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)

    if CLIENT then return end
    
    -- 1. Check Anchor via Networked Vars
    if not self:GetNWBool("HasAnchor") then
        self.Owner:ChatPrint("[Tether Gun] No Anchor! Left Click an object first.")
        self:EmitSound("buttons/button10.wav")
        return
    end

    local anchorEnt = self:GetNWEntity("AnchorEntity")
    if not IsValid(anchorEnt) then return end

    -- 2. Validate Target
    local tr = self.Owner:GetEyeTrace()
    local target = tr.Entity
    
    if not IsValid(target) or target:IsWorld() then return end
    if target == anchorEnt then return end 

    -- 3. Create Constraint
    local LPos1 = self:GetNWVector("AnchorPos")
    local LPos2 = target:WorldToLocal(tr.HitPos) 
    local bone1 = self:GetNWInt("AnchorBone")
    local bone2 = tr.PhysicsBone
    
    local constant = 500  
    local damping = 5     
    local rdamping = 0
    local width = 5 -- Thicker line
    local stretchonly = false 
    
    -- VISUAL CHANGE: Use 'cable/redlaser' for a glowing red beam
    constraint.Elastic(
        anchorEnt, 
        target, 
        bone1, 
        bone2, 
        LPos1, 
        LPos2, 
        constant, 
        damping, 
        rdamping, 
        "cable/redlaser", 
        width, 
        stretchonly
    )
    
    self:EmitSound("Weapon_Crossbow.BoltHitBody") 
    
    local effect = EffectData()
    effect:SetOrigin(tr.HitPos)
    util.Effect("StunstickImpact", effect)
    
    self:SetNextSecondaryFire(CurTime() + 0.2)
end

-- CLIENT-SIDE VISUALS: The "Preview Beam"
if CLIENT then
    local laserMat = Material("cable/redlaser")
    
    -- We use PostDrawOpaqueRenderables to draw lines in the 3D world
    hook.Add("PostDrawOpaqueRenderables", "DrawTetherGunPreview", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_tether_gun" then return end
        
        -- Only draw if we have an anchor
        if not wep:GetNWBool("HasAnchor") then return end
        
        local anchorEnt = wep:GetNWEntity("AnchorEntity")
        if not IsValid(anchorEnt) then return end
        
        -- Calculate Start Position (The Anchor)
        local localPos = wep:GetNWVector("AnchorPos")
        local startPos = anchorEnt:LocalToWorld(localPos)
        
        -- Calculate End Position (The Gun)
        local endPos = ply:GetShootPos() -- Default fall back
        
        if ply:ShouldDrawLocalPlayer() then
            -- Third Person: Draw to world model attachment
            local attachment = wep:GetAttachment(1)
            if attachment then endPos = attachment.Pos end
        else
            -- First Person: Draw to viewmodel attachment
            local vm = ply:GetViewModel()
            if IsValid(vm) then
                local attachment = vm:GetAttachment(1) -- Attachment 1 is usually the muzzle
                if attachment then endPos = attachment.Pos end
            end
        end

        -- Draw the Beam
        render.SetMaterial(laserMat)
        render.DrawBeam(startPos, endPos, 4, 0, 10, Color(255, 255, 255, 255))
    end)
end