import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import '../flutter/frontend_server_manager.dart';
import '../util/logger.dart';

/// Represents a connected VM service for a specific runtime
class RuntimeConnection {
  final String name;
  final String uri;
  VmService? service;
  bool connected = false;

  RuntimeConnection({required this.name, required this.uri});
}

/// Enum representing which runtime to reload
enum RuntimeTarget {
  /// Reload the server runtime (dart_dll on Server thread)
  server,

  /// Reload the client runtime (Flutter on Render thread)
  client,

  /// Reload both runtimes
  all,
}

/// Client for connecting to Dart VM services and triggering hot reload.
/// Supports dual runtime architecture with separate server and client VMs.
class HotReloadClient {
  static const String defaultServerUri = 'ws://127.0.0.1:5858/ws';
  static const int maxRetries = 60;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Legacy single-runtime support
  final String uri;
  VmService? _service;
  bool _cancelled = false;

  /// Dual-runtime connections
  RuntimeConnection? _serverConnection;
  RuntimeConnection? _clientConnection;

  /// Whether we're operating in dual-runtime mode
  bool _dualRuntimeMode = false;

  /// Frontend server manager for incremental compilation (optional)
  FrontendServerManager? _frontendServer;

  HotReloadClient({this.uri = defaultServerUri});

  /// Whether dual-runtime mode is enabled
  bool get isDualRuntimeMode => _dualRuntimeMode;

  /// Server VM service URI (if connected)
  String? get serverUri => _serverConnection?.uri;

  /// Client VM service URI (if connected)
  String? get clientUri => _clientConnection?.uri;

  /// Whether server runtime is connected
  bool get isServerConnected => _serverConnection?.connected ?? false;

  /// Whether client runtime is connected
  bool get isClientConnected => _clientConnection?.connected ?? false;

  /// Set the frontend server manager for incremental compilation
  void setFrontendServer(FrontendServerManager frontendServer) {
    _frontendServer = frontendServer;
  }

  /// Cancel any ongoing connection attempts
  void cancel() {
    _cancelled = true;
  }

  /// Configure dual-runtime mode with server and client URIs
  void configureDualRuntime({
    required String serverUri,
    required String clientUri,
  }) {
    _dualRuntimeMode = true;
    _serverConnection = RuntimeConnection(name: 'Server', uri: serverUri);
    _clientConnection = RuntimeConnection(name: 'Client', uri: clientUri);
    Logger.debug('Configured dual-runtime mode');
    Logger.debug('  Server VM: $serverUri');
    Logger.debug('  Client VM: $clientUri');
  }

  /// Set server URI dynamically (when parsed from output)
  void setServerUri(String wsUri) {
    _dualRuntimeMode = true;
    _serverConnection = RuntimeConnection(name: 'Server', uri: wsUri);
    Logger.debug('Server VM service detected: $wsUri');
  }

  /// Set client URI dynamically (when parsed from output)
  void setClientUri(String wsUri) {
    _dualRuntimeMode = true;
    _clientConnection = RuntimeConnection(name: 'Client', uri: wsUri);
    Logger.debug('Client VM service detected: $wsUri');
  }

  /// Connect to the Dart VM service(s).
  /// In dual-runtime mode, connects to both server and client VMs.
  /// Returns true if at least one connection succeeded.
  Future<bool> connect() async {
    _cancelled = false;

    if (_dualRuntimeMode) {
      return _connectDualRuntime();
    } else {
      return _connectSingleRuntime();
    }
  }

  /// Connect in single-runtime mode (legacy)
  Future<bool> _connectSingleRuntime() async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (_cancelled) {
        Logger.debug('Connection cancelled');
        return false;
      }
      try {
        Logger.debug(
            'Connecting to Dart VM (attempt ${attempt + 1}/$maxRetries)...');
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

  /// Connect in dual-runtime mode
  Future<bool> _connectDualRuntime() async {
    final futures = <Future<bool>>[];

    if (_serverConnection != null) {
      futures.add(_connectToRuntime(_serverConnection!));
    }
    if (_clientConnection != null) {
      futures.add(_connectToRuntime(_clientConnection!));
    }

    if (futures.isEmpty) {
      Logger.warning('No runtime URIs configured for dual-runtime mode');
      return false;
    }

    final results = await Future.wait(futures);
    final anyConnected = results.any((r) => r);

    if (anyConnected) {
      _printConnectionStatus();
    }

    return anyConnected;
  }

  /// Connect to a specific runtime
  Future<bool> _connectToRuntime(RuntimeConnection connection) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (_cancelled) {
        Logger.debug('Connection to ${connection.name} cancelled');
        return false;
      }
      try {
        Logger.debug(
            'Connecting to ${connection.name} VM (attempt ${attempt + 1}/$maxRetries)...');
        connection.service = await vmServiceConnectUri(connection.uri);

        // Verify connection
        await connection.service!.getVersion();
        connection.connected = true;
        Logger.debug('Connected to ${connection.name} VM');
        return true;
      } catch (e) {
        if (_cancelled) {
          Logger.debug('Connection to ${connection.name} cancelled');
          return false;
        }
        Logger.debug('${connection.name} connection failed: $e');
        await Future.delayed(retryDelay);
      }
    }

