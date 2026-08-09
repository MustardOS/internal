#!/bin/sh

SERIAL="$(xargs -n 1 -a /proc/cmdline | sed -n s/^snum=//p)"

if [ -z "$SERIAL" ] && [ -r /sys/firmware/devicetree/base/serial-number ]; then
	SERIAL=$(tr -d '\000[:space:]' </sys/firmware/devicetree/base/serial-number)
fi

if [ -z "$SERIAL" ] && [ -r /var/lib/dbus/machine-id ]; then
	IFS= read -r SERIAL </var/lib/dbus/machine-id
fi

if [ -z "$SERIAL" ] && [ -r /etc/machine-id ]; then
	IFS= read -r SERIAL </etc/machine-id
fi

if [ -z "$SERIAL" ] && [ -r /opt/muos/config/system/uuid ]; then
	IFS= read -r SERIAL </opt/muos/config/system/uuid
fi

SERIAL_FILE=/opt/muos/config/system/serial
if [ -z "$SERIAL" ] && [ -r "$SERIAL_FILE" ]; then
	IFS= read -r SERIAL <"$SERIAL_FILE"
fi

if [ -z "$SERIAL" ]; then
	SERIAL=$(hexdump -vn4 -e'4/4 "%08X" 1 "\n"' /dev/urandom | tr '[:upper:]' '[:lower:]')
	mkdir -p "${SERIAL_FILE%/*}"
	TEMP_FILE="${SERIAL_FILE}.tmp.$$"
	if printf "%s" "$SERIAL" >"$TEMP_FILE"; then
		chmod 600 "$TEMP_FILE"
		mv -f "$TEMP_FILE" "$SERIAL_FILE"
	else
		rm -f "$TEMP_FILE"
	fi
fi

SERIAL=$(printf "%s" "$SERIAL" | tr -d '[:space:]')
printf "%s" "$SERIAL"
