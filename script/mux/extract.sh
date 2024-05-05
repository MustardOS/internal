#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <archive>"
    exit 1
fi

if [ ! -e "$1" ]; then
    echo "Error: Archive '$1' not found"
    exit 1
fi

pkill -STOP muxarchive

/opt/muos/extra/muxlog &
sleep 1

echo "Waiting..." > /tmp/muxlog_info
sleep 1

ARCHIVE_NAME="${1##*/}"

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

MUX_TEMP="/opt/muxtmp"
mkdir "$MUX_TEMP"

unzip -o "$1" -d "$MUX_TEMP/" > "$TMP_FILE" 2>&1 &

C_LINE=""
while true; do
    IS_WORKING=$(ps aux | grep '[u]nzip' | awk '{print $1}')

    if [ -s "$TMP_FILE" ]; then
        N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
        if [ "$N_LINE" != "$C_LINE" ]; then
            echo "$N_LINE"
            echo "$N_LINE" > /tmp/muxlog_info
            C_LINE="$N_LINE"
        fi
    fi

    if [ -z "$IS_WORKING" ]; then
        break
    fi
    
    sleep 0.25
done

echo "Copying Files" > /tmp/muxlog_info
cp -rf "$MUX_TEMP"/* /

echo "Correcting Permissions" > /tmp/muxlog_info
chmod -R 755 /opt/muos

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
    echo "Running Update Script" > /tmp/muxlog_info
    chmod 755 "$UPDATE_SCRIPT"
    ./"$UPDATE_SCRIPT"
    rm "$UPDATE_SCRIPT"
fi

echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
sleep 1

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxarchive
killall -q extract.sh

