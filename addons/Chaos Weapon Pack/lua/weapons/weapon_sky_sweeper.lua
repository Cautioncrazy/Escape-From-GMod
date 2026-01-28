SWEP.PrintName = "Sky Sweeper"
SWEP.Author = "Jules"
SWEP.Instructions = "Primary: Fire Homing Missile (Locks on to Gunships/Choppers/Dropships)"
SWEP.Category = "Chaos Weapon Pack"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rpg.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = 10
SWEP.Primary.DefaultClip = 3
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.5

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = -1

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    -- Server-side Target Logic
    local target = nil
    if SERVER then
        local candidates = {}
        table.Add(candidates, ents.FindByClass("npc_helicopter"))
        table.Add(candidates, ents.FindByClass("npc_combinegunship"))
        table.Add(candidates, ents.FindByClass("npc_combinedropship"))

        local bestDist = 999999999
        local aimVec = self.Owner:GetAimVector()
        local eyePos = self.Owner:EyePos()

        for _, ent in pairs(candidates) do
            if IsValid(ent) and ent:Health() > 0 then
                local center = ent:WorldSpaceCenter()

                -- Gunships usually return an origin at their tail/base, so we try to aim for their mass
                if ent:GetClass() == "npc_combinegunship" then
                     center = ent:GetPos() + Vector(0,0,50)
                end

                -- Check if roughly in front of player
                local dir = (center - eyePos):GetNormalized()
                local dot = aimVec:Dot(dir)

                -- Field of View check (~45 degrees)
                if dot > 0.7 then
                    -- Relaxed Visibility Check:
                    -- Instead of ent:Visible() which might fail on Gunship hulls,
                    -- we do a simple trace to the center.
                    local tr = util.TraceLine({
                        start = eyePos,
                        endpos = center,
                        filter = {self.Owner, self},
                        mask = MASK_SHOT
                    })

                    -- If we hit the entity, OR if we hit nothing (sky) but the entity is huge
                    -- (Gunships often have weird hitboxes where traces pass through visual mesh)
                    -- We trust the Dot Product mainly.
                    if tr.Entity == ent or tr.Fraction > 0.99 or (tr.Entity:GetClass() == ent:GetClass()) then
                        local dist = eyePos:DistToSqr(ent:GetPos())
                        if dist < bestDist then
                            bestDist = dist
                            target = ent
                        end
                    end
                end
            end
        end
    end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self.Owner:SetAnimation(PLAYER_ATTACK1)

    self:EmitSound("Weapon_RPG.Single")

    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if CLIENT then return end

    -- Create Missile
    local missile = ents.Create("ent_projectile_homing_missile")
    if not IsValid(missile) then return end

    local eyePos = self.Owner:EyePos()
    local aimVec = self.Owner:GetAimVector()
    -- Adjust spawn position to not clip with player but be near barrel
    local spawnPos = eyePos + (aimVec * 40) + (self.Owner:GetRight() * 10) - (self.Owner:GetUp() * 5)

    missile:SetPos(spawnPos)
    missile:SetAngles(aimVec:Angle())
    missile:SetOwner(self.Owner)
    missile:Spawn()

    -- Assign Target
    if IsValid(target) then
        missile:SetTarget(target)
        self.Owner:ChatPrint("[Sky Sweeper] Locked on: " .. target:GetClass())
        self:EmitSound("weapons/rpg/shotdown.wav")
    else
        self.Owner:ChatPrint("[Sky Sweeper] Firing Dumb Missile (No Target)")
    end

    -- Initial Velocity
    local phys = missile:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(aimVec * 1500)
    end
end

function SWEP:SecondaryAttack()
    -- No secondary attack defined
end