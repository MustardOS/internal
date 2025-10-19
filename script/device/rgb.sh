#!/bin/sh

. /opt/muos/script/var/func.sh
[ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ] && exit 0

LED_SYSFS="/sys/class/led_anim"
SERIAL_DEVICE="/dev/ttyS5"
MCU_PWR="/sys/class/power_supply/axp2202-battery/mcu_pwr"

BACKEND="AUTO" # AUTO | SYSFS | SERIAL

PID_DIR="/run/muos"
PID_FILE="$PID_DIR/rgb_random.pid"
DEFAULT_INTERVAL_MS=50

FLAG_DUR_ALL=""

FLAG_DUR_L=""
FLAG_DUR_R=""
FLAG_DUR_M=""

FLAG_DUR_F1=""
FLAG_DUR_F2=""

FLAG_CYC_ALL=""

FLAG_CYC_L=""
FLAG_CYC_R=""
FLAG_CYC_M=""

FLAG_CYC_F1=""
FLAG_CYC_F2=""

USAGE() {
	printf "%s\n" \
		"Usage:
  $0 [-b auto|sysfs|serial] [--dur MS] [--dur-l MS] [--dur-r MS] [--dur-m MS] [--dur-f1 MS] [--dur-f2 MS] \\
     [--cycles N] [--cycles-l N] [--cycles-r N] [--cycles-m N] [--cycles-f1 N] [--cycles-f2 N] \\
     <mode> <brightness> [args...]
  $0 service {start|stop|status|restart} [...]

Backends:
  SYSFS  : /sys/class/led_anim
  SERIAL : /dev/ttyS5
  AUTO   : default (prefers SYSFS if present, else SERIAL)

SYSFS:
  Modes      : 1=static, 2=sniff, 3=breath, 4=blink1, 5=blink2, 6=blink3, 7=linear
  Brightness : 0–60 (clamped)
  Args:
    <L_r> <L_g> <L_b> [<R_r> <R_g> <R_b>] [M_r M_g M_b] [F1_r F1_g F1_b] [F2_r F2_g F2_b]
  Options:
    --dur, --dur-l, --dur-r, --dur-m, --dur-f1, --dur-f2         (default 1000 ms)
    --cycles, --cycles-l, --cycles-r, --cycles-m, --cycles-f1, --cycles-f2   (default -1)

SERIAL:
  Modes      : 1=solid, 2=breath fast, 3=breath med, 4=breath slow, 5=mono rainbow, 6=multi rainbow
  Brightness : 0–255 (clamped)
  Mode 1     : <right_r> <right_g> <right_b> <left_r> <left_g> <left_b>
  Modes 2–4  : <r> <g> <b>
  Modes 5–6  : <speed 0–255>
  Randomise  : use service:  $0 service start [-b serial|auto] 1 <brightness> random [interval_ms]"
}

CLAMP() {
	V=$1

	MIN=$2
	MAX=$3

	[ "$V" -lt "$MIN" ] && V=$MIN
	[ "$V" -gt "$MAX" ] && V=$MAX

	printf "%d" "$V"
}

CLAMP_RGB() {
	CLAMP "$1" 0 255
}

TO_HEX3() {
	printf "%02X%02X%02X" "$1" "$2" "$3"
}

EFFECT_MAP_SYSFS() {
	case "$1" in
		1) printf "%d" 4 ;; # static
		2) printf "%d" 3 ;; # sniff
		3) printf "%d" 2 ;; # breath
		4) printf "%d" 5 ;; # blink1
		5) printf "%d" 6 ;; # blink2
		6) printf "%d" 7 ;; # blink3
		7) printf "%d" 1 ;; # linear
		*) return 1 ;;
	esac
}

DETECT_BACKEND() {
	if [ "$BACKEND" = "AUTO" ]; then
		if [ -d "$LED_SYSFS" ]; then
			BACKEND="SYSFS"
		elif [ -c "$SERIAL_DEVICE" ]; then
			BACKEND="SERIAL"
		else
			printf "Error: no supported LED backend found (missing %s and %s)\n" "$LED_SYSFS" "$SERIAL_DEVICE" >&2
			exit 1
		fi
	fi
}

ENSURE_DIR() {
	[ -d "$1" ] || mkdir -p "$1"
}

