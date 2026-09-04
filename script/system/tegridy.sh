#!/bin/sh

set -u

INTEGRITY_DIR="/opt/muos/share/info/integrity"
MANIFEST="$INTEGRITY_DIR/manifest"
SIGNATURE="$INTEGRITY_DIR/manifest.sig"
VERIFIER="/opt/muos/frontend/muverify"
RESULT_DIR="/run/muos/integrity"
LOCK_DIR="/run/muos/integrity.lock"

CATEGORIES="signature provenance scripts frontend device kernel modules dtb ramdisk bootloader boot_resources"

TREE_DIGEST() {
	TREE_ROOT=$1
	[ -d "$TREE_ROOT" ] || return 1

	(
		cd "$TREE_ROOT" || exit 1
		find . \( -type f -o -type l \) -print | LC_ALL=C sort | while IFS= read -r TREE_ENTRY; do
			if [ -L "$TREE_ENTRY" ]; then
				printf 'link|%s|%s\n' "$TREE_ENTRY" "$(readlink "$TREE_ENTRY")"
			elif [ -f "$TREE_ENTRY" ]; then
				TREE_MODE=$(stat -c '%a' "$TREE_ENTRY") || exit 1
				TREE_HASH=$(sha256sum "$TREE_ENTRY") || exit 1
				TREE_HASH=${TREE_HASH%% *}
				printf 'file|%s|%s|%s\n' "$TREE_ENTRY" "$TREE_MODE" "$TREE_HASH"
			fi
		done
	) | sha256sum | cut -d ' ' -f 1
}

if [ "${1-}" = "--tree" ]; then
	[ "$#" -eq 2 ] || exit 2
	TREE_DIGEST "$2"
	exit $?
fi

mkdir -p /run/muos
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
	exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT HUP INT TERM

[ -e "$RESULT_DIR/complete" ] && exit 0
mkdir -p "$RESULT_DIR"

for CATEGORY in $CATEGORIES; do
	printf '%s\n' "Modified" >"$RESULT_DIR/$CATEGORY"
done
: >"$RESULT_DIR/details.log"

RECORD_FAILURE() {
	FAIL_CATEGORY=$1
	shift
	printf '%s\n' "Modified" >"$RESULT_DIR/$FAIL_CATEGORY"
	printf '%s: %s\n' "$FAIL_CATEGORY" "$*" >>"$RESULT_DIR/details.log"
}

FINISH() {
	date -u '+%Y-%m-%dT%H:%M:%SZ' >"$RESULT_DIR/complete"
}

if [ ! -x "$VERIFIER" ]; then
	RECORD_FAILURE signature "verifier is missing"
	FINISH
	exit 0
fi

if [ ! -f "$MANIFEST" ] || [ ! -f "$SIGNATURE" ]; then
	RECORD_FAILURE signature "signed release manifest is missing"
	FINISH
	exit 0
fi

if ! "$VERIFIER" "$MANIFEST" "$SIGNATURE" >>"$RESULT_DIR/details.log" 2>&1; then
	RECORD_FAILURE signature "release signature is invalid"
	FINISH
	exit 0
fi

for CATEGORY in $CATEGORIES; do
	printf '%s\n' "Clean" >"$RESULT_DIR/$CATEGORY"
done

BOOT_DEVICE=/dev/mmcblk0
while IFS='|' read -r RECORD_TYPE CATEGORY FIELD_A FIELD_B FIELD_C; do
	case "$RECORD_TYPE" in
		meta)
			[ "$CATEGORY" = "boot_device" ] && BOOT_DEVICE=$FIELD_A
			;;
		tree)
			ACTUAL_HASH=$(TREE_DIGEST "$FIELD_A" 2>/dev/null) || ACTUAL_HASH=""
			if [ -z "$ACTUAL_HASH" ] || [ "$ACTUAL_HASH" != "$FIELD_B" ]; then
				RECORD_FAILURE "$CATEGORY" "tree differs: $FIELD_A"
			fi
			;;
		file)
			if [ -f "$FIELD_A" ]; then
				ACTUAL_HASH=$(sha256sum "$FIELD_A" 2>/dev/null)
				ACTUAL_HASH=${ACTUAL_HASH%% *}
			else
				ACTUAL_HASH=""
			fi
			if [ -z "$ACTUAL_HASH" ] || [ "$ACTUAL_HASH" != "$FIELD_B" ]; then
				RECORD_FAILURE "$CATEGORY" "file differs: $FIELD_A"
			fi
			;;
		raw)
			ACTUAL_HASH=$(dd if="$BOOT_DEVICE" bs=512 skip="$FIELD_A" count="$FIELD_B" 2>/dev/null | sha256sum)
			ACTUAL_HASH=${ACTUAL_HASH%% *}
			if [ -z "$ACTUAL_HASH" ] || [ "$ACTUAL_HASH" != "$FIELD_C" ]; then
				RECORD_FAILURE "$CATEGORY" "boot media differs at sector $FIELD_A ($FIELD_B sectors)"
			fi
			;;
		none | '') ;;

		*)
			RECORD_FAILURE signature "unknown signed manifest record: $RECORD_TYPE"
			;;
	esac
done <"$MANIFEST"

FINISH
