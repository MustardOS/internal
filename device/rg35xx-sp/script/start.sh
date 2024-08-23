#!/bin/sh

. /opt/muos/script/var/func.sh

HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"

if [ "$(cat "$HALL_KEY")" = "0" ] && [ "$(cat "$(GET_VAR "device" "battery/charger")")" -eq 0 ]; then
	/opt/muos/script/system/halt.sh poweroff
fi

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

insmod /lib/modules/mali_kbase.ko
insmod /lib/modules/squashfs.ko

GET_VAR "device" "cpu/default" >"$(GET_VAR "device" "cpu/governor")"
GET_VAR "device" "cpu/sampling_rate_default" >"$(GET_VAR "device" "cpu/sampling_rate")"
GET_VAR "device" "cpu/up_threshold_default" >"$(GET_VAR "device" "cpu/up_threshold")"
GET_VAR "device" "cpu/sampling_down_factor_default" >"$(GET_VAR "device" "cpu/sampling_down_factor")"
GET_VAR "device" "cpu/io_is_busy_default" >"$(GET_VAR "device" "cpu/io_is_busy")"

if mount -t "$(GET_VAR "device" "storage/boot/type")" -o rw,utf8,noatime,nofail \
	/dev/"$(GET_VAR "device" "storage/boot/dev")$(GET_VAR "device" "storage/boot/sep")$(GET_VAR "device" "storage/boot/num")" \
	"$(GET_VAR "device" "storage/boot/mount")"; then
	SET_VAR "device" "storage/boot/active" "1"
fi

if mount -t "$(GET_VAR "device" "storage/rom/type")" -o rw,utf8,noatime,nofail \
	/dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" \
	"$(GET_VAR "device" "storage/rom/mount")"; then
	SET_VAR "device" "storage/rom/active" "1"
fi

# Bind mount storage preference to /run/muos
/opt/muos/script/var/init/storage.sh

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ] && [ "$(GET_VAR "global" "settings/general/hdmi")" -gt -1 ]; then
	/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/hdmi_start.sh &
fi

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

GET_VAR "global" "settings/general/colour" >/sys/class/disp/disp/attr/color_temperature

if [ "$(GET_VAR "global" "settings/advanced/thermal")" -eq 1 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		if [ -e "$ZONE/mode" ]; then
			echo "disabled" >"ZONE/mode"
		fi
	done
fi

echo noop >/sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:59b4/block/mmcblk0/queue/scheduler
echo on >/sys/devices/platform/soc/sdc0/mmc_host/mmc0/power/control

if [ "$(GET_VAR "global" "settings/advanced/android")" -eq 1 ]; then
	/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/adb.sh &
fi

/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/control.sh &
/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/input.sh &
