#!/bin/sh

. /opt/muos/script/var/func.sh

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

/opt/muos/device/current/input/audio.sh I
/opt/muos/device/current/input/bright.sh I

if [ "$(GET_VAR "global" "boot/device_mode")" -eq 1 ]; then
	/opt/muos/device/current/script/hdmi.sh start
else
	case "$(GET_VAR "global" "settings/advanced/brightness")" in
		"high")
			/opt/muos/device/current/input/bright.sh "$(GET_VAR "device" "screen/bright")"
			;;
		"medium")
			/opt/muos/device/current/input/bright.sh 90
			;;
		"low")
			/opt/muos/device/current/input/bright.sh 10
			;;
		*)
			PREV_BRIGHT=$(cat "/opt/muos/config/brightness.txt")
			/opt/muos/device/current/input/bright.sh "$PREV_BRIGHT"
			;;
	esac

	GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature
	SET_VAR "global" "settings/general/theme_resolution" "0"
	SET_VAR "global" "settings/hdmi/scan" "0"
fi

if [ "$(GET_VAR "global" "settings/advanced/overdrive")" -eq 1 ]; then
	SET_VAR "device" "audio/max" "200"
else
	SET_VAR "device" "audio/max" "100"
fi

if [ "$(GET_VAR "global" "settings/advanced/thermal")" -eq 1 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		if [ -e "$ZONE/mode" ]; then
			echo "disabled" >"$ZONE/mode"
		fi
	done
fi

# Add device specific Retroarch Binary
RA_BIN="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/retroarch/retroarch-rg"
RA_MD5="$(cat "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/retroarch/retroarch-rg.md5")"
RA_TARGET="/usr/bin/retroarch"

if [ -f "$RA_TARGET" ]; then
	CURRENT_MD5=$(md5sum "$RA_TARGET" | awk '{ print $1 }')
	if [ "$CURRENT_MD5" != "$RA_MD5" ]; then
		cp -f "$RA_BIN" "$RA_TARGET"
		chmod +x "$RA_TARGET"
	fi
else
	cp -f "$RA_BIN" "$RA_TARGET"
	chmod +x "$RA_TARGET"
fi
