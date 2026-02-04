# MTCP - Multi-Tool Control Panel
## by Technical Assistants

A professional PowerShell-based system administration toolkit designed for IT professionals managing Windows environments. Features an intuitive menu-driven interface, system monitoring, and automated maintenance tools.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

## 🚀 Quick Start

1. **Download**: Clone or download this repository
   ```bash
   git clone https://github.com/TA-Softies/mtcp.git
   ```

2. **Run**: Navigate to the ROOT folder and run as Administrator
   ```
   Right-click Start_Panel.bat → Run as Administrator
   ```

3. **Navigate**: Use arrow keys to browse tools, Enter to execute, ESC to go back

## ✨ Key Features

### 📊 Real-Time System Dashboard
- Computer name with domain information
- System model and manufacturer
- Windows version and build number
- Boot time and uptime tracking
- Network status (WiFi/Ethernet, IP address, connectivity)
- Hardware information (motherboard, RAM)
- Deep Freeze status monitoring

### 🛠️ Tool Categories

#### Troubleshooting
- **System**: SFC, DISM, Event Viewer, System Restore
- **Disk**: Check Disk, Disk Cleanup, Defragmentation
- **Network**: IP configuration, DNS flush, connectivity diagnostics

#### Maintenance
- Windows Update management
- Disk cleanup and optimization
- System file integrity checks
- Registry maintenance

#### System Tools
- Advanced system utilities
- Custom PowerShell scripts
- Third-party tool integration

### 🎨 User Interface
- Professional Unicode ASCII banner
- Color-coded categories (Green) and subcategories (Light Green)
- Highlighted selection with arrow key navigation
- Dynamic breadcrumb navigation
- Context-sensitive tool descriptions
- Optimized screen rendering (no full refresh on navigation)

### ❄️ Deep Freeze Integration
- Automatic detection of Deep Freeze installations
- Real-time status display (FROZEN/THAWED)
- Quick toggle with hotkey [D]
- Password-protected operations
- Supports all DFC.exe commands

### 🔄 Auto-Update System
- Background update checks on startup
- Version comparison with GitHub repository
- One-click update installation [U]
- Automatic backup before updates
- Rollback on failure
- Zero-downtime updates with auto-restart

## 📋 System Requirements

- **OS**: Windows 10 or Windows 11
- **PowerShell**: 5.1 or higher (included with Windows)
- **Privileges**: Administrator rights required
- **Internet**: Optional (required for updates only)
- **Screen**: Minimum 76x35 character console window

## 📦 Installation

### Standard Installation
1. Download the latest release from GitHub
2. Extract to your desired location (e.g., `C:\Tools\MTCP\`)
3. Run `ROOT\Start_Panel.bat` as Administrator

### Portable Installation
- No installation needed - runs from any folder
- Can be placed on USB drive for portable use
- No registry modifications
- No system file changes

## 🎮 Usage

### Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate menu items |
| `Enter` | Select/Execute |
| `ESC` | Go back or exit |
| `W` | Quick wallpaper change |
| `D` | Toggle Deep Freeze |
| `U` | Install update (when available) |

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

### Adding Custom Tools

1. **Create your PowerShell script** in `ROOT/sfu-tools/`
   ```powershell
   # My-CustomTool.ps1
   Write-Host "Running custom tool..." -ForegroundColor Green
   # Your code here
   ```

2. **Edit `config.json`** to add your tool:
   ```json
   {
       "name": "My Custom Tool",
       "description": "Brief description of what it does",
       "command": "& '$PSScriptRoot\\sfu-tools\\My-CustomTool.ps1'",
       "hotkey": "M"
   }
   ```

3. **Restart MTCP** to see your new tool

### Configuration File Structure

```json
{
    "meta": {
        "version": "0.1.0",
        "author": "Your Name"
    },
    "categories": [
        {
            "name": "Category Name",
            "description": "Category description",
            "subcategories": [
                {
                    "name": "Subcategory Name",
                    "tools": [...]
                }
            ],
            "tools": [
                {
                    "name": "Tool Name",
                    "description": "Tool description",
                    "command": "command to execute",
                    "hotkey": "H"
                }
            ]
        }
    ]
}
```

## 🔧 Advanced Features

### Deep Freeze Management

MTCP integrates with Faronics Deep Freeze:
- Automatic status detection via `DFC.exe`
- Toggle states: FROZEN ↔ THAWED
- Password-protected operations
- Supports all DFC commands:
  - `/BOOTFROZEN` - Restart frozen
  - `/BOOTTHAWED` - Restart thawed
  - `/LOCK` - Disable input
  - `/UNLOCK` - Enable input

### Update System

The auto-update system:
1. Checks GitHub on startup (background)
2. Compares semantic versions (e.g., 0.1.0 → 0.2.0)
3. Notifies when updates are available
4. Downloads from: `https://github.com/TA-Softies/mtcp/archive/refs/heads/main.zip`
5. Creates backup before installation
6. Extracts and replaces files
7. Restarts application automatically
8. Restores backup if update fails

### Custom Scripts Location

All custom scripts should be placed in:
```
ROOT/sfu-tools/
```

Reference them in config.json using `$PSScriptRoot`:
```json
"command": "& '$PSScriptRoot\\sfu-tools\\Your-Script.ps1'"
```

## 📁 Project Structure

```
SFU-TOOLS/
├── README.md                      # This file
├── .gitignore                     # Git exclusions
├── code.py                        # CircuitPython code (optional)
├── Setup-RoundingUtilUSB.ps1     # USB utility setup
├── Steps.md                       # Setup steps
└── ROOT/                          # Main application folder
    ├── Launch.ps1                 # Main launcher
    ├── Start_Panel.bat            # Entry point
    ├── README.md                  # Application docs
    └── sfu-tools/                 # Tool scripts
        ├── config.json            # Configuration
        ├── Check-Update.ps1       # Update checker
        ├── Install-Update.ps1     # Update installer
        ├── Toggle-DeepFreeze.ps1  # DF toggle
        ├── Invoke-CheckDisk.ps1   # Disk checker
        └── [custom scripts...]    # Your tools
```

## 🛡️ Security Notes

- Requires administrator privileges
- Execution policy set to Bypass for session
- Passwords stored temporarily in memory only
- No credential persistence
- Update verification via HTTPS
- Automatic cleanup of temporary files

## 🐛 Troubleshooting

### Common Issues

**"Script cannot be loaded"**
```powershell
# Run as Administrator:
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

**Deep Freeze status shows "Not Installed"**
- Check if `C:\Windows\SysWOW64\DFC.exe` exists
- Verify Deep Freeze is installed and configured

**Update check fails**
- Verify internet connectivity
- Check firewall/proxy settings
- Ensure GitHub is accessible

**Window size issues**
- MTCP requires 76x35 character window
- Some terminals don't support resizing
- Try Windows Terminal or standard cmd.exe

**Unicode characters don't display**
- Console must support UTF-8
- Font must include Unicode block characters
- Try Consolas, Cascadia Code, or Courier New

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Guidelines
- Use UTF-8 encoding for all files
- Follow PowerShell best practices
- Include descriptions for all tools
- Test with both PowerShell 5.1 and 7+
- Document new features in README

## 📝 Changelog

### Version 0.1.0 (Initial Release)
- Interactive menu-driven interface
- System information dashboard
- Categorized tool organization
- Deep Freeze integration
- Auto-update system
- Optimized navigation rendering
- Keyboard shortcuts
- Error handling with BSOD screens

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
