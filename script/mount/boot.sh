#!/bin/sh

. /opt/muos/script/var/func.sh

if mount -t "$(GET_VAR "device" "storage/boot/type")" -o rw,utf8,noatime,nofail \
	/dev/"$(GET_VAR "device" "storage/boot/dev")$(GET_VAR "device" "storage/boot/sep")$(GET_VAR "device" "storage/boot/num")" \
	"$(GET_VAR "device" "storage/boot/mount")"; then
	SET_VAR "device" "storage/boot/active" "1"
fi
