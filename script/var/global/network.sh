#!/bin/sh

# GLOBAL CONFIG - NETWORK
: "${GC_NET_ENABLED:=0}"
: "${GC_NET_TYPE:=1}"
: "${GC_NET_SSID:=0}"
: "${GC_NET_ADDRESS:=1}"
: "${GC_NET_GATEWAY:=0}"
: "${GC_NET_SUBNET:=1}"
: "${GC_NET_DNS:=0}"

GC_NET_ENABLED=$(PARSE_INI "$GLOBAL_CONFIG" "network" "enabled")
GC_NET_TYPE=$(PARSE_INI "$GLOBAL_CONFIG" "network" "type")
GC_NET_SSID=$(PARSE_INI "$GLOBAL_CONFIG" "network" "ssid")
GC_NET_ADDRESS=$(PARSE_INI "$GLOBAL_CONFIG" "network" "address")
GC_NET_GATEWAY=$(PARSE_INI "$GLOBAL_CONFIG" "network" "gateway")
GC_NET_SUBNET=$(PARSE_INI "$GLOBAL_CONFIG" "network" "subnet")
GC_NET_DNS=$(PARSE_INI "$GLOBAL_CONFIG" "network" "dns")

export GC_NET_ENABLED
export GC_NET_TYPE
export GC_NET_SSID
export GC_NET_ADDRESS
export GC_NET_GATEWAY
export GC_NET_SUBNET
export GC_NET_DNS
