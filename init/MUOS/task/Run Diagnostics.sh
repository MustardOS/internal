#!/bin/sh
# HELP: Run Diagnostics - A ZIP file will be generated on SD1 to send to the muOS crew!
# ICON: diagnostic

. /opt/muos/script/var/func.sh

pkill -STOP muxtask

# Set the output directory for the diagnostics
OUTPUT_DIR="/tmp/muos_diagnostics"
ARCHIVE_FILE="$(GET_VAR "device" "storage/rom/mount")/muOS_Diag_$(date +"%Y-%m-%d_%H-%M").zip"

# Create the output directory
mkdir -p "$OUTPUT_DIR"

echo "Collecting Basic System Information"
hostname >"$OUTPUT_DIR/hostname.log" 2>/dev/null
uname -a >"$OUTPUT_DIR/uname.log" 2>/dev/null
uptime >"$OUTPUT_DIR/uptime.log" 2>/dev/null
printenv >"$OUTPUT_DIR/env.log" 2>/dev/null
lsmod >"$OUTPUT_DIR/lsmod.log" 2>/dev/null

echo "Collecting CPU and Memory Information"
mkdir -p "$OUTPUT_DIR/cpumem"
cat /proc/cpuinfo >"$OUTPUT_DIR/cpumem/cpuinfo.log" 2>/dev/null
cat /proc/meminfo >"$OUTPUT_DIR/cpumem/meminfo.log" 2>/dev/null
cat /sys/class/thermal/thermal_zone0/temp >"$OUTPUT_DIR/cpumem/temp.log" 2>/dev/null

echo "Collecting Network Information"
mkdir -p "$OUTPUT_DIR/network"
ifconfig -a >"$OUTPUT_DIR/network/ifconfig.log" 2>/dev/null
netstat -tuln >"$OUTPUT_DIR/network/netstat.log" 2>/dev/null
ping -c 4 8.8.8.8 >"$OUTPUT_DIR/network/ping.log" 2>/dev/null
route -n >"$OUTPUT_DIR/network/route.log" 2>/dev/null

echo "Collecting Filesystem Information"
mkdir -p "$OUTPUT_DIR/filesystem"
cat /proc/mounts >"$OUTPUT_DIR/filesystem/mounts.log" 2>/dev/null
df -h >"$OUTPUT_DIR/filesystem/disk_usage.log" 2>/dev/null
lsblk -a >"$OUTPUT_DIR/filesystem/lsblk.log" 2>/dev/null
blkid >"$OUTPUT_DIR/filesystem/blkid.log" 2>/dev/null
fdisk -l >"$OUTPUT_DIR/filesystem/fdisk.log" 2>/dev/null

echo "Collecting Battery Information"
{
	printf "CAPACITY:\t%s\n" "$(cat "$(GET_VAR "device" "battery/capacity")")"
	printf "HEALTH:\t\t%s\n" "$(cat "$(GET_VAR "device" "battery/health")")"
	printf "VOLTAGE:\t%s\n" "$(cat "$(GET_VAR "device" "battery/voltage")")"
	printf "CHARGER:\t%s\n" "$(cat "$(GET_VAR "device" "battery/charger")")"
} >"$OUTPUT_DIR/battery.log" 2>/dev/null

# Capture a snapshot of top output over a 5 second interval - not the best but it'll do for now
echo "Capturing Top Processes"
top -b -n 5 -d 1 >"$OUTPUT_DIR/top.log" 2>/dev/null

echo "Adding Additional muOS Log Files"
LOG_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/log"
[ -d "$LOG_DIR" ] && cp -r "$LOG_DIR" "$OUTPUT_DIR/logs"

echo "Creating Diagnostic Archive"
cd "$OUTPUT_DIR" || exit 1
zip -r "$ARCHIVE_FILE" ./* >/dev/null 2>&1

# Clean up
rm -rf "$OUTPUT_DIR"

# Notify the user of the archive location
echo "muOS Diagnostics Collected: $ARCHIVE_FILE"
echo "Sync Filesystem"
sync

sleep 5

pkill -CONT muxtask
exit 0
