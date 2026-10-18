--[[
    ============================================================================
    TIKTOK LIVE TO ROBLOX STUDIO - PLUGIN UI SCRIPT
    File: TikTokLivePlugin.server.lua
    Lokasi: Folder Plugin / Local Plugins Roblox Studio
    ============================================================================

    Deskripsi:
    Plugin resmi untuk Roblox Studio yang menyediakan antarmuka (GUI) kontrol
    integrasi TikTok Live:
    1. UI DockWidgetPluginGui yang modern dan responsif.
    2. Input Text untuk: URL Server Backend (default: http://localhost:3000) dan Username TikTok.
    3. Tombol "Start Listening" dan "Stop Listening" untuk mengontrol polling HttpService
       secara real-time melalui ReplicatedStorage dan API Node.js backend.
    4. Penyimpanan persisten otomatis menggunakan plugin:SetSetting() dan plugin:GetSetting().
    5. Fitur Quick Simulator: Tombol simulasi Rose, Donut, dan Like langsung dari UI Plugin.
    ============================================================================
]]

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Pastikan script berjalan sebagai Plugin
if not plugin then
    return
end

-- ============================================================================
-- KONFIGURASI KEY SETTINGS (PERSISTENCE)
-- ============================================================================
local SETTING_URL_KEY = "TikTok_ServerUrl_V1"
local SETTING_USER_KEY = "TikTok_Username_V1"
local SETTING_AUTO_KEY = "TikTok_AutoConnect_V1"
local SETTING_THEME_KEY = "TikTok_SelectedTheme_V1"
local SETTING_AUTOMAP_KEY = "TikTok_AutoMapOnStart_V1"

local defaultUrl = plugin:GetSetting(SETTING_URL_KEY) or "http://localhost:3000"
local defaultUsername = plugin:GetSetting(SETTING_USER_KEY) or ""
local defaultTheme = plugin:GetSetting(SETTING_THEME_KEY) or "tropical"
local defaultAutoMap = plugin:GetSetting(SETTING_AUTOMAP_KEY)
if defaultAutoMap == nil then defaultAutoMap = true end
local isListening = false

-- ============================================================================
-- REPLICATED STORAGE CONFIG SYNC
-- ============================================================================
local function getOrCreateConfig()
    local folder = ReplicatedStorage:FindFirstChild("TikTokLiveConfig")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "TikTokLiveConfig"
        folder.Parent = ReplicatedStorage
    end

    local serverUrl = folder:FindFirstChild("ServerUrl")
    if not serverUrl then
        serverUrl = Instance.new("StringValue")
        serverUrl.Name = "ServerUrl"
        serverUrl.Value = defaultUrl
        serverUrl.Parent = folder
    end

    local usernameVal = folder:FindFirstChild("TikTokUsername")
    if not usernameVal then
        usernameVal = Instance.new("StringValue")
        usernameVal.Name = "TikTokUsername"
        usernameVal.Value = defaultUsername
        usernameVal.Parent = folder
    end

    local listeningVal = folder:FindFirstChild("IsListening")
    if not listeningVal then
        listeningVal = Instance.new("BoolValue")
        listeningVal.Name = "IsListening"
        listeningVal.Value = false
        listeningVal.Parent = folder
    end

    local autoMapVal = folder:FindFirstChild("AutoGenerateMap")
    if not autoMapVal then
        autoMapVal = Instance.new("BoolValue")
        autoMapVal.Name = "AutoGenerateMap"
        autoMapVal.Value = defaultAutoMap
        autoMapVal.Parent = folder
    end

    local defaultThemeVal = folder:FindFirstChild("DefaultMapTheme")
    if not defaultThemeVal then
        defaultThemeVal = Instance.new("StringValue")
        defaultThemeVal.Name = "DefaultMapTheme"
        defaultThemeVal.Value = defaultTheme
        defaultThemeVal.Parent = folder
    end

    return serverUrl, usernameVal, listeningVal, autoMapVal, defaultThemeVal
end

local configServerUrl, configUsername, configIsListening, configAutoMap, configDefaultTheme = getOrCreateConfig()

-- ============================================================================
-- MEMBUAT TOOLBAR & DOCKWIDGET
-- ============================================================================
local toolbar = plugin:CreateToolbar("TikTok Live")
local toggleButton = toolbar:CreateButton(
    "TikTokLiveManager",
    "Buka Panel Kontrol TikTok Live",
    "rbxassetid://6031075931" -- Network / Live icon
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right, -- Muncul di panel kanan Studio
    false,                       -- Awalnya tertutup (bisa dibuka via tombol toolbar)
    false,                       -- Tidak memaksa override ukuran sebelumnya
    330,                         -- Lebar default
    520,                         -- Tinggi default
    280,                         -- Lebar minimum
    400                          -- Tinggi minimum
)

local widget = plugin:CreateDockWidgetPluginGui("TikTokLiveConnectorWidget_v1", widgetInfo)
widget.Title = "TikTok Live - Roblox Connector"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Toggle widget visibility saat toolbar button ditekan
toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    toggleButton:SetActive(widget.Enabled)
end)

