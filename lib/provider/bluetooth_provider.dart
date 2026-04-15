  import 'dart:async';

  import 'package:blu_mat/services/bluetooth_service.dart';
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
    final A2dpProvider _a2dpProvider = A2dpProvider();

    BluetoothProvider() {
      // Forward BLE provider changes
      _bleProvider.addListener(() {
        notifyListeners();
      });

      // Forward Classic Bluetooth provider changes
      _a2dpProvider.addListener(() {
        notifyListeners();
      });

      BluetoothService.events.listen((event) {
        if (event['type'].startsWith('BLE')) {
          _bleProvider.handleEvent(event);
        } else if (event['type'].startsWith('A2DP')) {
          _a2dpProvider.handleEvent(event);
        }
      });
    }

    bool _isBleMode = true;
    bool get isBleMode => _isBleMode;

    // Unified Data Stream
    // final StreamController<List<int>> _incomingDataController =
    //     StreamController.broadcast();
    // Stream<List<int>> get incomingData => _incomingDataController.stream;

    // void _forwardData(List<int> data) {
    //   _incomingDataController.add(data);
    // }

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
        return _a2dpProvider.isA2dpScanning;
      }
    }

    // scanned Devices
    List<dynamic> get devices {
      if (isBleMode) {
        return _bleProvider.bleDevices;
      } else {
        return _a2dpProvider.a2dpDevices;
      }
    }

    // Connected Device
    dynamic get connectedDevice {
      if (isBleMode) {
        return _bleProvider.bleConnectedDeviceId;
      } else {
        return _a2dpProvider.a2dpConnectedAddress;
      }
    }

    // isConnected Flad
    bool get isConnected {
      if (isBleMode) {
        return _bleProvider.isBleConnected;
      } else {
        return _a2dpProvider.isA2dpConnected;
      }
    }

    void startScan() async {
      final granted = await requestBlePermissions();
      if (!granted) return; // Stop scan if permissions not granted

      if (isBleMode) {
        _bleProvider.startScan();
      } else {
        _a2dpProvider.startScan();
      }
    }

    void stopScan() {
      if (isBleMode) {
        _bleProvider.stopScan();
      } else {
        _a2dpProvider.stopScan();
      }
    }

    void connectToDevice(dynamic device) async {
      if (isBleMode) {
        final id = device['id'];
        if (id != null) {
          _bleProvider.connectToBleDevice(id);
        }
      } else {
        final address = device['address'];
        if (address != null) {
          await _a2dpProvider.connectToA2dpDevice(address);
        }
      }
      notifyListeners();
    }

    void disconnect() {
      if (isBleMode) {
        _bleProvider.disconnect(userInitiated: true);
      } else {
        _a2dpProvider.disconnect(userInitiated: true);
      }
    }

    // Ble Characteristics
    // void subscribeToBleCharacteristic({
    //   required dynamic serviceId,
    //   required dynamic characteristicId,
    // }) {
    //   if (!_isBleMode) return;

    //   _bleProvider.subscribeToCharacteristic(
    //     serviceId: serviceId,
    //     characteristicId: characteristicId,
    //     onData: _forwardData, // Forward BLE data to unified stream
    //   );
    // }

    // void unsubscribeFromBleCharacteristic() {
    //   if (!_isBleMode) return;
    //   _bleProvider.unsubscribeFromCharacteristic();
    // }

    @override
    void dispose() {
      _bleProvider.dispose();
      _a2dpProvider.dispose();
      // _incomingDataController.close();
      super.dispose();
    }
  }
