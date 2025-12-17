import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:redstone_test/redstone_test.dart';

/// Spinner animation frames (braille dots).
const _spinnerFrames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

/// Result state for a test.
enum TestResult { pass, fail, skip }

/// State for a single test.
class TestState {
  final String fullName;
  final String displayName; // Just the test name without group prefix
  final int depth; // Nesting level
  final List<String> output = [];
  TestResult? result;
  int? durationMicros; // Microseconds for sub-ms precision
  String? error;
  String? stack;

  TestState({
    required this.fullName,
    required this.displayName,
    required this.depth,
  });
}

/// State for a group.
class GroupState {
  final String name;
  final int depth;

  GroupState({required this.name, required this.depth});
}

/// Nocterm component for test runner UI.
///
/// Displays test results in a polished TUI similar to Jest/Vitest:
/// - Groups shown as headers with proper nesting
/// - Simple checkmark icons (✓/✗/-)
/// - Indentation based on group depth
/// - Filtered stack traces
/// - Color-coded durations for slow tests
class TestRunnerUI extends StatefulComponent {
  final Stream<TestEvent> eventStream;
  final Completer<int> exitCodeCompleter;

  const TestRunnerUI({
    super.key,
    required this.eventStream,
    required this.exitCodeCompleter,
  });

  @override
  State<TestRunnerUI> createState() => _TestRunnerUIState();
}

class _TestRunnerUIState extends State<TestRunnerUI> {
  // Track all display items (groups and tests) in order
  final List<dynamic> _items = []; // GroupState or TestState
  final List<String> _groupStack = []; // Current group path
  TestState? _currentTest;
  int _totalTests = 0;
  bool _done = false;
  int _passed = 0;
  int _failed = 0;
  int _skipped = 0;
  DateTime? _startTime;
  StreamSubscription<TestEvent>? _subscription;

  // Animation state
  Timer? _spinnerTimer;
  int _spinnerFrame = 0;