    Logger.warning('Failed to connect to ${connection.name} VM after $maxRetries attempts');
    return false;
  }

  /// Print connection status for both runtimes
  void _printConnectionStatus() {
    Logger.newLine();
    Logger.info('Hot reload enabled:');
    if (_serverConnection != null) {
      final status = _serverConnection!.connected ? '✓' : '✗';
      Logger.step('  Server VM: $status ${_serverConnection!.uri}');
    }
    if (_clientConnection != null) {
      final status = _clientConnection!.connected ? '✓' : '✗';
      Logger.step('  Client VM: $status ${_clientConnection!.uri}');
    }
  }

  /// Reload the server runtime only
  Future<bool> reloadServer({List<String>? changedFiles}) async {
    if (!_dualRuntimeMode || _serverConnection == null) {
      Logger.warning('Server runtime not configured');
      return false;
    }
    return _reloadRuntime(_serverConnection!, changedFiles: changedFiles);
  }

  /// Reload the client runtime only
  Future<bool> reloadClient({List<String>? changedFiles}) async {
    if (!_dualRuntimeMode || _clientConnection == null) {
      Logger.warning('Client runtime not configured');
      return false;
    }
    return _reloadRuntime(
      _clientConnection!,
      changedFiles: changedFiles,
      useFlutterReassemble: true,
    );
  }

  /// Reload both server and client runtimes
  Future<bool> reloadAll({List<String>? changedFiles}) async {
    if (!_dualRuntimeMode) {
      // Fall back to single runtime reload
      return reload(changedFiles: changedFiles);
    }

    final futures = <Future<bool>>[];

    if (_serverConnection?.connected ?? false) {
      futures.add(_reloadRuntime(_serverConnection!, changedFiles: changedFiles));
    }
    if (_clientConnection?.connected ?? false) {
      futures.add(_reloadRuntime(
        _clientConnection!,
        changedFiles: changedFiles,
        useFlutterReassemble: true,
      ));
    }

    if (futures.isEmpty) {
      Logger.warning('No runtimes connected');
      return false;
    }

    final results = await Future.wait(futures);
    return results.every((r) => r);
  }

  /// Reload a specific runtime based on target
  Future<bool> reloadTarget(
    RuntimeTarget target, {
    List<String>? changedFiles,
  }) async {
    switch (target) {
      case RuntimeTarget.server:
        return reloadServer(changedFiles: changedFiles);
      case RuntimeTarget.client:
        return reloadClient(changedFiles: changedFiles);
      case RuntimeTarget.all:
        return reloadAll(changedFiles: changedFiles);
    }
  }

  /// Reload a specific runtime connection
  Future<bool> _reloadRuntime(
    RuntimeConnection connection, {
    List<String>? changedFiles,
    bool useFlutterReassemble = false,
  }) async {
    if (!connection.connected || connection.service == null) {
      Logger.warning('${connection.name} runtime not connected');
      return false;
    }

    try {
      // If we have frontend_server and changed files, do incremental compile
      // (only for client runtime with Flutter)
      String? deltaPath;
      if (useFlutterReassemble &&
          _frontendServer != null &&
          changedFiles != null &&
          changedFiles.isNotEmpty) {
        Logger.debug(
            'Performing incremental compilation for ${changedFiles.length} files');
        final result = await _frontendServer!.recompile(changedFiles);
        if (!result.success) {
          Logger.error(
              'Compilation failed: ${result.errorMessage ?? result.errors.join('\n')}');
          return false;
        }
        deltaPath = result.outputPath;
        Logger.debug('Incremental compile succeeded: $deltaPath');
      }

      final vm = await connection.service!.getVM();

      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolateId = isolateRef.id;
        if (isolateId == null) continue;

        try {
          final report = await connection.service!.reloadSources(
            isolateId,
            rootLibUri: deltaPath,
          );

          if (report.success == true) {
            Logger.debug(
                '[${connection.name}] Reloaded isolate: ${isolateRef.name}');

            // Call Flutter reassemble if this is the client runtime
            if (useFlutterReassemble) {
              await _flutterReassemble(connection.service!, isolateId);
            }
          } else {
            Logger.warning(
                '[${connection.name}] Failed to reload isolate: ${isolateRef.name}');
            if (useFlutterReassemble) {
              _frontendServer?.reject();
            }
            return false;
          }
        } catch (e) {
          // Some isolates can't be reloaded (system isolates)
          Logger.debug(
              '[${connection.name}] Skipping isolate ${isolateRef.name}: $e');
        }
      }

      // Accept the compilation after successful reload
      if (useFlutterReassemble) {
        _frontendServer?.accept();
      }

      return true;
    } catch (e) {
      Logger.error('[${connection.name}] Hot reload failed: $e');
      if (useFlutterReassemble) {
        _frontendServer?.reject();
      }
      return false;
    }
  }

  /// Trigger a hot reload (legacy single-runtime support)
  /// Returns true if successful
  ///
  /// [changedFiles] - Optional list of file paths that have changed.
  /// If provided with a frontend server, incremental compilation will be used.
  Future<bool> reload({List<String>? changedFiles}) async {
    if (_dualRuntimeMode) {
      return reloadAll(changedFiles: changedFiles);
    }

    if (_service == null) {
      Logger.error('Not connected to Dart VM');
      return false;
    }

    try {
      // If we have frontend_server and changed files, do incremental compile
      String? deltaPath;
      if (_frontendServer != null &&
          changedFiles != null &&
          changedFiles.isNotEmpty) {
        Logger.debug(
            'Performing incremental compilation for ${changedFiles.length} files');
        final result = await _frontendServer!.recompile(changedFiles);
        if (!result.success) {
          Logger.error(
              'Compilation failed: ${result.errorMessage ?? result.errors.join('\n')}');
          return false;
        }
        deltaPath = result.outputPath;
        Logger.debug('Incremental compile succeeded: $deltaPath');
      }

      final vm = await _service!.getVM();

      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolateId = isolateRef.id;
        if (isolateId == null) continue;

        try {
          final report = await _service!.reloadSources(
            isolateId,
            rootLibUri: deltaPath, // Pass the delta.dill path if available
          );

          if (report.success == true) {
            Logger.debug('Reloaded isolate: ${isolateRef.name}');

            // Call Flutter reassemble to rebuild widgets
            await _flutterReassemble(_service!, isolateId);
          } else {
            Logger.warning('Failed to reload isolate: ${isolateRef.name}');
            // Reject the compilation if reload failed
            _frontendServer?.reject();
            return false;
          }
        } catch (e) {
          // Some isolates can't be reloaded (system isolates)
          Logger.debug('Skipping isolate ${isolateRef.name}: $e');
        }
      }

      // Accept the compilation after successful reload
      _frontendServer?.accept();

      return true;
    } catch (e) {
      Logger.error('Hot reload failed: $e');
      _frontendServer?.reject();
      return false;
    }
  }

  /// Call Flutter reassemble to rebuild widgets
  Future<void> _flutterReassemble(VmService service, String isolateId) async {
    try {
      await service.callServiceExtension(
        'ext.flutter.reassemble',
        isolateId: isolateId,
      );
      Logger.debug('Flutter reassemble completed');
    } catch (e) {
      // Flutter reassemble may not be available on server
      // This is expected, just log at debug level
      Logger.debug('Flutter reassemble not available: $e');
    }
  }

  /// Disconnect from the VM service(s)
  Future<void> disconnect() async {
    if (_dualRuntimeMode) {
      if (_serverConnection?.service != null) {
        await _serverConnection!.service!.dispose();
        _serverConnection!.service = null;
        _serverConnection!.connected = false;
      }
      if (_clientConnection?.service != null) {
        await _clientConnection!.service!.dispose();
        _clientConnection!.service = null;
        _clientConnection!.connected = false;
      }
    } else {
      await _service?.dispose();
      _service = null;
    }
  }

  /// Reset dual-runtime configuration (for reconnection after restart)
  void resetDualRuntime() {
    _serverConnection = null;
    _clientConnection = null;
    _dualRuntimeMode = false;
  }
}
