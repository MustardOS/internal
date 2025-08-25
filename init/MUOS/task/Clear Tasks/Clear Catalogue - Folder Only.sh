#!/bin/sh
# HELP: Clear the Folder directory within the catalogue
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

CATALOGUE_DIR="/run/muos/storage/info/catalogue"

[ -d "$CATALOGUE_DIR" ] && {
	printf "Purging 'Folder' from catalogue: %s\n" "$CATALOGUE_DIR/Folder"
	rm -rf "$CATALOGUE_DIR/Folder"
}

echo "Generating Predefined Catalogue"
/opt/muos/script/system/catalogue.sh "$(GET_VAR "device" "storage/rom/mount")"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
