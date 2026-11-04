# Theme files

Every look the widgets can wear is a **theme spec**: plain JSON, read by
`common/Theme.qml`. You normally make and change them in the **theme studio**
(`Super+Shift+P`, or "studio" / `E` in any widget's theme tab), but the files
are meant to be readable and hand-editable too.

| file | what |
|---|---|
| `common/themes/builtin.json` | the 21 built-in looks, in the order the theme tabs list them |
| `~/.config/quickshell/user-themes.json` | your themes (written by the studio). An entry whose `id` matches a built-in **overrides** it ("changed"); delete the entry to get the built-in back |
| `$XDG_RUNTIME_DIR/quickshell-theme-draft.json` | the studio's unsaved edit, worn live by every widget wearing that theme while the studio is open. Gone at logout |
| `~/.local/state/quickshell-theme.json` | which theme each widget wears (`shared`, per-widget `widgets`, `motion`) |

All of them are watched: saving a file re-themes every running widget, waybar
and dunst within a second.

## A spec

```json
{
  "id": "aero",
  "label": "frutiger aero",
  "glyph": "󰖌",
  "cat": "glass",
  "blurb": "glossy aqua glass · orbs · bubbles",
  "style": { "radius": 18, "surface": "gloss", "fx": "bubbles", "emblem": "orb", "sheen": true },
  "colors": {
    "aqua": { "from": "color5", "lean": [0.52, 0.88, 1.75, 0.06] },
    "accent": "@aqua",
    "panelTop": { "from": "bg", "mix": [["@aqua", 0.5]], "alpha": 0.68 }
  },
  "widgets": {
    "waybar": { "style": { "radius": 4 }, "colors": { "accent": "#ff8800" } }
  }
}
```

- `id` — stable key used by the state file; never shown. `label`, `glyph`,
  `blurb` are what the theme tabs show; `cat` is `glass`, `retro`, `console`,
  `mood` or `mine`.
- `style` — only the keys you change; the rest default (see below).
- `colors` — every named colour of the theme. Besides the tokens the widgets
  use, any extra name (`aqua` above) is a **helper** other colours refer to as
  `@aqua`.
- `widgets` — optional **per-widget overrides**: `style` and `colors` laid over
  the theme for one widget only (`launcher`, `waybar`, `notifications`,
  `wallpicker`, `todo`, `controlcenter`, `studio`). Overriding a colour others
  build on (e.g. `accent`) cascades to them in that widget.

## Colours are recipes

A colour is either a **reference** or a **recipe object**.

References:

| | |
|---|---|
| `bg` `fg` `color0` … `color15` | the walrs palette — follows every `rice` |
| `ok` `warn` `crit` | the rice's status colours (`#79d17f` `#e0a458` `#ef5f6b`) |
| `@name` | another colour of this theme |
| `#rrggbb`, `#aarrggbb`, `transparent`, svg names | a fixed colour |

A recipe starts `from` a reference and applies optional steps **in this order**:

| step | value | effect |
|---|---|---|
| `lean` | `[hue, amount, sat×, light±]` | turn the hue (0–1) toward `hue` by `amount`, scale saturation (floor 0.2), shift lightness (clamped .1–.9) |
| `vivid` | `[sat×, light±]` | more/less saturated, lighter/darker (greys untouched) |
| `tone` | `{ hue, hueShift, greyHue, satMul, satAdd, satMin, satMax, lightMul, lightAdd, lightMin, lightMax }` | free HSL: absolute or shifted hue (degrees), `value × mul + add` clamped to `[min, max]` |
| `lighter` | factor | Qt `lighter()` |
| `darker` | factor | Qt `darker()` |
| `mix` | `[[ref, k], …]` | blend toward each reference by `k`, in order |
| `alpha` | 0–1 | final opacity |

A recipe with only `from` is the same as the plain reference.

## Tokens the widgets read

| colour | used for |
|---|---|
| `accent`, `accent2` | selections, badges, gradients |
| `text`, `selText`, `match` (optional) | body text, text on a selection, search matches |
| `panelTop`, `panelMid`, `panelBottom`, `panelBorder`, `rim` | the glass panel |
| `well`, `wellBorder` | recessed lists / boxes |
| `field`, `fieldBorder`, `fieldFocus` | inputs |
| `ok`, `warn`, `crit` (optional) | status colours |
| `face`, `light`, `shade` | classic bevels · `xp`: luna's title bar |

| style | default | |
|---|---|---|
| `dark` | `true` | light themes draw selections near-opaque |
| `radius`, `radiusSm` | 16, 10 | panel and control corners |
| `pillFull` | false | pill-shaped tabs and fields |
| `shadow` | 0.55 | drop shadow strength |
| `surface` | `flat` | selection style: flat gloss block gradient soft ricepill lens classic wii nixie xmb p5 chrome |
| `fx` | `none` | background effect: bubbles grid scanlines blobs banner petals aurora titlebar sweep eco wii divergence wave xbox dmg p5 |
| `emblem` | `glow` | header badge: glow orb prompt sun soft lens classic plain wii nixie luna p5 |
| `titleStyle` | — | with `fx: titlebar`: `luna` for the xp bar |
| `sheen` `streak` `swoosh` `hairline` `edge` `bevel` `wellInset` `fieldInset` `raisedText` `glow` `halo` | false | details |
| `font`, `glyphFont` | Pixel Code, CaskaydiaCove Nerd Font | |
| `contrast` | `auto` | `off` = colours exactly as written; `auto` lifts text, accents and the selection until they read (WCAG) over the glass on dark **and** light wallpapers |

After evaluation, `readable()` in `Theme.qml` derives `dim`, `faint`, `ink`,
`match`, `okInk`, `warnInk`, `critInk`, `critFill`, `fill` and `selDim` — don't
name helpers after those.

## Adding a built-in

Append a spec to `builtin.json` (its position is its place in the theme tabs).
Effects (`fx`), selection styles (`surface`) and badges (`emblem`) are QML in
`ThemedPanel.qml`, `Surface.qml` and `Emblem.qml`; a new one needs a branch
there, then the studio lists it once you add the key to `surfaces` / `effects`
/ `emblems` in `ThemeStudio/shell.qml`.
