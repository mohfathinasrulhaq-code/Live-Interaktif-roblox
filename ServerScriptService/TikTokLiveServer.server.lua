--[[
    ============================================================================
    TIKTOK LIVE INTERACTIVE - SERVER GAME SCRIPT (ROBLOX STUDIO)
    File: TikTokLiveServer.server.lua
    Lokasi: ServerScriptService
    ============================================================================
    
    Deskripsi:
    Script utama di sisi Server Roblox yang bertugas melakukan polling antrean
    event dari Node.js backend secara berkala (setiap 1 detik) menggunakan HttpService.
    Script ini menangani:
    1. Polling HTTP via GetAsync dengan proteksi pcall (anti-crash saat server offline).
    2. Menghandle event Gift:
       - "Rose" / "Mawar" -> Menumbuhkan/men-spawn balok lantai baru secara dinamis.
       - "Donut" / "Donat" -> Memicu hazard Tsunami (ombak raksasa penyapu arena).
       - Gift lainnya -> Efek kejutan & koin/speed boost.
    3. Menghandle event Like:
       - Memancarkan partikel hati/sparkle pada semua karakter pemain & boost lompatan.
    4. Menghandle event Komentar & Follow:
       - Notifikasi publik dan kembang api perayaan.
    5. Menyinkronkan konfigurasi dengan Plugin UI (ReplicatedStorage: TikTokLiveConfig).
    ============================================================================
]]

-- Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- NOXORA STUDIO - Map Generator Integration
local MapGenerator
pcall(function()
    local mod = script.Parent:FindFirstChild("TikTokMapGenerator")
    if mod then
        MapGenerator = require(mod)
    end
end)

-- ============================================================================
-- KONFIGURASI DEFAULT
-- ============================================================================
local DEFAULT_BACKEND_URL = "http://localhost:3000" -- URL Node.js Backend lokal
local POLL_INTERVAL = 1.0                           -- Interval polling dalam detik
local IS_ACTIVE_BY_DEFAULT = true                   -- Apakah polling langsung aktif saat Play

-- ============================================================================
-- INISIALISASI REMOTE EVENT & CONFIG FOLDER DI REPLICATEDSTORAGE
-- ============================================================================

-- Folder konfigurasi untuk integrasi dinamis dengan Roblox Studio Plugin UI
local configFolder = ReplicatedStorage:FindFirstChild("TikTokLiveConfig")
if not configFolder then
    configFolder = Instance.new("Folder")
    configFolder.Name = "TikTokLiveConfig"
    configFolder.Parent = ReplicatedStorage
end

local serverUrlVal = configFolder:FindFirstChild("ServerUrl")
if not serverUrlVal then
    serverUrlVal = Instance.new("StringValue")
    serverUrlVal.Name = "ServerUrl"
    serverUrlVal.Value = DEFAULT_BACKEND_URL
    serverUrlVal.Parent = configFolder
end

local isListeningVal = configFolder:FindFirstChild("IsListening")
if not isListeningVal then
    isListeningVal = Instance.new("BoolValue")
    isListeningVal.Name = "IsListening"
    isListeningVal.Value = IS_ACTIVE_BY_DEFAULT
    isListeningVal.Parent = configFolder
end

local usernameVal = configFolder:FindFirstChild("TikTokUsername")
if not usernameVal then
    usernameVal = Instance.new("StringValue")
    usernameVal.Name = "TikTokUsername"
    usernameVal.Value = ""
    usernameVal.Parent = configFolder
end

-- NOXORA STUDIO: Auto Map Generator Configuration
local autoMapVal = configFolder:FindFirstChild("AutoGenerateMap")
if not autoMapVal then
    autoMapVal = Instance.new("BoolValue")
    autoMapVal.Name = "AutoGenerateMap"
    autoMapVal.Value = true -- Default aktif untuk sensasi "Paket Lengkap Instan"
    autoMapVal.Parent = configFolder
end

local defaultThemeVal = configFolder:FindFirstChild("DefaultMapTheme")
if not defaultThemeVal then
    defaultThemeVal = Instance.new("StringValue")
    defaultThemeVal.Name = "DefaultMapTheme"
    defaultThemeVal.Value = "tropical"
    defaultThemeVal.Parent = configFolder
end

-- RemoteEvent untuk sinkronisasi efek visual, audio, dan UI ke semua Client
local interactiveEvent = ReplicatedStorage:FindFirstChild("TikTokInteractiveEvent")
if not interactiveEvent then
    interactiveEvent = Instance.new("RemoteEvent")
    interactiveEvent.Name = "TikTokInteractiveEvent"
    interactiveEvent.Parent = ReplicatedStorage
end

-- RemoteEvent khusus untuk komunikasi dua arah dengan In-Game Admin Control GUI
local adminEvent = ReplicatedStorage:FindFirstChild("TikTokAdminEvent")
if not adminEvent then
    adminEvent = Instance.new("RemoteEvent")
    adminEvent.Name = "TikTokAdminEvent"
    adminEvent.Parent = ReplicatedStorage
end

-- RemoteFunction / Event backward-compatibility jika client lama memanggil 'interactiveEvent'
local legacyEvent = ReplicatedStorage:FindFirstChild("interactiveEvent")
if not legacyEvent then
    legacyEvent = Instance.new("RemoteEvent")
    legacyEvent.Name = "interactiveEvent"
    legacyEvent.Parent = ReplicatedStorage
end

