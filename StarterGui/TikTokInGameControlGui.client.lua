--[[
    ============================================================================
    TIKTOK LIVE IN-GAME ADMIN CONTROL GUI (CLIENT SCRIPT)
    File: TikTokInGameControlGui.client.lua
    Lokasi: StarterGui (atau StarterPlayerScripts)
    ============================================================================

    Deskripsi:
    Script GUI khusus yang berjalan langsung di dalam game (HUD / In-Game Panel).
    Pemain / Streamer / Host TIDAK PERLU lagi membuka Roblox Studio untuk mengatur
    integrasi TikTok Live:
    1. Custom Link: Bisa mengganti URL server backend (localhost, ngrok, VPS) & username TikTok.
    2. Start / Stop Polling: Mengontrol koneksi langsung dari dalam permainan.
    3. Custom Gift Mapper: Menghubungkan gift TikTok apa pun ke aksi game apa pun:
       - Rose -> Tambah Balok Lantai
       - Donut / Whale -> Tsunami Air Realistis 3D
       - Ice Cream -> Speed Boost 2x
       - Cap -> Super Jump 2x
       - Galaxy -> Gravitasi Bulan
       - Dragon -> Hujan Meteor Api
       - GG -> Bersihkan Arena
    4. Quick Tester & Live Event Feed: Menguji aksi game dan melihat live streaming chat/gift secara real-time.
    5. Tombol Shortcut: Tekan tombol 'M' atau 'F4' pada keyboard untuk Buka/Tutup GUI.
    ============================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- RemoteEvents dari Server
local adminEvent = ReplicatedStorage:WaitForChild("TikTokAdminEvent", 15)
local interactiveEvent = ReplicatedStorage:WaitForChild("TikTokInteractiveEvent", 15)

if not adminEvent or not interactiveEvent then
    warn("[TIKTOK IN-GAME GUI] RemoteEvent belum diinisialisasi oleh server!")
    return
end

-- ============================================================================
-- STATE LOKAL
-- ============================================================================
local currentBackendUrl = "http://localhost:3000"
local currentUsername = ""
local isListening = false
local currentGiftMap = {}
local activeTab = "Connection" -- "Connection", "GiftMapper", "Tester"

-- Daftar Aksi yang Tersedia
local AVAILABLE_ACTIONS = {
    { key = "spawn_floor", label = "🌹 Tambah Balok Lantai (+1)", color = Color3.fromRGB(255, 75, 120) },
    { key = "hazard_tsunami", label = "🌊 Tsunami Air Realistis 3D", color = Color3.fromRGB(0, 160, 240) },
    { key = "speed_boost", label = "⚡ Speed Boost 2x (8 Detik)", color = Color3.fromRGB(0, 230, 255) },
    { key = "super_jump", label = "🚀 Super Jump 2x (8 Detik)", color = Color3.fromRGB(255, 170, 0) },
    { key = "low_gravity", label = "🌙 Gravitasi Bulan (8 Detik)", color = Color3.fromRGB(180, 100, 255) },
    { key = "meteor_rain", label = "☄️ Hujan Meteor Api", color = Color3.fromRGB(255, 60, 40) },
    { key = "reset_floors", label = "🧹 Bersihkan Lantai Arena", color = Color3.fromRGB(255, 230, 100) },
    { key = "like_effect", label = "❤️ Efek Partikel Hati & Buff", color = Color3.fromRGB(255, 60, 110) }
}

local selectedActionKey = "spawn_floor"

-- ============================================================================
-- MEMBUAT SCREEN GUI
-- ============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TikTokInGameControlGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- 1. TOMBOL FLOATING TOGGLE DI POJOK KANAN ATAS
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "FloatingToggleBtn"
toggleBtn.Size = UDim2.new(0, 205, 0, 38)
toggleBtn.Position = UDim2.new(1, -220, 0, 18)
toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
toggleBtn.AutoButtonColor = true
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Text = "  🎮 TikTok Live Control"
toggleBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
toggleBtn.TextSize = 12
toggleBtn.TextXAlignment = Enum.TextXAlignment.Center
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(0, 200, 255)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = toggleBtn

local statusDot = Instance.new("Frame")
statusDot.Name = "StatusDot"
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.Position = UDim2.new(0, 12, 0.5, -5)
statusDot.BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Default: Offline (Merah)
statusDot.Parent = toggleBtn

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

-- 2. MODAL WINDOW UTAMA
local mainModal = Instance.new("Frame")
mainModal.Name = "MainModal"
mainModal.Size = UDim2.new(0, 540, 0, 430)
mainModal.Position = UDim2.new(0.5, -270, 0.5, -215)
mainModal.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
mainModal.Visible = false
mainModal.ClipsDescendants = true
mainModal.Parent = screenGui

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 14)
modalCorner.Parent = mainModal

local modalStroke = Instance.new("UIStroke")
modalStroke.Color = Color3.fromRGB(45, 50, 65)
modalStroke.Thickness = 1.5
modalStroke.Parent = mainModal

-- HEADER MODAL
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
header.BorderSizePixel = 0
header.Parent = mainModal

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header

-- Fix corner bleed at bottom of header
local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.6, 0, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "🎮 TikTok Live Controller (In-Game)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0.5, -16)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 58)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(200, 205, 220)
closeBtn.TextSize = 14
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

-- TAB NAVIGATION BAR
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -32, 0, 36)
tabBar.Position = UDim2.new(0, 16, 0, 54)
tabBar.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
tabBar.Parent = mainModal

local tabBarCorner = Instance.new("UICorner")
tabBarCorner.CornerRadius = UDim.new(0, 8)
tabBarCorner.Parent = tabBar

