#!/bin/sh

. /opt/muos/script/var/func.sh

IS_NORMAL_MODE && IS_HANDHELD_MODE && /opt/muos/script/mux/idle.sh start

HOTKEY_FIFO="$MUOS_RUN_DIR/hotkey"
[ -p "$HOTKEY_FIFO" ] || mkfifo "$HOTKEY_FIFO"

RETROWAIT="$(GET_VAR "config" "settings/advanced/retrowait")"
BOARD_NAME="$(GET_VAR "device" "board/name")"

CHARGE_ACTIVE=0
CHARGE_CHECK=0

HANDLE_HOTKEY() {
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
		RGB_MODE) RGBCLI -m up ;;
		RGB_BRIGHT_UP) RGBCLI -b up ;;
		RGB_BRIGHT_DOWN) RGBCLI -b down ;;
		RGB_COLOR_PREV) RGBCLI -c down ;;
		RGB_COLOR_NEXT) RGBCLI -c up ;;

		# "RetroArch Network Wait" combos:
		RETROWAIT_IGNORE) [ "$RETROWAIT" -eq 1 ] && echo ignore >"$MUOS_RUN_DIR/net_start" ;;
		RETROWAIT_MENU) [ "$RETROWAIT" -eq 1 ] && echo menu >"$MUOS_RUN_DIR/net_start" ;;
	esac
}

LID_CLOSED() {
	case "$BOARD_NAME" in
		rg34xx-sp | rg35xx-sp)
			HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"
			read -r VAL <"$HALL_KEY" 2>/dev/null || return 1
			[ "$VAL" -eq 0 ]
			;;
		*) return 1 ;;
	esac
}

SLEEP() {
	IS_NORMAL_MODE || return 0

	CURR_UPTIME=$(UPTIME 2>/dev/null)
	CURR_UPTIME=${CURR_UPTIME%%.*}
	[ -n "$CURR_UPTIME" ] || CURR_UPTIME=0

	LAST_RESUME=$(GET_VAR "system" "resume_uptime" 2>/dev/null)
	LAST_RESUME=${LAST_RESUME%%.*}
	[ -n "$LAST_RESUME" ] || LAST_RESUME=0

	# Time to go the fuck to sleep
	if [ $((CURR_UPTIME - LAST_RESUME)) -gt 5 ]; then
		SET_VAR "system" "resume_uptime" "$CURR_UPTIME"
		/opt/muos/script/system/suspend.sh
	fi
}

RGBCLI() {
	RGBCONTROLLER_DIR="$MUOS_SHARE_DIR/application/RGB Controller"

	LD_LIBRARY_PATH="$RGBCONTROLLER_DIR/libs:$LD_LIBRARY_PATH" \
		"$RGBCONTROLLER_DIR/love" "$RGBCONTROLLER_DIR/rgbcli" "$@"
}

while :; do
	/opt/muos/frontend/muhotkey >"$HOTKEY_FIFO" &
	MU_PID=$!

	while IFS= read -r HOTKEY <"$HOTKEY_FIFO"; do
		CHARGE_CHECK=$((CHARGE_CHECK + 1))
		if [ "$CHARGE_CHECK" -ge 32 ]; then
			if pgrep -x muxcharge >/dev/null 2>&1; then
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

	wait "$MU_PID" 2>/dev/null
	sleep 0.1
done
