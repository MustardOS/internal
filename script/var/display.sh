#!/bin/sh

[ -n "${MUOS_DISPLAY_LOADED-}" ] && return 0
MUOS_DISPLAY_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"
[ -n "${MUOS_GOVERNOR_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/governor.sh"

RGB_EXTERNAL() {
	[ "$(GET_VAR "config" "settings/rgb/mode")" = 10 ]
}

LED_CONTROL_CHANGE() {
	RGB_EXTERNAL && return 0
	[ "$(GET_VAR "device" "led/rgb")" -eq 1 ] && "$MUOS_RGB_BIN" "$1"
}

FBCON_DISABLE() {
	# TODO: Add advanced option for blinkies! (for antiKk)
	for VTCON in /sys/class/vtconsole/vtcon*; do
		[ -e "$VTCON/name" ] || continue

		VT_NAME=
		read -r VT_NAME <"$VTCON/name" 2>/dev/null
		case "$VT_NAME" in
			*frame*buffer* | *fbcon*) [ -w "$VTCON/bind" ] && printf "0\n" >"$VTCON/bind" ;;
		esac
	done

	[ -w /sys/class/graphics/fbcon/cursor_blink ] && printf "0\n" >/sys/class/graphics/fbcon/cursor_blink
	[ -w /sys/module/vt/parameters/default_utf8 ] && printf "1\n" >/sys/module/vt/parameters/default_utf8
}

RUMBLE() {
	if [ -n "$(GET_VAR "device" "board/rumble")" ]; then
		case "$(GET_VAR "device" "board/name")" in
			rk-g350-v)
				echo 1 >"$1"
				sleep "$2"
				echo 0 >"$1"
				;;
			rk*)
				echo 1 >"$1"
				sleep "$2"
				echo 1000000 >"$1"
				;;
			rg-vita*)
				echo 0 >"$1"
				sleep "$2"
				echo 1 >"$1"
				;;
			*)
				echo 1 >"$1"
				sleep "$2"
				echo 0 >"$1"
				;;
		esac
	fi
}

# Usage: FB_SWITCH WIDTH HEIGHT DEPTH [BUFFERS]
FB_SWITCH() {
	FB_WIDTH="${1}"
	FB_HEIGHT="${2}"
	FB_DEPTH="${3}"
	FB_BUFFERS="${4:-2}"

	HDMI_NODE="$(GET_VAR "device" "screen/hdmi")"
	FB_ACTUAL_WIDTH="${FB_WIDTH}"
	FB_ACTUAL_HEIGHT="${FB_HEIGHT}"

	if [ "$(GET_VAR "device" "board/name")" = "rg28xx-h" ]; then
		HDMI_NODE_VAL=0
		if [ -r "${HDMI_NODE}" ]; then
			IFS= read -r HDMI_NODE_VAL <"${HDMI_NODE}"
		fi
		if [ "${HDMI_NODE_VAL}" = "0" ]; then
			FB_ACTUAL_WIDTH="${FB_HEIGHT}"
			FB_ACTUAL_HEIGHT="${FB_WIDTH}"
		fi
	fi

	FB_CURRENT_VIRTUAL=
	FB_CURRENT_DEPTH=
	[ -r /sys/class/graphics/fb0/virtual_size ] && IFS= read -r FB_CURRENT_VIRTUAL </sys/class/graphics/fb0/virtual_size
	[ -r /sys/class/graphics/fb0/bits_per_pixel ] && IFS= read -r FB_CURRENT_DEPTH </sys/class/graphics/fb0/bits_per_pixel
	FB_EXPECTED_VIRTUAL="${FB_ACTUAL_WIDTH},$((FB_ACTUAL_HEIGHT * FB_BUFFERS))"

	if [ "$FB_CURRENT_VIRTUAL" != "$FB_EXPECTED_VIRTUAL" ] || [ "$FB_CURRENT_DEPTH" != "$FB_DEPTH" ]; then
		/opt/muos/frontend/mufbset -w "${FB_ACTUAL_WIDTH}" -h "${FB_ACTUAL_HEIGHT}" -d "${FB_DEPTH}" -b "${FB_BUFFERS}" || return 1
		MIRROR_REFRESH
	fi

	for FB_MODE in screen mux; do
		SET_VAR "device" "${FB_MODE}/width" "${FB_WIDTH}"
		SET_VAR "device" "${FB_MODE}/height" "${FB_HEIGHT}"
	done
}

