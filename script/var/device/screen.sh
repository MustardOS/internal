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

# DEVICE CONFIG - SCREEN
export DC_SCR_DEVICE=$(PARSE_INI "$DEVICE_CONFIG" "screen" "device")
export DC_SCR_HDMI=$(PARSE_INI "$DEVICE_CONFIG" "screen" "hdmi")
export DC_SCR_BRIGHT=$(PARSE_INI "$DEVICE_CONFIG" "screen" "bright")
export DC_SCR_BUFFER=$(PARSE_INI "$DEVICE_CONFIG" "screen" "buffer")
export DC_SCR_WIDTH=$(PARSE_INI "$DEVICE_CONFIG" "screen" "width")
export DC_SCR_HEIGHT=$(PARSE_INI "$DEVICE_CONFIG" "screen" "height")
export DC_SCR_ROTATE=$(PARSE_INI "$DEVICE_CONFIG" "screen" "rotate")
export DC_SCR_WAIT=$(PARSE_INI "$DEVICE_CONFIG" "screen" "wait")

