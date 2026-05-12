# vTree Gold

A file manager for ~all~ most Linux retro handheld devices, controlled entirely by gamepad.
Built in C with SDL2.

---

## Features

- **Single or Dual-pane explorer** - Select between the classic two-pane view and a single-pane option ideal for smaller devices
- **Robust suite of file operations** - Copy, Cut, Paste, Rename, Delete, Create new file/folder
- **Symlink creation** - paste clipboard items as symlinks, fully filesystem-aware (only available when the destination supports symlinks)
- **Multi-select** - mark multiple files/folders in one or both panes
- **Viewers**
  - Text viewer / editor
  - Hex viewer / editor
  - Image viewer (pan, zoom, fit-to-screen)
- **File / Dir information** - permissions, size (recursive for directories), owner/group, timestamps, symlink targets; multi-selection shows combined totals
- **Symlink awareness** - symlinks shown in a distinct colour; metadata follows the target
- **Themes** - many built-in presets (Dark, MustardOS, Spruce, Dracula, and more...); fully customisable, supports new themes!
- **Font selection** - drop `.ttf`/`.otf` files into a `fonts/` folder; select in Settings
- **Configurable key bindings** — explorer keys and on-screen keyboard keys are independently rebindable
- **Show hidden files** - toggle dotfile visibility in Settings
- **Remember directories** - optionally save and restore pane paths across sessions
- **Display rotation** - software rotation at 0°, 90°, 180°, or 270° for devices with rotated screens; configurable via `--rotate=` flag or Settings → General
- **Auto-detects screen resolution** - on first launch; falls back to 640×480
- **Mulit-language** - Fully supports multiple languages. Drop new ones into `./lang/Name.ini`
- **Script execution** — execute `.sh` scripts directly from the file manager; the launched app takes over the display cleanly (experimental, enable in Settings)

---

## Dependencies

| Library | Package (Debian/Ubuntu) |
|---------|------------------------|
| SDL2 | `libsdl2-dev` |
| SDL2_ttf | `libsdl2-ttf-dev` |
| SDL2_image | `libsdl2-image-dev` |

---

## Building

```sh
# Debug build (with AddressSanitizer + UBSan)
make

# Optimised release build
make release

# Cross-compile for AArch64 (e.g. muOS handhelds)
make release CC=aarch64-buildroot-linux-gnu-gcc

# Clean
make clean
```

The binary is named `vtree`. Place it alongside `./fonts`, `theme`, `config.ini`, and the `res/` icon folder.

---

## Directory Layout

```
vtree                           - the binary
config.ini                      - user configuration (created/updated by Save Config)
fonts/                          - fonts
fonts/JetBrainsMono-Medium.ttf  - default UI font (required)
lang/English.ini                - default language file (required)
res/                            - PNG icons used by the UI
theme/                          - themes ini files
gamecontrollerdb.txt            - SDL controller mappings (optional)
```

---

## Gamepad Controls

### Explorer

| Button | Action |
|--------|--------|
| D-pad Up / Down | Move cursor |
| D-pad Left / Right | Switch active pane (dual-pane mode only) |
| L1 / R1 | Page up / down |
| A | Enter folder / open file; with marks active, opens action menu |
| B | Clear all marks (if any); otherwise go up one directory |
| Back / Select | Mark / unmark file (cursor auto-advances) |
| Y | Open context menu |
| Guide | Open settings menu (two-menu mode) |

### Context Menu

| Button | Action |
|--------|--------|
| D-pad Up / Down | Navigate menu |
| A | Confirm selection |
| B / Y | Close menu |

File operations available: Copy, Cut, Paste, Symlink, Rename, Delete, New File, New Folder, Execute (scripts), File/Dir Info.  
When pasting with conflicts, a resolution dialog offers: Skip, Overwrite, Rename Copy, or Cancel.  
Disabled entries (e.g. Paste with empty clipboard, Symlink on unsupported filesystems, operations on `..`) are shown greyed out and skipped during navigation.

### Text Viewer

| Button | Action |
|--------|--------|
| D-pad Up / Down | Scroll one line |
| D-pad Left / Right | Pan horizontally (when not editing) |
| L1 / R1 | Page up / down |
| A | Edit current line (opens OSK) |
| Start | Save file |
| B | Close viewer |

