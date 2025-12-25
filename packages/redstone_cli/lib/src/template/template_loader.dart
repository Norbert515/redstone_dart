import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Represents a template file to be rendered
class TemplateFile {
  /// The relative path within the target directory (after rendering)
  final String relativePath;

  /// The raw content of the template
  final String content;

  /// Whether this content should be rendered through mustache (true for .tmpl, false for .copy.tmpl)
  final bool shouldRender;

  TemplateFile({
    required this.relativePath,
    required this.content,
    required this.shouldRender,
  });
}

/// Loads templates from the templates directory
class TemplateLoader {
  final Directory templatesDir;
  late final Map<String, dynamic> manifest;

  TemplateLoader(this.templatesDir);

  /// Load the template manifest
  Future<void> load() async {
    final manifestFile =
        File(p.join(templatesDir.path, 'template_manifest.json'));
    if (!manifestFile.existsSync()) {
      throw Exception(
          'Template manifest not found at ${manifestFile.path}');
    }
    manifest = jsonDecode(await manifestFile.readAsString())
        as Map<String, dynamic>;
  }

  /// Get all template files for a given template name
  ///
  /// [templateName] is the template to use (e.g., 'mod' or 'mod_empty')
  /// [variables] is a map of variable names to values for filename rendering
  Future<List<TemplateFile>> getTemplateFiles(
    String templateName,
    Map<String, String> variables,
  ) async {
    final templates = manifest['templates'] as Map<String, dynamic>?;
    if (templates == null) {
      throw Exception('No templates defined in manifest');
    }

    final template = templates[templateName] as Map<String, dynamic>?;
    if (template == null) {
      throw Exception('Template "$templateName" not found in manifest');
    }

    // Get base files
    final List<String> files;
    final String baseTemplateName;

    if (template.containsKey('extends')) {
      // This template extends another one
      baseTemplateName = template['extends'] as String;
      final baseTemplate = templates[baseTemplateName] as Map<String, dynamic>?;
      if (baseTemplate == null) {
        throw Exception(
            'Base template "$baseTemplateName" not found for "$templateName"');
      }
      files = List<String>.from(baseTemplate['files'] as List);
    } else {
      baseTemplateName = templateName;
      files = List<String>.from(template['files'] as List);
    }

    // Get overrides if this template extends another
    final overrides = template.containsKey('overrides')
        ? Set<String>.from(template['overrides'] as List)
        : <String>{};

    final result = <TemplateFile>[];

    for (final filePath in files) {
      // Determine which template directory to use for this file
      final templateDir = overrides.contains(filePath)
          ? templateName
          : baseTemplateName;

      final fullPath = p.join(templatesDir.path, templateDir, filePath);
      final file = File(fullPath);

      if (!file.existsSync()) {
        throw Exception('Template file not found: $fullPath');
      }

      final content = await file.readAsString();
      final renderedPath = _renderFilename(filePath, variables);
      final shouldRender = !filePath.endsWith('.copy.tmpl');

      result.add(TemplateFile(
        relativePath: renderedPath,
        content: content,
        shouldRender: shouldRender,
      ));
    }

    return result;
  }

  /// Render a filename by replacing __variable__ patterns and removing .tmpl extension
  String _renderFilename(String filename, Map<String, String> variables) {
    var result = filename;

    // Replace __variable__ patterns in filenames
    for (final entry in variables.entries) {
      result = result.replaceAll('__${entry.key}__', entry.value);
    }

    // Remove .copy.tmpl or .tmpl extensions
    if (result.endsWith('.copy.tmpl')) {
      result = result.substring(0, result.length - 10);
    } else if (result.endsWith('.tmpl')) {
      result = result.substring(0, result.length - 5);
    }

    return result;
  }

  /// Find the templates directory
  ///
  /// Works both in development mode (running from source) and when installed.
  static Future<Directory> findTemplatesDir() async {
    // Try to find templates directory relative to CLI package
    var dir = Directory(Platform.script.toFilePath()).parent;

    // Walk up looking for pubspec.yaml with name: redstone_cli
    for (var i = 0; i < 5; i++) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (content.contains('name: redstone_cli')) {
          final templatesDir = Directory(p.join(dir.path, 'templates'));
          if (templatesDir.existsSync()) {
            return templatesDir;
          }
        }
      }
      dir = dir.parent;
    }

    // Fallback: try relative to current file path in development
    final scriptDir = Platform.script.toFilePath();
    if (scriptDir.contains('packages/redstone_cli')) {
      final idx = scriptDir.indexOf('packages/redstone_cli');
      final cliPath =
          scriptDir.substring(0, idx + 'packages/redstone_cli'.length);
      final templatesDir = Directory(p.join(cliPath, 'templates'));
      if (templatesDir.existsSync()) {
        return templatesDir;
      }
    }

    throw Exception(
        'Could not find templates directory. Make sure you are running from the redstone_cli package.');
  }

  /// Get available template names
  List<String> getAvailableTemplates() {
    final templates = manifest['templates'] as Map<String, dynamic>?;
    return templates?.keys.toList() ?? [];
  }

  /// Get template description
  String? getTemplateDescription(String templateName) {
    final templates = manifest['templates'] as Map<String, dynamic>?;
    final template = templates?[templateName] as Map<String, dynamic>?;
    return template?['description'] as String?;
  }
}
