#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

/*
 * Keep this helper independent of libdrm: the raw structures and ioctl
 * numbers below are the stable Linux DRM UAPI used by CREATE_DUMB.
 */
#define DRM_IOCTL_BASE 'd'
#define DRM_IOWR(nr, type) _IOWR(DRM_IOCTL_BASE, nr, type)

struct drm_mode_create_dumb {
	uint32_t height;
	uint32_t width;
	uint32_t bpp;
	uint32_t flags;
	uint32_t handle;
	uint32_t pitch;
	uint64_t size;
};

struct drm_mode_map_dumb {
	uint32_t handle;
	uint32_t pad;
	uint64_t offset;
};

struct drm_mode_destroy_dumb {
	uint32_t handle;
};

#define DRM_IOCTL_DROP_MASTER _IO(DRM_IOCTL_BASE, 0x1f)
#define DRM_IOCTL_MODE_CREATE_DUMB DRM_IOWR(0xB2, struct drm_mode_create_dumb)
#define DRM_IOCTL_MODE_MAP_DUMB DRM_IOWR(0xB3, struct drm_mode_map_dumb)
#define DRM_IOCTL_MODE_DESTROY_DUMB DRM_IOWR(0xB4, struct drm_mode_destroy_dumb)

static volatile sig_atomic_t stopping;

static void stop_handler(int signal_number)
{
	(void)signal_number;
	stopping = 1;
}

int main(int argc, char **argv)
{
	const char *card = argc > 1 ? argv[1] : "/dev/dri/card0";
	struct drm_mode_create_dumb create = {
		/*
		 * Rockchip uses a best-fit IOVA allocator. This must be larger
		 * than the approximately 9 MiB high-address gap so the object
		 * is forced into the aperture beginning at address zero.
		 */
		.height = 2048,
		.width = 2048,
		.bpp = 32,
	};
	struct drm_mode_map_dumb map = { 0 };
	struct drm_mode_destroy_dumb destroy;
	struct sigaction action = {
		.sa_handler = stop_handler,
	};
	int fd;

	fd = open(card, O_RDWR | O_CLOEXEC);
	if (fd < 0) {
		fprintf(stderr, "vita-scanout-reserve: open %s: %s\n",
			card, strerror(errno));
		return EXIT_FAILURE;
	}

	/*
	 * The first client to open the card becomes DRM master. On a factory
	 * boot this helper runs before muwarn, so keeping master would lock SDL
	 * out of mode setting for as long as the helper lives.
	 */
	if (ioctl(fd, DRM_IOCTL_DROP_MASTER, 0) < 0 && errno != EINVAL)
		fprintf(stderr, "vita-scanout-reserve: drop master: %s\n",
			strerror(errno));

	if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &create) < 0) {
		fprintf(stderr, "vita-scanout-reserve: create dumb buffer: %s\n",
			strerror(errno));
		close(fd);
		return EXIT_FAILURE;
	}

	/*
	 * Before the first userspace commit the VOP can still be scanning from
	 * address zero, which is where this buffer lands. Rockchip does not
	 * clear new buffers, so blank it rather than show stale memory.
	 */
	map.handle = create.handle;
	if (ioctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &map) == 0) {
		void *pixels = mmap(NULL, create.size, PROT_READ | PROT_WRITE,
				    MAP_SHARED, fd, (off_t)map.offset);
		if (pixels != MAP_FAILED) {
			memset(pixels, 0, create.size);
			munmap(pixels, create.size);
		} else {
			fprintf(stderr, "vita-scanout-reserve: map buffer: %s\n",
				strerror(errno));
		}
	} else {
		fprintf(stderr, "vita-scanout-reserve: map dumb buffer: %s\n",
			strerror(errno));
	}

	fprintf(stderr,
		"vita-scanout-reserve: holding handle %u, pitch %u, size %llu on %s\n",
		create.handle, create.pitch, (unsigned long long)create.size, card);

	sigemptyset(&action.sa_mask);
	sigaction(SIGTERM, &action, NULL);
	sigaction(SIGINT, &action, NULL);
	sigaction(SIGHUP, &action, NULL);
	while (!stopping)
		pause();

	destroy.handle = create.handle;
	if (ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &destroy) < 0)
		fprintf(stderr, "vita-scanout-reserve: destroy dumb buffer: %s\n",
			strerror(errno));
	close(fd);
	return EXIT_SUCCESS;
}