HDMI_SWITCH() {
	HS_RES="$(GET_VAR "config" "settings/hdmi/resolution")"
	HD_DEP=32

	case "${HS_RES}" in
		0 | 1)
			HS_WIDTH=720
			HS_HEIGHT=480
			;; # 480i / 576i  (720-stride interlaced)
		2)
			HS_WIDTH=720
			HS_HEIGHT=480
			;; # 480p
		3)
			HS_WIDTH=720
			HS_HEIGHT=576
			;; # 576p
		4 | 5)
			HS_WIDTH=1280
			HS_HEIGHT=720
			;; # 720p (50 or 60 Hz)
		*)
			HS_RES=2
			HS_WIDTH=720
			HS_HEIGHT=480
			SET_VAR "config" "settings/hdmi/resolution" "${HS_RES}"
			;;
	esac

	SET_VAR "device" "screen/external/width" "${HS_WIDTH}"
	SET_VAR "device" "screen/external/height" "${HS_HEIGHT}"

	FB_SWITCH "${HS_WIDTH}" "${HS_HEIGHT}" "${HD_DEP}"
}

# Normal mode is stating that the factory reset routine is complete
# and the device can act as it's supposed to, seems like some users
# are "sleeping" their devices during the factory reset process.
IS_NORMAL_MODE() {
	[ "$(GET_VAR "config" "boot/factory_reset")" -eq 0 ]
}

# Handheld mode states stating whether or not the Console Mode (HDMI)
# is preset and active.  We don't want specific hotkeys to run if we
# are in currently in Console Mode.
IS_HANDHELD_MODE() {
	[ "$(GET_VAR "config" "boot/device_mode")" -eq 0 ]
}

MIRROR_PID_FILE="$MUOS_RUN_DIR/mirror.pid"

# Starts only the mudisp mirror process, the device display must already be on
MIRROR_DAEMON_START() {
	[ -x /opt/muos/frontend/mudisp ] || return 1

	/opt/muos/frontend/mudisp mirror 1 >/dev/null 2>&1 &
	printf "%s" "$!" >"$MIRROR_PID_FILE"
}

MIRROR_DAEMON_STOP() {
	[ -r "$MIRROR_PID_FILE" ] || return 0

	IFS= read -r MIRROR_PID <"$MIRROR_PID_FILE"
	rm -f "$MIRROR_PID_FILE"
	[ -n "$MIRROR_PID" ] || return 0

	kill "$MIRROR_PID" 2>/dev/null || return 0

	# Give it a moment to take its layer down before the display changes under it
	MIRROR_WAIT=0
	while kill -0 "$MIRROR_PID" 2>/dev/null && [ "$MIRROR_WAIT" -lt 20 ]; do
		sleep 0.05
		MIRROR_WAIT=$((MIRROR_WAIT + 1))
	done
}

# Mirrors the HDMI output onto the device display when it is enabled and HDMI is active
MIRROR_START() {
	IS_ONE "$(GET_VAR "config" "settings/hdmi/mirror")" || return 0
	IS_ONE "$(GET_VAR "config" "boot/device_mode")" || return 0

	MIRROR_STOP

	DISPLAY_WRITE disp1 switch "1 0"
	sleep 0.5

	MIRROR_BRIGHT=$(GET_VAR "config" "settings/general/brightness")
	[ "${MIRROR_BRIGHT:-0}" -le 8 ] && MIRROR_BRIGHT=16
	DISPLAY_WRITE disp1 setbl "$MIRROR_BRIGHT"

	MIRROR_DAEMON_START || LOG_WARN "$0" 0 "MIRROR" "Display tool missing, output not mirrored"
}

MIRROR_STOP() {
	MIRROR_WAS_RUNNING=0
	[ -r "$MIRROR_PID_FILE" ] && MIRROR_WAS_RUNNING=1

	MIRROR_DAEMON_STOP
	[ "$MIRROR_WAS_RUNNING" -eq 1 ] && DISPLAY_WRITE disp1 switch "0 0"
	return 0
}

# Framebuffer geometry changed, so the mirror has to pick up the new size
MIRROR_REFRESH() {
	[ -r "$MIRROR_PID_FILE" ] || return 0

	MIRROR_DAEMON_STOP
	MIRROR_DAEMON_START
}

