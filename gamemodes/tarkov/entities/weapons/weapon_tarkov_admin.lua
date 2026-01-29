SWEP.PrintName = "Tarkov Loot Manager"
SWEP.Author = "Senior Lua Engineer"
SWEP.Instructions = "L-Click: Action | R-Click: Open Menu | Reload: Cycle Pool"
SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.UseHands = true

-- CONFIG: The class name of the workshop entity you are using
local CACHE_CLASS = "ent_loot_cache"

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("vgui/gmod_tool")
    SWEP.BounceWeaponIcon = false
end

if SERVER then
    util.AddNetworkString("TarkovAdmin_SetPool")
    util.AddNetworkString("TarkovAdmin_Action")
end

function SWEP:Initialize()
    self:SetHoldType("pistol")
end

function SWEP:SetupDataTables()
    self:NetworkVar("String", 0, "Mode")
    self:NetworkVar("String", 1, "SelectedPool")

    if SERVER then
        self:SetMode("save")
        self:SetSelectedPool("random")
    end
end

-- Safe accessors
function SWEP:GetToolMode()
    if self.GetMode then return self:GetMode() end
    return "save"
end

function SWEP:GetToolPool()
    if self.GetSelectedPool then return self:GetSelectedPool() end
    return "random"
end

function SWEP:SetToolMode(mode)
    if self.SetMode then self:SetMode(mode) end
end

