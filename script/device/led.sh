#!/bin/sh

. /opt/muos/script/var/func.sh

# Some boards wire their indicator LEDs straight to GPIOs with no leds-gpio node
# behind them, so /sys/class/leds is empty and there is nothing for led/normal
# and led/low to point at. Export the lines here and mark them active low, which
# keeps those config values ordinary "write 1 or 0" paths for every caller.

# GPIO1: 42 is LED 1 red, 44 is LED 1 green, 45 to 47 are LEDs 2 to 4.
LED_GPIO_ALL="42 44 45 46 47"

# Exporting a line does not make its attributes appear immediately, and this
# runs early enough in boot for that to matter. Without the wait the setup below
# is skipped, active_low never gets set, and every later write is inverted.
# Same guard as G350_INITIALISE_RUMBLE_GPIO in script/init/sysinit.
LED_WAIT_FOR_GPIO() {
	LED_ATTEMPT=0

	while [ ! -e "$1/active_low" ] && [ "$LED_ATTEMPT" -lt 20 ]; do
		LED_ATTEMPT=$((LED_ATTEMPT + 1))
		sleep 0.05
	done

	[ -e "$1/active_low" ]
}

LED_SETUP() {
	for LED_SETUP_GPIO in $LED_GPIO_ALL; do
		LED_DIR="/sys/class/gpio/gpio$LED_SETUP_GPIO"

		[ -d "$LED_DIR" ] || echo "$LED_SETUP_GPIO" >/sys/class/gpio/export 2>/dev/null
		LED_WAIT_FOR_GPIO "$LED_DIR" || continue

		# Order matters. Writing "out" drives the line low, which with active_low
		# already set would read as lit, so the explicit 0 goes last.
		echo out >"$LED_DIR/direction" 2>/dev/null
		echo 1 >"$LED_DIR/active_low" 2>/dev/null
		echo 0 >"$LED_DIR/value" 2>/dev/null
	done
}

case "$(GET_VAR "device" "board/name")" in
	rk-pixel-2) LED_SETUP ;;
esac
