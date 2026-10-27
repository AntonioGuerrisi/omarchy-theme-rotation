# Omarchy Theme Rotation

A Quickshell plugin for Omarchy that periodically switches between installed
themes at random, without consecutive repeats.

- Configurable interval, from 1 minute to 7 days.
- Rotate all installed themes or a selected subset.
- Pause, resume, and switch themes manually from the bar.
- Settings persist across shell and system restarts.
- One shared rotation service, including on multi-monitor setups.

The settings panel is currently in Italian.

## Requirements

An Omarchy installation with the Quickshell plugin system, its built-in
`qs.Ui` components, and the `omarchy theme` commands. Bash, `jq`, and GNU
`shuf` must be available; these are normally included in Omarchy.

## Install

```bash
omarchy plugin add https://github.com/AntonioGuerrisi/omarchy-theme-rotation --enable
```

The plugin appears as **TR** in the right section of the bar. By default, it
rotates all installed themes every **30 minutes**. The first automatic
change happens after the interval, not immediately on startup.

Plugins execute unsandboxed inside the Omarchy shell; review the source before
enabling one.

## Controls

| Action | Result |
|---|---|
| Left-click **TR** | Pause or resume automatic rotation |
| Right-click **TR** | Switch to another included theme immediately |
| Middle-click **TR** | Open the settings panel |

In the settings panel, set **Intervallo (minuti)**, enable all installed
themes or select individual themes, then click **Salva**. **Annulla** closes
the panel without saving.

Selecting no themes stops automatic rotation. Selecting only the current
theme does not reapply it. Removed themes are ignored, never replaced with
unselected themes. When all themes are enabled, newly installed themes are
included automatically.

Manual switching also works while automatic rotation is paused.

## Configuration and IPC

Settings are stored in the `antonio.theme-rotation` bar layout entry in
`~/.config/omarchy/shell.json`:

```json
{
  "id": "antonio.theme-rotation",
  "intervalMinutes": 30,
  "paused": false,
  "includedThemes": null
}
```

`includedThemes: null` means all installed themes. An array selects specific
themes using the display names returned by `omarchy theme list`;
`includedThemes: []` means none.

The running service also exposes IPC commands:

```bash
omarchy-shell theme-rotation status
omarchy-shell theme-rotation pause
omarchy-shell theme-rotation resume
omarchy-shell theme-rotation next

omarchy-shell theme-rotation configure \
  '{"intervalMinutes":15,"includedThemes":["Nord","Tokyo Night"]}'
```

Changing the interval restarts its countdown. Restarting the shell also
starts a new interval; time remaining is not persisted.

## Update or disable

```bash
omarchy plugin update antonio.theme-rotation
omarchy plugin disable antonio.theme-rotation
```

If plugin code remains cached after an update, use `omarchy restart shell`.

## Development

The manifest, service, widget, and helper script live at the repository root.
The helper tests use mocked Omarchy commands and do not change your desktop:

```bash
bash -n rotate.sh
python3 -m unittest discover -s tests
omarchy plugin validate .
```

## License

[MIT](LICENSE)