local function createTabButton(name, text, posScale)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.333, -4, 1, -4)
    btn.Position = UDim2.new(posScale, 2, 0, 2)
    btn.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(180, 185, 200)
    btn.TextSize = 11
    btn.Parent = tabBar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    return btn
end

local tabBtnConn = createTabButton("TabBtnConn", "🌐 Koneksi", 0)
local tabBtnMap = createTabButton("TabBtnMap", "🎁 Hadiah", 0.25)
local tabBtnTest = createTabButton("TabBtnTest", "⚡ Uji Coba", 0.50)
local tabBtnTheme = createTabButton("TabBtnTheme", "🗺️ Tema Map", 0.75)

-- WATERMARK RESMI NOXORA STUDIO DI HEADER
local watermarkBadge = Instance.new("TextLabel")
watermarkBadge.Name = "NoxoraWatermarkBadge"
watermarkBadge.Size = UDim2.new(0, 150, 0, 22)
watermarkBadge.Position = UDim2.new(1, -195, 0.5, -11)
watermarkBadge.BackgroundColor3 = Color3.fromRGB(0, 40, 60)
watermarkBadge.Font = Enum.Font.GothamBold
watermarkBadge.Text = "★ NOXORA STUDIO"
watermarkBadge.TextColor3 = Color3.fromRGB(0, 230, 255)
watermarkBadge.TextSize = 10
watermarkBadge.Parent = header

local wbCorner = Instance.new("UICorner")
wbCorner.CornerRadius = UDim.new(0, 6)
wbCorner.Parent = watermarkBadge

local wbStroke = Instance.new("UIStroke")
wbStroke.Color = Color3.fromRGB(0, 200, 255)
wbStroke.Thickness = 1
wbStroke.Parent = watermarkBadge

-- CONTAINER KONTEN TAB
local tabContainer = Instance.new("Frame")
tabContainer.Name = "TabContainer"
tabContainer.Size = UDim2.new(1, -32, 1, -135)
tabContainer.Position = UDim2.new(0, 16, 0, 96)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainModal

-- FOOTER RESMI DENGAN WATERMARK HAK CIPTA NOXORA STUDIO
local footerWatermark = Instance.new("Frame")
footerWatermark.Name = "FooterWatermark"
footerWatermark.Size = UDim2.new(1, 0, 0, 28)
footerWatermark.Position = UDim2.new(0, 0, 1, -28)
footerWatermark.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
footerWatermark.BorderSizePixel = 0
footerWatermark.Parent = mainModal

local fwLabel = Instance.new("TextLabel")
fwLabel.Size = UDim2.new(1, -20, 1, 0)
fwLabel.Position = UDim2.new(0, 10, 0, 0)
fwLabel.BackgroundTransparency = 1
fwLabel.Font = Enum.Font.GothamBold
fwLabel.Text = "🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI • TIKTOK LIVE ENGINE"
fwLabel.TextColor3 = Color3.fromRGB(110, 125, 155)
fwLabel.TextSize = 10
fwLabel.TextXAlignment = Enum.TextXAlignment.Center
fwLabel.Parent = footerWatermark

-- ============================================================================
-- ANTI-TAMPER SECURITY: WATERMARK NOXORA STUDIO TERLINDUNGI
-- ============================================================================
-- Memastikan watermark hak cipta NOXORA STUDIO tidak bisa diubah atau disembunyikan oleh pemain/script
watermarkBadge:GetPropertyChangedSignal("Text"):Connect(function()
    if watermarkBadge.Text ~= "★ NOXORA STUDIO" then
        watermarkBadge.Text = "★ NOXORA STUDIO"
    end
end)

watermarkBadge:GetPropertyChangedSignal("Visible"):Connect(function()
    if not watermarkBadge.Visible then
        watermarkBadge.Visible = true
    end
end)

footerWatermark:GetPropertyChangedSignal("Visible"):Connect(function()
    if not footerWatermark.Visible then
        footerWatermark.Visible = true
    end
end)

fwLabel:GetPropertyChangedSignal("Text"):Connect(function()
    if fwLabel.Text ~= "🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI • TIKTOK LIVE ENGINE" then
        fwLabel.Text = "🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI • TIKTOK LIVE ENGINE"
    end
end)

-- ============================================================================
-- 1. TAB KONEKSI & CUSTOM LINK
-- ============================================================================
local pageConn = Instance.new("ScrollingFrame")
pageConn.Name = "PageConnection"
pageConn.Size = UDim2.new(1, 0, 1, 0)
pageConn.BackgroundTransparency = 1
pageConn.ScrollBarThickness = 4
pageConn.Visible = true
pageConn.Parent = tabContainer

local connLayout = Instance.new("UIListLayout")
connLayout.Padding = UDim.new(0, 10)
connLayout.Parent = pageConn

local function createCard(name, height)
    local card = Instance.new("Frame")
    card.Name = name
    card.Size = UDim2.new(1, 0, 0, height)
    card.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
    card.Parent = pageConn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 44, 58)
    stroke.Thickness = 1
    stroke.Parent = card

    return card
end

-- Card Input URL
local cardUrl = createCard("CardUrl", 88)
local lblUrl = Instance.new("TextLabel")
lblUrl.Text = "URL Server Backend:"
lblUrl.Size = UDim2.new(0.5, 0, 0, 18)
lblUrl.Position = UDim2.new(0, 10, 0, 6)
lblUrl.BackgroundTransparency = 1
lblUrl.Font = Enum.Font.GothamMedium
lblUrl.TextColor3 = Color3.fromRGB(180, 190, 210)
lblUrl.TextSize = 11
lblUrl.TextXAlignment = Enum.TextXAlignment.Left
lblUrl.Parent = cardUrl

