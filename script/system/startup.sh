#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh

# Initialise all of the internal device and global variables
/opt/muos/script/var/init/device.sh init
/opt/muos/script/var/init/global.sh init

# Restore the default device screen to current WxH dimensions
for MODE in "screen" "mux"; do
	SET_VAR "device" "$MODE/width" "$(GET_VAR "device" "screen/internal/width")"
	SET_VAR "device" "$MODE/height" "$(GET_VAR "device" "screen/internal/height")"
done

printf "awake" >"/tmp/sleep_state"

case "$(GET_VAR "global" "settings/advanced/rumble")" in
	1 | 4 | 5) RUMBLE "$(GET_VAR "device" "board/rumble")" 0.3 ;;
	*) ;;
esac

DEVICE_CURRENT="/opt/muos/device/current"
[ -L "$DEVICE_CURRENT" ] && rm -rf "$DEVICE_CURRENT"
mkdir -p "$DEVICE_CURRENT"
mount --bind "/opt/muos/device/$(GET_VAR "device" "board/name")" "$DEVICE_CURRENT"

echo "pipewire" >"$AUDIO_SRC"

/sbin/udevd -d || CRITICAL_FAILURE udev
udevadm trigger --type=subsystems --action=add &
udevadm trigger --type=devices --action=add &
udevadm settle --timeout=30 || LOG_ERROR "$0" 0 "BOOTING" "Udevadm Settle Failure"

if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 0 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Loading Storage Mounts"
	/opt/muos/script/mount/start.sh &

	LOG_INFO "$0" 0 "BOOTING" "Removing any update scripts"
	rm -rf /opt/update.sh

	echo 1 >/tmp/work_led_state
	: >/tmp/net_start
fi

LOG_INFO "$0" 0 "BOOTING" "Restoring Default Sound System"
cp -f "/opt/muos/device/current/control/asound.conf" "/etc/asound.conf"

LOG_INFO "$0" 0 "BOOTING" "Checking Swapfile Requirements"
/opt/muos/script/system/swapfile.sh &

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

if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
	/opt/muos/device/current/script/module.sh

	if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
		/opt/muos/device/current/script/led_control.sh 2 255 225 173 1
	fi

	LOG_INFO "$0" 0 "FACTORY RESET" "Setting date time to default"
	date 010100002025
	hwclock -w

	EXEC_MUX "" "muxtimezone"
	while [ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ]; do
		EXEC_MUX "" "muxrtc"
		[ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ] && EXEC_MUX "" "muxtimezone"
	done

	LOG_INFO "$0" 0 "FACTORY RESET" "Starting Hotkey Daemon"
	/opt/muos/script/mux/hotkey.sh &
	/usr/bin/mpv /opt/muos/media/factory.mp3 &

	if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
		LOG_INFO "$0" 0 "FACTORY RESET" "Generating SSH Host Keys"
		/opt/openssh/bin/ssh-keygen -A &
	fi

	LOG_INFO "$0" 0 "FACTORY RESET" "Setting ARMHF Requirements"
	if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
		LOG_INFO "$0" 0 "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
		ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
	fi
	ldconfig -v >"/opt/muos/ldconfig.log"

	LOG_INFO "$0" 0 "FACTORY RESET" "Initialising Factory Reset Script"
	/opt/muos/script/system/reset.sh

	LOG_INFO "$0" 0 "FACTORY RESET" "Switching off Factory Reset mode"
	SET_VAR "global" "boot/factory_reset" "0"
	SET_VAR "global" "settings/advanced/rumble" "0"

	killall -q "mpv"

	/opt/muos/bin/nosefart /opt/muos/media/support.nsf &
	EXEC_MUX "" "muxcredits"
	/opt/muos/script/mux/quit.sh reboot frontend
fi

LOG_INFO "$0" 0 "BOOTING" "Running Device Specifics"
/opt/muos/device/current/script/start.sh

# Block on storage mounts as late as possible to reduce boot time. Must wait
# before charger detection since muxcharge expects the theme to be mounted.
LOG_INFO "$0" 0 "BOOTING" "Waiting for Storage Mounts"
while [ ! -f /run/muos/storage/mounted ]; do
	sleep 0.25
