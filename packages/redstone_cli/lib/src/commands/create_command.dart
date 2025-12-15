import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../api/fabric_meta_api.dart';
import '../template/project_creator.dart';
import '../util/logger.dart';

class CreateCommand extends Command<int> {
  @override
  final name = 'create';

  @override
  final description = 'Create a new Redstone project.';

  @override
  final invocation = 'redstone create <project_name>';

  CreateCommand() {
    argParser.addOption(
      'org',
      help: 'The organization identifier (e.g., com.example).',
      defaultsTo: 'com.example',
    );
    argParser.addOption(
      'description',
      abbr: 'd',
      help: 'A short description of the mod.',
      defaultsTo: 'A Minecraft mod built with Redstone',
    );
    argParser.addOption(
      'author',
      help: 'The author name.',
    );
    argParser.addOption(
      'minecraft-version',
      abbr: 'm',
      help: 'The target Minecraft version (defaults to latest stable).',
    );
    argParser.addFlag(
      'empty',
      help: 'Create a minimal project without example code.',
      negatable: false,
    );
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      Logger.error('No project name specified.');
      Logger.info('Usage: redstone create <project_name>');
      return 1;
    }

    final projectName = argResults!.rest.first;

    // Validate project name
    if (!_isValidProjectName(projectName)) {
      Logger.error(
          'Invalid project name: "$projectName".\n'
          'Project names must be lowercase with underscores (e.g., my_mod).');
      return 1;
    }

    final targetDir = Directory(p.join(Directory.current.path, projectName));
    if (targetDir.existsSync()) {
      Logger.error('Directory "$projectName" already exists.');
      return 1;
    }

    // Get author from git config if not provided
    var author = argResults!['author'] as String?;
    if (author == null || author.isEmpty) {
      author = _getGitAuthor() ?? 'Your Name';
    }

    // Get Minecraft version - use provided or fetch latest from API
    var minecraftVersion = argResults!['minecraft-version'] as String?;
    if (minecraftVersion == null || minecraftVersion.isEmpty) {
      Logger.progress('Fetching latest Minecraft version');
      minecraftVersion = await FabricMetaApi.getLatestStableGameVersion();
      Logger.progressDone();
    }

    final config = ProjectConfig(
      name: projectName,
      description: argResults!['description'] as String,
      org: argResults!['org'] as String,
      author: author,
      minecraftVersion: minecraftVersion,
      empty: argResults!['empty'] as bool,
    );

    Logger.newLine();
    Logger.header('Creating Redstone project "$projectName"...');
    Logger.newLine();

    try {
      final creator = await ProjectCreator.create(config, targetDir.path);
      await creator.createProject();

      Logger.newLine();
      Logger.success('Project created successfully!');
      Logger.newLine();
      Logger.info('Next steps:');
      Logger.step('cd $projectName');
      Logger.step('redstone run');
      Logger.newLine();
      Logger.info('Happy modding! 🧱');
      Logger.newLine();

      return 0;
    } catch (e) {
      Logger.error('Failed to create project: $e');
      return 1;
    }
  }

  bool _isValidProjectName(String name) {
    // Must be lowercase with underscores, no spaces
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }

  String? _getGitAuthor() {
    try {
      final result = Process.runSync('git', ['config', 'user.name']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }
}
