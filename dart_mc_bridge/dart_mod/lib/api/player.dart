/// Player API for interacting with Minecraft players.
library;

import '../src/jni/generic_bridge.dart';
import '../src/types.dart';

/// The Java class name for DartBridge.
const _dartBridge = 'com/example/dartbridge/DartBridge';

/// Game mode for players.
enum GameMode {
  survival(0),
  creative(1),
  adventure(2),
  spectator(3);

  final int value;
  const GameMode(this.value);

  static GameMode fromValue(int value) {
    return switch (value) {
      0 => GameMode.survival,
      1 => GameMode.creative,
      2 => GameMode.adventure,
      3 => GameMode.spectator,
      _ => GameMode.survival,
    };
  }
}

/// Represents a player in the game.
class Player {
  /// Unique player ID (entity ID in the current session).
  final int id;

  const Player(this.id);

  // ==========================================================================
  // Position & Movement
  // ==========================================================================

  /// Get the player's current block position.
  BlockPos get position {
    final coords = _getPositionArray();
    if (coords == null) return const BlockPos(0, 0, 0);
    return BlockPos(coords[0].floor(), coords[1].floor(), coords[2].floor());
  }

  /// Get the player's precise position.
  Vec3 get precisePosition {
    final coords = _getPositionArray();
    if (coords == null) return Vec3.zero;
    return Vec3(coords[0], coords[1], coords[2]);
  }

  List<double>? _getPositionArray() {
    final x = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerX',
      '(I)D',
      [id],
    );
    final y = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerY',
      '(I)D',
      [id],
    );
    final z = GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerZ',
      '(I)D',
      [id],
    );
    return [x, y, z];
  }

  /// Get the player's yaw (horizontal rotation, 0-360).
  double get yaw {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerYaw',
      '(I)D',
      [id],
    );
  }

  /// Get the player's pitch (vertical rotation, -90 to 90).
  double get pitch {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerPitch',
      '(I)D',
      [id],
    );
  }

  /// Teleport the player to a block position.
  void teleport(BlockPos pos) {
    teleportPrecise(Vec3(pos.x + 0.5, pos.y.toDouble(), pos.z + 0.5));
  }

  /// Teleport the player to precise coordinates.
  void teleportPrecise(Vec3 pos, {double? yaw, double? pitch}) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'teleportPlayer',
      '(IDDDFF)V',
      [id, pos.x, pos.y, pos.z, yaw ?? this.yaw, pitch ?? this.pitch],
    );
  }

  // ==========================================================================
  // Health & Food
  // ==========================================================================

  /// Get the player's current health (0-20 by default).
  double get health {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerHealth',
      '(I)D',
      [id],
    );
  }

  /// Set the player's health.
  set health(double value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerHealth',
      '(IF)V',
      [id, value],
    );
  }

  /// Get the player's max health.
  double get maxHealth {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerMaxHealth',
      '(I)D',
      [id],
    );
  }

  /// Get the player's food level (0-20).
  int get foodLevel {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerFoodLevel',
      '(I)I',
      [id],
    );
  }

  /// Set the player's food level.
  set foodLevel(int value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerFoodLevel',
      '(II)V',
      [id, value],
    );
  }

  /// Get the player's saturation level.
  double get saturation {
    return GenericJniBridge.callStaticDoubleMethod(
      _dartBridge,
      'getPlayerSaturation',
      '(I)D',
      [id],
    );
  }

  /// Set the player's saturation level.
  set saturation(double value) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerSaturation',
      '(IF)V',
      [id, value],
    );
  }

  // ==========================================================================
  // Game State
  // ==========================================================================

  /// Get the player's game mode.
  GameMode get gameMode {
    final mode = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerGameMode',
      '(I)I',
      [id],
    );
    return GameMode.fromValue(mode);
  }

  /// Set the player's game mode.
  set gameMode(GameMode mode) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerGameMode',
      '(II)V',
      [id, mode.value],
    );
  }

  /// Check if player is in creative mode.
  bool get isCreative => gameMode == GameMode.creative;

  /// Check if player is in survival mode.
  bool get isSurvival => gameMode == GameMode.survival;

  /// Check if player is in spectator mode.
  bool get isSpectator => gameMode == GameMode.spectator;

  /// Check if player is in adventure mode.
  bool get isAdventure => gameMode == GameMode.adventure;

  // ==========================================================================
  // Experience
  // ==========================================================================

  /// Get the player's experience level.
  int get experienceLevel {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerExperienceLevel',
      '(I)I',
      [id],
    );
  }

  /// Set the player's experience level.
  set experienceLevel(int level) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'setPlayerExperienceLevel',
      '(II)V',
      [id, level],
    );
  }

  /// Get the player's total experience points.
  int get totalExperience {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerTotalExperience',
      '(I)I',
      [id],
    );
  }

  /// Give experience points to the player.
  void giveExperience(int amount) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'givePlayerExperience',
      '(II)V',
      [id, amount],
    );
  }

  // ==========================================================================
  // Communication
  // ==========================================================================

  /// Send a chat message to the player.
  void sendMessage(String message) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'sendPlayerMessage',
      '(ILjava/lang/String;)V',
      [id, message],
    );
  }

  /// Send an action bar message to the player.
  void sendActionBar(String message) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'sendPlayerActionBar',
      '(ILjava/lang/String;)V',
      [id, message],
    );
  }

  /// Send a title and optional subtitle to the player.
  void sendTitle(
    String title, {
    String? subtitle,
    int fadeIn = 10,
    int stay = 70,
    int fadeOut = 20,
  }) {
    GenericJniBridge.callStaticVoidMethod(
      _dartBridge,
      'sendPlayerTitle',
      '(ILjava/lang/String;Ljava/lang/String;III)V',
      [id, title, subtitle ?? '', fadeIn, stay, fadeOut],
    );
  }

  // ==========================================================================
  // Player Info
  // ==========================================================================

  /// Get the player's display name.
  String get name {
    return GenericJniBridge.callStaticStringMethod(
          _dartBridge,
          'getPlayerName',
          '(I)Ljava/lang/String;',
          [id],
        ) ??
        '';
  }

  /// Get the player's UUID string.
  String get uuid {
    return GenericJniBridge.callStaticStringMethod(
          _dartBridge,
          'getPlayerUuid',
          '(I)Ljava/lang/String;',
          [id],
        ) ??
        '';
  }

  /// Check if the player is on the ground.
  bool get isOnGround {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isPlayerOnGround',
      '(I)Z',
      [id],
    );
  }

  /// Check if the player is sneaking.
  bool get isSneaking {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isPlayerSneaking',
      '(I)Z',
      [id],
    );
  }

  /// Check if the player is sprinting.
  bool get isSprinting {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isPlayerSprinting',
      '(I)Z',
      [id],
    );
  }

  /// Check if the player is swimming.
  bool get isSwimming {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isPlayerSwimming',
      '(I)Z',
      [id],
    );
  }

  /// Check if the player is flying (creative/spectator flight).
  bool get isFlying {
    return GenericJniBridge.callStaticBoolMethod(
      _dartBridge,
      'isPlayerFlying',
      '(I)Z',
      [id],
    );
  }

  @override
  String toString() => 'Player($id, name: $name)';

  @override
  bool operator ==(Object other) => other is Player && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Utility class for getting and managing players.