-- Tombol 1-klik Set Localhost
local btnQuickLocalhost = Instance.new("TextButton")
btnQuickLocalhost.Name = "BtnQuickLocalhost"
btnQuickLocalhost.Size = UDim2.new(0, 140, 0, 20)
btnQuickLocalhost.Position = UDim2.new(1, -150, 0, 5)
btnQuickLocalhost.BackgroundColor3 = Color3.fromRGB(35, 42, 60)
btnQuickLocalhost.Font = Enum.Font.GothamBold
btnQuickLocalhost.Text = "💻 Set Localhost:3000"
btnQuickLocalhost.TextColor3 = Color3.fromRGB(0, 220, 255)
btnQuickLocalhost.TextSize = 10
btnQuickLocalhost.Parent = cardUrl

local bqlCorner = Instance.new("UICorner")
bqlCorner.CornerRadius = UDim.new(0, 4)
bqlCorner.Parent = btnQuickLocalhost

local txtUrl = Instance.new("TextBox")
txtUrl.Name = "InputUrl"
txtUrl.Size = UDim2.new(1, -20, 0, 28)
txtUrl.Position = UDim2.new(0, 10, 0, 28)
txtUrl.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
txtUrl.TextColor3 = Color3.fromRGB(255, 255, 255)
txtUrl.PlaceholderText = "http://localhost:3000 atau link tunnel publik..."
txtUrl.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
txtUrl.Text = currentBackendUrl
txtUrl.Font = Enum.Font.Code
txtUrl.TextSize = 12
txtUrl.TextXAlignment = Enum.TextXAlignment.Left
txtUrl.ClearTextOnFocus = false
txtUrl.Parent = cardUrl

local txtUrlCorner = Instance.new("UICorner")
txtUrlCorner.CornerRadius = UDim.new(0, 6)
txtUrlCorner.Parent = txtUrl

local txtUrlPad = Instance.new("UIPadding")
txtUrlPad.PaddingLeft = UDim.new(0, 8)

local lblUrlHint = Instance.new("TextLabel")
lblUrlHint.Size = UDim2.new(1, -20, 0, 24)
lblUrlHint.Position = UDim2.new(0, 10, 0, 60)
lblUrlHint.BackgroundTransparency = 1
lblUrlHint.Font = Enum.Font.Gotham
lblUrlHint.TextColor3 = Color3.fromRGB(130, 140, 165)
lblUrlHint.TextSize = 10
lblUrlHint.TextXAlignment = Enum.TextXAlignment.Left
lblUrlHint.Text = "• Studio: http://localhost:3000 (Gratis, No Tunnel) | • Game Publik: npm run tunnel"
lblUrlHint.Parent = cardUrl

btnQuickLocalhost.MouseButton1Click:Connect(function()
    txtUrl.Text = "http://localhost:3000"
end)
txtUrlPad.Parent = txtUrl

-- Card Input Username
local cardUser = createCard("CardUser", 64)
local lblUser = Instance.new("TextLabel")
lblUser.Text = "Username Akun TikTok Live (Tanpa tanda @):"
lblUser.Size = UDim2.new(1, -16, 0, 18)
lblUser.Position = UDim2.new(0, 10, 0, 6)
lblUser.BackgroundTransparency = 1
lblUser.Font = Enum.Font.GothamMedium
lblUser.TextColor3 = Color3.fromRGB(180, 190, 210)
lblUser.TextSize = 11
lblUser.TextXAlignment = Enum.TextXAlignment.Left
lblUser.Parent = cardUser

local txtUser = Instance.new("TextBox")
txtUser.Name = "InputUser"
txtUser.Size = UDim2.new(1, -20, 0, 28)
txtUser.Position = UDim2.new(0, 10, 0, 28)
txtUser.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
txtUser.TextColor3 = Color3.fromRGB(255, 255, 255)
txtUser.PlaceholderText = "Contoh: khaby.lame"
txtUser.PlaceholderColor3 = Color3.fromRGB(90, 95, 110)
txtUser.Text = currentUsername
txtUser.Font = Enum.Font.Gotham
txtUser.TextSize = 12
txtUser.TextXAlignment = Enum.TextXAlignment.Left
txtUser.ClearTextOnFocus = false
txtUser.Parent = cardUser

local txtUserCorner = Instance.new("UICorner")
txtUserCorner.CornerRadius = UDim.new(0, 6)
txtUserCorner.Parent = txtUser

local txtUserPad = Instance.new("UIPadding")
txtUserPad.PaddingLeft = UDim.new(0, 8)
txtUserPad.Parent = txtUser

-- Tombol Start & Stop
local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1, 0, 0, 40)
btnRow.BackgroundTransparency = 1
btnRow.Parent = pageConn

local btnStart = Instance.new("TextButton")
btnStart.Name = "BtnStart"
btnStart.Size = UDim2.new(0.485, 0, 1, 0)
btnStart.BackgroundColor3 = Color3.fromRGB(0, 175, 116)
btnStart.Font = Enum.Font.GothamBold
btnStart.Text = "▶ Start Listening"
btnStart.TextColor3 = Color3.fromRGB(255, 255, 255)
btnStart.TextSize = 12
btnStart.Parent = btnRow

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 8)
startCorner.Parent = btnStart

