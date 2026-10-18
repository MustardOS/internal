#!/bin/sh

[ -n "${MUOS_INPUT_LOADED-}" ] && return 0
MUOS_INPUT_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"

MUOS_INPUT_BIN="/opt/muos/frontend/muinput"
MUOS_INPUT_KEYS="/run/muinput/remote.keys"
MUOS_INPUT_SOCKET="/run/muinput/remote.sock"

SENDKEY_USAGE() {
	printf '%s\n' \
		'Usage: SENDKEY BUTTON[+BUTTON...] [HOLD_MS]' \
		'       SENDKEY hold BUTTON[+BUTTON...] [HOLD_MS]' \
		'       SENDKEY repeat BUTTON[+BUTTON...] COUNT [GAP_MS]' \
		'       SENDKEY stick AXIS VALUE [AXIS VALUE...] [HOLD_MS]' \
		'       SENDKEY volume|brightness up|down [COUNT]' \
		'       SENDKEY clear' >&2
}

SENDKEY_SLEEP() {
	[ "${1:-0}" -gt 0 ] 2>/dev/null || return 0
	if command -v usleep >/dev/null 2>&1; then
		usleep "$(($1 * 1000))"
	else
		sleep "$(awk -v MS="$1" 'BEGIN { printf "%.3f", MS / 1000 }')"
	fi
}

SENDKEY_SEND() {
	[ -S "$MUOS_INPUT_SOCKET" ] || {
		printf 'SENDKEY: the device input service is not ready\n' >&2
		return 1
	}
	[ -x "$MUOS_INPUT_BIN" ] || {
		printf 'SENDKEY: %s is not available\n' "$MUOS_INPUT_BIN" >&2
		return 1
	}
	"$MUOS_INPUT_BIN" --send "$1"
}

SENDKEY_AVAILABLE() {
	[ -r "$MUOS_INPUT_KEYS" ] || return 1
	case " $(cat "$MUOS_INPUT_KEYS") " in
		*" $1 "*) return 0 ;;
		*) return 1 ;;
	esac
}

# Injects normalised controls through muinput. Button combinations are joined with '+',
# analogue axes use values from -1.0 to 1.0, and every held control is released on return.
SENDKEY() {
	[ "$#" -gt 0 ] || {
		SENDKEY_USAGE
		return 2
	}

	case "$1" in
		clear)
			[ "$#" -eq 1 ] || {
				SENDKEY_USAGE
				return 2
			}
			SENDKEY_SEND clear
			return $?
			;;
		volume | brightness)
			SENDKEY_LEVEL=$1
			SENDKEY_DIRECTION=${2:-}
			SENDKEY_COUNT=${3:-1}
			case "$SENDKEY_DIRECTION" in
				up | U) SENDKEY_DIRECTION=U ;;
				down | D) SENDKEY_DIRECTION=D ;;
				*) SENDKEY_USAGE; return 2 ;;
			esac
			case "$SENDKEY_COUNT" in
				'' | *[!0-9]* | 0) SENDKEY_USAGE; return 2 ;;
			esac
			SENDKEY_INDEX=0
			while [ "$SENDKEY_INDEX" -lt "$SENDKEY_COUNT" ]; do
				RUN_DEVICE_SCRIPT "$([ "$SENDKEY_LEVEL" = volume ] && printf audio.sh || printf bright.sh)" \
					"$SENDKEY_DIRECTION" || return 1
				SENDKEY_INDEX=$((SENDKEY_INDEX + 1))
				[ "$SENDKEY_INDEX" -ge "$SENDKEY_COUNT" ] || SENDKEY_SLEEP 150
			done
			return 0
			;;
		repeat)
			SENDKEY_BUTTONS=${2:-}
			SENDKEY_COUNT=${3:-}
			SENDKEY_GAP=${4:-150}
			case "$SENDKEY_COUNT:$SENDKEY_GAP" in
				*[!0-9:]* | :* | *: | 0:*) SENDKEY_USAGE; return 2 ;;
			esac
			SENDKEY_INDEX=0
			while [ "$SENDKEY_INDEX" -lt "$SENDKEY_COUNT" ]; do
				SENDKEY "$SENDKEY_BUTTONS" || return 1
				SENDKEY_INDEX=$((SENDKEY_INDEX + 1))
				[ "$SENDKEY_INDEX" -ge "$SENDKEY_COUNT" ] || SENDKEY_SLEEP "$SENDKEY_GAP"
			done
			return 0
			;;
		stick)
			shift
			SENDKEY_TOTAL=$#
			[ "$SENDKEY_TOTAL" -ge 2 ] || {
				SENDKEY_USAGE
				return 2
			}
			SENDKEY_DURATION=100
			SENDKEY_MESSAGE=
			SENDKEY_RESET=
			SENDKEY_AXIS=
			SENDKEY_INDEX=0
			for SENDKEY_ARGUMENT do
				SENDKEY_INDEX=$((SENDKEY_INDEX + 1))
				if [ $((SENDKEY_TOTAL % 2)) -eq 1 ] && [ "$SENDKEY_INDEX" -eq "$SENDKEY_TOTAL" ]; then
					SENDKEY_DURATION=$SENDKEY_ARGUMENT
					break
				fi
				if [ -z "$SENDKEY_AXIS" ]; then
					case "$SENDKEY_ARGUMENT" in
						lx | ly | rx | ry) SENDKEY_AXIS=$SENDKEY_ARGUMENT ;;
						*) SENDKEY_USAGE; return 2 ;;
					esac
					SENDKEY_AVAILABLE "$SENDKEY_AXIS" || {
						printf 'SENDKEY: %s is not available on this device\n' "$SENDKEY_AXIS" >&2
						return 1
					}
				else
					case "$SENDKEY_ARGUMENT" in
						'' | *[!0-9.+-]*) SENDKEY_USAGE; return 2 ;;
					esac
					SENDKEY_NL='
