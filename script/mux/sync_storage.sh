#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/storage.sh

RUN_SYNC() {
	if [ "$1" != "$DC_STO_ROM_MOUNT" ]; then
		if [ ! -d "$1/$2" ]; then
			mkdir -p "$1/$2"
		fi
		rsync -a "$DC_STO_ROM_MOUNT/$2" "$1/$2"
	fi
}

case "$1" in
	theme)
		RUN_SYNC "$GC_STO_THEME" "MUOS/theme/"
		;;
	*) ;;
esac
