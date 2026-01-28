AddCSLuaFile()

SWEP.PrintName = "Loot Manager"
SWEP.Author = "Tarkov Dev"
SWEP.Purpose = "Save/Clear Loot Positions"
SWEP.Instructions = "Reload: Save ALL Loot Caches to File. Secondary: Clear ALL Saved Data for Map."

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 5
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"

if SERVER then
    -- Save Data to JSON
    function SWEP:Reload()
        if not self.Owner:IsSuperAdmin() then return end
        if (self.NextSave or 0) > CurTime() then return end
        self.NextSave = CurTime() + 2

        local mapName = game.GetMap()
        local data = {}

        -- Find all loot entities (both placed via tool and manually spawned)
        local count = 0
        local classes = {
            ["ent_loot_cache"] = true,
            ["item_item_crate"] = true,
            ["sent_lootbox"] = true,
            ["sim_loot_crate"] = true
        }

        for _, ent in ipairs(ents.GetAll()) do
            if classes[ent:GetClass()] or ent.IsTarkovLoot then
                -- Only save if it's meant to be persistent (usually we'd tag them, but let's save all for now)
                local entry = {
                    pos = ent:GetPos(),
                    ang = ent:GetAngles(),
                    class = ent:GetClass(),
                    pool = ent:GetNWString("LootPool", "random")
                }
                table.insert(data, entry)
                count = count + 1
            end
        end

        if not file.Exists("tarkov_data", "DATA") then file.CreateDir("tarkov_data") end
        file.Write("tarkov_data/" .. mapName .. ".json", util.TableToJSON(data, true))

        self.Owner:ChatPrint("[Tarkov Loot] Saved " .. count .. " loot caches for " .. mapName)
        self.Owner:EmitSound("buttons/button14.wav")
    end

    -- Clear Data
    function SWEP:SecondaryAttack()
        if not self.Owner:IsSuperAdmin() then return end
        if (self.NextClear or 0) > CurTime() then return end
        self.NextClear = CurTime() + 2

        local mapName = game.GetMap()
        if file.Exists("tarkov_data/" .. mapName .. ".json", "DATA") then
            file.Delete("tarkov_data/" .. mapName .. ".json")
            self.Owner:ChatPrint("[Tarkov Loot] CLEARED saved data for " .. mapName)
            self.Owner:EmitSound("buttons/button10.wav")
        else
            self.Owner:ChatPrint("[Tarkov Loot] No saved data found for this map.")
        end
    end

    function SWEP:PrimaryAttack()
         -- Placeholder
    end
end
