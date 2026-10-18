--[[
    ============================================================================
    NOXORA STUDIO - TIKTOK LIVE MAP GENERATOR MODULE
    File: TikTokMapGenerator.lua
    Lokasi: ServerScriptService (ModuleScript)
    ============================================================================
    
    Hak Cipta: (c) NOXORA STUDIO - All Rights Reserved.
    Watermark resmi mesin interaktif TikTok Live Roblox.
    
    Fitur Utama:
    1. Otomatis men-generate arena map siap pakai dengan 1 klik (Paket Lengkap).
    2. Mendukung 3 Tema Menakjubkan:
       - 'tropical'  : Pulau Tropis Eksotis (Pantai pasir, pohon kelapa, laut karang)
       - 'cyberpunk' : Cyber Neon Colosseum (Lantai obsidian, grid neon bersinar, pylon energi)
       - 'skyblock'  : Cloud Kingdom (Kastil pulau melayang di atas awan)
    3. Sudah include SpawnLocation, Billboard Info Gift Raksasa, dan Void KillZone Protection.
    4. Menyertakan Watermark Holografis resmi "NOXORA STUDIO".
    5. Fitur Reset / Clear Map instan tanpa merusak elemen map bawaan pengguna.
    ============================================================================
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local MapGenerator = {}

-- WATERMARK RESMI NOXORA STUDIO
local WATERMARK_TITLE = "NOXORA STUDIO"
local WATERMARK_TAGLINE = "TIKTOK INTERACTIVE ENGINE v2.5"

-- Helper untuk membuat part cepat
local function createPart(name, size, cframe, material, color, transparency, anchored, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cframe
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color or Color3.fromRGB(200, 200, 200)
    p.Transparency = transparency or 0
    p.Anchored = (anchored ~= nil) and anchored or true
    p.CanCollide = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- ============================================================================
-- 1. BERSIHKAN / RESET MAP (NON-DESTRUCTIVE)
-- ============================================================================
function MapGenerator.Clear()
    local existingMap = workspace:FindFirstChild("TikTokGeneratedMap")
    if existingMap then
        existingMap:Destroy()
        print("[NOXORA MAP] Map sebelumnya berhasil di-reset / dibersihkan.")
        return true
    end
    return false
end

-- ============================================================================
-- 2. WATERMARK RESMI & BILLBOARD STREAMING NOXORA STUDIO
-- ============================================================================
local function buildWatermarkAndBillboard(folder, themeKey)
    local billboardModel = Instance.new("Model")
    billboardModel.Name = "NoxoraStreamBillboard"
    billboardModel.Parent = folder

    -- Stand / Tiang Penyangga Layar
    local pole1 = createPart("PoleLeft", Vector3.new(2, 22, 2), CFrame.new(-18, 11, 45), Enum.Material.Metal, Color3.fromRGB(30, 32, 42), 0, true, billboardModel)
    local pole2 = createPart("PoleRight", Vector3.new(2, 22, 2), CFrame.new(18, 11, 45), Enum.Material.Metal, Color3.fromRGB(30, 32, 42), 0, true, billboardModel)

    -- Bingkai Layar Raksasa
    local screenFrame = createPart("ScreenFrame", Vector3.new(42, 24, 1.5), CFrame.new(0, 20, 45), Enum.Material.SmoothPlastic, Color3.fromRGB(15, 18, 25), 0, true, billboardModel)

    -- SurfaceGui untuk Display Info Gift
    local sg = Instance.new("SurfaceGui")
    sg.Name = "GiftInfoGui"
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(840, 480)
    sg.AlwaysOnTop = false
    sg.Parent = screenFrame

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
    bg.BorderSizePixel = 0
    bg.Parent = sg

    -- Header dengan Watermark NOXORA STUDIO
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, 80)
    headerFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = bg

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 45)
    titleLbl.Position = UDim2.new(0, 0, 0, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.Text = "🎁 PANDUAN GIFT TIKTOK LIVE INTERAKTIF"
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.TextSize = 28
    titleLbl.Parent = headerFrame

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, 0, 0, 24)
    subLbl.Position = UDim2.new(0, 0, 0, 48)
    subLbl.BackgroundTransparency = 1
    subLbl.Font = Enum.Font.GothamBold
    subLbl.Text = "⚡ POWERED BY " .. WATERMARK_TITLE .. " • " .. WATERMARK_TAGLINE
    subLbl.TextColor3 = Color3.fromRGB(0, 220, 255)
    subLbl.TextSize = 14
    subLbl.Parent = headerFrame

    -- Grid Item Gift
    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, -40, 1, -100)
    grid.Position = UDim2.new(0, 20, 0, 90)
    grid.BackgroundTransparency = 1
    grid.Parent = bg

    local uigrid = Instance.new("UIGridLayout")
    uigrid.CellSize = UDim2.new(0.485, 0, 0, 52)
    uigrid.CellPadding = UDim2.new(0.03, 0, 0, 10)
    uigrid.Parent = grid

    local giftList = {
        { name = "🌹 ROSE", action = "Spawn Balok Lantai (+1)", color = Color3.fromRGB(255, 75, 120) },
        { name = "🍩 DONUT", action = "BAHAYA TSUNAMI AIR 3D!", color = Color3.fromRGB(0, 160, 240) },
        { name = "⚡ ICE CREAM", action = "Speed Boost Lari 2x", color = Color3.fromRGB(0, 230, 255) },
        { name = "🚀 CAP", action = "Super Jump Roket 2x", color = Color3.fromRGB(255, 170, 0) },
        { name = "☄️ DRAGON", action = "Hujan Meteor Api Panas", color = Color3.fromRGB(255, 60, 40) },
        { name = "⭐ FOLLOW", action = "Kembang Api Perayaan", color = Color3.fromRGB(255, 220, 50) }
    }

    for _, g in ipairs(giftList) do
        local card = Instance.new("Frame")
        card.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
        card.Parent = grid

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = g.color
        cStroke.Thickness = 1.5
        cStroke.Parent = card

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, -20, 1, 0)
        txt.Position = UDim2.new(0, 10, 0, 0)
        txt.BackgroundTransparency = 1
        txt.Font = Enum.Font.GothamBold
        txt.Text = string.format("%s  ➔  %s", g.name, g.action)
        txt.TextColor3 = Color3.fromRGB(240, 245, 255)
        txt.TextSize = 16
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.Parent = card
    end

    -- 2. HOLOGRAPHIC PEDESTAL WATERMARK NOXORA STUDIO (Plakat Fisik Permanen & Terproteksi)
    local plaque = createPart("NoxoraWatermarkPlaque", Vector3.new(16, 3.5, 3), CFrame.new(0, 2, -28), Enum.Material.Glass, Color3.fromRGB(20, 25, 35), 0.1, true, billboardModel)
    local neonBorder = createPart("PlaqueNeonBorder", Vector3.new(16.4, 0.4, 3.4), CFrame.new(0, 3.6, -28), Enum.Material.Neon, Color3.fromRGB(0, 230, 255), 0, true, billboardModel)

    -- Kunci part agar tidak bisa dipindah/diedit sembarangan
    plaque.Locked = true
    neonBorder.Locked = true
    screenFrame.Locked = true
    pole1.Locked = true
    pole2.Locked = true

    -- Atribut hak cipta resmi
    plaque:SetAttribute("Copyright", "NOXORA STUDIO")
    plaque:SetAttribute("Protected", true)
    billboardModel:SetAttribute("Author", "NOXORA STUDIO")

    local sgPlaque = Instance.new("SurfaceGui")
    sgPlaque.Face = Enum.NormalId.Top
    sgPlaque.CanvasSize = Vector2.new(400, 80)
    sgPlaque.Parent = plaque

    local pLbl = Instance.new("TextLabel")
    pLbl.Size = UDim2.new(1, 0, 1, 0)
    pLbl.BackgroundTransparency = 1
    pLbl.Font = Enum.Font.GothamBlack
    pLbl.Text = "★ " .. WATERMARK_TITLE .. " OFFICIAL ENGINE ★"
    pLbl.TextColor3 = Color3.fromRGB(0, 240, 255)
    pLbl.TextSize = 20
    pLbl.Parent = sgPlaque

    -- Anti-Tamper Listener: Pastikan teks watermark tidak dapat diubah oleh script lain
    pLbl:GetPropertyChangedSignal("Text"):Connect(function()
        if pLbl.Text ~= "★ " .. WATERMARK_TITLE .. " OFFICIAL ENGINE ★" then
            pLbl.Text = "★ " .. WATERMARK_TITLE .. " OFFICIAL ENGINE ★"
        end
    end)

    subLbl:GetPropertyChangedSignal("Text"):Connect(function()
        if not string.find(subLbl.Text, WATERMARK_TITLE) then
            subLbl.Text = "⚡ POWERED BY " .. WATERMARK_TITLE .. " • " .. WATERMARK_TAGLINE
        end
    end)
