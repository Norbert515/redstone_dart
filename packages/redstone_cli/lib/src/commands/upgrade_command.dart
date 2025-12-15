import 'package:args/command_runner.dart';

import '../project/redstone_project.dart';
import '../util/logger.dart';

class UpgradeCommand extends Command<int> {
  @override
  final name = 'upgrade';

  @override
  final description = 'Upgrade the Redstone bridge and native libraries.';

  UpgradeCommand() {
    argParser.addFlag(
      'check',
      help: 'Check for updates without applying them.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    final project = RedstoneProject.find();
    if (project == null) {
      Logger.error('No Redstone project found.');
      return 1;
    }

    final checkOnly = argResults!['check'] as bool;

    Logger.newLine();
    Logger.header('Checking for Redstone updates...');
    Logger.newLine();

    // TODO: Implement actual version checking
    // For now, just show that it's up to date
    Logger.info('Current version: 0.1.0');
    Logger.info('Latest version:  0.1.0');
    Logger.newLine();

    if (checkOnly) {
      Logger.success('You are on the latest version!');
    } else {
      Logger.success('Already up to date!');
    }

    Logger.newLine();
    return 0;
  }
}
