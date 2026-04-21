#!/bin/sh

. /opt/muos/script/var/func.sh


case "$(GET_VAR "device" "board/name")" in
	rg-vita*)
		# Initialise external speaker amp (TAS58xx, I2C bus 3)
		LOG_INFO "$0" 0 "PIPEWIRE" "Initialising speaker amplifier"
		for addr in 0x58 0x5b; do
			i2cset -y 3 $addr 0x03 0x00
			i2cset -y 3 $addr 0x01 0x07
			i2cset -y 3 $addr 0x01 0x3f
			i2cset -y 3 $addr 0x03 0x01
		done
	    ;;
esac
