local TAG = "TarkovHUD"

-- 1. Hide Default HUD
local HIDE_ELEMENTS = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true,
    ["CHudDamageIndicator"] = true -- We have our own logic? Or keep default red flash? Keep default flash for now.
}

hook.Add("HUDShouldDraw", "TarkovHideHUD", function(name)
    if HIDE_ELEMENTS[name] then return false end
end)

-- 2. Draw Custom HUD
local COLOR_BG = Color(20, 20, 20, 200)
local COLOR_HEALTH = Color(200, 50, 50)
local COLOR_STAMINA = Color(50, 200, 50)
local COLOR_WATER = Color(50, 150, 250)
local COLOR_ENERGY = Color(250, 200, 50)

local function DrawBar(x, y, w, h, val, max, color, label)
    local pct = math.Clamp(val / max, 0, 1)
    draw.RoundedBox(4, x, y, w, h, COLOR_BG)
    draw.RoundedBox(4, x + 2, y + 2, (w - 4) * pct, h - 4, color)
    if label then
        draw.SimpleText(label, "DermaDefault", x + w/2, y + h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function GetLimbColor(hp, max)
    local pct = hp / max
    if hp <= 0 then return Color(20, 20, 20, 255) end -- Blacked
    if pct < 0.3 then return Color(200, 0, 0) end -- Critical
    if pct < 0.6 then return Color(200, 200, 0) end -- Hurt
    return Color(0, 200, 0) -- Fine
end

hook.Add("HUDPaint", "TarkovStatusHUD", function()
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    local w, h = ScrW(), ScrH()
    local x = 20
    local y = h - 150

    -- 1. Status Bars (Bottom Left)
    -- Hydration
    local hyd = ply:GetHydration()
    DrawBar(x, y, 150, 15, hyd, 100, COLOR_WATER, "Hydration")

    -- Energy (Hunger)
    y = y + 20
    local hun = ply:GetHunger()
    DrawBar(x, y, 150, 15, hun, 100, COLOR_ENERGY, "Energy")

    -- Stamina
    y = y + 30
    local stam = ply:GetStamina()
    DrawBar(x, y, 200, 20, stam, 100, COLOR_STAMINA, "Stamina")

    -- 2. Paper Doll (Top Left)
    -- Simple representation using boxes
    local dollX = 30
    local dollY = 30
    local boxSize = 25

    -- Head
    draw.RoundedBox(4, dollX + boxSize, dollY, boxSize, boxSize, GetLimbColor(ply:GetHeadHP(), 35))
    -- Thorax
    draw.RoundedBox(4, dollX + boxSize, dollY + boxSize + 2, boxSize, boxSize*1.5, GetLimbColor(ply:GetThoraxHP(), 85))
    -- Stomach
    draw.RoundedBox(4, dollX + boxSize, dollY + boxSize*2.5 + 4, boxSize, boxSize, GetLimbColor(ply:GetStomachHP(), 70))
    -- L Arm
    draw.RoundedBox(4, dollX, dollY + boxSize + 2, boxSize, boxSize*2, GetLimbColor(ply:GetLeftArmHP(), 60))
    -- R Arm
    draw.RoundedBox(4, dollX + boxSize*2 + 2, dollY + boxSize + 2, boxSize, boxSize*2, GetLimbColor(ply:GetRightArmHP(), 60))
    -- L Leg
    draw.RoundedBox(4, dollX + boxSize/2 - 2, dollY + boxSize*3.5 + 6, boxSize, boxSize*2.5, GetLimbColor(ply:GetLeftLegHP(), 65))
    -- R Leg
    draw.RoundedBox(4, dollX + boxSize*1.5 + 2, dollY + boxSize*3.5 + 6, boxSize, boxSize*2.5, GetLimbColor(ply:GetRightLegHP(), 65))

    -- 3. Conditions (Icons/Text next to doll)
    local cx = dollX + boxSize*3 + 10
    local cy = dollY

    local light = ply:GetLightBleeds()
    local heavy = ply:GetHeavyBleeds()
    local fracs = ply:GetFractures()

    if light > 0 then
        draw.SimpleText("Light Bleed", "DermaDefault", cx, cy, Color(255, 100, 100))
        cy = cy + 15
    end
    if heavy > 0 then
        draw.SimpleText("HEAVY BLEED", "DermaDefaultBold", cx, cy, Color(255, 0, 0))
        cy = cy + 15
    end
    if fracs > 0 then
        draw.SimpleText("Fracture", "DermaDefault", cx, cy, Color(200, 200, 200))
        cy = cy + 15
    end
end)
