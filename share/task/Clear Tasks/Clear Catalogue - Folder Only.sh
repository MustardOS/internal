#!/bin/sh
# HELP: Clear the Folder directory within the catalogue
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_catalogue_folder_only" "Clear Catalogue - Folder Only"


CATALOGUE_DIR="$MUOS_STORE_DIR/info/catalogue"

[ -d "$CATALOGUE_DIR" ] && {
	printf "Purging 'Folder' from catalogue: %s\n" "$CATALOGUE_DIR/Folder"
	rm -rf "$CATALOGUE_DIR/Folder"
}

TASK_STATUS "Generating Predefined Catalogue"
/opt/muos/script/system/catalogue.sh

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear Catalogue - Folder Only"

exit 0
