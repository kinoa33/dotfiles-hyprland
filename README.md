<div align="center">

# dotfiles-hyprland

A dark, glowing Hyprland desktop on Arch Linux. Colors follow the wallpaper through pywal, and the text uses Pixel Code everywhere.

![Hyprland](https://img.shields.io/badge/WM-Hyprland-58908C?style=for-the-badge&logo=hyprland&logoColor=white)
![Arch](https://img.shields.io/badge/OS-Arch%20Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-fish-4AAE46?style=for-the-badge&logo=gnubash&logoColor=white)
![Editor](https://img.shields.io/badge/Editor-Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)

</div>

---

## What's inside

| Folder | What it is |
|--------|------------|
| `hypr/` | Hyprland config written in **Lua** (`hyprland.lua`), the `hyprlock.conf` lock screen, and a layout toggle script |
| `waybar/` | Floating status bar with glow text, Japanese numeral workspaces, and a pywal color template |
| `kitty/` | Terminal: Pixel Code 16, 82% opacity, cursor trail, pywal colors |
| `quickshell/` | Two custom QML panels: a **clipboard history** picker and a **todo list** |
| `wofi/` | App launcher, a centered translucent panel colored by pywal |
| `swaync/` | Notification center (top right) with a control center |
| `fish/` | Fish shell: minimal prompt, runs fastfetch on start, `kfetch` and `kff` aliases |
| `fastfetch/` | Custom fetch layout with an ASCII rose logo and total uptime-hours script |
| `nvim/` | Neovim config on lazy.nvim, with LSP, treesitter, blink.cmp, fzf-lua, nvim-tree, gitsigns and lualine |
| `cava/` | Audio visualizer config with a set of GLSL shaders |
| `wal/` | pywal template that exports the palette to Hyprland |

---

## Highlights

**Hyprland**
- Defaults to the **scrolling layout** (column width 0.6). Dwindle and master are one keypress away.
- Rounded corners (`rounding = 12`), blur with vibrancy, soft shadows, and spring-based window animations.
- Wide side gaps (80px left and right), which gives the floating-panel look.
- Two keyboard layouts, **English and Arabic**, switched with `Super + Space`.
- Blur layer rules for Waybar, the clipboard panel, and the todo panel.
- Optional `glasscope` liquid-lens plugin, enabled only if it is installed.

**Waybar**
- Arch logo, clock, keyboard language, workspaces shown as 一 二 三 … 十, brightness, volume, do-not-disturb toggle, tray, and battery.
- Glow effect on the text, built from layered shadows tinted with the wallpaper accent.

**Quickshell panels**
- `clipboard`: shows your clipboard history (text and images, stored with `cliphist`) and copies the item you pick.
- `todo`: a small todo list you toggle on and off.
- Both read `~/.cache/wal/colors.json`, so they change color when you change wallpaper.

**Lock screen**
- Blurred screenshot background, date on top, a large 12-hour clock, and a rounded password field.

---

## Keybindings

`Super` is the main key.

| Keys | Action |
|------|--------|
| `Super + Q` | Terminal (kitty) |
| `Super + F` | Launcher (wofi) |
| `Super + E` | File manager (thunar) |
| `Super + Y` | Browser (brave) |
| `Super + C` | Close window |
| `Super + V` | Toggle floating |
| `Super + A` | Maximize |
| `Super + T` | Toggle scrolling / dwindle |
| `Super + G` | Cycle layouts: dwindle, scrolling, master |
| `Super + R` | Clipboard history |
| `Super + Z` | Todo list |
| `Super + Shift + X` | Minimize / restore window |
| `Super + S` | Toggle scratchpad |
| `Super + 1…0` | Go to workspace 1 to 10 |
| `Super + Shift + 1…0` | Move window to workspace |
| `Super + Space` | Switch keyboard layout (EN / AR) |
| `Super + M` | Exit Hyprland |
| `Ctrl + G` | Toggle the glasscope lens (if the plugin is installed) |
| `Print` | Screenshot tool (HyprQuickFrame) |

Volume, brightness, and media keys are bound through `wpctl`, `brightnessctl`, and `playerctl`.

---

## Dependencies

Core:

```bash
sudo pacman -S hyprland hyprlock waybar kitty fish neovim wofi cava fastfetch stow \
    python-pywal cliphist wl-clipboard playerctl brightnessctl wireplumber \
    pavucontrol thunar jq fcitx5
```

From the AUR or elsewhere, depending on your setup:

- `quickshell`
- `swaync`
- `awww` (wallpaper daemon)
- A Nerd Font and **Pixel Code**
- `HyprQuickFrame` (a Quickshell config) for the screenshot key. It is not included here.

Neovim 0.11 or newer is recommended.

---

## Installation

> Back up your current `~/.config` first.

### 1. Clone

```bash
git clone https://github.com/kinoa33/dotfiles-hyprland.git ~/dotfiles-hyprland
cd ~/dotfiles-hyprland
```

### 2. Link the configs

These folders are Stow packages (they already contain a `.config/` path):

```bash
stow cava fastfetch fish nvim swaync wal wofi
```

These four hold the config files directly, so link them into `~/.config` yourself:

```bash
ln -s ~/dotfiles-hyprland/hypr       ~/.config/hypr
ln -s ~/dotfiles-hyprland/waybar     ~/.config/waybar
ln -s ~/dotfiles-hyprland/kitty      ~/.config/kitty
ln -s ~/dotfiles-hyprland/quickshell ~/.config/quickshell
```

### 3. Set up pywal templates

Waybar, wofi, and the Quickshell panels read colors that pywal generates. Copy the Waybar template so pywal can fill it in:

```bash
mkdir -p ~/.config/wal/templates
cp ~/dotfiles-hyprland/waybar/colors-waybar.css ~/.config/wal/templates/
```

Then pick a wallpaper and build the palette:

```bash
wal -i /path/to/wallpaper.png
```

### 4. Start Hyprland

Log in to a Hyprland session, or reload with `hyprctl reload`.

---

## Change these for your machine

- **Monitor:** `hypr/hyprland.lua` sets `DP-3` at `1890x1080@120`. Change it to match `hyprctl monitors`.
- **Home path:** `waybar/style.css` and `wofi/.config/wofi/style.css` import colors from `/home/kino/.cache/wal/`. Replace `kino` with your username.
- **Wallpaper:** the autostart line calls `awww img` without a file. Add the path to your wallpaper.
- **Extra scripts:** the "infinite desktop" binds (`Super + D`, plus arrow-key window movement and resize) call Python scripts in `~/scripts/`. They are not part of this repo, so remove those binds if you do not have them.
- **Panels:** the config also starts `qs -c launcher`, which is not included here. Remove that line if you do not have it.
- **Do-not-disturb button:** the Waybar toggle uses `dunstctl`. If you use swaync, change it to `swaync-client`.

---

## Credits

- Neovim config structure and keymaps layout based on [impasto](https://github.com/andreumassanet/impasto) by andreumassanet.
- Several cava shaders (the `orion_*` ones) are by rezky_nightky, see the headers in `cava/.config/cava/shaders/` for the license.
- [Hyprland](https://hyprland.org/), [Waybar](https://github.com/Alexays/Waybar), [Quickshell](https://quickshell.org/), [pywal](https://github.com/dylanaraps/pywal), and the r/unixporn community.
