#!/bin/sh

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

GC_ADV_SWAP=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "swap")
GC_ADV_THERMAL=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "thermal")
GC_ADV_FONT=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "font")
GC_ADV_VERBOSE=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "verbose")
GC_ADV_VOLUME=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "volume")
GC_ADV_BRIGHTNESS=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "brightness")
GC_ADV_OFFSET=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "offset")
GC_ADV_LOCK=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "lock")
GC_ADV_LED=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "led")
GC_ADV_RANDOM_THEME=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "random_theme")
GC_ADV_RETROWAIT=$(PARSE_INI "$GLOBAL_CONFIG" "settings.advanced" "retrowait")

export GC_ADV_SWAP
export GC_ADV_THERMAL
export GC_ADV_FONT
export GC_ADV_VERBOSE
export GC_ADV_VOLUME
export GC_ADV_BRIGHTNESS
export GC_ADV_OFFSET
export GC_ADV_LOCK
export GC_ADV_LED
export GC_ADV_RANDOM_THEME
export GC_ADV_RETROWAIT
