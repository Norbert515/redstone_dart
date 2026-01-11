import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/logger.dart';

/// Generates a template Minecraft world for client E2E tests.
///
/// The template world is a pre-configured superflat world with optimized
/// settings for testing. The CLI copies this template before each test run
/// to ensure a clean, consistent starting state.
class TemplateWorldGenerator {
  /// The name of the test world in Minecraft saves.
  static const String testWorldName = 'dart_visual_test';

  /// Version of the template format. Increment this when making changes
  /// to the template structure to force regeneration.
  static const int _templateVersion = 5;

  /// Base64 encoded, gzip-compressed level.dat from a working superflat world
  // ignore: lines_longer_than_80_chars
  static const String _levelDatBase64 = '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';

  /// Path to the template world within .redstone directory.
  final String templateDir;

  TemplateWorldGenerator(String rootDir)
      : templateDir = p.join(rootDir, '.redstone', 'test_template_world');

  /// Generates the template world if it doesn't exist or is outdated.
  ///
  /// Returns true if the template was generated, false if it already existed
  /// and is up to date.
  Future<bool> generateIfNeeded() async {
    final versionFile = File(p.join(templateDir, '.version'));
    final levelDat = File(p.join(templateDir, 'level.dat'));

    // Check if template exists and is up to date
    if (await levelDat.exists() && await versionFile.exists()) {
      final currentVersion =
          int.tryParse(await versionFile.readAsString()) ?? 0;
      if (currentVersion >= _templateVersion) {
        Logger.debug('Template world already exists at: $templateDir');
        return false;
      }
      Logger.debug(
        'Template world outdated (v$currentVersion < v$_templateVersion), '
        'regenerating...',
      );
    }

    await generate();
    return true;
  }

  /// Generates the template world (overwrites if exists).
  Future<void> generate() async {
    Logger.debug('Generating template world at: $templateDir');

    // Create template directory structure
    final dir = Directory(templateDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    // Create empty region directory (Minecraft generates flat terrain on load)
    await Directory(p.join(templateDir, 'region')).create();

    // Create empty datapacks directory (required by Minecraft)
    await Directory(p.join(templateDir, 'datapacks')).create();

    // Create level.dat with optimized settings
    await _generateLevelDat();

    // Write version marker for future regeneration checks
    await File(p.join(templateDir, '.version'))
        .writeAsString('$_templateVersion');

    Logger.debug('Template world generated successfully (v$_templateVersion)');
  }

  /// Generates level.dat by decoding the base64 data from a working world.
  Future<void> _generateLevelDat() async {
    // Decode the base64 level.dat from a working superflat world
    final bytes = base64Decode(_levelDatBase64);
    final levelDatPath = p.join(templateDir, 'level.dat');
    await File(levelDatPath).writeAsBytes(bytes);

    Logger.debug('Generated level.dat at: $levelDatPath');
  }

  /// Copies the template world to the Minecraft saves directory.
  ///
  /// [savesDir] is the Minecraft saves directory (e.g., run/saves/)
  Future<void> copyToSaves(String savesDir) async {
    final targetDir = Directory(p.join(savesDir, testWorldName));

    // Remove existing world if present
    if (await targetDir.exists()) {
      Logger.debug('Removing existing test world: ${targetDir.path}');
      await targetDir.delete(recursive: true);
    }

    // Ensure saves directory exists
    await Directory(savesDir).create(recursive: true);

    // Copy template to saves
    Logger.debug('Copying template world to: ${targetDir.path}');
    await _copyDirectory(Directory(templateDir), targetDir);
  }

  /// Recursively copies a directory.
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);

    await for (final entity in source.list()) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }
}
