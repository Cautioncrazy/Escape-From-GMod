AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Homing Missile"
ENT.Author = "Jules"
ENT.Spawnable = false

local FLIGHT_MODEL = "models/weapons/w_missile.mdl"

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(FLIGHT_MODEL)

        -- Use Sphere physics to guarantee a valid physics object even if the model is non-solid
        self:PhysicsInitSphere(4, "metal")
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableGravity(false)
            phys:EnableDrag(false)
            phys:SetMass(1) -- Light mass for easier movement
        end

        -- Smoke Trail
        util.SpriteTrail(self, 0, Color(220, 220, 220), false, 15, 1, 0.5, 1 / (15 + 1) * 0.5, "trails/smoke")

        self.Speed = 2000
        self.Target = nil
        self.SpawnTime = CurTime()
    end

    function ENT:SetTarget(ent)
        self.Target = ent
    end

    function ENT:Think()
        local phys = self:GetPhysicsObject()
        if not IsValid(phys) then return end

        local desiredDir = phys:GetVelocity():GetNormalized()

        -- Fallback if velocity is zero (e.g. just spawned)
        if desiredDir:LengthSqr() < 0.1 then
            desiredDir = self:GetForward()
        end

        -- Homing Logic
        if IsValid(self.Target) and self.Target:Health() > 0 then
            local targetPos = self.Target:WorldSpaceCenter()

            -- Combine Gunships have an odd origin, aim slightly higher/center
            if self.Target:GetClass() == "npc_combinegunship" then
                 targetPos = self.Target:GetPos()
            end

            local myPos = self:GetPos()
            local dist = myPos:DistToSqr(targetPos)
            local dirToTarget = (targetPos - myPos):GetNormalized()

            -- Turn towards target (Aggressive tracking)
            desiredDir = LerpVector(0.2, desiredDir, dirToTarget):GetNormalized()

            -- Proximity Detonation (Fix for circling behavior)
            -- 250,000 = 500^2 units
            if (CurTime() - self.SpawnTime > 2.0) and (dist < 250000) then
                self:Explode(self.Target:WorldSpaceCenter(), self.Target)
                return
            end
        end

        -- Update Velocity and Rotation
        local newVel = desiredDir * self.Speed
        phys:SetVelocity(newVel)
        phys:SetAngles(desiredDir:Angle())

        self:NextThink(CurTime())
        return true
    end

    function ENT:Explode(pos, hitEnt)
        if not IsValid(self) then return end

        -- AR2 Alt-Fire "Disintegration" Effect
        local effectData = EffectData()
        effectData:SetOrigin(pos)
        effectData:SetMagnitude(5)
        effectData:SetScale(2)
        util.Effect("AR2Explosion", effectData)

        self:EmitSound("Weapon_AR2.NPC_Double")

        local attacker = self:GetOwner()
        if not IsValid(attacker) then attacker = self end

        if IsValid(hitEnt) then
             local class = hitEnt:GetClass()

             -- Special Handling for Air Units to ensure "Disintegration" / One-Shot
             if class == "npc_helicopter" or class == "npc_combinegunship" or class == "npc_combinedropship" then

                 -- 1. Apply Massive Damage with AIRBOAT + DISSOLVE type
                 -- DISSOLVE hints the engine to trigger the disintegration death effect
                 local dmg = DamageInfo()
                 dmg:SetDamage(10000)
                 dmg:SetAttacker(attacker)
                 dmg:SetInflictor(self)
                 -- Bitwise OR to combine flags
                 dmg:SetDamageType(bit.bor(DMG_AIRBOAT, DMG_DISSOLVE))
                 dmg:SetDamagePosition(pos)
                 hitEnt:TakeDamageInfo(dmg)

                 -- 2. Force Self-Destruct inputs (Engine specific)
                 -- This triggers the visual explosion/crash sequence
                 hitEnt:Fire("SelfDestruct")

                 -- 3. Explicitly kill the entity if it survived the initial blow
                 -- Wait a tiny fraction (0.1) so the physics effects register, then force remove if still alive
                 -- Or set health immediately to 0 to trigger OnDeath hooks properly
                 if hitEnt:Health() > 0 then
                    hitEnt:SetHealth(0)
                 end

                 -- 4. Failsafe Removal
                 -- If the death animation (spinning out) gets stuck or isn't desired (instant kill wanted),
                 -- we force a Kill input shortly after.
                 hitEnt:Fire("Kill", "", 0.5)
             else
                 -- Normal Damage for everything else
                 local dmg = DamageInfo()
                 dmg:SetDamage(5000)
                 dmg:SetAttacker(attacker)
                 dmg:SetInflictor(self)
                 dmg:SetDamageType(DMG_DISSOLVE) -- Disintegrate effect for normal props/NPCs
                 dmg:SetDamagePosition(pos)
                 hitEnt:TakeDamageInfo(dmg)
             end
        end

        -- Splash Damage
        util.BlastDamage(self, attacker, pos, 300, 500)

        self:Remove()
    end

    function ENT:PhysicsCollide(data, phys)
        self:Explode(data.HitPos, data.HitEntity)
    end
end