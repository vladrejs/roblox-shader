-- ============================================================================
-- UNIVERSAL PBR CINEMATIC SHADERS (PC + MOBILE TOUCH PANEL + [V] / [C] KEYS)
-- Працює однаково на ПК і телефоні:
--   • На ПК: [V] — День / Вечір / Ніч, [C] — повне видалення шейдера
--   • На телефоні (і на ПК): екранна панель з перемикачем режиму,
--     кнопкою повного видалення та згортанням/відкриттям панелі
-- ============================================================================

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

-- ============================================================================
-- 1. АВТОВИДАЛЕННЯ ПОПЕРЕДНЬОЇ КОПІЇ ПРИ ПОВТОРНОМУ ЗАПУСКУ
-- ============================================================================
if getgenv then
    if getgenv()._UniversalShaderCleanup then
        pcall(getgenv()._UniversalShaderCleanup)
    end
elseif _G._UniversalShaderCleanup then
    pcall(_G._UniversalShaderCleanup)
end

-- ============================================================================
-- 2. ЗБЕРЕЖЕННЯ ОРИГІНАЛЬНИХ НАЛАШТУВАНЬ МАПИ (ДЛЯ ПОВНОГО ВІДКАТУ)
-- ============================================================================
local OriginalLightingState = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    ExposureCompensation = Lighting.ExposureCompensation,
    GlobalShadows = Lighting.GlobalShadows,
    ShadowSoftness = Lighting.ShadowSoftness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    FogColor = Lighting.FogColor,
    GeographicLatitude = Lighting.GeographicLatitude
}

local OriginalWaterState = nil
if Terrain then
    OriginalWaterState = {
        WaterColor = Terrain.WaterColor,
        WaterReflectance = Terrain.WaterReflectance,
        WaterTransparency = Terrain.WaterTransparency,
        WaterWaveSize = Terrain.WaterWaveSize,
        WaterWaveSpeed = Terrain.WaterWaveSpeed
    }
end

local HiddenOriginalInstances = {}
for _, item in ipairs(Lighting:GetChildren()) do
    if item:IsA("PostEffect") or item:IsA("Atmosphere") or item:IsA("Sky") or item:IsA("Clouds") then
        if item.Name:sub(1, 15) == "UnivShaderObj__" then
            item:Destroy()
        else
            table.insert(HiddenOriginalInstances, { Instance = item, Parent = Lighting })
            item.Parent = nil
        end
    end
end

if Terrain then
    for _, item in ipairs(Terrain:GetChildren()) do
        if item:IsA("Clouds") then
            if item.Name:sub(1, 15) == "UnivShaderObj__" then
                item:Destroy()
            else
                table.insert(HiddenOriginalInstances, { Instance = item, Parent = Terrain })
                item.Parent = nil
            end
        end
    end
end

-- Прибираємо старий екранний UI, якщо залишився
local function RemoveOldGuiFrom(parentObj)
    if not parentObj then return end
    for _, child in ipairs(parentObj:GetChildren()) do
        if child.Name == "UnivShaderGui__ControlPanel" then
            child:Destroy()
        end
    end
end

RemoveOldGuiFrom(CoreGui)
if LocalPlayer then
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    RemoveOldGuiFrom(playerGui)
end

-- ============================================================================
-- 3. КОНФІГУРАЦІЯ ТА РЕАЛІСТИЧНІ РЕЖИМИ (ЯК НА ПК)
-- ============================================================================
local Config = {
    SwitchKey = Enum.KeyCode.V,
    RemoveKey = Enum.KeyCode.C,
    TransitionSpeed = 4.0,
    ShadowContrast = 0.28,
    ColorSaturation = 0.26,
    BloomIntensity = 0.42,
    BloomThreshold = 0.92,
    BloomSize = 28,
    SunRaysIntensity = 0.14,
    SunRaysSpread = 0.78,
    CloudCover = 0.48,
    CloudDensity = 0.62
}

