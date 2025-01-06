#!/bin/sh

mount -t configfs none /sys/kernel/config &

# These scripts return as soon as the necessary mounts are available, but also
# leave background jobs running that respond to future media add/remove events.
/opt/muos/script/mount/rom.sh &
/opt/muos/script/mount/sdcard.sh &
/opt/muos/script/mount/usb.sh &

# Wait for mounts required by the boot process to become available
wait

# Set up bind mounts under /run/muos/storage. Creates /run/muos/storage/mounted
# upon completion to unblock the rest of the boot process.
/opt/muos/script/var/init/storage.sh

# Mount boot partition and start watching for USB storage. These aren't needed
# by the rest of the boot process, so handle them after bind mounts are set up.
/opt/muos/script/mount/boot.sh &
