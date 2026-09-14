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

BIOS="/run/muos/storage/bios/saturn_bios.bin"
SAVE_DIR="/run/muos/storage/save/file/YabaSanshiro-Ext"
STATE_DIR="/run/muos/storage/save/state/YabaSanshiro-Ext"

mkdir -p "$STATE_DIR" "$SAVE_DIR"

if [ "$CORE" = "ext-yabasanshiro-hle" ]; then
	YABA_BIN="./yabasanshiro -r 3 -a -i"
elif [ "$CORE" = "ext-yabasanshiro-bios" ] && [ ! -f "$BIOS" ]; then
	YABA_BIN="./yabasanshiro -r 3 -a -i"
elif [ "$CORE" = "ext-yabasanshiro-bios" ]; then
	YABA_BIN="./yabasanshiro -b $BIOS -r 3 -a -i"
fi

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "yabasanshiro"

EMUDIR="$MUOS_SHARE_DIR/emulator/yabasanshiro"
export HOME="$EMUDIR"

# Grab full ROM name including extension
F_NAME=$(basename "$FILE")

# Memory cards fill out so fake one card per game.
# If we don't exit gracefully, save file may still exist as backup.bin, if so make a copy.
# We only keep one recovered backup
if [ -f "$SAVE_DIR/backup.bin" ]; then
	cp -f "$SAVE_DIR/backup.bin" "$SAVE_DIR/recovered.backup.bin"
	rm -f "$SAVE_DIR/backup.bin"
fi

# If a game specific save exists, copy to backup.bin
if [ -f "$SAVE_DIR/$F_NAME.backup.bin" ]; then
	cp -f "$SAVE_DIR/$F_NAME.backup.bin" "$SAVE_DIR/backup.bin"
fi

chmod +x "$EMUDIR"/yabasanshiro

cd "$EMUDIR" || exit

export LD_LIBRARY_PATH="$EMUDIR/libsark:$LD_LIBRARY_PATH"

$YABA_BIN "$FILE"

# Copy backup.bin to game specific save
if [ -f "$SAVE_DIR/backup.bin" ]; then
	cp -f "$SAVE_DIR/backup.bin" "$SAVE_DIR/$F_NAME.backup.bin"
	rm -f "$SAVE_DIR/backup.bin"
fi
