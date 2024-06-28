#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/audio.sh
. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/boot.sh
. /opt/muos/script/var/global/network.sh
. /opt/muos/script/var/global/setting_advanced.sh

if [ -s "$GLOBAL_CONFIG" ]; then
	LOGGER "$0" "BOOTING" "Config Check Passed"
else
	LOGGER "$0" "BOOTING" "Config Check Failed: Restoring"
	cp -f "/opt/muos/config/config.bak" "$GLOBAL_CONFIG"
fi

if [ "$GC_BOO_DEVICE_SETUP" -eq 1 ]; then
	MODIFY_INI "$GLOBAL_CONFIG" "boot" "device_setup" "0"
	/opt/muos/extra/muxdevice
fi

LOGGER "$0" "BOOTING" "Checking Firmware"
/opt/muos/script/system/firmware.sh

echo 1 >/tmp/work_led_state
echo 0 >/tmp/net_connected

LOGGER "$0" "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/$DEVICE_TYPE/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOGGER "$0" "BOOTING" "Restoring Audio Volume"
case "$GC_ADV_VOLUME" in
	"loud")
		amixer sset "$DC_SND_CONTROL" "$DC_SND_MAX" >/dev/null
		;;
	"quiet")
		amixer sset "$DC_SND_CONTROL" "$DC_SND_MIN" >/dev/null
		;;
	*)
		RESTORED=$(cat "/opt/muos/config/volume.txt")
		amixer sset "$DC_SND_CONTROL" "$RESTORED" >/dev/null
		;;
esac

if [ "$GC_BOO_FACTORY_RESET" -eq 1 ]; then
	LOGGER "$0" "FACTORY RESET" "Setting date time to default"
	date 070200002024
	hwclock -w

	/opt/muos/extra/muxtimezone
	while [ "$GC_BOO_CLOCK_SETUP" -eq 1 ]; do
		/opt/muos/extra/muxrtc
		. /opt/muos/script/var/global/boot.sh
		if [ "$GC_BOO_CLOCK_SETUP" -eq 1 ]; then
			/opt/muos/extra/muxtimezone
		fi
	done

	LOGGER "$0" "FACTORY RESET" "Starting Input Reader"
	/opt/muos/device/"$DEVICE_TYPE"/input/input.sh
	/opt/muos/bin/mp3play "/opt/muos/factory.mp3" &

	LOGGER "$0" "FACTORY RESET" "Initialising Factory Reset Script"
	/opt/muos/script/system/reset.sh

	if [ "$DC_DEV_NETWORK" -eq 1 ]; then
		LOGGER "$0" "FACTORY RESET" "Generating SSH Host Keys"
		/opt/openssh/bin/ssh-keygen -A
	fi

	killall -q "input.sh"
fi

LOGGER "$0" "BOOTING" "Detecting Charge Mode"
/opt/muos/device/"$DEVICE_TYPE"/script/charge.sh

LOGGER "$0" "BOOTING" "Checking for passcode lock"
HAS_UNLOCK=0
if [ "$GC_ADV_LOCK" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		LOGGER "$0" "BOOTING" "Enabling passcode lock"
		nice --20 /opt/muos/extra/muxpass -t boot
		HAS_UNLOCK="$?"
	done
fi

LOGGER "$0" "BOOTING" "Setting ARMHF Requirements"
if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
	LOGGER "$0" "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
fi
ldconfig -v >"$DC_STO_ROM_MOUNT/MUOS/log/ldconfig.log"

LOGGER "$0" "BOOTING" "Starting Storage Watchdog"
/opt/muos/script/mount/sdcard.sh &
/opt/muos/script/mount/usb.sh &

LOGGER "$0" "BOOTING" "Running Device Specifics"
/opt/muos/device/"$DEVICE_TYPE"/script/start.sh &

LOGGER "$0" "BOOTING" "Bringing up localhost network"
ifconfig lo up &

LOGGER "$0" "BOOTING" "Checking for network capability"
if [ "$DC_DEV_NETWORK" -eq 1 ] && [ "$GC_NET_ENABLED" -eq 1 ]; then
	LOGGER "$0" "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh &
fi

LOGGER "$0" "BOOTING" "Running dotclean"
/opt/muos/script/system/dotclean.sh &

LOGGER "$0" "BOOTING" "Running catalogue generator"
/opt/muos/script/system/catalogue.sh &

dmesg >"$DC_STO_ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &

LOGGER "$0" "BOOTING" "Correcting SSH permissions"
chown -R root:root /opt &
chmod -R 755 /opt &

echo 2 >/proc/sys/abi/cp15_barrier &

cp "$MUOS_BOOT_LOG" "$DC_STO_ROM_MOUNT/MUOS/log/boot/."

if [ "$GC_BOO_FACTORY_RESET" -eq 1 ]; then
	killall -q "mp3play"

	LOGGER "$0" "FACTORY RESET" "Setting factory_reset to 0"
	MODIFY_INI "$GLOBAL_CONFIG" "boot" "factory_reset" "0"

	/opt/muos/extra/muxcredits
fi

LOGGER "$0" "BOOTING" "Backing up global configuration"
/opt/muos/script/system/config_backup.sh &

LOGGER "$0" "BOOTING" "Starting muX frontend"
/opt/muos/script/mux/frontend.sh &
