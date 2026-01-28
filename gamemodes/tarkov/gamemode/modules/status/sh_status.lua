local TAG = "TarkovStatus"

hook.Add("SetupDataTables", "TarkovStatusDT", function(ply)
    -- Survival
    ply:NetworkVar("Float", 0, "Hunger")
    ply:NetworkVar("Float", 1, "Hydration")
    ply:NetworkVar("Float", 2, "Stamina")

    -- Limb Health
    ply:NetworkVar("Float", 3, "HeadHP")
    ply:NetworkVar("Float", 4, "ThoraxHP")
    ply:NetworkVar("Float", 5, "StomachHP")
    ply:NetworkVar("Float", 6, "LeftArmHP")
    ply:NetworkVar("Float", 7, "RightArmHP")
    ply:NetworkVar("Float", 8, "LeftLegHP")
    ply:NetworkVar("Float", 9, "RightLegHP")

    -- Conditions (Bitmasks)
    -- 1=Head, 2=Thorax, 4=Stomach, 8=LA, 16=RA, 32=LL, 64=RL
    ply:NetworkVar("Int", 0, "LightBleeds")
    ply:NetworkVar("Int", 1, "HeavyBleeds")
    ply:NetworkVar("Int", 2, "Fractures")
end)

if CLIENT then
    hook.Add("InitPostEntity", "TarkovStatusInit", function()
        -- Request full update if needed
        local ply = LocalPlayer()
        if IsValid(ply) and not ply.GetHeadHP then
            hook.Run("SetupDataTables", ply)
        end
    end)
end

-- Stamina Logic (Shared for Prediction)
local STAMINA_DRAIN_JUMP = 15

hook.Add("SetupMove", "TarkovStaminaMove", function(ply, mv, cmd)
    if not ply:Alive() then return end

    -- Check if we have the methods (in case shared loading delayed)
    if not ply.GetStamina then return end

    local current = ply:GetStamina()
    local max = 100
    local drain = 0
    local regen = 0.5 -- Base regen per tick (approx 33/sec) -> 3s to full

    -- Sprinting
    if mv:KeyDown(IN_SPEED) and mv:GetVelocity():Length2D() > 10 then
        if current > 0 then
            drain = 0.2 -- ~13 stamina/sec
            regen = 0
        else
            -- Cannot sprint
            local walk = ply:GetWalkSpeed()
            mv:SetMaxSpeed(walk)
            mv:SetMaxClientSpeed(walk)
        end
    end

    -- Jumping
    if mv:KeyPressed(IN_JUMP) and ply:OnGround() then
        if current >= STAMINA_DRAIN_JUMP then
            drain = drain + STAMINA_DRAIN_JUMP
            regen = 0
        else
            -- Cannot jump
            local buttons = mv:GetButtons()
            buttons = bit.band(buttons, bit.bnot(IN_JUMP))
            mv:SetButtons(buttons)
        end
    end

    -- Apply changes
    if drain > 0 then
        ply:SetStamina(math.max(0, current - drain))
        -- Delay regen
        ply.NextStaminaRegen = CurTime() + 1.5
    elseif (ply.NextStaminaRegen or 0) < CurTime() then
        -- Regen
        if current < max then
            -- Slower regen if moving
            if mv:GetVelocity():Length2D() > 10 then
                regen = 0.1 -- Slower regen while walking
            end
            ply:SetStamina(math.min(max, current + regen))
        end
    end
end)
