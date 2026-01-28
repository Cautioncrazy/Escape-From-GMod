AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Black Hole Singularity"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

local CORE_MODEL = "models/props_junk/PopCan01a.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Charge")
    self:NetworkVar("Bool", 0, "WhiteHole") -- New State: False = Black Hole, True = White Hole
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(CORE_MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        self:DrawShadow(false)
        
        -- Fix: Set collision group to DEBRIS so it doesn't physically block props/NPCs from entering the center
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableGravity(false) 
            phys:SetMass(100)
            phys:SetDamping(0, 0)
        end
        
        local charge = self:GetCharge()
        self.Radius = 200 + (charge * 800) 
        self.Force = 500 + (charge * 4500)
        self.LifeTime = CurTime() + 3 + (charge * 5)
    end

    function ENT:Think()
        if CurTime() > self.LifeTime then
            self:Remove()
            return
        end
        
        local pos = self:GetPos()
        local entities = ents.FindInSphere(pos, self.Radius)
        local isWhiteHole = self:GetWhiteHole()
        
        for _, v in pairs(entities) do
            if IsValid(v) and v ~= self then
                -- Protection: Don't affect the owner for 2 seconds after firing
                if v == self:GetOwner() and (self.LifeTime - CurTime()) > 2 then continue end
                
                local vPos = v:GetPos()
                local dist = pos:Distance(vPos)
                local phys = v:GetPhysicsObject()
                
                -- DIRECTION: Vector from Object -> Hole
                local direction = (pos - vPos):GetNormalized()
                
                -- LOGIC SPLIT: PULL vs PUSH
                local forceDir = direction -- Default Pull
                if isWhiteHole then
                    forceDir = direction * -1 -- Invert for Push (Repulsion)
                end

                -- APPLY FORCES (Props)
                if IsValid(phys) then
                    local strength = self.Force * (1 - (dist / self.Radius))
                    phys:ApplyForceCenter(forceDir * strength)
                end
                
                -- PLAYERS & NPCS (Move via velocity)
                if v:IsPlayer() or v:IsNPC() then
                    local strength = (self.Force * 0.1) * (1 - (dist / self.Radius))
                    
                    -- NEW: "Fake Ragdoll" Logic
                    -- If we don't do this, NPCs will try to run/walk against the force.
                    -- By setting their GroundEntity to NULL, we force them into their "Airborne/Falling" animation.
                    if v:IsNPC() and v:IsOnGround() then
                        v:SetGroundEntity(NULL)
                        -- Add a tiny upward pop to ensure they unstick from the floor
                        v:SetVelocity(Vector(0,0,100))
                    end
                    
                    v:SetVelocity(forceDir * strength)
                end
                
                -- EVENT HORIZON LOGIC (Only for Black Holes)
                if not isWhiteHole then
                    -- Fix: Use NearestPoint logic.
                    -- Previous code checked center-to-center distance, which failed for large objects (dumpsters, cars).
                    -- Now we check if ANY part of the object collision box is touching the event horizon.
                    local nearest = v:NearestPoint(pos)
                    local touchDist = pos:Distance(nearest)
                    
                    if touchDist < 100 then -- Increased threshold + NearestPoint check
                        self:HandleEventHorizon(v)
                    end
                end
            end
        end
        
        self:SetAngles(self:GetAngles() + Angle(0, 5, 0))
        self:NextThink(CurTime())
        return true
    end

    -- Handles Teleportation or Destruction
    function ENT:HandleEventHorizon(victim)
        -- 1. Look for a matching White Hole
        local whiteHole = nil
        local allHoles = ents.FindByClass("ent_projectile_blackhole")
        
        for _, hole in pairs(allHoles) do
            if hole:GetWhiteHole() and hole:GetOwner() == self:GetOwner() then
                whiteHole = hole
                break -- Found one!
            end
        end

        -- 2. Teleport or Destroy
        if IsValid(whiteHole) then
            -- TELEPORT
            local vel = victim:GetVelocity()
            local exitPoint = whiteHole:GetPos() + (vel:GetNormalized() * 100) -- Spit out slightly in front of movement
            
            -- Prevent getting sucked back in immediately (optional logic, usually momentum is enough)
            
            victim:SetPos(exitPoint)
            
            -- Wake physics
            local phys = victim:GetPhysicsObject()
            if IsValid(phys) then
                phys:Wake()
                phys:SetVelocity(vel) -- Maintain trajectory
            end
            
            -- Sound Effect
            whiteHole:EmitSound("Weapon_AR2.NPC_Reload")
        else
            -- DESTROY (No Exit Found)
            local dmg = DamageInfo()
            dmg:SetDamage(1000)
            dmg:SetAttacker(self:GetOwner() or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_DISSOLVE)
            victim:TakeDamageInfo(dmg)
        end
    end
end

if CLIENT then
    local matRefract = Material("sprites/heatwave")

    function ENT:Draw()
        local charge = self:GetCharge()
        local isWhiteHole = self:GetWhiteHole()
        
        local size = (50 + (charge * 100)) + math.sin(CurTime() * 10) * 5
        
        -- 1. Refraction
        render.SetMaterial(matRefract)
        render.UpdateRefractTexture()
        matRefract:SetFloat("$refractamount", 0.1 + (charge * 0.2)) 
        render.DrawSprite(self:GetPos(), size * 2.5, size * 2.5, Color(255, 255, 255, 255))
        
        -- 2. Core (3D Sphere)
        render.SetColorMaterial()
        
        local coreColor = Color(0, 0, 0, 255) -- Default Black
        if isWhiteHole then
            coreColor = Color(255, 255, 255, 255) -- White for White Hole
        end

        render.DrawSphere(self:GetPos(), size * 0.5, 30, 30, coreColor)
    end
end