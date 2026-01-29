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

-- LOOT TABLES (Will be rebuilt dynamically)
local LOOT_POOLS = {
    ["weapons"] = {},
    ["medical"] = {},
    ["misc"] = {},
    ["rare"] = {},
    ["gear"] = {},
    ["ammo"] = {},
    ["random"] = {}
}

-- DYNAMIC LOOT POOL GENERATION
local function BuildLootPools()
    -- Get All Items from shared registry
    local allItems = GetAllTarkovItems()

    -- Safety Check
    if not allItems then
        print("[Tarkov Bridge] CRITICAL ERROR: GetAllTarkovItems returned nil!")
        return
    end

    -- Reset Pools
    LOOT_POOLS = {
        ["weapons"] = {},
        ["medical"] = {},
        ["misc"] = {},
        ["rare"] = {},
        ["gear"] = {},
        ["ammo"] = {},
        ["random"] = {}
    }

    local count = 0
    for id, data in pairs(allItems) do
        count = count + 1
        table.insert(LOOT_POOLS["random"], id)

        local lId = string.lower(id)
        local lDesc = string.lower(data.Desc or "")
        local lName = string.lower(data.Name or "")

        -- Categorize based on ID, Type, or Description
        if data.Slot == "Primary" or data.Slot == "Secondary" or data.Slot == "Melee" or data.Slot == "Grenade" or string.find(lId, "weapon") then
            table.insert(LOOT_POOLS["weapons"], id)
        end

        if string.find(lId, "med") or string.find(lId, "health") or string.find(lName, "med") then
            table.insert(LOOT_POOLS["medical"], id)
        end

        if string.find(lId, "ammo") or string.find(lDesc, "ammo") then
            table.insert(LOOT_POOLS["ammo"], id)
        end

        -- Gear: Prioritize items with Capacity (Backpacks/Rigs) or Armor
        if data.Type == "equip" and not string.find(lId, "weapon") then
            if (data.Capacity and data.Capacity > 0) or data.Slot == "Armor" or data.Slot == "Rig" or data.Slot == "Backpack" then
                table.insert(LOOT_POOLS["gear"], id)
            end
        end

        if data.Type == "item" then
            table.insert(LOOT_POOLS["misc"], id)
        end

        if string.find(lId, "bitcoin") or string.find(lId, "gold") or string.find(lDesc, "rare") then
            table.insert(LOOT_POOLS["rare"], id)
        end
    end

    -- Fallback safety
    if #LOOT_POOLS["random"] == 0 then
        table.insert(LOOT_POOLS["random"], "tushonka")
    end

    print("[Tarkov Bridge] Built loot pools with " .. count .. " items.")
end

-- Rebuild pools after entities load (so dynamic items are registered)
hook.Add("InitPostEntity", "TarkovBuildPools", function()
    -- MUST RUN AFTER sh_tarkov_inventory's 3-second timer
    timer.Simple(5, function()
        BuildLootPools()
    end)
end)

-- DEBUG: Console command to force rebuild
concommand.Add("tarkov_debug_loot", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    print("--- TARKOV LOOT DEBUG ---")
    local items = GetAllTarkovItems()
    print("Total Registered Items: " .. table.Count(items))

    BuildLootPools()

    for pool, list in pairs(LOOT_POOLS) do
        print("Pool [" .. pool .. "]: " .. #list .. " items")
    end
    print("-------------------------")
end)

-- Helper to get random item from pool
local function GetRandomItem(poolName)
    local pool = LOOT_POOLS[poolName]
    -- Fallback to random if pool is empty or invalid
    if not pool or #pool == 0 then
        pool = LOOT_POOLS["random"]
    end

    if #pool > 0 then
        return pool[math.random(#pool)]
    else
        return "tushonka" -- Ultimate fallback
    end
end

-- Helper to open the loot interface (generates loot if needed)
local function OpenLootCache(ply, ent)
    local poolTag = ent:GetNWString("LootPool", "random")

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
end

-- HOOK: PlayerUse
-- Intercepts the use key on loot entities
hook.Add("PlayerUse", "TarkovBridge_Use", function(ply, ent)
    if not IsValid(ent) then return end

    local class = ent:GetClass()

    -- EXPLICIT IGNORE: Do not treat loose items as containers
    if class == "ent_loot_item" or string.sub(class, 1, 9) == "ent_item_" then
        return
    end

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

    -- Check if already searched
    if ent.SearchedBy and ent.SearchedBy[ply] then
        OpenLootCache(ply, ent)
        return false
    end

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

        -- Mark as searched
        ent.SearchedBy = ent.SearchedBy or {}
        ent.SearchedBy[ply] = true

        OpenLootCache(ply, ent)
    end)

    -- Return false to BLOCK the entity's default behavior
    -- (e.g. stop the workshop addon from opening its own menu)
    return false
end)

-- --- DATA PERSISTENCE ---
-- Loads saved loot cache configurations (Pools) on map start
local function LoadLootData()
    local mapName = game.GetMap()
    if file.Exists("tarkov_data/" .. mapName .. ".json", "DATA") then
        local json = file.Read("tarkov_data/" .. mapName .. ".json", "DATA")
        local data = util.JSONToTable(json)

        if data then
            print("[Tarkov Loot] Loading " .. #data .. " loot caches...")
            for _, entry in ipairs(data) do
                -- Try to find existing entity first (for map props)
                local found = false
                local nearby = ents.FindInSphere(entry.pos, 5)
                for _, ent in ipairs(nearby) do
                    if ent:GetClass() == (entry.class or "ent_loot_cache") then -- Only match if class matches (or default)
                        ent:SetNWString("LootPool", entry.pool)
                        -- Force update pos/ang just in case
                        ent:SetPos(entry.pos)
                        ent:SetAngles(entry.ang)
                        found = true
                        break
                    end
                end

                -- If not found (it was a spawned entity), respawn it
                if not found then
                    local ent = ents.Create(entry.class or "ent_loot_cache")
                    if IsValid(ent) then
                        ent:SetPos(entry.pos)
                        ent:SetAngles(entry.ang)
                        ent:Spawn()
                        ent:SetNWString("LootPool", entry.pool)
                        -- Ensure it doesn't fall through world if physics sleep
                        local phys = ent:GetPhysicsObject()
                        if IsValid(phys) then phys:EnableMotion(false) end
                    end
                end
            end
        end
    else
        print("[Tarkov Loot] No saved data for map: " .. mapName)
    end
end

-- DELAYED LOADING: Wait for other addons (like workshop map props) to spawn
hook.Add("InitPostEntity", "TarkovLoadLoot", function()
    timer.Simple(5, LoadLootData)
end)
hook.Add("PostCleanupMap", "TarkovLoadLootClean", function()
    timer.Simple(5, LoadLootData)
end)