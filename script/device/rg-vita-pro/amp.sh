#!/bin/sh

. /opt/muos/script/var/func.sh

# Initialise external speaker amp (TAS58xx, I2C bus 3)
LOG_INFO "$0" 0 "PIPEWIRE" "Initialising speaker amplifier"
for addr in 0x58 0x5b; do
	attempt=1
	while :; do
		i2cset -y 3 $addr 0x03 0x00 &&
			i2cset -y 3 $addr 0x01 0x07 &&
			i2cset -y 3 $addr 0x01 0x3f &&
			i2cset -y 3 $addr 0x03 0x01 && break

		if [ "$attempt" -ge 10 ]; then
			LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "Speaker amplifier %s did not respond" "$addr")"
			break
		fi

		attempt=$((attempt + 1))
		sleep 0.5
	done
done
