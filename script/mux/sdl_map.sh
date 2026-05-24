#!/bin/sh

. /opt/muos/script/var/func.sh

CON_GO="/tmp/con_go"
SELECTED_MAP=

if [ -e "$CON_GO" ]; then
	case "$(cat "$CON_GO")" in
		modern | retro) SELECTED_MAP=$(cat "$CON_GO") ;;
	esac
fi

if [ -z "$SELECTED_MAP" ]; then
	case "$(GET_VAR "config" "settings/remap/layout")" in
		1) SELECTED_MAP=modern ;;
		*) SELECTED_MAP=retro ;;
	esac
fi

SRC="$MUOS_SHARE_DIR/info/gamecontrollerdb/${SELECTED_MAP}.txt"

if [ ! -f "$SRC" ]; then
	LOG_WARN "$0" 0 "SDL_MAP" "$(printf "Map '%s' not found, falling back to retro" "$SELECTED_MAP")"
	SELECTED_MAP=retro
	SRC="$MUOS_SHARE_DIR/info/gamecontrollerdb/retro.txt"
fi

LOG_INFO "$0" 0 "SDL_MAP" "$(printf "Linking SDL controller map: '%s'" "$SELECTED_MAP")"

for LIB_D in lib lib32; do
	BASE="/usr/$LIB_D"
	[ -d "$BASE" ] || continue

	SDL_MAP_PATH="$BASE/gamecontrollerdb.txt"

	LOG_DEBUG "$0" 0 "SDL_MAP" "$(printf "Linking '%s' -> '%s'" "$SDL_MAP_PATH" "$SRC")"
	rm -f "$SDL_MAP_PATH"
	ln -s "$SRC" "$SDL_MAP_PATH"
done