function SWEP:SetToolPool(pool)
    if self.SetSelectedPool then self:SetSelectedPool(pool) end
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local mode = self:GetToolMode()
    local mapName = game.GetMap()

    if mode == "save" then
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

        self.Owner:ChatPrint("[Tarkov Admin] SAVED " .. #data .. " loot caches.")
        self:EmitSound("buttons/button14.wav")

    elseif mode == "clear" then
        file.Delete("tarkov_data/" .. mapName .. ".json")
        self.Owner:ChatPrint("[Tarkov Admin] CLEARED save data for map.")
        self:EmitSound("buttons/button10.wav")

    elseif mode == "tag" then
        local tr = self.Owner:GetEyeTrace()
        local ent = tr.Entity

        if IsValid(ent) and ent:GetClass() == CACHE_CLASS then
            local pool = self:GetToolPool()
            ent:SetNWString("LootPool", pool)
            self.Owner:ChatPrint("[Tarkov Admin] Tagged box as: " .. pool)
            self:EmitSound("buttons/blip1.wav")

            local effect = EffectData()
            effect:SetOrigin(ent:GetPos())
            util.Effect("Sparks", effect)
        end
    end

    self:SetNextPrimaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
    -- We handle the menu in CLIENT hook
    return false
end

function SWEP:Reload()
    if CLIENT then return end
    local pools = {"random", "weapons", "medical", "misc", "rare"}
    local current = self:GetToolPool()
    local nextPool = pools[1]

    for i, p in ipairs(pools) do
        if p == current then
            nextPool = pools[(i % #pools) + 1]
            break
        end
    end

    self:SetToolPool(nextPool)
    self.Owner:ChatPrint("[Tool] Quick Select: " .. nextPool)
    self:EmitSound("buttons/lightswitch2.wav")
    self:SetNextReload(CurTime() + 0.5)
end

if SERVER then
    net.Receive("TarkovAdmin_SetPool", function(len, ply)
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_tarkov_admin" then
            local pool = net.ReadString()
            wep:SetToolPool(pool)
        end
    end)

    net.Receive("TarkovAdmin_Action", function(len, ply)
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_tarkov_admin" then
            local mode = net.ReadString()
            wep:SetToolMode(mode)
            ply:ChatPrint("[Tool] Switched to mode: " .. string.upper(mode))
        end
    end)
end

if CLIENT then
    function SWEP:DrawHUD()
        local mode = "save"
        if self.GetToolMode then mode = self:GetToolMode() end

        local pool = "random"
        if self.GetToolPool then pool = self:GetToolPool() end

        draw.SimpleText("Mode: " .. string.upper(mode), "DermaLarge", ScrW() - 200, ScrH() - 150, Color(255, 200, 50), TEXT_ALIGN_RIGHT)
        if mode == "tag" then
            draw.SimpleText("Pool: " .. string.upper(pool), "DermaDefault", ScrW() - 200, ScrH() - 110, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
        end

        local tr = LocalPlayer():GetEyeTrace()
        if IsValid(tr.Entity) and tr.Entity:GetClass() == CACHE_CLASS then
            local ent = tr.Entity
            local tag = ent:GetNWString("LootPool", "random")
            local pos = ent:GetPos():ToScreen()

            draw.SimpleText(tag, "DermaLarge", pos.x, pos.y, Color(0, 255, 0), TEXT_ALIGN_CENTER)
        end
    end

    local frame = nil

    local function OpenToolMenu()
        if IsValid(frame) then frame:Remove() end

        local wep = LocalPlayer():GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_tarkov_admin" then return end

        frame = vgui.Create("DFrame")
        frame:SetSize(300, 300)
        frame:SetPos(ScrW() - 320, 100)
        frame:SetTitle("Loot Manager Settings")
        frame:MakePopup() -- Enable mouse
        frame:SetKeyboardInputEnabled(true) -- Enable typing
        frame:ShowCloseButton(true)

        -- Override OnClose to ensure we don't get stuck
        frame.OnClose = function()
            frame = nil
        end

        local pnl = vgui.Create("DPanel", frame)
        pnl:Dock(FILL)
        pnl.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40, 200)) end

        -- Mode Selection
        local label = vgui.Create("DLabel", pnl)
        label:SetText("Tool Mode:")
        label:Dock(TOP)
        label:DockMargin(5, 5, 5, 0)

        local combo = vgui.Create("DComboBox", pnl)
        combo:Dock(TOP)
        combo:DockMargin(5, 5, 5, 10)
        combo:AddChoice("Save Loot Positions", "save")
        combo:AddChoice("Clear Map Data", "clear")
        combo:AddChoice("Tag Loot Boxes", "tag")

        local curMode = "save"
        if wep.GetToolMode then curMode = wep:GetToolMode() end

        if curMode == "save" then combo:ChooseOptionID(1)
        elseif curMode == "clear" then combo:ChooseOptionID(2)
        elseif curMode == "tag" then combo:ChooseOptionID(3) end

        combo.OnSelect = function(self, index, value, data)
            net.Start("TarkovAdmin_Action")
            net.WriteString(data)
            net.SendToServer()
        end

        -- Loot Pool Entry
        local label2 = vgui.Create("DLabel", pnl)
        label2:SetText("Loot Pool Tag:")
        label2:Dock(TOP)
        label2:DockMargin(5, 10, 5, 0)

        local entry = vgui.Create("DTextEntry", pnl)
        entry:Dock(TOP)
        entry:DockMargin(5, 5, 5, 10)

        local curPool = "random"
        if wep.GetToolPool then curPool = wep:GetToolPool() end
        entry:SetText(curPool)

        entry.OnEnter = function(self)
            net.Start("TarkovAdmin_SetPool")
            net.WriteString(self:GetValue())
            net.SendToServer()
        end

        -- Update on change too, not just enter
        entry.OnChange = function(self)
             net.Start("TarkovAdmin_SetPool")
             net.WriteString(self:GetValue())
             net.SendToServer()
        end

        -- Quick Buttons
        local grid = vgui.Create("DIconLayout", pnl)
        grid:Dock(FILL)
        grid:SetSpaceX(5)
        grid:SetSpaceY(5)
        grid:DockMargin(5, 5, 5, 5)

        local common = {"random", "weapons", "medical", "misc", "rare"}
        for _, p in ipairs(common) do
            local btn = grid:Add("DButton")
            btn:SetText(p)
            btn:SetSize(85, 25)
            btn.DoClick = function()
                net.Start("TarkovAdmin_SetPool")
                net.WriteString(p)
                net.SendToServer()
                entry:SetText(p)
            end
        end
    end

    -- Open menu on Right Click
    function SWEP:SecondaryAttack()
        if IsFirstTimePredicted() then
            OpenToolMenu()
        end
        return true
    end

    -- Also hook C-menu for alternate opening style if preferred
    hook.Add("ContextMenuOpen", "TarkovAdminMenu_OpenC", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_tarkov_admin" then
            OpenToolMenu()
            return false -- Prevent default C menu from stealing focus if you want exclusive control
        end
    end)

    -- Cleanup on weapon switch
    function SWEP:Holster()
        if IsValid(frame) then frame:Remove() end
        return true
    end
end