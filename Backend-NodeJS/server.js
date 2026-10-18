/**
 * ============================================================================
 * TIKTOK LIVE TO ROBLOX STUDIO CONNECTOR - BACKEND SERVER (server.js)
 * ============================================================================
 * 
 * Server perantara langsung (Direct Bridge) yang menghubungkan TikTok Live Webcast
 * dengan Roblox Studio via REST API tanpa memerlukan Tikfinity / Indofinity.
 * 
 * Fitur Utama:
 * 1. Menghubungkan ke WebSocket TikTok Live menggunakan library 'tiktok-live-connector'.
 * 2. Menangkap event real-time: Gift, Like, Chat/Komentar, Follow, dan Share.
 * 3. Menyimpan data ke dalam antrean memori (eventQueue).
 * 4. Menyediakan endpoint GET '/get-events' untuk Roblox HttpService polling.
 * 5. Menyediakan endpoint dinamis untuk kontrol (/connect, /disconnect, /status, /simulate).
 * ============================================================================
 */

const express = require('express');
const cors = require('cors');

// Mendukung tiktok-live-connector versi 1.x dan 2.x
const TikTokModule = require('tiktok-live-connector');
let WebcastConnectionClass = TikTokModule.TikTokLiveConnection || TikTokModule.WebcastPushConnection;
if (!WebcastConnectionClass) {
    try {
        const legacy = require('tiktok-live-connector/legacy');
        WebcastConnectionClass = legacy.WebcastPushConnection;
    } catch (e) {}
}
if (!WebcastConnectionClass) {
    WebcastConnectionClass = TikTokModule.TikTokLiveConnection;
}


const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// State Global
let tiktokConnection = null;
let currentUsername = '';
let isConnected = false;
let currentRoomId = null;
let eventQueue = [];
let eventCounter = 0;

/**
 * Helper: Menambahkan event baru ke dalam antrean (FIFO)
 * @param {string} type - Jenis event ('gift', 'like', 'chat', 'follow', 'share')
 * @param {object} payload - Data detail dari event
 */
function pushToQueue(type, payload) {
    eventCounter++;
    const eventItem = {
        id: `evt_${Date.now()}_${eventCounter}`,
        type: type,
        timestamp: Date.now(),
        ...payload
    };

    eventQueue.push(eventItem);

    // Mencegah memori bocor jika game Roblox tidak mengambil data dalam waktu lama (maks 1000 antrean)
    if (eventQueue.length > 1000) {
        eventQueue.shift();
    }

    console.log(`[EVENT QUEUED] [${type.toUpperCase()}] ID: ${eventItem.id} | User: ${payload.user || 'Unknown'} | Queue Size: ${eventQueue.length}`);
}

/**
 * Menghubungkan ke TikTok Live Webcast
 * @param {string} username - Nama pengguna TikTok target (tanpa tanda @ atau dengan @)
 */
async function connectToTikTok(username, sessionId = null) {
    const cleanUsername = username.replace(/^@/, '').trim();
    if (!cleanUsername) {
        throw new Error('Username TikTok tidak valid.');
    }

    // Jika sudah ada koneksi aktif sebelumnya, putuskan terlebih dahulu
    if (tiktokConnection) {
        try {
            console.log(`[INFO] Memutuskan koneksi lama (@${currentUsername})...`);
            tiktokConnection.disconnect();
        } catch (err) {
            console.warn('[WARN] Gagal memutuskan koneksi lama:', err.message);
        }
        tiktokConnection = null;
        isConnected = false;
    }

    console.log(`[INFO] Memulai koneksi ke TikTok Live: @${cleanUsername}...`);

    const connectionOptions = {
        processInitialData: false,
        enableExtendedGiftInfo: true,
        enableWebsocketUpgrade: true,
        requestPollingIntervalMs: 1000,
        clientParams: {
            app_language: 'en-US',
            device_platform: 'web'
        }
    };

    // Opsional: Jika akun memerlukan autentikasi sesi (Cookie sessionid)
    if (sessionId && sessionId.trim() !== "") {
        connectionOptions.sessionId = sessionId.trim();
        console.log(`[INFO] Menggunakan Session ID untuk autentikasi.`);
    }

    tiktokConnection = new WebcastConnectionClass(cleanUsername, connectionOptions);

    // Pasang Event Listeners
    setupTikTokListeners(tiktokConnection);

    // Lakukan koneksi
    const state = await tiktokConnection.connect();
    isConnected = true;
    currentUsername = cleanUsername;
    currentRoomId = state.roomId;

    console.log(`[SUCCESS] Berhasil terhubung ke TikTok Live @${cleanUsername} (Room ID: ${currentRoomId})`);
    return { username: cleanUsername, roomId: currentRoomId };
}

