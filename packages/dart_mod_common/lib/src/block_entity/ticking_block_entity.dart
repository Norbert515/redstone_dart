/// Ticking block entity support.
library;

import 'block_entity.dart';

/// A block entity that receives server tick updates.
///
/// Override [serverTick] to perform actions every game tick (20 times per second).
///
/// ## Example
///
/// ```dart
/// class MyTickingBlockEntity extends TickingBlockEntity {
///   int tickCount = 0;
///
///   MyTickingBlockEntity() : super(
///     settings: BlockEntitySettings(id: 'mymod:counter'),
///   );
///
///   @override
///   void serverTick() {
///     tickCount++;
///     if (tickCount % 20 == 0) {
///       print('One second passed!');
///     }
///   }
/// }
/// ```
abstract class TickingBlockEntity extends BlockEntity {
  /// Creates a ticking block entity with the given settings.
  TickingBlockEntity({required super.settings});

  /// Called every server tick (20 times per second).
  ///
  /// Override to perform periodic actions like processing, animation updates,
  /// or state changes.
  void serverTick() {}
}
