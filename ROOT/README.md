# MTCP - Multi-Tool Control Panel

A professional PowerShell-based system administration toolkit with an interactive menu-driven interface.

## Features

- **System Information Dashboard**
  - Real-time display of system status (hostname, domain, model, OS version)
  - Network information (connection type, IP address, connectivity status)
  - Hardware details (motherboard, RAM)
  - Deep Freeze status monitoring
  - Boot time and uptime tracking

- **Categorized Tool Organization**
  - Troubleshooting (System, Disk, Network diagnostics)
  - Maintenance (cleanup, optimization)
  - System Tools (advanced utilities)

- **User Interface**
  - Unicode ASCII banner
  - Color-coded navigation (categories, subcategories, tools)
  - Keyboard shortcuts for quick access
  - Optimized rendering for smooth navigation
  - Dynamic footer with version and author information

- **Deep Freeze Integration**
  - Automatic status detection
  - Quick toggle between Frozen/Thawed states (hotkey: D)
  - Password-protected operations

- **Auto-Update System**
  - Background update checks on startup
  - One-click update installation
  - Automatic backup and restore on failure
  - Version comparison from GitHub repository

## Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Administrator privileges
- Internet connection (for updates)

## Installation

1. Download the latest release from GitHub
2. Extract the ZIP file to your desired location
3. Run `Start_Panel.bat` as Administrator

## Usage

### Navigation
- **Arrow Keys** (↑/↓): Navigate through menu items
- **Enter**: Select/Execute item
- **ESC**: Go back or exit

### Hotkeys
- **W**: Change wallpaper
- **D**: Toggle Deep Freeze (Freeze/Thaw)
- **U**: Update (when update is available)

## Configuration

Edit `ROOT/sfu-tools/config.json` to customize:
- Add/remove tools
- Modify categories and subcategories
- Set custom hotkeys
- Update version and author information

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
            "tools": [
                {
                    "name": "Tool Name",
                    "description": "Tool description",
                    "command": "powershell command or script",
                    "hotkey": "K"
                }
            ]
        }
    ]
}
```

## Adding Custom Tools

1. Create your PowerShell script in `ROOT/sfu-tools/`
2. Add an entry in `config.json`:

```json
{
    "name": "My Custom Tool",
    "description": "Does something useful",
    "command": "& '$PSScriptRoot\\sfu-tools\\My-Tool.ps1'"
}
```

## Deep Freeze Integration

MTCP automatically detects Deep Freeze installations and displays the current status:
- **FROZEN** (Cyan): System is protected
- **THAWED** (Red): Changes will persist
- **Not Installed** (Gray): DFC.exe not found

Press **D** to toggle between states (requires Deep Freeze password).

## Updates

MTCP checks for updates automatically on startup. When an update is available:
1. A notification appears at the top of the screen
2. Press **U** to download and install
3. The application backs up current version
4. New files are extracted and applied
5. Application restarts automatically

To manually check for updates, the check runs in the background on each launch.

## File Structure

```
ROOT/
├── Launch.ps1              # Main application
├── Start_Panel.bat         # Launcher (Run as Admin)
└── sfu-tools/
    ├── config.json         # Tool configuration
    ├── Check-Update.ps1    # Update checker
    ├── Install-Update.ps1  # Update installer
    ├── Toggle-DeepFreeze.ps1
    ├── Invoke-CheckDisk.ps1
    └── [other tools...]
```

## Troubleshooting

### "Script cannot be loaded" error
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### Deep Freeze status shows "Unknown"
- Ensure DFC.exe exists at `C:\Windows\SysWOW64\DFC.exe`
- Verify Deep Freeze is properly installed

### Update check fails
- Check internet connection
- Verify GitHub repository is accessible
- Check firewall/proxy settings

## License

This project is provided as-is for system administration purposes.

## Author

Technical Assistants
- Lead Developer: Meesum Ahmed

## Repository

https://github.com/TA-Softies/mtcp

## Version

Current: 0.1.0
