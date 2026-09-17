#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

PICKLES_OPT="$MUOS_STORE_DIR/save/pickles/coreopt/core"
PICKLES_SRC="$DEVICE_CONTROL_DIR/pickles/core"

[ -d "$PICKLES_SRC" ] || exit 0

mkdir -p "$PICKLES_OPT"

for SRC in "$PICKLES_SRC"/*.ini; do
	[ -f "$SRC" ] || continue
	DST="$PICKLES_OPT/${SRC##*/}"

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$DST" ]; then
		cp -f "$SRC" "$DST"
	fi
done
