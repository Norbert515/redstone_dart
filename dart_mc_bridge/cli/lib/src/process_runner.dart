import 'dart:async';
import 'dart:io';

/// Handles process management for Minecraft.
class ProcessRunner {
  Process? _minecraftProcess;
  final String _cliDir;

  /// Creates a ProcessRunner with the CLI directory as the base for relative paths.
  ProcessRunner(this._cliDir);

  /// The directory containing the Minecraft mod project.
  String get minecraftDir => '$_cliDir/../../myfirstmod';

  /// Whether Minecraft is currently running.
  bool get isRunning => _minecraftProcess != null;

  /// Starts the Minecraft client using gradlew.
  ///
  /// [onOutput] is called for each line of stdout.
  /// [onError] is called for each line of stderr.
  /// [onExit] is called when the process exits.
  Future<bool> startMinecraft({
    void Function(String)? onOutput,
    void Function(String)? onError,
    void Function(int)? onExit,
  }) async {
    try {
      final workingDir = Directory(minecraftDir);
      if (!await workingDir.exists()) {
        stderr.writeln('[MC-CLI] Error: Minecraft directory not found at $minecraftDir');
        return false;
      }

      _minecraftProcess = await Process.start(
        './gradlew',
        ['runClient'],
        workingDirectory: minecraftDir,
        mode: ProcessStartMode.normal,
      );

      // Stream stdout
      _minecraftProcess!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        if (onOutput != null) {
          for (final line in data.split('\n')) {
            if (line.isNotEmpty) {
              onOutput(line);
            }
          }
        }
      });

      // Stream stderr
      _minecraftProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) {
        if (onError != null) {
          for (final line in data.split('\n')) {
            if (line.isNotEmpty) {
              onError(line);
            }
          }
        }
      });

      // Handle exit
      _minecraftProcess!.exitCode.then((code) {
        _minecraftProcess = null;
        if (onExit != null) {
          onExit(code);
        }
      });

      return true;
    } catch (e) {
      stderr.writeln('[MC-CLI] Error starting Minecraft: $e');
      return false;
    }
  }

  /// Stops the Minecraft process if running.
  Future<void> stopMinecraft() async {
    if (_minecraftProcess != null) {
      _minecraftProcess!.kill(ProcessSignal.sigterm);

      // Wait a bit for graceful shutdown
      await Future.delayed(const Duration(seconds: 2));

      // Force kill if still running
      try {
        _minecraftProcess?.kill(ProcessSignal.sigkill);
      } catch (_) {
        // Process may have already exited
      }

      _minecraftProcess = null;
    }
  }
}
