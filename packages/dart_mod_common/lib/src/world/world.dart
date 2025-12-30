/// World API for Minecraft dimensions.
library;

/// Sound categories for audio playback.
enum SoundCategory {
  master('master'),
  music('music'),
  records('record'),
  weather('weather'),
  blocks('block'),
  hostile('hostile'),
  neutral('neutral'),
  players('player'),
  ambient('ambient'),
  voice('voice');

  final String id;
  const SoundCategory(this.id);
}

/// Explosion behavior modes.
enum ExplosionMode {
  /// No block damage
  none(0),

  /// Break blocks, drop items
  destroy(1),

  /// Break blocks, some items lost
  destroyDecay(2);

  final int value;
  const ExplosionMode(this.value);
}

/// Game difficulty levels.
enum Difficulty {
  peaceful(0),
  easy(1),
  normal(2),
  hard(3);

  final int value;
  const Difficulty(this.value);

  static Difficulty fromValue(int value) {
    return switch (value) {
      0 => Difficulty.peaceful,
      1 => Difficulty.easy,
      2 => Difficulty.normal,
      3 => Difficulty.hard,
      _ => Difficulty.normal,
    };
  }
}

/// Weather conditions.
enum Weather {
  clear,
  rain,
  thunder,
}

/// Common sound identifiers.
class Sounds {
  Sounds._();

  static const String explosion = 'minecraft:entity.generic.explode';
  static const String levelUp = 'minecraft:entity.player.levelup';
  static const String anvil = 'minecraft:block.anvil.land';
  static const String enderDragonDeath = 'minecraft:entity.ender_dragon.death';
  static const String witherSpawn = 'minecraft:entity.wither.spawn';
  static const String thunder = 'minecraft:entity.lightning_bolt.thunder';
  static const String portal = 'minecraft:block.portal.trigger';
  static const String endPortal = 'minecraft:block.end_portal.spawn';
  static const String totem = 'minecraft:item.totem.use';
  static const String chest = 'minecraft:block.chest.open';
  static const String doorOpen = 'minecraft:block.wooden_door.open';
  static const String doorClose = 'minecraft:block.wooden_door.close';
  static const String click = 'minecraft:ui.button.click';
  static const String xpOrb = 'minecraft:entity.experience_orb.pickup';
  static const String itemPickup = 'minecraft:entity.item.pickup';
  static const String hurt = 'minecraft:entity.player.hurt';
  static const String death = 'minecraft:entity.player.death';
  static const String splash = 'minecraft:entity.generic.splash';
  static const String swim = 'minecraft:entity.generic.swim';
  static const String eat = 'minecraft:entity.generic.eat';
  static const String burp = 'minecraft:entity.player.burp';
  static const String drink = 'minecraft:entity.generic.drink';
}

/// Common particle identifiers.
class Particles {
  Particles._();

  static const String explosion = 'minecraft:explosion';
  static const String explosionEmitter = 'minecraft:explosion_emitter';
  static const String flame = 'minecraft:flame';
  static const String smoke = 'minecraft:smoke';
  static const String largeSmoke = 'minecraft:large_smoke';
  static const String heart = 'minecraft:heart';
  static const String villagerHappy = 'minecraft:happy_villager';
  static const String villagerAngry = 'minecraft:angry_villager';
  static const String portal = 'minecraft:portal';
  static const String enchant = 'minecraft:enchant';
  static const String crit = 'minecraft:crit';
  static const String damageIndicator = 'minecraft:damage_indicator';
  static const String cloud = 'minecraft:cloud';
  static const String witch = 'minecraft:witch';
  static const String dragonBreath = 'minecraft:dragon_breath';
  static const String endRod = 'minecraft:end_rod';
  static const String totemOfUndying = 'minecraft:totem_of_undying';
  static const String soul = 'minecraft:soul';
  static const String soulFireFlame = 'minecraft:soul_fire_flame';
  static const String lava = 'minecraft:lava';
  static const String splash = 'minecraft:splash';
  static const String bubble = 'minecraft:bubble';
  static const String rain = 'minecraft:rain';
  static const String snowflake = 'minecraft:snowflake';
  static const String note = 'minecraft:note';
  static const String campfireSignalSmoke = 'minecraft:campfire_signal_smoke';
  static const String campfireCosySmoke = 'minecraft:campfire_cosy_smoke';
  static const String firework = 'minecraft:firework';
  static const String electricSpark = 'minecraft:electric_spark';
  static const String waxOn = 'minecraft:wax_on';
  static const String waxOff = 'minecraft:wax_off';
  static const String scrape = 'minecraft:scrape';
}

/// Represents a Minecraft world/dimension.
///
/// This is the common base class with no platform-specific code.
/// For live world access, use the server or client specific World implementations.
class World {
  /// The dimension identifier.
  final String dimensionId;

  const World(this.dimensionId);

  /// Common dimensions
  static const overworld = World('minecraft:overworld');
  static const nether = World('minecraft:the_nether');
  static const end = World('minecraft:the_end');

  @override
  String toString() => 'World($dimensionId)';

  @override
  bool operator ==(Object other) =>
      other is World && dimensionId == other.dimensionId;

  @override
  int get hashCode => dimensionId.hashCode;
}

/// Time of day in Minecraft.
class GameTime {
  /// The current tick (0-24000 for a full day cycle).
  final int tick;

  const GameTime(this.tick);

  /// Time in ticks within the current day (0-24000).
  int get dayTime => tick % 24000;

  /// Current day number.
  int get day => tick ~/ 24000;

  /// Is it daytime (6am-6pm in Minecraft time)?
  bool get isDay => dayTime >= 0 && dayTime < 12000;

  /// Is it nighttime?
  bool get isNight => !isDay;

  @override
  String toString() => 'GameTime(day $day, tick $dayTime)';
}
