import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

/// Showcase of all available widgets
class WidgetShowcase extends StatefulWidget {
  const WidgetShowcase({super.key});

  @override
  State<WidgetShowcase> createState() => _WidgetShowcaseState();
}

class _WidgetShowcaseState extends State<WidgetShowcase> {
  bool _checkboxValue = false;
  double _sliderValue = 0.5;
  int _selectedTab = 0;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: McButton(
                      text: '< Back',
                      size: McButtonSize.small,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const McText('Widget Showcase', fontSize: 2),
                  const SizedBox(height: 32),

                  // Buttons section
                  _buildSection(
                    'Buttons',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        McButton(
                          text: 'Normal',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        const McButton(
                          text: 'Disabled',
                          enabled: false,
                        ),
                      ],
                    ),
                  ),

                  // Button sizes
                  _buildSection(
                    'Button Sizes',
                    Column(
                      children: [
                        McButton(
                          text: 'Small Button',
                          size: McButtonSize.small,
                          onPressed: () {},
                        ),
                        const SizedBox(height: 8),
                        McButton(
                          text: 'Medium Button',
                          size: McButtonSize.medium,
                          onPressed: () {},
                        ),
                        const SizedBox(height: 8),
                        McButton(
                          text: 'Large Button',
                          size: McButtonSize.large,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

                  // Panel section
                  _buildSection(
                    'Panels',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        McPanel(
                          width: 100,
                          height: 60,
                          child: const Center(
                            child: McText.label('Normal'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        McPanel.inset(
                          width: 100,
                          height: 60,
                          child: const Center(
                            child: McText('Inset', shadow: false),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slots section
                  _buildSection(
                    'Inventory Slots',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const McSlot(),
                        const McSlot(),
                        McSlot(
                          item: Container(
                            color: McColors.formatGreen,
                          ),
                          count: 64,
                          onTap: () {},
                        ),
                        const McSlot(),
                      ],
                    ),
                  ),

                  // Text section
                  _buildSection(
                    'Text Styles',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const McText('Default text with shadow'),
                        const McText.title('Title text (no shadow)'),
                        const McText.label('Label text'),
                        const McText.disabled('Disabled text'),
                        const SizedBox(height: 8),
                        const McFormattedText('§aGreen §cRed §9Blue §eYellow §lBold'),
                      ],
                    ),
                  ),

                  // Checkbox section
                  _buildSection(
                    'Checkbox',
                    Column(
                      children: [
                        McCheckbox(
                          value: _checkboxValue,
                          label: 'Enable Feature',
                          onChanged: (v) => setState(() => _checkboxValue = v),
                        ),
                        const SizedBox(height: 8),
                        const McCheckbox(
                          value: true,
                          label: 'Disabled Checkbox',
                          enabled: false,
                        ),
                      ],
                    ),
                  ),

                  // Slider section
                  _buildSection(
                    'Slider',
                    Column(
                      children: [
                        McSlider(
                          value: _sliderValue,
                          label: 'Volume: ${(_sliderValue * 100).toInt()}%',
                          onChanged: (v) => setState(() => _sliderValue = v),
                        ),
                        const SizedBox(height: 8),
                        const McSlider(
                          value: 0.3,
                          label: 'Disabled',
                          enabled: false,
                        ),
                      ],
                    ),
                  ),

                  // Progress bars section
                  _buildSection(
                    'Progress Bars',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          children: [
                            const McText('Arrow (50%)'),
                            const SizedBox(height: 4),
                            const McProgressBar.arrow(progress: 0.5),
                          ],
                        ),
                        const SizedBox(width: 32),
                        Column(
                          children: [
                            const McText('Flame (75%)'),
                            const SizedBox(height: 4),
                            const McProgressBar.flame(progress: 0.75),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tabs section
                  _buildSection(
                    'Tab Bar',
                    Column(
                      children: [
                        McTabBar(
                          tabs: const [
                            McTab(label: 'Survival'),
                            McTab(label: 'Creative'),
                            McTab(label: 'Hardcore'),
                          ],
                          selectedIndex: _selectedTab,
                          onTabSelected: (i) => setState(() => _selectedTab = i),
                        ),
                        const SizedBox(height: 8),
                        McText('Selected: ${['Survival', 'Creative', 'Hardcore'][_selectedTab]}'),
                      ],
                    ),
                  ),

                  // Tooltip section
                  _buildSection(
                    'Tooltip',
                    McTooltip(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          McText('Diamond Sword', color: McColors.formatAqua),
                          McText('+7 Attack Damage', color: McColors.formatDarkGreen),
                          SizedBox(height: 4),
                          McText('When in Main Hand:', color: McColors.formatGray),
                          McText(' +7 Attack Damage', color: McColors.formatDarkGreen),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      children: [
        const SizedBox(height: 16),
        McText(title, color: McColors.formatGold, fontSize: 1.2),
        const SizedBox(height: 8),
        McPanel(
          padding: const EdgeInsets.all(16),
          child: content,
        ),
      ],
    );
  }
}
