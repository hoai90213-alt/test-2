#ifndef BOX64_COMPAT_SYS_SIGNALFD_H
#define BOX64_COMPAT_SYS_SIGNALFD_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/signalfd.h>
#else
#include <errno.h>
#include <signal.h>
#include <stdint.h>

struct signalfd_siginfo {
    uint32_t ssi_signo;
    uint8_t _pad[124];
};

#ifndef SFD_CLOEXEC
#define SFD_CLOEXEC 0x00080000
#endif

#ifndef SFD_NONBLOCK
#define SFD_NONBLOCK 0x00000800
#endif

static inline int signalfd(int fd, const sigset_t* mask, int flags)
{
    (void)fd;
    (void)mask;
    (void)flags;
    errno = ENOSYS;
    return -1;
}
#endif

#endif
