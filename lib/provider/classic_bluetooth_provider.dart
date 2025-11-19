import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ClassicBluetoothProvider extends ChangeNotifier {
  // ClassicBluetoothProvider Constructor
  ClassicBluetoothProvider() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      tryReconnect();
    });
  }

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
      if (!classicBDevices.any((d) => d.address == device.address)) {
        classicBDevices.add(device);
        notifyListeners();
      }
    }, onDone: stopScan);
  }

  Future<void> stopScan() async {
    await _classicBScanSubscription?.cancel();
    _classicBScanSubscription = null;
    _isClassicBScanning = false;
    notifyListeners();
  }

  // --------------
  // Connection
  // --------------
  BluetoothConnection? _classicBConnection;
  BluetoothDevice? _classicBConnectedDevice;
  BluetoothDevice? get classicBConnectedDevice => _classicBConnectedDevice;

  bool get isClassicBConnected => _classicBConnection?.isConnected ?? false;

  bool _userInitiatedDisconnect = false;
  BluetoothDevice? _lastClassicBConnectedDevice;

  // connect to Devices
  Future<void> connectToClassicBDevice(BluetoothDevice device) async {
    if (_classicBConnectedDevice?.address == device.address &&
        isClassicBConnected)
      return;

    await disconnect(userInitiated: false);

    try {
      _classicBConnection = await BluetoothConnection.toAddress(device.address);
      _classicBConnectedDevice = device;
      _userInitiatedDisconnect = false;
      _lastClassicBConnectedDevice = device;
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
    if (isClassicBScanning) return;
    // 3. No last device to reconnect to
    if (_lastClassicBConnectedDevice == null) return;
    // 4. If already connected — nothing to do
    if (isClassicBConnected) return;

    connectToClassicBDevice(_lastClassicBConnectedDevice!);
  }

  // Disconnect
  Future<void> disconnect({bool userInitiated = false}) async {
    _userInitiatedDisconnect = userInitiated;
    await _classicBConnection?.close();
    _classicBConnection = null;
    _classicBConnectedDevice = null;
    if (_userInitiatedDisconnect) {
      _lastClassicBConnectedDevice =
          null; // this will preveny storing previously connected devices
    }
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
