#ifndef BOX64_COMPAT_TIME_H
#define BOX64_COMPAT_TIME_H

#include_next <time.h>

#if defined(__APPLE__)
#ifndef CLOCK_MONOTONIC_COARSE
#ifdef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC_COARSE CLOCK_MONOTONIC
#elif defined(_CLOCK_MONOTONIC)
#define CLOCK_MONOTONIC_COARSE _CLOCK_MONOTONIC
#else
#define CLOCK_MONOTONIC_COARSE 6
#endif
#endif
#endif

#endif
