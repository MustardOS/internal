#!/bin/sh
# HELP: Toggle Grid Mode Collections
# ICON: theme

# Created for muOS 2502.0 Pixie +
# This script will enable or disable Grid mode for collections
# by updating the muxcollect.ini theme override file

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

INI_FILE="/run/muos/storage/theme/override/muxcollect.ini"
GRID_SECTION="[grid]"
COLUMN_SETTING="COLUMN_COUNT = 0"
ROW_SETTING="ROW_COUNT = 0"

mkdir -p "$(dirname "$INI_FILE")"

if grep -qFx "$GRID_SECTION" "$INI_FILE"; then
    if grep -qFx "$COLUMN_SETTING" "$INI_FILE" && grep -qFx "$ROW_SETTING" "$INI_FILE"; then
		echo "Enabling Grid Mode for collections"
        sed -i "/$COLUMN_SETTING/d" "$INI_FILE"
        sed -i "/$ROW_SETTING/d" "$INI_FILE"
    else
		echo "Disabling Grid Mode for collections"
        awk -v col="$COLUMN_SETTING" -v row="$ROW_SETTING" '
            /^\[grid\]$/ {print; found=1; next}
            found && NF==0 {print col "\n" row; found=0}
            {print}
            END {if (found) print col "\n" row}
        ' "$INI_FILE" > temp.ini && mv temp.ini "$INI_FILE"
    fi
else
	echo "Disabling Grid Mode for collections"
    echo -e "\n$GRID_SECTION\n$COLUMN_SETTING\n$ROW_SETTING" >> "$INI_FILE"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
/opt/muos/bin/toybox sleep 2

pkill -CONT muxtask
exit 0
