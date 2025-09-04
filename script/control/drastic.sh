#!/bin/sh

. /opt/muos/script/var/func.sh

DRASTIC_ADV="/opt/muos/share/emulator/drastic-trngaje"
DRASTIC_ADV_JSON="${DRASTIC_ADV}/resources/settings.json"
DRASTIC_ADV_CFG="${DRASTIC_ADV}/config/drastic.cfg"

if [ ! -f "$DRASTIC_ADV_JSON" ]; then
	mkdir -p "${DRASTIC_ADV}/resources"
	cp -f "$DEVICE_CONTROL_DIR/drastic-trngaje/settings.json" "$DRASTIC_ADV_JSON"
fi

if [ ! -f "$DRASTIC_ADV_CFG" ]; then
	mkdir -p "${DRASTIC_ADV}/config"
	cp -f "$DEVICE_CONTROL_DIR/drastic-trngaje/drastic.cfg" "$DRASTIC_ADV_CFG"
fi

DRASTIC_LEG="/opt/muos/share/emulator/drastic-legacy"
DRASTIC_LEG_CFG="${DRASTIC_LEG}/config/drastic.cfg"
if [ ! -f "$DRASTIC_LEG_CFG" ]; then
	mkdir -p "${DRASTIC_LEG}/config"
	cp -f "$DEVICE_CONTROL_DIR/drastic.cfg" "$DRASTIC_LEG_CFG"
fi
