#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - WEB SERVICES
: "${GC_WEB_SHELL:=1}"
: "${GC_WEB_BROWSER:=0}"
: "${GC_WEB_TERMINAL:=0}"
: "${GC_WEB_SYNCTHING:=0}"
: "${GC_WEB_NTP:=1}"
export GC_WEB_SHELL=$(PARSE_INI "$GLOBAL_CONFIG" "web" "shell")
export GC_WEB_BROWSER=$(PARSE_INI "$GLOBAL_CONFIG" "web" "browser")
export GC_WEB_TERMINAL=$(PARSE_INI "$GLOBAL_CONFIG" "web" "terminal")
export GC_WEB_SYNCTHING=$(PARSE_INI "$GLOBAL_CONFIG" "web" "syncthing")
export GC_WEB_NTP=$(PARSE_INI "$GLOBAL_CONFIG" "web" "ntp")

