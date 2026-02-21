#ifndef BOX64_COMPAT_DLFCN_H
#define BOX64_COMPAT_DLFCN_H

#include_next <dlfcn.h>

#if defined(__APPLE__)
#include <errno.h>

#ifndef RTLD_NEXT
#define RTLD_NEXT ((void*)-1L)
#endif
#ifndef RTLD_DEFAULT
#define RTLD_DEFAULT ((void*)0)
#endif
#ifndef RTLD_DL_SYMENT
#define RTLD_DL_SYMENT 1
#endif
#ifndef RTLD_DL_LINKMAP
#define RTLD_DL_LINKMAP 2
#endif

#ifndef __BOX64_DLVSYM_DEFINED
#define __BOX64_DLVSYM_DEFINED 1
static inline void* dlvsym(void* handle, const char* symbol, const char* version)
{
    (void)version;
    return dlsym(handle, symbol);
}
#endif
#endif

#endif
