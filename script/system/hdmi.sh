#!/bin/sh

mount -t debugfs debugfs /sys/kernel/debug
DISPLAY="/sys/kernel/debug/dispdbg"

RESET_DISP=0

SWITCHED_ON=0
SWITCHED_OFF=0

# Enable VSYNC
echo disp0 > $DISPLAY/name
echo vsync_enable > $DISPLAY/command
echo 1 > $DISPLAY/param
echo 1 > $DISPLAY/start

while true; do
	if [ "$(cat "/sys/devices/platform/soc/6000000.hdmi/extcon/hdmi/state")" = "HDMI=1" ]; then
		SWITCHED_OFF=0

		if [ $SWITCHED_ON -eq 0 ]; then
			RESET_DISP=0

			# Blank the screen
			echo disp0 > $DISPLAY/name
			echo blank > $DISPLAY/command
			echo 1 > $DISPLAY/param
			echo 1 > $DISPLAY/start;

			# Switch on HDMI
			echo disp0 > $DISPLAY/name
			echo switch1 > $DISPLAY/command
			echo 4 10 0 0 0x4 0x101 0 0 0 8 > $DISPLAY/param
			echo 1 > $DISPLAY/start

			# Reset the display
			if [ $RESET_DISP -eq 0 ]; then
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				RESET_DISP=1
			fi

			# Unblank the screen
			echo disp0 > $DISPLAY/name
			echo blank > $DISPLAY/command
			echo 0 > $DISPLAY/param
			echo 1 > $DISPLAY/start;

			SWITCHED_ON=1
		fi
	else
		SWITCHED_ON=0

		if [ $SWITCHED_OFF -eq 0 ]; then
			RESET_DISP=0

			# Blank the screen
			echo disp0 > $DISPLAY/name
			echo blank > $DISPLAY/command
			echo 1 > $DISPLAY/param
			echo 1 > $DISPLAY/start;

			# Switch off HDMI
			echo disp0 > $DISPLAY/name
			echo switch > $DISPLAY/command
			echo 1 0 > $DISPLAY/param
			echo 1 > $DISPLAY/start

			# Reset the display
			if [ $RESET_DISP -eq 0 ]; then
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				fbset -g 1280 720 1280 1440 32
				fbset -g 640 480 640 960 32
				RESET_DISP=1
			fi

			# Unblank the screen
			echo disp0 > $DISPLAY/name
			echo blank > $DISPLAY/command
			echo 0 > $DISPLAY/param
			echo 1 > $DISPLAY/start;

			SWITCHED_OFF=1
		fi
	fi
	sleep 3
done

