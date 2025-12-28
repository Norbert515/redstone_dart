import React, { useState } from 'react';

type FeatureKey = 'blocks' | 'items' | 'entities' | 'commands' | 'recipes' | 'loot';

interface Feature {
  key: FeatureKey;
  label: string;
  filename: string;
  icon: string;
  code: string;
}

const features: Feature[] = [
  {
    key: 'blocks',
    label: 'Blocks',
    filename: 'blocks.dart',
    icon: '🧱',
    code: `class MagicBlock extends CustomBlock {
  MagicBlock() : super(
    id: 'mymod:magic_block',
    settings: BlockSettings(
      hardness: 2.0,
      luminance: 15,
    ),
  );

  @override
  ActionResult onUse(Player player, BlockPos pos) {
    player.sendMessage('Hello from Dart!');
    return ActionResult.success;
  }
}`,
  },
  {
    key: 'items',
    label: 'Items',
    filename: 'items.dart',
    icon: '⚔️',
    code: `class MagicWand extends CustomItem {
  MagicWand() : super(
    id: 'mymod:magic_wand',
    settings: ItemSettings(
      maxStackSize: 1,
      rarity: Rarity.epic,
    ),
  );

  @override
  ActionResult onUse(Player player, Hand hand) {
    player.addEffect(Effect.speed, duration: 200);
    return ActionResult.success;
  }
}`,
  },
  {
    key: 'entities',
    label: 'Entities',
    filename: 'entities.dart',
    icon: '🧟',
    code: `class FriendlyZombie extends CustomMonster {
  FriendlyZombie() : super(
    id: 'mymod:friendly_zombie',
    settings: MonsterSettings(
      maxHealth: 30,
      attackDamage: 0,
      model: EntityModel.humanoid(
        texture: 'textures/friendly_zombie.png',
      ),
    ),
  );
}`,
  },
  {
    key: 'commands',
    label: 'Commands',
    filename: 'commands.dart',
    icon: '⌨️',
    code: `CommandRegistry.register(
  Command('heal')
    .argument('amount', IntArgument())
    .executes((ctx) {
      final amount = ctx.getInt('amount');
      ctx.player.heal(amount);
      ctx.player.sendMessage('Healed \$amount HP!');
    }),
);`,
  },
  {
    key: 'recipes',
    label: 'Recipes',
    filename: 'recipes.dart',
    icon: '📖',
    code: `RecipeRegistry.register(
  ShapedRecipe(
    id: 'mymod:magic_wand',
    pattern: [
      '  D',
      ' S ',
      'S  ',
    ],
    ingredients: {
      'D': Item.diamond,
      'S': Item.stick,
    },
    result: ItemStack(MyItems.magicWand),
  ),
);`,
  },
  {
    key: 'loot',
    label: 'Loot',
    filename: 'loot_tables.dart',
    icon: '💎',
    code: `LootTableRegistry.register(
  LootTable(
    id: 'mymod:friendly_zombie',
    pools: [
      LootPool(
        rolls: Range(1, 3),
        entries: [
          ItemEntry(Item.diamond, weight: 1),
          ItemEntry(Item.emerald, weight: 2),
          ItemEntry(Item.goldIngot, weight: 5),
        ],
      ),
    ],
  ),
);`,
  },
];

