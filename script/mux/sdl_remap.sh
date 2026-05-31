#!/bin/sh

. /opt/muos/script/var/func.sh

TARGET="$1"
MAPPING="$2"

[ -z "$TARGET" ] || [ -z "$MAPPING" ] && {
	printf "Usage: %s <modern|retro> <mapping_line>\n" "$0"
	exit 1
}

GCDB_DIR="$MUOS_SHARE_DIR/info/gamecontrollerdb"

case "$TARGET" in
	modern | retro)
		DB_FILE="$GCDB_DIR/${TARGET}.txt"
		;;
	*)
		LOG_ERROR "$0" 0 "SDL_REMAP" "$(printf "Unknown target: '%s'" "$TARGET")"
		exit 1
		;;
esac

# Extract the GUID (first 32 hex chars) from the mapping line
GUID=$(printf "%s" "$MAPPING" | cut -d',' -f1)

if [ -z "$GUID" ] || [ "${#GUID}" -lt 32 ]; then
	LOG_ERROR "$0" 0 "SDL_REMAP" "Invalid mapping line! Cannot extract GUID..."
	exit 1
fi

LOG_INFO "$0" 0 "SDL_REMAP" "$(printf "Saving remap for GUID '%s' to '%s'" "$GUID" "$DB_FILE")"

TMP_FILE="${DB_FILE}.tmp.$$"
TMP_SWAP="${DB_FILE}.swap.$$"

if [ -f "$DB_FILE" ]; then
	grep -v "^${GUID}," "$DB_FILE" >"$TMP_FILE" 2>/dev/null || : >"$TMP_FILE"
else
	: >"$TMP_FILE"
fi

printf "%s\n" "$MAPPING" | cat - "$TMP_FILE" >"$TMP_SWAP"
rm -f "$TMP_FILE"
mv -f "$TMP_SWAP" "$DB_FILE"

mkdir -p "$MUOS_CONF_GLOBAL/settings/remap"
SET_VAR "config" "settings/remap/layout" "$([ "$TARGET" = modern ] && printf 1 || printf 0)"

LOG_SUCCESS "$0" 0 "SDL_REMAP" "$(printf "Remap saved to '%s'" "$DB_FILE")"
