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

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_CONF="/opt/muos/share/info/config/retroarch.cfg"
RA_ARGS=$(CONFIGURE_RETROARCH "$RA_CONF")

IS_SWAP=$(DETECT_CONTROL_SWAP)

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
mkdir -p "$F_PATH/.$NAME"

# Compensate for Windows wild cuntery
dos2unix -n "$F_PATH/$NAME.doom" "$F_PATH/$NAME.doom"

PRBC="$F_PATH/.$NAME/prboom.cfg"
cp -f "$F_PATH/$NAME.doom" "$PRBC"
cp -f "/run/muos/storage/bios/prboom.wad" "$F_PATH/.$NAME/prboom.wad"

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$F_PATH/$NAME.doom")
cp -f "$F_PATH/.IWAD/$IWAD" "$F_PATH/.$NAME/$IWAD"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

nice --20 retroarch -v -f -c "$RA_CONF" $RA_ARGS -L "/opt/muos/share/core/prboom_libretro.so" "$F_PATH/.$NAME/$IWAD"

for RF in ra_no_load ra_autoload_once.cfg; do
	[ -e "/tmp/$RF" ] && ENSURE_REMOVED "/tmp/$RF"
done

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop
