#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

DIRS="
ARCHIVE
BACKUP
MUOS/bios
MUOS/info/activity
MUOS/info/catalogue
MUOS/info/config
MUOS/info/core
MUOS/info/favourite
MUOS/info/history
MUOS/music
MUOS/save/drastic/backup
MUOS/save/drastic/savestates
MUOS/save/file
MUOS/save/state
MUOS/screenshot
MUOS/theme/active
MUOS/theme/preview
"

for DIR in $DIRS; do
	if [ ! -d "$DIR" ]; then
		mkdir -p "$1/$DIR"
	fi
done

/opt/muos/script/system/catalogue.sh "$1" &

if [ -z "$(find "$1/MUOS/info/config" -mindepth 1 -print -quit)" ]; then
	cp -R "$DC_STO_ROM_MOUNT/MUOS/info/config" "$1/MUOS/info"
fi

if [ -z "$(find "$1/MUOS/theme/active" -mindepth 1 -print -quit)" ]; then
	cp -R "$DC_STO_ROM_MOUNT/MUOS/theme/active" "$1/MUOS/theme"
fi
