#!/bin/sh

. /opt/muos/script/var/log.sh

# The board DTS identifies a left/right AW87391 pair on I2C bus 3.
AMP_BUS=3
AMP_ADDRESSES="0x58 0x5b"
AMP_SYSCTRL=0x01
AMP_CONFIG=0x03

AMP_START() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Initialising AW87391 speaker amplifiers"
	for AMP_ADDRESS in $AMP_ADDRESSES; do
		ATTEMPT=1
		while :; do
			i2cset -y "$AMP_BUS" "$AMP_ADDRESS" "$AMP_CONFIG" 0x00 &&
				i2cset -y "$AMP_BUS" "$AMP_ADDRESS" "$AMP_SYSCTRL" 0x07 &&
				i2cset -y "$AMP_BUS" "$AMP_ADDRESS" "$AMP_SYSCTRL" 0x3f &&
				i2cset -y "$AMP_BUS" "$AMP_ADDRESS" "$AMP_CONFIG" 0x01 && break

			if [ "$ATTEMPT" -ge 10 ]; then
				LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "AW87391 amplifier %s did not respond" "$AMP_ADDRESS")"
				break
			fi

			ATTEMPT=$((ATTEMPT + 1))
			sleep 0.5
		done
	done
}

AMP_STOP() {
	for AMP_ADDRESS in $AMP_ADDRESSES; do
		[ -e "/sys/bus/i2c/devices/$AMP_BUS-00${AMP_ADDRESS#0x}" ] || continue
		i2cset -f -y "$AMP_BUS" "$AMP_ADDRESS" "$AMP_SYSCTRL" 0x00 2>/dev/null
	done
}

case "${1:-start}" in
	start) AMP_START ;;
	stop) AMP_STOP ;;
	*) exit 2 ;;
esac
