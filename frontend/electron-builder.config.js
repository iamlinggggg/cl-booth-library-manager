/**
 * @type {import('electron-builder').Configuration}
 */
module.exports = {
  appId: 'pm.booth.order-manager',
  productName: 'BOOTH Library Manager',
  copyright: 'Copyright © 2024 dodocha169',

  directories: {
    output: 'release',
  },

  // CLバックエンドバイナリを同梱
  extraResources: [
    {
      from: '../dist-cl/',
      to: 'cl-backend/',
      filter: ['**/*'],
    },
  ],

  // パッケージに含めるファイル
  files: [
    'dist/**/*',
    'node_modules/**/*',
    'package.json',
  ],

  win: {
    target: [
      {
        target: 'nsis',
        arch: ['x64'],
      },
    ],
    icon: 'assets/icon.ico',
  },

  nsis: {
    oneClick: false,
    allowToChangeInstallationDirectory: true,
    createDesktopShortcut: true,
    createStartMenuShortcut: true,
    shortcutName: 'BOOTH Library Manager',
  },

  mac: {
    target: 'dmg',
    icon: 'assets/icon.icns',
  },

  linux: {
    target: 'AppImage',
    icon: 'assets/icon.png',
  },

  // GitHub Releases への自動公開設定
  publish: {
    provider: 'github',
    releaseType: 'release',
  },
};
