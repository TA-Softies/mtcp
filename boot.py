import usb_cdc
import usb_midi
import usb_hid

# Disable serial and MIDI to free ~4KB RAM for the Keyboard library.
usb_cdc.disable()
usb_midi.disable()

# Explicitly enable HID with keyboard only.
# Without this, usb_hid.devices may be empty on some CircuitPython builds.
usb_hid.enable((usb_hid.Device.KEYBOARD,))

# Storage remains enabled so the CIRCUITPY drive stays accessible.