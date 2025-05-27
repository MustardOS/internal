#!/bin/sh

. /opt/muos/script/var/func.sh

LED_RGB="$(GET_VAR "device" "led/rgb")"
NETWORK_ENABLED="$(GET_VAR "device" "board/network")"

if [ "$LED_RGB" -eq 1 ]; then
	case "$(GET_VAR "device" "board/name")" in
		rg*) /opt/muos/device/current/script/led_control.sh 2 255 225 173 1 ;;
		tui-brick) /opt/muos/device/current/script/led_control.sh 1 10 225 173 1 225 173 1 225 173 1 225 173 1 225 173 1 ;;
		tui-spoon) /opt/muos/device/current/script/led_control.sh 1 10 225 173 1 225 173 1 225 173 1 ;;
		*) ;;
	esac
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Setting date time to default"
date 010100002025
hwclock -w

printf "timezone" >"/tmp/act_go"
EXEC_MUX "reset" "muxfrontend"

printf 0 >"/tmp/msg_progress"
[ -f "/tmp/msg_finish" ] && rm -f "/tmp/msg_finish"

/opt/muos/extra/muxstart 0 "/opt/muos/config/messages.txt" -d 5

LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &
/usr/bin/mpv /opt/muos/share/media/factory.mp3 &

if [ "$NETWORK_ENABLED" -eq 1 ]; then
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
