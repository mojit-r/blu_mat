import 'package:flutter/services.dart';

class A2dpService {
  static const MethodChannel _channel = MethodChannel('a2dp_channel');
  static const EventChannel _eventChannel = EventChannel('bluetooth_events');

  // Stream for listening events
  static Stream<Map<dynamic, dynamic>> get events {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<dynamic, dynamic>.from(event);
    });
  }

  static Future<List<dynamic>> scan() async {
    final result = await _channel.invokeMethod('scanClassic');
    return result;
  }

  static Future<bool> connect(String mac) async {
    return await _channel.invokeMethod('connectA2dp', {'address': mac});
  }

  static Future<bool> disconnect(String mac) async {
    return await _channel.invokeMethod('disconnectA2dp', {'address': mac});
  }
}
