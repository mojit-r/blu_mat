import 'dart:async';

import 'package:flutter/material.dart';
import 'ble_provider.dart';
import 'classic_bluetooth_provider.dart';

import 'package:permission_handler/permission_handler.dart';

Future<bool> requestBlePermissions() async {
  if (await Permission.bluetoothScan.request().isGranted &&
      await Permission.bluetoothConnect.request().isGranted &&
      await Permission.locationWhenInUse.request().isGranted) {
    return true;
  }
  return false;
}

class BluetoothProvider extends ChangeNotifier {
  final BleProvider _bleProvider = BleProvider();
  final ClassicBluetoothProvider _classicBluetoothProvider =
      ClassicBluetoothProvider();

  BluetoothProvider() {
    // Forward BLE provider changes
    _bleProvider.addListener(() {
      notifyListeners();
    });

    // Forward Classic Bluetooth provider changes
    _classicBluetoothProvider.addListener(() {
      notifyListeners();
    });
  }

  bool _isBleMode = true;
  bool get isBleMode => _isBleMode;

  // Unified Data Stream
  StreamController<List<int>> _incomingDataController =
      StreamController.broadcast();
  Stream<List<int>> get incomingData => _incomingDataController.stream;

  void _forwardData(List<int> data) {
    _incomingDataController.add(data);
  }

  void toggleBleMode() {
    _isBleMode = !_isBleMode;
    stopScan();
    disconnect();
    notifyListeners();
  }

  // scanning Devices
  bool get isScanning {
    if (isBleMode) {
      return _bleProvider.isBleScanning;
    } else {
      return _classicBluetoothProvider.isClassicBScanning;
    }
  }

  // scanned Devices
  List<dynamic> get devices {
    if (isBleMode) {
      return _bleProvider.bleDevices;
    } else {
      return _classicBluetoothProvider.classicBDevices;
    }
  }

  // Connected Device
  dynamic get connectedDevice {
    if (isBleMode) {
      return _bleProvider.bleConnectedDevice;
    } else {
      return _classicBluetoothProvider.classicBConnectedDevice;
    }
  }

  // isConnected Flad
  bool get isConnected {
    if (isBleMode) {
      return _bleProvider.isBleConnected;
    } else {
      return _classicBluetoothProvider.isClassicBConnected;
    }
  }

  void startScan() async {
    final granted = await requestBlePermissions();
    if (!granted) return; // Stop scan if permissions not granted

    if (isBleMode) {
      _bleProvider.startScan();
    } else {
      _classicBluetoothProvider.startScan();
    }
  }

  void stopScan() {
    if (isBleMode) {
      _bleProvider.stopScan();
    } else {
      _classicBluetoothProvider.stopScan();
    }
  }

  void connectToDevice(dynamic device) async {
    if (isBleMode) {
      _bleProvider.connectToBleDevice(device);
    } else {
      await _classicBluetoothProvider.connectToClassicBDevice(device);
      // Listen to incoming data from Classic BT
      _classicBluetoothProvider.classicDataStream.listen(_forwardData);
    }
    notifyListeners();
  }

  void disconnect() {
    if (isBleMode) {
      _bleProvider.disconnect();
    } else {
      _classicBluetoothProvider.disconnect(userInitiated: true);
    }
  }

  // Ble Characteristics
  void subscribeToBleCharacteristic({
    required dynamic serviceId,
    required dynamic characteristicId,
  }) {
    if (!_isBleMode) return;

    _bleProvider.subscribeToCharacteristic(
      serviceId: serviceId,
      characteristicId: characteristicId,
      onData: _forwardData, // Forward BLE data to unified stream
    );
  }

  void unsubscribeFromBleCharacteristic() {
    if (!_isBleMode) return;
    _bleProvider.unsubscribeFromCharacteristic();
  }

  @override
  void dispose() {
    _bleProvider.dispose();
    _classicBluetoothProvider.dispose();
    _incomingDataController.close();
    super.dispose();
  }
}
