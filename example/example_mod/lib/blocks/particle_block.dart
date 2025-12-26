import 'package:dart_mc/dart_mc.dart';

/// Block that spawns flame particles when stepped on
class ParticleBlock extends CustomBlock {
  ParticleBlock()
      : super(
          id: 'example_mod:particle_block',
          settings: const BlockSettings(hardness: 0.5),
          model: BlockModel.cubeAll(
              texture: 'assets/textures/block/particle.png'),
        );

  @override
  void onSteppedOn(int worldId, int x, int y, int z, int entityId) {
    World.overworld.spawnParticles(
      Particles.flame,
      Vec3(x + 0.5, y + 1.0, z + 0.5),
      count: 3,
    );
  }
}
