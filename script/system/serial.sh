#!/bin/sh

# Prints the current device's unique serial number.

# For H700 devices, this comes from the SID / Chip-ID
# (https://linux-sunxi.org/SID_Register_Guide). The stock U-Boot passes the
# serial number portion of the Chip-ID in the snum kernel command line param.
#
# On stock kernels, this is also exposed via the sunxi_chipid and sunxi_serial
# fields in /sys/class/sunxi_info/sys_info. The values line up as follows:
#
# snum:                  ZZZZ      YYYYYYY XXXXXXXX
# sunxi_chipid: 33806c00 ZZZZ4808 0YYYYYYY XXXXXXXX
# sunxi_serial: XXXXXXXX 0YYYYYYY 0000ZZZZ 00000000

SERIAL="$(xargs -n 1 -a /proc/cmdline | sed -n s/^snum=//p)"
[ -n "$SERIAL" ] || exit 1
printf '%s\n' "$SERIAL"
