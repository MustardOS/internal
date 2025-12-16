#!/bin/sh

dmesg | grep 'Please run fsck' | while read -r line; do
	DEVICE=$(echo "$line" | grep -oE '\(.*\)' | tr -d '()')

	if [ -n "$DEVICE" ]; then
		printf "Detected filesystem issue on '%s'! Checking filesystem type\n" "$DEVICE"

		if [ -e "/dev/$DEVICE" ]; then
			FS_TYPE=$(blkid -o value -s TYPE "/dev/$DEVICE")
			LOGFILE="/tmp/fsck_${DEVICE}.log"

			case "$FS_TYPE" in
				vfat)
					printf "Filesystem is VFAT. Running 'fsck.vfat' on /dev/%s\n" "$DEVICE"
					fsck.vfat -y "/dev/$DEVICE" >"$LOGFILE" 2>&1

					if grep -q "differences between boot sector" "$LOGFILE"; then
						printf "Notice: Boot sector differences detected on /dev/%s. Resolving\n" "$DEVICE"
						printf "1\n1\n" | fsck.vfat "/dev/$DEVICE" >>"$LOGFILE" 2>&1
					fi
					;;
				exfat)
					printf "Filesystem is exFAT. Running 'fsck.exfat' on /dev/%s\n" "$DEVICE"
					fsck.exfat "/dev/$DEVICE" >"$LOGFILE" 2>&1
					;;
				*)
					printf "Unknown or unsupported filesystem type '%s' for /dev/%s. Skipping!\n" "$FS_TYPE" "$DEVICE"
					;;
			esac
		else
			printf "Warning: Device /dev/%s does not exist? Skipping!\n" "$DEVICE"
		fi
	fi

	printf "\n"
done

sync
printf "\nAll done! Resuming Boot\n"
sleep 3
