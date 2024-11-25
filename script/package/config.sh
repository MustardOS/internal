#!/bin/sh

. /opt/muos/script/var/func.sh

CONFIG_DIR="/run/muos/storage/info/config"
CONFIG_ZIP="/run/muos/storage/package/config/$1.zip"

# Ensure the configuration directory is empty without deleting the directory itself
if [ -d "$CONFIG_DIR" ]; then
	printf "Purging configuration directory: %s" "$CONFIG_DIR"
	find "$CONFIG_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
	sync
fi

unzip "$CONFIG_ZIP" -d "$CONFIG_DIR"

# Run the device control configuration just in case people have forgotten about the retroarch.cfg file...
printf "Restoring device control configuration"
/opt/muos/device/current/script/control.sh

CONFIG_NAME=$(basename "$CONFIG_ZIP" .zip)
CLEANED_CONFIG_NAME=$(printf "%s\n" "$CONFIG_NAME" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
echo "$CLEANED_CONFIG_NAME" >"$CONFIG_DIR/config_name.txt"

sync
