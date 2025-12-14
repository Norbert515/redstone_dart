/// Static UI demo component for nocterm Minecraft rendering.
///
/// A simple solid color fill to test that basic rendering works.
/// This is the simplest demo - no animation, just a red container.
library;

import 'package:nocterm/nocterm.dart';

/// A static UI demo component (no animation).
/// Simple solid color fill to test rendering works.
class StaticUIComponent extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    // Just a solid red container that fills the entire space
    return const Container(
      color: Colors.red,
    );
  }
}
