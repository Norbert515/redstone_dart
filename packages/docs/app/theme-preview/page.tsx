'use client';

import { useState } from 'react';
import Link from 'next/link';

const themes = [
  {
    id: 'redstone-circuit',
    name: 'Redstone Circuit',
    description: 'Red primary with Dart blue accent. Bold and striking.',
    colors: {
      primary: '#DC4646',
      accent: '#13B9FD',
      bg: '#0C0C0C',
      card: '#1A1A1A',
    },
  },
  {
    id: 'dart-redstone',
    name: 'Dart Blue + Redstone',
    description: 'Professional developer feel. Dart blue primary, red accent.',
    colors: {
      primary: '#13B9FD',
      accent: '#DC4646',
      bg: '#0D1117',
      card: '#161B22',
    },
  },
  {
    id: 'minecraft-earth',
    name: 'Minecraft Earth',
    description: 'Warm and organic. Grass green with wood brown.',
    colors: {
      primary: '#70B237',
      accent: '#C28340',
      bg: '#1A1612',
      card: '#2A2219',
    },
  },
  {
    id: 'nether-portal',
    name: 'Nether Portal',
    description: 'Bold and magical. Purple primary with teal accent.',
    colors: {
      primary: '#A050D2',
      accent: '#00DCC8',
      bg: '#0F0A14',
      card: '#1A1222',
    },
  },
];

export default function ThemePreview() {
  const [activeTheme, setActiveTheme] = useState('redstone-circuit');

  return (
    <div className="min-h-screen bg-zinc-950 text-white p-8">
      <div className="max-w-6xl mx-auto">
        <Link href="/" className="text-zinc-400 hover:text-white mb-8 inline-block">
          ← Back to Home
        </Link>

        <h1 className="text-4xl font-bold mb-2">Theme Preview</h1>
        <p className="text-zinc-400 mb-8">
          Compare different color schemes for Redstone.Dart documentation.
        </p>

        <div className="grid md:grid-cols-2 gap-6 mb-12">
          {themes.map((theme) => (
            <button
              key={theme.id}
              onClick={() => setActiveTheme(theme.id)}
              className={`text-left p-6 rounded-xl border-2 transition-all ${
                activeTheme === theme.id
                  ? 'border-white bg-zinc-900'
                  : 'border-zinc-800 bg-zinc-900/50 hover:border-zinc-700'
              }`}
            >
              <div className="flex items-center gap-3 mb-3">
                <div
                  className="w-6 h-6 rounded-full"
                  style={{ backgroundColor: theme.colors.primary }}
                />
                <div
                  className="w-6 h-6 rounded-full"
                  style={{ backgroundColor: theme.colors.accent }}
                />
                <div
                  className="w-6 h-6 rounded border border-zinc-700"
                  style={{ backgroundColor: theme.colors.bg }}
                />
              </div>
              <h3 className="text-xl font-semibold mb-1">{theme.name}</h3>
              <p className="text-zinc-400 text-sm">{theme.description}</p>
            </button>
          ))}
        </div>

        {/* Preview Section */}
        <h2 className="text-2xl font-bold mb-4">Preview: {themes.find(t => t.id === activeTheme)?.name}</h2>

        {themes.map((theme) => (
          <div
            key={theme.id}
            className={`rounded-xl overflow-hidden border border-zinc-800 ${
              activeTheme === theme.id ? 'block' : 'hidden'
            }`}
          >
            {/* Mock Header */}
            <div
              className="p-4 border-b flex items-center gap-4"
              style={{ backgroundColor: theme.colors.card, borderColor: theme.colors.bg }}
            >
              <span className="font-bold text-lg">
                <span style={{ color: theme.colors.primary }}>Redstone</span>.Dart
              </span>
              <div className="flex-1" />
              <span className="text-zinc-400 text-sm">Docs</span>
              <span className="text-zinc-400 text-sm">GitHub</span>
            </div>

            {/* Mock Content */}
            <div className="flex" style={{ backgroundColor: theme.colors.bg }}>
              {/* Sidebar */}
              <div
                className="w-64 p-4 border-r"
                style={{ backgroundColor: theme.colors.card, borderColor: theme.colors.bg }}
              >
                <div className="space-y-2">
                  <div
                    className="px-3 py-2 rounded text-sm"
                    style={{ backgroundColor: `${theme.colors.primary}22`, color: theme.colors.primary }}
                  >
                    Introduction
                  </div>
                  <div className="px-3 py-2 rounded text-sm text-zinc-400">Getting Started</div>
                  <div className="px-3 py-2 rounded text-sm text-zinc-500 mt-4 uppercase text-xs">
                    Core Concepts
                  </div>
                  <div className="px-3 py-2 rounded text-sm text-zinc-400">Blocks</div>
                  <div className="px-3 py-2 rounded text-sm text-zinc-400">Items</div>
                  <div className="px-3 py-2 rounded text-sm text-zinc-400">Entities</div>
                </div>
              </div>

              {/* Main Content */}
              <div className="flex-1 p-8">
                <h1 className="text-3xl font-bold mb-2">Introduction</h1>
                <p className="text-zinc-400 mb-6">
                  Write Minecraft mods in Dart with hot reload support.
                </p>

                <div
                  className="rounded-lg p-4 mb-6"
                  style={{ backgroundColor: theme.colors.card }}
                >
                  <pre className="text-sm">
                    <span style={{ color: theme.colors.primary }}>class</span>{' '}
                    <span style={{ color: theme.colors.accent }}>HelloBlock</span>{' '}
                    <span style={{ color: theme.colors.primary }}>extends</span> CustomBlock {'{'}
                    {'\n'}  ...
                    {'\n'}{'}'}
                  </pre>
                </div>

                <div className="flex gap-3">
                  <button
                    className="px-4 py-2 rounded-lg font-medium text-sm"
                    style={{ backgroundColor: theme.colors.primary, color: 'white' }}
                  >
                    Get Started
                  </button>
                  <button
                    className="px-4 py-2 rounded-lg font-medium text-sm border"
                    style={{ borderColor: theme.colors.accent, color: theme.colors.accent }}
                  >
                    View on GitHub
                  </button>
                </div>
              </div>
            </div>
          </div>
        ))}

        {/* Color Values */}
        <div className="mt-8 p-6 bg-zinc-900 rounded-xl">
          <h3 className="text-lg font-semibold mb-4">
            Color Values for "{themes.find(t => t.id === activeTheme)?.name}"
          </h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {Object.entries(themes.find(t => t.id === activeTheme)?.colors || {}).map(([name, value]) => (
              <div key={name} className="flex items-center gap-3">
                <div
                  className="w-10 h-10 rounded border border-zinc-700"
                  style={{ backgroundColor: value }}
                />
                <div>
                  <div className="text-sm font-medium capitalize">{name}</div>
                  <div className="text-xs text-zinc-500 font-mono">{value}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <p className="text-zinc-500 text-sm mt-8">
          To apply a theme, update <code className="bg-zinc-800 px-1 rounded">app/global.css</code> to import the desired theme file.
        </p>
      </div>
    </div>
  );
}
