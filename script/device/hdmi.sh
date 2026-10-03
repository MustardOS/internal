#!/bin/sh

. /opt/muos/script/var/func.sh

MUDISP=/opt/muos/frontend/mudisp

HDMI_RESOLUTION=$(GET_VAR "config" "settings/hdmi/resolution")
HDMI_SPACE=$(GET_VAR "config" "settings/hdmi/space")
HDMI_DEPTH=$(GET_VAR "config" "settings/hdmi/depth")
HDMI_RANGE=$(GET_VAR "config" "settings/hdmi/range")
HDMI_SCAN=$(GET_VAR "config" "settings/hdmi/scan")

# 720p is the maximum, earlier 1080 choices keep their refresh rate
case "$HDMI_RESOLUTION" in
	0 | 1 | 2 | 3 | 4 | 5) ;;
	6 | 8)
		HDMI_RESOLUTION=4
		SET_VAR "config" "settings/hdmi/resolution" "$HDMI_RESOLUTION"
		;;
	7 | 9)
		HDMI_RESOLUTION=5
		SET_VAR "config" "settings/hdmi/resolution" "$HDMI_RESOLUTION"
		;;
	*)
		HDMI_RESOLUTION=2
		SET_VAR "config" "settings/hdmi/resolution" "$HDMI_RESOLUTION"
		;;
esac

REFRESH_HDMI() {
	printf "1" >"$MUOS_RUN_DIR/hdmi_refresh"
	printf "%s" "$1" >"$MUOS_RUN_DIR/hdmi_mode"
}

# Setting index to display driver TV mode, as per the "secret" display documentation!
GET_TV_MODE() {
	case "$1" in
		0) printf "0" ;;  # DISP_TV_MOD_480I
		1) printf "1" ;;  # DISP_TV_MOD_576I
		2) printf "2" ;;  # DISP_TV_MOD_480P
		3) printf "3" ;;  # DISP_TV_MOD_576P
		4) printf "4" ;;  # DISP_TV_MOD_720P_50HZ
		5) printf "5" ;;  # DISP_TV_MOD_720P_60HZ
		*) printf "2" ;;
	esac
}

GET_FB_DIMENSIONS() {
	case "$1" in
		0 | 2) printf "720x480" ;;
		1 | 3) printf "720x576" ;;
		4 | 5) printf "1280x720" ;;
		*) printf "720x480" ;;
	esac
}

# The panel refresh SDL reports is a fixed 60, so the real output rate has to come from here
GET_REFRESH() {
	case "$1" in
		0 | 2) printf "59.94" ;;
		1 | 3 | 4) printf "50.00" ;;
		*) printf "60.00" ;;
	esac
}

# Fallbacks stay on the same refresh family so content keeps its pacing
GET_FALLBACKS() {
	case "$1" in
		0) printf "0 2" ;;
		1) printf "1 3" ;;
		2) printf "2 0" ;;
		3) printf "3 1" ;;
		4) printf "4 3" ;;
		5) printf "5 2" ;;
		*) printf "2" ;;
	esac
}

# Menu values to display driver values, only RGB through YUV420 exist
GET_COLOUR_SPACE() {
	case "$HDMI_SPACE" in
		1) printf "1" ;; # YUV444
		2) printf "2" ;; # YUV422
		3) printf "3" ;; # YUV420
		*) printf "0" ;; # RGB
	esac
}

GET_COLOUR_DEPTH() {
	case "$HDMI_DEPTH" in
		1) printf "1" ;;     # 10 bit
		2) printf "2" ;;     # 12 bit
		3 | 4) printf "3" ;; # 16 bit, 4 is the old menu position
		*) printf "0" ;;     # 8 bit
	esac
}

GET_COLOUR_RANGE() {
	case "$HDMI_RANGE" in
		1) printf "1" ;; # Full
		*) printf "2" ;; # Limited
	esac
}

GET_SCAN_MODE() {
	case "$HDMI_SCAN" in
		1) printf "2" ;; # Underscan
		*) printf "1" ;; # Overscan
	esac
}

CHECK_HPD() {
	HPD_PATH=""
	HPD_VAL=""

	for P in "/sys/class/switch/hdmi/state" "/sys/class/extcon/hdmi/state"; do
		if [ -r "$P" ]; then
			HPD_PATH="$P"
			break
		fi
	done

	if [ -z "$HPD_PATH" ]; then
		LOG_WARN "hdmi" 0 "HDMI" "No HPD node, continuing"
		return 0
	fi

	IFS= read -r HPD_VAL <"$HPD_PATH"

	case "$HPD_VAL" in
		*=*) HPD_VAL=${HPD_VAL##*=} ;;
	esac

	case "$HPD_VAL" in
		1)
			LOG_INFO "hdmi" 0 "HDMI" "HPD asserted"
			return 0
			;;
		*)
			LOG_WARN "hdmi" 0 "HDMI" "HPD not asserted"
			return 1
			;;
	esac
}

