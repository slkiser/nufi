<p align="center">
  <a href="https://github.com/slkiser/nufi">
    <picture>
      <source srcset="readme/nufi-logo-dark.svg" media="(prefers-color-scheme: dark)">
      <source srcset="readme/nufi-logo-light.svg" media="(prefers-color-scheme: light)">
      <img src="readme/nufi-logo-light.svg" alt="Nufi">
    </picture>
  </a>
</p>
<p align="center">Paste copied text as a new file in Finder.</p>
<p align="center">
  <img alt="Version 0.1.0-alpha.1" src="https://img.shields.io/badge/version-0.1.0--alpha.1-blue?style=flat-square" />
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-black?style=flat-square" />
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" /></a>
</p>

## Install

Nufi is in alpha, so for now you build it yourself:

```sh
brew install xcodegen
./scripts/build-local.sh
cp -R build/Nufi.app /Applications/
open /Applications/Nufi.app
```

Then follow the setup checklist to turn on the Finder extension.

## Use

Right-click empty space in any Finder window:

- **Paste as New File** saves your copied text as a `.txt` or `.md` file.
- **New File** makes a blank one.

Type a name and press Return. On the Desktop, use the menu bar icon instead.

Add more file types and templates in Settings.

## Troubleshooting

- **No Nufi items in Finder.** Quit and reopen Nufi, then turn the extension on again from the setup checklist.
- **Paste as New File is greyed out.** Your clipboard has no text.
- **The new file isn't ready to rename.** Allow Accessibility and Automation for Nufi in System Settings.
- **Can't move Nufi to the Trash.** Use Settings → About → **Uninstall…** first.

## Credits

Built by [Shawn Kiser](https://github.com/slkiser), starting from [NewFile](https://github.com/mariusgm/newfile) by mariusgm. [MIT](LICENSE) licensed. No accounts, no telemetry, nothing uploaded.
