#!/bin/sh

. /opt/muos/script/var/func.sh

CON_GO=/tmp/con_go
SELECTED_MAP=

if [ -e "$CON_GO" ]; then
	case "$(cat "$CON_GO")" in
		modern | retro) SELECTED_MAP=$(cat "$CON_GO") ;;
	esac
fi

if [ -z "$SELECTED_MAP" ]; then
	if [ "$(GET_VAR "config" "settings/advanced/swap")" -eq 1 ]; then
		SELECTED_MAP=modern
	else
		SELECTED_MAP=retro
	fi
fi

SRC="/opt/muos/share/info/gamecontrollerdb/${SELECTED_MAP}.txt"

for LIB_D in lib lib32; do
	BASE="/usr/$LIB_D"
	[ -d "$BASE" ] || continue

	SDL_MAP_PATH="$BASE/gamecontrollerdb.txt"

	rm -f "$SDL_MAP_PATH"
	ln -s "$SRC" "$SDL_MAP_PATH"
done
