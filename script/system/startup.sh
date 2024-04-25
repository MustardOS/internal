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

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

COLOUR=$(parse_ini "$CONFIG" "settings.general" "colour")
echo $COLOUR > /sys/class/disp/disp/attr/color_temperature

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

FACTORYRESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORYRESET" -eq 1 ]; then
	MUOSBOOT_LOG="/tmp/muosboot__${CURRENT_DATE}.log"
else
	MUOSBOOT_LOG="/mnt/mmc/MUOS/log/boot/muosboot__${CURRENT_DATE}.log"
fi

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

LOGGER "BOOTING" "Starting..."

if [ "$HDMI" -eq 1 ]; then
	/opt/muos/script/system/hdmi.sh &
fi

echo noop > /sys/devices/platform/soc/sdc0/mmc_host/mmc0/mmc0:59b4/block/mmcblk0/queue/scheduler
echo on > /sys/devices/platform/soc/sdc0/mmc_host/mmc0/power/control

echo 0xF > /sys/devices/system/cpu/autoplug/plug_mask

LOGGER "BOOTING" "Starting Storage Watchdog"
/opt/muos/script/mount/sdcard.sh
/opt/muos/script/mount/usb.sh

LOGGER "BOOTING" "Restoring Volume"
VOLUME_LOW=$(parse_ini "$CONFIG" "settings.advanced" "volume_low")
if [ "$VOLUME_LOW" -eq 1 ]; then
	cp -f /opt/muos/config/volume_low.txt /opt/muos/config/volume.txt
fi
/opt/muos/script/system/volume.sh restore &

if [ -e "/opt/muos/flag/DeviceSetup" ]; then
	/opt/muos/extra/muxdevice
	rm /opt/muos/flag/DeviceSetup
fi

FACTORYRESET=$(parse_ini "$CONFIG" "boot" "factory_reset")
if [ "$FACTORYRESET" -eq 1 ]; then
	date 010100002024
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

	LOGGER "FACTORY RESET" "Caching Shared Libraries"
	ldconfig

	TEMP_CONFIG=/tmp/temp_cfg

	awk -F "=" '/factory_reset/ {sub(/1/, "0", $2)} 1' OFS="=" $CONFIG > $TEMP_CONFIG
	mv $TEMP_CONFIG $CONFIG

	awk -F "=" '/verbose/ {sub(/1/, "0", $2)} 1' OFS="=" $CONFIG > $TEMP_CONFIG
	mv $TEMP_CONFIG $CONFIG

	hwclock -s
	
	killall "mp3play"
	
	/opt/muos/extra/muxkofi
else
	hwclock -s
fi

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
dmesg > "/mnt/mmc/MUOS/log/dmesg__${CURRENT_DATE}.log" &

LOGGER "BOOTING" "Fix for Multi-arch PortMaster"
ln -s /lib32/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
ldconfig

LOGGER "BOOTING" "Reset /opt to Root Ownership"
chown -R root:root /opt
chmod -R 755 /opt
# Special directories that should not be world editable!
chmod -R 700 /opt/openssh/var
chmod -R 700 /opt/openssh/etc

VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	cp "$MUOSBOOT_LOG" /mnt/mmc/MUOS/log/boot/.
fi

LOGGER "BOOTING" "Running Device Specific Script"
DEVICE=$(cat "/opt/muos/config/device.txt" | tr '[:upper:]' '[:lower:]')
/opt/muos/script/device/"$DEVICE".sh &

echo 2 > /proc/sys/abi/cp15_barrier &

/opt/muos/script/mux/frontend.sh &

