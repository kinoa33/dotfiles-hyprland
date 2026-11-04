<div align="center">
dotfiles-hyprland

A dark, cyberpunk-cozy Hyprland desktop on Arch Linux, themed with pywal and managed with GNU Stow.

Show Image Show Image Show Image

</div>
Preview
<!-- Add your screenshots here, e.g. put them in a `screenshots/` folder -->
Desktop	Launcher
desktop	launcher
Terminal	Lock screen
terminal	lock
What's inside

Each folder is a standalone GNU Stow package.

Package	Description
hypr	Hyprland window manager config (rounded corners, blur, subtle borders, animations)
waybar	Status bar, including a custom Dynamic Island-style module
quickshell	Quickshell-based widgets
kitty	Terminal emulator with pywal colors and blur
fish	Fish shell config
nvim	Neovim config
wofi	Application launcher with a dark teal theme
swaync	Notification center (SwayNotificationCenter)
cava	Audio visualizer
fastfetch	System info fetch config
wal	pywal templates, so every app follows the wallpaper palette
Look and feel
Style: dark, cyberpunk-cozy, macOS-inspired rounding and blur
Accent: teal 
#58908C
Font: Pixel Code (with a Nerd Font for icons and glyphs)
Theming: pywal generates colors from the wallpaper and the templates in wal/ apply them to the apps
Installation

Back up your existing configs first. Stow will refuse to overwrite files that already exist.

1. Install dependencies (Arch Linux)
bash
sudo pacman -S hyprland waybar kitty fish neovim wofi cava fastfetch stow

You will also need, from the official repos or the AUR depending on your setup:

swaync
quickshell
python-pywal
Pixel Code font and a Nerd Font
2. Clone the repo
bash
git clone https://github.com/kinoa33/dotfiles-hyprland.git ~/dotfiles-hyprland
cd ~/dotfiles-hyprland
3. Symlink with Stow

Link everything:

bash
stow */

Or pick only what you want:

bash
stow hypr waybar kitty

To remove a package:

bash
stow -D waybar
4. Generate the colors

Set a wallpaper and let pywal build the palette:

bash
wal -i /path/to/wallpaper.png

Then log in to Hyprland, or reload it with hyprctl reload.

Notes
Some files are ignored on purpose (backups, fish_variables, local-only folders), see .gitignore.
These are personal dotfiles. Take what you like, and expect to adjust paths, monitors and keybinds for your own machine.
Credits

Thanks to the Hyprland, Waybar, Quickshell and pywal projects, and to the wider r/unixporn community for the inspiration.
