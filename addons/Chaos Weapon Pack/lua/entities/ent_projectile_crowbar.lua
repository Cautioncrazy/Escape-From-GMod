AddCSLuaFile() 

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "High Velocity Crowbar"
ENT.Author = "Senior Lua Engineer"
ENT.Spawnable = false 

-- Constants
local DAMAGE_NORMAL = 100
local EMP_RADIUS = 350
local FLIGHT_MODEL = "models/weapons/w_crowbar.mdl"

if CLIENT then
    -- Register a generic killicon to prevent console warnings
    killicon.AddAlias("ent_projectile_crowbar", "weapon_crowbar")
    
    function ENT:Draw()
        self:DrawModel()
    end
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(FLIGHT_MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
        end

        util.SpriteTrail(self, 0, Color(255, 0, 0), false, 15, 1, 2, 1 / (15 + 1) * 0.5, "trails/plasma")
        
        -- Default States
        if self.IsExplosive == nil then self.IsExplosive = false end
        if self.IsEMP == nil then self.IsEMP = false end
    end

    function ENT:SetExplosive(bool)
        self.IsExplosive = bool
    end

    function ENT:SetEMP(bool)
        self.IsEMP = bool
    end

    function ENT:PhysicsCollide(data, phys)
        
        -- 0. CRITICAL: Cache the attacker immediately
        -- The 'Owner' might be cleared (SetOwner(NULL)) in previous bounces or lost in the timer delay.
        -- We store it in 'self.LastAttacker' so we never forget who threw this.
        local currentOwner = self:GetOwner()
        if IsValid(currentOwner) then
            self.LastAttacker = currentOwner
        end
        
        -- Determine who gets credit for the damage
        local attacker = self.LastAttacker
        if not IsValid(attacker) then attacker = self end -- Fallback to self if player disconnected

        -- 1. EMP LOGIC
        if self.IsEMP then
            timer.Simple(0, function()
                if not IsValid(self) then return end
                
                -- Capture HitPos now because 'data' is not valid in the timer
                local hitPos = self:GetPos() 

                -- VISUALS: Combine Ball Explosion (Blue Electric)
                local effectData = EffectData()
                effectData:SetOrigin(hitPos)
                effectData:SetMagnitude(2)
                effectData:SetScale(1)
                effectData:SetRadius(EMP_RADIUS)
                util.Effect("cball_explode", effectData)
                
                self:EmitSound("Weapon_StunStick.Melee_Hit")

                -- EMP EFFECT: Disable mechanical NPCs
                local targets = ents.FindInSphere(hitPos, EMP_RADIUS)
                for _, ent in ipairs(targets) do
                    if IsValid(ent) then
                        local class = ent:GetClass()
                        
                        -- List of things to destroy/disable
                        local isMech = (class == "npc_turret_floor") or 
                                       (class == "npc_turret_ceiling") or 
                                       (class == "npc_rollermine") or 
                                       (class == "npc_manhack") or 
                                       (class == "npc_cscanner") or 
                                       (class == "npc_clawscanner") or
                                       (class == "npc_combine_camera")

                        if isMech then
                            -- Visual feedback on the NPC
                            local spark = EffectData()
                            spark:SetOrigin(ent:GetPos())
                            util.Effect("ManhackSparks", spark)
                            
                            -- Logic: Force self destruct or disable
                            ent:Fire("SelfDestruct") -- Turrets usually accept this
                            ent:Fire("PowerDown")    -- Rollermines accept this
                            ent:TakeDamage(500, attacker, self) -- Use cached attacker
                        end
                    end
                end

                self:Remove()
            end)
            return
        end

        -- 2. EXPLOSIVE LOGIC
        if self.IsExplosive then
            timer.Simple(0, function()
                if not IsValid(self) then return end
                
                -- Spawn Native Explosion
                local explosion = ents.Create("env_explosion")
                if IsValid(explosion) then
                    local explosionPos = data.HitPos + (data.HitNormal * 10)
                    explosion:SetPos(explosionPos)
                    explosion:SetOwner(attacker) -- Use cached attacker
                    explosion:SetKeyValue("iMagnitude", "175") 
                    explosion:Spawn()
                    explosion:Fire("Explode", "", 0)
                    explosion:Fire("Kill", "", 0.1)
                    util.Decal("Scorch", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal)
                end

                self:Remove()
            end)
            return 
        end

        -- 3. NORMAL LOGIC
        if data.Speed > 50 then 
            self:EmitSound("Physics.MetalSolid")
        end

        local hitEnt = data.HitEntity

        timer.Simple(0, function() 
            if not IsValid(self) then return end

            if IsValid(hitEnt) then
                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage(DAMAGE_NORMAL)
                dmgInfo:SetAttacker(attacker) -- Use cached attacker
                dmgInfo:SetInflictor(self)
                dmgInfo:SetDamageType(DMG_CLUB)
                hitEnt:TakeDamageInfo(dmgInfo)
            end

            -- Clear collision owner so it can bounce off the player, but we kept 'self.LastAttacker' for credit.
            self:SetOwner(NULL) 
            SafeRemoveEntityDelayed(self, 5) 
        end)
    end
end