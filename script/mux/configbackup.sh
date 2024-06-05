#!/bin/sh

CONFIG="/opt/muos/config/config.ini"
BACKUP="/opt/muos/config/config.bak"

LOGGER "BOOTING" "Config Backup Starting"
if [ -s $CONFIG ]; then
    CONFIG_MD5=$(md5sum "$CONFIG" | awk '{ print $1 }')

    cp -f "$CONFIG" "$BACKUP"

    BACKUP_MD5=$(md5sum "$BACKUP" | awk '{ print $1 }')

    if [ "$CONFIG_MD5" = "$BACKUP_MD5" ]; then
    LOGGER "BOOTING" "Config Backup Success"
    fi
    
else
    LOGGER "BOOTING" "Comfig Backup Failed"
fi