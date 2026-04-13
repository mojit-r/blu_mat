  import 'dart:async';

  import 'package:flutter/material.dart';
  import 'ble_provider.dart';
  import 'a2dp_provider.dart';

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
    final A2dpProvider _a2dpluetoothProvider = A2dpProvider();

    BluetoothProvider() {
      // Forward BLE provider changes
      _bleProvider.addListener(() {
        notifyListeners();
      });

      // Forward Classic Bluetooth provider changes
      _a2dpluetoothProvider.addListener(() {
        notifyListeners();
      });
    }

    bool _isBleMode = true;
    bool get isBleMode => _isBleMode;

    // Unified Data Stream
    final StreamController<List<int>> _incomingDataController =
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
        return _a2dpluetoothProvider.isA2dpScanning;
      }
    }

    // scanned Devices
    List<dynamic> get devices {
      if (isBleMode) {
        return _bleProvider.bleDevices;
      } else {
        return _a2dpluetoothProvider.a2dpDevices;
      }
    }

    // Connected Device
    dynamic get connectedDevice {
      if (isBleMode) {
        return _bleProvider.bleConnectedDevice;
      } else {
        return _a2dpluetoothProvider.a2dpConnectedAddress;
      }
    }

    // isConnected Flad
    bool get isConnected {
      if (isBleMode) {
        return _bleProvider.isBleConnected;
      } else {
        return _a2dpluetoothProvider.isA2dpConnected;
      }
    }

    void startScan() async {
      final granted = await requestBlePermissions();
      if (!granted) return; // Stop scan if permissions not granted

      if (isBleMode) {
        _bleProvider.startScan();
      } else {
        _a2dpluetoothProvider.startScan();
      }
    }

    void stopScan() {
      if (isBleMode) {
        _bleProvider.stopScan();
      } else {
        _a2dpluetoothProvider.stopScan();
      }
    }

    void connectToDevice(dynamic device) async {
      if (isBleMode) {
        _bleProvider.connectToBleDevice(device);
      } else {
        final address = device['address'];
        if (address != null) {
          await _a2dpluetoothProvider.connectToA2dpDevice(address);
        }
      }
      notifyListeners();
    }

    void disconnect() {
      if (isBleMode) {
        _bleProvider.disconnect(userInitiated: true);
      } else {
        _a2dpluetoothProvider.disconnect(userInitiated: true);
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
      _a2dpluetoothProvider.dispose();
      _incomingDataController.close();
      super.dispose();
    }
  }
