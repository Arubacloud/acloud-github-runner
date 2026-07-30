// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  mainSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Introduction',
    },
    {
      type: 'doc',
      id: 'getting-started',
      label: 'Getting Started',
    },
    {
      type: 'category',
      label: 'Usage',
      items: [
        'usage-auto',
        'usage-existing',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'reference',
        'flavors',
      ],
    },
    {
      type: 'category',
      label: 'Project',
      items: [
        'contributing',
        'changelog',
      ],
    },
  ],
};

module.exports = sidebars;
