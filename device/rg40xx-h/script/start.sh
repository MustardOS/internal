#!/bin/sh

. /opt/muos/script/var/func.sh

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/module.sh &

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ] && [ "$(GET_VAR "global" "settings/general/hdmi")" -gt -1 ]; then
	/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/hdmi_start.sh &
fi

(
	case "$(GET_VAR "global" "settings/advanced/brightness")" in
		"high")
			/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh "$(GET_VAR "device" "screen/bright")"
			;;
		"low")
			/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh 10
			;;
		*)
			PREV_BRIGHT=$(cat "/opt/muos/config/brightness.txt")
			/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh "$PREV_BRIGHT"
			;;
	esac
) &

GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature &

if [ "$(GET_VAR "global" "settings/advanced/thermal")" -eq 1 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		if [ -e "$ZONE/mode" ]; then
			echo "disabled" >"$ZONE/mode"
		fi
	done
fi

BLK_ID4=""
for D in /sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:*; do
	[ -d "$D" ] && BLK_ID4="${D##*/}" && break
done
echo noop >/sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:"$BLK_ID4"/block/mmcblk0/queue/scheduler
echo on >/sys/devices/platform/soc/sdc0/mmc_host/mmc0/power/control

# Switch GPU power policy
echo always_on >/sys/devices/platform/gpu/power_policy &

if [ "$(GET_VAR "global" "settings/advanced/android")" -eq 1 ]; then
	/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/adb.sh &
fi

/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/control.sh &
/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/input.sh &
