#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

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

FIRMWARE_DONE=$(parse_ini "$CONFIG" "boot" "firmware_done")
if [ "$FIRMWARE_DONE" -eq 0 ]; then
	LOGGER "FIRMWARE UPDATE" "Updating to required firmware for device!"

	FW_BOOT_OUT=$(parse_ini "$DEVICE_CONFIG" "firmware.boot" "out")
	FW_BOOT_SEEK=$(parse_ini "$DEVICE_CONFIG" "firmware.boot" "seek")

	FW_PACK_OUT=$(parse_ini "$DEVICE_CONFIG" "firmware.package" "out")
	FW_PACK_SEEK=$(parse_ini "$DEVICE_CONFIG" "firmware.package" "seek")

	dd if=/opt/muos/"$DEVICE"/firmware/boot.bin of=/dev/"$FW_BOOT_OUT" seek="$FW_BOOT_SEEK" conv=notrunc
	dd if=/opt/muos/"$DEVICE"/firmware/package.bin of=/dev/"$FW_PACK_OUT" seek="$FW_PACK_SEEK" conv=notrunc

	modify_ini "$CONFIG" "boot" "firmware_done" "1"
	reboot
fi

