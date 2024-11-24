#!/bin/sh

. /opt/muos/script/var/func.sh

CATALOGUE_DIR="/run/muos/storage/info/catalogue"
CATALOGUE_ZIP="/run/muos/storage/package/catalogue/$1.zip"

while [ -d "$CATALOGUE_DIR" ]; do
	[ -z "$(ls -A "$CATALOGUE_DIR" 2>/dev/null)" ] && break
	rm -rf "$CATALOGUE_DIR/*"
	sync
	sleep 1
done

unzip "$CATALOGUE_ZIP" -d "$CATALOGUE_DIR"

# Run the catalogue generation script just in case people have forgotten things...
/opt/muos/script/system/catalogue.sh

$CATALOGUE_NAME=$(basename "$CATALOGUE_ZIP" .zip)
CLEANED_CATALOGUE_NAME=$(echo "$CATALOGUE_NAME" | sed -E 's/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$//')
echo "$CLEANED_CATALOGUE_NAME" >"$CATALOGUE_DIR/catalogue_name.txt"

sync
