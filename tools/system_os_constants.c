/* SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1 */

#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

/* Encode values as symbol sizes for the host generator. The extra byte
 * permits zero values. This object is never linked into the firmware. */
#define CONSTANT(name, value) const unsigned char gnat_system_os_constants_##name[(value) + 1] = {0}

CONSTANT(configMAX_PRIORITIES, configMAX_PRIORITIES);
CONSTANT(configTICK_RATE_HZ, configTICK_RATE_HZ);
CONSTANT(portMUX_TYPE_Size, sizeof(portMUX_TYPE));
CONSTANT(portMUX_TYPE_Alignment, _Alignof(portMUX_TYPE));
CONSTANT(StaticTask_t_Size, sizeof(StaticTask_t));
CONSTANT(StaticTask_t_Alignment, _Alignof(StaticTask_t));
CONSTANT(StaticSemaphore_t_Size, sizeof(StaticSemaphore_t));
CONSTANT(StaticSemaphore_t_Alignment, _Alignof(StaticSemaphore_t));
CONSTANT(ATCB_Slot, CONFIG_GNAT_RUNTIME_ATCB_TLS_SLOT);
