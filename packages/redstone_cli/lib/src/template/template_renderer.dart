/// Simple template renderer using {{variable}} syntax
class TemplateRenderer {
  final Map<String, String> variables;

  TemplateRenderer(this.variables);

  /// Render a template string, replacing {{variable}} with values
  String render(String template) {
    var result = template;

    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }

    return result;
  }

  /// Render a filename (same syntax as content)
  String renderFilename(String filename) {
    return render(filename).replaceAll('.tmpl', '');
  }
}