-- ============================================================================
-- PEMBUATAN UI KOMPONEN (MODERN DARK THEME)
-- ============================================================================
local mainContainer = Instance.new("ScrollingFrame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(1, 0, 1, 0)
mainContainer.BackgroundColor3 = Color3.fromRGB(25, 27, 33)
mainContainer.BorderSizePixel = 0
mainContainer.ScrollBarThickness = 6
mainContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 65, 80)
mainContainer.CanvasSize = UDim2.new(0, 0, 0, 960)
mainContainer.Parent = widget

local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 16)
uiPadding.PaddingBottom = UDim.new(0, 16)
uiPadding.PaddingLeft = UDim.new(0, 16)
uiPadding.PaddingRight = UDim.new(0, 16)
uiPadding.Parent = mainContainer

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 12)
uiListLayout.Parent = mainContainer

-- 0. WATERMARK BADGE RESMI NOXORA STUDIO
local watermarkBadge = Instance.new("Frame")
watermarkBadge.Name = "NoxoraWatermarkBadge"
watermarkBadge.Size = UDim2.new(1, 0, 0, 26)
watermarkBadge.BackgroundColor3 = Color3.fromRGB(15, 30, 45)
watermarkBadge.LayoutOrder = 0
watermarkBadge.Parent = mainContainer

local wbCorner = Instance.new("UICorner")
wbCorner.CornerRadius = UDim.new(0, 6)
wbCorner.Parent = watermarkBadge

local wbStroke = Instance.new("UIStroke")
wbStroke.Color = Color3.fromRGB(0, 220, 255)
wbStroke.Thickness = 1
wbStroke.Parent = watermarkBadge

local wbText = Instance.new("TextLabel")
wbText.Size = UDim2.new(1, 0, 1, 0)
wbText.BackgroundTransparency = 1
wbText.Font = Enum.Font.GothamBold
wbText.Text = "★ NOXORA STUDIO OFFICIAL ENGINE ★"
wbText.TextColor3 = Color3.fromRGB(0, 240, 255)
wbText.TextSize = 10
wbText.Parent = watermarkBadge

-- 1. HEADER (Title & Status Badge)
local headerFrame = Instance.new("Frame")
headerFrame.Name = "HeaderFrame"
headerFrame.Size = UDim2.new(1, 0, 0, 48)
headerFrame.BackgroundTransparency = 1
headerFrame.LayoutOrder = 1
headerFrame.Parent = mainContainer

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(0.65, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "TikTok Live Bridge\n<font size=\"10\" color=\"#00e6b4\">by NOXORA STUDIO</font>"
titleLabel.RichText = true
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 15
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local statusBadge = Instance.new("TextLabel")
statusBadge.Name = "StatusBadge"
statusBadge.Size = UDim2.new(0.35, 0, 0, 28)
statusBadge.Position = UDim2.new(0.65, 0, 0.5, -14)
statusBadge.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
statusBadge.Font = Enum.Font.GothamMedium
statusBadge.Text = "STOPPED"
statusBadge.TextColor3 = Color3.fromRGB(200, 205, 215)
statusBadge.TextSize = 11
statusBadge.Parent = headerFrame

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 14)
badgeCorner.Parent = statusBadge

