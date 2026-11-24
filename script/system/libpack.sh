#!/bin/sh

. /opt/muos/script/var/boot.sh

LIBPACK_SOURCE="/opt/device/common/pack"
LIBPACK_DEST="/opt/muos/device/pack"
LIBPACK_TOOL="/opt/muos/frontend/tool/mulibpack"

rm -rf /opt/muos/frontend/pack /opt/muos/share/libpack /usr/lib/muos-libpack.sqfs

[ -d "$LIBPACK_SOURCE" ] || exit 0

[ "${1:-}" = "after-paint" ] && WAIT_FOR_FIRST_PAINT 300

LIBPACK_CURRENT=
for LIBPACK_FILE in "$LIBPACK_DEST"/*.manifest; do
	[ -f "$LIBPACK_FILE" ] && LIBPACK_CURRENT=$LIBPACK_FILE && break
done

LIBPACK_BEST=
[ -x "$LIBPACK_TOOL" ] && LIBPACK_BEST=$("$LIBPACK_TOOL" select "$LIBPACK_SOURCE" "$LIBPACK_CURRENT" 2>/dev/null)

if [ -n "$LIBPACK_BEST" ] && [ -f "${LIBPACK_BEST%.sqfs}.manifest" ]; then
	LIBPACK_NAME=${LIBPACK_BEST##*/}
	LIBPACK_NAME=${LIBPACK_NAME%.sqfs}
	mkdir -p "$LIBPACK_DEST"

	if cp "$LIBPACK_BEST" "$LIBPACK_DEST/$LIBPACK_NAME.sqfs.tmp" 2>/dev/null &&
		cp "${LIBPACK_BEST%.sqfs}.manifest" "$LIBPACK_DEST/$LIBPACK_NAME.manifest.tmp" 2>/dev/null; then
		chmod 644 "$LIBPACK_DEST/$LIBPACK_NAME.sqfs.tmp" "$LIBPACK_DEST/$LIBPACK_NAME.manifest.tmp"
		mv -f "$LIBPACK_DEST/$LIBPACK_NAME.sqfs.tmp" "$LIBPACK_DEST/$LIBPACK_NAME.sqfs"
		mv -f "$LIBPACK_DEST/$LIBPACK_NAME.manifest.tmp" "$LIBPACK_DEST/$LIBPACK_NAME.manifest"

		for LIBPACK_FILE in "$LIBPACK_DEST"/*; do
			case "${LIBPACK_FILE##*/}" in
				"$LIBPACK_NAME.sqfs" | "$LIBPACK_NAME.manifest") ;;
				*) rm -f "$LIBPACK_FILE" ;;
			esac
		done

		LOG_INFO "$0" 0 "LIBPACK" "$(printf "Installed library pack %s" "$LIBPACK_NAME")"
	else
		rm -f "$LIBPACK_DEST/$LIBPACK_NAME.sqfs.tmp" "$LIBPACK_DEST/$LIBPACK_NAME.manifest.tmp"
	fi
fi

rm -rf "$LIBPACK_SOURCE"
rmdir /opt/device/common /opt/device 2>/dev/null
sync