-- ============================================================================
-- DAFTAR MAPPING GIFT DINAMIS (CUSTOM GIFT MAPPING)
-- Dapat diubah secara live kapan saja dari In-Game GUI tanpa restart Studio!
-- ============================================================================
local giftActionMap = {
    ["rose"] = "spawn_floor",
    ["mawar"] = "spawn_floor",
    ["donut"] = "hazard_tsunami",
    ["donat"] = "hazard_tsunami",
    ["ice cream"] = "speed_boost",
    ["cap"] = "super_jump",
    ["heart"] = "like_effect",
    ["galaxy"] = "low_gravity",
    ["dragon"] = "meteor_rain",
    ["whale"] = "hazard_tsunami",
    ["gg"] = "reset_floors",
}


-- ============================================================================
-- FOLDER & STATE WORKSPACE UNTUK SPAWN INTERAKTIF
-- ============================================================================
local interactiveFolder = workspace:FindFirstChild("TikTokInteractive")
if not interactiveFolder then
    interactiveFolder = Instance.new("Folder")
    interactiveFolder.Name = "TikTokInteractive"
    interactiveFolder.Parent = workspace
end

local floorFolder = interactiveFolder:FindFirstChild("SpawnedFloors")
if not floorFolder then
    floorFolder = Instance.new("Folder")
    floorFolder.Name = "SpawnedFloors"
    floorFolder.Parent = interactiveFolder
end

local hazardFolder = interactiveFolder:FindFirstChild("Hazards")
if not hazardFolder then
    hazardFolder = Instance.new("Folder")
    hazardFolder.Name = "Hazards"
    hazardFolder.Parent = interactiveFolder
end

-- Counter dan posisi awal balok lantai
local floorCount = 0
local INITIAL_FLOOR_POSITION = Vector3.new(0, 5, 0)
local FLOOR_SIZE = Vector3.new(6, 1.2, 6)

-- Palet warna neon estetik untuk lantai yang di-spawn
local NEON_PALETTE = {
    Color3.fromRGB(255, 75, 120),  -- Rose Pink
    Color3.fromRGB(0, 225, 255),   -- Cyan Neon
    Color3.fromRGB(255, 215, 0),   -- Golden Yellow
    Color3.fromRGB(170, 0, 255),   -- Electric Purple
    Color3.fromRGB(0, 255, 136),   -- Mint Green
    Color3.fromRGB(255, 110, 0)    -- Vibrant Orange
}

-- ============================================================================
-- FUNGSI LOGIKA GAME INTERAKTIF
-- ============================================================================

