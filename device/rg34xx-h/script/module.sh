#!/bin/sh

. /opt/muos/script/var/func.sh

MODULES="mali_kbase squashfs"
for KMOD in $MODULES; do insmod /lib/modules/"$KMOD".ko || printf "Failed to load %s module\n" "$KMOD"; done

# Initialise the network module if we have one
if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
	modprobe --force-modversion "$(GET_VAR "device" "network/module")"
	while [ ! -d "/sys/class/net/$(GET_VAR "device" "network/iface")" ]; do sleep 0.25; done

	rfkill unblock all

	ip link set "$(GET_VAR "device" "network/iface")" up
	iw dev "$(GET_VAR "device" "network/iface")" set power_save off

	echo "nameserver $(GET_VAR "global" "network/dns")" >/etc/resolv.conf
fi

# Switch GPU power policy and set to maximum frequency
echo always_on >/sys/devices/platform/gpu/power_policy
echo 648000000 >/sys/devices/platform/gpu/devfreq/gpu/min_freq
echo 648000000 >/sys/devices/platform/gpu/devfreq/gpu/max_freq