local Modes = {
    {
        Name = "День",
        ClockTime = 14.2,
        Brightness = 3.0,
        Exposure = 0.12,
        ShadowSoftness = 0.28,
        Ambient = Color3.fromRGB(78, 86, 102),
        OutdoorAmbient = Color3.fromRGB(122, 134, 155),
        ColorShift_Top = Color3.fromRGB(255, 248, 236),
        ColorShift_Bottom = Color3.fromRGB(115, 130, 155),
        AtmoDensity = 0.16,
        AtmoOffset = 0.42,
        AtmoHaze = 0.45,
        AtmoGlare = 0.35,
        AtmoColor = Color3.fromRGB(198, 220, 248),
        AtmoDecay = Color3.fromRGB(105, 125, 155),
        Tint = Color3.fromRGB(255, 252, 248),
        CloudColor = Color3.fromRGB(255, 255, 255),
        SunRays = 0.14
    },
    {
        Name = "Світлий Вечір",
        ClockTime = 17.3,
        Brightness = 2.85,
        Exposure = 0.24,
        ShadowSoftness = 0.32,
        Ambient = Color3.fromRGB(98, 84, 78),
        OutdoorAmbient = Color3.fromRGB(156, 126, 104),
        ColorShift_Top = Color3.fromRGB(255, 214, 168),
        ColorShift_Bottom = Color3.fromRGB(130, 112, 125),
        AtmoDensity = 0.18,
        AtmoOffset = 0.38,
        AtmoHaze = 0.55,
        AtmoGlare = 0.5,
        AtmoColor = Color3.fromRGB(248, 198, 152),
        AtmoDecay = Color3.fromRGB(145, 102, 88),
        Tint = Color3.fromRGB(255, 226, 192),
        CloudColor = Color3.fromRGB(255, 224, 195),
        SunRays = 0.18
    },
    {
        Name = "Світла Місячна Ніч",
        ClockTime = 1.6,
        Brightness = 1.85,
        Exposure = 0.28,
        ShadowSoftness = 0.3,
        Ambient = Color3.fromRGB(72, 86, 118),
        OutdoorAmbient = Color3.fromRGB(108, 128, 175),
        ColorShift_Top = Color3.fromRGB(185, 210, 255),
        ColorShift_Bottom = Color3.fromRGB(68, 82, 115),
        AtmoDensity = 0.15,
        AtmoOffset = 0.45,
        AtmoHaze = 0.4,
        AtmoGlare = 0.3,
        AtmoColor = Color3.fromRGB(95, 125, 185),
        AtmoDecay = Color3.fromRGB(55, 72, 112),
        Tint = Color3.fromRGB(210, 228, 255),
        CloudColor = Color3.fromRGB(150, 175, 225),
        SunRays = 0.08
    }
}

-- ============================================================================
-- 4. СТВОРЕННЯ ШЕЙДЕРІВ, ТІНЕЙ, АТМОСФЕРИ ТА ВОДИ
-- ============================================================================
if sethiddenproperty then
    pcall(function()
        sethiddenproperty(Lighting, "Technology", Enum.Technology.Future)
    end)
end

Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 1.0
Lighting.EnvironmentSpecularScale = 1.0
Lighting.GeographicLatitude = 44.0
Lighting.FogStart = 10000
Lighting.FogEnd = 100000

local CreatedInstances = {}
local function TrackInstance(inst)
    inst.Name = "UnivShaderObj__" .. inst.Name
    table.insert(CreatedInstances, inst)
    return inst
end

local Sky = TrackInstance(Instance.new("Sky"))
Sky.SunAngularSize = 14
Sky.MoonAngularSize = 13
Sky.StarCount = 4500
Sky.Parent = Lighting

