#!/bin/sh

. /opt/muos/script/var/func.sh

if  [ ! -f "/tmp/recent_wake" ] && [ "$(GET_VAR "config" "settings/advanced/dpad_swap")" -eq 1 ]; then
	RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"

	case "$(GET_VAR "system" "foreground_process")" in
		mux*) ;;
		*)
			case "$(GET_VAR "device" "board/name")" in
				rg*)
					DPAD_FILE="/sys/class/power_supply/axp2202-battery/nds_pwrkey"
					case "$(cat "$DPAD_FILE")" in
						0)
							echo 2 >"$DPAD_FILE"
							RUMBLE "$RUMBLE_DEVICE" .1
							;;
						2)
							echo 0 >"$DPAD_FILE"
							RUMBLE "$RUMBLE_DEVICE" .1
							TBOX sleep 0.1
							RUMBLE "$RUMBLE_DEVICE" .1
							;;
					esac
					;;
				tui*)
					DPAD_FILE="/tmp/trimui_inputd/input_dpad_to_joystick"
					if [ -e "$DPAD_FILE" ]; then
						rm -f "$DPAD_FILE"
						RUMBLE "$RUMBLE_DEVICE" .1
					else
						touch "$DPAD_FILE"
						RUMBLE "$RUMBLE_DEVICE" .1
						TBOX sleep 0.1
						RUMBLE "$RUMBLE_DEVICE" .1
					fi
					;;
			esac
			;;
	esac
fi