--[[
    1. SPAWN BALOK LANTAI BARU (Dipicu oleh: Gift Rose / Mawar)
    Membuat balok baru yang tersusun membentuk jembatan spiral / platform melayang.
    Menampilkan BillboardGui bertuliskan nama penonton yang mengirim gift.
]]
local function spawnFloorBlock(eventData)
    floorCount = floorCount + 1
    local username = eventData.user or "Penonton"
    local repeatCount = eventData.repeatCount or 1

    -- Kalkulasi posisi balok lantai berjenjang (pola spiral tangga/platform)
    local angle = (floorCount * 35) * (math.pi / 180)
    local radius = 8 + (floorCount * 0.4)
    local offsetX = math.cos(angle) * radius
    local offsetZ = math.sin(angle) * radius
    local offsetY = (floorCount * 1.5)
    local targetPos = INITIAL_FLOOR_POSITION + Vector3.new(offsetX, offsetY, offsetZ)

    -- Buat balok part
    local block = Instance.new("Part")
    block.Name = "FloorBlock_" .. floorCount
    block.Size = FLOOR_SIZE
    block.Anchored = true
    block.Material = Enum.Material.Neon
    block.Color = NEON_PALETTE[(floorCount % #NEON_PALETTE) + 1]
    
    -- Mulai dari transparan dan skala kecil untuk animasi kemunculan halus (Tween)
    block.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
    block.Transparency = 1
    block.Parent = floorFolder

    -- Billboard UI di atas balok penanda nama pengirim gift
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "UserTag"
    billboard.Size = UDim2.new(0, 180, 0, 45)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = block

    local tagLabel = Instance.new("TextLabel")
    tagLabel.Size = UDim2.new(1, 0, 1, 0)
    tagLabel.BackgroundTransparency = 0.3
    tagLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    tagLabel.Font = Enum.Font.GothamBold
    tagLabel.TextSize = 13
    tagLabel.Text = string.format("🌹 %s (+%d)", username, repeatCount)
    tagLabel.TextScaled = false
    tagLabel.Parent = billboard

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = tagLabel

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = block.Color
    uiStroke.Thickness = 1.5
    uiStroke.Parent = tagLabel

    -- Partikel efek percikan saat blok muncul
    local attachment = Instance.new("Attachment")
    attachment.Parent = block

    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxassetid://6071575925" -- Star / Sparkle
    sparks.Color = ColorSequence.new(block.Color)
    sparks.Size = NumberSequence.new(0.6, 0.1)
    sparks.Lifetime = NumberRange.new(0.6, 1.2)
    sparks.Rate = 25
    sparks.Speed = NumberRange.new(5, 10)
    sparks.Parent = attachment

    -- Suara kemunculan
    local popSound = Instance.new("Sound")
    popSound.SoundId = "rbxassetid://9114223170" -- Soft Pop Sound
    popSound.Volume = 0.6
    popSound.Parent = block
    popSound:Play()

    -- Animasi turun halus (Tween)
    local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
    local tween = TweenService:Create(block, tweenInfo, {
        CFrame = CFrame.new(targetPos),
        Transparency = 0.1
    })
    tween:Play()

    -- Hentikan partikel setelah beberapa detik
    task.delay(1.5, function()
        if sparks and sparks.Parent then
            sparks.Enabled = false
        end
    end)

    print(string.format("[TIKTOK EVENT] Lantai #%d di-spawn oleh @%s (Gift: %s)", floorCount, username, eventData.giftName or "Rose"))

    -- Kirim notifikasi ke semua client untuk UI banner
    interactiveEvent:FireAllClients("Notification", {
        title = "🌹 GIFT MAWAR!",
        message = string.format("@%s menambahkan balok lantai #%d!", username, floorCount),
        color = Color3.fromRGB(255, 75, 120)
    })
end

--[[
    ============================================================================
    HELPER: MEMBUAT MODEL GELOMBANG TSUNAMI AIR REALISTIS (3D CURVED WATER WAVE)
    ============================================================================
    Bukan berbentuk dinding kotak datar! Gelombang ini dibangun dengan struktur 3D
    menyerupai gulungan ombak laut raksasa asli:
    1. Base Swell (Volume air laut dalam yang bergelombang di dasar).
    2. Sloped Wave Ramp (Kemiringan lereng air laut yang naik tinggi menjulang).
    3. Curled Crest Lip (Puncak ombak silindris yang melengkung menggulung ke depan).
    4. White Frothy Sea Foam (Buih putih ombak laut di puncak bibir ombak).
    5. Emitter Partikel Semprotan Kabut & Percikan Air Laut (Mist, Spray, Splash).
    6. Material Glass berkilau (Refraction, Glossy Water Reflectance, Deep Oceanic Colors).
]]
local function createRealisticTsunamiModel(originCFrame, travelDirection, waveWidth, waveHeight, waveDepth)
    local waveModel = Instance.new("Model")
    waveModel.Name = "RealisticTsunamiWave"
    waveModel.Parent = hazardFolder

    -- 1. ROOT PART (Anchor Utama untuk Tweening Halus)
    local rootPart = Instance.new("Part")
    rootPart.Name = "RootPart"
    rootPart.Size = Vector3.new(waveWidth, waveHeight, waveDepth)
    rootPart.CFrame = originCFrame
    rootPart.Transparency = 1
    rootPart.CanCollide = false
    rootPart.Anchored = true
    rootPart.Parent = waveModel
    waveModel.PrimaryPart = rootPart

    local function weldToRoot(part)
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = rootPart
        weld.Part1 = part
        weld.Parent = rootPart
    end

    -- 2. BASE WATER SWELL (Volume air dasar yang menggelegak di bawah)
    local waveBase = Instance.new("Part")
    waveBase.Name = "WaveBase"
    waveBase.Size = Vector3.new(waveWidth, waveHeight * 0.45, waveDepth * 0.9)
    waveBase.CFrame = rootPart.CFrame * CFrame.new(0, -waveHeight * 0.25, 0)
    waveBase.Material = Enum.Material.Glass
    waveBase.Color = Color3.fromRGB(12, 90, 175) -- Deep Ocean Blue
    waveBase.Transparency = 0.22
    waveBase.Reflectance = 0.38
    waveBase.CanCollide = false
    waveBase.Anchored = false
    waveBase.Parent = waveModel
    weldToRoot(waveBase)

    -- 3. SLOPED WAVE RAMP / FACE (Lereng air yang naik menjulang tinggi ke atas)
    local waveFace = Instance.new("WedgePart")
    waveFace.Name = "WaveFace"
    waveFace.Size = Vector3.new(waveWidth, waveHeight * 0.85, waveDepth * 0.65)
    -- Orientasikan lereng menghadap arah sapuan
    waveFace.CFrame = rootPart.CFrame * CFrame.new(0, waveHeight * 0.05, waveDepth * 0.1) * CFrame.Angles(0, math.pi, 0)
    waveFace.Material = Enum.Material.Glass
    waveFace.Color = Color3.fromRGB(18, 140, 225) -- Radiant Turquoise Ocean
    waveFace.Transparency = 0.20
    waveFace.Reflectance = 0.45
    waveFace.CanCollide = false
    waveFace.Anchored = false
    waveFace.Parent = waveModel
    weldToRoot(waveFace)

    -- 4. CURLED CREST LIP (Puncak ombak melengkung silindris yang menggulung ke depan)
    local waveCrest = Instance.new("Part")
    waveCrest.Name = "WaveCrestCurl"
    waveCrest.Shape = Enum.PartType.Cylinder
    -- Pada silinder Roblox, Size.X adalah panjang silinder (lebar ombak)
    waveCrest.Size = Vector3.new(waveDepth * 0.35, waveWidth, waveDepth * 0.35)
    waveCrest.CFrame = rootPart.CFrame * CFrame.new(0, waveHeight * 0.42, -waveDepth * 0.28) * CFrame.Angles(0, 0, math.rad(90))
    waveCrest.Material = Enum.Material.Glass
    waveCrest.Color = Color3.fromRGB(45, 185, 245) -- Crystal Blue Wave Crest
    waveCrest.Transparency = 0.18
    waveCrest.Reflectance = 0.52
    waveCrest.CanCollide = false
    waveCrest.Anchored = false
    waveCrest.Parent = waveModel
    weldToRoot(waveCrest)

    -- 5. WHITE FROTHY SEA FOAM (Buih putih ombak laut di sepanjang bibir puncak ombak)
    local foamLip = Instance.new("Part")
    foamLip.Name = "FoamLip"
    foamLip.Size = Vector3.new(waveWidth, 3.2, waveDepth * 0.22)
    foamLip.CFrame = rootPart.CFrame * CFrame.new(0, waveHeight * 0.46, -waveDepth * 0.35)
    foamLip.Material = Enum.Material.SmoothPlastic
    foamLip.Color = Color3.fromRGB(245, 252, 255) -- White Ocean Foam
    foamLip.Transparency = 0.12
    foamLip.CanCollide = false
    foamLip.Anchored = false
    foamLip.Parent = waveModel
    weldToRoot(foamLip)

    -- 6. PARTIKEL REALISTIS: SEMPROTAN KABUT AIR (SEA SPRAY) & PERCIKAN BUIH (FOAM SPLASH)
    local crestAttachment = Instance.new("Attachment")
    crestAttachment.Name = "CrestEmitterAttachment"
    crestAttachment.CFrame = CFrame.new(0, 0, 0)
    crestAttachment.Parent = foamLip

    -- Semburan kabut air laut dari puncak ombak
    local sprayEmitter = Instance.new("ParticleEmitter")
    sprayEmitter.Name = "SeaSpray"
    sprayEmitter.Texture = "rbxassetid://241594419" -- Soft mist / water spray
    sprayEmitter.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
    sprayEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 2.0),
        NumberSequenceKeypoint.new(0.5, 5.0),
        NumberSequenceKeypoint.new(1, 8.5)
    })
    sprayEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.6, 0.55),
        NumberSequenceKeypoint.new(1, 1.0)
    })
    sprayEmitter.Lifetime = NumberRange.new(1.2, 2.0)
    sprayEmitter.Rate = 95
    sprayEmitter.Speed = NumberRange.new(14, 28)
    sprayEmitter.SpreadAngle = Vector2.new(45, 30)
    sprayEmitter.EmissionDirection = Enum.NormalId.Front
    sprayEmitter.Parent = crestAttachment

    -- Percikan buih dan tetesan air laut yang terbang
    local bubbleEmitter = Instance.new("ParticleEmitter")
    bubbleEmitter.Name = "WaterDroplets"
    bubbleEmitter.Texture = "rbxassetid://6071575925" -- Droplets / sparkle
    bubbleEmitter.Color = ColorSequence.new(Color3.fromRGB(215, 242, 255))
    bubbleEmitter.Size = NumberSequence.new(0.9, 0.2)
    bubbleEmitter.Lifetime = NumberRange.new(0.8, 1.5)
    bubbleEmitter.Rate = 60
    bubbleEmitter.Speed = NumberRange.new(16, 32)
    bubbleEmitter.SpreadAngle = Vector2.new(60, 60)
    sprayEmitter.EmissionDirection = Enum.NormalId.Front
    bubbleEmitter.Parent = crestAttachment

    -- Kabut dasar (Base Sea Mist)
    local baseAttachment = Instance.new("Attachment")
    baseAttachment.Name = "BaseEmitterAttachment"
    baseAttachment.CFrame = CFrame.new(0, -waveHeight * 0.2, -waveDepth * 0.4)
    baseAttachment.Parent = waveBase

    local baseMist = Instance.new("ParticleEmitter")
    baseMist.Name = "BaseOceanMist"
    baseMist.Texture = "rbxassetid://241594419"
    baseMist.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
    baseMist.Size = NumberSequence.new(4, 9)
    baseMist.Transparency = NumberSequence.new(0.4, 1.0)
    baseMist.Lifetime = NumberRange.new(1.0, 1.8)
    baseMist.Rate = 45
    baseMist.Speed = NumberRange.new(8, 18)
    baseMist.EmissionDirection = Enum.NormalId.Front
    baseMist.Parent = baseAttachment

    -- 7. PENCAHAYAAN AMBIENT AIR LAUT (Soft Cyan Glow)
    local oceanLight = Instance.new("PointLight")
    oceanLight.Color = Color3.fromRGB(110, 210, 255)
    oceanLight.Range = 70
    oceanLight.Brightness = 2.5
    oceanLight.Parent = waveBase

    -- 8. SUARA GEMURUH DEBURAN OMBAK BESAR (Ocean Surf Roar)
    local oceanSound = Instance.new("Sound")
    oceanSound.Name = "TsunamiRoar"
    oceanSound.SoundId = "rbxassetid://9114221580" -- Water / Rumble Rush
    oceanSound.Volume = 1.8
    oceanSound.RollOffMaxDistance = 350
    oceanSound.Looped = true
    oceanSound.Parent = rootPart
    oceanSound:Play()

    return waveModel, rootPart, { sprayEmitter, bubbleEmitter, baseMist }
