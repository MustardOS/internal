#!/bin/sh
# HELP: Run Diagnostics - A ZIP file will be generated on SD1 to send to the MustardOS crew!
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "system_diagnostics" "System Diagnostics"


OUTPUT_DIR="/tmp/muos_diagnostics"
ARCHIVE_FILE="$(GET_VAR "device" "storage/rom/mount")/MustardOS_Diag_$(date +"%Y-%m-%d_%H-%M").zip"
LOG_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/log"
INT_DIR="/opt/muos"

mkdir -p "$OUTPUT_DIR/cpumem" "$OUTPUT_DIR/network" "$OUTPUT_DIR/filesystem/msd" "$OUTPUT_DIR/int"

COLLECT_BASIC() {
	TASK_STATUS "Collecting Basic System Information"
	hostname >"$OUTPUT_DIR/hostname.log" 2>/dev/null
	uname -a >"$OUTPUT_DIR/uname.log" 2>/dev/null
	uptime >"$OUTPUT_DIR/uptime.log" 2>/dev/null
	printenv >"$OUTPUT_DIR/env.log" 2>/dev/null
	lsmod >"$OUTPUT_DIR/lsmod.log" 2>/dev/null
}

COLLECT_CPUMEM() {
	TASK_STATUS "Collecting CPU and Memory Information"
	cat /proc/cpuinfo >"$OUTPUT_DIR/cpumem/cpuinfo.log" 2>/dev/null
	cat /proc/meminfo >"$OUTPUT_DIR/cpumem/meminfo.log" 2>/dev/null
	cat /sys/class/thermal/thermal_zone0/temp >"$OUTPUT_DIR/cpumem/temp.log" 2>/dev/null
}

COLLECT_NETWORK() {
	TASK_STATUS "Collecting Network Information"
	ifconfig -a >"$OUTPUT_DIR/network/ifconfig.log" 2>/dev/null
	netstat -tuln >"$OUTPUT_DIR/network/netstat.log" 2>/dev/null
	route -n >"$OUTPUT_DIR/network/route.log" 2>/dev/null
	cat /etc/resolv.conf >"$OUTPUT_DIR/network/resolv.log" 2>/dev/null

	ping -c 4 8.8.8.8 >"$OUTPUT_DIR/network/pingGoogle.log" 2>/dev/null &
	ping -c 4 1.1.1.1 >"$OUTPUT_DIR/network/pingCloudflare.log" 2>/dev/null &

	awk '/^nameserver/ { print $2 }' /etc/resolv.conf | while read -r NS; do
		ping -c 4 "$NS" >>"$OUTPUT_DIR/network/pingLocal.log" 2>/dev/null &
	done

	wait
}

COLLECT_FILESYSTEM() {
	TASK_STATUS "Collecting Filesystem Information"
	cat /proc/mounts >"$OUTPUT_DIR/filesystem/mounts.log" 2>/dev/null
	df -h >"$OUTPUT_DIR/filesystem/disk_usage.log" 2>/dev/null
	lsblk -a >"$OUTPUT_DIR/filesystem/lsblk.log" 2>/dev/null
	blkid >"$OUTPUT_DIR/filesystem/blkid.log" 2>/dev/null
	fdisk -l >"$OUTPUT_DIR/filesystem/fdisk.log" 2>/dev/null
	cp /tmp/msd_check/* >"$OUTPUT_DIR/filesystem/msd/" 2>/dev/null
}

COLLECT_BATTERY() {
	TASK_STATUS "Collecting Battery Information"
	{
		printf "CAPACITY:\t%s\n" "$(cat "$MUOS_RUN_DIR/battery/capacity")"
		printf "HEALTH:\t\t%s\n" "$(cat "$(GET_VAR "device" "battery/health")")"
		printf "VOLTAGE:\t%s\n" "$(cat "$MUOS_RUN_DIR/battery/voltage")"
		printf "CHARGER:\t%s\n" "$(cat "$MUOS_RUN_DIR/battery/charger")"
	} >"$OUTPUT_DIR/battery.log" 2>/dev/null
}

COLLECT_PROCESSES() {
	TASK_STATUS "Capturing Top Processes"
	top -b -n 3 -d 1 >"$OUTPUT_DIR/top.log" 2>/dev/null
	TASK_STATUS "Capturing All Processes"
	ps -ef >"$OUTPUT_DIR/ps.log" 2>/dev/null
}

COLLECT_KERNEL() {
	TASK_STATUS "Collecting Kernel Messages"
	dmesg >"$OUTPUT_DIR/dmesg.log" 2>/dev/null
}

COLLECT_LOGS() {
	TASK_STATUS "Collecting Storage Log Files"
	[ -d "$LOG_DIR" ] && cp -r "$LOG_DIR" "$OUTPUT_DIR/logs"

	TASK_STATUS "Collecting Internal Log Files"
	[ -d "$INT_DIR/log" ] && cp -r "$INT_DIR/log" "$OUTPUT_DIR/int/"
	[ -f "$INT_DIR/halt.log" ] && cp "$INT_DIR/halt.log" "$OUTPUT_DIR/int/"
	[ -f "$INT_DIR/ldconfig.log" ] && cp "$INT_DIR/ldconfig.log" "$OUTPUT_DIR/int/"
}

COLLECT_VARS() {
	TASK_STATUS "Collecting Config Variables"
	find /opt/muos/config -type f | while read -r FILE; do
		RELPATH="${FILE#/opt/muos/config/}"
		echo "$RELPATH" | grep -qE 'network/pass|network/ssid' && continue
		{
			printf '%s: ' "$RELPATH"
			cat "$FILE" 2>/dev/null
			echo
		} >>"$OUTPUT_DIR/config.log"
	done

	TASK_STATUS "Collecting Device Variables"
	find /opt/muos/device/config -type f | while read -r FILE; do
		RELPATH="${FILE#/opt/muos/device/config/}"
		{
			printf '%s: ' "$RELPATH"
			cat "$FILE" 2>/dev/null
			echo
		} >>"$OUTPUT_DIR/device.log"
	done

	TASK_STATUS "Collecting Kiosk Variables"
	find /opt/muos/kiosk -type f | while read -r FILE; do
		RELPATH="${FILE#/opt/muos/kiosk/}"
		{
			printf '%s: ' "$RELPATH"
			cat "$FILE" 2>/dev/null
			echo
		} >>"$OUTPUT_DIR/kiosk.log"
	done
}

COLLECT_BASIC &
COLLECT_CPUMEM &
COLLECT_FILESYSTEM &
COLLECT_STORAGE_HEALTH &
COLLECT_BATTERY &
COLLECT_KERNEL &
COLLECT_VARS &
COLLECT_LOGS &
COLLECT_PROCESSES &
COLLECT_NETWORK &

wait

TASK_STATUS "Creating Diagnostic Archive"
cd "$OUTPUT_DIR" || exit 1
zip -r "$ARCHIVE_FILE" ./* >/dev/null 2>&1

rm -rf "$OUTPUT_DIR"

TASK_STATUS "Diagnostics Collected: $ARCHIVE_FILE"
TASK_STATUS "Sync Filesystem"
sync

sleep 3

exit 0
