import 'dart:async';

import 'package:blu_mat/services/bluetooth_service.dart';
import 'package:flutter/material.dart';

class A2dpProvider extends ChangeNotifier {
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
  StreamSubscription? _sub;

  String? _a2dpConnectedAddress;
  String? get a2dpConnectedAddress => _a2dpConnectedAddress;

  String? _lastA2dpConnectedAddress;

  bool _userInitiatedDisconnect = false;

  bool get isA2dpConnected => _a2dpConnectedAddress != null;

  bool isAudioConnected = false;

  int _retryCount = 0;
  final int _maxRetries = 3;

  // A2DP Provider Constructor
  A2dpProvider() {
    _sub = BluetoothService.events.listen((event) {
      final type = event['type'];

      if (type == 'A2DP_CONNECTION') {
        final state = event['state'];
        final address = event['address'];
        debugPrint('EVENT: $state | $address');

        if (state == 'CONNECTED') {
          _a2dpConnectedAddress = address;
          isAudioConnected = true;
        } else if (state == 'DISCONNECTED') {
          _a2dpConnectedAddress = null;
          isAudioConnected = false;
        }
        notifyListeners();
      }
    });

    Timer.periodic(const Duration(seconds: 5), (timer) {
      tryReconnect();
    });
  }

  // -----------------------
  // Scan (paired devices)
  // -----------------------
  void startScan() async {
    if (isA2dpScanning) return;
    _isA2dpScanning = true;
    notifyListeners();

    try {
      final result = await BluetoothService.scanA2dp();
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
      final success = await BluetoothService.connectA2dp(address);

      if (success) {
        _lastA2dpConnectedAddress = address;
        _userInitiatedDisconnect = false;
      }
      debugPrint(
        success ? '✅ A2DP connect triggered' : '❌ A2DP connect failed',
      );
    } catch (e) {
      debugPrint('Connection error: $e');
    }
    notifyListeners();
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
    // 5. if within the retry range
    if (_retryCount >= _maxRetries) return;

    _retryCount++;
    connectToA2dpDevice(_lastA2dpConnectedAddress!);
  }

  // Disconnect
  Future<void> disconnect({bool userInitiated = false}) async {
    _userInitiatedDisconnect = userInitiated;
    if (_a2dpConnectedAddress != null) {
      final success = await BluetoothService.disconnectA2dp(_a2dpConnectedAddress!);
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
    _sub?.cancel();
    stopScan();
    disconnect();
    super.dispose();
  }
}
