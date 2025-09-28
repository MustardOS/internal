#!/bin/sh

. /opt/muos/script/var/func.sh

ACTION=$1

BOARD_NAME=$(GET_VAR "device" "board/name")
FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")

SCN_PATH="/sys/class/net"
RESOLV_CONF="/etc/resolv.conf"

HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_MODULE=$(GET_VAR "device" "network/module")
NET_IFACE=$(GET_VAR "device" "network/iface")
DNS_ADDR=$(GET_VAR "config" "network/dns")

MAX_WAIT=30

WAIT_FOR_SDIO() {
	for _ in $(seq 1 $MAX_WAIT); do
		[ -d "/sys/bus/mmc/devices/mmc2:0001" ] && return 0
		TBOX sleep 1
	done

	return 1
}

WAIT_FOR_IFACE() {
	W_IFACE=$1

	for _ in $(seq 1 $MAX_WAIT); do
		if [ -n "$W_IFACE" ] && [ -d "$SCN_PATH/$W_IFACE" ]; then
			printf "%s" "$W_IFACE"
			return 0
		fi

		for N in "$SCN_PATH"/*; do
			[ -d "$N" ] || continue

			ND="$(basename "$N")"
			case "$ND" in
				wlan[0-9]*)
					printf "%s" "$ND"
					return 0
					;;
				eth[0-9]*)
					printf "%s" "$ND"
					return 0
					;;
			esac
		done

		TBOX sleep 1
	done

	return 1
}

LOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	# Not really necessary for the TrimUI devices but because the H700 devices
	# run this just before probing the network module we are going to add it
	# here "just in case" but also somewhat uniformity...
	udevadm settle --timeout=5
	! modprobe -q "$NET_MODULE" && return 1

	# On certain devices we have to actually wait for the SDIO controller
	# to finish initialising because, that's right, the Wi-Fi chip is
	# controlled by the fucking SDIO controller... so wait for `mmc2` after
	# we modprobe the network module!
	case "$BOARD_NAME" in
		rg*) ! WAIT_FOR_SDIO && return 1 ;;
		*) ;;
	esac

	# We'll do this again because fuck it why not...
	udevadm settle --timeout=5
	NET_IFACE_READY=$(WAIT_FOR_IFACE "$NET_IFACE") || return 1

	rfkill unblock all 2>/dev/null
	ip link set "$NET_IFACE" up 2>/dev/null

	if [ -L "$SCN_PATH/$NET_IFACE/phy80211" ]; then
		iw dev "$NET_IFACE" set power_save off 2>/dev/null
	fi

	[ -f "$RESOLV_CONF" ] && cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
	printf "nameserver %s\n" "$DNS_ADDR" >"$RESOLV_CONF"
}

RELOAD_NETWORK() {
	if echo "$NET_MODULE" | grep -q "8821cs"; then
		modprobe -q -r 8821cs
		udevadm settle --timeout=5
		# just to be absolutely certain
		TBOX sleep 1
		LOAD_NETWORK
	fi
}

UNLOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	[ -d "$SCN_PATH/$NET_IFACE" ] && ip link set "$NET_IFACE" down 2>/dev/null

	rfkill block all 2>/dev/null
	rmmod "$NET_MODULE" 2>/dev/null

	[ -f "$RESOLV_CONF.bak" ] && mv "$RESOLV_CONF.bak" "$RESOLV_CONF"
}

LOAD_MODULES() {
	case "$BOARD_NAME" in
		rg*)
			insmod /lib/modules/4.9.170/kernel/drivers/fs/squashfs.ko
			insmod /lib/modules/4.9.170/kernel/drivers/video/gpu/mali_kbase.ko

			GPU_PATH="/sys/devices/platform/gpu"

			echo always_on >"$GPU_PATH/power_policy"
			echo 648000000 >"$GPU_PATH/devfreq/gpu/min_freq"
			echo 648000000 >"$GPU_PATH/devfreq/gpu/max_freq"
			;;
		*) ;;
	esac
}

UNLOAD_MODULES() {
	case "$BOARD_NAME" in
		rg*)
			rmmod mali_kbase 2>/dev/null
			rmmod squashfs 2>/dev/null
			;;
		*) ;;
	esac
}

case "$ACTION" in
	load) LOAD_MODULES ;;
	unload) UNLOAD_MODULES ;;
	reload-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && RELOAD_NETWORK ;;
	load-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && LOAD_NETWORK ;;
	unload-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && UNLOAD_NETWORK ;;
	*) echo "Usage: $0 {load|unload|load-network|unload-network|reload-network}" >&2 && exit 1 ;;
esac
