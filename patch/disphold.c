#include <drm/drm_mipi_dsi.h>
#include <linux/device.h>
#include <linux/errno.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>

struct held_driver {
	struct device_driver *driver;
	void (*shutdown)(struct device *dev);
};

static struct held_driver held[3];

static int hold_platform_driver(const char *name, struct held_driver *slot)
{
	struct device_driver *driver;

	driver = driver_find(name, &platform_bus_type);
	if (!driver)
		return -ENODEV;
	if (!driver->shutdown)
		return -EALREADY;

	slot->driver = driver;
	slot->shutdown = driver->shutdown;
	WRITE_ONCE(driver->shutdown, NULL);
	return 0;
}

static int hold_panel_driver(struct held_driver *slot)
{
	struct device_node *node;
	struct mipi_dsi_device *dsi;
	struct device_driver *driver;

	node = of_find_compatible_node(NULL, NULL, "elida,kd35t133");
	if (!node)
		return -ENODEV;

	dsi = of_find_mipi_dsi_device_by_node(node);
	of_node_put(node);
	if (!dsi)
		return -EPROBE_DEFER;

	driver = dsi->dev.driver;
	if (!driver || !driver->shutdown) {
		put_device(&dsi->dev);
		return -ENODEV;
	}

	slot->driver = driver;
	slot->shutdown = driver->shutdown;
	WRITE_ONCE(driver->shutdown, NULL);
	put_device(&dsi->dev);
	return 0;
}

static void restore_drivers(void)
{
	int i;

	for (i = ARRAY_SIZE(held) - 1; i >= 0; --i) {
		if (!held[i].driver || !held[i].shutdown)
			continue;
		if (!READ_ONCE(held[i].driver->shutdown))
			WRITE_ONCE(held[i].driver->shutdown, held[i].shutdown);
		held[i].driver = NULL;
		held[i].shutdown = NULL;
	}
}

static int __init disphold_init(void)
{
	int ret;

	ret = hold_platform_driver("rockchip-drm", &held[0]);
	if (ret)
		return ret;

	ret = hold_platform_driver("pwm-backlight", &held[1]);
	if (ret)
		goto fail;

	ret = hold_panel_driver(&held[2]);
	if (ret)
		goto fail;

	return 0;

fail:
	restore_drivers();
	return ret;
}

static void __exit disphold_exit(void)
{
	restore_drivers();
}

module_init(disphold_init);
module_exit(disphold_exit);

MODULE_DESCRIPTION("G350 shutdown display hold");
MODULE_LICENSE("GPL");