  bool get _isSingleTestMode => _done && _totalTests == 1;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _subscription = component.eventStream.listen(_handleEvent);
    _startSpinner();
  }

  void _startSpinner() {
    _spinnerTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_currentTest != null) {
        setState(() {
          _spinnerFrame = (_spinnerFrame + 1) % _spinnerFrames.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _spinnerTimer?.cancel();
    super.dispose();
  }

  void _handleEvent(TestEvent event) {
    setState(() {
      switch (event) {
        case GroupStartEvent(:final name):
          // Add group header to display
          _items.add(GroupState(name: name, depth: _groupStack.length));
          _groupStack.add(name);

        case GroupEndEvent():
          if (_groupStack.isNotEmpty) {
            _groupStack.removeLast();
          }

        case TestStartEvent(:final name):
          // Extract just the test name (after last " > ")
          final displayName =
              name.contains(' > ') ? name.split(' > ').last : name;
          _currentTest = TestState(
            fullName: name,
            displayName: displayName,
            depth: _groupStack.length,
          );
          _items.add(_currentTest!);
          _totalTests++;

        case PrintEvent(:final message):
          _currentTest?.output.add(message);

        case TestPassEvent(:final name, :final durationMicros):
          final test = _findTest(name);
          if (test != null) {
            test.result = TestResult.pass;
            test.durationMicros = durationMicros;
            _passed++;
          }
          _currentTest = null;

        case TestFailEvent(:final name, :final error, :final stack):
          final test = _findTest(name);
          if (test != null) {
            test.result = TestResult.fail;
            test.error = error;
            test.stack = stack;
            _failed++;
          }
          _currentTest = null;

        case TestSkipEvent(:final name, :final reason):
          var test = _findTest(name);
          if (test == null) {
            // Test was skipped before TestStartEvent
            final displayName =
                name.contains(' > ') ? name.split(' > ').last : name;
            test = TestState(
              fullName: name,
              displayName: displayName,
              depth: _groupStack.length,
            );
            _items.add(test);
            _totalTests++;
          }
          test.result = TestResult.skip;
          test.error = reason;
          _skipped++;
          _currentTest = null;

        case DoneEvent(:final exitCode):
          _done = true;
          component.exitCodeCompleter.complete(exitCode);
          Future.delayed(const Duration(milliseconds: 100), () {
            shutdownApp();
          });

        case SuiteStartEvent():
        case SuiteEndEvent():
          break;
      }
    });
  }

  TestState? _findTest(String name) {
    for (final item in _items) {
      if (item is TestState && item.fullName == name) {
        return item;
      }
    }
    return null;
  }

  /// Filter stack trace to show only relevant lines.
  List<String> _filterStackTrace(String? stack) {
    if (stack == null) return [];

    return stack
        .split('\n')
        .where(
          (line) =>
              line.trim().isNotEmpty &&
              !line.contains('dart:async') &&
              !line.contains('<asynchronous suspension>') &&
              !line.contains('package:test/') &&
              !line.contains('package:matcher/') &&
              !line.contains('package:redstone_test/'),
        )
        .take(3)
        .toList();
  }

  /// Parse error message into lines for proper display.
  List<String> _parseErrorLines(String? error) {
    if (error == null) return [];
    return error.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display items (groups and tests) with spacing
        for (var i = 0; i < _items.length; i++) ...[
          // Add padding before groups (except first item)
          if (_items[i] is GroupState && i > 0) Text(''),
          // Add padding before failed tests
          if (_items[i] is TestState &&
              (_items[i] as TestState).result == TestResult.fail &&
              i > 0 &&
              _items[i - 1] is! GroupState)
            Text(''),
          if (_items[i] is GroupState)
            _buildGroupHeader(_items[i] as GroupState)
          else if (_items[i] is TestState)
            _buildTest(_items[i] as TestState),
          // Add padding after failed tests
          if (_items[i] is TestState &&
              (_items[i] as TestState).result == TestResult.fail)
            Text(''),
        ],

        // Summary
        if (_items.isNotEmpty) _buildSummary(),
      ],
    );
  }

  Component _buildGroupHeader(GroupState group) {
    final indent = '  ' * group.depth;
    return Text(
      '$indent${group.name}',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Component _buildTest(TestState test) {
    final isRunning = test.result == null;
    final shouldExpand =
        isRunning || test.result == TestResult.fail || _isSingleTestMode;

    if (shouldExpand) {
      return _buildExpandedTest(test);
    } else {
      return _buildCollapsedTest(test);
    }
  }

  Component _buildCollapsedTest(TestState test) {
    final indent = '  ' * test.depth;
    final (icon, color) = switch (test.result) {
      TestResult.pass => ('✓', Colors.green),
      TestResult.skip => ('-', Colors.yellow),
      _ => ('?', Colors.grey),
    };

    final durationStr = _formatDuration(test.durationMicros);
    final durationColor = _getDurationColor(test.durationMicros);

    // Build as row: icon + name + duration
    return Row(
      children: [
        Text('$indent$icon ', style: TextStyle(color: color)),
        Text(test.displayName, style: TextStyle(color: Colors.grey)),
        if (durationStr.isNotEmpty)
          Text(' $durationStr', style: TextStyle(color: durationColor)),
      ],
    );
  }

  Component _buildExpandedTest(TestState test) {
    final indent = '  ' * test.depth;
    final isRunning = test.result == null;

    // Use animated spinner for running tests
    final (icon, color) = switch (test.result) {
      TestResult.pass => ('✓', Colors.green),
      TestResult.fail => ('✗', Colors.red),
      TestResult.skip => ('-', Colors.yellow),
      null => (_spinnerFrames[_spinnerFrame], Colors.cyan),
    };

    final children = <Component>[];

    // Header line
    final durationStr = _formatDuration(test.durationMicros);
    final durationColor = _getDurationColor(test.durationMicros);

    children.add(
      Row(
        children: [
          Text('$indent$icon ', style: TextStyle(color: color)),
          Text(
            isRunning ? '${test.displayName}...' : test.displayName,
            style: TextStyle(
              color: isRunning
                  ? Colors.cyan
                  : (test.result == TestResult.fail ? Colors.red : Colors.grey),
            ),
          ),
          if (durationStr.isNotEmpty)
            Text(' $durationStr', style: TextStyle(color: durationColor)),
        ],
      ),
    );

    // For failed tests, show a nice error box
    if (test.result == TestResult.fail) {
      final errorIndent = '$indent  ';

      // Error box with corner characters
      children.add(
        Text('$errorIndent╭─ Error:', style: TextStyle(color: Colors.red)),
      );

      // Parse and display error lines with highlighting
      final errorLines = _parseErrorLines(test.error);
      for (final line in errorLines) {
        final trimmed = line.trim();
        Color lineColor = Colors.red;

        // Highlight special keywords
        if (trimmed.startsWith('Expected:')) {
          lineColor = Colors.yellow;
        } else if (trimmed.startsWith('Actual:')) {
          lineColor = Colors.cyan;
        } else if (trimmed.startsWith('Which:')) {
          lineColor = Colors.grey;
        }

        children.add(
          Text('$errorIndent│ $trimmed', style: TextStyle(color: lineColor)),
        );
      }

      // Stack trace
      final stackLines = _filterStackTrace(test.stack);
      if (stackLines.isNotEmpty) {
        children.add(
          Text('$errorIndent├─ Stack:', style: TextStyle(color: Colors.grey)),
        );
        for (final line in stackLines) {
          children.add(
            Text('$errorIndent│ $line', style: TextStyle(color: Colors.grey)),
          );
        }
      }

      // Close the box
      children.add(
        Text('$errorIndent╰${'─' * 40}', style: TextStyle(color: Colors.red)),
      );
    } else if (isRunning) {
      // Show output for running tests
      final outputIndent = '$indent  │ ';
      for (final line in test.output) {
        children.add(
          Text('$outputIndent$line', style: TextStyle(color: Colors.grey)),
        );
      }
    } else if (_isSingleTestMode && test.output.isNotEmpty) {
      // Show output in single test mode
      final outputIndent = '$indent  │ ';
      for (final line in test.output) {
        children.add(
          Text('$outputIndent$line', style: TextStyle(color: Colors.grey)),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  String _formatDuration(int? micros) {
    if (micros == null) return '';
    if (micros < 1000) return '(${micros}µs)'; // Microseconds
    if (micros < 1000000) return '(${(micros / 1000).toStringAsFixed(1)}ms)'; // Milliseconds
    return '(${(micros / 1000000).toStringAsFixed(2)}s)'; // Seconds
  }

  Color _getDurationColor(int? micros) {
    if (micros == null) return Colors.grey;
    if (micros > 1000000) return Colors.red; // > 1s
    if (micros > 200000) return Colors.yellow; // > 200ms
    return Colors.grey;
  }

  Component _buildSummary() {
    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds
        : 0;
    final timeStr = elapsed < 1000
        ? '${elapsed}ms'
        : '${(elapsed / 1000).toStringAsFixed(2)}s';

    final status = _done ? '' : 'Running... ';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(''),
        Text('─' * 50, style: TextStyle(color: Colors.grey)),
        Row(
          children: [
            Text(status, style: TextStyle(color: Colors.cyan)),
            Text(
              '$_passed passed',
              style: TextStyle(
                color: _passed > 0 ? Colors.green : Colors.grey,
              ),
            ),
            Text(', ', style: TextStyle(color: Colors.grey)),
            Text(
              '$_failed failed',
              style: TextStyle(color: _failed > 0 ? Colors.red : Colors.grey),
            ),
            Text(', ', style: TextStyle(color: Colors.grey)),
            Text(
              '$_skipped skipped',
              style: TextStyle(
                color: _skipped > 0 ? Colors.yellow : Colors.grey,
              ),
            ),
            Text(' ', style: TextStyle(color: Colors.grey)),
            Text('($_totalTests total, $timeStr)', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
