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

  bool get isBleConnected => _bleConnectedDeviceId != null;

  String? _lastBleConnectedDeviceId;
  bool _userInitiatedDisconnect = false;

  bool _shouldAutoReconnect = true;
  int _retryCount = 0;
  final int _maxRetries = 3;


  // BLE Provider Constructor
  BleProvider() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      tryReconnect();
    });
  }

  void handleEvent(Map<String, dynamic> event) {
    _sub = BluetoothService.events.listen((event) {
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
        } else if (state == 'DISCONNECTED') {
          _bleConnectedDeviceId = null;
        }
        notifyListeners();
      }
    });
  }

  // --------------
  // Scanning
  // --------------
  void startScan() async{
    if (isBleScanning) return;
    _bleDevices.clear();
    _isBleScanning = true;
    notifyListeners();

    try {
      await BluetoothService.startBleScan();

      Future.delayed(const Duration(seconds: 10), () {
        stopScan();
      });
    } catch (e) {
      debugPrint('BLE Scan error: $e');
    }
  }

  Future<void> stopScan() async {
    await BluetoothService.stopBleScan();
    _isBleScanning = false;
    notifyListeners();
  }

  // --------------
  // Connection
  // --------------
  Future<void> connectToBleDevice(String id) async {
    if (_bleConnectedDeviceId == id && isBleConnected) return;

    await disconnect(userInitiated: false); 

    try {
      await BluetoothService.connectBle(id);

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
  Future<void> tryReconnect() async {
    log('retry 1');
    // 1. Do not reconnect if user intentionally disconnected
    if (_userInitiatedDisconnect) return;
    log('user initited');
    // 2. Do not reconnect while scanning
    if (isBleScanning) return;
    log('after scanning');
    // 3. No last device to reconnect to
    if (_lastBleConnectedDeviceId == null) return;
    log('last connected');
    // 4. If already connected — nothing to do
    if (isBleConnected) return;
    log('after connection');
    if (_retryCount >= _maxRetries) return;
    _retryCount++;
    if (!_userInitiatedDisconnect &&
        _shouldAutoReconnect &&
        _lastBleConnectedDeviceId != null) {
      stopScan();
      connectToBleDevice(_lastBleConnectedDeviceId!);
      log('---post retry---');
    }
  }

  // Disconnect
  Future<void> disconnect({bool userInitiated = false}) async {
    _userInitiatedDisconnect = userInitiated;
    _shouldAutoReconnect = false;
    try {
      await BluetoothService.disconnectBle();
    } catch (e) {
      debugPrint('BLE disconnect error: $e');
    }
    if (userInitiated) {
      _lastBleConnectedDeviceId = null; // remove previously connected
    }
    _bleConnectedDeviceId = null;
    notifyListeners();
    _shouldAutoReconnect = true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    stopScan();
    disconnect();
    super.dispose();
  }
}
