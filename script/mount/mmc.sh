#!/bin/sh

. /opt/muos/script/var/func.sh

if mount -t "$(GET_VAR "device" "storage/rom/type")" -o rw,utf8,noatime,nofail \
	/dev/"$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")" \
	"$(GET_VAR "device" "storage/rom/mount")"; then
	SET_VAR "device" "storage/rom/active" "1"
fi
