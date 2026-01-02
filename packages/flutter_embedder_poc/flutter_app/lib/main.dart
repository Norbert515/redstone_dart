import 'package:flutter/material.dart';
import 'package:minecraft_ui/minecraft_ui.dart';

void main() {
  runApp(const MinecraftGuiApp());
}

class MinecraftGuiApp extends StatelessWidget {
  const MinecraftGuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      home: const McTheme(
        guiScale: 1.0,  // Use 1.0 - embedder already handles scaling
        child: MinecraftGuiScreen(),
      ),
    );
  }
}

class MinecraftGuiScreen extends StatefulWidget {
  const MinecraftGuiScreen({super.key});

  @override
  State<MinecraftGuiScreen> createState() => _MinecraftGuiScreenState();
}

class _MinecraftGuiScreenState extends State<MinecraftGuiScreen> {
  int _counter = 0;
  bool _enableSound = true;
  double _volume = 0.7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: McPanel(
          width: 176,  // Standard Minecraft inventory width
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const McText.title('Flutter GUI'),
              const SizedBox(height: 8),

              // Counter display
              McPanel.inset(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const McText('Count:', color: McColors.darkGray),
                    McText(
                      '$_counter',
                      fontSize: 1.5,
                      color: McColors.formatYellow,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Buttons row
              Row(
                children: [
                  Expanded(
                    child: McButton(
                      text: '-',
                      onPressed: () => setState(() => _counter--),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: McButton(
                      text: '+',
                      onPressed: () => setState(() => _counter++),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Reset button
              McButton(
                text: 'Reset Counter',
                size: McButtonSize.large,
                onPressed: () => setState(() => _counter = 0),
              ),
              const SizedBox(height: 12),

              // Inventory slots
              const McText.label('Inventory'),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  9,
                  (index) => McSlot(
                    item: index < 3
                        ? Container(
                            margin: const EdgeInsets.all(1),
                            color: [
                              McColors.formatGold,
                              McColors.formatAqua,
                              McColors.formatGreen,
                            ][index],
                          )
                        : null,
                    count: index < 3 ? (index + 1) * 16 : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Settings
              McCheckbox(
                value: _enableSound,
                label: 'Sound Effects',
                onChanged: (v) => setState(() => _enableSound = v),
              ),
              const SizedBox(height: 8),

              McSlider(
                value: _volume,
                width: 150,
                label: 'Music: ${(_volume * 100).round()}%',
                onChanged: (v) => setState(() => _volume = v),
              ),
              const SizedBox(height: 8),

              // Close button
              McButton(
                text: 'Done',
                size: McButtonSize.large,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
