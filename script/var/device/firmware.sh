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

# DEVICE CONFIG - FIRMWARE - BOOT
export DC_FIR_BOOT_OUT=$(PARSE_INI "$DEVICE_CONFIG" "firmware.boot" "out")
export DC_FIR_BOOT_SEEK=$(PARSE_INI "$DEVICE_CONFIG" "firmware.boot" "seek")

# DEVICE CONFIG - FIRMWARE - PACKAGE
export DC_FIR_PACKAGE_OUT=$(PARSE_INI "$DEVICE_CONFIG" "firmware.package" "out")
export DC_FIR_PACKAGE_SEEK=$(PARSE_INI "$DEVICE_CONFIG" "firmware.package" "seek")

