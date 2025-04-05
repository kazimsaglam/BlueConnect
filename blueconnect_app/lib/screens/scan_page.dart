import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'home_page.dart';

class ScanPage extends StatefulWidget {
  final bool isDarkMode;
  final void Function(bool) onToggleTheme;
  const ScanPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<ScanResult> _results = [];
  bool _isScanning = false;
  StreamSubscription? _scanSub;
  StreamSubscription? _scanningStateSub;
  BluetoothCharacteristic? _dhtCharacteristic;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  @override
  void initState() {
    super.initState();
    _monitorBluetoothState();
    _checkBluetooth();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanningStateSub?.cancel();
    super.dispose();
  }

  void _monitorBluetoothState() {
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _adapterState = state;
      });
    });
  }

  void _checkBluetooth() async {
    try {
      _adapterState = await FlutterBluePlus.adapterState.first;
      if (_adapterState != BluetoothAdapterState.on && Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
      _startScan();
    } catch (e) {
      Fluttertoast.showToast(msg: "Bluetooth kontrol hatası: $e");
    }
  }

  void _startScan() async {
    await FlutterBluePlus.stopScan();
    setState(() => _results.clear());

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (_results.every(
          (r) => r.device.remoteId != result.device.remoteId,
        )) {
          setState(() => _results.add(result));
        }
      }
    });

    _scanningStateSub = FlutterBluePlus.isScanning.listen((scanning) {
      setState(() => _isScanning = scanning);
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 6),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Tarama hatası: $e');
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    try {
      final connectedDevices = await FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        if (device.remoteId != result.device.remoteId) {
          await device.disconnect();
        }
      }

      await result.device.connect();
      List<BluetoothService> services = await result.device.discoverServices();

      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.notify) {
            _dhtCharacteristic = char;
            break;
          }
        }
      }

      if (_dhtCharacteristic != null && mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (_, __, ___) => HomePage(
                  dhtCharacteristic: _dhtCharacteristic!,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        Fluttertoast.showToast(msg: 'Notify karakteristiği bulunamadı');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Bağlantı hatası: $e');
    }
  }

  Widget _buildDeviceCard(ScanResult result) {
    final name =
        result.device.platformName.isNotEmpty
            ? result.device.platformName
            : "İsimsiz Cihaz";
    final id = result.device.remoteId.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.bluetooth, color: Colors.indigo, size: 32),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(id),
        trailing: ElevatedButton(
          onPressed: () => _connectToDevice(result),
          style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
          child: const Text("Bağlan"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOn = _adapterState == BluetoothAdapterState.on;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              isOn ? Icons.bluetooth : Icons.bluetooth_disabled,
              color: isOn ? Colors.greenAccent : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(isOn ? 'Bluetooth Açık' : 'Bluetooth Kapalı'),
          ],
        ),
        actions: [
          Row(
            children: [
              const Icon(Icons.light_mode),
              Switch(value: widget.isDarkMode, onChanged: widget.onToggleTheme),
              const Icon(Icons.dark_mode),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _isScanning || !isOn ? null : _startScan,
              icon: const Icon(Icons.refresh),
              label:
                  _isScanning
                      ? const Row(
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Taranıyor...'),
                        ],
                      )
                      : const Text('Yeniden Tara'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                !_isScanning && _results.isEmpty
                    ? const Center(child: Text("Cihaz bulunamadı"))
                    : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder:
                          (context, index) => _buildDeviceCard(_results[index]),
                    ),
          ),
        ],
      ),
    );
  }

}