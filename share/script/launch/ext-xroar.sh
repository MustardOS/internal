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

XROAR_BIN="xroar"
XROAR_DIR="$MUOS_SHARE_DIR/emulator/$XROAR_BIN"

LD_LIBRARY_PATH="$XROAR_DIR/libs:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "$XROAR_BIN"

case "$CORE" in
	xroar | ext-xroar) CORE="coco2bus" ;;
esac

XR_GPTK="$XROAR_DIR/gptk"

GAME_BN=$(basename "${FILE%.*}")
GPTK_SP="${XR_GPTK}/${GAME_BN}.gptk"

[ ! -f "$GPTK_SP" ] && GPTK_SP="${XR_GPTK}/$XROAR_BIN.gptk"

PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
LIB_IPOSE="libinterpose.aarch64.so"
ln -sf "$PM_DIR/$LIB_IPOSE" "/usr/lib/$LIB_IPOSE" >/dev/null 2>&1
"$PM_DIR"/gptokeyb2 "$XROAR_BIN" -c "$GPTK_SP" &

"$XROAR_DIR/$XROAR_BIN" -c "$XROAR_DIR/$XROAR_BIN.conf" -default-machine "$CORE" "$FILE"
