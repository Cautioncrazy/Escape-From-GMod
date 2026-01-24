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
    -- Scan for Spawnable Weapons
    for _, wep in pairs(list.Get("Weapon")) do
        if wep.Spawnable and wep.WorldModel and wep.PrintName then
            local id = wep.ClassName
            if not ITEMS[id] then
                RegisterItem(id, {
                    Name = wep.PrintName,
                    Desc = "Weapon: " .. (wep.Category or "Unknown"),
                    Model = wep.WorldModel,
                    Type = "equip",
                    Slot = (wep.Slot == 0 or wep.Slot == 1) and "Secondary" or "Primary",
                    Weight = 2.0
                })
            end
        end
    end

    -- Scan for Spawnable Entities (Simple Props logic)
    for class, entData in pairs(scripted_ents.GetList()) do
        local t = entData.t
        if t.Spawnable and t.PrintName and not ITEMS[class] then
            -- Fallback model since many scripted ents don't define WorldModel strictly
            local model = "models/props_junk/cardboard_box004a.mdl"
            RegisterItem(class, {
                Name = t.PrintName,
                Desc = "Item: " .. (t.Category or "Misc"),
                Model = model,
                Type = "item",
                Weight = 1.0
            })
        end
    end
end)

-- --- 2. SERVER SIDE LOGIC ---
if SERVER then
    util.AddNetworkString(TAG .. "_Update")
    util.AddNetworkString(TAG .. "_Action") -- Drop, Equip, Unequip, Use, Move
    util.AddNetworkString(TAG .. "_Pickup") -- Manual Pickup
    util.AddNetworkString(TAG .. "_SearchUI") -- NEW: Search Progress

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

                if string.sub(itemId, 1, 6) == "weapon" then ply:Give(itemId)
                elseif itemId == "armor_hev" then ply:EquipSuit(); ply:SetArmor(100) end
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

        elseif action == "quick_move" then
            local container = net.ReadString()
            local index = net.ReadUInt(8)
            
            -- If coming from a container (cache, pockets, backpack, rig)
            local list = ply.TarkovData.Containers[container]
            if list and list[index] then
                local itemID = list[index]
                local itemData = ITEMS[itemID]
                
                -- Try to Auto-Equip first
                if itemData.Type == "equip" and not ply.TarkovData.Equipment[itemData.Slot] then
                     ply.TarkovData.Containers[container][index] = nil
                     ply.TarkovData.Equipment[itemData.Slot] = itemID
                     
                     if string.sub(itemID, 1, 6) == "weapon" then ply:Give(itemID)
                     elseif itemID == "armor_hev" then ply:EquipSuit(); ply:SetArmor(100) end
                     if itemData.Slot == "Backpack" then ply:SetNWString("TarkovBackpack", itemData.Model) end
                     
                     SyncInventory(ply)
                     return
                end
                
                -- Else move to best available container (that isn't self if possible, but simplicity first)
                -- If in Cache, try Pockets/Rig/Backpack
                if container == "cache" then
                    if AddItemToInventory(ply, itemID) then
                        ply.TarkovData.Containers[container][index] = nil
                        SyncInventory(ply)
                    end
                else
                    -- If in inventory, try to move to Cache if open? 
                    -- Or just move to another container?
                    -- For now, "Quick Move" usually implies "Loot" -> "Inventory" or "Equip"
                    -- Let's support Inventory -> Cache if Cache is open
                    if IsValid(ply.ActiveLootCache) then
                        -- Try to add to cache
                        local cacheCap = 20
                        for i=1, cacheCap do
                            if not ply.TarkovData.Containers.cache[i] then
                                ply.TarkovData.Containers.cache[i] = itemID
                                ply.TarkovData.Containers[container][index] = nil
                                SyncInventory(ply)
                                return
                            end
                        end
                    end
                end
            end
        end

        ply:ChatPrint("[Inventory] No space in Pockets/Rig/Backpack!")
        return false
    end

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
                if not ply.TarkovData.Equipment[itemData.Slot] then
                    ply.TarkovData.Containers[container][index] = nil
                    ply.TarkovData.Equipment[itemData.Slot] = itemID

                    if string.sub(itemID, 1, 6) == "weapon" then ply:Give(itemID)
                    elseif itemID == "armor_hev" then ply:EquipSuit(); ply:SetArmor(100) end
                    if itemData.Slot == "Backpack" then ply:SetNWString("TarkovBackpack", itemData.Model) end

                    SyncInventory(ply)
                else
                    ply:ChatPrint("Slot " .. itemData.Slot .. " is occupied!")
                end
            end

        elseif action == "unequip" then
            local slot = net.ReadString()
            local itemID = ply.TarkovData.Equipment[slot]
            if itemID then
                if AddItemToInventory(ply, itemID) then
                    ply.TarkovData.Equipment[slot] = nil
                    if string.sub(itemID, 1, 6) == "weapon" then ply:StripWeapon(itemID)
                    elseif itemID == "armor_hev" then ply:RemoveSuit(); ply:SetArmor(0) end
                    if slot == "Backpack" then ply:SetNWString("TarkovBackpack", "") end
                    SyncInventory(ply)
                end
            end

        elseif action == "drop_equip" then
            local slot = net.ReadString()
            local itemID = ply.TarkovData.Equipment[slot]
            if itemID then
                ply.TarkovData.Equipment[slot] = nil
                if string.sub(itemID, 1, 6) == "weapon" then ply:StripWeapon(itemID)
                elseif itemID == "armor_hev" then ply:RemoveSuit(); ply:SetArmor(0) end
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
                if itemData.Type == "item" then
                    local used = false
                    if itemID == "tushonka" then
                        ply:SetHealth(math.min(ply:Health() + 25, ply:GetMaxHealth()))
                        ply:EmitSound("npc/barnacle/barnacle_crunch2.wav")
                        used = true
                    elseif itemID == "medkit" then
                        ply:SetHealth(math.min(ply:Health() + 50, ply:GetMaxHealth()))
                        ply:EmitSound("items/medshot4.wav")
                        used = true
                    end
                    if used then
                        itemList[index] = nil
                        SyncInventory(ply)
                    end
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

    function SyncInventory(ply)
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
    local invFrame = nil
    local cacheFrame = nil -- NEW: Separate frame for loot cache
    local OpenInventory

    net.Receive(TAG .. "_Update", function()
        LocalData = net.ReadTable()
        IsCacheOpen = net.ReadBool()

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

    local function CreateItemPanel(parent, itemID, w, h, onClick, draggableData, dropHandler)
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
                model.OnMousePressed = function(s, code)
                    if code == MOUSE_RIGHT and onClick then
                        onClick()
                        return
                    end
                    -- Ctrl+Click Logic
                    if code == MOUSE_LEFT and input.IsKeyDown(KEY_LCONTROL) then
                        if draggableData then -- draggableData contains { Container = "...", Index = ... }
                             net.Start(TAG .. "_Action")
                             net.WriteString("quick_move")
                             net.WriteString(draggableData.Container)
                             net.WriteUInt(draggableData.Index, 8)
                             net.SendToServer()
                             return
                        end
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

        local slots = { {name="Head",x=110,y=10}, {name="Armor",x=110,y=80}, {name="Primary",x=10,y=200,w=120,h=60}, {name="Secondary",x=170,y=200,w=120,h=60}, {name="Rig",x=10,y=300,w=80,h=80}, {name="Backpack",x=210,y=300,w=80,h=80} }
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
            end, nil, HandleEquipDrop)
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
                            net.Start(TAG .. "_Action")
                            net.WriteString("move")
                            net.WriteString(src.Container); net.WriteUInt(src.Index, 8)
                            net.WriteString(name); net.WriteUInt(i, 8)
                            net.SendToServer()
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
                    end, dragInfo, HandleDrop)
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

    local wasPressed = false
    hook.Add("Think", "ToggleInv", function()
        if input.IsButtonDown(KEY_I) then
            if not wasPressed then
                local focus = vgui.GetKeyboardFocus()
                if not (IsValid(focus) and focus:GetClassName() == "TextEntry") and not gui.IsGameUIVisible() then
                    if IsValid(invFrame) then
                        CloseDermaMenus()
                        invFrame.OnRemove = nil
                        invFrame:Remove()
                        invFrame = nil
                        if IsValid(cacheFrame) then cacheFrame:Remove() cacheFrame = nil end
                    else
                        OpenInventory()
                    end
                end
                wasPressed = true
            end
        else wasPressed = false end
    end)

    hook.Add("OnPlayerChat", "ChatInv", function(ply, text) if text=="/bag" then if ply==LocalPlayer() then OpenInventory() end return true end end)
    hook.Add("KeyPress", "TarkovLootPickup", function(ply, key)
        if key == IN_USE and IsFirstTimePredicted() then
            local tr = util.TraceHull({start=ply:GetShootPos(),endpos=ply:GetShootPos()+ply:GetAimVector()*100,mins=Vector(-10,-10,-10),maxs=Vector(10,10,10),filter=ply})
            if IsValid(tr.Entity) and tr.Entity.IsTarkovLoot then net.Start(TAG.."_Pickup"); net.WriteEntity(tr.Entity); net.SendToServer() end
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
    function ENT_ITEM:Use(activator) end -- Manual pickup override
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

        -- Fill with Random Loot
        self.CacheInventory = {}
        local keys = {}
        for k in pairs(ITEMS) do table.insert(keys, k) end
        for i=1, math.random(5, 10) do
            local item = keys[math.random(#keys)]
            local slot = math.random(1, 20)
            if not self.CacheInventory[slot] then self.CacheInventory[slot] = item end
        end
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
