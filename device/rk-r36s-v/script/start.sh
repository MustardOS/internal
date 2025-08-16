#!/bin/sh

. /opt/muos/script/var/func.sh

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
	/opt/muos/device/script/hdmi.sh
else
	LED_CONTROL_CHANGE

	/opt/muos/device/script/bright.sh R

	case "$(GET_VAR "config" "settings/advanced/brightness")" in
		"high")
			/opt/muos/device/script/bright.sh "$(GET_VAR "device" "screen/bright")"
			;;
		"medium")
			/opt/muos/device/script/bright.sh 90
			;;
		"low")
			/opt/muos/device/script/bright.sh 10
			;;
		*)
			/opt/muos/device/script/bright.sh "$(GET_VAR "config" "settings/general/brightness")"
			;;
	esac

	GET_VAR "config" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature
	SET_VAR "config" "settings/hdmi/scan" "0"
fi

if [ "$(GET_VAR "config" "settings/advanced/overdrive")" -eq 1 ]; then
	SET_VAR "device" "audio/max" "200"
else
	SET_VAR "device" "audio/max" "100"
fi

if [ "$(GET_VAR "config" "settings/advanced/thermal")" -eq 0 ]; then
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
