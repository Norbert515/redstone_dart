import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
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

    // In dual-runtime mode, consider success if client (Flutter) succeeds
    // Server reload may fail since embedded Dart VM has different reload behavior
    final serverIndex = _serverConnection?.connected == true ? 0 : -1;
    final clientIndex = _clientConnection?.connected == true ?
        (serverIndex >= 0 ? 1 : 0) : -1;

    if (clientIndex >= 0 && results[clientIndex]) {
      // Client succeeded, that's what matters for UI updates
      return true;
    }

    // Fall back to requiring all to succeed
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

  /// Reload a specific runtime connection (dual-runtime mode)
  Future<bool> _reloadRuntime(
    RuntimeConnection connection, {
    List<String>? changedFiles,
    bool useFlutterReassemble = false,
  }) async {
    if (!connection.connected || connection.service == null) {
      Logger.warning('${connection.name} runtime not connected');
      return false;
    }

    // Skip server reload - the server Dart VM doesn't have Flutter libraries
    // and cannot load Flutter kernel deltas. Server-side Dart code is minimal
    // and hot reload for server is not currently supported.
    if (!useFlutterReassemble) {
      Logger.debug('[${connection.name}] Skipping reload (server runtime not supported)');
      return true;  // Return success to not block client reload
    }

    return _performReload(
      service: connection.service!,
      runtimeName: connection.name,
      changedFiles: changedFiles,
      // In dual-runtime mode, reset compiler and auto-discover files
      resetCompiler: true,
      autoDiscoverFiles: true,
      pauseDuringReload: true,
    );
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

    return _performReload(
      service: _service!,
      runtimeName: null,
      changedFiles: changedFiles,
      // Legacy single-runtime mode: no reset, no auto-discover, no pause
      resetCompiler: false,
      autoDiscoverFiles: false,
      pauseDuringReload: false,
    );
  }

  /// Core hot reload logic shared between single and dual runtime modes
  ///
  /// [service] - The VM service to use for reload
  /// [runtimeName] - Optional name for logging (e.g., "Client", "Server")
  /// [changedFiles] - List of files that changed (if known)
  /// [resetCompiler] - Whether to reset frontend_server before recompile
  ///   (needed for embedded Flutter to avoid "class not loaded yet" errors)
  /// [autoDiscoverFiles] - Whether to scan for recently modified files if none provided
  /// [pauseDuringReload] - Whether to pause isolates during reload
  Future<bool> _performReload({
    required VmService service,
    required String? runtimeName,
    List<String>? changedFiles,
    required bool resetCompiler,
    required bool autoDiscoverFiles,
    required bool pauseDuringReload,
  }) async {
    final logPrefix = runtimeName != null ? '[$runtimeName] ' : '';

    try {
      String? deltaPath;
      if (_frontendServer != null) {
        // Reset compiler if requested (produces full kernel instead of delta)
        if (resetCompiler) {
          _frontendServer!.reset();
        }

        // Determine which files to recompile
        List<String>? filesToRecompile;
        if (changedFiles != null && changedFiles.isNotEmpty) {
          filesToRecompile = changedFiles;
        } else if (autoDiscoverFiles) {
          // Scan for recently modified .dart files
          filesToRecompile = await _findRecentlyModifiedFiles(_frontendServer!.entryPoint);
          if (filesToRecompile.isEmpty) {
            filesToRecompile = [_frontendServer!.entryPoint];
          }
        }

        // Only recompile if we have files to compile
        if (filesToRecompile != null && filesToRecompile.isNotEmpty) {
          if (runtimeName != null) {
            Logger.step('${logPrefix}Compiling ${filesToRecompile.length} file(s)...');
          } else {
            Logger.debug('Performing incremental compilation for ${filesToRecompile.length} files');
          }

          final result = await _frontendServer!.recompile(filesToRecompile);
          if (!result.success) {
            Logger.error(
                'Compilation failed: ${result.errorMessage ?? result.errors.join('\n')}');
            return false;
          }
          deltaPath = result.outputPath;

          if (runtimeName != null) {
            Logger.step('${logPrefix}Compilation succeeded');
          } else {
            Logger.debug('Incremental compile succeeded: $deltaPath');
          }
        }
      }

      final vm = await service.getVM();

      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolateId = isolateRef.id;
        if (isolateId == null) continue;

        try {
          final deltaUri = deltaPath != null ? Uri.file(deltaPath).toString() : null;

          final report = await service.reloadSources(
            isolateId,
            rootLibUri: deltaUri,
            force: true,
            pause: pauseDuringReload,
          );

          if (report.success == true) {
            if (runtimeName != null) {
              Logger.step('${logPrefix}Reloaded isolate: ${isolateRef.name}');
            } else {
              Logger.debug('Reloaded isolate: ${isolateRef.name}');
            }

            // Resume isolate if we paused it
            if (pauseDuringReload) {
              try {
                await service.resume(isolateId);
              } catch (e) {
                Logger.debug('${logPrefix}Could not resume isolate (may already be running): $e');
              }
            }

            await _flutterReassemble(service, isolateId);
          } else {
            Logger.warning('${logPrefix}Failed to reload isolate: ${isolateRef.name}');
            _frontendServer?.reject();
            return false;
          }
        } catch (e) {
          Logger.debug('${logPrefix}Skipping isolate ${isolateRef.name}: $e');
        }
      }

      _frontendServer?.accept();
      return true;
    } catch (e) {
      Logger.error('${logPrefix}Hot reload failed: $e');
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
      Logger.step('[Client] Flutter reassemble completed');

      // Schedule a frame to force visual update
      try {
        await service.callServiceExtension(
          'ext.redstone.scheduleFrame',
          isolateId: isolateId,
        );
        Logger.step('[Client] Frame scheduled');
      } catch (e) {
        Logger.debug('[Client] Could not schedule frame: $e');
      }
    } catch (e) {
      // Flutter reassemble may not be available on server
      Logger.warning('[Client] Flutter reassemble failed: $e');
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

  /// Find .dart files that were modified recently (within last 10 seconds)
  /// This is used to detect which files the user has edited for hot reload
  Future<List<String>> _findRecentlyModifiedFiles(String entryPoint) async {
    // entryPoint is like /path/to/packages/client/lib/main.dart
    // We want to search in /path/to/packages/client/lib/
    final libDir = Directory(p.dirname(entryPoint));
    if (!await libDir.exists()) {
      Logger.debug('lib directory not found: ${libDir.path}');
      return [];
    }
    Logger.debug('Searching for modified files in: ${libDir.path}');

    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 10));
    final modifiedFiles = <String>[];

    // Search in the lib/ directory and its subdirectories
    await for (final entity in libDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Skip generated files
        if (entity.path.contains('.dart_tool') ||
            entity.path.contains('.g.dart') ||
            entity.path.contains('.freezed.dart')) {
          continue;
        }
        try {
          final stat = await entity.stat();
          if (stat.modified.isAfter(cutoffTime)) {
            modifiedFiles.add(entity.path);
            Logger.debug('Found recently modified: ${entity.path}');
          }
        } catch (_) {
          // Skip files we can't stat
        }
      }
    }

    return modifiedFiles;
  }
}
