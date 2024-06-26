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

# DEVICE CONFIG - MUX
export DC_MUX_WIDTH=$(PARSE_INI "$DEVICE_CONFIG" "mux" "width")
export DC_MUX_HEIGHT=$(PARSE_INI "$DEVICE_CONFIG" "mux" "height")
export DC_MUX_ITEM_COUNT=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_count")
export DC_MUX_ITEM_HEIGHT=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_height")
export DC_MUX_ITEM_PANEL=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_panel")
export DC_MUX_ITEM_PREV_LOW=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_prev_low")
export DC_MUX_ITEM_PREV_HIGH=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_prev_high")
export DC_MUX_ITEM_NEXT_LOW=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_next_low")
export DC_MUX_ITEM_NEXT_HIGH=$(PARSE_INI "$DEVICE_CONFIG" "mux" "item_next_high")

