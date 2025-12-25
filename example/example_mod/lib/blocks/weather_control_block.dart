import 'package:dart_mc/dart_mc.dart';

/// Weather Control Block - Cycles through weather states and advances time.
/// Demonstrates: Weather API, time control, action bar messages, sneak detection.
class WeatherControlBlock extends CustomBlock {
  WeatherControlBlock()
      : super(
          id: 'example_mod:weather_control',
          settings: BlockSettings(hardness: 2.0, resistance: 6.0),
        );

  @override
  ActionResult onUse(int worldId, int x, int y, int z, int playerId, int hand) {
    final player = Players.getPlayer(playerId);
    if (player == null) return ActionResult.pass;

    final world = World.overworld;
    final pos = Vec3(x + 0.5, y + 1.0, z + 0.5);

    if (player.isSneaking) {
      // Sneak + right-click: Advance time by 1000 ticks
      final currentTime = world.timeOfDay;
      final newTime = (currentTime + 1000) % 24000;
      world.timeOfDay = newTime;

      final timeLabel = _getTimeLabel(newTime);
      player.sendActionBar('§e⏰ Time advanced to $timeLabel ($newTime ticks)');
      player.sendMessage('§e[Weather Control] §fAdvanced time to §a$timeLabel');
      world.playSound(pos, Sounds.click, volume: 0.8);
    } else {
      // Regular right-click: Cycle weather
      final currentWeather = world.weather;
      final Weather newWeather;
      final String weatherName;

      switch (currentWeather) {
        case Weather.clear:
          newWeather = Weather.rain;
          weatherName = '§9Rain';
        case Weather.rain:
          newWeather = Weather.thunder;
          weatherName = '§5Thunder';
        case Weather.thunder:
          newWeather = Weather.clear;
          weatherName = '§eClear';
      }

      world.setWeather(newWeather, 6000); // 5 minutes
      player.sendActionBar('§b☁ Weather changed to $weatherName');
      player.sendMessage('§b[Weather Control] §fWeather set to $weatherName §ffor 5 minutes');

      // Play appropriate sound
      if (newWeather == Weather.thunder) {
        world.playSound(pos, Sounds.thunder, volume: 0.5);
      } else {
        world.playSound(pos, Sounds.click, volume: 0.8);
      }
    }

    // Spawn particles around the block
    world.spawnParticles(Particles.enchant, pos, count: 30, delta: Vec3(0.5, 0.5, 0.5));

    return ActionResult.success;
  }

  String _getTimeLabel(int time) {
    if (time >= 0 && time < 6000) return 'Morning';
    if (time >= 6000 && time < 12000) return 'Noon';
    if (time >= 12000 && time < 18000) return 'Evening';
    return 'Night';
  }
}
