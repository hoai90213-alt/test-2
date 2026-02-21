#ifndef BOX64_COMPAT_DLFCN_H
#define BOX64_COMPAT_DLFCN_H

#include_next <dlfcn.h>

#if defined(__APPLE__)
#include <errno.h>

#ifndef RTLD_NEXT
#define RTLD_NEXT ((void*)-1L)
#endif

#ifndef __BOX64_DL_INFO_DEFINED
#define __BOX64_DL_INFO_DEFINED 1
typedef struct {
    const char* dli_fname;
    void* dli_fbase;
    const char* dli_sname;
    void* dli_saddr;
} Dl_info;
#endif

static inline int dladdr(const void* addr, Dl_info* info)
{
    (void)addr;
    if (info) {
        info->dli_fname = 0;
        info->dli_fbase = 0;
        info->dli_sname = 0;
        info->dli_saddr = 0;
    }
    errno = ENOSYS;
    return 0;
}

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