end

--[[
    2. PANGGIL HAZARD TSUNAMI (Dipicu oleh: Gift Donut / Donat)
    Membuat gelombang tsunami air bergelombang tinggi 3D yang megah dan realistis
    lengkap dengan lengkungan ombak, buih putih, semprotan kabut, dan suara gemuruh air laut.
]]
local function spawnHazardTsunami(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] 🌊 BAHAYA GELOMBANG TSUNAMI AIR DIPANGGIL OLEH @%s!", username))

    -- Notifikasi peringatan ke semua client & aktifkan efek visual getar kamera + splash di layar
    interactiveEvent:FireAllClients("TsunamiAlert", {
        title = "🌊 PERINGATAN TSUNAMI LAUT!",
        message = string.format("Penonton @%s memanggil Gelombang Tsunami Air Raksasa! Cari tempat tinggi!", username),
        duration = 8
    })

    -- Dimensi gelombang air laut realistis
    local WAVE_WIDTH = 140     -- Lebar bentangan gelombang (menyapu seluruh arena)
    local WAVE_HEIGHT = 42     -- Tinggi menjulang ombak air laut (42 studs!)
    local WAVE_DEPTH = 36      -- Ketebalan gulungan air dari depan ke belakang
    local SWEEP_DURATION = 8.5 -- Durasi gerakan menyapu arena dalam detik

    -- Hitung koordinat lintasan ombak
    local arenaOrigin = INITIAL_FLOOR_POSITION
    local startPos = arenaOrigin + Vector3.new(-90, 8, 0)
    local endPos = arenaOrigin + Vector3.new(90, 8, 0)
    local travelVector = (endPos - startPos)
    local travelDirection = travelVector.Unit

    -- Rotasikan ombak menghadap arah pergerakan
    local startCFrame = CFrame.lookAt(startPos, startPos + travelDirection)
    local endCFrame = CFrame.lookAt(endPos, endPos + travelDirection)

    -- Buat model gelombang air 3D realistis
    local waveModel, rootPart, emitters = createRealisticTsunamiModel(
        startCFrame,
        travelDirection,
        WAVE_WIDTH,
        WAVE_HEIGHT,
        WAVE_DEPTH
    )

    -- Deteksi sentuhan pemain dengan gelombang ombak tsunami (Fisika Angkat & Hempas Air)
    local hitDebounce = {}
    local touchConn
    touchConn = rootPart.Touched:Connect(function(hit)
        local character = hit.Parent
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local hrp = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and hrp and not hitDebounce[character] then
            hitDebounce[character] = true

            -- Terangkat ke atas terbawa gulungan ombak dan terlempar ke depan (Realistic Buoyancy & Surge)
            local launchVelocity = (travelDirection * 85) + Vector3.new(0, 48, 0)
            hrp.AssemblyLinearVelocity = launchVelocity

            -- Damage hantaman arus air
            humanoid:TakeDamage(30)

            -- Efek percikan air di tubuh karakter
            local splash = Instance.new("ParticleEmitter")
            splash.Name = "PlayerWaterSplash"
            splash.Texture = "rbxassetid://241594419"
            splash.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255))
            splash.Size = NumberSequence.new(2.5, 0.3)
            splash.Rate = 50
            splash.Speed = NumberRange.new(12, 22)
            splash.Parent = hrp

            local splashSound = Instance.new("Sound")
            splashSound.SoundId = "rbxassetid://138084889" -- Water Splash Impact
            splashSound.Volume = 0.9
            splashSound.Parent = hrp
            splashSound:Play()

            task.delay(1.0, function()
                splash.Enabled = false
                Debris:AddItem(splash, 2)
                Debris:AddItem(splashSound, 2)
            end)

            task.delay(1.5, function()
                hitDebounce[character] = nil
            end)
        end
    end)

    -- Animasi sapuan ombak melintasi arena (TweenService)
    local tweenInfo = TweenInfo.new(SWEEP_DURATION, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(rootPart, tweenInfo, {
        CFrame = endCFrame
    })
    tween:Play()

    -- Pembersihan setelah gelombang selesai menyapu arena
    tween.Completed:Connect(function()
        if touchConn then touchConn:Disconnect() end

        -- Matikan emitter partikel agar perlahan menghilang
        for _, em in ipairs(emitters) do
            if em and em.Parent then em.Enabled = false end
        end

        -- Fade out halus seluruh bagian air
        local partsToFade = {}
        for _, obj in ipairs(waveModel:GetDescendants()) do
            if obj:IsA("BasePart") and obj ~= rootPart then
                table.insert(partsToFade, obj)
            end
        end

        local fadeTweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, p in ipairs(partsToFade) do
            TweenService:Create(p, fadeTweenInfo, { Transparency = 1 }):Play()
        end

        task.delay(1.4, function()
            waveModel:Destroy()
        end)
    end)
end

--[[
    3. PENANGANAN EVENT LIKE
    Memancarkan partikel cinta/hati pada seluruh pemain dan memberi lompatan tambahan.
]]
local function handleLike(eventData)
    local count = eventData.likeCount or 1
    local username = eventData.user or "Penonton"

    print(string.format("[TIKTOK EVENT] ❤️ Like diterima (+%d) dari @%s", count, username))

    -- Berikan efek partikel pada semua karakter pemain
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if hrp then
            local heartEmitter = Instance.new("ParticleEmitter")
            heartEmitter.Name = "LikeHeartParticles"
            heartEmitter.Texture = "rbxassetid://258128463" -- Heart decal / particle
            heartEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 60, 110))
            heartEmitter.Size = NumberSequence.new(1.2, 0.3)
            heartEmitter.Lifetime = NumberRange.new(1.0, 1.8)
            heartEmitter.Rate = 20
            heartEmitter.Speed = NumberRange.new(6, 12)
            heartEmitter.SpreadAngle = Vector2.new(45, 45)
            heartEmitter.Parent = hrp

            -- Beri buff lompat kecil selama 3 detik
            if humanoid then
                local originalJump = humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight
                if humanoid.UseJumpPower then
                    humanoid.JumpPower = originalJump * 1.3
                else
                    humanoid.JumpHeight = originalJump * 1.3
                end

                task.delay(3, function()
                    if humanoid and humanoid.Parent then
                        if humanoid.UseJumpPower then
                            humanoid.JumpPower = originalJump
                        else
                            humanoid.JumpHeight = originalJump
                        end
                    end
                end)
            end

            -- Matikan emisi setelah 1.5 detik
            task.delay(1.5, function()
                if heartEmitter and heartEmitter.Parent then
                    heartEmitter.Enabled = false
                    Debris:AddItem(heartEmitter, 2)
                end
            end)
        end
    end

    interactiveEvent:FireAllClients("LikeEffect", {
        user = username,
        likeCount = count
    })