-- Helper untuk membuat Text Input Field
local function createInputField(name, labelText, placeholder, defaultValue, layoutOrder)
    local card = Instance.new("Frame")
    card.Name = name .. "_Card"
    card.Size = UDim2.new(1, 0, 0, 68)
    card.BackgroundColor3 = Color3.fromRGB(33, 36, 44)
    card.LayoutOrder = layoutOrder
    card.Parent = mainContainer

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(48, 52, 65)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 8)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamSemibold
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(180, 185, 200)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = card

    local textBox = Instance.new("TextBox")
    textBox.Name = "InputBox"
    textBox.Size = UDim2.new(1, -20, 0, 30)
    textBox.Position = UDim2.new(0, 10, 0, 30)
    textBox.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
    textBox.TextColor3 = Color3.fromRGB(240, 240, 245)
    textBox.PlaceholderColor3 = Color3.fromRGB(110, 115, 130)
    textBox.PlaceholderText = placeholder
    textBox.Text = defaultValue or ""
    textBox.Font = Enum.Font.Gotham
    textBox.TextSize = 13
    textBox.ClearTextOnFocus = false
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.Parent = card

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = textBox

    local boxPadding = Instance.new("UIPadding")
    boxPadding.PaddingLeft = UDim.new(0, 8)
    boxPadding.PaddingRight = UDim.new(0, 8)
    boxPadding.Parent = textBox

    return card, textBox
end

-- 2. INPUT FIELDS
local _, urlTextBox = createInputField("ServerUrl", "URL Server Backend", "http://localhost:3000", defaultUrl, 2)
local _, userTextBox = createInputField("TikTokUser", "Username TikTok Live", "Contoh: khaby.lame", defaultUsername, 3)

-- 3. TOMBOL AKSI UTAMA (Start & Stop)
local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "ButtonContainer"
buttonContainer.Size = UDim2.new(1, 0, 0, 44)
buttonContainer.BackgroundTransparency = 1
buttonContainer.LayoutOrder = 4
buttonContainer.Parent = mainContainer

local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Size = UDim2.new(0.48, 0, 1, 0)
startButton.Position = UDim2.new(0, 0, 0, 0)
startButton.BackgroundColor3 = Color3.fromRGB(0, 175, 116)
startButton.Font = Enum.Font.GothamBold
startButton.Text = "▶ Start Listening"
startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startButton.TextSize = 13
startButton.AutoButtonColor = true
startButton.Parent = buttonContainer

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 8)
startCorner.Parent = startButton

local stopButton = Instance.new("TextButton")
stopButton.Name = "StopButton"
stopButton.Size = UDim2.new(0.48, 0, 1, 0)
stopButton.Position = UDim2.new(0.52, 0, 0, 0)
stopButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
stopButton.Font = Enum.Font.GothamBold
stopButton.Text = "⏹ Stop"
stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopButton.TextSize = 13
stopButton.AutoButtonColor = true
stopButton.Parent = buttonContainer

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 8)
stopCorner.Parent = stopButton

-- 4. LOG / STATUS ACTIVITY CONSOLE DI DALAM PLUGIN
local logCard = Instance.new("Frame")
logCard.Name = "LogCard"
logCard.Size = UDim2.new(1, 0, 0, 95)
logCard.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
logCard.LayoutOrder = 5
logCard.Parent = mainContainer

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 8)
logCorner.Parent = logCard

local logStroke = Instance.new("UIStroke")
logStroke.Color = Color3.fromRGB(40, 44, 55)
logStroke.Thickness = 1
logStroke.Parent = logCard

local logLabel = Instance.new("TextLabel")
logLabel.Name = "LogLabel"
logLabel.Size = UDim2.new(1, -16, 1, -12)
logLabel.Position = UDim2.new(0, 8, 0, 6)
logLabel.BackgroundTransparency = 1
logLabel.Font = Enum.Font.Code
logLabel.TextColor3 = Color3.fromRGB(0, 230, 180)
logLabel.TextSize = 11
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.Text = "Status: Siap.\nMasukkan username & klik 'Start Listening'."
logLabel.Parent = logCard

