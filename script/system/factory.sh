#!/bin/sh

. /opt/muos/script/var/service.sh
. /opt/muos/script/var/storage.sh

LOG_INFO "$0" 0 "FACTORY RESET" "Setting date time to default"
date 010100002026
RTC_CLOCK=$(GET_VAR "device" "board/rtc_clock")
if command -v hwclock >/dev/null 2>&1 && [ -n "$RTC_CLOCK" ] && [ -e "$RTC_CLOCK" ]; then
	hwclock -f "$RTC_CLOCK" -w || LOG_WARN "$0" 0 "FACTORY RESET" "Unable to update the hardware clock"
fi

while pgrep "muwarn" >/dev/null 2>&1; do sleep 0.25; done

RUN_DEVICE_SCRIPT amp.sh
/opt/muos/script/device/speaker.sh

AUTO_INSTALL_FS=""
OEM_WIFI_STASH="$MUOS_RUN_DIR/oem_wifi.conf"

# Factory defaults go in before the OEM profile, so a profile can still choose its own
SET_VAR_DURABLE "config" "settings/advanced/rumble" "0"
SET_VAR_DURABLE "config" "settings/power/saver_type" "1"

IMPORT_OEM_PROFILE() {
	OEM_PART="/dev/$(GET_VAR "device" "storage/rom/dev")$(GET_VAR "device" "storage/rom/sep")$(GET_VAR "device" "storage/rom/num")"
	[ -b "$OEM_PART" ] || return 0

	OEM_MOUNT=$(mktemp -d /tmp/oem-profile.XXXXXX) || return 0
	OEM_MOUNTED=0
	for OEM_TYPE in exfat vfat ext4; do
		if MOUNT_FILESYSTEM "$OEM_TYPE" ro "$OEM_PART" "$OEM_MOUNT" 2>/dev/null; then
			OEM_MOUNTED=1
			break
		fi
	done

	if [ "$OEM_MOUNTED" -eq 1 ]; then
		WIFI_FILE=$(find "$OEM_MOUNT" -maxdepth 1 -type f -iname wifi.conf | head -n 1)
		if [ -n "$WIFI_FILE" ]; then
			LOG_INFO "$0" 0 "FACTORY RESET" "Importing OEM network settings"
			if /opt/muos/script/system/profile.sh import-wifi "$WIFI_FILE"; then
				# The network profile is written once the ROMS partition has been prepared, as it lives there
				(umask 077 && cp "$WIFI_FILE" "$OEM_WIFI_STASH") ||
					LOG_WARN "$0" 0 "FACTORY RESET" "OEM network settings could not be kept for the network profile"
			else
				LOG_WARN "$0" 0 "FACTORY RESET" "OEM network settings could not be applied"
			fi
		fi

		OEM_FILE=$(find "$OEM_MOUNT" -maxdepth 1 -type f -iname profile.conf | head -n 1)
		if [ -n "$OEM_FILE" ] && AUTO_INSTALL_FS=$(/opt/muos/script/system/profile.sh oem-install "$OEM_FILE"); then
			LOG_INFO "$0" 0 "FACTORY RESET" "$(printf "OEM profile requests an automatic install on %s" "$AUTO_INSTALL_FS")"
		else
			AUTO_INSTALL_FS=""
		fi

		if [ -n "$OEM_FILE" ]; then
			: >"$MUOS_RUN_DIR/oem_profile"
			LOG_INFO "$0" 0 "FACTORY RESET" "Importing OEM profile"
			/opt/muos/script/system/profile.sh import-oem "$OEM_FILE" ||
				LOG_WARN "$0" 0 "FACTORY RESET" "OEM profile could not be applied"
		fi
		umount "$OEM_MOUNT" 2>/dev/null
	fi

	rmdir "$OEM_MOUNT" 2>/dev/null
}

IMPORT_OEM_PROFILE

RUN_DEVICE_SCRIPT amp.sh &

if [ -n "$AUTO_INSTALL_FS" ]; then
	SET_VAR "device" "storage/rom/type" "$AUTO_INSTALL_FS"
	LOG_INFO "$0" 0 "FACTORY RESET" "$(printf "Skipping the installer, the storage will be formatted as %s" "$AUTO_INSTALL_FS")"
	printf "install" >"$ACT_GO"
else
	printf "installer" >"$ACT_GO"
fi
/opt/muos/script/mux/install.sh

printf 0 >"/tmp/msg_progress"
[ -f "/tmp/msg_finish" ] && rm -f "/tmp/msg_finish"

LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
HOTKEY start

/opt/muos/frontend/muxmessage 0 "$MUOS_SHARE_DIR/message.txt" -d 5

FACTORY_AUDIO_PID=
if command -v mpv >/dev/null 2>&1; then
	mpv --really-quiet "$MUOS_SHARE_DIR/media/factory.mp3" &
	FACTORY_AUDIO_PID=$!
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Setting ARMHF Requirements"
ARMHF="ld-linux-armhf.so.3"
if [ ! -e "/lib/${ARMHF}" ] && [ -e "/lib32/${ARMHF}" ]; then
	LOG_INFO "$0" 0 "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s "/lib32/${ARMHF}" "/lib/${ARMHF}"
fi
if command -v ldconfig >/dev/null 2>&1; then
	ldconfig -v >"/opt/muos/ldconfig.log"
fi

LOG_INFO "$0" 0 "FACTORY RESET" "Initialising Factory Reset Script"
/opt/muos/script/system/reset.sh

touch "/tmp/msg_finish"
sleep 1
if [ -n "$FACTORY_AUDIO_PID" ]; then
	kill "$FACTORY_AUDIO_PID" 2>/dev/null || true
fi

if EXFAT_NATIVE_BUILTIN; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Built-in exFAT support active, removing FUSE helper"
	# This seems crazy but it works!
	rm -f /sbin/mount.exfat /sbin/mount.exfat-fuse
elif EXFAT_NATIVE_READY; then
	LOG_INFO "$0" 0 "FACTORY RESET" "Native exFAT module active"
else
	LOG_INFO "$0" 0 "FACTORY RESET" "Using FUSE exFAT fallback"
fi

CREDITS_DIR="/tmp/mustardos"
CREDITS_COMPLETE="$CREDITS_DIR/mucredits.complete"
mkdir -p "$CREDITS_DIR"
rm -f "$CREDITS_COMPLETE"

/opt/muos/frontend/mucredits &
CREDITS_PID=$!
CREDITS_GRACE=0

while [ -r "/proc/$CREDITS_PID/stat" ]; do
	read -r _ _ CREDITS_STATE _ <"/proc/$CREDITS_PID/stat" 2>/dev/null || break
	[ "$CREDITS_STATE" = Z ] && break

	if [ -e "$CREDITS_COMPLETE" ]; then
		CREDITS_GRACE=$((CREDITS_GRACE + 1))
		[ "$CREDITS_GRACE" -eq 50 ] && kill -TERM "$CREDITS_PID" 2>/dev/null
		if [ "$CREDITS_GRACE" -ge 60 ]; then
			kill -KILL "$CREDITS_PID" 2>/dev/null
			break
		fi
	fi

	sleep 0.1
done

if [ ! -r "/proc/$CREDITS_PID/stat" ]; then
	wait "$CREDITS_PID" 2>/dev/null
else
	read -r _ _ CREDITS_STATE _ <"/proc/$CREDITS_PID/stat" 2>/dev/null
	[ "$CREDITS_STATE" = Z ] && wait "$CREDITS_PID" 2>/dev/null
fi

rm -f "$CREDITS_COMPLETE"

SET_VAR_DURABLE "config" "boot/factory_reset" "0"