local btnStop = Instance.new("TextButton")
btnStop.Name = "BtnStop"
btnStop.Size = UDim2.new(0.485, 0, 1, 0)
btnStop.Position = UDim2.new(0.515, 0, 0, 0)
btnStop.BackgroundColor3 = Color3.fromRGB(220, 50, 65)
btnStop.Font = Enum.Font.GothamBold
btnStop.Text = "⏹ Stop Listening"
btnStop.TextColor3 = Color3.fromRGB(255, 255, 255)
btnStop.TextSize = 12
btnStop.Parent = btnRow

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 8)
stopCorner.Parent = btnStop

-- Status Card
local cardStatus = createCard("CardStatus", 75)
local lblStatusText = Instance.new("TextLabel")
lblStatusText.Name = "StatusLog"
lblStatusText.Size = UDim2.new(1, -20, 1, -12)
lblStatusText.Position = UDim2.new(0, 10, 0, 6)
lblStatusText.BackgroundTransparency = 1
lblStatusText.Font = Enum.Font.Code
lblStatusText.TextColor3 = Color3.fromRGB(0, 230, 180)
lblStatusText.TextSize = 11
lblStatusText.TextXAlignment = Enum.TextXAlignment.Left
lblStatusText.TextYAlignment = Enum.TextYAlignment.Top
lblStatusText.TextWrapped = true
lblStatusText.Text = "Status: Siap.\nMasukkan URL & Username, lalu klik 'Start Listening'."
lblStatusText.Parent = cardStatus

-- ============================================================================
-- 2. TAB CUSTOM GIFT MAPPER
-- ============================================================================
local pageMap = Instance.new("Frame")
pageMap.Name = "PageGiftMapper"
pageMap.Size = UDim2.new(1, 0, 1, 0)
pageMap.BackgroundTransparency = 1
pageMap.Visible = false
pageMap.Parent = tabContainer

-- Area Input Mapping Baru (Top)
local mapInputCard = Instance.new("Frame")
mapInputCard.Size = UDim2.new(1, 0, 0, 105)
mapInputCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
mapInputCard.Parent = pageMap

local micCorner = Instance.new("UICorner")
micCorner.CornerRadius = UDim.new(0, 8)
micCorner.Parent = mapInputCard

local micStroke = Instance.new("UIStroke")
micStroke.Color = Color3.fromRGB(40, 44, 58)
micStroke.Parent = mapInputCard

local lblGiftName = Instance.new("TextLabel")
lblGiftName.Text = "Nama Gift TikTok (misal: Ice Cream, Rose, Cap, Donut):"
lblGiftName.Size = UDim2.new(1, -16, 0, 16)
lblGiftName.Position = UDim2.new(0, 10, 0, 6)
lblGiftName.BackgroundTransparency = 1
lblGiftName.Font = Enum.Font.GothamMedium
lblGiftName.TextColor3 = Color3.fromRGB(180, 190, 210)
lblGiftName.TextSize = 11
lblGiftName.TextXAlignment = Enum.TextXAlignment.Left
lblGiftName.Parent = mapInputCard

local txtGiftName = Instance.new("TextBox")
txtGiftName.Name = "InputGiftName"
txtGiftName.Size = UDim2.new(0.48, 0, 0, 28)
txtGiftName.Position = UDim2.new(0, 10, 0, 24)
txtGiftName.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
txtGiftName.TextColor3 = Color3.fromRGB(255, 255, 255)
txtGiftName.PlaceholderText = "Ketik nama gift..."
txtGiftName.Font = Enum.Font.Gotham
txtGiftName.TextSize = 12
txtGiftName.TextXAlignment = Enum.TextXAlignment.Left
txtGiftName.ClearTextOnFocus = false
txtGiftName.Parent = mapInputCard

local tgnCorner = Instance.new("UICorner")
tgnCorner.CornerRadius = UDim.new(0, 6)
tgnCorner.Parent = txtGiftName

local tgnPad = Instance.new("UIPadding")
tgnPad.PaddingLeft = UDim.new(0, 8)
tgnPad.Parent = txtGiftName

-- Tombol Selector Aksi
local btnActionSelect = Instance.new("TextButton")
btnActionSelect.Name = "BtnActionSelect"
btnActionSelect.Size = UDim2.new(0.48, 0, 0, 28)
btnActionSelect.Position = UDim2.new(0.51, 0, 0, 24)
btnActionSelect.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
btnActionSelect.Font = Enum.Font.GothamMedium
btnActionSelect.Text = "Pilih Aksi ▼"
btnActionSelect.TextColor3 = Color3.fromRGB(0, 220, 255)
btnActionSelect.TextSize = 11
btnActionSelect.Parent = mapInputCard

local basCorner = Instance.new("UICorner")
basCorner.CornerRadius = UDim.new(0, 6)
basCorner.Parent = btnActionSelect

-- Tombol Simpan Mapping
local btnSaveMapping = Instance.new("TextButton")
btnSaveMapping.Name = "BtnSaveMapping"
btnSaveMapping.Size = UDim2.new(1, -20, 0, 32)
btnSaveMapping.Position = UDim2.new(0, 10, 0, 62)
btnSaveMapping.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
btnSaveMapping.Font = Enum.Font.GothamBold
btnSaveMapping.Text = "➕ Simpan Mapping Gift"
btnSaveMapping.TextColor3 = Color3.fromRGB(255, 255, 255)
btnSaveMapping.TextSize = 12
btnSaveMapping.Parent = mapInputCard

local bsmCorner = Instance.new("UICorner")
bsmCorner.CornerRadius = UDim.new(0, 6)
bsmCorner.Parent = btnSaveMapping

-- Scrolling List Mapping Aktif (Bottom)
local mapListScroll = Instance.new("ScrollingFrame")
mapListScroll.Name = "MapListScroll"
mapListScroll.Size = UDim2.new(1, 0, 1, -115)
mapListScroll.Position = UDim2.new(0, 0, 0, 115)
mapListScroll.BackgroundTransparency = 1
mapListScroll.ScrollBarThickness = 4
mapListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mapListScroll.Parent = pageMap

