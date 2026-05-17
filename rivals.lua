--[[
    ╔═══════════════════════════════════════╗
    ║             scar.lol - V1.1           ║
    ║        Made by: Dataoffset           ║
    ║   Compatible with All Executors      ║
    ║        Mobile Optimized Edition      ║
    ╚═══════════════════════════════════════╝
]]

-- Wait for the Roblox engine and player components to fully load (essential for teleport auto-execution!)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
while not Players.LocalPlayer do
    task.wait(0.1)
end

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart", 10)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

-- Global connections for safe uninject
local charAddedConn, charAddedConn2

-- Update character reference on respawn
charAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
end)

--------------------------------------------------
-- SAVED SETTINGS
--------------------------------------------------
local Settings = {
    UIColor = Color3.fromRGB(168, 85, 247), -- Default Sleek Neon Cyber-Purple
    UITransparency = 0.08, -- High-end glass look
    UIScale = 1,
    AnimationSpeed = 0.25, -- Snappy and modern
    GlowEnabled = true,
    RainbowMode = false,
    
    -- Watermark Settings
    WatermarkEnabled = true,
    
    -- Crosshair Settings
    CrosshairEnabled = false,
    CrosshairSize = 10,
    CrosshairGap = 4,
    CrosshairThickness = 2,
    CrosshairColor = Color3.fromRGB(0, 255, 0), -- Default neon green
    CrosshairSpin = false,
    CrosshairSpinSpeed = 3,
    CrosshairPulse = false,
    AutoExecute = false,
}

-- Declare local functions for early scope access in buttons/toggles
local registerTeleportQueue
local createNotification

--------------------------------------------------
-- SECURE JSON CONFIG SYSTEM
--------------------------------------------------
local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "scar_configs.json"

local function saveConfig()
    pcall(function()                                                                                                    
        if writefile then
            local data = {
                Settings = {},
                FeatureStates = {}
            }
            -- Serialize Settings (convert Color3 to RGB tables)
            for k, v in pairs(Settings) do
                if typeof(v) == "Color3" then
                    data.Settings[k] = {v.R, v.G, v.B, "__color3"}
                else
                    data.Settings[k] = v
                end
            end
            -- Serialize FeatureStates
            for k, v in pairs(FeatureStates) do
                data.FeatureStates[k] = v
            end
            
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function loadConfig()
    pcall(function()
        if readfile and isfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            
            -- Restore Settings
            if decoded.Settings then
                for k, v in pairs(decoded.Settings) do
                    if typeof(v) == "table" and v[4] == "__color3" then
                        Settings[k] = Color3.new(v[1], v[2], v[3])
                    else
                        Settings[k] = v
                    end
                end
            end
            -- Restore FeatureStates
            if decoded.FeatureStates then
                for k, v in pairs(decoded.FeatureStates) do
                    FeatureStates[k] = v
                end
            end
        end
    end)
end

-- Autoload immediately on startup
loadConfig()

--------------------------------------------------
-- FEATURE STATES
--------------------------------------------------
local FeatureStates = {
    OrbitAura = false,
    AutoCollect = false,
    AutoRespawn = false,
    FPSBoost = false,
}

--------------------------------------------------
-- ORBIT AURA VARIABLES (ORIGINAL UNKILLABLE VERSION)
--------------------------------------------------
local VOID_POS = Vector3.new(0, -500, 0)  -- Far below the map for safety
local HEIGHT_OFFSET = 5
local ORBIT_RADIUS = 10
local ORBIT_SPEED = 2
local orbitConnection = nil
local orbitAngle = 0

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------
local function createTween(instance, properties, duration, style, direction)
    local tweenInfo = TweenInfo.new(
        duration or Settings.AnimationSpeed, 
        style or Enum.EasingStyle.Quad, 
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Settings.UIColor
    stroke.Thickness = thickness or 1.5
    stroke.Parent = parent
    return stroke
end

-- Snappy mobile-friendly drag handler
local function makeDraggable(frame)
    local dragging = false
    local dragInput, mousePos, framePos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            local newPos = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
            createTween(frame, {Position = newPos}, 0.08)
        end
    end)
end

--------------------------------------------------
-- ORBIT AURA FUNCTIONS (ORIGINAL UNKILLABLE CODE)
--------------------------------------------------
local function getClosestEnemy()
    local closest = nil
    local shortestDist = math.huge
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local enemyHrp = v.Character:FindFirstChild("HumanoidRootPart")
            local enemyHum = v.Character:FindFirstChild("Humanoid")
            
            if enemyHrp and enemyHum and enemyHum.Health > 0 then
                local dist = (hrp.Position - enemyHrp.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closest = v.Character
                end
            end
        end
    end
    
    return closest
end

local function teleportToVoid()
    if hrp then
        hrp.CFrame = CFrame.new(VOID_POS)
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
end

local function setCameraVoid(enemy)
    if not enemy then return end
    
    local ehrp = enemy:FindFirstChild("HumanoidRootPart")
    if not ehrp then return end
    
    -- Create orbit effect
    orbitAngle = orbitAngle + ORBIT_SPEED
    local x = math.cos(math.rad(orbitAngle)) * ORBIT_RADIUS
    local z = math.sin(math.rad(orbitAngle)) * ORBIT_RADIUS
    local behind = Vector3.new(x, 0, z)
    
    local targetPos = ehrp.Position + behind + Vector3.new(0, HEIGHT_OFFSET, 0)
    Camera.CFrame = CFrame.new(VOID_POS, targetPos)
end

local function toggleOrbitAura(enabled)
    FeatureStates.OrbitAura = enabled
    
    if enabled then
        orbitConnection = RunService.Stepped:Connect(function()
            if character and hrp then
                teleportToVoid()
                local enemy = getClosestEnemy()
                if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                    setCameraVoid(enemy)
                end
            end
        end)
    else
        if orbitConnection then
            orbitConnection:Disconnect()
            orbitConnection = nil
        end
        if character and hrp then
            hrp.CFrame = CFrame.new(0, 5, 0)
            Camera.CameraSubject = character:FindFirstChild("Humanoid")
        end
    end
end

--------------------------------------------------
-- AUTO COLLECT FUNCTIONS
--------------------------------------------------
local collectConnection = nil

local function toggleAutoCollect(enabled)
    FeatureStates.AutoCollect = enabled
    
    if enabled then
        collectConnection = RunService.RenderStepped:Connect(function()
            if not character then return end
            local currentHrp = character:FindFirstChild("HumanoidRootPart")
            if not currentHrp then return end
            local humanoid = character:FindFirstChild("Humanoid")
            local needsHealth = humanoid and humanoid.Health < humanoid.MaxHealth
            
            for _, obj in pairs(workspace:GetChildren()) do
                if obj.Name == "_drop" and obj:IsA("BasePart") then
                    if (obj:FindFirstChild("Health") and needsHealth) or obj:FindFirstChild("Ammo") then
                        firetouchinterest(currentHrp, obj, 0)
                        firetouchinterest(currentHrp, obj, 1)
                    end
                end
            end
        end)
    else
        if collectConnection then
            collectConnection:Disconnect()
            collectConnection = nil
        end
    end
end

--------------------------------------------------
-- AUTO RESPAWN FUNCTIONS
--------------------------------------------------
local respawnConnection = nil

local function setupRespawn(char)
    if not FeatureStates.AutoRespawn then return end
    
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if not FeatureStates.AutoRespawn then return end
        task.wait()
        pcall(function()
            local respawnRemote = ReplicatedStorage:FindFirstChild("Remotes")
            if respawnRemote then
                respawnRemote = respawnRemote:FindFirstChild("Duels")
                if respawnRemote then
                    respawnRemote = respawnRemote:FindFirstChild("RespawnNow")
                    if respawnRemote then
                        respawnRemote:FireServer()
                    end
                end
            end
        end)
    end)
end

local function toggleAutoRespawn(enabled)
    FeatureStates.AutoRespawn = enabled
    
    if enabled then
        respawnConnection = LocalPlayer.CharacterAdded:Connect(setupRespawn)
        if LocalPlayer.Character then
            setupRespawn(LocalPlayer.Character)
        end
    else
        if respawnConnection then
            respawnConnection:Disconnect()
            respawnConnection = nil
        end
    end
end

--------------------------------------------------
-- FPS BOOSTER FUNCTIONS
--------------------------------------------------
local function toggleFPSBoost(enabled)
    FeatureStates.FPSBoost = enabled
    
    if enabled then
        -- Lighting optimizations
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
        
        -- Workspace optimizations
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Fire") or obj:IsA("Smoke") then
                obj.Enabled = false
            elseif obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end
        
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
    else
        -- Restore settings
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 100000
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = true
            end
        end
        
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end)
    end
