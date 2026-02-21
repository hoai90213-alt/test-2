#ifndef BOX64_COMPAT_MALLOC_H
#define BOX64_COMPAT_MALLOC_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <malloc.h>
#else
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <malloc/malloc.h>

#ifndef malloc_usable_size
#define malloc_usable_size(P) malloc_size(P)
#endif

struct mallinfo {
    int arena;
    int ordblks;
    int smblks;
    int hblks;
    int hblkhd;
    int usmblks;
    int fsmblks;
    int uordblks;
    int fordblks;
    int keepcost;
};

static inline struct mallinfo mallinfo(void)
{
    struct mallinfo mi;
    memset(&mi, 0, sizeof(mi));
    return mi;
}

static inline int mallopt(int param, int value)
{
    (void)param;
    (void)value;
    return 0;
}

static inline int malloc_trim(size_t pad)
{
    (void)pad;
    return 0;
}

static inline void malloc_stats(void)
{
}

static inline int malloc_info(int options, FILE* stream)
{
    (void)options;
    (void)stream;
    errno = ENOSYS;
    return -1;
}

#if !defined(__APPLE__)
static inline void* memalign(size_t alignment, size_t size)
{
    void* ptr = NULL;
    if (posix_memalign(&ptr, alignment, size) != 0) {
        return NULL;
    }
    return ptr;
}
#endif
#endif

#endif
