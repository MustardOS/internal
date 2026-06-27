#!/bin/sh

. /opt/muos/script/var/func.sh

HDMI_RESOLUTION=$(GET_VAR "config" "settings/hdmi/resolution")
HDMI_SPACE=$(GET_VAR "config" "settings/hdmi/space")
HDMI_DEPTH=$(GET_VAR "config" "settings/hdmi/depth")
HDMI_RANGE=$(GET_VAR "config" "settings/hdmi/range")
HDMI_SCAN=$(GET_VAR "config" "settings/hdmi/scan")

REFRESH_HDMI() {
	printf "1" >"$MUOS_RUN_DIR/hdmi_refresh"
	printf "%s" "$1" >"$MUOS_RUN_DIR/hdmi_mode"
}

GET_TV_MODE() {
	# As per the "secret" display documentation!
	case "$HDMI_RESOLUTION" in
		0) printf "0" ;; # DISP_TV_MOD_480I
		1) printf "1" ;; # DISP_TV_MOD_576I
		2) printf "2" ;; # DISP_TV_MOD_480P
		3) printf "3" ;; # DISP_TV_MOD_576P
		4) printf "4" ;; # DISP_TV_MOD_720P_50HZ
		5) printf "5" ;; # DISP_TV_MOD_720P_60HZ
		6) printf "6" ;; # DISP_TV_MOD_1080I_50HZ
		7) printf "7" ;; # DISP_TV_MOD_1080I_60HZ
		8) printf "8" ;; # DISP_TV_MOD_1080P_24HZ
		9) printf "9" ;; # DISP_TV_MOD_1080P_50HZ
		10) printf "10" ;; # DISP_TV_MOD_1080P_60HZ
		*) printf "2" ;; # default: 480P
	esac
}

GET_FB_DIMENSIONS() {
	case "$1" in
		0 | 1 | 2) printf "720x480" ;;
		3) printf "720x576" ;;
		4 | 5) printf "1280x720" ;;
		6 | 7 | 8 | 9 | 10 | 26 | 27) printf "1920x1080" ;;
		*) printf "1920x1080" ;;
	esac
}

GET_COLOUR_SPACE() {
	case "$HDMI_SPACE" in
		0) printf "RGB" ;;
		1) printf "YUV444" ;;
		2) printf "YUV422" ;;
		3) printf "YUV420" ;;
		*) printf "RGB" ;;
	esac
}

GET_COLOUR_DEPTH() {
	case "$HDMI_DEPTH" in
		0) printf "8" ;;
		1) printf "10" ;;
		2) printf "12" ;;
		3) printf "14" ;;
		4) printf "16" ;;
		*) printf "8" ;;
	esac
}

GET_COLOUR_RANGE() {
	case "$HDMI_RANGE" in
		0) printf "limited" ;;
		1) printf "full" ;;
		*) printf "limited" ;;
	esac
}

GET_SCAN_MODE() {
	case "$HDMI_SCAN" in
		0) printf "overscan" ;;
		1) printf "underscan" ;;
		*) printf "underscan" ;;
	esac
}

GET_DELAYS() {
	case "$1" in
		1920x1080)
			PRE_FB=0.35
			POST_FB=0.20
			PRE_FE=0.35
			;;
		*)
			PRE_FB=0.20
			POST_FB=0.10
			PRE_FE=0.10
			;;
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

VERIFY_SWITCH() {
	SYS="/sys/class/disp/disp/attr/sys"
	[ -r "$SYS" ] || return 0

	while IFS= read -r LINE; do
		case "$LINE" in
			*"hdmi output"*)
				LOG_INFO "hdmi" 0 "HDMI" "DE status: $LINE"
				return 0
				;;
		esac
	done <"$SYS"

	LOG_WARN "hdmi" 0 "HDMI" "No HDMI output detected"
	return 1
}

TV_MODE=$(GET_TV_MODE)
FB_DIMS=$(GET_FB_DIMENSIONS "$TV_MODE")

FB_W=${FB_DIMS%%x*}
FB_H=${FB_DIMS##*x}
FB_MODE="${FB_W}x${FB_H}"

COLOUR_SPACE=$(GET_COLOUR_SPACE)
COLOUR_DEPTH=$(GET_COLOUR_DEPTH)
COLOUR_RANGE=$(GET_COLOUR_RANGE)
SCAN_MODE=$(GET_SCAN_MODE)

GET_DELAYS "$FB_MODE"

LOG_INFO "hdmi" 0 "HDMI" "Switching HDMI: mode=$TV_MODE res=$FB_MODE space=$COLOUR_SPACE depth=${COLOUR_DEPTH}bit range=$COLOUR_RANGE scan=$SCAN_MODE"

CHECK_HPD || exit 1

DISPLAY_WRITE disp0 switch "4 $TV_MODE"

sleep "$PRE_FB"

FB_SWITCH "$FB_W" "$FB_H" 32

SET_VAR "device" "screen/external/width" "$FB_W"
SET_VAR "device" "screen/external/height" "$FB_H"

sleep "$POST_FB"

VERIFY_SWITCH || exit 1

sleep "$PRE_FE"

REFRESH_HDMI 1

LOG_INFO "hdmi" 0 "HDMI" "HDMI switch complete: $FB_MODE"
