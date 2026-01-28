GM.Name = "Escape from GMOD"
GM.Author = "User"
GM.Email = "N/A"
GM.Website = "N/A"
GM.TeamBased = false

-- Helper to load modules
function GM:LoadModule(path)
    if SERVER then
        AddCSLuaFile(path)
        include(path)
    else
        include(path)
    end
end

-- 1. LOAD CORE (MUST LOAD FIRST)
-- This defines the NetworkVars (GetHydration, etc.)
if SERVER then
    AddCSLuaFile("core/sh_status.lua")
    include("core/sh_status.lua")
else
    include("core/sh_status.lua")
end

-- 2. LOAD STATUS SYSTEM (Depends on Core)
if SERVER then
    AddCSLuaFile("modules/status/sv_status.lua")
    include("modules/status/sv_status.lua")
end

-- 3. LOAD HEALTH SYSTEM (Depends on Status)
if SERVER then
    AddCSLuaFile("modules/status/sh_health.lua")
    include("modules/status/sh_health.lua")
    include("modules/status/sv_health.lua")
else
    include("modules/status/sh_health.lua")
end

-- 4. LOAD INVENTORY SYSTEM (Depends on Health/Status)
if SERVER then
    AddCSLuaFile("modules/inventory/sh_inventory.lua")
    include("modules/inventory/sh_inventory.lua")
    include("modules/inventory/sv_loot.lua")
else
    include("modules/inventory/sh_inventory.lua")
end

-- 5. LOAD HUD (Depends on Everything)
if SERVER then
    AddCSLuaFile("modules/hud/cl_hud.lua")
else
    include("modules/hud/cl_hud.lua")
end

-- 6. LOAD ADMIN PROPERTIES (Independent)
if SERVER then
    AddCSLuaFile("modules/admin/sh_admin_properties.lua")
    include("modules/admin/sh_admin_properties.lua")
else
    include("modules/admin/sh_admin_properties.lua")
end
