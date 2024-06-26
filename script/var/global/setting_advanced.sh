#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - SETTINGS - ADVANCED
: "${GC_ADV_SWAP:=0}"
: "${GC_ADV_THERMAL:=0}"
: "${GC_ADV_FONT:=1}"
: "${GC_ADV_VERBOSE:=0}"
: "${GC_ADV_VOLUME:=previous}"
: "${GC_ADV_BRIGHTNESS:=previous}"
: "${GC_ADV_OFFSET:=50}"
: "${GC_ADV_LOCK:=0}"
: "${GC_ADV_LED:=0}"
: "${GC_ADV_RANDOM_THEME:=0}"
: "${GC_ADV_RETROWAIT:=0}"
export GC_ADV_SWAP=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "swap")
export GC_ADV_THERMAL=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "thermal")
export GC_ADV_FONT=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "font")
export GC_ADV_VERBOSE=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "verbose")
export GC_ADV_VOLUME=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "volume")
export GC_ADV_BRIGHTNESS=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "brightness")
export GC_ADV_OFFSET=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "offset")
export GC_ADV_LOCK=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "lock")
export GC_ADV_LED=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "led")
export GC_ADV_RANDOM_THEME=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "random_theme")
export GC_ADV_RETROWAIT=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "retrowait")

