import 'package:flutter/material.dart';

class ConnectionProvider extends ChangeNotifier {
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Toggle connection state
  void toggleConnection() {
    _isConnected = !_isConnected;
    notifyListeners();
  }
}