done

# Now we can unionise all of the above mounts "ROMS" folders into a singular
# mount making our life just that little bit easier(?)
LOG_INFO "$0" 0 "BOOTING" "Unionising ROMS on Storage Mounts"
/opt/muos/script/mount/union.sh start &

LOG_INFO "$0" 0 "BOOTING" "Checking for Safety Script"
OOPS="$(GET_VAR "device" "storage/rom/mount")/oops.sh"
[ -e "$OOPS" ] && ./"$OOPS"

LOG_INFO "$0" 0 "BOOTING" "Checking Disk Health"
if dmesg | grep 'Please run fsck'; then
	/opt/muos/bin/fbpad -bg 000000 -fg FFFFFF /opt/muos/script/system/fixdisk.sh
fi

LOG_INFO "$0" 0 "BOOTING" "Detecting Charge Mode"
/opt/muos/device/current/script/charge.sh

LOG_INFO "$0" 0 "BOOTING" "Starting Low Power Indicator"
/opt/muos/script/system/lowpower.sh &

LOG_INFO "$0" 0 "BOOTING" "Precaching RetroArch System"
ionice -c idle /opt/muos/bin/vmtouch -tfb /opt/muos/config/preload.txt &

LOG_INFO "$0" 0 "BOOTING" "Starting USB Function"
/opt/muos/script/system/usb.sh &

# Check for a kiosk configuration file on SD1
KIOSK_HARD_CONFIG="/opt/muos/config/kiosk.ini"
KIOSK_USER_CONFIG="$(GET_VAR "device" "storage/rom/mount")"/MUOS/kiosk.ini
[ -f "$KIOSK_USER_CONFIG" ] && [ ! -f "$KIOSK_HARD_CONFIG" ] && mv "$KIOSK_USER_CONFIG" "$KIOSK_HARD_CONFIG"
[ -f "$KIOSK_HARD_CONFIG" ] && /opt/muos/script/var/init/kiosk.sh init

LOG_INFO "$0" 0 "BOOTING" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &

LOG_INFO "$0" 0 "BOOTING" "Setting Device Controls"
/opt/muos/device/current/script/control.sh &

# Set the device specific SDL Controller Map
LOG_INFO "$0" 0 "BOOTING" "Setting up SDL Controller Map"
/opt/muos/script/mux/sdl_map.sh &

LOG_INFO "$0" 0 "BOOTING" "Checking for passcode lock"
HAS_UNLOCK=0
if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		LOG_INFO "$0" 0 "BOOTING" "Enabling passcode lock"
		EXEC_MUX "" "muxpass" -t boot
		HAS_UNLOCK="$?"
	done
fi

LOG_INFO "$0" 0 "BOOTING" "Bringing up localhost network"
ifconfig lo up &

LOG_INFO "$0" 0 "BOOTING" "Checking for network capability"
if [ "$(GET_VAR "device" "board/network")" -eq 1 ] && [ "$(GET_VAR "global" "network/enabled")" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh &
fi

LOG_INFO "$0" 0 "BOOTING" "Running catalogue generator"
/opt/muos/script/system/catalogue.sh "$(GET_VAR "device" "storage/rom/mount")" &

dmesg >"$(GET_VAR "device" "storage/rom/mount")/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &

LOG_INFO "$0" 0 "BOOTING" "Correcting Home permissions"
chown -R root:root /root &
chmod -R 755 /root &

LOG_INFO "$0" 0 "BOOTING" "Correcting SSH permissions"
chown -R root:root /opt &
chmod -R 755 /opt &

echo 2 >/proc/sys/abi/cp15_barrier &

LOG_INFO "$0" 0 "BOOTING" "Backing up global configuration"
/opt/muos/script/system/config_backup.sh &

LOG_INFO "$0" 0 "BOOTING" "Starting muX frontend"
/opt/muos/script/mux/frontend.sh &

if [ "$(GET_VAR "global" "settings/advanced/user_init")" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting user initialisation scripts"
	/opt/muos/script/system/user_init.sh &
fi
