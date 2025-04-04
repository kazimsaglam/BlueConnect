const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

let latestData = {};

app.post('/api/sensor-data', (req, res) => {
  const { deviceId, temperature, humidity, timestamp } = req.body;
  latestData[deviceId] = { temperature, humidity, timestamp };
  console.log(`[✓] Veri alındı: ${deviceId}`, latestData[deviceId]);
  res.sendStatus(200);
});

app.get('/api/latest-data', (req, res) => {
  res.json(latestData);
});

app.listen(3000, () => {
  console.log('🌐 Sunucu çalışıyor: http://localhost:3000');
});
