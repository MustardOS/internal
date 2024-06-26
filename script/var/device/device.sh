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

# DEVICE CONFIG - DEVICE
export DC_DEV_NAME=$(PARSE_INI "$DEVICE_CONFIG" "device" "name")
export DC_DEV_HOME=$(PARSE_INI "$DEVICE_CONFIG" "device" "home")
export DC_DEV_NETWORK=$(PARSE_INI "$DEVICE_CONFIG" "device" "network")
export DC_DEV_BLUETOOTH=$(PARSE_INI "$DEVICE_CONFIG" "device" "bluetooth")
export DC_DEV_PORTMASTER=$(PARSE_INI "$DEVICE_CONFIG" "device" "portmaster")
export DC_DEV_LID=$(PARSE_INI "$DEVICE_CONFIG" "device" "lid")
export DC_DEV_HDMI=$(PARSE_INI "$DEVICE_CONFIG" "device" "hdmi")
export DC_DEV_EVENT=$(PARSE_INI "$DEVICE_CONFIG" "device" "event")
export DC_DEV_DEBUGFS=$(PARSE_INI "$DEVICE_CONFIG" "device" "debugfs")
export DC_DEV_RTC=$(PARSE_INI "$DEVICE_CONFIG" "device" "rtc")
export DC_DEV_LED=$(PARSE_INI "$DEVICE_CONFIG" "device" "led")