### Hex Viewer

| Button | Action |
|--------|--------|
| D-pad | Move cursor |
| L1 / R1 | Page up / down |
| A | Edit byte at cursor |
| X | Go to offset |
| Start | Save file |
| B | Close viewer |

### Image Viewer

| Button | Action |
|--------|--------|
| D-pad | Pan image |
| L1 / R1 | Previous / next image in folder |
| A | Fit to screen |
| Y / X | Zoom in / out |
| B | Close viewer |

### On-Screen Keyboard (OSK)

| Button | Action |
|--------|--------|
| D-pad | Navigate keys |
| A | Type selected key |
| X | Backspace |
| Y | Cycle layer (abc → ABC → symbols) |
| B | Cancel / discard |
| Back / Select | Show / hide keyboard grid |
| Start | Toggle Insert / Overwrite mode |
| L1 / R1 | Move text caret left / right |

When the keyboard grid is hidden, D-pad Left/Right move the caret directly.

---

## Configuration

`config.ini` is created next to the binary on first save. All values are optional — defaults are used for anything omitted.

```ini
[General]
ShowHidden=false      # show dotfiles / hidden entries
RememberDirs=false    # restore pane paths on next launch
ExecScripts=false     # allow executing .sh files (experimental)
SinglePane=false      # full-width single-pane mode (disables pane switching and paste destination dialog)

[Display]
ScreenWidth=0         # 0 = auto-detect on first launch (stores physical dims)
ScreenHeight=0
Rotation=0            # 0=none, 1=90 CW, 2=180, 3=270 CW  (also: --rotate= CLI flag)
FontSizeList=18
FontSizeHeader=18
FontSizeFooter=18
FontSizeMenu=18
FontSizeHex=16
FontFile=             # basename of font file; scanned from fonts/ at startup

[Paths]
StartDirectoryLeft=/
StartDirectoryRight=/mnt/sdcard
GameControllerDB=     # leave blank to search next to the binary

[Keys]
# SDL button names: a b x y back start leftshoulder rightshoulder guide misc1
KeyConfirm=a
KeyBack=b
KeyMenu=y
KeyMark=back
KeyPgUp=leftshoulder
KeyPgDn=rightshoulder

[OskKeys]
OskKeyType=a
OskKeyBksp=x
OskKeyShift=y
OskKeyOk=misc1
OskKeyCancel=b
OskKeyToggle=back
OskKeyIns=start

[ActiveTheme]
ActiveTheme=Dark      # must match a [Theme.Name] section in theme.ini

[FileTypes]
ExtraImageExts=       # space/comma separated, dot optional — e.g. .raw .exr
ExtraTextExts=        # appended to the built-in list
```

Settings can also be changed at runtime from the context menu → Settings, then saved with **Save Config**.

---

## Theming

Themes live in `./theme/theme-name.ini` as `[Theme.Name]` sections. The active theme is stored in `config.ini` under `[ActiveTheme]`. When you save config from the Settings screen, the current theme colours are also written back to `config.ini` so inline edits round-trip cleanly.

Colour values are `#RRGGBB` or `#RRGGBBAA`.

**Customisable colours:**  
`Bg`, `AltBg`, `HeaderBg`, `Text`, `TextDisabled`, `LinkText`, `HighlightBg`, `MarkedText`, `MenuBg`, `MenuBorder`

**Hex viewer byte categories (optional):**  
`HexZero`, `HexCtrl`, `HexSpace`, `HexPunct`, `HexDigit`, `HexLetter`, `HexHigh`, `HexFull`

---

## Adding Fonts

Drop any `.ttf` or `.otf` file into a `fonts/` folder next to the `vtree` binary. On next launch it will appear in Settings → Font File. Changes take effect immediately and are saved with Save Config.

---

## Attribution

- Icons: [LineIcons](https://lineicons.com)
- Default font: [JetBrains Mono](https://www.jetbrains.com/lp/mono/) by JetBrains
- Controller mappings: [SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB)

---

## License

See `LICENSE`.
