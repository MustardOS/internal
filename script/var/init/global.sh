#!/bin/sh

. /opt/muos/script/var/func.sh

for INIT in boot clock network settings/general settings/advanced visual web storage; do
	case $INIT in
		"boot") VARS="factory_reset device_setup clock_setup firmware_done" ;;
		"clock") VARS="notation pool" ;;
		"network") VARS="enabled type ssid address gateway subnet dns" ;;
		"settings/general") VARS="hidden bgm sound startup power low_battery colour hdmi shutdown" ;;
		"settings/advanced") VARS="swap thermal font verbose volume brightness offset lock led random_theme retrowait android state" ;;
		"visual") VARS="battery network bluetooth clock boxart name dash contentfolder contentfile" ;;
		"web") VARS="shell browser terminal syncthing ntp" ;;
		"storage") VARS="bios config catalogue fav music save screenshot theme" ;;
	esac
	GEN_VAR "$(basename "$0" .sh)" "$INIT" "$VARS"
done
