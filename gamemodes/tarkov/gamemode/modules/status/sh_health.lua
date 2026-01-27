TARKOV_LIMBS = {
    HEAD = 1,
    THORAX = 2,
    STOMACH = 4,
    L_ARM = 8,
    R_ARM = 16,
    L_LEG = 32,
    R_LEG = 64
}

TARKOV_LIMB_NAMES = {
    [1] = "Head",
    [2] = "Thorax",
    [4] = "Stomach",
    [8] = "L. Arm",
    [16] = "R. Arm",
    [32] = "L. Leg",
    [64] = "R. Leg"
}

TARKOV_MAX_HP = {
    [1] = 35,
    [2] = 85,
    [4] = 70,
    [8] = 60,
    [16] = 60,
    [32] = 65,
    [64] = 65
}

-- Mapping GMod HitGroups to our limbs
TARKOV_HITGROUP_MAP = {
    [HITGROUP_HEAD] = 1,
    [HITGROUP_CHEST] = 2,
    [HITGROUP_STOMACH] = 4,
    [HITGROUP_LEFTARM] = 8,
    [HITGROUP_RIGHTARM] = 16,
    [HITGROUP_LEFTLEG] = 32,
    [HITGROUP_RIGHTLEG] = 64,
    -- Fallbacks
    [HITGROUP_GENERIC] = 2,
    [HITGROUP_GEAR] = 2
}

-- Accessors for Player
local meta = FindMetaTable("Player")

function meta:GetLimbHP(limbFlag)
    if limbFlag == 1 then return self:GetHeadHP() end
    if limbFlag == 2 then return self:GetThoraxHP() end
    if limbFlag == 4 then return self:GetStomachHP() end
    if limbFlag == 8 then return self:GetLeftArmHP() end
    if limbFlag == 16 then return self:GetRightArmHP() end
    if limbFlag == 32 then return self:GetLeftLegHP() end
    if limbFlag == 64 then return self:GetRightLegHP() end
    return 0
end

function meta:SetLimbHP(limbFlag, val)
    if limbFlag == 1 then self:SetHeadHP(val) end
    if limbFlag == 2 then self:SetThoraxHP(val) end
    if limbFlag == 4 then self:SetStomachHP(val) end
    if limbFlag == 8 then self:SetLeftArmHP(val) end
    if limbFlag == 16 then self:SetRightArmHP(val) end
    if limbFlag == 32 then self:SetLeftLegHP(val) end
    if limbFlag == 64 then self:SetRightLegHP(val) end
end
