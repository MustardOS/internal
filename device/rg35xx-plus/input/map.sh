#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

INPUT_UP="$(parse_ini "$DEVICE_CONFIG" "raw_input.dpad" "dp_up")"
COUNT_UP=0
STATE_UP=0
PRESS_UP="*code $INPUT_UP * value -1*"
RELEASE_UP="*code $INPUT_UP * value 0*"

INPUT_DOWN="$(parse_ini "$DEVICE_CONFIG" "raw_input.dpad" "dp_down")"
COUNT_DOWN=0
STATE_DOWN=0
PRESS_DOWN="*code $INPUT_DOWN * value 1*"
RELEASE_DOWN="*code $INPUT_DOWN * value 0*"

INPUT_LEFT="$(parse_ini "$DEVICE_CONFIG" "raw_input.dpad" "dp_left")"
COUNT_LEFT=0
STATE_LEFT=0
PRESS_LEFT="*code $INPUT_LEFT * value -1*"
RELEASE_LEFT="*code $INPUT_LEFT * value 0*"

INPUT_RIGHT="$(parse_ini "$DEVICE_CONFIG" "raw_input.dpad" "dp_right")"
COUNT_RIGHT=0
STATE_RIGHT=0
PRESS_RIGHT="*code $INPUT_RIGHT * value 1*"
RELEASE_RIGHT="*code $INPUT_RIGHT * value 0*"

INPUT_A="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "a")"
COUNT_A=0
STATE_A=0
PRESS_A="*code 304 * value 1*"
RELEASE_A="*code 304 * value 0*"

INPUT_B="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "b")"
COUNT_B=0
STATE_B=0
PRESS_B="*code 305 * value 1*"
RELEASE_B="*code 305 * value 0*"

INPUT_C="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "c")"
COUNT_C=0
STATE_C=0
PRESS_C="*code 305 * value 1*"
RELEASE_C="*code 305 * value 0*"

INPUT_X="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "x")"
COUNT_X=0
STATE_X=0
PRESS_X="*code $COUNT_X * value 1*"
RELEASE_X="*code $COUNT_X * value 0*"

INPUT_Y="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "y")"
COUNT_Y=0
STATE_Y=0
PRESS_Y="*code $INPUT_Y * value 1*"
RELEASE_Y="*code $INPUT_Y * value 0*"

INPUT_Z="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "z")"
COUNT_Z=0
STATE_Z=0
PRESS_Z="*code $INPUT_Z * value 1*"
RELEASE_Z="*code $INPUT_Z * value 0*"

INPUT_SELECT="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "select")"
COUNT_SELECT=0
STATE_SELECT=0
PRESS_SELECT="*code $INPUT_SELECT * value 1*"
RELEASE_SELECT="*code $INPUT_SELECT * value 0*"

INPUT_START="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "start")"
COUNT_START=0
STATE_START=0
PRESS_START="*code $INPUT_START * value 1*"
RELEASE_START="*code $INPUT_START * value 0*"

INPUT_MENU_SHORT="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "menu_short")"
COUNT_MENU_SHORT=0
STATE_MENU_SHORT=0
PRESS_MENU_SHORT="*code $INPUT_MENU_SHORT * value 1*"
RELEASE_MENU_SHORT="*code $INPUT_MENU_SHORT * value 0*"

INPUT_MENU_LONG="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "menu_long")"
COUNT_MENU_LONG=0
STATE_MENU_LONG=0
PRESS_MENU_LONG="*code $INPUT_MENU_LONG * value 1*"
RELEASE_MENU_LONG="*code $INPUT_MENU_LONG * value 0*"

INPUT_L1="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "l1")"
COUNT_L1=0
STATE_L1=0
PRESS_L1="*code $INPUT_L1 * value 1*"
RELEASE_L1="*code $INPUT_L1 * value 0*"

INPUT_L2="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "l2")"
COUNT_L2=0
STATE_L2=0
PRESS_L2="*code $INPUT_L2 * value 1*"
RELEASE_L2="*code $INPUT_L2 * value 0*"

INPUT_L3="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "l3")"
COUNT_L3=0
STATE_L3=0
PRESS_L3="*code $INPUT_L3 * value 1*"
RELEASE_L3="*code $INPUT_L3 * value 0*"

INPUT_R1="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "r1")"
COUNT_R1=0
STATE_R1=0
PRESS_R1="*code $INPUT_R1 * value 1*"
RELEASE_R1="*code $INPUT_R1 * value 0*"

INPUT_R2="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "r2")"
COUNT_R2=0
STATE_R2=0
PRESS_R2="*code $INPUT_R2 * value 1*"
RELEASE_R2="*code $INPUT_R2 * value 0*"

INPUT_R3="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "r3")"
COUNT_R3=0
STATE_R3=0
PRESS_R3="*code $INPUT_R3 * value 1*"
RELEASE_R3="*code $INPUT_R3 * value 0*"

INPUT_VOL_UP="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "vol_up")"
COUNT_VOL_UP=0
STATE_VOL_UP=0
PRESS_VOL_UP="*code $INPUT_VOL_UP * value 1*"
RELEASE_VOL_UP="*code $INPUT_VOL_UP * value 0*"

INPUT_VOL_DOWN="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "vol_down")"
COUNT_VOL_DOWN=0
STATE_VOL_DOWN=0
PRESS_VOL_DOWN="*code $INPUT_VOL_DOWN * value 1*"
RELEASE_VOL_DOWN="*code $INPUT_VOL_DOWN * value 0*"

INPUT_POWER_SHORT="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "power_short")"
COUNT_POWER_SHORT=0
STATE_POWER_SHORT=0
PRESS_POWER_SHORT="*code $INPUT_POWER_SHORT * value 1*"
RELEASE_POWER_SHORT="*code $INPUT_POWER_SHORT * value 0*"

INPUT_POWER_LONG="$(parse_ini "$DEVICE_CONFIG" "raw_input.button" "power_long")"
COUNT_POWER_LONG=0
STATE_POWER_LONG=0
PRESS_POWER_LONG="*code $INPUT_POWER_LONG * value 2*"
RELEASE_POWER_LONG="*code $INPUT_POWER_LONG * value 0*"

