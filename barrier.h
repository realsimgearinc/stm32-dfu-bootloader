#ifndef BARRIER_H
#define BARRIER_H

#define DSB() __asm__("dsb")
#define DMB() __asm__("dmb")

#endif