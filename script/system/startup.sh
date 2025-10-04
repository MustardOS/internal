#!/bin/sh
#:] ## Startup Sequence
#:] This is the main script that is called by the `S01muos` script within `/etc/init.d`.
#:] Everything from here on in will run via these internal scripts. The `LOG_*` runners are
#:] kept to a minimum and are invoked by the `func.sh` global script. Most of them are kept
#:] under wraps unless a debug flag is set as it cause increase boot time by a few seconds.
#:] ~

. /opt/muos/script/var/func.sh

#:] ### Session Housekeeping
#:] Create a temp workspace and clear any stale logs and update data from previous boots.
mkdir -p "/tmp/muos"
rm -rf /opt/muos/log/*.log /opt/muxtmp

#:] ### Initialise Core State
#:] Cache uptime and baseline flags used by other components during boot.
read -r MU_UPTIME _ </proc/uptime
SET_VAR "system" "resume_uptime" "$MU_UPTIME"
SET_VAR "system" "idle_inhibit" "0"
SET_VAR "config" "boot/device_mode" "0"
SET_VAR "device" "audio/ready" "0"

#:] ### Set OS Release Metadata
#:] Generate `/etc/os-release` and similar so services can report the right version.
LOG_INFO "$0" 0 "BOOTING" "Setting OS Release"
/opt/muos/script/system/os_release.sh &

#:] ### Reset Display variables
#:] Just in case somebody, or something, has rotated the display.
LOG_INFO "$0" 0 "BOOTING" "Reset temporary screen rotation and zoom"
SCREEN_DIR="/opt/muos/device/config/screen"
rm -f "$SCREEN_DIR/s_rotate" "$SCREEN_DIR/s_zoom" &

#:] ### Frequently Used Variables
#:] These are best to call once and use repeatedly instead of calling them individually.
LOG_INFO "$0" 0 "BOOTING" "Caching System Variables"
BOARD_NAME=$(GET_VAR "device" "board/name")
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
FIRST_INIT=$(GET_VAR "config" "boot/first_init")
USB_FUNCTION=$(GET_VAR "config" "settings/advanced/usb_function")
CONNECT_ON_BOOT=$(GET_VAR "config" "settings/network/boot")
HDMI_PATH=$(GET_VAR "device" "screen/hdmi")
NET_ASYNC=$(GET_VAR "config" "settings/network/async_load")
NET_COMPAT=$(GET_VAR "config" "settings/network/compat")

#:] ### Enable Rumble Support
#:] Primarily used for TrimUI/RK3326 devices at the moment.
case "$BOARD_NAME" in
	tui*)
		[ -e /sys/class/gpio/gpio227 ] || echo 227 >/sys/class/gpio/export
		echo out >/sys/class/gpio/gpio227/direction
		echo 0 >/sys/class/gpio/gpio227/value
		;;
	rk*)
		[ -e /sys/class/pwm/pwmchip0/pwm0 ] || echo 0 >/sys/class/pwm/pwmchip0/export
		echo 1000000 >/sys/class/pwm/pwmchip0/pwm0/period
		echo 1000000 >/sys/class/pwm/pwmchip0/pwm0/duty_cycle
		echo 1 >/sys/class/pwm/pwmchip0/pwm0/enable
		;;
esac

#:] ### Start PipeWire Audio
#:] Launch PipeWire services (and wireplumber, if enabled) in one go.
LOG_INFO "$0" 0 "BOOTING" "Starting Pipewire"
/opt/muos/script/system/pipewire.sh start &

#:] ### Set Default CPU Governor
#:] Run the CPU at full performance during boot to shorten startup time.
#:] Default is `performance` so that startup runs just that little bit quicker.
LOG_INFO "$0" 0 "BOOTING" "Setting 'performance' Governor"
echo "performance" >"$GOVERNOR" &

#:] ### Device Specific Module Loading
#:] Load device specific kernel modules (except network).
LOG_INFO "$0" 0 "BOOTING" "Loading Device Specific Modules"
if [ "$FIRST_INIT" -eq 1 ] && [ "$FACTORY_RESET" -eq 0 ]; then
	/opt/muos/script/device/module.sh load &
fi

#:] ### First Init Messages
#:] On the very first boot, show a disclaimer.
#:] Once that is done and we've rebooted display a "Getting Ready" message for slower device combinations.
if [ "$FIRST_INIT" -eq 0 ]; then
	/opt/muos/script/device/module.sh load
	if [ "$FACTORY_RESET" -eq 1 ]; then
		LOG_INFO "$0" 0 "BOOTING" "Loading First Init Disclaimer"
		/opt/muos/frontend/muxwarn &
	else
		/opt/muos/frontend/muxmessage 0 "$(printf 'FIRST INIT\n\nMustardOS is Getting Ready!\nPlease wait a moment...')" &
	fi
fi

#:] ### Mark first-boot complete (_if applicable_)
#:] This is a first initialisation flag, once everything is a-ok we'll mark it as done.
#:] Upon next startup we don't run any specific first initialisation routines.
[ "$FIRST_INIT" -eq 0 ] && SET_VAR "config" "boot/first_init" "1"

#:] ### Rumble Self Test
#:] Briefly vibrate on capable devices to confirm GPIO/PWM configuration.
LOG_INFO "$0" 0 "BOOTING" "Device Rumble Check"
case "$RUMBLE_SETTING" in 1 | 4 | 5) RUMBLE "$RUMBLE_PIN" 0.3 ;; esac

#:] ### Loopback Network
#:] Bring up `lo` so local services can bind immediately.
LOG_INFO "$0" 0 "BOOTING" "Bringing Up 'localhost' Network"
ifconfig lo up

#:] ### Factory Reset Detection
#:] If we are in factory reset mode, run the reset routine and reboot immediately once done.
if [ "$FACTORY_RESET" -eq 1 ]; then
	LED_CONTROL_CHANGE

	/opt/muos/script/system/factory.sh
	/opt/muos/script/system/halt.sh reboot

	exit 0
fi

#:] ### Restore Internal Display Geometry
#:] Ensure both the internal screen and the mux frontend have the proper resolution.
LOG_INFO "$0" 0 "BOOTING" "Restoring Screen Mode"
for MODE in screen mux; do
	SET_VAR "device" "$MODE/width" "$WIDTH"
	SET_VAR "device" "$MODE/height" "$HEIGHT"
done &

#:] ### Network Compatibility Routine
#:] On certain devices we unload the network module if Module Compatibility is enabled and reload
#:] it again as we found that SDIO sometimes inhibits the network module on cold boots.
#:] This happens asynchronously (_in background_) by default, but may be blocking to user's choice.
if [ "$NET_COMPAT" -eq 0 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Loading Network Module (background)"
	/opt/muos/script/device/network.sh load &
else
	LOG_INFO "$0" 0 "BOOTING" "Loading Network Module (foreground)"
	/opt/muos/script/device/network.sh load
	LOG_INFO "$0" 0 "BOOTING" "Executing Module Compatibility Handling"
	case "$BOARD_NAME" in
		rg*)
			if [ "$NET_ASYNC" -eq 1 ]; then
				LOG_INFO "$0" 0 "BOOTING" "Module Compatibility Routine (background)"
				/opt/muos/script/device/network.sh reload &
			else
				LOG_INFO "$0" 0 "BOOTING" "Module Compatibility Routine (foreground)"
				/opt/muos/script/device/network.sh reload
			fi
			;;
		*) ;;
	esac
fi

#:] ### Regular Boot Startup
#:] Kick off mount handling and update script removal.
#:] Then determine console mode (internal vs HDMI).
#:] Also check whether swap is required based on user preferences.
LOG_INFO "$0" 0 "BOOTING" "Loading Storage Mounts"
/opt/muos/script/mount/start.sh &

LOG_INFO "$0" 0 "BOOTING" "Removing Existing Update Scripts"
rm -rf /opt/update.sh

echo 1 >/tmp/work_led_state
: >/tmp/net_start

LOG_INFO "$0" 0 "BOOTING" "Detecting Console Mode"
CONSOLE_MODE=0
if [ "$BOARD_HDMI" -eq 1 ]; then
	HDMI_VALUE=0

	[ -n "$HDMI_PATH" ] && [ -f "$HDMI_PATH" ] && HDMI_VALUE=$(cat "$HDMI_PATH")

	case "$HDMI_VALUE" in
		1) CONSOLE_MODE=1 ;;                # HDMI is active = external
		*[!0-9]* | 0 | *) CONSOLE_MODE=0 ;; # Non-numeric, 0, or fallback = internal
	esac
fi
SET_VAR "config" "boot/device_mode" "$CONSOLE_MODE"

LOG_INFO "$0" 0 "BOOTING" "Checking Swap Requirements"
/opt/muos/script/system/swap.sh &

#:] ### Permissions sanity pass (background)
#:] Ensure ownership and perms are sane on key trees.
#:] Typically for SSH. This is needed specifically for the H700
#:] kernel because the kernel reverts back to 1000:1000 as the UID:GID
#:] for whatever reason.
LOG_INFO "$0" 0 "BOOTING" "Correcting Permissions"
(
	chown -R root:root /root /opt/openssh /opt/sftpgo
	chmod -R 755 /root /opt/openssh /opt/sftpgo
) &

#:] ### Device Specific Startup
#:] Board/variant hooks to finalise hardware setup.
LOG_INFO "$0" 0 "BOOTING" "Device Specific Startup"
/opt/muos/script/device/start.sh &

#:] ### Storage Mount Wait
#:] Block until union mounts are ready so later steps can rely on them.
LOG_INFO "$0" 0 "BOOTING" "Waiting for Storage Mounts"
until [ -f "$MUOS_STORE_DIR/mounted" ]; do TBOX sleep 0.01; done

#:] ### Safety Script (_optional_)
#:] If a supplied `oops.sh` exists on ROM storage, run it now!
LOG_INFO "$0" 0 "BOOTING" "Checking for Safety Script"
OOPS="$ROM_MOUNT/oops.sh"
if [ -x "$OOPS" ]; then
	"$OOPS"
	rm -f "$OOPS"
fi

#:] ### Unionise Content Directories
#:] Build the content view (_overlay/union_) across storage devices.
LOG_INFO "$0" 0 "BOOTING" "Unionising ROMS on Storage Mounts"
/opt/muos/script/mount/union.sh start &

#:] ### Detect Charging Mode (_handheld mode only_)
#:] On internal display mode, detect charger state and adjust LEDs accordingly.
if [ "$CONSOLE_MODE" -eq 0 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Detecting Charge Mode"
	/opt/muos/script/device/charge.sh
	LED_CONTROL_CHANGE
fi

#:] ### Network Runner (_background_)
#:] Auto-connect to network when configured (_if capability present_).
LOG_INFO "$0" 0 "BOOTING" "Connecting Network on Boot if requested and possible"
if [ "$HAS_NETWORK" -eq 1 ]; then
	[ "$CONNECT_ON_BOOT" -eq 1 ] && /opt/muos/script/system/network.sh connect &
fi

#:] ### Hotkey Daemon
#:] Start the input listener that powers global hotkeys.
LOG_INFO "$0" 0 "BOOTING" "Starting Hotkey Daemon"
HOTKEY start

#:] ### Start muX frontend
#:] Launch the UI after all core services are prepared.
LOG_INFO "$0" 0 "BOOTING" "Starting muX Frontend"
FRONTEND start

#:] ### System sounds (_background_)
#:] Preload short UI sounds so they're instant when invoked.
(
	LOG_INFO "$0" 0 "BOOTING" "Preparing System Sounds"
	PREP_SOUND reboot
	PREP_SOUND shutdown
) &

#:] ### User Init Scripts (_optional_)
#:] Allow users to run custom boot hooks.
#:] This can be enabled within the **Advanced Settings** menu.
if [ "$USER_INIT" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Starting User Initialisation Scripts"
	/opt/muos/script/system/user_init.sh &
fi

#:] ### Low Power Indicator
#:] Start battery monitoring/alerts.
LOG_INFO "$0" 0 "BOOTING" "Starting Low Power Indicator"
/opt/muos/script/system/lowpower.sh &

#:] ### USB Gadget
#:] Bring up the configured USB function (adb _or_ mtp) unless disabled.
LOG_INFO "$0" 0 "BOOTING" "Starting USB Function"
[ "$USB_FUNCTION" != "none" ] && /opt/muos/script/system/usb_gadget.sh start &

#:] ### Device Controls
#:] Apply device-specific control defaults for RetroArch, emulators, ports etc.
LOG_INFO "$0" 0 "BOOTING" "Setting Device Controls"
/opt/muos/script/device/control.sh &

#:] ### SDL Controller Maps
#:] Set default `/usr/lib/gamecontrollerdb.txt` symlink to user defined controller.
#:] Which can be either `modern` or `retro`.
LOG_INFO "$0" 0 "BOOTING" "Setting up SDL Controller Map"
/opt/muos/script/mux/sdl_map.sh &

#:] ### Catalogue Generator
#:] Generate, and refresh, catalogue directories in the background.
#:] This is based on `catalogue` entries within the `global.ini` assign files.
LOG_INFO "$0" 0 "BOOTING" "Running Catalogue Generator"
/opt/muos/script/system/catalogue.sh &

#:] ### Pre-cache RetroArch assets
#:] Touch common files into the page cache to speed up first launches.
LOG_INFO "$0" 0 "BOOTING" "Precaching RetroArch System"
ionice -c idle /opt/muos/bin/vmtouch -tfb "$MUOS_SHARE_DIR/conf/preload.txt" &

#:] ### Save kernel boot log
#:] Persist `dmesg` for later diagnostics.
LOG_INFO "$0" 0 "BOOTING" "Saving Kernel Boot Log"
dmesg >"$ROM_MOUNT/MUOS/log/dmesg/dmesg__$(date +"%Y_%m_%d__%H_%M_%S").log" &
