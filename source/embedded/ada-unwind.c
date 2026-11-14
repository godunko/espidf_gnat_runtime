/*
 *  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */

//  Adapt ESP-IDF stack unwinding to support Ada exceptions in interrupt
//  context.

#include "freertos/FreeRTOS.h"

static portMUX_TYPE unwind_mux = portMUX_INITIALIZER_UNLOCKED;

int __gnat_unwind_active(void)
{
    return 0;
    /* Address is the gthread probe. */
}

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