local function setLog(text, color)
    logLabel.Text = string.format("[%s]\n%s", os.date("%H:%M:%S"), text)
    logLabel.TextColor3 = color or Color3.fromRGB(0, 230, 180)
end

-- 5. PANEL QUICK SIMULATOR (PENGUJIAN CEPAT)
local simTitle = Instance.new("TextLabel")
simTitle.Name = "SimTitle"
simTitle.Size = UDim2.new(1, 0, 0, 20)
simTitle.BackgroundTransparency = 1
simTitle.Font = Enum.Font.GothamBold
simTitle.Text = "⚡ QUICK SIMULATOR (TESTING)"
simTitle.TextColor3 = Color3.fromRGB(170, 175, 190)
simTitle.TextSize = 11
simTitle.TextXAlignment = Enum.TextXAlignment.Left
simTitle.LayoutOrder = 6
simTitle.Parent = mainContainer

local simContainer = Instance.new("Frame")
simContainer.Name = "SimContainer"
simContainer.Size = UDim2.new(1, 0, 0, 36)
simContainer.BackgroundTransparency = 1
simContainer.LayoutOrder = 7
simContainer.Parent = mainContainer

local simLayout = Instance.new("UIGridLayout")
simLayout.CellSize = UDim2.new(0.31, 0, 1, 0)
simLayout.CellPadding = UDim2.new(0.035, 0, 0, 0)
simLayout.Parent = simContainer

