#!/bin/sh

. /opt/muos/script/var/global/setting_general.sh

# Clear saved IP address and last played game. (See
# https://github.com/MustardOS/frontend/blob/main/muxlaunch/main.c.)
: >/opt/muos/config/address.txt
if [ "$GC_GEN_STARTUP" = resume ]; then
	: >/opt/muos/config/lastplay.txt
fi

/opt/muos/bin/fbpad /opt/muos/script/system/halt.sh poweroff