local Clouds = nil
if Terrain then
    Clouds = TrackInstance(Instance.new("Clouds"))
    Clouds.Cover = Config.CloudCover
    Clouds.Density = Config.CloudDensity
    Clouds.Parent = Terrain

    Terrain.WaterColor = Color3.fromRGB(34, 82, 104)
    Terrain.WaterReflectance = 0.9
    Terrain.WaterTransparency = 0.32
    Terrain.WaterWaveSize = 0.16
    Terrain.WaterWaveSpeed = 11
end

local Atmosphere = TrackInstance(Instance.new("Atmosphere"))
Atmosphere.Parent = Lighting

local Bloom = TrackInstance(Instance.new("BloomEffect"))
Bloom.Intensity = Config.BloomIntensity
Bloom.Size = Config.BloomSize
Bloom.Threshold = Config.BloomThreshold
Bloom.Parent = Lighting

local SunRays = TrackInstance(Instance.new("SunRaysEffect"))
SunRays.Spread = Config.SunRaysSpread
SunRays.Parent = Lighting

local ColorCorrection = TrackInstance(Instance.new("ColorCorrectionEffect"))
ColorCorrection.Contrast = Config.ShadowContrast
ColorCorrection.Saturation = Config.ColorSaturation
ColorCorrection.Parent = Lighting

local currentModeIndex = 1
local isDestroyed = false

local function ApplyInstantMode(mode)
    Lighting.ClockTime = mode.ClockTime
    Lighting.Brightness = mode.Brightness
    Lighting.ExposureCompensation = mode.Exposure
    Lighting.ShadowSoftness = mode.ShadowSoftness
    Lighting.Ambient = mode.Ambient
    Lighting.OutdoorAmbient = mode.OutdoorAmbient
    Lighting.ColorShift_Top = mode.ColorShift_Top
    Lighting.ColorShift_Bottom = mode.ColorShift_Bottom

    Atmosphere.Density = mode.AtmoDensity
    Atmosphere.Offset = mode.AtmoOffset
    Atmosphere.Haze = mode.AtmoHaze
    Atmosphere.Glare = mode.AtmoGlare
    Atmosphere.Color = mode.AtmoColor
    Atmosphere.Decay = mode.AtmoDecay

    ColorCorrection.TintColor = mode.Tint
    SunRays.Intensity = mode.SunRays
    if Clouds then
        Clouds.Color = mode.CloudColor
    end
end

ApplyInstantMode(Modes[currentModeIndex])

-- ============================================================================
-- 5. ЕКРАННА ПАНЕЛЬ КЕРУВАННЯ (ТЕЛЕФОН + ПК: РЕЖИМ, ВИДАЛИТИ, ЗГОРНУТИ/ВІДКРИТИ)
-- ============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UnivShaderGui__ControlPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiAttached = pcall(function()
    screenGui.Parent = CoreGui
end)
if not guiAttached and LocalPlayer then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Основна панель керування
local mainPanel = Instance.new("Frame")
mainPanel.Name = "MainPanel"
mainPanel.Size = UDim2.new(0, 236, 0, 88)
mainPanel.Position = UDim2.new(0, 14, 0.5, -44)
mainPanel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
mainPanel.BackgroundTransparency = 0.12
mainPanel.BorderSizePixel = 0
mainPanel.Active = true
mainPanel.Draggable = true
mainPanel.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainPanel

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Transparency = 0.85
mainStroke.Thickness = 1
mainStroke.Parent = mainPanel

-- Верхня панель із назвою та кнопкою згортання
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -68, 0, 26)
titleLabel.Position = UDim2.new(0, 10, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✨ Шейдер • " .. Modes[currentModeIndex].Name
titleLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainPanel

local hideBtn = Instance.new("TextButton")
hideBtn.Name = "HideButton"
hideBtn.Size = UDim2.new(0, 26, 0, 24)
hideBtn.Position = UDim2.new(1, -58, 0, 5)
hideBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 58)
hideBtn.Text = "—"
hideBtn.TextColor3 = Color3.fromRGB(235, 240, 250)
hideBtn.TextSize = 14
hideBtn.Font = Enum.Font.GothamBold
hideBtn.Parent = mainPanel

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 7)
hideCorner.Parent = hideBtn