SLEEP_MS() {
	MS=$1
	TBOX sleep "$(printf "%d.%03d" "$((MS / 1000))" "$((MS % 1000))")"
}

IS_PID_ALIVE() {
	PID=$1
	[ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}

READ_PID() {
	[ -f "$PID_FILE" ] && awk 'NF{print $1; exit}' "$PID_FILE"
}

WRITE_PID() {
	ENSURE_DIR "$PID_DIR"
	printf "%s\n" "$1" >"$PID_FILE"
}

CLEAR_PID() {
	rm -f "$PID_FILE"
}

RANDOM_BYTE() {
	printf "%s" "$(od -An -N1 -tu1 /dev/urandom 2>/dev/null | tr -d ' ')"
}

RANDOM_RGB() {
	printf "%s %s %s\n" "$(RANDOM_BYTE)" "$(RANDOM_BYTE)" "$(RANDOM_BYTE)"
}

CHECKSUM_U8() {
	SUM=0
	# shellcheck disable=SC2068
	for B in $@; do
		SUM=$(((SUM + B) & 255))
	done
	printf "%d" "$SUM"
}

SERIAL_WRITE() {
	# argv are decimal bytes 0..255; convert to a single escaped string then output as raw bytes
	# shellcheck disable=SC2059
	printf %b "$(printf '\\x%02X' "$@")" >"$SERIAL_DEVICE"
}

SERIAL_PREPARE() {
	[ -w "$MCU_PWR" ] && printf "1\n" >"$MCU_PWR"
	stty -F "$SERIAL_DEVICE" 115200 cs8 -parenb -cstopb -opost -isig -icanon -echo 2>/dev/null

	# Small warm-up so first frame is not lost
	TBOX sleep 0.1
}

SERIAL_SEND_MODE1_COLORS() {
	# Args: <brightness> <RR> <RG> <RB> <LR> <LG> <LB>
	BRI=$(CLAMP "$1" 0 255)

	RR=$(CLAMP_RGB "$2")
	RG=$(CLAMP_RGB "$3")
	RB=$(CLAMP_RGB "$4")

	LR=$(CLAMP_RGB "$5")
	LG=$(CLAMP_RGB "$6")
	LB=$(CLAMP_RGB "$7")

	BYTES="1 $BRI"

	I=0
	while [ $I -lt 8 ]; do
		BYTES="$BYTES $RR $RG $RB"
		I=$((I + 1))
	done

	I=0
	while [ $I -lt 8 ]; do
		BYTES="$BYTES $LR $LG $LB"
		I=$((I + 1))
	done

	CHK=$(CHECKSUM_U8 $BYTES)
	set -- $BYTES "$CHK"

	[ "${RGB_DEBUG:-0}" -eq 1 ] && {
		printf 'TX:' >&2
		for X; do printf ' %02X' "$X" >&2; done
		printf '\n' >&2
	}

	SERIAL_WRITE "$@"
}

SERIAL_RANDOMISE_DAEMON() {
	BRI=$1
	IMS=$2

	DETECT_BACKEND

	if [ "$BACKEND" != "SERIAL" ]; then
		printf "Error: random requires SERIAL backend.\n" >&2
		return 1
	fi

	SERIAL_PREPARE
	trap 'exit 0' INT TERM

	while :; do
		set -- $(RANDOM_RGB)
		RR=$1
		RG=$2
		RB=$3

		set -- $(RANDOM_RGB)
		LR=$1
		LG=$2
		LB=$3

		SERIAL_SEND_MODE1_COLORS "$BRI" "$RR" "$RG" "$RB" "$LR" "$LG" "$LB"
		SLEEP_MS "$IMS"
	done
}

SYSFS_HAS() {
	[ -w "$LED_SYSFS/$1" ]
}

SYSFS_WRITE() {
	P="$LED_SYSFS/$1"
	V=$2
	[ -w "$P" ] && printf "%s\n" "$V" >"$P"
}

APPLY_SYSFS() {
	MODE=$1
	BRI=$2
	shift 2

	case "$MODE" in 1 | 2 | 3 | 4 | 5 | 6 | 7) : ;; *)
		printf "Invalid mode for SYSFS: %s (1–7)\n" "$MODE" >&2
		exit 1
		;;
	esac

	BRI=$(CLAMP "$BRI" 0 60)

	LR=$1
	LG=$2
	LB=$3

	RR=${4:-$LR}
	RG=${5:-$LG}
	RB=${6:-$LB}

	MR=${7:-$LR}
	MG=${8:-$LG}
	MB=${9:-$LB}

	F1R=${10:-$LR}
	F1G=${11:-$LG}
	F1B=${12:-$LB}

	F2R=${13:-$RR}
	F2G=${14:-$RG}
	F2B=${15:-$RB}

	if [ -z "$LR" ] || [ -z "$LG" ] || [ -z "$LB" ] || [ -z "$RR" ] || [ -z "$RG" ] || [ -z "$RB" ]; then
		printf "SYSFS usage:\n  %s -b sysfs [--dur ...] [--cycles ...] <mode 1-7> <brightness 0-60> \\\n    <L_r L_g L_b> <R_r R_g R_b> [M_r M_g M_b] [F1_r F1_g F1_b] [F2_r F2_g F2_b]\n" "$0" >&2
		exit 1
	fi

	LR=$(CLAMP_RGB "$LR")
	LG=$(CLAMP_RGB "$LG")
	LB=$(CLAMP_RGB "$LB")

	RR=$(CLAMP_RGB "$RR")
	RG=$(CLAMP_RGB "$RG")
	RB=$(CLAMP_RGB "$RB")

	MR=$(CLAMP_RGB "$MR")
	MG=$(CLAMP_RGB "$MG")
	MB=$(CLAMP_RGB "$MB")

	F1R=$(CLAMP_RGB "$F1R")
	F1G=$(CLAMP_RGB "$F1G")
	F1B=$(CLAMP_RGB "$F1B")

	F2R=$(CLAMP_RGB "$F2R")
	F2G=$(CLAMP_RGB "$F2G")
	F2B=$(CLAMP_RGB "$F2B")

	# Hex strings (driver expects trailing space)
	HEX_L=$(TO_HEX3 "$LR" "$LG" "$LB")
	HEX_L_SP="${HEX_L} "

	HEX_R=$(TO_HEX3 "$RR" "$RG" "$RB")
	HEX_R_SP="${HEX_R} "

	HEX_M=$(TO_HEX3 "$MR" "$MG" "$MB")
	HEX_M_SP="${HEX_M} "

	HEX_F1=$(TO_HEX3 "$F1R" "$F1G" "$F1B")
	HEX_F1_SP="${HEX_F1} "

	HEX_F2=$(TO_HEX3 "$F2R" "$F2G" "$F2B")
	HEX_F2_SP="${HEX_F2} "

	EFFECT=$(EFFECT_MAP_SYSFS "$MODE") || {
		printf "Bad mode mapping.\n" >&2
		exit 1
	}

	SYSFS_WRITE "max_scale" "$BRI"

	if [ "$HEX_L" = "$HEX_R" ] && SYSFS_HAS "effect_rgb_hex_lr"; then
		SYSFS_WRITE "effect_rgb_hex_lr" "$HEX_L_SP"
	else
		SYSFS_WRITE "effect_rgb_hex_l" "$HEX_L_SP"
		SYSFS_WRITE "effect_rgb_hex_r" "$HEX_R_SP"
	fi

	SYSFS_WRITE "effect_rgb_hex_m" "$HEX_M_SP"

	SYSFS_WRITE "effect_rgb_hex_f1" "$HEX_F1_SP"
	SYSFS_WRITE "effect_rgb_hex_f2" "$HEX_F2_SP"

	DUR_ALL=${FLAG_DUR_ALL:-${LED_DUR:-1000}}

	DUR_LV=${FLAG_DUR_L:-${LED_DUR_L:-$DUR_ALL}}
	DUR_RV=${FLAG_DUR_R:-${LED_DUR_R:-$DUR_ALL}}
	DUR_MV=${FLAG_DUR_M:-${LED_DUR_M:-$DUR_ALL}}

	DUR_F1V=${FLAG_DUR_F1:-${LED_DUR_F1:-$DUR_ALL}}
	DUR_F2V=${FLAG_DUR_F2:-${LED_DUR_F2:-$DUR_ALL}}

	CYC_ALL=${FLAG_CYC_ALL:-${LED_CYCLES:--1}}

	CYC_LV=${FLAG_CYC_L:-${LED_CYCLES_L:-$CYC_ALL}}
	CYC_RV=${FLAG_CYC_R:-${LED_CYCLES_R:-$CYC_ALL}}
	CYC_MV=${FLAG_CYC_M:-${LED_CYCLES_M:-$CYC_ALL}}

	CYC_F1V=${FLAG_CYC_F1:-${LED_CYCLES_F1:-$CYC_ALL}}
	CYC_F2V=${FLAG_CYC_F2:-${LED_CYCLES_F2:-$CYC_ALL}}

	if SYSFS_HAS "effect_duration_lr" && [ "$DUR_LV" = "$DUR_RV" ]; then
		SYSFS_WRITE "effect_duration_lr" "$DUR_LV"
	else
		SYSFS_WRITE "effect_duration_l" "$DUR_LV"
		SYSFS_WRITE "effect_duration_r" "$DUR_RV"
	fi

	SYSFS_WRITE "effect_duration_m" "$DUR_MV"
	SYSFS_WRITE "effect_duration_f1" "$DUR_F1V"
	SYSFS_WRITE "effect_duration_f2" "$DUR_F2V"

	if SYSFS_HAS "effect_cycles_lr" && [ "$CYC_LV" = "$CYC_RV" ]; then
		SYSFS_WRITE "effect_cycles_lr" "$CYC_LV"
	else
		SYSFS_WRITE "effect_cycles_l" "$CYC_LV"
		SYSFS_WRITE "effect_cycles_r" "$CYC_RV"
	fi

	SYSFS_WRITE "effect_cycles_m" "$CYC_MV"
	SYSFS_WRITE "effect_cycles_f1" "$CYC_F1V"
	SYSFS_WRITE "effect_cycles_f2" "$CYC_F2V"

	if SYSFS_HAS "effect_lr"; then
		SYSFS_WRITE "effect_lr" "$EFFECT"
	else
		SYSFS_WRITE "effect_l" "$EFFECT"
		SYSFS_WRITE "effect_r" "$EFFECT"
	fi

	SYSFS_WRITE "effect_m" "$EFFECT"
	SYSFS_WRITE "effect_f1" "$EFFECT"
	SYSFS_WRITE "effect_f2" "$EFFECT"

	SYSFS_WRITE "effect_enable" "1"

	printf "LED mode %s applied (SYSFS)\n" "$MODE"
	printf "Brightness: %s\n" "$BRI"
	printf "Left:   RGB(%s %s %s) = #%s\n" "$LR" "$LG" "$LB" "$HEX_L"
	printf "Right:  RGB(%s %s %s) = #%s\n" "$RR" "$RG" "$RB" "$HEX_R"
	printf "Middle: RGB(%s %s %s) = #%s\n" "$MR" "$MG" "$MB" "$HEX_M"
	printf "F1:     RGB(%s %s %s) = #%s\n" "$F1R" "$F1G" "$F1B" "$HEX_F1"
	printf "F2:     RGB(%s %s %s) = #%s\n" "$F2R" "$F2G" "$F2B" "$HEX_F2"
	printf "Durations ms: L=%s R=%s M=%s F1=%s F2=%s | Cycles: L=%s R=%s M=%s F1=%s F2=%s\n" \
		"$DUR_LV" "$DUR_RV" "$DUR_MV" "$DUR_F1V" "$DUR_F2V" \
		"$CYC_LV" "$CYC_RV" "$CYC_MV" "$CYC_F1V" "$CYC_F2V"
}

