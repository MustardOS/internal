#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

GCDB_STORE="$MUOS_SHARE_DIR/info/gamecontrollerdb"
GCDB_FULL="$MUOS_SHARE_DIR/conf/gamecontrollerdb.txt"
BOARD_NAME=$(GET_VAR "device" "board/name")

case "$BOARD_NAME" in
	tui-brick) PORTMASTER_NAME="TRIMUI Brick Controller" ;;
	tui-spoon) PORTMASTER_NAME="TRIMUI Smart Pro Controller" ;;
	*) PORTMASTER_NAME="Deeplay-keys" ;;
esac

mkdir -p "$GCDB_STORE"

for SRC in "$DEVICE_CONTROL_DIR/gamecontrollerdb"/*.txt; do
	[ -f "$SRC" ] || continue

	DST="$GCDB_STORE/$(basename "$SRC")"
	PORTMASTER_GUID=$(awk -F, '!/^#/ && NF > 1 {print $1; exit}' "$SRC")

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST" ] || ! grep -Fq "$PORTMASTER_GUID,$PORTMASTER_NAME," "$DST"; then
		TMP="${DST}.tmp.$$"
		if [ -f "$GCDB_FULL" ]; then
			cp "$GCDB_FULL" "$TMP"
			# Remove any community entry whose GUID conflicts with a device-specific entry
			while IFS=',' read -r guid _rest; do
				case "$guid" in
					"" | \#*) continue ;;
				esac
				grep -v "^${guid}," "$TMP" >"${TMP}.f" && mv "${TMP}.f" "$TMP"
			done <"$SRC"
			cat "$SRC" >>"$TMP"
		else
			cp "$SRC" "$TMP"
		fi
		awk -F, -v OFS=, -v name="$PORTMASTER_NAME" '!/^#/ && NF > 1 {$2 = name; print}' "$SRC" >>"$TMP"
		mv -f "$TMP" "$DST"
	fi
done

# Purge anything with the 'system' reserved name
rm -f "$GCDB_STORE/system.txt"
: >"$GCDB_STORE/system.txt"
