if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Wait 8 seconds to ensure UE Ragebot and other executors fully load and initialize their camera hooks before scar.lol loads
task.wait(8)
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local rs = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local function tween(object, properties, duration, style, direction)
    style = style or Enum.EasingStyle.Quad
    direction = direction or Enum.EasingDirection.Out
    local info = TweenInfo.new(duration or 0.2, style, direction)
    local t = TweenService:Create(object, info, properties)
    t:Play()
    return t
end

-- Cleanup previous instances if re-executed
local targetGuiParent = (gethui and gethui()) or CoreGui
for _, child in ipairs(targetGuiParent:GetChildren()) do
    if child.Name == "scarGui" then
        child:Destroy()
    end
end

local configFileName = "scar_lol_config.json"
local defaultConfig = {
    voidActive = false,
    orbitActive = false,
    autoExecute = false,
    espActive = false,
    aaActive = false,
    tpActive = false,
    crouchActive = false,
    riotActive = false
}

local hrp
local clientc
local clientv
local clientva
local voidConnection1
local orbitConnection
local voidActive, orbitActive, autoExecute = false, false, false
local espActive, aaActive, tpActive, crouchActive, riotActive = false, false, false, false, false
local espConn, aaConn, tpConn, crouchConn, riotConn
local espFolder = Instance.new("Folder", scarGui)
espFolder.Name = "ESP"
local function loadConfig()
    local success, result = pcall(function()
        if isfile and not isfile(configFileName) then error("File not found") end
        return HttpService:JSONDecode(readfile(configFileName))
    end)
    if success and type(result) == "table" then
        return result
    end
    return defaultConfig
end

local function saveConfig()
    if writefile then
        local data = {
            voidActive = voidActive,
            orbitActive = orbitActive,
            autoExecute = autoExecute,
            espActive = espActive,
            aaActive = aaActive,
            tpActive = tpActive,
            crouchActive = crouchActive,
            riotActive = riotActive
        }
        pcall(function()
            writefile(configFileName, HttpService:JSONEncode(data))
        end)
    end
end

local function getVoidValue()
    local val = math.random(1147483646, 2147483646)
    return math.random() > 0.5 and val or -val
end

-- Create the ScreenGui
local scarGui = Instance.new("ScreenGui")
scarGui.Name = "scarGui"
scarGui.ResetOnSpawn = false

-- Try to protect the GUI if the executor supports it
if syn and syn.protect_gui then
    syn.protect_gui(scarGui)
    scarGui.Parent = CoreGui
elseif gethui then
    scarGui.Parent = gethui()
else
    scarGui.Parent = CoreGui
end

-- Main Background Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = scarGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20) -- Sleek dark
MainFrame.BackgroundTransparency = 0.1
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -200)
MainFrame.Size = UDim2.new(0, 0, 0, 0) -- Starts closed
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Animated Glowing Border
local MainStroke = Instance.new("UIStroke")
MainStroke.Parent = MainFrame
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Transparency = 0.2

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Parent = MainStroke
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 60, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 60, 255))
})

