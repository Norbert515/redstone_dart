import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/redstone_project.dart';
import '../util/logger.dart';

/// Manages the Minecraft process lifecycle
class MinecraftRunner {
  final RedstoneProject project;
  Process? _process;
  final _exitCompleter = Completer<int>();

  MinecraftRunner(this.project);

  /// Exit code future - completes when Minecraft exits
  Future<int> get exitCode => _exitCompleter.future;

  /// Start Minecraft with the mod
  Future<void> start() async {
    // First, copy files
    await _prepareFiles();

    // Start Minecraft via Gradle
    final gradlew = Platform.isWindows ? 'gradlew.bat' : './gradlew';

    Logger.debug('Starting Minecraft from ${project.minecraftDir}');

    _process = await Process.start(
      gradlew,
      ['runClient'],
      workingDirectory: project.minecraftDir,
      mode: ProcessStartMode.inheritStdio,
    );

    // Handle process exit
    _process!.exitCode.then((code) {
      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(code);
      }
    });
  }

  /// Stop Minecraft gracefully
  Future<void> stop() async {
    if (_process != null) {
      Logger.debug('Stopping Minecraft...');

      // Try graceful shutdown first
      _process!.kill(ProcessSignal.sigterm);

      // Wait a bit for graceful exit
      final exited = await _process!.exitCode
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);

      if (exited == -1) {
        // Force kill if didn't exit gracefully
        Logger.debug('Force killing Minecraft...');
        _process!.kill(ProcessSignal.sigkill);
      }

      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(0);
      }
    }
  }

  /// Prepare files before running
  Future<void> _prepareFiles() async {
    // Copy Dart mod to run/mods/
    await _copyDartMod();

    // Copy native libs to run/natives/
    await _copyNativeLibs();
  }

  Future<void> _copyDartMod() async {
    final sourceDir = Directory(project.libDir);
    // DartModLoader expects the mod at mods/dart_mc/lib/dart_mc.dart
    final targetDir = Directory(
      p.join(project.minecraftDir, 'run', 'mods', 'dart_mc'),
    );

    // Create target directory
    if (targetDir.existsSync()) {
      targetDir.deleteSync(recursive: true);
    }
    targetDir.createSync(recursive: true);

    // Copy lib/ contents
    final targetLibDir = Directory(p.join(targetDir.path, 'lib'));
    await _copyDirectory(sourceDir, targetLibDir);

    // Rename main.dart to dart_mc.dart if it exists (DartModLoader expects this name)
    final mainDart = File(p.join(targetLibDir.path, 'main.dart'));
    final dartMcDart = File(p.join(targetLibDir.path, 'dart_mc.dart'));
    if (mainDart.existsSync() && !dartMcDart.existsSync()) {
      mainDart.renameSync(dartMcDart.path);
    }

    // Copy pubspec.yaml
    final pubspec = File(p.join(project.rootDir, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      pubspec.copySync(p.join(targetDir.path, 'pubspec.yaml'));
    }

    // Run pub get in the target directory
    await Process.run('dart', ['pub', 'get'], workingDirectory: targetDir.path);
  }

  Future<void> _copyNativeLibs() async {
    final nativeDir = Directory(project.nativeDir);
    final targetDir = Directory(p.join(project.minecraftDir, 'run', 'natives'));

    if (!nativeDir.existsSync()) {
      Logger.warning('Native libraries not found at ${nativeDir.path}');
      return;
    }

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    await for (final entity in nativeDir.list()) {
      if (entity is File) {
        final targetPath = p.join(targetDir.path, p.basename(entity.path));
        entity.copySync(targetPath);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!source.existsSync()) return;

    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }
}
