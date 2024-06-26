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

# DEVICE CONFIG - CPU
export DC_CPU_DEFAULT=$(PARSE_INI "$DEVICE_CONFIG" "cpu" "default")
export DC_CPU_GOVERNOR=$(PARSE_INI "$DEVICE_CONFIG" "cpu" "governor")
export DC_CPU_SCALER=$(PARSE_INI "$DEVICE_CONFIG" "cpu" "scaler")

