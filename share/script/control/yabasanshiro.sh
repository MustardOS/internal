#!/bin/sh

. /opt/muos/script/var/func.sh

YABA_DIR="$MUOS_SHARE_DIR/emulator/yabasanshiro/.emulationstation"
YABA_CFG="${YABA_DIR}/es_temporaryinput.cfg"

if [ ! -f "$YABA_CFG" ]; then
	mkdir -p "$YABA_DIR"
	cp "$DEVICE_CONTROL_DIR/yabasanshiro/es_temporaryinput.cfg" "$YABA_CFG"
fi
