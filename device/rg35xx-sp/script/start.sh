#!/bin/sh

. /opt/muos/script/var/func.sh

HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"

if [ "$(cat "$HALL_KEY")" = "0" ] && [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
	/opt/muos/script/system/halt.sh poweroff
fi

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

/opt/muos/device/current/script/module.sh &

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ] && [ "$(GET_VAR "global" "settings/hdmi/enabled")" -eq 1 ]; then
	/opt/muos/device/current/script/hdmi.sh start &
else
	SET_VAR "global" "settings/hdmi/enabled" 0
fi

(
	case "$(GET_VAR "global" "settings/advanced/brightness")" in
		"high")
			/opt/muos/device/current/input/combo/bright.sh "$(GET_VAR "device" "screen/bright")"
			;;
		"low")
			/opt/muos/device/current/input/combo/bright.sh 10
			;;
		*)
			PREV_BRIGHT=$(cat "/opt/muos/config/brightness.txt")
			/opt/muos/device/current/input/combo/bright.sh "$PREV_BRIGHT"
			;;
	esac
) &

GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature &

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
