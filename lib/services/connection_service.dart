import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';

class ConnectionService {
  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(true);
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectionService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check connectivity: $e');
      }
      isConnected.value = false;
    }

    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = isConnected.value;
    isConnected.value = result != ConnectivityResult.none;
    
    // If we just got connection back, try to reconnect to Supabase
    if (!wasConnected && isConnected.value) {
      _attemptReconnection();
    }
  }
  
  Future<void> _attemptReconnection() async {
    try {
      // If we're transitioning to connected state, try to reinitialize Supabase
      // if it wasn't already done
      await SupabaseService.initialize();
      if (kDebugMode) {
        print('Successfully reconnected to Supabase');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to reconnect to Supabase: $e');
      }
    }
  }

  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      isConnected.value = result != ConnectivityResult.none;
      return isConnected.value;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check connectivity: $e');
      }
      isConnected.value = false;
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
} 