/*
 *  ESP-IDF GNAT Runtime. Copyright (C) 2026 Vadim Godunko
 *
 *  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
 */

#include <assert.h>
#include <stdint.h>
#include <sys/time.h>

/* Keep the SDK's timeval/time_t ABI at the C boundary. */
int64_t __gnat_calendar_clock_usec(void)
{
    struct timeval now;
    int result = gettimeofday(&now, NULL);
    assert(result == 0);
    return (int64_t)now.tv_sec * 1000000 + now.tv_usec;
}
