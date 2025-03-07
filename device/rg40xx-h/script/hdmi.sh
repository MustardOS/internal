#!/bin/sh

. /opt/muos/script/var/func.sh

REFRESH_HDMI() {
	printf "1" >"/tmp/hdmi_do_refresh"
	printf "%s" "$1" >"/tmp/hdmi_in_use"
}

SET_AUDIO() {
	case "$1" in
		EXT) NID="$(GET_VAR "audio" "nid_external")" ;;
		INT) NID="$(GET_VAR "audio" "nid_internal")" ;;
		*)
			printf "Error: Invalid argument for audio: %s\n" "$1" >&2
			exit 1
			;;
	esac
	wpctl set-default "$NID"
	[ "$1" = "EXT" ] && wpctl set-volume "$NID" 100%
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

if [ "$(GET_VAR "global" "settings/hdmi/audio")" -eq 0 ]; then
	SET_AUDIO "EXT"
else
	SET_AUDIO "INT"
fi

DISPLAY_WRITE disp0 switch1 "$(SET_DISPLAY_PARAMS)"
sleep 0.5

HDMI_SWITCH
REFRESH_HDMI 1
