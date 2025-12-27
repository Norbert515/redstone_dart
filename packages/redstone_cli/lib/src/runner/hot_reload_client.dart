import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import '../util/logger.dart';

/// Client for connecting to Dart VM service and triggering hot reload
class HotReloadClient {
  static const String defaultUri = 'ws://127.0.0.1:5858/ws';
  static const int maxRetries = 60;
  static const Duration retryDelay = Duration(seconds: 2);

  final String uri;
  VmService? _service;
  bool _cancelled = false;

  HotReloadClient({this.uri = defaultUri});

  /// Cancel any ongoing connection attempts
  void cancel() {
    _cancelled = true;
  }

  /// Connect to the Dart VM service
  /// Returns true if connected successfully
  Future<bool> connect() async {
    _cancelled = false; // Reset cancelled flag for fresh connection attempts
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (_cancelled) {
        Logger.debug('Connection cancelled');
        return false;
      }
      try {
        Logger.debug('Connecting to Dart VM (attempt ${attempt + 1}/$maxRetries)...');
        _service = await vmServiceConnectUri(uri);

        // Verify connection
        await _service!.getVersion();
        return true;
      } catch (e) {
        if (_cancelled) {
          Logger.debug('Connection cancelled');
          return false;
        }
        Logger.debug('Connection failed: $e');
        await Future.delayed(retryDelay);
      }
    }

    return false;
  }

  /// Trigger a hot reload
  /// Returns true if successful
  Future<bool> reload() async {
    if (_service == null) {
      Logger.error('Not connected to Dart VM');
      return false;
    }

    try {
      final vm = await _service!.getVM();

      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolateId = isolateRef.id;
        if (isolateId == null) continue;

        try {
          final report = await _service!.reloadSources(isolateId);

          if (report.success == true) {
            Logger.debug('Reloaded isolate: ${isolateRef.name}');
          } else {
            Logger.warning('Failed to reload isolate: ${isolateRef.name}');
          }
        } catch (e) {
          // Some isolates can't be reloaded (system isolates)
          Logger.debug('Skipping isolate ${isolateRef.name}: $e');
        }
      }

      return true;
    } catch (e) {
      Logger.error('Hot reload failed: $e');
      return false;
    }
  }

  /// Disconnect from the VM service
  Future<void> disconnect() async {
    await _service?.dispose();
    _service = null;
  }
}
