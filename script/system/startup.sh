#!/bin/sh
# shellcheck disable=1090,2002

CHARGER_ONLINE=$(cat /sys/class/power_supply/axp2202-usb/online)
if [ "$CHARGER_ONLINE" -eq 1 ]; then
	echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
	/opt/muos/extra/muxcharge
fi

# This right here is important for various reasons!
insmod /lib/modules/mali_kbase.ko &
insmod /lib/modules/squashfs.ko &

echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

mount -t vfat -o rw,utf8,noatime,nofail /dev/mmcblk0p2 /mnt/boot
mount -t exfat -o rw,utf8,noatime,nofail /dev/mmcblk0p7 /mnt/mmc
mount -t debugfs debugfs /sys/kernel/debug

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo "$COLOUR" > /sys/class/disp/disp/attr/color_temperature

THERMAL=$(parse_ini "$CONFIG" "settings.advanced" "thermal")
if [ "$THERMAL" -eq 1 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		if [ -e "$ZONE/mode" ]; then
			echo "disabled" > "ZONE/mode"
		fi
	done
fi

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

LOGGER() {
VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	_TITLE=$1
	_MESSAGE=$2
	_FORM=$(cat <<EOF
$_TITLE

$_MESSAGE
EOF
	)
	/opt/muos/extra/muxstart "$_FORM" && sleep 0.5
	echo "=== ${CURRENT_DATE} === $_MESSAGE" >> "$MUOSBOOT_LOG"
fi
}

FACTORYRESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORYRESET" -eq 1 ]; then
	MUOSBOOT_LOG="/tmp/muosboot__${CURRENT_DATE}.log"
else
	MUOSBOOT_LOG="/mnt/mmc/MUOS/log/boot/muosboot__${CURRENT_DATE}.log"
fi

LOGGER "BOOTING" "Starting..."

HAS_UNLOCK=0
LOCK=$(parse_ini "$CONFIG" "settings.advanced" "lock")
if [ "$LOCK" -eq 1 ]; then
	while [ "$HAS_UNLOCK" != 1 ]; do
		nice --20 /opt/muos/extra/muxpass -t boot
		HAS_UNLOCK="$?"
	done
fi

HDMI=$(parse_ini "$CONFIG" "settings.general" "hdmi")
if [ "$HDMI" -eq 1 ]; then
	/opt/muos/script/system/hdmi.sh &
fi

echo noop > /sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:59b4/block/mmcblk0/queue/scheduler
echo on > /sys/devices/platform/soc/sdc0/mmc_host/mmc0/power/control

echo 1 > /tmp/work_led_state

if [ -e "/opt/muos/flag/DeviceSetup" ]; then
	/opt/muos/extra/muxdevice
	rm /opt/muos/flag/DeviceSetup
fi

FIRMWARE_DONE=$(parse_ini "$CONFIG" "boot" "firmware_done")
if [ "$FIRMWARE_DONE" -eq 0 ]; then
	if [ $(cat "/opt/muos/config/device.txt") = "RG35XX-SP" ]; then
		LOGGER "FIRMWARE UPDATE" "Updating to required firmware for device!"

		dd if=/opt/muos/firmware/rg35xxsp/boot.bin of=/dev/mmcblk0 seek=176128 conv=notrunc
		dd if=/opt/muos/firmware/rg35xxsp/package.bin of=/dev/mmcblk0 bs=1024 seek=16400 conv=notrunc

		modify_ini "$CONFIG" "boot" "firmware_done" "1"

		reboot
	fi
fi

LOGGER "BOOTING" "Starting Storage Watchdog"
/opt/muos/script/mount/sdcard.sh
/opt/muos/script/mount/usb.sh

LOGGER "BOOTING" "Restoring Volume"
VOLUME_LOW=$(parse_ini "$CONFIG" "settings.advanced" "volume_low")
if [ "$VOLUME_LOW" -eq 1 ]; then
	cp -f /opt/muos/config/volume_low.txt /opt/muos/config/volume.txt
fi
/opt/muos/script/system/volume.sh restore &

FACTORYRESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORYRESET" -eq 1 ]; then
	date 051000002024
	hwclock -w

	/opt/muos/extra/muxtimezone
	while [ -e "/opt/muos/flag/ClockSetup" ]; do
		/opt/muos/extra/muxrtc
		if [ -e "/opt/muos/flag/ClockSetup" ]; then
			/opt/muos/extra/muxtimezone
		fi
	done

	/opt/muos/bin/muaudio &
	/opt/muos/bin/mp3play "/opt/muos/factory.mp3" &

	LOGGER "FACTORY RESET" "Initialising Factory Reset Script"
	/opt/muos/script/system/reset.sh "$MUOSBOOT_LOG"
	
	LOGGER "FACTORY RESET" "Generating SSH Host Keys"
	/opt/openssh/bin/ssh-keygen -A
else
	/opt/muos/script/mux/frontend.sh &
fi

LOGGER "BOOTING" "Setting System Time"
hwclock -s &

NET_ENABLED=$(parse_ini "$CONFIG" "network" "enabled")
if [ "$NET_ENABLED" -eq 1 ]; then
	LOGGER "BOOTING" "Starting Network Services"
	/opt/muos/script/system/network.sh "$MUOSBOOT_LOG" &
fi

LOGGER "BOOTING" "Starting muX Services"
/opt/muos/script/system/watchdog.sh &

LOGGER "BOOTING" "Cleaning Dotfiles"
/opt/muos/script/system/dotclean.sh &

LOGGER "BOOTING" "Exporting Diagnostic Messages"
dmesg > "/mnt/mmc/MUOS/log/dmesg/dmesg__${CURRENT_DATE}.log" &

LOGGER "BOOTING" "Caching Shared Libraries"
rm -f /etc/ld.so.cache
until [ -e "/lib/ld-linux-armhf.so.3" ]; do
        ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
done
ldconfig &

LOGGER "BOOTING" "Reset /opt to Root Ownership"
chown -R root:root /opt &
chmod -R 755 /opt &

VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	cp "$MUOSBOOT_LOG" /mnt/mmc/MUOS/log/boot/.
fi

LOGGER "BOOTING" "Running Device Specific Script"
DEVICE=$(cat "/opt/muos/config/device.txt" | tr '[:upper:]' '[:lower:]')
/opt/muos/script/device/"$DEVICE".sh
/opt/muos/script/input/"$DEVICE"/init.sh

FACTORYRESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORYRESET" -eq 1 ]; then
	killall "mp3play"

	TEMP_CONFIG=/tmp/temp_cfg

	modify_ini "$CONFIG" "boot" "factory_reset" "0"
	modify_ini "$CONFIG" "settings.advanced" "verbose" "0"

	/opt/muos/extra/muxkofi

	/opt/muos/script/mux/frontend.sh &
fi

echo 2 > /proc/sys/abi/cp15_barrier &

