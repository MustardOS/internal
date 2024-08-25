#!/bin/sh

. /opt/muos/script/var/func.sh

# Initialise all of the internal device and global variables
/opt/muos/script/var/init/device.sh init
/opt/muos/script/var/init/global.sh init

if [ "$(GET_VAR "device" "board/name")" = "rg40xx-h" ]; then
	/opt/muos/device/rg40xx-h/script/led_control.sh 2 255 225 173 1
fi

echo "pipewire" >"$AUDIO_SRC"

/sbin/udevd -d || {
	echo "FAIL"
	exit 1
}
udevadm trigger --type=subsystems --action=add &
udevadm trigger --type=devices --action=add &
udevadm settle --timeout=30 || LOGGER "$0" "BOOTING" "Udevadm Settle Failure"

if [ -s "$ALSA_CONFIG" ]; then
	LOGGER "$0" "BOOTING" "ALSA Config Check Passed"
else
	LOGGER "$0" "BOOTING" "ALSA Config Check Failed: Restoring"
	cp -f "/opt/muos/config/alsa.conf" "$ALSA_CONFIG"
fi

LOGGER "$0" "BOOTING" "Removing any update scripts"
rm -rf /opt/update.sh

echo 1 >/tmp/work_led_state
: >/tmp/net_start

LOGGER "$0" "BOOTING" "Restoring Audio State"
cp -f "/opt/muos/device/$(GET_VAR "device" "board/name")/control/asound.state" "/var/lib/alsa/asound.state"
alsactl -U restore

LOGGER "$0" "BOOTING" "Restoring Audio Volume"
case "$(GET_VAR "global" "settings/advanced/volume")" in
	"loud")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(GET_VAR "device" "audio/max")"
		;;
	"quiet")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$(GET_VAR "device" "audio/min")"
		;;
	*)
		RESTORED=$(cat "/opt/muos/config/volume.txt")
		wpctl set-volume @DEFAULT_AUDIO_SINK@ "$RESTORED"
		;;
esac

/opt/muos/script/system/pipewire.sh &

if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
	LOGGER "$0" "FACTORY RESET" "Setting date time to default"
	date 082100002024
	hwclock -w

	/opt/muos/extra/muxtimezone
	while [ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ]; do
		/opt/muos/extra/muxrtc
		if [ "$(GET_VAR "global" "boot/clock_setup")" -eq 1 ]; then
			/opt/muos/extra/muxtimezone
		fi
	done

	LOGGER "$0" "FACTORY RESET" "Starting Input Reader"
	/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/input.sh
	/usr/bin/mpg123 -q /opt/muos/factory.mp3 &

	LOGGER "$0" "FACTORY RESET" "Initialising Factory Reset Script"
	/opt/muos/script/system/reset.sh

	if [ "$(GET_VAR "device" "board/network")" -eq 1 ]; then
		LOGGER "$0" "FACTORY RESET" "Generating SSH Host Keys"
		/opt/openssh/bin/ssh-keygen -A
	fi

	killall -q "input.sh"
fi

LOGGER "$0" "BOOTING" "Starting Storage Watchdog"
/opt/muos/script/mount/sdcard.sh
/opt/muos/script/mount/usb.sh

LOGGER "$0" "BOOTING" "Running Device Specifics"
/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/start.sh

LOGGER "$0" "BOOTING" "Detecting Charge Mode"
/opt/muos/device/"$(GET_VAR "device" "board/name")"/script/charge.sh

LOGGER "$0" "BOOTING" "Setting ARMHF Requirements"
if [ ! -f "/lib/ld-linux-armhf.so.3" ]; then
	LOGGER "$0" "BOOTING" "Configuring Dynamic Linker Run Time Bindings"
	ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
fi
ldconfig -v >"$(GET_VAR "device" "storage/rom/mount")/MUOS/log/ldconfig.log"

LOGGER "$0" "BOOTING" "Setting up SDL Controller Map"
for l in lib lib32; do
	if [ ! -f "/usr/$l/gamecontrollerdb.txt" ]; then
		ln -s "/opt/muos/device/$(GET_VAR "device" "board/name")/control/gamecontrollerdb.txt" "/usr/$l/gamecontrollerdb.txt"
	fi
done

if [ "$(GET_VAR "global" "boot/factory_reset")" -eq 1 ]; then
	LOGGER "$0" "FACTORY RESET" "Setting factory_reset to 0"
	SET_VAR "global" "boot/factory_reset" "0"

	/opt/muos/extra/muxcredits
	killall -q "mpg123"

	. /opt/muos/script/mux/close_game.sh
	HALT_SYSTEM frontend reboot
fi

LOGGER "$0" "BOOTING" "Checking for passcode lock"
HAS_UNLOCK=0
if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		LOGGER "$0" "BOOTING" "Enabling passcode lock"
		nice --20 /opt/muos/extra/muxpass -t boot
		HAS_UNLOCK="$?"
	done
fi

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

cp /opt/muos/*.log "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/boot/."

LOGGER "$0" "BOOTING" "Setting current variable modes"
GET_VAR "global" "settings/advanced/android" >/tmp/mux_adb_mode
GET_VAR "global" "settings/general/colour" >/tmp/mux_colour_temp
GET_VAR "global" "settings/general/hdmi" >/tmp/mux_hdmi_mode
/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/audio.sh I
/opt/muos/device/"$(GET_VAR "device" "board/name")"/input/combo/bright.sh I

LOGGER "$0" "BOOTING" "Backing up global configuration"
/opt/muos/script/system/config_backup.sh &

LOGGER "$0" "BOOTING" "Starting muX frontend"
/opt/muos/script/mux/frontend.sh &
