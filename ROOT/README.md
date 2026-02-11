# MTCP - Multi-Tool Control Panel

A modern Python Textual TUI for system administration, built for Technical Assistants.

## Features

- **Modern TUI Interface** (Python Textual)
  - Real-time system information dashboard
  - Live monitoring panel (CPU, RAM, Disk, Network)
  - Keyboard-driven navigation with vim-style bindings
  - Color-coded categories and tools

- **System Information Dashboard**
  - Hostname, domain, system model
  - Windows version and uptime
  - Network status (WiFi/Ethernet, IP, connectivity)
  - Deep Freeze status

- **Categorized Tool Organization**
  - Troubleshooting (System, Disk, Network diagnostics)
  - Maintenance (cleanup, optimization)
  - System Tools (advanced utilities)

- **Deep Freeze Integration**
  - Automatic status detection
  - Quick toggle with hotkey [D]
  - Supports FROZEN/THAWED states

- **Auto-Update System**
  - Downloads from GitHub releases
  - Standalone .exe distribution

## Requirements

- Windows 10/11
- Administrator privileges
- Python 3.10+ (auto-installed if missing)

## Quick Start

### Option 1: Run the Launcher (Recommended)
```powershell
# Right-click Launch.ps1 → Run with PowerShell
# Or from PowerShell (Admin):
.\Launch.ps1
```

The launcher will:
1. Check for `MTCP.exe` → run directly
2. Try to download latest release from GitHub
3. Fall back to Python source mode (creates venv, installs deps)

### Option 2: Run from Python Source
```powershell
cd ROOT
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r mtcp/requirements.txt
python -m mtcp
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu |
| `Enter` / `→` | Select item |
| `Esc` / `←` | Go back |
| `W` | Change wallpaper |
| `D` | Toggle Deep Freeze |
| `/` | Command mode |
| `F1` | Help |
| `Q` / `E` | Exit |

## Commands (Press `/`)

| Command | Action |
|---------|--------|
| `/help` | Show help |
| `/credits` | Show credits |
| `/debug` | Debug info |
| `/update` | Check for updates |
| `/exit` | Exit application |

## Configuration

Edit `sfu-tools/config.json` to customize tools and categories.

## Building from Source

```powershell
pip install pyinstaller
pyinstaller mtcp.spec --noconfirm
# Output: dist/MTCP.exe
```

## License

MIT License - See LICENSE file in repository root.## Author

Technical Assistants
- Lead Developer: Meesum Ahmed

## Repository

https://github.com/TA-Softies/mtcp

## Version

Current: 0.1.0
