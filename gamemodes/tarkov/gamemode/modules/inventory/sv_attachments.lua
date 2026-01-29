-- SV_ATTACHMENTS.LUA
-- Handles integration with ArcCW and Arc9 to restrict attachments to inventory availability.

local TAG = "TarkovInv"

-- CONFIGURATION
hook.Add("InitPostEntity", "TarkovAttachmentConfig", function()
    -- ArcCW: Disable free attachments (requires entity/inventory)
    if ConVarExists("arccw_attinv_free") then
        RunConsoleCommand("arccw_attinv_free", "0")
        print("[Tarkov Config] ArcCW Free Attachments Disabled")
    end
    -- Ensure customization is enabled (just not free)
    if ConVarExists("arccw_enable_customization") then
        RunConsoleCommand("arccw_enable_customization", "1")
    end

    -- Arc9: Disable free attachments
    if ConVarExists("arc9_free_atts") then
        RunConsoleCommand("arc9_free_atts", "0")
        print("[Tarkov Config] Arc9 Free Attachments Disabled")
    end
end)

-- Helper to find an item in the player's inventory
local function FindItem(ply, id)
    if not ply.TarkovData then return nil, nil end
    for cName, items in pairs(ply.TarkovData.Containers) do
        for idx, itemID in pairs(items) do
            if itemID == id then return cName, idx end
        end
    end
    return nil, nil
end

local function ConsumeItem(ply, id)
    local cName, idx = FindItem(ply, id)
    if cName then
        ply.TarkovData.Containers[cName][idx] = nil

        -- Sync
        net.Start(TAG .. "_Update")
        net.WriteTable(ply.TarkovData)
        net.WriteBool(IsValid(ply.ActiveLootCache))
        net.Send(ply)
        return true
    end
    return false
end

-- --- ArcCW Integration ---

hook.Add("ArcCW_PlayerCanAttach", "TarkovArcCWRestrict", function(ply, wep, attName, slot, detach)
    if detach then return true end -- Always allow detaching

    -- Check if player has the item
    local c, _ = FindItem(ply, attName)
    if c then return true end

    return false
end)

hook.Add("ArcCW_OnAttach", "TarkovArcCWConsume", function(ply, wep, attName)
    ConsumeItem(ply, attName)
end)

-- --- Arc9 Integration ---

hook.Add("ARC9_PlayerCanAttach", "TarkovArc9Restrict", function(ply, wep, attid, slotid, detach)
    if detach then return true end

    local c, _ = FindItem(ply, attid)
    if c then return true end

    return false
end)

hook.Add("ARC9_OnAttach", "TarkovArc9Consume", function(ply, wep, attid)
    ConsumeItem(ply, attid)
end)
