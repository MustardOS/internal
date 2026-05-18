#!/bin/sh

. /opt/muos/script/var/func.sh

if [ "$(GET_VAR "device" "board/stick")" -eq 0 ] && [ "$(GET_VAR "config" "settings/advanced/dpad_swap")" -eq 1 ]; then
	RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
	DPAD_SWAP=$(GET_VAR "device" "board/swap")

	case "$(GET_VAR "system" "foreground_process")" in
		mux*) ;;
		*)
			case "$(GET_VAR "device" "board/name")" in
				rg*)
					case "$(cat "$DPAD_SWAP")" in
						0)
							LOG_INFO "$0" 0 "SWAP_DPAD" "Switching DPAD to analogue (rg)"
							echo 2 >"$DPAD_SWAP"
							RUMBLE "$RUMBLE_DEVICE" .1
							;;
						2)
							LOG_INFO "$0" 0 "SWAP_DPAD" "Switching DPAD to digital (rg)"
							echo 0 >"$DPAD_SWAP"
							RUMBLE "$RUMBLE_DEVICE" .1
							sleep 0.1
							RUMBLE "$RUMBLE_DEVICE" .1
							;;
					esac
					;;
				tui*)
					if [ -e "$DPAD_SWAP" ]; then
						LOG_INFO "$0" 0 "SWAP_DPAD" "Switching DPAD to default (tui)"
						rm -f "$DPAD_SWAP"
						RUMBLE "$RUMBLE_DEVICE" .1
					else
						LOG_INFO "$0" 0 "SWAP_DPAD" "Switching DPAD to alternate (tui)"
						touch "$DPAD_SWAP"
						RUMBLE "$RUMBLE_DEVICE" .1
						sleep 0.1
						RUMBLE "$RUMBLE_DEVICE" .1
					fi
					;;
			esac
			;;
	esac
fi