local function createSimButton(name, text, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Parent = simContainer

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local btnTestRose = createSimButton("BtnRose", "🌹 Test Rose", Color3.fromRGB(230, 50, 100))
local btnTestDonut = createSimButton("BtnDonut", "🍩 Test Donut", Color3.fromRGB(210, 105, 30))
local btnTestLike = createSimButton("BtnLike", "❤️ Test Like", Color3.fromRGB(160, 40, 200))

-- ============================================================================
-- 6. PANEL AUTO MAP GENERATOR (PAKET LENGKAP - NOXORA STUDIO)
-- ============================================================================
local mapCard = Instance.new("Frame")
mapCard.Name = "MapCard"
mapCard.Size = UDim2.new(1, 0, 0, 235)
mapCard.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
mapCard.LayoutOrder = 8
mapCard.Parent = mainContainer

local mcCorner = Instance.new("UICorner")
mcCorner.CornerRadius = UDim.new(0, 8)
mcCorner.Parent = mapCard

local mcStroke = Instance.new("UIStroke")
mcStroke.Color = Color3.fromRGB(0, 200, 255)
mcStroke.Thickness = 1.2
mcStroke.Parent = mapCard

local mcTitle = Instance.new("TextLabel")
mcTitle.Size = UDim2.new(1, -20, 0, 22)
mcTitle.Position = UDim2.new(0, 10, 0, 8)
mcTitle.BackgroundTransparency = 1
mcTitle.Font = Enum.Font.GothamBold
mcTitle.Text = "🗺️ AUTO MAP GENERATOR (PAKET LENGKAP)"
mcTitle.TextColor3 = Color3.fromRGB(0, 230, 255)
mcTitle.TextSize = 12
mcTitle.TextXAlignment = Enum.TextXAlignment.Left
mcTitle.Parent = mapCard

local mcDesc = Instance.new("TextLabel")
mcDesc.Size = UDim2.new(1, -20, 0, 28)
mcDesc.Position = UDim2.new(0, 10, 0, 28)
mcDesc.BackgroundTransparency = 1
mcDesc.Font = Enum.Font.Gotham
mcDesc.Text = "Bangun arena 3D instan 1-klik! Termasuk spawn, billboard gift & void guard. Fitur ini aman & opsional jika Anda sudah punya map sendiri."
mcDesc.TextColor3 = Color3.fromRGB(170, 180, 200)
mcDesc.TextSize = 10
mcDesc.TextWrapped = true
mcDesc.TextXAlignment = Enum.TextXAlignment.Left
mcDesc.Parent = mapCard

-- Theme selector grid (3 tema)
local selectedPluginTheme = defaultTheme
local themePluginBtns = {}

local themeGrid = Instance.new("Frame")
themeGrid.Size = UDim2.new(1, -20, 0, 52)
themeGrid.Position = UDim2.new(0, 10, 0, 60)
themeGrid.BackgroundTransparency = 1
themeGrid.Parent = mapCard

local tgLayout = Instance.new("UIGridLayout")
tgLayout.CellSize = UDim2.new(0.315, 0, 1, 0)
tgLayout.CellPadding = UDim2.new(0.027, 0, 0, 0)
tgLayout.Parent = themeGrid

local PLUGIN_THEMES = {
    { key = "tropical", name = "🏝️ Tropis", desc = "Pantai & Sunset", color = Color3.fromRGB(230, 160, 40) },
    { key = "cyberpunk", name = "⚡ Cyberpunk", desc = "Neon & Obsidian", color = Color3.fromRGB(0, 220, 255) },
    { key = "skyblock", name = "☁️ Skyblock", desc = "Kastil Awan", color = Color3.fromRGB(180, 120, 255) }
}

for _, t in ipairs(PLUGIN_THEMES) do
    local tBtn = Instance.new("TextButton")
    tBtn.Name = "BtnTheme_" .. t.key
    tBtn.BackgroundColor3 = (selectedPluginTheme == t.key) and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(20, 23, 30)
    tBtn.Font = Enum.Font.GothamBold
    tBtn.Text = t.name .. "\n" .. t.desc
    tBtn.TextColor3 = (selectedPluginTheme == t.key) and t.color or Color3.fromRGB(180, 185, 200)
    tBtn.TextSize = 10
    tBtn.Parent = themeGrid

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 6)
    tCorner.Parent = tBtn

    local tStroke = Instance.new("UIStroke")
    tStroke.Color = (selectedPluginTheme == t.key) and t.color or Color3.fromRGB(45, 50, 65)
    tStroke.Thickness = (selectedPluginTheme == t.key) and 1.8 or 1
    tStroke.Parent = tBtn

    themePluginBtns[t.key] = { btn = tBtn, stroke = tStroke, data = t }

    tBtn.MouseButton1Click:Connect(function()
        selectedPluginTheme = t.key
        plugin:SetSetting(SETTING_THEME_KEY, t.key)
        configDefaultTheme.Value = t.key
        for k, v in pairs(themePluginBtns) do
            local isSel = (k == selectedPluginTheme)
            v.btn.BackgroundColor3 = isSel and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(20, 23, 30)
            v.btn.TextColor3 = isSel and v.data.color or Color3.fromRGB(180, 185, 200)
            v.stroke.Color = isSel and v.data.color or Color3.fromRGB(45, 50, 65)
            v.stroke.Thickness = isSel and 1.8 or 1
        end
    end)
end

-- Tombol SELECT/GENERATE dan RESET
local mapActionsRow = Instance.new("Frame")
mapActionsRow.Size = UDim2.new(1, -20, 0, 36)
mapActionsRow.Position = UDim2.new(0, 10, 0, 120)
mapActionsRow.BackgroundTransparency = 1
mapActionsRow.Parent = mapCard

local btnPluginGenMap = Instance.new("TextButton")
btnPluginGenMap.Name = "BtnPluginGenMap"
btnPluginGenMap.Size = UDim2.new(0.62, 0, 1, 0)
btnPluginGenMap.BackgroundColor3 = Color3.fromRGB(0, 175, 116)
btnPluginGenMap.Font = Enum.Font.GothamBold
btnPluginGenMap.Text = "✨ Generate Map Tema"
btnPluginGenMap.TextColor3 = Color3.fromRGB(255, 255, 255)
btnPluginGenMap.TextSize = 11
btnPluginGenMap.Parent = mapActionsRow

local bpgCorner = Instance.new("UICorner")
bpgCorner.CornerRadius = UDim.new(0, 6)
bpgCorner.Parent = btnPluginGenMap

