#ifndef BOX64_COMPAT_SYS_STAT_H
#define BOX64_COMPAT_SYS_STAT_H

#include_next <sys/stat.h>

#if defined(__APPLE__)
#ifndef st_atim
#define st_atim st_atimespec
#endif
#ifndef st_mtim
#define st_mtim st_mtimespec
#endif
#ifndef st_ctim
#define st_ctim st_ctimespec
#endif
#endif

#endif
