#!/bin/sh

mydir=`dirname "$0"`


export LD_LIBRARY_PATH=$mydir/libs:$LD_LIBRARY_PATH
export SDL_VIDEODRIVER=mmiyoo
export EGL_VIDEODRIVER=mmiyoo


cd $mydir

./drastic "$1"

