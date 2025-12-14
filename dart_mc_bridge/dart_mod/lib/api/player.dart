/// Player API for interacting with Minecraft players.
library;

import '../src/types.dart';

/// Represents a player in the game.
class Player {
  /// Unique player ID (entity ID in the current session).
  final int id;

  const Player(this.id);

  @override
  String toString() => 'Player($id)';

  @override
  bool operator ==(Object other) => other is Player && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Information about a player.
class PlayerInfo {
  final Player player;
  final String? name;
  final BlockPos? position;
  final double? health;
  final int? foodLevel;

  const PlayerInfo({
    required this.player,
    this.name,
    this.position,
    this.health,
    this.foodLevel,
  });

  @override
  String toString() => 'PlayerInfo($name at $position)';
}

// TODO: Add methods to interact with players via native bridge
// These will require additional JNI functions to get player data from Minecraft
//
// Example future API:
// class Players {
//   static PlayerInfo? getPlayer(int id) { ... }
//   static List<Player> getAllPlayers() { ... }
//   static void sendMessage(Player player, String message) { ... }
//   static BlockPos? getPosition(Player player) { ... }
// }
