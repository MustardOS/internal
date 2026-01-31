#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_NAME=$(GET_VAR "device" "network/name")

depmod -a 2>/dev/null

case "$1" in
	load)
		[ "$HAS_NETWORK" -eq 1 ] && modprobe -q "$NET_NAME"

		case "$BOARD_NAME" in
			rg*)
				modprobe -q mali_kbase
				modprobe -q squashfs

				if [ "$(GET_VAR "config" "settings/advanced/maxgpu")" -eq 1 ]; then
					GPU_PATH="/sys/devices/platform/gpu"
					echo always_on >"$GPU_PATH/power_policy"
					echo 648000000 >"$GPU_PATH/devfreq/gpu/min_freq"
					echo 648000000 >"$GPU_PATH/devfreq/gpu/max_freq"
				fi
				;;
			tui*)
				modprobe -q dc_sunxi

				# Check if any trimui_inputd process is already running
				# because this script is typically run with suspend too
				if ! pgrep -f 'trimui_inputd_' >/dev/null 2>&1; then
					case "$BOARD_NAME" in
						*brick) /usr/bin/trimui_inputd_brick & ;;
						*spoon) /usr/bin/trimui_inputd_smart_pro & ;;
					esac
				fi
				;;
			mgx*)
				modprobe -q fuse
				modprobe -q simplepad
				modprobe -q dc_sunxi
				;;
			*) ;;
		esac
		;;

	unload)
		[ "$HAS_NETWORK" -eq 1 ] && modprobe -qr "$NET_NAME"

		case "$BOARD_NAME" in
			rg*)
				modprobe -qr mali_kbase
				modprobe -qr squashfs
				;;
			tui*)
				# Don't unload the following.  We are leaving it here for reference!
				# modprobe -qr dc_sunxi
				#
				# We also don't want to kill the input just in case some running
				# processes don't like the input being restarted for whatever reason
				# case "$BOARD_NAME" in
				#	*brick) killall -9 trimui_inputd_brick ;;
				#	*spoon) killall -9 trimui_inputd_smart_pro ;;
				# esac
				;;
			mgx*)
				# Don't unload the fuse module!
				modprobe -qr simplepad
				;;
			*) ;;
		esac
		;;

	*) echo "Usage: $0 {load|unload}" >&2 && exit 1 ;;
esac
