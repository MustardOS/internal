#!/bin/sh
# shellcheck source=/dev/null

UDEV_CONFIG="/etc/udev/udev.conf"
test -r "$UDEV_CONFIG" || exit 6
. "$UDEV_CONFIG"

FIRST_PAINT_FLAG="/run/muos/first_paint"
DEFERRED_SUBSYSTEMS="sdio net bluetooth ieee80211 rfkill scsi scsi_device scsi_disk scsi_host bsg media video4linux ppp"

TRIGGER_DEFERRED() {
	PAINT_WAIT=0
	while [ ! -e "$FIRST_PAINT_FLAG" ] && [ "$PAINT_WAIT" -lt 300 ]; do
		sleep 0.05
		PAINT_WAIT=$((PAINT_WAIT + 1))
	done

	set --
	for SUBSYSTEM in $DEFERRED_SUBSYSTEMS; do
		set -- "$@" --subsystem-match="$SUBSYSTEM"
	done

	udevadm trigger --type=devices --action=add "$@"
	udevadm settle --timeout=5
}

case "$1" in
	start)
		printf "Populating %s using udev: " "${udev_root:-/dev}"
		[ -e "/proc/sys/kernel/hotplug" ] && printf '\000\000\000\000' >"/proc/sys/kernel/hotplug"
		/sbin/udevd -d || {
			echo "FAIL"
			exit 1
		}

		set --
		for SUBSYSTEM in $DEFERRED_SUBSYSTEMS; do
			set -- "$@" --subsystem-nomatch="$SUBSYSTEM"
		done

		udevadm trigger --type=subsystems --action=add
		udevadm trigger --type=devices --action=add "$@"
		udevadm settle --timeout=5 || echo "udevadm settle failed"

		TRIGGER_DEFERRED </dev/null >/dev/null 2>&1 &
		echo "done"
		;;
	stop)
		udevadm control --stop-exec-queue
		killall udevd 2>/dev/null
		;;
	*)
		echo "Usage: $0 {start|stop}"
		exit 1
		;;
esac

exit 0
