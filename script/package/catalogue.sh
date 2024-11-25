#!/bin/sh

. /opt/muos/script/var/func.sh

CATALOGUE_DIR="/run/muos/storage/info/catalogue"
CATALOGUE_ZIP="/run/muos/storage/package/catalogue/$1.zip"

# Ensure the catalogue directory is empty without deleting the directory itself
if [ -d "$CATALOGUE_DIR" ]; then
	printf "Purging catalogue directory: %s" "$CONFIG_DIR"
	find "$CATALOGUE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
	sync
fi

unzip "$CATALOGUE_ZIP" -d "$CATALOGUE_DIR"

# Run the catalogue generation script just in case people have forgotten things...
printf "Running catalogue generation script"
/opt/muos/script/system/catalogue.sh

CATALOGUE_NAME=$(basename "$CATALOGUE_ZIP" .zip)
CLEANED_CATALOGUE_NAME=$(printf "%s\n" "$CATALOGUE_NAME" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
echo "$CLEANED_CATALOGUE_NAME" >"$CATALOGUE_DIR/catalogue_name.txt"

sync
