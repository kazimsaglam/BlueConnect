const path = require("path");
const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');
const http = require('http');
const { Server } = require('socket.io');

// Express ve Socket.io Sunucu Kurulumu
const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(cors());
app.use(express.json());

// MongoDB Bağlantı Ayarları
const uri = "mongodb+srv://blueadmin:blue123@blueconnect.v5osp0i.mongodb.net/?retryWrites=true&w=majority&appName=BlueConnect";
const client = new MongoClient(uri);
let db;

// MongoDB'ye Bağlan
async function connectDB() {
    try {
        await client.connect();
        db = client.db();
        console.log("✅ MongoDB'ye bağlandı!");
    } catch (err) {
        console.error("❌ MongoDB bağlantı hatası:", err);
    }
}
connectDB();

// WebSocket Bağlantısı
io.on('connection', (socket) => {
    console.log('🔌 WebSocket bağlantısı kuruldu');
});

// Static Dosyalar
app.use(express.static(path.join(__dirname, 'public')));

// Ana Sayfa
app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// 1. Sensör Veri Kaydetme Endpoint'i
app.post('/api/sensor-data', async (req, res) => {
    try {
        const { deviceId, deviceName, temperature, humidity, timestamp } = req.body;

        const collection = db.collection('sensor_readings');
        await collection.insertOne({
            deviceId,
            deviceName: deviceName || "Bilinmeyen Cihaz",
            temperature: parseFloat(temperature),
            humidity: parseFloat(humidity),
            timestamp: new Date(timestamp)
        });

        console.log(`[✓] Veri kaydedildi: ${deviceId}`);

        // 🎯 WebSocket ile canlı veri yayını
        io.emit('new-data', {
            deviceId,
            deviceName,
            temperature,
            humidity,
            timestamp
        });

        res.sendStatus(200);
    } catch (err) {
        console.error("Veri kaydetme hatası:", err);
        res.status(500).send("Sunucu hatası");
    }
});

// 2. Son Verileri Göster
app.get('/api/latest-data', async (req, res) => {
    try {
        const collection = db.collection('sensor_readings');
        const devices = await collection.distinct("deviceId");

        const latestData = {};
        for (const deviceId of devices) {
            const [data] = await collection.find({ deviceId })
                .sort({ timestamp: -1 })
                .limit(1)
                .toArray();
            latestData[deviceId] = data;
        }

        res.json(latestData);
    } catch (err) {
        console.error("Veri çekme hatası:", err);
        res.status(500).json({ error: "Sunucu hatası" });
    }
});

// 3. Tarihsel Veri Endpoint'i
app.get('/api/historical-data', async (req, res) => {
    try {
        const { deviceId, startDate, endDate } = req.query;
        const collection = db.collection('sensor_readings');

        const query = {
            timestamp: {
                $gte: new Date(startDate),
                $lte: new Date(endDate)
            }
        };
        if (deviceId) query.deviceId = deviceId;

        const data = await collection.find(query).sort({ timestamp: 1 }).toArray();
        res.json(data);
    } catch (err) {
        console.error("Geçmiş veri hatası:", err);
        res.status(500).json({ error: "Sunucu hatası" });
    }
});

// 4. Cihaz Listesi Endpoint'i
app.get('/api/device-list', async (req, res) => {
      try {
    const collection = db.collection('sensor_readings')

    const devices = await collection.aggregate([
      { $sort: { timestamp: -1 } },          
      { $group: {                          
          _id: "$deviceId",
          deviceName: { $first: "$deviceName" }
      }},
      { $project: {                      
          _id: 0,
          deviceId: "$_id",
          deviceName: { $ifNull: ["$deviceName", "$_id"] }
      }},
      { $sort: { deviceName: 1 } }           
    ]).toArray();

    res.json(devices);
  } catch (err) {
    console.error("Cihaz listesi hatası:", err);
    res.status(500).json({ error: "Sunucu hatası" });
  }
});

// === EKLENENLER: Cihaz Gizleme Sistemi ===

// 5. Gizli Cihazları Getir
app.get('/api/hidden-devices', async (req, res) => {
    try {
        const hidden = await db.collection('hidden_devices').find().toArray();
        res.json(hidden.map(h => h.deviceId));
    } catch (err) {
        console.error("Gizli cihaz çekme hatası:", err);
        res.status(500).json({ error: "Sunucu hatası" });
    }
});

// 6. Cihazı Gizle
app.post('/api/hide-device', async (req, res) => {
    try {
        const { deviceId } = req.body;
        await db.collection('hidden_devices').updateOne(
            { deviceId },
            { $set: { deviceId } },
            { upsert: true }
        );
        res.sendStatus(200);
    } catch (err) {
        console.error("Cihaz gizleme hatası:", err);
        res.status(500).json({ error: "Sunucu hatası" });
    }
});

// 7. Gizli Cihazı Geri Getir
app.post('/api/unhide-device', async (req, res) => {
    try {
        const { deviceId } = req.body;
        await db.collection('hidden_devices').deleteOne({ deviceId });
        res.sendStatus(200);
    } catch (err) {
        console.error("Cihaz geri getirme hatası:", err);
        res.status(500).json({ error: "Sunucu hatası" });
    }
});

// Sunucuyu Başlat
server.listen(3000, () => {
    console.log('🌐 Sunucu çalışıyor: http://localhost:3000');
});
