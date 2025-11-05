import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ClassicBluetoothProvider extends ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  // Stream for incoming Classic BT data
  final StreamController<List<int>> _classicDataController =
      StreamController.broadcast();
  Stream<List<int>> get classicDataStream => _classicDataController.stream;

  // Call this method whenever you receive data from the Classic BT device
  void _onDataReceived(List<int> data) {
    _classicDataController.add(data);
  }

  // --------------
  // Scanning
  // --------------
  List<BluetoothDevice> _classicBDevices = [];
  List<BluetoothDevice> get classicBDevices => _classicBDevices;

  bool _isClassicBScanning = false;
  bool get isClassicBScanning => _isClassicBScanning;

  StreamSubscription<BluetoothDiscoveryResult>? _classicBScanSubscription;

  void startScan() {
    if (isClassicBScanning) return;
    _isClassicBScanning = true;
    _classicBDevices.clear();
    notifyListeners();

    _classicBScanSubscription = _bluetooth.startDiscovery().listen((
      BluetoothDiscoveryResult result,
    ) {
      final device = result.device;
      if (classicBDevices.any((d) => d.address == device.address)) {
        classicBDevices.add(device);
        notifyListeners();
      }
    }, onDone: stopScan);
  }

  Future<void> stopScan() async {
    await _classicBScanSubscription?.cancel();
    _classicBScanSubscription = null;
    _isClassicBScanning = false;
  }

  // --------------
  // Connection
  // --------------
  BluetoothConnection? _classicBConnection;
  BluetoothDevice? _classicBConnectedDevice;
  BluetoothDevice? get classicBConnectedDevice => _classicBConnectedDevice;

  bool get isClassicBConnected => _classicBConnection?.isConnected ?? false;

  Future<void> connectToClassicBDevice(BluetoothDevice device) async {
    if (_classicBConnectedDevice?.address == device.address &&
        isClassicBConnected)
      return;

    await disconnect();

    try {
      _classicBConnection = await BluetoothConnection.toAddress(device.address);
      _classicBConnectedDevice = device;
      notifyListeners();

      _classicBConnection!.input!.listen(
        (Uint8List data) {
          // Handle Incomming data from the device
          debugPrint('Received data: $data');
          // Forward incoming data to the StreamController
          _onDataReceived(data.toList()); // convert Uint8List to List<int>
        },
        onDone: () {
          debugPrint('Disconnected by Remote');
          _classicBConnectedDevice = null;
          _classicBConnection = null;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Connection error: $e');
    }
  }

  Future<void> disconnect() async {
    await _classicBConnection?.close();
    _classicBConnection = null;
    _classicBConnectedDevice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    _classicDataController.close();
    super.dispose();
  }
}
