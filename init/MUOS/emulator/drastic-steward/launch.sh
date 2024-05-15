#!/bin/sh
CUST_LOGO=0
CUST_CPUCLOCK=1
USE_752x560_RES=0

mydir=`dirname "$0"`


export LD_LIBRARY_PATH=$mydir/libs:$LD_LIBRARY_PATH
export SDL_VIDEODRIVER=mmiyoo
export SDL_AUDIODRIVER=mmiyoo
export EGL_VIDEODRIVER=mmiyoo


cd $mydir

./drastic "$1"

