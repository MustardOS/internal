#!/bin/sh

. /opt/muos/script/var/func.sh

SCREEN_IMAGE=${1:-$MUOS_RUN_DIR/dash_screenshot.png}
SCREEN_SCOPE=${2:-private}
SCREEN_STATE="$SCREEN_IMAGE.state"
SCREEN_LOCK="$SCREEN_IMAGE.lock"
SCREEN_TEMP="$SCREEN_IMAGE.tmp.png"
SCREEN_PRIVATE="muxwebcode muxpass muxpasscfg muxnetprofile muxnetproxy muxwebserv"

if [ -d "$SCREEN_LOCK" ] && [ -n "$(find "$SCREEN_LOCK" -prune -mmin +1 2>/dev/null)" ]; then
	rmdir "$SCREEN_LOCK" 2>/dev/null
fi
mkdir "$SCREEN_LOCK" 2>/dev/null || exit 0
trap 'rm -f "$SCREEN_TEMP"; rmdir "$SCREEN_LOCK" 2>/dev/null' 0 HUP INT TERM

case "$(GET_VAR "device" "board/name")" in
	mgx*) SCREEN_ROTATE=270 ;;
	rg-vita* | rg28xx-h | rk-pixel-2) SCREEN_ROTATE=90 ;;
	*) SCREEN_ROTATE=0 ;;
esac

WRITE_STATE() {
	printf '%s %s\n' "$1" "$SCREEN_ROTATE" >"$SCREEN_STATE.tmp" && mv -f "$SCREEN_STATE.tmp" "$SCREEN_STATE"
}

# A finished child can linger as a zombie under a private module name, so only running processes count.
PRIVATE_RUNNING() {
	for SCREEN_PID in $(pgrep -x "$1" 2>/dev/null); do
		SCREEN_STAT=$(cat "/proc/$SCREEN_PID/stat" 2>/dev/null) || continue
		SCREEN_STAT=${SCREEN_STAT##*) }
		[ "${SCREEN_STAT%% *}" = "Z" ] || return 0
	done
	return 1
}

PRIVATE_OPEN() {
	[ "$SCREEN_SCOPE" = all ] && return 1
	for SCREEN_MODULE in $SCREEN_PRIVATE; do
		PRIVATE_RUNNING "$SCREEN_MODULE" && return 0
	done
	return 1
}

if PRIVATE_OPEN; then
	WRITE_STATE hidden
	exit 0
fi

if command -v ionice >/dev/null 2>&1; then
	set -- ionice -c 3 nice -n 19
else
	set -- nice -n 19
fi

if "$@" /opt/muos/frontend/mufbset -g "$SCREEN_TEMP" >/dev/null 2>&1 && [ -s "$SCREEN_TEMP" ]; then
	# A private screen may have opened while the picture was being taken, so check again before keeping it.
	if PRIVATE_OPEN; then
		WRITE_STATE hidden
		exit 0
	fi
	mv -f "$SCREEN_TEMP" "$SCREEN_IMAGE"
	WRITE_STATE ok
else
	WRITE_STATE failed
fi