end

-- ============================================================================
-- 3. VOID KILLZONE / RESPAWN PROTECTION
-- ============================================================================
local function setupVoidProtection(folder, spawnPos)
    local killPart = createPart("VoidProtectionBarrier", Vector3.new(600, 4, 600), CFrame.new(0, -35, 0), Enum.Material.ForceField, Color3.fromRGB(255, 0, 0), 1, true, folder)
    killPart.CanCollide = false

    killPart.Touched:Connect(function(hit)
        local character = hit.Parent
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Teleport pemain kembali ke spawn dengan aman
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
            print(string.format("[NOXORA PROTECTION] %s diselamatkan dari void dan diteleport ke spawn.", character.Name))
        end
    end)
end

-- ============================================================================
-- 4. TEMA 1: PULAU TROPIS (TROPICAL ISLAND)
-- ============================================================================
local function buildTropicalIsland(mapFolder)
    local islandModel = Instance.new("Model")
    islandModel.Name = "TropicalIsland"
    islandModel.Parent = mapFolder

    -- Pasir Pulau Utama (Lingkaran Pasir Lebar)
    local sandBase = createPart("IslandSandBase", Vector3.new(80, 8, 80), CFrame.new(0, 0, 0), Enum.Material.Sand, Color3.fromRGB(230, 210, 160), 0, true, islandModel)
    sandBase.Shape = Enum.PartType.Cylinder
    sandBase.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))

    -- Tanah Rumput Tengah
    local grassCenter = createPart("IslandGrassCenter", Vector3.new(50, 8.2, 50), CFrame.new(0, 0.1, 0), Enum.Material.Grass, Color3.fromRGB(85, 165, 60), 0, true, islandModel)
    grassCenter.Shape = Enum.PartType.Cylinder
    grassCenter.CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))

    -- Cincin Air Laguna Laut di Sekitar Pulau
    local lagoon = createPart("CoralLagoonWater", Vector3.new(160, 2, 160), CFrame.new(0, -1, 0), Enum.Material.Glass, Color3.fromRGB(15, 140, 200), 0.35, true, islandModel)
    lagoon.Shape = Enum.PartType.Cylinder
    lagoon.CFrame = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90))
    lagoon.CanCollide = false

    -- Batu Karang Dekorasi
    createPart("Rock1", Vector3.new(8, 6, 8), CFrame.new(-32, 3, -15), Enum.Material.Slate, Color3.fromRGB(120, 125, 130), 0, true, islandModel)
    createPart("Rock2", Vector3.new(10, 7, 9), CFrame.new(30, 3, 20), Enum.Material.Slate, Color3.fromRGB(110, 115, 120), 0, true, islandModel)

    -- Pohon Kelapa Stylized (Trunk + Leaves)
    local function spawnPalmTree(pos, rotY)
        local trunk = createPart("PalmTrunk", Vector3.new(2.5, 18, 2.5), CFrame.new(pos + Vector3.new(0, 9, 0)) * CFrame.Angles(math.rad(8), math.rad(rotY), 0), Enum.Material.Wood, Color3.fromRGB(130, 85, 45), 0, true, islandModel)
        local leafCenter = pos + Vector3.new(0, 18, 0)
        for i = 1, 6 do
            local angle = (i * 60) * (math.pi / 180)
            local leaf = createPart("PalmLeaf_" .. i, Vector3.new(10, 0.8, 3.5), CFrame.new(leafCenter + Vector3.new(math.cos(angle) * 4, -1, math.sin(angle) * 4)) * CFrame.Angles(0, angle, math.rad(-20)), Enum.Material.Grass, Color3.fromRGB(45, 140, 40), 0, true, islandModel)
        end
    end

    spawnPalmTree(Vector3.new(-22, 4, 15), 30)
    spawnPalmTree(Vector3.new(24, 4, -12), 120)

    -- SpawnLocation Kayu Tropis
    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Name = "TropicalSpawn"
    spawnLoc.Size = Vector3.new(10, 1.2, 10)
    spawnLoc.CFrame = CFrame.new(0, 4.5, -16)
    spawnLoc.Material = Enum.Material.WoodPlanks
    spawnLoc.Color = Color3.fromRGB(160, 110, 65)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = true
    spawnLoc.Neutral = true
    spawnLoc.Duration = 0
    spawnLoc.Parent = islandModel

    -- Suasana Lighting: Sunset Golden Hour
    Lighting.ClockTime = 17.6
    Lighting.Brightness = 2.2
    Lighting.OutdoorAmbient = Color3.fromRGB(160, 120, 90)

    return spawnLoc.Position
