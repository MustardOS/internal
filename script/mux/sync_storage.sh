#!/bin/sh

# Import muOS Functions
. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/storage.sh

if [ ! $GC_STO_THEME = "$DC_STO_ROM_MOUNT" ]; then
    if [ ! -d "$GC_STO_THEME/MUOS/theme/" ]; then
        mkdir -p "$GC_STO_THEME/MUOS/theme/"
    fi
    rsync -a "$DC_STO_ROM_MOUNT/MUOS/theme/" "$GC_STO_THEME/MUOS/theme/"
fi