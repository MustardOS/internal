#!/bin/sh

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

GC_GEN_HIDDEN=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "hidden")
GC_GEN_BGM=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "bgm")
GC_GEN_SOUND=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "sound")
GC_GEN_STARTUP=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "startup")
GC_GEN_POWER=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "power")
GC_GEN_LOW_BATTERY=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "low_battery")
GC_GEN_COLOUR=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "colour")
GC_GEN_HDMI=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "hdmi")
GC_GEN_SHUTDOWN=$(PARSE_INI "$GLOBAL_CONFIG" "settings.general" "shutdown")

export GC_GEN_HIDDEN
export GC_GEN_BGM
export GC_GEN_SOUND
export GC_GEN_STARTUP
export GC_GEN_POWER
export GC_GEN_LOW_BATTERY
export GC_GEN_COLOUR
export GC_GEN_HDMI
export GC_GEN_SHUTDOWN
