import 'dart:async';

import 'package:blu_mat/services/a2dp_service.dart';
import 'package:flutter/material.dart';

class A2dpProvider extends ChangeNotifier {
  A2dpProvider() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      tryReconnect();
    });
  }

  // --------------
  // Devices (from native scan)
  // --------------
  List<Map<String, String>> _a2dpDevices = [];
  List<Map<String, String>> get a2dpDevices => _a2dpDevices;

  bool _isA2dpScanning = false;
  bool get isA2dpScanning => _isA2dpScanning;

  // -----------------------
  // Connection State
  // -----------------------
  String? _a2dpConnectedAddress;
  String? get a2dpConnectedAddress => _a2dpConnectedAddress;

  String? _lastA2dpConnectedAddress;

  bool _userInitiatedDisconnect = false;

  bool get isA2dpConnected => _a2dpConnectedAddress != null;

  bool isAudioConnected = false;

  // -----------------------
  // Scan (paired devices)
  // -----------------------
  void startScan() async {
    if (isA2dpScanning) return;
    _isA2dpScanning = true;
    notifyListeners();

    try {
      final result = await A2dpService.scan();
      _a2dpDevices = (result)
          .map(
            (e) => Map<String, String>.from(
              e.map((key, value) => MapEntry(key.toString(), value.toString())),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Scan error: $e');
    }

    _isA2dpScanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    _isA2dpScanning = false;
    notifyListeners();
  }

  // --------------
  // Connection
  // --------------

  // connect to Devices
  Future<void> connectToA2dpDevice(String address) async {
    if (_a2dpConnectedAddress == address && isA2dpConnected) return;

    await disconnect(userInitiated: false);
    try {
      final success = await A2dpService.connect(address);

      if (success) {
        _a2dpConnectedAddress = address;
        _lastA2dpConnectedAddress = address;
        _userInitiatedDisconnect = false;
      }
      debugPrint(
        success ? '✅ A2DP connect triggered' : '❌ A2DP connect failed',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Connection error: $e');
    }
  }

  // tryReconnecting the existing devices feature
  Future<void> tryReconnect() async {
    // 1. Do not reconnect if user intentionally disconnected
    if (_userInitiatedDisconnect) return;
    // 2. Do not reconnect while scanning
    if (isA2dpScanning) return;
    // 3. No last device to reconnect to
    if (_lastA2dpConnectedAddress == null) return;
    // 4. If already connected — nothing to do
    if (isA2dpConnected) return;

    connectToA2dpDevice(_lastA2dpConnectedAddress!);
  }

  // Disconnect
  Future<void> disconnect({bool userInitiated = false}) async {
    _userInitiatedDisconnect = userInitiated;
    if (_a2dpConnectedAddress != null) {
      final success = await A2dpService.disconnect(_a2dpConnectedAddress!);
      debugPrint(
        success ? '✅ A2DP disconnect triggered' : '❌ A2DP disconnect failed',
      );
    }

    if (_userInitiatedDisconnect) {
      _lastA2dpConnectedAddress =
          null; // remove previously connected devices if it's userInitiated disconnect
    }
    _a2dpConnectedAddress = null;
    isAudioConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    super.dispose();
  }
}
