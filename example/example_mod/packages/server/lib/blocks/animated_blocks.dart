import 'package:dart_mod_server/dart_mod_server.dart';

/// A block that spins continuously around the Y axis.
class SpinningBlock extends CustomBlock {
  SpinningBlock()
      : super(
          id: 'example_mod:spinning_block',
          settings: BlockSettings(hardness: 1.0),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/spinning_block.png',
          ),
          animation: BlockAnimation.spin(speed: 1.0),
        );
}

/// A floating crystal that spins and bobs up and down.
class FloatingCrystalBlock extends CustomBlock {
  FloatingCrystalBlock()
      : super(
          id: 'example_mod:floating_crystal',
          settings: BlockSettings(hardness: 2.0),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/floating_crystal.png',
          ),
          animation: BlockAnimation.combine([
            BlockAnimation.spin(axis: Axis3D.y, speed: 0.5),
            BlockAnimation.bob(amplitude: 0.1, frequency: 1.0),
          ]),
        );
}

/// A pulsing block that grows and shrinks.
class PulsingBlock extends CustomBlock {
  PulsingBlock()
      : super(
          id: 'example_mod:pulsing_block',
          settings: BlockSettings(hardness: 1.5),
          model: BlockModel.cubeAll(
            texture: 'assets/textures/block/pulsing_block.png',
          ),
          animation: BlockAnimation.pulse(
            minScale: 0.85,
            maxScale: 1.0,
            frequency: 0.8,
          ),
        );
}