# Sets BL_PATH_CACHE without a subshell so the lookup is only done once
DISPLAY_SYSFS_BACKLIGHT() {
	[ -n "${BL_PATH_CACHE-}" ] && return 0

	for B in /sys/class/backlight/*; do
		[ -f "$B/brightness" ] || continue
		BL_PATH_CACHE=$B
		return 0
	done

	return 1
}

# Writes a setting value to the display driver.
# Typically used for brightness on most devices but has
# HDMI mode support for those who use it, unfortunately
# Usage: DISPLAY_WRITE NAME COMMAND PARAM
DISPLAY_WRITE() {
	DW_NAME="${1}"
	DW_CMD="${2}"
	DW_PARAM="${3}"

	# Only brightness belongs on a sysfs backlight, output switching must reach the display driver
	if [ "$DW_CMD" = "setbl" ] && DISPLAY_SYSFS_BACKLIGHT; then
		printf "%s" "$DW_PARAM" >"$BL_PATH_CACHE/brightness"
		return
	fi

	# Fallback to dispdbg parameters
	case "$(GET_VAR "device" "board/name")" in
		rg* | mgx* | tui*)
			printf "%s" "${DW_NAME}" >/sys/kernel/debug/dispdbg/name
			printf "%s" "${DW_CMD}" >/sys/kernel/debug/dispdbg/command
			printf "%s" "${DW_PARAM}" >/sys/kernel/debug/dispdbg/param
			printf "1\n" >/sys/kernel/debug/dispdbg/start
			;;
	esac
}

# Reads and prints a setting value from the display driver.
# Just like the above function it is mainly for brightness
# but can also be used for HDMI functionality...
# Usage: DISPLAY_READ NAME COMMAND
DISPLAY_READ() {
	DR_NAME="${1}"
	DR_CMD="${2}"

	if [ "$DR_CMD" = "getbl" ] && DISPLAY_SYSFS_BACKLIGHT; then
		IFS= read -r BL_VAL <"$BL_PATH_CACHE/brightness" && printf "%s\n" "$BL_VAL"
		return
	fi

	case "$(GET_VAR "device" "board/name")" in
		rg* | mgx* | tui*)
			printf "%s" "${DR_NAME}" >/sys/kernel/debug/dispdbg/name
			printf "%s" "${DR_CMD}" >/sys/kernel/debug/dispdbg/command
			printf "1\n" >/sys/kernel/debug/dispdbg/start
			cat /sys/kernel/debug/dispdbg/info
			;;
	esac
}

DISPLAY_IDLE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && amixer set "Master" mute

	[ "$(DISPLAY_READ disp0 getbl)" -gt 10 ] && DISPLAY_WRITE disp0 setbl 10

	LED_CONTROL_CHANGE off

	printf 1 >"$IDLE_STATE"

	: >"$IS_IDLE"

	# muhotkey has dropped the CPU to the idle governor, so release the clocks a
	# performance session pinned alongside it and remember to pin them again.
	if [ -s "$MUOS_RUN_DIR/dmc_governor" ]; then
		: >"$MUOS_RUN_DIR/idle_devfreq"
		(
			SYNC_GPU_FREQUENCY powersave
			SYNC_CPU_IDLE powersave
			SYNC_DMC_FREQUENCY powersave
		)
	fi
}

DISPLAY_ACTIVE() {
	[ "$(GET_VAR "config" "settings/power/idle_mute")" -eq 1 ] && amixer set "Master" unmute

	DISPLAY_WRITE disp0 setbl "$(GET_VAR "config" "settings/general/brightness")"

	LED_CONTROL_CHANGE restore

	printf 0 >"$IDLE_STATE"

	[ -e "$IS_IDLE" ] && rm -f "$IS_IDLE"

	if [ -e "$MUOS_RUN_DIR/idle_devfreq" ]; then
		rm -f "$MUOS_RUN_DIR/idle_devfreq"
		(
			SYNC_GPU_FREQUENCY performance
			SYNC_CPU_IDLE performance
			SYNC_DMC_FREQUENCY performance
		)
	fi
}

LCD_DISABLE() {
	if [ "$(GET_VAR "config" "settings/advanced/disp_suspend")" -eq 1 ]; then
		sleep 0.5
		DISPLAY_WRITE lcd0 disable 0
		sleep 0.5
	fi
}

LCD_ENABLE() {
	if [ "$(GET_VAR "config" "settings/advanced/disp_suspend")" -eq 1 ]; then
		sleep 0.5
		DISPLAY_WRITE lcd0 enable 0
		sleep 0.5
	fi
}

SETUP_GL4ES() {
	GL4ES_LIB="/usr/lib/gl4es"

	if [ -d "$GL4ES_LIB" ]; then
		case ":${LD_LIBRARY_PATH-}:" in
			*":$GL4ES_LIB:"*) ;;
			*) LD_LIBRARY_PATH="$GL4ES_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
		esac
		export LD_LIBRARY_PATH
	fi
}

SETUP_SDL_ENVIRONMENT() {
	REQ_STYLE=""
	SKIP_BLITTER=0
	KEEP_CURSOR=0

	for A in "$@"; do
		case "$A" in
			retro | modern) REQ_STYLE="$A" ;; # Optional priority override: $1 = retro | modern
			skip_blitter) SKIP_BLITTER=1 ;; # Used primarily for external ScummVM at the moment
			keep_cursor) KEEP_CURSOR=1 ;; # Mouse-driven applications such as ScummVM
		esac
	done

	GCDB_DEFAULT="/usr/lib/gamecontrollerdb.txt"
	GCDB_COMPAT="/usr/lib32/gamecontrollerdb.txt"
	GCDB_STORE="$MUOS_SHARE_DIR/info/gamecontrollerdb"

	case "$REQ_STYLE" in
		modern) GCDB_FILE="$GCDB_STORE/modern.txt" ;;
		retro) GCDB_FILE="$GCDB_STORE/retro.txt" ;;
		*)
			CON_GO="$MUOS_RUN_DIR/controller"
			if [ -e "$CON_GO" ]; then
				IFS= read -r SEL <"$CON_GO"
				case "$SEL" in
					# honour "system" - otherwise use whatever was selected from content...
					system)
						case "$(GET_VAR "config" "settings/remap/layout")" in
							1) GCDB_FILE="$GCDB_STORE/modern.txt" ;;
							*) GCDB_FILE="$GCDB_STORE/retro.txt" ;;
						esac
						;;
					*) GCDB_FILE="$GCDB_STORE/$SEL.txt" ;;
				esac
			else
				case "$(GET_VAR "config" "settings/remap/layout")" in
					1) GCDB_FILE="$GCDB_STORE/modern.txt" ;;
					*) GCDB_FILE="$GCDB_STORE/retro.txt" ;;
				esac
			fi
			;;
	esac

	if [ ! -f "$GCDB_FILE" ]; then
		case "$(GET_VAR "config" "settings/remap/layout")" in
			1) GCDB_FILE="$GCDB_STORE/modern.txt" ;;
			*) GCDB_FILE="$GCDB_STORE/retro.txt" ;;
		esac
	fi

	# Remove and relink controller DB
	rm -f "$GCDB_DEFAULT"
	ln -sf "$GCDB_FILE" "$GCDB_DEFAULT"
	if [ -d "${GCDB_COMPAT%/*}" ]; then
		rm -f "$GCDB_COMPAT"
		ln -sf "$GCDB_FILE" "$GCDB_COMPAT"
	fi

	# Set both the SDL controller file and configuration
	SDL_GAMECONTROLLERCONFIG_FILE="$GCDB_FILE"
	SDL_CACHE="/tmp/sdl_gc_${GCDB_FILE##*/}"
	if [ -f "$SDL_CACHE" ]; then
		SDL_GAMECONTROLLERCONFIG=$(cat "$SDL_CACHE")
	else
		SDL_GAMECONTROLLERCONFIG=$(grep "$(GET_VAR "device" "sdl/name")" "$GCDB_FILE")
		printf '%s\n' "$SDL_GAMECONTROLLERCONFIG" >"$SDL_CACHE"
	fi
	[ -n "$SDL_GAMECONTROLLERCONFIG" ] || SDL_GAMECONTROLLERCONFIG=$(GET_VAR "device" "board/sdl_map")

	export SDL_GAMECONTROLLERCONFIG_FILE SDL_GAMECONTROLLERCONFIG

	if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
		SDL_HQ_SCALER=2
		SDL_ROTATION=0
		[ "$SKIP_BLITTER" -eq 0 ] && SDL_BLITTER_DISABLED=1
	else
		SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
		SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
		[ "$SKIP_BLITTER" -eq 0 ] && SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
	fi

	SDL_ASSERT=always_ignore

	if [ "$SKIP_BLITTER" -eq 0 ]; then
		export SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
	else
		# Do not retain a value inherited from a previous or nested launcher.
		unset SDL_BLITTER_DISABLED
		export SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION
	fi

	SDL_CURSOR_LIB="$MUX_LIB/libmucursor.so"
	if [ "$KEEP_CURSOR" -eq 0 ]; then
		if [ -f "$SDL_CURSOR_LIB" ]; then
			case " ${LD_PRELOAD-} " in
				*" $SDL_CURSOR_LIB "*) ;;
				*) LD_PRELOAD="$SDL_CURSOR_LIB${LD_PRELOAD:+ $LD_PRELOAD}" ;;
			esac
			export LD_PRELOAD
		fi
	else
		SDL_PRELOAD=""
		for PRELOAD_LIB in ${LD_PRELOAD-}; do
			[ "$PRELOAD_LIB" = "$SDL_CURSOR_LIB" ] && continue
			SDL_PRELOAD="$SDL_PRELOAD${SDL_PRELOAD:+ }$PRELOAD_LIB"
		done

		if [ -n "$SDL_PRELOAD" ]; then
			LD_PRELOAD="$SDL_PRELOAD"
			export LD_PRELOAD
		else
			unset LD_PRELOAD
		fi
	fi

	SETUP_GL4ES
}