local strokeConn
strokeConn = rs.RenderStepped:Connect(function(dt)
    if not MainFrame or not MainFrame.Parent then
        strokeConn:Disconnect()
        return
    end
    local currentRotation = StrokeGradient.Rotation
    StrokeGradient.Rotation = (currentRotation + (dt * 150)) % 360
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Title "scar.lol"
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1.000
Title.Position = UDim2.new(0, 0, 0, 15)
Title.Size = UDim2.new(1, 0, 0, 20)
Title.Font = Enum.Font.GothamBold
Title.Text = "scar.lol"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18.000

-- Auto Execute Button
local AutoButton = Instance.new("TextButton")
AutoButton.Name = "AutoButton"
AutoButton.Parent = MainFrame
AutoButton.BackgroundTransparency = 1.000
AutoButton.Position = UDim2.new(0, 5, 0, 5)
AutoButton.Size = UDim2.new(0, 40, 0, 20)
AutoButton.Font = Enum.Font.GothamBold
AutoButton.Text = "AUTO"
AutoButton.TextColor3 = Color3.fromRGB(150, 150, 150)
AutoButton.TextSize = 12.000

AutoButton.MouseEnter:Connect(function()
    tween(AutoButton, {TextColor3 = Color3.fromRGB(200, 200, 255)})
end)

AutoButton.MouseLeave:Connect(function()
    if autoExecute then
        tween(AutoButton, {TextColor3 = Color3.fromRGB(180, 140, 255)})
    else
        tween(AutoButton, {TextColor3 = Color3.fromRGB(150, 150, 150)})
    end
end)

local function applyQueueOnTeleport()
    if autoExecute then
        local env = (getgenv and getgenv()) or getfenv(0)
        local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or env.queue_on_teleport or env.queueonteleport
        if qot then
            -- Bypass GitHub cache using a randomized query parameter
            local code = [[
                loadstring(game:HttpGet("https://raw.githubusercontent.com/voidedryann-droid/scar/refs/heads/main/rivals.lua?t=" .. tostring(tick())))()
            ]]
            pcall(function() qot(code) end)
        end
    end
end

AutoButton.MouseButton1Click:Connect(function()
    autoExecute = not autoExecute
    if autoExecute then
        tween(AutoButton, {TextColor3 = Color3.fromRGB(180, 140, 255)})
        applyQueueOnTeleport()
    else
        tween(AutoButton, {TextColor3 = Color3.fromRGB(150, 150, 150)})
    end
    saveConfig()
end)

-- Close Button (Unload)
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Parent = MainFrame
CloseButton.BackgroundTransparency = 1.000
CloseButton.Position = UDim2.new(1, -25, 0, 5)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(150, 150, 150)
CloseButton.TextSize = 14.000

CloseButton.MouseEnter:Connect(function()
    tween(CloseButton, {TextColor3 = Color3.fromRGB(255, 100, 100)})
end)

CloseButton.MouseLeave:Connect(function()
    tween(CloseButton, {TextColor3 = Color3.fromRGB(150, 150, 150)})
end)



-- Status Text
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundTransparency = 1.000
StatusLabel.Position = UDim2.new(0, 0, 0, 45)
StatusLabel.Size = UDim2.new(1, 0, 0, 15)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "STATUS: IDLE"
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
StatusLabel.TextSize = 11.000

local function UpdateStatus()
    local active = {}
    if voidActive then table.insert(active, "VOID") end
    if orbitActive then table.insert(active, "ORBIT") end
    if espActive then table.insert(active, "ESP") end
    if aaActive then table.insert(active, "AA") end
    if tpActive then table.insert(active, "TP") end
    if crouchActive then table.insert(active, "CROUCH") end
    if riotActive then table.insert(active, "RIOT") end
    
    if #active > 0 then
        StatusLabel.Text = "STATUS: " .. table.concat(active, " + ")
    else
        StatusLabel.Text = "STATUS: IDLE"
    end
end

-- Void Button
local VoidButton = Instance.new("TextButton")
VoidButton.Name = "VoidButton"
VoidButton.Parent = MainFrame
VoidButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
VoidButton.Position = UDim2.new(0.05, 0, 0, 75)
VoidButton.Size = UDim2.new(0.9, 0, 0, 40)
VoidButton.Font = Enum.Font.GothamBold
VoidButton.Text = "TOGGLE VOID"
VoidButton.TextColor3 = Color3.fromRGB(230, 230, 230)
VoidButton.TextSize = 14.000
VoidButton.AutoButtonColor = false

local VoidCorner = Instance.new("UICorner")
VoidCorner.CornerRadius = UDim.new(0, 6)
VoidCorner.Parent = VoidButton

VoidButton.MouseEnter:Connect(function()
    tween(VoidButton, {BackgroundColor3 = Color3.fromRGB(45, 45, 60)})
end)

VoidButton.MouseLeave:Connect(function()
    if not voidActive then
        tween(VoidButton, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
    end
end)

local function toggleVoid(forceState)
    if forceState ~= nil then
        if voidActive == forceState then return end
        voidActive = forceState
    else
        voidActive = not voidActive
    end
    
    if voidActive then
        UpdateStatus()
        tween(VoidButton, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)}, 0.3) -- Active color
        
        local lastHrp = nil
        local spawnDelay = 0
        
        voidConnection1 = rs.Heartbeat:Connect(function()
            local character = Players.LocalPlayer.Character
            if character then
                hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if hrp ~= lastHrp then
                        lastHrp = hrp
                        spawnDelay = tick() + 2 -- Wait 2 seconds for safe spawn
                        clientc = hrp.CFrame
                    end
                    
                    if tick() < spawnDelay then
                        clientc = hrp.CFrame
                        clientv = hrp.AssemblyLinearVelocity
                        clientva = hrp.AssemblyAngularVelocity
                        return
                    end
                    
                    clientc = hrp.CFrame
                    clientv = hrp.AssemblyLinearVelocity
                    clientva = hrp.AssemblyAngularVelocity
                    
                    hrp.CFrame = CFrame.new(getVoidValue(), math.random(100000, 500000), getVoidValue()) * CFrame.Angles(math.rad(math.pi), math.rad(math.pi), math.rad(math.pi))
                    hrp.AssemblyLinearVelocity = Vector3.new(getVoidValue(), getVoidValue(), getVoidValue())
                    hrp.AssemblyAngularVelocity = Vector3.new(getVoidValue(), getVoidValue(), getVoidValue())
                end
            end
        end)
        
        rs:BindToRenderStep("csync", Enum.RenderPriority.First.Value, function()
            if hrp and clientc and tick() >= spawnDelay then
                hrp.CFrame = clientc
                hrp.AssemblyLinearVelocity = clientv
                hrp.AssemblyAngularVelocity = clientva
            end
        end)
    else
        UpdateStatus()
        tween(VoidButton, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}, 0.3)
        if voidConnection1 then voidConnection1:Disconnect() end
        pcall(function() rs:UnbindFromRenderStep("csync") end)
        
        -- Restore state so the player doesn't get flung
        if hrp and clientc then
            hrp.CFrame = clientc
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
    saveConfig()
