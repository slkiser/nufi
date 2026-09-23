<p align="center">
  <a href="https://github.com/slkiser/nufi">
    <picture>
      <source srcset="readme/nufi-logo-dark.svg" media="(prefers-color-scheme: dark)">
      <source srcset="readme/nufi-logo-light.svg" media="(prefers-color-scheme: light)">
      <img src="readme/nufi-logo-light.svg" alt="Nufi">
    </picture>
  </a>
</p>
<p align="center">Paste copied text as a new file in the Finder folder you already have open.</p>
<p align="center">
  <img alt="Version 0.1.0-alpha.1" src="https://img.shields.io/badge/version-0.1.0--alpha.1-blue?style=flat-square" />
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-black?style=flat-square" />
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" /></a>
</p>

## Quick start

`0.1.0-alpha.1` is a local Apple Development build. There is no GitHub installer or Homebrew cask yet.

1. Build and install:

   ```sh
   brew install xcodegen
   ./scripts/build-local.sh
   cp -R build/Nufi.app /Applications/
   open /Applications/Nufi.app
   ```

2. In Nufi, choose **Open Login Items & Extensions** and turn on **Nufi Extension**.
3. Copy some text. In Finder, right-click the background of an open folder (not an icon). Choose **Paste as New File**, then **.txt** or **.md**. Type the basename and press Return once.

Blank files still work from **New File**. Default types include `.txt` and `.md`. Settings can enable more.

On the Desktop wallpaper, use the **Nufi menu bar icon** instead. It creates in the frontmost Finder window, or on the Desktop when none is open.

## Features

- **Paste as New File.** Writes the clipboard's plain text as UTF-8. Unicode and line breaks stay intact. Empty or non-text clipboards disable the paste items. Nufi does not change the clipboard, intercept ⌘V, or upload anything.
- **Blank files.** Same collision-safe names as [NewFile](https://github.com/mariusgm/newfile): `New Text File.txt`, then `New Text File 2.txt`, and so on. Optional starter templates live in Preferences.
- **Inline rename.** After either create path, Finder selects the new file and starts renaming so the extension stays put. Cancel keeps the collision-safe default name.
- **Open folder first.** Files land in the folder whose background you clicked. An optional setting also adds the actions when you right-click a folder in its parent window.
- **Menu bar item.** The same New File and Paste actions from the menu bar, aimed at the folder Finder is showing. Finder does not offer extension menus on the Desktop wallpaper, so this is the Desktop path. Optional **Open at login**.

## Configure

Nufi → **Settings**, the menu bar icon's **Settings…**, or the toolbar menu's **Customize…** row.

- **General.** Show or hide the menu bar item, open at login, group blank types under **New File** or show them top-level, selected-folder creation, and the Accessibility and Automation permissions inline rename needs.
- **File Types.** Enable, label, reorder, and template the blank-file types. **Paste as New File** stays a submenu.

Nufi stores those settings in its own App Group. It does not share preferences with NewFile.

## Troubleshooting

**Nufi Extension does not appear.** Update past macOS Sequoia 15.1 if you can. Then quit Nufi, reopen it, and use the in-app **Open Login Items & Extensions** button.

**Nothing appears when right-clicking the Desktop wallpaper.** Expected. Finder Sync extensions only get the menu inside Finder windows. Use the menu bar icon, or open the Desktop as a Finder window.

**Paste as New File is disabled.** The clipboard has no plain text. Copy text and right-click again. Nufi will not create an empty file from a paste action.

**The file appears but is not in rename mode.** Approve Automation for Finder and System Events, plus Accessibility, when macOS asks. Select the file and press Enter (fn-Return on a laptop) to rename once.

**macOS says Nufi is in use when you Trash it.** Use **Nufi → Uninstall Nufi…** so the Finder extension stops first, then drag the app to the Trash.

**Uninstall leftovers.** Delete `~/Library/Group Containers/28W383DD2Q.dev.slkiser.nufi` if you also want saved file types gone.

## Contributors

- [Shawn Kiser](https://github.com/slkiser) maintains Nufi.
- Nufi starts from [NewFile](https://github.com/mariusgm/newfile) by [mariusgm](https://github.com/mariusgm) / Wheel Up Labs, snapshot `b3f665ab839dfe95e6925735ca2a8209d3100fb8`. NewFile's MIT copyright notice is kept in [LICENSE](LICENSE).

## License

[MIT](LICENSE). Free to use, modify, and redistribute. No accounts, no paid features, no telemetry, no clipboard uploads.
