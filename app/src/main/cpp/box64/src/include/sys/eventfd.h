#ifndef BOX64_COMPAT_SYS_EVENTFD_H
#define BOX64_COMPAT_SYS_EVENTFD_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/eventfd.h>
#else
#include <errno.h>
#include <stdint.h>

typedef uint64_t eventfd_t;

#ifndef EFD_SEMAPHORE
#define EFD_SEMAPHORE 0x1
#endif

#ifndef EFD_CLOEXEC
#define EFD_CLOEXEC 0x00080000
#endif

#ifndef EFD_NONBLOCK
#define EFD_NONBLOCK 0x00000800
#endif

static inline int eventfd(unsigned int initval, int flags)
{
    (void)initval;
    (void)flags;
    errno = ENOSYS;
    return -1;
}
#endif

#endif
