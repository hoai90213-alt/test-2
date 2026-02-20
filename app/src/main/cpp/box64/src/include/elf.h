#ifndef ZOMDROID_BOX64_ELF_WRAPPER_H
#define ZOMDROID_BOX64_ELF_WRAPPER_H

#if defined(__APPLE__) && !defined(__ANDROID__)
#include "elf_apple_compat.h"
#else
#include_next <elf.h>
#endif

#endif
