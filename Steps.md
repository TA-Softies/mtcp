# TA-RoundingUtilsUSB | Setup & Usage Guide

## 1. Preparation
Ensure your installation folder contains **exactly** these files and folders. The script relies on this structure to work automatically.

### Folder Structure
```text
/Installer_Folder
 │
 ├── Setup-RoundingUtilUSB.ps1     <-- The Wizard Script
 ├── code.py                       <-- The Automation Payload
 ├── adafruit...rp2040...uf2       <-- Firmware file (CircuitPython)
 ├── adafruit...bundle...zip       <-- Library Bundle (HID Drivers)
 │
 └── ROOT/                         <-- Main Tool Folder
      ├── Start_Panel.bat
      ├── autorun.inf
      └── sfu-tools/               <-- Your scripts (config.json, etc)
```

## 2. Installation (The Wizard)

### Step A: Connect the Key (RP2040)
1.  Unplug the RP2040 board.
2.  Hold down the **BOOT** button.
3.  Plug it into your PC.
4.  Release the button.
    * *Check:* You should see a drive named `RPI-RP2` appear.

### Step B: Run the Script
1.  Right-click `Setup-RoundingUtilUSB.ps1`.
2.  Select **Run with PowerShell**.

### Step C: Follow the Wizard
The script will guide you through two stages:

1.  **Stage 1: Key Setup**
    * Press Enter to confirm the Key is connected.
    * The script will flash the firmware, install the drivers, and upload the code automatically.
    * *Result:* The Key is now programmed.

2.  **Stage 2: Storage Setup**
    * Plug in your main USB Flash Drive (SanDisk, Kingston, etc.).
    * Press Enter to scan.
    * Select your drive number from the list (e.g., `1`).
    * The script will rename the drive to `TA-RoundingUtilsUSB` and copy all files from the `ROOT` folder.

## 3. Field Usage
How to use the tool on a target computer:

1.  **Plug in the Storage USB.**
    * (Nothing happens yet).
2.  **Plug in the Key (RP2040).**
    * Wait 3 seconds.
    * The Key will detect the storage drive and automatically launch the **Technical Assistants Panel**.

---

## Troubleshooting
* **Key doesn't flash:** Make sure you are using a **Data Cable**. Many charging cables do not work.
* **"Board not found":** Ensure you held the BOOT button while plugging it in for the initial setup.
* **Panel doesn't launch:** Check if the Main USB is named exactly `TA-RoundingUtilsUSB`. If not, run the installer (Stage 2) again.