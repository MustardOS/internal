#!/bin/sh

X86_RESOLUTION_LIST=/run/muos/x86_resolutions
X86_RESOLUTION_PENDING=/run/muos/x86_resolution_pending
X86_RESOLUTION_SETTING=/opt/muos/config/settings/general/x86_resolution

X86_RESOLUTION_DISCOVER() {
	: >"$X86_RESOLUTION_LIST"
	for X86_RESOLUTION in 320x240 640x480 720x480 720x576 720x720 1024x768 1280x720 1366x768 1920x1080; do
		[ -d "/opt/muos/share/theme/MustardOS/$X86_RESOLUTION" ] || continue
		for X86_MODES in /sys/class/drm/card*-*/modes; do
			[ -r "$X86_MODES" ] || continue
			if grep -qx "$X86_RESOLUTION" "$X86_MODES"; then
				printf '%s\n' "$X86_RESOLUTION" >>"$X86_RESOLUTION_LIST"
				break
			fi
		done
	done

	[ -s "$X86_RESOLUTION_LIST" ] || printf '%s\n' 640x480 >"$X86_RESOLUTION_LIST"
}

X86_RESOLUTION_APPLY() {
	[ "$1" -eq 1 ] || [ -e "$X86_RESOLUTION_PENDING" ] || return 0

	X86_RESOLUTION=640x480
	[ ! -r "$X86_RESOLUTION_SETTING" ] || IFS= read -r X86_RESOLUTION <"$X86_RESOLUTION_SETTING"

	case "$X86_RESOLUTION" in
		320x240 | 640x480 | 720x480 | 720x576 | 720x720 | 1024x768 | 1280x720 | 1366x768 | 1920x1080) ;;
		*) X86_RESOLUTION=640x480 ;;
	esac

	if [ -s "$X86_RESOLUTION_LIST" ] && ! grep -qx "$X86_RESOLUTION" "$X86_RESOLUTION_LIST"; then
		if grep -qx 640x480 "$X86_RESOLUTION_LIST"; then
			X86_RESOLUTION=640x480
		else
			IFS= read -r X86_RESOLUTION <"$X86_RESOLUTION_LIST"
		fi
		printf '%s' "$X86_RESOLUTION" >"$X86_RESOLUTION_SETTING"
	fi

	X86_WIDTH=${X86_RESOLUTION%x*}
	X86_HEIGHT=${X86_RESOLUTION#*x}

	for X86_PATH in screen/width screen/internal/width screen/external/width mux/width; do
		printf '%s' "$X86_WIDTH" >"/opt/muos/device/config/$X86_PATH"
	done
	for X86_PATH in screen/height screen/internal/height screen/external/height mux/height; do
		printf '%s' "$X86_HEIGHT" >"/opt/muos/device/config/$X86_PATH"
	done

	rm -f "$X86_RESOLUTION_PENDING"
}

DEVICE_FRONTEND_START() {
	X86_RESOLUTION_DISCOVER
	X86_RESOLUTION_APPLY 1
	RUN_DEVICE_SCRIPT display.sh recover -w &
	X86_SPLASH_PID=$!
	(
		X86_SPLASH_WAIT=0
		while [ ! -e "$MUOS_RUN_DIR/first_paint" ] && kill -0 "$X86_SPLASH_PID" 2>/dev/null && [ "$X86_SPLASH_WAIT" -lt 300 ]; do
			sleep 0.05
			X86_SPLASH_WAIT=$((X86_SPLASH_WAIT + 1))
		done
		if kill -0 "$X86_SPLASH_PID" 2>/dev/null; then
			kill -TERM "$X86_SPLASH_PID" 2>/dev/null
		fi
	) &
}

DEVICE_FRONTEND_EXEC() {
	X86_RESOLUTION_APPLY 0
	EXEC_MUX "$@"
}