end

--[[
    4. PENANGANAN EVENT CHAT / KOMENTAR
]]
local function handleChat(eventData)
    local username = eventData.user or "Penonton"
    local comment = eventData.comment or ""

    print(string.format("[TIKTOK CHAT] @%s: %s", username, comment))

    interactiveEvent:FireAllClients("ChatMessage", {
        user = username,
        comment = comment
    })
end

--[[
    5. PENANGANAN EVENT FOLLOW
]]
local function handleFollow(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] ⭐ @%s telah mengikuti live stream!", username))

    interactiveEvent:FireAllClients("Notification", {
        title = "⭐ FOLLOWER BARU!",
        message = string.format("Terima kasih @%s telah follow!", username),
        color = Color3.fromRGB(255, 215, 0)
    })
end

--[[
    6. AKSI INTERAKTIF: SPEED BOOST (Semua Pemain Berlari Cepat)
]]
local function applySpeedBoost(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] ⚡ SPEED BOOST DIAKTIFKAN OLEH @%s!", username))

    interactiveEvent:FireAllClients("Notification", {
        title = "⚡ SPEED BOOST 2X!",
        message = string.format("Penonton @%s memberikan dorongan lari cepat kilat!", username),
        color = Color3.fromRGB(0, 230, 255)
    })

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local oldSpeed = humanoid.WalkSpeed
            humanoid.WalkSpeed = oldSpeed * 2.0
            task.delay(8.0, function()
                if humanoid and humanoid.Parent then
                    humanoid.WalkSpeed = oldSpeed
                end
            end)
        end
    end
