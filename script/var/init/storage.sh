#!/bin/sh

. /opt/muos/script/var/func.sh

# Make sure both VARS and LOCS match the same index as required
STORAGE_VARS="bios catalogue catalogue config config content content content music save screenshot theme language"
STORAGE_LOCS="bios info/catalogue info/name retroarch info/config info/core info/favourite info/history music save screenshot theme language"

# Shouldn't need to touch any of the below logic unless a critical failure occurs!
S_=0

for S_VAR in $STORAGE_VARS; do
	S_LOC=$(echo "$STORAGE_LOCS" | cut -d' ' -f$((S_ + 1)))

	mkdir -p "/run/muos/storage/$S_LOC"
	case "$(GET_VAR "global" "storage/$S_VAR")" in
		0)
			MOUNT="$(GET_VAR "device" "storage/rom/mount")"
			FALLBACK=0
			;;
		1)
			MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
			FALLBACK=0
			;;
		2)
			MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
			FALLBACK=1
			;;
		*)
			printf "Storage not valid! Skipping...\n"
			S_=$((S_ + 1))
			continue
			;;
	esac

	# Always mount 'retroarch' to SD1 as no user should realistically place it on SD2.
	# It also reduces a number of headaches if somebody decides to force SD2 on RetroArch Config storage preference!
	if [ "$S_LOC" = "retroarch" ]; then
		mount --bind "$(GET_VAR "device" "storage/rom/mount")/MUOS/$S_LOC" "/run/muos/storage/$S_LOC"
	else
		echo mount --bind "$MOUNT/MUOS/$S_LOC" "/run/muos/storage/$S_LOC"

		if ! mount --bind "$MOUNT/MUOS/$S_LOC" "/run/muos/storage/$S_LOC"; then
			if [ "$FALLBACK" -eq 1 ]; then
				MOUNT="$(GET_VAR "device" "storage/rom/mount")"
				if ! mount --bind "$MOUNT/MUOS/$S_LOC" "/run/muos/storage/$S_LOC"; then
					CRITICAL_FAILURE directory "$S_LOC" "$MOUNT"
				fi
			else
				CRITICAL_FAILURE directory "$S_LOC" "$MOUNT"
			fi
		fi
	fi

	S_=$((S_ + 1))
done

# Bind hardcoded paths on SD1's ROM partition (where we can't use symlinks) to
# subdirs of the appropriate locations under /run/muos/storage (bound above).
BIND_INTO_STORAGE() {
	TARGET="/run/muos/storage/$1"
	MOUNT="$(GET_VAR "device" "storage/rom/mount")/MUOS/$2"
	mkdir -p "$TARGET" "$MOUNT"
	if ! mount --bind "$TARGET" "$MOUNT"; then
		CRITICAL_FAILURE directory "$TARGET" "$MOUNT"
	fi
}

BIND_INTO_STORAGE save/state/PPSSPP-Ext emulator/ppsspp/.config/ppsspp/PSP/PPSSPP_STATE
BIND_INTO_STORAGE save/file/PPSSPP-Ext emulator/ppsspp/.config/ppsspp/PSP/SAVEDATA
