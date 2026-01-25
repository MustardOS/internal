#!/bin/sh

. /opt/muos/script/var/func.sh

FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
BOARD_NAME=$(GET_VAR "device" "board/name")

SCN_PATH="/sys/class/net"
RESOLV_CONF="/etc/resolv.conf"

HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_IFACE=$(GET_VAR "device" "network/iface")
NET_NAME=$(GET_VAR "device" "network/name")
DNS_ADDR=$(GET_VAR "config" "network/dns")

NET_COMPAT=$(GET_VAR "config" "settings/network/compat")
MAX_WAIT=$(GET_VAR "config" "settings/network/wait_timer")
MAX_RETRY=$(GET_VAR "config" "settings/network/compat_retry")

# Ensure network interface is never blank at the start...
[ -n "$NET_IFACE" ] || NET_IFACE=$(GET_VAR "device" "network/iface_active")
[ -n "$NET_IFACE" ] || NET_IFACE="wlan0"

FORCE_SDIO_AWAKE() {
	# Keep SDIO from dozing while we bring Wi-Fi up
	for P in /sys/bus/sdio/devices/*/power/control; do
		[ -f "$P" ] || continue
		echo on >"$P"
	done
}

WAIT_FOR_SDIO() {
	I=0
	while [ "$I" -lt "${MAX_WAIT:-5}" ]; do
		[ -d "/sys/bus/mmc/devices/mmc2:0001" ] && return 0

		I=$((I + 1))
		sleep 1
	done

	return 1
}

WAIT_FOR_IFACE() {
	W_IFACE=$1

	I=0
	while [ "$I" -lt "${MAX_WAIT:-5}" ]; do
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
			printf "%s" "${N##*/}"

			return 0
		done

		I=$((I + 1))
		sleep 1
	done

	return 1
}

LOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	# We need this because the 8821cs driver likes to be persistent when it has failed
	if grep -qw "^$NET_NAME" /proc/modules; then
		case "$BOARD_NAME" in
			rg*)
				modprobe -qr "$NET_NAME"
				sleep 1
				;;
		esac
	fi

	# Should probably poke it again and make sure it's really awake before proceeding with final load
	FORCE_SDIO_AWAKE

	case "$BOARD_NAME" in
		rg*)
			modprobe -qf "$NET_NAME"
			;;
		tui*)
		    # Can't "force" the module to load on TrimUI devices because otherwise it gets cranky
			modprobe -q "$NET_NAME"
			;;
		rk*)
			# For USB WiFi adapters using 'wext' extensions, ensure cfg80211
			# is loaded first if it exists (might be built-in or not needed)
			modprobe -q cfg80211
			;;
	esac

	# On certain devices we have to actually wait for the SDIO controller
	# to finish initialising because, that's right, the Wi-Fi chip is
	# controlled by the fucking SDIO controller... so wait for `mmc2` after
	# we modprobe the network module!
	if [ "$NET_COMPAT" -eq 1 ]; then
		case "$BOARD_NAME" in
			rg*) WAIT_FOR_SDIO || return 1 ;;
		esac
	fi

	NET_IFACE_TMP=$(WAIT_FOR_IFACE "$NET_IFACE")
	if [ -n "$NET_IFACE_TMP" ]; then
		NET_IFACE="$NET_IFACE_TMP"
	elif [ -z "$NET_IFACE" ]; then
		NET_IFACE=$(GET_VAR "device" "network/iface_active")
		[ -n "$NET_IFACE" ] || NET_IFACE="wlan0"
	fi

	SET_VAR "device" "network/iface_active" "$NET_IFACE"

	# Bring the interface up and disable Wi-Fi powersave if phy80211 present
	ip link set "$NET_IFACE" up
	[ -L "$SCN_PATH/$NET_IFACE/phy80211" ] && iw dev "$NET_IFACE" set power_save off

	# Only touch resolv.conf if we actually have a DNS to set
	if [ -n "$DNS_ADDR" ]; then
		[ -f "$RESOLV_CONF" ] && cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
		printf "nameserver %s\n" "$DNS_ADDR" >"$RESOLV_CONF"
	fi

	return 0
}

UNLOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	[ -n "$NET_IFACE" ] && {
		iw dev "$NET_IFACE" disconnect
		ip link set "$NET_IFACE" down
	}

	if grep -qw "^$NET_NAME" /proc/modules; then
		modprobe -qr "$NET_NAME"
		sleep 1
	fi

	case "$BOARD_NAME" in
		tui*)
			# Remove the stupid leftover xradio modules
			modprobe -qr "xradio_mac"
			;;
	esac

	[ -f "$RESOLV_CONF.bak" ] && mv -f "$RESOLV_CONF.bak" "$RESOLV_CONF"
}

RELOAD_NETWORK() {
	[ "$HAS_NETWORK" -eq 0 ] && return 0

	# We reload the driver a couple of times because sometimes the
	# RTL really wants to sleep.  It's okay to bully the hardware!
	I=0
	while [ "$I" -lt "$MAX_RETRY" ]; do
		UNLOAD_NETWORK
		sleep 1

		LOAD_NETWORK && return 0

		I=$((I + 1))
	done

	sleep 1
	return 1
}

if [ "$FACTORY_RESET" -eq 0 ]; then
	case "$1" in
		load) [ "$HAS_NETWORK" -eq 1 ] && LOAD_NETWORK ;;
		unload) [ "$HAS_NETWORK" -eq 1 ] && UNLOAD_NETWORK ;;
		reload) [ "$HAS_NETWORK" -eq 1 ] && RELOAD_NETWORK ;;
		*) echo "Usage: $0 {load|unload|reload}" >&2 && exit 1 ;;
	esac
fi
