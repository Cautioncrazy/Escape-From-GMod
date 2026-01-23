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
-- You can expand this list with more specific items
local LOOT_POOLS = {
    ["weapons"] = {"weapon_pistol", "weapon_smg1", "medkit"},
    ["medical"] = {"medkit", "medkit", "tushonka"},
    ["misc"] = {"scrap", "tushonka", "backpack_scav"},
    ["rare"] = {"bitcoin", "weapon_smg1", "rig_combine"},
    ["random"] = {"tushonka", "medkit", "bitcoin", "weapon_pistol", "backpack_scav", "scrap", "rig_combine"}
}

-- Helper to get random item from pool
local function GetRandomItem(poolName)
    local pool = LOOT_POOLS[poolName] or LOO_POOLS["random"]
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
end)