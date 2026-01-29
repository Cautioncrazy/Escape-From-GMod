AddCSLuaFile()

-- --- 1. SHARED CONFIG & ITEM REGISTRY ---
local TAG = "TarkovInv"

-- Inventory Configuration
local CONTAINER_SIZES = {
    pockets = 4,
    secure = 4,
    backpack = 0, -- Dynamic based on equipped item
    rig = 0,      -- Dynamic based on equipped item
    cache = 20    -- Fixed size for loot boxes
}

-- The Master List of all possible items
local ITEMS = {}

function RegisterItem(id, data)
    ITEMS[id] = data
    data.ID = id
end

function GetItemData(id)
    return ITEMS[id]
end

-- ACCESSOR: Allow server to read all registered items
function GetAllTarkovItems()
    return ITEMS
end

-- --- ITEM DEFINITIONS ---

-- 1. GEAR (Containers & Armor)
RegisterItem("backpack_scav", {
    Name = "Trash Bag Backpack",
    Desc = "A literal garbage bag with some string. Holds 6 items.",
    Model = "models/props_junk/garbage_bag001a.mdl",
    Type = "equip",
    Slot = "Backpack",
    Capacity = 6,
    Weight = 0.5
})

RegisterItem("rig_combine", {
    Name = "Combine Vest",
    Desc = "Standard issue patrol vest. Adds 10 slots.",
    Model = "models/Combine_Helicopter/helicopter_bomb01.mdl",
    Type = "equip",
    Slot = "Rig",
    Capacity = 10,
    Weight = 3.0
})

RegisterItem("armor_hev", {
    Name = "HEV Suit Mk V",
    Desc = "Hazardous Environment Suit. Provides protection.",
    Model = "models/items/item_item_crate.mdl",
    Type = "equip",
    Slot = "Armor",
    Weight = 10.0
})

-- 2. WEAPONS
RegisterItem("weapon_smg1", {
    Name = "SMG-1",
    Desc = "Compact submachine gun.",
    Model = "models/weapons/w_smg1.mdl",
    Type = "equip",
    Slot = "Primary",
    Weight = 3.5
})

RegisterItem("weapon_pistol", {
    Name = "9mm Pistol",
    Desc = "Reliable sidearm.",
    Model = "models/weapons/w_pistol.mdl",
    Type = "equip",
    Slot = "Secondary",
    Weight = 1.2
})

-- 3. LOOT & CONSUMABLES
RegisterItem("tushonka", {
    Name = "Tushonka",
    Desc = "Canned beef stew. Restores hunger.",
    Model = "models/props_junk/garbage_metalcan002a.mdl",
    Type = "item",
    Weight = 0.5
})

RegisterItem("medkit", {
    Name = "AI-2 Medkit",
    Desc = "Standard issue first aid.",
    Model = "models/items/healthkit.mdl",
    Type = "item",
    Weight = 0.2
})

RegisterItem("bitcoin", {
    Name = "Physical Bitcoin",
    Desc = "Valuable crypto currency.",
    Model = "models/props_lab/monitor01a.mdl",
    Type = "item",
    Weight = 0.1,
    Color = Color(255, 215, 0)
})

-- --- 4. DYNAMIC LOOT GENERATION (NEW) ---
hook.Add("InitPostEntity", "TarkovGenDynamicItems", function()
    -- Delay generation to ensure all weapons (client & server) are fully registered
    timer.Simple(3, function()
        -- Helper: Determine Slot Type
        local function GetWeaponSlot(wep)
            local class = string.lower(wep.ClassName or "")
            local base = string.lower(wep.Base or "")
            local cat = string.lower(wep.Category or "")
            local name = string.lower(wep.PrintName or "")
            local hold = string.lower(wep.HoldType or "")
            local slot = wep.Slot or -1

            -- 1. DETECT MELEE
            if slot == 0 or hold == "melee" or hold == "melee2" or hold == "knife" or hold == "fist" then return "Melee" end
            if string.find(base, "melee") or string.find(cat, "melee") or string.find(name, "knife") or string.find(name, "bayonet") then return "Melee" end

            -- 2. DETECT GRENADE / THROWABLE
            if slot == 4 or hold == "grenade" or hold == "slam" then return "Grenade" end
            if string.find(base, "grenade") or string.find(cat, "grenade") or string.find(name, "grenade") or string.find(name, "smoke") or string.find(name, "flash") then return "Grenade" end
            -- ArcCW specific check for throwables
            if wep.Throwing or (wep.Primary and string.find(tostring(wep.Primary.Ammo), "grenade")) then return "Grenade" end

            -- 3. DETECT SECONDARY (Pistols, SMGs, Launchers)
            if slot == 1 or hold == "pistol" or hold == "revolver" then return "Secondary" end

            -- Detect SMGs as secondary if explicit Slot 1 or defined by keywords
            if string.find(cat, "secondary") then return "Secondary" end
            -- Launchers / RPGs
            if hold == "rpg" or string.find(name, "launcher") or string.find(name, "rpg") or string.find(cat, "launcher") then return "Secondary" end
            -- Small SMGs / Machine Pistols
            if hold == "smg" or string.find(name, "smg") or string.find(name, "mp7") or string.find(name, "mp9") or string.find(name, "mac") or string.find(name, "uzi") then
                -- Default SMGs to Secondary unless explicitly marked as Slot 2 (Primary) AND not a "Machine Pistol"
                if slot == 2 then
                     if string.find(name, "machine pistol") or string.find(name, "micro") then return "Secondary" end
                     return "Primary" -- Large SMG
                end
                return "Secondary"
            end

            -- 4. DEFAULT TO PRIMARY
            return "Primary"
        end

        -- Scan for Spawnable Weapons
        for _, wep in pairs(list.Get("Weapon")) do
            if wep.Spawnable and wep.PrintName then
                -- Protected call to prevent one bad weapon from breaking everything
                local success, err = pcall(function()
                    local id = wep.ClassName
                    if not ITEMS[id] then
                        -- Get the truest definition we can find
                        local stored = weapons.GetStored(id) or wep

                        -- FIX: Ensure a valid model exists, using common addon fields
                        local mdl = stored.WorldModel
                        if not mdl or mdl == "" then mdl = stored.WM end -- ArcCW/TFA
                        if not mdl or mdl == "" then mdl = stored.ViewModel end -- Last resort

                        -- Fallback to list entry if stored failed
                        if not mdl or mdl == "" then mdl = wep.WorldModel end
                        if not mdl or mdl == "" then mdl = wep.ViewModel end

                        -- Sanity check for error model
                        if not mdl or mdl == "" or mdl == "models/error.mdl" then
                            mdl = "models/weapons/w_rif_ak47.mdl" -- Fallback generic weapon
                        end

                        -- DETERMINE SLOT
                        local slot = GetWeaponSlot(stored)

                        RegisterItem(id, {
                            Name = wep.PrintName,
                            Desc = "Weapon: " .. (wep.Category or "Unknown"),
                            Model = mdl,
                            Type = "equip",
                            Slot = slot,
                            Weight = 2.0
                        })
                    end
                end)
                if not success then
                    print("[Tarkov Inv] Error registering weapon " .. tostring(wep.ClassName) .. ": " .. tostring(err))
                end
            end
        end

        -- Scan for Spawnable Entities (Simple Props logic)
        for class, entData in pairs(scripted_ents.GetList()) do
            local t = entData.t
            if t.Spawnable and t.PrintName and not ITEMS[class] then
                -- Attempt to find a real model
                local model = t.Model or t.WorldModel

                -- If invalid or missing, fallback to box
                if not model or model == "" or model == "models/error.mdl" then
                    model = "models/props_junk/cardboard_box004a.mdl"
                end

                RegisterItem(class, {
                    Name = t.PrintName,
                    Desc = "Item: " .. (t.Category or "Misc"),
                    Model = model,
                    Type = "item",
                    Weight = 1.0
                })
            end
        end
        print("[Tarkov Inv] Generated dynamic items.")
    end)
end)

