#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/mux/close_game.sh

mkdir -p /tmp/combo
mkdir -p /tmp/trigger

killall -q "evtest"

. /opt/muos/device/"$(GET_VAR "device" "board/name")"/input/map.sh

KEY_COMBO=0
RESUME_UPTIME="$(UPTIME)"

HALL="/sys/class/power_supply/axp2202-battery/hallkey"
DPAD="/sys/class/power_supply/axp2202-battery/nds_pwrkey"

MOTO_BUZZ() {
	echo 1 >"$(GET_VAR "device" "board/rumble")"
	sleep 0.1
	echo 0 >"$(GET_VAR "device" "board/rumble")"
}

echo "awake" >"/tmp/sleep_state"

# Place combo and trigger scripts here because fuck knows why for loops won't work...
# Make sure to put them in order of how you want them to work too!
if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 0 ]; then
	if [ "$(GET_VAR "global" "settings/general/shutdown")" -ge 0 ]; then
		/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/trigger/power.sh &
		/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/trigger/sleep.sh &
	fi
fi

{
	evtest "$(GET_VAR "device" "input/ev0")" &
	evtest "$(GET_VAR "device" "input/ev1")" &
	wait
} | while read -r EVENT; do

	if [ $KEY_COMBO -eq 0 ]; then
		case $STATE_START in
			1)
				KEY_COMBO=1
				[ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 1 ] && printf "ignore" >"/tmp/net_start"
				;;
		esac

		case $STATE_SELECT in
			1)
				KEY_COMBO=1
				[ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 1 ] && printf "menu" >"/tmp/net_start"
				;;
		esac

		case "$STATE_MENU_LONG:$STATE_VOL_UP:$STATE_VOL_DOWN:$STATE_POWER_SHORT" in
			1:1:0:0)
				KEY_COMBO=1
				/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh U
				;;
			1:0:1:0)
				KEY_COMBO=1
				/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh D
				;;
			1:0:0:1)
				KEY_COMBO=1
				/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/screenshot.sh
				;;
			0:1:0:0)
				KEY_COMBO=1
				/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/audio.sh U
				;;
			0:0:1:0)
				KEY_COMBO=1
				/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/audio.sh D
				;;
		esac
	fi

	# In the hall of the mountain king...
	if [ "$(cat $HALL)" = "0" ]; then
		TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
		if [ "$(cat $TMP_POWER_LONG)" = "off" ]; then
			echo on >$TMP_POWER_LONG
		else
			echo off >$TMP_POWER_LONG
		fi
	fi

	# Power long press combos:
	if [ "$COUNT_POWER_LONG" -eq 1 ]; then
		COUNT_POWER_LONG=0

		if [ "$STATE_L1:$STATE_L2:$STATE_R1:$STATE_R2" = 1:1:1:1 ]; then
			# Power+L1+L2+R1+R2: Overall System Failsafe (Reboot)
			HALT_SYSTEM osf reboot
		elif [ "$(GET_VAR "global" "settings/general/shutdown")" -eq -1 ]; then
			# Power: Sleep Suspend
			#
			# Avoid suspending again immediately by ignoring power
			# long presses processed within 100ms of wakeup.
			if [ "$(echo "$(UPTIME) - $RESUME_UPTIME >= .1" | bc)" = 1 ]; then
				/opt/muos/script/system/suspend.sh power
				RESUME_UPTIME="$(UPTIME)"
			fi
		elif [ "$(GET_VAR "global" "settings/general/shutdown")" -eq 2 ]; then
			# Power: Instant Shutdown
			HALT_SYSTEM sleep poweroff
		else
			# Power: Sleep XXs + Shutdown
			TMP_POWER_LONG="/tmp/trigger/POWER_LONG"
			if [ ! -e $TMP_POWER_LONG ]; then
				echo on >$TMP_POWER_LONG
			fi
			if [ "$(cat $TMP_POWER_LONG)" = "off" ]; then
				echo on >$TMP_POWER_LONG
			else
				echo off >$TMP_POWER_LONG
			fi
		fi
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
				FG_PROC_VAL=$(GET_VAR "system" "foreground_process")
				DPAD_VAL=$(cat "$DPAD")
				if [ "${FG_PROC_VAL#mux}" = "$FG_PROC_VAL" ] && [ "$STATE_MENU_LONG" -ne 1 ]; then
					if [ "$DPAD_VAL" -eq 0 ]; then
						echo 2 >$DPAD
						MOTO_BUZZ
					elif [ "$DPAD_VAL" -eq 2 ]; then
						echo 0 >$DPAD
						MOTO_BUZZ
						sleep 0.1
						MOTO_BUZZ
					fi
				fi
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
