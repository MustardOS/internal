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

# DEVICE CONFIG - BATTERY
export DC_BAT_CAPACITY=$(PARSE_INI "$DEVICE_CONFIG" "battery" "capacity")
export DC_BAT_HEALTH=$(PARSE_INI "$DEVICE_CONFIG" "battery" "health")
export DC_BAT_VOLTAGE=$(PARSE_INI "$DEVICE_CONFIG" "battery" "voltage")
export DC_BAT_CHARGER=$(PARSE_INI "$DEVICE_CONFIG" "battery" "charger")

