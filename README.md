# 🔵 BlueConnect - Akıllı Sensör Takip Paneli

BlueConnect, ESP32 + DHT11 ile elde edilen sıcaklık ve nem verilerini **Bluetooth Low Energy (BLE)** üzerinden mobil uygulamaya ileten, bu verileri **MongoDB** veritabanına kaydeden ve **gerçek zamanlı** olarak bir web panelde gösteren uçtan uca IoT projesidir. 🛰️📱🌐

---

## 🚀 Özellikler

- ✅ **Gerçek zamanlı veri takibi** (Socket.IO ile anında güncelleme)
- 🌡️ **Anlık sıcaklık ve nem ölçümleri**
- 📈 **Geçmiş veri analizi** (Tarihe ve cihaza göre filtrelenebilir)
- 📊 **Grafiksel gösterim**
- 💾 **MongoDB veri kaydı**
- 📦 **CSV ile veri dışa aktarma**
- 🛜 **BLE ile mobil veri aktarımı**

---

## 📱 Mobil Uygulama (Flutter)

BLE üzerinden ESP32 ile haberleşir. Alınan verileri anlık olarak gösterir ve sunucuya gönderir.

### 📦 Özellikler:
- Anlık sıcaklık & nem verisi
- Bağlantı süresi & cihaz bilgisi
- Tema desteği (Dark/Light)
- BLE cihaz tarama & bağlanma
- Otomatik veri gönderme
- Web'e canlı veri push

> 📍 Bulunduğu klasör: `/blueconnect_app`

---

## 🌐 Web Panel (Express.js + MongoDB + Socket.IO)

Sensör verilerini sunar, analiz eder, filtreler ve dışa aktarmanı sağlar.

### Özellikler:
- Son veri durumu
- Tarihsel analiz ve grafikler
- Cihazlara göre filtreleme
- Gerçek zamanlı güncelleme (WebSocket)
- CSV dışa aktar

> 📍 Bulunduğu klasör: `/blueconnect_web`

---

## 🧠 Kullanılan Teknolojiler

| Teknoloji        | Açıklama                          |
|------------------|-----------------------------------|
| Flutter          | Mobil uygulama (Android)          |
| ESP32 + DHT11    | Donanım tarafı                    |
| Node.js + Express| Backend sunucu                    |
| MongoDB Atlas    | Veritabanı (Cloud)                |
| Socket.IO        | Gerçek zamanlı bağlantı (WebSocket) |
| Chart.js         | Grafikler                         |

---

## 📷 Ekran Görüntüsü
