import 'package:mustache_template/mustache_template.dart';

/// Template renderer using Mustache syntax ({{variable}})
class TemplateRenderer {
  final Map<String, String> variables;

  TemplateRenderer(this.variables);

  /// Render a template string, replacing {{variable}} with values
  ///
  /// Uses the mustache_template package for rendering, with:
  /// - lenient: true - allows missing variables without errors
  /// - htmlEscapeValues: false - prevents HTML escaping of values
  String render(String template) {
    final t = Template(template, lenient: true, htmlEscapeValues: false);
    return t.renderString(variables);
  }

  /// Render a filename by replacing __variable__ patterns and removing .tmpl extension
  ///
  /// Filenames use __variable__ syntax instead of {{variable}} to avoid
  /// filesystem issues on some platforms.
  String renderFilename(String filename) {
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
}
