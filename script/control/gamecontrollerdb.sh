#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

GCDB_STORE="$MUOS_SHARE_DIR/info/gamecontrollerdb"

mkdir -p "$GCDB_STORE"

for SRC in "$DEVICE_CONTROL_DIR/gamecontrollerdb"/*.txt; do
	[ -f "$SRC" ] || continue

	DST="$GCDB_STORE/$(basename "$SRC")"

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST" ]; then
		cp -f "$SRC" "$DST"
	fi
done

# Purge anything with the 'system' reserved name
rm -f "$GCDB_STORE/system.txt"
: >"$GCDB_STORE/system.txt"
