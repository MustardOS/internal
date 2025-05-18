#!/bin/sh

. /opt/muos/script/var/func.sh

ACTION=$1

GPU_PATH="/sys/devices/platform/gpu"
DNS_CONF="/etc/resolv.conf"
RESOLV_BACKUP="/tmp/resolv.conf.bak"

LOAD_MODULES() {
	insmod /lib/modules/squashfs.ko
	insmod /lib/modules/mali_kbase.ko

	if [ "$(GET_VAR device board/network)" -eq 1 ]; then
		NET_MODULE=$(GET_VAR device network/module)
		NET_IFACE=$(GET_VAR device network/iface)
		DNS_ADDR=$(GET_VAR global network/dns)

		modprobe --force-modversion "$NET_MODULE"
		while [ ! -d "/sys/class/net/$NET_IFACE" ]; do /opt/muos/bin/toybox sleep 0.5; done

		rfkill unblock all

		ip link set "$NET_IFACE" up
		iw dev "$NET_IFACE" set power_save off

		[ -f "$DNS_CONF" ] && cp "$DNS_CONF" "$RESOLV_BACKUP"
		echo "nameserver $DNS_ADDR" >"$DNS_CONF"
	fi

	echo always_on >"$GPU_PATH/power_policy"
	echo 648000000 >"$GPU_PATH/devfreq/gpu/min_freq"
	echo 648000000 >"$GPU_PATH/devfreq/gpu/max_freq"
}

UNLOAD_MODULES() {
	[ -e "$GPU_PATH/power_policy" ] && echo auto >"$GPU_PATH/power_policy"

	if [ "$(GET_VAR device board/network)" -eq 1 ]; then
		NET_MODULE=$(GET_VAR device network/module)
		NET_IFACE=$(GET_VAR device network/iface)

		ip link set "$NET_IFACE" down 2>/dev/null
		rfkill block all
		rmmod "$NET_MODULE" 2>/dev/null

		[ -f "$RESOLV_BACKUP" ] && mv "$RESOLV_BACKUP" "$DNS_CONF"
	fi

	rmmod mali_kbase.ko 2>/dev/null
	rmmod squashfs.ko 2>/dev/null
}

case "$ACTION" in
	load) LOAD_MODULES ;;
	unload) UNLOAD_MODULES ;;
	*) echo "Usage: $0 {load|unload}" >&2 && exit 1 ;;
esac
