if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(2)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local rs = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

-- Cleanup previous instances
local targetGuiParent = (gethui and gethui()) or CoreGui
for _, child in ipairs(targetGuiParent:GetChildren()) do
    if child.Name == "scarGui" or child.Name == "ESPPreviewGui" then
        child:Destroy()
    end
end

-- Unload existing LinoriaLib if we're re-executing
if shared._scar_lib_unload then
    pcall(shared._scar_lib_unload)
end

--------------------------------------------------
-- CONFIG SYSTEM
--------------------------------------------------
local configFileName = "scar_lol_config.json"
local defaultConfig = {
    voidActive = false,
    orbitActive = false,
    autoExecute = false,
    autoRespawn = false,
    fpsBoost = false
}

-- Config active states (functional features)
local autoExecute = false
local autoRespawn = false
local fpsBoost = false
local voidActive = false
local orbitActive = false

local respawnConnection
local voidConnection
local orbitConnection

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
            autoRespawn = autoRespawn,
            fpsBoost = fpsBoost
        }
        pcall(function() writefile(configFileName, HttpService:JSONEncode(data)) end)
    end
end

-- Generates safe high-altitude coordinates to prevent float/physics engine crashes
local function getVoidValue()
    local val = math.random(100000, 300000)
    return math.random() > 0.5 and val or -val
end

--------------------------------------------------
-- UTILITY & AUTOMATION LOGIC (FUNCTIONAL)
--------------------------------------------------

-- AUTO RESPAWN
local function toggleRespawn(state)
    autoRespawn = state
    if autoRespawn then
        if respawnConnection then respawnConnection:Disconnect() end
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
        if respawnConnection then respawnConnection:Disconnect() respawnConnection = nil end
    end
end

-- FPS BOOSTER
local function toggleFPS(state)
    fpsBoost = state
    if fpsBoost then
        Lighting.GlobalShadows = false
        Lighting.Brightness = 1
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then 
                obj.Material = Enum.Material.Plastic 
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then 
                obj.Transparency = 1 
            end
        end
    else
        Lighting.GlobalShadows = true
    end
end

