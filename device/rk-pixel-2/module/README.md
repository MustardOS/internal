# rk805-pwrkey.ko: GKD Pixel 2 power key driver (out-of-tree)

The Pixel 2 kernel (`package/Image`, 5.10.209, Rockchip BSP) was built without
`CONFIG_INPUT_RK805_PWRKEY`. The RK817 PMIC exposes the `rk805-pwrkey` device
but nothing binds to it, so the power button produces no input events.

This module is the unmodified mainline Linux 5.10.209
`drivers/input/misc/rk805-pwrkey.c`, compiled separately against a
reconstructed copy of the kernel's config. `script/device/module.sh` loads it
(inside the `rk*` case) at boot, in `S01init.sh`, and again on resume.
Never unload it on suspend: it is the wake source.

The stock muhotkey has no power event for this board (`board.c` `pwr_event =
nop`, and the event index changes between boots), so `module.sh` also starts
`script/device/pwrkey.sh`. It finds the key by name and sends `SLEEP_SHORT`
to the hotkey FIFO on release. It starts from `module.sh` rather than
`S05device.sh` because the async init pool runs three scripts at a time and
`S05device.sh` queues behind `S02network.sh`, which put the listener about
60 s into boot. Taps before the frontend is up (`progress_done`) are ignored.
`suspend.sh` gives the board `--power-device "rk805 pwrkey"` so the same key
wakes it.

Behaviour: tap = sleep and wake. A long hold is left to the RK817's own
long-press power cut (at or before 5 s), the same as the H700 boards. No
software hold-to-shutdown, because it cannot beat the PMIC. After a hardware
cut, RK817 OFF_SOURCE (reg 0xf6) reads 0x04; after a software shutdown, 0x80.

## If you rebuild or replace the Pixel 2 kernel, read this

The module only works with the exact kernel it was built for. `module.sh`
refuses to load it unless `uname -v` matches `PWRKEY_BUILD`, so a new kernel
will not crash, but the power button goes dead again until you do one of:

1. **Best:** build the new kernel with `CONFIG_INPUT_RK805_PWRKEY=y`, then
   delete this directory and the `rk-pixel-2` block in `module.sh`.
2. Rebuild this module against the new kernel (recipe below) and update
   `PWRKEY_BUILD` in `module.sh` to the new `uname -v`.

Also update `PWRKEY_BUILD` if the kernel is rebuilt from the same source with
the same version number, because `uname -v` changes with every build.

## How it was built

- Tree: https://github.com/rockchip-linux/kernel `develop-5.10`, with
  `SUBLEVEL` set to 209 so vermagic matches (`5.10.209 SMP mod_unload aarch64`).
- Config: `rockchip_linux_defconfig` + `ARM64_PTR_AUTH=y` + `DEBUG_SPINLOCK=y`,
  with `DEBUG_MUTEXES`, `JUMP_LABEL`, `MODVERSIONS` and `MODULE_SIG` off.
- Compiler: aarch64 gcc 13.3 (the kernel was built with Buildroot gcc 13.3).
- The driver **source** comes from mainline 5.10.209, not the Rockchip tree.
  The Rockchip variant reads `dev.parent->of_node`, whose offset differs in
  this kernel, and it oopses on load.

The real kernel config is not public, so it was reconstructed by matching
struct layouts against a module the kernel does ship (`gpio_keys.ko`):

| Check                           | Kernel | This build |
|---------------------------------|--------|------------|
| `sizeof(struct module)`         | 0x380  | 0x380      |
| `module.init` / `module.exit`   | 0x170 / 0x350 | 0x170 / 0x350 |
| `input_dev.dev`                 | 584    | 584        |
| `device.driver_data`            | 120    | 120        |

Every struct offset the module's code uses (`objdump -d`) is in that validated
set. **If you change the driver source, recheck this**, because other
`struct device` fields are known **not** to match.

## Tested (2606.0 4600add0)

10 reboots, 10 sleep/wake cycles, boot gate, guard (fake `uname -v`),
rmmod/insmod x3. No oops.

## panel-off.ko: GKD Pixel 2 screen off while asleep (out-of-tree)

On the Pixel 2 no backlight setting goes dark. Backlight level 0 maps to
17/255, and `bl_power`, `fb0` blank and every PWM duty tried all leave the
panel visibly lit. Only switching the display pipeline off does, and from
userspace that needs the DRM master (the frontend) to set DPMS.

This module does it from the kernel side, with no frontend change:

- `insmod` runs `drm_atomic_helper_suspend()` on the Rockchip DRM device and
  keeps the state it returns
- `rmmod` runs `drm_atomic_helper_resume()` with that state

This is the core of what `rockchip_drm_sys_suspend/resume` do on a real
system suspend. Every CRTC is disabled (VOP, DSI, panel power off) and the
saved state is restored on resume, which re-runs the panel init.

The state lives in the module, not in `mode_config.suspend_state`. If the
kernel suspends (`mem`) while the module is loaded, `rockchip_drm_sys_suspend`
and `_resume` overwrite and then clear that slot. Using the
`drm_mode_config_helper_*` pair instead left the screen off after a `mem`
wake (`WARN drm_modeset_helper.c:238`).

`script/system/suspend.sh` (`PIXEL2_DISPLAY`) loads it right after the
backlight goes to 0 in `SLEEP`, so the screen is black at the tap, and unloads
it as soon as `mususpend` returns. `muxfrontend`, `muxretro` and `retroarch`
are stopped while the module goes in or out, because a page flip against a
suspended pipeline fails. On the way down `mususpend --quiesce` then keeps
them stopped. Pickles has already acknowledged its save state by then.

### If you rebuild or replace the Pixel 2 kernel, read this

Same rule as `rk805-pwrkey.ko`: the module only matches the exact kernel it
was built for. `suspend.sh` skips it unless `uname -v` matches
`PANEL_OFF_BUILD`, so a new kernel falls back to the dim screen, it does not
crash. After a kernel change either rebuild this module (source in this
directory, same recipe as `rk805-pwrkey.ko`) and update `PANEL_OFF_BUILD`, or
drop it if the frontend gains DPMS off.

Kernel layout it depends on beyond `struct module`: `struct device.driver_data`
(through `dev_get_drvdata`), offset 120, checked against `gpio_keys.ko` from the
shipped kernel. Every other access is its own globals or a call to an exported
function (`objdump -d` shows only `[x0, #120]` into kernel structures).

### Why not just the panel

Panel-only versions were tried first: `drm_panel_disable/unprepare`, DCS
display-off + enter-sleep, and replaying the DT `panel-init-sequence` on wake.
All go black, and none brings the picture back, because this panel (an ST7701
by its init sequence) only shows the stream again after a modeset.

### Tested (2606.0 4600add0)

Menu and in game (Wipeout 2097, Pickles): black at the tap, clean wake,
a modeset on every wake, no oops. Guard (fake `uname -v`) falls back to
the dim sleep.