end

-- ============================================================================
-- 5. TEMA 2: CYBER NEON COLOSSEUM (CYBERPUNK)
-- ============================================================================
local function buildCyberColosseum(mapFolder)
    local cyberModel = Instance.new("Model")
    cyberModel.Name = "CyberColosseum"
    cyberModel.Parent = mapFolder

    -- Lantai Obsidian Gelap Utama
    local baseFloor = createPart("CyberBaseFloor", Vector3.new(84, 6, 84), CFrame.new(0, 0, 0), Enum.Material.Glass, Color3.fromRGB(15, 17, 24), 0.1, true, cyberModel)
    baseFloor.Shape = Enum.PartType.Cylinder
    baseFloor.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))

    -- Ring Neon Cyan Bercahaya di Sekeliling Arena
    local neonRing = createPart("NeonGridRing", Vector3.new(86, 0.8, 86), CFrame.new(0, 3.2, 0), Enum.Material.Neon, Color3.fromRGB(0, 240, 255), 0, true, cyberModel)
    neonRing.Shape = Enum.PartType.Cylinder
    neonRing.CFrame = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90))
    neonRing.CanCollide = false

    -- Jalur Grid Neon Magenta (Cross lines)
    createPart("GridLineX", Vector3.new(80, 0.2, 2.5), CFrame.new(0, 3.1, 0), Enum.Material.Neon, Color3.fromRGB(255, 0, 128), 0, true, cyberModel).CanCollide = false
    createPart("GridLineZ", Vector3.new(2.5, 0.2, 80), CFrame.new(0, 3.1, 0), Enum.Material.Neon, Color3.fromRGB(255, 0, 128), 0, true, cyberModel).CanCollide = false

    -- 6 Pylon Energi di Sekeliling Arena (Hexagonal Energy Pylons)
    for i = 1, 6 do
        local angle = (i * 60) * (math.pi / 180)
        local px = math.cos(angle) * 38
        local pz = math.sin(angle) * 38

        local pylonBase = createPart("PylonBase_" .. i, Vector3.new(5, 14, 5), CFrame.new(px, 7, pz), Enum.Material.Metal, Color3.fromRGB(25, 28, 38), 0, true, cyberModel)
        local pylonCore = createPart("PylonCore_" .. i, Vector3.new(2, 10, 2), CFrame.new(px, 7, pz), Enum.Material.Neon, Color3.fromRGB(0, 230, 255), 0, true, cyberModel)

        local pylonLight = Instance.new("PointLight")
        pylonLight.Color = Color3.fromRGB(0, 220, 255)
        pylonLight.Range = 25
        pylonLight.Brightness = 2.0
        pylonLight.Parent = pylonCore
    end

    -- SpawnLocation Cyber Hex Pad
    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Name = "CyberSpawn"
    spawnLoc.Size = Vector3.new(10, 1.2, 10)
    spawnLoc.CFrame = CFrame.new(0, 3.6, -18)
    spawnLoc.Material = Enum.Material.Neon
    spawnLoc.Color = Color3.fromRGB(0, 255, 180)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = true
    spawnLoc.Neutral = true
    spawnLoc.Duration = 0
    spawnLoc.Parent = cyberModel

    -- Suasana Lighting: Cyber Midnight
    Lighting.ClockTime = 22.0
    Lighting.Brightness = 1.6
    Lighting.OutdoorAmbient = Color3.fromRGB(30, 25, 55)

    return spawnLoc.Position
