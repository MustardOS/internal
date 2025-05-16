#!/bin/sh

. /opt/muos/script/var/func.sh

FRONTEND stop

COMMAND=$(basename "$0")

END() {
	/opt/muos/bin/toybox sleep 3
	FRONTEND start picker
	exit 1
}

USAGE() {
	printf "Usage: %s <install> <bootlogo>\n" "$COMMAND"
	END
}

[ "$#" -lt 2 ] && USAGE

MODE="$1"
BOOTLOGO_ARG="$2"
BOOTLOGO_MOUNT="$(GET_VAR device storage/boot/mount)"

INSTALL() {
	# Ensure bootlogo.bmp image exists in the archive!
	if ! unzip -l "$BOOTLOGO_ARG" | grep -q 'bootlogo.bmp'; then
		printf "Error: 'bootlogo.bmp' not found in archive: %s\n" "$BOOTLOGO_ARG"
		END
	fi

	# Extract bootlogo.bmp from the archive to the mount point
	unzip -j "$BOOTLOGO_ARG" "bootlogo.bmp" -d "$BOOTLOGO_MOUNT" >/dev/null 2>&1
	if [ ! -f "$BOOTLOGO_MOUNT/bootlogo.bmp" ]; then
		printf "Error: Failed to extract 'bootlogo.bmp' to %s\n" "$BOOTLOGO_MOUNT"
		END
	fi

	DEVICE_NAME=$(GET_VAR device board/name)
	case "$DEVICE_NAME" in
		rg28* | rg35* | rg40*)
			TARGET_W=640
			TARGET_H=480
			;;
		rg34*)
			TARGET_W=720
			TARGET_H=480
			;;
		rgcube*)
			TARGET_W=720
			TARGET_H=720
			;;
		tui-brick)
			TARGET_W=1024
			TARGET_H=768
			;;
		tui-spoon)
			TARGET_W=1280
			TARGET_H=720
			;;
		*)
			printf "Warning: Unknown device resolution\n"
			END
			;;
	esac

	# Resize and pad to fit resolution while preserving aspect ratio
	convert "$BOOTLOGO_MOUNT/bootlogo.bmp" \
		-resize "${TARGET_W}x${TARGET_H}" \
		-background black -gravity center -extent "${TARGET_W}x${TARGET_H}" \
		"$BOOTLOGO_MOUNT/bootlogo.bmp"

	# Rotate for those annoying devices...
	case "$DEVICE_NAME" in
		rg28*) convert "$BOOTLOGO_MOUNT/bootlogo.bmp" -rotate 270 "$BOOTLOGO_MOUNT/bootlogo.bmp" ;;
	esac

	printf "Boot Logo Changed\n"
	sync

	FRONTEND start picker
}

case "$MODE" in
	install) INSTALL ;;
	*) USAGE ;;
esac
