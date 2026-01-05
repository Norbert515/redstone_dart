/// Reactive widgets that rebuild when [SyncedInt] values change.
library;

import 'package:dart_mod_common/dart_mod_common.dart';
import 'package:flutter/widgets.dart';

/// A widget that rebuilds when a [SyncedInt] value changes.
///
/// Uses the listener pattern from [SyncedInt] to trigger rebuilds when
/// the synced value is updated from the server.
///
/// Example:
/// ```dart
/// Watch(
///   container.burnProgress,
///   builder: (value) => Text('Progress: $value'),
/// )
/// ```
class Watch extends StatefulWidget {
  /// The synced value to watch.
  final SyncedInt value;

  /// Builder that receives the current value.
  final Widget Function(int value) builder;

  /// Creates a Watch widget.
  const Watch(
    this.value, {
    required this.builder,
    super.key,
  });

  @override
  State<Watch> createState() => _WatchState();
}

class _WatchState extends State<Watch> {
  @override
  void initState() {
    super.initState();
    widget.value.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(Watch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      oldWidget.value.removeListener(_onValueChanged);
      widget.value.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    widget.value.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.value.value);
  }
}

/// A widget that rebuilds when either of two [SyncedInt] values change.
///
/// Useful for computing derived values from multiple synced values,
/// such as progress percentages.
///
/// Example:
/// ```dart
/// Watch2(
///   container.cookProgress,
///   container.maxCookTime,
///   builder: (progress, maxTime) {
///     final percent = maxTime > 0 ? progress / maxTime : 0.0;
///     return ProgressBar(progress: percent);
///   },
/// )
/// ```
class Watch2 extends StatefulWidget {
  /// The first synced value to watch.
  final SyncedInt value1;

  /// The second synced value to watch.
  final SyncedInt value2;

  /// Builder that receives both current values.
  final Widget Function(int value1, int value2) builder;

  /// Creates a Watch2 widget.
  const Watch2(
    this.value1,
    this.value2, {
    required this.builder,
    super.key,
  });

  @override
  State<Watch2> createState() => _Watch2State();
}

class _Watch2State extends State<Watch2> {
  @override
  void initState() {
    super.initState();
    widget.value1.addListener(_onValueChanged);
    widget.value2.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(Watch2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value1 != widget.value1) {
      oldWidget.value1.removeListener(_onValueChanged);
      widget.value1.addListener(_onValueChanged);
    }
    if (oldWidget.value2 != widget.value2) {
      oldWidget.value2.removeListener(_onValueChanged);
      widget.value2.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    widget.value1.removeListener(_onValueChanged);
    widget.value2.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.value1.value, widget.value2.value);
  }
}

/// A widget that rebuilds when any of three [SyncedInt] values change.
///
/// Example:
/// ```dart
/// Watch3(
///   container.value1,
///   container.value2,
///   container.value3,
///   builder: (v1, v2, v3) => Text('$v1, $v2, $v3'),
/// )
/// ```
class Watch3 extends StatefulWidget {
  /// The first synced value to watch.
  final SyncedInt value1;

  /// The second synced value to watch.
  final SyncedInt value2;

  /// The third synced value to watch.
  final SyncedInt value3;

  /// Builder that receives all three current values.
  final Widget Function(int value1, int value2, int value3) builder;

  /// Creates a Watch3 widget.
  const Watch3(
    this.value1,
    this.value2,
    this.value3, {
    required this.builder,
    super.key,
  });

  @override
  State<Watch3> createState() => _Watch3State();
}

class _Watch3State extends State<Watch3> {
  @override
  void initState() {
    super.initState();
    widget.value1.addListener(_onValueChanged);
    widget.value2.addListener(_onValueChanged);
    widget.value3.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(Watch3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value1 != widget.value1) {
      oldWidget.value1.removeListener(_onValueChanged);
      widget.value1.addListener(_onValueChanged);
    }
    if (oldWidget.value2 != widget.value2) {
      oldWidget.value2.removeListener(_onValueChanged);
      widget.value2.addListener(_onValueChanged);
    }
    if (oldWidget.value3 != widget.value3) {
      oldWidget.value3.removeListener(_onValueChanged);
      widget.value3.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    widget.value1.removeListener(_onValueChanged);
    widget.value2.removeListener(_onValueChanged);
    widget.value3.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      widget.value1.value,
      widget.value2.value,
      widget.value3.value,
    );
  }
}

/// A widget that rebuilds when any of four [SyncedInt] values change.
///
/// Common for furnace-like containers with litTime, litDuration,
/// cookingProgress, and cookingTotalTime.
///
/// Example:
/// ```dart
/// Watch4(
///   container.litTime,
///   container.litDuration,
///   container.cookProgress,
///   container.maxCookTime,
///   builder: (litTime, litDuration, cookProgress, maxCookTime) {
///     return FurnaceProgress(
///       litProgress: litDuration > 0 ? litTime / litDuration : 0,
///       cookProgress: maxCookTime > 0 ? cookProgress / maxCookTime : 0,
///     );
///   },
/// )
/// ```
class Watch4 extends StatefulWidget {
  /// The first synced value to watch.
  final SyncedInt value1;

  /// The second synced value to watch.
  final SyncedInt value2;

  /// The third synced value to watch.
  final SyncedInt value3;

  /// The fourth synced value to watch.
  final SyncedInt value4;

  /// Builder that receives all four current values.
  final Widget Function(int value1, int value2, int value3, int value4) builder;

  /// Creates a Watch4 widget.
  const Watch4(
    this.value1,
    this.value2,
    this.value3,
    this.value4, {
    required this.builder,
    super.key,
  });

  @override
  State<Watch4> createState() => _Watch4State();
}

class _Watch4State extends State<Watch4> {
  @override
  void initState() {
    super.initState();
    widget.value1.addListener(_onValueChanged);
    widget.value2.addListener(_onValueChanged);
    widget.value3.addListener(_onValueChanged);
    widget.value4.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(Watch4 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value1 != widget.value1) {
      oldWidget.value1.removeListener(_onValueChanged);
      widget.value1.addListener(_onValueChanged);
    }
    if (oldWidget.value2 != widget.value2) {
      oldWidget.value2.removeListener(_onValueChanged);
      widget.value2.addListener(_onValueChanged);
    }
    if (oldWidget.value3 != widget.value3) {
      oldWidget.value3.removeListener(_onValueChanged);
      widget.value3.addListener(_onValueChanged);
    }
    if (oldWidget.value4 != widget.value4) {
      oldWidget.value4.removeListener(_onValueChanged);
      widget.value4.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    widget.value1.removeListener(_onValueChanged);
    widget.value2.removeListener(_onValueChanged);
    widget.value3.removeListener(_onValueChanged);
    widget.value4.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      widget.value1.value,
      widget.value2.value,
      widget.value3.value,
      widget.value4.value,
    );
  }
}
