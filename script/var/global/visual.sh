#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - VISUAL OPTIONS
: "${GC_VIS_BATTERY:=1}"
: "${GC_VIS_NETWORK:=0}"
: "${GC_VIS_BLUETOOTH:=0}"
: "${GC_VIS_CLOCK:=1}"
: "${GC_VIS_BOXART:=1}"
: "${GC_VIS_NAME:=0}"
: "${GC_VIS_DASH:=0}"
export GC_VIS_BATTERY=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "battery")
export GC_VIS_NETWORK=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "network")
export GC_VIS_BLUETOOTH=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "bluetooth")
export GC_VIS_CLOCK=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "clock")
export GC_VIS_BOXART=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "boxart")
export GC_VIS_NAME=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "name")
export GC_VIS_DASH=$(PARSE_INI "$GLOBAL_CONFIG" "visual" "dash")

