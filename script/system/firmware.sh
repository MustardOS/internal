#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

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

TRANSFER_FIRMWARE() {
	PACKAGE="$1"
	FW_OUT="$2"
	FW_SEEK="$3"

	LOGGER "FIRMWARE UPDATE" "Updating '$PACKAGE' for device!"
	dd if=/opt/muos/device/"$DEVICE"/firmware/"$PACKAGE" of=/dev/"$FW_OUT" seek="$FW_SEEK" conv=notrunc,fsync
}

FIRMWARE_DONE=$(parse_ini "$CONFIG" "boot" "firmware_done")

BOOT_BIN_PATH="/opt/muos/device/$DEVICE/firmware/boot.bin"
PACK_BIN_PATH="/opt/muos/device/$DEVICE/firmware/package.bin"

if [ "$FIRMWARE_DONE" -eq 0 ]; then
	FW_DONE=0

        if [ -f "$BOOT_BIN_PATH" ]; then
        	FWO=$(parse_ini "$DEVICE_CONFIG" "firmware.boot" "out")
		FWS=$(parse_ini "$DEVICE_CONFIG" "firmware.boot" "seek")
		TRANSFER_FIRMWARE "boot.bin" "$FWO" "$FWS"
		FW_DONE=1
	fi
	
        if [ -f "$PACK_BIN_PATH" ]; then
        	FWO=$(parse_ini "$DEVICE_CONFIG" "firmware.package" "out")
		FWS=$(parse_ini "$DEVICE_CONFIG" "firmware.package" "seek")
		TRANSFER_FIRMWARE "package.bin" "$FWO" "$FWS"
		FW_DONE=1
	fi

	modify_ini "$CONFIG" "boot" "firmware_done" "1"
	
	if [ "$FW_DONE" -eq 1 ]; then
		reboot
	fi
fi

