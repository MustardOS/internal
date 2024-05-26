#!/bin/sh

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

LOGGER() {
VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	_TITLE=$1
	_MESSAGE=$2
	_FORM=$(cat <<EOF
$_TITLE

$_MESSAGE
EOF
	)
	/opt/muos/extra/muxstart "$_FORM" && sleep 0.5
	echo "=== ${CURRENT_DATE} === $_MESSAGE" >> "$MUOSBOOT_LOG"
fi
}

FACTORY_RESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORY_RESET" -eq 1 ]; then
	MUOSBOOT_LOG="/tmp/muosboot__${CURRENT_DATE}.log"
else
	MUOSBOOT_LOG="/mnt/mmc/MUOS/log/boot/muosboot__${CURRENT_DATE}.log"
fi

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

FACTORY_RESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
CHARGER_ONLINE=$(cat /sys/class/power_supply/axp2202-usb/online)
if [ "$CHARGER_ONLINE" -eq 1 ] && [ "$FACTORY_RESET" -eq 0 ]; then
	echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
	/opt/muos/extra/muxcharge
fi

insmod /lib/modules/mali_kbase.ko &
insmod /lib/modules/squashfs.ko &

GOVERNOR=$(parse_ini "$DEVICE_CONFIG" "cpu" "governor")
echo performance > "$GOVERNOR"

BOOT_DEV=$(parse_ini "$DEVICE_CONFIG" "storage.boot" "dev")
BOOT_NUM=$(parse_ini "$DEVICE_CONFIG" "storage.boot" "num")
BOOT_MNT=$(parse_ini "$DEVICE_CONFIG" "storage.boot" "mount")
BOOT_TYPE=$(parse_ini "$DEVICE_CONFIG" "storage.boot" "type")
mount -t "$BOOT_TYPE" -o rw,utf8,noatime,nofail /dev/"$BOOT_DEV"p"$BOOT_NUM" "$BOOT_MNT"

ROM_DEV=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "dev")
ROM_NUM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "num")
ROM_MNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
ROM_TYPE=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "type")
mount -t "$ROM_TYPE" -o rw,utf8,noatime,nofail /dev/"$ROM_DEV"p"$ROM_NUM" "$ROM_MNT"

USE_DEBUGFS=$(parse_ini "$DEVICE_CONFIG" "partition" "debug")
if [ "$USE_DEBUGFS" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo "$COLOUR" > /sys/class/disp/disp/attr/color_temperature

THERMAL=$(parse_ini "$CONFIG" "settings.advanced" "thermal")
if [ "$THERMAL" -eq 1 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		if [ -e "$ZONE/mode" ]; then
			echo "disabled" > "ZONE/mode"
		fi
	done
fi

echo noop > /sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:59b4/block/mmcblk0/queue/scheduler
echo on > /sys/devices/platform/soc/sdc0/mmc_host/mmc0/power/control

/opt/muos/device/"$DEVICE"/script/control.sh

