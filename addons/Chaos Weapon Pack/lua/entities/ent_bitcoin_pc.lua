AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Bitcoin PC"
ENT.Author = "Senior Lua Engineer"
ENT.Category = "Chaos Weapon Pack" 
ENT.Spawnable = true
ENT.AdminOnly = false

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        
        -- Optional: Add a "Hot" glow if mining
        if self:GetNWBool("IsMining") then
            local color = Color(255, 50 + math.sin(CurTime()*10)*50, 0)
            render.SetColorMaterial()
            -- Draw a slight overlay to make it look like it's glowing hot
            render.DrawSphere(self:GetPos(), 20, 30, 30, Color(255, 100, 0, 50))
        end
    end
end

if SERVER then
    function ENT:Initialize()
        -- Classic CRT Monitor model
        self:SetModel("models/props_lab/monitor01a.mdl") 
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        
        -- Tint it Gold to represent "Bitcoin"
        self:SetColor(Color(255, 215, 0))
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
        
        self.IsMining = false
    end

    function ENT:Use(activator, caller)
        if self.IsMining then return end
        self.IsMining = true
        self:SetNWBool("IsMining", true)
        
        -- Phase 1: Startup
        self:EmitSound("ambient/machines/combine_terminal_idle4.wav")
        if IsValid(activator) then
            activator:ChatPrint("[Bitcoin PC] Miner V1.0 Starting... Hashrate climbing...")
        end
        
        -- Phase 2: Overheating (2 seconds later)
        timer.Simple(2, function()
            if not IsValid(self) then return end
            
            -- Play a heavy loop sound (sounds like aggressive fans)
            self:EmitSound("ambient/levels/labs/equipment_printer_loop1.wav")
            
            -- Make the prop shake to simulate fan vibration
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:AddAngleVelocity(Vector(100, 100, 0))
            end
            
            if IsValid(activator) then
                activator:ChatPrint("[Bitcoin PC] WARNING: GPU TEMP 105°C")
            end
        end)
        
        -- Phase 3: Meltdown (5 seconds later)
        timer.Simple(5, function()
            if not IsValid(self) then return end
            
            -- Stop the fan sound
            self:StopSound("ambient/levels/labs/equipment_printer_loop1.wav")
            
            -- Explosion Sound
            self:EmitSound("ambient/explosions/explode_4.wav")
            
            -- Ignite the prop
            self:Ignite(30) -- Burn for 30 seconds
            
            -- Visual Explosion Effect
            local effect = EffectData()
            effect:SetOrigin(self:GetPos())
            util.Effect("Explosion", effect)
            
            -- Physical Pop: Launch it into the air
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(Vector(0, 0, 6000)) -- Launch UP
                phys:AddAngleVelocity(Vector(500, 500, 500)) -- Spin wildly
            end
            
            if IsValid(activator) then
                activator:ChatPrint("[Bitcoin PC] CRITICAL FAILURE! ASSETS LIQUIDATED!")
            end
            
            -- Reset after 30 seconds (extinguish)
            timer.Simple(30, function()
                if IsValid(self) then
                    self.IsMining = false
                    self:SetNWBool("IsMining", false)
                    self:SetColor(Color(50, 50, 50)) -- Turn black/burnt
                end
            end)
        end)
    end
end