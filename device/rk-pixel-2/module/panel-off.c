// SPDX-License-Identifier: GPL-2.0
/*
 * GKD Pixel 2: switch the display pipeline off while this module is loaded.
 *
 * Loading it runs drm_atomic_helper_suspend() on the Rockchip DRM device and
 * unloading it runs drm_atomic_helper_resume() with the state it returned.
 * That is the core of rockchip_drm_sys_suspend/resume: every CRTC is disabled
 * (VOP, DSI, panel off) and the saved state is restored on resume, including
 * the panel's init sequence.
 *
 * The state is kept here, not in mode_config.suspend_state. A kernel suspend
 * (mem) while loaded runs rockchip_drm_sys_suspend/resume, which overwrite
 * and then clear that slot, and the picture would not come back.
 *
 * muOS inserts it on sleep (frontend frozen) and removes it on wake. Only the
 * DRM master could do this from userspace, and no muOS binary has DPMS code.
 *
 * Panel-only attempts (unprepare, DCS sleep, init replay) go black but the
 * picture never returns without a modeset.
 *
 * Kernel layout used beyond struct module: struct device.driver_data (via
 * dev_get_drvdata), offset 120, validated against gpio_keys.ko for pwrkey.
 */
#include <linux/device.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <drm/drm_atomic_helper.h>

static struct device *dev;
static struct drm_device *drm;
static struct drm_atomic_state *state;

static int __init panel_off_init(void)
{
	struct device_node *np;
	int ret;

	np = of_find_compatible_node(NULL, NULL, "rockchip,display-subsystem");
	if (!np)
		return -ENODEV;

	dev = bus_find_device(&platform_bus_type, NULL, np, device_match_of_node);
	of_node_put(np);
	if (!dev)
		return -ENODEV;

	drm = dev_get_drvdata(dev);
	if (!drm) {
		put_device(dev);
		return -ENODEV;
	}

	state = drm_atomic_helper_suspend(drm);
	if (IS_ERR(state)) {
		ret = PTR_ERR(state);
		pr_err("panel-off: suspend returned %d\n", ret);
		put_device(dev);
		return ret;
	}

	return 0;
}

static void __exit panel_off_exit(void)
{
	int ret;

	ret = drm_atomic_helper_resume(drm, state);
	if (ret)
		pr_err("panel-off: resume returned %d\n", ret);

	put_device(dev);
}

module_init(panel_off_init);
module_exit(panel_off_exit);

MODULE_DESCRIPTION("GKD Pixel 2 display off while loaded");
MODULE_LICENSE("GPL");
