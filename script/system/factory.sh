#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "FACTORY RESET" "Setting date time to default"
date 010100002026
hwclock -w

while pgrep "muwarn" >/dev/null 2>&1; do sleep 0.25; done

/opt/muos/script/device/amp.sh
/opt/muos/script/device/speaker.sh

printf "installer" >"$ACT_GO"
/opt/muos/script/mux/install.sh

printf 0 >"/tmp/msg_progress"
[ -f "/tmp/msg_finish" ] && rm -f "/tmp/msg_finish"

LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
HOTKEY start

/opt/muos/frontend/muxmessage 0 "$MUOS_SHARE_DIR/message.txt" -d 5

/usr/bin/mpv --really-quiet "$MUOS_SHARE_DIR/media/factory.mp3" &

LOG_INFO "$0" 0 "FACTORY RESET" "Generating SSH Host Keys"
if [ -x /opt/openssh/sbin/sshd ]; then
	/opt/openssh/bin/ssh-keygen -A &
elif [ -x /usr/sbin/sshd ]; then
	/usr/bin/ssh-keygen -A &
fi

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

if EXFAT_NATIVE_BUILTIN; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Built-in exFAT support active, removing FUSE helper"
	# This seems crazy but it works!
	rm -f /sbin/mount.exfat /sbin/mount.exfat-fuse
elif EXFAT_NATIVE_READY; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Native exFAT module active"
else
	LOG_INFO "$0" 0 "FACTORY RESET" "Using FUSE exFAT fallback"
fi

CREDITS_DIR="/tmp/mustardos"
CREDITS_COMPLETE="$CREDITS_DIR/mucredits.complete"
mkdir -p "$CREDITS_DIR"
rm -f "$CREDITS_COMPLETE"

/opt/muos/frontend/mucredits &
CREDITS_PID=$!
CREDITS_GRACE=0

while [ -r "/proc/$CREDITS_PID/stat" ]; do
	read -r _ _ CREDITS_STATE _ <"/proc/$CREDITS_PID/stat" 2>/dev/null || break
	[ "$CREDITS_STATE" = Z ] && break

	if [ -e "$CREDITS_COMPLETE" ]; then
		CREDITS_GRACE=$((CREDITS_GRACE + 1))
		[ "$CREDITS_GRACE" -eq 50 ] && kill -TERM "$CREDITS_PID" 2>/dev/null
		if [ "$CREDITS_GRACE" -ge 60 ]; then
			kill -KILL "$CREDITS_PID" 2>/dev/null
			break
		fi
	fi

	sleep 0.1
done

if [ ! -r "/proc/$CREDITS_PID/stat" ]; then
	wait "$CREDITS_PID" 2>/dev/null
else
	read -r _ _ CREDITS_STATE _ <"/proc/$CREDITS_PID/stat" 2>/dev/null
	[ "$CREDITS_STATE" = Z ] && wait "$CREDITS_PID" 2>/dev/null
fi

rm -f "$CREDITS_COMPLETE"

SET_VAR_DURABLE "config" "boot/factory_reset" "0"
SET_VAR_DURABLE "config" "settings/advanced/rumble" "0"
SET_VAR_DURABLE "config" "settings/power/saver_type" "1"
