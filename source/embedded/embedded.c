/* ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
 * SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */
#include <stdint.h>
#include <sys/time.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

/* Keep in sync with System.OS_Constants for this ESP32-S3 configuration. */
_Static_assert(CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS == 2,
               "ATCB uses TLS slot 1; configure exactly 2 slots for this ABI");
_Static_assert(tskNO_AFFINITY == 0x7FFFFFFF,
               "tskNO_AFFINITY differs from System.OS_Interface");
_Static_assert(configTICK_RATE_HZ == 100,
               "configTICK_RATE_HZ differs from System.OS_Constants");
_Static_assert(configMAX_PRIORITIES == 25,
               "configMAX_PRIORITIES differs from System.OS_Constants");

_Static_assert(sizeof(portMUX_TYPE) == 8 && _Alignof(portMUX_TYPE) == 4,
               "portMUX_TYPE differs from System.OS_Constants");
_Static_assert(sizeof(StaticTask_t) == 348,
               "StaticTask_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticTask_t) == 4,
               "StaticTask_t alignment differs from System.OS_Constants");
_Static_assert(sizeof(StaticSemaphore_t) == 84,
               "StaticSemaphore_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticSemaphore_t) == 4,
               "StaticSemaphore_t alignment differs from System.OS_Constants");

void __gnat_portENTER_CRITICAL_SAFE(portMUX_TYPE *mux)
{
    portENTER_CRITICAL_SAFE(mux);
}

void __gnat_portEXIT_CRITICAL_SAFE(portMUX_TYPE *mux)
{
    portEXIT_CRITICAL_SAFE(mux);
}

void __gnat_portMUX_INITIALIZE(portMUX_TYPE *mux)
{
    portMUX_INITIALIZE(mux);
}

void __gnat_portYIELD_FROM_ISR(BaseType_t xHigherPriorityTaskWoken)
{
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

SemaphoreHandle_t __gnat_xSemaphoreCreateBinaryStatic(StaticSemaphore_t *storage)
{
    configASSERT(storage);
    configASSERT((uintptr_t)storage % _Alignof(StaticSemaphore_t) == 0);
    return xSemaphoreCreateBinaryStatic(storage);
}

SemaphoreHandle_t __gnat_xSemaphoreCreateMutexStatic(StaticSemaphore_t *storage)
{
    configASSERT(!xPortInIsrContext() && storage);
    return xSemaphoreCreateMutexStatic(storage);
}

SemaphoreHandle_t __gnat_xSemaphoreCreateRecursiveMutexStatic(StaticSemaphore_t *storage)
{
    configASSERT(!xPortInIsrContext() && storage);
    return xSemaphoreCreateRecursiveMutexStatic(storage);
}

UBaseType_t __gnat_uxSemaphoreGetCount(SemaphoreHandle_t semaphore)
{
    configASSERT(!xPortInIsrContext());
    return uxSemaphoreGetCount(semaphore);
}

BaseType_t __gnat_xSemaphoreGive(SemaphoreHandle_t cv)
{
    configASSERT(!xPortInIsrContext());
    return xSemaphoreGive(cv);
}

BaseType_t __gnat_xSemaphoreGiveFromISR(SemaphoreHandle_t xSemaphore, BaseType_t * const pxHigherPriorityTaskWoken)
{
    return xSemaphoreGiveFromISR(xSemaphore, pxHigherPriorityTaskWoken);
}

BaseType_t __gnat_xSemaphoreGiveRecursive(SemaphoreHandle_t mutex)
{
    configASSERT(!xPortInIsrContext() && mutex);
    return xSemaphoreGiveRecursive(mutex);
}

BaseType_t __gnat_xSemaphoreTake(SemaphoreHandle_t cv, TickType_t ticks)
{
    configASSERT(!xPortInIsrContext());
    return xSemaphoreTake(cv, ticks);
}

BaseType_t __gnat_xSemaphoreTakeRecursive(SemaphoreHandle_t mutex, TickType_t ticks)
{
    configASSERT(!xPortInIsrContext() && mutex);
    return xSemaphoreTakeRecursive(mutex, ticks);
}

/* Keep the SDK's timeval/time_t ABI at the C boundary. */
int64_t __gnat_calendar_clock_usec(void)
{
    struct timeval now;
    int result = gettimeofday(&now, NULL);
    configASSERT(result == 0);
    return (int64_t)now.tv_sec * 1000000 + now.tv_usec;
}

/* Macro/inline ABI bridges; storage and runtime policy are owned by Ada. */
BaseType_t __gnat_mux_try(portMUX_TYPE *mux)
{ return xPortEnterCriticalTimeout(mux, 0); }
BaseType_t __gnat_core_id(void) { return xPortGetCoreID(); }
/* SDK/ISA boundary. Nesting, unlike PS.INTLEVEL, stays stable in critical
 * sections. Levels 1..3 are the C-callable Xtensa ISR levels on ESP32-S3. */
extern unsigned port_interruptNesting[portNUM_PROCESSORS];
BaseType_t __gnat_interrupt_nesting(void)
{ return port_interruptNesting[xPortGetCoreID()]; }
BaseType_t __gnat_interrupt_level(void)
{
    unsigned ps;
    __asm__ volatile ("rsr.ps %0" : "=a" (ps));
    return ps & 0xf;
}
/* Private gthread bindings for the SDK's FDE registry object. Other pthread
 * mutexes retain their SDK implementation. All registry operations use this
 * critical section, including first-use cache initialization.
 */
static portMUX_TYPE unwind_mux = portMUX_INITIALIZER_UNLOCKED;
int __gnat_unwind_active(void) { return 0; } /* Address is the gthread probe. */
int __gnat_unwind_lock(void *unused)
{
    (void)unused;
    portENTER_CRITICAL_SAFE(&unwind_mux);
    return 0;
}
int __gnat_unwind_unlock(void *unused)
{
    (void)unused;
    portEXIT_CRITICAL_SAFE(&unwind_mux);
    return 0;
}
