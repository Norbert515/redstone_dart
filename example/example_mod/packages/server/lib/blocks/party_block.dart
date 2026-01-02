import 'package:dart_mod_server/dart_mod_server.dart';

/// Party Block - Creates a celebration effect with title and particles.
/// Demonstrates: Player titles, multiple particle types, sounds.
class PartyBlock extends CustomBlock {
  PartyBlock()
      : super(
          id: 'example_mod:party_block',
          settings: BlockSettings(hardness: 1.0, resistance: 1.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    // Big title
    player.sendTitle('§6§lPARTY TIME!', subtitle: '§e✨ Let\'s celebrate! ✨', fadeIn: 5, stay: 40, fadeOut: 10);

    // Lots of particles!
    world.spawnParticles(Particles.totemOfUndying, pos, count: 100, delta: Vec3(1.0, 1.5, 1.0), speed: 0.5);
    world.spawnParticles(Particles.firework, pos, count: 50, delta: Vec3(0.8, 1.0, 0.8), speed: 0.3);
    world.spawnParticles(Particles.note, pos, count: 20, delta: Vec3(0.5, 0.5, 0.5));

    // Totem sound (epic!)
    world.playSound(pos, Sounds.totem, volume: 1.0);

    // Give player some experience as a party favor
    player.giveExperience(100);

    player.sendMessage('§6[Party] §f🎉 You got §a100 XP§f as a party favor! 🎉');

    return ActionResult.success;
  }
}
