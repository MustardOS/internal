#!/bin/sh

. /opt/muos/script/var/func.sh

SLEEP() {
	cat "$(GET_VAR "device" "cpu/governor")" >/tmp/orig_cpu_gov
	echo "powersave" >"$(GET_VAR "device" "cpu/governor")"
	for C in $(seq 1 $(("$(GET_VAR "device" "cpu/cores")" - 1))); do
		echo 0 >"/sys/devices/system/cpu/cpu${C}/online"
	done

	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
	fi

	case "$(GET_VAR "global" "settings/advanced/rumble")" in
		3 | 5 | 6) RUMBLE "$(GET_VAR "device" "board/rumble")" 0.3 ;;
		*) ;;
	esac
}

RESUME() {
	cat "/tmp/orig_cpu_gov" >"$(GET_VAR "device" "cpu/governor")"
	for C in $(seq 1 $(("$(GET_VAR "device" "cpu/cores")" - 1))); do
		echo 1 >"/sys/devices/system/cpu/cpu${C}/online"
	done

	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
		if [ -f "$RGBCONF_SCRIPT" ]; then
			"$RGBCONF_SCRIPT"
		else
			/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
		fi
	fi
}

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <power|sleep|resume>"
	exit 1
fi

SUSPEND_PROC="adbd pipewire sshd sftpgo ttyd syncthing rslsync tailscaled"

case "$1" in
	power)
		SLEEP
		sleep 0.1
		GET_VAR "global" "settings/advanced/state" >"/sys/power/state"
		sleep 0.1
		RESUME
		SET_VAR "system" "resume_uptime" "$(UPTIME)"
		;;
	sleep)
		for PROC in $SUSPEND_PROC; do
			pkill -STOP "$PROC"
		done
		SLEEP
		;;
	resume)
		for PROC in $SUSPEND_PROC; do
			pkill -CONT "$PROC"
		done
		RESUME
		;;
	*)
		echo "Invalid mode: $1"
		echo "Usage: $0 <power|sleep|resume>"
		exit 1
		;;
esac
