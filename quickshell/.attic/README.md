# attic

Moved here on 2026-10-19 (nothing launched them; a full copy is also in
`~/.config/rice-backup-20261019-1117/quickshell/`):

- `shell.qml` — the original test bar from the first quickshell setup. As the
  root `shell.qml` it made `~/.config/quickshell` itself a config, which is why
  `quickshell -c <Name>` was unreliable; every launcher now uses `-p <dir>`.
- `Bar.qml`, `Bar/` — an older bar + todo widget, replaced by waybar and
  `TodoWidget/`.

Move anything back with `mv .attic/<file> ..` if you want it.
