if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Wait 8 seconds to ensure UE Ragebot and other executors fully load
task.wait(8)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local rs = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

-- Cleanup previous scarGui instances just in case
local targetGuiParent = (gethui and gethui()) or CoreGui
for _, child in ipairs(targetGuiParent:GetChildren()) do
    if child.Name == "scarGui" then
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
    autoCollect = false,
    autoRespawn = false,
    fpsBoost = false,
    espActive = false,
    espType = "Highlight",
    espColorR = 255, espColorG = 0, espColorB = 0,
    espTransparency = 0.5
}

local voidActive, orbitActive, autoExecute = false, false, false
local autoCollect, autoRespawn, fpsBoost = false, false, false
local voidConnection, orbitConnection, collectConnection, respawnConnection

-- ESP Settings
local espActive = false
local espType = "Highlight"
local espColor = Color3.fromRGB(255, 0, 0)
local espTransparency = 0.5
local espCache = {}

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
            fpsBoost = fpsBoost,
            espActive = espActive,
            espType = espType,
            espColorR = espColor.R * 255, espColorG = espColor.G * 255, espColorB = espColor.B * 255,
            espTransparency = espTransparency
        }
        pcall(function() writefile(configFileName, HttpService:JSONEncode(data)) end)
    end
end

local function getVoidValue()
    local val = math.random(1147483646, 2147483646)
    return math.random() > 0.5 and val or -val
end

--------------------------------------------------
-- ESP CORE
--------------------------------------------------
local function clearESP(player)
    if espCache[player] then
        if espCache[player].type == "Highlight" then
            if espCache[player].obj then espCache[player].obj:Destroy() end
        elseif espCache[player].type == "ForceField" then
            if player.Character then
                for part, data in pairs(espCache[player].originalMats) do
                    if part and part.Parent then
                        part.Material = data.Material
                        part.Color = data.Color
                    end
                end
            end
        end
        espCache[player] = nil
    end
end

local function clearAllESP()
    for player, _ in pairs(espCache) do
        clearESP(player)
    end
end

local function updateESP()
    if not espActive then
        clearAllESP()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == Players.LocalPlayer then continue end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if char and hrp then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if espCache[player] and espCache[player].type ~= espType then
                    clearESP(player)
                end
                
                if espType == "Highlight" then
                    if not espCache[player] then
                        local hl = Instance.new("Highlight")
                        hl.Parent = char
                        hl.Name = "ESP_Highlight"
                        espCache[player] = {type = "Highlight", obj = hl}
                    end
                    local hl = espCache[player].obj
                    if hl.Parent ~= char then hl.Parent = char end
                    hl.FillColor = espColor
                    hl.OutlineColor = espColor
                    hl.FillTransparency = espTransparency
                    hl.OutlineTransparency = 0.1
                    
                elseif espType == "ForceField" then
                    if not espCache[player] then
                        espCache[player] = {type = "ForceField", originalMats = {}}
                    end
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                            if not espCache[player].originalMats[part] then
                                espCache[player].originalMats[part] = {
                                    Material = part.Material,
                                    Color = part.Color
                                }
                            end
                            part.Material = Enum.Material.ForceField
                            part.Color = espColor
                        end
                    end
                end
            else
                clearESP(player) -- Dead
            end
        else
            clearESP(player) -- No char
        end
    end
end

local espConnection
local function toggleESP(state)
    espActive = state
    if espActive then
        if not espConnection then
            espConnection = rs.RenderStepped:Connect(updateESP)
        end
    else
        if espConnection then espConnection:Disconnect(); espConnection = nil end
        clearAllESP()
    end
end
Players.PlayerRemoving:Connect(clearESP)

--------------------------------------------------
-- CORE LOGIC FUNCTIONS
--------------------------------------------------

-- VOID SPAM
local function toggleVoid(state)
    voidActive = state
    if voidActive then
        if voidConnection then voidConnection:Disconnect() end
        voidConnection = rs.Stepped:Connect(function()
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(getVoidValue(), math.random(200000, 500000), getVoidValue())
                hrp.AssemblyLinearVelocity = Vector3.new(getVoidValue(), getVoidValue(), getVoidValue())
                
                local closest = nil
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= Players.LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        closest = v.Character.HumanoidRootPart
                        break
                    end
                end
                
                if closest then
                    local angle = tick() * 2
                    local offset = Vector3.new(math.cos(angle)*10, 5, math.sin(angle)*10)
                    Camera.CFrame = CFrame.new(Vector3.new(0, 50, 0), closest.Position + offset)
                end
            end
        end)
    else
        if voidConnection then voidConnection:Disconnect() voidConnection = nil end
        local char = Players.LocalPlayer.Character
        if char then Camera.CameraSubject = char:FindFirstChild("Humanoid") end
    end
end

-- ORBIT
local function toggleOrbit(state)
    orbitActive = state
    if orbitActive then
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

