#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "HOTKEY" "Hotkey daemon starting"

IS_NORMAL_MODE && IS_HANDHELD_MODE && /opt/muos/script/mux/idle.sh start

HOTKEY_FIFO="$MUOS_RUN_DIR/hotkey"

if [ ! -p "$HOTKEY_FIFO" ]; then
	LOG_DEBUG "$0" 0 "HOTKEY" "$(printf "Creating hotkey FIFO: '%s'" "$HOTKEY_FIFO")"
	rm -f "$HOTKEY_FIFO"
	mkfifo "$HOTKEY_FIFO" || {
		LOG_ERROR "$0" 0 "HOTKEY" "$(printf "Failed to create hotkey FIFO: '%s'" "$HOTKEY_FIFO")"
		exit 1
	}
fi

exec 3<>"$HOTKEY_FIFO"

RETROWAIT="$(GET_VAR "config" "settings/advanced/retrowait")"
BOARD_NAME="$(GET_VAR "device" "board/name")"

CHARGE_ACTIVE=0
CHARGE_CHECK=0
MU_PID=0

HANDLE_HOTKEY() {
	LOG_DEBUG "$0" 0 "HOTKEY" "$(printf "Hotkey received: '%s'" "$1")"
	# This blocks the event loop, so commands here should finish quickly.
	case "$1" in
		# Input activity/idle:
		IDLE_ACTIVE) IS_NORMAL_MODE && IS_HANDHELD_MODE && DISPLAY_ACTIVE ;;
		IDLE_DISPLAY)
			IDLE_DISPLAY_CFG="$(GET_VAR "config" "settings/power/idle_display")"
			[ "$IDLE_DISPLAY_CFG" -gt 0 ] && IS_NORMAL_MODE && IS_HANDHELD_MODE && DISPLAY_IDLE
			;;
		IDLE_SLEEP)
			IDLE_SLEEP_CFG="$(GET_VAR "config" "settings/power/idle_sleep")"
			[ "$IDLE_SLEEP_CFG" -gt 0 ] && IS_NORMAL_MODE && IS_HANDHELD_MODE && SLEEP
			;;

		SLEEP_SHORT | SLEEP_LONG) SLEEP ;;

			# RGB combos:
			#		RGB_MODE) RGBCLI -m up ;;
			#		RGB_BRIGHT_UP) RGBCLI -b up ;;
			#		RGB_BRIGHT_DOWN) RGBCLI -b down ;;
			#		RGB_COLOR_PREV) RGBCLI -c down ;;
			#		RGB_COLOR_NEXT) RGBCLI -c up ;;

		# "RetroArch Network Wait" combos:
		RETROWAIT_IGNORE) [ "$RETROWAIT" -eq 1 ] && printf "%s" ignore >"$MUOS_RUN_DIR/net_start" ;;
		RETROWAIT_MENU) [ "$RETROWAIT" -eq 1 ] && printf "%s" menu >"$MUOS_RUN_DIR/net_start" ;;
	esac
}

LID_CLOSED() {
	case "$BOARD_NAME" in
		rg34xx-sp | rg35xx-sp)
			HALL_KEY="$(cat "$(GET_VAR "device" "board/hall")")"
			read -r VAL <"$HALL_KEY" 2>/dev/null || return 1
			[ "$VAL" -eq 0 ]
			;;
		*) return 1 ;;
	esac
}

SLEEP() {
	IS_NORMAL_MODE || return 0

	# Global caffeinated override
	[ -f "$MUOS_RUN_DIR/caffeine" ] && return 0

	# Prevent sleep immediately after resume
	[ -f "$MUOS_RUN_DIR/recent_wake" ] && return 0

	# Ignore if our lid switch is disabled
	case "$BOARD_NAME" in
		rg34xx-sp | rg35xx-sp) [ "$(GET_VAR "config" "settings/advanced/lidswitch")" -eq 0 ] && return 0 ;;
	esac

	CURR_UPTIME=$(UPTIME 2>/dev/null)
	CURR_UPTIME=${CURR_UPTIME%%.*}
	[ -n "$CURR_UPTIME" ] || CURR_UPTIME=0

	LAST_RESUME=$(GET_VAR "system" "resume_uptime" 2>/dev/null)
	LAST_RESUME=${LAST_RESUME%%.*}
	[ -n "$LAST_RESUME" ] || LAST_RESUME=0

	# Time to go the fuck to sleep
	if [ $((CURR_UPTIME - LAST_RESUME)) -gt 5 ]; then
		LOG_INFO "$0" 0 "HOTKEY" "Triggering system suspend"
		SET_VAR "system" "resume_uptime" "$CURR_UPTIME"
		/opt/muos/script/system/suspend.sh
	fi
}

START_MUHOTKEY() {
	LOG_DEBUG "$0" 0 "HOTKEY" "Starting muhotkey backend"
	/opt/muos/frontend/muhotkey >&3 &
	MU_PID=$!
}

STOP_MUHOTKEY() {
	[ "$MU_PID" -gt 0 ] && LOG_DEBUG "$0" 0 "HOTKEY" "$(printf "Stopping muhotkey backend (PID: %s)" "$MU_PID")"
	[ "$MU_PID" -gt 0 ] && kill "$MU_PID" 2>/dev/null
	wait "$MU_PID" 2>/dev/null
	MU_PID=0
}

# Ensure clean shutdown!
trap 'STOP_MUHOTKEY; exit 0' INT TERM

START_MUHOTKEY

while :; do
	# Restart if muhotkey kicked the bucket
	if ! kill -0 "$MU_PID" 2>/dev/null; then
		LOG_WARN "$0" 0 "HOTKEY" "muhotkey backend died - restarting"
		STOP_MUHOTKEY
		START_MUHOTKEY
	fi

	if ! IFS= read -r HOTKEY <&3; then
		continue
	fi

	[ -z "$HOTKEY" ] && continue
	[ -f "$MUOS_RUN_DIR/recent_wake" ] && continue

	CHARGE_CHECK=$((CHARGE_CHECK + 1))
	if [ "$CHARGE_CHECK" -ge 32 ]; then
		if pgrep -f muxcharge >/dev/null 2>&1; then
			CHARGE_ACTIVE=1
		else
			CHARGE_ACTIVE=0
		fi
		CHARGE_CHECK=0
	fi

	if [ "$CHARGE_CHECK" -eq 0 ]; then
		IS_NORMAL_MODE && IS_HANDHELD_MODE && /opt/muos/script/mux/idle.sh start
	fi

	# Don't respond to any hotkeys while in charge mode or with lid closed.
	if [ "$CHARGE_ACTIVE" -eq 1 ] || LID_CLOSED; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
