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
local CACHE_CLASS = "ent_loot_cache" 

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    
    local ply = self:GetOwner()
    local mode = self:GetClientInfo("mode")
    local mapName = game.GetMap()
    
    if mode == "save" then
        -- SAVE LOGIC
        local data = {}
        local caches = ents.FindByClass(CACHE_CLASS)
        
        for _, ent in ipairs(caches) do
            table.insert(data, {
                pos = ent:GetPos(),
                ang = ent:GetAngles(),
                pool = ent:GetNWString("LootPool", "random")
            })
        end
        
        file.CreateDir("tarkov_data")
        file.Write("tarkov_data/" .. mapName .. ".json", util.TableToJSON(data))
        
        ply:ChatPrint("[Tarkov Loot] Saved " .. #data .. " loot caches.")
        ply:EmitSound("buttons/button14.wav")
        
    elseif mode == "clear" then
        -- CLEAR LOGIC
        file.Delete("tarkov_data/" .. mapName .. ".json")
        ply:ChatPrint("[Tarkov Loot] Cleared loot data for map.")
        ply:EmitSound("buttons/button10.wav")
        
    elseif mode == "tag" then
        -- TAG LOGIC
        local ent = trace.Entity
        if IsValid(ent) and ent:GetClass() == CACHE_CLASS then
            local pool = self:GetClientInfo("pool")
            ent:SetNWString("LootPool", pool)
            
            ply:ChatPrint("[Tarkov Loot] Tagged box as: " .. pool)
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
    if IsValid(ent) and ent:GetClass() == CACHE_CLASS then
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
    AddTagButton("medical")
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
        if IsValid(ent) and ent:GetClass() == CACHE_CLASS then
            
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