if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Wait 8 seconds to ensure UE Ragebot and other executors fully load
task.wait(8)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local rs = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local function tween(object, properties, duration, style, direction)
    style = style or Enum.EasingStyle.Quad
    direction = direction or Enum.EasingDirection.Out
    local info = TweenInfo.new(duration or 0.2, style, direction)
    local t = TweenService:Create(object, info, properties)
    t:Play()
    return t
end

-- Cleanup previous instances
local targetGuiParent = (gethui and gethui()) or CoreGui
for _, child in ipairs(targetGuiParent:GetChildren()) do
    if child.Name == "scarGui" then
        child:Destroy()
    end
end

--------------------------------------------------
-- CONFIG SYSTEM
--------------------------------------------------
local configFileName = "scar_lol_config.json"
local defaultConfig = {
    voidActive = false,
    orbitActive = false,
    autoExecute = false,
    autoCollect = false,
    autoRespawn = false,
    fpsBoost = false
}

local voidActive, orbitActive, autoExecute = false, false, false
local autoCollect, autoRespawn, fpsBoost = false, false, false
local voidConnection, orbitConnection, collectConnection, respawnConnection

local function loadConfig()
    local success, result = pcall(function()
        if isfile and not isfile(configFileName) then error("File not found") end
        return HttpService:JSONDecode(readfile(configFileName))
    end)
    if success and type(result) == "table" then return result end
    return defaultConfig
end

local function saveConfig()
    if writefile then
        local data = {
            voidActive = voidActive,
            orbitActive = orbitActive,
            autoExecute = autoExecute,
            autoCollect = autoCollect,
            autoRespawn = autoRespawn,
            fpsBoost = fpsBoost
        }
        pcall(function() writefile(configFileName, HttpService:JSONEncode(data)) end)
    end
end

--------------------------------------------------
-- GUI CREATION (STAYING SCAR.LOL STYLE)
--------------------------------------------------
local scarGui = Instance.new("ScreenGui")
scarGui.Name = "scarGui"
scarGui.ResetOnSpawn = false
if syn and syn.protect_gui then syn.protect_gui(scarGui) scarGui.Parent = CoreGui
elseif gethui then scarGui.Parent = gethui()
else scarGui.Parent = CoreGui end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = scarGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BackgroundTransparency = 0.1
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -200)
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

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

rs.RenderStepped:Connect(function(dt)
    if MainFrame and MainFrame.Parent then
        StrokeGradient.Rotation = (StrokeGradient.Rotation + (dt * 150)) % 360
    end
end)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 15)
Title.Size = UDim2.new(1, 0, 0, 20)
Title.Font = Enum.Font.GothamBold
Title.Text = "scar.lol"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 0, 0, 45)
StatusLabel.Size = UDim2.new(1, 0, 0, 15)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "STATUS: IDLE"
StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
StatusLabel.TextSize = 11

local function UpdateStatus()
    local active = {}
    if voidActive then table.insert(active, "VOID") end
    if orbitActive then table.insert(active, "ORBIT") end
    if autoCollect then table.insert(active, "COLLECT") end
    if autoRespawn then table.insert(active, "RESPAWN") end
    if fpsBoost then table.insert(active, "FPS") end
    StatusLabel.Text = #active > 0 and "STATUS: " .. table.concat(active, " + ") or "STATUS: IDLE"
end

--------------------------------------------------
-- FEATURE BUTTONS
--------------------------------------------------
local function createBtn(text, y, toggleFn)
    local btn = Instance.new("TextButton")
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
        if text:find("VOID") then active = voidActive
        elseif text:find("ORBIT") then active = orbitActive
        elseif text:find("COLLECT") then active = autoCollect
        elseif text:find("RESPAWN") then active = autoRespawn
        elseif text:find("FPS") then active = fpsBoost
        end
        if not active then tween(btn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}) end
    end)
    btn.MouseButton1Click:Connect(toggleFn)
    return btn
