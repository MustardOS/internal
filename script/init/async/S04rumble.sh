#!/bin/sh

BOARD_NAME=$(GET_VAR "device" "board/name")
RUMBLE_PIN=$(GET_VAR "device" "board/rumble")

RUMBLE_SETTING=$(GET_VAR "config" "settings/advanced/rumble")

DO_START() {
	case "$BOARD_NAME" in
		mgx* | tui*)
			[ -e /sys/class/gpio/gpio227 ] || printf "227" >/sys/class/gpio/export
			printf "out" >/sys/class/gpio/gpio227/direction
			printf "0" >/sys/class/gpio/gpio227/value
			;;
		rk-g350-v)
			G350_RUMBLE_GPIO=/sys/class/gpio/gpio15
			[ -d "$G350_RUMBLE_GPIO" ] || printf '%s' 15 >/sys/class/gpio/export 2>/dev/null
			[ ! -d "$G350_RUMBLE_GPIO" ] || printf '%s' low >"$G350_RUMBLE_GPIO/direction"
			;;
		rk*)
			[ -e /sys/class/pwm/pwmchip0/pwm0 ] || printf "0" >/sys/class/pwm/pwmchip0/export
			printf "1000000" >/sys/class/pwm/pwmchip0/pwm0/period
			printf "1000000" >/sys/class/pwm/pwmchip0/pwm0/duty_cycle
			printf "1" >/sys/class/pwm/pwmchip0/pwm0/enable
			;;
		rg-vita*)
			[ -e /sys/class/pwm/pwmchip1/pwm0 ] || printf "0" >/sys/class/pwm/pwmchip1/export
			printf "100000" >/sys/class/pwm/pwmchip1/pwm0/period
			printf "100000" >/sys/class/pwm/pwmchip1/pwm0/duty_cycle
			printf "1" >/sys/class/pwm/pwmchip1/pwm0/enable
			;;
	esac

	LOG_INFO "$0" 0 "BOOTING" "Device Rumble Check"
	case "$BOARD_NAME:$RUMBLE_SETTING" in
		rk-g350-v:*) ;;
		*:1 | *:4 | *:5) RUMBLE "$RUMBLE_PIN" 0.3 ;;
	esac
}

case "$1" in
	start)
		DO_START
		;;
	stop)
		# GPIO and PWM state is not reversible at runtime
		;;
	restart)
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
