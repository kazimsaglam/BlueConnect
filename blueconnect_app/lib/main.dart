import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'screens/scan_page.dart';

void main() async{
  await Future.delayed(Duration(seconds: 5));

  FlutterNativeSplash.remove();

  runApp(const BlueConnectApp());
}

class BlueConnectApp extends StatefulWidget {
  const BlueConnectApp({super.key});

  @override
  State<BlueConnectApp> createState() => _BlueConnectAppState();
}

class _BlueConnectAppState extends State<BlueConnectApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueConnect',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: ScanPage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }

}