end

-- VOID SPAM (Astral Orbit Aura Logic)
local function toggleVoid(force)
    voidActive = force ~= nil and force or not voidActive
    if voidActive then
        tween(VoidBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        voidConnection = rs.Stepped:Connect(function()
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(0, -500, 0) -- Astral Void Pos
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                
                -- Find target to orbit camera
                local closest, dist = nil, 500
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= Players.LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local d = (hrp.Position - v.Character.HumanoidRootPart.Position).Magnitude
                        if d < dist then closest, dist = v.Character.HumanoidRootPart, d end
                    end
                end
                if closest then
                    local angle = tick() * 2
                    local offset = Vector3.new(math.cos(angle)*10, 5, math.sin(angle)*10)
                    Camera.CFrame = CFrame.new(Vector3.new(0, -500, 0), closest.Position + offset)
                end
            end
        end)
    else
        tween(VoidBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if voidConnection then voidConnection:Disconnect() end
        local char = Players.LocalPlayer.Character
        if char then Camera.CameraSubject = char:FindFirstChild("Humanoid") end
    end
    UpdateStatus()
    saveConfig()
end
VoidBtn = createBtn("TOGGLE VOID SPAM", 75, toggleVoid)

-- ORBIT (Legacy scar.lol style)
local function toggleOrbit(force)
    orbitActive = force ~= nil and force or not orbitActive
    if orbitActive then
        tween(OrbitBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        orbitConnection = rs.RenderStepped:Connect(function(dt)
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local closest, dist = nil, 250
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Players.LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local d = (p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                        if d < dist then closest, dist = p.Character.HumanoidRootPart, d end
                    end
                end
                if closest then
                    local angle = tick() * 8
                    local offset = Vector3.new(math.cos(angle)*8, 0, math.sin(angle)*8)
                    hrp.CFrame = CFrame.new(closest.Position + offset, closest.Position)
                else
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(1500 * dt), 0)
                end
            end
        end)
    else
        tween(OrbitBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if orbitConnection then orbitConnection:Disconnect() end
    end
    UpdateStatus()
    saveConfig()
end
OrbitBtn = createBtn("TOGGLE ORBIT", 130, toggleOrbit)

-- AUTO COLLECT
local function toggleCollect(force)
    autoCollect = force ~= nil and force or not autoCollect
    if autoCollect then
        tween(CollectBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        collectConnection = rs.RenderStepped:Connect(function()
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, obj in pairs(workspace:GetChildren()) do
                if obj.Name == "_drop" and obj:IsA("BasePart") then
                    firetouchinterest(hrp, obj, 0)
                    firetouchinterest(hrp, obj, 1)
                end
            end
        end)
    else
        tween(CollectBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if collectConnection then collectConnection:Disconnect() end
    end
    UpdateStatus()
    saveConfig()
end
CollectBtn = createBtn("AUTO COLLECT", 185, toggleCollect)

-- AUTO RESPAWN
local function toggleRespawn(force)
    autoRespawn = force ~= nil and force or not autoRespawn
    if autoRespawn then
        tween(RespawnBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        respawnConnection = Players.LocalPlayer.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid")
            hum.Died:Connect(function()
                task.wait()
                pcall(function()
                    local rem = ReplicatedStorage:FindFirstChild("Remotes")
                    if rem then rem = rem:FindFirstChild("Duels") end
                    if rem then rem = rem:FindFirstChild("RespawnNow") end
                    if rem then rem:FireServer() end
                end)
            end)
        end)
    else
        tween(RespawnBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        if respawnConnection then respawnConnection:Disconnect() end
    end
    UpdateStatus()
    saveConfig()
end
RespawnBtn = createBtn("AUTO RESPAWN", 240, toggleRespawn)

-- FPS BOOSTER
local function toggleFPS(force)
    fpsBoost = force ~= nil and force or not fpsBoost
    if fpsBoost then
        tween(FPSBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)})
        Lighting.GlobalShadows = false
        Lighting.Brightness = 1
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then obj.Material = Enum.Material.Plastic obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = 1 end
        end
    else
        tween(FPSBtn, {BackgroundColor3 = Color3.fromRGB(30, 30, 40)})
        Lighting.GlobalShadows = true
    end
    UpdateStatus()
    saveConfig()
end
FPSBtn = createBtn("FPS BOOSTER", 295, toggleFPS)

-- CLOSE / AUTO
local function applyQueueOnTeleport()
    if autoExecute then
        local env = (getgenv and getgenv()) or getfenv(0)
        local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or env.queue_on_teleport or env.queueonteleport
        if qot then
            local code = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/voidedryann-droid/scar/refs/heads/main/rivals.lua?t=" .. tostring(tick())))()]]
            pcall(function() qot(code) end)
        end
    end
end

AutoButton.MouseButton1Click:Connect(function()
    autoExecute = not autoExecute
    tween(AutoButton, {TextColor3 = autoExecute and Color3.fromRGB(180, 140, 255) or Color3.fromRGB(150, 150, 150)})
    if autoExecute then applyQueueOnTeleport() end
    saveConfig()
end)

local CloseButton = Instance.new("TextButton", MainFrame)
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -25, 0, 5)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(150, 150, 150)
CloseButton.TextSize = 14

CloseButton.MouseButton1Click:Connect(function()
    toggleVoid(false) toggleOrbit(false) toggleCollect(false) toggleRespawn(false) toggleFPS(false)
    local t = tween(MainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    t.Completed:Wait()
    scarGui:Destroy()
end)

--------------------------------------------------
-- WELCOME SEQUENCE
--------------------------------------------------
local WelcomeFrame = Instance.new("Frame", scarGui)
WelcomeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
WelcomeFrame.BackgroundTransparency = 1
WelcomeFrame.Size = UDim2.new(1, 0, 1, 0)
WelcomeFrame.ZIndex = 10

local WelcomeTitle = Instance.new("TextLabel", WelcomeFrame)
WelcomeTitle.BackgroundTransparency = 1
WelcomeTitle.Position = UDim2.new(0, 0, 0.45, -25)
WelcomeTitle.Size = UDim2.new(1, 0, 0, 50)
WelcomeTitle.Font = Enum.Font.GothamBold
WelcomeTitle.Text = "Welcome to Scar.lol"
WelcomeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
WelcomeTitle.TextSize = 36
WelcomeTitle.TextTransparency = 1
WelcomeTitle.ZIndex = 11

task.spawn(function()
    local blur = Instance.new("BlurEffect", game:GetService("Lighting"))
    blur.Size = 0
    tween(WelcomeFrame, {BackgroundTransparency = 0.4}, 0.5)
    tween(blur, {Size = 24}, 0.5)
    tween(WelcomeTitle, {TextTransparency = 0}, 0.5)
    task.wait(2)
    tween(WelcomeTitle, {TextTransparency = 1}, 0.5)
    tween(WelcomeFrame, {BackgroundTransparency = 1}, 0.5)
    tween(blur, {Size = 0}, 0.5).Completed:Wait()
    WelcomeFrame:Destroy() blur:Destroy()
    tween(MainFrame, {Size = UDim2.new(0, 220, 0, 350)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end)

-- Auto Load
task.spawn(function()
    local cfg = loadConfig()
    autoExecute = cfg.autoExecute or false
    if autoExecute then
        AutoButton.TextColor3 = Color3.fromRGB(180, 140, 255)
        applyQueueOnTeleport()
        if cfg.voidActive then toggleVoid(true) end
        if cfg.orbitActive then toggleOrbit(true) end
        if cfg.autoCollect then toggleCollect(true) end
        if cfg.autoRespawn then toggleRespawn(true) end
        if cfg.fpsBoost then toggleFPS(true) end
    end
end)
