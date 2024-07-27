#!/bin/sh

DIRS="
ARCHIVE
BACKUP
MUOS/bios
MUOS/info/activity
MUOS/info/catalogue
MUOS/info/config
MUOS/info/favourite
MUOS/info/history
MUOS/music
MUOS/save/drastic/backup
MUOS/save/drastic/savestates
MUOS/save/file
MUOS/save/state
MUOS/screenshot
MUOS/theme
"

for DIR in $DIRS; do
	if [ ! -d "$DIR" ]; then
		mkdir -p "$1/$DIR"
	fi
done

/opt/muos/script/system/catalogue.sh "$1" &
cp -R "/mnt/mmc/MUOS/info/config" "$1/MUOS/info/config"
