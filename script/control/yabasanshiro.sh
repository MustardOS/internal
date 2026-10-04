#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "${1:-}" = "FORCE_COPY" ] && FORCE_COPY=1

YABA_DIR="$MUOS_SHARE_DIR/emulator/yabasanshiro/.emulationstation"
YABA_CFG="$YABA_DIR/es_temporaryinput.cfg"
YABA_KEYMAP="$MUOS_SHARE_DIR/emulator/yabasanshiro/.yabasanshiro/keymapv2.json"

if [ "$FORCE_COPY" -eq 1 ] || [ ! -f "$YABA_CFG" ]; then
	mkdir -p "$YABA_DIR"
	cp -f "$DEVICE_CONTROL_DIR/yabasanshiro/es_temporaryinput.cfg" "$YABA_CFG" || exit 1
	rm -f "$YABA_KEYMAP"
fi
