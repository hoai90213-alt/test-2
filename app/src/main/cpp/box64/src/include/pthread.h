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

static inline int pthread_setattr_default_np(const pthread_attr_t* attr)
{
    (void)attr;
    errno = ENOSYS;
    return -1;
}

#ifndef PTHREAD_MUTEX_STALLED
#define PTHREAD_MUTEX_STALLED 0
#endif
#ifndef PTHREAD_MUTEX_ROBUST
#define PTHREAD_MUTEX_ROBUST 1
#endif

static inline int pthread_mutexattr_getrobust(const pthread_mutexattr_t* attr, int* robust)
{
    (void)attr;
    if (robust) {
        *robust = PTHREAD_MUTEX_STALLED;
    }
    errno = ENOSYS;
    return -1;
}

static inline int pthread_mutexattr_setrobust(pthread_mutexattr_t* attr, int robust)
{
    (void)attr;
    (void)robust;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_condattr_getclock(const pthread_condattr_t* attr, clockid_t* clk_id)
{
    (void)attr;
    if (clk_id) {
        *clk_id = CLOCK_REALTIME;
    }
    errno = ENOSYS;
    return -1;
}

static inline int pthread_condattr_setclock(pthread_condattr_t* attr, clockid_t clk_id)
{
    (void)attr;
    (void)clk_id;
    errno = ENOSYS;
    return -1;
}

#ifndef PTHREAD_BARRIER_SERIAL_THREAD
#define PTHREAD_BARRIER_SERIAL_THREAD 1

typedef struct {
    int __opaque;
} pthread_barrier_t;

typedef struct {
    int __opaque;
} pthread_barrierattr_t;

static inline int pthread_barrierattr_init(pthread_barrierattr_t* attr)
{
    (void)attr;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_barrierattr_destroy(pthread_barrierattr_t* attr)
{
    (void)attr;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_barrierattr_getpshared(const pthread_barrierattr_t* attr, int* pshared)
{
    (void)attr;
    if (pshared) {
        *pshared = 0;
    }
    errno = ENOSYS;
    return -1;
}

static inline int pthread_barrierattr_setpshared(pthread_barrierattr_t* attr, int pshared)
{
    (void)attr;
    (void)pshared;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_barrier_init(pthread_barrier_t* barrier, const pthread_barrierattr_t* attr, unsigned count)
{
    (void)barrier;
    (void)attr;
    (void)count;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_barrier_destroy(pthread_barrier_t* barrier)
{
    (void)barrier;
    errno = ENOSYS;
    return -1;
}

static inline int pthread_barrier_wait(pthread_barrier_t* barrier)
{
    (void)barrier;
    errno = ENOSYS;
    return -1;
}
#endif
#endif
#endif

#endif
