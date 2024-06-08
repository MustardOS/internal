#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

FACTORY_RESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
CHARGER_ONLINE=$(cat /sys/class/power_supply/axp2202-usb/online)
if [ "$CHARGER_ONLINE" -eq 1 ] && [ "$FACTORY_RESET" -eq 0 ]; then
	ROM_DEV=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "dev")
	ROM_NUM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "num")
	ROM_MNT=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
	ROM_TYPE=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "type")
	mount -t "$ROM_TYPE" -o rw,utf8,noatime,nofail /dev/"$ROM_DEV"p"$ROM_NUM" /"$ROM_MNT"

	GOVERNOR=$(parse_ini "$DEVICE_CONFIG" "cpu" "governor")
	echo powersave > "$GOVERNOR"

	/opt/muos/extra/muxcharge

	umount /"$ROM_MNT"
fi

