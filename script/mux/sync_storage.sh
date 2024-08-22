#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <type>"
	exit 1
fi

. /opt/muos/script/var/func.sh

RUN_SYNC() {
	case "$1" in
		0)
			MOUNT="$(GET_VAR "device" "storage/rom/mount")"
			;;
		1)
			MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
			;;
		2)
			MOUNT="$(GET_VAR "device" "storage/usb/mount")"
			;;
		*)
			printf "Storage not valid! Skipping...\n"
			return
			;;
	esac

	if [ "$MOUNT" != "$(GET_VAR "device" "storage/rom/mount")" ]; then
		if [ ! -d "$MOUNT/$2" ]; then
			mkdir -p "$MOUNT/$2"
		fi
		rsync -a "$(GET_VAR "device" "storage/rom/mount")/$2" "$MOUNT/$2"
	fi
}

case "$1" in
	theme)
		RUN_SYNC "$(GET_VAR "global" "storage/theme")" "MUOS/theme/"
		;;
	*) ;;
esac
