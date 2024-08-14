#!/bin/sh

. /opt/muos/script/var/func.sh

SLEEP() {
	cat "$(GET_VAR "device" "cpu/governor")" >/tmp/orig_cpu_gov
	echo "powersave" >"$(GET_VAR "device" "cpu/governor")"
	for C in $(seq 1 $((DC_CPU_CORES - 1))); do
		echo 0 >"/sys/devices/system/cpu/cpu${C}/online"
	done
}

RESUME() {
	cat "/tmp/orig_cpu_gov" >"$(GET_VAR "device" "cpu/governor")"
	for C in $(seq 1 $((DC_CPU_CORES - 1))); do
		echo 1 >"/sys/devices/system/cpu/cpu${C}/online"
	done
}

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <power|sleep|resume>"
	exit 1
fi

SUSPEND_PROC="golden.sh adbd pipewire sshd sftpgo gotty syncthing"

case "$1" in
	power)
		SLEEP
		sleep 0.1
		GET_VAR "global" "settings/advanced/state" >"/sys/power/state"
		sleep 0.1
		RESUME
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
