#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

# Define message block
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

LOGPATH="/mnt/mmc/MUOS/log/nxe.log"

if [ -e "$DOUK" ]; then
	/opt/muos/script/mux/track.sh "$NAME" retroarch -v -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/$CORE"\" \""$DOUK"\"
else
	CZ_NAME="Cave Story (En).zip"
	CAVE_URL="https://bot.libretro.com/assets/cores/Cave Story/$CZ_NAME"
	BIOS_FOLDER="/mnt/mmc/MUOS/bios/"

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
			Please see https://muos.dev for more information."
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
	/opt/muos/script/mux/track.sh "$NAME" retroarch -v -c \""/mnt/mmc/MUOS/retroarch/retroarch.cfg"\" -L \""/mnt/mmc/MUOS/core/$CORE"\" \""$DOUK"\"
fi