local btnPluginResetMap = Instance.new("TextButton")
btnPluginResetMap.Name = "BtnPluginResetMap"
btnPluginResetMap.Size = UDim2.new(0.35, 0, 1, 0)
btnPluginResetMap.Position = UDim2.new(0.65, 0, 0, 0)
btnPluginResetMap.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
btnPluginResetMap.Font = Enum.Font.GothamBold
btnPluginResetMap.Text = "🧹 Reset Map"
btnPluginResetMap.TextColor3 = Color3.fromRGB(255, 255, 255)
btnPluginResetMap.TextSize = 11
btnPluginResetMap.Parent = mapActionsRow

local bprCorner = Instance.new("UICorner")
bprCorner.CornerRadius = UDim.new(0, 6)
bprCorner.Parent = btnPluginResetMap

-- Toggle Checkbox Auto-Generate saat Play
local autoRow = Instance.new("Frame")
autoRow.Size = UDim2.new(1, -20, 0, 24)
autoRow.Position = UDim2.new(0, 10, 0, 164)
autoRow.BackgroundTransparency = 1
autoRow.Parent = mapCard

local autoToggleBtn = Instance.new("TextButton")
autoToggleBtn.Size = UDim2.new(0, 20, 0, 20)
autoToggleBtn.Position = UDim2.new(0, 0, 0, 2)
autoToggleBtn.BackgroundColor3 = defaultAutoMap and Color3.fromRGB(0, 175, 116) or Color3.fromRGB(40, 45, 55)
autoToggleBtn.Font = Enum.Font.GothamBold
autoToggleBtn.Text = defaultAutoMap and "✓" or ""
autoToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoToggleBtn.TextSize = 12
autoToggleBtn.Parent = autoRow

local atbCorner = Instance.new("UICorner")
atbCorner.CornerRadius = UDim.new(0, 4)
atbCorner.Parent = autoToggleBtn

local autoLabel = Instance.new("TextLabel")
autoLabel.Size = UDim2.new(1, -28, 1, 0)
autoLabel.Position = UDim2.new(0, 28, 0, 0)
autoLabel.BackgroundTransparency = 1
autoLabel.Font = Enum.Font.GothamMedium
autoLabel.Text = "Otomatis generate map saat Play (Paket Lengkap)"
autoLabel.TextColor3 = Color3.fromRGB(200, 210, 225)
autoLabel.TextSize = 10
autoLabel.TextXAlignment = Enum.TextXAlignment.Left
autoLabel.Parent = autoRow

autoToggleBtn.MouseButton1Click:Connect(function()
    local newState = not configAutoMap.Value
    configAutoMap.Value = newState
    plugin:SetSetting(SETTING_AUTOMAP_KEY, newState)
    autoToggleBtn.Text = newState and "✓" or ""
    autoToggleBtn.BackgroundColor3 = newState and Color3.fromRGB(0, 175, 116) or Color3.fromRGB(40, 45, 55)
    setLog(string.format("Auto-Generate Map saat Play: %s", newState and "AKTIF" or "NONAKTIF"), Color3.fromRGB(150, 220, 255))
end)

local noteMap = Instance.new("TextLabel")
noteMap.Size = UDim2.new(1, -20, 0, 30)
noteMap.Position = UDim2.new(0, 10, 0, 192)
noteMap.BackgroundTransparency = 1
noteMap.Font = Enum.Font.Gotham
noteMap.Text = "💡 Tips: Jika Anda memiliki map kustom sendiri, hilangkan centang di atas atau klik 'Reset Map'."
noteMap.TextColor3 = Color3.fromRGB(130, 140, 165)
noteMap.TextSize = 9
noteMap.TextWrapped = true
noteMap.TextXAlignment = Enum.TextXAlignment.Left
noteMap.Parent = mapCard

-- ============================================================================
-- 7. FOOTER WATERMARK HAK CIPTA RESMI (NOXORA STUDIO)
-- ============================================================================
local pluginFooter = Instance.new("Frame")
pluginFooter.Name = "PluginFooterWatermark"
pluginFooter.Size = UDim2.new(1, 0, 0, 36)
pluginFooter.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
pluginFooter.LayoutOrder = 9
pluginFooter.Parent = mainContainer

