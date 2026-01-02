import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// Recreates the Minecraft Pause Menu
class PauseMenuScreen extends StatefulWidget {
  const PauseMenuScreen({super.key});

  @override
  State<PauseMenuScreen> createState() => _PauseMenuScreenState();
}

class _PauseMenuScreenState extends State<PauseMenuScreen> {
  bool _showOptions = false;
  double _musicVolume = 1.0;
  double _soundVolume = 1.0;
  bool _showCoordinates = true;
  int _renderDistance = 12;

  @override
  Widget build(BuildContext context) {
    return McTheme(
      guiScale: 2.0,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                McColors.transparentOverlayTop,
                McColors.transparentOverlayBottom,
              ],
            ),
          ),
          child: Center(
            child: _showOptions ? _buildOptionsMenu() : _buildPauseMenu(),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const McText('Game Menu', fontSize: 2),
        const SizedBox(height: 32),

        // Back to Game
        McButton(
          text: 'Back to Game',
          size: McButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),

        // Advancements (disabled)
        const McButton(
          text: 'Advancements',
          size: McButtonSize.large,
          enabled: false,
        ),
        const SizedBox(height: 8),

        // Statistics (disabled)
        const McButton(
          text: 'Statistics',
          size: McButtonSize.large,
          enabled: false,
        ),
        const SizedBox(height: 8),

        // Options row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 98,
              child: McButton(
                text: 'Options...',
                onPressed: () => setState(() => _showOptions = true),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 98,
              child: McButton(
                text: 'Open to LAN',
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Save and Quit
        McButton(
          text: 'Save and Quit to Title',
          size: McButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildOptionsMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const McText('Options', fontSize: 2),
        const SizedBox(height: 32),

        // Music Volume slider
        McSlider(
          value: _musicVolume,
          width: 200,
          label: 'Music: ${(_musicVolume * 100).toInt()}%',
          onChanged: (v) => setState(() => _musicVolume = v),
        ),
        const SizedBox(height: 8),

        // Sound Volume slider
        McSlider(
          value: _soundVolume,
          width: 200,
          label: 'Sound: ${(_soundVolume * 100).toInt()}%',
          onChanged: (v) => setState(() => _soundVolume = v),
        ),
        const SizedBox(height: 16),

        // Show Coordinates checkbox
        McCheckbox(
          value: _showCoordinates,
          label: 'Show Coordinates',
          onChanged: (v) => setState(() => _showCoordinates = v),
        ),
        const SizedBox(height: 16),

        // Render Distance
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const McText('Render Distance: '),
            McButton(
              text: '-',
              width: 30,
              onPressed: _renderDistance > 2
                  ? () => setState(() => _renderDistance--)
                  : null,
            ),
            const SizedBox(width: 8),
            McText('$_renderDistance chunks'),
            const SizedBox(width: 8),
            McButton(
              text: '+',
              width: 30,
              onPressed: _renderDistance < 32
                  ? () => setState(() => _renderDistance++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Video Settings (disabled)
        const McButton(
          text: 'Video Settings...',
          size: McButtonSize.large,
          enabled: false,
        ),
        const SizedBox(height: 8),

        // Controls (disabled)
        const McButton(
          text: 'Controls...',
          size: McButtonSize.large,
          enabled: false,
        ),
        const SizedBox(height: 8),

        // Done button
        McButton(
          text: 'Done',
          size: McButtonSize.large,
          onPressed: () => setState(() => _showOptions = false),
        ),
      ],
    );
  }
}
