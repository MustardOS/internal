#!/bin/sh

# We need to ensure that config.ini is readable before we continue
if [ -s "/opt/muos/config/config.ini" ]; then
	LOGGER "BOOTING" "Config Check Passed"
else
	LOGGER "BOOTING" "Config Check Failed: Restoring"
	cp -f "/opt/muos/config/config.bak" "/opt/muos/config/config.ini"
fi

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

# THIS REQUIRES SOMETHING TO PARSE `dmesg` FOR UNIQUE VALUES
# SO THAT WE CAN ADJUST FOR UNIQUE DEVICES AUTOMATICALLY!

DEVICE_SETUP=$(parse_ini "$CONFIG" "boot" "device_setup")
if [ "$DEVICE_SETUP" -eq 1 ]; then
	modify_ini "$CONFIG" "boot" "device_setup" "0"
	/opt/muos/extra/muxdevice
fi

LOGGER "BOOTING" "Checking Firmware"
/opt/muos/script/system/firmware.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

echo 1 > /tmp/work_led_state
echo 0 > /tmp/net_connected

LOGGER "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/$DEVICE/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOGGER "BOOTING" "Restoring Audio Volume"
VOLUME=$(parse_ini "$CONFIG" "settings.advanced" "volume")
AUDIO_CONTROL=$(parse_ini "$DEVICE_CONFIG" "audio" "control")
AUDIO_VOL_MIN=$(parse_ini "$DEVICE_CONFIG" "audio" "min")
AUDIO_VOL_MAX=$(parse_ini "$DEVICE_CONFIG" "audio" "max")
case "$VOLUME" in
	"loud")		
		amixer sset "$AUDIO_CONTROL" "$AUDIO_VOL_MAX" > /dev/null
		;;
	"quiet")
		amixer sset "$AUDIO_CONTROL" "$AUDIO_VOL_MIN" > /dev/null
		;;
	*)
		RESTORED=$(cat "/opt/muos/config/volume.txt")
		amixer sset "$AUDIO_CONTROL" "$RESTORED" > /dev/null
		;;
esac

FACTORY_RESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORY_RESET" -eq 1 ]; then
	date 060200002024
	hwclock -w

	CLOCK_SETUP=$(parse_ini "$CONFIG" "boot" "clock_setup")
	/opt/muos/extra/muxtimezone
	while [ "$CLOCK_SETUP" -eq 1 ]; do
		/opt/muos/extra/muxrtc
		CLOCK_SETUP=$(parse_ini "$CONFIG" "boot" "clock_setup")
		if [ "$CLOCK_SETUP" -eq 1 ]; then
			/opt/muos/extra/muxtimezone
		fi
	done

	/opt/muos/bin/muaudio &
	/opt/muos/bin/mp3play "/opt/muos/factory.mp3" &

	LOGGER "FACTORY RESET" "Initialising Factory Reset Script"
	/opt/muos/script/system/reset.sh "$MUOSBOOT_LOG"

	SUPPORT_NETWORK=$(parse_ini "$DEVICE_CONFIG" "device" "network")
	if [ "$SUPPORT_NETWORK" -eq 1 ]; then
		LOGGER "FACTORY RESET" "Generating SSH Host Keys"
		/opt/openssh/bin/ssh-keygen -A
	fi
fi

/opt/muos/device/"$DEVICE"/script/charge.sh

HAS_UNLOCK=0
LOCK=$(parse_ini "$CONFIG" "settings.advanced" "lock")
if [ "$LOCK" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		nice --20 /opt/muos/extra/muxpass -t boot
		HAS_UNLOCK="$?"
	done
fi

LOGGER "BOOTING" "Setting ARMhf Requirements"
if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
	LOGGER "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
fi
ldconfig -v > "$STORE_ROM/MUOS/log/ldconfig.log"

LOGGER "BOOTING" "Starting Storage Watchdog"
/opt/muos/script/mount/sdcard.sh &
/opt/muos/script/mount/usb.sh &

LOGGER "BOOTING" "Running Device Specifics"
/opt/muos/device/"$DEVICE"/script/start.sh &

SUPPORT_HDMI=$(parse_ini "$DEVICE_CONFIG" "device" "hdmi")
HDMI=$(parse_ini "$CONFIG" "settings.general" "hdmi")
if [ "$SUPPORT_HDMI" -eq 1 ] && [ "$HDMI" -eq 1 ]; then
	/opt/muos/script/system/hdmi.sh &
fi

SUPPORT_NETWORK=$(parse_ini "$DEVICE_CONFIG" "device" "network")
NET_ENABLED=$(parse_ini "$CONFIG" "network" "enabled")
if [ "$SUPPORT_NETWORK" -eq 1 ] && [ "$NET_ENABLED" -eq 1 ]; then
	LOGGER "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh "$MUOSBOOT_LOG" &
fi

/opt/muos/script/system/dotclean.sh &
/opt/muos/script/system/catalogue.sh &

dmesg > "$STORE_ROM/MUOS/log/dmesg/dmesg__${CURRENT_DATE}.log" &

chown -R root:root /opt &
chmod -R 755 /opt &

echo 2 > /proc/sys/abi/cp15_barrier &

VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	cp "$MUOSBOOT_LOG" "$STORE_ROM/MUOS/log/boot/."
fi

FACTORY_RESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORY_RESET" -eq 1 ]; then
	LOGGER "FACTORY RESET" "All Done!"
	killall "mp3play"

	modify_ini "$CONFIG" "boot" "factory_reset" "0"
	modify_ini "$CONFIG" "settings.advanced" "verbose" "0"

	/opt/muos/extra/muxcredits
fi

/opt/muos/script/mux/configbackup.sh &

touch /tmp/pdi_go
/opt/muos/script/mux/frontend.sh &

