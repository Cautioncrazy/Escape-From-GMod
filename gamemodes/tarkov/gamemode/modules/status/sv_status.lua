local TAG = "TarkovStatus"

hook.Add("PlayerSpawn", "TarkovStatusSpawn", function(ply)
    if not ply.SetHunger then
        hook.Run("SetupDataTables", ply)
        if not ply.SetHunger then return end
    end
    ply:SetHunger(100)
    ply:SetHydration(100)
    ply:SetStamina(100)
end)

-- Survival Loop (Hunger/Thirst)
-- Runs every 5 seconds
timer.Create("TarkovSurvivalTick", 5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() and ply.GetHunger then
            -- Hunger Drain: ~1 point per minute? (1/12 per 5s)
            -- Let's make it faster for testing: 1 point per 30s -> 0.16 per 5s
            -- User wants implementation, so I'll set reasonable gameplay values
            local hunger = ply:GetHunger()
            ply:SetHunger(math.max(0, hunger - 0.2))

            -- Hydration Drain: Faster
            local hydration = ply:GetHydration()
            ply:SetHydration(math.max(0, hydration - 0.3))

            -- Damage if 0
            if hunger <= 0 or hydration <= 0 then
                local dmg = DamageInfo()
                dmg:SetDamage(2)
                dmg:SetDamageType(DMG_SHOCK) -- Use SHOCK or STARVE logic
                dmg:SetAttacker(ply)
                ply:TakeDamageInfo(dmg)
                -- ply:ChatPrint("You are starving/dehydrated!") -- Too spammy every 5s
            end
        end
    end
end)
