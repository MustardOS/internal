#!/bin/sh

# Thanks acmeplus! :D
# Modified from: https://github.com/knulli-cfw/distribution/blob/knulli-main/
# 					board/batocera/allwinner/h700/rg35xx-plus/fsoverlay/etc/init.d/S50adb

. /opt/muos/script/var/func.sh

mount -t configfs none /sys/kernel/config
mkdir -p /sys/kernel/config/usb_gadget/g1

#USB 2.0
echo 0x0200 >/sys/kernel/config/usb_gadget/g1/bcdUSB

#Instantiate English strings
mkdir -p /sys/kernel/config/usb_gadget/g1/strings/0x409
echo 1 1 >/sys/kernel/config/usb_gadget/g1/os_desc/use

#Configure VID/PID/ProductName/Serial (replace with your vid/pid)
echo "0x1d6b" >/sys/kernel/config/usb_gadget/g1/idVendor
echo "0x0105" >/sys/kernel/config/usb_gadget/g1/idProduct
echo "0123456789" >/sys/kernel/config/usb_gadget/g1/strings/0x409/serialnumber
echo "muOS" >/sys/kernel/config/usb_gadget/g1/strings/0x409/manufacturer
GET_VAR "device" "board/name" >/sys/kernel/config/usb_gadget/g1/strings/0x409/product

#Create Function(s) Instance(s)
mkdir -p /sys/kernel/config/usb_gadget/g1/functions/ffs.adb
mkdir -p /sys/kernel/config/usb_gadget/g1/configs/b.1
mkdir -p /sys/kernel/config/usb_gadget/g1/configs/b.1/strings/0x409
echo "ffs.adb" >/sys/kernel/config/usb_gadget/g1/configs/b.1/strings/0x409/configuration

#Bind functions
ln -s /sys/kernel/config/usb_gadget/g1/functions/ffs.adb /sys/kernel/config/usb_gadget/g1/configs/b.1

mkdir -p /dev/usb-ffs
mkdir -p /dev/usb-ffs/adb
mount -t functionfs adb /dev/usb-ffs/adb

#Start adbd daemon
/usr/bin/adbd >/dev/null &

echo 0x1 >/sys/kernel/config/usb_gadget/g1/os_desc/b_vendor_code

sleep 2

#Attach created gadget device to the UDC driver
#UDC driver name obtained from "ls /sys/class/udc/"
echo 5100000.udc-controller >/sys/kernel/config/usb_gadget/g1/UDC
