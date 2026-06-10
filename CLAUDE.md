# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MTCP (Multi-Tool Control Panel) is a Windows TUI application for Technical Assistants to manage system diagnostics, maintenance, and administration. Built with Python + Textual, it runs either as a PyInstaller-compiled `.exe` or directly from source.

The repo also contains CircuitPython firmware for a companion USB macro device (RP2040): `code.py`, `boot.py`, `firmware/`, and `Setup-RoundingUtilUSB.ps1`.

## Running

```powershell
# From source (inside ROOT/)
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r mtcp/requirements.txt
python -m mtcp
```

```powershell
# Smart launcher (handles admin elevation, exe discovery, release download, Python fallback)
.\ROOT\Launch.ps1
```

## Building

```powershell
# Inside ROOT/ with .venv active and pyinstaller installed
pyinstaller mtcp.spec --noconfirm
# Output: ROOT/dist/MTCP.exe
```

CI builds on `v*` tags via `.github/workflows/build.yml` (PyInstaller → GitHub Release). The workflow requires `permissions: contents: write` on the job — without it, `GITHUB_TOKEN` cannot create releases (403). The rolling `latest` pre-release uses `make_latest: false` to avoid conflicting with versioned releases.

## Architecture

```
ROOT/mtcp/          Python package
  app.py            MTCPApp (Textual app class) — main entry, navigation state, live metrics loop
  screens.py        Modal screens pushed/popped: Help, Credits, Debug, Update, Exit, ToolOutput
  sysinfo.py        WMI + psutil: system info snapshot (get_system_info) and live metrics (get_live_metrics)
  tools.py          config.json loader, tool executor (run_tool), update checker
  theme.tcss        Textual CSS — dark theme, cyan/blue accents

ROOT/sfu-tools/
  config.json       All tool definitions: categories, subcategories, commands, hotkeys, slash commands
  *.ps1             PowerShell scripts called by tools (Deep Freeze, Check Disk, Wallpaper, DelProf2, updates)
```

**Data flow:** `Launch.ps1` → `__main__.py` → `MTCPApp` loads config (async worker) and system info (async worker) → Textual widgets render category/subcategory/tool tree → user selects tool → `tools.run_tool()` executes PowerShell/exe/msc → `ToolOutput` modal shows results.

**Live metrics:** `get_live_metrics()` is called every 2 seconds via a `set_interval` timer to update CPU/RAM/Disk/Network progress bars.

**PyInstaller awareness:** Resource paths use `sys._MEIPASS` when running as frozen exe, falling back to relative paths in source mode. Both `theme.tcss` and `sfu-tools/` are bundled.

## Launcher fallback chain (`ROOT/Launch.ps1`)

1. `MTCP.exe` found locally → launch immediately
2. No local exe → download from GitHub `latest` release → launch
3. Download fails → fetch Python source from GitHub (git clone or zip) if `mtcp/` missing
4. Run in Python source mode (create venv, install deps)

Dependency installation only runs in mode 4. The log file is written to `C:\Windows\Temp\MTCP_launch.log` when running elevated (the normal case).

## USB Macro Device (RP2040)

**`boot.py`** — Runs at CircuitPython startup. Disables USB serial and MIDI to free RAM, enables HID keyboard only. Storage stays enabled so Windows can see the `CIRCUITPY` volume label (needed by `code.py`'s drive lookup).

**`code.py`** — The automation payload:
1. Waits 8 seconds for Windows to mount the drive and open File Explorer autoplay
2. Presses `Win+D` (show desktop) + 2s wait to clear focus from File Explorer
3. Opens Run dialog (`Win+R`), types a hidden PowerShell command that looks up the `CIRCUITPY` drive letter and runs `ROOT\Launch.ps1`
4. Submits with `Ctrl+Shift+Enter` to trigger UAC elevation
5. Presses `Alt+Y` up to 4 times (3s apart) to accept the UAC prompt

**Critical:** The PowerShell command typed by the device must not use `$variable` assignment — the outer shell (cmd or PowerShell) expands undefined `$vars` to empty string before the inner PowerShell sees them. Use inline expressions: `(Get-Volume -FileSystemLabel 'CIRCUITPY').DriveLetter` directly.

**`Setup-RoundingUtilUSB.ps1`** — Wizard to flash firmware and deploy payload to a CIRCUITPY device. Key behaviors:
- Detects RPI-RP2 (bootloader) or CIRCUITPY (already flashed) automatically
- Clears the FAT dirty bit with `chkdsk /f /x` before deploying (continues gracefully if access is denied)
- Uses `cmd /c rmdir /s /q` instead of `Remove-Item -Recurse -Force` when removing the old ROOT folder — PS 5.1 fails on deeply nested trees (e.g. `.venv`)
- Excludes `.venv`, `__pycache__`, `.git`, `dist`, `.pytest_cache` when copying ROOT to the device

## Key Configuration

**`ROOT/sfu-tools/config.json`** — the single source of truth for all tools. Adding a new tool means adding an entry here (category → subcategory → tool with `name`, `description`, `command`, optional `type`). Slash commands and hotkey mappings are also defined here.

**`ROOT/mtcp.spec`** — PyInstaller spec; update `datas` list when adding new bundled assets.

## Navigation & Hotkeys

`↑/↓` navigate lists, `Enter/→` drill in, `Esc/←` go back, `/` opens command palette, `W` randomizes wallpaper, `D` toggles Deep Freeze, `F1` opens help, `Q/E` exits.

## Dependencies

- `textual>=1.0.0` — TUI framework
- `rich>=13.0.0` — terminal formatting
- `psutil>=5.9.0` — process/system metrics
- `wmi>=1.5.1` — Windows Management Instrumentation
- `pywin32>=306` — Windows COM access

Requires Python 3.10+ on Windows 10/11. Most system operations need administrator privileges (handled by `Launch.ps1`).

## PowerShell gotchas (PS 5.1)

- **`Remove-Item -Recurse -Force`** fails silently on deep directory trees. Use `cmd /c rmdir /s /q "$path"` instead.
- **`2>&1` on native executables** wraps stderr lines in `ErrorRecord` objects and sets `$?` to `$false` even on exit code 0 — avoid or wrap in try/catch.
- **Non-ASCII characters** (em dash, smart quotes) in `.ps1` files cause parse errors if the file encoding doesn't match what PS 5.1 expects. Keep scripts ASCII-safe or run `Fix-Encoding.ps1` to re-encode all `.ps1`/`.json` files to UTF-8 with BOM.
- **`$var` in `-C "..."` strings** — PowerShell expands variables in the outer session before passing to the inner process. Use single-quoted strings or inline expressions to avoid silent empty-string substitution.
