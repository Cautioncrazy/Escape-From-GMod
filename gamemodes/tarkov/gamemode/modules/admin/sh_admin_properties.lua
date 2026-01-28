AddCSLuaFile()

properties.Add("tarkov_god", {
    MenuLabel = "Toggle God Mode",
    Order = 1000,
    MenuIcon = "icon16/shield.png",
    Filter = function(self, ent, ply)
        return IsValid(ent) and ent:IsPlayer() and ply:IsSuperAdmin()
    end,
    Action = function(self, ent)
        self:MsgStart()
            net.WriteEntity(ent)
        self:MsgEnd()
    end,
    Receive = function(self, length, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) or not ply:IsSuperAdmin() then return end

        if ent:HasGodMode() then
            ent:GodDisable()
            ply:ChatPrint("God Mode DISABLED for " .. ent:Nick())
        else
            ent:GodEnable()
            ply:ChatPrint("God Mode ENABLED for " .. ent:Nick())
        end
    end
})

properties.Add("tarkov_ignore", {
    MenuLabel = "Toggle Ignore (NoTarget)",
    Order = 1001,
    MenuIcon = "icon16/user_gray.png",
    Filter = function(self, ent, ply)
        return IsValid(ent) and ent:IsPlayer() and ply:IsSuperAdmin()
    end,
    Action = function(self, ent)
        self:MsgStart()
            net.WriteEntity(ent)
        self:MsgEnd()
    end,
    Receive = function(self, length, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) or not ply:IsSuperAdmin() then return end

        local current = ent:GetNoTarget()
        ent:SetNoTarget(not current)

        if not current then
             ply:ChatPrint(ent:Nick() .. " is now IGNORED by NPCs.")
        else
             ply:ChatPrint(ent:Nick() .. " is VISIBLE to NPCs.")
        end
    end
})
