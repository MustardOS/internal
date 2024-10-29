#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
  *":/opt/muos/extra/lib:"*) ;;
  *) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh

# Initialise all of the internal device and global variables
/opt/muos/script/var/init/device.sh init
/opt/muos/script/var/init/global.sh init

case "$(GET_VAR "global" "settings/advanced/rumble")" in
	1 | 4 | 5) RUMBLE "$(GET_VAR "device" "board/rumble")" 0.3 ;;
	*) ;;
esac

DEV_BOARD=$(GET_VAR "device" "board/name")
[ ! -L /opt/muos/device/current ] && ln -s "$DEV_BOARD" /opt/muos/device/current

echo "pipewire" >"$AUDIO_SRC"

/sbin/udevd -d || CRITICAL_FAILURE udev
udevadm trigger --type=subsystems --action=add &
udevadm trigger --type=devices --action=add &
udevadm settle --timeout=30 || LOGGER "$0" "BOOTING" "Udevadm Settle Failure"

if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 0 ]; then
	LOGGER "$0" "BOOTING" "Loading Storage Mounts"
	/opt/muos/script/mount/start.sh &

	LOGGER "$0" "BOOTING" "Removing any update scripts"
	rm -rf /opt/update.sh

	echo 1 >/tmp/work_led_state
	: >/tmp/net_start
fi

LOGGER "$0" "BOOTING" "Restoring Default Sound System"
cp -f "/opt/muos/device/current/control/asound.conf" "/etc/asound.conf"

if [ -s "$ALSA_CONFIG" ]; then
	LOGGER "$0" "BOOTING" "ALSA Config Check Passed"
else
	LOGGER "$0" "BOOTING" "ALSA Config Check Failed: Restoring"
	cp -f "/opt/muos/config/alsa.conf" "$ALSA_CONFIG"
fi

LOGGER "$0" "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/current/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOGGER "$0" "BOOTING" "Starting Pipewire"
/opt/muos/script/system/pipewire.sh &

if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
	case "$DEV_BOARD" in
		rg40xx*) /opt/muos/device/current/script/led_control.sh 2 255 225 173 1 ;;
		*) ;;
	esac

	LOGGER "$0" "FACTORY RESET" "Setting date time to default"
	date 101100002024
	hwclock -w

	/opt/muos/extra/muxtimezone
	while [ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ]; do
		/opt/muos/extra/muxrtc
		if [ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ]; then
			/opt/muos/extra/muxtimezone
		fi
	done

	LOGGER "$0" "FACTORY RESET" "Starting Hotkey Daemon"
	/opt/muos/script/mux/hotkey.sh &
	/usr/bin/mpg123 -q /opt/muos/factory.mp3 &

	if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
		LOGGER "$0" "FACTORY RESET" "Generating SSH Host Keys"
		/opt/openssh/bin/ssh-keygen -A &
	fi

	LOGGER "$0" "FACTORY RESET" "Setting ARMHF Requirements"
	if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
		LOGGER "$0" "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
		ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
	fi
	ldconfig -v >"/opt/muos/ldconfig.log"

	LOGGER "$0" "FACTORY RESET" "Initialising Factory Reset Script"
	/opt/muos/script/system/reset.sh

	LOGGER "$0" "FACTORY RESET" "Switching off Factory Reset mode"
	SET_VAR "global" "boot/factory_reset" "0"
	SET_VAR "global" "settings/advanced/rumble" "0"

	killall -q "hotkey.sh" "mpg123"
	rm -f "/opt/muos/factory.mp3"

	/opt/muos/extra/muxcredits
	/opt/muos/script/mux/quit.sh reboot frontend
fi

LOGGER "$0" "BOOTING" "Starting Low Power Indicator"
/opt/muos/script/system/lowpower.sh &

LOGGER "$0" "BOOTING" "Precaching RetroArch System"
ionice -c idle /opt/muos/bin/vmtouch -tfb /opt/muos/preload.txt &

LOGGER "$0" "BOOTING" "Running Device Specifics"
/opt/muos/device/current/script/start.sh

LOGGER "$0" "BOOTING" "Starting Hotkey Daemon"
/opt/muos/script/mux/hotkey.sh &

# Block on storage mounts as late as possible to reduce boot time. Must wait
# before charger detection since muxcharge expects the theme to be mounted.
LOGGER "$0" "BOOTING" "Waiting for Storage Mounts"
while [ ! -f /run/muos/storage/mounted ]; do
	sleep 0.25
done

LOGGER "$0" "BOOTING" "Detecting Charge Mode"
/opt/muos/device/current/script/charge.sh

LOGGER "$0" "BOOTING" "Setting Device Controls"
/opt/muos/device/current/script/control.sh &

# Set the device specific SDL Controller Map
LOGGER "$0" "BOOTING" "Setting up SDL Controller Map"
/opt/muos/script/mux/sdl_map.sh &

LOGGER "$0" "BOOTING" "Checking for passcode lock"
HAS_UNLOCK=0
if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		LOGGER "$0" "BOOTING" "Enabling passcode lock"
		nice --20 /opt/muos/extra/muxpass -t boot
		HAS_UNLOCK="$?"
	done
fi

LOGGER "$0" "BOOTING" "Starting USB Function"
/opt/muos/script/system/usb.sh &

LOGGER "$0" "BOOTING" "Bringing up localhost network"
ifconfig lo up &

LOGGER "$0" "BOOTING" "Checking for network capability"
if [ "$(GET_VAR "device" "board/network")" -eq 1 ] && [ "$(GET_VAR "global" "network/enabled")" -eq 1 ]; then
	LOGGER "$0" "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh &
fi

LOGGER "$0" "BOOTING" "Running catalogue generator"
/opt/muos/script/system/catalogue.sh "$(GET_VAR "device" "storage/rom/mount")" &

dmesg >"$(GET_VAR "device" "storage/rom/mount")/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &

LOGGER "$0" "BOOTING" "Correcting Home permissions"
chown -R root:root /root &
chmod -R 755 /root &

LOGGER "$0" "BOOTING" "Correcting SSH permissions"
chown -R root:root /opt &
chmod -R 755 /opt &

echo 2 >/proc/sys/abi/cp15_barrier &

LOGGER "$0" "BOOTING" "Backing up global configuration"
/opt/muos/script/system/config_backup.sh &

LOGGER "$0" "BOOTING" "Starting muX frontend"
/opt/muos/script/mux/frontend.sh &
