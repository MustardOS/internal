#!/bin/sh
# HELP: Archive Manager
# ICON: archive

. /opt/muos/script/var/func.sh

SET_VAR "system" "foreground_process" "muxarchive"

nice --20 /opt/muos/extra/muxarchive

while :; do
	if [ "$(cat /tmp/act_go)" = archive ]; then
		echo app >/tmp/act_go
		nice --20 /opt/muos/extra/muxarchive
	else
		echo app >/tmp/act_go
		break
	fi
done
