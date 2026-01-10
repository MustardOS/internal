#!/bin/sh

. /opt/muos/script/var/func.sh

FORCE_COPY=0
[ "$1" = "FORCE_COPY" ] && FORCE_COPY=1

ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
RMP_LOG="$ROM_MOUNT/MUOS/log/psx.remap.log"
LOG_DATE="$(date +'[%Y-%m-%d]')"

REMAP_DIR="$MUOS_SHARE_DIR/info/config/remaps"

LOG_REMAP() {
	echo "$LOG_DATE $1" >>"$RMP_LOG"
}

WRITE_REMAP() {
	RMP_FILE="$1"
	RMP_NAME="$2"
	RMP_DATA="$3"

	mkdir -p "$(dirname "$RMP_FILE")"

	if [ "$FORCE_COPY" -eq 1 ] || [ ! -e "$RMP_FILE" ]; then
		printf '%s\n' "$RMP_DATA" >"$RMP_FILE"

		if [ "$FORCE_COPY" -eq 1 ]; then
			LOG_REMAP "File $RMP_FILE regenerated (FORCE_COPY). $RMP_NAME"
		else
			LOG_REMAP "File $RMP_FILE created. $RMP_NAME"
		fi
	else
		LOG_REMAP "No file created. Remap existed at $RMP_FILE"
	fi
}

WRITE_REMAP \
	"$REMAP_DIR/DuckStation/DuckStation.rmp" "DualShock Enabled for DuckStation" \
	'input_libretro_device_p1 = "5"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "1"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"'

WRITE_REMAP \
	"$REMAP_DIR/PCSX-ReARMed/PCSX-ReARMed.rmp" "DualShock Enabled for PCSX-ReARMed" \
	'input_libretro_device_p1 = "517"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "0"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"'

WRITE_REMAP \
	"$REMAP_DIR/SwanStation/SwanStation.rmp" "DualShock Enabled for SwanStation" \
	'input_libretro_device_p1 = "261"
input_libretro_device_p2 = "1"
input_libretro_device_p3 = "1"
input_libretro_device_p4 = "1"
input_player1_analog_dpad_mode = "0"
input_player2_analog_dpad_mode = "0"
input_player3_analog_dpad_mode = "0"
input_player4_analog_dpad_mode = "0"
input_remap_port_p1 = "0"
input_remap_port_p2 = "1"
input_remap_port_p3 = "2"
input_remap_port_p4 = "3"'
