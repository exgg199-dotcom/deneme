#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

static char g_engine_common[1024] = {0};

static void __attribute__((constructor)) nx_init(void) {
    CFBundleRef bundle = CFBundleGetMainBundle();
    if (!bundle) return;
    CFURLRef url = CFBundleCopyBundleURL(bundle);
    if (!url) return;
    char base[900] = {0};
    CFURLGetFileSystemRepresentation(url, true, (UInt8 *)base, sizeof(base) - 1);
    CFRelease(url);
    snprintf(g_engine_common, sizeof(g_engine_common), "%s/Engine/Common", base);
}

static const char *redirect_read(const char *path) {
    if (!path || !g_engine_common[0]) return path;
    if (!strstr(path, "Engine/Common/")) return path;
    const char *filename = strrchr(path, '/');
    if (!filename) return path;
    filename++;
    static __thread char buf[1024];
    snprintf(buf, sizeof(buf), "%s/%s", g_engine_common, filename);
    int fd = open(buf, O_RDONLY);
    if (fd >= 0) {
        close(fd);
        return buf;
    }
    return path;
}

static FILE *nx_fopen(const char *path, const char *mode) {
    if (mode && mode[0] == 'r') {
        return fopen(redirect_read(path), mode);
    }
    return fopen(path, mode);
}

static int nx_open(const char *path, int flags, ...) {
    if ((flags & O_ACCMODE) == O_RDONLY) {
        return open(redirect_read(path), flags);
    }
    return open(path, flags);
}

typedef struct { void *new_fn; void *orig_fn; } interpose_t;

__attribute__((used))
static const interpose_t nx_interposers[]
    __attribute__((section("__DATA,__interpose"))) = {
    { (void *)nx_fopen, (void *)fopen },
    { (void *)nx_open,  (void *)open  },
};