end

--------------------------------------------------
-- GUI CREATION
--------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "scar_lol"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Protection for different executors
if syn then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = game.CoreGui
elseif gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = game.CoreGui
end

-- Toggle Button (Open/Close) - Mobile Friendly
local ToggleFrame = Instance.new("Frame")
ToggleFrame.Name = "ToggleFrame"
ToggleFrame.Size = UDim2.new(0, 60, 0, 60)
ToggleFrame.Position = UDim2.new(0, 20, 0.4, -30)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
ToggleFrame.BorderSizePixel = 0
ToggleFrame.Parent = ScreenGui
ToggleFrame.Active = true
addCorner(ToggleFrame, 30)
local toggleFrameStroke = addStroke(ToggleFrame, Settings.UIColor, 2)

-- Glow effect for toggle button
local ToggleGlow = Instance.new("ImageLabel")
ToggleGlow.Name = "Glow"
ToggleGlow.BackgroundTransparency = 1
ToggleGlow.Position = UDim2.new(0, -10, 0, -10)
ToggleGlow.Size = UDim2.new(1, 20, 1, 20)
ToggleGlow.ZIndex = 0
ToggleGlow.Image = "rbxassetid://6015897843"
ToggleGlow.ImageColor3 = Settings.UIColor
ToggleGlow.ImageTransparency = 0.35
ToggleGlow.ScaleType = Enum.ScaleType.Slice
ToggleGlow.SliceCenter = Rect.new(49, 49, 450, 450)
ToggleGlow.Parent = ToggleFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(1, 0, 1, 0)
ToggleButton.BackgroundTransparency = 1
ToggleButton.Text = "⚡" -- Premium emblem
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 24
ToggleButton.Parent = ToggleFrame

-- Hover spring scale effect for floating toggle button
ToggleFrame.MouseEnter:Connect(function()
    createTween(ToggleFrame, {Size = UDim2.new(0, 66, 0, 66), Position = UDim2.new(ToggleFrame.Position.X.Scale, ToggleFrame.Position.X.Offset - 3, ToggleFrame.Position.Y.Scale, ToggleFrame.Position.Y.Offset - 3)}, 0.2)
    createTween(ToggleButton, {Rotation = 15}, 0.2)
end)

ToggleFrame.MouseLeave:Connect(function()
    createTween(ToggleFrame, {Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(ToggleFrame.Position.X.Scale, ToggleFrame.Position.X.Offset + 3, ToggleFrame.Position.Y.Scale, ToggleFrame.Position.Y.Offset + 3)}, 0.2)
    createTween(ToggleButton, {Rotation = 0}, 0.2)
end)

-- Make Toggle Button Draggable (Mobile + PC)
local dragging = false
local dragInput, mousePos, framePos

ToggleFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        mousePos = input.Position
        framePos = ToggleFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - mousePos
        local newPos = UDim2.new(
            framePos.X.Scale,
            framePos.X.Offset + delta.X,
            framePos.Y.Scale,
            framePos.Y.Offset + delta.Y
        )
        createTween(ToggleFrame, {Position = newPos}, 0.1)
    end
end)

-- Main Frame - Mobile Optimized Size
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 430, 0, 560)
MainFrame.Position = UDim2.new(0.5, -215, 0.5, -280)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
MainFrame.BackgroundTransparency = Settings.UITransparency
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Active = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 16)
local MainWindowStroke = addStroke(MainFrame, Settings.UIColor, 1.8)

-- Beautiful rotating border glow sequence
local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Settings.UIColor),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 40, 55)),
    ColorSequenceKeypoint.new(1, Settings.UIColor)
}
StrokeGradient.Parent = MainWindowStroke

local borderRotationConn
borderRotationConn = RunService.RenderStepped:Connect(function()
    if not ScreenGui.Parent then
        borderRotationConn:Disconnect()
        return
    end
    StrokeGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Settings.UIColor),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 40, 55)),
        ColorSequenceKeypoint.new(1, Settings.UIColor)
    }
    StrokeGradient.Rotation = (StrokeGradient.Rotation + 1) % 360
end)

-- Make Main Frame Draggable
local mainDragging = false
local mainDragInput, mainMousePos, mainFramePos

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        mainDragging = true
        mainMousePos = input.Position
        mainFramePos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                mainDragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        mainDragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == mainDragInput and mainDragging then
        local delta = input.Position - mainMousePos
        local newPos = UDim2.new(
            mainFramePos.X.Scale,
            mainFramePos.X.Offset + delta.X,
            mainFramePos.Y.Scale,
            mainFramePos.Y.Offset + delta.Y
        )
        createTween(MainFrame, {Position = newPos}, 0.1)
    end
end)

-- Shadow Effect
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.BackgroundTransparency = 1
Shadow.Position = UDim2.new(0, -20, 0, -20)
Shadow.Size = UDim2.new(1, 40, 1, 40)
Shadow.ZIndex = 0
Shadow.Image = "rbxassetid://6015897843"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.4
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 65)
Header.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
addCorner(Header, 16)

-- Mask the bottom corners so they are sharp
local HeaderMask = Instance.new("Frame")
HeaderMask.Name = "HeaderMask"
HeaderMask.Size = UDim2.new(1, 0, 0, 15)
HeaderMask.Position = UDim2.new(0, 0, 1, -15)
HeaderMask.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
HeaderMask.BorderSizePixel = 0
HeaderMask.Parent = Header

-- Logo
local LogoFrame = Instance.new("Frame")
LogoFrame.Size = UDim2.new(0, 40, 0, 40)
LogoFrame.Position = UDim2.new(0, 15, 0.5, -20)
LogoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
LogoFrame.BorderSizePixel = 0
LogoFrame.Parent = Header
addCorner(LogoFrame, 12)
addStroke(LogoFrame, Settings.UIColor, 1.5)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "⚡"
LogoText.TextColor3 = Settings.UIColor
LogoText.Font = Enum.Font.GothamBold
LogoText.TextSize = 22
LogoText.Parent = LogoFrame

-- Title Container
local TitleContainer = Instance.new("Frame")
TitleContainer.Size = UDim2.new(1, -140, 1, 0)
TitleContainer.Position = UDim2.new(0, 65, 0, 0)
TitleContainer.BackgroundTransparency = 1
TitleContainer.Parent = Header

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 22)
Title.Position = UDim2.new(0, 0, 0.5, -20)
Title.BackgroundTransparency = 1
Title.Text = "scar.lol"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleContainer

local Subtitle = Instance.new("TextLabel")
Subtitle.Name = "Subtitle"
Subtitle.Size = UDim2.new(1, 0, 0, 15)
Subtitle.Position = UDim2.new(0, 0, 0.5, 2)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "PREMIUM MULTI-TOOL"
Subtitle.TextColor3 = Color3.fromRGB(150, 150, 165)
Subtitle.Font = Enum.Font.GothamBold
Subtitle.TextSize = 10
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = TitleContainer

-- Modern minimal close button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 32, 0, 32)
CloseButton.Position = UDim2.new(1, -45, 0.5, -16)
CloseButton.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(180, 180, 190)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = Header
addCorner(CloseButton, 8)
local CloseStroke = addStroke(CloseButton, Color3.fromRGB(45, 45, 55), 1)

CloseButton.MouseEnter:Connect(function()
    createTween(CloseButton, {BackgroundColor3 = Color3.fromRGB(239, 68, 68)}, 0.2)
    createTween(CloseButton, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
    CloseStroke.Color = Color3.fromRGB(239, 68, 68)
end)

CloseButton.MouseLeave:Connect(function()
    createTween(CloseButton, {BackgroundColor3 = Color3.fromRGB(24, 24, 30)}, 0.2)
    createTween(CloseButton, {TextColor3 = Color3.fromRGB(180, 180, 190)}, 0.2)
    CloseStroke.Color = Color3.fromRGB(45, 45, 55)
end)

-- Tab System Container
local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, -30, 0, 42)
TabContainer.Position = UDim2.new(0, 15, 0, 80)
TabContainer.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
TabContainer.Parent = MainFrame
addCorner(TabContainer, 10)
addStroke(TabContainer, Color3.fromRGB(25, 25, 35), 1)

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0, 8)
TabLayout.Parent = TabContainer

