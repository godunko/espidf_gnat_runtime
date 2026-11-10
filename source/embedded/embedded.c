/* ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
 * SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */
#include <stdint.h>
#include <stdatomic.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

/* Keep in sync with System.OS_Constants for this ESP32-S3 configuration. */
_Static_assert(tskNO_AFFINITY == 0x7FFFFFFF,
               "tskNO_AFFINITY differs from System.OS_Interface");
_Static_assert(configMAX_PRIORITIES == 25,
               "configMAX_PRIORITIES differs from System.OS_Constants");
_Static_assert(sizeof(StaticTask_t) == 340,
               "StaticTask_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticTask_t) == 4,
               "StaticTask_t alignment differs from System.OS_Constants");

_Static_assert(sizeof(StaticSemaphore_t) == 84,
               "StaticSemaphore_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticSemaphore_t) == 4,
               "StaticSemaphore_t alignment differs from System.OS_Constants");

#ifdef GNAT_EMBEDDED_TESTING
_Atomic unsigned __gnat_embedded_test_wakeups;
#endif

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
#ifdef GNAT_EMBEDDED_TESTING
    atomic_fetch_add(&__gnat_embedded_test_wakeups, 1);
#endif
    return xSemaphoreGive(cv);
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