end

VoidButton.MouseButton1Click:Connect(function() toggleVoid() end)

-- Orbit Button
local OrbitButton = Instance.new("TextButton")
OrbitButton.Name = "OrbitButton"
OrbitButton.Parent = MainFrame
OrbitButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
OrbitButton.Position = UDim2.new(0.05, 0, 0, 130)
OrbitButton.Size = UDim2.new(0.9, 0, 0, 40)
OrbitButton.Font = Enum.Font.GothamBold
OrbitButton.Text = "TOGGLE ORBIT"
OrbitButton.TextColor3 = Color3.fromRGB(230, 230, 230)
OrbitButton.TextSize = 14.000
OrbitButton.AutoButtonColor = false

local OrbitCorner = Instance.new("UICorner")
OrbitCorner.CornerRadius = UDim.new(0, 6)
OrbitCorner.Parent = OrbitButton


local orbitConnection

OrbitButton.MouseEnter:Connect(function()
    tween(OrbitButton, {BackgroundColor3 = Color3.fromRGB(45, 45, 60)})
end)

OrbitButton.MouseLeave:Connect(function()
    if not orbitActive then
        tween(OrbitButton, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
    end
end)

local function toggleOrbit(forceState)
    if forceState ~= nil then
        if orbitActive == forceState then return end
        orbitActive = forceState
    else
        orbitActive = not orbitActive
    end
    
    if orbitActive then
        UpdateStatus()
        tween(OrbitButton, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)}, 0.3)
        
        local angle = 0
        local radius = 8
        local speed = 8
        local closest = nil
        local lastTargetUpdate = 0
        local lastOrbitHrp = nil
        
        orbitConnection = rs.RenderStepped:Connect(function(dt)
            local character = Players.LocalPlayer.Character
            if character then
                local hrp_orbit = character:FindFirstChild("HumanoidRootPart")
                if hrp_orbit then
                    if hrp_orbit ~= lastOrbitHrp then
                        lastOrbitHrp = hrp_orbit
                    end
                    
                    local now = tick()
                    if now - lastTargetUpdate > 0.25 then
                        lastTargetUpdate = now
                        closest = nil
                        local minDist = 250 -- Max orbit engage distance
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= Players.LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                local dist = (p.Character.HumanoidRootPart.Position - hrp_orbit.Position).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    closest = p.Character.HumanoidRootPart
                                end
                            end
                        end
                    end
                    
                    if closest and closest.Parent then
                        -- Circle around the closest enemy
                        angle = angle + (speed * dt)
                        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                        hrp_orbit.CFrame = CFrame.new(closest.Position + offset, closest.Position)
                    else
                        -- Default to self-spin if no enemies are nearby
                        hrp_orbit.CFrame = hrp_orbit.CFrame * CFrame.Angles(0, math.rad(1500 * dt), 0)
                    end
                end
            end
        end)
    else
        UpdateStatus()
        tween(OrbitButton, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}, 0.3)
        if orbitConnection then orbitConnection:Disconnect() end
    end
    saveConfig()
end

OrbitButton.MouseButton1Click:Connect(function() toggleOrbit() end)