/**
 * Mendaftarkan event listener pada instance WebcastPushConnection
 * @param {WebcastPushConnection} conn 
 */
function setupTikTokListeners(conn) {
    // 1. EVENT GIFT
    conn.on('gift', (data) => {
        // Pada gift berulang/streak, data.repeatEnd menandai akhir streak
        // data.repeatCount memberi jumlah gift yang dikirimkan
        pushToQueue('gift', {
            giftId: data.giftId,
            giftName: data.giftName,
            repeatCount: data.repeatCount || 1,
            repeatEnd: data.repeatEnd === true || data.repeatEnd === 1,
            diamondCount: data.diamondCount || 0,
            user: data.uniqueId,
            nickname: data.nickname,
            profilePictureUrl: data.profilePictureUrl || ''
        });
    });

    // 2. EVENT LIKE
    conn.on('like', (data) => {
        pushToQueue('like', {
            likeCount: data.likeCount || 1,
            totalLikeCount: data.totalLikeCount || 0,
            user: data.uniqueId,
            nickname: data.nickname
        });
    });

    // 3. EVENT CHAT / KOMENTAR
    conn.on('chat', (data) => {
        pushToQueue('chat', {
            comment: data.comment,
            user: data.uniqueId,
            nickname: data.nickname
        });
    });

    // 4. EVENT FOLLOW
    conn.on('follow', (data) => {
        pushToQueue('follow', {
            user: data.uniqueId,
            nickname: data.nickname
        });
    });

    // 5. EVENT SHARE
    conn.on('share', (data) => {
        pushToQueue('share', {
            user: data.uniqueId,
            nickname: data.nickname
        });
    });

    // Connection Events
    conn.on('disconnected', () => {
        console.warn(`[DISCONNECT] Terputus dari TikTok Live @${currentUsername}`);
        isConnected = false;
        currentRoomId = null;
    });

    conn.on('error', (err) => {
        console.error(`[ERROR TIKTOK]`, err);
    });
}

// ============================================================================
// REST API ENDPOINTS
// ============================================================================

/**
 * GET /get-events
 * Di-poll oleh Roblox Studio (HttpService:GetAsync) setiap detik.
 * Mengembalikan array antrean event dalam format JSON dan langsung mengosongkannya.
 */
app.get('/get-events', (req, res) => {
    // Salin event saat ini
    const eventsToSend = [...eventQueue];
    
    // Kosongkan antrean seketika setelah diambil
    eventQueue = [];

    res.json({
        success: true,
        count: eventsToSend.length,
        connected: isConnected,
        username: currentUsername,
        events: eventsToSend
    });
});

/**
 * GET /status
 * Melihat status koneksi server dan jumlah antrean saat ini
 */
app.get('/status', (req, res) => {
    res.json({
        success: true,
        connected: isConnected,
        username: currentUsername || null,
        roomId: currentRoomId || null,
        queueLength: eventQueue.length,
        totalEventsProcessed: eventCounter,
        uptime: process.uptime()
    });
});

/**
 * POST & GET /connect
 * Menginisialisasi koneksi ke TikTok Live untuk username yang ditentukan
 * Dapat dipanggil dari Browser, Roblox Studio Plugin, atau cURL
 */
const handleConnect = async (req, res) => {
    const username = req.body.username || req.query.username;
    const sessionId = req.body.sessionId || req.query.sessionId || req.query.sessionid || null;

    if (!username) {
        return res.status(400).json({
            success: false,
            message: 'Parameter "username" diperlukan.'
        });
    }

    try {
        const result = await connectToTikTok(username, sessionId);
        res.json({
            success: true,
            message: `Berhasil terhubung ke live stream @${result.username}`,
            data: result
        });
    } catch (err) {
        console.error(`[CONNECT ERROR]`, err.message);
        res.status(500).json({
            success: false,
            message: `Gagal terhubung ke TikTok Live: ${err.message}`
        });
    }
};
app.post('/connect', handleConnect);
app.get('/connect', handleConnect);

/**
 * POST & GET /disconnect
 * Memutuskan koneksi aktif dari TikTok Live
 */
