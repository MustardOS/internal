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

NET_COMPAT=$(GET_VAR "config" "network/compat")

MAX_WAIT=30

PRIME_IW_SCAN() {
	IFACE=$1

	ATTEMPTS=3
	TIMEOUT=3

	I=0
	while [ "$I" -lt "$ATTEMPTS" ]; do
		# Kick a passive scan in the background, because fucked if I know why
		# first scan just sits there twiddling its thumbs!
		iw dev "$IFACE" scan passive >/dev/null 2>&1 &
		SCAN_PID=$!

		ELAPSED=0
		while kill -0 "$SCAN_PID" 2>/dev/null; do
			[ "$ELAPSED" -ge "$TIMEOUT" ] && break
			TBOX sleep 1
			ELAPSED=$((ELAPSED + 1))
		done

		# If still running, abort politely then kill...
		if kill -0 "$SCAN_PID" 2>/dev/null; then
			iw dev "$IFACE" scan abort >/dev/null 2>&1
			kill -TERM "$SCAN_PID" 2>/dev/null
			wait "$SCAN_PID" 2>/dev/null
		fi

		I=$((I + 1))
		TBOX sleep 1
	done

	iw dev "$IFACE" scan passive >/dev/null 2>&1
	return 0
}

WAIT_FOR_LINK_READY() {
	IFACE=$1

	# Wait for carrier for ethernet connections
	if [ -f "$SCN_PATH/$IFACE/carrier" ]; then
		for _ in $(seq 1 "$MAX_WAIT"); do
			[ "$(cat "$SCN_PATH/$IFACE/carrier" 2>/dev/null)" = "1" ] && return 0
			TBOX sleep 1
		done
		return 1
	else
		# Verify we can scan with wlan
		for _ in $(seq 1 "$MAX_WAIT"); do
			iw dev "$IFACE" scan passive >/dev/null 2>&1 && return 0
			TBOX sleep 1
		done
	fi

	# If we cannot verify, do not block boot
	return 0
}

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

	if echo "$NET_MODULE" | grep -q "8821cs"; then
		modprobe -q -r 8821cs
		udevadm settle --timeout=5

		TBOX sleep 1
	fi

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

	NET_IFACE=$(WAIT_FOR_IFACE "$NET_IFACE")
	[ -n "$NET_IFACE" ] || return 1
	SET_VAR "device" "network/iface_active" "$NET_IFACE"

	rfkill unblock all 2>/dev/null

	# Bring the interface up and disable Wi-Fi powersave if phy80211 present
	ip link set "$NET_IFACE" up 2>/dev/null
	[ -L "$SCN_PATH/$NET_IFACE/phy80211" ] && iw dev "$NET_IFACE" set power_save off 2>/dev/null

	FORCE_SDIO_AWAKE

	# Idle any secondary wlan interfaces (wlan1 etc.)
	for N in "$SCN_PATH"/wlan*; do
		[ -d "$N" ] || continue
		B="$(basename "$N")"
		[ "$B" = "$NET_IFACE" ] && continue
		ip link set "$B" down 2>/dev/null
	done

	# Wait for basic readiness...
	if [ "$NET_COMPAT" -eq 1 ]; then
		PRIME_IW_SCAN "$NET_IFACE"
		WAIT_FOR_LINK_READY "$NET_IFACE" || return 1
	fi

	# Only touch resolv.conf if we actually have a DNS to set
	if [ -n "$DNS_ADDR" ]; then
		[ -f "$RESOLV_CONF" ] && cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
		printf "nameserver %s\n" "$DNS_ADDR" >"$RESOLV_CONF"
	fi
}

UNLOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	[ -n "$NET_IFACE" ] && [ -d "$SCN_PATH/$NET_IFACE" ] && ip link set "$NET_IFACE" down 2>/dev/null

	rfkill block all 2>/dev/null
	modprobe -q -r "$NET_MODULE" 2>/dev/null || rmmod "$NET_MODULE" 2>/dev/null
	udevadm settle --timeout=5

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
	load-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && LOAD_NETWORK ;;
	unload-network) [ "$FACTORY_RESET" -eq 0 ] && [ "$HAS_NETWORK" -eq 1 ] && UNLOAD_NETWORK ;;
	*) echo "Usage: $0 {load|unload|load-network|unload-network|reload-network}" >&2 && exit 1 ;;
esac
