AddCSLuaFile()

if SERVER then
    -- Network strings to communicate slider changes
    util.AddNetworkString("UpdateSunPosition")

    -- Global references to avoid expensive FindByClass calls every tick
    local g_ShadowProjector = nil
    local g_SkyLight = nil
    local g_SkyPaint = nil
    
    -- State variables for caching (Prevents "Flickering" from spamming inputs)
    local g_CurrentTime = 0.5
    local g_RayTracing = false
    local g_AutoCycle = false
    local g_CycleDuration = 240 -- 4 minutes in seconds
    
    -- Cache for change detection
    local g_LastPattern = ""
    local g_LastNightState = nil -- nil forces first update

    -- Helper to find entities once or refresh if invalid
    local function RefreshEntities()
        if not IsValid(g_SkyLight) then g_SkyLight = ents.FindByClass("light_environment")[1] end
        if not IsValid(g_SkyPaint) then g_SkyPaint = ents.FindByClass("env_skypaint")[1] end
    end

    -- Function to actually move the sun and change lighting
    local function SetTime(timeRatio, enableRayTracing)
        -- Refresh entities cache
        RefreshEntities()
        
        -- 24-HOUR CYCLE MATH
        -- TimeRatio: 0.0 (Midnight) -> 0.5 (Noon) -> 1.0 (Midnight)
        
        -- Calculate Pitch (Sun Angle)
        local pitch = 90 - (timeRatio * 360)
        local yaw = 90
        
        local sunAng = Angle(pitch, yaw, 0)
        local sunVec = sunAng:Forward()
        local isNight = (pitch > 0) -- Pitch > 0 means sun is below horizon
        
        -- HANDLE SUN SPRITES (env_sun)
        -- We handle this specifically to stop flickering. 
        -- We only Fire("TurnOn/Off") if the state (Day/Night) actually changes.
        local allSuns = ents.FindByClass("env_sun")
        for _, sun in pairs(allSuns) do
            if IsValid(sun) then
                sun:SetAngles(sunAng)
                -- Only update vector keyvalue, don't spam it if not needed, 
                -- but SetKeyValue is fast enough for movement.
                local vecStr = string.format("%f %f %f", sunVec.x, sunVec.y, sunVec.z)
                sun:SetKeyValue("sun_dir", vecStr)
                sun:Activate()
                
                -- STATE CHECK: Only Fire inputs if night state changed to prevent flickering
                if g_LastNightState ~= isNight then
                    if isNight then 
                        sun:Fire("TurnOff")
                    else
                        sun:Fire("TurnOn")
                    end
                end
            end
        end
        -- Update cache
        g_LastNightState = isNight
        
        -- Calculate Brightness
        local rawBrightness = math.max(0, math.sin((timeRatio - 0.25) * 2 * math.pi))
        
        -- Apply steep curve for darkness
        local effectiveBrightness = math.pow(rawBrightness, 3)

        -- Update Sky Light
        if IsValid(g_SkyLight) then
            local charIndex = 97
            if effectiveBrightness > 0 then
                charIndex = 97 + math.floor(effectiveBrightness * 10)
            end
            local pattern = string.char(charIndex) 
            
            -- STATE CHECK: Only set pattern if it changed
            if g_LastPattern ~= pattern then
                g_SkyLight:Fire("SetPattern", pattern)
                g_SkyLight:Activate()
                g_LastPattern = pattern
            end
        end

        -- Update Sky Paint (Visual Skybox)
        local lightSourceVec = sunVec 
        local moonVec = sunVec * -1
        
        -- Determine dominant light source
        if effectiveBrightness <= 0.001 then
            lightSourceVec = moonVec
        else
            lightSourceVec = sunVec
        end
        
        if IsValid(g_SkyPaint) then
            local skyBlue = Vector(0.2, 0.5, 1.0)
            local skyDark = Vector(0.0, 0.0, 0.0)
            local sunYellow = Vector(1.0, 1.0, 0.8)
            local sunOrange = Vector(1.0, 0.4, 0.0)

            -- Interpolate Sky Color
            g_SkyPaint:SetTopColor(LerpVector(effectiveBrightness, skyDark, skyBlue))
            g_SkyPaint:SetBottomColor(LerpVector(effectiveBrightness, skyDark, Vector(0.8, 0.9, 1.0)))
            
            -- CUSTOM SUN/MOON LOGIC
            if effectiveBrightness <= 0.001 then
                -- NIGHT: Show Moon
                g_SkyPaint:SetSunNormal(moonVec)
                g_SkyPaint:SetSunColor(Vector(1, 1, 1)) -- White Moon
                g_SkyPaint:SetSunSize(0.05) 
            else
                -- DAY: Show Sun
                g_SkyPaint:SetSunNormal(sunVec)
                local baseSunColor = LerpVector(rawBrightness, sunOrange, sunYellow)
                g_SkyPaint:SetSunColor(baseSunColor * rawBrightness)
                g_SkyPaint:SetSunSize(0.20) 
            end
            
            -- Dusk Logic
            local duskAmount = (1 - rawBrightness) * math.Clamp(rawBrightness * 4, 0, 1)
            g_SkyPaint:SetDuskScale(duskAmount)
            g_SkyPaint:SetDuskIntensity(duskAmount)
            g_SkyPaint:SetDuskColor(Vector(1.0, 0.2, 0.0))
            
            -- Stars
            if effectiveBrightness < 0.1 then
                g_SkyPaint:SetStarScale(2.0)
                g_SkyPaint:SetStarTexture("skybox/starfield")
                g_SkyPaint:SetStarFade(2.0)
            else
                g_SkyPaint:SetStarScale(0)
                g_SkyPaint:SetStarFade(0)
            end
        end

        -- --- RAYTRACED LIGHTING (Projected Texture) ---
        if enableRayTracing then
            if not IsValid(g_ShadowProjector) then
                g_ShadowProjector = ents.Create("env_projectedtexture")
                g_ShadowProjector:SetPos(Vector(0, 0, 16000))
                g_ShadowProjector:SetKeyValue("enableshadows", 1)
                g_ShadowProjector:SetKeyValue("nearz", 100)
                g_ShadowProjector:SetKeyValue("farz", 32000)
                g_ShadowProjector:SetKeyValue("lightfov", 100)
                g_ShadowProjector:SetKeyValue("lightworld", 1)
                g_ShadowProjector:Spawn()
                g_ShadowProjector:Fire("SetTexture", "effects/flashlight001")
            end

            -- CALCULATE CORRECT SHADOW ANGLE
            local shadowDir = lightSourceVec * -1
            g_ShadowProjector:SetAngles(shadowDir:Angle())
            
            if isNight then
                -- MOON LIGHT
                local moonColor = Vector(0.2, 0.3, 0.5) * 50 
                g_ShadowProjector:SetKeyValue("lightcolor", string.format("%f %f %f 255", moonColor.x, moonColor.y, moonColor.z))
            else
                -- SUN LIGHT
                local c = IsValid(g_SkyPaint) and g_SkyPaint:GetSunColor() or Vector(1,1,0.8)
                local intensity = 255 * effectiveBrightness
                g_ShadowProjector:SetKeyValue("lightcolor", string.format("%f %f %f 255", c.x * intensity, c.y * intensity, c.z * intensity))
            end
        else
            if IsValid(g_ShadowProjector) then
                g_ShadowProjector:Remove()
            end
        end
    end

    -- Automatic Cycle Logic
    hook.Add("Think", "SunCycleThink", function()
        if g_AutoCycle then
            -- Advance time based on frame time and cycle duration
            local dt = FrameTime()
            g_CurrentTime = g_CurrentTime + (dt / g_CycleDuration)
            
            -- Loop around at midnight
            if g_CurrentTime >= 1.0 then g_CurrentTime = 0.0 end
            
            SetTime(g_CurrentTime, g_RayTracing)
        end
    end)

    -- Listener for Client Requests
    net.Receive("UpdateSunPosition", function(len, ply)
        -- Security Check
        if IsValid(ply) and not ply:IsAdmin() then return end
        
        local time = net.ReadFloat()
        local rt = net.ReadBool()
        local auto = net.ReadBool()
        
        g_CurrentTime = time
        g_RayTracing = rt
        g_AutoCycle = auto
        
        SetTime(g_CurrentTime, g_RayTracing)
    end)
