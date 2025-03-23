#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh

rm -f "/opt/muos/boot.log"

LOG_INFO "$0" 0 "BOOTING" "Initialising System Variables"
/opt/muos/script/var/init/device.sh init
/opt/muos/script/var/init/global.sh init

LOG_INFO "$0" 0 "BOOTING" "Caching System Variables"
GOVERNOR=$(GET_VAR "device" "cpu/governor")
WIDTH=$(GET_VAR "device" "screen/internal/width")
HEIGHT=$(GET_VAR "device" "screen/internal/height")
RUMBLE_SETTING=$(GET_VAR "global" "settings/advanced/rumble")
RUMBLE_PIN=$(GET_VAR "device" "board/rumble")
BOARD_NAME=$(GET_VAR "device" "board/name")
HDMI_PATH=$(GET_VAR "device" "screen/hdmi")
BOARD_HDMI=$(GET_VAR "device" "board/hdmi")
ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")
PASSCODE_LOCK=$(GET_VAR "global" "settings/advanced/lock")
FACTORY_RESET=$(GET_VAR "global" "boot/factory_reset")
HAS_NETWORK=$(GET_VAR "device" "board/network")
USER_INIT=$(GET_VAR "global" "settings/advanced/user_init")

LOG_INFO "$0" 0 "BOOTING" "Setting 'performance' Governor"
echo "performance" >"$GOVERNOR"

LOG_INFO "$0" 0 "BOOTING" "Device Rumble Check"
case "$RUMBLE_SETTING" in 1 | 4 | 5) RUMBLE "$RUMBLE_PIN" 0.3 ;; esac

LOG_INFO "$0" 0 "BOOTING" "Restoring Screen Mode"
for MODE in screen mux; do
	SET_VAR "device" "$MODE/width" "$WIDTH"
	SET_VAR "device" "$MODE/height" "$HEIGHT"
done &

LOG_INFO "$0" 0 "BOOTING" "Mounting Current Device Specifics"
DEVICE_CURRENT="/opt/muos/device/current"
[ -L "$DEVICE_CURRENT" ] && rm -rf "$DEVICE_CURRENT"
mkdir -p "$DEVICE_CURRENT"
mount --bind "/opt/muos/device/$BOARD_NAME" "$DEVICE_CURRENT"

LOG_INFO "$0" 0 "BOOTING" "Starting Device Management System"
/sbin/udevd -d || CRITICAL_FAILURE udev
udevadm trigger --type=subsystems --action=add &
udevadm trigger --type=devices --action=add &
udevadm settle --timeout=10 || LOG_ERROR "$0" 0 "BOOTING" "Udevadm Settle Failure"

if [ "$FACTORY_RESET" -eq 0 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Loading Storage Mounts"
	/opt/muos/script/mount/start.sh &

	LOG_INFO "$0" 0 "BOOTING" "Removing Existing Update Scripts"
	rm -rf /opt/update.sh

	echo 1 >/tmp/work_led_state
	: >/tmp/net_start
fi

LOG_INFO "$0" 0 "BOOTING" "Bringing Up 'localhost' Network"
ifconfig lo up &

LOG_INFO "$0" 0 "BOOTING" "Detecting Console Mode"
DEVICE_MODE=0
if [ "$(cat "$HDMI_PATH")" -eq 1 ] && [ "$BOARD_HDMI" -eq 1 ]; then
	LOG_INFO "$0" 0 "DEVICE MODE" "Entering Console Mode"
	DEVICE_MODE=1
fi
SET_VAR "global" "boot/device_mode" "$DEVICE_MODE"

LOG_INFO "$0" 0 "BOOTING" "Checking Swap Requirements"
/opt/muos/script/system/swap.sh &

LOG_INFO "$0" 0 "BOOTING" "Restoring Default Sound System"
cp -f "/opt/muos/device/current/control/asound.conf" "/etc/asound.conf"

if [ -s "$ALSA_CONFIG" ]; then
	LOG_INFO "$0" 0 "BOOTING" "ALSA Config Check Passed"
else
	LOG_WARN "$0" 0 "BOOTING" "ALSA Config Check Failed: Restoring"
	cp -f "/opt/muos/config/alsa.conf" "$ALSA_CONFIG"
fi

LOG_INFO "$0" 0 "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/current/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOG_INFO "$0" 0 "BOOTING" "Starting Pipewire"
/opt/muos/script/system/pipewire.sh &

[ "$FACTORY_RESET" -eq 1 ] && /opt/muos/script/system/factory.sh

LOG_INFO "$0" 0 "BOOTING" "Correcting Permissions"
(
	for DIR in /root /opt; do
		chown -R root:root "$DIR" &
		chmod -R 755 "$DIR" &
	done
	wait
) &

LOG_INFO "$0" 0 "BOOTING" "Device Specific Startup"
/opt/muos/device/current/script/start.sh &

LOG_INFO "$0" 0 "BOOTING" "Waiting for Storage Mounts"
while [ ! -f /run/muos/storage/mounted ]; do sleep 0.1; done

LOG_INFO "$0" 0 "BOOTING" "Unionising ROMS on Storage Mounts"
/opt/muos/script/mount/union.sh start &

LOG_INFO "$0" 0 "BOOTING" "Checking for Safety Script"
OOPS="$ROM_MOUNT/oops.sh"
[ -e "$OOPS" ] && ./"$OOPS"

LOG_INFO "$0" 0 "BOOTING" "Detecting Charge Mode"
/opt/muos/device/current/script/charge.sh

LOG_INFO "$0" 0 "BOOTING" "Checking for Network Capability"
if [ "$HAS_NETWORK" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh connect &
fi

LOG_INFO "$0" 0 "BOOTING" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &

LOG_INFO "$0" 0 "BOOTING" "Checking for Kiosk Mode"
KIOSK_HARD_CONFIG="/opt/muos/config/kiosk.ini"
KIOSK_USER_CONFIG="$ROM_MOUNT/MUOS/kiosk.ini"
[ -f "$KIOSK_USER_CONFIG" ] && [ ! -f "$KIOSK_HARD_CONFIG" ] && mv "$KIOSK_USER_CONFIG" "$KIOSK_HARD_CONFIG"
[ -f "$KIOSK_HARD_CONFIG" ] && /opt/muos/script/var/init/kiosk.sh init &

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

LOG_INFO "$0" 0 "BOOTING" "Backing up Global Configuration"
/opt/muos/script/system/config_backup.sh &

LOG_INFO "$0" 0 "BOOTING" "Starting Low Power Indicator"
/opt/muos/script/system/lowpower.sh &

LOG_INFO "$0" 0 "BOOTING" "Starting USB Function"
/opt/muos/script/system/usb.sh &

LOG_INFO "$0" 0 "BOOTING" "Setting Device Controls"
/opt/muos/device/current/script/control.sh &

LOG_INFO "$0" 0 "BOOTING" "Setting up SDL Controller Map"
/opt/muos/script/mux/sdl_map.sh &

LOG_INFO "$0" 0 "BOOTING" "Running Catalogue Generator"
/opt/muos/script/system/catalogue.sh "$ROM_MOUNT" &

LOG_INFO "$0" 0 "BOOTING" "Precaching RetroArch System"
ionice -c idle /opt/muos/bin/vmtouch -tfb /opt/muos/config/preload.txt &

dmesg >"$ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &
