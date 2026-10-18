# 🚀 Sistem Integrasi Langsung TikTok Live & Roblox Studio (Direct Integration)

Sistem integrasi real-time antara **TikTok Live Webcast** dan **Roblox Studio / Roblox Game Client** tanpa menggunakan layanan pihak ketiga berbayar (tanpa Tikfinity / Indofinity). Sistem ini memungkinkan siaran langsung TikTok mengontrol mekanika permainan Roblox secara interaktif (Gift, Like, Komentar, dan Follow).

Dilengkapi dengan **In-Game Admin Control GUI** sehingga streamer / pemain **TIDAK PERLU LAGI membuka Roblox Studio** saat mengoperasikan live streaming!

---

## 📁 Struktur Folder Proyek

```text
Live-Interaktif [RBX]/
├── Backend-NodeJS/
│   ├── node_modules/                     # Modul dependensi Node.js
│   ├── package.json                      # Konfigurasi dependensi project (express, cors, tiktok-live-connector)
│   ├── server.js                         # Server perantara (Express + tiktok-live-connector)
│   └── test-simulator.html               # Web Simulator visual (Testing gratis tanpa koin TikTok)
│
├── ServerScriptService/
│   └── TikTokLiveServer.server.lua       # Script Game Utama (Polling GetAsync, pcall, logika aksi interaktif & remote admin)
│
├── StarterGui/
│   └── TikTokInGameControlGui.client.lua # GUI KONTROL DI DALAM GAME (Custom Link, Custom Gift Mapper, Live Feed)
│
├── Plugin/
│   └── TikTokLivePlugin.server.lua       # Plugin Studio bawaan (DockWidgetPluginGui + UI Kontrol + Settings)
│
├── Client Script (Local Script - StarterPlayerScripts)/
│   └── client.lua                        # Script Client (Popup Notifikasi, Efek Kamera Tsunami, Shortcut Key 1, 2, 3)
│
└── README.md                             # Dokumentasi & Panduan Lengkap
```

---

## 🎮 Fitur Baru: In-Game Control Panel (Tanpa Buka Roblox Studio Lagi!)

Fitur ini dirancang khusus agar Anda dapat **mengontrol seluruh sistem langsung dari dalam game** (baik saat Play test di Studio maupun saat game sudah dipublikasikan dan dimainkan di Roblox Player biasa).

### Cara Membuka / Menutup In-Game GUI:
1. Klik tombol melayang di pojok kanan atas layar bertuliskan: **`[ 🎮 TikTok Live Control ]`** (Dilengkapi lampu indikator hijau/merah).
2. Atau tekan tombol shortcut keyboard: **`M`** atau **`F4`**.

---

### Tiga Tab Utama di Dalam In-Game GUI:

#### 1. 🌐 Tab Koneksi & URL (Custom Link)
* **Custom Link Backend**: Kolom input untuk memasukkan alamat URL server Node.js.
  * Default: `http://localhost:3000` (saat bermain di PC yang sama dengan server).
  * Cloud/Tunneling: Bisa diisi link **ngrok** (misal: `https://abcd-1234.ngrok-free.app`) atau IP VPS jika game dimainkan di Roblox Player publik.
* **Username TikTok Live**: Kolom input untuk memasukkan username streamer TikTok (tanpa tanda `@`).
* **Tombol Start Listening (Hijau)**: Langsung menghubungkan backend ke TikTok Live dan mengaktifkan polling di dalam game.
* **Tombol Stop Listening (Merah)**: Memutus koneksi stream dan menjeda polling.
* **Lampu Indikator Real-Time**: Bulatan hijau menyala saat `ONLINE` dan merah saat `OFFLINE`.

#### 2. 🎁 Tab Custom Gift Mapper (Atur Gift Suka-Suka)
Anda bebas menghubungkan gift TikTok apa pun ke aksi permainan apa pun tanpa perlu menyentuh atau mengubah script code:
* **Cara Menambah Mapping Baru**:
  1. Masukkan nama gift pada kolom teks (contoh: `Ice Cream`, `Cap`, `Whale`, `Dragon`, `Galaxy`, dll).
  2. Klik tombol **Pilih Aksi ▼** dan tentukan mekanika yang diinginkan:
     * `🌹 Tambah Balok Lantai (+1)` (`spawn_floor`)
     * `🌊 Tsunami Air Realistis 3D` (`hazard_tsunami`)
     * `⚡ Speed Boost 2x (8 Detik)` (`speed_boost`)
     * `🚀 Super Jump 2x (8 Detik)` (`super_jump`)
     * `🌙 Gravitasi Bulan (8 Detik)` (`low_gravity`)
     * `☄️ Hujan Meteor Api` (`meteor_rain`)
     * `🧹 Bersihkan Lantai Arena` (`reset_floors`)
     * `❤️ Efek Partikel Hati & Buff` (`like_effect`)
  3. Klik tombol biru **"➕ Simpan Mapping Gift"**.
* **Daftar Mapping Aktif**: Menampilkan semua gift yang sedang terpasang beserta tombol **`[ ✕ ]`** untuk menghapus mapping kapan saja secara instan.

#### 3. ⚡ Tab Uji Coba & Live Event Feed
* **Tombol Uji Coba Instan**: Tombol cepat untuk memicu aksi tanpa menunggu penonton mengirim gift (`Test Rose`, `Test Tsunami`, `Test Speed`, `Super Jump`, `Hujan Meteor`, `Reset Lantai`).
* **Live Event Feed Console**: Menampilkan log aktivitas real-time yang masuk dari live stream (Gift penonton, pesan chat komentar, like, dan follower baru).

---

## 🌊 Mekanika Unggulan: Hazard Tsunami Air Realistis 3D

Tsunami dalam sistem ini **BUKAN** berupa dinding tipis datar, melainkan gelombang ombak air laut 3D raksasa (*Curved High Water Wave*) setinggi **42 studs** dan selebar **140 studs**:
1. **Dasar Ombak Samudra (`Base Water Swell`)**: Material `Glass` semi-transparan berkilau dengan warna *Deep Ocean Blue*.
2. **Lereng Air Melengkung (`Sloped Wave Ramp`)**: Permukaan air bersudut yang menjulang tinggi dengan gradasi *Radiant Turquoise Aqua*.
3. **Puncak Ombak Menggulung (`Curled Crest Lip`)**: Gulungan ombak silindris di bagian paling atas (*barrel wave*).
4. **Buih Putih Ombak (`White Sea Foam`)**: Busa air laut putih di bibir puncak gelombang.
5. **Partikel Kabut Semburan Ombak (`Sea Spray & Water Droplets`)**: Kabut air yang bertiup ke depan dihempas angin badai.
6. **Efek Layar Pemain (`Screen Water Splash`)**: Cipratan air biru transparan yang membasahi layar pemain saat ombak menerjang, disertai getaran gemuruh kamera (*camera rumble shake*).
7. **Fisika Angkat & Hempas Arus**: Pemain yang terkena ombak akan terangkat ke atas mengikuti pusaran air dan terlempar kuat ke depan (*buoyancy & surge physics*).

---

## ❓ Apakah Pengguna Memerlukan TikTok Live API Key?

### Jawabannya: **TIDAK PERLU API KEY SAMA SEKALI!** 🚀

Banyak developer baru yang khawatir karena TikTok secara resmi **tidak menyediakan API Key publik** untuk siaran langsung (live webcast) kepada kreator biasa (API resmi hanya untuk perusahaan korporat besar).

### Bagaimana Sistem Ini Bisa Berjalan Tanpa API Key?
1. **Koneksi Webcast WebSocket Publik**:
   Pustaka `tiktok-live-connector` bekerja dengan cara menyambungkan socket client langsung ke server WebSocket publik TikTok (`webcast.tiktok.com`).
2. **Cukup Username Saja**:
   Anda hanya perlu memasukkan **Username TikTok** streamer (contoh: `khaby.lame`). Sistem akan secara otomatis mencari ID Room siaran langsung dan mendengarkan event yang masuk.
3. **Gratis 100%**:
   Tidak ada biaya langganan, tidak perlu mendaftar akun TikTok Developer, dan tidak ada limit koin.

---

### 💡 Solusi Jika Mengalami Kendala Tanpa API Key:

| Masalah yang Sering Muncul | Penyebab | Solusi Mudah |
| :--- | :--- | :--- |
| **Error: `LIVE has ended` / `Room not found`** | Akun TikTok belum memulai live broadcast saat tombol ditekan. | TikTok hanya membuka jalur WebSocket saat siaran langsung aktif di aplikasi TikTok. **Pastikan streamer sudah menekan "Go Live" di HP / PC**, baru kemudian klik *Start Listening*. |
| **Ingin tes game tapi belum mau Live di TikTok** | Tidak ada stream yang sedang berjalan. | Gunakan fitur **Simulator Bawaan**! Di In-Game GUI, buka **Tab 3: Uji Coba** atau buka file `test-simulator.html` di browser. Anda bisa memicu Rose, Tsunami, dan Like secara instan tanpa perlu streaming sungguhan. |
| **Verifikasi Keamanan / Akun Terproteksi (Khusus Akun Tertentu)** | TikTok meminta verifikasi sesi login untuk wilayah tertentu. | Salin cookie `sessionid` dari akun TikTok Anda di browser (Buka tiktok.com -> F12 -> Application -> Cookies -> `sessionid`), lalu masukkan saat memanggil endpoint `/connect?username=...&sessionId=...`. Sistem kami sudah mendukung parameter ini. |

---

## 🛠️ Panduan Langkah Demi Langkah (Step-by-Step)

### Langkah 1: Install Dependensi Node.js Backend
1. Pastikan komputer Anda sudah terinstall **Node.js** (versi 18 ke atas).
2. Buka Command Prompt / PowerShell di folder `Backend-NodeJS`:
   ```bash
   cd "f:\Project [RBX]\Plugins [RBX]\Live-Interaktif [RBX]\Backend-NodeJS"
   npm install
   ```
3. Dependensi yang terpasang otomatis:
   * `express`: Web server REST API.
   * `cors`: Menghindari blokir CORS browser.
   * `tiktok-live-connector`: WebSocket wrapper resmi untuk TikTok Webcast API.

---

### Langkah 2: Menjalankan Server Backend
Jalankan server Node.js:
```bash
npm start
```
Terminal akan menampilkan:
```text
================================================================
🚀 TIKTOK TO ROBLOX SERVER RUNNING ON: http://localhost:3000
📡 GET Events Endpoint : http://localhost:3000/get-events
🔗 Connect Endpoint    : http://localhost:3000/connect?username=<user>
🎮 Simulator Endpoint  : http://localhost:3000/simulate?type=gift&name=Rose
================================================================
```

---

### Langkah 3: Mengaktifkan HTTP Requests di Roblox Studio (Wajib)
Secara bawaan Roblox Studio memblokir koneksi jaringan eksternal. Anda wajib mengaktifkannya:
1. Buka Game Anda di **Roblox Studio**.
2. Klik tab **Home** -> pilih **Game Settings** *(Simpan game terlebih dahulu jika tombol belum aktif)*.
3. Masuk ke menu **Security** di sebelah kiri.
4. Aktifkan / centang toggle **"Allow HTTP Requests"**.
5. Klik **Save**.

---

### Langkah 4: Memasang Script Game di Roblox Studio
1. **Server Script**:
   * Di panel **Explorer**, klik kanan **ServerScriptService** -> **Insert Object** -> **Script**.
   * Beri nama `TikTokLiveServer`.
   * Salin seluruh isi dari [`ServerScriptService/TikTokLiveServer.server.lua`](file:///f:/Project%20[RBX]/Plugins%20[RBX]/Live-Interaktif%20[RBX]/ServerScriptService/TikTokLiveServer.server.lua) dan paste ke dalamnya.
2. **In-Game Control GUI (Baru)**:
   * Di panel **Explorer**, cari folder **StarterGui** -> **Insert Object** -> **LocalScript**.
   * Beri nama `TikTokInGameControlGui`.
   * Salin seluruh isi dari [`StarterGui/TikTokInGameControlGui.client.lua`](file:///f:/Project%20[RBX]/Plugins%20[RBX]/Live-Interaktif%20[RBX]/StarterGui/TikTokInGameControlGui.client.lua) dan paste ke dalamnya.
3. **Client Companion Script**:
   * Di panel **Explorer**, buka **StarterPlayer** -> **StarterPlayerScripts** -> **Insert Object** -> **LocalScript**.
   * Beri nama `TikTokLiveClient`.
   * Salin seluruh isi dari [`Client Script (Local Script - StarterPlayerScripts)/client.lua`](file:///f:/Project%20[RBX]/Plugins%20[RBX]/Live-Interaktif%20[RBX]/Client%20Script%20%28Local%20Script%20-%20StarterPlayerScripts%29/client.lua) dan paste ke dalamnya.

---

### Langkah 5: Cara Menghubungkan Game (Pilihan Metode Paling Mudah)

Banyak orang mengira wajib menggunakan Ngrok yang rumit. Sebenarnya **ada metode yang jauh lebih mudah dan tanpa perlu daftar akun sama sekali**:

---

#### 🌟 Pilihan A: Bermain di Roblox Studio (Paling Mudah - 100% TANPA TUNNEL!)
Jika Anda melakukan siaran langsung (live streaming) dengan bermain di **Roblox Studio (Tekan Play / F5)**:
* Anda **TIDAK BUTUH NGROK ATAU TUNNEL APAPUN!**
* Karena Roblox Studio berjalan langsung di komputer Anda, Roblox Studio dapat membaca `localhost` secara instan tanpa internet.
* **Cara**: Cukup gunakan URL bawaan: `http://localhost:3000` (atau klik tombol **`[ 💻 Set Localhost:3000 ]`** di In-Game GUI).

---

#### 🚀 Pilihan B: Localtunnel (Alternatif Ngrok Terbaik - 1 Perintah, Tanpa Daftar Akun!)
Jika Anda ingin bermain di aplikasi **Roblox Player biasa** (bukan Studio), gunakan **Localtunnel**.
* **Keunggulan**: **TIDAK PERLU DAFTAR AKUN**, tidak perlu download aplikasi apapun karena sudah otomatis ada di Node.js Anda!
* **Cara Menggunakan**:
  1. Buka terminal baru di folder `Backend-NodeJS`.
  2. Ketik perintah:
     ```bash
     npm run tunnel
     ```
     *(Atau: `npx localtunnel --port 3000`)*
  3. Terminal akan langsung menampilkan link publik gratis, contoh:
     ```text
     your url is: https://bright-pandas-sing.loca.lt
     ```
  4. Salin link tersebut dan paste ke kolom **URL Server Backend** di In-Game GUI atau Plugin Studio Anda! Selesai!

---

#### ⚡ Pilihan C: Pinggy SSH (Menggunakan Bawaan Windows - Tanpa Install Apapun!)
Windows 10 dan Windows 11 sudah memiliki fitur SSH bawaan di Command Prompt.
* **Keunggulan**: Tidak perlu install software tambahan, tidak perlu akun, langsung jadi dalam 2 detik.
* **Cara Menggunakan**:
  1. Buka Command Prompt / PowerShell baru.
  2. Ketik perintah:
     ```bash
     npm run tunnel:pinggy
     ```
     *(Atau langsung ketik: `ssh -p 443 -R0:localhost:3000 a.pinggy.io`)*
  3. Pinggy akan langsung memberikan link publik `https://xxxxx.a.pinggy.link`.
  4. Salin link HTTPS tersebut dan masukkan ke In-Game GUI di dalam game.

---

#### ☁️ Pilihan D: Cloudflare Tunnel (Sangat Cepat & Stabil)
Cloudflare menyediakan Quick Tunnel gratis tanpa perlu registrasi akun Cloudflare.
* **Cara Menggunakan**:
  ```bash
  npm run tunnel:cloudflare
  ```
  Terminal akan menampilkan link `https://xxxx.trycloudflare.com` yang sangat stabil dan bebas batasan kuota.

---

#### 🌐 Pilihan E: Deploy Gratis ke Cloud (Render.com / Railway - Permanen Tanpa Buka Terminal!)
Jika Anda tidak ingin menyalakan terminal atau komputer untuk server:
1. Buat akun gratis di [Render.com](https://render.com).
2. Buat **New Web Service** -> Hubungkan ke repository GitHub folder `Backend-NodeJS`.
3. Anda akan mendapatkan URL permanen gratis, contoh: `https://tiktok-roblox-live.onrender.com`.
4. Masukkan URL tersebut ke In-Game GUI. Server Anda akan aktif 24 jam nonstop di cloud!

---

## 🏰 Paket Lengkap: Auto Map Generator (Otomatis & Siap Pakai Langsung)

Sistem ini menghadirkan fitur **Auto Map Generator** bawaan (*Built-in Arena Generator*). Saat Anda memasang Plugin dan menjalankan script, Anda tidak perlu lagi repot membuat map dari nol. Sistem secara cerdas akan langsung men-generate arena berkualitas tinggi lengkap dengan lighting sinematik, sehingga pengguna langsung merasakan:
> **"Wow, ini benar-benar paket lengkap siap streaming!"**

---

### 🎨 3 Tema Map Eksklusif yang Bisa Dipilih:

| Tema Map | Deskripsi Visual & Fitur Unik | Suasana Pencahayaan (Lighting) |
| :--- | :--- | :--- |
| **🏝️ Pulau Tropis (Tropical Island)** *(Default)* | Pulau pantai pasir emas melingkar di tengah samudra, laguna air laut berkarang, pohon kelapa 3D stylized, dan bebatuan karang. Sangat dramatis saat ombak tsunami menerjang dari laut! | *Sunset Golden Hour* (Pukul 17:30) dengan langit jingga hangat dan bayangan lembut. |
| **⚡ Cyberpunk Neon Colosseum** | Arena koloseum futuristik berbahan kaca obsidian hitam pekat, dilingkari ring neon cyan bercahaya terang, grid garis magenta, dan **6 menara pylon energi heksagonal** dengan *PointLight*. | *Cyber Midnight* (Pukul 22:00) yang memantulkan kilauan neon balok dan gelombang tsunami secara spektakuler. |
| **☁️ Cloud Kingdom (Skyblock)** | Kastil pulau batu melayang di atas langit dengan pilar-pilar marmer klasik megah, gumpalan awan putih halus di sekeliling pulau, dan **obelisk kristal melayang bercahaya ungu** di pusat arena. | *Radiant Daylight* (Pukul 14:00) dengan cahaya surga yang jernih dan megah. |

---

### 📦 Setiap Map yang Di-generate Sudah Mencakup (All-In-One):
1. **`SpawnLocation` Resmi**: Pemain langsung otomatis spawn di platform aman map.
2. **`NoxoraStreamBillboard` (Papan Panduan Gift Raksasa)**:
   * Layar billboard 3D raksasa (Front Facing) menggunakan `SurfaceGui` yang menampilkan daftar gift penonton (Rose, Donut, Ice Cream, Cap, Dragon, Follow).
   * Menampilkan header resmi: `⚡ POWERED BY NOXORA STUDIO • TIKTOK INTERACTIVE ENGINE v2.5`.
3. **`VoidProtectionBarrier` (Zona Penyelamat Jatuh)**:
   * Lapisan barrier otomatis di bawah pulau. Jika pemain terhempas ombak atau terjatuh dari arena, mereka akan secara otomatis diteleportasikan kembali ke platform spawn tanpa mati.
4. **`NoxoraWatermarkPlaque`**: Plakat fisik holografis di tengah arena.

---

### 🎮 Kontrol Khusus Map: "SELECT / GENERATE" & "RESET"

Pengguna memiliki kendali penuh untuk memilih tema map atau menghapusnya kapan saja melalui **2 Antarmuka Khusus**:

#### 1. Melalui In-Game Admin Control GUI (Saat Bermain / Streaming):
1. Tekan tombol **`M`** atau klik tombol **`[ 🎮 TikTok Live Control ]`** di kanan atas layar.
2. Buka tab ke-4: **`🗺️ Tema Map`**.
3. Klik salah satu tema: **🏝️ Tropis**, **⚡ Cyberpunk**, atau **☁️ Skyblock**.
4. Klik tombol hijau: **`🏗️ Generate Map Tema Terpilih`** untuk langsung membangun map secara real-time.
5. Klik tombol merah: **`🧹 Reset Map`** untuk membersihkan arena otomatis seketika.

#### 2. Melalui DockWidget Plugin Roblox Studio (Di Mode Edit Studio):
1. Buka widget **TikTok Live Bridge** di Roblox Studio.
2. Pada kartu **`🗺️ AUTO MAP GENERATOR (PAKET LENGKAP)`**:
   * Pilih tema dengan mengklik tombol tema (akan menyala dengan bingkai cyan).
   * Klik tombol hijau **`✨ Generate Map Tema`** -> Map langsung dibangun di Workspace Studio Anda secara instan (mendukung *Undo/Redo* via `Ctrl + Z`).
   * Klik tombol merah **`🧹 Reset Map`** -> Map otomatis dibersihkan dari Workspace.
   * Centang/Hilangkan centang **"Otomatis generate map saat Play"** untuk mengatur apakah map dibuat otomatis saat game dimulai.

---

### 🛡️ Bagaimana Jika Pengguna Sudah Memiliki Elemen Map Sendiri?

Fitur Auto Map Generator dirancang **100% Non-Destructive (Sangat Aman & Tidak Merusak Map Anda)**:
* Seluruh elemen map yang dibuat oleh generator dikelompokkan ke dalam satu folder khusus: `workspace.TikTokGeneratedMap`.
* **Map kustom Anda TIDAK AKAN PERNAH tersentuh atau tertimpa**:
  1. Jika Anda sudah memiliki bangunan, pulau, atau map sendiri di Workspace, Anda cukup klik **`🧹 Reset Map`** atau hilangkan centang **"Otomatis generate map saat Play"**.
  2. Folder `TikTokGeneratedMap` akan dihapus bersih tanpa mempengaruhi part, model, atau terrain buatan Anda sendiri.
  3. Sistem TikTok Live akan tetap berjalan 100% normal pada map kustom Anda!

---

## 🛡️ Hak Cipta & Watermark Resmi: "NOXORA STUDIO" (Protected & Anti-Tamper)

Untuk melindungi keaslian dan hak cipta karya intelektual dari Plugin dan Script ini, telah ditambahkan watermark resmi **"NOXORA STUDIO"** yang dilindungi secara sistematis:

### 1. Titik Penempatan Watermark Resmi:
* **Pada Plakat Holografis 3D Arena (`NoxoraWatermarkPlaque`)**:
  * Plakat kaca obsidian beralas neon cyan dengan teks bercahaya:
    ```text
    ★ NOXORA STUDIO OFFICIAL ENGINE ★
    ```
* **Pada Papan Panduan Streaming Raksasa (`NoxoraStreamBillboard`)**:
  * Header billboard memuat teks identitas resmi:
    ```text
    ⚡ POWERED BY NOXORA STUDIO • TIKTOK INTERACTIVE ENGINE v2.5
    ```
* **Pada In-Game Admin Controller GUI**:
  * Badge Neon di Header jendela: `★ NOXORA STUDIO`
  * Footer Bar permanen di bagian bawah:
    ```text
    🛡️ POWERED BY NOXORA STUDIO • HAK CIPTA DILINDUNGI • TIKTOK LIVE ENGINE
    ```
* **Pada Plugin DockWidget Roblox Studio**:
  * Watermark badge di bagian atas widget dan kartu footer legalitas resmi.

### 2. Sistem Proteksi Anti-Tamper (Tidak Bisa Diubah Pengguna):
* **Part Locking**: Seluruh part watermark pada billboard dan plakat memiliki properti `Locked = true` sehingga tidak dapat digeser, dipilih secara tidak sengaja, atau diubah posisinya di viewport Studio.
* **Property Watcher & Anti-Tamper Event Listener**:
  * Komponen GUI dan plakat dipasangi sinyal event listener (`GetPropertyChangedSignal("Text")` dan `GetPropertyChangedSignal("Visible")`).
  * Jika ada script pihak ketiga atau pengguna yang mencoba mengubah isi teks atau menyembunyikan watermark (`Visible = false`), sistem akan **secara otomatis mengembalikan teks resmi "NOXORA STUDIO" dan memulihkan visibilitasnya seketika**.
* **Model Attributes**: Atribut resmi `Copyright = "NOXORA STUDIO"` dan `Protected = true` terpasang permanen pada metadata instans part.

---

## ⚠️ Troubleshooting & Masalah Umum

| Gejala Masalah | Penyebab | Solusi |
| :--- | :--- | :--- |
| `Http requests are not enabled` | Pengaturan HTTP di Studio belum diizinkan. | Buka **Game Settings** -> **Security** -> Centang **Allow HTTP Requests** -> Save. |
| `Connection Refused / Failed to connect` | Node.js backend belum dijalankan. | Buka terminal dan jalankan `npm start` di folder `Backend-NodeJS`. |
| In-Game GUI tidak muncul | Script belum diletakkan di `StarterGui`. | Pastikan file `TikTokInGameControlGui.client.lua` ditaruh di dalam folder `StarterGui`. Tekan tombol **`M`** untuk membuka. |
| Custom Gift tidak memicu aksi | Nama gift salah ketik. | Pastikan ejaan nama gift sama dengan nama gift di TikTok (contoh: `rose`, `donut`, `ice cream`, `cap`). Huruf besar/kecil tidak berpengaruh. |
| Main di Roblox Player biasa tapi data tidak masuk | Menggunakan `localhost` di game publik. | Saat bermain di Roblox Player biasa, gunakan link dari **Pilihan B (Localtunnel)** (`npm run tunnel`) atau **Pilihan C (Pinggy)**. Masukkan link tersebut ke kolom URL In-Game GUI. |
