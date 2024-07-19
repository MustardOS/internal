#!/bin/sh
export CUST_LOGO=0
export CUST_CPUCLOCK=1
export USE_752x560_RES=0

LDLIB="$(dirname "$0")/libs":"$LD_LIBRARY_PATH"

export LD_LIBRARY_PATH="$LDLIB"
export SDL_VIDEODRIVER=mmiyoo
export SDL_AUDIODRIVER=mmiyoo
export EGL_VIDEODRIVER=mmiyoo

./drastic "$1"

