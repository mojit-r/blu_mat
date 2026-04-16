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

  // Service UUID and Characteristic
  String? writeChar;
  String? notifyChar;
  String? serviceId;

  // const service = "YOUR_SERVICE_UUID";
  // const char = "YOUR_CHAR_UUID";    

  String _hexInput = '';
  String get hexInput => _hexInput;

  void handleEvent(Map<String, dynamic> event) {
    final type = event['type'];

    switch (type) {
      case 'ERROR':
        _bleConnectedDeviceId = null;
        _isBleConnected = false;
        debugPrint('BLE ERROR: ${event['status']}');
        if (!_userInitiatedDisconnect && _lastBleConnectedDeviceId != null) {
          _scheduleReconnect();
        }
        notifyListeners();
        debugPrint('❌ ERROR: ${event['message']}');
        break;

      case 'BLE_SCAN':
        final device = {
          'name': (event['name'] ?? 'Unknown').toString(),
          'id': event['id'].toString(),
        };
        final exists = _bleDevices.any((d) => d['id'] == device['id']);
        if (!exists) {
          _bleDevices.add(device);
          notifyListeners();
        }
        debugPrint('📡 Found: ${device['name']}');
        break;

      case 'BLE_CONNECTION':
        final state = event['state'];
        final id = event['id'];
        debugPrint('🔌 Connection: $state');

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
        }
        notifyListeners();
        break;

      case 'BLE_SERVICES':
        debugPrint('🧩 Services discovered');
        final services = (event['services'] as List)
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        for (var s in services) {
          debugPrint('Service: ${s['uuid']}');
          for (var c in s['characteristics']) {
            final char = Map<String, dynamic>.from(c);
            debugPrint('   👉 CHAR: ${char['uuid']}');
            debugPrint('      ⚙ props: ${char['properties']}');
          }
        }
        // SETUP after SERVICES DISCOVERED
        _setupDevice(services);
        break;

      case 'BLE_WRITE_SENT':
        debugPrint("📤 Sent: ${event['value']}");
        break;

      case 'BLE_WRITE':
        debugPrint('✅ Write result: ${event['status']}');
        // // 🔥 ADD THIS
        // Future.delayed(const Duration(milliseconds: 300), () {
        //   BluetoothService.readCharacteristic(serviceId!, notifyChar!);
        // });
        break;

      case 'BLE_NOTIFY':
        debugPrint('📥 Notify: ${event['value']}');
        break;

      // case 'NOTIFY_ENABLED':
      //   debugPrint('✅ Notifications enabled');
      //   break;

      case 'BLE_READ':
        debugPrint('📖 Read: ${event['value']}');
        break;
    }
  }

  Future<void> _setupDevice(List<Map<String, dynamic>> services) async {
    await Future.delayed(const Duration(milliseconds: 800));

    for (var s in services) {
      for (var c in s['characteristics']) {
        final char = Map<String, dynamic>.from(c);
        final props = char['properties'];
        debugPrint(props.toString());

        if ((props & 8) != 0 || (props & 4) != 0) {
          writeChar = char['uuid'];
          serviceId = s['uuid'];
          debugPrint('✍️ WRITE CHAR FOUND: $writeChar');
        }

        if ((props & 16) != 0) {
          notifyChar = char['uuid'];
          debugPrint('📡 NOTIFY CHAR FOUND: $notifyChar');
        }
      }
    }
    if (serviceId == null || writeChar == null) {
      debugPrint('❌ No WRITE characteristic found');
      return;
    }
    
    _sendInitialCommand();
    // Enable live updates
    // await BluetoothService.enableNotifications(service, char);
    // if (notifyChar != null) {
    //   await Future.delayed(const Duration(milliseconds: 500));
    //   await BluetoothService.enableNotifications(serviceId!, notifyChar!);
    // }

    // Optional: get initial state (ONLY if needed)
    // await BluetoothService.readCharacteristic(service, char);
  }

  void _sendInitialCommand() async {
    // await BluetoothService.writeCharacteristic(
    //   service,
    //   char,
    //   hexToBytes('06320A50'),
    // );
    await BluetoothService.writeCharacteristic(
      serviceId!,
      writeChar!,
      hexToBytes('09560000'),
    );
  }

  void updateHex(String value) {
    _hexInput = value;
  }

  Future<void> sendHexCommand() async {
    if (serviceId == null || writeChar == null) {
      debugPrint('❌ Service/Char not ready');
      return;
    }
  
    if (_hexInput.isEmpty) {
      debugPrint('❌ Empty input');
      return;
    }
  
    try {
      final bytes = hexToBytes(_hexInput);
      debugPrint('📤 Sending: $bytes');
  
      await BluetoothService.writeCharacteristic(
        serviceId!,
        writeChar!,
        bytes,
      );
    } catch (e) {
      debugPrint('❌ Invalid HEX: $e');
    }
  }

  List<int> hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    return List.generate(
      hex.length ~/ 2,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    );
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
    stopScan();
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
