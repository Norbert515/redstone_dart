import MacOSCodeEditor from './components/MacOSCodeEditor';

export default function App() {
  return (
    <main className="min-h-screen text-white relative overflow-hidden">
      {/* Animated Background */}
      <div className="fixed inset-0 -z-10">
        <div
          className="absolute animate-slow-pan"
          style={{
            top: '-10%',
            left: '-10%',
            width: '120%',
            height: '120%',
          }}
        >
          <img
            src="/screenshots/bg.png"
            alt=""
            className="w-full h-full object-cover blur-sm scale-110"
            style={{ objectPosition: 'center 30%' }}
          />
        </div>
        <div className="absolute inset-0 bg-black/70" />
      </div>

      {/* Hero Section */}
      <section className="min-h-screen flex flex-col items-center justify-center px-6 relative">
        <div className="max-w-7xl mx-auto w-full">
          <div className="grid lg:grid-cols-[1fr_1.4fr] gap-12 items-center">
            <div>
              <img
                src="/screenshots/redstone_logo.png"
                alt="Redstone.Dart"
                className="w-auto max-h-48 md:max-h-56 lg:max-h-64 mb-8 object-contain"
              />

              <p className="text-lg md:text-xl text-zinc-300 mb-8 max-w-md">
                Create blocks, items, entities, and more. Hot reload your changes instantly.
              </p>

              <div className="flex flex-col sm:flex-row gap-3">
                <a
                  href="https://docs.redstone-dart.dev/docs"
                  className="bg-zinc-700 hover:bg-zinc-600 px-6 py-3 rounded-lg font-medium transition-colors flex items-center gap-2"
                >
                  Get Started
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                  </svg>
                </a>
                <a
                  href="https://github.com/Norbert515/redstone_dart"
                  className="bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 px-6 py-3 rounded-lg font-medium transition-colors flex items-center gap-2"
                >
                  <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                    <path fillRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clipRule="evenodd" />
                  </svg>
                  GitHub
                </a>
              </div>
            </div>

            <div className="bg-zinc-900 border border-zinc-700 rounded-xl overflow-hidden shadow-2xl">
              <div className="flex items-center gap-2 px-4 py-3 border-b border-zinc-700 bg-zinc-800">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-red-500" />
                  <div className="w-3 h-3 rounded-full bg-yellow-500" />
                  <div className="w-3 h-3 rounded-full bg-green-500" />
                </div>
                <span className="text-zinc-400 text-sm ml-2 font-mono">my_block.dart</span>
              </div>
              <pre className="p-6 overflow-x-auto text-base leading-relaxed text-[#ebdbb2]">
                <code>
                  <span style={{color: '#fe8019'}}>class</span> <span style={{color: '#fabd2f'}}>MyBlock</span> <span style={{color: '#fe8019'}}>extends</span> <span style={{color: '#fabd2f'}}>CustomBlock</span> {'{\n'}
                  {'  '}<span style={{color: '#fabd2f'}}>MyBlock</span>() : <span style={{color: '#fe8019'}}>super</span>({'\n'}
                  {'    '}id: <span style={{color: '#b8bb26'}}>'mymod:my_block'</span>,{'\n'}
                  {'    '}settings: <span style={{color: '#fabd2f'}}>BlockSettings</span>({'\n'}
                  {'      '}hardness: <span style={{color: '#d3869b'}}>2.0</span>,{'\n'}
                  {'      '}luminance: <span style={{color: '#d3869b'}}>15</span>,{'\n'}
                  {'    '}),{'\n'}
                  {'  '});{'\n'}
                  {'}'}
                </code>
              </pre>
            </div>
          </div>
        </div>

        <div className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce">
          <svg className="w-6 h-6 text-zinc-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-24 px-6 bg-zinc-900/80">
        <div className="container mx-auto max-w-6xl">
          <h2 className="text-3xl font-bold mb-12 text-center">Features</h2>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <FeatureCard
              icon="⚡"
              title="Hot Reload"
              description="See changes instantly without restarting Minecraft. Edit Dart code, press r, done."
            />
            <FeatureCard
              icon="🧱"
              title="Blocks & Items"
              description="Create custom blocks, items, tools, and armor in pure Dart with a clean, declarative API."
            />
            <FeatureCard
              icon="👾"
              title="Custom Entities"
              description="Define monsters, animals, and projectiles with AI goals, custom behaviors, and models."
            />
            <FeatureCard
              icon="🧪"
              title="E2E Testing"
              description="Write tests in Dart that run inside a real headless Minecraft server."
            />
            <FeatureCard
              icon="🎮"
              title="GUI Screens"
              description="Build custom interfaces with Dart—widgets, buttons, and interactive elements."
            />
            <FeatureCard
              icon="📦"
              title="CLI Tooling"
              description="One command to create, build, run, and test your mods."
            />
          </div>
        </div>
      </section>

      {/* Code Example */}
      <section className="py-24 px-6 bg-zinc-900">
        <div className="container mx-auto max-w-6xl">
          <div className="grid lg:grid-cols-[1fr_1.8fr] gap-12 items-center">
            <div>
              <h2 className="text-3xl font-bold mb-4">
                Hot reload, for real
              </h2>
              <p className="text-zinc-400 mb-6">
                Change your code, press <kbd className="bg-zinc-800 px-2 py-0.5 rounded text-sm font-mono border border-zinc-700">r</kbd>, see it in Minecraft. No restart needed.
              </p>
              <ul className="space-y-3 text-zinc-400">
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  ~200ms reload time
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  World state preserved
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  Works with blocks, items, commands
                </li>
              </ul>
            </div>

            <div className="pt-8">
              <MacOSCodeEditor />
            </div>
          </div>
        </div>
      </section>

      {/* Testing Section */}
      <section className="py-24 px-6 bg-zinc-900">
        <div className="container mx-auto max-w-6xl">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div className="bg-zinc-900 border border-zinc-700 rounded-xl overflow-hidden shadow-2xl order-2 lg:order-1">
              <div className="flex items-center gap-2 px-4 py-3 border-b border-zinc-700 bg-zinc-800">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-red-500" />
                  <div className="w-3 h-3 rounded-full bg-yellow-500" />
                  <div className="w-3 h-3 rounded-full bg-green-500" />
                </div>
                <span className="text-zinc-400 text-sm ml-2 font-mono">block_test.dart</span>
              </div>
              <pre className="p-6 overflow-x-auto text-sm leading-relaxed text-[#ebdbb2]">
                <code>
                  <span style={{color: '#fe8019'}}>await</span> <span style={{color: '#8ec07c'}}>testMinecraft</span>(<span style={{color: '#b8bb26'}}>'can place blocks'</span>, (game) <span style={{color: '#fe8019'}}>async</span> {'{\n'}
                  {'  '}<span style={{color: '#fe8019'}}>final</span> pos = <span style={{color: '#fabd2f'}}>BlockPos</span>(<span style={{color: '#d3869b'}}>100</span>, <span style={{color: '#d3869b'}}>64</span>, <span style={{color: '#d3869b'}}>100</span>);{'\n\n'}
                  {'  '}game.<span style={{color: '#8ec07c'}}>placeBlock</span>(pos, <span style={{color: '#fabd2f'}}>Block</span>.stone);{'\n'}
                  {'  '}<span style={{color: '#fe8019'}}>await</span> game.<span style={{color: '#8ec07c'}}>waitTicks</span>(<span style={{color: '#d3869b'}}>1</span>);{'\n\n'}
                  {'  '}<span style={{color: '#8ec07c'}}>expect</span>({'\n'}
                  {'    '}game.<span style={{color: '#8ec07c'}}>getBlock</span>(pos),{'\n'}
                  {'    '}<span style={{color: '#8ec07c'}}>isBlock</span>(<span style={{color: '#fabd2f'}}>Block</span>.stone),{'\n'}
                  {'  '});{'\n'}
                  {'}'});
                </code>
              </pre>
            </div>
            <div className="order-1 lg:order-2">
              <h2 className="text-3xl font-bold mb-4">
                Test Your Mods in Real Minecraft
              </h2>
              <p className="text-zinc-400 mb-6">
                Write E2E tests that run inside a real headless Minecraft server. No mocking, no simulation—actual game behavior.
              </p>
              <ul className="space-y-3 text-zinc-400">
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  Headless server, no GUI needed
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  Tick-based timing for precise control
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  Full world access—blocks, entities, players
                </li>
                <li className="flex items-center gap-2">
                  <span className="text-green-400">✓</span>
                  CI/CD ready out of the box
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* What's Included */}
      <section className="py-24 px-6 bg-zinc-900">
        <div className="container mx-auto max-w-4xl">
          <h2 className="text-3xl font-bold mb-12 text-center">What's Included</h2>
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <IncludedItem text="Custom Blocks" />
            <IncludedItem text="Custom Items" />
            <IncludedItem text="Custom Entities" />
            <IncludedItem text="Entity AI Goals" />
            <IncludedItem text="Commands" />
            <IncludedItem text="Recipes" />
            <IncludedItem text="Loot Tables" />
            <IncludedItem text="GUI Screens" />
            <IncludedItem text="World API" />
            <IncludedItem text="E2E Testing" />
            <IncludedItem text="Hot Reload" />
            <IncludedItem text="CLI Tools" />
          </div>
        </div>
      </section>

      {/* Quick Start */}
      <section className="py-24 px-6 bg-zinc-900/80">
        <div className="container mx-auto max-w-2xl text-center">
          <h2 className="text-3xl font-bold mb-4">Get Started</h2>
          <p className="text-zinc-400 mb-8">
            The CLI handles everything—just install and run.
          </p>
          <div className="space-y-3 text-left">
            <CommandStep step={1} command="dart pub global activate redstone_cli" />
            <CommandStep step={2} command="redstone create my_mod" />
            <CommandStep step={3} command="cd my_mod && redstone run" />
          </div>
          <p className="text-zinc-500 mt-6 text-sm">
            Minecraft launches with your mod. Press <kbd className="bg-zinc-800 px-1.5 py-0.5 rounded text-xs font-mono">r</kbd> to hot reload.
          </p>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 px-6 bg-zinc-950 border-t border-zinc-800">
        <div className="container mx-auto max-w-5xl">
          <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-zinc-500">
            <img src="/screenshots/redstone_logo.png" alt="Redstone.Dart" className="h-6" />
            <div className="flex items-center gap-6">
              <a href="https://docs.redstone-dart.dev/docs" className="hover:text-white transition-colors">Docs</a>
              <a href="https://github.com/Norbert515/redstone_dart" className="hover:text-white transition-colors">GitHub</a>
            </div>
            <span>MIT License</span>
          </div>
        </div>
      </footer>
    </main>
  );
}

function CommandStep({ step, command }: { step: number; command: string }) {
  return (
    <div className="flex items-center gap-3 bg-zinc-800 border border-zinc-700 rounded-lg p-3">
      <span className="bg-zinc-700 w-7 h-7 rounded flex items-center justify-center text-sm font-mono text-zinc-400">
        {step}
      </span>
      <code className="text-zinc-300 font-mono text-sm">{command}</code>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: string; title: string; description: string }) {
  return (
    <div className="bg-zinc-800 border border-zinc-700 rounded-xl p-6 hover:border-zinc-600 transition-colors">
      <div className="text-3xl mb-3">{icon}</div>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-zinc-400 text-sm">{description}</p>
    </div>
  );
}

function IncludedItem({ text }: { text: string }) {
  return (
    <div className="flex items-center gap-2 bg-zinc-800 border border-zinc-700 rounded-lg px-4 py-3">
      <span className="text-green-400">✓</span>
      <span className="text-zinc-300 text-sm">{text}</span>
    </div>
  );
}
