import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/logger.dart';
import 'flutter_sdk.dart';

/// Result of an incremental compilation
class IncrementalCompileResult {
  /// Whether the compilation succeeded
  final bool success;

  /// Path to the output .dill file
  final String? outputPath;

  /// Error message if compilation failed
  final String? errorMessage;

  /// List of compilation errors from the compiler
  final List<String> errors;

  /// List of compilation warnings from the compiler
  final List<String> warnings;

  IncrementalCompileResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Manages a persistent frontend_server process for incremental compilation
///
/// The frontend_server can be run in incremental mode, where it stays running
/// and accepts recompile commands. This is much faster than starting a fresh
/// compilation each time, as it can reuse parsed/analyzed state.
///
/// This is the same mechanism Flutter uses for hot reload.
class FrontendServerManager {
  final FlutterSdk flutterSdk;
  final String entryPoint;
  final String outputDir;
  final String packagesPath;
  final bool trackWidgetCreation;

  Process? _process;
  String _boundaryKey = '';

  final StreamController<String> _stdoutController = StreamController<String>.broadcast();
  final StreamController<String> _stderrController = StreamController<String>.broadcast();

  /// Buffer for collecting output between boundary markers
  final StringBuffer _outputBuffer = StringBuffer();

  /// Completer for the current compilation
  Completer<IncrementalCompileResult>? _currentCompile;

  /// Whether we're waiting for an initial compile (no boundary key)
  bool _isInitialCompile = false;

  /// Whether the server is currently running
  bool get isRunning => _process != null;

  /// Stream of stdout output (for debugging)
  Stream<String> get stdout => _stdoutController.stream;

  /// Stream of stderr output (for debugging)
  Stream<String> get stderr => _stderrController.stream;

  FrontendServerManager({
    required this.flutterSdk,
    required this.entryPoint,
    required this.outputDir,
    required this.packagesPath,
    this.trackWidgetCreation = true,
  });

  /// Create a FrontendServerManager by locating the Flutter SDK automatically
  static FrontendServerManager? create({
    required String entryPoint,
    required String outputDir,
    required String packagesPath,
    bool trackWidgetCreation = true,
  }) {
    final sdk = FlutterSdk.locate();
    if (sdk == null) return null;
    return FrontendServerManager(
      flutterSdk: sdk,
      entryPoint: entryPoint,
      outputDir: outputDir,
      packagesPath: packagesPath,
      trackWidgetCreation: trackWidgetCreation,
    );
  }

  /// Start the frontend_server in incremental mode
  ///
  /// Returns the path to the initial compiled kernel, or throws if startup fails.
  Future<String> start() async {
    if (_process != null) {
      throw StateError('Frontend server is already running');
    }

    // Create output directory if needed
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // Generate a unique boundary key for this session
    _boundaryKey = 'boundary_${DateTime.now().millisecondsSinceEpoch}';

    final frontendServerPath = flutterSdk.bestFrontendServerPath;
    if (!File(frontendServerPath).existsSync()) {
      throw Exception('Frontend server not found at: $frontendServerPath');
    }

    final initialOutputPath = p.join(outputDir, 'kernel.dill');

    final args = <String>[
      frontendServerPath,
      '--sdk-root=${flutterSdk.sdkRoot}',
      '--incremental',
      '--target=flutter',
      '--packages=$packagesPath',
      '--output-dill=$initialOutputPath',
    ];

    if (trackWidgetCreation) {
      args.add('--track-widget-creation');
    }

    // Determine the correct Dart runtime to use
    // AOT snapshots (frontend_server_aot.dart.snapshot) need dartaotruntime
    final isAotSnapshot = frontendServerPath.contains('_aot.');
    final dartRuntime = isAotSnapshot
        ? flutterSdk.dartAotRuntimePath
        : flutterSdk.dartPath;

    Logger.debug('Starting frontend_server in incremental mode');
    Logger.debug('Command: $dartRuntime ${args.join(' ')}');

    _process = await Process.start(
      dartRuntime,
      args,
      workingDirectory: p.dirname(entryPoint),
    );

    // Handle stdout - parse boundary-delimited responses
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);

