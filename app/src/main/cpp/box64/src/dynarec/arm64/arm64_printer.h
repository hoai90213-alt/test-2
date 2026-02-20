#ifndef _ARM_PRINTER_H_
#define _ARM_PRINTER_H_

#include <stdint.h>
#include <stddef.h>

const char* arm64_print(uint32_t opcode, uintptr_t addr);

#endif //_ARM_PRINTER_H_
