#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/battery.sh
. /opt/muos/script/var/device/cpu.sh
. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/screen.sh
. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/setting_advanced.sh
. /opt/muos/script/var/global/setting_general.sh

HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"

if [ "$(cat "$HALL_KEY")" = "0" ] && [ "$(cat "$DC_BAT_CHARGER")" -eq 0 ]; then
	/opt/muos/bin/mushutdown
fi

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

insmod /lib/modules/mali_kbase.ko &
insmod /lib/modules/squashfs.ko &

echo "$DC_CPU_DEFAULT" >"$DC_CPU_GOVERNOR"
echo "$DC_CPU_SAMPLING_RATE_DEFAULT" > "$DC_CPU_SAMPLING_RATE"
echo "$DC_CPU_UP_THRESHOLD_DEFAULT" > "$DC_CPU_UP_THRESHOLD"
echo "$DC_CPU_SAMPLING_DOWN_FACTOR_DEFAULT" > "$DC_CPU_SAMPLING_DOWN_FACTOR"
echo "$DC_CPU_IO_IS_BUSY_DEFAULT" > "$DC_CPU_IO_IS_BUSY"

mount -t "$DC_STO_BOOT_TYPE" -o rw,utf8,noatime,nofail /dev/"$DC_STO_BOOT_DEV"p"$DC_STO_BOOT_NUM" "$DC_STO_BOOT_MOUNT"
mount -t "$DC_STO_ROM_TYPE" -o rw,utf8,noatime,nofail /dev/"$DC_STO_ROM_DEV"p"$DC_STO_ROM_NUM" "$DC_STO_ROM_MOUNT"

LOGGER "$0" "BOOTING" "Running dotclean"
/opt/muos/script/system/dotclean.sh &

if [ "$DC_DEV_DEBUGFS" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$DC_DEV_HDMI" -eq 1 ] && [ "$GC_GEN_HDMI" -gt -1 ]; then
	/opt/muos/device/"$DEVICE_TYPE"/script/hdmi_start.sh &
fi

case "$GC_ADV_BRIGHTNESS" in
	"high")
		/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh "$DC_SCR_BRIGHT"
		;;
	"low")
		/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh 10
		;;
	*)
		PREV_BRIGHT=$(cat "/opt/muos/config/brightness.txt")
		/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh "$PREV_BRIGHT"
		;;
esac

echo "$GC_GEN_COLOUR" >/sys/class/disp/disp/attr/color_temperature

if [ "$GC_ADV_THERMAL" -eq 1 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		if [ -e "$ZONE/mode" ]; then
			echo "disabled" >"ZONE/mode"
		fi
	done
fi

echo noop >/sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:59b4/block/mmcblk0/queue/scheduler
echo on >/sys/devices/platform/soc/sdc0/mmc_host/mmc0/power/control

/opt/muos/device/"$DEVICE_TYPE"/script/control.sh
/opt/muos/device/"$DEVICE_TYPE"/input/input.sh