-- Content Frame
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -30, 1, -155)
ContentFrame.Position = UDim2.new(0, 15, 0, 135)
ContentFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
ContentFrame.BackgroundTransparency = 0.4
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 4
ContentFrame.ScrollBarImageColor3 = Settings.UIColor
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentFrame.Parent = MainFrame
addCorner(ContentFrame, 12)
local ContentFrameStroke = addStroke(ContentFrame, Color3.fromRGB(25, 25, 35), 1)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 10)
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentFrame

ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 20)
end)

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 10)
ContentPadding.PaddingBottom = UDim.new(0, 10)
ContentPadding.Parent = ContentFrame

--------------------------------------------------
-- TAB CREATION FUNCTION
--------------------------------------------------
local currentTab = nil
local tabs = {}

local function createTab(name, icon)
    local TabButton = Instance.new("TextButton")
    TabButton.Name = name .. "Tab"
    TabButton.Size = UDim2.new(0.3, 0, 0.8, 0)
    TabButton.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    TabButton.BackgroundTransparency = 1
    TabButton.Text = icon .. " " .. name
    TabButton.TextColor3 = Color3.fromRGB(160, 160, 175)
    TabButton.Font = Enum.Font.GothamBold
    TabButton.TextSize = 12
    TabButton.Parent = TabContainer
    addCorner(TabButton, 8)
    
    local TabContent = Instance.new("Frame")
    TabContent.Name = name .. "Content"
    TabContent.Size = UDim2.new(1, 0, 0, 0) -- Start height at 0, will expand dynamically
    TabContent.BackgroundTransparency = 1
    TabContent.Visible = false
    TabContent.Parent = ContentFrame
    
    local TabContentLayout = Instance.new("UIListLayout")
    TabContentLayout.Padding = UDim.new(0, 10)
    TabContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabContentLayout.Parent = TabContent
    
    tabs[name] = {Button = TabButton, Content = TabContent}
    
    -- Dynamically expand/contract TabContent height based on children size in real-time
    TabContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if TabContent.Visible then
            TabContent.Size = UDim2.new(1, 0, 0, TabContentLayout.AbsoluteContentSize.Y)
        else
            TabContent.Size = UDim2.new(1, 0, 0, 0)
        end
    end)
    
    TabButton.MouseEnter:Connect(function()
        if currentTab ~= name then
            createTween(TabButton, {TextColor3 = Color3.fromRGB(220, 220, 235)}, 0.2)
        end
    end)
    
    TabButton.MouseLeave:Connect(function()
        if currentTab ~= name then
            createTween(TabButton, {TextColor3 = Color3.fromRGB(160, 160, 175)}, 0.2)
        end
    end)
    
    TabButton.MouseButton1Click:Connect(function()
        if currentTab == name then return end
        
        -- Collapse and hide all other tabs
        for tabName, tab in pairs(tabs) do
            tab.Content.Visible = false
            tab.Content.Size = UDim2.new(1, 0, 0, 0)
            createTween(tab.Button, {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(160, 160, 175)}, 0.2)
        end
        
        -- Expand new tab dynamically
        TabContent.Visible = true
        TabContent.Size = UDim2.new(1, 0, 0, TabContentLayout.AbsoluteContentSize.Y)
        currentTab = name
        createTween(TabButton, {BackgroundTransparency = 0, BackgroundColor3 = Settings.UIColor, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
        
        -- Smoothly reset scroll position to the top of the container
        ContentFrame.CanvasPosition = Vector2.new(0, 0)
    end)
    
    return TabContent
end

--------------------------------------------------
-- TOGGLE CREATION FUNCTION
--------------------------------------------------
local function createToggle(parent, name, description, callback)
    local ToggleContainer = Instance.new("Frame")
    ToggleContainer.Name = name .. "Container"
    ToggleContainer.Size = UDim2.new(1, -10, 0, 66)
    ToggleContainer.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    ToggleContainer.BorderSizePixel = 0
    ToggleContainer.Parent = parent
    addCorner(ToggleContainer, 10)
    local containerStroke = addStroke(ToggleContainer, Color3.fromRGB(30, 30, 40), 1)
    
    local ToggleName = Instance.new("TextLabel")
    ToggleName.Size = UDim2.new(1, -90, 0, 25)
    ToggleName.Position = UDim2.new(0, 15, 0, 12)
    ToggleName.BackgroundTransparency = 1
    ToggleName.Text = name
    ToggleName.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleName.Font = Enum.Font.GothamBold
    ToggleName.TextSize = 14
    ToggleName.TextXAlignment = Enum.TextXAlignment.Left
    ToggleName.Parent = ToggleContainer
    
    local ToggleDesc = Instance.new("TextLabel")
    ToggleDesc.Size = UDim2.new(1, -90, 0, 20)
    ToggleDesc.Position = UDim2.new(0, 15, 0, 35)
    ToggleDesc.BackgroundTransparency = 1
    ToggleDesc.Text = description
    ToggleDesc.TextColor3 = Color3.fromRGB(150, 150, 165)
    ToggleDesc.Font = Enum.Font.Gotham
    ToggleDesc.TextSize = 11
    ToggleDesc.TextXAlignment = Enum.TextXAlignment.Left
    ToggleDesc.Parent = ToggleContainer
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = UDim2.new(0, 52, 0, 26)
    ToggleButton.Position = UDim2.new(1, -67, 0.5, -13)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    ToggleButton.Text = ""
    ToggleButton.Parent = ToggleContainer
    addCorner(ToggleButton, 13)
    local buttonStroke = addStroke(ToggleButton, Color3.fromRGB(48, 48, 60), 1)
    
    local ToggleIndicator = Instance.new("Frame")
    ToggleIndicator.Name = "Indicator"
    ToggleIndicator.Size = UDim2.new(0, 20, 0, 20)
    ToggleIndicator.Position = UDim2.new(0, 3, 0.5, -10)
    ToggleIndicator.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
    ToggleIndicator.Parent = ToggleButton
    addCorner(ToggleIndicator, 10)
    
    -- Load Visual Active/Inactive State from config auto-sync
    local enabled = false
    if string.find(name, "Orbit Aura") then
        enabled = FeatureStates.OrbitAura
    elseif string.find(name, "Auto Collect") then
        enabled = FeatureStates.AutoCollect
    elseif string.find(name, "Auto Respawn") then
        enabled = FeatureStates.AutoRespawn
    elseif string.find(name, "FPS Booster") then
        enabled = FeatureStates.FPSBoost
    elseif string.find(name, "Watermark") then
        enabled = Settings.WatermarkEnabled
    elseif string.find(name, "Custom Crosshair") then
        enabled = Settings.CrosshairEnabled
    elseif string.find(name, "Crosshair Spin") then
        enabled = Settings.CrosshairSpin
    elseif string.find(name, "Crosshair Pulse") then
        enabled = Settings.CrosshairPulse
    elseif string.find(name, "Glow Effect") then
        enabled = Settings.GlowEnabled
    elseif string.find(name, "Rainbow Mode") then
        enabled = Settings.RainbowMode
    elseif string.find(name, "Auto Execute") then
        enabled = Settings.AutoExecute
    end
    
    if enabled then
        ToggleButton.BackgroundColor3 = Settings.UIColor
        buttonStroke.Color = Settings.UIColor
        ToggleIndicator.Position = UDim2.new(0, 29, 0.5, -10)
        ToggleIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    -- Smooth hover transitions
    ToggleContainer.MouseEnter:Connect(function()
        createTween(ToggleContainer, {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}, 0.2)
        createTween(containerStroke, {Color = Settings.UIColor}, 0.2)
    end)
    
    ToggleContainer.MouseLeave:Connect(function()
        createTween(ToggleContainer, {BackgroundColor3 = Color3.fromRGB(16, 16, 22)}, 0.2)
        createTween(containerStroke, {Color = Color3.fromRGB(30, 30, 40)}, 0.2)
    end)
    
    ToggleButton.MouseButton1Click:Connect(function()
        enabled = not enabled
        
        if enabled then
            createTween(ToggleButton, {BackgroundColor3 = Settings.UIColor}, 0.25)
            createTween(buttonStroke, {Color = Settings.UIColor}, 0.25)
            createTween(ToggleIndicator, {Position = UDim2.new(0, 29, 0.5, -10), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}, 0.25)
        else
            createTween(ToggleButton, {BackgroundColor3 = Color3.fromRGB(32, 32, 42)}, 0.25)
            createTween(buttonStroke, {Color = Color3.fromRGB(48, 48, 60)}, 0.25)
            createTween(ToggleIndicator, {Position = UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = Color3.fromRGB(180, 180, 190)}, 0.25)
        end
        
        callback(enabled)
    end)
    
    return ToggleContainer
end

--------------------------------------------------
-- SLIDER CREATION FUNCTION
--------------------------------------------------
local function createSlider(parent, name, min, max, default, callback)
    local SliderContainer = Instance.new("Frame")
    SliderContainer.Name = name .. "Container"
    SliderContainer.Size = UDim2.new(1, -10, 0, 75)
    SliderContainer.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    SliderContainer.BorderSizePixel = 0
    SliderContainer.Parent = parent
    addCorner(SliderContainer, 10)
    local containerStroke = addStroke(SliderContainer, Color3.fromRGB(30, 30, 40), 1)
    
    local SliderName = Instance.new("TextLabel")
    SliderName.Size = UDim2.new(0.6, 0, 0, 25)
    SliderName.Position = UDim2.new(0, 15, 0, 10)
    SliderName.BackgroundTransparency = 1
    SliderName.Text = name
    SliderName.TextColor3 = Color3.fromRGB(255, 255, 255)
    SliderName.Font = Enum.Font.GothamBold
    SliderName.TextSize = 13
    SliderName.TextXAlignment = Enum.TextXAlignment.Left
    SliderName.Parent = SliderContainer
    
    local ValueBadge = Instance.new("Frame")
    ValueBadge.Size = UDim2.new(0, 45, 0, 20)
    ValueBadge.Position = UDim2.new(1, -60, 0, 12)
    ValueBadge.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    ValueBadge.BorderSizePixel = 0
    ValueBadge.Parent = SliderContainer
    addCorner(ValueBadge, 6)
    addStroke(ValueBadge, Color3.fromRGB(45, 45, 55), 1)
    
    local SliderValue = Instance.new("TextLabel")
    SliderValue.Size = UDim2.new(1, 0, 1, 0)
    SliderValue.BackgroundTransparency = 1
    SliderValue.Text = tostring(default)
    SliderValue.TextColor3 = Settings.UIColor
    SliderValue.Font = Enum.Font.GothamBold
    SliderValue.TextSize = 11
    SliderValue.Parent = ValueBadge
    
    local SliderTrack = Instance.new("Frame")
    SliderTrack.Size = UDim2.new(1, -30, 0, 5)
    SliderTrack.Position = UDim2.new(0, 15, 0, 50)
    SliderTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    SliderTrack.BorderSizePixel = 0
    SliderTrack.Parent = SliderContainer
    addCorner(SliderTrack, 2.5)
    
    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    SliderFill.BackgroundColor3 = Settings.UIColor
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderTrack
    addCorner(SliderFill, 2.5)
    
    local SliderButton = Instance.new("TextButton")
    SliderButton.Size = UDim2.new(0, 14, 0, 14)
    SliderButton.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
    SliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderButton.Text = ""
    SliderButton.Parent = SliderTrack
    addCorner(SliderButton, 7)
    local buttonStroke = addStroke(SliderButton, Settings.UIColor, 2)
    
    local dragging = false
    
    -- Smooth hover transitions
    SliderContainer.MouseEnter:Connect(function()
        createTween(SliderContainer, {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}, 0.2)
        createTween(containerStroke, {Color = Settings.UIColor}, 0.2)
        createTween(SliderButton, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(SliderButton.Position.X.Scale, -8, 0.5, -8)}, 0.2)
    end)
    
    SliderContainer.MouseLeave:Connect(function()
        createTween(SliderContainer, {BackgroundColor3 = Color3.fromRGB(16, 16, 22)}, 0.2)
        createTween(containerStroke, {Color = Color3.fromRGB(30, 30, 40)}, 0.2)
        createTween(SliderButton, {Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(SliderButton.Position.X.Scale, -7, 0.5, -7)}, 0.2)
    end)
    
    SliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mousePos = UserInputService:GetMouseLocation().X
            local trackPos = SliderTrack.AbsolutePosition.X
            local trackSize = SliderTrack.AbsoluteSize.X
            local relativePos = math.clamp(mousePos - trackPos, 0, trackSize)
            local percentage = relativePos / trackSize
            local value = math.floor(min + (max - min) * percentage)
            
            SliderValue.Text = tostring(value)
            createTween(SliderFill, {Size = UDim2.new(percentage, 0, 1, 0)}, 0.1)
            createTween(SliderButton, {Position = UDim2.new(percentage, -7, 0.5, -7)}, 0.1)
            
            callback(value)
        end
    end)
    
    return SliderContainer
