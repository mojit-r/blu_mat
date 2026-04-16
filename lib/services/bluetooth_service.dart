import 'package:flutter/services.dart';

class BluetoothService {
  static const MethodChannel _channel = MethodChannel('bluetooth_channel');
  static const EventChannel _eventChannel = EventChannel('bluetooth_events');

  /// 🔥 Unified stream (BLE + A2DP both come here)
  static Stream<Map<String, dynamic>> get events {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event);
    });
  }

  // ================= A2DP =================
  static Future<List<dynamic>> scanA2dp() async {
    final result = await _channel.invokeMethod('scanClassic');
    return result;
  }

  static Future<bool> connectA2dp(String mac) async {
    return await _channel.invokeMethod('connectA2dp', {'address': mac});
  }

  static Future<bool> disconnectA2dp(String mac) async {
    return await _channel.invokeMethod('disconnectA2dp', {'address': mac});
  }

  // ================= BLE =================

  static Future<void> startBleScan() async {
    await _channel.invokeMethod('startBleScan');
  }

  static Future<void> stopBleScan() async {
    await _channel.invokeMethod('stopBleScan');
  }

  static Future<void> connectBle(String id) async {
    await _channel.invokeMethod('connectBle', {'id': id});
  }

  static Future<void> disconnectBle() async {
    await _channel.invokeMethod('disconnectBle');
  }

  static Future<void> readCharacteristic(String service, String char) async {
    await _channel.invokeMethod('readCharacteristic', {
      'service': service,
      'char': char,
    });
  }

  static Future<void> writeCharacteristic(
    String service,
    String char,
    List<int> value,
  ) async {
    await _channel.invokeMethod('writeCharacteristic', {
      'service': service,
      'char': char,
      'value': value,
    });
  }

  static Future<void> enableNotifications(String service, String char) async {
    await _channel.invokeMethod('enableNotifications', {
      'service': service,
      'char': char,
    });
  }
}
