-- gamemodes/tarkov/gamemode/modules/inventory/cl_attachments.lua
-- Integration with ArcCW Client Side to show inventory counts

hook.Add("InitPostEntity", "TarkovArcCWClientShim", function()
    -- Wait a frame to ensure ArcCW is fully loaded
    timer.Simple(1, function()
        if not ArcCW then return end
        print("[Tarkov] Injecting ArcCW Inventory Shim...")

        -- ArcCW 2.0 / Modern usually uses ArcCW.PlayerGetAtts
        if ArcCW.PlayerGetAtts then
            local oldGetAtts = ArcCW.PlayerGetAtts

            -- Detour
            ArcCW.PlayerGetAtts = function(self, ply, att)
                local count = 0
                -- Call original if it exists (handles free attachments or other logic)
                if oldGetAtts then
                    count = oldGetAtts(self, ply, att) or 0
                end

                -- If checking LocalPlayer (UI usually does), add our inventory counts
                if IsValid(ply) and ply == LocalPlayer() then
                    if ply.TarkovData and ply.TarkovData.Containers then
                        -- scan containers
                        for cName, items in pairs(ply.TarkovData.Containers) do
                            for _, id in pairs(items) do
                                if id == att then
                                    count = count + 1
                                end
                            end
                        end
                    end
                end

                return count
            end
            print("[Tarkov] ArcCW.PlayerGetAtts detoured successfully.")
        else
            print("[Tarkov] ArcCW.PlayerGetAtts NOT FOUND. ArcCW Integration may fail.")
        end
    end)
end)

-- Arc9 Shim
hook.Add("InitPostEntity", "TarkovArc9ClientShim", function()
     timer.Simple(1, function()
        if not ARC9 then return end
        print("[Tarkov] Injecting Arc9 Inventory Shim...")

        if ARC9.GetAttCount then
            local oldGetAttCount = ARC9.GetAttCount
            ARC9.GetAttCount = function(self, att)
                 local count = oldGetAttCount(self, att) or 0
                 local ply = LocalPlayer()
                 if IsValid(ply) and ply.TarkovData and ply.TarkovData.Containers then
                      for cName, items in pairs(ply.TarkovData.Containers) do
                           for _, id in pairs(items) do
                                if id == att then count = count + 1 end
                           end
                      end
                 end
                 return count
            end
            print("[Tarkov] ARC9.GetAttCount detoured successfully.")
        end
    end)
end)