'
					SENDKEY_MESSAGE="${SENDKEY_MESSAGE}${SENDKEY_MESSAGE:+$SENDKEY_NL}${SENDKEY_AXIS} $SENDKEY_ARGUMENT"
					SENDKEY_RESET="${SENDKEY_RESET}${SENDKEY_RESET:+$SENDKEY_NL}${SENDKEY_AXIS} 0"
					SENDKEY_AXIS=
				fi
			done
			[ -z "$SENDKEY_AXIS" ] && [ -n "$SENDKEY_MESSAGE" ] || {
				SENDKEY_USAGE
				return 2
			}
			case "$SENDKEY_DURATION" in
				'' | *[!0-9]*) SENDKEY_USAGE; return 2 ;;
			esac
			SENDKEY_LEFT=$SENDKEY_DURATION
			while [ "$SENDKEY_LEFT" -gt 0 ]; do
				SENDKEY_SEND "$SENDKEY_MESSAGE" || {
					SENDKEY_SEND clear >/dev/null 2>&1 || :
					return 1
				}
				[ "$SENDKEY_LEFT" -gt 200 ] && SENDKEY_STEP=200 || SENDKEY_STEP=$SENDKEY_LEFT
				SENDKEY_SLEEP "$SENDKEY_STEP"
				SENDKEY_LEFT=$((SENDKEY_LEFT - SENDKEY_STEP))
			done
			SENDKEY_SEND "$SENDKEY_RESET"
			return $?
			;;
		hold)
			SENDKEY_BUTTONS=${2:-}
			SENDKEY_DURATION=${3:-1000}
			;;
		*)
			SENDKEY_BUTTONS=$1
			SENDKEY_DURATION=${2:-100}
			;;
	esac

	case "$SENDKEY_DURATION" in
		'' | *[!0-9]* | 0) SENDKEY_USAGE; return 2 ;;
	esac
	case "$SENDKEY_BUTTONS" in
		'' | *[!A-Za-z0-9_+-]*) SENDKEY_USAGE; return 2 ;;
	esac

	SENDKEY_BUTTONS=$(printf '%s' "$SENDKEY_BUTTONS" | tr '[:upper:]_+' '[:lower:]  ')
	SENDKEY_PRESS=
	SENDKEY_RELEASE=
	SENDKEY_NL='
'
	for SENDKEY_BUTTON in $SENDKEY_BUTTONS; do
		case "$SENDKEY_BUTTON" in
			dpadup) SENDKEY_BUTTON=up ;;
			dpaddown) SENDKEY_BUTTON=down ;;
			dpadleft) SENDKEY_BUTTON=left ;;
			dpadright) SENDKEY_BUTTON=right ;;
		esac
		case "$SENDKEY_BUTTON" in
			up | down | left | right | a | b | x | y | l1 | r1 | l2 | r2 | l3 | r3 | select | start | menu) ;;
			*) printf 'SENDKEY: unknown button %s\n' "$SENDKEY_BUTTON" >&2; return 2 ;;
		esac
		SENDKEY_AVAILABLE "$SENDKEY_BUTTON" || {
			printf 'SENDKEY: %s is not available on this device\n' "$SENDKEY_BUTTON" >&2
			return 1
		}
		SENDKEY_PRESS="${SENDKEY_PRESS}${SENDKEY_PRESS:+$SENDKEY_NL}${SENDKEY_BUTTON} 1"
		SENDKEY_RELEASE="${SENDKEY_RELEASE}${SENDKEY_RELEASE:+$SENDKEY_NL}${SENDKEY_BUTTON} 0"
	done

	SENDKEY_LEFT=$SENDKEY_DURATION
	while [ "$SENDKEY_LEFT" -gt 0 ]; do
		SENDKEY_SEND "$SENDKEY_PRESS" || {
			SENDKEY_SEND clear >/dev/null 2>&1 || :
			return 1
		}
		[ "$SENDKEY_LEFT" -gt 750 ] && SENDKEY_STEP=750 || SENDKEY_STEP=$SENDKEY_LEFT
		SENDKEY_SLEEP "$SENDKEY_STEP"
		SENDKEY_LEFT=$((SENDKEY_LEFT - SENDKEY_STEP))
	done
	SENDKEY_SEND "$SENDKEY_RELEASE" || {
		SENDKEY_SEND clear >/dev/null 2>&1 || :
		return 1
	}
}

