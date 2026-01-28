AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Supply Crate Roulette"
ENT.Author = "Senior Lua Engineer"
ENT.Category = "Chaos Weapon Pack"
ENT.Spawnable = true
ENT.AdminOnly = false

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/items/item_item_crate.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
        
        self.IsSpinning = false
    end

    function ENT:Use(activator, caller)
        if self.IsSpinning then return end
        self.IsSpinning = true
        
        -- Visual/Audio Feedback of "Rolling"
        self:EmitSound("ambient/levels/labs/coinslot1.wav")
        activator:ChatPrint("[Roulette] Rolling the dice...")
        
        -- Shake slightly
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:AddAngleVelocity(Vector(0, 0, 100))
        end
        
        -- Delay for the result
        timer.Simple(2, function()
            if not IsValid(self) then return end
            self:TriggerRandomOutcome(activator)
        end)
    end

    function ENT:TriggerRandomOutcome(ply)
        local roll = math.random(1, 100)
        
        local pos = self:GetPos() + Vector(0,0,20) -- Spawn things slightly above
        
        -- 1. JACKPOT (Watermelon Shower) - 10% Chance
        if roll <= 10 then
            self:EmitSound("garrysmod/save_load1.wav")
            ply:ChatPrint("[Roulette] JACKPOT! MELON PARTY!")
            
            for i=1, 20 do
                local melon = ents.Create("prop_physics")
                melon:SetModel("models/props_junk/watermelon01.mdl")
                melon:SetPos(pos + VectorRand() * 20)
                melon:Spawn()
                local phys = melon:GetPhysicsObject()
                if IsValid(phys) then phys:ApplyForceCenter(Vector(0,0,300) + VectorRand()*100) end
            end
            self:Remove()
            
        -- 2. TRAP (Manhacks) - 20% Chance
        elseif roll <= 30 then
            self:EmitSound("npc/manhack/grind_flesh1.wav")
            ply:ChatPrint("[Roulette] UH OH! MANHACKS!")
            
            for i=1, 3 do
                local npc = ents.Create("npc_manhack")
                npc:SetPos(pos + Vector(math.random(-20,20), math.random(-20,20), 20))
                npc:Spawn()
                npc:Activate()
                -- Make them hate the player immediately
                if IsValid(ply) then
                    npc:AddEntityRelationship(ply, D_HT, 99)
                    npc:SetEnemy(ply)
                end
            end
            
            -- Break the crate
            self:GibBreakClient(Vector(0,0,10))
            self:Remove()

        -- 3. WEAPON DROP (Chaos Pack) - 20% Chance
        elseif roll <= 50 then
            self:EmitSound("items/ammo_pickup.wav")
            ply:ChatPrint("[Roulette] Weapon Acquired!")
            
            local weapons = {
                "weapon_crowbar_cannon",
                "weapon_sawblade_launcher",
                "weapon_blackhole_gun",
                "weapon_cryo_blaster",
                "weapon_ricochet_rifle",
                "weapon_prop_cannon",
                "weapon_magnet_gun",
                "weapon_ice_skates"
            }
            local chosen = weapons[math.random(#weapons)]
            
            local wep = ents.Create(chosen)
            if IsValid(wep) then
                wep:SetPos(pos)
                wep:Spawn()
            end
            self:Remove()

        -- 4. SUPPLIES (Health/Battery) - 30% Chance
        elseif roll <= 80 then
            self:EmitSound("items/smallmedkit1.wav")
            ply:ChatPrint("[Roulette] Survival Supplies.")
            
            local ent = ents.Create("item_healthkit")
            ent:SetPos(pos)
            ent:Spawn()
            
            local ent2 = ents.Create("item_battery")
            ent2:SetPos(pos + Vector(10,0,0))
            ent2:Spawn()
            
            self:Remove()

        -- 5. EXPLOSION (Bad Luck) - 20% Chance
        else
            ply:ChatPrint("[Roulette] CRITICAL FAILURE.")
            
            local explo = ents.Create("env_explosion")
            explo:SetPos(pos)
            explo:SetOwner(ply)
            explo:SetKeyValue("iMagnitude", "100")
            explo:Spawn()
            explo:Fire("Explode", "", 0)
            
            self:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        -- Draw a floating "?" above it
        local ang = LocalPlayer():EyeAngles()
        ang:RotateAroundAxis(ang:Forward(), 90)
        ang:RotateAroundAxis(ang:Right(), 90)
        
        cam.Start3D2D(self:GetPos() + Vector(0,0,30), ang, 0.2)
            draw.SimpleText("?", "DermaLarge", 0, 0, Color(255, 255, 0, 255 + math.sin(CurTime()*5)*50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end