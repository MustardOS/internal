#!/bin/sh

. /opt/muos/script/var/func.sh

IS_NORMAL_MODE && IS_HANDHELD_MODE && . /opt/muos/script/mux/idle.sh

READ_HOTKEYS() {
	# Restart muhotkey if it exits. (tweak.sh kills it on config changes.)
	while :; do
		/opt/muos/frontend/muhotkey
	done
}

HANDLE_HOTKEY() {
	RETROWAIT="$(GET_VAR "config" "settings/advanced/retrowait")"

	# This blocks the event loop, so commands here should finish quickly.
	case "$1" in
		# Input activity/idle:
		IDLE_ACTIVE) IS_NORMAL_MODE && IS_HANDHELD_MODE && DISPLAY_ACTIVE ;;
		IDLE_DISPLAY) IS_NORMAL_MODE && IS_HANDHELD_MODE && DISPLAY_IDLE ;;
		IDLE_SLEEP) IS_NORMAL_MODE && IS_HANDHELD_MODE && SLEEP ;;

		# Power combos:
		SLEEP) SLEEP ;;

		# RGB combos:
		RGB_MODE) RGBCLI -m up ;;
		RGB_BRIGHT_UP) RGBCLI -b up ;;
		RGB_BRIGHT_DOWN) RGBCLI -b down ;;
		RGB_COLOR_PREV) RGBCLI -c down ;;
		RGB_COLOR_NEXT) RGBCLI -c up ;;

		# "RetroArch Network Wait" combos:
		RETROWAIT_IGNORE) [ "$RETROWAIT" -eq 1 ] && echo ignore >"/tmp/net_start" ;;
		RETROWAIT_MENU) [ "$RETROWAIT" -eq 1 ] && echo menu >"/tmp/net_start" ;;
	esac
}

LID_CLOSED() {
	case "$(GET_VAR "device" "board/name")" in
		rg34xx-sp | rg35xx-sp)
			HALL_KEY_FILE="/sys/class/power_supply/axp2202-battery/hallkey"
			[ "$(cat "$HALL_KEY_FILE")" -eq 0 ]
			;;
		*) false ;;
	esac
}

SLEEP() {
	if IS_NORMAL_MODE; then
		CURR_UPTIME="$(UPTIME 2>/dev/null | cut -d. -f1)"
		[ -n "$CURR_UPTIME" ] || CURR_UPTIME=0

		LAST_RESUME="$(GET_VAR "system" "resume_uptime" 2>/dev/null | cut -d. -f1)"
		[ -n "$LAST_RESUME" ] || LAST_RESUME=0

		# Time to go the fuck to sleep
		if [ $((CURR_UPTIME - LAST_RESUME)) -gt 5 ]; then
			SET_VAR "system" "resume_uptime" "$CURR_UPTIME"
			/opt/muos/script/system/suspend.sh
		fi
	fi
}

RGBCLI() {
	RGBCONTROLLER_DIR="$MUOS_SHARE_DIR/application/RGB Controller"

	LD_LIBRARY_PATH="$RGBCONTROLLER_DIR/libs:$LD_LIBRARY_PATH" \
		"$RGBCONTROLLER_DIR/love" "$RGBCONTROLLER_DIR/rgbcli" "$@"
}

READ_HOTKEYS | while read -r HOTKEY; do
	# Don't respond to any hotkeys while in charge mode or with lid closed.
	if pgrep "muxcharge" >/dev/null 2>&1 || LID_CLOSED; then
		continue
	fi

	HANDLE_HOTKEY "$HOTKEY"
done
