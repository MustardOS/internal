#!/bin/sh

. /opt/muos/script/var/func.sh

/opt/muos/device/current/script/module.sh

if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
	/opt/muos/device/current/script/led_control.sh 2 255 225 173 1
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Setting date time to default"
date 010100002025
hwclock -w

EXEC_MUX "" "muxtimezone"
while [ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ]; do
	EXEC_MUX "" "muxrtc"
	[ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ] && EXEC_MUX "" "muxtimezone"
done

killall -9 mux*
/opt/muos/bin/toybox sleep 1

LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &
/usr/bin/mpv /opt/muos/share/media/factory.mp3 &

if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Generating SSH Host Keys"
	/opt/openssh/bin/ssh-keygen -A &
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Setting ARMHF Requirements"
if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
	LOG_INFO "$0" 0 "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
fi
ldconfig -v >"/opt/muos/ldconfig.log"

LOG_INFO "$0" 0 "FACTORY RESET" "Initialising Factory Reset Script"
/opt/muos/script/system/reset.sh

killall -q "mpv"

/opt/muos/bin/nosefart /opt/muos/share/media/support.nsf &
EXEC_MUX "" "muxcredits"

SET_VAR "global" "boot/factory_reset" "0"
SET_VAR "global" "settings/advanced/rumble" "0"

/opt/muos/script/mux/quit.sh reboot frontend