end

--------------------------------------------------
-- COLOR PICKER CREATION FUNCTION
--------------------------------------------------
local function createColorPicker(parent, name, default, callback)
    local ColorContainer = Instance.new("Frame")
    ColorContainer.Name = name .. "Container"
    ColorContainer.Size = UDim2.new(1, -10, 0, 66)
    ColorContainer.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    ColorContainer.BorderSizePixel = 0
    ColorContainer.Parent = parent
    addCorner(ColorContainer, 10)
    local containerStroke = addStroke(ColorContainer, Color3.fromRGB(30, 30, 40), 1)
    
    local ColorName = Instance.new("TextLabel")
    ColorName.Size = UDim2.new(0.6, 0, 1, 0)
    ColorName.Position = UDim2.new(0, 15, 0, 0)
    ColorName.BackgroundTransparency = 1
    ColorName.Text = name
    ColorName.TextColor3 = Color3.fromRGB(255, 255, 255)
    ColorName.Font = Enum.Font.GothamBold
    ColorName.TextSize = 13
    ColorName.TextXAlignment = Enum.TextXAlignment.Left
    ColorName.Parent = ColorContainer
    
    local ColorDisplay = Instance.new("Frame")
    ColorDisplay.Size = UDim2.new(0, 80, 0, 26)
    ColorDisplay.Position = UDim2.new(1, -95, 0.5, -13)
    ColorDisplay.BackgroundColor3 = default
    ColorDisplay.BorderSizePixel = 0
    ColorDisplay.Parent = ColorContainer
    addCorner(ColorDisplay, 6)
    local displayStroke = addStroke(ColorDisplay, Color3.fromRGB(255, 255, 255), 1.5)
    
    local ColorButton = Instance.new("TextButton")
    ColorButton.Size = UDim2.new(1, 0, 1, 0)
    ColorButton.BackgroundTransparency = 1
    ColorButton.Text = ""
    ColorButton.Parent = ColorDisplay
    
    local currentColor = default
    
    ColorContainer.MouseEnter:Connect(function()
        createTween(ColorContainer, {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}, 0.2)
        createTween(containerStroke, {Color = Settings.UIColor}, 0.2)
    end)
    
    ColorContainer.MouseLeave:Connect(function()
        createTween(ColorContainer, {BackgroundColor3 = Color3.fromRGB(16, 16, 22)}, 0.2)
        createTween(containerStroke, {Color = Color3.fromRGB(30, 30, 40)}, 0.2)
    end)
    
    ColorButton.MouseButton1Click:Connect(function()
        local colors = {
            Color3.fromRGB(168, 85, 247), -- Purple
            Color3.fromRGB(244, 63, 94),  -- Cyber Pink / Rose
            Color3.fromRGB(6, 182, 212),  -- Cyan
            Color3.fromRGB(16, 185, 129), -- Emerald Green
            Color3.fromRGB(245, 158, 11), -- Amber Orange
            Color3.fromRGB(239, 68, 68),  -- Red
        }
        
        local currentIndex = 1
        for i, color in ipairs(colors) do
            if color.R == currentColor.R and color.G == currentColor.G and color.B == currentColor.B then
                currentIndex = i
                break
            end
        end
        
        currentIndex = currentIndex % #colors + 1
        currentColor = colors[currentIndex]
        
        createTween(ColorDisplay, {BackgroundColor3 = currentColor}, 0.2)
        callback(currentColor)
    end)
    
    return ColorContainer
end

