import 'dart:convert';
import 'package:http/http.dart' as http;

class WebService {
  static const String _endpoint = 'https://blueconnect.onrender.com/api/sensor-data';

  /// ESP32 cihazından gelen veriyi sunucuya gönderir
  static Future<void> sendSensorData({
    required String deviceName,
    required String deviceId,
    required double temperature,
    required int humidity,
  }) async {
    final payload = {
      "deviceName": deviceName,
      "deviceId": deviceId,
      "temperature": temperature,
      "humidity": humidity,
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print("✅ Veri gönderildi: $payload");
      } else {
        print("❌ Sunucu hatası [${response.statusCode}]: ${response.body}");
      }
    } catch (e) {
      print("🌐 HTTP isteği hatası: $e");
    }
  }

}