end

if CLIENT then
    -- Use list.Set to add an icon to the Context Menu Desktop
    list.Set( "DesktopWindows", "TimeEditor", {
        title = "Time Editor",
        icon = "icon16/time.png",
        width = 300,
        height = 160, 
        onewindow = true,
        init = function( icon, window )
            window:SetTitle("Time of Day Editor")
            
            local currentTime = 0.5
            local currentRT = false
            local currentAuto = false

            local slider = vgui.Create("DNumSlider", window)
            slider:SetPos(10, 30)
            slider:SetSize(280, 40)
            slider:SetText("24h Time") 
            slider:SetMin(0)
            slider:SetMax(1)
            slider:SetDecimals(2)
            slider:SetValue(currentTime) 
            
            local checkAuto = vgui.Create("DCheckBoxLabel", window)
            checkAuto:SetPos(10, 70)
            checkAuto:SetText("Enable 4-Minute Day/Night Cycle")
            checkAuto:SetValue(currentAuto)
            checkAuto:SizeToContents()
            
            local checkbox = vgui.Create("DCheckBoxLabel", window)
            checkbox:SetPos(10, 100)
            checkbox:SetText("Enable Raytraced Lighting (High Cost)")
            checkbox:SetTextColor(Color(255,100,100))
            checkbox:SetValue(currentRT)
            checkbox:SizeToContents()

            local function SendUpdate()
                net.Start("UpdateSunPosition")
                net.WriteFloat(currentTime)
                net.WriteBool(currentRT)
                net.WriteBool(currentAuto)
                net.SendToServer()
            end

            slider.OnValueChanged = function(self, value)
                currentTime = value
                SendUpdate()
            end

            checkAuto.OnChange = function(self, value)
                currentAuto = value
                SendUpdate()
            end

            checkbox.OnChange = function(self, value)
                currentRT = value
                SendUpdate()
            end
        end
    } )
end