local mapListLayout = Instance.new("UIListLayout")
mapListLayout.Padding = UDim.new(0, 6)
mapListLayout.Parent = mapListScroll

-- Dropdown Popup untuk Memilih Aksi
local actionDropdownFrame = Instance.new("ScrollingFrame")
actionDropdownFrame.Name = "ActionDropdownFrame"
actionDropdownFrame.Size = UDim2.new(0.9, 0, 0, 180)
actionDropdownFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
actionDropdownFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
actionDropdownFrame.Visible = false
actionDropdownFrame.ZIndex = 10
actionDropdownFrame.ScrollBarThickness = 4
actionDropdownFrame.Parent = pageMap

local adfCorner = Instance.new("UICorner")
adfCorner.CornerRadius = UDim.new(0, 8)
adfCorner.Parent = actionDropdownFrame

local adfStroke = Instance.new("UIStroke")
adfStroke.Color = Color3.fromRGB(0, 200, 255)
adfStroke.Thickness = 1.5
adfStroke.Parent = actionDropdownFrame

local adfLayout = Instance.new("UIListLayout")
adfLayout.Padding = UDim.new(0, 4)
adfLayout.Parent = actionDropdownFrame

for _, act in ipairs(AVAILABLE_ACTIONS) do
    local itemBtn = Instance.new("TextButton")
    itemBtn.Size = UDim2.new(1, -8, 0, 30)
    itemBtn.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
    itemBtn.Font = Enum.Font.GothamMedium
    itemBtn.Text = "  " .. act.label
    itemBtn.TextColor3 = act.color
    itemBtn.TextSize = 11
    itemBtn.TextXAlignment = Enum.TextXAlignment.Left
    itemBtn.ZIndex = 11
    itemBtn.Parent = actionDropdownFrame

    local ibCorner = Instance.new("UICorner")
    ibCorner.CornerRadius = UDim.new(0, 6)
    ibCorner.Parent = itemBtn

    itemBtn.MouseButton1Click:Connect(function()
        selectedActionKey = act.key
        btnActionSelect.Text = act.label
        btnActionSelect.TextColor3 = act.color
        actionDropdownFrame.Visible = false
    end)
end

btnActionSelect.MouseButton1Click:Connect(function()
    actionDropdownFrame.Visible = not actionDropdownFrame.Visible
end)

-- ============================================================================
-- 3. TAB UJI COBA & LIVE EVENT FEED
-- ============================================================================
local pageTest = Instance.new("Frame")
pageTest.Name = "PageTester"
pageTest.Size = UDim2.new(1, 0, 1, 0)
pageTest.BackgroundTransparency = 1
pageTest.Visible = false
pageTest.Parent = tabContainer

-- Area Tombol Uji Aksi (Grid)
local testGrid = Instance.new("Frame")
testGrid.Size = UDim2.new(1, 0, 0, 80)
testGrid.BackgroundTransparency = 1
testGrid.Parent = pageTest

local tgLayout = Instance.new("UIGridLayout")
tgLayout.CellSize = UDim2.new(0.315, 0, 0, 34)
tgLayout.CellPadding = UDim2.new(0.027, 0, 0, 8)
tgLayout.Parent = testGrid

local function createTestButton(label, actionKey, color)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamMedium
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Parent = testGrid

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        adminEvent:FireServer("TriggerAction", { actionKey = actionKey })
    end)
end

createTestButton("🌹 Test Rose", "spawn_floor", Color3.fromRGB(230, 50, 100))
createTestButton("🌊 Test Tsunami", "hazard_tsunami", Color3.fromRGB(0, 140, 230))
createTestButton("⚡ Test Speed", "speed_boost", Color3.fromRGB(0, 180, 220))
createTestButton("🚀 Super Jump", "super_jump", Color3.fromRGB(220, 140, 20))
createTestButton("☄️ Hujan Meteor", "meteor_rain", Color3.fromRGB(220, 50, 40))
createTestButton("🧹 Reset Lantai", "reset_floors", Color3.fromRGB(150, 150, 60))

-- Live Event Feed Console (Bawah)
local feedCard = Instance.new("Frame")
feedCard.Size = UDim2.new(1, 0, 1, -90)
feedCard.Position = UDim2.new(0, 0, 0, 90)
feedCard.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
feedCard.Parent = pageTest

local fcCorner = Instance.new("UICorner")
fcCorner.CornerRadius = UDim.new(0, 8)
fcCorner.Parent = feedCard

local fcStroke = Instance.new("UIStroke")
fcStroke.Color = Color3.fromRGB(35, 40, 52)
fcStroke.Parent = feedCard

local feedScroll = Instance.new("ScrollingFrame")
feedScroll.Size = UDim2.new(1, -16, 1, -12)
feedScroll.Position = UDim2.new(0, 8, 0, 6)
feedScroll.BackgroundTransparency = 1
feedScroll.ScrollBarThickness = 4
feedScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
feedScroll.Parent = feedCard

local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding = UDim.new(0, 4)
feedLayout.Parent = feedScroll

