import { source } from '@/lib/source';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import type { ReactNode } from 'react';

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <DocsLayout
      tree={source.pageTree}
      nav={{
        title: (
          <span className="font-bold text-lg">
            <span className="text-red-500">Redstone</span>.Dart
          </span>
        ),
      }}
      links={[
        { text: 'GitHub', url: 'https://github.com/Norbert515/redstone_dart' },
      ]}
    >
      {children}
    </DocsLayout>
  );
}
