#!/bin/sh

export DEVICE_TYPE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
export DEVICE_CONFIG="/opt/muos/device/$DEVICE_TYPE/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# DEVICE CONFIG - STORAGE - BOOT
export DC_STO_BOOT_DEV=$(PARSE_INI "$DEVICE_CONFIG" "storage.boot" "dev")
export DC_STO_BOOT_NUM=$(PARSE_INI "$DEVICE_CONFIG" "storage.boot" "num")
export DC_STO_BOOT_MOUNT=$(PARSE_INI "$DEVICE_CONFIG" "storage.boot" "mount")
export DC_STO_BOOT_TYPE=$(PARSE_INI "$DEVICE_CONFIG" "storage.boot" "type")

# DEVICE CONFIG - STORAGE - ROM
export DC_STO_ROM_DEV=$(PARSE_INI "$DEVICE_CONFIG" "storage.rom" "dev")
export DC_STO_ROM_NUM=$(PARSE_INI "$DEVICE_CONFIG" "storage.rom" "num")
export DC_STO_ROM_MOUNT=$(PARSE_INI "$DEVICE_CONFIG" "storage.rom" "mount")
export DC_STO_ROM_TYPE=$(PARSE_INI "$DEVICE_CONFIG" "storage.rom" "type")

# DEVICE CONFIG - STORAGE - ROOT
export DC_STO_ROOT_DEV=$(PARSE_INI "$DEVICE_CONFIG" "storage.root" "dev")
export DC_STO_ROOT_NUM=$(PARSE_INI "$DEVICE_CONFIG" "storage.root" "num")
export DC_STO_ROOT_MOUNT=$(PARSE_INI "$DEVICE_CONFIG" "storage.root" "mount")
export DC_STO_ROOT_TYPE=$(PARSE_INI "$DEVICE_CONFIG" "storage.root" "type")

# DEVICE CONFIG - STORAGE - SDCARD
export DC_STO_SDCARD_DEV=$(PARSE_INI "$DEVICE_CONFIG" "storage.sdcard" "dev")
export DC_STO_SDCARD_NUM=$(PARSE_INI "$DEVICE_CONFIG" "storage.sdcard" "num")
export DC_STO_SDCARD_MOUNT=$(PARSE_INI "$DEVICE_CONFIG" "storage.sdcard" "mount")
export DC_STO_SDCARD_TYPE=$(PARSE_INI "$DEVICE_CONFIG" "storage.sdcard" "type")

# DEVICE CONFIG - STORAGE - USB
export DC_STO_USB_DEV=$(PARSE_INI "$DEVICE_CONFIG" "storage.usb" "dev")
export DC_STO_USB_NUM=$(PARSE_INI "$DEVICE_CONFIG" "storage.usb" "num")
export DC_STO_USB_MOUNT=$(PARSE_INI "$DEVICE_CONFIG" "storage.usb" "mount")
export DC_STO_USB_TYPE=$(PARSE_INI "$DEVICE_CONFIG" "storage.usb" "type")