-- Feature Button Helper
local function createFeatureBtn(name, text, y, toggleFn)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.Position = UDim2.new(0.05, 0, 0, y)
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.TextSize = 14
    btn.AutoButtonColor = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = Color3.fromRGB(45, 45, 60)}) end)
    btn.MouseLeave:Connect(function()
        local active = false
        if name == "ESPButton" then active = espActive
        elseif name == "AAButton" then active = aaActive
        elseif name == "TPButton" then active = tpActive
        elseif name == "CrouchButton" then active = crouchActive
        elseif name == "RiotButton" then active = riotActive
        end
        if not active then tween(btn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}) end
    end)
    btn.MouseButton1Click:Connect(toggleFn)
    return btn
end

-- ESP
local function toggleESP(force)
    espActive = force ~= nil and force or not espActive
    if espActive then
        tween(ESPBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        espConn = rs.RenderStepped:Connect(function()
            espFolder:ClearAllChildren()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Players.LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local bg = Instance.new("BillboardGui", espFolder)
                    bg.Size = UDim2.new(0, 200, 0, 50)
                    bg.Adornee = p.Character.HumanoidRootPart
                    bg.AlwaysOnTop = true
                    local tl = Instance.new("TextLabel", bg)
                    tl.Size = UDim2.new(1, 0, 1, 0)
                    tl.BackgroundTransparency = 1
                    tl.TextColor3 = Color3.fromRGB(255, 100, 100)
                    tl.TextStrokeTransparency = 0
                    tl.Font = Enum.Font.GothamBold
                    tl.TextSize = 12
                    tl.Text = p.Name .. "\n[" .. math.floor(p.Character:FindFirstChildOfClass("Humanoid").Health) .. " HP]"
                end
            end
        end)
    else
        tween(ESPBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if espConn then espConn:Disconnect() end
        espFolder:ClearAllChildren()
    end
    UpdateStatus()
    saveConfig()
end
ESPBtn = createFeatureBtn("ESPButton", "TOGGLE ESP", 185, toggleESP)

-- Anti-Aim
local function toggleAA(force)
    aaActive = force ~= nil and force or not aaActive
    if aaActive then
        tween(AABtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        aaConn = rs.RenderStepped:Connect(function(dt)
            local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(1500 * dt), 0)
            end
        end)
    else
        tween(AABtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if aaConn then aaConn:Disconnect() end
    end
    UpdateStatus()
    saveConfig()
end
AABtn = createFeatureBtn("AAButton", "TOGGLE ANTI-AIM", 240, toggleAA)

-- TP Under
local function toggleTP(force)
    tpActive = force ~= nil and force or not tpActive
    if tpActive then
        tween(TPBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        tpConn = rs.RenderStepped:Connect(function()
            local myHrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end
            local target, dist = nil, 250
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Players.LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (p.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude
                    if d < dist then target, dist = p.Character.HumanoidRootPart, d end
                end
            end
            if target then
                myHrp.CFrame = target.CFrame * CFrame.new(0, -10, 0)
                myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end)
    else
        tween(TPBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if tpConn then tpConn:Disconnect() end
    end
    UpdateStatus()
    saveConfig()
end
TPBtn = createFeatureBtn("TPButton", "TP UNDER TARGET", 295, toggleTP)

-- Crouch Spam
local function toggleCrouch(force)
    crouchActive = force ~= nil and force or not crouchActive
    if crouchActive then
        tween(CrouchBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        crouchConn = task.spawn(function()
            while crouchActive do
                local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.HipHeight = 0
                    task.wait(0.1)
                    hum.HipHeight = 2
                    task.wait(0.1)
                end
                task.wait()
            end
        end)
    else
        tween(CrouchBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        crouchActive = false
        local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.HipHeight = 2 end
    end
    UpdateStatus()
    saveConfig()
end
CrouchBtn = createFeatureBtn("CrouchButton", "CROUCH SPAM", 350, toggleCrouch)

-- Riot Abuser
local function toggleRiot(force)
    riotActive = force ~= nil and force or not riotActive
    if riotActive then
        tween(RiotBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        riotConn = rs.Heartbeat:Connect(function()
            local myHrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end
            local target, dist = nil, 500
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Players.LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (p.Character.HumanoidRootPart.Position - myHrp.Position).Magnitude
                    if d < dist then target, dist = p.Character.HumanoidRootPart, d end
                end
            end
            if target then
                myHrp.CFrame = target.CFrame * CFrame.new(math.sin(tick()*10)*10, 0, math.cos(tick()*10)*10)
                local tool = Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then tool:Activate() end
            end
        end)
    else
        tween(RiotBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if riotConn then riotConn:Disconnect() end
    end
    UpdateStatus()
    saveConfig()
end
RiotBtn = createFeatureBtn("RiotButton", "RIOT ABUSER", 405, toggleRiot)

CloseButton.MouseButton1Click:Connect(function()
    -- Safely unload everything
    toggleVoid(false)
    toggleOrbit(false)
    toggleESP(false)
    toggleAA(false)
    toggleTP(false)
    toggleCrouch(false)
    toggleRiot(false)
    
    -- Tween out
    local t = tween(MainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    t.Completed:Wait()
    
    -- Destroy GUI
    scarGui:Destroy()
end)

-- Welcome Screen
local WelcomeFrame = Instance.new("Frame")
WelcomeFrame.Name = "WelcomeFrame"
WelcomeFrame.Parent = scarGui
WelcomeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
WelcomeFrame.BackgroundTransparency = 1
WelcomeFrame.Position = UDim2.new(0, 0, 0, 0)
WelcomeFrame.Size = UDim2.new(1, 0, 1, 0)
WelcomeFrame.ZIndex = 10

local WelcomeTitle = Instance.new("TextLabel")
WelcomeTitle.Parent = WelcomeFrame
WelcomeTitle.BackgroundTransparency = 1
WelcomeTitle.Position = UDim2.new(0, 0, 0.45, -25)
WelcomeTitle.Size = UDim2.new(1, 0, 0, 50)
WelcomeTitle.Font = Enum.Font.GothamBold
WelcomeTitle.Text = "Welcome to Scar.lol"
WelcomeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
WelcomeTitle.TextSize = 36
WelcomeTitle.TextTransparency = 1
WelcomeTitle.ZIndex = 11

local WelcomeSub = Instance.new("TextLabel")
WelcomeSub.Parent = WelcomeFrame
WelcomeSub.BackgroundTransparency = 1
WelcomeSub.Position = UDim2.new(0, 0, 0.45, 25)
WelcomeSub.Size = UDim2.new(1, 0, 0, 30)
WelcomeSub.Font = Enum.Font.Gotham
WelcomeSub.Text = "Thank you for buying."
WelcomeSub.TextColor3 = Color3.fromRGB(170, 170, 170)
WelcomeSub.TextSize = 18
WelcomeSub.TextTransparency = 1
WelcomeSub.ZIndex = 11

-- Run the Welcome Animation Sequence
task.spawn(function()
    -- Create Blur
    local blur = Instance.new("BlurEffect")
    blur.Name = "ScarBlur"
    blur.Size = 0
    blur.Parent = game:GetService("Lighting")
    
    -- Fade in tint and blur
    tween(WelcomeFrame, {BackgroundTransparency = 0.4}, 0.5)
    tween(blur, {Size = 24}, 0.5)
    
    -- Fade in text
    tween(WelcomeTitle, {TextTransparency = 0}, 0.5)
    tween(WelcomeSub, {TextTransparency = 0}, 0.5).Completed:Wait()
    
    -- Wait for user to read
    task.wait(2)
    
    -- Fade out text
    tween(WelcomeTitle, {TextTransparency = 1}, 0.5)
    tween(WelcomeSub, {TextTransparency = 1}, 0.5)
    
    -- Fade out tint and blur
    tween(WelcomeFrame, {BackgroundTransparency = 1}, 0.5)
    tween(blur, {Size = 0}, 0.5).Completed:Wait()
    
    WelcomeFrame:Destroy()
    blur:Destroy()
    
    -- NOW pop in the Main Menu
    -- NOW pop in the Main Menu
    tween(MainFrame, {Size = UDim2.new(0, 220, 0, 465)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end)

-- Auto-Load Config on script execute
task.spawn(function()
    local savedConfig = loadConfig()
    autoExecute = savedConfig.autoExecute or false
    
    if autoExecute then
        tween(AutoButton, {TextColor3 = Color3.fromRGB(180, 140, 255)})
        applyQueueOnTeleport()
        
        if savedConfig.voidActive then toggleVoid(true) end
        if savedConfig.orbitActive then toggleOrbit(true) end
        if savedConfig.espActive then toggleESP(true) end
        if savedConfig.aaActive then toggleAA(true) end
        if savedConfig.tpActive then toggleTP(true) end
        if savedConfig.crouchActive then toggleCrouch(true) end
        if savedConfig.riotActive then toggleRiot(true) end
    end
end)