-- VOID SPAM
local function toggleVoid(state)
    voidActive = state
    if voidActive then
        -- Mutually exclusive with Orbit to prevent physics conflicts and crashes
        if orbitActive then
            if Toggles and Toggles.OrbitToggle then
                Toggles.OrbitToggle:SetValue(false)
            else
                orbitActive = false
                if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
            end
        end
        
        if voidConnection then voidConnection:Disconnect() end
        voidConnection = rs.Stepped:Connect(function()
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Set stable coordinates and clean velocity vectors to prevent physics crashes
                hrp.CFrame = CFrame.new(getVoidValue(), math.random(200000, 300000), getVoidValue())
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                
                local closest = nil
                local minDist = 99999
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= Players.LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (v.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                        if dist < minDist then
                            closest = v.Character.HumanoidRootPart
                            minDist = dist
                        end
                    end
                end
                
                -- Robust, crash-free camera tracking using native camera subjects
                if closest and closest.Parent then
                    local hum = closest.Parent:FindFirstChildOfClass("Humanoid")
                    if hum then
                        Camera.CameraSubject = hum
                    else
                        Camera.CameraSubject = closest
                    end
                end
            end
        end)
    else
        if voidConnection then voidConnection:Disconnect() voidConnection = nil end
        local char = Players.LocalPlayer.Character
        if char then 
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                Camera.CameraSubject = hum
            end
        end
    end
end

-- ORBIT
local function toggleOrbit(state)
    orbitActive = state
    if orbitActive then
        -- Mutually exclusive with Void Spam to prevent physics conflicts and crashes
        if voidActive then
            if Toggles and Toggles.VoidToggle then
                Toggles.VoidToggle:SetValue(false)
            else
                voidActive = false
                if voidConnection then voidConnection:Disconnect() voidConnection = nil end
            end
        end
        
        if orbitConnection then orbitConnection:Disconnect() end
        orbitConnection = rs.RenderStepped:Connect(function(dt)
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local closest, dist = nil, 10000
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
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
    end
end

-- AUTO EXECUTE / QUEUE ON TELEPORT
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

--------------------------------------------------
-- LINORIALIB GUI CREATION
--------------------------------------------------
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

shared._scar_lib_unload = function()
    Library:Unload()
end

local Window = Library:CreateWindow({
    Title = 'scar.lol',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Misc = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- MISC TAB
local AutomationGroup = Tabs.Misc:AddLeftGroupbox('Automation')
local PerformanceGroup = Tabs.Misc:AddRightGroupbox('Performance')

AutomationGroup:AddToggle('VoidToggle', {
    Text = 'Toggle Void Spam',
    Default = false,
    Tooltip = 'Rapidly teleports you into the void while orbiting target',
    Callback = function(Value)
        toggleVoid(Value)
        saveConfig()
    end
}):AddKeyPicker('VoidKey', { 
    Default = 'None', 
    Text = 'Void Spam', 
    SyncToggleState = true,
    NoUI = true
})

AutomationGroup:AddToggle('OrbitToggle', {
    Text = 'Toggle Orbit',
    Default = false,
    Tooltip = 'Orbits the closest player',
    Callback = function(Value)
        toggleOrbit(Value)
        saveConfig()
    end
}):AddKeyPicker('OrbitKey', { 
    Default = 'None', 
    Text = 'Orbit', 
    SyncToggleState = true,
    NoUI = true
})

AutomationGroup:AddToggle('RespawnToggle', {
    Text = 'Auto Respawn',
    Default = false,
    Tooltip = 'Automatically respawns you upon death',
    Callback = function(Value)
        toggleRespawn(Value)
        saveConfig()
    end
}):AddKeyPicker('RespawnKey', { 
    Default = 'None', 
    Text = 'Auto Respawn', 
    SyncToggleState = true,
    NoUI = true
})

PerformanceGroup:AddToggle('FPSToggle', {
    Text = 'FPS Booster',
    Default = false,
    Tooltip = 'Lowers graphics settings for maximum performance',
    Callback = function(Value)
        toggleFPS(Value)
        saveConfig()
    end
}):AddKeyPicker('FPSKey', { 
    Default = 'None', 
    Text = 'FPS Booster', 
    SyncToggleState = true,
    NoUI = true
})

-- UI SETTINGS TAB
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddToggle('AutoExecToggle', {
    Text = 'Auto Execute (Queue On Teleport)',
    Default = false,
    Tooltip = 'Automatically executes scar.lol on server hop',
    Callback = function(Value)
        autoExecute = Value
        if autoExecute then applyQueueOnTeleport() end
        saveConfig()
    end
})

MenuGroup:AddToggle('KeybindsListToggle', {
    Text = 'Show Keybinds',
    Default = true,
    Callback = function(Value)
        Library.KeybindFrame.Visible = Value
    end
})
Library.KeybindFrame.Visible = true -- initialize visible by default

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

-- Set watermark
Library:SetWatermarkVisibility(true)
Library:SetWatermark('scar.lol')

ThemeManager:SetFolder('scarlol')
SaveManager:SetFolder('scarlol/rivals')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

-- Unload handler to disconnect connections
Library:OnUnload(function()
    toggleRespawn(false)
    toggleVoid(false)
    toggleOrbit(false)
    toggleFPS(false)
end)

--------------------------------------------------
-- INITIALIZE CONFIG
--------------------------------------------------
task.spawn(function()
    local cfg = loadConfig()
    
    -- Ensure Option elements are fully registered before setting values to avoid startup execution crashes
    task.wait(1.5) 
    
    if cfg.autoExecute and Toggles and Toggles.AutoExecToggle then Toggles.AutoExecToggle:SetValue(true) end
    if cfg.autoRespawn and Toggles and Toggles.RespawnToggle then Toggles.RespawnToggle:SetValue(true) end
    if cfg.fpsBoost and Toggles and Toggles.FPSToggle then Toggles.FPSToggle:SetValue(true) end
    if cfg.voidActive and Toggles and Toggles.VoidToggle then Toggles.VoidToggle:SetValue(true) end
    if cfg.orbitActive and Toggles and Toggles.OrbitToggle then Toggles.OrbitToggle:SetValue(true) end
end)
