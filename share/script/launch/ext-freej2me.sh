#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
    LOG_INFO "$0" 0 "Content Launch" "DETAIL"
    LOG_INFO "$0" 0 "NAME" "$NAME"
    LOG_INFO "$0" 0 "CORE" "$CORE"
    LOG_INFO "$0" 0 "FILE" "$FILE"
) &

FREEJ2ME_DIR="$MUOS_SHARE_DIR/emulator/freej2me"

# The bundled sdl_interface wrapper compares the raw joystick button index against the ten
# keypad entries in keymap.cfg, and the values it understands are ten fixed names standing for
# ten fixed indices. It was built for a TrimUI button order, so on everything else its own
# defaults land the keypad on the volume rocker. The board sdl_map is what actually says which
# raw index each control sits on, so the map is written from that at launch.
#
# A control the name vocabulary cannot reach is parked on L2, which resolves to index 20 and no
# muOS device reports that, rather than left to fire off something unrelated. The four arrows
# come in on the hat and are handled separately, so they need no entry here.
#
# All ten entries have to be present. The wrapper dereferences each lookup without checking it,
# so a short file takes the process down rather than falling back, which is why the map is
# rewritten on every launch instead of being left to whatever is on disk.
KEYMAP_NAME_FOR_INDEX() {
	case "$1" in
		0) printf 'B' ;;
		1) printf 'A' ;;
		2) printf 'Y' ;;
		3) printf 'X' ;;
		4) printf 'L' ;;
		5) printf 'R' ;;
		6) printf 'SELECT' ;;
		7) printf 'START' ;;
		20) printf 'L2' ;;
		21) printf 'R2' ;;
		*) printf 'L2' ;;
	esac
}

KEYMAP_NAME_FOR_CONTROL() {
	KM_INDEX=$(printf '%s' "$SDL_MAP" | tr ',' '\n' | sed -n "s/^$1:b\([0-9]\{1,2\}\)\$/\1/p" | head -1)
	KEYMAP_NAME_FOR_INDEX "$KM_INDEX"
}

WRITE_KEYMAP() {
	SDL_MAP=$(GET_VAR "device" "board/sdl_map")
	[ -n "$SDL_MAP" ] || return 0

	cat >"$FREEJ2ME_DIR/keymap.cfg" <<-KEYMAP
	{
	  "OK": "$(KEYMAP_NAME_FOR_CONTROL a)",
	  "左键": "$(KEYMAP_NAME_FOR_CONTROL leftshoulder)",
	  "右键": "$(KEYMAP_NAME_FOR_CONTROL b)",
	  "0": "$(KEYMAP_NAME_FOR_CONTROL rightshoulder)",
	  "*": "$(KEYMAP_NAME_FOR_CONTROL x)",
	  "#": "$(KEYMAP_NAME_FOR_CONTROL y)",
	  "1": "L2",
	  "3": "L2",
	  "7": "L2",
	  "9": "L2"
	}
	KEYMAP
}

SETUP_SDL_ENVIRONMENT

HOME="$FREEJ2ME_DIR"
export HOME

XDG_CONFIG_HOME="$HOME/.config"
export XDG_CONFIG_HOME

cd "$FREEJ2ME_DIR" || exit

WRITE_KEYMAP

SET_VAR "system" "foreground_process" "java"

case "$CORE" in
    *128)
        WIDTH=128
        HEIGHT=128
        ;;
    *176)
        WIDTH=176
        HEIGHT=208
        ;;
    *240)
        WIDTH=240
        HEIGHT=320
        ;;
    *320)
        WIDTH=320
        HEIGHT=240
        ;;
    *640)
        WIDTH=640
        HEIGHT=360
        ;;
    *) exit 0 ;;
esac

TIMIDITY_CFG="./timidity/timidity.cfg" JAVA_TOOL_OPTIONS="-Djava.util.prefs.systemRoot=./java/system -Djava.util.prefs.userRoot=./java/user -Djava.awt.headless=true -Dsun.jnu.encoding=UTF-8 -Dfile.encoding=UTF-8 -Djava.library.path=/opt/zulu/lib" /opt/zulu/bin/java -jar ./freej2me-sdl.jar "$FILE" "$WIDTH" "$HEIGHT" 100

