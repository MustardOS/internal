#!/bin/sh

. /opt/muos/script/var/func.sh

CONFIG_DIR="/run/muos/storage/info/config"
CONFIG_ZIP="/run/muos/storage/package/config/$1.zip"

while [ -d "$CONFIG_DIR" ]; do
	[ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ] && break
	rm -rf "$CONFIG_DIR/*"
	sync
	sleep 1
done

unzip "$CONFIG_ZIP" -d "$CONFIG_DIR"

# Run the device control configuration just in case people have forgotten about the retroarch.cfg file...
/opt/muos/device/current/script/control.sh

CONFIG_NAME=$(basename "$CONFIG_ZIP" .zip)
CLEANED_CONFIG_NAME=$(echo "$CONFIG_NAME" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
echo "$CLEANED_CONFIG_NAME" >"$CONFIG_DIR/config_name.txt"

sync
