#!/bin/sh

. /opt/muos/script/var/func.sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo app >/tmp/act_go

export HOME=$(GET_VAR "device" "board/home")

SET_VAR "system" "foreground_process" "retroarch"

nice --20 /usr/bin/retroarch -v -f -c "$(GET_VAR "device" "storage/rom/mount")/MUOS/retroarch/retroarch.cfg"
