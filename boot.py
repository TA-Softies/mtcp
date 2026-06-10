import usb_cdc
import usb_midi
import usb_hid
import storage

# Disable serial and MIDI to free ~4KB RAM for the Keyboard library.
usb_cdc.disable()
usb_midi.disable()

# Explicitly enable HID with keyboard only.
# Without this, usb_hid.devices may be empty on some CircuitPython builds.
usb_hid.enable((usb_hid.Device.KEYBOARD,))

# Hide the CIRCUITPY drive from the host PC entirely.
# The board appears as a plain HID keyboard — no drive popup, no autoplay.
# To edit files: hold BOOT while plugging in (enters UF2 bootloader,
# boot.py is skipped) then run Setup-RoundingUtilUSB.ps1 to redeploy.
storage.disable()