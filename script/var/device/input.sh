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

# DEVICE CONFIG - INPUT
export DC_INP_EVENT_0=$(PARSE_INI "$DEVICE_CONFIG" "input" "ev0")
export DC_INP_EVENT_1=$(PARSE_INI "$DEVICE_CONFIG" "input" "ev1")
export DC_INP_AXIS_MIN=$(PARSE_INI "$DEVICE_CONFIG" "input" "axis_min")
export DC_INP_AXIS_MAX=$(PARSE_INI "$DEVICE_CONFIG" "input" "axis_max")

# DEVICE CONFIG - RAW INPUT - DPAD
export DC_INP_RAW_DPAD_UP=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.dpad" "dp_up")
export DC_INP_RAW_DPAD_DOWN=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.dpad" "dp_down")
export DC_INP_RAW_DPAD_LEFT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.dpad" "dp_left")
export DC_INP_RAW_DPAD_RIGHT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.dpad" "dp_right")

# DEVICE CONFIG - RAW INPUT - ANALOG - LEFT
export DC_INP_RAW_ANALOG_LEFT_UP=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.left" "an_left_up")
export DC_INP_RAW_ANALOG_LEFT_DOWN=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.left" "an_left_down")
export DC_INP_RAW_ANALOG_LEFT_LEFT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.left" "an_left_left")
export DC_INP_RAW_ANALOG_LEFT_RIGHT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.left" "an_left_right")
export DC_INP_RAW_ANALOG_LEFT_CLICK=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.left" "an_left_click")

# DEVICE CONFIG - RAW INPUT - ANALOG - RIGHT
export DC_INP_RAW_ANALOG_RIGHT_UP=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.right" "an_right_up")
export DC_INP_RAW_ANALOG_RIGHT_DOWN=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.right" "an_right_down")
export DC_INP_RAW_ANALOG_RIGHT_LEFT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.right" "an_right_left")
export DC_INP_RAW_ANALOG_RIGHT_RIGHT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.right" "an_right_right")
export DC_INP_RAW_ANALOG_RIGHT_CLICK=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.analog.right" "an_right_click")

# DEVICE CONFIG - RAW INPUT - BUTTON
export DC_INP_RAW_BUTTON_A=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "a")
export DC_INP_RAW_BUTTON_B=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "b")
export DC_INP_RAW_BUTTON_C=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "c")
export DC_INP_RAW_BUTTON_X=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "x")
export DC_INP_RAW_BUTTON_Y=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "y")
export DC_INP_RAW_BUTTON_Z=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "z")
export DC_INP_RAW_BUTTON_L1=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "l1")
export DC_INP_RAW_BUTTON_L2=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "l2")
export DC_INP_RAW_BUTTON_L3=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "l3")
export DC_INP_RAW_BUTTON_R1=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "r1")
export DC_INP_RAW_BUTTON_R2=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "r2")
export DC_INP_RAW_BUTTON_R3=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "r3")
export DC_INP_RAW_BUTTON_MENU_SHORT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "menu_short")
export DC_INP_RAW_BUTTON_MENU_LONG=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "menu_long")
export DC_INP_RAW_BUTTON_SELECT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "select")
export DC_INP_RAW_BUTTON_START=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "start")
export DC_INP_RAW_BUTTON_POWER_SHORT=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "power_short")
export DC_INP_RAW_BUTTON_POWER_LONG=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "power_long")
export DC_INP_RAW_BUTTON_VOL_UP=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "vol_up")
export DC_INP_RAW_BUTTON_VOL_DOWN=$(PARSE_INI "$DEVICE_CONFIG" "raw_input.button" "vol_down")

