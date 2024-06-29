#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/input.sh

. /opt/muos/script/var/global/boot.sh
. /opt/muos/script/var/global/setting_advanced.sh

mkdir -p /tmp/combo
mkdir -p /tmp/trigger

killall -q "evtest"

. /opt/muos/device/"$DEVICE_TYPE"/input/map.sh

KEY_COMBO=0

# Place combo and trigger scripts here because fuck knows why for loops won't work...
# Make sure to put them in order of how you want them to work too!
if [ "$GC_BOO_FACTORY_RESET" -eq 0 ]; then
	/opt/muos/device/"$DEVICE_TYPE"/input/trigger/power.sh &
	/opt/muos/device/"$DEVICE_TYPE"/input/trigger/sleep.sh &
else
	echo "awake" >"/tmp/sleep_state"
fi

{
	evtest "$DC_INP_EVENT_0" &
	evtest "$DC_INP_EVENT_1" &
	wait
} | while read -r EVENT; do

	if [ $KEY_COMBO -eq 0 ]; then
		case $STATE_START in
			1)
				KEY_COMBO=1
				if [ "$GC_ADV_RETROWAIT" -eq 1 ]; then
					echo 2 >"/tmp/net_connected"
				fi
				;;
		esac

		case $STATE_SELECT in
			1)
				KEY_COMBO=1
				if [ "$GC_ADV_RETROWAIT" -eq 1 ]; then
					echo 3 >"/tmp/net_connected"
				fi
				;;
		esac

		case "$STATE_MENU_LONG:$STATE_VOL_UP:$STATE_VOL_DOWN:$STATE_POWER_SHORT" in
			1:1:0:0)
				KEY_COMBO=1
				/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh U
				;;
			1:0:1:0)
				KEY_COMBO=1
				/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh D
				;;
			1:0:0:1)
				KEY_COMBO=1
				/opt/muos/device/"$DEVICE_TYPE"/input/combo/screenshot.sh
				;;
			0:1:0:0)
				KEY_COMBO=1
				/opt/muos/device/"$DEVICE_TYPE"/input/combo/audio.sh U
				;;
			0:0:1:0)
				KEY_COMBO=1
				/opt/muos/device/"$DEVICE_TYPE"/input/combo/audio.sh D
				;;
		esac
	fi

	if [ $COUNT_POWER_LONG -eq 1 ]; then
		TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
		HALL_KEY="/sys/class/power_supply/axp2202-battery/hallkey"
		if [ ! -e $TMP_POWER_LONG ]; then
			echo on >$TMP_POWER_LONG
		fi
		if [ "$(cat $HALL_KEY)" = "1" ]; then
			if [ "$(cat $TMP_POWER_LONG)" = "off" ]; then
				echo on >$TMP_POWER_LONG
			else
				echo off >$TMP_POWER_LONG
			fi
		fi
		COUNT_POWER_LONG=0
	fi

	case $EVENT in
		$PRESS_UP)
			STATE_UP=1
			COUNT_UP=$((COUNT_UP + 1))
			;;
		$RELEASE_UP) # The following is required as the same release state is in both keys!
			if [ $STATE_UP -eq 1 ] || [ $STATE_DOWN -eq 1 ]; then
				if [ $STATE_DOWN -eq 1 ]; then
					KEY_COMBO=0
					STATE_DOWN=0
				else
					KEY_COMBO=0
					STATE_UP=0
				fi
			fi
			;;
		$PRESS_DOWN)
			STATE_DOWN=1
			COUNT_DOWN=$((COUNT_DOWN + 1))
			;;
		$PRESS_LEFT)
			STATE_LEFT=1
			COUNT_LEFT=$((COUNT_LEFT + 1))
			;;
		$RELEASE_LEFT) # The following is required as the same release state is in both keys!
			if [ $STATE_LEFT -eq 1 ] || [ $STATE_RIGHT -eq 1 ]; then
				if [ $STATE_RIGHT -eq 1 ]; then
					KEY_COMBO=0
					STATE_RIGHT=0
				else
					KEY_COMBO=0
					STATE_LEFT=0
				fi
			fi
			;;
		$PRESS_RIGHT)
			STATE_RIGHT=1
			COUNT_RIGHT=$((COUNT_RIGHT + 1))
			;;
		$PRESS_A)
			STATE_A=1
			COUNT_A=$((COUNT_A + 1))
			;;
		$RELEASE_A)
			if [ $STATE_A -eq 1 ]; then
				KEY_COMBO=0
				STATE_A=0
			fi
			;;
		$PRESS_B)
			STATE_B=1
			COUNT_B=$((COUNT_B + 1))
			;;
		$RELEASE_B)
			if [ $STATE_B -eq 1 ]; then
				KEY_COMBO=0
				STATE_B=0
			fi
			;;
		$PRESS_X)
			STATE_X=1
			COUNT_X=$((COUNT_X + 1))
			;;
		$RELEASE_X)
			if [ $STATE_X -eq 1 ]; then
				KEY_COMBO=0
				STATE_X=0
			fi
			;;
		$PRESS_Y)
			STATE_Y=1
			COUNT_Y=$((COUNT_Y + 1))
			;;
		$RELEASE_Y)
			if [ $STATE_Y -eq 1 ]; then
				KEY_COMBO=0
				STATE_Y=0
			fi
			;;
		$PRESS_SELECT)
			STATE_SELECT=1
			COUNT_SELECT=$((COUNT_SELECT + 1))
			;;
		$RELEASE_SELECT)
			if [ $STATE_SELECT -eq 1 ]; then
				KEY_COMBO=0
				STATE_SELECT=0
			fi
			;;
		$PRESS_START)
			STATE_START=1
			COUNT_START=$((COUNT_START + 1))
			;;
		$RELEASE_START)
			if [ $STATE_START -eq 1 ]; then
				KEY_COMBO=0
				STATE_START=0
			fi
			;;
		$PRESS_MENU_SHORT)
			STATE_MENU_SHORT=1
			COUNT_MENU_SHORT=$((COUNT_MENU_SHORT + 1))
			;;
		$RELEASE_MENU_SHORT)
			if [ $STATE_MENU_SHORT -eq 1 ]; then
				KEY_COMBO=0
				STATE_MENU_SHORT=0
			fi
			;;
		$PRESS_MENU_LONG)
			STATE_MENU_LONG=1
			COUNT_MENU_LONG=$((COUNT_MENU_LONG + 1))
			;;
		$RELEASE_MENU_LONG)
			if [ $STATE_MENU_LONG -eq 1 ]; then
				KEY_COMBO=0
				STATE_MENU_LONG=0
			fi
			;;
		$PRESS_L1)
			STATE_L1=1
			COUNT_L1=$((COUNT_L1 + 1))
			;;
		$RELEASE_L1)
			if [ $STATE_L1 -eq 1 ]; then
				KEY_COMBO=0
				STATE_L1=0
			fi
			;;
		$PRESS_R1)
			STATE_R1=1
			COUNT_R1=$((COUNT_R1 + 1))
			;;
		$RELEASE_R1)
			if [ $STATE_R1 -eq 1 ]; then
				KEY_COMBO=0
				STATE_R1=0
			fi
			;;
		$PRESS_L2)
			STATE_L2=1
			COUNT_L2=$((COUNT_L2 + 1))
			;;
		$RELEASE_L2)
			if [ $STATE_L2 -eq 1 ]; then
				KEY_COMBO=0
				STATE_L2=0
			fi
			;;
		$PRESS_R2)
			STATE_R2=1
			COUNT_R2=$((COUNT_R2 + 1))
			;;
		$RELEASE_R2)
			if [ $STATE_R2 -eq 1 ]; then
				KEY_COMBO=0
				STATE_R2=0
			fi
			;;
		$PRESS_VOL_UP)
			STATE_VOL_UP=1
			COUNT_VOL_UP=$((COUNT_VOL_UP + 1))
			;;
		$RELEASE_VOL_UP)
			if [ $STATE_VOL_UP -eq 1 ]; then
				KEY_COMBO=0
				STATE_VOL_UP=0
			fi
			;;
		$PRESS_VOL_DOWN)
			STATE_VOL_DOWN=1
			COUNT_VOL_DOWN=$((COUNT_VOL_DOWN + 1))
			;;
		$RELEASE_VOL_DOWN)
			if [ $STATE_VOL_DOWN -eq 1 ]; then
				KEY_COMBO=0
				STATE_VOL_DOWN=0
			fi
			;;
		$PRESS_POWER_SHORT)
			STATE_POWER_SHORT=1
			COUNT_POWER_SHORT=$((COUNT_POWER_SHORT + 1))
			;;
		$RELEASE_POWER_SHORT)
			if [ $STATE_POWER_LONG -eq 1 ]; then
				KEY_COMBO=0
				STATE_POWER_SHORT=0
				STATE_POWER_LONG=0
			else
				KEY_COMBO=0
				STATE_POWER_SHORT=0
				STATE_POWER_LONG=0
			fi
			;;
		$PRESS_POWER_LONG)
			if [ $STATE_POWER_LONG -eq 0 ]; then
				STATE_POWER_LONG=1
				COUNT_POWER_LONG=$((COUNT_POWER_LONG + 1))
			fi
			;;
	esac
done &
