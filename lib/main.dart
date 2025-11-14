import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Theme/theme.dart';
import 'provider/ble_provider.dart';
import 'provider/bluetooth_provider.dart';
import 'provider/classic_bluetooth_provider.dart';
import 'screens/homescreen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => BluetoothProvider()),
        ChangeNotifierProvider(create: (context) => BleProvider()),
        ChangeNotifierProvider(create: (context) => ClassicBluetoothProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ThemeProvider, ThemeMode>(
      selector: (context, provider) => provider.customThemeMode,
      builder: (context, customThemeMode, _) => MaterialApp(
        title: 'BluMat',
        debugShowCheckedModeBanner: false,
        theme: lightMode,
        darkTheme: darkMode,
        themeMode: customThemeMode,
        home: const Homescreen(),
      ),
    );
  }
}
