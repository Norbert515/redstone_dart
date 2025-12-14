import 'dart:async';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client for connecting to the Dart VM service and triggering hot reloads.
class HotReloadClient {
  VmService? _vmService;
  String? _mainIsolateId;

  /// Whether the client is currently connected to the VM service.
  bool get isConnected => _vmService != null && _mainIsolateId != null;

  /// Attempts to connect to the Dart VM service.
  ///
  /// Retries connection until successful or max retries reached.
  /// Returns true on success, false on failure after all retries.
  Future<bool> connect({
    String uri = 'ws://127.0.0.1:5858/ws',
    int maxRetries = 60,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _vmService = await vmServiceConnectUri(uri);

        // Get the main isolate
        final vm = await _vmService!.getVM();
        if (vm.isolates != null && vm.isolates!.isNotEmpty) {
          _mainIsolateId = vm.isolates!.first.id;
          return true;
        }

        // VM connected but no isolates yet, will retry
        await _vmService?.dispose();
        _vmService = null;
      } on SocketException {
        // VM service not available yet, expected during startup
      } on WebSocketException {
        // WebSocket connection failed, expected during startup
      } catch (e) {
        // Other errors, log and retry
        stderr.writeln('[MC-CLI] Connection attempt $attempt failed: $e');
      }

      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    return false;
  }

  /// Triggers a hot reload on the connected VM.
  ///
  /// Returns the [ReloadReport] from the VM service.
  /// Throws if not connected.
  Future<ReloadReport> reload() async {
    if (_vmService == null || _mainIsolateId == null) {
      throw StateError('Not connected to VM service. Call connect() first.');
    }

    return await _vmService!.reloadSources(
      _mainIsolateId!,
      force: true,
    );
  }

  /// Disconnects from the VM service and cleans up resources.
  Future<void> disconnect() async {
    await _vmService?.dispose();
    _vmService = null;
    _mainIsolateId = null;
  }
}
