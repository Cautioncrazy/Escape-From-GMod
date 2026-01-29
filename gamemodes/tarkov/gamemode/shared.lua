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

-- Load Status Module (Defines NetworkVars)
if SERVER then
    AddCSLuaFile("modules/status/sh_status.lua")
    include("modules/status/sh_status.lua")
    include("modules/status/sv_status.lua")
else
    include("modules/status/sh_status.lua")
end

-- Load Health Module (Defines Meta Methods, Depends on Status)
if SERVER then
    AddCSLuaFile("modules/status/sh_health.lua")
    include("modules/status/sh_health.lua")
    include("modules/status/sv_health.lua")
else
    include("modules/status/sh_health.lua")
end

-- Load Inventory Module (Depends on Health/Status)
if SERVER then
    AddCSLuaFile("modules/inventory/sh_inventory.lua")
    include("modules/inventory/sh_inventory.lua")
    include("modules/inventory/sv_loot.lua")
    include("modules/inventory/sv_attachments.lua")
else
    include("modules/inventory/sh_inventory.lua")
end

-- Load HUD Module (Client Only)
if SERVER then
    AddCSLuaFile("modules/hud/cl_hud.lua")
else
    include("modules/hud/cl_hud.lua")
end

-- Load RaPD Config
if SERVER then
    AddCSLuaFile("modules/rapd/sh_rapd_config.lua")
    include("modules/rapd/sh_rapd_config.lua")
else
    include("modules/rapd/sh_rapd_config.lua")
end
