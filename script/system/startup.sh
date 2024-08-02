#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/audio.sh
. /opt/muos/script/var/device/device.sh
. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/boot.sh
. /opt/muos/script/var/global/network.sh
. /opt/muos/script/var/global/setting_advanced.sh
. /opt/muos/script/var/global/setting_general.sh

if [ "$DC_DEV_NAME" = "RG40XX" ]; then
	/opt/muos/device/rg40xx/script/led_control.sh 2 255 225 173 1
fi

AUDIO_SRC="/tmp/mux_audio_src"
echo "pipewire" >$AUDIO_SRC

/sbin/udevd -d || {
	echo "FAIL"
	exit 1
}
udevadm trigger --type=subsystems --action=add &
udevadm trigger --type=devices --action=add &
udevadm settle --timeout=30 || LOGGER "$0" "BOOTING" "Udevadm Settle Failure"

if [ -s "$GLOBAL_CONFIG" ]; then
	LOGGER "$0" "BOOTING" "Global Config Check Passed"
else
	LOGGER "$0" "BOOTING" "Global Config Check Failed: Restoring"
	cp -f "/opt/muos/config/config.bak" "$GLOBAL_CONFIG"
fi

if [ -s "$ALSA_CONFIG" ]; then
	LOGGER "$0" "BOOTING" "ALSA Config Check Passed"
else
	LOGGER "$0" "BOOTING" "ALSA Config Check Failed: Restoring"
	cp -f "/opt/muos/config/alsa.conf" "$ALSA_CONFIG"
fi

if [ "$GC_BOO_DEVICE_SETUP" -eq 1 ]; then
	MODIFY_INI "$GLOBAL_CONFIG" "boot" "device_setup" "0"
	/opt/muos/extra/muxdevice
fi

LOGGER "$0" "BOOTING" "Checking Firmware"
/opt/muos/script/system/firmware.sh

LOGGER "$0" "BOOTING" "Removing any update scripts"
rm -rf /opt/update.sh

echo 1 >/tmp/work_led_state
: >/tmp/net_start

LOGGER "$0" "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/$DEVICE_TYPE/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOGGER "$0" "BOOTING" "Restoring Audio Volume"
case "$GC_ADV_VOLUME" in
	"loud")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$DC_SND_MAX"
		;;
	"quiet")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$DC_SND_MIN"
		;;
	*)
		RESTORED=$(cat "/opt/muos/config/volume.txt")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$RESTORED"
		;;
esac

/opt/muos/script/system/pipewire.sh &

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
	/usr/bin/mpg123 -q /opt/muos/factory.mp3 &

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

LOGGER "$0" "BOOTING" "Setting up SDL Controller Map"
if [ ! -f "/usr/lib/gamecontrollerdb.txt" ]; then
	ln -s "/opt/muos/device/$DEVICE_TYPE/control/gamecontrollerdb.txt" "/usr/lib/gamecontrollerdb.txt"
fi
if [ ! -f "/usr/lib32/gamecontrollerdb.txt" ]; then
	ln -s "/opt/muos/device/$DEVICE_TYPE/control/gamecontrollerdb.txt" "/usr/lib32/gamecontrollerdb.txt"
fi

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

LOGGER "$0" "BOOTING" "Running catalogue generator"
/opt/muos/script/system/catalogue.sh "$DC_STO_ROM_MOUNT" &

dmesg >"$DC_STO_ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &

LOGGER "$0" "BOOTING" "Correcting Home permissions"
chown -R root:root /root &
chmod -R 755 /root &

LOGGER "$0" "BOOTING" "Correcting SSH permissions"
chown -R root:root /opt &
chmod -R 755 /opt &

echo 2 >/proc/sys/abi/cp15_barrier &

cp "$MUOS_BOOT_LOG" "$DC_STO_ROM_MOUNT/MUOS/log/boot/."

if [ "$GC_BOO_FACTORY_RESET" -eq 1 ]; then
	killall -q "mpg123"

	LOGGER "$0" "FACTORY RESET" "Setting factory_reset to 0"
	MODIFY_INI "$GLOBAL_CONFIG" "boot" "factory_reset" "0"

	/opt/muos/extra/muxcredits
fi

LOGGER "$0" "BOOTING" "Setting current variable modes"
echo "$GC_ADV_ANDROID" >/tmp/mux_adb_mode
echo "$GC_GEN_COLOUR" >/tmp/mux_colour_temp
echo "$GC_GEN_HDMI" >/tmp/mux_hdmi_mode
/opt/muos/device/"$DEVICE_TYPE"/input/combo/audio.sh I
/opt/muos/device/"$DEVICE_TYPE"/input/combo/bright.sh I

LOGGER "$0" "BOOTING" "Backing up global configuration"
/opt/muos/script/system/config_backup.sh &

LOGGER "$0" "BOOTING" "Starting muX frontend"
/opt/muos/script/mux/frontend.sh &