--------------------------------------------------
-- BUTTON CREATION FUNCTION
--------------------------------------------------
local function createButton(parent, name, description, btnText, callback)
    local ButtonContainer = Instance.new("Frame")
    ButtonContainer.Name = name .. "Container"
    ButtonContainer.Size = UDim2.new(1, -10, 0, 66)
    ButtonContainer.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    ButtonContainer.BorderSizePixel = 0
    ButtonContainer.Parent = parent
    addCorner(ButtonContainer, 10)
    local containerStroke = addStroke(ButtonContainer, Color3.fromRGB(30, 30, 40), 1)
    
    local ButtonName = Instance.new("TextLabel")
    ButtonName.Size = UDim2.new(1, -110, 0, 25)
    ButtonName.Position = UDim2.new(0, 15, 0, 12)
    ButtonName.BackgroundTransparency = 1
    ButtonName.Text = name
    ButtonName.TextColor3 = Color3.fromRGB(255, 255, 255)
    ButtonName.Font = Enum.Font.GothamBold
    ButtonName.TextSize = 14
    ButtonName.TextXAlignment = Enum.TextXAlignment.Left
    ButtonName.Parent = ButtonContainer
    
    local ButtonDesc = Instance.new("TextLabel")
    ButtonDesc.Size = UDim2.new(1, -110, 0, 20)
    ButtonDesc.Position = UDim2.new(0, 15, 0, 35)
    ButtonDesc.BackgroundTransparency = 1
    ButtonDesc.Text = description
    ButtonDesc.TextColor3 = Color3.fromRGB(150, 150, 165)
    ButtonDesc.Font = Enum.Font.Gotham
    ButtonDesc.TextSize = 11
    ButtonDesc.TextXAlignment = Enum.TextXAlignment.Left
    ButtonDesc.Parent = ButtonContainer
    
    local ClickButton = Instance.new("TextButton")
    ClickButton.Name = "ClickButton"
    ClickButton.Size = UDim2.new(0, 80, 0, 28)
    ClickButton.Position = UDim2.new(1, -95, 0.5, -14)
    ClickButton.BackgroundColor3 = Settings.UIColor
    ClickButton.Text = btnText or "Click"
    ClickButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClickButton.Font = Enum.Font.GothamBold
    ClickButton.TextSize = 12
    ClickButton.Parent = ButtonContainer
    addCorner(ClickButton, 8)
    local clickStroke = addStroke(ClickButton, Color3.fromRGB(255, 255, 255), 1)
    clickStroke.Transparency = 0.8
    
    -- Smooth hover transitions
    ButtonContainer.MouseEnter:Connect(function()
        createTween(ButtonContainer, {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}, 0.2)
        createTween(containerStroke, {Color = Settings.UIColor}, 0.2)
    end)
    
    ButtonContainer.MouseLeave:Connect(function()
        createTween(ButtonContainer, {BackgroundColor3 = Color3.fromRGB(16, 16, 22)}, 0.2)
        createTween(containerStroke, {Color = Color3.fromRGB(30, 30, 40)}, 0.2)
    end)
    
    ClickButton.MouseEnter:Connect(function()
        createTween(ClickButton, {BackgroundColor3 = Settings.UIColor:Lerp(Color3.fromRGB(255, 255, 255), 0.15)}, 0.2)
    end)
    
    ClickButton.MouseLeave:Connect(function()
        createTween(ClickButton, {BackgroundColor3 = Settings.UIColor}, 0.2)
    end)
    
    ClickButton.MouseButton1Click:Connect(function()
        -- Snappy click scale animation
        createTween(ClickButton, {Size = UDim2.new(0, 76, 0, 25), Position = UDim2.new(1, -93, 0.5, -12.5)}, 0.1)
        task.wait(0.1)
        createTween(ClickButton, {Size = UDim2.new(0, 80, 0, 28), Position = UDim2.new(1, -95, 0.5, -14)}, 0.1)
        callback()
    end)
    
    return ButtonContainer
end

--------------------------------------------------
-- WATERMARK SYSTEM (TOP STATUS BAR - ANIMATED & AUTO-SIZING)
--------------------------------------------------
local WatermarkFrame = Instance.new("Frame")
WatermarkFrame.Name = "Watermark"
WatermarkFrame.Size = UDim2.new(0, 310, 0, 28)
WatermarkFrame.Position = UDim2.new(1, -330, 0, 15)
WatermarkFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
WatermarkFrame.BackgroundTransparency = 0.15
WatermarkFrame.BorderSizePixel = 0
WatermarkFrame.Active = true -- Capture mouse clicks and touches
WatermarkFrame.Visible = Settings.WatermarkEnabled
WatermarkFrame.Parent = ScreenGui
addCorner(WatermarkFrame, 6)
local watermarkStroke = addStroke(WatermarkFrame, Settings.UIColor, 1.2)
makeDraggable(WatermarkFrame)

-- Watermark Rotating Gradient Border (Matches Main Frame!)
local WatermarkGradient = Instance.new("UIGradient")
WatermarkGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Settings.UIColor),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 40, 55)),
    ColorSequenceKeypoint.new(1, Settings.UIColor)
}
WatermarkGradient.Parent = watermarkStroke

-- Layout for clean horizontal items
local WatermarkLayout = Instance.new("UIListLayout")
WatermarkLayout.FillDirection = Enum.FillDirection.Horizontal
WatermarkLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
WatermarkLayout.VerticalAlignment = Enum.VerticalAlignment.Center
WatermarkLayout.Padding = UDim.new(0, 8)
WatermarkLayout.Parent = WatermarkFrame

local WatermarkPadding = Instance.new("UIPadding")
WatermarkPadding.PaddingLeft = UDim.new(0, 10)
WatermarkPadding.PaddingRight = UDim.new(0, 10)
WatermarkPadding.Parent = WatermarkFrame

-- 1. Animated brand name: "scar.lol"
local BrandLabel = Instance.new("TextLabel")
BrandLabel.Name = "BrandLabel"
BrandLabel.Size = UDim2.new(0, 50, 1, 0)
BrandLabel.BackgroundTransparency = 1
BrandLabel.Text = "scar.lol"
BrandLabel.TextColor3 = Settings.UIColor
BrandLabel.Font = Enum.Font.GothamBold
BrandLabel.TextSize = 11
BrandLabel.Parent = WatermarkFrame

-- 2. Separator 1
local Div1 = Instance.new("TextLabel")
Div1.Size = UDim2.new(0, 5, 1, 0)
Div1.BackgroundTransparency = 1
Div1.Text = "|"
Div1.TextColor3 = Color3.fromRGB(55, 55, 65)
Div1.Font = Enum.Font.Gotham
Div1.TextSize = 11
Div1.Parent = WatermarkFrame

-- 3. FPS counter
local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(0, 45, 1, 0)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Text = "fps: 0"
FPSLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.TextSize = 11
FPSLabel.Parent = WatermarkFrame

-- 4. Separator 2
local Div2 = Instance.new("TextLabel")
Div2.Size = UDim2.new(0, 5, 1, 0)
Div2.BackgroundTransparency = 1
Div2.Text = "|"
Div2.TextColor3 = Color3.fromRGB(55, 55, 65)
Div2.Font = Enum.Font.Gotham
Div2.TextSize = 11
Div2.Parent = WatermarkFrame

-- 5. Ping tracker
local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(0, 65, 1, 0)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "ping: 0ms"
PingLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
PingLabel.Font = Enum.Font.GothamBold
PingLabel.TextSize = 11
PingLabel.Parent = WatermarkFrame

-- 6. Separator 3
local Div3 = Instance.new("TextLabel")
Div3.Size = UDim2.new(0, 5, 1, 0)
Div3.BackgroundTransparency = 1
Div3.Text = "|"
Div3.TextColor3 = Color3.fromRGB(55, 55, 65)
Div3.Font = Enum.Font.Gotham
Div3.TextSize = 11
Div3.Parent = WatermarkFrame

-- 7. Version Label
local VersionLabel = Instance.new("TextLabel")
VersionLabel.Size = UDim2.new(0, 30, 1, 0)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = "v1.1"
VersionLabel.TextColor3 = Color3.fromRGB(130, 130, 145)
VersionLabel.Font = Enum.Font.Gotham
VersionLabel.TextSize = 11
VersionLabel.Parent = WatermarkFrame

