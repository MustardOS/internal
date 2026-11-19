#!/bin/sh

. /opt/muos/script/var/base.sh
. /opt/muos/script/var/zip.sh

THEME_DIR="$MUOS_STORE_DIR/theme"

USAGE() {
	printf 'Usage: %s <export|import> <source> <target>\n' "${0##*/}" >&2
	exit 2
}

[ "$#" -eq 3 ] || USAGE

EXPORT() {
	SRC="$THEME_DIR/$1"
	OUT="$2"

	[ -d "$SRC" ] || exit 3
	mkdir -p "${OUT%/*}" || exit 1
	rm -f "$OUT.part"

	if ! (cd "$SRC" && zip -r0 -q "$OUT.part" . -x ".lab/*" "lab.txt"); then
		rm -f "$OUT.part"
		exit 1
	fi

	mv -f "$OUT.part" "$OUT"
}

IMPORT() {
	ARCHIVE="$1"
	DEST="$THEME_DIR/$2"

	[ -f "$ARCHIVE" ] || exit 3
	[ -e "$DEST" ] && exit 4

	trap 'ARCHIVE_CACHE_CLEANUP' EXIT
	SAFE_ARCHIVE "$ARCHIVE" >/dev/null || exit 5

	if ! EXTRACT_ARCHIVE "Theme" "$ARCHIVE" "$DEST" >/dev/null; then
		rm -rf "$DEST"
		exit 1
	fi

	[ -f "$DEST/name.txt" ] || printf '%s\n' "$2" >"$DEST/name.txt"
}

case "$1" in
	export) EXPORT "$2" "$3" ;;
	import) IMPORT "$2" "$3" ;;
	*) USAGE ;;
esac
