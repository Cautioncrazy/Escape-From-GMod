-- Forces Chaos Weapons to use base HL2 icons to prevent broken/blank Q menu entries.

local CHAOS_ICON_MAPPING = {
    -- Melee / Physics
    ["weapon_crowbar_cannon"] = "vgui/hud/weapon_crowbar",
    ["weapon_ice_skates"] = "vgui/hud/weapon_crowbar",
    ["weapon_prop_cannon"] = "vgui/hud/weapon_physcannon",
    ["weapon_sawblade_launcher"] = "vgui/hud/weapon_physcannon",
    ["weapon_magnet_gun"] = "vgui/hud/weapon_physcannon",
    ["weapon_tether_gun"] = "vgui/hud/weapon_physcannon",

    -- Heavy / Energy
    ["weapon_blackhole_gun"] = "vgui/hud/weapon_ar2",
    ["weapon_cryo_blaster"] = "vgui/hud/weapon_smg1",
    ["weapon_napalm_sprayer"] = "vgui/hud/weapon_smg1",

    -- Explosive / Special
    ["weapon_sky_sweeper"] = "vgui/hud/weapon_rpg",
    ["weapon_gravity_grenade"] = "vgui/hud/weapon_frag",
    ["weapon_ricochet_rifle"] = "vgui/hud/weapon_357",
    ["weapon_quantum_sniper"] = "vgui/hud/weapon_crossbow"
}

hook.Add("Initialize", "ChaosWeaponIconFix", function()
    -- Wait for weapons to be registered
    timer.Simple(1, function()
        local weapons_table = weapons.GetList()

        for _, wep in pairs(weapons_table) do
            local icon = CHAOS_ICON_MAPPING[wep.ClassName]
            if icon then
                -- Set the IconOverride for the spawnmenu generator
                wep.IconOverride = icon

                -- Update the stored weapon table to ensure persistence
                local stored = weapons.GetStored(wep.ClassName)
                if stored then
                    stored.IconOverride = icon
                end

                -- Also update the Entity table if it exists (sometimes used for 'Entities' tab)
                local ent_table = scripted_ents.Get(wep.ClassName)
                if ent_table then
                     ent_table.IconOverride = icon
                end
            end
        end
    end)
end)

-- Force update on weapon population
hook.Add("PopulateWeapons", "ChaosWeaponPopulate", function(pnl, tree, node)
    -- This hook ensures that if the menu is rebuilt, our overrides persist
    -- The main logic is in Initialize, but this acts as a safeguard.
end)