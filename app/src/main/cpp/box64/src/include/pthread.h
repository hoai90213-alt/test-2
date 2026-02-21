#ifndef BOX64_COMPAT_PTHREAD_H
#define BOX64_COMPAT_PTHREAD_H

#include_next <pthread.h>

#if defined(__APPLE__)
#ifndef PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP
#define PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP PTHREAD_MUTEX_INITIALIZER
#endif

#ifndef __BOX64_PTHREAD_UNWIND_BUF_T_DEFINED
#define __BOX64_PTHREAD_UNWIND_BUF_T_DEFINED 1
typedef struct {
    void* __data[8];
} __pthread_unwind_buf_t;
#endif
#endif

#endif