-- --- 2. SERVER SIDE LOGIC ---
if SERVER then
    util.AddNetworkString(TAG .. "_Update")
    util.AddNetworkString(TAG .. "_Action") -- Drop, Equip, Unequip, Use, Move
    util.AddNetworkString(TAG .. "_Pickup") -- Manual Pickup
    util.AddNetworkString(TAG .. "_SearchUI") -- NEW: Search Progress
    util.AddNetworkString(TAG .. "_Close") -- NEW: Client Request to Stop Looting

    -- Ensure data exists (Lazy Init)
    local function EnsureProfile(ply)
        if not ply.TarkovData then
            ply.TarkovData = {
                Equipment = {},
                Containers = {
                    pockets = {},
                    secure = {},
                    backpack = {},
                    rig = {},
                    cache = {} -- Stores loot from currently open box
                }
            }
        end
        -- Initialize searched caches list
        if not ply.SearchedCaches then
            ply.SearchedCaches = {}
        end
    end

    -- Initialize Inventory on Spawn
    hook.Add("PlayerInitialSpawn", TAG .. "_Init", function(ply)
        EnsureProfile(ply)
        ply:SetNWString("TarkovBackpack", "")
        ply.ActiveLootCache = nil
        ply.IsSearching = false
        ply.SearchedCaches = {} -- Reset on spawn
    end)

    -- Helper: Get Capacity of a container for a player
    local function GetContainerCapacity(ply, containerName)
        EnsureProfile(ply)
        if containerName == "pockets" then return CONTAINER_SIZES.pockets end
        if containerName == "secure" then return CONTAINER_SIZES.secure end
        if containerName == "cache" then return CONTAINER_SIZES.cache end

        if containerName == "backpack" then
            local bagID = ply.TarkovData.Equipment["Backpack"]
            if bagID and ITEMS[bagID] then return ITEMS[bagID].Capacity or 0 end
            return 0
        end
        if containerName == "rig" then
            local rigID = ply.TarkovData.Equipment["Rig"]
            if rigID and ITEMS[rigID] then return ITEMS[rigID].Capacity or 0 end
            return 0
        end
        return 0
    end

    -- Sync Function (Forward Declaration)
    local SyncInventory

    -- Helper: Stop Looting Logic
    local function StopLooting(ply)
        if IsValid(ply.ActiveLootCache) then
            -- Save state back to the entity
            ply.ActiveLootCache.CacheInventory = table.Copy(ply.TarkovData.Containers.cache)
            ply.ActiveLootCache = nil
            ply.TarkovData.Containers.cache = {}
            SyncInventory(ply) -- Send update (IsCacheOpen will be false)
        end
    end

    -- Helper: Add Item to best available container OR Equip if empty
    function AddItemToInventory(ply, itemId)
        EnsureProfile(ply)
        if not ITEMS[itemId] then
            print("[Inv] Item ID Invalid: " .. tostring(itemId))
            return false
        end

        local itemData = ITEMS[itemId]

        -- 1. Auto-Equip Logic
        if itemData.Type == "equip" and itemData.Slot then
            if not ply.TarkovData.Equipment[itemData.Slot] then
                ply.TarkovData.Equipment[itemData.Slot] = itemId

                -- FIX: Use slot type (include Melee/Grenade)
                if itemData.Slot == "Primary" or itemData.Slot == "Secondary" or itemData.Slot == "Melee" or itemData.Slot == "Grenade" then
                    ply:Give(itemId)
                    ply:SelectWeapon(itemId)
                elseif itemData.Slot == "Armor" and itemId == "armor_hev" then
                    ply:EquipSuit()
                    ply:SetArmor(100)
                end

                if itemData.Slot == "Backpack" then ply:SetNWString("TarkovBackpack", itemData.Model) end

                ply:ChatPrint("[Inventory] Auto-Equipped " .. itemData.Name)
                SyncInventory(ply)
                return true
            end
        end

        -- 2. Container Logic (First Empty Slot)
        local priority = {"pockets", "rig", "backpack"}

        for _, contName in ipairs(priority) do
            local cap = GetContainerCapacity(ply, contName)
            if cap > 0 then
                for i = 1, cap do
                    if not ply.TarkovData.Containers[contName][i] then
                        ply.TarkovData.Containers[contName][i] = itemId
                        SyncInventory(ply)
                        return true
                    end
                end
            end
        end

        ply:ChatPrint("[Inventory] No space in Pockets/Rig/Backpack!")
        return false
    end

    -- Close Handler
    net.Receive(TAG .. "_Close", function(len, ply)
        EnsureProfile(ply)
        StopLooting(ply)
    end)

    -- Distance Check Loop
    hook.Add("Think", "TarkovLootDistanceCheck", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply.ActiveLootCache) then
                if ply:GetPos():DistToSqr(ply.ActiveLootCache:GetPos()) > 150*150 then
                    StopLooting(ply)
                end
            end
        end
    end)

    -- Action Handler
    net.Receive(TAG .. "_Action", function(len, ply)
        EnsureProfile(ply)
        local action = net.ReadString()

        if action == "drop" then
            local container = net.ReadString()
            local index = net.ReadUInt(8)
            local list = ply.TarkovData.Containers[container]

            if list and list[index] then
                local itemID = list[index]
                list[index] = nil -- Clear slot

                local ent = ents.Create("ent_loot_item")
                ent:SetPos(ply:GetShootPos() + ply:GetAimVector() * 50)
                ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
                ent:DefineItem(itemID)
                ent:Spawn()

                SyncInventory(ply)
            end

        elseif action == "move" then
            local fromCont = net.ReadString()
            local fromIdx = net.ReadUInt(8)
            local toCont = net.ReadString()
            local toIdx = net.ReadUInt(8)

            local fromList = ply.TarkovData.Containers[fromCont]
            local toList = ply.TarkovData.Containers[toCont]
            local toCap = GetContainerCapacity(ply, toCont)

            if fromList and toList and fromList[fromIdx] and toIdx <= toCap then
                local itemA = fromList[fromIdx]
                local itemB = toList[toIdx]

                toList[toIdx] = itemA
                fromList[fromIdx] = itemB

                SyncInventory(ply)
            end

        elseif action == "equip" then
            local container = net.ReadString()
            local index = net.ReadUInt(8)
            local itemID = ply.TarkovData.Containers[container][index]
            local itemData = ITEMS[itemID]

            if itemData and itemData.Type == "equip" then
                local targetSlot = itemData.Slot

                -- Check if slot is occupied (SWAP LOGIC)
                if ply.TarkovData.Equipment[targetSlot] then
                    local oldItemID = ply.TarkovData.Equipment[targetSlot]
                    -- Attempt to move old item to inventory (swap)
                    -- Note: We use AddItemToInventory but we must ensure it doesn't just re-equip it!
                    -- We manually check space.

                    -- Simple check: Is there space in the container we are taking from? (1:1 swap)
                    -- Actually, AddItemToInventory searches all containers.
                    -- But to avoid infinite recursion or complex state, we'll try to add it.
                    -- We clear the equipment slot temporarily to allow the add? No.

                    -- Attempt to add old item to storage
                    if AddItemToInventory(ply, oldItemID) then
                        -- If successful, unequip logic for old item
                        local oldData = ITEMS[oldItemID]
                        if oldData and (oldData.Slot == "Primary" or oldData.Slot == "Secondary" or oldData.Slot == "Melee" or oldData.Slot == "Grenade") then
                            ply:StripWeapon(oldItemID)
                        elseif oldItemID == "armor_hev" then
                            ply:RemoveSuit(); ply:SetArmor(0)
                        end
                        if targetSlot == "Backpack" then ply:SetNWString("TarkovBackpack", "") end

                        -- Now slot is technically empty in data (AddItemToInventory might have put it in a container)
                        -- Proceed to equip NEW item
                        ply.TarkovData.Equipment[targetSlot] = nil -- Ensure clean state
                    else
                        ply:ChatPrint("No space to swap item!")
                        return
                    end
                end

                -- EQUIP NEW ITEM
                ply.TarkovData.Containers[container][index] = nil
                ply.TarkovData.Equipment[targetSlot] = itemID

                if targetSlot == "Primary" or targetSlot == "Secondary" or targetSlot == "Melee" or targetSlot == "Grenade" then
                    ply:Give(itemID)
                    ply:SelectWeapon(itemID)
                elseif targetSlot == "Armor" and itemID == "armor_hev" then
                    ply:EquipSuit()
                    ply:SetArmor(100)
                end

                if targetSlot == "Backpack" then ply:SetNWString("TarkovBackpack", itemData.Model) end

                SyncInventory(ply)
            end

        elseif action == "unequip" then
            local slot = net.ReadString()
            local itemID = ply.TarkovData.Equipment[slot]
            if itemID then
                local itemData = ITEMS[itemID]
                if AddItemToInventory(ply, itemID) then
                    ply.TarkovData.Equipment[slot] = nil

                    -- FIX: Use slot type
                    if itemData and (itemData.Slot == "Primary" or itemData.Slot == "Secondary" or itemData.Slot == "Melee" or itemData.Slot == "Grenade") then
                        ply:StripWeapon(itemID)
                    elseif itemID == "armor_hev" then
                        ply:RemoveSuit()
                        ply:SetArmor(0)
                    end

                    if slot == "Backpack" then ply:SetNWString("TarkovBackpack", "") end
                    SyncInventory(ply)
                end
            end

        elseif action == "unequip_to" then
            local slot = net.ReadString()
            local toCont = net.ReadString()
            local toIdx = net.ReadUInt(8)
            local itemID = ply.TarkovData.Equipment[slot]

            if itemID then
                local toList = ply.TarkovData.Containers[toCont]
                local toCap = GetContainerCapacity(ply, toCont)

                if toList and toIdx <= toCap and not toList[toIdx] then
                    ply.TarkovData.Equipment[slot] = nil
                    toList[toIdx] = itemID

                    local itemData = ITEMS[itemID]
                    if itemData and (itemData.Slot == "Primary" or itemData.Slot == "Secondary" or itemData.Slot == "Melee" or itemData.Slot == "Grenade") then
                        ply:StripWeapon(itemID)
                    elseif itemID == "armor_hev" then
                        ply:RemoveSuit(); ply:SetArmor(0)
                    end
                    if slot == "Backpack" then ply:SetNWString("TarkovBackpack", "") end

                    SyncInventory(ply)
                end
            end

        elseif action == "quick_move" then
            local container = net.ReadString()
            local index = net.ReadUInt(8)
            local list = ply.TarkovData.Containers[container]

            if list and list[index] then
                local itemID = list[index]

                -- 1. From Cache -> Inventory
                if container == "cache" then
                    if AddItemToInventory(ply, itemID) then
                        list[index] = nil
                        SyncInventory(ply)
                    end
                -- 2. From Inventory -> Equip
                else
                    local itemData = ITEMS[itemID]
                    if itemData and itemData.Type == "equip" then
                        if not ply.TarkovData.Equipment[itemData.Slot] then
                            ply.TarkovData.Containers[container][index] = nil
                            ply.TarkovData.Equipment[itemData.Slot] = itemID

                            -- FIX: Use slot type (include Melee/Grenade)
                            if itemData.Slot == "Primary" or itemData.Slot == "Secondary" or itemData.Slot == "Melee" or itemData.Slot == "Grenade" then
                                ply:Give(itemID)
                                ply:SelectWeapon(itemID)
                            elseif itemData.Slot == "Armor" and itemID == "armor_hev" then
                                ply:EquipSuit()
                                ply:SetArmor(100)
                            end
                            if itemData.Slot == "Backpack" then ply:SetNWString("TarkovBackpack", itemData.Model) end

                            SyncInventory(ply)
                        else
                             ply:ChatPrint("Slot " .. itemData.Slot .. " is occupied!")
                        end
                    end
                end
            end

        elseif action == "drop_equip" then
            local slot = net.ReadString()
            local itemID = ply.TarkovData.Equipment[slot]
            if itemID then
                local itemData = ITEMS[itemID]
                ply.TarkovData.Equipment[slot] = nil

                -- FIX: Use slot type
                if itemData and (itemData.Slot == "Primary" or itemData.Slot == "Secondary" or itemData.Slot == "Melee" or itemData.Slot == "Grenade") then
                    ply:StripWeapon(itemID)
                elseif itemID == "armor_hev" then
                    ply:RemoveSuit()
                    ply:SetArmor(0)
                end

                if slot == "Backpack" then ply:SetNWString("TarkovBackpack", "") end

                local ent = ents.Create("ent_loot_item")
                ent:SetPos(ply:GetShootPos() + ply:GetAimVector() * 50)
                ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
                ent:DefineItem(itemID)
                ent:Spawn()
                SyncInventory(ply)
            end

        elseif action == "use" then
            local container = net.ReadString()
            local index = net.ReadUInt(8)
            local itemList = ply.TarkovData.Containers[container]
            if itemList and itemList[index] then
                local itemID = itemList[index]
                local itemData = ITEMS[itemID]

                -- Support using ANY item if it maps to a scripted entity (like ammo)
                -- or if it is a consumable defined below
                local used = false

                -- 1. Try generic entity usage (Ammo, Weapons, etc.)
                local entTable = scripted_ents.Get(itemID)
                if entTable then
                    -- Give the entity to the player (standard GMod behavior for ammo/weps)
                    ply:Give(itemID)
                    used = true
                end

                -- 2. Try hardcoded consumables
                if not used and itemData and itemData.Type == "item" then
                    if itemID == "tushonka" then
                        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
                        ply:EmitSound("npc/barnacle/barnacle_crunch2.wav")
                        used = true
                    elseif itemID == "medkit" then
                        ply:SetHealth(math.min(ply:Health() + 50, ply:GetMaxHealth()))
                        ply:EmitSound("items/medshot4.wav")
                        used = true
                    end
                end

                if used then
                    itemList[index] = nil
                    SyncInventory(ply)
                end
            end
        end
    end)

    -- Manual Pickup Handler
    net.Receive(TAG .. "_Pickup", function(len, ply)
        if (ply.NextPickupTime or 0) > CurTime() then return end
        ply.NextPickupTime = CurTime() + 0.2

        local ent = net.ReadEntity()
        if IsValid(ent) and ent.IsTarkovLoot then
            if ent:GetPos():DistToSqr(ply:GetPos()) < 150*150 then
                local id = ent:GetNWString("ItemID", "")
                if id ~= "" then
                    if AddItemToInventory(ply, id) then
                        ply:EmitSound("items/ammo_pickup.wav")
                        ply:ChatPrint("Picked up: " .. (ITEMS[id].Name or id))
                        ent:Remove()
                    end
                end
            end
        end
    end)

    SyncInventory = function(ply)
        EnsureProfile(ply)

        -- Sync Cache: Copy player's cache session back to the entity logic
        if IsValid(ply.ActiveLootCache) then
            ply.ActiveLootCache.CacheInventory = table.Copy(ply.TarkovData.Containers.cache)
        else
            -- If no cache open, clear the session cache
            ply.TarkovData.Containers.cache = {}
        end

        net.Start(TAG .. "_Update")
        net.WriteTable(ply.TarkovData)
        net.WriteBool(IsValid(ply.ActiveLootCache))
        net.Send(ply)
    end

    concommand.Add("give_loot", function(ply, cmd, args)
        local id = args[1] or "tushonka"
        AddItemToInventory(ply, id)
    end)
