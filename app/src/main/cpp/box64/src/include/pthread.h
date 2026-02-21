#ifndef BOX64_COMPAT_PTHREAD_H
#define BOX64_COMPAT_PTHREAD_H

#include_next <pthread.h>

#if defined(__APPLE__)
#include <errno.h>

#ifndef PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP
#define PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP PTHREAD_MUTEX_INITIALIZER
#endif

#ifndef __BOX64_PTHREAD_UNWIND_BUF_T_DEFINED
#define __BOX64_PTHREAD_UNWIND_BUF_T_DEFINED 1
typedef struct {
    void* __data[8];
} __pthread_unwind_buf_t;
#endif

#ifndef __BOX64_PTHREAD_AFFINITY_NP_DEFINED
#define __BOX64_PTHREAD_AFFINITY_NP_DEFINED 1
static inline int pthread_attr_setaffinity_np(pthread_attr_t* attr, size_t cpusetsize, const void* cpuset)
{
    (void)attr;
    (void)cpusetsize;
    (void)cpuset;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_setaffinity_np(pthread_t thread, size_t cpusetsize, const void* cpuset)
{
    (void)thread;
    (void)cpusetsize;
    (void)cpuset;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_getaffinity_np(pthread_t thread, size_t cpusetsize, void* cpuset)
{
    (void)thread;
    (void)cpusetsize;
    (void)cpuset;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_getattr_np(pthread_t thread, pthread_attr_t* attr)
{
    (void)thread;
    (void)attr;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_getattr_default_np(pthread_attr_t* attr)
{
    (void)attr;
    errno = ENOSYS;
    return -1;
}
#endif
#endif

#endif
