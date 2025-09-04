#!/bin/sh

. /opt/muos/script/var/func.sh

OBOR_DIR="/opt/muos/share/emulator/openbor/userdata/system/configs/openbor"

for BOR_INI in "$DEVICE_CONTROL_DIR/openbor/"*.ini; do
	if [ ! -f "${OBOR_DIR}/$(basename "$BOR_INI")" ]; then
		mkdir -p "$OBOR_DIR"
		cp "$BOR_INI" "${OBOR_DIR}/"
	fi
done
