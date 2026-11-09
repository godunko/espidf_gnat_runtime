--
--  ESP-IDF embedded backend. Copyright (C) 2026 Vadim Godunko
--
--  SPDX-License-Identifier: GPL-3.0-or-later WITH GCC-exception-3.1
--

package System.OS_Constants is

   pragma Pure;

   configMAX_PRIORITIES : constant := 25;

   --  Byte sizes and alignments for the tested ESP32-S3 / ESP-IDF 6.1
   --  configuration with Newlib. Keep the C assertions in embedded.c in sync.
   StaticTask_t_Size           : constant := 340;
   StaticTask_t_Alignment      : constant := 4;
   StaticSemaphore_t_Size      : constant := 84;
   StaticSemaphore_t_Alignment : constant := 4;

end System.OS_Constants;
