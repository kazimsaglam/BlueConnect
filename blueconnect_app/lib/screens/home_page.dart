import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'scan_page.dart';
import '/services/web_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  final BluetoothCharacteristic dhtCharacteristic;
  final bool isDarkMode;
  final void Function(bool) onToggleTheme;

  const HomePage({
    super.key,
    required this.dhtCharacteristic,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late BluetoothCharacteristic _characteristic;
  double temperature = 0;
  int humidity = 0;
  double feltTemperature = 0;
  double? lastSentTemperature;
  int? lastSentHumidity;
  double? lastFeltNotified;
  bool _notificationsEnabled = true;
  late bool _isDarkMode;

  DateTime? _connectedAt;
  String _elapsedTime = "0s";
  Timer? _durationTimer;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _characteristic = widget.dhtCharacteristic;
    _connectedAt = DateTime.now();
    _initializeNotifications();
    _startDurationTimer();
    _startNotify();
    _monitorConnection();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _monitorConnection() {
    _connectionSubscription = _characteristic.device.connectionState.listen((
      state,
    ) {
      if (state == BluetoothConnectionState.disconnected && mounted) {
        Fluttertoast.showToast(msg: 'Bağlantı koptu');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (_) => ScanPage(
                  isDarkMode: _isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
          ),
          (route) => false,
        );
      }
    });
  }

  void _startNotify() async {
    await _characteristic.setNotifyValue(true);
    _notifySubscription = _characteristic.lastValueStream.listen((value) {
      try {
        final decoded = jsonDecode(utf8.decode(value));
        final double newTemp = (decoded['temperature'] as num).toDouble();
        final int newHum = (decoded['humidity'] as num).toInt();
        final double newFelt = (newTemp - ((100 - newHum) / 5)).clamp(-100, 100);

        setState(() {
          temperature = newTemp;
          humidity = newHum;
          feltTemperature = newFelt;
        });

        if (_notificationsEnabled &&
            (lastFeltNotified == null ||
                (newFelt - lastFeltNotified!).abs() >= 1.0)) {
          lastFeltNotified = newFelt;
          _showNotification(newTemp, newFelt);
        }

        if (lastSentTemperature != newTemp || lastSentHumidity != newHum) {
          lastSentTemperature = newTemp;
          lastSentHumidity = newHum;

          try {
            WebService.sendSensorData(
              deviceName: _characteristic.device.platformName,
              deviceId: _characteristic.device.remoteId.toString(),
              temperature: temperature,
              humidity: humidity,
            );
          } catch (e) {
            debugPrint("Web'e veri gönderilemedi: $e");
          }
        }
      } catch (e) {
        debugPrint('Veri çözümleme hatası: $e');
      }
    });
  }

  Future<void> _showNotification(double temp, double felt) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidDetails = AndroidNotificationDetails(
      'blueconnect_channel',
      'BlueConnect Bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notifDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Ortam Güncellendi',
      'Sıcaklık: ${temp.toStringAsFixed(1)}°C, Hissedilen: ${felt.toStringAsFixed(1)}°C',
      notifDetails,
    );
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        final duration = DateTime.now().difference(_connectedAt!);
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

        setState(() {
          _elapsedTime = "$hours:$minutes:$seconds";
        });
      }
    });
  }

  void _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Bağlantıyı Kes"),
            content: const Text(
              "Bu cihazın bağlantısını kesmek istediğinize emin misiniz?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("İptal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Evet"),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _characteristic.write(
        utf8.encode(jsonEncode({"command": "disconnect"})),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      await _characteristic.device.disconnect();

      Fluttertoast.showToast(msg: 'Cihaz bağlantısı kesildi');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (_) => ScanPage(
                isDarkMode: _isDarkMode,
                onToggleTheme: widget.onToggleTheme,
              ),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Bağlantı kesme hatası: $e");
      Fluttertoast.showToast(msg: 'Bağlantı kesilirken hata oluştu');
    }
  }

  Widget _buildSwitchCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🌙 Karanlık Tema"),
                Switch(
                  value: _isDarkMode,
                  onChanged: (value) {
                    setState(() => _isDarkMode = value);
                    widget.onToggleTheme(value);
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🔔 Bildirimler"),
                Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String label,
    required String valueText,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(13, 0, 0, 0),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedScale(
            scale: 1.2,
            duration: const Duration(milliseconds: 200),
            child: Icon(icon, color: color, size: 40),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text(
                  valueText,
                  key: ValueKey(valueText),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    final name = _characteristic.device.platformName;
    final id = _characteristic.device.remoteId.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📡 Cihaz Bilgileri",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.device_hub, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(child: Text("Ad: $name")),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.confirmation_number, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(child: Text("MAC: $id")),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(child: Text("Bağlantı Süresi: $_elapsedTime")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectCard() {
    return GestureDetector(
      onTap: _disconnect,
      child: Card(
        color: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        margin: const EdgeInsets.only(top: 20),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Center(
            child: Text(
              '🔌 Bağlantıyı Kes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTemperatureColor(double value) {
    if (value < 20) return Colors.blueAccent;
    if (value < 35) return Colors.green;
    return Colors.redAccent;
  }

  Color _getHumidityColor(int value) {
    if (value < 30) return Colors.blueAccent;
    if (value < 70) return Colors.green;
    return Colors.redAccent;
  }

  Color _getFeltColor(double value) {
    if (value < 20) return Colors.blueAccent;
    if (value < 35) return Colors.green;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final feelsLike = (temperature + humidity * 0.05);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlueConnect - Bağlı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSwitchCard(),
            _buildDeviceInfo(),

            if (temperature == 0 && humidity == 0)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text("Veri bekleniyor..."),
                  ],
                ),
              )
            else ...[
              _buildSensorCard(
                icon: Icons.thermostat,
                label: "Sıcaklık",
                color: _getTemperatureColor(temperature),
                valueText: "${temperature.toStringAsFixed(1)} °C",
              ),
              _buildSensorCard(
                icon: Icons.water_drop,
                label: "Nem",
                color: _getHumidityColor(humidity),
                valueText: "$humidity %",
              ),
              _buildSensorCard(
              icon: Icons.device_thermostat,
              label: "Hissedilen Sıcaklık",
              color: _getFeltColor(feelsLike),
              valueText: "${feelsLike.toStringAsFixed(1)} °C",
              ),
            ],

            _buildDisconnectCard(),
          ],
        ),
      ),
    );
  }
}