end

--[[
    7. AKSI INTERAKTIF: SUPER JUMP (Semua Pemain Melompat Super Tinggi)
]]
local function applySuperJump(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] 🚀 SUPER JUMP DIAKTIFKAN OLEH @%s!", username))

    interactiveEvent:FireAllClients("Notification", {
        title = "🚀 SUPER JUMP 2X!",
        message = string.format("Penonton @%s memberikan kekuatan lompatan roket!", username),
        color = Color3.fromRGB(255, 170, 0)
    })

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local origPower = humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight
            if humanoid.UseJumpPower then
                humanoid.JumpPower = origPower * 2.2
            else
                humanoid.JumpHeight = origPower * 2.2
            end

            task.delay(8.0, function()
                if humanoid and humanoid.Parent then
                    if humanoid.UseJumpPower then
                        humanoid.JumpPower = origPower
                    else
                        humanoid.JumpHeight = origPower
                    end
                end
            end)
        end
    end
end

--[[
    8. AKSI INTERAKTIF: GRAVITASI RENDAH (Moon Gravity)
]]
local function applyLowGravity(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] 🌙 GRAVITASI BULAN DIAKTIFKAN OLEH @%s!", username))

    interactiveEvent:FireAllClients("Notification", {
        title = "🌙 GRAVITASI BULAN!",
        message = string.format("Penonton @%s mengubah arena menjadi gravitasi luar angkasa!", username),
        color = Color3.fromRGB(180, 100, 255)
    })

    local oldGravity = workspace.Gravity
    workspace.Gravity = 45

    task.delay(8.0, function()
        workspace.Gravity = oldGravity
    end)
end

--[[
    9. AKSI INTERAKTIF: HUJAN METEOR API (Meteor Hazard)
]]
local function spawnMeteorRain(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] ☄️ HUJAN METEOR DITURUNKAN OLEH @%s!", username))

    interactiveEvent:FireAllClients("Notification", {
        title = "☄️ BAHAYA HUJAN METEOR!",
        message = string.format("Penonton @%s menjatuhkan meteor api ke arena!", username),
        color = Color3.fromRGB(255, 60, 40)
    })

    local meteorCount = 10
    local center = INITIAL_FLOOR_POSITION

    for i = 1, meteorCount do
        task.delay((i - 1) * 0.4, function()
            local offsetX = math.random(-45, 45)
            local offsetZ = math.random(-45, 45)
            local targetPos = center + Vector3.new(offsetX, 0, offsetZ)
            local spawnPos = targetPos + Vector3.new(math.random(-15, 15), 80, math.random(-15, 15))

            local meteor = Instance.new("Part")
            meteor.Name = "Meteor_" .. i
            meteor.Shape = Enum.PartType.Ball
            meteor.Size = Vector3.new(6, 6, 6)
            meteor.Color = Color3.fromRGB(255, 80, 20)
            meteor.Material = Enum.Material.Neon
            meteor.CFrame = CFrame.new(spawnPos)
            meteor.Anchored = true
            meteor.CanCollide = false
            meteor.Parent = hazardFolder

            local fire = Instance.new("Fire")
            fire.Size = 10
            fire.Heat = 20
            fire.Parent = meteor

            local fallTween = TweenService:Create(meteor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = CFrame.new(targetPos)
            })
            fallTween:Play()

            fallTween.Completed:Connect(function()
                -- Ledakan saat menyentuh lantai
                local explosion = Instance.new("Explosion")
                explosion.Position = targetPos
                explosion.BlastRadius = 14
                explosion.BlastPressure = 150000
                explosion.Parent = hazardFolder

                meteor:Destroy()
            end)
        end)
    end
