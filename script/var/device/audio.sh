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

# DEVICE CONFIG - AUDIO
export DC_SND_CONTROL=$(PARSE_INI "$DEVICE_CONFIG" "audio" "control")
export DC_SND_MIN=$(PARSE_INI "$DEVICE_CONFIG" "audio" "min")
export DC_SND_MAX=$(PARSE_INI "$DEVICE_CONFIG" "audio" "max")

