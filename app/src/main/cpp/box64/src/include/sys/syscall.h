#ifndef BOX64_COMPAT_SYS_SYSCALL_H
#define BOX64_COMPAT_SYS_SYSCALL_H

#include_next <sys/syscall.h>

#if defined(__APPLE__)
#ifndef SYS_gettid
#ifdef SYS_GETTID
#define SYS_gettid SYS_GETTID
#else
#define SYS_gettid 186
#endif
#endif

#ifndef SYS_GETTID
#define SYS_GETTID SYS_gettid
#endif

#ifndef SYS_modify_ldt
#ifdef SYS_MODIFY_LDT
#define SYS_modify_ldt SYS_MODIFY_LDT
#else
#define SYS_modify_ldt 154
#endif
#endif

#ifndef __NR_gettid
#define __NR_gettid SYS_gettid
#endif

#ifndef __NR_modify_ldt
#define __NR_modify_ldt SYS_modify_ldt
#endif

long syscall(long number, ...);
#endif

#endif
