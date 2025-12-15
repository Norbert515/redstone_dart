import 'dart:io';

/// Represents the current platform and architecture
class PlatformInfo {
  final String os;
  final String arch;

  const PlatformInfo(this.os, this.arch);

  String get identifier => '$os-$arch';

  bool get isMacOS => os == 'macos';
  bool get isLinux => os == 'linux';
  bool get isWindows => os == 'windows';
  bool get isArm64 => arch == 'arm64';
  bool get isX64 => arch == 'x64';

  /// Native library extension for this platform
  String get dylibExtension {
    if (isMacOS) return 'dylib';
    if (isWindows) return 'dll';
    return 'so';
  }

  /// Native library prefix for this platform
  String get dylibPrefix {
    if (isWindows) return '';
    return 'lib';
  }

  @override
  String toString() => identifier;

  /// Detect the current platform
  static PlatformInfo detect() {
    final os = _detectOS();
    final arch = _detectArch();
    return PlatformInfo(os, arch);
  }

  static String _detectOS() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    throw UnsupportedError('Unsupported operating system');
  }

  static String _detectArch() {
    // Check for ARM64
    final result = Process.runSync('uname', ['-m']);
    final machine = result.stdout.toString().trim().toLowerCase();

    if (machine.contains('arm64') || machine.contains('aarch64')) {
      return 'arm64';
    }
    return 'x64';
  }
}
