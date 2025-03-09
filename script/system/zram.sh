#!/bin/sh

. /opt/muos/script/var/func.sh

ZRAM_FILE="/dev/zram0"
ZRAM_SIZE=$(GET_VAR "global" "settings/advanced/zramfile")

CREATE_ZRAM() {
	if [ "$2" -eq 1 ]; then
		LOG_INFO "$1" 0 "ZRAMFILE" "Creating Swapfile"
        modprobe /lib/modules/4.9.170/kernel/drivers/block/zram.ko
        zramctl --size ${ZRAM_SIZE}M --algorithm lz4 /dev/zram0
	fi
	LOG_INFO "$1" 0 "SWAPFILE" "Mounting Swapfile"
	chmod 0600 "$ZRAM_FILE"
	mkswap "$ZRAM_FILE"
	swapon --priority -1 "$ZRAM_FILE"
}

PURGE_ZRAM() {
	LOG_INFO "$1" 0 "SWAPFILE" "Purging Swapfile"
	swapoff "$ZRAM_FILE"
}

if [ "$ZRAM_SIZE" -eq 0 ]; then
	PURGE_ZRAM "$0"
else
    # Check if zramctl lists our zram device
    if zramctl | grep -q "^$ZRAM_FILE "; then
        # Get the DISKSIZE field (e.g. "1G", "1024M")
        CURRENT_SIZE=$(zramctl | awk -v dev="$ZRAM_FILE" '$1==dev {print $3}')
        
        # Convert CURRENT_SIZE (human readable) to bytes
        current_bytes=$(echo "$CURRENT_SIZE" | awk '{
            unit = substr($0, length($0), 1);
            num = substr($0, 1, length($0)-1);
            if (unit == "G")
                printf("%d", num * 1024 * 1024 * 1024);
            else if (unit == "M")
                printf("%d", num * 1024 * 1024);
            else if (unit == "K")
                printf("%d", num * 1024);
            else
                printf("%d", num);
        }')
        
        # Calculate desired size in bytes
        NEW_SIZE=$((ZRAM_SIZE * 1024 * 1024))
        
        if [ "$current_bytes" -ne "$NEW_SIZE" ]; then
            PURGE_ZRAM "$0"
            CREATE_ZRAM "$0" "1"
        else
            CREATE_ZRAM "$0" "0"
        fi
    else
        CREATE_ZRAM "$0" "1"
    fi
fi