// Dart syntax highlighting
function highlightDart(code: string): React.ReactElement[] {
  const lines = code.split('\n');

  return lines.map((line, lineIndex) => {
    const tokens: React.ReactElement[] = [];
    let remaining = line;
    let tokenIndex = 0;

    const patterns: [RegExp, string][] = [
      // Comments
      [/^(\/\/.*)/, 'text-zinc-500'],
      // Strings
      [/^('(?:[^'\\]|\\.)*')/, 'text-green-400'],
      // Numbers
      [/^(\d+\.?\d*)/, 'text-orange-400'],
      // Keywords
      [/^(class|extends|super|return|final|void|override|new|this|if|else|for|while|switch|case|break|continue|true|false|null)\b/, 'text-purple-400'],
      // Types and class names (capitalized words)
      [/^([A-Z][a-zA-Z0-9]*)\b/, 'text-cyan-300'],
      // Annotations
      [/^(@\w+)/, 'text-zinc-500'],
      // Method calls and function names
      [/^(\.[a-z][a-zA-Z0-9]*)\s*\(/, 'text-blue-300'],
      [/^([a-z][a-zA-Z0-9]*)\s*\(/, 'text-blue-300'],
      // Property access
      [/^(\.[a-z][a-zA-Z0-9]*)/, 'text-white'],
      // Identifiers
      [/^([a-z_][a-zA-Z0-9_]*)/, 'text-white'],
      // Operators and punctuation
      [/^([{}()\[\]:;,.<>=+\-*\/!?&|]+)/, 'text-white'],
      // Whitespace
      [/^(\s+)/, ''],
      // Anything else
      [/^(.)/, 'text-white'],
    ];

    while (remaining.length > 0) {
      let matched = false;

      for (const [pattern, colorClass] of patterns) {
        const match = remaining.match(pattern);
        if (match) {
          const text = match[1] || match[0];
          // Special handling for method calls - only color the method name
          if (pattern.source.includes('\\(') && text.startsWith('.')) {
            tokens.push(
              <span key={`${lineIndex}-${tokenIndex++}`} className={colorClass}>
                {text}
              </span>
            );
          } else if (pattern.source.includes('\\(') && !text.startsWith('.')) {
            tokens.push(
              <span key={`${lineIndex}-${tokenIndex++}`} className={colorClass}>
                {text}
              </span>
            );
          } else {
            tokens.push(
              <span key={`${lineIndex}-${tokenIndex++}`} className={colorClass || undefined}>
                {text}
              </span>
            );
          }
          remaining = remaining.slice(text.length);
          matched = true;
          break;
        }
      }

      if (!matched) {
        tokens.push(
          <span key={`${lineIndex}-${tokenIndex++}`}>
            {remaining[0]}
          </span>
        );
        remaining = remaining.slice(1);
      }
    }

    return (
      <div key={lineIndex} className="leading-relaxed">
        {tokens.length > 0 ? tokens : '\u00A0'}
      </div>
    );
  });
}

// Traffic light buttons
function TrafficLights() {
  return (
    <div className="flex gap-2">
      <div className="w-3 h-3 rounded-full bg-red-500 hover:bg-red-400 transition-colors" />
      <div className="w-3 h-3 rounded-full bg-yellow-500 hover:bg-yellow-400 transition-colors" />
      <div className="w-3 h-3 rounded-full bg-green-500 hover:bg-green-400 transition-colors" />
    </div>
  );
}

export default function MacOSCodeEditor() {
  const [activeFeature, setActiveFeature] = useState<FeatureKey>('blocks');
  const feature = features.find(f => f.key === activeFeature)!;
  const codeLines = feature.code.split('\n');

  return (
    <div className="bg-zinc-900 rounded-xl overflow-hidden shadow-2xl border border-zinc-700/50 min-h-[420px]">
      {/* Title bar */}
      <div className="flex items-center px-4 py-3 bg-zinc-800 border-b border-zinc-700/50">
        <TrafficLights />
        <span className="text-zinc-500 text-sm ml-4">{feature.filename}</span>
      </div>

      <div className="flex h-[380px]">
        {/* Sidebar */}
        <div className="w-40 bg-zinc-800/30 border-r border-zinc-700/50 flex-shrink-0 flex flex-col">
          {/* Explorer header */}
          <div className="px-4 py-2 text-xs text-zinc-500 font-medium uppercase tracking-wider">
            Explorer
          </div>

          {/* File tree */}
          <div className="flex-1">
            {features.map((f) => (
              <button
                key={f.key}
                onClick={() => setActiveFeature(f.key)}
                className={`w-full px-4 py-2 text-left text-sm flex items-center gap-3 transition-all ${
                  activeFeature === f.key
                    ? 'bg-zinc-700/50 text-white'
                    : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-700/30'
                }`}
              >
                <span className="text-base">{f.icon}</span>
                <span>{f.label}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Code area with line numbers */}
        <div className="flex-1 overflow-auto min-w-0">
          <div className="flex min-h-full">
            {/* Line numbers gutter */}
            <div className="bg-zinc-900/50 text-zinc-600 text-sm font-mono py-4 px-3 text-right select-none border-r border-zinc-800">
              {codeLines.map((_, i) => (
                <div key={i} className="leading-relaxed">{i + 1}</div>
              ))}
            </div>

            {/* Code */}
            <div className="flex-1 p-4 overflow-x-auto">
              <pre className="font-mono text-sm">
                <code>{highlightDart(feature.code)}</code>
              </pre>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
