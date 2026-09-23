#!/bin/sh

. /opt/muos/script/var/func.sh

# Some boards wire their indicator LEDs straight to GPIOs with no leds-gpio node
# behind them, so /sys/class/leds is empty and there is nothing for led/normal
# and led/low to point at. Export the lines here and mark them active low, which
# keeps those config values ordinary "write 1 or 0" paths for every caller.
#
# Usage: led.sh [init|boot|shutdown]
#   init      set the lines up and leave them dark, the default
#   boot      as above, then sweep upwards until the boot progress finishes
#   shutdown  as above, then sweep downwards and leave the charge light latched

# GPIO1: 42 is LED 1 red, 44 is LED 1 green, 45 to 47 are LEDs 2 to 4.
LED_GPIO_ALL="42 44 45 46 47"
LED_RED=42

# Sweep the green of LED 1 and then LEDs 2 to 4, so the run is a single colour.
LED_SWEEP_UP="44 45 46 47"
LED_SWEEP_DOWN="47 46 45 44"

LED_STEP_SLEEP=0.15

# Boot runs until the progress flag appears, with this as a hard stop. Shutdown
# has nothing to wait for, so it runs a fixed handful of cycles.
LED_BOOT_MAX_CYCLE=40
LED_SHUTDOWN_CYCLE=3

LED_VALUE_PATH() {
	printf '/sys/class/gpio/gpio%s/value' "$1"
}

LED_SET() {
	echo "$2" >"$(LED_VALUE_PATH "$1")" 2>/dev/null
}

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

# Every loop here uses its own variable name. Shell functions share the caller's
# scope, so a shared name would leave the caller's loop variable pinned to the
# last line this touched, and the sweep would sit on one LED instead of moving.
LED_ALL_OFF() {
	for LED_OFF_GPIO in $LED_GPIO_ALL; do
		LED_SET "$LED_OFF_GPIO" 0
	done
}

# LED_SWEEP <gpio list> <max cycles> <stop when this file exists, or empty>
LED_SWEEP() {
	LED_SWEEP_LIST="$1"
	LED_SWEEP_MAX="$2"
	LED_SWEEP_UNTIL="$3"
	LED_CYCLE=0

	while [ "$LED_CYCLE" -lt "$LED_SWEEP_MAX" ]; do
		[ -n "$LED_SWEEP_UNTIL" ] && [ -e "$LED_SWEEP_UNTIL" ] && break

		for LED_SWEEP_GPIO in $LED_SWEEP_LIST; do
			LED_ALL_OFF
			LED_SET "$LED_SWEEP_GPIO" 1
			sleep "$LED_STEP_SLEEP"
		done

		LED_CYCLE=$((LED_CYCLE + 1))
	done

	LED_ALL_OFF
}

case "$(GET_VAR "device" "board/name")" in
	rk-pixel-2)
		LED_SETUP

		case "${1:-init}" in
			boot) LED_SWEEP "$LED_SWEEP_UP" "$LED_BOOT_MAX_CYCLE" "$BOOT_PROGRESS_DONE" ;;
			shutdown)
				LED_SWEEP "$LED_SWEEP_DOWN" "$LED_SHUTDOWN_CYCLE" ""

				# Leave the charge light latched. Nothing runs once the system is
				# down - no scripts and no kernel, since this board has no charge
				# boot mode - so this latched line is the only off state charge
				# indication there can be, and it is what the hardware default
				# gave before muOS started driving these lines.
				LED_SET "$LED_RED" 1
				;;
		esac
		;;
esac
