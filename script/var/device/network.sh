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

# DEVICE CONFIG - NETWORK
export DC_NET_MODULE=$(PARSE_INI "$DEVICE_CONFIG" "network" "module")
export DC_NET_NAME=$(PARSE_INI "$DEVICE_CONFIG" "network" "name")
export DC_NET_TYPE=$(PARSE_INI "$DEVICE_CONFIG" "network" "type")
export DC_NET_INTERFACE=$(PARSE_INI "$DEVICE_CONFIG" "network" "iface")

