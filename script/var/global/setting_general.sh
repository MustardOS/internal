#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - SETTINGS - GENERAL
: "${GC_GEN_HIDDEN:=0}"
: "${GC_GEN_BGM:=0}"
: "${GC_GEN_SOUND:=0}"
: "${GC_GEN_STARTUP:=launcher}"
: "${GC_GEN_POWER:=0}"
: "${GC_GEN_LOW_BATTERY:=0}"
: "${GC_GEN_COLOUR:=9}"
: "${GC_GEN_HDMI:=-1}"
: "${GC_GEN_SHUTDOWN:=300}"
export GC_GEN_HIDDEN=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "hidden")
export GC_GEN_BGM=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "bgm")
export GC_GEN_SOUND=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "sound")
export GC_GEN_STARTUP=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "startup")
export GC_GEN_POWER=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "power")
export GC_GEN_LOW_BATTERY=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "low_battery")
export GC_GEN_COLOUR=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "colour")
export GC_GEN_HDMI=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "hdmi")
export GC_GEN_SHUTDOWN=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "shutdown")