end

-- --- 3. CLIENT SIDE UI ---
if CLIENT then
    local LocalData = { Equipment = {}, Containers = { pockets={}, secure={}, backpack={}, rig={}, cache={} } }
    local IsCacheOpen = false
    local CacheOpenedAt = 0 -- Track when the cache was opened
    local invFrame = nil
    local cacheFrame = nil -- NEW: Separate frame for loot cache
    local OpenInventory

    net.Receive(TAG .. "_Update", function()
        local wasCacheOpen = IsCacheOpen
        LocalData = net.ReadTable()
        IsCacheOpen = net.ReadBool()

        -- Detect if cache JUST opened
        if IsCacheOpen and not wasCacheOpen then
             CacheOpenedAt = CurTime()
        end

        -- If we have a cache frame but cache is closed, close it
        if not IsCacheOpen and IsValid(cacheFrame) then
             cacheFrame:Remove()
             cacheFrame = nil
        end

        if IsValid(invFrame) then
            OpenInventory(true)
        elseif IsCacheOpen then
            OpenInventory(false) -- Auto Open if cache is active
        end
    end)

    -- NEW: SEARCH UI
    local SearchEndTime = 0
    local SearchDuration = 0
    net.Receive(TAG .. "_SearchUI", function()
        SearchDuration = net.ReadFloat()
        SearchEndTime = CurTime() + SearchDuration
    end)

    hook.Add("HUDPaint", "TarkovSearchHUD", function()
        if CurTime() < SearchEndTime then
            local w, h = ScrW(), ScrH()
            local pct = 1 - ((SearchEndTime - CurTime()) / SearchDuration)
            draw.RoundedBox(4, w/2 - 100, h/2 + 50, 200, 20, Color(0,0,0,200))
            draw.RoundedBox(4, w/2 - 98, h/2 + 52, 196 * pct, 16, Color(200, 200, 200, 255))
            draw.SimpleText("SEARCHING...", "DermaDefault", w/2, h/2 + 60, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    local function DrawAttachedBackpack(ent, mdl)
        if not mdl or mdl == "" then return end
        if not IsValid(ent.VisBackpack) or ent.VisBackpack:GetModel() ~= mdl then
            if IsValid(ent.VisBackpack) then ent.VisBackpack:Remove() end
            ent.VisBackpack = ClientsideModel(mdl)
            ent.VisBackpack:SetNoDraw(true)
            ent.VisBackpack:SetModelScale(0.85)
        end
        local bone = ent:LookupBone("ValveBiped.Bip01_Spine2")
        if not bone then return end
        local m = ent:GetBoneMatrix(bone)
        if not m then return end
        local pos, ang = m:GetTranslation(), m:GetAngles()
        ang:RotateAroundAxis(ang:Right(), 180)
        ang:RotateAroundAxis(ang:Up(), 180)
        pos = pos + ang:Up() * -4
        pos = pos + ang:Forward() * -8
        ent.VisBackpack:SetRenderOrigin(pos)
        ent.VisBackpack:SetRenderAngles(ang)
        ent.VisBackpack:DrawModel()
    end

    hook.Add("PostPlayerDraw", "TarkovDrawBackpack", function(ply)
        if not IsValid(ply) then return end
        local mdl = ply:GetNWString("TarkovBackpack", "")
        DrawAttachedBackpack(ply, mdl)
    end)

    local function CreateItemPanel(parent, itemID, w, h, onClick, draggableData, dropHandler, quickAction)
        local pnl = parent:Add("DPanel")
        pnl:SetSize(w, h)
        pnl.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
            if not itemID then return end
        end

        if dropHandler then
             pnl:Receiver("TarkovItemDrag", dropHandler)
        end

        if itemID then
            local itemData = ITEMS[itemID]
            if itemData then
                local model = vgui.Create("DModelPanel", pnl)
                model:Dock(FILL)
                model:SetModel(itemData.Model)
                if itemData.Color then model:SetColor(itemData.Color) end

                local mn, mx = model.Entity:GetRenderBounds()
                local size = 0
                size = math.max( size, math.abs(mn.x) + math.abs(mx.x) )
                size = math.max( size, math.abs(mn.y) + math.abs(mx.y) )
                size = math.max( size, math.abs(mn.z) + math.abs(mx.z) )
                model:SetFOV(45)
                model:SetCamPos(Vector(size, size, size))
                model:SetLookAt((mn + mx) * 0.5)

                if draggableData then
                    model:Droppable("TarkovItemDrag")
                    model.DragData = draggableData
                end

                if dropHandler then
                    model:Receiver("TarkovItemDrag", dropHandler)
                end

                local baseMousePressed = model.OnMousePressed
                local lastClick = 0
                model.OnMousePressed = function(s, code)
                    if code == MOUSE_LEFT then
                        if input.IsKeyDown(KEY_LCONTROL) and quickAction then
                            quickAction()
                            return
                        end

                        -- Double Click Logic
                        if CurTime() - lastClick < 0.3 then
                            lastClick = 0 -- Reset to prevent triple-click triggering twice

                            local container = draggableData and draggableData.Container
                            local index = draggableData and draggableData.Index
                            local data = ITEMS[itemID]

                            if container and index and data then
                                if container == "cache" then
                                    if data.Type == "item" then
                                        -- Use/Consume from Cache
                                        net.Start(TAG.."_Action")
                                        net.WriteString("use")
                                        net.WriteString(container)
                                        net.WriteUInt(index, 8)
                                        net.SendToServer()
                                    else
                                        -- Take (Quick Move)
                                        net.Start(TAG.."_Action")
                                        net.WriteString("quick_move")
                                        net.WriteString(container)
                                        net.WriteUInt(index, 8)
                                        net.SendToServer()
                                    end
                                else
                                    -- Inventory
                                    if data.Type == "equip" then
                                        -- Equip
                                        net.Start(TAG.."_Action")
                                        net.WriteString("equip")
                                        net.WriteString(container)
                                        net.WriteUInt(index, 8)
                                        net.SendToServer()
                                    elseif data.Type == "item" then
                                        -- Use
                                        net.Start(TAG.."_Action")
                                        net.WriteString("use")
                                        net.WriteString(container)
                                        net.WriteUInt(index, 8)
                                        net.SendToServer()
                                    end
                                end
                            end
                            return
                        end
                        lastClick = CurTime()
                    end

                    if code == MOUSE_RIGHT and onClick then
                        onClick()
                        return
                    end
                    if baseMousePressed then baseMousePressed(s, code) end
                end

                model:SetTooltip(itemData.Name .. "\n" .. (itemData.Desc or ""))
            end
        end
        return pnl
    end

    function OpenInventory(bRefresh)
        if IsValid(invFrame) and not bRefresh then
            invFrame:Close()
            invFrame = nil
            if IsValid(cacheFrame) then cacheFrame:Remove() cacheFrame = nil end
            return
        end

        local leftPanel
        local playerModel
        local rightPanel

        if not IsValid(invFrame) then
            invFrame = vgui.Create("DFrame")
            invFrame:SetSize(800, 600)
            invFrame:Center()
            invFrame:SetTitle("GEAR & LOOT")
            invFrame:MakePopup()
            invFrame:ShowCloseButton(true)

            -- Cleanup callback
            invFrame.OnRemove = function()
                CloseDermaMenus()
                invFrame = nil
                if IsValid(cacheFrame) then cacheFrame:Remove() cacheFrame = nil end -- Close cache too
            end

            invFrame.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(20, 20, 20, 250))
            end

            leftPanel = vgui.Create("DPanel", invFrame)
            leftPanel:Dock(LEFT)
            leftPanel:SetWide(300)
            leftPanel.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30, 100)) end
            invFrame.LeftPanel = leftPanel

            playerModel = vgui.Create("DModelPanel", leftPanel)
            playerModel:Dock(FILL)
            playerModel:SetModel(LocalPlayer():GetModel())

            playerModel.LayoutEntity = function(self, ent)
                ent:SetAngles(Angle(0, RealTime()*10 % 360, 0))
                local backpackID = LocalData.Equipment["Backpack"]
                if backpackID and ITEMS[backpackID] then
                    DrawAttachedBackpack(ent, ITEMS[backpackID].Model)
                end
            end

            -- FIX LEAK: Remove attached clientside model when panel is removed
            playerModel.OnRemove = function(self)
                local ent = self:GetEntity()
                if IsValid(ent) and IsValid(ent.VisBackpack) then
                     ent.VisBackpack:Remove()
                end
            end
            invFrame.PlayerModel = playerModel

            rightPanel = vgui.Create("DScrollPanel", invFrame)
            rightPanel:Dock(FILL)
            rightPanel:DockMargin(10, 0, 0, 0)
            invFrame.RightPanel = rightPanel
        else
            leftPanel = invFrame.LeftPanel
            playerModel = invFrame.PlayerModel
            rightPanel = invFrame.RightPanel
        end

        -- Cleanup Slots (children of leftPanel except PlayerModel)
        for _, child in ipairs(leftPanel:GetChildren()) do
            if child ~= playerModel then child:Remove() end
        end

        -- Cleanup Right Panel
        rightPanel:Clear()

        -- Updated slots layout to include Grenade and Melee
        local slots = {
            {name="Head",x=110,y=10},
            {name="Armor",x=110,y=80},
            {name="Primary",x=10,y=200,w=120,h=60},
            {name="Secondary",x=170,y=200,w=120,h=60},
            {name="Rig",x=10,y=300,w=80,h=80},
            {name="Backpack",x=210,y=300,w=80,h=80},
            {name="Melee",x=10,y=390,w=80,h=80},
            {name="Grenade",x=210,y=390,w=80,h=80}
        }
        for _, slotInfo in ipairs(slots) do
            local w,h = slotInfo.w or 80, slotInfo.h or 80
            local itemID = LocalData.Equipment[slotInfo.name]

            local function HandleEquipDrop(self, panels, bDoDrop, Command, x, y)
                if bDoDrop then
                    local src = panels[1].DragData
                    if src then
                        local list = LocalData.Containers[src.Container]
                        if list and list[src.Index] then
                             local dropItemID = list[src.Index]
                             local itemData = ITEMS[dropItemID]
                             if itemData and itemData.Slot == slotInfo.name then
                                 net.Start(TAG .. "_Action")
                                 net.WriteString("equip")
                                 net.WriteString(src.Container)
                                 net.WriteUInt(src.Index, 8)
                                 net.SendToServer()
                             end
                        end
                    end
                end
            end

            local pnl = CreateItemPanel(leftPanel, itemID, w, h, function()
                local menu = DermaMenu()
                menu:AddOption("Unequip", function() net.Start(TAG.."_Action"); net.WriteString("unequip"); net.WriteString(slotInfo.name); net.SendToServer() end)
                menu:AddOption("Drop", function() net.Start(TAG.."_Action"); net.WriteString("drop_equip"); net.WriteString(slotInfo.name); net.SendToServer() end)
                menu:Open()
            end, { Slot = slotInfo.name, IsEquip = true }, HandleEquipDrop,
            function() -- Quick Action (Ctrl+Click)
                net.Start(TAG.."_Action"); net.WriteString("unequip"); net.WriteString(slotInfo.name); net.SendToServer()
            end)
            pnl:SetPos(slotInfo.x, slotInfo.y)
            local lbl = vgui.Create("DLabel", pnl); lbl:SetText(slotInfo.name); lbl:SizeToContents(); lbl:SetPos(2, 2)
        end

        local function AddContainerDisplay(targetPanel, name, title, isCache)
            local capacity = 0
            if name == "pockets" then capacity = 4
            elseif name == "secure" then capacity = 4
            elseif name == "cache" then capacity = 20
            elseif name == "backpack" then local id = LocalData.Equipment["Backpack"]; if id and ITEMS[id] then capacity = ITEMS[id].Capacity end
            elseif name == "rig" then local id = LocalData.Equipment["Rig"]; if id and ITEMS[id] then capacity = ITEMS[id].Capacity end
            end

            -- Cache logic handled separately now
            if name == "cache" and not IsCacheOpen then return end

            local header = targetPanel:Add("DLabel")
            header:SetText(title)
            header:SetFont("DermaLarge")
            header:Dock(TOP)
            header:DockMargin(0, 10, 0, 5)
            if isCache then header:SetColor(Color(255, 200, 50)) end

            if capacity == 0 then
                local msg = targetPanel:Add("DLabel")
                msg:SetText("No " .. title .. " equipped.")
                msg:Dock(TOP); msg:DockMargin(5, 0, 0, 10)
                return
            end

            local grid = targetPanel:Add("DIconLayout")
            grid:Dock(TOP); grid:SetSpaceX(5); grid:SetSpaceY(5)

            local items = LocalData.Containers[name] or {}
            for i = 1, capacity do
                local itemID = items[i]
                local slotPnl = grid:Add("DPanel")
                slotPnl:SetSize(80, 80)
                slotPnl.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 255)) end

                local function HandleDrop(self, panels, bDoDrop, Command, x, y)
                    if bDoDrop then
                        local src = panels[1].DragData
                        if src then
                            if src.IsEquip then
                                net.Start(TAG .. "_Action")
                                net.WriteString("unequip_to")
                                net.WriteString(src.Slot)
                                net.WriteString(name); net.WriteUInt(i, 8)
                                net.SendToServer()
                            else
                                net.Start(TAG .. "_Action")
                                net.WriteString("move")
                                net.WriteString(src.Container); net.WriteUInt(src.Index, 8)
                                net.WriteString(name); net.WriteUInt(i, 8)
                                net.SendToServer()
                            end
                        end
                    end
                end
                slotPnl:Receiver("TarkovItemDrag", HandleDrop)

                if itemID then
                    local dragInfo = { Container = name, Index = i }
                    local itemPnl = CreateItemPanel(slotPnl, itemID, 80, 80, function()
                        local menu = DermaMenu()
                        local data = ITEMS[itemID]
                        if data.Type == "equip" then
                            menu:AddOption("Equip", function() net.Start(TAG.."_Action"); net.WriteString("equip"); net.WriteString(name); net.WriteUInt(i, 8); net.SendToServer() end)
                        elseif data.Type == "item" then
                             menu:AddOption("Use", function() net.Start(TAG.."_Action"); net.WriteString("use"); net.WriteString(name); net.WriteUInt(i, 8); net.SendToServer() end)
                        end
                        menu:AddOption("Drop", function() net.Start(TAG.."_Action"); net.WriteString("drop"); net.WriteString(name); net.WriteUInt(i, 8); net.SendToServer() end)
                        menu:Open()
                    end, dragInfo, HandleDrop,
                    function() -- Quick Action
                        net.Start(TAG.."_Action"); net.WriteString("quick_move"); net.WriteString(name); net.WriteUInt(i, 8); net.SendToServer()
                    end)
                    itemPnl:Dock(FILL)
                end
            end
        end

        AddContainerDisplay(rightPanel, "pockets", "Pockets", false)
        AddContainerDisplay(rightPanel, "secure", "Secure Container", false)
        AddContainerDisplay(rightPanel, "rig", "Tactical Rig", false)
        AddContainerDisplay(rightPanel, "backpack", "Backpack", false)

        -- NEW: Separate Window for Cache
        if IsCacheOpen then
            if IsValid(cacheFrame) then cacheFrame:Remove() end
            cacheFrame = vgui.Create("DFrame")
            cacheFrame:SetSize(400, 600)
            -- Position to the right of the main inventory
            local ix, iy = invFrame:GetPos()
            cacheFrame:SetPos(ix + 810, iy)
            cacheFrame:SetTitle("LOOT CACHE")
            cacheFrame:ShowCloseButton(false) -- Closes with main inv
            cacheFrame:MakePopup()
            cacheFrame.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(20, 20, 20, 250))
            end

            local cacheScroll = vgui.Create("DScrollPanel", cacheFrame)
            cacheScroll:Dock(FILL)
            cacheScroll:DockMargin(10, 10, 10, 10)

            AddContainerDisplay(cacheScroll, "cache", "CONTAINER CONTENTS", true)
        end
    end

    local wasPressedI = false
    local wasPressedE = false

    hook.Add("Think", "ToggleInv", function()
        -- TOGGLE WITH I
        if input.IsButtonDown(KEY_I) then
            if not wasPressedI then
                local focus = vgui.GetKeyboardFocus()
                if not (IsValid(focus) and focus:GetClassName() == "TextEntry") and not gui.IsGameUIVisible() then
                    if IsValid(invFrame) then
                        -- Close UI Request
                        if IsCacheOpen then net.Start(TAG.."_Close"); net.SendToServer() end
                        CloseDermaMenus()
                        invFrame.OnRemove = nil
                        invFrame:Remove()
                        invFrame = nil
                        if IsValid(cacheFrame) then cacheFrame:Remove() cacheFrame = nil end
                    else
                        OpenInventory()
                    end
                end
                wasPressedI = true
            end
        else wasPressedI = false end

        -- CLOSE WITH E
        if input.IsButtonDown(KEY_E) then
            if not wasPressedE then
                local focus = vgui.GetKeyboardFocus()
                if not (IsValid(focus) and focus:GetClassName() == "TextEntry") then
                    if IsValid(invFrame) and IsCacheOpen then
                        if CurTime() > CacheOpenedAt + 1.0 then
                            -- Close UI Request
                            net.Start(TAG.."_Close"); net.SendToServer()

                            CloseDermaMenus()
                            invFrame.OnRemove = nil
                            invFrame:Remove()
                            invFrame = nil
                            if IsValid(cacheFrame) then cacheFrame:Remove() cacheFrame = nil end
                        end
                    end
                end
                wasPressedE = true
            end
        else wasPressedE = false end
    end)

    hook.Add("OnPlayerChat", "ChatInv", function(ply, text) if text=="/bag" then if ply==LocalPlayer() then OpenInventory() end return true end end)
    hook.Add("KeyPress", "TarkovLootPickup", function(ply, key)
        if key == IN_USE and IsFirstTimePredicted() then
            local tr = util.TraceHull({start=ply:GetShootPos(),endpos=ply:GetShootPos()+ply:GetAimVector()*100,mins=Vector(-10,-10,-10),maxs=Vector(10,10,10),filter=ply})
            if IsValid(tr.Entity) and tr.Entity.IsTarkovLoot then net.Start(TAG.."_Pickup"); net.WriteEntity(tr.Entity); net.SendToServer() end
        end
    end)

    -- QUICK KEYS (G / V)
    -- Also use PlayerBindPress to potentially block default actions if we have a valid action
    hook.Add("PlayerBindPress", "TarkovBindBlock", function(ply, bind, pressed)
        if not pressed then return end
        if bind == "noclip" then
            local itemID = LocalData.Equipment["Melee"]
            if itemID and ITEMS[itemID] then
                 -- If we have a melee weapon equipped, BLOCK noclip so we can use it for quick melee
                 -- But only if we are not in noclip already? No, standard tarkov logic overrides standard commands.
                 -- Let's just return true to block it.
                 -- CAUTION: This might annoy admins.
                 if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
                     return true
                 end
            end
        end
    end)

    hook.Add("PlayerButtonDown", "TarkovQuickKeys", function(ply, key)
        if not IsFirstTimePredicted() then return end
        if gui.IsGameUIVisible() or (vgui.GetKeyboardFocus() and vgui.GetKeyboardFocus():GetClassName() == "TextEntry") then return end

        local slotName
        if key == KEY_G then slotName = "Grenade" end
        if key == KEY_V then slotName = "Melee" end

        if not slotName then return end

        -- DEBUG
        print("[TarkovQuick] Key Pressed: " .. slotName)

        local itemID = LocalData.Equipment[slotName]
        if not itemID or not ITEMS[itemID] then
            print("[TarkovQuick] No item in slot or invalid item.")
            return
        end

        local wepClass = itemID
        local wep = ply:GetWeapon(wepClass)

        -- DEBUG
        print("[TarkovQuick] Item: " .. itemID .. " | Entity Valid: " .. tostring(IsValid(wep)))

        if IsValid(wep) then
            local currentWep = ply:GetActiveWeapon()
            if not IsValid(currentWep) then return end

            -- If already active, just attack
            if currentWep == wep then
                 RunConsoleCommand("+attack")
                 timer.Simple(0.1, function() RunConsoleCommand("-attack") end)
                 return
            end

            local prevWepClass = currentWep:GetClass()

            -- Switch
            input.SelectWeapon(wep)

            -- Timed Attack Sequence
            -- Increased initial delay slightly to account for slow deployments
            timer.Create("TarkovQuick_"..slotName, 0.5, 1, function()
                if not IsValid(ply) then return end

                -- Check if switch happened
                if ply:GetActiveWeapon() ~= wep then
                    print("[TarkovQuick] Switch failed or interrupted. Active: " .. tostring(ply:GetActiveWeapon()))
                    return
                end

                RunConsoleCommand("+attack")

                timer.Simple(0.2, function()
                    RunConsoleCommand("-attack")

                    timer.Simple(0.6, function()
                        if not IsValid(ply) then return end
                        -- Only switch back if we are still holding the quick weapon
                        if ply:GetActiveWeapon() == wep then
                             local prev = ply:GetWeapon(prevWepClass)
                             if IsValid(prev) then input.SelectWeapon(prev) end
                        end
                    end)
                end)
            end)
        else
            -- Debug: why is weapon invalid?
            print("[TarkovQuick] Weapon entity not found on client. Latency?")
        end
    end)
