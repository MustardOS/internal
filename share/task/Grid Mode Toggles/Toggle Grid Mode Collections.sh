#!/bin/sh
# HELP: Toggle Grid Mode Collections
# ICON: theme
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

# Created for muOS 2502.0 Pixie +
# This script will enable or disable Grid mode for collections
# by updating the muxcollect.ini theme override file

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "toggle_grid_mode_collections" "Toggle Grid Mode Collections"


INI_FILE="$MUOS_STORE_DIR/theme/override/muxcollect.ini"
GRID_SECTION="[grid]"
COLUMN_SETTING="COLUMN_COUNT = 0"
ROW_SETTING="ROW_COUNT = 0"

mkdir -p "$(dirname "$INI_FILE")"

if grep -qFx "$GRID_SECTION" "$INI_FILE"; then
    if grep -qFx "$COLUMN_SETTING" "$INI_FILE" && grep -qFx "$ROW_SETTING" "$INI_FILE"; then
		TASK_STATUS "Enabling Grid Mode for collections"
        sed -i "/$COLUMN_SETTING/d" "$INI_FILE"
        sed -i "/$ROW_SETTING/d" "$INI_FILE"
    else
		TASK_STATUS "Disabling Grid Mode for collections"
        awk -v col="$COLUMN_SETTING" -v row="$ROW_SETTING" '
            /^\[grid\]$/ {print; found=1; next}
            found && NF==0 {print col "\n" row; found=0}
            {print}
            END {if (found) print col "\n" row}
        ' "$INI_FILE" > /tmp/temp.ini && mv /tmp/temp.ini "$INI_FILE"
    fi
else
	TASK_STATUS "Disabling Grid Mode for collections"
    echo -e "\n$GRID_SECTION\n$COLUMN_SETTING\n$ROW_SETTING" >> "$INI_FILE"
fi

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Toggle Grid Mode Collections"

exit 0
