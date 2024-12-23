#!/bin/sh

"$EVSIEVE_DIR/$EVSIEVE_BIN" \
--input /dev/input/event1 grab \
--hook btn:start toggle \
--toggle "" @analog @dpad \
--map yield abs:hat0x:-1@analog      abs:x:-4096 \
--map yield abs:hat0x:-1..0~@analog  abs:x:0 \
--map yield abs:hat0x:1@analog       abs:x:4096 \
--map yield abs:hat0x:1..~0@analog   abs:x:0 \
--map yield abs:hat0y:1@analog       abs:y:4096 \
--map yield abs:hat0y:1..~0@analog   abs:y:0 \
--map yield abs:hat0y:-1@analog      abs:y:-4096 \
--map yield abs:hat0y:-1..0~@analog  abs:y:0  \
--map yield abs:hat0x:-1@dpad        abs:rx:-4096 \
--map yield abs:hat0x:-1..0~@dpad    abs:rx:0 \
--map yield abs:hat0x:1@dpad         abs:rx:4096 \
--map yield abs:hat0x:1..~0@dpad     abs:rx:0 \
--map yield abs:hat0y:1@dpad         abs:ry:4096 \
--map yield abs:hat0y:1..~0@dpad     abs:ry:0 \
--map yield abs:hat0y:-1@dpad        abs:ry:-4096 \
--map yield abs:hat0y:-1..0~@dpad    abs:ry:0 \
`# L1 Button ` \
--map yield btn:west          btn:east \
`# R1 Button ` \
--map yield btn:z             btn:c \
`# Start Button ` \
--map yield btn:tr            btn:west \
`# Select Button ` \
--map yield btn:tl            btn:north \
`# X Button ` \
--map yield btn:north         key:volumeup \
`# Y Button ` \
--map yield btn:c             btn:south \
`# B Button ` \
--map yield btn:east          key:volumedown \
`# A Button` \
--map yield btn:south         key:esc \
--output name=scummvm & 
