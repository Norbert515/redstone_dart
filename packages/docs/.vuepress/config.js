import { viteBundler } from '@vuepress/bundler-vite'
import { defaultTheme } from '@vuepress/theme-default'
import { defineUserConfig } from 'vuepress'

export default defineUserConfig({
  lang: 'en-US',
  title: 'Redstone.Dart',
  description: 'The Flutter for Minecraft - Write Minecraft mods in Dart with hot reload support',

  bundler: viteBundler(),

  theme: defaultTheme({
    logo: '/logo.png',
    repo: 'user/redstone-dart',

    navbar: [
      { text: 'Guide', link: '/guide/' },
      { text: 'Examples', link: '/examples/' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          children: [
            '/guide/README.md',
            '/guide/getting-started.md',
            '/guide/cli.md',
          ],
        },
        {
          text: 'Creating Content',
          children: [
            '/guide/blocks.md',
            '/guide/items.md',
            '/guide/events.md',
          ],
        },
        {
          text: 'More',
          children: [
            '/guide/world.md',
            '/guide/players.md',
            '/guide/hot-reload.md',
          ],
        },
      ],
      '/examples/': [
        '/examples/README.md',
      ],
    },
  }),
})