const handleDisconnect = (req, res) => {
    if (tiktokConnection) {
        try {
            tiktokConnection.disconnect();
        } catch (err) {
            console.warn('[WARN]', err.message);
        }
        tiktokConnection = null;
        isConnected = false;
        const prevUser = currentUsername;
        currentUsername = '';
        currentRoomId = null;

        return res.json({
            success: true,
            message: `Koneksi dengan @${prevUser} telah diputuskan.`
        });
    }

    res.json({
        success: true,
        message: 'Tidak ada koneksi aktif yang sedang berjalan.'
    });
};
app.post('/disconnect', handleDisconnect);
app.get('/disconnect', handleDisconnect);

/**
 * POST & GET /simulate
 * Endpoint simulator untuk keperluan testing tanpa perlu live stream aktif atau menghabiskan koin sungguhan.
 * Contoh query: /simulate?type=gift&name=Rose&user=SultanRoblox
 */
const handleSimulate = (req, res) => {
    const type = req.body.type || req.query.type || 'gift';
    const user = req.body.user || req.query.user || 'ViewerSimulasi';
    const nickname = req.body.nickname || req.query.nickname || 'Simulasi User';

    let payload = { user, nickname };

    if (type === 'gift') {
        const giftName = req.body.giftName || req.query.name || req.body.name || 'Rose';
        const repeatCount = parseInt(req.body.repeatCount || req.query.count || 1);
        const diamondCount = parseInt(req.body.diamondCount || (giftName.toLowerCase() === 'donut' ? 30 : 1));

        payload = {
            ...payload,
            giftId: 5655,
            giftName: giftName,
            repeatCount: repeatCount,
            repeatEnd: true,
            diamondCount: diamondCount
        };
    } else if (type === 'like') {
        payload = {
            ...payload,
            likeCount: parseInt(req.body.likeCount || req.query.count || 15),
            totalLikeCount: 1000
        };
    } else if (type === 'chat') {
        payload = {
            ...payload,
            comment: req.body.comment || req.query.comment || 'Halo Roblox TikTok Live!'
        };
    } else if (type === 'follow') {
        // payload sudah ada user & nickname
    }

    pushToQueue(type, payload);

    res.json({
        success: true,
        message: `Event simulasi '${type}' berhasil dimasukkan ke antrean!`,
        event: payload,
        queueLength: eventQueue.length
    });
};
app.post('/simulate', handleSimulate);
app.get('/simulate', handleSimulate);

/**
 * Endpoint Utama / Root: Informasi status dan bantuan singkat
 */
app.get('/', (req, res) => {
    res.json({
        service: 'TikTok Live to Roblox Studio Direct Integration Server',
        status: isConnected ? 'CONNECTED' : 'STANDBY',
        username: currentUsername || 'None',
        queueLength: eventQueue.length,
        endpoints: {
            'GET /get-events': 'Mengambil antrean event dan mengosongkannya (di-poll oleh Roblox HttpService)',
            'GET /status': 'Cek status koneksi',
            'POST /connect?username=...': 'Koneksi ke TikTok Live',
            'POST /disconnect': 'Putus koneksi',
            'GET /simulate?type=gift&name=Rose': 'Simulasi event untuk testing'
        }
    });
});

// Menjalankan server
app.listen(PORT, () => {
    console.log('================================================================');
    console.log(`🚀 TIKTOK TO ROBLOX SERVER RUNNING ON: http://localhost:${PORT}`);
    console.log(`📡 GET Events Endpoint : http://localhost:${PORT}/get-events`);
    console.log(`🔗 Connect Endpoint    : http://localhost:${PORT}/connect?username=<user>`);
    console.log(`🎮 Simulator Endpoint  : http://localhost:${PORT}/simulate?type=gift&name=Rose`);
    console.log('----------------------------------------------------------------');
    console.log(`💡 TIPS KONEKSI ROBLOX:`);
    console.log(`1. ROBLOX STUDIO: Gunakan http://localhost:${PORT} (TIDAK BUTUH TUNNEL!)`);
    console.log(`2. ROBLOX CLIENT (Publik): Buka terminal baru dan ketik:`);
    console.log(`   👉 npm run tunnel         (Localtunnel - Gratis, Tanpa Daftar Akun)`);
    console.log(`   👉 npm run tunnel:pinggy  (Pinggy SSH - Tanpa Install Software Apapun)`);
    console.log('================================================================');
});
