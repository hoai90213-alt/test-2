#ifndef BOX64_COMPAT_SYS_VFS_H
#define BOX64_COMPAT_SYS_VFS_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/vfs.h>
#else
#include <sys/mount.h>

#ifndef statfs64
#define statfs64 statfs
#endif

#ifndef fstatfs64
#define fstatfs64 fstatfs
#endif
#endif

#endif