APPLY_SERIAL() {
	MODE=$1
	BRI=$2
	shift 2

	case "$MODE" in 1 | 2 | 3 | 4 | 5 | 6) : ;; *)
		printf "Invalid mode for SERIAL: %s (1–6)\n" "$MODE" >&2
		exit 1
		;;
	esac

	BRI=$(CLAMP "$BRI" 0 255)
	SERIAL_PREPARE

	if [ "$MODE" -ge 5 ] && [ "$MODE" -le 6 ]; then
		[ $# -eq 1 ] || {
			printf "SERIAL usage (5–6): %s -b serial <5|6> <brightness> <speed 0-255>\n" "$0" >&2
			exit 1
		}

		SPEED=$(CLAMP "$1" 0 255)
		CHK=$(CHECKSUM_U8 $MODE $BRI 1 1 $SPEED)

		[ "${RGB_DEBUG:-0}" -eq 1 ] && {
			printf 'TX:' >&2
			for X in $MODE $BRI 1 1 $SPEED $CHK; do printf ' %02X' "$X" >&2; done
			printf '\n' >&2
		}

		SERIAL_WRITE "$MODE" "$BRI" 1 1 "$SPEED" "$CHK"
		printf "LED mode %s set with brightness %s (SERIAL)\n" "$MODE" "$BRI"
	elif [ "$MODE" -eq 1 ] && [ $# -ge 1 ] && [ "$1" = "random" ]; then
		printf "Use service mode for random:\n  %s service start -b serial 1 %s random [interval_ms]\n" "$0" "$BRI" >&2
		exit 1
	elif [ "$MODE" -eq 1 ]; then
		[ $# -eq 6 ] || {
			printf "SERIAL usage (1): %s -b serial 1 <brightness> <right_r> <right_g> <right_b> <left_r> <left_g> <left_b>\n" "$0" >&2
			exit 1
		}

		RR=$(CLAMP_RGB "$1")
		RG=$(CLAMP_RGB "$2")
		RB=$(CLAMP_RGB "$3")

		LR=$(CLAMP_RGB "$4")
		LG=$(CLAMP_RGB "$5")
		LB=$(CLAMP_RGB "$6")

		BYTES="$MODE $BRI"

		I=0
		while [ $I -lt 8 ]; do
			BYTES="$BYTES $RR $RG $RB"
			I=$((I + 1))
		done

		I=0
		while [ $I -lt 8 ]; do
			BYTES="$BYTES $LR $LG $LB"
			I=$((I + 1))
		done

		CHK=$(CHECKSUM_U8 $BYTES)
		set -- $BYTES "$CHK"

		[ "${RGB_DEBUG:-0}" -eq 1 ] && {
			printf 'TX:' >&2
			for X; do printf ' %02X' "$X" >&2; done
			printf '\n' >&2
		}

		SERIAL_WRITE "$@"
		printf "LED mode %s set with brightness %s (SERIAL)\n" "$MODE" "$BRI"
	else
		[ $# -eq 3 ] || {
			printf "SERIAL usage (2–4): %s -b serial <2|3|4> <brightness> <r> <g> <b>\n" "$0" >&2
			exit 1
		}

		R=$(CLAMP_RGB "$1")
		G=$(CLAMP_RGB "$2")
		B=$(CLAMP_RGB "$3")

		BYTES="$MODE $BRI"

		I=0
		while [ $I -lt 16 ]; do
			BYTES="$BYTES $R $G $B"
			I=$((I + 1))
		done

		CHK=$(CHECKSUM_U8 $BYTES)
		set -- $BYTES "$CHK"

		[ "${RGB_DEBUG:-0}" -eq 1 ] && {
			printf 'TX:' >&2
			for X; do printf ' %02X' "$X" >&2; done
			printf '\n' >&2
		}

		SERIAL_WRITE "$@"
		printf "LED mode %s set with brightness %s (SERIAL)\n" "$MODE" "$BRI"
	fi
}