end

-- --- 4. LOOT ITEM ENTITY ---
local ENT_ITEM = {}
ENT_ITEM.Type = "anim"
ENT_ITEM.Base = "base_gmodentity"
ENT_ITEM.PrintName = "Loot Item"
ENT_ITEM.Spawnable = false
ENT_ITEM.IsTarkovLoot = true

if SERVER then
    function ENT_ITEM:Initialize()
        self:SetModel("models/props_junk/cardboard_box004a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS); self:SetMoveType(MOVETYPE_VPHYSICS); self:SetSolid(SOLID_VPHYSICS); self:SetUseType(SIMPLE_USE); self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        local phys = self:GetPhysicsObject(); if IsValid(phys) then phys:Wake() end
    end
    function ENT_ITEM:DefineItem(id)
        self:SetNWString("ItemID", id)
        local data = ITEMS[id]
        if data then self:SetModel(data.Model); if data.Color then self:SetColor(data.Color) end
        self:PhysicsInit(SOLID_VPHYSICS); self:SetMoveType(MOVETYPE_VPHYSICS); self:SetSolid(SOLID_VPHYSICS); self:SetUseType(SIMPLE_USE); self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        local phys = self:GetPhysicsObject(); if IsValid(phys) then phys:Wake() end end
    end
    function ENT_ITEM:Use(activator)
        if IsValid(activator) and activator:IsPlayer() then
             local id = self:GetNWString("ItemID", "")
             if id ~= "" then
                  local res = AddItemToInventory(activator, id)
                  if res then
                      activator:EmitSound("items/ammo_pickup.wav")
                      activator:ChatPrint("Picked up: " .. (ITEMS[id].Name or id))
                      self:Remove()
                  end
             end
        end
    end
end
if CLIENT then
    function ENT_ITEM:Draw() self:DrawModel() end
    local function GetLootTrace() return util.TraceHull({start=LocalPlayer():GetShootPos(),endpos=LocalPlayer():GetShootPos()+LocalPlayer():GetAimVector()*100,mins=Vector(-10,-10,-10),maxs=Vector(10,10,10),filter=LocalPlayer()}) end
    hook.Add("PreDrawHalos", "TarkovLootHalo", function() local tr = GetLootTrace(); if IsValid(tr.Entity) and tr.Entity.IsTarkovLoot then halo.Add({tr.Entity}, Color(255, 255, 255), 2, 2, 1, true, false) end end)
    hook.Add("HUDPaint", "TarkovLootText", function() local tr = GetLootTrace(); if IsValid(tr.Entity) and tr.Entity.IsTarkovLoot then local id = tr.Entity:GetNWString("ItemID", ""); local data = ITEMS[id]; if data then local w,h = ScrW(),ScrH(); draw.SimpleText("Press E to pick up " .. data.Name, "TargetID", w/2+2, h/2+42, Color(0,0,0,200), 1, 1); draw.SimpleText("Press E to pick up " .. data.Name, "TargetID", w/2, h/2+40, Color(255,255,255), 1, 1) end end end)
end
scripted_ents.Register(ENT_ITEM, "ent_loot_item")

-- --- 5. LOOT CACHE ENTITY ---
local ENT_CACHE = {}
ENT_CACHE.Type = "anim"
ENT_CACHE.Base = "base_gmodentity"
ENT_CACHE.PrintName = "Loot Cache"
ENT_CACHE.Category = "Tarkov Loot"
ENT_CACHE.Spawnable = true
ENT_CACHE.IsTarkovLoot = true -- FIX: Make it glow like other loot

if SERVER then
    function ENT_CACHE:Initialize()
        self:SetModel("models/items/item_item_crate.mdl")
        self:PhysicsInit(SOLID_VPHYSICS); self:SetMoveType(MOVETYPE_VPHYSICS); self:SetSolid(SOLID_VPHYSICS); self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject(); if IsValid(phys) then phys:Wake() end

    end

    function ENT_CACHE:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        EnsureProfile(activator) -- Make sure profile exists

        -- Check if already searched
        if activator.SearchedCaches[self:EntIndex()] then
            -- SKIP SEARCH - Open Immediately
            activator.ActiveLootCache = self
            activator.TarkovData.Containers.cache = table.Copy(self.CacheInventory)
            net.Start(TAG .. "_Update")
            net.WriteTable(activator.TarkovData)
            net.WriteBool(true)
            net.Send(activator)
            return
        end

        if activator.IsSearching then return end

        activator.IsSearching = true
        activator:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav")

        net.Start(TAG .. "_SearchUI")
        net.WriteFloat(3.0)
        net.Send(activator)

        timer.Simple(3.0, function()
            if not IsValid(activator) or not IsValid(self) then return end
            if activator:GetPos():DistToSqr(self:GetPos()) > 150*150 then
                activator.IsSearching = false
                return
            end

            activator.IsSearching = false
            activator.ActiveLootCache = self
            activator.SearchedCaches[self:EntIndex()] = true -- MARK AS SEARCHED

            -- Copy data to player session
            activator.TarkovData.Containers.cache = table.Copy(self.CacheInventory)

            -- Open UI
            net.Start(TAG .. "_Update")
            net.WriteTable(activator.TarkovData)
            net.WriteBool(true)
            net.Send(activator)
        end)
    end
end

if CLIENT then function ENT_CACHE:Draw() self:DrawModel() end end
scripted_ents.Register(ENT_CACHE, "ent_loot_cache")

-- Generate Individual Items
for id, data in pairs(ITEMS) do
    local ItemENT = { Type="anim", Base="ent_loot_item", PrintName=data.Name, Category="Tarkov Loot", Spawnable=true, IsTarkovLoot=true }
    if SERVER then function ItemENT:Initialize() self.BaseClass.Initialize(self); self:DefineItem(id) end end
    scripted_ents.Register(ItemENT, "ent_item_" .. id)
end