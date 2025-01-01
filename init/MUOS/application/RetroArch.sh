#!/bin/sh
# HELP: RetroArch
# ICON: retroarch

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

export HOME=$(GET_VAR "device" "board/home")

SET_VAR "system" "foreground_process" "retroarch"

RA_CONF=/run/muos/storage/info/config/retroarch.cfg

# Include default button mappings from retroarch.device.cfg. (Settings in the
# retroarch.cfg will take precedence. Modified settings will save to the main
# retroarch.cfg, not the included retroarch.device.cfg.)
sed -n -e '/^#include /!p' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.device.cfg"' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.resolution.cfg"' \
	-i "$RA_CONF"

nice --20 /usr/bin/retroarch -v -f -c "$RA_CONF"