local pfCorner = Instance.new("UICorner")
pfCorner.CornerRadius = UDim.new(0, 8)
pfCorner.Parent = pluginFooter

local pfStroke = Instance.new("UIStroke")
pfStroke.Color = Color3.fromRGB(35, 40, 55)
pfStroke.Parent = pluginFooter

local pfLabel = Instance.new("TextLabel")
pfLabel.Size = UDim2.new(1, -20, 1, 0)
pfLabel.Position = UDim2.new(0, 10, 0, 0)
pfLabel.BackgroundTransparency = 1
pfLabel.Font = Enum.Font.GothamBold
pfLabel.Text = "🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI"
pfLabel.TextColor3 = Color3.fromRGB(0, 200, 240)
pfLabel.TextSize = 10
pfLabel.TextXAlignment = Enum.TextXAlignment.Center
pfLabel.Parent = pluginFooter

-- Anti-tamper protection untuk footer plugin
pfLabel:GetPropertyChangedSignal("Text"):Connect(function()
    if pfLabel.Text ~= "🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI" then
        pfLabel.Text = "🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI"
    end
end)

-- ============================================================================
-- LOGIKA KONTROL LISTENING & PERSISTENSI SETTINGS
-- ============================================================================

local function saveCurrentSettings()
    local url = urlTextBox.Text:gsub("%s+", "")
    local username = userTextBox.Text:gsub("%s+", ""):gsub("^@", "")

    if url == "" then url = "http://localhost:3000" end

    -- Simpan ke Studio Settings
    plugin:SetSetting(SETTING_URL_KEY, url)
    plugin:SetSetting(SETTING_USER_KEY, username)

    -- Sinkronisasi ke ReplicatedStorage (bisa dibaca script game)
    configServerUrl.Value = url
    configUsername.Value = username

    return url, username
end

-- Simpan otomatis saat teks input diedit
urlTextBox.FocusLost:Connect(saveCurrentSettings)
userTextBox.FocusLost:Connect(saveCurrentSettings)

-- Aksi Start Listening
startButton.MouseButton1Click:Connect(function()
    local url, username = saveCurrentSettings()

    if username == "" then
        setLog("PERINGATAN: Harap masukkan username TikTok terlebih dahulu!", Color3.fromRGB(255, 180, 50))
        return
    end

    setLog("Menghubungkan ke backend: " .. url .. "...", Color3.fromRGB(100, 200, 255))

    -- Update state ReplicatedStorage
    configIsListening.Value = true
    isListening = true

    -- Kirim permintaan ke Backend untuk menghubungkan TikTok Live ke username tersebut
    task.spawn(function()
        local endpoint = string.format("%s/connect?username=%s", url, HttpService:UrlEncode(username))
        local success, result = pcall(function()
            return HttpService:GetAsync(endpoint, true)
        end)

        if success then
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(result)
            end)

            if decodeSuccess and data and data.success then
                statusBadge.Text = "LISTENING"
                statusBadge.BackgroundColor3 = Color3.fromRGB(0, 175, 116)
                statusBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
                setLog(string.format("TERHUBUNG!\nLive Stream @%s aktif.\nPolling dimulai.", username), Color3.fromRGB(0, 255, 150))
            else
                local errMsg = (data and data.message) or "Gagal menghubungkan ke live."
                setLog("Backend Response:\n" .. errMsg, Color3.fromRGB(255, 180, 50))
                statusBadge.Text = "ACTIVE (ERR)"
                statusBadge.BackgroundColor3 = Color3.fromRGB(230, 140, 20)
            end
        else
            setLog("Gagal terhubung ke backend server!\nPastikan 'node server.js' berjalan di " .. url .. "\nError: " .. tostring(result), Color3.fromRGB(255, 80, 80))
            statusBadge.Text = "OFFLINE"
            statusBadge.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        end
    end)
end)

-- Aksi Stop Listening
stopButton.MouseButton1Click:Connect(function()
    local url, _ = saveCurrentSettings()

    configIsListening.Value = false
    isListening = false

    statusBadge.Text = "STOPPED"
    statusBadge.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
    statusBadge.TextColor3 = Color3.fromRGB(200, 205, 215)
    setLog("Polling dihentikan oleh user.", Color3.fromRGB(200, 205, 215))

    -- Beritahu backend untuk disconnect
    task.spawn(function()
        pcall(function()
            HttpService:GetAsync(url .. "/disconnect", true)
        end)
    end)
end)

