#!/bin/sh
# HELP: Boot and Services Report - Checks boot health, safe mode, background services and recent errors, then saves a report to SD1
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "boot_services_report" "Boot and Services Report"

DIAG_SECTION "Boot health"
DIAG_KV "Boot attempts" "$(DIAG_READ "$BOOT_STATE_DIR/attempt_count")"
DIAG_KV "Boot confirmed" "$([ -e "$BOOT_CONFIRMED_FLAG" ] && printf yes || printf no)"
DIAG_KV "Safe mode" "$([ -e "$SAFE_MODE_FLAG" ] && printf yes || printf no)"
DIAG_KV "Device mode" "$(GET_VAR "config" "boot/device_mode" 2>/dev/null)"
DIAG_KV "Factory reset pending" "$(GET_VAR "config" "boot/factory_reset" 2>/dev/null)"
DIAG_KV "Debug mode" "$(GET_VAR "config" "system/debug_mode" 2>/dev/null)"
DIAG_KV "Kernel taint" "$(DIAG_READ /proc/sys/kernel/tainted)"
[ -e "$SAFE_MODE_FLAG" ] && DIAG_FINDING "BOOT" "muOS started in safe mode after repeated failed boots."
[ -e "$BOOT_CONFIRMED_FLAG" ] || DIAG_FINDING "BOOT" "This boot was never confirmed as good. Another failed boot may trigger safe mode."
DIAG_CONFIG "$BOOT_STATE_DIR"

DIAG_SECTION "Frontend"
if FRONTEND_RUNNING; then
	DIAG_KV "muxfrontend" "running ($(GET_FRONTEND_PIDS))"
else
	DIAG_KV "muxfrontend" "not running"
fi
DIAG_KV "Foreground process" "$(DIAG_READ "$MUOS_CONF_SYSTEM/foreground_process")"

DIAG_SECTION "Tracked services"
for PID_FILE in /run/muos/process/*.pid; do
	[ -f "$PID_FILE" ] || continue
	NAME=$(basename "$PID_FILE" .pid)
	PID=$(DIAG_READ "$PID_FILE" | head -n 1)
	if DIAG_IS_NUM "$PID" && [ -d "/proc/$PID" ]; then
		DIAG_KV "$NAME" "running ($PID, $(DIAG_READ "/proc/$PID/comm"))"
	else
		DIAG_KV "$NAME" "finished or stopped (was ${PID:-unknown})"
		case "$NAME" in
			battery | hotkey | lowpower) DIAG_FINDING "SERVICE" "The $NAME service is not running, but it should run all the time." ;;
		esac
	fi
done
for DAEMON in muhotkey mubattery muinput pipewire wireplumber dbus-daemon; do
	DIAG_RUNNING "$DAEMON" && DIAG_KV "$DAEMON" "running" || DIAG_KV "$DAEMON" "not running"
done

DIAG_SECTION "Recent logs"
LOG_ROOT="$(GET_VAR "device" "storage/rom/mount" 2>/dev/null)/MUOS/log"
DIAG_OUT "-- Newest log files"
NEWEST_LOGS=$(ls -t "$MUOS_LOG_DIR"/*.log "$LOG_ROOT"/*.log "$LOG_ROOT"/*/*.log 2>/dev/null | head -n 15)
printf '%s\n' "$NEWEST_LOGS" | DIAG_APPEND
for LOG in $NEWEST_LOGS; do
	grep -iE "error|fail|critical" "$LOG" 2>/dev/null | tail -n 5 | sed "s|^|$(basename "$LOG"): |"
done | tail -n 60 | DIAG_APPEND
[ -f /opt/muos/halt.log ] && DIAG_OUT "-- Last shutdown" && tail -n 30 /opt/muos/halt.log | DIAG_APPEND

DIAG_SECTION "Kernel problems since boot"
DIAG_DMESG "Internal error|Oops:|Kernel panic|segfault|BUG:|Call trace|hung task|watchdog|Unable to handle|blocked for more" 40
CRASHES=$(dmesg 2>/dev/null | grep -cE "Internal error|Oops:|Kernel panic|Unable to handle kernel|Call trace:")
[ "${CRASHES:-0}" -gt 0 ] && DIAG_FINDING "KERNEL" "The kernel logged $CRASHES crash traces since boot."
SEGFAULTS=$(dmesg 2>/dev/null | grep -ci "segfault")
[ "${SEGFAULTS:-0}" -gt 0 ] && DIAG_FINDING "INFO" "Programs crashed with a segmentation fault $SEGFAULTS time(s) since boot."
DIAG_DMESG "error|fail" 60

DIAG_FINISH "Boot and services report saved"
exit 0
