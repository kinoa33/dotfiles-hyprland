# quickshell widgets

The rice's own widgets, written in QML for [quickshell](https://quickshell.org)
(0.3, Qt 6.11) on Hyprland. They share one theme system: every widget, waybar,
the dunst notifications and the screenshot tool wear one of 21 built-in looks
(or one you made in the **theme studio**), coloured from the walrs palette of
the current wallpaper.

## Layout

| path | what | how it runs |
|---|---|---|
| `Launcher/` | apps · windows · run · clipboard · session · theme; in the apps search `=` calc / units, `?` web (`?yt`, `?aw` …), `>` run, `+` todo, `:` emoji, `/` files; clipboard: ⇧del removes one, "clear all" / `Ctrl+Shift+Del` twice wipes the history | daemon from `hypr/conf/autostart.conf`; `Super+A` / `V` / `` ` `` / `Shift+Esc` via `hypr/scripts/launcher.sh`. Also renders the waybar / dunst / screenshot themes (`common/ThemeExport.qml`) |
| `TodoWidget/` | to-do list: priorities (`!!`), due dates (`@fri`), filters, keyboard, undo (QML LocalStorage via `common/todo.js`) | `Super+D` → `hypr/scripts/qs-toggle.sh TodoWidget` |
| `ControlCenter/` | stats, volume + output picker + per-app mixer, brightness, media (mpris: art, seek, players), toggles, other widgets, power · notification history tab | `Super+C` → `qs-toggle.sh ControlCenter` |
| `WallPicker/` | wallpapers: grid, crop, peek, favourites, rotation, colour filter, trash | `Super+Shift+W` → `qs-toggle.sh WallPicker` (+ `thumbs.sh`, `rotate.sh`) |
| `ThemeStudio/` | make and change themes, per widget | `Super+Shift+P` → `hypr/scripts/theme-studio.sh [theme] [widget]` |
| `HyprQuickFrame/` | screenshots (third-party, MIT) | `Alt+S` / `Ctrl+Alt+S`; wears the theme through a generated `theme.toml` |
| `common/` | the shared theme system and components | symlinked into every widget dir as `common` |
| `tools/` | checks, linters, audits, the widget template | run by hand — see [Tools](#tools) |
| `.attic/` | retired configs (old bar) | not used |
| `bk/` | downloaded reference bars | not used |

Every widget dir is its own quickshell config and holds a `common -> ../common`
symlink; QML imports it as `import "common"` (quickshell refuses
`import "../common"` from outside a config root). Always start configs by path:
`quickshell -p ~/.config/quickshell/<Dir>` — never `-c`.

## The theme system (`common/`)

| file | role |
|---|---|
| `Theme.qml` | singleton. Loads the theme files, keeps the state (which theme each widget wears), compiles a theme spec into **tokens** (`Theme.t`) and solves contrast |
| `WalColors.qml` | singleton. The walrs palette (`~/.cache/wal/colors.json`), live; `QS_WAL_JSON` overrides it |
| `ThemedPanel.qml` | the glass panel a widget sits on: gradient, border, rim, sheen, the animated `fx` layer, classic/luna title bars |
| `Surface.qml` | a selected / active / hovered surface, drawn per the theme's `surface` style |
| `Emblem.qml` | the header badge, per the theme's `emblem` |
| `Field.qml`, `Well.qml`, `TabBar.qml`, `Keycap.qml`, `IconTile.qml` | input well, recessed area, pill tabs, footer key hint, app tile |
| `todo.js` | the to-do store (LocalStorage db `todoDB`) and the `!!` / `@due` quick-add syntax — shared by TodoWidget and the launcher's `+` row |
| `ThemePicker.qml` | the **theme tab** in every widget: target widget, linked/own, motion, categories, try-on, studio |
| `ThemeExport.qml` | (launcher daemon only) renders the non-QML targets — see below |
| `themes/builtin.json` | the 21 built-in looks, as data |
| `themes/README.md` | **the theme file format** (specs, colour recipes, tokens) |

Components take `th` (default `Theme.t`), so anything can be drawn in another
theme — the theme cards and the studio previews do exactly that.

**State** — `~/.local/state/quickshell-theme.json`:
`{ "shared": "rice", "widgets": { "todo": "aero" }, "motion": true }`. A widget
missing from `widgets` is *linked* and wears `shared`; picking a theme for a
linked widget changes every linked widget. Every running widget watches the
file, so changes land live.

**Theme files** — specs, not code (format: `common/themes/README.md`):

| file | |
|---|---|
| `common/themes/builtin.json` | built-ins |
| `~/.config/quickshell/user-themes.json` | yours, written by the studio. Same `id` as a built-in = that built-in, changed |
| `$XDG_RUNTIME_DIR/quickshell-theme-draft.json` | the studio's unsaved edit, worn live while it's open |

A spec's colours are **recipes over the palette** (`{ "from": "color5", "lean":
[...], "alpha": 0.7 }`), so every theme follows each `rice`. A spec can carry
**per-widget overrides** (`"widgets": { "waybar": { "style": {...}, "colors":
{...} } }`). After compiling, `readable()` lifts or dims text, accents and the
selection until they meet WCAG contrast over the glass on both a dark and a
light wallpaper.

**Exports** — waybar, dunst and HyprQuickFrame can't run QML, so the launcher
daemon's `ThemeExport.qml` renders their themes into `~/.cache/quickshell-theme/`
whenever the theme state, a theme file, the draft or the palette changes:

| file | consumer |
|---|---|
| `waybar.css` | `waybar/style.css` imports it; the export rewrites `style.css` (same bytes) so `reload_style_on_change` reloads only the css. Never `SIGUSR2` waybar for a theme change — it aborts on back-to-back reloads |
| `waybar.sh` | shell vars for `waybar/scripts/powermenu.sh` (rofi) |
| `dunst.conf` | linked as `~/.config/dunst/dunstrc.d/50-theme.conf`, then `dunstctl reload` |
| `hyprquickframe.toml` | linked as `~/.config/hyprquickframe/theme.toml`, read at every screenshot |

"rice" exactly as shipped is special: waybar keeps `waybar/base.css` and dunst
keeps pywal's colours. Once you change rice in the studio, they're generated
like every other theme.

## The theme studio

`Super+Shift+P`, or **studio** / `E` (`Ctrl+E` in the launcher) in any widget's
theme tab — it opens on the highlighted theme, previewing that widget.

- **left** — every theme; new (`Ctrl+N`), copy (`Ctrl+D`), export/import
  (clipboard JSON), delete (yours) or reset (a changed built-in).
- **middle** — stand-ins of every widget (`studio/*Mock.qml`) wearing the edit,
  over your wallpaper (blurred under the glass like Hyprland does) or a plain
  dark / light backdrop; "wear on" puts the theme on widgets.
- **right** — the inspector: readability report, name/glyph/category,
  surfaces (selection style, background effect, badge), details, shape, type,
  and every colour as a recipe (source → lean → vivid → tone → lighter/darker →
  mix → opacity). **Editing for** picks the whole theme or one widget; per-widget
  values show a dot, click it to drop the override.
- **live** (`Ctrl+L`, on by default) shows unsaved edits on the real widgets
  wearing the theme; `Ctrl+S` saves, discard reverts, `Ctrl+Z` / `Ctrl+Shift+Z`
  undo and redo. Switching theme or closing with unsaved edits asks first.
- `Shift`+scroll nudges a slider; plain scroll scrolls.

IPC (`quickshell ipc -p ~/.config/quickshell/ThemeStudio call studio …`):
`open theme widget`, `select`, `scope`, `preview`, `backdrop`, `setStyle key json`,
`setColor name json`, `edit`, `save`, `discard`, `undo`, `create label from`,
`remove`, `exportTheme`, `importTheme`, `importJson`, `state`, `quit`.

## IPC

`quickshell ipc -p ~/.config/quickshell/<Dir> show` lists a config's targets.

| config | target | functions |
|---|---|---|
| Launcher | `launcher` | `toggle mode`, `open mode`, `close`, `themeFor widget`, `prefill mode text` |
| TodoWidget (while open) | `todo` | `add text`, `list`, `undo`, `filter all\|open\|today\|done` |
| ThemeStudio | `studio` | see above |

## Adding things

**A widget** — `tools/new-widget.sh <Dir> <key> [label]` makes a themed overlay
from `tools/widget-template/` (glass panel, theme tab with studio access, focus
grab, Esc / click-outside to close) and prints the remaining steps: add
`{ key, label, glyph }` to `Theme.widgets` in `common/Theme.qml` (theme tabs and
the studio then offer it), bind a key to `qs-toggle.sh <Dir>`, and add the
layer namespace `quickshell-<key>` to the blur `layerrule`s in
`hypr/conf/windowrules.conf`. Then `tools/check.sh <Dir>`.

**A theme** — make it in the studio (it's saved to `user-themes.json`). To ship
it as a built-in, append the spec to `common/themes/builtin.json`, then run
`tools/theme-lint.py` and `tools/contrast.sh`.

**A selection style / effect / badge** — add a `case` and a `Component` in
`Surface.qml` / `ThemedPanel.qml` / `Emblem.qml`, the key to the studio's lists
(`surfaces` / `effects` / `emblems` in `ThemeStudio/shell.qml`) and to
`tools/theme-lint.py`. A new `surface` also needs its row look in
`Theme.selFill()` (contrast), the css in `ThemeExport.surface()` (waybar) and
`tools/contrast.py`.

## Tools

| | |
|---|---|
| `tools/check.sh [Dir …]` | smoke test: starts each widget for 5 s in a sandbox (own state, theme, draft, export files and todo database) and prints any QML warning or error |
| `tools/lint.sh [file …]` | qmllint with `.qmllint.ini` (quickshell false positives off) |
| `tools/theme-lint.py [file …]` | validates theme files: refs, recipes, enums, cycles, per-widget overrides |
| `tools/contrast.sh [widget]` | readability audit of every theme over the test palettes in `tools/palettes/` (dark, light, grey, warm, cool) |
| `tools/tokdump/` | prints every theme's tokens as JSON (`QS_WAL_JSON`, `QS_DUMP_WIDGET`) |
| `tools/new-widget.sh` | see [Adding things](#adding-things) |
| `tools/gen-emoji.py` | rebuilds `Launcher/emoji.tsv` (the `:` emoji search) from python's unicode data |

Environment overrides the tools use (handy for your own experiments):
`QS_WAL_JSON` (palette), `XDG_STATE_HOME` (theme state, launcher usage,
wallpicker prefs), `QS_USER_THEMES`, `QS_THEME_DRAFT`, `QS_EXPORT_DIR`,
`QS_EXPORT_POKE`, `QS_EXPORT_WIDGET`.

Known near-misses in `contrast.sh` (WCAG 4.5 for body text): on a *light*
palette, liquid glass and vaporwave selections reach about 4.1–4.2:1 (their
selection is translucent by design), and ps3's white selection text on a green
palette reaches 4.4:1.

## Widget data

| what | where |
|---|---|
| to-do tasks | `~/.local/share/quickshell/QML/OfflineStorage/Databases/<md5 of todoDB>.sqlite`, table `tasks(text, done, prio, due, created, done_at)` — older rows get the new columns on first open |
| launcher usage, pins, hidden apps, recent emoji | `~/.local/state/quickshell-launcher/usage.json` |
| wallpicker favourites, recent, view | `~/.local/state/wallpicker/state.json` |
| wallpaper thumbnails, sizes, colours | `~/.cache/wallpicker/thumbs/<key>.{jpg,dim,pal}` (`thumbs.sh`) |

## Gotchas

- **Layout overflow**: a `RowLayout` never shrinks a child below its implicit
  width, so a row of key hints in a wide font pushes the whole panel wider.
  Footers put their hints in a clipped `Item { Layout.fillWidth: true; clip: true }`.
- **Delegate index**: a ListView delegate being removed sees `index === -1`;
  compare `index >= 0 && root.sel === index`, or `-1 === -1` lights it up.
- **Reserved names**: a QML method can't be called `escape` ("Illegal method name").
- **Pipewire streams**: an app's playback stream is `isStream && isSink`
  (quickshell's sense of "sink"), a capture stream is `isStream && !isSink`.

- **Glyphs**: nerd-font icons in the Private Use Area can get lost by editors and
  tools. New code writes them as escapes, `"\u{F03D8}"`; keep existing literal
  glyphs intact when editing (check with `grep -P '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]'`).
- **FileView loading**: a `path:` binding is applied after the FileView is
  created, so `blockLoading` alone still loads late. `Theme.qml` and
  `WalColors.qml` call `text()` in `Component.onCompleted` to force the first
  read, then turn `watchChanges` on — that's why the first frame already has
  the right theme. Writes use `atomicWrites: false` so every process's inotify
  watch survives.
- **Binding order**: in `onXChanged` handlers, bindings that depend on `X` may
  not have updated yet — read the source of truth (`Theme.effectiveFor()`)
  instead of a dependent property.
- **Hot reload**: quickshell reloads a config when its files change, and a
  reloaded launcher daemon can lose its IPC. After editing launcher or
  `common/` files, restart it: `pkill` its pid, then
  `hyprctl dispatch exec "quickshell -p ~/.config/quickshell/Launcher -n"`.
- **Performance**: widget windows are panel-sized (not full-screen) and closed
  by `HyprlandFocusGrab`; full-screen overlays made Hyprland re-blur the whole
  screen every animation frame. Animations use Animators (render thread).
  Measure with `hyprctl keyword debug:overlay true`.
