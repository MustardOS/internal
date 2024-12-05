#!/bin/sh

. /opt/muos/script/var/func.sh

SWAP_FILE="/opt/muswap"
SWAP_SIZE=$(GET_VAR "global" "settings/advanced/swapfile")

CREATE_SWAP() {
	LOG_INFO "$0" 0 "SWAPFILE" "Creating Swapfile"
	dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE"
	chmod 0600 "$SWAP_FILE"
	mkswap "$SWAP_FILE"
	swapon "$SWAP_FILE"
}

PURGE_SWAP() {
	LOG_INFO "$0" 0 "SWAPFILE" "Purging Swapfile"
	swapoff "$SWAP_FILE"
	rm -f "$SWAP_FILE"
}

if [ "$SWAP_SIZE" -eq 0 ]; then
	PURGE_SWAP "$0"
else
	if [ -e "$SWAP_FILE" ]; then
		CURRENT_SIZE=$(du -b "$SWAP_FILE" | awk '{print $1}')
		NEW_SIZE=$((SWAP_SIZE * 1024 * 1024))
		if [ "$CURRENT_SIZE" -ne "$NEW_SIZE" ]; then
			PURGE_SWAP "$0"
			CREATE_SWAP "$0"
		fi
	else
		CREATE_SWAP "$0"
	fi
fi
