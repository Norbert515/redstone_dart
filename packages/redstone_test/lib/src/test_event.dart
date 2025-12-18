/// Test event types for the Redstone test protocol.
///
/// Events are emitted via stdout with a magic prefix for real-time test reporting.
library;

import 'dart:async';
import 'dart:convert';

/// Magic prefix for test events in stdout.
const testEventPrefix = '##REDSTONE_TEST##';

/// Base class for all test events.
sealed class TestEvent {
  const TestEvent();

  /// Convert to JSON map.
  Map<String, dynamic> toJson();

  /// Parse a test event from JSON.
  static TestEvent fromJson(Map<String, dynamic> json) {
    final event = json['event'] as String;
    return switch (event) {
      'suite_start' => SuiteStartEvent.fromJson(json),
      'suite_end' => SuiteEndEvent.fromJson(json),
      'group_start' => GroupStartEvent.fromJson(json),
      'group_end' => GroupEndEvent.fromJson(json),
      'test_start' => TestStartEvent.fromJson(json),
      'test_pass' => TestPassEvent.fromJson(json),
      'test_fail' => TestFailEvent.fromJson(json),
      'test_skip' => TestSkipEvent.fromJson(json),
      'print' => PrintEvent.fromJson(json),
      'done' => DoneEvent.fromJson(json),
      _ => throw ArgumentError('Unknown event type: $event'),
    };
  }

  /// Try to parse a line as a test event.
  /// Returns null if the line doesn't have the magic prefix.
  static TestEvent? tryParse(String line) {
    if (!line.startsWith(testEventPrefix)) {
      return null;
    }
    final jsonStr = line.substring(testEventPrefix.length);
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return TestEvent.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

/// Emitted when a test suite (file) starts.
final class SuiteStartEvent extends TestEvent {
  final String name;

  const SuiteStartEvent({required this.name});

  factory SuiteStartEvent.fromJson(Map<String, dynamic> json) {
    return SuiteStartEvent(name: json['name'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'event': 'suite_start', 'name': name};
}

/// Emitted when a test suite (file) ends.
final class SuiteEndEvent extends TestEvent {
  final String name;

  const SuiteEndEvent({required this.name});

  factory SuiteEndEvent.fromJson(Map<String, dynamic> json) {
    return SuiteEndEvent(name: json['name'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'event': 'suite_end', 'name': name};
}

/// Emitted when a test group starts.
final class GroupStartEvent extends TestEvent {
  final String name;

  const GroupStartEvent({required this.name});

  factory GroupStartEvent.fromJson(Map<String, dynamic> json) {
    return GroupStartEvent(name: json['name'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'event': 'group_start', 'name': name};
}

/// Emitted when a test group ends.
final class GroupEndEvent extends TestEvent {
  final String name;

  const GroupEndEvent({required this.name});

  factory GroupEndEvent.fromJson(Map<String, dynamic> json) {
    return GroupEndEvent(name: json['name'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'event': 'group_end', 'name': name};
}

/// Emitted when a test starts.
final class TestStartEvent extends TestEvent {
  final String name;

  const TestStartEvent({required this.name});

  factory TestStartEvent.fromJson(Map<String, dynamic> json) {
    return TestStartEvent(name: json['name'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'event': 'test_start', 'name': name};
}

/// Emitted when a test passes.
final class TestPassEvent extends TestEvent {
  final String name;
  /// Duration in microseconds for sub-millisecond precision.
  final int durationMicros;

  const TestPassEvent({required this.name, required this.durationMicros});

  factory TestPassEvent.fromJson(Map<String, dynamic> json) {
    return TestPassEvent(
      name: json['name'] as String,
      // Support both old 'duration_ms' and new 'duration_micros' for compatibility
      durationMicros: json['duration_micros'] as int? ??
          ((json['duration_ms'] as int?) ?? 0) * 1000,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'event': 'test_pass',
        'name': name,
        'duration_micros': durationMicros,
      };
}

/// Emitted when a test fails.
final class TestFailEvent extends TestEvent {
  final String name;
  final String error;
  final String? stack;

  const TestFailEvent({required this.name, required this.error, this.stack});

  factory TestFailEvent.fromJson(Map<String, dynamic> json) {
    return TestFailEvent(
      name: json['name'] as String,
      error: json['error'] as String,
      stack: json['stack'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'event': 'test_fail',
        'name': name,
        'error': error,
        if (stack != null) 'stack': stack,
      };
}

/// Emitted when a test is skipped.
final class TestSkipEvent extends TestEvent {
  final String name;
  final String? reason;

  const TestSkipEvent({required this.name, this.reason});

  factory TestSkipEvent.fromJson(Map<String, dynamic> json) {
    return TestSkipEvent(
      name: json['name'] as String,
      reason: json['reason'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'event': 'test_skip',
        'name': name,
        if (reason != null) 'reason': reason,
      };
}

/// Emitted when a test prints output.
final class PrintEvent extends TestEvent {
  final String message;

  const PrintEvent({required this.message});

  factory PrintEvent.fromJson(Map<String, dynamic> json) {
    return PrintEvent(message: json['message'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {'event': 'print', 'message': message};
}

/// Emitted when all tests are done.
final class DoneEvent extends TestEvent {
  final int passed;
  final int failed;
  final int skipped;
  final int exitCode;

  const DoneEvent({
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.exitCode,
  });

  factory DoneEvent.fromJson(Map<String, dynamic> json) {
    return DoneEvent(
      passed: json['passed'] as int,
      failed: json['failed'] as int,
      skipped: json['skipped'] as int,
      exitCode: json['exit_code'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'event': 'done',
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'exit_code': exitCode,
      };
}

/// Emit a test event to stdout with the magic prefix.
void emitEvent(TestEvent event) {
  final json = jsonEncode(event.toJson());
  // Use Zone.root.print to bypass any custom zone handlers.
  // This prevents infinite recursion when emitEvent is called from
  // inside a zone's print handler (which would otherwise re-trigger
  // the handler, calling emitEvent again, ad infinitum).
  Zone.root.print('$testEventPrefix$json');
}
