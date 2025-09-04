#!/bin/sh

. /opt/muos/script/var/func.sh

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
	/opt/muos/script/device/hdmi.sh
else
	/opt/muos/script/device/bright.sh R

	case "$(GET_VAR "config" "settings/advanced/brightness")" in
		"high")
			/opt/muos/script/device/bright.sh "$(GET_VAR "device" "screen/bright")"
			;;
		"medium")
			/opt/muos/script/device/bright.sh 90
			;;
		"low")
			/opt/muos/script/device/bright.sh 35
			;;
		*)
			/opt/muos/script/device/bright.sh "$(GET_VAR "config" "settings/general/brightness")"
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
		[ -e "$ZONE/mode" ] && echo "disabled" >"$ZONE/mode"
	done
fi

# Add device specific Retroarch Binary
RA_DIR="/opt/muos/share/emulator/retroarch"
RA_BIN="$RA_DIR/retroarch-rg"
RA_MD5="$RA_DIR/retroarch-rg.md5"
RA_TGT="/usr/bin/retroarch"

if [ -f "$RA_TGT" ]; then
	CURRENT_MD5=$(md5sum "$RA_TGT" | awk '{ print $1 }')
	if [ "$CURRENT_MD5" != "$RA_MD5" ]; then
		cp -f "$RA_BIN" "$RA_TGT"
		chmod +x "$RA_TGT"
	fi
else
	cp -f "$RA_BIN" "$RA_TGT"
	chmod +x "$RA_TGT"
fi
