/* ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
 * SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */
#include <stdint.h>
#include <stdatomic.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

/* Keep in sync with System.OS_Constants for this ESP32-S3 configuration. */
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

static SemaphoreHandle_t rts_lock;
static StaticSemaphore_t rts_lock_storage;
#ifdef GNAT_EMBEDDED_TESTING
unsigned __gnat_embedded_test_fail_create;
unsigned __gnat_embedded_test_create_attempts;
_Atomic unsigned __gnat_embedded_test_wakeups;
#endif

void __gnat_embedded_init(void)
{
    configASSERT(!xPortInIsrContext() && !rts_lock);
    rts_lock = xSemaphoreCreateRecursiveMutexStatic(&rts_lock_storage);
    configASSERT(rts_lock);
}
void __gnat_embedded_rts_lock(void)
{
    configASSERT(!xPortInIsrContext() && rts_lock);
    BaseType_t ok = xSemaphoreTakeRecursive(rts_lock, portMAX_DELAY);
    configASSERT(ok == pdTRUE);
}
void __gnat_embedded_rts_unlock(void)
{
    BaseType_t ok = xSemaphoreGiveRecursive(rts_lock);
    configASSERT(ok == pdTRUE);
}
TaskHandle_t __gnat_embedded_create(TaskFunction_t code, void *atcb,
                                    void *stack, void *task_buffer, size_t size,
                                    UBaseType_t priority, int cpu)
{
    configASSERT(!xPortInIsrContext() && code && atcb && stack && task_buffer);
    configASSERT((uintptr_t)task_buffer % _Alignof(StaticTask_t) == 0);
    configASSERT(cpu >= 0 && cpu <= portNUM_PROCESSORS);
    configASSERT(size >= configMINIMAL_STACK_SIZE);
#ifdef GNAT_EMBEDDED_TESTING
    if (++__gnat_embedded_test_create_attempts == __gnat_embedded_test_fail_create)
        return NULL;
#endif
    return xTaskCreateStaticPinnedToCore(code, "Ada task", size, atcb,
        priority, stack, task_buffer,
        cpu ? cpu - 1 : tskNO_AFFINITY);
}
SemaphoreHandle_t __gnat_xSemaphoreCreateBinaryStatic(StaticSemaphore_t *storage)
{
    configASSERT(storage);
    configASSERT((uintptr_t)storage % _Alignof(StaticSemaphore_t) == 0);
    return xSemaphoreCreateBinaryStatic(storage);
}

BaseType_t __gnat_xSemaphoreTake(SemaphoreHandle_t cv, TickType_t ticks)
{
    configASSERT(!xPortInIsrContext());
    return xSemaphoreTake(cv, ticks);
}

BaseType_t __gnat_xSemaphoreGive(SemaphoreHandle_t cv)
{
    configASSERT(!xPortInIsrContext());
#ifdef GNAT_EMBEDDED_TESTING
    atomic_fetch_add(&__gnat_embedded_test_wakeups, 1);
#endif
    return xSemaphoreGive(cv);
}
