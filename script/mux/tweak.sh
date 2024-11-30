#!/bin/sh

. /opt/muos/script/var/func.sh

# hotkey.sh will restart it
killall muhotkey

C_BRIGHT="$(cat /opt/muos/config/brightness.txt)"
if [ "$C_BRIGHT" -lt 1 ]; then
	/opt/muos/device/current/input/combo/bright.sh U
else
	/opt/muos/device/current/input/combo/bright.sh "$C_BRIGHT"
fi

GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature

/opt/muos/script/system/usb.sh &

# Set the device specific SDL Controller Map
/opt/muos/script/mux/sdl_map.sh &

# Retrieve the new and old BGM types
NEW_BGM_TYPE=$(GET_VAR "global" "settings/general/bgm")
OLD_BGM_TYPE=$(cat "/tmp/bgm_type" 2>/dev/null || echo 0)

# If the BGM type has changed, kill the current process (and of course wait for it to be killed) and start the new one!
if [ "$NEW_BGM_TYPE" -ne "$OLD_BGM_TYPE" ]; then
	killall "playbgm.sh" "mpv"
	while pgrep "playbgm.sh" >/dev/null || pgrep "mpv" >/dev/null; do sleep 0.1; done
	case $NEW_BGM_TYPE in
		0) ;;
		1) nohup /opt/muos/script/mux/playbgm.sh "/run/muos/storage/music" & ;;
		2) nohup /opt/muos/script/mux/playbgm.sh "/run/muos/storage/theme/active/music" & ;;
	esac
	printf "%s" "$NEW_BGM_TYPE" >"/tmp/bgm_type"
fi
