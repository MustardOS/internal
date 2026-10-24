# GCS H36S kernel modules

Taken unchanged from the stock GC-H36S card, built for its kernel (4.9.191 #37, Wed Mar 19 14:22:15 UTC 2025).
The A133 rootfs carries modules built for the TrimUI kernel (#535), which do not include these two.

- `sunxi-backlight.ko` drives the panel backlight. It is loaded after `dc_sunxi`, matching the stock boot order.
- `8723ds.ko` is the RTL8723DS Wi-Fi driver, loaded by the network service when network support is enabled.

If the GCS H36S kernel is ever replaced, these must be rebuilt for the new kernel.

## PowerVR 1.11

The stock kernel's GPU driver is PowerVR release 1.11, while the A133 rootfs carries release 1.19. `pvrsrvkm.ko` and
`dc_sunxi.ko` here are the stock 1.11 modules, and `../gpu` holds the matching firmware and user libraries from the
stock card. `script/device/module.sh` bind mounts those over the rootfs copies and loads these modules, replacing the
rootfs `pvrsrvkm` if udev loaded it first.
