#ifndef BOX64_COMPAT_SYS_PERSONALITY_H
#define BOX64_COMPAT_SYS_PERSONALITY_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/personality.h>
#else
#include <errno.h>

#ifndef ADDR_NO_RANDOMIZE
#define ADDR_NO_RANDOMIZE 0x0040000
#endif

#ifndef ADDR_LIMIT_32BIT
#define ADDR_LIMIT_32BIT 0x0800000
#endif

static inline int personality(unsigned long persona)
{
    (void)persona;
    errno = ENOSYS;
    return -1;
}
#endif

#endif
