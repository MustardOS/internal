#!/bin/sh

export GLOBAL_CONFIG="/opt/muos/config/config.ini"

PARSE_INI() {
	# https://stackoverflow.com/a/40778047
	INI_FILE="$1"
	SECTION="$2"
	KEY="$3"
	sed -nr "/^\[$SECTION\]/ { :l /^$KEY[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "$INI_FILE"
}

# GLOBAL CONFIG - NETWORK
: "${GC_NET_ENABLED:=0}"
: "${GC_NET_TYPE:=1}"
: "${GC_NET_SSID:=0}"
: "${GC_NET_ADDRESS:=1}"
: "${GC_NET_GATEWAY:=0}"
: "${GC_NET_SUBNET:=1}"
: "${GC_NET_DNS:=0}"
export GC_NET_ENABLED=$(PARSE_INI "$GLOBAL_CONFIG" "network" "enabled")
export GC_NET_TYPE=$(PARSE_INI "$GLOBAL_CONFIG" "network" "type")
export GC_NET_SSID=$(PARSE_INI "$GLOBAL_CONFIG" "network" "ssid")
export GC_NET_ADDRESS=$(PARSE_INI "$GLOBAL_CONFIG" "network" "address")
export GC_NET_GATEWAY=$(PARSE_INI "$GLOBAL_CONFIG" "network" "gateway")
export GC_NET_SUBNET=$(PARSE_INI "$GLOBAL_CONFIG" "network" "subnet")
export GC_NET_DNS=$(PARSE_INI "$GLOBAL_CONFIG" "network" "dns")

