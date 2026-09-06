#!/bin/sh

PS1='[\w]\$ '
export LANG=UTF-8

. /opt/muos/script/var/func.sh

printf "\033[1mWelcome to MustardOS %s\033[0m\n" "$(cat /opt/muos/config/system/version | head -n1 | tr '_' ' ')"
/opt/muos/bin/fastfetch -c /opt/muos/bin/fastfetch.cfg

CMD="\033[1;33m"
DESC="\033[0;33m"
RESET="\033[0m"

printf "${CMD}MUXCTL${DESC}   [stop | start]\tAll services below${RESET}\n"
printf "${CMD}FRONTEND${DESC} [stop | start]\tFrontend services${RESET}\n"
printf "${CMD}HOTKEY${DESC}   [stop | start]\tHotkey services${RESET}\n"
printf "${CMD}BATTERY${DESC}  [stop | start]\tBattery services${RESET}\n"
printf "${DESC}----------------${RESET}\n"
printf "${CMD}CAFFEINE${DESC} [on | off] Toggle sleep functionality${RESET}\n\n"

if IS_MUTERM; then
    printf "\033[0;33mPress Start/Enter to continue...\033[0m"
    IFS= read -r _

    reset
fi