if [ "${1:-}" = "service" ]; then
	SUBCMD=$2
	shift 2
	case "$SUBCMD" in
		start)
			BACKEND="AUTO"
			if [ "${1:-}" = "-b" ]; then
				BACKEND_OPT=$2
				case "$BACKEND_OPT" in
					auto | AUTO) BACKEND="AUTO" ;;
					serial | SERIAL) BACKEND="SERIAL" ;;
					sysfs | SYSFS)
						printf "Error: service random is SERIAL only.\n" >&2
						exit 1
						;;
					*)
						printf "Error: invalid backend '%s'\n" "$BACKEND_OPT" >&2
						exit 1
						;;
				esac
				shift 2
			fi

			if [ $# -lt 3 ] || [ "$1" -ne 1 ] || [ "$3" != "random" ]; then
				printf "Usage: %s service start [-b serial|auto] 1 <brightness> random [interval_ms]\n" "$0" >&2
				exit 1
			fi

			MODE=$1
			BRI=$2

			INTERVAL_MS=${4:-$DEFAULT_INTERVAL_MS}

			case "$BRI" in *[!0-9]* | "")
				printf "Brightness must be numeric.\n" >&2
				exit 1
				;;
			esac

			case "$INTERVAL_MS" in *[!0-9]* | "")
				printf "Interval must be numeric ms.\n" >&2
				exit 1
				;;
			esac

			OLDPID=$(READ_PID)
			if IS_PID_ALIVE "$OLDPID"; then
				printf "RGB random already running (pid %s)\n" "$OLDPID"
				exit 0
			fi

			(
				exec </dev/null >/dev/null 2>&1
				SERIAL_RANDOMISE_DAEMON "$BRI" "$INTERVAL_MS"
			) &

			NEWPID=$!
			if IS_PID_ALIVE "$NEWPID"; then
				WRITE_PID "$NEWPID"
				printf "Started RGB random (pid %s, interval %sms, brightness %s)\n" "$NEWPID" "$INTERVAL_MS" "$BRI"
				exit 0
			fi

			printf "Failed to start daemon.\n" >&2
			exit 1
			;;
		stop)
			PID=$(READ_PID)
			if ! IS_PID_ALIVE "$PID"; then
				printf "No running RGB random service.\n"
				CLEAR_PID
				exit 0
			fi

			kill "$PID" 2>/dev/null || :

			I=0
			while [ $I -lt 20 ]; do
				IS_PID_ALIVE "$PID" || break
				SLEEP_MS 100
				I=$((I + 1))
			done

			IS_PID_ALIVE "$PID" && kill -9 "$PID" 2>/dev/null || :
			CLEAR_PID

			printf "Stopped RGB random (pid %s)\n" "$PID"
			exit 0
			;;
		status)
			PID=$(READ_PID)
			if IS_PID_ALIVE "$PID"; then
				printf "RGB random is running (pid %s)\n" "$PID"
				exit 0
			else
				printf "RGB random is not running\n"
				exit 1
			fi
			;;
		restart)
			"$0" service stop
			exec "$0" service start "$@"
			;;
		*)
			printf "Usage: %s service {start|stop|status|restart} [...]\n" "$0" >&2
			exit 1
			;;
	esac
