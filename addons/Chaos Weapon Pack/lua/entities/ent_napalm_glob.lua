AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Napalm Glob"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/rock001a.mdl") -- Tiny rock as core
        self:SetMaterial("models/debug/debugwhite")
        self:SetColor(Color(255, 100, 0))
        self:SetModelScale(0.2)
        
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(1)
            phys:EnableGravity(true)
        end
        
        -- Start fire immediately
        self:Ignite(10, 50) -- Burn for 10 seconds, radius 50
        
        -- Remove quickly if it doesn't hit anything
        SafeRemoveEntityDelayed(self, 10)
    end

    function ENT:PhysicsCollide(data, phys)
        -- Stick to world or ignite entity
        local hitEnt = data.HitEntity
        
        if IsValid(hitEnt) and not hitEnt:IsWorld() then
            hitEnt:Ignite(10)
            self:Remove() -- Consumed by the target
        else
            -- Hit world: Stick and burn
            self:SetMoveType(MOVETYPE_NONE)
            -- Create a fire patch
            local fire = ents.Create("env_fire")
            fire:SetPos(data.HitPos)
            fire:SetKeyValue("health", "10") -- Duration roughly
            fire:SetKeyValue("firesize", "64")
            fire:SetKeyValue("fireattack", "2")
            fire:SetKeyValue("damagescale", "1.0")
            fire:SetKeyValue("startdisabled", "0")
            fire:SetKeyValue("flags", "128") -- 128 = Delete when out
            fire:Spawn()
            fire:Fire("StartFire", "", 0)
            
            self:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        -- Don't draw model, just draw fire particle
        -- self:DrawModel()
        
        -- Simple particle emitter could go here for better visuals
        -- But self:Ignite() handles the basic fire effect automatically
    end
end