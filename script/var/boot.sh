#!/bin/sh

[ -n "${MUOS_BOOT_LOADED-}" ] && return 0
MUOS_BOOT_LOADED=1
[ -n "${MUOS_SERVICE_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/service.sh"
[ -n "${MUOS_AUDIO_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/audio.sh"
[ -n "${MUOS_LOG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/log.sh"

MESSAGE_FINISH="/tmp/msg_finish"
BOOT_PROGRESS_TARGET="$MUOS_RUN_DIR/boot/progress_target"
BOOT_PROGRESS_TEXT="Starting up"

LED_QUIET() {
	LED_ANIM_DIR="/sys/class/led_anim"
	[ -d "$LED_ANIM_DIR" ] || return 0

	for LED_ZONE in l r lr m f1 f2; do
		printf "0" >"$LED_ANIM_DIR/effect_$LED_ZONE" 2>/dev/null
		printf "000000" >"$LED_ANIM_DIR/effect_rgb_hex_$LED_ZONE" 2>/dev/null
	done

	printf "0" >"$LED_ANIM_DIR/max_scale" 2>/dev/null
}

BOOT_PROGRESS_QUIPS="$MUOS_SHARE_DIR/loading.txt"
BOOT_PROGRESS_DONE="$MUOS_RUN_DIR/boot/progress_done"
LOADING_PAINT_FLAG="$MUOS_RUN_DIR/loading_paint"
LOADING_RELEASED_FLAG="$MUOS_RUN_DIR/loading_released"
FIRST_PAINT_FLAG="$MUOS_RUN_DIR/first_paint"

BOOT_PROGRESS_FLOOR=5

BOOT_PROGRESS_QUIP() {
	[ -r "$BOOT_PROGRESS_QUIPS" ] || return 1

	read -r QUIP_SEED _ </proc/uptime 2>/dev/null || QUIP_SEED=0

	awk -v seed="${QUIP_SEED#*.}$$" \
		'BEGIN { srand(seed) } { line[NR] = $0 } END { if (NR > 0) print line[int(rand() * NR) + 1] }' \
		"$BOOT_PROGRESS_QUIPS" 2>/dev/null
}

BOOT_PROGRESS() {
	mkdir -p "${BOOT_PROGRESS_TARGET%/*}" 2>/dev/null
	printf '%s\n' "$1" >"$BOOT_PROGRESS_TARGET" 2>/dev/null
}

BOOT_PROGRESS_SMOOTH() {
	(
		PROG_CUR=$BOOT_PROGRESS_FLOOR
		PROG_SHOWN=-1
		PROG_TICK=0
		PROG_QUIP=$BOOT_PROGRESS_TEXT
		PROG_LAST_QUIP=

		while [ ! -e "$MESSAGE_FINISH" ] && [ ! -e "$BOOT_PROGRESS_DONE" ]; do
			[ -f "$MESSAGE_TEXT" ] || break

			PROG_TGT=0
			[ -r "$BOOT_PROGRESS_TARGET" ] && read -r PROG_TGT <"$BOOT_PROGRESS_TARGET" 2>/dev/null
			case "$PROG_TGT" in
				'' | *[!0-9]*) PROG_TGT=0 ;;
			esac

			if [ $((PROG_TICK % 20)) -eq 0 ]; then
				PROG_QUIP=$(BOOT_PROGRESS_QUIP)
				[ -n "$PROG_QUIP" ] || PROG_QUIP=$BOOT_PROGRESS_TEXT
			fi
			PROG_TICK=$((PROG_TICK + 1))

			if [ ! -e "$LOADING_PAINT_FLAG" ]; then
				PROG_CUR=$BOOT_PROGRESS_FLOOR
			elif [ "$PROG_CUR" -lt "$PROG_TGT" ]; then
				PROG_STEP=$(((PROG_TGT - PROG_CUR) / 2))
				[ "$PROG_STEP" -lt 2 ] && PROG_STEP=2
				PROG_CUR=$((PROG_CUR + PROG_STEP))
			else
				PROG_CEIL=$((PROG_TGT + 14))
				[ "$PROG_CEIL" -gt 97 ] && PROG_CEIL=97

				if [ "$PROG_CUR" -lt "$PROG_CEIL" ]; then
					PROG_STEP=$(((PROG_CEIL - PROG_CUR) / 5))
					[ "$PROG_STEP" -lt 1 ] && PROG_STEP=1
					PROG_CUR=$((PROG_CUR + PROG_STEP))
				fi
			fi

			if [ "$PROG_CUR" -ne "$PROG_SHOWN" ] || [ "$PROG_QUIP" != "$PROG_LAST_QUIP" ]; then
				PROG_SHOWN=$PROG_CUR
				PROG_LAST_QUIP=$PROG_QUIP

				printf '%s\n' "$PROG_CUR" >"$MESSAGE_PROG" 2>/dev/null
				printf '%s\\n\\n%s%%\n' "$PROG_QUIP" "$PROG_CUR" >"$MESSAGE_TEXT" 2>/dev/null
			fi

			sleep 0.15
		done
	) &
}

GPU_NODE_READY() {
	[ -e /dev/mali0 ] && return 0

	for GPU_NODE in /dev/dri/renderD* /dev/dri/card*; do
		[ -e "$GPU_NODE" ] && return 0
	done

	return 1
}

BOOT_PROGRESS_START() {
	[ -x "$MESSAGE_EXEC" ] || return 0

	[ "$(GET_VAR "config" "boot/factory_reset")" = "1" ] && return 0
	[ "$(GET_VAR "config" "boot/first_init")" = "0" ] && return 0

	(
		PROG_WAIT=0
		while [ "$PROG_WAIT" -lt 100 ]; do
			GPU_NODE_READY && break
			sleep 0.1
			PROG_WAIT=$((PROG_WAIT + 1))
		done

		if ! GPU_NODE_READY; then
			LOG_WARN "$0" 0 "BOOTING" "No render node appeared, skipping the loading screen"
			exit 0
		fi

		rm -f "$MESSAGE_FINISH" "$BOOT_PROGRESS_DONE" "$LOADING_RELEASED_FLAG" 2>/dev/null

		PROG_QUIP=$(BOOT_PROGRESS_QUIP)
		[ -n "$PROG_QUIP" ] || PROG_QUIP=$BOOT_PROGRESS_TEXT

		printf '%s\n' "$BOOT_PROGRESS_FLOOR" >"$MESSAGE_PROG" 2>/dev/null
		printf '%s\\n\\n%s%%\n' "$PROG_QUIP" "$BOOT_PROGRESS_FLOOR" >"$MESSAGE_TEXT" 2>/dev/null

		PROG_TRY=0
		while [ "$PROG_TRY" -lt 8 ]; do
			[ -e "$BOOT_PROGRESS_DONE" ] && exit 0
			[ -e "$FIRST_PAINT_FLAG" ] && exit 0

			MESSAGE start

			PROG_SETTLE=0
			while [ "$PROG_SETTLE" -lt 15 ]; do
				[ -e "$LOADING_PAINT_FLAG" ] && break
				sleep 0.1
				PROG_SETTLE=$((PROG_SETTLE + 1))
			done

			[ -e "$LOADING_PAINT_FLAG" ] && break

			for PROG_PID in $(pidof muxmessage 2>/dev/null); do
				kill -TERM "$PROG_PID" 2>/dev/null
			done

			sleep 0.25
			PROG_TRY=$((PROG_TRY + 1))
		done

		if [ ! -e "$LOADING_PAINT_FLAG" ]; then
			LOG_WARN "$0" 0 "BOOTING" "Loading screen never painted, carrying on without it"
			exit 0
		fi

		BOOT_PROGRESS_SMOOTH
	) &
}

BOOT_PROGRESS_STOP() {
	: >"$BOOT_PROGRESS_DONE" 2>/dev/null

	if ! pidof muxmessage >/dev/null 2>&1; then
		rm -f "$MESSAGE_TEXT" "$MESSAGE_PROG" "$MESSAGE_FINISH" "$BOOT_PROGRESS_TARGET" 2>/dev/null
		return 0
	fi

	PROG_QUIP=$(BOOT_PROGRESS_QUIP)
	[ -n "$PROG_QUIP" ] || PROG_QUIP="Nearly There"

	PROG_NOW=0
	[ -r "$MESSAGE_PROG" ] && read -r PROG_NOW <"$MESSAGE_PROG" 2>/dev/null
	case "$PROG_NOW" in
		'' | *[!0-9]*) PROG_NOW=0 ;;
	esac

	while [ "$PROG_NOW" -lt 100 ]; do
		PROG_STEP=$(((100 - PROG_NOW) / 2))
		[ "$PROG_STEP" -lt 6 ] && PROG_STEP=6
		PROG_NOW=$((PROG_NOW + PROG_STEP))
		[ "$PROG_NOW" -gt 100 ] && PROG_NOW=100

		printf '%s\n' "$PROG_NOW" >"$MESSAGE_PROG" 2>/dev/null
		printf '%s\\n\\n%s%%\n' "$PROG_QUIP" "$PROG_NOW" >"$MESSAGE_TEXT" 2>/dev/null
		sleep 0.06
	done

	sleep 0.12

	: >"$MESSAGE_FINISH" 2>/dev/null

	PROG_WAIT=0
	while [ "$PROG_WAIT" -lt 40 ]; do
		[ -e "$LOADING_RELEASED_FLAG" ] && break
		sleep 0.05
		PROG_WAIT=$((PROG_WAIT + 1))
	done

	if pidof muxmessage >/dev/null 2>&1; then
		LOG_WARN "$0" 0 "BOOTING" "Progress screen did not exit on its own, terminating"
		for PROG_PID in $(pidof muxmessage 2>/dev/null); do
			kill -TERM "$PROG_PID" 2>/dev/null
		done
		sleep 0.2
	fi

	rm -f "$MESSAGE_TEXT" "$MESSAGE_PROG" "$MESSAGE_FINISH" \
		"$BOOT_PROGRESS_TARGET" "$LOADING_RELEASED_FLAG" 2>/dev/null
}

SHOW_MESSAGE() {
	[ ! -f "$MESSAGE_TEXT" ] && MESSAGE start

	if /opt/muos/script/var/process.sh status message; then
		echo "$1" >"$MESSAGE_PROG"
		echo "$2" >"$MESSAGE_TEXT"
	fi
}

EXEC_MUX() {
	if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
		while [ ! -f "$MUOS_RUN_DIR/hdmi_mode" ]; do sleep 0.05; done
	fi

	[ -f "$SAFE_QUIT" ] && rm -f "$SAFE_QUIT"

	GOBACK="$1"
	MODULE="$2"
	shift

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"

	RESTORE_AUDIO_VOLUME

	SET_VAR "system" "foreground_process" "$MODULE"
	"/opt/muos/frontend/$MODULE" "$@"

	while [ ! -f "$SAFE_QUIT" ]; do sleep 0.05; done
}

# Prints current system uptime in hundredths of a second. Unlike date or
# EPOCHREALTIME, this won't decrease if the system clock is set back, so it can
# be used to measure an interval of real time.
UPTIME() {
	cut -d ' ' -f 1 /proc/uptime
}

DELETE_CRUFT() {
	(
		[ "$1" ] || return

		find "$1" -type d \( \
			-name 'System Volume Information' -o \
			-name '.Trashes' -o \
			-name '.Spotlight' -o \
			-name '.fseventsd' \
			\) -exec rm -rf -- {} +

		find "$1" -type f \( \
			-name '._*' -o \
			-name '.DS_Store' -o \
			-name 'desktop.ini' -o \
			-name 'Thumbs.db' -o \
			-name '.DStore' -o \
			-name '.gitkeep' \
			\) -exec rm -f -- {} +
	) &
}
