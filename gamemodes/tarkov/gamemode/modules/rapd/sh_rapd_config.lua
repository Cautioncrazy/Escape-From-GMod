-- RAPD CONFIGURATION
-- Forces specific settings for Realistic Damage

if SERVER then
    hook.Add("Initialize", "RaPD_ForceConfig", function()
        -- Disable inventory saving (handled by our gamemode)
        RunConsoleCommand("rapd_saveinventory", "0")

        -- Enable weapon dropping on damage/death
        RunConsoleCommand("rapd_dropweapon", "1")

        print("[RaPD Config] Settings enforced.")
    end)
end

if CLIENT then
    -- Bind O key to open RaPD Menu
    hook.Add("PlayerButtonDown", "RaPD_MenuBind", function(ply, key)
        if not IsFirstTimePredicted() then return end

        -- Prevent opening while typing
        if gui.IsGameUIVisible() or (vgui.GetKeyboardFocus() and vgui.GetKeyboardFocus():GetClassName() == "TextEntry") then return end

        if key == KEY_O then
            RunConsoleCommand("rapd_menu")
        end
    end)
end