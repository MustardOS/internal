#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - BOOT
: "${GC_BOO_FACTORY_RESET:=0}"
: "${GC_BOO_DEVICE_SETUP:=0}"
: "${GC_BOO_CLOCK_SETUP:=0}"
: "${GC_BOO_FIRMWARE_DONE:=1}"
export GC_BOO_FACTORY_RESET=$(PARSE_INI "$GLOBAL_CONFIG" "boot" "factory_reset")
export GC_BOO_DEVICE_SETUP=$(PARSE_INI "$GLOBAL_CONFIG" "boot" "device_setup")
export GC_BOO_CLOCK_SETUP=$(PARSE_INI "$GLOBAL_CONFIG" "boot" "clock_setup")
export GC_BOO_FIRMWARE_DONE=$(PARSE_INI "$GLOBAL_CONFIG" "boot" "firmware_done")

