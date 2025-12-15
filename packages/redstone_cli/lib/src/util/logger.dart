import 'dart:io';

/// ANSI color codes for terminal output
class _Colors {
  static const reset = '\x1B[0m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
}

class Logger {
  static bool verbose = false;

  static void info(String message) {
    stdout.writeln(message);
  }

  static void success(String message) {
    stdout.writeln('${_Colors.green}✓${_Colors.reset} $message');
  }

  static void error(String message) {
    stderr.writeln('${_Colors.red}✗${_Colors.reset} $message');
  }

  static void warning(String message) {
    stdout.writeln('${_Colors.yellow}!${_Colors.reset} $message');
  }

  static void debug(String message) {
    if (verbose) {
      stdout.writeln('${_Colors.dim}$message${_Colors.reset}');
    }
  }

  static void header(String message) {
    stdout.writeln('${_Colors.bold}${_Colors.cyan}$message${_Colors.reset}');
  }

  static void step(String message) {
    stdout.writeln('  $message');
  }

  static void newLine() {
    stdout.writeln();
  }

  static void progress(String message) {
    stdout.write('$message... ');
  }

  static void progressDone() {
    stdout.writeln('${_Colors.green}done${_Colors.reset}');
  }

  static void progressFailed() {
    stdout.writeln('${_Colors.red}failed${_Colors.reset}');
  }

  /// Print a key-value pair with alignment
  static void keyValue(String key, String value, {int keyWidth = 20}) {
    final paddedKey = key.padRight(keyWidth);
    stdout.writeln('  $paddedKey $value');
  }

  /// Print a section divider
  static void divider() {
    stdout.writeln('${'─' * 40}');
  }
}