-- Resize Watermark Frame dynamically to fit content beautifully
WatermarkLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    WatermarkFrame.Size = UDim2.new(0, WatermarkLayout.AbsoluteContentSize.X + 24, 0, 28)
end)

-- Simple FPS & Ping tracker + Gradient & Brand Text animations
local fpsCount = 0
local lastTick = tick()
local ping = 0
local colorAngle = 0

local watermarkAnimConn
watermarkAnimConn = RunService.RenderStepped:Connect(function()
    if not ScreenGui.Parent then
        watermarkAnimConn:Disconnect()
        return
    end
    
    -- 1. Rotate Watermark Border Gradient
    WatermarkGradient.Rotation = (WatermarkGradient.Rotation + 1.5) % 360
    WatermarkGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Settings.UIColor),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 40, 55)),
        ColorSequenceKeypoint.new(1, Settings.UIColor)
    }
    
    -- 2. Animate "scar.lol" brand text (elegant color cycling rainbow wave)
    colorAngle = colorAngle + 2
    local brandColor
    if Settings.RainbowMode then
        brandColor = Settings.UIColor
    else
        -- Elegant glow pulse between theme color and a slightly brighter accent color
        local ratio = (math.sin(math.rad(colorAngle)) + 1) / 2
        brandColor = Settings.UIColor:Lerp(Color3.fromRGB(255, 255, 255), ratio * 0.35)
    end
    BrandLabel.TextColor3 = brandColor
    
    -- Update FPS & Stats (Throttled update)
    fpsCount = fpsCount + 1
    local currentTick = tick()
    if currentTick - lastTick >= 1 then
        local fps = fpsCount
        fpsCount = 0
        lastTick = currentTick
        
        pcall(function()
            local stats = game:GetService("Stats")
            ping = math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
        end)
        
        FPSLabel.Text = string.format("fps: %d", fps)
        PingLabel.Text = string.format("ping: %dms", ping)
    end
end)

--------------------------------------------------
-- CUSTOM RETICLE CROSSHAIR ENGINE
--------------------------------------------------
local CrosshairContainer = Instance.new("Frame")
CrosshairContainer.Name = "Crosshair"
CrosshairContainer.Size = UDim2.new(0, 100, 0, 100)
CrosshairContainer.Position = UDim2.new(0.5, -50, 0.5, -50)
CrosshairContainer.BackgroundTransparency = 1
CrosshairContainer.Visible = Settings.CrosshairEnabled
CrosshairContainer.Parent = ScreenGui

-- Real-time crosshair animation variables
local crosshairAngle = 0
local crosshairPulseAngle = 0

-- Connection for real-time crosshair animations
local crosshairAnimConn
crosshairAnimConn = RunService.RenderStepped:Connect(function()
    if not ScreenGui.Parent then
        crosshairAnimConn:Disconnect()
        return
    end
    
    if Settings.CrosshairEnabled then
        -- 1. Apply Crosshair Spinning Rotation
        if Settings.CrosshairSpin then
            crosshairAngle = (crosshairAngle + Settings.CrosshairSpinSpeed) % 360
            CrosshairContainer.Rotation = crosshairAngle
        else
            CrosshairContainer.Rotation = 0
        end
        
        -- 2. Apply Crosshair Breathing Pulsation (Modulates Gap)
        if Settings.CrosshairPulse then
            crosshairPulseAngle = (crosshairPulseAngle + 4) % 360
            local pulseOffset = (math.sin(math.rad(crosshairPulseAngle)) + 1) * 3 -- Pulse offset up to 6px
            
            local baseGap = Settings.CrosshairGap
            local currentGap = baseGap + pulseOffset
            
            -- Dynamically reposition crosshair segments based on pulsed gap
            if CrosshairContainer:FindFirstChild("Left_Outline") then
                CrosshairContainer.Left_Outline.Position = UDim2.new(0.5, -currentGap, 0.5, 0)
            end
            if CrosshairContainer:FindFirstChild("Right_Outline") then
                CrosshairContainer.Right_Outline.Position = UDim2.new(0.5, currentGap, 0.5, 0)
            end
            if CrosshairContainer:FindFirstChild("Top_Outline") then
                CrosshairContainer.Top_Outline.Position = UDim2.new(0.5, 0, 0.5, -currentGap)
            end
            if CrosshairContainer:FindFirstChild("Bottom_Outline") then
                CrosshairContainer.Bottom_Outline.Position = UDim2.new(0.5, 0, 0.5, currentGap)
            end
        end
    end
end)

local function drawCrosshairLine(name, isVertical, size, thickness, anchorPoint, position)
    -- Wrapper Frame (Black Outline)
    local wrapper = Instance.new("Frame")
    wrapper.Name = name .. "_Outline"
    wrapper.BorderSizePixel = 0
    wrapper.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    wrapper.AnchorPoint = anchorPoint
    
    -- Inner Colored Line (Your Custom Crosshair)
    local line = Instance.new("Frame")
    line.Name = name
    line.BorderSizePixel = 0
    line.BackgroundColor3 = Settings.CrosshairColor
    
    if isVertical then
        -- Vertical Line: Wrapper is 2px wider and taller than inner line
        wrapper.Size = UDim2.new(0, thickness + 2, 0, size + 2)
        wrapper.Position = position
        
        line.Size = UDim2.new(0, thickness, 0, size)
        line.Position = UDim2.new(0, 1, 0, 1) -- Offset by 1px to center
    else
        -- Horizontal Line: Wrapper is 2px wider and taller than inner line
        wrapper.Size = UDim2.new(0, size + 2, 0, thickness + 2)
        wrapper.Position = position
        
        line.Size = UDim2.new(0, size, 0, thickness)
        line.Position = UDim2.new(0, 1, 0, 1) -- Offset by 1px to center
    end
    
    line.Parent = wrapper
    wrapper.Parent = CrosshairContainer
    return wrapper
end

local crosshairLines = {}

local function updateCrosshair()
    -- Clear previous crosshair lines
    for _, line in pairs(crosshairLines) do
        line:Destroy()
    end
    crosshairLines = {}
    
    if not Settings.CrosshairEnabled then
        CrosshairContainer.Visible = false
        return
    end
    CrosshairContainer.Visible = true
    
    local size = Settings.CrosshairSize
    local gap = Settings.CrosshairGap
    local thickness = Settings.CrosshairThickness
    
    -- Left line (Horizontal)
    crosshairLines.Left = drawCrosshairLine(
        "Left",
        false, -- isVertical
        size,
        thickness,
        Vector2.new(1, 0.5),
        UDim2.new(0.5, -gap, 0.5, 0)
    )
    
    -- Right line (Horizontal)
    crosshairLines.Right = drawCrosshairLine(
        "Right",
        false, -- isVertical
        size,
        thickness,
        Vector2.new(0, 0.5),
        UDim2.new(0.5, gap, 0.5, 0)
    )
    
    -- Top line (Vertical)
    crosshairLines.Top = drawCrosshairLine(
        "Top",
        true, -- isVertical
        size,
        thickness,
        Vector2.new(0.5, 1),
        UDim2.new(0.5, 0, 0.5, -gap)
    )
    
    -- Bottom line (Vertical)
    crosshairLines.Bottom = drawCrosshairLine(
        "Bottom",
        true, -- isVertical
        size,
        thickness,
        Vector2.new(0.5, 0),
        UDim2.new(0.5, 0, 0.5, gap)
    )
end

--------------------------------------------------
-- CREATE TABS
--------------------------------------------------
local FeaturesTab = createTab("Features", "⚡")
local MiscTab = createTab("Misc", "⚙️")
local AdjustmentTab = createTab("Settings", "🎨")

-- Set default tab active state
tabs["Features"].Content.Visible = true
local featLayout = tabs["Features"].Content:FindFirstChildOfClass("UIListLayout")
if featLayout then
    tabs["Features"].Content.Size = UDim2.new(1, 0, 0, featLayout.AbsoluteContentSize.Y)
end
currentTab = "Features"
createTween(tabs["Features"].Button, {BackgroundTransparency = 0, BackgroundColor3 = Settings.UIColor, TextColor3 = Color3.fromRGB(255, 255, 255)})

--------------------------------------------------
-- FEATURES TAB CONTENT
--------------------------------------------------
createToggle(FeaturesTab, "🌀 Orbit Aura", "Unkillable void teleport with orbit", function(enabled)
    toggleOrbitAura(enabled)
    saveConfig()
end)

