#!/bin/sh
# HELP: Clear the entire catalogue and generate a clean one
# ICON: clear
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "clear_catalogue_everything" "Clear Catalogue - Everything"


CATALOGUE_DIR="$MUOS_STORE_DIR/info/catalogue"

[ -d "$CATALOGUE_DIR" ] && {
	printf "Purging catalogue directory: %s\n" "$CATALOGUE_DIR"
	find "$CATALOGUE_DIR" -mindepth 1 -exec rm -rf {} + 2>/dev/null
}

TASK_STATUS "Generating Predefined Catalogue"
/opt/muos/script/system/catalogue.sh

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Clear Catalogue - Everything"

exit 0