end

--[[
    10. AKSI INTERAKTIF: RESET LANTAI ARENA
]]
local function resetFloors(eventData)
    local username = eventData.user or "Penonton"
    print(string.format("[TIKTOK EVENT] 🧹 ARENA DI-RESET OLEH @%s!", username))

    interactiveEvent:FireAllClients("Notification", {
        title = "🧹 BERSIHKAN LANTAI!",
        message = string.format("Penonton @%s membersihkan seluruh balok arena!", username),
        color = Color3.fromRGB(255, 230, 100)
    })

    for _, blk in ipairs(floorFolder:GetChildren()) do
        if blk:IsA("BasePart") then
            TweenService:Create(blk, TweenInfo.new(0.6), { Transparency = 1 }):Play()
            task.delay(0.65, function() blk:Destroy() end)
        end
    end
    floorCount = 0
end

-- ============================================================================
-- EKSEKUTOR AKSI UTAMA (ACTION DISPATCHER)
-- ============================================================================
local function executeAction(actionKey, eventData)
    if actionKey == "spawn_floor" then
        spawnFloorBlock(eventData)
    elseif actionKey == "hazard_tsunami" then
        spawnHazardTsunami(eventData)
    elseif actionKey == "speed_boost" then
        applySpeedBoost(eventData)
    elseif actionKey == "super_jump" then
        applySuperJump(eventData)
    elseif actionKey == "low_gravity" then
        applyLowGravity(eventData)
    elseif actionKey == "meteor_rain" then
        spawnMeteorRain(eventData)
    elseif actionKey == "reset_floors" then
        resetFloors(eventData)
    elseif actionKey == "like_effect" then
        handleLike(eventData)
    else
        -- Default fallback: spawn floor
        spawnFloorBlock(eventData)
    end
end

