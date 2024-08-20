#!/bin/sh

. /opt/muos/script/var/func.sh

RUN_SYNC() {
	if [ "$1" != "$(GET_VAR "device" "storage/rom/mount")" ]; then
		if [ ! -d "$1/$2" ]; then
			mkdir -p "$1/$2"
		fi
		rsync -a "$(GET_VAR "device" "storage/rom/mount")/$2" "$1/$2"
	fi
}

case "$1" in
	theme)
		RUN_SYNC "$(GET_VAR "global" "storage/theme")" "MUOS/theme/"
		;;
	*) ;;
esac
