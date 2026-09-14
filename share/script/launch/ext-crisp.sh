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

# Only the game preferences and high scores are kept
HOME="/run/muos/storage/save/crisp"
export HOME

SETUP_SDL_ENVIRONMENT

CGLP_BIN="cglpsdl2"
EMU_DIR="$MUOS_SHARE_DIR/emulator/crisp"

SET_VAR "system" "foreground_process" "$CGLP_BIN"

mkdir -p "$HOME"
cd "$EMU_DIR" || exit

chmod +x ./"$CGLP_BIN"
./"$CGLP_BIN" -f "$FILE"
