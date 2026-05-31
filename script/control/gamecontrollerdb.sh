#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

GCDB_STORE="$MUOS_SHARE_DIR/info/gamecontrollerdb"
GCDB_FULL="$MUOS_SHARE_DIR/conf/gamecontrollerdb.txt"

mkdir -p "$GCDB_STORE"

for SRC in "$DEVICE_CONTROL_DIR/gamecontrollerdb"/*.txt; do
	[ -f "$SRC" ] || continue

	DST="$GCDB_STORE/$(basename "$SRC")"

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST" ]; then
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
		mv -f "$TMP" "$DST"
	fi
done

# Purge anything with the 'system' reserved name
rm -f "$GCDB_STORE/system.txt"
: >"$GCDB_STORE/system.txt"
