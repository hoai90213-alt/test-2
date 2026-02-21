#ifndef BOX64_COMPAT_SYS_UCRED_H
#define BOX64_COMPAT_SYS_UCRED_H

#if defined(__linux__) && !defined(__APPLE__)
#include_next <sys/ucred.h>
#else
#define u_char unsigned char
#define u_short unsigned short
#define u_int unsigned int
#define u_long unsigned long
#include_next <sys/ucred.h>
#undef u_long
#undef u_int
#undef u_short
#undef u_char
#endif

#endif
