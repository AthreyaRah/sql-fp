import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'SQL from First Principles',
  tagline:
    'Every SQL concept from zero: the mechanism, a hand-trace on real rows, a runnable script, and a break you fix.',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://athreyarah.github.io',
  baseUrl: '/sql-fp/',

  organizationName: 'AthreyaRah',
  projectName: 'sql-fp',
  trailingSlash: false,

  onBrokenLinks: 'throw',

  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },
  themes: [
    '@docusaurus/theme-mermaid',
    [
      // Offline, free, no Algolia account required.
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        indexBlog: false,
        docsRouteBasePath: '/',
        highlightSearchTermsOnTargetPage: true,
      },
    ],
  ],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/AthreyaRah/sql-fp/tree/main/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    docs: {
      sidebar: {
        hideable: true,
      },
    },
    navbar: {
      title: 'SQL from First Principles',
      logo: {
        alt: 'SQL from First Principles',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'foundationsSidebar',
          position: 'left',
          label: 'Foundations',
        },
        {type: 'docSidebar', sidebarId: 'backendSidebar', position: 'left', label: 'Backend'},
        {
          type: 'docSidebar',
          sidebarId: 'dataEngineeringSidebar',
          position: 'left',
          label: 'Data Engineering',
        },
        {type: 'docSidebar', sidebarId: 'appendixSidebar', position: 'left', label: 'Appendix'},
        {
          href: 'https://github.com/AthreyaRah/sql-fp',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Learn',
          items: [
            {label: 'How to use this site', to: '/how-to-use'},
            {label: 'Foundations', to: '/foundations/'},
            {label: 'Run locally (optional)', to: '/appendix/run-locally'},
          ],
        },
        {
          title: 'Sections',
          items: [
            {label: 'Backend Engineering', to: '/backend/'},
            {label: 'Data Engineering', to: '/data-engineering/'},
            {label: 'Appendix', to: '/appendix/glossary'},
          ],
        },
        {
          title: 'More',
          items: [
            {label: 'GitHub', href: 'https://github.com/AthreyaRah/sql-fp'},
            {label: 'Python from First Principles', href: 'https://github.com/AthreyaRah/python-fp'},
          ],
        },
      ],
      copyright: `MIT licensed. Educational reference. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['sql', 'bash', 'json', 'ini'],
    },
    mermaid: {
      theme: {light: 'neutral', dark: 'dark'},
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
