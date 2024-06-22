#!/bin/sh

echo "muxtask" > /tmp/fg_proc

nice --20 /opt/muos/extra/muxtask

while true; do
	if [ "$(cat /tmp/act_go)" = task ]; then
		echo app > /tmp/act_go
		nice --20 /opt/muos/extra/muxtask
	else
		echo app > /tmp/act_go
		break
	fi
done

