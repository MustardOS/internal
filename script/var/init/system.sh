#!/bin/sh

. /opt/muos/script/var/func.sh

GLOBAL_CONFIG="/opt/muos/config/config.ini"
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/dbus/system_bus_socket"
PIPEWIRE_RUNTIME_DIR="/var/run"
XDG_RUNTIME_DIR="/var/run"
DEVICE_TYPE=$(tr '[:upper:]' '[:lower:]' <"/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$(GET_VAR "device" "board/name")/config.ini"
DEVICE_CONTROL_DIR="/opt/muos/device/$(GET_VAR "device" "board/name")/control"
MUOS_BOOT_LOG="/opt/muos/boot.log"
ALSA_CONFIG="/usr/share/alsa/alsa.conf"
AUDIO_SRC="/tmp/mux_audio_src"

export GLOBAL_CONFIG DBUS_SESSION_BUS_ADDRESS PIPEWIRE_RUNTIME_DIR XDG_RUNTIME_DIR \
	DEVICE_TYPE DEVICE_CONFIG DEVICE_CONTROL_DIR MUOS_BOOT_LOG ALSA_CONFIG AUDIO_SRC

mkdir -p "/run/muos/system/foreground_process"
