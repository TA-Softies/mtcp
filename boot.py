import usb_cdc
import usb_midi

# DISABLE USB SERIAL & MIDI
# This frees up ~4KB of RAM, which is critical for the RP2040
# to load the Keyboard library without crashing.
usb_cdc.disable()
usb_midi.disable()

# Note: We do NOT disable storage, so you can still edit files.