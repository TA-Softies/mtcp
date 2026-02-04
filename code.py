import time
import usb_hid
import board
import digitalio
from adafruit_hid.keyboard import Keyboard
from adafruit_hid.keyboard_layout_us import KeyboardLayoutUS
from adafruit_hid.keycode import Keycode

# --- CONFIGURATION ---
# The label of your big USB drive (Case Sensitive!)
TARGET_DRIVE = "TA-RoundingUtilsUSB"
TARGET_FILE  = "Start_Panel.bat"

# --- SETUP ---
kbd = Keyboard(usb_hid.devices)
layout = KeyboardLayoutUS(kbd)

# Try to blink the LED (Pin 25 is standard for most, Pin 23 for some YD-RP2040s)
led = digitalio.DigitalInOut(board.GP25)
led.direction = digitalio.Direction.OUTPUT

# --- PAYLOAD ---
led.value = True
time.sleep(3.0) # Safety wait for Windows driver load

# Open Run Dialog
kbd.press(Keycode.GUI, Keycode.R)
time.sleep(0.1)
kbd.release_all()
time.sleep(0.5)

# Type the Command
# Finds drive with label 'TA-RoundingUtilsUSB' and runs the bat file
cmd = f"powershell -W Hidden -C \"$d=(Get-Volume -FileSystemLabel '{TARGET_DRIVE}').DriveLetter; if($d){{Start-Process ($d+':\\{TARGET_FILE}')}}\""
layout.write(cmd)

# Enter
time.sleep(0.5)
kbd.press(Keycode.ENTER)
time.sleep(0.1)
kbd.release_all()

led.value = False