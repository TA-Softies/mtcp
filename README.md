# MTCP - Multi-Tool Control Panel
## by Technical Assistants

A modern Python Textual TUI for Windows system administration. Features a rich terminal interface with live system monitoring, categorized tools, and Deep Freeze integration.

![Version](https://img.shields.io/badge/version-0.3.1-blue)
![Python](https://img.shields.io/badge/Python-3.10%2B-blue)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

## 🚀 Quick Start

### Option 1: Download Release (Recommended)
```powershell
# Download MTCP.exe from GitHub Releases
# Run as Administrator
```

### Option 2: Run from Source
```powershell
# Clone repository
git clone https://github.com/TA-Softies/mtcp.git
cd mtcp/ROOT

# Run launcher (handles everything automatically)
.\Launch.ps1
```

The launcher will:
1. Check for `MTCP.exe` → run directly
2. Download latest release from GitHub
3. Fall back to Python mode (creates venv, installs dependencies)

## ✨ Key Features

### 📊 Real-Time Dashboard
- System info: hostname, domain, model, Windows version
- Network status: WiFi/Ethernet, IP address, connectivity
- Deep Freeze status: FROZEN/THAWED/Not Installed
- Boot time and uptime tracking

### 📈 Live Monitoring Panel
- CPU usage percentage
- RAM usage (used/total GB)
- Disk usage (used/total GB)
- Network connectivity status

### 🛠️ Tool Categories

| Category | Tools |
|----------|-------|
| **Troubleshooting** | SFC, DISM, Event Viewer, Check Disk, Network diagnostics |
| **Maintenance** | Disk cleanup, Windows Update, System optimization |
| **System Tools** | Advanced utilities, PowerShell scripts |

### ❄️ Deep Freeze Integration
- Automatic status detection via `DFC.exe`
- Quick toggle with hotkey **[D]**
- Supports FROZEN ↔ THAWED states
- Password-protected operations

### 🔄 Auto-Update System
- Downloads from GitHub Releases
- Standalone `.exe` distribution
- Background update checks

## 📋 System Requirements

- **OS**: Windows 10 or Windows 11
- **Python**: 3.10 or higher (auto-installed by launcher if missing)
- **Privileges**: Administrator rights required
- **Internet**: Optional (required for updates/release download)

## 📦 Installation

### Standalone Executable
1. Download `MTCP.exe` from [GitHub Releases](https://github.com/TA-Softies/mtcp/releases)
2. Place in `ROOT/` folder alongside `sfu-tools/`
3. Run as Administrator

### From Source
```powershell
cd ROOT
.\Launch.ps1  # Handles venv creation and dependencies
```

### Manual Python Setup
```powershell
cd ROOT
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r mtcp/requirements.txt
python -m mtcp
```

## 🎮 Usage

### Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items |
| `Enter` / `→` | Select/Execute |
| `Esc` / `←` | Go back |
| `W` | Quick wallpaper change |
| `D` | Toggle Deep Freeze |
| `/` | Command mode |
| `F1` | Help screen |
| `Q` / `E` | Exit |

### Commands (Press `/`)

| Command | Action |
|---------|--------|
| `/help` | Show help screen |
| `/credits` | Show credits |
| `/debug` | Debug information |
| `/update` | Check for updates |
| `/exit` | Exit application |

### Navigation Flow
```
Main Menu
  ├─ [CAT] Troubleshooting
  │    ├─ [SUB] System
  │    │    └─ System File Checker
  │    ├─ [SUB] Disk
  │    └─ [SUB] Network
  ├─ [CAT] Maintenance
  └─ [CAT] System Tools
```

## ⚙️ Configuration

Edit `ROOT/sfu-tools/config.json` to customize tools and categories.

### Adding Custom Tools

1. **Create your PowerShell script** in `ROOT/sfu-tools/`
   ```powershell
   # My-CustomTool.ps1
   Write-Host "Running custom tool..." -ForegroundColor Green
   ```

2. **Add to `config.json`**:
   ```json
   {
       "name": "My Custom Tool",
       "description": "What it does",
       "command": "& '$PSScriptRoot\\sfu-tools\\My-CustomTool.ps1'"
   }
   ```

3. **Restart MTCP** to see your new tool

## 🔧 Advanced Features

### Deep Freeze Management

MTCP integrates with Faronics Deep Freeze:
- Automatic status detection via `DFC.exe`
- Toggle states: FROZEN ↔ THAWED
- Dedicated screen with Y/N/Esc controls
- Supports DFC commands:
  - `/BOOTFROZEN` - Restart frozen
  - `/BOOTTHAWED` - Restart thawed

### Building from Source

```powershell
cd ROOT
pip install pyinstaller
pyinstaller mtcp.spec --noconfirm
# Output: dist/MTCP.exe
```

## 📁 Project Structure

```
SFU-TOOLS/                         # Git repository root
├── .github/workflows/build.yml    # CI/CD workflow
├── .gitignore                     # Git exclusions
├── README.md                      # This file
├── LICENSE                        # MIT License
└── ROOT/                          # MTCP application
    ├── Launch.ps1                 # Smart launcher
    ├── mtcp.spec                  # PyInstaller spec
    ├── mtcp/                      # Python package
    │   ├── __main__.py            # Entry point
    │   ├── app.py                 # Main Textual app
    │   ├── screens.py             # Modal screens
    │   ├── sysinfo.py             # System info (WMI)
    │   ├── tools.py               # Tool execution
    │   ├── theme.tcss             # CSS theme
    │   ├── requirements.txt       # Dependencies
    │   └── icons/                 # App icons
    └── sfu-tools/                 # Tool scripts
        ├── config.json            # Configuration
        ├── Toggle-DeepFreeze.ps1  # DF toggle
        ├── Invoke-CheckDisk.ps1   # Disk checker
        └── [custom scripts...]    # Your tools
```

## 🛡️ Security Notes

- Requires administrator privileges
- WMI used for system information
- No credential persistence
- Releases distributed via GitHub

## 🐛 Troubleshooting

### Common Issues

**"Script cannot be loaded"**
```powershell
# Run as Administrator:
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

**Deep Freeze status shows "Not Installed"**
- Check if `C:\Windows\SysWOW64\DFC.exe` exists
- Verify Deep Freeze is properly installed

**Python not found**
- Run `Launch.ps1` - it will auto-install Python 3.12
- Or manually install from python.org

**Window rendering issues**
- Use Windows Terminal for best results
- Ensure terminal supports UTF-8

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Setup
```powershell
cd ROOT
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r mtcp/requirements.txt
pip install pyinstaller  # For building
python -m mtcp  # Run from source
```

## 📝 Changelog

### Version 0.3.1
- Migrated from PowerShell to Python Textual TUI
- Added live monitoring panel (CPU, RAM, Disk, Network)
- Modern terminal UI with CSS theming
- Standalone .exe distribution via PyInstaller
- GitHub Actions CI/CD for automated builds
- Smart launcher with release download

### Version 0.1.0 (Legacy)
- Initial PowerShell-based release
- Interactive menu interface
- Deep Freeze integration
- Auto-update system

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Authors

**Technical Assistants** - A Simon Fraser University Student Organization
- **Meesum Ahmed** - Lead Developer
- **TA-Softies Team** - Contributors and Maintainers

## 🔗 Links

- **Repository**: https://github.com/TA-Softies/mtcp
- **Issues**: https://github.com/TA-Softies/mtcp/issues
- **Releases**: https://github.com/TA-Softies/mtcp/releases

## 📧 Support

For support, please:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Search existing [Issues](https://github.com/TA-Softies/mtcp/issues)
3. Create a new issue with detailed information

## ⭐ Show Your Support

If you find this project useful, please consider giving it a star on GitHub!

---

**Made with ❤️ by Technical Assistants**