local function appendEventLog(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextColor3 = color or Color3.fromRGB(200, 235, 255)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = string.format("[%s] %s", os.date("%H:%M:%S"), text)
    lbl.Parent = feedScroll

    feedScroll.CanvasSize = UDim2.new(0, 0, 0, feedLayout.AbsoluteContentSize.Y + 20)
    feedScroll.CanvasPosition = Vector2.new(0, feedScroll.CanvasSize.Y.Offset)
end

appendEventLog("Live Feed siap. Menunggu event penonton...", Color3.fromRGB(120, 150, 180))

-- ============================================================================
-- 4. TAB TEMA MAP (AUTO GENERATOR & RESET MAP) - NOXORA STUDIO
-- ============================================================================
local pageTheme = Instance.new("ScrollingFrame")
pageTheme.Name = "PageMapTheme"
pageTheme.Size = UDim2.new(1, 0, 1, 0)
pageTheme.BackgroundTransparency = 1
pageTheme.ScrollBarThickness = 4
pageTheme.Visible = false
pageTheme.Parent = tabContainer

local themeLayout = Instance.new("UIListLayout")
themeLayout.Padding = UDim.new(0, 10)
themeLayout.Parent = pageTheme

-- Card Deskripsi Paket Lengkap
local cardThemeInfo = Instance.new("Frame")
cardThemeInfo.Size = UDim2.new(1, 0, 0, 68)
cardThemeInfo.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
cardThemeInfo.Parent = pageTheme

local ctiCorner = Instance.new("UICorner")
ctiCorner.CornerRadius = UDim.new(0, 8)
ctiCorner.Parent = cardThemeInfo

local ctiStroke = Instance.new("UIStroke")
ctiStroke.Color = Color3.fromRGB(0, 200, 255)
ctiStroke.Thickness = 1
ctiStroke.Parent = cardThemeInfo

local ctiTitle = Instance.new("TextLabel")
ctiTitle.Size = UDim2.new(1, -16, 0, 20)
ctiTitle.Position = UDim2.new(0, 10, 0, 6)
ctiTitle.BackgroundTransparency = 1
ctiTitle.Font = Enum.Font.GothamBold
ctiTitle.Text = "🏰 Paket Lengkap Auto Map Generator"
ctiTitle.TextColor3 = Color3.fromRGB(0, 230, 255)
ctiTitle.TextSize = 12
ctiTitle.TextXAlignment = Enum.TextXAlignment.Left
ctiTitle.Parent = cardThemeInfo

local ctiDesc = Instance.new("TextLabel")
ctiDesc.Size = UDim2.new(1, -20, 0, 36)
ctiDesc.Position = UDim2.new(0, 10, 0, 26)
ctiDesc.BackgroundTransparency = 1
ctiDesc.Font = Enum.Font.Gotham
ctiDesc.Text = "Otomatis membangun pulau arena, spawn point, billboard info gift, dan proteksi void. Jika Anda sudah punya map sendiri, fitur ini opsional."
ctiDesc.TextColor3 = Color3.fromRGB(180, 190, 210)
ctiDesc.TextSize = 11
ctiDesc.TextWrapped = true
ctiDesc.TextXAlignment = Enum.TextXAlignment.Left
ctiDesc.Parent = cardThemeInfo

-- Pilihan 3 Tema Map
local selectedThemeKey = "tropical"
local themeBtns = {}

local themeGrid = Instance.new("Frame")
themeGrid.Size = UDim2.new(1, 0, 0, 75)
themeGrid.BackgroundTransparency = 1
themeGrid.Parent = pageTheme

local tgLayout2 = Instance.new("UIGridLayout")
tgLayout2.CellSize = UDim2.new(0.315, 0, 1, 0)
tgLayout2.CellPadding = UDim2.new(0.027, 0, 0, 0)
tgLayout2.Parent = themeGrid

local THEMES_DATA = {
    { key = "tropical", name = "🏝️ Tropis", desc = "Pantai, Pasir, Sunset", color = Color3.fromRGB(230, 160, 40) },
    { key = "cyberpunk", name = "⚡ Cyberpunk", desc = "Obsidian, Neon, Malam", color = Color3.fromRGB(0, 220, 255) },
    { key = "skyblock", name = "☁️ Skyblock", desc = "Kastil Langit, Siang", color = Color3.fromRGB(180, 120, 255) }
}

for _, t in ipairs(THEMES_DATA) do
    local cardBtn = Instance.new("TextButton")
    cardBtn.Name = "Theme_" .. t.key
    cardBtn.BackgroundColor3 = (selectedThemeKey == t.key) and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(20, 23, 30)
    cardBtn.AutoButtonColor = true
    cardBtn.Text = ""
    cardBtn.Parent = themeGrid

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 8)
    cbCorner.Parent = cardBtn

    local cbStroke = Instance.new("UIStroke")
    cbStroke.Color = (selectedThemeKey == t.key) and t.color or Color3.fromRGB(40, 44, 55)
    cbStroke.Thickness = (selectedThemeKey == t.key) and 2 or 1
    cbStroke.Parent = cardBtn

    local lblName = Instance.new("TextLabel")
    lblName.Size = UDim2.new(1, 0, 0, 28)
    lblName.Position = UDim2.new(0, 0, 0, 10)
    lblName.BackgroundTransparency = 1
    lblName.Font = Enum.Font.GothamBold
    lblName.Text = t.name
    lblName.TextColor3 = t.color
    lblName.TextSize = 13
    lblName.Parent = cardBtn

    local lblSub = Instance.new("TextLabel")
    lblSub.Size = UDim2.new(1, -10, 0, 24)
    lblSub.Position = UDim2.new(0, 5, 0, 38)
    lblSub.BackgroundTransparency = 1
    lblSub.Font = Enum.Font.Gotham
    lblSub.Text = t.desc
    lblSub.TextColor3 = Color3.fromRGB(160, 170, 190)
    lblSub.TextSize = 10
    lblSub.TextWrapped = true
    lblSub.Parent = cardBtn

    themeBtns[t.key] = { btn = cardBtn, stroke = cbStroke, data = t }

    cardBtn.MouseButton1Click:Connect(function()
        selectedThemeKey = t.key
        for k, v in pairs(themeBtns) do
            local isSel = (k == selectedThemeKey)
            v.btn.BackgroundColor3 = isSel and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(20, 23, 30)
            v.stroke.Color = isSel and v.data.color or Color3.fromRGB(40, 44, 55)
            v.stroke.Thickness = isSel and 2 or 1
        end
    end)
