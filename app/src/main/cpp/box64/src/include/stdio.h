#ifndef BOX64_COMPAT_STDIO_H
#define BOX64_COMPAT_STDIO_H

#include_next <stdio.h>

#if defined(__APPLE__)
#include <stdarg.h>
#include <stdlib.h>

#ifndef fseeko64
#define fseeko64 fseeko
#endif
#ifndef ftello64
#define ftello64 ftello
#endif

static inline int box64_vasprintf(char** strp, const char* fmt, va_list ap)
{
    va_list ap_copy;
    int len;
    char* buf;

    va_copy(ap_copy, ap);
    len = vsnprintf(NULL, 0, fmt, ap_copy);
    va_end(ap_copy);
    if (len < 0) {
        if (strp) {
            *strp = NULL;
        }
        return -1;
    }

    buf = (char*)malloc((size_t)len + 1);
    if (!buf) {
        if (strp) {
            *strp = NULL;
        }
        return -1;
    }

    va_copy(ap_copy, ap);
    len = vsnprintf(buf, (size_t)len + 1, fmt, ap_copy);
    va_end(ap_copy);
    if (len < 0) {
        free(buf);
        if (strp) {
            *strp = NULL;
        }
        return -1;
    }

    if (strp) {
        *strp = buf;
    } else {
        free(buf);
    }
    return len;
}

static inline int box64_asprintf(char** strp, const char* fmt, ...)
{
    va_list ap;
    int ret;
    va_start(ap, fmt);
    ret = box64_vasprintf(strp, fmt, ap);
    va_end(ap);
    return ret;
}

#ifndef vasprintf
#define vasprintf box64_vasprintf
#endif
#ifndef asprintf
#define asprintf box64_asprintf
#endif
#endif

#endif