createToggle(FeaturesTab, "💊 Auto Collect", "Automatically collect health and ammo", function(enabled)
    toggleAutoCollect(enabled)
    saveConfig()
end)

createToggle(FeaturesTab, "🔄 Auto Respawn", "Instantly respawn when you die", function(enabled)
    toggleAutoRespawn(enabled)
    saveConfig()
end)

createToggle(FeaturesTab, "⚡ FPS Booster", "Optimize game performance", function(enabled)
    toggleFPSBoost(enabled)
    saveConfig()
end)

--------------------------------------------------
-- MISC TAB CONTENT
--------------------------------------------------
createToggle(MiscTab, "📋 Watermark", "Toggle top status bar details", function(enabled)
    Settings.WatermarkEnabled = enabled
    WatermarkFrame.Visible = enabled
    saveConfig()
end)

createToggle(MiscTab, "🎯 Custom Crosshair", "Draw elegant neon crosshair lines", function(enabled)
    Settings.CrosshairEnabled = enabled
    updateCrosshair()
    saveConfig()
end)

createSlider(MiscTab, "🎯 Crosshair Size", 2, 30, Settings.CrosshairSize, function(value)
    Settings.CrosshairSize = value
    updateCrosshair()
    saveConfig()
end)

createSlider(MiscTab, "🎯 Crosshair Gap", 0, 20, Settings.CrosshairGap, function(value)
    Settings.CrosshairGap = value
    updateCrosshair()
    saveConfig()
end)

createSlider(MiscTab, "🎯 Crosshair Weight", 1, 8, Settings.CrosshairThickness, function(value)
    Settings.CrosshairThickness = value
    updateCrosshair()
    saveConfig()
end)

createColorPicker(MiscTab, "🎯 Crosshair Color", Settings.CrosshairColor, function(color)
    Settings.CrosshairColor = color
    updateCrosshair()
    saveConfig()
end)

createToggle(MiscTab, "🔄 Crosshair Spin", "Spin the crosshair lines tactically", function(enabled)
    Settings.CrosshairSpin = enabled
    saveConfig()
end)

createSlider(MiscTab, "🔄 Spin Speed", 1, 10, Settings.CrosshairSpinSpeed, function(value)
    Settings.CrosshairSpinSpeed = value
    saveConfig()
end)

createToggle(MiscTab, "💓 Crosshair Pulse", "Make the crosshair lines breathe dynamic gaps", function(enabled)
    Settings.CrosshairPulse = enabled
    if not enabled then
        updateCrosshair() -- Instantly reset back to default static gap position
    end
    saveConfig()
end)

--------------------------------------------------
-- ADJUSTMENT TAB CONTENT
--------------------------------------------------
createColorPicker(AdjustmentTab, "UI Theme Color", Settings.UIColor, function(color)
    Settings.UIColor = color
    
    -- Update active accent elements
    createTween(LogoText, {TextColor3 = color})
    createTween(ToggleGlow, {ImageColor3 = color})
    createTween(toggleFrameStroke, {Color = color})
    createTween(MainWindowStroke, {Color = color})
    createTween(watermarkStroke, {Color = color})
    ContentFrame.ScrollBarImageColor3 = color
    
    for tabName, tab in pairs(tabs) do
        if tabName == currentTab then
            createTween(tab.Button, {BackgroundColor3 = color})
        end
    end
    
    -- Update active toggles and sliders
    for _, child in pairs(ContentFrame:GetDescendants()) do
        if child.Name == "ToggleButton" and child:FindFirstChild("Indicator") then
            local indicator = child.Indicator
            if indicator.Position.X.Offset > 10 then -- Active switch
                createTween(child, {BackgroundColor3 = color})
                local stroke = child:FindFirstChildOfClass("UIStroke")
                if stroke then createTween(stroke, {Color = color}) end
            end
        elseif child.Name == "SliderFill" then
            createTween(child, {BackgroundColor3 = color})
        elseif child.Name == "SliderButton" then
            local stroke = child:FindFirstChildOfClass("UIStroke")
            if stroke then createTween(stroke, {Color = color}) end
        elseif child.Name == "SliderValue" then
            createTween(child, {TextColor3 = color})
        end
    end
    saveConfig()
end)

createSlider(AdjustmentTab, "UI Transparency", 0, 90, Settings.UITransparency * 100, function(value)
    Settings.UITransparency = value / 100
    createTween(MainFrame, {BackgroundTransparency = Settings.UITransparency})
    saveConfig()
end)

createSlider(AdjustmentTab, "Animation Speed", 1, 10, Settings.AnimationSpeed * 10, function(value)
    Settings.AnimationSpeed = value / 10
    saveConfig()
end)

createToggle(AdjustmentTab, "✨ Glow Effect", "Add glow to UI elements", function(enabled)
    Settings.GlowEnabled = enabled
    Shadow.Visible = enabled
    ToggleGlow.Visible = enabled
    saveConfig()
end)

createToggle(AdjustmentTab, "🌈 Rainbow Mode", "Cycle through colors automatically", function(enabled)
    Settings.RainbowMode = enabled
    
    if enabled then
        task.spawn(function()
            local hue = 0
            while Settings.RainbowMode do
                hue = (hue + 1) % 360
                local color = Color3.fromHSV(hue / 360, 0.8, 0.95)
                Settings.UIColor = color
                
                createTween(LogoText, {TextColor3 = color}, 0.1)
                createTween(ToggleGlow, {ImageColor3 = color}, 0.1)
                createTween(toggleFrameStroke, {Color = color}, 0.1)
                createTween(MainWindowStroke, {Color = color}, 0.1)
                createTween(watermarkStroke, {Color = color}, 0.1)
                ContentFrame.ScrollBarImageColor3 = color
                
                for tabName, tab in pairs(tabs) do
                    if tabName == currentTab then
                        createTween(tab.Button, {BackgroundColor3 = color}, 0.1)
                    end
                end
                
                -- Dynamic updating of toggles, fills and active buttons
                for _, child in pairs(ContentFrame:GetDescendants()) do
                    if child.Name == "ToggleButton" and child:FindFirstChild("Indicator") then
                        local indicator = child.Indicator
                        if indicator.Position.X.Offset > 10 then
                            createTween(child, {BackgroundColor3 = color}, 0.1)
                            local stroke = child:FindFirstChildOfClass("UIStroke")
                            if stroke then createTween(stroke, {Color = color}, 0.1) end
                        end
                    elseif child.Name == "SliderFill" then
                        createTween(child, {BackgroundColor3 = color}, 0.1)
                    elseif child.Name == "SliderButton" then
                        local stroke = child:FindFirstChildOfClass("UIStroke")
                        if stroke then createTween(stroke, {Color = color}, 0.1) end
                    elseif child.Name == "SliderValue" then
                        createTween(child, {TextColor3 = color}, 0.1)
                    end
                end
                
                task.wait(0.05)
            end
        end)
    end
    saveConfig()
end)

createButton(AdjustmentTab, "💾 Save Config", "Manually write settings to scar_configs.json", "Save", function()
    saveConfig()
    createNotification("💾 Config saved successfully!")
end)

createButton(AdjustmentTab, "🔄 Reset Config", "Reset settings to factory defaults", "Reset", function()
    pcall(function()
        if delfile then
            delfile(CONFIG_FILE)
        elseif writefile then
            writefile(CONFIG_FILE, "{}")
        end
    end)
    createNotification("🔄 Config reset! Please re-inject.")
end)

createToggle(AdjustmentTab, "⚡ Auto Execute", "Auto-run script on match teleports", function(enabled)
    Settings.AutoExecute = enabled
    saveConfig()
    if enabled then
        createNotification("⚡ Auto Execute active for next match!")
        if registerTeleportQueue then
            registerTeleportQueue()
        end
    else
        createNotification("🚫 Teleport Auto-Execute disabled.")
    end
end)

