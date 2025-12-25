import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-zinc-900 to-black text-white">
      {/* Hero Section */}
      <section className="container mx-auto px-6 py-24 text-center relative">
        {/* Subtle pixel grid */}
        <div className="absolute inset-0 pixel-grid opacity-20" />

        <div className="relative z-10">
          <h1 className="text-6xl font-bold mb-6">
            <span className="text-red-500">Redstone</span>
            <span className="text-zinc-500">.</span>
            <span className="text-cyan-400">Dart</span>
          </h1>

          <p className="text-xl text-zinc-400 mb-8 max-w-2xl mx-auto">
            Write Minecraft mods in Dart with hot reload.
            Change code, see results instantly.
          </p>

          <div className="flex gap-4 justify-center">
            <Link
              href="/docs"
              className="bg-red-600 hover:bg-red-500 px-8 py-3 rounded-lg font-semibold text-lg transition-colors"
            >
              Get Started
            </Link>
            <a
              href="https://github.com/user/redstone-dart"
              className="border border-zinc-600 hover:border-zinc-400 px-8 py-3 rounded-lg font-semibold text-lg transition-colors"
            >
              GitHub
            </a>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container mx-auto px-6 py-16">
        <div className="grid md:grid-cols-3 gap-8">
          <FeatureCard
            icon="⚡"
            title="Hot Reload"
            description="Change your code and see results in under a second. No more waiting for Minecraft to restart."
          />
          <FeatureCard
            icon="🎯"
            title="Dart Language"
            description="Write mods in modern Dart instead of Java. Enjoy null safety, async/await, and a great type system."
          />
          <FeatureCard
            icon="🛠️"
            title="Full Featured"
            description="Custom blocks, items, entities, commands, recipes, loot tables, and GUI screens."
          />
        </div>
      </section>

      {/* Code Example */}
      <section className="container mx-auto px-6 py-16">
        <h2 className="text-3xl font-bold text-center mb-8">
          Simple & Expressive
        </h2>
        <div className="max-w-3xl mx-auto bg-zinc-800/50 border border-zinc-700 rounded-lg p-6 font-mono text-sm overflow-x-auto">
          <pre className="text-zinc-300">{`class HelloBlock extends CustomBlock {
  HelloBlock() : super(
    id: 'mymod:hello_block',
    settings: BlockSettings(hardness: 2.0),
  );

  @override
  ActionResult onUse(int worldId, int x, int y, int z,
                     int playerId, int hand) {
    Players.getPlayer(playerId)?.sendMessage('§aHello!');
    return ActionResult.success;
  }
}`}</pre>
        </div>
      </section>

      {/* Quick Start */}
      <section className="container mx-auto px-6 py-16">
        <h2 className="text-3xl font-bold text-center mb-8">
          Get Started in <span className="text-red-500">30 Seconds</span>
        </h2>
        <div className="max-w-2xl mx-auto space-y-4">
          <CodeStep step={1} code="dart pub global activate redstone_cli" />
          <CodeStep step={2} code="redstone create my_mod" />
          <CodeStep step={3} code="cd my_mod && redstone run" />
        </div>
        <p className="text-center text-zinc-400 mt-8">
          That's it! Minecraft launches with your mod. Press <kbd className="bg-zinc-700 px-2 py-1 rounded font-mono">r</kbd> to hot reload.
        </p>
      </section>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-8 mt-16">
        <div className="container mx-auto px-6 text-center text-zinc-500">
          Built with <span className="text-cyan-400">Dart</span> + <span className="text-red-500">Redstone</span>
        </div>
      </footer>
    </main>
  );
}

function FeatureCard({ icon, title, description }: {
  icon: string;
  title: string;
  description: string;
}) {
  return (
    <div className="bg-zinc-800/50 border border-zinc-700 rounded-lg p-6 hover:border-zinc-600 transition-colors">
      <div className="text-4xl mb-4">{icon}</div>
      <h3 className="text-xl font-semibold mb-2">{title}</h3>
      <p className="text-zinc-400">{description}</p>
    </div>
  );
}

function CodeStep({ step, code }: { step: number; code: string }) {
  return (
    <div className="flex items-center gap-4 bg-zinc-800/50 border border-zinc-700 rounded-lg p-4">
      <span className="bg-red-600 w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm">
        {step}
      </span>
      <code className="text-zinc-300 font-mono text-sm flex-1">{code}</code>
    </div>
  );
}
