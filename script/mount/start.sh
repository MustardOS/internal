#!/bin/sh

mount -t configfs none /sys/kernel/config &

# These scripts return as soon as the necessary mounts are available, but also
# leave background jobs running that respond to future media add/remove events.
/opt/muos/script/mount/storage.sh "rom" "mount" 1 &
/opt/muos/script/mount/storage.sh "sdcard" "mount" 1 &
/opt/muos/script/mount/storage.sh "usb" "mount" 1 &

# Wait for mounts required by the boot process to become available
wait

# We're all set for our device storage at least for now so we'll run
# the union script to merge all of the potential content directories.
/opt/muos/script/mount/union.sh start

# Set up bind mounts under /run/muos/storage. Creates /run/muos/storage/mounted
# upon completion to unblock the rest of the boot process.
/opt/muos/script/mount/bind.sh &

# Mount boot partition and start watching for USB storage. These aren't needed
# by the rest of the boot process, so handle them after bind mounts are set up.
/opt/muos/script/mount/boot.sh &
