#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$(GET_VAR "device" "led/rgb")" -eq 1 ]; then
	case "$(GET_VAR "device" "board/name")" in
		rg*) /opt/muos/script/device/rgb.sh 2 255 225 173 1 ;;
		tui-brick) /opt/muos/script/device/rgb.sh 1 10 225 173 1 225 173 1 225 173 1 225 173 1 225 173 1 ;;
		tui-spoon) /opt/muos/script/device/rgb.sh 1 10 225 173 1 225 173 1 225 173 1 ;;
		*) ;;
	esac
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Setting date time to default"
date 010100002025
hwclock -w

while pgrep "muxwarn" >/dev/null 2>&1; do TBOX sleep 1; done

printf "timezone" >"/tmp/act_go"
EXEC_MUX "reset" "muxfrontend"

printf 0 >"/tmp/msg_progress"
[ -f "/tmp/msg_finish" ] && rm -f "/tmp/msg_finish"

/opt/muos/frontend/muxmessage 0 "/opt/muos/share/message.txt" -d 5

LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &
/usr/bin/mpv --really-quiet "/opt/muos/share/media/factory.mp3" &

LOG_INFO "$0" 0 "FACTORY RESET" "Generating SSH Host Keys"
/opt/openssh/bin/ssh-keygen -A &

LOG_INFO "$0" 0 "FACTORY RESET" "Setting ARMHF Requirements"
if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
	LOG_INFO "$0" 0 "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s "/lib32/ld-linux-armhf.so.3" "/lib/ld-linux-armhf.so.3"
fi
ldconfig -v >"/opt/muos/ldconfig.log"

LOG_INFO "$0" 0 "FACTORY RESET" "Initialising Factory Reset Script"
/opt/muos/script/system/reset.sh

touch "/tmp/msg_finish"
TBOX sleep 1
killall -q "mpv"

/opt/muos/bin/nosefart "/opt/muos/share/media/support.nsf" &
/opt/muos/frontend/muxcredits

SET_VAR "config" "boot/factory_reset" "0"
SET_VAR "config" "settings/advanced/rumble" "0"
