const path = require("path");
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Veriler burada tutulur
let latestData = {};

// API: Sensör verisi alımı
app.post('/api/sensor-data', (req, res) => {
  const { deviceId, deviceName, temperature, humidity, timestamp } = req.body;

  latestData[deviceId] = {
    deviceName: deviceName || "Bilinmeyen",
    temperature,
    humidity,
    timestamp,
  };

  console.log(`[✓] Veri alındı: ${deviceId}`, latestData[deviceId]);
  res.sendStatus(200);
});

// API: Son verileri gönder
app.get('/api/latest-data', (req, res) => {
  res.json(latestData);
});

// Sunucuyu başlat
app.listen(3000, () => {
  console.log('🌐 Sunucu çalışıyor: http://localhost:3000');
});
