--[[
    ============================================================================
    TIKTOK LIVE INTERACTIVE - CLIENT SCRIPT (LOCAL SCRIPT)
    Lokasi: StarterPlayer -> StarterPlayerScripts -> client.lua
    ============================================================================

    Deskripsi:
    Script di sisi Client (Pemain) yang bertugas untuk:
    1. Menangkap remote event dari Server ('TikTokInteractiveEvent') untuk menampilkan
       efek visual client-side (Popup notifikasi, efek getar kamera saat tsunami, audio).
    2. Menyediakan shortcut tombol keyboard (1, 2, 3) untuk mempermudah Developer
       melakukan testing interaksi secara instan tanpa perlu streaming sungguhan.
    ============================================================================
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- RemoteEvent dari Server
local interactiveEvent = ReplicatedStorage:WaitForChild("TikTokInteractiveEvent", 10)
local legacyEvent = ReplicatedStorage:WaitForChild("interactiveEvent", 10)

-- ============================================================================
-- PEMBUATAN SCREEN GUI NOTIFIKASI DI SISI CLIENT
-- ============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TikTokLiveNotificationGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local bannerFrame = Instance.new("Frame")
bannerFrame.Name = "BannerFrame"
bannerFrame.Size = UDim2.new(0, 320, 0, 70)
bannerFrame.Position = UDim2.new(0.5, -160, 0, -90) -- Mulai di luar layar atas
bannerFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
bannerFrame.BackgroundTransparency = 0.15
bannerFrame.Parent = screenGui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = bannerFrame

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(255, 75, 120)
bannerStroke.Thickness = 2
bannerStroke.Parent = bannerFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -20, 0, 24)
titleLabel.Position = UDim2.new(0, 10, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "TIKTOK EVENT"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = bannerFrame

local descLabel = Instance.new("TextLabel")
descLabel.Name = "DescLabel"
descLabel.Size = UDim2.new(1, -20, 0, 26)
descLabel.Position = UDim2.new(0, 10, 0, 34)
descLabel.BackgroundTransparency = 1
descLabel.Font = Enum.Font.GothamMedium
descLabel.Text = "Notifikasi dari penonton live"
descLabel.TextColor3 = Color3.fromRGB(210, 215, 230)
descLabel.TextSize = 12
descLabel.TextXAlignment = Enum.TextXAlignment.Left
descLabel.TextWrapped = true
descLabel.Parent = bannerFrame

-- Fungsi memunculkan banner notifikasi
local isBannerShowing = false
local function showBanner(title, message, strokeColor)
    titleLabel.Text = title or "TIKTOK EVENT"
    descLabel.Text = message or ""
    bannerStroke.Color = strokeColor or Color3.fromRGB(0, 200, 255)

    if isBannerShowing then return end
    isBannerShowing = true

    -- Animasi Slide Down (Muncul)
    local slideDown = TweenService:Create(bannerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 0, 25)
    })
    slideDown:Play()

    task.delay(3.5, function()
        -- Animasi Slide Up (Sembunyi)
        local slideUp = TweenService:Create(bannerFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -160, 0, -90)
        })
        slideUp:Play()
        slideUp.Completed:Connect(function()
            isBannerShowing = false
        end)
    end)
end

-- ============================================================================
-- EFEK CIPRATAN AIR DI LAYAR (SCREEN WATER SPLASH OVERLAY)
-- ============================================================================
local waterSplashOverlay = Instance.new("Frame")
waterSplashOverlay.Name = "WaterSplashOverlay"
waterSplashOverlay.Size = UDim2.new(1, 0, 1, 0)
waterSplashOverlay.BackgroundColor3 = Color3.fromRGB(10, 130, 220)
waterSplashOverlay.BackgroundTransparency = 1
waterSplashOverlay.BorderSizePixel = 0
waterSplashOverlay.ZIndex = 5
waterSplashOverlay.Parent = screenGui

local splashGradient = Instance.new("UIGradient")
splashGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.4),
    NumberSequenceKeypoint.new(0.5, 0.85),
    NumberSequenceKeypoint.new(1, 0.3)
})
splashGradient.Color = ColorSequence.new(Color3.fromRGB(120, 210, 255), Color3.fromRGB(0, 140, 230))
splashGradient.Rotation = 45
splashGradient.Parent = waterSplashOverlay

local function triggerScreenWaterSplash()
    -- Munculkan efek air membasahi layar
    local inTween = TweenService:Create(waterSplashOverlay, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.65
    })
    inTween:Play()
    inTween.Completed:Connect(function()
        task.delay(2.0, function()
            -- Air perlahan menetes dan memudar dari layar
            local outTween = TweenService:Create(waterSplashOverlay, TweenInfo.new(3.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1
            })
            outTween:Play()
        end)
    end)
end

-- ============================================================================
-- EFEK GETAR KAMERA (CAMERA SHAKE) SAAT TSUNAMI DATANG
-- ============================================================================
local function shakeCamera(intensity, duration)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local startTime = tick()
    local shakeConn
    shakeConn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed > duration then
            shakeConn:Disconnect()
            return
        end

        local decay = 1 - (elapsed / duration)
        local rotX = (math.random() - 0.5) * 2 * intensity * decay
        local rotY = (math.random() - 0.5) * 2 * intensity * decay
        local rotZ = (math.random() - 0.5) * 2 * intensity * decay

        camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(rotX), math.rad(rotY), math.rad(rotZ))
    end)
end

-- ============================================================================
-- MENDENGARKAN EVENT DARI SERVER
-- ============================================================================
if interactiveEvent then
    interactiveEvent.OnClientEvent:Connect(function(actionType, data)
        if actionType == "Notification" then
            showBanner(data.title, data.message, data.color)
        elseif actionType == "TsunamiAlert" then
            showBanner(data.title, data.message, Color3.fromRGB(0, 160, 255))
            shakeCamera(2.2, 6.5) -- Getar kamera gemuruh ombak selama 6.5 detik
            triggerScreenWaterSplash() -- Efek air laut membasahi layar pemain
        elseif actionType == "LikeEffect" then
            -- Optional efek client tambahan
        end
    end)
end

-- ============================================================================
-- TESTING KEYBOARD (SHORTCUT UNTUK DEVELOPER)
-- 1 = Tambah Lantai (Gift Rose)
-- 2 = Panggil Tsunami (Gift Donut)
-- 3 = Efek Like
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.One then
        -- Shortcut tombol 1: Simulasi Gift Rose / Tambah Lantai
        print("⌨️ [TEST KEY 1] Simulasi Tambah Lantai (Gift Rose)")
        if legacyEvent then
            legacyEvent:FireServer("TambahLantai", 1)
        end
    elseif input.KeyCode == Enum.KeyCode.Two then
        -- Shortcut tombol 2: Simulasi Hazard Tsunami (Gift Donut)
        print("⌨️ [TEST KEY 2] Simulasi Hazard Tsunami (Gift Donut)")
        if legacyEvent then
            legacyEvent:FireServer("Tsunami", 1)
        end
    elseif input.KeyCode == Enum.KeyCode.Three then
        -- Shortcut tombol 3: Simulasi Like
        print("⌨️ [TEST KEY 3] Simulasi Like")
        if legacyEvent then
            legacyEvent:FireServer("Like", 1)
        end
    end
end)

print("[TIKTOK CLIENT] Client script siap! Tekan 1 (Rose), 2 (Tsunami), 3 (Like) untuk testing manual.")