class Players {
  Players._();

  /// Get a player by their entity ID.
  /// Returns null if no player with that ID exists.
  static Player? getPlayer(int id) {
    // Check if player exists by trying to get their name
    final name = GenericJniBridge.callStaticStringMethod(
      _dartBridge,
      'getPlayerName',
      '(I)Ljava/lang/String;',
      [id],
    );
    if (name == null || name.isEmpty) return null;
    return Player(id);
  }

  /// Get a player by their name.
  /// Returns null if no player with that name is online.
  static Player? getPlayerByName(String name) {
    final id = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerIdByName',
      '(Ljava/lang/String;)I',
      [name],
    );
    if (id < 0) return null;
    return Player(id);
  }

  /// Get a player by their UUID.
  /// Returns null if no player with that UUID is online.
  static Player? getPlayerByUuid(String uuid) {
    final id = GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerIdByUuid',
      '(Ljava/lang/String;)I',
      [uuid],
    );
    if (id < 0) return null;
    return Player(id);
  }

  /// Get all online players.
  static List<Player> getAllPlayers() {
    final count = playerCount;
    final players = <Player>[];

    // Get all player IDs
    for (var i = 0; i < count; i++) {
      final id = GenericJniBridge.callStaticIntMethod(
        _dartBridge,
        'getPlayerIdByIndex',
        '(I)I',
        [i],
      );
      if (id >= 0) {
        players.add(Player(id));
      }
    }

    return players;
  }

  /// Get the number of online players.
  static int get playerCount {
    return GenericJniBridge.callStaticIntMethod(
      _dartBridge,
      'getPlayerCount',
      '()I',
      [],
    );
  }
}

/// Information about a player (snapshot of player data).
class PlayerInfo {
  final Player player;
  final String name;
  final BlockPos position;
  final Vec3 precisePosition;
  final double health;
  final double maxHealth;
  final int foodLevel;
  final double saturation;
  final GameMode gameMode;
  final int experienceLevel;
  final bool isOnGround;
  final bool isSneaking;
  final bool isSprinting;

  const PlayerInfo({
    required this.player,
    required this.name,
    required this.position,
    required this.precisePosition,
    required this.health,
    required this.maxHealth,
    required this.foodLevel,
    required this.saturation,
    required this.gameMode,
    required this.experienceLevel,
    required this.isOnGround,
    required this.isSneaking,
    required this.isSprinting,
  });

  /// Create a PlayerInfo snapshot from a Player.
  factory PlayerInfo.fromPlayer(Player player) {
    return PlayerInfo(
      player: player,
      name: player.name,
      position: player.position,
      precisePosition: player.precisePosition,
      health: player.health,
      maxHealth: player.maxHealth,
      foodLevel: player.foodLevel,
      saturation: player.saturation,
      gameMode: player.gameMode,
      experienceLevel: player.experienceLevel,
      isOnGround: player.isOnGround,
      isSneaking: player.isSneaking,
      isSprinting: player.isSprinting,
    );
  }

  @override
  String toString() => 'PlayerInfo($name at $position, health: $health/$maxHealth)';
}
