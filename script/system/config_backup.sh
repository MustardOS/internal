#!/bin/sh

. /opt/muos/script/var/func.sh

CONFIG="/opt/muos/config/config.ini"
BACKUP="/opt/muos/config/config.bak"

LOG_INFO "$0" 0 "BOOTING" "Config Backup Starting"
if [ -s $CONFIG ]; then
	CONFIG_MD5=$(md5sum "$CONFIG" | awk '{ print $1 }')

	cp -f "$CONFIG" "$BACKUP"

	BACKUP_MD5=$(md5sum "$BACKUP" | awk '{ print $1 }')

	if [ "$CONFIG_MD5" = "$BACKUP_MD5" ]; then
		LOG_SUCCESS "$0" 0 "BOOTING" "Config Backup Success"
	fi
else
	LOG_ERROR "$0" 0 "BOOTING" "Config Backup Failed"
fi
