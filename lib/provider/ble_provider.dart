import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleProvider extends ChangeNotifier {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // --------------
  // Scanning
  // --------------
  // list of Discovered Devices after Scan
  List<DiscoveredDevice> _bleDevices = [];
  List<DiscoveredDevice> get bleDevices => _bleDevices;

  // Connection Subscription
  StreamSubscription<DiscoveredDevice>? _bleScanSubscription;
  bool _isBleScanning = false;
  bool get isBleScanning => _isBleScanning;

  // method to Start Scanning BLE Devices
  void startScan() {
    if (isBleScanning) return;
    _bleDevices.clear();
    _isBleScanning = true;
    notifyListeners();

    _bleScanSubscription = _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen(
          (device) {
            // Avoid duplicates
            if (!_bleDevices.any((d) => d.id == device.id)) {
              _bleDevices.add(device);
              notifyListeners();
            }
          },
          onError: (error) {
            debugPrint('Scan error: $error');
            stopScan();
          },
        );
  }

  // method to Stop Scanning BLE Devices
  Future<void> stopScan() async {
    await _bleScanSubscription?.cancel();
    _bleScanSubscription = null;
    _isBleScanning = false;
    notifyListeners();
  }

  // --------------
  // Connection
  // --------------
  DiscoveredDevice? _bleConnectedDevice;
  DiscoveredDevice? get bleConnectedDevice => _bleConnectedDevice;

  // Connection State
  DeviceConnectionState _bleConnectionState =
      DeviceConnectionState.disconnected;
  DeviceConnectionState get bleConnectionState => _bleConnectionState;

  // Ble Connection Subsctiption
  StreamSubscription<ConnectionStateUpdate>? _bleConnection;

  // IsConnected Flag
  bool get isBleConnected =>
      _bleConnection != null &&
      _bleConnectionState == DeviceConnectionState.connected;

  // Ble Data Subscription
  StreamSubscription<List<int>>? _bleDataSubscription;

  // Connect to Ble Device
  void connectToBleDevice(DiscoveredDevice device) {
    if (_bleConnectedDevice?.id == device.id && isBleConnected) return;

    _bleConnection?.cancel();
    _bleConnectedDevice = device;
    notifyListeners();

    _bleConnection = _ble
        .connectToDevice(
          id: device.id,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          (update) {
            _bleConnectionState = update.connectionState;
            notifyListeners();

            // Auto-reconnect
            if (update.connectionState == DeviceConnectionState.disconnected) {
              Future.delayed(const Duration(seconds: 2), () {
                if (_bleConnectedDevice?.id == device.id)
                  connectToBleDevice(device);
              });
            }
          },
          onError: (error) {
            debugPrint('Connection error: $error');
            _bleConnectionState = DeviceConnectionState.disconnected;
            notifyListeners();
          },
        );
  }

  // Discover services and subscribe to a characteristic
  Future<void> subscribeToCharacteristic({
    required Uuid serviceId,
    required Uuid characteristicId,
    required void Function(List<int> data) onData,
  }) async {
    if (_bleConnectedDevice == null) return;

    _bleDataSubscription?.cancel();

    // Create the characteristic reference
    final characteristic = QualifiedCharacteristic(
      serviceId: serviceId,
      characteristicId: characteristicId,
      deviceId: _bleConnectedDevice!.id,
    );

    _bleDataSubscription = _ble
        .subscribeToCharacteristic(characteristic)
        .listen(
          onData,
          onError: (err) {
            debugPrint('Ble characteristic subscription error: $err');
          },
        );
  }

  // Unsubscribe to Characteristic
  Future<void> unsubscribeFromCharacteristic() async {
    await _bleDataSubscription?.cancel();
    _bleDataSubscription = null;
    debugPrint('Unsubscribed from BLE characteristic');
  }

  // Disconnect
  Future<void> disconnect() async {
    await _bleDataSubscription?.cancel();
    _bleDataSubscription = null;
    await _bleConnection?.cancel();
    _bleConnection = null;
    _bleConnectionState = DeviceConnectionState.disconnected;
    _bleConnectedDevice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    super.dispose();
  }
}
