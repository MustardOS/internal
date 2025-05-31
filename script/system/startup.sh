#!/bin/sh

. /opt/muos/script/var/func.sh

rm -f /opt/muos/log/*.log &
rm -rf /opt/muxtmp &

SET_VAR "system" "idle_inhibit" 0
SET_VAR "system" "resume_uptime" "$(cut -d ' ' -f 1 /proc/uptime)"
SET_VAR "config" "boot/device_mode" "0"

LOG_INFO "$0" 0 "BOOTING" "Setting OS Release"
/opt/muos/script/system/os_release.sh &

LOG_INFO "$0" 0 "BOOTING" "Reset temporary screen rotation and zoom"
SCREEN_DIR="/opt/muos/device/config/screen"
for T in s_rotate s_zoom; do
	[ -f "$SCREEN_DIR/$T" ] && rm -f "$SCREEN_DIR/$T"
done

LOG_INFO "$0" 0 "BOOTING" "Caching System Variables"
GOVERNOR=$(GET_VAR "device" "cpu/governor")
WIDTH=$(GET_VAR "device" "screen/internal/width")
HEIGHT=$(GET_VAR "device" "screen/internal/height")
RUMBLE_SETTING=$(GET_VAR "config" "settings/advanced/rumble")
RUMBLE_PIN=$(GET_VAR "device" "board/rumble")
BOARD_HDMI=$(GET_VAR "device" "board/hdmi")
ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")
PASSCODE_LOCK=$(GET_VAR "config" "settings/advanced/lock")
FACTORY_RESET=$(GET_VAR "config" "boot/factory_reset")
HAS_NETWORK=$(GET_VAR "device" "board/network")
USER_INIT=$(GET_VAR "config" "settings/advanced/user_init")

LOG_INFO "$0" 0 "BOOTING" "Setting 'performance' Governor"
echo "performance" >"$GOVERNOR"

LOG_INFO "$0" 0 "BOOTING" "Device Rumble Check"
case "$RUMBLE_SETTING" in 1 | 4 | 5) RUMBLE "$RUMBLE_PIN" 0.3 ;; esac

LOG_INFO "$0" 0 "BOOTING" "Restoring Screen Mode"
for MODE in screen mux; do
	SET_VAR "device" "$MODE/width" "$WIDTH"
	SET_VAR "device" "$MODE/height" "$HEIGHT"
done &

LOG_INFO "$0" 0 "BOOTING" "Bringing Up 'localhost' Network"
ifconfig lo up &

LOG_INFO "$0" 0 "BOOTING" "Loading Device Specific Modules"
/opt/muos/device/script/module.sh load &

LOG_INFO "$0" 0 "BOOTING" "Starting Device Management System"
/sbin/udevd -d || CRITICAL_FAILURE udev
udevadm trigger --type=subsystems --action=add &
udevadm trigger --type=devices --action=add &
udevadm settle --timeout=10 || LOG_ERROR "$0" 0 "BOOTING" "Udevadm Settle Failure"

if [ "$FACTORY_RESET" -eq 0 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Setting RTC Maximum Frequency"
	echo 2048 >/sys/class/rtc/rtc0/max_user_freq

	LOG_INFO "$0" 0 "BOOTING" "Loading Storage Mounts"
	/opt/muos/script/mount/start.sh &

	LOG_INFO "$0" 0 "BOOTING" "Removing Existing Update Scripts"
	rm -rf /opt/update.sh

	echo 1 >/tmp/work_led_state
	: >/tmp/net_start
fi

LOG_INFO "$0" 0 "BOOTING" "Detecting Console Mode"
if [ "$BOARD_HDMI" -eq 1 ]; then
	if ! IS_INTERNAL_DISPLAY; then
		SET_VAR "config" "boot/device_mode" "1"
	fi
fi

LOG_INFO "$0" 0 "BOOTING" "Checking Swap Requirements"
/opt/muos/script/system/swap.sh &

LOG_INFO "$0" 0 "BOOTING" "Restoring Default Sound System"
cp -f "/opt/muos/device/control/asound.conf" "/etc/asound.conf"

if [ -s "$ALSA_CONFIG" ]; then
	LOG_INFO "$0" 0 "BOOTING" "ALSA Config Check Passed"
else
	LOG_WARN "$0" 0 "BOOTING" "ALSA Config Check Failed: Restoring"
	cp -f "/opt/muos/share/conf/alsa.conf" "$ALSA_CONFIG"
fi

LOG_INFO "$0" 0 "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOG_INFO "$0" 0 "BOOTING" "Starting Pipewire"
/opt/muos/script/system/pipewire.sh &

if [ "$FACTORY_RESET" -eq 1 ]; then
	/opt/muos/script/system/factory.sh
	/opt/muos/script/system/halt.sh reboot
fi

LOG_INFO "$0" 0 "BOOTING" "Correcting Permissions"
(chown -R root:root /root && chmod -R 755 /root) &
(chown -R root:root /opt && chmod -R 755 /opt) &

LOG_INFO "$0" 0 "BOOTING" "Device Specific Startup"
/opt/muos/device/script/start.sh &

LOG_INFO "$0" 0 "BOOTING" "Waiting for Storage Mounts"
while [ ! -f /run/muos/storage/mounted ]; do /opt/muos/bin/toybox sleep 0.1; done

LOG_INFO "$0" 0 "BOOTING" "Unionising ROMS on Storage Mounts"
/opt/muos/script/mount/union.sh start &

LOG_INFO "$0" 0 "BOOTING" "Checking for Safety Script"
OOPS="$ROM_MOUNT/oops.sh"
[ -x "$OOPS" ] && "$OOPS"

LOG_INFO "$0" 0 "BOOTING" "Detecting Charge Mode"
/opt/muos/device/script/charge.sh

LOG_INFO "$0" 0 "BOOTING" "Checking for Network Capability"
if [ "$HAS_NETWORK" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh connect &
fi

LOG_INFO "$0" 0 "BOOTING" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &

LOG_INFO "$0" 0 "BOOTING" "Checking for Passcode Lock"
HAS_UNLOCK=0
if [ "$PASSCODE_LOCK" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		EXEC_MUX "" "muxpass" -t boot
		HAS_UNLOCK="$EXIT_STATUS"
	done
fi

if [ "$USER_INIT" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting User Initialisation Scripts"
	/opt/muos/script/system/user_init.sh &
fi

LOG_INFO "$0" 0 "BOOTING" "Starting muX Frontend"
/opt/muos/script/mux/frontend.sh &

LOG_INFO "$0" 0 "BOOTING" "Starting Low Power Indicator"
/opt/muos/script/system/lowpower.sh &

LOG_INFO "$0" 0 "BOOTING" "Starting USB Function"
/opt/muos/script/system/usb.sh &

LOG_INFO "$0" 0 "BOOTING" "Setting Device Controls"
/opt/muos/device/script/control.sh &

LOG_INFO "$0" 0 "BOOTING" "Setting up SDL Controller Map"
/opt/muos/script/mux/sdl_map.sh &

LOG_INFO "$0" 0 "BOOTING" "Running Catalogue Generator"
/opt/muos/script/system/catalogue.sh "$ROM_MOUNT" &

LOG_INFO "$0" 0 "BOOTING" "Precaching RetroArch System"
ionice -c idle /opt/muos/bin/vmtouch -tfb /opt/muos/share/conf/preload.txt &

dmesg >"$ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &
