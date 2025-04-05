#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

// Pin ve sensör tanımlamaları
#define DHTPIN 15
#define DHTTYPE DHT11

#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "abcd1234-5678-90ab-cdef-123456789abc"
#define SERVERNAME          "ESP32 - DHT Sensor"

DHT dht(DHTPIN, DHTTYPE);

BLEServer* pServer = NULL;
BLECharacteristic* dhtCharacteristic = NULL;
bool deviceConnected = false;

DynamicJsonDocument sendDoc(128);
DynamicJsonDocument receivedDoc(64);


class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("🔗 Cihaz bağlandı.");
  };

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ Cihaz bağlantısı kesildi.");
    BLEDevice::startAdvertising();
  }
};

class CharacteristicCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* dhtCharacteristic) {
    String value = dhtCharacteristic->getValue().c_str();
    deserializeJson(receivedDoc, value);
    
    if (receivedDoc["command"] == "disconnect") {
      Serial.println("🔌 Flutter bağlantıyı kesecek, notify durduruluyor.");
      deviceConnected = false;
    }
  }
};

void setupBle() {
  Serial.println("📡 BLE başlatılıyor...");
  BLEDevice::init(SERVERNAME);
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  dhtCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY |
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE);

  dhtCharacteristic->addDescriptor(new BLE2902());
  dhtCharacteristic->setCallbacks(new CharacteristicCallback());
  pService->start();

  // Reklam ayarları
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("✅ BLE aktif ve bağlantı bekleniyor...");
}

void readSensorData(float& temperature, float& humidity) {
  humidity = dht.readHumidity();
  temperature = dht.readTemperature();

  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("⚠️ Sensör verisi okunamadı.");
    delay(1000);
    return;
  }
}

void sendData(float temperature, float humidity) {
  sendDoc["temperature"] = temperature;
  sendDoc["humidity"] = humidity;

  String data;
  serializeJson(sendDoc, data);
  
  dhtCharacteristic->setValue(data.c_str());
  dhtCharacteristic->notify();

  Serial.println("📤 Gönderildi: " + data);
}

void setup() {
  Serial.begin(115200);
  dht.begin();
  setupBle();
}

void loop() {
  static float temperature, humidity;
  
  readSensorData(temperature, humidity);

  if (deviceConnected) {
    sendData(temperature, humidity);
  }
  
  delay(1000);
}