-- ============================================================================
-- EVENT ROUTER / DISPATCHER
-- ============================================================================
local function processSingleEvent(event)
    if not event or type(event) ~= "table" then return end
    local eventType = event.type

    -- Broadcast ke semua client untuk Live Event Feed di In-Game GUI
    interactiveEvent:FireAllClients("EventFeed", event)

    if eventType == "gift" then
        local rawName = tostring(event.giftName or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        -- Periksa mapping custom yang telah diatur user dari In-Game GUI
        local mappedAction = giftActionMap[rawName]

        if not mappedAction then
            -- Cek pencarian substring
            for giftPattern, act in pairs(giftActionMap) do
                if string.find(rawName, giftPattern) then
                    mappedAction = act
                    break
                end
            end
        end

        if mappedAction then
            executeAction(mappedAction, event)
        else
            -- Default jika gift belum dimapping: tambah balok lantai
            spawnFloorBlock(event)
        end
    elseif eventType == "like" then
        handleLike(event)
    elseif eventType == "chat" then
        handleChat(event)
    elseif eventType == "follow" then
        handleFollow(event)
    end
end

-- ============================================================================
-- MAIN POLLING LOOP (HttpService:GetAsync dengan pcall)
-- ============================================================================
local function startPollingLoop()
    task.spawn(function()
        print("----------------------------------------------------------------")
        print("🎮 [TIKTOK LIVE] Service polling dimulai di ServerScriptService...")
        print("----------------------------------------------------------------")

        local hasReportedHttpDisabled = false

        while true do
            task.wait(POLL_INTERVAL)

            local isListening = isListeningVal.Value
            local currentBackendUrl = serverUrlVal.Value
            if currentBackendUrl == "" then
                currentBackendUrl = DEFAULT_BACKEND_URL
            end

            if isListening then
                local endpointUrl = string.format("%s/get-events", currentBackendUrl)

                local success, response = pcall(function()
                    return HttpService:GetAsync(endpointUrl, true)
                end)

                if success then
                    hasReportedHttpDisabled = false
                    local decodeSuccess, data = pcall(function()
                        return HttpService:JSONDecode(response)
                    end)

                    if decodeSuccess and data and data.success then
                        local events = data.events or {}
                        if #events > 0 then
                            print(string.format("[TIKTOK LIVE] Mengambil %d event dari backend...", #events))
                            for _, ev in ipairs(events) do
                                task.spawn(processSingleEvent, ev)
                            end
                        end
                    end
                else
                    local errLower = tostring(response):lower()
                    if string.find(errLower, "http requests are not enabled") then
                        if not hasReportedHttpDisabled then
                            warn("❌ [TIKTOK LIVE] PERINGATAN KRUSIAL: 'Allow HTTP Requests' belum diaktifkan!")
                            warn("👉 Buka Roblox Studio: Home -> Game Settings -> Security -> Centang 'Allow HTTP Requests' -> Save.")
                            hasReportedHttpDisabled = true
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- KOMUNIKASI DUA ARAH DENGAN IN-GAME ADMIN CONTROL GUI
-- ============================================================================
adminEvent.OnServerEvent:Connect(function(player, command, payload)
    if command == "GetState" then
        -- Kirim state server saat ini ke client GUI yang meminta
        adminEvent:FireClient(player, "StateUpdate", {
            serverUrl = serverUrlVal.Value,
            username = usernameVal.Value,
            isListening = isListeningVal.Value,
            giftMap = giftActionMap
        })
    elseif command == "UpdateConfig" and type(payload) == "table" then
        if payload.serverUrl then serverUrlVal.Value = payload.serverUrl end
        if payload.username then usernameVal.Value = payload.username end
        if payload.isListening ~= nil then isListeningVal.Value = payload.isListening end

        -- Hubungkan / Putuskan koneksi di sisi Node.js backend
        task.spawn(function()
            local url = serverUrlVal.Value
            if isListeningVal.Value and usernameVal.Value ~= "" then
                local endpoint = string.format("%s/connect?username=%s", url, HttpService:UrlEncode(usernameVal.Value))
                pcall(function() HttpService:GetAsync(endpoint, true) end)
            elseif not isListeningVal.Value then
                pcall(function() HttpService:GetAsync(url .. "/disconnect", true) end)
            end
        end)

        -- Broadcast state baru ke semua player
        adminEvent:FireAllClients("StateUpdate", {
            serverUrl = serverUrlVal.Value,
            username = usernameVal.Value,
            isListening = isListeningVal.Value,
            giftMap = giftActionMap
        })
    elseif command == "SetGiftMapping" and type(payload) == "table" then
        local giftName = tostring(payload.giftName or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local actionKey = tostring(payload.actionKey or "spawn_floor")
        if giftName ~= "" then
            giftActionMap[giftName] = actionKey
            print(string.format("[ADMIN GUI] Mapping diperbarui: Gift '%s' -> Aksi '%s'", giftName, actionKey))
            adminEvent:FireAllClients("StateUpdate", {
                serverUrl = serverUrlVal.Value,
                username = usernameVal.Value,
                isListening = isListeningVal.Value,
                giftMap = giftActionMap
            })
        end
    elseif command == "RemoveGiftMapping" and type(payload) == "table" then
        local giftName = tostring(payload.giftName or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        giftActionMap[giftName] = nil
        print(string.format("[ADMIN GUI] Mapping dihapus: Gift '%s'", giftName))
        adminEvent:FireAllClients("StateUpdate", {
            serverUrl = serverUrlVal.Value,
            username = usernameVal.Value,
            isListening = isListeningVal.Value,
            giftMap = giftActionMap
        })
    elseif command == "TriggerAction" and type(payload) == "table" then
        local actionKey = payload.actionKey or "spawn_floor"
        print(string.format("[ADMIN GUI] Test Trigger aksi: '%s' oleh %s", actionKey, player.Name))
        executeAction(actionKey, {
            user = player.Name,
            giftName = "In-Game Test",
            repeatCount = 1
        })
    elseif command == "GenerateMap" and type(payload) == "table" then
        local theme = payload.theme or "tropical"
        print(string.format("[NOXORA STUDIO] Permintaan generate map tema '%s' dari %s", theme, player.Name))
        if MapGenerator then
            MapGenerator.Generate(theme)
            interactiveEvent:FireAllClients("Notification", {
                title = "🗺️ MAP BARU DIBUAT!",
                message = string.format("Tema '%s' aktif! Powered by NOXORA STUDIO", theme:upper()),
                color = Color3.fromRGB(0, 230, 255)
            })
        end
    elseif command == "ClearMap" then
        print(string.format("[NOXORA STUDIO] Permintaan reset map dari %s", player.Name))
        if MapGenerator then
            MapGenerator.Clear()
            interactiveEvent:FireAllClients("Notification", {
                title = "🧹 MAP DI-RESET!",
                message = "Map otomatis dibersihkan. Map kustom Anda tetap aman.",
                color = Color3.fromRGB(255, 200, 50)
            })
        end
    end
end)

-- Integrasi backward compatibility
legacyEvent.OnServerEvent:Connect(function(player, actionType, param)
    if actionType == "TambahLantai" or actionType == "Rose" then
        spawnFloorBlock({ user = player.Name, giftName = "Rose", repeatCount = 1 })
    elseif actionType == "Tsunami" or actionType == "Donut" then
        spawnHazardTsunami({ user = player.Name, giftName = "Donut" })
    elseif actionType == "Like" then
        handleLike({ user = player.Name, likeCount = 10 })
    end
end)

interactiveEvent.OnServerEvent:Connect(function(player, actionType, payload)
    if actionType == "Simulate" and type(payload) == "table" then
        processSingleEvent(payload)
    end
end)

-- Jalankan polling loop
startPollingLoop()

-- ============================================================================
-- AUTO-GENERATE STARTER MAP ON STARTUP (PAKET LENGKAP - NOXORA STUDIO)
-- ============================================================================
-- Memastikan pengguna langsung mendapatkan arena spektakuler siap pakai saat Play.
-- Jika pengguna sudah memiliki elemen map sendiri, mereka bisa me-reset kapan saja dari In-Game GUI.
task.defer(function()
    task.wait(0.5) -- Beri waktu service lain siap
    if autoMapVal.Value == true and MapGenerator then
        local existingMap = workspace:FindFirstChild("TikTokGeneratedMap")
        if not existingMap then
            print("================================================================")
            print("🏰 [NOXORA STUDIO] AUTO-GENERATING STARTER ARENA MAP...")
            print("🎨 Tema Terpilih : " .. defaultThemeVal.Value:upper())
            print("🛡️ Watermark     : NOXORA STUDIO OFFICIAL ENGINE")
            print("================================================================")
            MapGenerator.Generate(defaultThemeVal.Value)
        end
    end
end)
