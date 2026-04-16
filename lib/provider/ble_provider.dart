import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:blu_mat/services/bluetooth_service.dart';

class BleProvider extends ChangeNotifier {
  // --------------
  // Devices (from native scan)
  // --------------
  List<Map<String, String>> _bleDevices = [];
  List<Map<String, String>> get bleDevices => _bleDevices;

  bool _isBleScanning = false;
  bool get isBleScanning => _isBleScanning;

  // -----------------------
  // Connection State
  // -----------------------
  StreamSubscription? _sub;

  String? _bleConnectedDeviceId;
  String? get bleConnectedDeviceId => _bleConnectedDeviceId;

  bool _isBleConnected = false;
  bool get isBleConnected => _isBleConnected;

  String? _lastBleConnectedDeviceId;
  bool _userInitiatedDisconnect = false;

  int _retryCount = 0;
  final int _maxRetries = 5;
  Timer? _reconnectTimer;

  void handleEvent(Map<String, dynamic> event) {
    final type = event['type'];

    if (type == 'BLE_SCAN') {
      final device = {
        'name': (event['name'] ?? 'Unknown').toString(),
        'id': event['id'].toString(),
      };

      final exists = _bleDevices.any((d) => d['id'] == device['id']);
      if (!exists) {
        _bleDevices.add(device);
        notifyListeners();
      }
    }

    if (type == 'BLE_CONNECTION') {
      final state = event['state'];
      final id = event['id'];

      if (state == 'CONNECTED') {
        _bleConnectedDeviceId = id;
        _isBleConnected = true;
        _retryCount = 0;
        _reconnectTimer?.cancel();
      } else if (state == 'DISCONNECTED') {
        _bleConnectedDeviceId = null;
        _isBleConnected = false;
        if (!_userInitiatedDisconnect && _lastBleConnectedDeviceId != null) {
          _scheduleReconnect();
        }
      } else if (state == 'ERROR') {
        _bleConnectedDeviceId = null;
        _isBleConnected = false;
        debugPrint("BLE ERROR: ${event['status']}");
        if (!_userInitiatedDisconnect && _lastBleConnectedDeviceId != null) {
          _scheduleReconnect();
        }
      }
      notifyListeners();
    }
    if (type == 'ERROR') {
      log('BLE system error: ${event['message']}');
    }
  }

  // --------------
  // Scanning
  // --------------
  void startScan() async {
    if (isBleScanning) return;
    _bleDevices.clear();
    _isBleScanning = true;
    notifyListeners();

    try {
      await BluetoothService.startBleScan();
      Future.delayed(const Duration(seconds: 10), stopScan);
    } catch (e) {
      debugPrint('BLE Scan error: $e');
      _isBleScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (!_isBleScanning) return;
    try {
      await BluetoothService.stopBleScan();
    } catch (e) {
      debugPrint('stopScan error: $e');
    }
    _isBleScanning = false;
    notifyListeners();
  }

  // --------------
  // Connection
  // --------------
  Future<void> connectToBleDevice(String id) async {
    if (_bleConnectedDeviceId == id && isBleConnected) return;

    if (isBleConnected) {
      await disconnect(userInitiated: false);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      await BluetoothService.connectBle(id);
      _retryCount = 0;
      _lastBleConnectedDeviceId = id;
      _userInitiatedDisconnect = false;
    } catch (e) {
      debugPrint('BLE connect error: $e');
    }
  }

  // // Discover services and subscribe to a characteristic
  // Future<void> subscribeToCharacteristic({
  //   required Uuid serviceId,
  //   required Uuid characteristicId,
  //   required void Function(List<int> data) onData,
  // }) async {
  //   if (_bleConnectedDevice == null) return;

  //   _bleDataSubscription?.cancel();

  //   // Create the characteristic reference
  //   final characteristic = QualifiedCharacteristic(
  //     serviceId: serviceId,
  //     characteristicId: characteristicId,
  //     deviceId: _bleConnectedDevice!.id,
  //   );

  //   _bleDataSubscription = _ble
  //       .subscribeToCharacteristic(characteristic)
  //       .listen(
  //         onData,
  //         onError: (err) {
  //           debugPrint('Ble characteristic subscription error: $err');
  //         },
  //       );
  // }

  // // Unsubscribe to Characteristic
  // Future<void> unsubscribeFromCharacteristic() async {
  //   await _bleDataSubscription?.cancel();
  //   _bleDataSubscription = null;
  //   debugPrint('Unsubscribed from BLE characteristic');
  // }

  // tryReconnecting the existing devices feature
  void _scheduleReconnect() {
    if (_retryCount >= _maxRetries) {
      log('Max reconnect attempts reached ($_maxRetries). Giving up.');
      return;
    }

    _retryCount++;

    _reconnectTimer?.cancel();
    final delaySeconds = _retryCount * 2; // backoff: 2s, 4s, 6s, 8s, 10s
    log(
      'Scheduling reconnect attempt $_retryCount/$_maxRetries in ${delaySeconds}s',
    );

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      // Re-check conditions at the time the delay fires
      if (_userInitiatedDisconnect) return;
      if (_isBleConnected) return;
      if (_lastBleConnectedDeviceId == null) return;

      connectToBleDevice(_lastBleConnectedDeviceId!);
    });
  }

  // Disconnect
  Future<void> disconnect({bool userInitiated = false}) async {
    _userInitiatedDisconnect = userInitiated;
    try {
      await BluetoothService.disconnectBle();
    } catch (e) {
      debugPrint('BLE disconnect error: $e');
    }
    if (userInitiated) {
      _lastBleConnectedDeviceId = null; // remove previously connected
      _retryCount = 0;
      _reconnectTimer?.cancel();
    }
    _isBleConnected = false;
    _bleConnectedDeviceId = null;
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
