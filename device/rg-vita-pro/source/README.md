## Vita Pro scanout reservation helper

`vita_scanout_reserve.c` holds a 16 MiB DRM dumb buffer before muX starts.
Rockchip's best-fit IOVA allocator places it at address zero, preventing SDL's
real scanout buffers from using the VOP's broken zero-address path.

It deliberately uses only the stable DRM UAPI and libc, with no libdrm runtime
dependency. Build it using the same AArch64 Bootlin toolchain as the image:

```sh
aarch64-linux-gcc -O2 -Wall -Wextra -Werror \
  -o ../bin/vita-scanout-reserve vita_scanout_reserve.c
```