end

-- Tombol Eksekusi Map (SELECT GENERATE & RESET)
local mapBtnRow = Instance.new("Frame")
mapBtnRow.Size = UDim2.new(1, 0, 0, 42)
mapBtnRow.BackgroundTransparency = 1
mapBtnRow.Parent = pageTheme

local btnGenerateMap = Instance.new("TextButton")
btnGenerateMap.Name = "BtnGenerateMap"
btnGenerateMap.Size = UDim2.new(0.62, 0, 1, 0)
btnGenerateMap.BackgroundColor3 = Color3.fromRGB(0, 175, 116)
btnGenerateMap.Font = Enum.Font.GothamBold
btnGenerateMap.Text = "🏗️ Generate Map Tema Terpilih"
btnGenerateMap.TextColor3 = Color3.fromRGB(255, 255, 255)
btnGenerateMap.TextSize = 12
btnGenerateMap.Parent = mapBtnRow

local bgmCorner = Instance.new("UICorner")
bgmCorner.CornerRadius = UDim.new(0, 8)
bgmCorner.Parent = btnGenerateMap

local btnClearMap = Instance.new("TextButton")
btnClearMap.Name = "BtnClearMap"
btnClearMap.Size = UDim2.new(0.35, 0, 1, 0)
btnClearMap.Position = UDim2.new(0.65, 0, 0, 0)
btnClearMap.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
btnClearMap.Font = Enum.Font.GothamBold
btnClearMap.Text = "🧹 Reset Map"
btnClearMap.TextColor3 = Color3.fromRGB(255, 255, 255)
btnClearMap.TextSize = 12
btnClearMap.Parent = mapBtnRow

local bcmCorner = Instance.new("UICorner")
bcmCorner.CornerRadius = UDim.new(0, 8)
bcmCorner.Parent = btnClearMap

btnGenerateMap.MouseButton1Click:Connect(function()
    adminEvent:FireServer("GenerateMap", { theme = selectedThemeKey })
end)

btnClearMap.MouseButton1Click:Connect(function()
    adminEvent:FireServer("ClearMap")
end)

-- ============================================================================
-- LOGIKA TAB NAVIGATION (4 TABS)
-- ============================================================================
local function switchTab(tabName)
    activeTab = tabName
    pageConn.Visible = (tabName == "Connection")
    pageMap.Visible = (tabName == "GiftMapper")
    pageTest.Visible = (tabName == "Tester")
    pageTheme.Visible = (tabName == "ThemeMap")

    tabBtnConn.BackgroundColor3 = (tabName == "Connection") and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(22, 25, 34)
    tabBtnConn.TextColor3 = (tabName == "Connection") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)

    tabBtnMap.BackgroundColor3 = (tabName == "GiftMapper") and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(22, 25, 34)
    tabBtnMap.TextColor3 = (tabName == "GiftMapper") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)

    tabBtnTest.BackgroundColor3 = (tabName == "Tester") and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(22, 25, 34)
    tabBtnTest.TextColor3 = (tabName == "Tester") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)

    tabBtnTheme.BackgroundColor3 = (tabName == "ThemeMap") and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(22, 25, 34)
    tabBtnTheme.TextColor3 = (tabName == "ThemeMap") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)
end

tabBtnConn.MouseButton1Click:Connect(function() switchTab("Connection") end)
tabBtnMap.MouseButton1Click:Connect(function() switchTab("GiftMapper") end)
tabBtnTest.MouseButton1Click:Connect(function() switchTab("Tester") end)
tabBtnTheme.MouseButton1Click:Connect(function() switchTab("ThemeMap") end)
switchTab("Connection")

-- ============================================================================
-- UPDATE LIST MAPPING CUSTOM GIFT
-- ============================================================================
local function refreshGiftMapList()
    for _, child in ipairs(mapListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local count = 0
    for giftName, actionKey in pairs(currentGiftMap) do
        count = count + 1
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -6, 0, 32)
        itemFrame.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
        itemFrame.Parent = mapListScroll

        local ifCorner = Instance.new("UICorner")
        ifCorner.CornerRadius = UDim.new(0, 6)
        ifCorner.Parent = itemFrame

        -- Cari label aksi
        local actLabel = actionKey
        local actColor = Color3.fromRGB(200, 220, 255)
        for _, a in ipairs(AVAILABLE_ACTIONS) do
            if a.key == actionKey then
                actLabel = a.label
                actColor = a.color
                break
            end
        end

        local txtDesc = Instance.new("TextLabel")
        txtDesc.Size = UDim2.new(0.8, -10, 1, 0)
        txtDesc.Position = UDim2.new(0, 10, 0, 0)
        txtDesc.BackgroundTransparency = 1
        txtDesc.Font = Enum.Font.GothamMedium
        txtDesc.Text = string.format("🎁 %s  ➔  %s", giftName:upper(), actLabel)
        txtDesc.TextColor3 = actColor
        txtDesc.TextSize = 11
        txtDesc.TextXAlignment = Enum.TextXAlignment.Left
        txtDesc.Parent = itemFrame

        local btnDelete = Instance.new("TextButton")
        btnDelete.Size = UDim2.new(0, 26, 0, 22)
        btnDelete.Position = UDim2.new(1, -32, 0.5, -11)
        btnDelete.BackgroundColor3 = Color3.fromRGB(180, 40, 50)
        btnDelete.Font = Enum.Font.GothamBold
        btnDelete.Text = "✕"
        btnDelete.TextColor3 = Color3.fromRGB(255, 255, 255)
        btnDelete.TextSize = 11
        btnDelete.Parent = itemFrame

        local bdCorner = Instance.new("UICorner")
        bdCorner.CornerRadius = UDim.new(0, 4)
        bdCorner.Parent = btnDelete

        local capturedGift = giftName
        btnDelete.MouseButton1Click:Connect(function()
            adminEvent:FireServer("RemoveGiftMapping", { giftName = capturedGift })
        end)
    end

    mapListScroll.CanvasSize = UDim2.new(0, 0, 0, count * 38)
