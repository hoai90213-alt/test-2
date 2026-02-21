#ifndef BOX64_COMPAT_SYS_PTRACE_H
#define BOX64_COMPAT_SYS_PTRACE_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/ptrace.h>
#else
#include <errno.h>
#include <sys/types.h>

#ifndef PTRACE_TRACEME
#define PTRACE_TRACEME 0
#endif

static inline long ptrace(int request, pid_t pid, void* addr, void* data)
{
    (void)request;
    (void)pid;
    (void)addr;
    (void)data;
    errno = ENOSYS;
    return -1;
}
#endif

#endif