# Picks the first resolution in the fallback list the connected sink accepts
PICK_RESOLUTION() {
	if [ ! -x "$MUDISP" ]; then
		printf "%s" "$HDMI_RESOLUTION"
		return
	fi

	for CANDIDATE in $(GET_FALLBACKS "$HDMI_RESOLUTION"); do
		"$MUDISP" support "$(GET_TV_MODE "$CANDIDATE")" >/dev/null 2>&1
		case $? in
			0)
				printf "%s" "$CANDIDATE"
				return
				;;
			2)
				# The check itself failed so trust the user choice
				printf "%s" "$HDMI_RESOLUTION"
				return
				;;
		esac
	done

	printf "%s" "$HDMI_RESOLUTION"
}

VERIFY_SWITCH() {
	SYS="/sys/class/disp/disp/attr/sys"
	[ -r "$SYS" ] || return 0

	VERIFY_ATTEMPT=0
	while [ "$VERIFY_ATTEMPT" -lt 20 ]; do
		while IFS= read -r LINE; do
			case "$LINE" in
				*"hdmi output"*)
					LOG_INFO "hdmi" 0 "HDMI" "DE status: $LINE"
					return 0
					;;
			esac
		done <"$SYS"
		VERIFY_ATTEMPT=$((VERIFY_ATTEMPT + 1))
		sleep 0.1
	done

	LOG_WARN "hdmi" 0 "HDMI" "No HDMI output detected"
	return 1
}

APPLY_COLOUR() {
	[ -x "$MUDISP" ] || {
		LOG_WARN "hdmi" 0 "HDMI" "Display tool missing, colour settings not applied"
		return 0
	}

	"$MUDISP" set "format=$COLOUR_SPACE" "bits=$COLOUR_DEPTH" "range=$COLOUR_RANGE" "scan=$SCAN_MODE" >/dev/null 2>&1
	case $? in
		0) LOG_INFO "hdmi" 0 "HDMI" "Colour applied: format=$COLOUR_SPACE bits=$COLOUR_DEPTH range=$COLOUR_RANGE scan=$SCAN_MODE" ;;
		3) LOG_WARN "hdmi" 0 "HDMI" "Sink downgraded colour settings: $("$MUDISP" get 2>/dev/null | tr '\n' ' ')" ;;
		*) LOG_WARN "hdmi" 0 "HDMI" "Colour settings could not be applied" ;;
	esac
}

ACTIVE_RESOLUTION=$(PICK_RESOLUTION)
if [ "$ACTIVE_RESOLUTION" != "$HDMI_RESOLUTION" ]; then
	LOG_WARN "hdmi" 0 "HDMI" "Sink does not support resolution $HDMI_RESOLUTION, using $ACTIVE_RESOLUTION"
fi

TV_MODE=$(GET_TV_MODE "$ACTIVE_RESOLUTION")
FB_DIMS=$(GET_FB_DIMENSIONS "$ACTIVE_RESOLUTION")
REFRESH=$(GET_REFRESH "$ACTIVE_RESOLUTION")

FB_W=${FB_DIMS%%x*}
FB_H=${FB_DIMS##*x}

COLOUR_SPACE=$(GET_COLOUR_SPACE)
COLOUR_DEPTH=$(GET_COLOUR_DEPTH)
COLOUR_RANGE=$(GET_COLOUR_RANGE)
SCAN_MODE=$(GET_SCAN_MODE)

PRE_FB=0.20
POST_FB=0.10
PRE_FE=0.10

LOG_INFO "hdmi" 0 "HDMI" "Switching HDMI: mode=$TV_MODE res=$FB_DIMS refresh=$REFRESH"

CHECK_HPD || exit 1

# Async init mounts debugfs and may not have got there yet, the switch goes through dispdbg
grep -q " /sys/kernel/debug debugfs " /proc/mounts || mount -t debugfs debugfs /sys/kernel/debug

DISPLAY_WRITE disp0 switch "4 $TV_MODE"

sleep "$PRE_FB"

VERIFY_SWITCH || exit 1

APPLY_COLOUR

FB_BUFFER_COUNT=2

if ! FB_SWITCH "$FB_W" "$FB_H" 32 "$FB_BUFFER_COUNT"; then
	LOG_ERROR "hdmi" 0 "HDMI" "Framebuffer switch failed: $FB_DIMS"
	DISPLAY_WRITE disp0 switch "1 0"
	exit 1
fi

SET_VAR "device" "screen/external/width" "$FB_W"
SET_VAR "device" "screen/external/height" "$FB_H"
SET_VAR "device" "screen/external/buffers" "$FB_BUFFER_COUNT"
SET_VAR "device" "screen/external/refresh" "$REFRESH"

sleep "$POST_FB"

sleep "$PRE_FE"

REFRESH_HDMI 1

MIRROR_START

LOG_INFO "hdmi" 0 "HDMI" "HDMI switch complete: ${FB_W}x${FB_H} x${FB_BUFFER_COUNT} at ${REFRESH}Hz"
