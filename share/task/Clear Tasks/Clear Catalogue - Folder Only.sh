#!/bin/sh
# HELP: Clear the Folder directory within the catalogue
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

CATALOGUE_DIR="$MUOS_STORE_DIR/info/catalogue"

[ -d "$CATALOGUE_DIR" ] && {
	printf "Purging 'Folder' from catalogue: %s\n" "$CATALOGUE_DIR/Folder"
	rm -rf "$CATALOGUE_DIR/Folder"
}

echo "Generating Predefined Catalogue"
/opt/muos/script/system/catalogue.sh

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

FRONTEND start task
exit 0
