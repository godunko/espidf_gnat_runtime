/* ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
 * SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdatomic.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

/* Keep in sync with System.OS_Constants for this ESP32-S3 configuration. */
_Static_assert(sizeof(StaticTask_t) == 340,
               "StaticTask_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticTask_t) == 4,
               "StaticTask_t alignment differs from System.OS_Constants");

/* Private to this C translation unit; Ada stores an opaque pointer. */
struct ada_thread {
    TaskHandle_t handle;
    void *atcb;
    void (*code)(void *);
    struct ada_thread *next;
    StaticSemaphore_t gate_storage, wake_storage;
    SemaphoreHandle_t gate, wake;
    _Atomic int priority;
    int cpu;                       /* Ada numbering: 0 unspecified, 1..N */
    bool cancelled;
};
static struct ada_thread environment;
static _Thread_local struct ada_thread *current;
static _Thread_local struct ada_thread *pending;
static _Thread_local bool activating;
static SemaphoreHandle_t rts_lock;
static StaticSemaphore_t rts_lock_storage;
#ifdef GNAT_EMBEDDED_TESTING
unsigned __gnat_embedded_test_fail_create;
unsigned __gnat_embedded_test_create_attempts;
unsigned __gnat_embedded_test_cancel_requests;
_Atomic unsigned __gnat_embedded_test_wrapper_entries;
_Atomic unsigned __gnat_embedded_test_cancelled;
#endif

static UBaseType_t kernel_priority(int priority)
{
    configASSERT(priority >= 0);
    /* Ada 0..23 -> FreeRTOS 1..24; reserve priority 0 for idle tasks.
     * Higher Ada ceilings are tracked, but ISR masking is a later stage. */
    return priority < configMAX_PRIORITIES - 1 ? priority + 1
                                              : configMAX_PRIORITIES - 1;
}

void __gnat_embedded_init(void *atcb)
{
    configASSERT(!current && !xPortInIsrContext());
    rts_lock = xSemaphoreCreateRecursiveMutexStatic(&rts_lock_storage);
    configASSERT(rts_lock);
    environment.handle = xTaskGetCurrentTaskHandle();
    environment.atcb = atcb;
    environment.cpu = xPortGetCoreID() + 1;
    environment.wake = xSemaphoreCreateBinaryStatic(&environment.wake_storage);
    configASSERT(environment.wake);
    current = &environment;
}
void *__gnat_embedded_self(void) { configASSERT(current); return current; }
void *__gnat_embedded_atcb(void) { configASSERT(current); return current->atcb; }
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
void __gnat_embedded_begin(void)
{
    configASSERT(current && !activating && !pending);
    activating = true;
}
static void trampoline(void *arg)
{
    struct ada_thread *thread = arg;
    current = thread;
    BaseType_t ok = xSemaphoreTake(thread->gate, portMAX_DELAY);
    configASSERT(ok == pdTRUE);
    if (!thread->cancelled) {
#ifdef GNAT_EMBEDDED_TESTING
        atomic_fetch_add(&__gnat_embedded_test_wrapper_entries, 1);
#endif
        thread->code(thread->atcb);
        /* Restricted task wrappers should not return. */
        abort();
    }
    /* The TCB storage belongs to the static Ada ATCB. The C descriptor and
     * semaphore storage remain alive while this cancelled trampoline exits. */
#ifdef GNAT_EMBEDDED_TESTING
    atomic_fetch_add(&__gnat_embedded_test_cancelled, 1);
#endif
    vTaskDelete(NULL);
}
void *__gnat_embedded_create(void (*code)(void *), void *atcb,
                             void *stack, void *task_buffer, size_t size,
                             int priority, int cpu)
{
    configASSERT(activating && code && atcb && stack && task_buffer);
    configASSERT((uintptr_t)task_buffer % _Alignof(StaticTask_t) == 0);
    configASSERT(cpu >= 0 && cpu <= portNUM_PROCESSORS);
    configASSERT(size >= configMINIMAL_STACK_SIZE);
#ifdef GNAT_EMBEDDED_TESTING
    if (++__gnat_embedded_test_create_attempts == __gnat_embedded_test_fail_create)
        return NULL;
#endif
    struct ada_thread *thread = calloc(1, sizeof(*thread));
    if (!thread) return NULL;
    thread->atcb = atcb;
    thread->code = code;
    thread->cpu = cpu;
    atomic_init(&thread->priority, priority);
    thread->gate = xSemaphoreCreateBinaryStatic(&thread->gate_storage);
    thread->wake = xSemaphoreCreateBinaryStatic(&thread->wake_storage);
    configASSERT(thread->gate && thread->wake);
    thread->handle = xTaskCreateStaticPinnedToCore(trampoline, "Ada task",
        size, thread, kernel_priority(priority), stack, task_buffer,
        cpu ? cpu - 1 : tskNO_AFFINITY);
    if (!thread->handle) {
        vSemaphoreDelete(thread->gate);
        vSemaphoreDelete(thread->wake);
        free(thread);
        return NULL;
    }
    thread->next = pending;
    pending = thread;
    return thread;
}
static void finish_group(bool cancel)
{
    configASSERT(activating);
    struct ada_thread *thread = pending;
    pending = NULL;
    activating = false;
    while (thread) {
        struct ada_thread *next = thread->next;
        thread->cancelled = cancel;
#ifdef GNAT_EMBEDDED_TESTING
        if (cancel) ++__gnat_embedded_test_cancel_requests;
#endif
        /* Semaphore release publishes ATCB/handle/state to the trampoline;
         * the signal persists if it has not yet entered xSemaphoreTake. */
        BaseType_t ok = xSemaphoreGive(thread->gate);
        configASSERT(ok == pdTRUE);
        thread = next;
    }
}
void __gnat_embedded_commit(void) { finish_group(false); }
void __gnat_embedded_abort(void) { if (activating) finish_group(true); }
void __gnat_embedded_set_priority(int priority)
{
    configASSERT(current && !xPortInIsrContext());
    atomic_store(&current->priority, priority);
    vTaskPrioritySet(NULL, kernel_priority(priority));
}
int __gnat_embedded_priority(struct ada_thread *thread)
{ return atomic_load(&thread->priority); }
int __gnat_embedded_affinity(struct ada_thread *thread) { return thread->cpu; }
void __gnat_embedded_sleep(void)
{
    configASSERT(current && !xPortInIsrContext());
    BaseType_t ok = xSemaphoreTake(current->wake, portMAX_DELAY);
    configASSERT(ok == pdTRUE);
}
void __gnat_embedded_wakeup(struct ada_thread *thread)
{
    /* Stage 1: task context only. Binary tokens coalesce repeated wakeups. */
    configASSERT(!xPortInIsrContext());
    (void)xSemaphoreGive(thread->wake);
}
