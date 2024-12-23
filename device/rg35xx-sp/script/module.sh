#!/bin/sh

MODULES="mali_kbase squashfs"

for KMOD in $MODULES; do
    insmod /lib/modules/"$KMOD".ko || printf "Failed to load %s module\n" "$KMOD"
done

# Switch GPU power policy and set to maximum frequency
echo always_on >/sys/devices/platform/gpu/power_policy
echo 648000000 >/sys/devices/platform/gpu/devfreq/gpu/min_freq
echo 648000000 >/sys/devices/platform/gpu/devfreq/gpu/max_freq