local closeGuiBtn = Instance.new("TextButton")
closeGuiBtn.Name = "RemoveShaderButton"
closeGuiBtn.Size = UDim2.new(0, 24, 0, 24)
closeGuiBtn.Position = UDim2.new(1, -29, 0, 5)
closeGuiBtn.BackgroundColor3 = Color3.fromRGB(165, 42, 48)
closeGuiBtn.Text = "✕"
closeGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeGuiBtn.TextSize = 13
closeGuiBtn.Font = Enum.Font.GothamBold
closeGuiBtn.Parent = mainPanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeGuiBtn

-- Кнопка перемикання режиму (День / Вечір / Ніч)
local modeBtn = Instance.new("TextButton")
modeBtn.Name = "ModeButton"
modeBtn.Size = UDim2.new(1, -20, 0, 40)
modeBtn.Position = UDim2.new(0, 10, 0, 36)
modeBtn.BackgroundColor3 = Color3.fromRGB(52, 98, 215)
modeBtn.Text = "Режим: " .. Modes[currentModeIndex].Name .. "  (V)"
modeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
modeBtn.TextSize = 13
modeBtn.Font = Enum.Font.GothamBold
modeBtn.Parent = mainPanel

local modeCorner = Instance.new("UICorner")
modeCorner.CornerRadius = UDim.new(0, 9)
modeCorner.Parent = modeBtn

-- Маленька кнопка для повторного відкриття згорнутої панелі
local reopenBtn = Instance.new("TextButton")
reopenBtn.Name = "ReopenButton"
reopenBtn.Size = UDim2.new(0, 118, 0, 36)
reopenBtn.Position = UDim2.new(0, 14, 0.5, -18)
reopenBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
reopenBtn.BackgroundTransparency = 0.12
reopenBtn.Text = "✨ Шейдер меню"
reopenBtn.TextColor3 = Color3.fromRGB(245, 248, 255)
reopenBtn.TextSize = 13
reopenBtn.Font = Enum.Font.GothamBold
reopenBtn.Visible = false
reopenBtn.Active = true
reopenBtn.Draggable = true
reopenBtn.Parent = screenGui

local reopenCorner = Instance.new("UICorner")
reopenCorner.CornerRadius = UDim.new(0, 10)
reopenCorner.Parent = reopenBtn

local reopenStroke = Instance.new("UIStroke")
reopenStroke.Color = Color3.fromRGB(255, 255, 255)
reopenStroke.Transparency = 0.85
reopenStroke.Thickness = 1
reopenStroke.Parent = reopenBtn

local function UpdatePanelLabels()
    local modeName = Modes[currentModeIndex].Name
    titleLabel.Text = "✨ Шейдер • " .. modeName
    modeBtn.Text = "Режим: " .. modeName .. "  (V)"
end

-- ============================================================================
-- 6. ПОВНЕ ВИДАЛЕННЯ ШЕЙДЕРІВ ТА ПАНЕЛІ
-- ============================================================================
local renderConnection
local inputConnection

local function DestroyShadersCompletely()
    if isDestroyed then return end
    isDestroyed = true

    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end

    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end

    for _, inst in ipairs(CreatedInstances) do
        if inst and inst.Parent then
            inst:Destroy()
        end
    end
    table.clear(CreatedInstances)

    for _, v in ipairs(Lighting:GetChildren()) do
        if v.Name:sub(1, 15) == "UnivShaderObj__" then
            v:Destroy()
        end
    end

    for _, data in ipairs(HiddenOriginalInstances) do
        if data.Instance then
            pcall(function()
                data.Instance.Parent = data.Parent
            end)
        end
    end
    table.clear(HiddenOriginalInstances)

    for prop, value in pairs(OriginalLightingState) do
        pcall(function()
            Lighting[prop] = value
        end)
    end

    if Terrain and OriginalWaterState then
        for prop, value in pairs(OriginalWaterState) do
            pcall(function()
                Terrain[prop] = value
            end)
        end
    end

    print("🧹 Шейдери та панель керування повністю видалено!")
