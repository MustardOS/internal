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
date 010100002026
hwclock -w

while pgrep "muxwarn" >/dev/null 2>&1; do sleep 0.25; done

printf "installer" >"/tmp/act_go"
/opt/muos/script/mux/install.sh

printf 0 >"/tmp/msg_progress"
[ -f "/tmp/msg_finish" ] && rm -f "/tmp/msg_finish"

/opt/muos/frontend/muxmessage 0 "$MUOS_SHARE_DIR/message.txt" -d 5

LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &
/usr/bin/mpv --really-quiet "$MUOS_SHARE_DIR/media/factory.mp3" &

LOG_INFO "$0" 0 "FACTORY RESET" "Generating SSH Host Keys"
/opt/openssh/bin/ssh-keygen -A &

LOG_INFO "$0" 0 "FACTORY RESET" "Setting ARMHF Requirements"
ARMHF="ld-linux-armhf.so.3"
if [ ! -f "/lib/${ARMHF}" ]; then
	LOG_INFO "$0" 0 "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s "/lib32/${ARMHF}" "/lib/${ARMHF}"
fi
ldconfig -v >"/opt/muos/ldconfig.log"

LOG_INFO "$0" 0 "FACTORY RESET" "Initialising Factory Reset Script"
/opt/muos/script/system/reset.sh

touch "/tmp/msg_finish"
sleep 1
killall -q "mpv"

EXFAT_NATIVE=0
if zcat /proc/config.gz 2>/dev/null | grep -q "^CONFIG_EXFAT_FS=y"; then
	EXFAT_NATIVE=1
	LOG_INFO "$0" 0 "FACTORY RESET" "Built-in exFAT detected via kernel config"
elif grep -qw exfat /proc/filesystems 2>/dev/null; then
	EXFAT_NATIVE=1
	LOG_INFO "$0" 0 "FACTORY RESET" "Native exFAT detected via /proc/filesystems"
fi

if [ "$EXFAT_NATIVE" = "1" ]; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Kernel mount supports exFAT, removing FUSE helper"
	# This seems crazy but it works!
	rm -f /sbin/mount.exfat /sbin/mount.exfat-fuse
else
	LOG_INFO "$0" 0 "FACTORY RESET" "Relying on FUSE mount.exfat"
fi

/opt/muos/bin/nosefart "$MUOS_SHARE_DIR/media/support.nsf" &
/opt/muos/frontend/muxcredits

SET_VAR "config" "boot/factory_reset" "0"
SET_VAR "config" "settings/advanced/rumble" "0"
SET_VAR "config" "settings/power/screensaver" "90"
