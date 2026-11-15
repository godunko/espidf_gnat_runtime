/*
 *  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */

#include <stdint.h>
#include "sdkconfig.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

#if CONFIG_IDF_TARGET_ARCH_XTENSA
#include "xt_instr_macros.h"
#include "xtensa/corebits.h"
#elif CONFIG_IDF_TARGET_ARCH_RISCV
#include "soc/soc.h"
#include "soc/interrupt_reg.h"
#include "soc/soc_caps.h"
#if SOC_INT_CLIC_SUPPORTED
#include "esp_private/interrupt_clic.h"
#endif
#endif

/* Keep in sync with System.OS_Constants for this ESP32-S3 configuration. */
_Static_assert(CONFIG_FREERTOS_THREAD_LOCAL_STORAGE_POINTERS == 2,
               "ATCB uses TLS slot 1; configure exactly 2 slots for this ABI");
_Static_assert(tskNO_AFFINITY == 0x7FFFFFFF,
               "tskNO_AFFINITY differs from System.OS_Interface");
_Static_assert(configTICK_RATE_HZ == 100,
               "configTICK_RATE_HZ differs from System.OS_Constants");
_Static_assert(configMAX_PRIORITIES == 25,
               "configMAX_PRIORITIES differs from System.OS_Constants");

_Static_assert(sizeof(portMUX_TYPE) == 8,
               "portMUX_TYPE size differs from System.OS_Constants");
_Static_assert(_Alignof(portMUX_TYPE) == 4,
               "portMUX_TYPE alignment differs from System.OS_Constants");
_Static_assert(sizeof(StaticTask_t) == 348,
               "StaticTask_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticTask_t) == 4,
               "StaticTask_t alignment differs from System.OS_Constants");
_Static_assert(sizeof(StaticSemaphore_t) == 84,
               "StaticSemaphore_t size differs from System.OS_Constants");
_Static_assert(_Alignof(StaticSemaphore_t) == 4,
               "StaticSemaphore_t alignment differs from System.OS_Constants");

/* ESP-IDF owns one downward-growing interrupt stack per CPU. These are the
 * same arrays selected by the port's interrupt-entry assembly (both kernels).
 */
#if CONFIG_IDF_TARGET_ARCH_XTENSA
extern volatile StackType_t port_IntStack[portNUM_PROCESSORS][configISR_STACK_SIZE];
#elif CONFIG_IDF_TARGET_ARCH_RISCV
#if CONFIG_FREERTOS_SMP
extern StackType_t xIsrStack[configISR_STACK_SIZE];
#else
extern StackType_t xIsrStack[portNUM_PROCESSORS][configISR_STACK_SIZE];
#endif
#endif

_Static_assert(portSTACK_GROWTH < 0, "Stack checking requires downward stacks");

/* Expose port-owned ISR storage; all checking and context selection is Ada. */
void __gnat_get_interrupt_stack_bounds(void **bottom, void **top)
{
#if CONFIG_IDF_TARGET_ARCH_XTENSA
    const unsigned core = xPortGetCoreID();
    *bottom = (void *)&port_IntStack[core][0];
    *top = (void *)&port_IntStack[core][configISR_STACK_SIZE];
#elif CONFIG_IDF_TARGET_ARCH_RISCV
#if CONFIG_FREERTOS_SMP
    *bottom = (void *)&xIsrStack[0];
    *top = (void *)&xIsrStack[configISR_STACK_SIZE];
#else
    const unsigned core = xPortGetCoreID();
    *bottom = (void *)&xIsrStack[core][0];
    *top = (void *)&xIsrStack[core][configISR_STACK_SIZE];
#endif
#endif
}

/* Read the exact depth for Ada ISR pseudo-tasks, not an in-ISR boolean.
 * These counters belong to the ESP-IDF FreeRTOS ports. CONFIG_FREERTOS_SMP
 * selects the alternative kernel; the default kernel also supports multicore.
 */
#if CONFIG_IDF_TARGET_ARCH_XTENSA
extern unsigned port_interruptNesting[portNUM_PROCESSORS];
#elif CONFIG_IDF_TARGET_ARCH_RISCV
#if CONFIG_FREERTOS_SMP
extern volatile UBaseType_t uxInterruptNesting;
#else
extern volatile UBaseType_t port_uxInterruptNesting[portNUM_PROCESSORS];
#endif
#else
#error "Interrupt nesting is not implemented for this ESP-IDF architecture"
#endif

BaseType_t __gnat_interrupt_nesting(void)
{
#if CONFIG_IDF_TARGET_ARCH_XTENSA
    return port_interruptNesting[xPortGetCoreID()];
#elif CONFIG_IDF_TARGET_ARCH_RISCV
#if CONFIG_FREERTOS_SMP
    return uxInterruptNesting;
#else
    /* Also an array with CONFIG_FREERTOS_UNICORE, including single-core SoCs. */
    return port_uxInterruptNesting[xPortGetCoreID()];
#endif
#endif
}

BaseType_t __gnat_interrupt_level(void)
{
#if CONFIG_IDF_TARGET_ARCH_XTENSA
    unsigned ps;
    RSR(XT_REG_PS, ps);
    return ps & PS_INTLEVEL_MASK;
#elif CONFIG_IDF_TARGET_ARCH_RISCV
#if SOC_INT_CLIC_SUPPORTED
    /* CLIC tracks the active ISR level in hardware. The masking threshold
     * can be higher inside a critical section; both masks are inclusive.
     */
    uint32_t level = rv_utils_get_interrupt_level();
    uint32_t threshold = rv_utils_get_interrupt_threshold();
    return level > threshold ? level : threshold;
#else
    /* INTC/PLIC mask priorities strictly below the threshold. ESP-IDF's
     * ISR entry sets it to the active priority + 1. Threshold 0 or 1
     * therefore means that no interrupt priority is masked.
     */
    uint32_t threshold = REG_READ(INTERRUPT_CURRENT_CORE_INT_THRESH_REG);
    return threshold > 0 ? threshold - 1 : 0;
#endif
#else
#error "Interrupt level is not implemented for this ESP-IDF architecture"
#endif
}

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

BaseType_t __gnat_xPortGetCoreID(void)
{
    return xPortGetCoreID();
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
