#ifndef BOX64_COMPAT_SYS_MMAN_H
#define BOX64_COMPAT_SYS_MMAN_H

#include_next <sys/mman.h>

#if defined(__APPLE__)
#ifndef MAP_ANONYMOUS
#ifdef MAP_ANON
#define MAP_ANONYMOUS MAP_ANON
#else
#define MAP_ANONYMOUS 0x1000
#endif
#endif

#ifndef MAP_NORESERVE
#define MAP_NORESERVE 0
#endif

#ifndef MAP_GROWSDOWN
#define MAP_GROWSDOWN 0
#endif

#ifndef mmap64
#define mmap64 mmap
#endif
#endif

#endif
