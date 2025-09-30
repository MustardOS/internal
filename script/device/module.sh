#!/bin/sh

. /opt/muos/script/var/func.sh

ACTION=$1

BOARD_NAME=$(GET_VAR "device" "board/name")
FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")

SCN_PATH="/sys/class/net"
RESOLV_CONF="/etc/resolv.conf"

HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_IFACE=$(GET_VAR "device" "network/iface")
NET_NAME=$(GET_VAR "device" "network/name")
DNS_ADDR=$(GET_VAR "config" "network/dns")

MAX_WAIT=$(GET_VAR "config" "settings/network/wait_timer")
MAX_RETRY=$(GET_VAR "config" "settings/network/compat_retry")

FORCE_SDIO_AWAKE() {
	# Keep SDIO from dozing while we bring Wi-Fi up
	for P in /sys/bus/sdio/devices/*/power/control; do
		[ -f "$P" ] || continue
		echo on >"$P" 2>/dev/null
	done
}

WAIT_FOR_SDIO() {
	for _ in $(seq 1 $MAX_WAIT); do
		[ -d "/sys/bus/mmc/devices/mmc2:0001" ] && return 0
		TBOX sleep 1
	done

	return 1
}

WAIT_FOR_IFACE() {
	W_IFACE=$1
	for _ in $(seq 1 "$MAX_WAIT"); do
		# Honour explicit iface if it exists
		if [ -n "$W_IFACE" ] && [ -d "$SCN_PATH/$W_IFACE" ]; then
			printf "%s" "$W_IFACE"
			return 0
		fi

		# Always prefer wlan0 if it exists
		if [ -d "$SCN_PATH/wlan0" ]; then
			printf "%s" "wlan0"
			return 0
		fi

		# Otherwise take the first wlan*, then eth*... is there others?
		for N in "$SCN_PATH"/wlan* "$SCN_PATH"/eth*; do
			[ -d "$N" ] || continue
			printf "%s" "$(basename "$N")"
			return 0
		done

		TBOX sleep 1
	done

	return 1
}

LOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	# We need this because the 8821cs driver likes to be persistent when it has failed
	case "$BOARD_NAME" in
		rg*)
			modprobe -q -r "$NET_NAME"
			udevadm settle --timeout=5
			TBOX sleep 1
			;;
		*) ;;
	esac

	# Should probably poke it again and make sure it's really awake before proceeding with final load
	FORCE_SDIO_AWAKE

	# Not really necessary for the TrimUI devices but because the H700 devices
	# run this just before probing the network module we are going to add it
	# here "just in case" but also somewhat uniformity...
	udevadm settle --timeout=5
	! modprobe -q "$NET_NAME" && return 1

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

	NET_IFACE=$(WAIT_FOR_IFACE "$NET_IFACE")
	[ -n "$NET_IFACE" ] || return 1
	SET_VAR "device" "network/iface_active" "$NET_IFACE"

	rfkill unblock all 2>/dev/null

	# Bring the interface up and disable Wi-Fi powersave if phy80211 present
	ip link set "$NET_IFACE" up 2>/dev/null
	[ -L "$SCN_PATH/$NET_IFACE/phy80211" ] && iw dev "$NET_IFACE" set power_save off 2>/dev/null

	# Idle any secondary wlan interfaces (wlan1 etc.)
	for N in "$SCN_PATH"/wlan*; do
		[ -d "$N" ] || continue
		B="$(basename "$N")"
		[ "$B" = "$NET_IFACE" ] && continue
		ip link set "$B" down 2>/dev/null
	done

	# Only touch resolv.conf if we actually have a DNS to set
	if [ -n "$DNS_ADDR" ]; then
		[ -f "$RESOLV_CONF" ] && cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
		printf "nameserver %s\n" "$DNS_ADDR" >"$RESOLV_CONF"
	fi

	return 0
}

UNLOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	[ -n "$NET_IFACE" ] && [ -d "$SCN_PATH/$NET_IFACE" ] && ip link set "$NET_IFACE" down 2>/dev/null

	rfkill block all 2>/dev/null
	modprobe -q -r "$NET_NAME" 2>/dev/null || rmmod "$NET_NAME" 2>/dev/null
	udevadm settle --timeout=5

	[ -f "$RESOLV_CONF.bak" ] && mv "$RESOLV_CONF.bak" "$RESOLV_CONF"
}

RELOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0
	# we reload the driver a couple of times because sometimes the RTL really wants to sleep
	# it's okay to bully hardware... i think?
	for _ in $(seq 1 $MAX_RETRY); do
		UNLOAD_NETWORK
		! LOAD_NETWORK && return 0
		TBOX sleep 1
	done
	TBOX sleep 1
	return 1
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
	load-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && LOAD_NETWORK ;;
	unload-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && UNLOAD_NETWORK ;;
	reload-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && RELOAD_NETWORK ;;
	*) echo "Usage: $0 {load|unload|load-network|unload-network|reload-network}" >&2 && exit 1 ;;
esac
