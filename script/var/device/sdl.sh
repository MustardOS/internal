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

# DEVICE CONFIG - SDL
export DC_SDL_SCALER=$(PARSE_INI "$DEVICE_CONFIG" "sdl" "scaler")
export DC_SDL_ROTATION=$(PARSE_INI "$DEVICE_CONFIG" "sdl" "rotation")
export DC_SDL_BLITTER_DISABLED=$(PARSE_INI "$DEVICE_CONFIG" "sdl" "blitter_disabled")