    // Handle stderr
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _stderrController.add(line);
      Logger.debug('[frontend_server stderr] $line');
    });

    // Handle process exit
    _process!.exitCode.then((code) {
      Logger.debug('Frontend server exited with code: $code');
      _process = null;
      _currentCompile?.completeError(
        Exception('Frontend server exited unexpectedly with code: $code'),
      );
    });

    // Perform initial compilation
    final result = await _compileInitial();
    if (!result.success) {
      await stop();
      throw Exception(
        'Initial compilation failed: ${result.errorMessage ?? result.errors.join('\n')}',
      );
    }

    return result.outputPath!;
  }

  /// Perform the initial compilation (compile command)
  Future<IncrementalCompileResult> _compileInitial() async {
    _currentCompile = Completer<IncrementalCompileResult>();
    _isInitialCompile = true;

    // Send compile command with entry point
    Logger.debug('Sending initial compile command: compile $entryPoint');
    _process!.stdin.writeln('compile $entryPoint');

    return _currentCompile!.future;
  }

  /// Recompile with changed files
  ///
  /// [invalidatedFiles] - List of file paths that have changed since last compile.
  /// Returns the path to the delta .dill file containing only the changes.
  Future<IncrementalCompileResult> recompile(List<String> invalidatedFiles) async {
    if (_process == null) {
      throw StateError('Frontend server is not running');
    }

    _currentCompile = Completer<IncrementalCompileResult>();
    _isInitialCompile = false;

    // Send recompile command with boundary key
    Logger.debug('Sending recompile command for ${invalidatedFiles.length} files');
    _process!.stdin.writeln('recompile $_boundaryKey');

    // Send each invalidated file
    for (final file in invalidatedFiles) {
      _process!.stdin.writeln(file);
    }

    // End with boundary key
    _process!.stdin.writeln(_boundaryKey);

    return _currentCompile!.future;
  }

  /// Accept the last compilation
  ///
  /// This tells the server that the compilation was successfully applied,
  /// allowing it to clear temporary state.
  void accept() {
    if (_process == null) return;
    Logger.debug('Accepting last compilation');
    _process!.stdin.writeln('accept');
  }

  /// Reject the last compilation
  ///
  /// This tells the server to revert to the previous state, useful when
  /// hot reload fails.
  void reject() {
    if (_process == null) return;
    Logger.debug('Rejecting last compilation');
    _process!.stdin.writeln('reject');
  }

  /// Stop the frontend_server
  Future<void> stop() async {
    if (_process == null) return;

    Logger.debug('Stopping frontend_server');

    try {
      _process!.stdin.writeln('quit');
      await _process!.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Logger.debug('Frontend server did not exit gracefully, killing');
          _process!.kill();
          return -1;
        },
      );
    } catch (e) {
      Logger.debug('Error stopping frontend_server: $e');
      _process?.kill();
    }

    _process = null;
    await _stdoutController.close();
    await _stderrController.close();
  }

  /// Handle a line of stdout from the frontend_server
  void _handleStdoutLine(String line) {
    _stdoutController.add(line);
    Logger.debug('[frontend_server stdout] $line');

    // Parse the output for compilation results
    // The frontend_server protocol uses boundary-based responses for both initial compile and recompile:
    //
    // Response format:
    // result <boundary_key>
    // <boundary_key>
    // +file:///path/to/dependency1.dart
    // +file:///path/to/dependency2.dart
    // ...
    // <boundary_key> /path/to/output.dill <error_count>
    //
    // The final line format: "<boundary_key> <output_path> <error_count>"
    // Note: The boundary key from the server response may differ from our _boundaryKey
    // because for initial compile, the server generates its own UUID boundary.

    if (line.startsWith('result ')) {
      // Start of result block - the rest of the line contains a boundary key (not the .dill path!)
      // The actual result comes later in the format: "<boundary> <path> <error_count>"
      _outputBuffer.clear();
      return;
    }

    // Check for the final result line: "<uuid> <output_path> <error_count>"
    // This line contains a UUID boundary key followed by the output path and error count
    if (line.contains('.dill') && _currentCompile != null && !_currentCompile!.isCompleted) {
      final parts = line.split(' ');
      if (parts.length >= 2) {
        // Find the .dill path in the parts
        final dillPath = parts.firstWhere(
          (p) => p.endsWith('.dill'),
          orElse: () => '',
        );
        if (dillPath.isNotEmpty) {
          // Parse error count if present (last part should be the count)
          final errorCount = parts.length >= 3 ? int.tryParse(parts.last) ?? 0 : 0;

          if (errorCount == 0) {
            _currentCompile!.complete(IncrementalCompileResult(
              success: true,
              outputPath: dillPath,
            ));
          } else {
            // There were compilation errors
            _currentCompile!.complete(IncrementalCompileResult(
              success: false,
              errorMessage: 'Compilation had $errorCount errors',
              errors: _outputBuffer.toString().split('\n').where((l) =>
                l.contains('Error:') || l.contains('error:')).toList(),
            ));
          }
          _outputBuffer.clear();
          _isInitialCompile = false;
          return;
        }
      }
    }

    // Skip file dependency lines that start with +
    if (line.startsWith('+')) {
      return;
    }

    // Skip standalone boundary/UUID lines (they look like UUIDs or our boundary key)
    if (RegExp(r'^[a-f0-9\-]{36}$').hasMatch(line.trim()) ||
        line.trim() == _boundaryKey ||
        line.startsWith('boundary_')) {
      return;
    }

    // Accumulate output for error messages
    if (_currentCompile != null && !_currentCompile!.isCompleted) {
      if (_outputBuffer.isNotEmpty) {
        _outputBuffer.writeln();
      }
      _outputBuffer.write(line);
    }
  }

  /// Parse the compilation result from accumulated output
  void _parseCompileResult(String output) {
    if (_currentCompile == null || _currentCompile!.isCompleted) {
      return;
    }

    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.isEmpty) {
      _currentCompile!.complete(IncrementalCompileResult(
        success: false,
        errorMessage: 'Empty response from frontend_server',
      ));
      return;
    }

    // Check for success indicator
    // The first line after "result" should be the output .dill path on success
    final firstLine = lines.first.trim();

    if (firstLine.endsWith('.dill')) {
      // Successful compilation - first line is the output path
      _currentCompile!.complete(IncrementalCompileResult(
        success: true,
        outputPath: firstLine,
        warnings: lines.skip(1).where((l) => l.contains('warning:')).toList(),
      ));
    } else {
      // Compilation failed - lines contain error messages
      final errors = lines.where((l) => l.contains('Error:') || l.contains('error:')).toList();
      final warnings = lines.where((l) => l.contains('Warning:') || l.contains('warning:')).toList();

      _currentCompile!.complete(IncrementalCompileResult(
        success: false,
        errorMessage: lines.join('\n'),
        errors: errors,
        warnings: warnings,
      ));
    }
  }
}