-- AUTO COLLECT
local function toggleCollect(state)
    autoCollect = state
    if autoCollect then
        if collectConnection then collectConnection:Disconnect() end
        collectConnection = rs.RenderStepped:Connect(function()
            local char = Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, obj in pairs(workspace:GetChildren()) do
                if obj.Name == "_drop" and obj:IsA("BasePart") then
                    if firetouchinterest then
                        firetouchinterest(hrp, obj, 0)
                        firetouchinterest(hrp, obj, 1)
                    end
                end
            end
        end)
    else
        if collectConnection then collectConnection:Disconnect() collectConnection = nil end
    end
end

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
            if obj:IsA("BasePart") then obj.Material = Enum.Material.Plastic obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = 1 end
        end
    else
        Lighting.GlobalShadows = true
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
    Main = Window:AddTab('Main'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local LeftGroupBox = Tabs.Main:AddLeftGroupbox('Features')
local RightGroupBox = Tabs.Main:AddRightGroupbox('Visuals')

LeftGroupBox:AddToggle('VoidToggle', {
    Text = 'Toggle Void Spam',
    Default = false,
    Tooltip = 'Rapidly teleports you into the void while orbiting target',
    Callback = function(Value)
        toggleVoid(Value)
        saveConfig()
    end
}):AddKeyPicker('VoidKey', { Default = 'None', Text = 'Void Spam', SyncToggleState = true })

LeftGroupBox:AddToggle('OrbitToggle', {
    Text = 'Toggle Orbit',
    Default = false,
    Tooltip = 'Orbits the closest player',
    Callback = function(Value)
        toggleOrbit(Value)
        saveConfig()
    end
}):AddKeyPicker('OrbitKey', { Default = 'None', Text = 'Orbit', SyncToggleState = true })

LeftGroupBox:AddToggle('CollectToggle', {
    Text = 'Auto Collect',
    Default = false,
    Tooltip = 'Automatically collects drops',
    Callback = function(Value)
        toggleCollect(Value)
        saveConfig()
    end
}):AddKeyPicker('CollectKey', { Default = 'None', Text 'Auto Collect', SyncToggleState = true })

LeftGroupBox:AddToggle('RespawnToggle', {
    Text = 'Auto Respawn',
    Default = false,
    Tooltip = 'Automatically respawns you upon death',
    Callback = function(Value)
        toggleRespawn(Value)
        saveConfig()
    end
}):AddKeyPicker('RespawnKey', { Default = 'None', Text = 'Auto Respawn', SyncToggleState = true })

LeftGroupBox:AddToggle('FPSToggle', {
    Text = 'FPS Booster',
    Default = false,
    Tooltip = 'Lowers graphics for better performance',
    Callback = function(Value)
        toggleFPS(Value)
        saveConfig()
    end
}):AddKeyPicker('FPSKey', { Default = 'None', Text = 'FPS Booster', SyncToggleState = true })


RightGroupBox:AddToggle('ESPToggle', {
    Text = 'Enable ESP',
    Default = false,
    Tooltip = 'Shows players through walls',
    Callback = function(Value)
        toggleESP(Value)
        saveConfig()
    end
}):AddKeyPicker('ESPKey', { Default = 'None', Text = 'Enable ESP', SyncToggleState = true })

RightGroupBox:AddDropdown('ESPType', {
    Values = { 'Highlight', 'ForceField' },
    Default = 1,
    Text = 'ESP Mode',
    Callback = function(Value)
        espType = Value
        if espActive then clearAllESP() end
        saveConfig()
    end
})

RightGroupBox:AddColorPicker('ESPColor', {
    Default = Color3.fromRGB(255, 0, 0),
    Title = 'ESP Color',
    Callback = function(Value)
        espColor = Value
        saveConfig()
    end
})

RightGroupBox:AddSlider('ESPTransparency', {
    Text = 'Fill Transparency',
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 1,
    Callback = function(Value)
        espTransparency = Value
        saveConfig()
    end
})

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
    toggleVoid(false)
    toggleOrbit(false)
    toggleCollect(false)
    toggleRespawn(false)
    toggleFPS(false)
    toggleESP(false)
end)

--------------------------------------------------
-- INITIALIZE CONFIG
--------------------------------------------------
task.spawn(function()
    local cfg = loadConfig()
    if cfg.espColorR then
        espColor = Color3.fromRGB(cfg.espColorR / 255, cfg.espColorG / 255, cfg.espColorB / 255)
        Options.ESPColor:SetValueRGB(espColor)
    end
    if cfg.espTransparency then Options.ESPTransparency:SetValue(cfg.espTransparency) end
    if cfg.espType then Options.ESPType:SetValue(cfg.espType) end

    if cfg.autoExecute then Options.AutoExecToggle:SetValue(true) end
    if cfg.voidActive then Options.VoidToggle:SetValue(true) end
    if cfg.orbitActive then Options.OrbitToggle:SetValue(true) end
    if cfg.autoCollect then Options.CollectToggle:SetValue(true) end
    if cfg.autoRespawn then Options.RespawnToggle:SetValue(true) end
    if cfg.fpsBoost then Options.FPSToggle:SetValue(true) end
    if cfg.espActive then Options.ESPToggle:SetValue(true) end
end)
