// @ts-check

const lightCodeTheme = require('prism-react-renderer').themes.github;
const darkCodeTheme = require('prism-react-renderer').themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'ArubaCloud GitHub Runner',
  tagline: 'On-demand self-hosted GitHub Actions runners on Aruba Cloud',
  favicon: 'img/favicon.ico',

  url: 'https://arubacloud.github.io',
  baseUrl: '/acloud-github-runner/',

  organizationName: 'Arubacloud',
  projectName: 'acloud-github-runner',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'it'],
    localeConfigs: {
      en: {
        label: 'English',
        direction: 'ltr',
        htmlLang: 'en-US',
        calendar: 'gregory',
      },
      it: {
        label: 'Italiano',
        direction: 'ltr',
        htmlLang: 'it-IT',
        calendar: 'gregory',
      },
    },
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/Arubacloud/acloud-github-runner/tree/main/docs/',
          routeBasePath: '/',
          path: 'docs',
          versions: process.env.DISABLE_VERSIONING === 'true' ? {} : {
            current: {
              label: 'Next',
            },
          },
          showLastUpdateTime: true,
          showLastUpdateAuthor: true,
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  plugins: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        language: ['en', 'it'],
        highlightSearchTermsOnTargetPage: true,
        explicitSearchResultPath: true,
        indexBlog: false,
        indexPages: false,
        docsRouteBasePath: '/',
        removeDefaultStopWordFilter: false,
        removeDefaultStemmer: false,
      },
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/logo-cloud.png',
      navbar: {
        title: 'GitHub Runner',
        logo: {
          alt: 'Aruba Cloud GitHub Runner',
          src: 'img/logo-cloud.png',
          srcDark: 'img/logo-cloud.png',
          width: 32,
          height: 32,
          href: '/intro',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'mainSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            type: 'localeDropdown',
            position: 'right',
          },
          ...(process.env.DISABLE_VERSIONING !== 'true' ? [{
            type: 'docsVersionDropdown',
            position: 'right',
          }] : []),
          {
            href: 'https://github.com/Arubacloud/acloud-github-runner',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              {
                label: 'Getting Started',
                to: '/getting-started',
              },
              {
                label: 'Inputs & Outputs',
                to: '/reference',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/Arubacloud/acloud-github-runner',
              },
              {
                label: 'Issues',
                href: 'https://github.com/Arubacloud/acloud-github-runner/issues',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'Aruba Cloud',
                href: 'https://www.arubacloud.com',
              },
              {
                label: 'acloud-cli docs',
                href: 'https://arubacloud.github.io/acloud-cli/intro',
              },
              {
                label: 'Changelog',
                to: '/changelog',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Aruba S.p.A. - via San Clemente, 53 - 24036 Ponte San Pietro (BG) P.IVA 01573850516 - C.F. 04552920482 - C.S. € 4.000.000,00 i.v. - Numero REA: BG – 434483 - All rights reserved`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['bash', 'yaml', 'powershell'],
      },
    }),
};

module.exports = config;
