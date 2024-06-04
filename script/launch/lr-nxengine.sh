#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")
SDL_ROTATE=$(parse_ini "$DEVICE_CONFIG" "sdl" "rotation")
SDL_BLITTER=$(parse_ini "$DEVICE_CONFIG" "sdl" "blitter_disabled")

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$SDL_SCALER"
export SDL_ROTATION="$SDL_ROTATE"
export SDL_BLITTER_DISABLED="$SDL_BLITTER"

echo "retroarch" > /tmp/fg_proc

MESSAGE() {
    _TITLE=$1
    _MESSAGE=$2
    _FORM=$(cat <<EOF
$_TITLE

$_MESSAGE
EOF
    )
    /opt/muos/extra/muxstart "$_FORM" && sleep "$3"
}

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')
DOUK="$ROMPATH/.Cave Story (En)/Doukutsu.exe"

LOGPATH="$STORE_ROM/MUOS/log/nxe.log"

if [ -e "$DOUK" ]; then
	retroarch -v -c "$STORE_ROM/MUOS/retroarch/retroarch.cfg" -L "$STORE_ROM/MUOS/core/$CORE" "$DOUK"
else
	CZ_NAME="Cave Story (En).zip"
	CAVE_URL="https://bot.libretro.com/assets/cores/Cave Story/$CZ_NAME"
	BIOS_FOLDER="$STORE_ROM/MUOS/bios/"

	if [ -e "$BIOS_FOLDER$CZ_NAME" ]; then
		echo "$CZ_NAME exists at $BIOS_FOLDER" >> "$LOGPATH"
	else
		echo "$CZ_NAME not found in $BIOS_FOLDER" >> "$LOGPATH"
		## Is this thing on(line)?
		check_internet() {
			echo "Pinging github.com" >> "$LOGPATH"
			ping -c 1 github.com > /dev/null 2>&1
			return $?
		}
		if check_internet; then
			echo "Downloading from $CAVE_URL" >> "$LOGPATH"
   			wget -O "$BIOS_FOLDER$CZ_NAME" "$CAVE_URL"
		else
    		# If local copy doesn't exist and cannot download a copy, pop message 
    		echo "Unable to download $CZ_NAME" >> "$LOGPATH"
			TITLE="Missing File"
			CONTENT="Cave Story (En).zip not found in /MUOS/bios
			Please see https://muos.dev for more information!"
    		MESSAGE "$TITLE" "$CONTENT" 5
		fi
	fi

	## Extract the zip
	echo "Extracting $CZ_NAME to $ROMPATH" >> "$LOGPATH"
	unzip -o "$BIOS_FOLDER$CZ_NAME" -d "$ROMPATH"

	if [ -e "$ROMPATH/Cave Story (En)" ]; then
		echo "Hiding folder" >> "$LOGPATH"
		mv "$ROMPATH/Cave Story (En)" "$ROMPATH/.Cave Story (En)"
	elif [ -e "$ROMPATH/.Cave Story (En)" ]; then
		echo "Already hidden" >> "$LOGPATH"
	else
		echo "Did extraction fail?" >> "$LOGPATH"
	fi

	retroarch -v -c "$STORE_ROM/MUOS/retroarch/retroarch.cfg" -L "$STORE_ROM/MUOS/core/$CORE" "$DOUK"
fi

