/// Entity types and base classes.
library;

/// Status effects that can be applied to living entities.
enum StatusEffect {
  speed('minecraft:speed'),
  slowness('minecraft:slowness'),
  haste('minecraft:haste'),
  miningFatigue('minecraft:mining_fatigue'),
  strength('minecraft:strength'),
  instantHealth('minecraft:instant_health'),
  instantDamage('minecraft:instant_damage'),
  jumpBoost('minecraft:jump_boost'),
  nausea('minecraft:nausea'),
  regeneration('minecraft:regeneration'),
  resistance('minecraft:resistance'),
  fireResistance('minecraft:fire_resistance'),
  waterBreathing('minecraft:water_breathing'),
  invisibility('minecraft:invisibility'),
  blindness('minecraft:blindness'),
  nightVision('minecraft:night_vision'),
  hunger('minecraft:hunger'),
  weakness('minecraft:weakness'),
  poison('minecraft:poison'),
  wither('minecraft:wither'),
  healthBoost('minecraft:health_boost'),
  absorption('minecraft:absorption'),
  saturation('minecraft:saturation'),
  glowing('minecraft:glowing'),
  levitation('minecraft:levitation'),
  luck('minecraft:luck'),
  badLuck('minecraft:unluck'),
  slowFalling('minecraft:slow_falling'),
  conduitPower('minecraft:conduit_power'),
  dolphinsGrace('minecraft:dolphins_grace'),
  badOmen('minecraft:bad_omen'),
  heroOfTheVillage('minecraft:hero_of_the_village');

  /// The Minecraft effect ID.
  final String id;

  const StatusEffect(this.id);

  /// Get a StatusEffect by its Minecraft ID.
  static StatusEffect? fromId(String id) {
    for (final effect in values) {
      if (effect.id == id) return effect;
    }
    return null;
  }
}

/// Common entity types.
class EntityTypes {
  EntityTypes._();

  static const String player = 'minecraft:player';
  static const String zombie = 'minecraft:zombie';
  static const String skeleton = 'minecraft:skeleton';
  static const String creeper = 'minecraft:creeper';
  static const String spider = 'minecraft:spider';
  static const String enderman = 'minecraft:enderman';
  static const String pig = 'minecraft:pig';
  static const String cow = 'minecraft:cow';
  static const String sheep = 'minecraft:sheep';
  static const String chicken = 'minecraft:chicken';
  static const String wolf = 'minecraft:wolf';
  static const String cat = 'minecraft:cat';
  static const String villager = 'minecraft:villager';
  static const String item = 'minecraft:item';
  static const String arrow = 'minecraft:arrow';
  static const String fireball = 'minecraft:fireball';
}