end

-- Simpan Mapping Baru
btnSaveMapping.MouseButton1Click:Connect(function()
    local giftName = txtGiftName.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if giftName == "" then
        lblStatusText.Text = "PERINGATAN: Masukkan nama gift terlebih dahulu!"
        lblStatusText.TextColor3 = Color3.fromRGB(255, 180, 50)
        return
    end

    adminEvent:FireServer("SetGiftMapping", {
        giftName = giftName,
        actionKey = selectedActionKey
    })

    txtGiftName.Text = ""
end)

-- ============================================================================
-- KONEKSI START & STOP LISTENING
-- ============================================================================
btnStart.MouseButton1Click:Connect(function()
    local url = txtUrl.Text:gsub("%s+", "")
    local username = txtUser.Text:gsub("%s+", ""):gsub("^@", "")

    if url == "" then url = "http://localhost:3000" end
    if username == "" then
        lblStatusText.Text = "PERINGATAN: Masukkan username TikTok terlebih dahulu!"
        lblStatusText.TextColor3 = Color3.fromRGB(255, 180, 50)
        return
    end

    lblStatusText.Text = "Menghubungkan ke " .. url .. " (@" .. username .. ")..."
    lblStatusText.TextColor3 = Color3.fromRGB(100, 200, 255)

    adminEvent:FireServer("UpdateConfig", {
        serverUrl = url,
        username = username,
        isListening = true
    })
end)

btnStop.MouseButton1Click:Connect(function()
    adminEvent:FireServer("UpdateConfig", {
        isListening = false
    })
end)

-- ============================================================================
-- MENDENGARKAN UPDATE DARI SERVER
-- ============================================================================
adminEvent.OnClientEvent:Connect(function(msgType, data)
    if msgType == "StateUpdate" and type(data) == "table" then
        if data.serverUrl then currentBackendUrl = data.serverUrl; txtUrl.Text = data.serverUrl end
        if data.username then currentUsername = data.username; txtUser.Text = data.username end
        if data.isListening ~= nil then isListening = data.isListening end
        if data.giftMap then currentGiftMap = data.giftMap end

        -- Update UI Indikator
        if isListening then
            statusDot.BackgroundColor3 = Color3.fromRGB(0, 230, 120) -- Hijau
            toggleBtn.Text = "  ● TikTok Live (ONLINE)"
            lblStatusText.Text = string.format("TERHUBUNG!\nBackend: %s\nTarget: @%s (Polling Aktif)", currentBackendUrl, currentUsername)
            lblStatusText.TextColor3 = Color3.fromRGB(0, 255, 150)
        else
            statusDot.BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Merah
            toggleBtn.Text = "  🎮 TikTok Live Control"
            lblStatusText.Text = "Status: Terhenti (Stopped).\nKlik 'Start Listening' untuk memulai integrasi."
            lblStatusText.TextColor3 = Color3.fromRGB(200, 205, 220)
        end

        refreshGiftMapList()
    end
end)

-- Live Feed Listener
interactiveEvent.OnClientEvent:Connect(function(actionType, data)
    if actionType == "EventFeed" and type(data) == "table" then
        local evType = tostring(data.type or ""):upper()
        local user = data.user or "Penonton"

        if evType == "GIFT" then
            local gName = data.giftName or "Gift"
            local count = data.repeatCount or 1
            appendEventLog(string.format("🎁 [GIFT] @%s mengirim %s (x%d)", user, gName, count), Color3.fromRGB(255, 120, 180))
        elseif evType == "LIKE" then
            appendEventLog(string.format("❤️ [LIKE] @%s memberi like (+%d)", user, data.likeCount or 1), Color3.fromRGB(255, 80, 130))
        elseif evType == "CHAT" then
            appendEventLog(string.format("💬 [CHAT] @%s: %s", user, data.comment or ""), Color3.fromRGB(150, 220, 255))
        elseif evType == "FOLLOW" then
            appendEventLog(string.format("⭐ [FOLLOW] @%s mulai mengikuti stream!", user), Color3.fromRGB(255, 215, 0))
        end
    end
end)

-- ============================================================================
-- TOGGLE MODAL OPEN / CLOSE (BUTTON & KEYBOARD M / F4)
-- ============================================================================
local function toggleModal()
    mainModal.Visible = not mainModal.Visible
end

toggleBtn.MouseButton1Click:Connect(toggleModal)
closeBtn.MouseButton1Click:Connect(function() mainModal.Visible = false end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.F4 then
        toggleModal()
    end
end)

-- Minta state awal ke server saat baru spawn
task.delay(0.5, function()
    adminEvent:FireServer("GetState")
end)

print("[TIKTOK IN-GAME GUI] GUI Kontrol siap! Tekan 'M' atau klik tombol di kanan atas untuk membuka.")
