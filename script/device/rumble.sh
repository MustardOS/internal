#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")

case "$BOARD_NAME" in
	tui*)
		[ -e /sys/class/gpio/gpio227 ] || echo 227 >/sys/class/gpio/export
		echo out >/sys/class/gpio/gpio227/direction
		echo 0 >/sys/class/gpio/gpio227/value
		;;
	rk*)
		[ -e /sys/class/pwm/pwmchip0/pwm0 ] || echo 0 >/sys/class/pwm/pwmchip0/export
		echo 1000000 >/sys/class/pwm/pwmchip0/pwm0/period
		echo 1000000 >/sys/class/pwm/pwmchip0/pwm0/duty_cycle
		echo 1 >/sys/class/pwm/pwmchip0/pwm0/enable
		;;
esac
