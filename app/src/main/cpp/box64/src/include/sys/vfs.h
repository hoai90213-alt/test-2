#ifndef BOX64_COMPAT_SYS_VFS_H
#define BOX64_COMPAT_SYS_VFS_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/vfs.h>
#else
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/mount.h>

struct statfs64 {
    uint32_t f_type;
    uint32_t f_bsize;
    uint64_t f_blocks;
    uint64_t f_bfree;
    uint64_t f_bavail;
    uint64_t f_files;
    uint64_t f_ffree;
    struct {
        int __val[2];
    } f_fsid;
    uint32_t f_namelen;
    uint32_t f_frsize;
    uint32_t f_flags;
    uint32_t f_spare[4];
};

static inline int statfs64(const char* path, struct statfs64* buf)
{
    (void)path;
    if (buf) memset(buf, 0, sizeof(*buf));
    errno = ENOSYS;
    return -1;
}

static inline int fstatfs64(int fd, struct statfs64* buf)
{
    (void)fd;
    if (buf) memset(buf, 0, sizeof(*buf));
    errno = ENOSYS;
    return -1;
}
#endif

#endif
