import 'dart:io';

import 'package:args/command_runner.dart';

import '../project/dart_dll_manager.dart';
import '../util/logger.dart';
import '../util/platform.dart';

class DoctorCommand extends Command<int> {
  @override
  final name = 'doctor';

  @override
  final description = 'Check your development environment for Redstone.';

  @override
  Future<int> run() async {
    Logger.newLine();
    Logger.header('Redstone Doctor');
    Logger.divider();
    Logger.newLine();

    var issues = 0;
    var nonBlocking = 0;

    // Check Dart SDK
    final dartCheck = await _checkDart();
    if (!dartCheck.ok) issues++;
    _printCheck(dartCheck);

    // Check Java
    final javaCheck = await _checkJava();
    if (!javaCheck.ok) issues++;
    _printCheck(javaCheck);

    // Check Gradle
    final gradleCheck = await _checkGradle();
    if (!gradleCheck.ok) {
      nonBlocking++;
    }
    _printCheck(gradleCheck);

    // Check CMake (non-blocking)
    final cmakeCheck = await _checkCMake();
    if (!cmakeCheck.ok) {
      nonBlocking++;
    }
    _printCheck(cmakeCheck);

    // Check dart_dll (non-blocking, will be auto-downloaded when needed)
    final dartDllCheck = _checkDartDll();
    if (!dartDllCheck.ok) {
      nonBlocking++;
    }
    _printCheck(dartDllCheck);

    // Check platform
    final platform = PlatformInfo.detect();
    Logger.success('Platform: ${platform.identifier}');

    Logger.newLine();
    Logger.divider();

    if (issues > 0) {
      Logger.error('$issues blocking issue(s) found. Please fix them before continuing.');
      return 1;
    } else if (nonBlocking > 0) {
      Logger.warning('$nonBlocking non-blocking issue(s) found.');
      Logger.success('Redstone is ready to use!');
    } else {
      Logger.success('All checks passed! Redstone is ready to use.');
    }

    Logger.newLine();
    return 0;
  }

  void _printCheck(_Check check) {
    if (check.ok) {
      Logger.success('${check.name}: ${check.version}');
    } else if (check.blocking) {
      Logger.error('${check.name}: ${check.message}');
    } else {
      Logger.warning('${check.name}: ${check.message}');
      if (check.hint != null) {
        Logger.step('└ ${check.hint}');
      }
    }
  }

  Future<_Check> _checkDart() async {
    try {
      final result = await Process.run('dart', ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'Dart SDK version: (\S+)').firstMatch(output);
        final version = match?.group(1) ?? 'unknown';
        return _Check.ok('Dart SDK', version);
      }
    } catch (_) {}
    return _Check.fail('Dart SDK', 'Not found', blocking: true);
  }

  Future<_Check> _checkJava() async {
    try {
      final result = await Process.run('java', ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        if (lines.isNotEmpty) {
          final match = RegExp(r'(\d+)\.?').firstMatch(lines.first);
          final majorVersion = int.tryParse(match?.group(1) ?? '');
          if (majorVersion != null && majorVersion >= 21) {
            return _Check.ok('Java', lines.first.trim());
          } else {
            return _Check.fail(
              'Java',
              'Version $majorVersion found, but 21+ required',
              blocking: true,
            );
          }
        }
      }
    } catch (_) {}
    return _Check.fail('Java', 'Not found (required: 21+)', blocking: true);
  }

  Future<_Check> _checkGradle() async {
    try {
      final result = await Process.run('gradle', ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'Gradle (\S+)').firstMatch(output);
        final version = match?.group(1) ?? 'unknown';
        return _Check.ok('Gradle', version);
      }
    } catch (_) {}
    return _Check.warn(
      'Gradle',
      'Not found (will use Gradle wrapper)',
      hint: 'Projects use bundled gradlew, so this is optional',
    );
  }

  Future<_Check> _checkCMake() async {
    try {
      final result = await Process.run('cmake', ['--version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'cmake version (\S+)').firstMatch(output);
        final version = match?.group(1) ?? 'unknown';
        return _Check.ok('CMake', version);
      }
    } catch (_) {}
    return _Check.warn(
      'CMake',
      'Not found',
      hint: 'Only needed if building native libraries from source',
    );
  }

  _Check _checkDartDll() {
    if (!DartDllManager.needsDownload()) {
      return _Check.ok('dart_dll', 'v${DartDllManager.dartDllVersion}');
    }
    return _Check.warn(
      'dart_dll',
      'Not found',
      hint: 'Will be auto-downloaded on first run/create',
    );
  }
}

class _Check {
  final String name;
  final String? version;
  final String? message;
  final String? hint;
  final bool ok;
  final bool blocking;

  _Check._({
    required this.name,
    this.version,
    this.message,
    this.hint,
    required this.ok,
    this.blocking = false,
  });

  factory _Check.ok(String name, String version) =>
      _Check._(name: name, version: version, ok: true);

  factory _Check.fail(String name, String message, {bool blocking = true}) =>
      _Check._(name: name, message: message, ok: false, blocking: blocking);

  factory _Check.warn(String name, String message, {String? hint}) =>
      _Check._(name: name, message: message, hint: hint, ok: false, blocking: false);
}
