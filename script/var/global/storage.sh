#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh

STORAGE_MAP() {
	case "$1" in
		0) echo "$DC_STO_ROM_MOUNT" ;;
		1) echo "$DC_STO_SDCARD_MOUNT" ;;
		2) echo "$DC_STO_USB_MOUNT" ;;
		*) echo "$DC_STO_ROM_MOUNT" ;;
	esac
}

# GLOBAL CONFIG - STORAGE OPTIONS
: "${GC_STO_BIOS:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_CONFIG:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_CATALOGUE:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_FAV:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_MUSIC:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_SAVE:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_SCREENSHOT:=$DC_STO_ROM_MOUNT}"
: "${GC_STO_THEME:=$DC_STO_ROM_MOUNT}"

GC_STO_BIOS=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "bios")")
GC_STO_CONFIG=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "config")")
GC_STO_CATALOGUE=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "catalogue")")
GC_STO_FAV=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "fav")")
GC_STO_MUSIC=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "music")")
GC_STO_SAVE=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "save")")
GC_STO_SCREENSHOT=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "screenshot")")
GC_STO_THEME=$(STORAGE_MAP "$(PARSE_INI "$GLOBAL_CONFIG" "storage" "theme")")

export GC_STO_BIOS
export GC_STO_CONFIG
export GC_STO_CATALOGUE
export GC_STO_FAVE
export GC_STO_MUSIC
export GC_STO_SAVE
export GC_STO_SCREENSHOT
export GC_STO_THEME
