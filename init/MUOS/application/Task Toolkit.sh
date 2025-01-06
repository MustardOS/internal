#!/bin/sh
# HELP: Task Toolkit
# ICON: task

. /opt/muos/script/var/func.sh

SET_VAR "system" "foreground_process" "muxtask"

nice --20 /opt/muos/extra/muxtask

while :; do
	if [ "$(cat /tmp/act_go)" = task ]; then
		echo app >/tmp/act_go
		nice --20 /opt/muos/extra/muxtask
	else
		echo app >/tmp/act_go
		break
	fi
done
