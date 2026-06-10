# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MTCP (Multi-Tool Control Panel) is a Windows TUI application for Technical Assistants to manage system diagnostics, maintenance, and administration. Built with Python + Textual, it runs either as a PyInstaller-compiled `.exe` or directly from source.

The repo also contains CircuitPython firmware for a companion USB macro device (RP2040) in `firmware/` and `code.py`/`boot.py`.

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

CI builds on `v*` tags via `.github/workflows/build.yml` (PyInstaller → GitHub Release).

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
