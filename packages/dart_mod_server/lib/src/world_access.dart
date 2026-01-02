/// Server-side world access API.
///
/// This provides live access to the Minecraft world on the server side.
/// It extends the common World class with actual JNI calls to read/write world data.
library;

import 'package:dart_mod_common/dart_mod_common.dart';

import 'entity.dart' show Entity;
import 'player.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/redstone/DartBridge';

/// Server-side world with live Minecraft access.
///
/// This class provides methods to read and write world data through the JNI bridge.
class ServerWorld extends World {
  const ServerWorld(super.dimensionId);

  /// Get the overworld.
  static const overworld = ServerWorld('minecraft:overworld');

  /// Get the nether.
  static const nether = ServerWorld('minecraft:the_nether');

  /// Get the end.
  static const end = ServerWorld('minecraft:the_end');

  // ==========================================================================
  // Block Manipulation APIs
  // ==========================================================================

  /// Get the block at a position in this world.
  /// Returns the block, or [Block.air] if the position is invalid/unloaded.
  Block getBlock(BlockPos pos) {
    final blockId = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getBlockId',
      '(Ljava/lang/String;III)Ljava/lang/String;',
      [dimensionId, pos.x, pos.y, pos.z],
    );
    if (blockId == null) return Block.air;
    return Block(blockId);
  }

  /// Set a block at a position in this world.
  /// Returns true if successful.
  bool setBlock(BlockPos pos, Block block) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'setBlock',
      '(Ljava/lang/String;IIILjava/lang/String;)Z',
      [dimensionId, pos.x, pos.y, pos.z, block.id],
    );
  }

  /// Check if a position contains air.
  bool isAir(BlockPos pos) {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isAirBlock',
      '(Ljava/lang/String;III)Z',
      [dimensionId, pos.x, pos.y, pos.z],
    );
  }

  // ==========================================================================
  // Time APIs
  // ==========================================================================

  /// Time of day (0-24000, 0=dawn, 6000=noon, 12000=dusk, 18000=midnight).
  int get timeOfDay {
    return GenericJniBridge.callStaticLongMethod(
      _dartBridge,
      'getTimeOfDay',
      '(Ljava/lang/String;)J',
      [dimensionId],
    ).toInt();
  }

  /// Set the time of day (0-24000).
  set timeOfDay(int time) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setTimeOfDay',
      '(Ljava/lang/String;J)V',
      [dimensionId, time],
    );
  }

  /// Full world time (total ticks since world creation).
  int get gameTime {
    return GenericJniBridge.callStaticLongMethod(
      _dartBridge,
      'getGameTime',
      '(Ljava/lang/String;)J',
      [dimensionId],
    ).toInt();
  }

  /// Current day count.
  int get dayCount {
    return GenericJniBridge.callStaticLongMethod(
      _dartBridge,
      'getDayCount',
      '(Ljava/lang/String;)J',
      [dimensionId],
    ).toInt();
  }

  /// Is it daytime (roughly 6000-18000 ticks, when sun is up).
  bool get isDaytime {
    final time = timeOfDay;
    return time >= 0 && time < 12000;
  }

  /// Is it nighttime.
  bool get isNighttime => !isDaytime;

  // ==========================================================================
  // Weather APIs
  // ==========================================================================

  /// Get current weather.
  Weather get weather {
    final weatherInt = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getWeather',
      '(Ljava/lang/String;)I',
      [dimensionId],
    );
    return switch (weatherInt) {
      1 => Weather.rain,
      2 => Weather.thunder,
      _ => Weather.clear,
    };
  }

  /// Set weather.
  set weather(Weather weather) {
    setWeather(weather, 6000); // Default 5 minutes
  }

  /// Set weather with duration in ticks.
  void setWeather(Weather weather, int durationTicks) {
    final weatherInt = switch (weather) {
      Weather.clear => 0,
      Weather.rain => 1,
      Weather.thunder => 2,
    };
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setWeather',
      '(Ljava/lang/String;II)V',
      [dimensionId, weatherInt, durationTicks],
    );
  }

  /// Is it currently raining.
  bool get isRaining {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isRaining',
      '(Ljava/lang/String;)Z',
      [dimensionId],
    );
  }

  /// Is it currently thundering.
  bool get isThundering {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isThundering',
      '(Ljava/lang/String;)Z',
      [dimensionId],
    );
  }

  // ==========================================================================
  // Sound APIs
  // ==========================================================================

  /// Play a sound at position audible to all nearby players.
  void playSound(
    Vec3 position,
    String sound, {
    SoundCategory category = SoundCategory.master,
    double volume = 1.0,
    double pitch = 1.0,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'playSound',
      '(Ljava/lang/String;DDDLjava/lang/String;Ljava/lang/String;FF)V',
      [
        dimensionId,
        position.x,
        position.y,
        position.z,
        sound,
        category.id,
        volume,
        pitch,
      ],
    );
  }

  /// Play sound to a specific player only.
  void playSoundToPlayer(
    Player player,
    String sound, {
    SoundCategory category = SoundCategory.master,
    double volume = 1.0,
    double pitch = 1.0,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'playSoundToPlayer',
      '(ILjava/lang/String;Ljava/lang/String;FF)V',
      [player.id, sound, category.id, volume, pitch],
    );
  }

  // ==========================================================================
  // Particle APIs
  // ==========================================================================

  /// Spawn particles at a position visible to all nearby players.
  void spawnParticles(
    String particle,
    Vec3 position, {
    int count = 1,
    Vec3 delta = Vec3.zero,
    double speed = 0.0,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'spawnParticles',
      '(Ljava/lang/String;Ljava/lang/String;DDDIDDDD)V',
      [
        dimensionId,
        particle,
        position.x,
        position.y,
        position.z,
        count,
        delta.x,
        delta.y,
        delta.z,
        speed,
      ],
    );
  }

  /// Spawn particles visible to a specific player only.
  void spawnParticlesToPlayer(
    Player player,
    String particle,
    Vec3 position, {
    int count = 1,
    Vec3 delta = Vec3.zero,
    double speed = 0.0,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'spawnParticlesToPlayer',
      '(ILjava/lang/String;DDDIDDDD)V',
      [
        player.id,
        particle,
        position.x,
        position.y,
        position.z,
        count,
        delta.x,
        delta.y,
        delta.z,
        speed,
      ],
    );
  }

  // ==========================================================================
  // Explosion APIs
  // ==========================================================================

  /// Create an explosion at a position.
  void createExplosion(
    Vec3 position,
    double power, {
    bool fire = false,
    ExplosionMode mode = ExplosionMode.destroy,
    Entity? source,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'createExplosion',
      '(Ljava/lang/String;DDDFZII)V',
      [
        dimensionId,
        position.x,
        position.y,
        position.z,
        power,
        fire,
        mode.value,
        source?.id ?? -1,
      ],
    );
  }

  // ==========================================================================
  // Lightning APIs
  // ==========================================================================

  /// Spawn a lightning bolt at a position.
  /// Returns the lightning entity.
  Entity? spawnLightning(Vec3 position, {bool damageOnly = false}) {
    final entityId = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'spawnLightning',
      '(Ljava/lang/String;DDDZ)I',
      [dimensionId, position.x, position.y, position.z, damageOnly],
    );
    if (entityId < 0) return null;
    return Entity(entityId);
  }

  // ==========================================================================
  // World Border APIs
  // ==========================================================================

  /// Get the world border center.
  Vec3 get worldBorderCenter {
    final result = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getWorldBorderCenter',
      '(Ljava/lang/String;)Ljava/lang/String;',
      [dimensionId],
    );
    if (result == null || result.isEmpty) return Vec3.zero;
    final parts = result.split(',');
    if (parts.length < 2) return Vec3.zero;
    return Vec3(
      double.tryParse(parts[0]) ?? 0,
      0,
      double.tryParse(parts[1]) ?? 0,
    );
  }

  /// Set the world border center.
  set worldBorderCenter(Vec3 center) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setWorldBorderCenter',
      '(Ljava/lang/String;DD)V',
      [dimensionId, center.x, center.z],
    );
  }

  /// Get the world border size (diameter).
  double get worldBorderSize {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getWorldBorderSize',
      '(Ljava/lang/String;)D',
      [dimensionId],
    );
  }

  /// Set the world border size instantly.
  set worldBorderSize(double size) {
    setWorldBorderSize(size, 0);
  }

  /// Set the world border size with transition time in milliseconds.
  void setWorldBorderSize(double size, int transitionMillis) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setWorldBorderSize',
      '(Ljava/lang/String;DJ)V',
      [dimensionId, size, transitionMillis],
    );
  }

  // ==========================================================================
  // Spawn Point APIs
  // ==========================================================================

  /// Get the world spawn point.
  BlockPos get spawnPoint {
    final result = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getSpawnPoint',
      '(Ljava/lang/String;)Ljava/lang/String;',
      [dimensionId],
    );
    if (result == null || result.isEmpty) return const BlockPos(0, 64, 0);
    final parts = result.split(',');
    if (parts.length < 3) return const BlockPos(0, 64, 0);
    return BlockPos(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 64,
      int.tryParse(parts[2]) ?? 0,
    );
  }

  /// Set the world spawn point.
  set spawnPoint(BlockPos pos) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setSpawnPoint',
      '(Ljava/lang/String;III)V',
      [dimensionId, pos.x, pos.y, pos.z],
    );
  }

  // ==========================================================================
  // Difficulty APIs
  // ==========================================================================

  /// Get current game difficulty.
  Difficulty get difficulty {
    final diffInt = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getDifficulty',
      '()I',
      [],
    );
    return Difficulty.fromValue(diffInt);
  }

  /// Set game difficulty.
  set difficulty(Difficulty diff) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setDifficulty',
      '(I)V',
      [diff.value],
    );
  }

  // ==========================================================================
  // Game Rules APIs
  // ==========================================================================

  /// Get a game rule value as a string.
  String getGameRule(String rule) {
    return GenericJniBridge.callStaticStringMethod(
          _dartBridge,
          'getGameRule',
          '(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;',
          [dimensionId, rule],
        ) ??
        '';
  }

  /// Set a game rule value.
  void setGameRule(String rule, String value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setGameRule',
      '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V',
      [dimensionId, rule, value],
    );
  }

  // Common game rules as typed getters/setters

  /// Whether the day/night cycle is active.
  bool get doDaylightCycle => getGameRule('doDaylightCycle') == 'true';
  set doDaylightCycle(bool value) =>
      setGameRule('doDaylightCycle', value.toString());

  /// Whether weather changes.
  bool get doWeatherCycle => getGameRule('doWeatherCycle') == 'true';
  set doWeatherCycle(bool value) =>
      setGameRule('doWeatherCycle', value.toString());

  /// Whether players keep inventory on death.
  bool get keepInventory => getGameRule('keepInventory') == 'true';
  set keepInventory(bool value) =>
      setGameRule('keepInventory', value.toString());

  /// Whether mobs can spawn naturally.
  bool get doMobSpawning => getGameRule('doMobSpawning') == 'true';
  set doMobSpawning(bool value) =>
      setGameRule('doMobSpawning', value.toString());

  /// Whether mobs can modify blocks.
  bool get mobGriefing => getGameRule('mobGriefing') == 'true';
  set mobGriefing(bool value) => setGameRule('mobGriefing', value.toString());

  /// Whether PvP is enabled.
  bool get pvp => getGameRule('pvp') == 'true';
  set pvp(bool value) => setGameRule('pvp', value.toString());

  /// Random tick speed (default 3).
  int get randomTickSpeed =>
      int.tryParse(getGameRule('randomTickSpeed')) ?? 3;
  set randomTickSpeed(int value) =>
      setGameRule('randomTickSpeed', value.toString());

  /// Whether fire spreads.
  bool get doFireTick => getGameRule('doFireTick') == 'true';
  set doFireTick(bool value) => setGameRule('doFireTick', value.toString());

  /// Whether entities drop loot.
  bool get doEntityDrops => getGameRule('doEntityDrops') == 'true';
  set doEntityDrops(bool value) =>
      setGameRule('doEntityDrops', value.toString());

  /// Whether tiles drop items.
  bool get doTileDrops => getGameRule('doTileDrops') == 'true';
  set doTileDrops(bool value) => setGameRule('doTileDrops', value.toString());

  /// Whether natural regeneration is enabled.
  bool get naturalRegeneration => getGameRule('naturalRegeneration') == 'true';
  set naturalRegeneration(bool value) =>
      setGameRule('naturalRegeneration', value.toString());

  /// Whether to show death messages.
  bool get showDeathMessages => getGameRule('showDeathMessages') == 'true';
  set showDeathMessages(bool value) =>
      setGameRule('showDeathMessages', value.toString());

  /// Whether to announce advancements.
  bool get announceAdvancements =>
      getGameRule('announceAdvancements') == 'true';
  set announceAdvancements(bool value) =>
      setGameRule('announceAdvancements', value.toString());

  /// Max command chain length.
  int get maxCommandChainLength =>
      int.tryParse(getGameRule('maxCommandChainLength')) ?? 65536;
  set maxCommandChainLength(int value) =>
      setGameRule('maxCommandChainLength', value.toString());

  /// Spawn radius for new players.
  int get spawnRadius => int.tryParse(getGameRule('spawnRadius')) ?? 10;
  set spawnRadius(int value) => setGameRule('spawnRadius', value.toString());
}
