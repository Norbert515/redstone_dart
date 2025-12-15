import 'package:args/command_runner.dart';

import 'build_command.dart';
import 'create_command.dart';
import 'devices_command.dart';
import 'doctor_command.dart';
import 'generate_command.dart';
import 'run_command.dart';
import 'upgrade_command.dart';

const String version = '0.1.0';

class RedstoneCommandRunner extends CommandRunner<int> {
  RedstoneCommandRunner()
      : super(
          'redstone',
          'Redstone - The Flutter for Minecraft\n'
              'Build Minecraft mods with Dart.',
        ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the Redstone version.',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose logging.',
    );

    addCommand(BuildCommand());
    addCommand(CreateCommand());
    addCommand(DevicesCommand());
    addCommand(DoctorCommand());
    addCommand(GenerateCommand());
    addCommand(RunCommand());
    addCommand(UpgradeCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    final results = argParser.parse(args);

    if (results['version'] as bool) {
      print('Redstone $version');
      return 0;
    }

    return await super.run(args) ?? 0;
  }
}
