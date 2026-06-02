import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor internet connectivity
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService() {
    _init();
  }

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Future<void> _init() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> result) {
    final wasOnline = _isOnline;
    _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  /// Check connectivity manually
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    return _isOnline;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
