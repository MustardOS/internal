#!/bin/sh

. /opt/muos/script/var/log.sh

LOGO_ROTATE=270

LOGO_ENTRIES="logo.bmp logo_kernel.bmp"
LOGO_TMP="/tmp/vita_bootlogo_$$.bmp"

BOOT_MOUNT=$(GET_VAR "device" "storage/boot/mount")
BACKUP="$BOOT_MOUNT/resource.orig.img"

RESOURCE_DEVICE() {
	ROOT_DEV=$(sed -n 's/.*root=\([^ ]*\).*/\1/p' /proc/cmdline)
	DISK=$(basename "${ROOT_DEV%p[0-9]*}")
	[ -n "$DISK" ] || return 1

	for PART in /sys/class/block/"$DISK"p*; do
		[ -r "$PART/uevent" ] || continue
		if grep -q '^PARTNAME=resource$' "$PART/uevent"; then
			printf '/dev/%s\n' "$(basename "$PART")"
			return 0
		fi
	done

	return 1
}

READ_U8() {
	dd if="$1" bs=1 skip="$2" count=1 2>/dev/null | od -An -tu1 | tr -d ' '
}

READ_U32() {
	dd if="$1" bs=1 skip="$2" count=4 2>/dev/null | od -An -tu4 | tr -d ' '
}

WRITE_U32() {
	VALUE=$3
	BYTES=""

for _ in 1 2 3 4; do
		BYTES="$BYTES\\$(printf '%03o' $((VALUE & 255)))"
		VALUE=$((VALUE >> 8))
	done

	# shellcheck disable=SC2059
	printf "$BYTES" | dd of="$1" bs=1 seek="$2" count=4 conv=notrunc 2>/dev/null
}

LIST_ENTRIES() {
	DEV=$1
	[ "$(dd if="$DEV" bs=1 count=4 2>/dev/null)" = "RSCE" ] || return 1

	TABLE_BLOCK=$(READ_U8 "$DEV" 9)
	ENTRY_BLOCKS=$(READ_U8 "$DEV" 10)

	INDEX=0
	while :; do
		OFFSET=$(((TABLE_BLOCK + INDEX * ENTRY_BLOCKS) * 512))
		[ "$(dd if="$DEV" bs=1 skip="$OFFSET" count=4 2>/dev/null)" = "ENTR" ] || break

		NAME=$(dd if="$DEV" bs=1 skip=$((OFFSET + 4)) count=220 2>/dev/null | tr -d '\000')
		printf '%s %s %s %s %s\n' "$NAME" "$(READ_U32 "$DEV" $((OFFSET + 260)))" \
			"$(READ_U32 "$DEV" $((OFFSET + 264)))" "$(READ_U32 "$DEV" $((OFFSET + 256)))" "$OFFSET"

		INDEX=$((INDEX + 1))
	done
}

APPLY() {
	SRC=$1
	[ -f "$SRC" ] || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "$(printf "No such image: %s" "$SRC")"
		return 1
	}

	DEV=$(RESOURCE_DEVICE) || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "No resource partition found on the boot disk"
		return 1
	}

	ENTRIES=$(LIST_ENTRIES "$DEV") || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "The resource partition has no RSCE header"
		return 1
	}

	# The internal screen is reported landscape, the panel itself is portrait...
	SCREEN_W=$(GET_VAR "device" "screen/internal/width")
	SCREEN_H=$(GET_VAR "device" "screen/internal/height")
	[ -n "$SCREEN_W" ] && [ -n "$SCREEN_H" ] || return 1

	magick "${SRC}[0]" -resize "${SCREEN_W}x${SCREEN_H}!" -rotate "$LOGO_ROTATE" \
		-alpha off -type TrueColor BMP3:"$LOGO_TMP" || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "Unable to convert the boot logo"
		return 1
	}

	LOGO_SIZE=$(wc -c <"$LOGO_TMP")
	PART_BLOCKS=$(cat "/sys/class/block/$(basename "$DEV")/size")

	for LOGO in $LOGO_ENTRIES; do
		LINE=$(printf '%s\n' "$ENTRIES" | awk -v n="$LOGO" '$1 == n')
		[ -n "$LINE" ] || {
			LOG_ERROR "$0" 0 "BOOTLOGO" "$(printf "The resource partition has no %s" "$LOGO")"
			rm -f "$LOGO_TMP"
			return 1
		}

		# shellcheck disable=SC2046,SC2086
		set -- $LINE
		BLOCK=$2
		HASH_SIZE=$4

		NEXT=$(printf '%s\n' "$ENTRIES" | awk -v b="$BLOCK" -v end="$PART_BLOCKS" '
			BEGIN { next_block = end }
			$2 > b && $2 < next_block { next_block = $2 }
			END { print next_block }
		')

		if [ "$HASH_SIZE" -ne 0 ]; then
			LOG_ERROR "$0" 0 "BOOTLOGO" "$(printf "%s carries a hash, leaving it alone" "$LOGO")"
			rm -f "$LOGO_TMP"
			return 1
		fi

		if [ "$LOGO_SIZE" -gt $(((NEXT - BLOCK) * 512)) ]; then
			LOG_ERROR "$0" 0 "BOOTLOGO" "$(printf "The boot logo does not fit the %s slot" "$LOGO")"
			rm -f "$LOGO_TMP"
			return 1
		fi
	done

	if [ ! -f "$BACKUP" ]; then
		dd if="$DEV" of="$BACKUP" bs=1M 2>/dev/null || {
			LOG_ERROR "$0" 0 "BOOTLOGO" "Unable to save the original resource partition"
			rm -f "$BACKUP" "$LOGO_TMP"
			return 1
		}
		sync
	fi

	for LOGO in $LOGO_ENTRIES; do
		# shellcheck disable=SC2046,SC2086
		set -- $(printf '%s\n' "$ENTRIES" | awk -v n="$LOGO" '$1 == n')
		dd if="$LOGO_TMP" of="$DEV" bs=512 seek="$2" conv=notrunc,fsync 2>/dev/null
		WRITE_U32 "$DEV" $(($5 + 264)) "$LOGO_SIZE"
	done

	sync
	rm -f "$LOGO_TMP"

	LOG_INFO "$0" 0 "BOOTLOGO" "Boot logo written to the resource partition"
	return 0
}

RESTORE() {
	[ -f "$BACKUP" ] || return 0

	# shellcheck disable=SC2046,SC2086
	set -- $(LIST_ENTRIES "$BACKUP" | awk '$1 == "logo.bmp"')
	[ -n "$2" ] || {
		LOG_ERROR "$0" 0 "BOOTLOGO" "The saved resource partition has no logo.bmp"
		return 1
	}

	ORIGINAL="/tmp/vita_bootlogo_original_$$.bmp"

	dd if="$BACKUP" bs=512 skip="$2" count=$((($3 + 511) / 512)) 2>/dev/null | head -c "$3" >"$ORIGINAL"
	magick "$ORIGINAL" -rotate $((360 - LOGO_ROTATE)) "$ORIGINAL" || {
		rm -f "$ORIGINAL"
		return 1
	}

	APPLY "$ORIGINAL"
	RESULT=$?

	rm -f "$ORIGINAL"
	return "$RESULT"
}

case "$1" in
	apply) APPLY "$2" ;;
	restore) RESTORE ;;
	*)
		printf 'Usage: %s apply IMAGE | restore\n' "$0" >&2
		exit 1
		;;
esac
