#!/bin/sh

. /opt/muos/script/var/func.sh

REFRESH_HDMI() {
	printf "1" >"/tmp/hdmi_do_refresh"
	printf "%s" "$1" >"/tmp/hdmi_in_use"
}

SET_DISPLAY_PARAMS() {
	printf "4 "
	printf "%s " "$(GET_VAR "global" "settings/hdmi/resolution")"
	printf "%s " "$(GET_VAR "global" "settings/hdmi/space")"
	printf "%s " "$(GET_VAR "global" "settings/hdmi/depth")"
	printf "0x4 "
	printf "0x201 "
	printf "0 "
	printf "%s " "$(GET_VAR "global" "settings/hdmi/range")"
	printf "%s " "$(GET_VAR "global" "settings/hdmi/scan")"
	printf "8"
}

DISPLAY_WRITE disp0 switch1 "$(SET_DISPLAY_PARAMS)"

HDMI_SWITCH
REFRESH_HDMI 1
