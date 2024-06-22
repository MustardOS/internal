#!/bin/sh

. /opt/muos/script/system/parse.sh

CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

mkdir -p /tmp/combo
mkdir -p /tmp/trigger

killall -q "evtest"

INPUT_DEVICE_0="$(parse_ini "$DEVICE_CONFIG" "input" "ev0")" # Power buttons
INPUT_DEVICE_1="$(parse_ini "$DEVICE_CONFIG" "input" "ev1")" # Everything else!

. /opt/muos/device/"$DEVICE"/input/map.sh

KEY_COMBO=0

# Place combo and trigger scripts here because fuck knows why for loops won't work...
# Make sure to put them in order of how you want them to work too!
FACTORY_RESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORY_RESET" -eq 0 ]; then
	/opt/muos/device/"$DEVICE"/input/trigger/power.sh &
	/opt/muos/device/"$DEVICE"/input/trigger/sleep.sh &
else
	echo "awake" > "/tmp/sleep_state"
fi

{
	evtest "$INPUT_DEVICE_0" &
	evtest "$INPUT_DEVICE_1" &
	wait
} | while read -r EVENT; do

#	# KEY COMBO EXAMPLE
#	# combo variable is set to stop double triggers!
#        if [ $STATE_A -eq 1 ] && [ $STATE_B -eq 1 ] && [ $KEY_COMBO -eq 0 ]; then
#        	KEY_COMBO=1
#        	# Use the following for other scripts to pick up the combo then delete the file in the other script!
#        	touch /tmp/combo/AB
#        	echo "Combo A + B detected"
#        elif [ $STATE_A -eq 0 ] || [ $STATE_B -eq 0 ]; then
#        	KEY_COMBO=0
#        fi
#
#        # KEY TRIGGER COUNT EXAMPLE
#        if [ $COUNT_UP -eq 5 ]; then
#        	COUNT_UP=0
#        	# Use the following for other scripts to pick up the trigger then delete the file in the other script!
#        	touch /tmp/trigger/UP
#        	echo "Trigger of UP detected"
#        fi

        if [ $STATE_MENU_LONG -eq 1 ] && [ $STATE_VOL_UP -eq 1 ] && [ $KEY_COMBO -eq 0 ]; then
        	KEY_COMBO=1
        	/opt/muos/device/"$DEVICE"/input/combo/bright.sh U
        	STATE_VOL_UP=0
        	KEY_COMBO=0
        elif [ $STATE_MENU_LONG -eq 0 ] || [ $STATE_VOL_UP -eq 0 ]; then
        	KEY_COMBO=0
        fi

        if [ $STATE_MENU_LONG -eq 1 ] && [ $STATE_VOL_DOWN -eq 1 ] && [ $KEY_COMBO -eq 0 ]; then
        	KEY_COMBO=1
        	/opt/muos/device/"$DEVICE"/input/combo/bright.sh D
        	STATE_VOL_DOWN=0
        	KEY_COMBO=0
        elif [ $STATE_MENU_LONG -eq 0 ] || [ $STATE_VOL_DOWN -eq 0 ]; then
        	KEY_COMBO=0
        fi

        if [ $STATE_MENU_LONG -eq 1 ] && [ $STATE_POWER_SHORT -eq 1 ] && [ $KEY_COMBO -eq 0 ]; then
        	KEY_COMBO=1
        	/opt/muos/device/"$DEVICE"/input/combo/screenshot.sh
        	STATE_MENU_LONG=0
        	STATE_POWER_SHORT=0
        	KEY_COMBO=0
        elif [ $STATE_MENU_LONG -eq 0 ] || [ $STATE_POWER_SHORT -eq 0 ]; then
        	KEY_COMBO=0
        fi

        if [ $STATE_MENU_LONG -eq 0 ] && [ $STATE_VOL_UP -eq 1 ] && [ $KEY_COMBO -eq 0 ]; then
        	KEY_COMBO=1
		/opt/muos/device/"$DEVICE"/input/combo/audio.sh U
        	STATE_MENU_LONG=0
        	STATE_VOL_UP=0
        	KEY_COMBO=0
        elif [ $STATE_MENU_LONG -eq 0 ] || [ $STATE_VOL_UP -eq 0 ]; then
		COUNT_MENU_LONG=0
		COUNT_VOL_UP=0
        	KEY_COMBO=0
        fi

        if [ $STATE_MENU_LONG -eq 0 ] && [ $STATE_VOL_DOWN -eq 1 ] && [ $KEY_COMBO -eq 0 ]; then
        	KEY_COMBO=1
		/opt/muos/device/"$DEVICE"/input/combo/audio.sh D
        	STATE_MENU_LONG=0
        	STATE_VOL_DOWN=0
        	KEY_COMBO=0
        elif [ $STATE_MENU_LONG -eq 0 ] || [ $STATE_VOL_DOWN -eq 0 ]; then
		COUNT_MENU_LONG=0
		COUNT_VOL_DOWN=0
        	KEY_COMBO=0
        fi

        if [ $COUNT_POWER_LONG -eq 1 ]; then
        	TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
		HALL_KEY=/sys/devices/platform/soc/twi5/i2c-5/5-0034/axp2202-bat-power-supply.0/power_supply/axp2202-battery/hallkey
		if [ ! -e $TMP_POWER_LONG ]; then
			echo on > $TMP_POWER_LONG
		fi
		if [ "$(cat $HALL_KEY)" = "1" ]; then
        		if [ "$(cat $TMP_POWER_LONG)" = "off" ]; then
	        		echo on > $TMP_POWER_LONG
	        	else
	        		echo off > $TMP_POWER_LONG
	        	fi
		fi
		COUNT_POWER_LONG=0
        fi

	case $EVENT in
		$PRESS_UP)
			STATE_UP=1
			COUNT_UP=$((COUNT_UP+1))
			echo "BTN_UP pressed - $COUNT_UP"
			;;
		$RELEASE_UP) # The following is required as the same release state is in both keys!
			if [ $STATE_UP -eq 1 ] || [ $STATE_DOWN -eq 1 ]; then
				if [ $STATE_DOWN -eq 1 ]; then
					STATE_DOWN=0
					echo "BTN_DOWN released"
				else
					STATE_UP=0
					echo "BTN_UP released"
				fi
			fi
			;;
		$PRESS_DOWN)
			STATE_DOWN=1
			COUNT_DOWN=$((COUNT_DOWN+1))
			echo "BTN_DOWN pressed - $COUNT_DOWN"
			;;
		$PRESS_LEFT)
			STATE_LEFT=1
			COUNT_LEFT=$((COUNT_LEFT+1))
			echo "BTN_LEFT pressed - $COUNT_LEFT"
			;;
		$RELEASE_LEFT) # The following is required as the same release state is in both keys!
			if [ $STATE_LEFT -eq 1 ] || [ $STATE_RIGHT -eq 1 ]; then
				if [ $STATE_RIGHT -eq 1 ]; then
					STATE_RIGHT=0
					echo "BTN_RIGHT released"
				else
					STATE_LEFT=0
					echo "BTN_LEFT released"
				fi
			fi
			;;
		$PRESS_RIGHT)
			STATE_RIGHT=1
			COUNT_RIGHT=$((COUNT_RIGHT+1))
			echo "BTN_RIGHT pressed - $COUNT_RIGHT"
			;;
		$PRESS_A)
			STATE_A=1
			COUNT_A=$((COUNT_A+1))
			echo "BTN_A pressed - $COUNT_A"
			;;
		$RELEASE_A)
			if [ $STATE_A -eq 1 ]; then
				STATE_A=0
				echo "BTN_A released"
			fi
			;;
		$PRESS_B)
			STATE_B=1
			COUNT_B=$((COUNT_B+1))
			echo "BTN_B pressed - $COUNT_B"
			;;
		$RELEASE_B)
			if [ $STATE_B -eq 1 ]; then
				STATE_B=0
				echo "BTN_B released"
			fi
			;;
		$PRESS_X)
			STATE_X=1
			COUNT_X=$((COUNT_X+1))
			echo "BTN_X pressed - $COUNT_X"
			;;
		$RELEASE_X)
			if [ $STATE_X -eq 1 ]; then
				STATE_X=0
				echo "BTN_X released"
			fi
			;;
		$PRESS_Y)
			STATE_Y=1
			COUNT_Y=$((COUNT_Y+1))
			echo "BTN_Y pressed - $COUNT_Y"
			;;
		$RELEASE_Y)
			if [ $STATE_Y -eq 1 ]; then
				STATE_Y=0
				echo "BTN_Y released"
			fi
			;;
		$PRESS_SELECT)
			STATE_SELECT=1
			COUNT_SELECT=$((COUNT_SELECT+1))
			echo "BTN_SELECT pressed - $COUNT_SELECT"
			;;
		$RELEASE_SELECT)
			if [ $STATE_SELECT -eq 1 ]; then
				STATE_SELECT=0
				echo "BTN_SELECT released"
			fi
			;;
		$PRESS_START)
			STATE_START=1
			COUNT_START=$((COUNT_START+1))
			echo "BTN_START pressed - $COUNT_START"
			;;
		$RELEASE_START)
			if [ $STATE_START -eq 1 ]; then
				STATE_START=0
				echo "BTN_START released"
			fi
			;;
		$PRESS_MENU_SHORT)
			STATE_MENU_SHORT=1
			COUNT_MENU_SHORT=$((COUNT_MENU_SHORT+1))
			echo "BTN_MENU_SHORT pressed - $COUNT_MENU_SHORT"
			;;
		$RELEASE_MENU_SHORT)
			if [ $STATE_MENU_SHORT -eq 1 ]; then
				STATE_MENU_SHORT=0
				echo "BTN_MENU_SHORT released"
			fi
			;;
		$PRESS_MENU_LONG)
			STATE_MENU_LONG=1
			COUNT_MENU_LONG=$((COUNT_MENU_LONG+1))
			echo "BTN_MENU_LONG pressed - $COUNT_MENU_LONG"
			;;
		$RELEASE_MENU_LONG)
			if [ $STATE_MENU_LONG -eq 1 ]; then
				STATE_MENU_LONG=0
				echo "BTN_MENU_LONG released"
			fi
			;;
		$PRESS_L1)
			STATE_L1=1
			COUNT_L1=$((COUNT_L1+1))
			echo "BTN_L1 pressed - $COUNT_L1"
			;;
		$RELEASE_L1)
			if [ $STATE_L1 -eq 1 ]; then
				STATE_L1=0
				echo "BTN_L1 released"
			fi
			;;
		$PRESS_R1)
			STATE_R1=1
			COUNT_R1=$((COUNT_R1+1))
			echo "BTN_R1 pressed - $COUNT_R1"
			;;
		$RELEASE_R1)
			if [ $STATE_R1 -eq 1 ]; then
				STATE_R1=0
				echo "BTN_R1 released"
			fi
			;;
		$PRESS_L2)
			STATE_L2=1
			COUNT_L2=$((COUNT_L2+1))
			echo "BTN_L2 pressed - $COUNT_L2"
			;;
		$RELEASE_L2)
			if [ $STATE_L2 -eq 1 ]; then
				STATE_L2=0
				echo "BTN_L2 released"
			fi
			;;
		$PRESS_R2)
			STATE_R2=1
			COUNT_R2=$((COUNT_R2+1))
			echo "BTN_R2 pressed - $COUNT_R2"
			;;
		$RELEASE_R2)
			if [ $STATE_R2 -eq 1 ]; then
				STATE_R2=0
				echo "BTN_R2 released"
			fi
			;;
		$PRESS_VOL_UP)
			STATE_VOL_UP=1
			COUNT_VOL_UP=$((COUNT_VOL_UP+1))
			echo "BTN_VOL_UP pressed - $COUNT_VOL_UP"
			;;
		$RELEASE_VOL_UP)
			if [ $STATE_VOL_UP -eq 1 ]; then
				STATE_VOL_UP=0
				echo "BTN_VOL_UP released"
			fi
			;;
		$PRESS_VOL_DOWN)
			STATE_VOL_DOWN=1
			COUNT_VOL_DOWN=$((COUNT_VOL_DOWN+1))
			echo "BTN_VOL_DOWN pressed - $COUNT_VOL_DOWN"
			;;
		$RELEASE_VOL_DOWN)
			if [ $STATE_VOL_DOWN -eq 1 ]; then
				STATE_VOL_DOWN=0
				echo "BTN_VOL_DOWN released"
			fi
			;;
		$PRESS_POWER_SHORT)
			STATE_POWER_SHORT=1
			COUNT_POWER_SHORT=$((COUNT_POWER_SHORT+1))
			echo "BTN_POWER_SHORT pressed - $COUNT_POWER_SHORT"
			;;
		$RELEASE_POWER_SHORT)
			if [ $STATE_POWER_LONG -eq 1 ]; then
				STATE_POWER_LONG=0
				echo "BTN_POWER_LONG released"
			else
				STATE_POWER_SHORT=0
				echo "BTN_POWER_SHORT released"
			fi
			;;
		$PRESS_POWER_LONG)
			if [ $STATE_POWER_LONG -eq 0 ]; then
				STATE_POWER_LONG=1
				COUNT_POWER_LONG=$((COUNT_POWER_LONG+1))
				echo "BTN_POWER_LONG pressed - $COUNT_POWER_LONG"
			fi
			;;
	esac
done &

