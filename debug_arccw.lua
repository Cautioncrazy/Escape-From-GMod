if SERVER then
    print("\n--- DEBUG ARCCW TABLE ---")
    if ArcCW and ArcCW.AttachmentTable then
        local count = 0
        for k, v in pairs(ArcCW.AttachmentTable) do
            count = count + 1
            if count <= 5 then
                print("ShortName: " .. k)
                print("  Entity: " .. tostring(v.Entity))
                print("  Model: " .. tostring(v.Model))
            end
        end
        print("Total ArcCW Atts: " .. count)
    else
        print("ArcCW not found or AttachmentTable missing.")
    end

    print("\n--- DEBUG SCRIPTED ENTS ---")
    local count = 0
    for k, v in pairs(scripted_ents.GetList()) do
        if string.find(k, "arccw") then
            count = count + 1
            if count <= 5 then
                print("Class: " .. k)
                print("  Model: " .. tostring(v.t.Model))
            end
        end
    end
    print("Total ArcCW Ents: " .. count)
end
