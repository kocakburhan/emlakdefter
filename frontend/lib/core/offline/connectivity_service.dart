import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionStatus { online, offline, unknown }

/// Monitors network connectivity changes and notifies listeners.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _status = ConnectionStatus.unknown;

  ConnectionStatus get status => _status;
  Stream<ConnectionStatus> get stream => _controller.stream;

  /// Returns true if currently online.
  bool get isOnline => _status == ConnectionStatus.online;

  Future<void> initialize() async {
    // Get initial status
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _status == ConnectionStatus.online;

    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      _status = ConnectionStatus.offline;
    } else {
      _status = ConnectionStatus.online;
    }

    _controller.add(_status);

    // Trigger sync when coming back online
    if (!wasOnline && _status == ConnectionStatus.online) {
      _onReconnected();
    }
  }

  /// Override point for sync trigger — set by SyncService.
  VoidCallback? onReconnect;
  /// Override point for cache refresh — set at app level (e.g., refetch properties).
  VoidCallback? onReconnectRefresh;

  void _onReconnected() {
    onReconnect?.call();
    onReconnectRefresh?.call();
  }

  /// Check current connectivity synchronously.
  Future<ConnectionStatus> check() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return ConnectionStatus.offline;
    }
    return ConnectionStatus.online;
  }

  void dispose() {
    _controller.close();
  }
}
