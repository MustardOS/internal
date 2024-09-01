#!/bin/sh

. /opt/muos/script/var/func.sh

COUNT_UP=0
STATE_UP=0
PRESS_UP="*code $(GET_VAR "device" "input/code/dpad/up") * value -1*"
RELEASE_UP="*code $(GET_VAR "device" "input/code/dpad/up") * value 0*"

COUNT_DOWN=0
STATE_DOWN=0
PRESS_DOWN="*code $(GET_VAR "device" "input/code/dpad/down") * value 1*"
RELEASE_DOWN="*code $(GET_VAR "device" "input/code/dpad/down") * value 0*"

COUNT_LEFT=0
STATE_LEFT=0
PRESS_LEFT="*code $(GET_VAR "device" "input/code/dpad/left") * value -1*"
RELEASE_LEFT="*code $(GET_VAR "device" "input/code/dpad/left") * value 0*"

COUNT_RIGHT=0
STATE_RIGHT=0
PRESS_RIGHT="*code $(GET_VAR "device" "input/code/dpad/right") * value 1*"
RELEASE_RIGHT="*code $(GET_VAR "device" "input/code/dpad/right") * value 0*"

COUNT_A=0
STATE_A=0
PRESS_A="*code $(GET_VAR "device" "input/code/button/a") * value 1*"
RELEASE_A="*code $(GET_VAR "device" "input/code/button/a") * value 0*"

COUNT_B=0
STATE_B=0
PRESS_B="*code $(GET_VAR "device" "input/code/button/b") * value 1*"
RELEASE_B="*code $(GET_VAR "device" "input/code/button/b") * value 0*"

COUNT_C=0
STATE_C=0
PRESS_C="*code $(GET_VAR "device" "input/code/button/c") * value 1*"
RELEASE_C="*code $(GET_VAR "device" "input/code/button/c") * value 0*"

COUNT_X=0
STATE_X=0
PRESS_X="*code $(GET_VAR "device" "input/code/button/x") * value 1*"
RELEASE_X="*code $(GET_VAR "device" "input/code/button/x") * value 0*"

COUNT_Y=0
STATE_Y=0
PRESS_Y="*code $(GET_VAR "device" "input/code/button/y") * value 1*"
RELEASE_Y="*code $(GET_VAR "device" "input/code/button/y") * value 0*"

COUNT_Z=0
STATE_Z=0
PRESS_Z="*code $(GET_VAR "device" "input/code/button/z") * value 1*"
RELEASE_Z="*code $(GET_VAR "device" "input/code/button/z") * value 0*"

COUNT_SELECT=0
STATE_SELECT=0
PRESS_SELECT="*code $(GET_VAR "device" "input/code/button/select") * value 1*"
RELEASE_SELECT="*code $(GET_VAR "device" "input/code/button/select") * value 0*"

COUNT_START=0
STATE_START=0
PRESS_START="*code $(GET_VAR "device" "input/code/button/start") * value 1*"
RELEASE_START="*code $(GET_VAR "device" "input/code/button/start") * value 0*"

COUNT_MENU_SHORT=0
STATE_MENU_SHORT=0
PRESS_MENU_SHORT="*code $(GET_VAR "device" "input/code/button/menu_short") * value 1*"
RELEASE_MENU_SHORT="*code $(GET_VAR "device" "input/code/button/menu_short") * value 0*"

COUNT_MENU_LONG=0
STATE_MENU_LONG=0
PRESS_MENU_LONG="*code $(GET_VAR "device" "input/code/button/menu_long") * value 1*"
RELEASE_MENU_LONG="*code $(GET_VAR "device" "input/code/button/menu_long") * value 0*"

COUNT_L1=0
STATE_L1=0
PRESS_L1="*code $(GET_VAR "device" "input/code/button/l1") * value 1*"
RELEASE_L1="*code $(GET_VAR "device" "input/code/button/l1") * value 0*"

COUNT_L2=0
STATE_L2=0
PRESS_L2="*code $(GET_VAR "device" "input/code/button/l2") * value 1*"
RELEASE_L2="*code $(GET_VAR "device" "input/code/button/l2") * value 0*"

COUNT_L3=0
STATE_L3=0
PRESS_L3="*code $(GET_VAR "device" "input/code/button/l3") * value 1*"
RELEASE_L3="*code $(GET_VAR "device" "input/code/button/l3") * value 0*"

COUNT_R1=0
STATE_R1=0
PRESS_R1="*code $(GET_VAR "device" "input/code/button/r1") * value 1*"
RELEASE_R1="*code $(GET_VAR "device" "input/code/button/r1") * value 0*"

COUNT_R2=0
STATE_R2=0
PRESS_R2="*code $(GET_VAR "device" "input/code/button/r2") * value 1*"
RELEASE_R2="*code $(GET_VAR "device" "input/code/button/r2") * value 0*"

COUNT_R3=0
STATE_R3=0
PRESS_R3="*code $(GET_VAR "device" "input/code/button/r3") * value 1*"
RELEASE_R3="*code $(GET_VAR "device" "input/code/button/r3") * value 0*"

COUNT_VOL_UP=0
STATE_VOL_UP=0
PRESS_VOL_UP="*code $(GET_VAR "device" "input/code/button/vol_up") * value 1*"
RELEASE_VOL_UP="*code $(GET_VAR "device" "input/code/button/vol_up") * value 0*"

COUNT_VOL_DOWN=0
STATE_VOL_DOWN=0
PRESS_VOL_DOWN="*code $(GET_VAR "device" "input/code/button/vol_down") * value 1*"
RELEASE_VOL_DOWN="*code $(GET_VAR "device" "input/code/button/vol_down") * value 0*"

COUNT_POWER_SHORT=0
STATE_POWER_SHORT=0
PRESS_POWER_SHORT="*code $(GET_VAR "device" "input/code/button/power_short") * value 1*"
RELEASE_POWER_SHORT="*code $(GET_VAR "device" "input/code/button/power_short") * value 0*"

COUNT_POWER_LONG=0
STATE_POWER_LONG=0
PRESS_POWER_LONG="*code $(GET_VAR "device" "input/code/button/power_long") * value 2*"
RELEASE_POWER_LONG="*code $(GET_VAR "device" "input/code/button/power_long") * value 0*"