createButton(AdjustmentTab, "🔴 Uninject", "Completely remove and clean up scar.lol", "Clean Up", function()
    -- 1. Turn off all cheats immediately & safely
    toggleOrbitAura(false)
    toggleAutoCollect(false)
    toggleAutoRespawn(false)
    toggleFPSBoost(false) -- Restores lighting & graphics automatically!
    
    -- 2. Turn off crosshairs and watermarks
    Settings.WatermarkEnabled = false
    Settings.CrosshairEnabled = false
    Settings.RainbowMode = false
    
    if WatermarkFrame then WatermarkFrame.Visible = false end
    if CrosshairContainer then CrosshairContainer.Visible = false end
    
    -- 3. Disconnect CharacterAdded connection and clean up variables
    if charAddedConn then
        charAddedConn:Disconnect()
        charAddedConn = nil
    end
    if charAddedConn2 then
        charAddedConn2:Disconnect()
        charAddedConn2 = nil
    end
    
    -- 4. Play a gorgeous fading out animation on all core frames
    createTween(MainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    createTween(ToggleFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.35, Enum.EasingStyle.Quad)
    createTween(WatermarkFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.35, Enum.EasingStyle.Quad)
    
    task.wait(0.35)
    
    -- 5. Safe destruction of the parent GUI container (removes ALL elements instantly)
    ScreenGui:Destroy()
    
    -- 6. Console notification
    print("╔═══════════════════════════════════════╗")
    print("║          scar.lol - UNINJECTED ✓      ║")
    print("║ All connections closed & cleaned.     ║")
    print("╚═══════════════════════════════════════╝")
end)

--------------------------------------------------
-- TOGGLE MENU FUNCTIONALITY (GORGEOUS TRANSITION)
--------------------------------------------------
local isMenuOpen = false

ToggleButton.MouseButton1Click:Connect(function()
    isMenuOpen = not isMenuOpen
    
    if isMenuOpen then
        MainFrame.Visible = true
        createTween(MainFrame, {Size = UDim2.new(0, 430, 0, 560), BackgroundTransparency = Settings.UITransparency}, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        createTween(ToggleButton, {Rotation = 135}, 0.35, Enum.EasingStyle.Quad)
    else
        createTween(MainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        createTween(ToggleButton, {Rotation = 0}, 0.35, Enum.EasingStyle.Quad)
        task.wait(0.4)
        if not isMenuOpen then
            MainFrame.Visible = false
        end
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    isMenuOpen = false
    createTween(MainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    createTween(ToggleButton, {Rotation = 0}, 0.35, Enum.EasingStyle.Quad)
    task.wait(0.4)
    if not isMenuOpen then
        MainFrame.Visible = false
    end
end)

--------------------------------------------------
-- CHARACTER RESPAWN HANDLER
--------------------------------------------------
charAddedConn2 = LocalPlayer.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
    
    -- Reconnect orbit aura if it was enabled
    if FeatureStates.OrbitAura then
        toggleOrbitAura(false)
        task.wait(0.1)
        toggleOrbitAura(true)
    end
    
    -- Setup auto respawn
    if FeatureStates.AutoRespawn then
        setupRespawn(char)
    end
end)

--------------------------------------------------
-- INITIALIZATION
--------------------------------------------------
print("╔═══════════════════════════════════════╗")
print("║             scar.lol - LOADED ✓       ║")
print("║ Version: 1.1 | Made by: scar          ║")
print("║ Mobile Optimized | Press ⚡ to open!  ║")
print("╚═══════════════════════════════════════╝")

-- Dynamic Startup Executors (Applies loaded configuration states on start)
task.spawn(function()
    task.wait(0.3) -- Give Roblox CoreGui a frame tick to construct completely
    if FeatureStates.OrbitAura then toggleOrbitAura(true) end
    if FeatureStates.AutoCollect then toggleAutoCollect(true) end
    if FeatureStates.AutoRespawn then toggleAutoRespawn(true) end
    if FeatureStates.FPSBoost then toggleFPSBoost(true) end
    
    -- Start Rainbow Mode loop automatically if loaded as active
    if Settings.RainbowMode then
        task.spawn(function()
            local hue = 0
            while Settings.RainbowMode do
                hue = (hue + 1) % 360
                local color = Color3.fromHSV(hue / 360, 0.8, 0.95)
                Settings.UIColor = color
                
                pcall(function()
                    createTween(LogoText, {TextColor3 = color}, 0.1)
                    createTween(ToggleGlow, {ImageColor3 = color}, 0.1)
                    createTween(toggleFrameStroke, {Color = color}, 0.1)
                    createTween(MainWindowStroke, {Color = color}, 0.1)
                    createTween(watermarkStroke, {Color = color}, 0.1)
                    ContentFrame.ScrollBarImageColor3 = color
                    
                    for tabName, tab in pairs(tabs) do
                        if tabName == currentTab then
                            createTween(tab.Button, {BackgroundColor3 = color}, 0.1)
                        end
                    end
                    
                    for _, child in pairs(ContentFrame:GetDescendants()) do
                        if child.Name == "ToggleButton" and child:FindFirstChild("Indicator") then
                            local indicator = child.Indicator
                            if indicator.Position.X.Offset > 10 then
                                createTween(child, {BackgroundColor3 = color}, 0.1)
                                local stroke = child:FindFirstChildOfClass("UIStroke")
                                if stroke then createTween(stroke, {Color = color}, 0.1) end
                            end
                        elseif child.Name == "SliderFill" then
                            createTween(child, {BackgroundColor3 = color}, 0.1)
                        elseif child.Name == "SliderButton" then
                            local stroke = child:FindFirstChildOfClass("UIStroke")
                            if stroke then createTween(stroke, {Color = color}, 0.1) end
                        elseif child.Name == "SliderValue" then
                            createTween(child, {TextColor3 = color}, 0.1)
                        end
                    end
                end)
                task.wait(0.05)
            end
        end)
    end
end)

-- Notification Creator
createNotification = function(text)
    local NotifFrame = Instance.new("Frame")
    NotifFrame.Size = UDim2.new(0, 310, 0, 65)
    NotifFrame.Position = UDim2.new(1, 10, 1, -85)
    NotifFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    NotifFrame.BorderSizePixel = 0
    NotifFrame.Parent = ScreenGui
    addCorner(NotifFrame, 10)
    local notifStroke = addStroke(NotifFrame, Settings.UIColor, 1.5)
    
    local AccentBar = Instance.new("Frame")
    AccentBar.Size = UDim2.new(0, 5, 1, 0)
    AccentBar.BackgroundColor3 = Settings.UIColor
    AccentBar.BorderSizePixel = 0
    AccentBar.Parent = NotifFrame
    addCorner(AccentBar, 10)
    
    local AccentMask = Instance.new("Frame")
    AccentMask.Size = UDim2.new(0, 3, 1, 0)
    AccentMask.Position = UDim2.new(1, -3, 0, 0)
    AccentMask.BackgroundColor3 = Settings.UIColor
    AccentMask.BorderSizePixel = 0
    AccentMask.Parent = AccentBar
    
    local NotifText = Instance.new("TextLabel")
    NotifText.Size = UDim2.new(1, -35, 1, 0)
    NotifText.Position = UDim2.new(0, 20, 0, 0)
    NotifText.BackgroundTransparency = 1
    NotifText.Text = text
    NotifText.TextColor3 = Color3.fromRGB(255, 255, 255)
    NotifText.Font = Enum.Font.GothamBold
    NotifText.TextSize = 12
    NotifText.TextWrapped = true
    NotifText.TextXAlignment = Enum.TextXAlignment.Left
    NotifText.Parent = NotifFrame
    
    -- Animate entry (slide left with bounce)
    createTween(NotifFrame, {Position = UDim2.new(1, -325, 1, -85)}, 0.4, Enum.EasingStyle.Quad)
    
    task.spawn(function()
        task.wait(3.5)
        -- Animate exit
        createTween(NotifFrame, {Position = UDim2.new(1, 10, 1, -85)}, 0.4, Enum.EasingStyle.Quad)
        task.wait(0.4)
        NotifFrame:Destroy()
    end)
end

createNotification("✅ scar.lol Loaded!\nMade by: scar")

--------------------------------------------------
-- TELEPORT AUTO-EXECUTION (AUTO-RUN IN NEW MATCHES)
--------------------------------------------------
registerTeleportQueue = function()
    pcall(function()
        local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
        if queue then
            local code = [[
                pcall(function()
                    if isfile then
                        if isfile("rivals.lua") then
                            loadstring(readfile("rivals.lua"))()
                        elseif isfile("scar.lua") then
                            loadstring(readfile("scar.lua"))()
                        end
                    end
                end)
            ]]
            queue(code)
        end
    end)
end

if Settings.AutoExecute then
    registerTeleportQueue()
end
