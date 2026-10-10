#!/bin/sh

. /opt/muos/script/var/func.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_NAME=$(GET_VAR "device" "network/name")

G350_SET_RUMBLE_GPIO_OFF() {
	G350_RUMBLE_GPIO=/sys/class/gpio/gpio15

	[ -d "$G350_RUMBLE_GPIO" ] || printf '%s' 15 >/sys/class/gpio/export 2>/dev/null || return 1
	[ -d "$G350_RUMBLE_GPIO" ] || return 1

	printf "%s" low >"$G350_RUMBLE_GPIO/direction"
}

MODULES_DIR="/lib/modules/$(uname -r)"
DEPMOD_STAMP="$MODULES_DIR/depmod.stamp"
if [ ! -f "$DEPMOD_STAMP" ] || [ -n "$(find "$MODULES_DIR" -newer "$DEPMOD_STAMP" -maxdepth 0)" ]; then
	depmod -a 2>/dev/null && touch "$DEPMOD_STAMP"
fi

case "$1" in
	load)
		[ "$HAS_NETWORK" -eq 1 ] && modprobe -q "$NET_NAME"

		case "$BOARD_NAME" in
			gcs-h36s)
				modprobe -q dc_sunxi
				if ! pidof muinput >/dev/null 2>&1; then
					/opt/muos/frontend/muinput &
				fi
				;;
			rg*)
				modprobe -q mali_kbase
				modprobe -q squashfs

				if [ "$(GET_VAR "config" "settings/advanced/maxgpu")" -eq 1 ]; then
					GPU_PATH="/sys/devices/platform/gpu"
					GPU_FREQ="$(GET_VAR "config" "danger/gpu_max")"
					case "$GPU_FREQ" in
						'' | 0 | *[!0-9]*)
							GPU_FREQ=$(tr ' ' '\n' <"$GPU_PATH/devfreq/gpu/available_frequencies" 2>/dev/null | grep -v '^$' | sort -n | tail -1)
							;;
					esac
					[ -n "$GPU_FREQ" ] || GPU_FREQ=648000000

					# The maximum goes first so a raised minimum is never refused for sitting above it
					printf "always_on" >"$GPU_PATH/power_policy"
					printf "%s" "$GPU_FREQ" >"$GPU_PATH/devfreq/gpu/max_freq"
					printf "%s" "$GPU_FREQ" >"$GPU_PATH/devfreq/gpu/min_freq"
				fi

				case "$BOARD_NAME" in
					rg-vita-pro|rg28xx-h|rg34xx-h|rg34xx-sp|rg35xx-2024|rg35xx-h|rg35xx-plus|rg35xx-pro|rg35xx-sp|rg40xx-h|rg40xx-v|rgcubexx-h|rgsp)
					if ! pidof muinput >/dev/null 2>&1; then
						/opt/muos/frontend/muinput &
					fi

					(
						DIRECT_KEYS_DRIVER="/sys/bus/platform/drivers/dierct-keys-polled"
						H700_ISOLATION_ATTEMPT=0
						while [ "$H700_ISOLATION_ATTEMPT" -lt 50 ]; do
							if [ -c /dev/muinput/h700-source ]; then
								rm -f /dev/input/by-path/platform-dierct-keys-polled-event
								if [ -e "$DIRECT_KEYS_DRIVER/dierct-keys-polled" ]; then
									printf '%s' "dierct-keys-polled" >"$DIRECT_KEYS_DRIVER/unbind"
									exit 0
								fi
							fi
							H700_ISOLATION_ATTEMPT=$((H700_ISOLATION_ATTEMPT + 1))
							sleep 0.1
						done
					) &
					;;
				esac
				;;
			tui*)
				modprobe -q dc_sunxi
				modprobe -q ax88179_178a

				case "$BOARD_NAME" in
					tui-spoon|tui-brick|tui-brick-pro|tui-smpro-s)
						if ! pidof muinput >/dev/null 2>&1; then
							/opt/muos/frontend/muinput &
						fi
						;;
				esac
				;;
			mgx*)
				modprobe -q fuse
				modprobe -q simplepad
				modprobe -q dc_sunxi
				if ! pidof muinput >/dev/null 2>&1; then
					/opt/muos/frontend/muinput &
				fi
				;;
			rk-g350-v)
				G350_SET_RUMBLE_GPIO_OFF

				if ! pidof muinput >/dev/null 2>&1; then
					/opt/muos/frontend/muinput &
				fi
				;;
			rk*)
				if [ "$BOARD_NAME" = rk-pixel-2 ]; then
					# Out-of-tree power key driver, see device/rk-pixel-2/module/README.md.
					# Only valid for the exact kernel build below. If the kernel is rebuilt,
					# this is skipped (no crash) and the power key goes dead until the
					# module is rebuilt or the kernel ships CONFIG_INPUT_RK805_PWRKEY.
					PWRKEY_BUILD="#4 SMP Sun Jun 7 23:27:50 EDT 2026"
					PWRKEY_KO="/opt/muos/device/module/rk805-pwrkey.ko"

					if [ "$(uname -v)" = "$PWRKEY_BUILD" ] && [ -f "$PWRKEY_KO" ]; then
						grep -q '^rk805_pwrkey ' /proc/modules || insmod "$PWRKEY_KO"
					else
						LOG_WARN "$0" 0 "MODULE" "rk805-pwrkey skipped: kernel build does not match"
					fi

					# Started here rather than S05device so it is not queued behind S02network
					pgrep -f "$DEVICE_SCRIPT_DIR/rk-pixel-2/pwrkey.sh" >/dev/null 2>&1 ||
						RUN_DEVICE_SCRIPT pwrkey.sh &
				fi

				if ! pidof muinput >/dev/null 2>&1; then
					/opt/muos/frontend/muinput &
				fi
				;;
		esac
		;;
	unload)
		[ "$HAS_NETWORK" -eq 1 ] && modprobe -qr "$NET_NAME"

		case "$BOARD_NAME" in
			gcs-h36s) modprobe -qr dc_sunxi ;;
			rg*)
				modprobe -qr mali_kbase
				modprobe -qr squashfs
				;;
			mgx*)
				modprobe -qr simplepad
				modprobe -qr dc_sunxi
				;;
		esac
		;;
	*)
		printf "Usage: %s {load|unload}\n" "$0" >&2
		exit 1
		;;
esac
