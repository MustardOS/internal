#!/bin/sh

echo app > /tmp/act_go

echo "muxarchive" > /tmp/fg_proc

nice --20 /opt/muos/extra/muxarchive

