#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - CLOCK
: "${GC_CLK_NOTATION:=0}"
: "${GC_CLK_POOL:=0}"
export GC_CLK_NOTATION=$(PARSE_INI "$GLOBAL_CONFIG" "clock" "notation")
export GC_CLK_POOL=$(PARSE_INI "$GLOBAL_CONFIG" "clock" "pool")

