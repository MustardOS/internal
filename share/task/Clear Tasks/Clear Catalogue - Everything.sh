#!/bin/sh
# HELP: Clear the entire catalogue and generate a clean one
# ICON: clear

. /opt/muos/script/var/func.sh

FRONTEND stop

CATALOGUE_DIR="$MUOS_STORE_DIR/info/catalogue"

[ -d "$CATALOGUE_DIR" ] && {
	printf "Purging catalogue directory: %s\n" "$CATALOGUE_DIR"
	find "$CATALOGUE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
}

echo "Generating Predefined Catalogue"
/opt/muos/script/system/catalogue.sh

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0