end

-- ============================================================================
-- 6. TEMA 3: CLOUD KINGDOM (SKYBLOCK CASTLE)
-- ============================================================================
local function buildSkyblockKingdom(mapFolder)
    local skyModel = Instance.new("Model")
    skyModel.Name = "SkyblockKingdom"
    skyModel.Parent = mapFolder

    -- Pulau Batu Terapung Utama
    local stoneFloor = createPart("CastleStoneFloor", Vector3.new(78, 7, 78), CFrame.new(0, 0, 0), Enum.Material.Cobblestone, Color3.fromRGB(160, 165, 175), 0, true, skyModel)
    stoneFloor.Shape = Enum.PartType.Cylinder
    stoneFloor.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))

    -- Pilar-Pilar Kastil Yunani Kuno di Tepi Pulau
    for i = 1, 8 do
        local angle = (i * 45) * (math.pi / 180)
        local px = math.cos(angle) * 35
        local pz = math.sin(angle) * 35
        local col = createPart("CastleColumn_" .. i, Vector3.new(4, 16, 4), CFrame.new(px, 8, pz), Enum.Material.Marble, Color3.fromRGB(240, 240, 245), 0, true, skyModel)
        col.Shape = Enum.PartType.Cylinder
        col.CFrame = CFrame.new(px, 8, pz) * CFrame.Angles(0, 0, math.rad(90))
    end

    -- Obelisk Kristal Melayang di Tengah
    local obelisk = createPart("FloatingCrystal", Vector3.new(4, 9, 4), CFrame.new(0, 12, 0), Enum.Material.Glass, Color3.fromRGB(180, 100, 255), 0.15, true, skyModel)
    local oLight = Instance.new("PointLight")
    oLight.Color = Color3.fromRGB(200, 120, 255)
    oLight.Range = 30
    oLight.Brightness = 2.5
    oLight.Parent = obelisk

    -- Efek Gumpalan Awan Putih di Bawah Pulau
    for i = 1, 6 do
        local angle = (i * 60) * (math.pi / 180)
        local cx = math.cos(angle) * 32
        local cz = math.sin(angle) * 32
        local cloud = createPart("FluffyCloud_" .. i, Vector3.new(22, 6, 22), CFrame.new(cx, -3, cz), Enum.Material.SmoothPlastic, Color3.fromRGB(250, 252, 255), 0.35, true, skyModel)
        cloud.CanCollide = false
    end

    -- SpawnLocation Altar Suci
    local spawnLoc = Instance.new("SpawnLocation")
    spawnLoc.Name = "SkySpawn"
    spawnLoc.Size = Vector3.new(10, 1.2, 10)
    spawnLoc.CFrame = CFrame.new(0, 4.0, -18)
    spawnLoc.Material = Enum.Material.Marble
    spawnLoc.Color = Color3.fromRGB(255, 235, 170)
    spawnLoc.Anchored = true
    spawnLoc.CanCollide = true
    spawnLoc.Neutral = true
    spawnLoc.Duration = 0
    spawnLoc.Parent = skyModel

    -- Suasana Lighting: Radiant Heavenly Daylight
    Lighting.ClockTime = 14.0
    Lighting.Brightness = 2.8
    Lighting.OutdoorAmbient = Color3.fromRGB(140, 160, 200)

    return spawnLoc.Position
