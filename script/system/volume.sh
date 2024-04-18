#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <save/restore>"
	exit 1
fi

if [ "$1" = "save" ]; then
	alsactl -U store
	cp -f /var/lib/alsa/asound.state /opt/muos/config/volume.txt
	rm /var/lib/alsa/asound.state
fi

if [ "$1" = "restore" ]; then
	cp -f /opt/muos/config/volume.txt /var/lib/alsa/asound.state
	alsactl -U restore
fi