end

if getgenv then
    getgenv()._UniversalShaderCleanup = DestroyShadersCompletely
else
    _G._UniversalShaderCleanup = DestroyShadersCompletely
end

-- ============================================================================
-- 7. ДІЇ КНОПОК ТА КЛАВІШ [V] / [C]
-- ============================================================================
local function SwitchMode()
    if isDestroyed then return end
    currentModeIndex = currentModeIndex + 1
    if currentModeIndex > #Modes then
        currentModeIndex = 1
    end
    UpdatePanelLabels()
    print("🎨 Режим: " .. Modes[currentModeIndex].Name)
end

modeBtn.MouseButton1Click:Connect(SwitchMode)

hideBtn.MouseButton1Click:Connect(function()
    reopenBtn.Position = mainPanel.Position
    mainPanel.Visible = false
    reopenBtn.Visible = true
end)

reopenBtn.MouseButton1Click:Connect(function()
    mainPanel.Position = reopenBtn.Position
    reopenBtn.Visible = false
    mainPanel.Visible = true
end)

closeGuiBtn.MouseButton1Click:Connect(DestroyShadersCompletely)

inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isDestroyed then return end

    if input.KeyCode == Config.SwitchKey then
        SwitchMode()
    elseif input.KeyCode == Config.RemoveKey then
        DestroyShadersCompletely()
    end
end)

-- ============================================================================
-- 8. ГОЛОВНИЙ ЦИКЛ ПЛАВНОГО ОСВІТЛЕННЯ ТА ТІНЕЙ
-- ============================================================================
local function lerp(a, b, t)
    return a + (b - a) * t
end

renderConnection = RunService.RenderStepped:Connect(function(dt)
    if isDestroyed then return end

    local target = Modes[currentModeIndex]
    local alpha = math.clamp(dt * Config.TransitionSpeed, 0, 1)

    Lighting.ClockTime = lerp(Lighting.ClockTime, target.ClockTime, alpha)
    Lighting.Brightness = lerp(Lighting.Brightness, target.Brightness, alpha)
    Lighting.ExposureCompensation = lerp(Lighting.ExposureCompensation, target.Exposure, alpha)
    Lighting.ShadowSoftness = lerp(Lighting.ShadowSoftness, target.ShadowSoftness, alpha)

    Lighting.Ambient = Lighting.Ambient:Lerp(target.Ambient, alpha)
    Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(target.OutdoorAmbient, alpha)
    Lighting.ColorShift_Top = Lighting.ColorShift_Top:Lerp(target.ColorShift_Top, alpha)
    Lighting.ColorShift_Bottom = Lighting.ColorShift_Bottom:Lerp(target.ColorShift_Bottom, alpha)

    Atmosphere.Density = lerp(Atmosphere.Density, target.AtmoDensity, alpha)
    Atmosphere.Offset = lerp(Atmosphere.Offset, target.AtmoOffset, alpha)
    Atmosphere.Haze = lerp(Atmosphere.Haze, target.AtmoHaze, alpha)
    Atmosphere.Glare = lerp(Atmosphere.Glare, target.AtmoGlare, alpha)
    Atmosphere.Color = Atmosphere.Color:Lerp(target.AtmoColor, alpha)
    Atmosphere.Decay = Atmosphere.Decay:Lerp(target.AtmoDecay, alpha)

    ColorCorrection.TintColor = ColorCorrection.TintColor:Lerp(target.Tint, alpha)
    SunRays.Intensity = lerp(SunRays.Intensity, target.SunRays, alpha)

    if Clouds then
        Clouds.Color = Clouds.Color:Lerp(target.CloudColor, alpha)
    end
end)

print("📱💻 Універсальний шейдер (ПК + Телефон) запущено! Панель з'явилась на екрані.")