end

-- ============================================================================
-- 7. FUNGSI GENERATE MAP UTAMA
-- ============================================================================
function MapGenerator.Generate(themeKey)
    themeKey = tostring(themeKey or "tropical"):lower()

    -- Reset map lama terlebih dahulu jika ada
    MapGenerator.Clear()

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "TikTokGeneratedMap"
    mapFolder.Parent = workspace

    local spawnPos = Vector3.new(0, 5, -18)

    if themeKey == "cyberpunk" or themeKey == "cyber" or themeKey == "neon" then
        spawnPos = buildCyberColosseum(mapFolder)
    elseif themeKey == "skyblock" or themeKey == "cloud" or themeKey == "castle" then
        spawnPos = buildSkyblockKingdom(mapFolder)
    else
        -- Default: Pulau Tropis
        spawnPos = buildTropicalIsland(mapFolder)
    end

    -- Bangun Billboard Info Gift Raksasa & Watermark Plakat NOXORA STUDIO
    buildWatermarkAndBillboard(mapFolder, themeKey)

    -- Pasang Void Barrier Protector agar pemain tidak jatuh ke kehampaan
    setupVoidProtection(mapFolder, spawnPos)

    print(string.format("================================================================"))
    print(string.format("🏰 [NOXORA STUDIO] MAP OTOMATIS BERHASIL DI-GENERATE!"))
    print(string.format("🎨 Tema Aktif    : %s", themeKey:upper()))
    print(string.format("📍 Titik Spawn   : %s", tostring(spawnPos)))
    print(string.format("🛡️ Watermark     : %s (Protected)", WATERMARK_TITLE))
    print(string.format("================================================================"))

    return true, themeKey
end

return MapGenerator