fi

while :; do
	case "${1:-}" in
		-b)
			case "${2:-}" in
				auto | AUTO) BACKEND="AUTO" ;;
				sysfs | SYSFS) BACKEND="SYSFS" ;;
				serial | SERIAL) BACKEND="SERIAL" ;;
				*)
					printf "Invalid backend: %s\n" "${2:-}" >&2
					USAGE
					exit 1
					;;
			esac
			shift 2
			;;
		-h | --help)
			USAGE
			exit 0
			;;
		--dur)
			FLAG_DUR_ALL="$2"
			shift 2
			;;
		--dur-l)
			FLAG_DUR_L="$2"
			shift 2
			;;
		--dur-r)
			FLAG_DUR_R="$2"
			shift 2
			;;
		--dur-m)
			FLAG_DUR_M="$2"
			shift 2
			;;
		--dur-f1)
			FLAG_DUR_F1="$2"
			shift 2
			;;
		--dur-f2)
			FLAG_DUR_F2="$2"
			shift 2
			;;
		--cycles)
			FLAG_CYC_ALL="$2"
			shift 2
			;;
		--cycles-l)
			FLAG_CYC_L="$2"
			shift 2
			;;
		--cycles-r)
			FLAG_CYC_R="$2"
			shift 2
			;;
		--cycles-m)
			FLAG_CYC_M="$2"
			shift 2
			;;
		--cycles-f1)
			FLAG_CYC_F1="$2"
			shift 2
			;;
		--cycles-f2)
			FLAG_CYC_F2="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			printf "Unknown option: %s\n" "$1" >&2
			USAGE
			exit 1
			;;
		*) break ;;
	esac
done

[ $# -ge 2 ] || {
	USAGE
	exit 1
}

MODE=$1
BRI=$2
shift 2

DETECT_BACKEND

case "$BACKEND" in
	SYSFS)
		[ -d "$LED_SYSFS" ] || {
			printf "Error: SYSFS backend selected but %s not present.\n" "$LED_SYSFS" >&2
			exit 1
		}

		APPLY_SYSFS "$MODE" "$BRI" "$@"
		;;
	SERIAL)
		[ -c "$SERIAL_DEVICE" ] || {
			printf "Error: SERIAL backend selected but %s not present.\n" "$SERIAL_DEVICE" >&2
			exit 1
		}

		APPLY_SERIAL "$MODE" "$BRI" "$@"
		;;
	*)
		printf "Internal error: unknown backend '%s'\n" "$BACKEND" >&2
		exit 1
		;;
esac