-- Handler Tombol Simulator Cepat
local function triggerSimulation(type, name, count)
    local url, _ = saveCurrentSettings()
    local endpoint = string.format("%s/simulate?type=%s&name=%s&count=%d&user=StudioTester", url, type, name, count or 1)
    
    setLog("Mengirim event simulasi: " .. name .. "...", Color3.fromRGB(150, 200, 255))

    task.spawn(function()
        local success, res = pcall(function()
            return HttpService:GetAsync(endpoint, true)
        end)
        if success then
            setLog("Simulasi berhasil dikirim ke antrean!\nEvent: " .. name, Color3.fromRGB(0, 255, 150))
        else
            setLog("Gagal mengirim simulasi: " .. tostring(res), Color3.fromRGB(255, 80, 80))
        end
    end)
end

btnTestRose.MouseButton1Click:Connect(function()
    triggerSimulation("gift", "Rose", 1)
end)

btnTestDonut.MouseButton1Click:Connect(function()
    triggerSimulation("gift", "Donut", 1)
end)

btnTestLike.MouseButton1Click:Connect(function()
    triggerSimulation("like", "Like", 20)
end)

-- ============================================================================
-- HANDLER AUTO MAP GENERATOR (STUDIO EDIT MODE) - NOXORA STUDIO
-- ============================================================================
local function getOrCreateMapGenerator()
    local sss = game:GetService("ServerScriptService")
    local mod = sss:FindFirstChild("TikTokMapGenerator")
    if mod and mod:IsA("ModuleScript") then
        local ok, res = pcall(require, mod)
        if ok and res then return res end
    end
    return nil
end

btnPluginGenMap.MouseButton1Click:Connect(function()
    setLog(string.format("Membangun map tema '%s' di Workspace...", selectedPluginTheme), Color3.fromRGB(100, 200, 255))
    ChangeHistoryService:SetWaypoint("Sebelum Generate Map Noxora")

    local MapGen = getOrCreateMapGenerator()
    if MapGen then
        local ok, res = pcall(function()
            return MapGen.Generate(selectedPluginTheme)
        end)
        if ok then
            setLog(string.format("SUKSES!\nMap tema '%s' aktif di Workspace.\nPowered by NOXORA STUDIO", selectedPluginTheme:upper()), Color3.fromRGB(0, 255, 180))
            ChangeHistoryService:SetWaypoint("Setelah Generate Map Noxora")
        else
            setLog("Gagal generate map: " .. tostring(res), Color3.fromRGB(255, 80, 80))
        end
    else
        setLog("PERINGATAN: 'TikTokMapGenerator' tidak ditemukan di ServerScriptService!\nPastikan file 'TikTokMapGenerator.lua' ada.", Color3.fromRGB(255, 180, 50))
    end
end)

btnPluginResetMap.MouseButton1Click:Connect(function()
    ChangeHistoryService:SetWaypoint("Sebelum Reset Map Noxora")
    local MapGen = getOrCreateMapGenerator()
    if MapGen then
        MapGen.Clear()
        setLog("SUKSES!\nMap TikTokGeneratedMap dibersihkan.\nMap kustom Anda tetap aman.", Color3.fromRGB(255, 200, 50))
    else
        local existingMap = workspace:FindFirstChild("TikTokGeneratedMap")
        if existingMap then
            existingMap:Destroy()
            setLog("Folder TikTokGeneratedMap berhasil dihapus.", Color3.fromRGB(255, 200, 50))
        else
            setLog("Tidak ada map TikTokGeneratedMap yang perlu dibersihkan.", Color3.fromRGB(180, 190, 200))
        end
    end
    ChangeHistoryService:SetWaypoint("Setelah Reset Map Noxora")
end)

print("[TIKTOK LIVE PLUGIN] Plugin resmi NOXORA STUDIO berhasil dimuat!")
