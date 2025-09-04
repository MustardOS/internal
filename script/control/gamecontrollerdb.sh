#!/bin/sh

. /opt/muos/script/var/func.sh

# Move gamecontrollerdb files - overwrite existing for users protection!
GCDB_STORE="/opt/muos/share/info/gamecontrollerdb"

[ -d "$GCDB_STORE" ] || mkdir -p "$GCDB_STORE"
cp -f "$DEVICE_CONTROL_DIR/gamecontrollerdb"/*.txt "$GCDB_STORE"/

# Purge anything with the 'system' reserved name!
rm -f "$GCDB_STORE/system.txt"
touch "$GCDB_STORE/system.txt"
