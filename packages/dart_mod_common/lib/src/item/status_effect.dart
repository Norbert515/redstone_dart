/// Status effect instances for custom food items.
library;

/// Represents a status effect instance that can be applied to entities.
class StatusEffectInstance {
  /// The status effect type (e.g., 'minecraft:speed', 'minecraft:regeneration')
  final String effect;

  /// Duration in ticks (20 ticks = 1 second)
  final int duration;

  /// Amplifier (0 = level I, 1 = level II, etc.)
  final int amplifier;

  /// Whether to show particles
  final bool showParticles;

  /// Whether to show the effect icon
  final bool showIcon;

  const StatusEffectInstance({
    required this.effect,
    required this.duration,
    this.amplifier = 0,
    this.showParticles = true,
    this.showIcon = true,
  });

  /// Create a regeneration effect
  factory StatusEffectInstance.regeneration({
    required int duration,
    int amplifier = 0,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:regeneration',
      duration: duration,
      amplifier: amplifier,
    );
  }

  /// Create a speed effect
  factory StatusEffectInstance.speed({
    required int duration,
    int amplifier = 0,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:speed',
      duration: duration,
      amplifier: amplifier,
    );
  }

  /// Create a poison effect
  factory StatusEffectInstance.poison({
    required int duration,
    int amplifier = 0,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:poison',
      duration: duration,
      amplifier: amplifier,
    );
  }

  /// Create a hunger effect
  factory StatusEffectInstance.hunger({
    required int duration,
    int amplifier = 0,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:hunger',
      duration: duration,
      amplifier: amplifier,
    );
  }

  /// Create a nausea effect
  factory StatusEffectInstance.nausea({
    required int duration,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:nausea',
      duration: duration,
    );
  }

  /// Create an absorption effect
  factory StatusEffectInstance.absorption({
    required int duration,
    int amplifier = 0,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:absorption',
      duration: duration,
      amplifier: amplifier,
    );
  }

  /// Create a resistance effect
  factory StatusEffectInstance.resistance({
    required int duration,
    int amplifier = 0,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:resistance',
      duration: duration,
      amplifier: amplifier,
    );
  }

  /// Create a fire resistance effect
  factory StatusEffectInstance.fireResistance({
    required int duration,
  }) {
    return StatusEffectInstance(
      effect: 'minecraft:fire_resistance',
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() => {
        'effect': effect,
        'duration': duration,
        'amplifier': amplifier,
        'showParticles': showParticles,
        'showIcon': showIcon,
      };
}
