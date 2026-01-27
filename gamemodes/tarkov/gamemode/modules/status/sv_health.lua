-- SV_HEALTH.LUA

hook.Add("PlayerSpawn", "TarkovHealthSpawn", function(ply)
    -- Reset HP
    ply:SetHeadHP(35)
    ply:SetThoraxHP(85)
    ply:SetStomachHP(70)
    ply:SetLeftArmHP(60)
    ply:SetRightArmHP(60)
    ply:SetLeftLegHP(65)
    ply:SetRightLegHP(65)

    -- Reset Status
    ply:SetLightBleeds(0)
    ply:SetHeavyBleeds(0)
    ply:SetFractures(0)

    -- Set total health
    ply:SetHealth(440)
    ply:SetMaxHealth(440)
end)

-- Damage Handler
hook.Add("ScalePlayerDamage", "TarkovLimbDamage", function(ply, hitgroup, dmginfo)
    -- Return if God mode
    if not ply:Alive() then return end

    -- Get Limb Flag
    local limb = TARKOV_HITGROUP_MAP[hitgroup] or 2 -- Default Thorax if unknown

    local damage = dmginfo:GetDamage()
    local currentHP = ply:GetLimbHP(limb)

    -- Apply Damage
    local newHP = currentHP - damage

    -- Check Blacked Limb Logic
    if newHP < 0 then
        -- Limb destroyed. Distribute overflow.
        local overflow = math.abs(newHP)
        newHP = 0

        -- Distribute overflow (simplistic: spread to all other limbs)
        -- Tarkov formula: different multipliers.
        -- We'll just do 0.7x damage to remaining limbs for simplicity
        local spread = (overflow * 0.7) / 6

        -- Reduce other limbs
        for flag, _ in pairs(TARKOV_MAX_HP) do
            if flag ~= limb then
                local hp = ply:GetLimbHP(flag)
                if hp > 0 then
                    ply:SetLimbHP(flag, math.max(0, hp - spread))
                end
            end
        end
    end

    ply:SetLimbHP(limb, newHP)

    -- Bleed Chance (Simulated)
    if damage > 15 then
        local roll = math.random()
        if roll < 0.3 then
             -- Light Bleed
             local bleeds = ply:GetLightBleeds()
             if bit.band(bleeds, limb) == 0 then
                 ply:SetLightBleeds(bit.bor(bleeds, limb))
                 ply:ChatPrint("You are bleeding (Light)!")
             end
        elseif roll < 0.1 then
             -- Heavy Bleed
             local bleeds = ply:GetHeavyBleeds()
             if bit.band(bleeds, limb) == 0 then
                 ply:SetHeavyBleeds(bit.bor(bleeds, limb))
                 ply:ChatPrint("You are bleeding (HEAVY)!")
             end
        end
    end

    -- Fracture Chance
    if damage > 30 and math.random() < 0.2 then
        local fracs = ply:GetFractures()
        if bit.band(fracs, limb) == 0 then
            ply:SetFractures(bit.bor(fracs, limb))
            ply:ChatPrint("You have a fracture!")
            ply:EmitSound("player/pl_pain5.wav")
        end
    end

    -- Update Total Health for HUD compatibility
    local total = 0
    local head = ply:GetHeadHP()
    local thorax = ply:GetThoraxHP()
    for flag, _ in pairs(TARKOV_MAX_HP) do total = total + ply:GetLimbHP(flag) end
    ply:SetHealth(total)

    -- Death Logic (Immediate)
    if head <= 0 or thorax <= 0 then
        ply:Kill()
    end

    -- Scale standard damage to 0 so we don't double dip
    -- (We manually updated health above)
    dmginfo:ScaleDamage(0)
end)

-- Bleeding Tick (Every 2 seconds)
timer.Create("TarkovBleedTick", 2, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            local light = ply:GetLightBleeds()
            local heavy = ply:GetHeavyBleeds()

            if light > 0 or heavy > 0 then
                local totalDrain = 0
                -- Check each limb
                for flag, max in pairs(TARKOV_MAX_HP) do
                    -- Heavy Bleed: 3 HP per 2 sec
                    if bit.band(heavy, flag) ~= 0 then
                        local hp = ply:GetLimbHP(flag)
                        if hp > 0 then
                            ply:SetLimbHP(flag, math.max(0, hp - 3))
                            totalDrain = totalDrain + 3
                        end
                        -- Trail
                        if math.random() < 0.5 then
                            util.Decal("Blood", ply:GetPos(), ply:GetPos() - Vector(0,0,50), ply)
                        end
                    -- Light Bleed: 1 HP per 2 sec
                    elseif bit.band(light, flag) ~= 0 then
                        local hp = ply:GetLimbHP(flag)
                        if hp > 0 then
                            ply:SetLimbHP(flag, math.max(0, hp - 1))
                            totalDrain = totalDrain + 1
                        end
                    end
                end

                -- Death from blood loss
                if ply:GetHeadHP() <= 0 or ply:GetThoraxHP() <= 0 then
                    ply:Kill()
                end

                -- Sync visual health
                 local total = 0
                for flag, _ in pairs(TARKOV_MAX_HP) do total = total + ply:GetLimbHP(flag) end
                ply:SetHealth(total)
            end
        end
    end
end)
