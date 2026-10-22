#!/bin/sh

. /opt/muos/script/var/log.sh

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_NAME=$(GET_VAR "device" "network/name")

G350_SET_RUMBLE_GPIO_OFF() {
	G350_RUMBLE_GPIO=/sys/class/gpio/gpio15

	[ -d "$G350_RUMBLE_GPIO" ] || printf '%s' 15 >/sys/class/gpio/export 2>/dev/null || return 1
	[ -d "$G350_RUMBLE_GPIO" ] || return 1

	printf "%s" low >"$G350_RUMBLE_GPIO/direction"
}

# The GCS H36S has to run its stock kernel, whose PowerVR driver is release 1.11, while the
# shared A133 rootfs carries release 1.19.  The kernel module, firmware and user libraries
# must all come from the same release, so the stock set is laid over the rootfs copies here.
GCS_GPU_STACK() {
	GCS_DEVICE=/opt/muos/device

	while IFS=: read -r GCS_SOURCE GCS_TARGET; do
		[ -f "$GCS_DEVICE/$GCS_SOURCE" ] && [ -e "$GCS_TARGET" ] || continue
		grep -q " $GCS_TARGET " /proc/mounts || mount --bind "$GCS_DEVICE/$GCS_SOURCE" "$GCS_TARGET"
	done <<EOF
gpu/firmware/rgx.fw.22.102.54.38:/lib/firmware/rgx.fw.22.102.54.38
gpu/lib/libEGL.so:/usr/lib/libEGL.so
gpu/lib/libGLES_CM.so:/usr/lib/libGLES_CM.so
gpu/lib/libGLESv2.so:/usr/lib/libGLESv2.so
gpu/lib/libglslcompiler.so:/usr/lib/libglslcompiler.so
gpu/lib/libIMGegl.so:/usr/lib/libIMGegl.so
gpu/lib/libpvrNULL_WSEGL.so:/usr/lib/libpvrNULL_WSEGL.so
gpu/lib/libPVROCL.so:/usr/lib/libPVROCL.so.1
gpu/lib/libPVRScopeServices.so:/usr/lib/libPVRScopeServices.so
gpu/lib/libsrv_um.so:/usr/lib/libsrv_um.so
gpu/lib/libusc.so:/usr/lib/libusc.so
EOF

	# udev loads the rootfs pvrsrvkm by its device alias during boot, so swap it out unless
	# the stock module was the one loaded here.  Nothing has opened the GPU by this point.
	GCS_MARK=/run/muos/gcs_gpu_stock
	if [ ! -e "$GCS_MARK" ] && grep -q '^pvrsrvkm ' /proc/modules; then
		rmmod dc_sunxi 2>/dev/null
		rmmod pvrsrvkm || LOG_ERROR "$0" 0 "MODULE" "Could not unload the rootfs pvrsrvkm"
	fi

	for GCS_MODULE in pvrsrvkm:pvrsrvkm.ko dc_sunxi:dc_sunxi.ko sunxi_backlight:sunxi-backlight.ko; do
		grep -q "^${GCS_MODULE%%:*} " /proc/modules && continue
		if insmod "$GCS_DEVICE/module/${GCS_MODULE#*:}"; then
			[ "${GCS_MODULE%%:*}" = pvrsrvkm ] && mkdir -p "${GCS_MARK%/*}" && : >"$GCS_MARK"
		else
			LOG_ERROR "$0" 0 "MODULE" "$(printf "Could not load %s" "${GCS_MODULE%%:*}")"
		fi
	done
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
				GCS_GPU_STACK

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
			gcs-h36s) rmmod dc_sunxi 2>/dev/null ;;
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
