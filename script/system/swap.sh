#!/bin/sh

. /opt/muos/script/var/func.sh

ZRAM_FILE="/dev/zram0"
ZRAM_SIZE=$(GET_VAR "config" "settings/advanced/zramfile")

SWAP_FILE="/opt/muswap"
SWAP_SIZE=$(GET_VAR "config" "settings/advanced/swapfile")

CREATE_ZRAM() {
	if [ "$2" -eq 1 ]; then
		LOG_INFO "$1" 0 "ZRAMFILE" "Creating Zramfile"
		modprobe /lib/modules/4.9.170/kernel/drivers/block/zram.ko
		zramctl --size "${ZRAM_SIZE}M" --algorithm lz4 "$ZRAM_FILE"
	fi
	LOG_INFO "$1" 0 "ZRAMFILE" "Mounting Zramfile"
	mkswap "$ZRAM_FILE"
	swapon --priority -1 "$ZRAM_FILE"
}

CREATE_SWAP() {
	if [ "$2" -eq 1 ]; then
		LOG_INFO "$1" 0 "SWAPFILE" "Creating Swapfile"
		dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE"
	fi
	LOG_INFO "$1" 0 "SWAPFILE" "Mounting Swapfile"
	chmod 0600 "$SWAP_FILE"
	mkswap "$SWAP_FILE"
	swapon --priority -2 "$SWAP_FILE"
}

PURGE_ZRAM() {
	if [ -e "$ZRAM_FILE" ]; then
		LOG_INFO "$1" 0 "ZRAMFILE" "Purging Zramfile"
		swapoff "$ZRAM_FILE"
	fi
}

PURGE_SWAP() {
	if [ -e "$SWAP_FILE" ]; then
		LOG_INFO "$1" 0 "SWAPFILE" "Purging Swapfile"
		swapoff "$SWAP_FILE"
		rm -f "$SWAP_FILE"
	fi
}

if [ "$ZRAM_SIZE" -eq 0 ]; then
	PURGE_ZRAM "$0"
else
	if zramctl | grep -q "^$ZRAM_FILE "; then
		CURRENT_SIZE=$(zramctl | awk -v dev="$ZRAM_FILE" '$1==dev {print $3}')
		CURRENT_BYTE=$(echo "$CURRENT_SIZE" | awk '{
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

		NEW_SIZE=$((ZRAM_SIZE * 1024 * 1024))

		if [ "$CURRENT_BYTE" -ne "$NEW_SIZE" ]; then
			PURGE_ZRAM "$0"
			CREATE_ZRAM "$0" "1"
		else
			CREATE_ZRAM "$0" "0"
		fi
	else
		CREATE_ZRAM "$0" "1"
	fi
fi

if [ "$SWAP_SIZE" -eq 0 ]; then
	PURGE_SWAP "$0"
else
	if [ -e "$SWAP_FILE" ]; then
		CURRENT_SIZE=$(du -b "$SWAP_FILE" | awk '{print $1}')
		NEW_SIZE=$((SWAP_SIZE * 1024 * 1024))
		if [ "$CURRENT_SIZE" -ne "$NEW_SIZE" ]; then
			PURGE_SWAP "$0"
			CREATE_SWAP "$0" "1"
		else
			CREATE_SWAP "$0" "0"
		fi
	else
		CREATE_SWAP "$0" "1"
	fi
fi
