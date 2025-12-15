import 'package:args/command_runner.dart';

import '../util/logger.dart';

class DevicesCommand extends Command<int> {
  @override
  final name = 'devices';

  @override
  final description = 'List available Minecraft versions and configurations.';

  @override
  Future<int> run() async {
    Logger.newLine();
    Logger.header('Available Minecraft configurations:');
    Logger.newLine();

    // For now, just show hardcoded versions
    // TODO: Detect installed versions or allow configuration
    final devices = [
      _Device('minecraft-1.21.11', 'Fabric 0.18.2', true),
      _Device('minecraft-1.21.1', 'Fabric 0.18.2', false),
      _Device('minecraft-1.20.4', 'Fabric 0.15.0', false),
      _Device('minecraft-1.20.1', 'Fabric 0.14.0', false),
    ];

    for (final device in devices) {
      final defaultMark = device.isDefault ? ' (default)' : '';
      Logger.keyValue(
        device.name,
        '• ${device.fabricVersion}$defaultMark',
        keyWidth: 20,
      );
    }

    Logger.newLine();
    Logger.info('To use a specific version:');
    Logger.step('redstone run -d minecraft-1.20.4');
    Logger.newLine();

    return 0;
  }
}

class _Device {
  final String name;
  final String fabricVersion;
  final bool isDefault;

  _Device(this.name, this.fabricVersion, this.isDefault);
}
