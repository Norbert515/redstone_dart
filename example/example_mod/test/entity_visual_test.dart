/// Visual tests for entity rendering in example_mod.
///
/// These tests spawn custom entities and take screenshots to verify
/// that entity models render correctly in the Minecraft client.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  // Flat world ground level is at Y=-60
  const int groundY = -60;

  await clientGroup('Entity Visual Tests', () async {
    await testMinecraftClient('dart_zombie entity renders', (game) async {
      // Clear area and set up for entity viewing
      final spawnPos = Vec3(100, groundY.toDouble(), 100);
      final cameraPos = BlockPos(105, groundY + 2, 105);
      final lookAtPos = BlockPos(100, groundY + 1, 100);

      // Position camera slightly away, looking at spawn point
      await game.positionCameraLookingAt(cameraPos, lookAt: lookAtPos);
      await game.waitTicks(5);

      // Spawn the entity
      game.spawnEntity('example_mod:dart_zombie', spawnPos);
      await game.waitTicks(20); // Wait 1 second for entity to spawn and render

      // Take screenshot
      final screenshotPath = await game.takeScreenshot('dart_zombie_render');
      print('Screenshot saved to: $screenshotPath');
    });

    await testMinecraftClient('dart_cow entity renders', (game) async {
      final spawnPos = Vec3(110, groundY.toDouble(), 100);
      final cameraPos = BlockPos(115, groundY + 2, 105);
      final lookAtPos = BlockPos(110, groundY + 1, 100);

      await game.positionCameraLookingAt(cameraPos, lookAt: lookAtPos);
      await game.waitTicks(5);

      game.spawnEntity('example_mod:dart_cow', spawnPos);
      await game.waitTicks(20);

      final screenshotPath = await game.takeScreenshot('dart_cow_render');
      print('Screenshot saved to: $screenshotPath');
    });

    await testMinecraftClient('multiple entities render together', (game) async {
      final zombiePos = Vec3(120, groundY.toDouble(), 100);
      final cowPos = Vec3(123, groundY.toDouble(), 100);
      final cameraPos = BlockPos(121, groundY + 3, 108);
      final lookAtPos = BlockPos(121, groundY + 1, 100);

      // Position camera to see both entities
      await game.positionCameraLookingAt(cameraPos, lookAt: lookAtPos);
      await game.waitTicks(5);

      // Spawn both entities
      game.spawnEntity('example_mod:dart_zombie', zombiePos);
      game.spawnEntity('example_mod:dart_cow', cowPos);
      await game.waitTicks(40); // Wait 2 seconds for both to render

      final screenshotPath = await game.takeScreenshot('both_entities_render');
      print('Screenshot saved to: $screenshotPath');
    });
  });
}
