#!/bin/sh

echo "muxarchive" >/tmp/fg_proc

nice --20 /opt/muos/extra/muxarchive

while true; do
	if [ "$(cat /tmp/act_go)" = archive ]; then
		echo app >/tmp/act_go
		nice --20 /opt/muos/extra/muxarchive
	else
		echo app >/tmp/act_go
		break
	fi
done
