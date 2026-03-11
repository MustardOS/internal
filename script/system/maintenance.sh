#!/bin/sh
# -----------------------------------------------------------------------------
# muOS System Maintenance Utility
# Consolidates log cleaning, cruft removal, and system audits.
# -----------------------------------------------------------------------------

. /opt/muos/script/var/func.sh

RETENTION_DAYS=7
ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")
SD_MOUNT=$(GET_VAR "device" "storage/sdcard/mount")

#:] ### Log Cleaner
#:] Removes log files older than the retention period across system directories.
MAINT_CLEAN_LOGS() {
	LOG_INFO "$0" 0 "MAINT" "Starting log cleanup (Retention: $RETENTION_DAYS days)"
	
	# Clean system logs
	if [ -d "$MUOS_LOG_DIR" ]; then
		find "$MUOS_LOG_DIR" -type f -name '*.log' -mtime +"$RETENTION_DAYS" -exec rm -f -- {} \;
		LOG_INFO "$0" 0 "MAINT" "Cleaned system logs in $MUOS_LOG_DIR"
	fi

	# Clean ROM mount logs (consistent with existing LOG_CLEANER)
	if [ -d "$ROM_MOUNT" ]; then
		find "$ROM_MOUNT" -type f -name '*.log' -mtime +"$RETENTION_DAYS" -exec rm -f -- {} \;
		LOG_INFO "$0" 0 "MAINT" "Cleaned application logs in $ROM_MOUNT"
	fi
}

#:] ### Cruft Remover
#:] Wraps existing DELETE_CRUFT but adds logging and checks for SD card.
MAINT_CLEAN_CRUFT() {
	LOG_INFO "$0" 0 "MAINT" "Removing filesystem cruft (.DS_Store, Thumbs.db, etc.)"
	
	[ -d "$ROM_MOUNT" ] && DELETE_CRUFT "$ROM_MOUNT"
	[ -d "$SD_MOUNT" ] && DELETE_CRUFT "$SD_MOUNT"
	
	LOG_INFO "$0" 0 "MAINT" "Cruft removal background tasks started."
}

#:] ### System Audit
#:] Reports storage usage and core system status.
MAINT_SHOW_AUDIT() {
	printf "\n--- muOS System Audit ---\n"
	printf "Uptime: %s seconds\n" "$(UPTIME)"
	printf "\nStorage Usage:\n"
	df -h | grep -E 'Filesystem|/mnt/|/opt/'
	printf "\n--- End Audit ---\n"
}

# --- Main Entry ---

case "$1" in
	logs)
		MAINT_CLEAN_LOGS
		;;
	cruft)
		MAINT_CLEAN_CRUFT
		;;
	audit)
		MAINT_SHOW_AUDIT
		;;
	all)
		MAINT_CLEAN_LOGS
		MAINT_CLEAN_CRUFT
		MAINT_SHOW_AUDIT
		;;
	*)
		printf "Usage: %s {logs|cruft|audit|all}\n" "$0"
		exit 1
		;;
esac

exit 0
