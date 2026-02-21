#ifndef BOX64_COMPAT_BITS_TIMESPEC_H
#define BOX64_COMPAT_BITS_TIMESPEC_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <bits/timespec.h>
#else
#include <time.h>
#endif

#endif
