-- SV_TARKOV_LOOT_BRIDGE.LUA
-- Connects Workshop Loot Entities to our Custom Inventory System

local TAG = "TarkovInv"

-- A cache to avoid expensive string.find operations on entity classes
local CLASS_CACHE = {}

-- Ensure Network Strings exist (Redundant safety check to prevent "unpooled message" errors)
util.AddNetworkString(TAG .. "_SearchUI")
util.AddNetworkString(TAG .. "_Update")

-- CONFIG: Add any entity classes that should act as loot containers here
local CACHE_ENTITIES = {
    ["ent_loot_cache"] = true,
    ["item_item_crate"] = true,
    ["sent_lootbox"] = true,
    ["sim_loot_crate"] = true,
    ["ent_loot_cache_tarkov"] = true -- Added our custom test entity just in case
}

-- LOOT TABLES (Simple list of item IDs from sh_tarkov_inventory.lua)
-- LOOT TABLES (Dynamic now)
local LOOT_POOLS = {}

local function BuildLootPools()
    LOOT_POOLS = {
        ["weapons"] = {},
        ["medical"] = {},
        ["misc"] = {},
        ["rare"] = {},
        ["random"] = {},
        ["ammo"] = {},
        ["entities"] = {},
        ["gear"] = {}
    }

    if not GetAllTarkovItems then return end
    local items = GetAllTarkovItems()

    for id, data in pairs(items) do
        -- Add to Random
        table.insert(LOOT_POOLS["random"], id)

        -- Determine Category
        local name = string.lower(data.Name or "")
        local desc = string.lower(data.Desc or "")
        local type = data.Type
        local slot = data.Slot

        local isWeapon = (type == "equip" and (slot == "Primary" or slot == "Secondary"))
        local isGear = (type == "equip" and (slot == "Backpack" or slot == "Rig" or slot == "Armor"))
        local isAmmo = (string.find(name, "ammo") or string.find(desc, "ammo") or string.find(name, "round") or string.find(desc, "cartridge") or string.find(desc, "magazine"))
        local isMedical = (string.find(name, "med") or string.find(name, "health") or string.find(name, "heal") or string.find(desc, "heal") or id == "tushonka") -- Tushonka is food but keeps you alive :P

        -- Special handling for "Category" field if it was captured from entity registry
        local cat = string.lower(data.Desc or "") -- In sh_tarkov_inventory, Desc often contains "Category: ..."
        if string.find(cat, "ammo") then isAmmo = true end

        if isWeapon then
            table.insert(LOOT_POOLS["weapons"], id)
        elseif isAmmo then
            table.insert(LOOT_POOLS["ammo"], id)
        elseif isMedical then
            table.insert(LOOT_POOLS["medical"], id)
        elseif isGear then
            table.insert(LOOT_POOLS["gear"], id)
        elseif type == "item" then
            -- If it's an item and not ammo/med, it's likely an entity or misc
            -- If it was registered from scripted_ents and not handled above
            if not isAmmo and not isMedical then
                table.insert(LOOT_POOLS["entities"], id)
                table.insert(LOOT_POOLS["misc"], id) -- Also put in misc
            end
        else
            table.insert(LOOT_POOLS["misc"], id)
        end

        -- Rare check (Simple keyword search)
        if string.find(name, "rare") or string.find(desc, "valuable") or id == "bitcoin" or id == "armor_hev" then
            table.insert(LOOT_POOLS["rare"], id)
        end
    end

    -- Fallbacks if empty
    if #LOOT_POOLS["weapons"] == 0 then table.insert(LOOT_POOLS["weapons"], "weapon_pistol") end
    if #LOOT_POOLS["random"] == 0 then table.insert(LOOT_POOLS["random"], "tushonka") end

    print("[Tarkov Loot] Generated Loot Pools. Total Items: " .. table.Count(items))
end

hook.Add("InitPostEntity", "TarkovBuildLootPools", function()
    -- Run after a short delay to ensure all items are registered
    timer.Simple(1, BuildLootPools)
end)

-- Helper to get random item from pool
local function GetRandomItem(poolName)
    local pool = LOOT_POOLS[poolName] or LOOT_POOLS["random"]
    if not pool or #pool == 0 then return "tushonka" end
    return pool[math.random(#pool)]
end

-- HOOK: PlayerUse
-- Intercepts the use key on loot entities
hook.Add("PlayerUse", "TarkovBridge_Use", function(ply, ent)
    if not IsValid(ent) then return end

    local class = ent:GetClass()

    -- Check cache first
    if CLASS_CACHE[class] == false then return end
    if CLASS_CACHE[class] == true then
        -- This is a known loot box, proceed with logic
    else
        -- Not in cache, perform the expensive check
        local isLoot = CACHE_ENTITIES[class] or string.find(class, "loot") or string.find(class, "cache")
        if isLoot then
            CLASS_CACHE[class] = true -- Store positive result
        else
            CLASS_CACHE[class] = false -- Store negative result
            return
        end
    end

    -- This code block will only be reached if the entity is a loot container
        -- Safety: If searching flag got stuck but timer is gone, reset it
        if ply.IsSearching and (ply.SearchEndTime or 0) < CurTime() then
            ply.IsSearching = false
        end

        -- Prevent spam / check if already searching
        if ply.IsSearching then return false end

        -- Get the pool tag set by your Admin Tool
        local poolTag = ent:GetNWString("LootPool", "random")
        -- print("[Tarkov Bridge] Found Loot Box! Pool: " .. poolTag)

        -- 1. START SEARCHING (Visuals)
        ply.IsSearching = true
        ply.SearchEndTime = CurTime() + 3.5 -- Safety timeout

        ply:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav")

        -- Send Search Progress Bar to Client
        net.Start(TAG .. "_SearchUI")
        net.WriteFloat(3.0) -- 3.0 Seconds duration
        net.Send(ply)

        -- 2. TIMER (Logic)
        timer.Create("TarkovSearch_" .. ply:SteamID64(), 3.0, 1, function()
            if not IsValid(ply) then return end
            ply.IsSearching = false

            if not IsValid(ent) then return end

            -- Validate Distance
            if ply:GetPos():DistToSqr(ent:GetPos()) > 150*150 then
                ply:ChatPrint("You moved too far away.")
                return
            end

            -- 3. GENERATE LOOT (Only if not already looted/generated)
            if not ent.CacheInventory then
                ent.CacheInventory = {}

                -- Generate 3-8 items based on the tag
                for i=1, math.random(3, 8) do
                    local slot = math.random(1, 20) -- 20 is cache size
                    local item = GetRandomItem(poolTag)

                    if not ent.CacheInventory[slot] then
                        ent.CacheInventory[slot] = item
                    end
                end
                -- print("[Tarkov Bridge] Generated loot for box.")
            end

            -- 4. OPEN INVENTORY MENU
            -- Set this entity as the player's active cache session
            ply.ActiveLootCache = ent

            -- Sync the cache data to the player's "cache" container slot in their session
            if ply.TarkovData then
                ply.TarkovData.Containers.cache = table.Copy(ent.CacheInventory)

                -- Send update to client (This opens the menu because IsCacheOpen will be true)
                net.Start(TAG .. "_Update")
                net.WriteTable(ply.TarkovData)
                net.WriteBool(true) -- Tell client cache is OPEN
                net.Send(ply)

                ply:EmitSound("items/ammo_pickup.wav")

                -- Force open menu command just in case
                ply:ConCommand("tarkov_open_inventory")
            end
        end)

        -- Return false to BLOCK the entity's default behavior
        -- (e.g. stop the workshop addon from opening its own menu)
        return false
    end
