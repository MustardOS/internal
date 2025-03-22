#!/bin/sh

. /opt/muos/script/var/func.sh

for KMOD in mali_kbase squashfs; do
	insmod /lib/modules/"$KMOD".ko || printf "Failed to load %s module\n" "$KMOD"
done

# Initialise the network module if we have one
if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
	NET_MODULE=$(GET_VAR "device" "network/module")
	NET_IFACE=$(GET_VAR "device" "network/iface")
	DNS_ADDR=$(GET_VAR "global" "network/dns")

	# Wait until the network interface is created
	modprobe --force-modversion "$NET_MODULE"
	while [ ! -d "/sys/class/net/$NET_IFACE" ]; do sleep 0.1; done

	rfkill unblock all

	ip link set "$NET_IFACE" up
	iw dev "$NET_IFACE" set power_save off

	echo "nameserver $DNS_ADDR" >/etc/resolv.conf
fi

# Switch GPU power policy and set to maximum frequency
GPU_PATH="/sys/devices/platform/gpu"
echo always_on >"$GPU_PATH/power_policy"
echo 648000000 >"$GPU_PATH/devfreq/gpu/min_freq"
echo 648000000 >"$GPU_PATH/devfreq/gpu/max_freq"
