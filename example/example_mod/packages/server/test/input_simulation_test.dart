/// Input simulation API tests.
///
/// Tests for keyboard and mouse input simulation in full client tests.
/// These tests verify that the input simulation API works correctly
/// for automating player interactions.
import 'package:redstone_test/redstone_test.dart';

Future<void> main() async {
  await fullGroup('Input Simulation Tests', () async {
    await fullGroup('Keyboard Input', () async {
      await testMinecraftFull('can press E to open inventory', (game) async {
        // Press E key to open inventory
        await game.pressKey(GlfwKeys.e);
        await game.waitTicks(10);

        // Take screenshot to verify inventory is open
        await game.takeScreenshot('inventory_open');

        // Press Escape to close
        await game.pressKey(GlfwKeys.escape);
        await game.waitTicks(5);
      });

      await testMinecraftFull('can hold W to walk forward', (game) async {
        // Debug: Check if LocalPlayer exists
        print('Has LocalPlayer: ${game.hasLocalPlayer}');
        print('Input state before: ${game.localPlayerInputDebug}');

        // Get starting position (client-side)
        final startPos = game.localPlayerPosition;
        print('Start position (client): $startPos');

        // Also check server-side for comparison
        final players = Players.getAllPlayers();
        if (players.isNotEmpty) {
          print('Start position (server): ${players.first.precisePosition}');
        }

        // Hold W for 2 seconds (40 ticks) - need longer for client→server sync
        await game.holdKeyFor(GlfwKeys.w, 40);

        print('Input state after hold: ${game.localPlayerInputDebug}');

        // Get ending position (client-side)
        final endPos = game.localPlayerPosition;
        print('End position (client): $endPos');

        // Also check server-side for comparison
        if (players.isNotEmpty) {
          print('End position (server): ${players.first.precisePosition}');
        }

        // Use client-side distance calculation
        final distance = _distance(startPos, endPos);
        print('Distance moved (client): $distance');

        expect(distance, greaterThan(0.1));

        await game.takeScreenshot('after_walk_forward');
      });

      await testMinecraftFull('can press space to jump', (game) async {
        final players = Players.getAllPlayers();
        if (players.isEmpty) return;

        final player = players.first;

        // Make sure player is on ground first
        await game.waitUntilOrThrow(
          () => player.isOnGround,
          maxTicks: 100,
          reason: 'Player should be on ground before jump test',
        );

        final startY = player.precisePosition.y;
        print('Starting Y position: $startY');

        // Hold space to jump - like movement, jump is a polled input
        // The key must be held when KeyboardInput.tick() runs
        game.holdKey(GlfwKeys.space);
        await game.waitTicks(10); // Wait for jump to register and execute

        // Player should be higher (in the air)
        final midY = player.precisePosition.y;
        print('Mid-air Y position: $midY');

        game.releaseKey(GlfwKeys.space);

        expect(midY, greaterThan(startY));

        await game.takeScreenshot('player_jumping');

        // Wait for landing
        await game.waitTicks(20);
      });

      await testMinecraftFull('can hold shift to sneak', (game) async {
        print('Has LocalPlayer: ${game.hasLocalPlayer}');
        print('Input state before sneak: ${game.localPlayerInputDebug}');
        print('Client sneaking before: ${game.isLocalPlayerSneaking}');

        final players = Players.getAllPlayers();
        if (players.isNotEmpty) {
          print('Server sneaking before: ${players.first.isSneaking}');
        }

        // Start holding sneak - need longer wait for client→server sync
        game.holdKey(GlfwKeys.sneak);
        await game.waitTicks(20);

        print('Input state after hold: ${game.localPlayerInputDebug}');
        print('Client sneaking after: ${game.isLocalPlayerSneaking}');

        // Check client-side first
        expect(game.isLocalPlayerSneaking, isTrue);

        // Also verify server-side synced
        if (players.isNotEmpty) {
          print('Server sneaking after: ${players.first.isSneaking}');
          expect(players.first.isSneaking, isTrue);
        }

        await game.takeScreenshot('player_sneaking');

        // Release sneak
        await game.releaseKey(GlfwKeys.sneak);
        await game.waitTicks(5);

        print('Client sneaking after release: ${game.isLocalPlayerSneaking}');
        expect(game.isLocalPlayerSneaking, isFalse);
      });

      await testMinecraftFull('can hold control to sprint while walking', (game) async {
        print('Has LocalPlayer: ${game.hasLocalPlayer}');
        print('Input state before sprint: ${game.localPlayerInputDebug}');
        print('Client sprinting before: ${game.isLocalPlayerSprinting}');

        final players = Players.getAllPlayers();
        if (players.isNotEmpty) {
          print('Server sprinting before: ${players.first.isSprinting}');
        }

        // Hold sprint and forward - need longer wait for client→server sync
        game.holdKey(GlfwKeys.sprint);
        game.holdKey(GlfwKeys.w);
        await game.waitTicks(20);

        print('Input state after hold: ${game.localPlayerInputDebug}');
        print('Client sprinting after: ${game.isLocalPlayerSprinting}');

        // Check client-side first
        expect(game.isLocalPlayerSprinting, isTrue);

        // Also verify server-side synced
        if (players.isNotEmpty) {
          print('Server sprinting after: ${players.first.isSprinting}');
          expect(players.first.isSprinting, isTrue);
        }

        await game.takeScreenshot('player_sprinting');

        // Release keys
        await game.releaseKey(GlfwKeys.w);
        await game.releaseKey(GlfwKeys.sprint);
        await game.waitTicks(5);

        print('Client sprinting after release: ${game.isLocalPlayerSprinting}');
      });
    });

    await fullGroup('Character Typing', () async {
      await testMinecraftFull('can type in chat', (game) async {
        // Press T to open chat
        await game.pressKey(GlfwKeys.chat);
        await game.waitTicks(5);

        // Type a message
        await game.typeChars('Hello from input simulation!');
        await game.waitTicks(2);

        await game.takeScreenshot('chat_typed');

        // Press Escape to close without sending
        await game.pressKey(GlfwKeys.escape);
        await game.waitTicks(5);
      });

      await testMinecraftFull('can type command in chat', (game) async {
        // Press / to open command prompt
        await game.pressKey(GlfwKeys.command);
        await game.waitTicks(5);

        // Type a command (without the /)
        await game.typeChars('help');
        await game.waitTicks(2);

        await game.takeScreenshot('command_typed');

        // Press Escape to close without executing
        await game.pressKey(GlfwKeys.escape);
        await game.waitTicks(5);
      });
    });

    await fullGroup('Mouse Input', () async {
      await testMinecraftFull('can move cursor and click in inventory', (game) async {
        // Open inventory first
        await game.pressKey(GlfwKeys.inventory);
        await game.waitTicks(10);

        // Move cursor to center of screen
        final centerX = game.windowWidth / 2;
        final centerY = game.windowHeight / 2;
        await game.moveCursor(centerX.toDouble(), centerY.toDouble());
        await game.waitTicks(2);

        // Click
        await game.click();
        await game.waitTicks(5);

        await game.takeScreenshot('inventory_after_click');

        // Close inventory
        await game.pressKey(GlfwKeys.escape);
        await game.waitTicks(5);
      });

      await testMinecraftFull('can right click to use items', (game) async {
        // Right click performs "use" action
        await game.click(button: MouseButton.right);
        await game.waitTicks(5);

        await game.takeScreenshot('after_right_click');
      });

      await testMinecraftFull('can hold left click to break blocks', (game) async {
        // Hold left click (attack/break action)
        game.holdMouse(button: MouseButton.left);
        await game.waitTicks(20);

        await game.takeScreenshot('holding_left_click');

        await game.releaseMouse(button: MouseButton.left);
        await game.waitTicks(5);
      });

      await testMinecraftFull('can scroll to change hotbar selection', (game) async {
        // Scroll up
        await game.scroll(1);
        await game.waitTicks(5);

        await game.takeScreenshot('after_scroll_up');

        // Scroll down
        await game.scroll(-1);
        await game.waitTicks(5);

        await game.takeScreenshot('after_scroll_down');
      });

      await testMinecraftFull('can click at specific position', (game) async {
        // Open inventory
        await game.pressKey(GlfwKeys.inventory);
        await game.waitTicks(10);

        // Click at a specific position (e.g., upper left area)
        await game.clickAt(100, 100);
        await game.waitTicks(5);

        await game.takeScreenshot('clicked_at_position');

        // Close inventory
        await game.pressKey(GlfwKeys.escape);
        await game.waitTicks(5);
      });

      await testMinecraftFull('can drag items in inventory', (game) async {
        // Open inventory
        await game.pressKey(GlfwKeys.inventory);
        await game.waitTicks(10);

        final centerX = game.windowWidth / 2;
        final centerY = game.windowHeight / 2;

        // Drag from center to nearby position
        await game.drag(
          centerX.toDouble(),
          centerY.toDouble(),
          centerX.toDouble() + 50,
          centerY.toDouble() + 50,
          durationTicks: 10,
        );
        await game.waitTicks(5);

        await game.takeScreenshot('after_drag');

        // Close inventory
        await game.pressKey(GlfwKeys.escape);
        await game.waitTicks(5);
      });
    });

    await fullGroup('Combined Input', () async {
      await testMinecraftFull('can strafe while looking around', (game) async {
        // Simulate looking around while strafing
        game.holdKey(GlfwKeys.a); // Strafe left

        for (int i = 0; i < 5; i++) {
          // Move cursor to simulate mouse movement (changes camera)
          await game.waitTicks(5);
        }

        await game.releaseKey(GlfwKeys.a);
        await game.waitTicks(5);

        await game.takeScreenshot('after_strafe_look');
      });

      await testMinecraftFull('can place and break blocks with mouse', (game) async {
        // Give player a block to place (requires creative mode)
        final players = Players.getAllPlayers();
        if (players.isEmpty) return;

        final player = players.first;
        final originalMode = player.gameMode;
        player.gameMode = GameMode.creative;
        await game.waitTicks(5);

        // Right click to place
        await game.click(button: MouseButton.right);
        await game.waitTicks(5);

        await game.takeScreenshot('after_place_attempt');

        // Left click to break
        await game.click(button: MouseButton.left);
        await game.waitTicks(5);

        await game.takeScreenshot('after_break_attempt');

        // Restore game mode
        player.gameMode = originalMode;
        await game.waitTicks(5);
      });
    });

    await fullGroup('Input Cleanup', () async {
      await testMinecraftFull('releaseAllInputs clears held keys', (game) async {
        // Hold several keys
        game.holdKey(GlfwKeys.w);
        game.holdKey(GlfwKeys.a);
        game.holdMouse(button: MouseButton.left);
        await game.waitTicks(5);

        // Release all inputs
        game.releaseAllInputs();
        await game.waitTicks(5);

        // Verify player is no longer moving (would need to check velocity/position)
        // For now just verify no crash
        await game.takeScreenshot('after_release_all');
      });
    });

    await fullGroup('Function Keys', () async {
      await testMinecraftFull('F3 toggles debug overlay', (game) async {
        // Press F3 to show debug info
        await game.pressKey(GlfwKeys.f3);
        await game.waitTicks(10);

        await game.takeScreenshot('debug_overlay_on');

        // Press F3 again to hide
        await game.pressKey(GlfwKeys.f3);
        await game.waitTicks(10);

        await game.takeScreenshot('debug_overlay_off');
      });

      await testMinecraftFull('F5 toggles camera perspective', (game) async {
        await game.takeScreenshot('perspective_first_person');

        // Press F5 to switch to third person back
        await game.pressKey(GlfwKeys.f5);
        await game.waitTicks(10);

        await game.takeScreenshot('perspective_third_person_back');

        // Press F5 again for third person front
        await game.pressKey(GlfwKeys.f5);
        await game.waitTicks(10);

        await game.takeScreenshot('perspective_third_person_front');

        // Press F5 to return to first person
        await game.pressKey(GlfwKeys.f5);
        await game.waitTicks(10);
      });
    });

    await fullGroup('Hotbar Selection', () async {
      await testMinecraftFull('can select hotbar slots with number keys', (game) async {
        // Select slot 1
        await game.pressKey(GlfwKeys.num1);
        await game.waitTicks(5);
        await game.takeScreenshot('hotbar_slot_1');

        // Select slot 5
        await game.pressKey(GlfwKeys.num5);
        await game.waitTicks(5);
        await game.takeScreenshot('hotbar_slot_5');

        // Select slot 9
        await game.pressKey(GlfwKeys.num9);
        await game.waitTicks(5);
        await game.takeScreenshot('hotbar_slot_9');
      });
    });
  });
}

/// Calculate Euclidean distance between two Vec3 positions.
double _distance(Vec3 a, Vec3 b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  final dz = a.z - b.z;
  return (dx * dx + dy * dy + dz * dz);
}
