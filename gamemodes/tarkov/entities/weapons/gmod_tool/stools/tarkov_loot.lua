TOOL.Category = "Tarkov Tools"
TOOL.Name = "Loot Manager"
TOOL.Command = nil
TOOL.ConfigName = "" -- Settings are saved based on this

-- Client-side Tool Instructions
if CLIENT then
    language.Add("tool.tarkov_loot.name", "Tarkov Loot Manager")
    language.Add("tool.tarkov_loot.desc", "Manage loot cache positions and types.")
    language.Add("tool.tarkov_loot.0", "Left Click: Save/Tag/Clear (Based on Mode) | Right Click: Copy Settings")
end

-- Define Tool ConVars (Settings)
-- These automatically sync between client and server
TOOL.ClientConVar["mode"] = "save"
TOOL.ClientConVar["pool"] = "random"

-- CONFIG: The class name of the workshop entity you are using
local CACHE_CLASSES = {
    ["ent_loot_cache"] = true,
    ["item_item_crate"] = true,
    ["sent_lootbox"] = true,
    ["sim_loot_crate"] = true,
    ["ent_loot_cache_tarkov"] = true
}

-- Helper: Determine if an entity is a valid loot container
-- This matches the logic in the Bridge script + the explicit list + flags
local function IsValidLootCache(ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    -- 1. Exclude loose items and pickup entities
    if class == "ent_loot_item" then return false end
    if string.sub(class, 1, 9) == "ent_item_" then return false end

    -- 2. Check Whitelist
    if CACHE_CLASSES[class] then return true end

    -- 3. Check Internal Flag
    if ent.IsTarkovLoot then return true end

    -- 4. Check Name Pattern (Matches sv_tarkov_loot_bridge.lua logic)
    -- This ensures we catch workshop entities that aren't in our hardcoded list
    if string.find(class, "loot") or string.find(class, "cache") or string.find(class, "crate") then
        return true
    end

    return false
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    local mode = self:GetClientInfo("mode")
    local mapName = game.GetMap()

    if mode == "save" then
        -- SAVE LOGIC
        local data = {}
        local count = 0

        -- SCAN ALL ENTITIES
        for _, ent in ipairs(ents.GetAll()) do
            if IsValidLootCache(ent) then
                table.insert(data, {
                    pos = ent:GetPos(),
                    ang = ent:GetAngles(),
                    pool = ent:GetNWString("LootPool", "random"),
                    class = ent:GetClass()
                })
                count = count + 1
                -- Debug print to verify
                -- print("[Tarkov Loot] Found: " .. ent:GetClass())
            end
        end

        file.CreateDir("tarkov_data")
        file.Write("tarkov_data/" .. mapName .. ".json", util.TableToJSON(data))

        ply:ChatPrint("[Tarkov Loot] Saved " .. count .. " loot caches.")
        ply:EmitSound("buttons/button14.wav")

    elseif mode == "clear" then
        -- CLEAR LOGIC
        file.Delete("tarkov_data/" .. mapName .. ".json")
        ply:ChatPrint("[Tarkov Loot] Cleared loot data for map.")
        ply:EmitSound("buttons/button10.wav")

    elseif mode == "tag" then
        -- TAG LOGIC
        local ent = trace.Entity
        if IsValidLootCache(ent) then
            local pool = self:GetClientInfo("pool")
            ent:SetNWString("LootPool", pool)

            ply:ChatPrint("[Tarkov Loot] Tagged box (" .. ent:GetClass() .. ") as: " .. pool)
            ply:EmitSound("buttons/blip1.wav")

            local effect = EffectData()
            effect:SetOrigin(ent:GetPos())
            util.Effect("Sparks", effect)
        end
    end

    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    -- Copy Tag from entity (Eyedropper function)
    local ent = trace.Entity
    if IsValidLootCache(ent) then
        local pool = ent:GetNWString("LootPool", "random")
        self:GetOwner():ConCommand("tarkov_loot_pool " .. pool) -- Update client var
        self:GetOwner():ChatPrint("[Tarkov Loot] Copied tag: " .. pool)
    end

    return true
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", { Text = "#tool.tarkov_loot.name", Description = "#tool.tarkov_loot.desc" })

    -- Mode Selector
    local combo = panel:AddControl("ComboBox", { Label = "Operation Mode", Command = "tarkov_loot_mode" })
    combo:AddOption("Save All Caches", { tarkov_loot_mode = "save" })
    combo:AddOption("Clear Map Data", { tarkov_loot_mode = "clear" })
    combo:AddOption("Tag Specific Box", { tarkov_loot_mode = "tag" })

    -- Loot Pool Text Entry
    panel:AddControl("TextBox", { Label = "Loot Pool Tag", Command = "tarkov_loot_pool", MaxLength = "20" })

    -- Quick Tag Buttons
    panel:AddControl("Label", { Text = "Quick Tags:" })

    local function AddTagButton(name)
        local btn = vgui.Create("DButton", panel)
        btn:SetText(name)
        btn:Dock(TOP)
        btn:DockMargin(0, 2, 0, 2)
        btn.DoClick = function()
            RunConsoleCommand("tarkov_loot_pool", name)
        end
        panel:AddItem(btn)
    end

    AddTagButton("random")
    AddTagButton("weapons")
    AddTagButton("ammo")
    AddTagButton("gear")
    AddTagButton("medical")
    AddTagButton("entities")
    AddTagButton("misc")
    AddTagButton("rare")

    panel:AddControl("Label", { Text = "Note: Saving stores all current caches on the map to a file. On restart, the gamemode will re-spawn them." })
end

-- Draw HUD Info for Tagging
function TOOL:DrawHUD()
    if CLIENT then
        local ply = LocalPlayer()
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        -- Check if looking at a valid cache
        -- Note: We duplicate the logic slightly for CLIENT side since IsValidLootCache is local to this file
        -- But since this file is shared, the function exists on client too!
        if IsValidLootCache(ent) then

            -- Draw Halo
            halo.Add({ent}, Color(0, 255, 0), 2, 2, 1, true, true)

            -- Draw Text in Center of Screen
            local tag = ent:GetNWString("LootPool", "random")
            local w, h = ScrW(), ScrH()

            draw.SimpleText("LOOT CACHE", "DermaLarge", w / 2, h / 2 + 40, Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Pool: " .. string.upper(tag), "DermaDefault", w / 2, h / 2 + 65, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end